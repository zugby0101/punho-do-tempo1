"""Resolve as poses-chave de moves.py em trilhas de ossos do Godot, sem o Blender.

Faz o mesmo que blender_rig.py + o Blender fazem para uma Action:
  1. interpola os CONTROLES entre as poses-chave com a curva de cada trecho (as mesmas fórmulas de
     interpolação do Blender: SINE, QUAD, CUBIC, EXPO, BACK, CONSTANT, LINEAR...): quadril, giro do
     tronco, giro da cabeça, ângulo da arma e alvos de IK das mãos e dos pés;
  2. resolve o IK de 2 ossos de braços e pernas no plano, dobrando para o lado do alvo de polo
     (cotovelos para baixo, presos ao tronco; joelhos para a frente, presos ao quadril);
  3. converte para a pose local de cada Bone2D (posição e rotação relativas ao pai), como
     blender_rig.export_frame.

`validate()` confere o resolvedor contra animações que o Blender já gerou (rigs/*.tscn).
Coordenadas do jogo: pixels, origem nos pés, x para a frente, y para BAIXO.
"""
import math

import hitboxes as HB

FRAMES_U = 60  # golpes e estados: u = 0..1 em 60 quadros (blender_rig.FRAMES_U)


# ---------------------------------------------------------------------------
# Curvas de interpolação do Blender (BLI_easing.c), com t, b=0, c=1, d=1


def _ease(interp, easing, t, back=1.70158):
    if interp == "CONSTANT":
        return 0.0
    if interp in ("LINEAR", "BEZIER"):
        return t
    e = easing if easing not in ("AUTO", None) else ("EASE_OUT" if interp in ("BACK", "BOUNCE", "ELASTIC") else "EASE_IN")

    def f_in(x):
        if interp == "SINE":
            return 1.0 - math.cos(x * math.pi / 2.0)
        if interp == "QUAD":
            return x * x
        if interp == "CUBIC":
            return x ** 3
        if interp == "QUART":
            return x ** 4
        if interp == "QUINT":
            return x ** 5
        if interp == "EXPO":
            return 0.0 if x == 0.0 else 2.0 ** (10.0 * (x - 1.0)) - 0.001
        if interp == "CIRC":
            return 1.0 - math.sqrt(max(0.0, 1.0 - x * x))
        if interp == "BACK":
            return x * x * ((back + 1.0) * x - back)
        return x

    def f_out(x):
        if interp == "EXPO":
            return 1.0 if x == 1.0 else 1.001 * (1.0 - 2.0 ** (-10.0 * x))
        if interp == "BACK":
            y = x - 1.0
            return y * y * ((back + 1.0) * y + back) + 1.0
        return 1.0 - f_in(1.0 - x)

    if e == "EASE_IN":
        return f_in(t)
    if e == "EASE_OUT":
        return f_out(t)
    # EASE_IN_OUT
    if interp == "BACK":
        s = back * 1.525
        x = t * 2.0
        if x < 1.0:
            return 0.5 * (x * x * ((s + 1.0) * x - s))
        x -= 2.0
        return 0.5 * (x * x * ((s + 1.0) * x + s) + 2.0)
    if interp == "EXPO":
        if t == 0.0 or t == 1.0:
            return t
        return 0.5 * 2.0 ** (10.0 * (2.0 * t - 1.0)) if t < 0.5 else 0.5 * (2.0 - 2.0 ** (-10.0 * (2.0 * t - 1.0)))
    return 0.5 * f_in(2.0 * t) if t < 0.5 else 1.0 - 0.5 * f_in(2.0 * (1.0 - t))


# ---------------------------------------------------------------------------
# Rig: repouso tirado da própria cena do Godot


def _apply(t, p):
    x, y, a = t
    return (x + p[0] * math.cos(a) - p[1] * math.sin(a), y + p[0] * math.sin(a) + p[1] * math.cos(a))


def _inv_apply(t, p):
    x, y, a = t
    dx, dy = p[0] - x, p[1] - y
    return (dx * math.cos(-a) - dy * math.sin(-a), dx * math.sin(-a) + dy * math.cos(-a))


class Rig:
    def __init__(self, text):
        self.bones, self.anims = HB.parse_scene(text)
        self.rest = HB.pose_at(self.bones, {"length": 1.0, "tracks": {}}, 0.0)
        g = lambda n: self.rest[n][:2]
        tip = lambda n: HB.tip(self.bones, self.rest, n)
        self.j = {"hip": g("pelvis"), "shoulder": tip("spine"), "head": tip("head"),
                  "sh_b": g("arm_b_up"), "sh_f": g("arm_f_up"), "hip_b": g("leg_b_up"), "hip_f": g("leg_f_up"),
                  "hb": tip("arm_b_lo"), "hf": tip("arm_f_lo"), "bf": tip("leg_b_lo"), "ff": tip("leg_f_lo")}
        j = self.j
        # alvos de polo em repouso (blender_rig.bone_specs) e onde ficam presos (pai)
        self.poles = {"arm_b": ((j["sh_b"][0] - 4, j["sh_b"][1] + 46), "spine"),
                      "arm_f": ((j["sh_f"][0] - 4, j["sh_f"][1] + 46), "spine"),
                      "leg_b": ((j["hip_b"][0] + 44, j["hip_b"][1] + 16), "pelvis"),
                      "leg_f": ((j["hip_f"][0] + 44, j["hip_f"][1] + 16), "pelvis")}
        self.weapon_rest = self.rest["weapon"][2]

    def controls(self, ps):
        """Controles do animador para uma pose de moves.py (o que blender_rig.key_pose anima)."""
        j = self.j
        sv = (ps["shoulder"][0] - ps["hip"][0], ps["shoulder"][1] - ps["hip"][1])
        rv = (j["shoulder"][0] - j["hip"][0], j["shoulder"][1] - j["hip"][1])
        spine = math.atan2(sv[1], sv[0]) - math.atan2(rv[1], rv[0])
        hv = (ps["head"][0] - ps["shoulder"][0], ps["head"][1] - ps["shoulder"][1])
        hr = (j["head"][0] - j["shoulder"][0], j["head"][1] - j["shoulder"][1])
        head = math.atan2(hv[1], hv[0]) - math.atan2(hr[1], hr[0]) - spine
        return {"hip": tuple(ps["hip"]), "spine": spine, "head": head, "weapon": ps["weapon"],
                "hf": tuple(ps["hf"]), "hb": tuple(ps["hb"]), "ff": tuple(ps["ff"]), "bf": tuple(ps["bf"])}

    def solve(self, c):
        """Pose global (x, y, ângulo) de cada osso a partir dos controles."""
        B, R, j = self.bones, self.rest, self.j
        G = {"root": R["root"]}
        G["pelvis"] = (c["hip"][0], c["hip"][1], R["pelvis"][2])
        sa = R["spine"][2] + c["spine"]
        G["spine"] = (c["hip"][0], c["hip"][1], sa)
        sh = _apply(G["spine"], (B["head"]["pos"][0], B["head"]["pos"][1]))
        G["head"] = (sh[0], sh[1], sa + B["head"]["rot"] + c["head"])

        def attach(child, parent):  # posição de repouso do filho no referencial do pai
            return _apply(G[parent], _inv_apply(R[parent], R[child][:2]))

        for side, up, lo, tgt, parent in (("arm_b", "arm_b_up", "arm_b_lo", "hb", "spine"),
                                          ("arm_f", "arm_f_up", "arm_f_lo", "hf", "spine"),
                                          ("leg_b", "leg_b_up", "leg_b_lo", "bf", "pelvis"),
                                          ("leg_f", "leg_f_up", "leg_f_lo", "ff", "pelvis")):
            a = attach(up, parent)
            pole_rest, pole_par = self.poles[side]
            pole = _apply(G[pole_par], _inv_apply(R[pole_par], pole_rest))
            l1, l2 = B[up]["len"], B[lo]["len"]
            t = c[tgt]
            dx, dy = t[0] - a[0], t[1] - a[1]
            d = math.hypot(dx, dy)
            base = math.atan2(dy, dx)
            if d >= l1 + l2 - 1e-6:
                a1 = base
                elbow = (a[0] + math.cos(a1) * l1, a[1] + math.sin(a1) * l1)
                a2 = base
            else:
                d = max(d, 1e-6)
                cos_a = max(-1.0, min(1.0, (l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d)))
                off = math.acos(cos_a)
                # lado do polo: sinal do produto vetorial (alvo - ombro) x (polo - ombro)
                side_sign = (dx * (pole[1] - a[1]) - dy * (pole[0] - a[0]))
                a1 = base + (off if side_sign > 0 else -off)
                elbow = (a[0] + math.cos(a1) * l1, a[1] + math.sin(a1) * l1)
                a2 = math.atan2(t[1] - elbow[1], t[0] - elbow[0])
            G[up] = (a[0], a[1], a1)
            G[lo] = (elbow[0], elbow[1], a2)
        hf_tip = _apply(G["arm_f_lo"], (B["arm_f_lo"]["len"], 0.0))
        G["weapon"] = (hf_tip[0], hf_tip[1], c["weapon"])  # não herda rotação: ângulo absoluto
        for foot, lo in (("foot_b", "leg_b_lo"), ("foot_f", "leg_f_lo")):
            p = _apply(G[lo], (B[lo]["len"], 0.0))
            G[foot] = (p[0], p[1], R[foot][2])  # pés não herdam rotação: ficam retos
        return G

    def local(self, G):
        """Pose global -> posição/rotação locais de cada Bone2D (blender_rig.export_frame)."""
        out = {}
        for n, b in self.bones.items():
            if n not in G:
                continue
            if b["parent"] is None or b["parent"] not in G:
                pos, rot = G[n][:2], G[n][2]
            else:
                pos = _inv_apply(G[b["parent"]], G[n][:2])
                rot = G[n][2] - G[b["parent"]][2]
            rot = (rot + math.pi) % (2.0 * math.pi) - math.pi
            out[n] = (pos, rot)
        return out


def _lerp_controls(a, b, k):
    out = {}
    for key, va in a.items():
        vb = b[key]
        if isinstance(va, tuple):
            out[key] = (va[0] + (vb[0] - va[0]) * k, va[1] + (vb[1] - va[1]) * k)
        else:
            out[key] = va + (vb - va) * k
    return out


def sample_move(rig, mv):
    """[(t em segundos, {osso: (pos, rot)})] a 60 quadros por u (golpes/estados) ou por segundo (loops)."""
    keys = mv["keys"]
    ctr = [rig.controls(k["pose"]) for k in keys]
    if mv["loop"]:
        frames = [f / 60.0 for f in range(0, round(mv["length"] * 60) + 1)]
        tk = [round(k["t"] * 60) / 60.0 for k in keys]
    else:
        frames = [f / FRAMES_U for f in range(0, FRAMES_U + 1)]
        tk = [round(k["t"] * FRAMES_U) / FRAMES_U for k in keys]
    out = []
    for t in frames:
        i = 0
        while i < len(keys) - 2 and t >= tk[i + 1]:
            i += 1
        k0 = keys[i]
        span = max(tk[i + 1] - tk[i], 1e-9)
        x = min(max((t - tk[i]) / span, 0.0), 1.0)
        e = _ease(k0["interp"], k0.get("easing"), x, k0.get("back", 1.70158))
        if t >= tk[-1]:
            c = ctr[-1]
        else:
            c = _lerp_controls(ctr[i], ctr[i + 1], e)
        out.append((t * (mv["length"] if not mv["loop"] else 1.0), rig.local(rig.solve(c))))
    return out


def validate(text, anim, mv):
    """Erro máximo (rad, px) do resolvedor contra a animação que o Blender gerou nesta cena."""
    rig = Rig(text)
    got = sample_move(rig, mv)
    ref = rig.anims[anim]
    worst_r, worst_p, where = 0.0, 0.0, ""
    for t, frame in got:
        u = t / ref["length"]
        for n, (pos, rot) in frame.items():
            tr = ref["tracks"]
            if (n, "rotation") in tr:
                # nos cortes instantâneos (rig_to_godot.snap_jumps) o tempo exato cai no meio do corte:
                # compara também um pouquinho antes e depois e fica com o menor erro
                e = min(abs((rot - HB._sample(tr[(n, "rotation")], u * ref["length"] + dt) + math.pi) % (2 * math.pi) - math.pi)
                        for dt in (0.0, -0.0006, 0.0006))
                if e > worst_r:
                    worst_r, where = e, "%s rot u=%.2f" % (n, u)
            if (n, "position") in tr:
                p = HB._sample(tr[(n, "position")], u * ref["length"])
                e = math.hypot(pos[0] - p[0], pos[1] - p[1])
                worst_p = max(worst_p, e)
    return worst_r, worst_p, where
