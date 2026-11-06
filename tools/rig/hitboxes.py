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
    return d


HURT_H, HURT_W = 100.0, 16.0  # hurtbox do corpo (fighter.gd)
GAME_WINDOW = {"jumpkick": (0.0, 1.0)}  # no ar o jogo vai de 0 a 1 em 0,16 s e fica no fim


def _interp(arr, stride, u):
    n = len(arr) // stride
    f = min(max(u, 0.0), 1.0) * (n - 1)
    i = min(int(f), n - 2)
    k = f - i
    return [arr[i * stride + j] + (arr[(i + 1) * stride + j] - arr[i * stride + j]) * k for j in range(1, stride)]


def simulate(d, u, reach, wlen=None, scale=1.0, height=0.0, rot=0.0, both=False):
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
    h = height - y * scale
    return (-far if both else -15.0, far, h - r * scale, h + r * scale)


def hits(box, dx, tg_h=0.0, tg_s=1.0):
    return (box is not None and dx + HURT_W * tg_s >= box[0] and dx - HURT_W * tg_s <= box[1]
            and box[3] >= tg_h and box[2] <= tg_h + HURT_H * tg_s)


def gameplay_check(name, hb):
    """Todo golpe do jogo, nesta animação, ainda acerta um alvo parado no chão a 90% do alcance
    em algum quadro da janela de acerto (como a caixa antiga acertava)."""
    bad = []
    cases = [("jab", 58, None), ("cross", 62, None), ("kick", 74, None), ("upper", 56, None), ("slam", 64, None),
             ("charge", 56, None), ("swing", 82, 22.0), ("swing", 88, 44.0), ("slam", 86, 30.0), ("jumpkick", 66, None)]
    for an, reach, wlen in cases:
        if an not in hb:
            continue
        lo, hi = GAME_WINDOW.get(an, (U_HIT, U_HOLD))
        height = 40.0 if an == "jumpkick" else 0.0
        us = [lo + (hi - lo) * i / 24.0 for i in range(25)]
        if not any(hits(simulate(hb[an], u, reach, wlen, 1.0, height), reach * 0.9) for u in us):
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


def write_meta(text, hb):
    line = "metadata/hitboxes = " + _fmt(hb)
    text = re.sub(r"\nmetadata/hitboxes = [^\n]*", "", text)
    m = re.search(r'(\[node name="Rig_[^"]*" type="Node2D"\]\n(?:metadata/[^\n]*\n)*)', text)
    return text[:m.end()] + line + "\n" + text[m.end():]


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
        late += gameplay_check(fp.stem, hb) + special_check(fp.stem, hb)
        if not only_check:
            fp.write_text(write_meta(text, hb), encoding="utf-8")
        summary = "  ".join("%s:%s %.2f-%.2f" % (an, d["bone"].replace("arm_", "").replace("_lo", ""), d["on"], d["off"])
                            for an, d in hb.items())
        print("%-28s %s" % (fp.relative_to(ROOT), summary))
    print("%d rigs. Problemas (janela fora da linha do tempo do jogo ou golpe que não acerta mais): %d" % (len(files), len(late)))
    for s in late:
        print("  ", s)
    if late and only_check:
        sys.exit(1)


if __name__ == "__main__":
    main()
