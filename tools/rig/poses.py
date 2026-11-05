"""Poses dos lutadores, portadas de scripts/fighter.gd (_draw_body e _weapon_angle).

Coordenadas do jogo: pixels, origem nos pés, x para a frente, y para BAIXO.
Cada pose devolve onde ficam o quadril, o ombro, a cabeça, as mãos e os pés;
o rig do Blender usa as mãos/pés como alvos de IK.
"""
import math

# Proporções do rig (pixels)
HIP_Y = -36.0
SHOULDER_Y = -68.0
UPPER_ARM = 22.0
FOREARM = 22.0
THIGH = 21.0
SHIN = 21.0


def _lerp(a, b, t):
    return a + (b - a) * t


def pose(name: str, p: float = 0.0, t: float = 0.0) -> dict:
    """p = fase do golpe (-1 preparação, 0 neutro, 1 golpe); t = tempo da animação (idle/walk)."""
    bob = 0.0
    bf = [-7.0, 0.0]
    ff = [9.0, 0.0]
    hip = [0.0, HIP_Y]
    lean = 0.0
    hb = [8.0, -60.0]
    hf = [18.0, -64.0]
    head_off = [0.0, 0.0]

    if name == "idle":
        bob = math.sin(t * 4.0) * 1.5
    elif name == "walk":
        w = math.sin(t * 12.0)
        bf = [-7.0 + w * 10.0, -max(0.0, w) * 4.0]
        ff = [9.0 - w * 10.0, -max(0.0, -w) * 4.0]
        bob = abs(w) * 2.0
    elif name == "jab":
        hf = [18.0 + (p * 30.0 if p > 0 else p * 14.0), -66.0]
        lean = 3.0 * p
    elif name == "cross":
        hb = [8.0 + (p * 40.0 if p > 0 else p * 16.0), -64.0]
        hf = [12.0, -60.0]
        lean = 6.0 * max(p, 0.0)
        bf[0] -= 4.0
    elif name == "upper":
        hf = [20.0 + max(p, 0.0) * 10.0, -64.0 - max(p, 0.0) * 38.0]
        if p < 0:
            hf = [14.0, -48.0]
        lean = 5.0 * p
    elif name == "swing":
        if p < 0:
            hf = [-6.0, -84.0]
            hb = [-2.0, -70.0]
            lean = -5.0
        else:
            hf = [_lerp(0.0, 30.0, p), _lerp(-76.0, -60.0, p)]
            hb = [_lerp(-2.0, 22.0, p), -62.0]
            lean = 7.0 * p
            bf[0] -= 5.0 * p
    elif name == "dive":
        hf = [6.0, -96.0]
        hb = [-2.0, -94.0]
        bf = [-6.0, 4.0]
        ff = [6.0, 4.0]
    elif name == "throw":
        hf = [34.0, -72.0]
        hb = [-12.0, -64.0]
        lean = 8.0
    elif name == "kick":
        k = max(p, 0.0)
        ff = [9.0 + k * 44.0, -k * 44.0]
        lean = -9.0 * k
        hf = [10.0, -66.0]
        hb = [-6.0, -62.0]
    elif name == "jumpkick":
        ff = [44.0, -24.0]
        bf = [-12.0, -18.0]
        hip[1] = -40.0
        lean = -7.0
        hf = [4.0, -70.0]
        hb = [-14.0, -66.0]
    elif name == "jump":
        bf = [-10.0, -12.0]
        ff = [12.0, -16.0]
        hf = [16.0, -78.0]
        hb = [-6.0, -74.0]
    elif name == "special":
        hf = [44.0, -70.0]
        hb = [-44.0, -70.0]
        bf = [-14.0, 0.0]
        ff = [14.0, 0.0]
    elif name == "slam":
        if p < 0:
            hf = [4.0, -100.0]
            hb = [-4.0, -98.0]
            lean = -6.0
        else:
            hf = [40.0, -40.0]
            hb = [34.0, -38.0]
            lean = 10.0 * p
    elif name == "charge":
        lean = 12.0 * max(p, 0.0)
        hf = [26.0, -66.0]
        hb = [20.0, -60.0]
        if p < 0:
            lean = -6.0
    elif name == "hurt":
        lean = -10.0
        head_off = [-4.0, 2.0]
        hf = [-4.0, -80.0]
        hb = [-16.0, -72.0]
        bf[0] -= 4.0
    elif name == "down":
        hf = [6.0, -46.0]
        hb = [-4.0, -44.0]

    hip[1] += bob * 0.5
    shoulder = [lean, SHOULDER_Y + bob]
    head = [shoulder[0] + 3.0 + head_off[0], shoulder[1] - 15.0 + head_off[1]]
    return {"hip": hip, "shoulder": shoulder, "head": head, "hf": hf, "hb": hb, "ff": ff, "bf": bf,
            "weapon": weapon_angle(name, p)}


def weapon_angle(name: str, p: float) -> float:
    """Ângulo da arma (radianos, coordenadas do jogo: positivo = para baixo)."""
    if name == "swing":
        if p < 0:
            return _lerp(-1.2, -2.5, -p)
        if p >= 1.0:
            return 0.35
        return _lerp(-0.9, 0.35, p)
    return {"hurt": -2.1, "down": -0.2, "throw": -0.4, "jumpkick": -1.6, "kick": -1.6}.get(name, -1.05)


# ---------------------------------------------------------------------------
# Animações geradas para o rig
#   loop:  amostras ao longo de um ciclo (o jogo toca em loop pelo tempo)
#   phase: o tempo da animação (0..1) representa a fase do golpe p = -1..1
#   still: pose parada
IDLE_LEN = 2.0 * math.pi / 4.0
WALK_LEN = 2.0 * math.pi / 12.0

ANIMATIONS = {
    "idle": {"kind": "loop", "length": IDLE_LEN, "samples": 12},
    "walk": {"kind": "loop", "length": WALK_LEN, "samples": 12},
    "jab": {"kind": "phase"}, "cross": {"kind": "phase"}, "upper": {"kind": "phase"},
    "kick": {"kind": "phase"}, "swing": {"kind": "phase"}, "slam": {"kind": "phase"},
    "charge": {"kind": "phase"},
    "jump": {"kind": "still"}, "jumpkick": {"kind": "still"}, "special": {"kind": "still"},
    "throw": {"kind": "still"}, "dive": {"kind": "still"}, "hurt": {"kind": "still"},
    "down": {"kind": "still"},
}

# fases amostradas nas animações "phase" (mudanças bruscas em p=0 ficam bem marcadas)
PHASES = [-1.0, -0.5, -0.02, 0.0, 0.25, 0.5, 0.75, 1.0]


def samples(anim: str):
    """Lista de (tempo_da_animação, pose) para uma animação."""
    a = ANIMATIONS[anim]
    if a["kind"] == "loop":
        n = a["samples"]
        return [(a["length"] * i / n, pose(anim, 0.0, a["length"] * i / n)) for i in range(n + 1)]
    if a["kind"] == "phase":
        return [((ph + 1.0) / 2.0, pose(anim, ph)) for ph in PHASES]
    return [(0.0, pose(anim, 0.0))]


def anim_length(anim: str) -> float:
    a = ANIMATIONS[anim]
    if a["kind"] == "loop":
        return a["length"]
    if a["kind"] == "phase":
        return 1.0
    return 0.05
