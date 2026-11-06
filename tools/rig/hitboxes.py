"""Hitboxes sincronizadas com a animação, para os 79 rigs.

    python tools/rig/hitboxes.py            # lê rigs/**/*.tscn e grava metadata/hitboxes em cada cena
    python tools/rig/hitboxes.py --check    # só confere (não grava) e mostra o relatório

Não precisa do Blender: lê as próprias cenas do Godot (ossos em repouso + trilhas das animações),
refaz a cinemática direta com interpolação linear (a mesma que o Godot usa: trilhas "interp = 1")
e, em cada golpe, descobre qual ponta acerta (punho, pé ou arma), quando ela está no ponto de
impacto e por onde ela passa quadro a quadro.

Para cada animação de golpe grava em `metadata/hitboxes` do nó raiz da cena:

    "jab": {
        "bone": "arm_f_lo",        # osso cuja ponta acerta
        "r": 10.0,                 # raio da hitbox em volta da ponta (px, escala 1)
        "on": 0.30, "off": 0.42,   # janela de contato na linha do tempo da animação (u = 0..1)
        "peak": 46.0,              # alcance da ponta no impacto (px à frente dos pés)
        "pts": PackedFloat32Array(u0, x0, y0, u1, x1, y1, ...)   # trajetória da ponta (60 amostras/u)
        # golpes armados (swing, slam): base e ângulo da arma e a janela de contato da ponta da arma
        "won": 0.30, "woff": 0.40, "wpn": PackedFloat32Array(u0, x0, y0, ang0, ...)
    }

Coordenadas do rig: origem nos pés, x para a frente, y para BAIXO, escala 1.
O jogo (fighter.gd -> hitbox_now) transforma para o mundo com facing, body_scale e altura.
"""
import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RIGS = ROOT / "rigs"

# Linha do tempo dos golpes (igual a moves.py e fighter.gd -> _attack_u)
U_HIT, U_HOLD = 0.30, 0.42
STEP = 1.0 / 60.0

# Golpes e quais pontas podem acertar em cada um
STRIKES = {
    "jab": ["arm_f_lo", "arm_b_lo"],
    "cross": ["arm_b_lo", "arm_f_lo"],
    "upper": ["arm_f_lo", "arm_b_lo"],
    "kick": ["foot_f", "foot_b"],
    "jumpkick": ["foot_f", "foot_b"],
    "swing": ["arm_f_lo"],
    "slam": ["arm_f_lo", "arm_b_lo"],
    "charge": ["arm_f_lo", "arm_b_lo", "spine"],
    "throw": ["arm_f_lo", "arm_b_lo"],
    "special": ["arm_f_lo", "arm_b_lo", "foot_f", "foot_b"],
    "dive": ["head", "arm_f_lo", "arm_b_lo"],
    "finisher": ["arm_f_lo", "arm_b_lo", "foot_f"],
}
WEAPON_ANIMS = ("swing", "slam")  # golpes armados (Weapons.player_combo / enemy_combo)
RADIUS = {"arm": 10.0, "foot": 12.0, "spine": 16.0, "head": 14.0}
# jumpkick no jogo vai de 0 a 1 em 0,16 s e fica parado no fim: a janela é a perna esticada
OPEN_ENDED = ("jumpkick",)
# Rotação do corpo inteiro que o jogo aplica por cima da animação (fighter.gd -> body_rot):
# no mergulho (TOPE SUICIDA) o lutador voa deitado, e os braços "para cima" apontam para a frente.
BODY_ROT = {"dive": math.pi * 0.45}

NUM = r"-?[\d.]+(?:e-?\d+)?"


def _floats(s):
    return [float(x) for x in re.findall(NUM, s)]


def parse_scene(text):
    """Ossos (pai, posição e rotação de repouso, comprimento) e trilhas das animações."""
    bones = {}
    for m in re.finditer(r'\[node name="(\w+)" type="Bone2D" parent="([^"]+)"\]\n(.*?)(?=\n\[|\Z)', text, re.S):
        name, parent, body = m.group(1), m.group(2).split("/")[-1], m.group(3)
        pos = re.search(r"^position = Vector2\(([^)]*)\)", body, re.M)
        rot = re.search(r"^rotation = (" + NUM + ")", body, re.M)
        ln = re.search(r"^length = (" + NUM + ")", body, re.M)
        bones[name] = {
            "parent": None if parent == "Skeleton2D" else parent,
            "pos": tuple(_floats(pos.group(1))) if pos else (0.0, 0.0),
            "rot": float(rot.group(1)) if rot else 0.0,
            "len": float(ln.group(1)) if ln else 0.0,
        }
    anims = {}
    for m in re.finditer(r'\[sub_resource type="Animation" id="Animation_(\w+)"\]\n(.*?)(?=\n\[|\Z)', text, re.S):
        name, body = m.group(1), m.group(2)
        length = float(re.search(r"^length = (" + NUM + ")", body, re.M).group(1))
        tracks = {}
        for t in re.finditer(r'tracks/\d+/path = NodePath\("([^"]+)"\).*?"times": PackedFloat32Array\(([^)]*)\).*?"values": \[(.*?)\]\n\}',
                             body, re.S):
            path, times, values = t.group(1), _floats(t.group(2)), t.group(3)
            node, prop = path.rsplit(":", 1)
            bone = node.split("/")[-1]
            if prop == "position":
                vals = [tuple(_floats(v)) for v in re.findall(r"Vector2\(([^)]*)\)", values)]
            elif prop == "rotation":
                vals = _floats(values)
            else:
                continue
            tracks[(bone, prop)] = (times, vals)
        anims[name] = {"length": length, "tracks": tracks}
    return bones, anims


def _sample(track, t):
    times, vals = track
    if t <= times[0]:
        return vals[0]
    if t >= times[-1]:
        return vals[-1]
    lo, hi = 0, len(times) - 1
    while hi - lo > 1:
        mid = (lo + hi) // 2
        if times[mid] <= t:
            lo = mid
        else:
            hi = mid
    k = (t - times[lo]) / max(times[hi] - times[lo], 1e-9)
    a, b = vals[lo], vals[hi]
    if isinstance(a, tuple):
        return (a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k)
    return a + (b - a) * k


def pose_at(bones, anim, u):
    """Transform global (x, y, ângulo) de cada osso no ponto u (0..1) da animação."""
    t = u * anim["length"]
    out = {}

    def solve(n):
        if n in out:
            return out[n]
        b = bones[n]
        tr = anim["tracks"]
        px, py = _sample(tr[(n, "position")], t) if (n, "position") in tr else b["pos"]
        r = _sample(tr[(n, "rotation")], t) if (n, "rotation") in tr else b["rot"]
        if b["parent"] is None:
            x, y, a = px, py, r
        else:
            qx, qy, qa = solve(b["parent"])
            x = qx + px * math.cos(qa) - py * math.sin(qa)
            y = qy + px * math.sin(qa) + py * math.cos(qa)
            a = qa + r
        out[n] = (x, y, a)
        return out[n]

    for n in bones:
        solve(n)
    return out


def tip(bones, pose, n):
    x, y, a = pose[n]
    ln = bones[n]["len"]
    return x + math.cos(a) * ln, y + math.sin(a) * ln


UPWARD = ("upper",)  # golpes que acertam subindo: o alcance é a altura da ponta, não o avanço
EXT_MIN = 0.75  # fração do alcance máximo da ponta que ainda conta como contato
WPN_LEN = 36.0  # comprimento típico das armas (weapons.gd: 20..44) para achar a janela do golpe armado


def contact_window(us, poses, cands, tipf, an):
    """Ponta que mais avança no trecho "active" e o intervalo em que ela fica lá na frente
    (alcance >= EXT_MIN do máximo): vale para golpes retos (jab, chute) e em arco (arma, slam)."""
    lo, hi = U_HIT - 0.02, (1.0 if an in OPEN_ENDED else U_HOLD + 0.02)
    idx = [i for i, u in enumerate(us) if lo <= u <= hi]
    up = an in UPWARD

    def reach(b, p):
        x, y = tipf(b, p)
        return -y if up else x

    _, bone, ipk = max((reach(b, poses[i]), b, i) for b in cands for i in idx)
    ref = tipf(bone, poses[ipk])
    cut = reach(bone, poses[ipk]) * EXT_MIN

    def out(i):
        return reach(bone, poses[i]) >= cut

    a = b = ipk
    while a > 0 and out(a - 1) and us[a - 1] >= U_HIT - 0.04:
        a -= 1
    while b < len(us) - 1 and out(b + 1):
        b += 1
    return bone, us[a], us[b], ref


def strike_data(bones, anim, an):
    us = [i * STEP for i in range(int(round(1.0 / STEP)) + 1)]
    poses = [pose_at(bones, anim, u) for u in us]
    cands = [b for b in STRIKES[an] if b in bones]
    rot = BODY_ROT.get(an, 0.0)

    def ltip(b, p):
        x, y = tip(bones, p, b)
        return x * math.cos(rot) - y * math.sin(rot), x * math.sin(rot) + y * math.cos(rot)

    bone, on, off, ref = contact_window(us, poses, cands, ltip, an)
    pts = []
    for u, p in zip(us, poses):
        x, y = tip(bones, p, bone)
        pts += [round(u, 4), round(x, 2), round(y, 2)]
    kind = "arm" if bone.startswith("arm") else "foot" if bone.startswith("foot") else bone
    d = {"bone": bone, "r": RADIUS.get(kind, 10.0), "on": round(on, 4), "off": round(off, 4),
         "peak": round(ref[0], 2), "pts": pts}  # pts sem a rotação do corpo; peak já com ela
    if an in WEAPON_ANIMS and "weapon" in bones:
        def wtip(_b, p):
            x, y, ang = p["weapon"]
            return x + math.cos(ang) * WPN_LEN, y + math.sin(ang) * WPN_LEN
        _, won, woff, _ = contact_window(us, poses, ["weapon"], wtip, an)
        w = []
        for u, p in zip(us, poses):
            x, y, ang = p["weapon"]
            w += [round(u, 4), round(x, 2), round(y, 2), round(ang, 4)]
        d.update({"won": round(won, 4), "woff": round(woff, 4), "wpn": w})
        d["wsw"] = swing_onset(us, [wtip(None, p) for p in poses], won)
    d["sw"] = swing_onset(us, [ltip(bone, p) for p in poses], on)
    return d


SWING_FROM = 0.10    # o golpe no ar só pode começar depois daqui (antes é a guarda/antecipação lenta)
SWING_SPEED = 0.25   # começa quando a ponta passa de 25% da velocidade máxima até o impacto


def swing_onset(us, tips, on):
    """[u em que a ponta começa o trecho rápido que termina no impacto, caminho dela (px) nesse trecho]:
    o som do golpe cortando o ar começa ali (fighter.gd -> _process_attack)."""
    idx = [i for i, u in enumerate(us) if SWING_FROM <= u <= on + 1e-6 and i > 0]
    if not idx:
        return [round(on, 4), 0.0]
    sp = {i: math.hypot(tips[i][0] - tips[i - 1][0], tips[i][1] - tips[i - 1][1]) for i in idx}
    top = max(sp.values())
    # último trecho rápido contínuo até o impacto (o golpe; a subida da preparação não conta)
    start = idx[-1]
    while start - 1 in sp and sp[start - 1] >= SWING_SPEED * top:
        start -= 1
    arc = sum(sp[i] for i in idx if i >= start)
    return [round(us[start - 1], 4), round(arc, 1)]


HURT_H, HURT_W = 100.0, 16.0  # hurtbox do corpo (fighter.gd)
GAME_WINDOW = {"jumpkick": (0.0, 1.0)}  # no ar o jogo vai de 0 a 1 em 0,16 s e fica no fim


def _interp(arr, stride, u):
    n = len(arr) // stride
    f = min(max(u, 0.0), 1.0) * (n - 1)
    i = min(int(f), n - 2)
    k = f - i
    return [arr[i * stride + j] + (arr[(i + 1) * stride + j] - arr[i * stride + j]) * k for j in range(1, stride)]


SWEPT, SWEEP_U = ("upper",), 0.04  # fighter.gd: hitbox cobre o caminho da ponta nos últimos SWEEP_U


def simulate(d, u, reach, wlen=None, scale=1.0, height=0.0, rot=0.0, both=False, an=None, body=None):
    """Mesmo cálculo de fighter.gd -> hitbox_now. None = fora da janela de contato.
    rot = rotação do corpo (mergulho); both = golpe giratório, acerta dos dois lados."""
    armed = wlen is not None and "wpn" in d
    on, off = (d["won"], d["woff"]) if armed else (d["on"], d["off"])
    if u < on - 0.001 or u > off + 0.001:
        return None
    x, y = _interp(d["pts"], 3, u)
    x, y = x * math.cos(rot) - y * math.sin(rot), x * math.sin(rot) + y * math.cos(rot)
    r, peak = d["r"], max(d["peak"], 1.0)
    if armed:
        wx, wy, ang = _interp(d["wpn"], 4, u)
        x, y = wx + math.cos(ang) * wlen, wy + math.sin(ang) * wlen
        px, _, pa = _interp(d["wpn"], 4, on)
        peak, r = max(px + math.cos(pa) * wlen, 1.0), 14.0
    far = reach * min(max(x / peak, 0.2), 1.15) * scale
    lo = hi = height - y * scale
    if an in SWEPT:
        _, py = _interp(d["pts"], 3, max(u - SWEEP_U, 0.0))
        lo, hi = min(lo, height - py * scale), max(hi, height - py * scale)
    if body is not None:  # investida: o corpo inteiro avança (fighter.gd -> hitbox_at, "dash")
        bx0, by0, bx1, by1 = body
        lo, hi = min(lo, height - by1 * scale), max(hi, height - by0 * scale)
        far = max(far, bx1 * scale)
    return (-far if both else -15.0, far, lo - r * scale, hi + r * scale)


def hits(box, dx, tg_h=0.0, tg_s=1.0):
    return (box is not None and dx + HURT_W * tg_s >= box[0] and dx - HURT_W * tg_s <= box[1]
            and box[3] >= tg_h and box[2] <= tg_h + HURT_H * tg_s)


def gameplay_check(name, hb):
    """Todo golpe do jogo, nesta animação, ainda acerta um alvo parado no chão a 90% do alcance
    em algum quadro da janela de acerto (como a caixa antiga acertava)."""
    bad = []
    cases = [("jab", 58, None), ("cross", 62, None), ("kick", 74, None), ("upper", 56, None), ("slam", 64, None),
             ("charge", 56, None), ("swing", 82, 22.0), ("swing", 88, 44.0), ("slam", 86, 30.0), ("jumpkick", 66, None),
             ("finisher", 72, None)]
    for an, reach, wlen in cases:
        if an not in hb:
            continue
        lo, hi = GAME_WINDOW.get(an, (U_HIT, U_HOLD))
        height = 40.0 if an == "jumpkick" else 0.0
        us = [lo + (hi - lo) * i / 24.0 for i in range(25)]
        if not any(hits(simulate(hb[an], u, reach, wlen, 1.0, height, an=an), reach * 0.9) for u in us):
            bad.append("%s/%s (alcance %d%s)" % (name, an, reach, ", arma %d" % wlen if wlen else ""))
    # especial básico giratório (ATK_SPECIAL do jogador e o giro dos chefes): acerta na frente e atrás
    if "special" in hb:
        us = [U_HIT + (U_HOLD - U_HIT) * i / 24.0 for i in range(25)]
        for dx in (90.0, -90.0):
            if not any(hits(simulate(hb["special"], u, 100.0, both=True), dx) for u in us):
                bad.append("%s/special giratório (alvo a %+d px)" % (name, dx))
    return bad


def player_specials():
    """(slug, especial) dos 14 lutadores, lidos de scripts/characters.gd (mesma ordem das duas listas)."""
    text = (ROOT / "scripts" / "characters.gd").read_text(encoding="utf-8")
    sps = []
    for line in re.findall(r'^\t\t\{"name": "[^"]+", "type": .*$', text, re.M):
        sp = {k: v for k, v in re.findall(r'"(type|pose|pose_a|pose_b)": "(\w+)"', line)}
        sp["name"] = re.search(r'"name": "([^"]+)"', line).group(1)
        sp["reach"] = float(re.search(r'"reach": (' + NUM + ')', line).group(1)) if '"reach"' in line else 0.0
        sp["spin"] = '"spin": true' in line or sp["type"] == "spin"
        sps.append(sp)
    names = re.findall(r'^\t\t\{"name": "([^"]+)", "region"', text, re.M)
    slug = lambda n: n.lower().translate(str.maketrans("áàâãéêíóôõúç", "aaaaeeiooouc"))
    return [(slug(n), sp) for n, sp in zip(names, sps)]


# Como cada tipo de especial dirige a animação no jogo (player.gd -> _process_special, fighter.gd -> rig_anim):
# fase 1 = golpeando -> u 0,36 (voadora: 1,0, perna esticada); altura do lutador quando acerta.
SPECIAL_HEIGHT = {"dive": 32.0, "rise": 20.0}


def special_check(slug, hb):
    """Cada especial corpo a corpo do lutador acerta um alvo no chão a 90% do alcance
    (e, nos giratórios, também atrás dele) no quadro em que o jogo confere o acerto."""
    bad = []
    for sl, sp in player_specials():
        if sl != slug or sp["type"] in ("projectile", "quake"):
            continue
        poses = [sp.get("pose_a"), sp.get("pose_b"), "upper"] if sp["type"] == "flurry" else \
            ["slam"] if sp["type"] == "slam" else [sp.get("pose", "dive" if sp["type"] == "dive" else "special")]
        for an in poses:
            u = 1.0 if an == "jumpkick" else 0.36
            box = simulate(hb[an], u, sp["reach"], height=SPECIAL_HEIGHT.get(sp["type"], 0.0),
                           rot=BODY_ROT.get(an, 0.0) if sp["type"] == "dive" else 0.0,
                           both=sp["spin"] or sp["type"] == "slam")
            ok = hits(box, sp["reach"] * 0.9) and (not (sp["spin"] or sp["type"] == "slam") or hits(box, -sp["reach"] * 0.9))
            if not ok:
                bad.append("%s/especial %s (%s, alcance %d)" % (slug, sp["name"], an, sp["reach"]))
    return bad


# Projéteis soltos no quadro de contato da animação (fighter.gd -> release_point):
# (animação, faixa de altura aceitável do ponto de soltura acima do chão, avanço mínimo)
RELEASES = {"throw": (30.0, 120.0, 20.0), "jab": (30.0, 110.0, 20.0), "slam": (0.0, 40.0, 20.0)}
KI_R, WAVE_H = 18.0, 34.0  # energy.gd


def release_point(d):
    x, y = _interp(d["pts"], 3, d["on"])
    return x, -y


def projectile_check(name, hb, player):
    """O ponto de soltura de cada projétil fica na mão/punho, à frente e na altura certa, e a
    hitbox do projétil acerta um alvo parado no chão."""
    bad = []
    for an, (h0, h1, fwd) in RELEASES.items():
        if an not in hb or (an != "throw" and not player):
            continue  # Onda Ki (jab) e Onda Sísmica (slam) são dos lutadores; inimigos só arremessam (ÉON)
        x, h = release_point(hb[an])
        if not (h0 <= h <= h1 and x >= fwd):
            bad.append("%s/soltura do %s em (%.0f, %.0f)" % (name, an, x, h))
    if player and "jab" in hb:
        _, h = release_point(hb["jab"])
        if not hits((-34.0, 34.0, h - KI_R, h + KI_R), 0.0):
            bad.append("%s/onda ki na altura %.0f não acerta alvo no chão" % (name, h))
    return bad


# Caixas quebráveis (crate.gd): hurtbox = caixa desenhada (52 × 50) + folga da tampa
CRATE_W, CRATE_H, CRATE_LID = 52.0, 50.0, 8.0


def player_sizes():
    text = (ROOT / "scripts" / "characters.gd").read_text(encoding="utf-8")
    sizes = [float(x) for x in re.findall(r'"size": (' + NUM + ')', text)]
    return {sl: sz for (sl, _), sz in zip(player_specials(), sizes)}


def crate_check(name, hb):
    """Com o tamanho real do lutador, o combo básico (jab, cross, chute) e o golpe armado
    quebram uma caixa à frente: a ponta da animação passa pela caixa desenhada."""
    size = player_sizes().get(name)
    if size is None:
        return []
    bad = []
    us = [U_HIT + (U_HOLD - U_HIT) * i / 24.0 for i in range(25)]
    for an, reach, wlen in (("jab", 58, None), ("cross", 62, None), ("kick", 74, None), ("swing", 82, 30.0)):
        dx = reach * 0.7 * size
        ok = any(b is not None and dx + CRATE_W / 2 >= b[0] and dx - CRATE_W / 2 <= b[1]
                 and b[3] >= 0.0 and b[2] <= CRATE_H + CRATE_LID
                 for b in (simulate(hb[an], u, reach, wlen, size) for u in us))
        if not ok:
            bad.append("%s/%s não quebra a caixa" % (name, an))
    return bad


def enemy_hurt_check(players_hb, name, hurt):
    """Com a hurtbox animada do inimigo (parado, no quadro do idle), cada golpe básico de cada lutador
    ainda acerta: jab, cross, gancho, chute, voadora e golpe armado, nos tamanhos reais dos lutadores."""
    bad = []
    b = hurt["idle"]["box"]
    x0, y0, x1, y1 = b[1:5]  # primeiro quadro do idle
    sizes = player_sizes()
    us = [U_HIT + (U_HOLD - U_HIT) * i / 24.0 for i in range(25)]
    for scale in (1.0, 1.3, 1.6):  # tipos comuns, brutos/sub-chefes e chefes
        for sl, hb in players_hb.items():
            sz = sizes[sl]
            for an, reach, wlen, height, uu in (("jab", 58, None, 0.0, us), ("cross", 62, None, 0.0, us),
                                                  ("upper", 56, None, 0.0, us), ("kick", 74, None, 0.0, us),
                                                  ("swing", 82, 30.0, 0.0, us), ("jumpkick", 66, None, 40.0, [1.0])):
                dx = reach * 0.8 * sz
                tx0, tx1 = dx + x0 * scale, dx + x1 * scale  # inimigo virado para o lutador (espelhado)
                tx0, tx1 = dx - x1 * scale, dx - x0 * scale
                th0, th1 = -y1 * scale, -y0 * scale
                ok = False
                for u in uu:
                    bx = simulate(hb[an], u, reach, wlen, sz, height, an=an)
                    if bx and tx1 >= bx[0] and tx0 <= bx[1] and bx[3] >= th0 and bx[2] <= th1:
                        ok = True
                        break
                if not ok:
                    bad.append("%s (escala %.1f) não apanha do %s de %s" % (name, scale, an, sl))
    return bad


def enemy_attacks():
    """{tipo: (escala, [(pose, alcance, radial)])} lidos de scripts/enemy.gd (golpes normais da IA)."""
    text = (ROOT / "scripts" / "enemy.gd").read_text(encoding="utf-8")
    out = {}
    parts = re.split(r'^\t\t"(\w+)":\n', text, flags=re.M)
    for kind, body in zip(parts[1::2], parts[2::2]):
        sc = re.search(r"body_scale = (" + NUM + ")", body)
        m = re.search(r"\battacks = \[(.*?)\]\n", body, re.S)
        if not m:
            continue
        atks = [(a, float(r), '"radial": true' in line)
                for line in m.group(1).split("\n") for a, r in re.findall(r'"pose": "(\w+)".*?"reach": (' + NUM + ')', line)]
        sp = re.search(r'special_attack = \{"pose": "(\w+)".*?"reach": (' + NUM + ')', body)
        if sp:
            atks.append((sp.group(1), float(sp.group(2)), "dash"))
        out[kind] = (float(sc.group(1)) if sc else 1.0, atks)
    return out


def player_hurt_check(enemy_hb, players_hurt, enemy_hurt):
    """Os golpes normais de cada inimigo (no tamanho do tipo dele) acertam cada lutador parado, com a
    hurtbox animada do lutador (primeiro quadro do idle), à distância em que a IA para (48 px × escala)."""
    bad = []
    sizes = player_sizes()
    us = [U_HIT + (U_HOLD - U_HIT) * i / 24.0 for i in range(25)]
    kinds = enemy_attacks()
    for name, hb in enemy_hb.items():
        kind = name.split("_", 1)[1]
        if kind not in kinds:
            continue
        scale, atks = kinds[kind]
        for sl, hurt in players_hurt.items():
            sz = sizes[sl]
            x0, y0, x1, y1 = hurt["idle"]["box"][1:5]
            hover = max(0.0, -enemy_hurt[name]["idle"]["box"][4]) * scale  # quem flutua desce para golpear
            for an, reach, radial in atks:
                if an not in hb:
                    continue
                dx = 48.0 * scale
                tx0, tx1 = dx - x1 * sz, dx - x0 * sz  # lutador virado para o inimigo
                th0, th1 = -y1 * sz, -y0 * sz
                def bodyat(u):
                    if radial != "dash":
                        return None
                    bb = enemy_hurt[name][an]["box"]
                    i = min(int(round(u * 30)), 30)
                    return bb[i * 5 + 1:i * 5 + 5]
                ok = any(b and tx1 >= b[0] and tx0 <= b[1] and b[3] >= th0 and b[2] <= th1
                         for b in (simulate(hb[an], u, reach, None, scale, -hover, both=radial is True, an=an,
                                            body=bodyat(u)) for u in us))
                if not ok:
                    bad.append("%s (%s, escala %.1f) não acerta %s parado" % (name, an, scale, sl))
            if kind == "secret_boss" and "throw" in hb:
                # orbes: saem da mão no quadro de soltura (já no chão) e voam a essa altura
                _, h = release_point(hb["throw"])
                h = h * scale - hover
                if not (h + KI_R >= -y1 * sz and h - KI_R <= -y0 * sz):
                    bad.append("%s (orbes na altura %.0f) não acertam %s parado" % (name, h, sl))
    return bad


def _fmt(v):
    if isinstance(v, dict):
        return "{" + ", ".join('"%s": %s' % (k, _fmt(x)) for k, x in v.items()) + "}"
    if isinstance(v, list):
        return "PackedFloat32Array(" + ", ".join(_g(x) for x in v) + ")"
    if isinstance(v, str):
        return '"%s"' % v
    return _g(v)


def _g(x):
    s = ("%.4f" % x).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def rig_hitboxes(text):
    bones, anims = parse_scene(text)
    return {an: strike_data(bones, anims[an], an) for an in STRIKES if an in anims}


# Hurtbox do corpo quadro a quadro: caixa da silhueta desenhada (peças do corpo) em cada amostra.
BODY_BONES = ("root", "pelvis", "spine", "head", "arm_b_up", "arm_b_lo", "arm_f_up", "arm_f_lo",
              "leg_b_up", "leg_b_lo", "foot_b", "leg_f_up", "leg_f_lo", "foot_f")
HURT_STEP = 1.0 / 30.0
HURT_ANIMS = ("idle", "walk", "hurt", "jab", "cross", "upper", "kick", "swing", "slam", "charge", "throw", "special",
              "jump", "jumpkick", "dive", "block", "dodge", "finisher")


def parse_parts(text):
    """Peças desenhadas (Polygon2D com skinning): vértices em repouso e [(osso, pesos por vértice)]."""
    parts = []
    for m in re.finditer(r'\[node name="(\w+)" type="Polygon2D" parent="Parts"\]\n(.*?)(?=\n\[|\Z)', text, re.S):
        body = m.group(2)
        poly = re.search(r"^polygon = PackedVector2Array\(([^)]*)\)", body, re.M)
        bl = re.search(r"^bones = \[(.*)\]$", body, re.M)
        if not poly or not bl:
            continue
        v = _floats(poly.group(1))
        verts = list(zip(v[0::2], v[1::2]))
        ws = [(path.split("/")[-1], _floats(w))
              for path, w in re.findall(r'NodePath\("([^"]+)"\), PackedFloat32Array\(([^)]*)\)', bl.group(1))]
        parts.append((m.group(1), verts, ws))
    return parts


def _inv(t):
    x, y, a = t
    c, s = math.cos(-a), math.sin(-a)
    return (-(x * c - y * s), -(x * s + y * c), -a)


def _apply(t, p):
    x, y, a = t
    return (x + p[0] * math.cos(a) - p[1] * math.sin(a), y + p[0] * math.sin(a) + p[1] * math.cos(a))


def body_box(bones, pose, parts, rest):
    """Caixa da silhueta desenhada neste quadro: cada vértice das peças do corpo (cabelo e chapéu
    incluídos) deformado pelos ossos como o Godot faz (pose do osso x inverso do repouso)."""
    xs, ys = [], []
    for name, verts, ws in parts:
        if name.startswith(("ol_", "dt_", "est_")):
            continue  # contornos e detalhes de acabamento: a caixa do corpo é a das peças-base
        if any(b not in BODY_BONES for b, _ in ws):
            continue  # capas, halo, ampulheta, orbes, tranças: efeitos que balançam sozinhos
        for i, v in enumerate(verts):
            x = y = tw = 0.0
            for b, w in ws:
                wi = w[i] if i < len(w) else 0.0
                if wi <= 0.0:
                    continue
                q = _apply(pose[b], _apply(_inv(rest[b]), v))
                x, y, tw = x + q[0] * wi, y + q[1] * wi, tw + wi
            if tw > 0.0:
                xs.append(x / tw)
                ys.append(y / tw)
    return min(xs), min(ys), max(xs), min(max(ys), 0.0)  # não passa do chão


def rig_hurtboxes(text):
    """{anim: {"len": duração (s), "box": PackedFloat32Array(u, x0, y0, x1, y1, ...)}} a cada 1/30 de u."""
    bones, anims = parse_scene(text)
    parts = parse_parts(text)
    rest = pose_at(bones, {"length": 1.0, "tracks": {}}, 0.0)
    out = {}
    for an in HURT_ANIMS:
        if an not in anims:
            continue
        box = []
        n = int(round(1.0 / HURT_STEP))
        for i in range(n + 1):
            u = i / n
            x0, y0, x1, y1 = body_box(bones, pose_at(bones, anims[an], u), parts, rest)
            box += [round(u, 4), round(x0, 1), round(y0, 1), round(x1, 1), round(y1, 1)]
        out[an] = {"len": round(anims[an]["length"], 4), "box": box}
    return out


def _set_meta(text, key, value):
    line = "metadata/%s = %s" % (key, _fmt(value))
    text = re.sub(r"\nmetadata/%s = [^\n]*" % key, "", text)
    m = re.search(r'(\[node name="Rig_[^"]*" type="Node2D"\]\n(?:metadata/[^\n]*\n)*)', text)
    return text[:m.end()] + line + "\n" + text[m.end():]


def write_meta(text, hb, hurt=None):
    text = _set_meta(text, "hitboxes", hb)
    if hurt is not None:
        text = _set_meta(text, "hurtboxes", hurt)
    return text


def main():
    files = sorted(RIGS.glob("*.tscn")) + sorted((RIGS / "enemies").glob("*.tscn"))
    only_check = "--check" in sys.argv
    late = []
    for fp in files:
        text = fp.read_text(encoding="utf-8")
        hb = rig_hitboxes(text)
        for an, d in hb.items():
            for k0, k1 in (("on", "off"), ("won", "woff")):
                if k0 in d and an not in OPEN_ENDED and not (U_HIT - 0.04 <= d[k0] <= U_HOLD and d[k1] >= U_HIT):
                    late.append("%s/%s %s=%.3f %s=%.3f" % (fp.stem, an, k0, d[k0], k1, d[k1]))
        late += gameplay_check(fp.stem, hb) + special_check(fp.stem, hb) + projectile_check(fp.stem, hb, fp.parent == RIGS) + crate_check(fp.stem, hb)
        if not only_check:
            fp.write_text(write_meta(text, hb, rig_hurtboxes(text)), encoding="utf-8")  # hurtbox animada: todos
        summary = "  ".join("%s:%s %.2f-%.2f" % (an, d["bone"].replace("arm_", "").replace("_lo", ""), d["on"], d["off"])
                            for an, d in hb.items())
        print("%-28s %s" % (fp.relative_to(ROOT), summary))
    players_hb = {fp.stem: rig_hitboxes(fp.read_text(encoding="utf-8")) for fp in sorted(RIGS.glob("*.tscn"))}
    enemy_hb, enemy_hurt = {}, {}
    for fp in sorted((RIGS / "enemies").glob("*.tscn")):
        text = fp.read_text(encoding="utf-8")
        enemy_hb[fp.stem], enemy_hurt[fp.stem] = rig_hitboxes(text), rig_hurtboxes(text)
        late += enemy_hurt_check(players_hb, fp.stem, enemy_hurt[fp.stem])
    players_hurt = {fp.stem: rig_hurtboxes(fp.read_text(encoding="utf-8")) for fp in sorted(RIGS.glob("*.tscn"))}
    late += player_hurt_check(enemy_hb, players_hurt, enemy_hurt)
    print("%d rigs. Problemas (janela fora da linha do tempo do jogo ou golpe que não acerta mais): %d" % (len(files), len(late)))
    for s in late:
        print("  ", s)
    if late and only_check:
        sys.exit(1)


if __name__ == "__main__":
    main()
