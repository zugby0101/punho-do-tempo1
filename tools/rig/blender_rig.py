"""Monta no Blender os rigs 2D dos 14 lutadores e exporta os dados para o Godot.

Rode com o Blender (qualquer um dos dois jeitos):
    blender --background --python tools/rig/blender_rig.py
    python tools/rig/blender_rig.py          # com o módulo "bpy" instalado (pip install bpy)

Para cada personagem cria:
  - uma Armature 2D (plano XZ, vista frontal) com ossos de corpo, braços, pernas, pés e arma;
  - controles de IK para mãos e pés, com alvos de polo para cotovelos e joelhos;
  - as peças do corpo (malhas planas coloridas) presas aos ossos;
  - uma Action por animação, animando os CONTROLES (como um animador faria).
Depois avalia cada Action quadro a quadro (o Blender resolve o IK) e grava:
  art/rigs/punho_rigs.blend          o arquivo do Blender, editável
  art/rigs/json/<personagem>.json    ossos, peças e animações já resolvidas
  art/rigs/preview.png               prévia renderizada (Cycles)
"""
import json
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import chars as chars_mod  # noqa: E402
import looks as looks_mod  # noqa: E402
import poses as P  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "art" / "rigs"
FPS = 60
PX = 0.01  # 1 pixel do jogo = 0,01 unidade do Blender

# ---------------------------------------------------------------------------
# Conversões: jogo (x frente, y para baixo, pixels) <-> Blender (X frente, Z cima)


def g2b(x, y):
    return Vector((x * PX, 0.0, -y * PX))


def b2g(v):
    return [round(v.x / PX, 3), round(-v.z / PX, 3)]


def ang_b(vx, vy):
    """Ângulo, no plano XZ do Blender, de um vetor dado em coordenadas do jogo."""
    return math.atan2(-vy, vx)


def two_bone(a, b, l1, l2, bend_sign):
    """IK analítico de 2 ossos (só para a pose de repouso). Retorna o cotovelo/joelho."""
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    d = max(1e-4, min(math.hypot(dx, dy), l1 + l2 - 1e-3))
    cos_a = (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)
    base = math.atan2(dy, dx)
    ang = base + bend_sign * math.acos(max(-1.0, min(1.0, cos_a)))
    return (ax + math.cos(ang) * l1, ay + math.sin(ang) * l1)


# ---------------------------------------------------------------------------
# Cores (mesmas regras do jogo: Color.darkened)


def darken(c, amt):
    return (c[0] * (1 - amt), c[1] * (1 - amt), c[2] * (1 - amt), c[3])


# ---------------------------------------------------------------------------
# Geometria das peças (coordenadas do jogo, pose de repouso)


def circle(cx, cy, r, n=18):
    return [(cx + math.cos(i * 2 * math.pi / n) * r, cy + math.sin(i * 2 * math.pi / n) * r) for i in range(n)]


def dome(cx, cy, r, a0=math.pi, a1=2 * math.pi, n=12):
    return [(cx + math.cos(a0 + (a1 - a0) * i / n) * r, cy + math.sin(a0 + (a1 - a0) * i / n) * r) for i in range(n + 1)]


def rect(x, y, w, h):
    return [(x, y), (x + w, y), (x + w, y + h), (x, y + h)]


def capsule(a, b, w, n=6):
    """Segmento grosso com pontas arredondadas (membros)."""
    ax, ay = a
    bx, by = b
    ang = math.atan2(by - ay, bx - ax)
    r = w / 2
    pts = []
    for i in range(n + 1):  # ponta B
        t = ang - math.pi / 2 + math.pi * i / n
        pts.append((bx + math.cos(t) * r, by + math.sin(t) * r))
    for i in range(n + 1):  # ponta A
        t = ang + math.pi / 2 + math.pi * i / n
        pts.append((ax + math.cos(t) * r, ay + math.sin(t) * r))
    return pts


def line(a, b, w):
    return capsule(a, b, w, 3)


def dots_ring(cx, cy, r, n, rad, col, trail=False):
    """Anel de pontos. Com trail=True os pontos crescem em tamanho e brilho ao longo do anel
    (rastro de cometa), para que o giro animado fique visível."""
    out = []
    for i in range(n):
        k = (i + 1) / n if trail else 1.0
        c = (col[0], col[1], col[2], col[3] * (0.25 + 0.75 * k)) if trail else col
        out.append((circle(cx + math.cos(i * 2 * math.pi / n) * r, cy + math.sin(i * 2 * math.pi / n) * r, rad * (0.55 + 0.6 * k), 6), c))
    return out


def hair_parts(style, head, hair, skin, f, shirt=(0.5, 0.5, 0.5, 1)):
    """Penteados/acessórios dos lutadores (versão em polígonos do _draw_hat do jogo).
    Retorna (peças atrás da cabeça, peças na frente). Cada peça: (polígono, cor)."""
    hx, hy = head
    back, front = [], []
    if style == "ponytail":
        back.append((capsule((hx - 8, hy - 4), (hx - 15, hy + 15), 6.0), hair, "tail"))
        front.append((dome(hx, hy - 1, 10.5, math.pi * 0.9, 2 * math.pi), hair))
        front.append((rect(hx + 3, hy - 10, 8, 4), hair))
    elif style == "longhair":
        back.append((rect(hx - 11, hy - 4, 12, 26), hair, "hair_long"))
        front.append((dome(hx, hy - 1, 10.5, math.pi * 0.9, 2 * math.pi), hair))
        front.append((rect(hx + 3, hy - 10, 8, 4), hair))
    elif style == "braidcrown":
        back.append((capsule((hx - 8, hy), (hx - 10, hy + 22), 5.0), hair, "braid"))
        front.append((dome(hx, hy - 1, 10.0), hair))
        for i in range(5):
            front.append((circle(hx - 9 + i * 4.5, hy - 9 + abs(i - 2) * 1.5, 3.2, 10), darken(hair, -0.15)))
        front.append((circle(hx + 6, hy - 10, 2.5, 8), (0.9, 0.2, 0.3, 1)))
    elif style == "short":
        front.append((dome(hx, hy - 2, 10.0), hair))
        front.append((rect(hx + 2, hy - 10, 9, 4), hair))
    elif style == "buzz":
        front.append((dome(hx, hy - 1, 10.0, math.pi * 1.05, 2 * math.pi - 0.1), (hair[0], hair[1], hair[2], 0.75)))
    elif style == "curly":
        for i in range(6):
            a = math.pi + i * math.pi / 5
            front.append((circle(hx + math.cos(a) * 9, hy - 1 + math.sin(a) * 9, 4.5, 10), hair))
    elif style == "bob":
        front.append((dome(hx, hy - 1, 11.5, math.pi * 0.75, 2 * math.pi + 0.1), hair))
        front.append((rect(hx - 11, hy - 2, 6, 12), hair))
        front.append((rect(hx + 2, hy - 11, 10, 5), hair))
    elif style == "buns":
        front.append((dome(hx, hy - 1, 10.0), hair))
        front.append((circle(hx - 8, hy - 10, 5.5, 12), hair))
        front.append((circle(hx + 7, hy - 11, 5.5, 12), hair))
    elif style == "headwrap":
        wrap = (0.95, 0.6, 0.1, 1)
        front.append((dome(hx - 1, hy - 4, 12.0, math.pi * 0.95, 2 * math.pi + 0.05), wrap))
        front.append((circle(hx - 2, hy - 14, 7.0, 12), wrap))
        front.append((capsule((hx - 10, hy - 6), (hx + 8, hy - 9), 3.0, 3), (0.1, 0.5, 0.3, 1)))
    elif style == "luchamask":
        mask = (0.95, 0.15, 0.5, 1)
        back.append((capsule((hx - 8, hy - 2), (hx - 14, hy + 18), 5.0), hair, "braid"))
        front.append((circle(hx + 1, hy + 1, 10.5), mask))
        front.append((circle(hx + 5, hy - 1, 3.5, 10), (0.98, 0.98, 0.98, 1)))
        front.append((rect(hx + 5, hy - 2, 2, 2), (0.05, 0.05, 0.05, 1)))
        front.append((capsule((hx - 8, hy - 6), (hx + 8, hy - 8), 2.5, 3), (0.95, 0.85, 0.2, 1)))
    elif style == "topknot":
        front.append((rect(hx - 9, hy - 9, 16, 4), hair))
        front.append((circle(hx - 2, hy - 13, 4.0, 10), hair))
    elif style == "band":
        red = (0.95, 0.1, 0.15, 1)
        front.append((capsule((hx - 9, hy - 4), (hx + 9, hy - 5), 3.5, 3), red))
        front.append((capsule((hx - 9, hy - 4), (hx - 18, hy + 2), 2.5, 3), red, "band_tail"))
    # ----- inimigos, sub-chefes e chefes (porte de _draw_hat em fighter.gd) -----
    H = lambda dx, dy: (hx + dx, hy + dy)  # noqa: E731
    dark = (0.05, 0.05, 0.05, 1)
    if style == "mohawk":
        for i in range(4):
            front.append((line(H(-6 + i * 4, -8), H(-7 + i * 4, -17), 3.0), (0.2, 0.9, 0.3, 1)))
    elif style == "cap":
        c = (0.2, 0.2, 0.25, 1)
        front.append((rect(hx - 10, hy - 11, 20, 7), c))
        front.append((rect(hx + 6, hy - 6, 9, 3), c))
    elif style == "bald":
        front.append((rect(hx - 2, hy + 4, 9, 3), (0.3, 0.2, 0.1, 1)))
    elif style == "wild":
        for i in range(6):
            a = math.pi + i * math.pi / 5
            front.append((circle(hx + math.cos(a) * 9 - 2, hy + math.sin(a) * 9, 5.0, 10), hair))
        front.append((circle(hx + 3, hy + 8, 6.0, 12), hair))  # barba
    elif style == "horns":
        bone = (0.92, 0.88, 0.75, 1)
        front.append((line(H(-6, -7), H(-12, -20), 4.0), bone))
        front.append((line(H(5, -8), H(9, -21), 4.0), bone))
    elif style in ("helmet", "helmet2"):
        steel = (0.62, 0.64, 0.68, 1) if style == "helmet" else (0.32, 0.36, 0.28, 1)
        front.append((dome(hx, hy - 2, 11.5), steel))
        front.append((rect(hx - 12, hy - 3, 24, 3), darken(steel, 0.2)))
        if style == "helmet":
            front.append((line(H(6, -2), H(6, 6), 2.5), steel))
    elif style == "greathelm":
        front.append((rect(hx - 11, hy - 12, 22, 22), (0.2, 0.2, 0.24, 1)))
        front.append((rect(hx, hy - 3, 11, 3), (0.9, 0.2, 0.1, 1)))
        front.append((line(H(-2, -12), H(-8, -24), 4.0), (0.8, 0.1, 0.1, 1)))
    elif style == "hood":
        hc = darken(shirt, 0.2)
        front.append((dome(hx - 1, hy, 12.0, math.pi * 0.75, 2 * math.pi + 0.1), hc))
        front.append((line(H(-10, 0), H(-12, 12), 5.0), hc))
    elif style == "ninja":
        nc = (0.1, 0.1, 0.12, 1)
        front.append((circle(hx + 1, hy + 1, 10.5), nc))
        front.append((rect(hx - 1, hy - 3, 10, 4), skin))
        front.append((rect(hx + 4, hy - 2, 3, 2), dark))
        front.append((line(H(-9, -4), H(-17, 0), 3.0), nc, "ninja_tail"))
    elif style == "kabuto":
        kc = (0.45, 0.06, 0.08, 1)
        gold = (1, 0.8, 0.2, 1)
        front.append((dome(hx, hy - 2, 12.0), kc))
        front.append((rect(hx - 14, hy - 3, 28, 4), darken(kc, 0.3)))
        front.append((line(H(0, -10), H(-8, -24), 3.0), gold))
        front.append((line(H(0, -10), H(10, -24), 3.0), gold))
    elif style == "bandana":
        bc = darken(shirt, 0.1) if max(shirt[:3]) < 0.8 else (0.8, 0.15, 0.15, 1)
        front.append((dome(hx, hy - 1, 10.5), bc))
        front.append((line(H(-9, -3), H(-15, 4), 3.0), bc))
    elif style == "tricorn":
        front.append(([H(-17, -5), H(17, -5), H(8, -20), H(-8, -20)], (0.08, 0.08, 0.1, 1)))
        front.append((line(H(-17, -5), H(17, -5), 2.0), (0.9, 0.75, 0.2, 1)))
        front.append((circle(hx, hy - 13, 3.0, 10), (0.95, 0.95, 0.95, 1)))
    elif style == "flatcap":
        fc = (0.35, 0.3, 0.26, 1)
        front.append((dome(hx, hy - 3, 10.5), fc))
        front.append((rect(hx + 4, hy - 5, 11, 3), darken(fc, 0.2)))
    elif style == "tophat":
        hc = (0.06, 0.06, 0.08, 1)
        front.append((rect(hx - 8, hy - 30, 16, 22), hc))
        front.append((rect(hx - 14, hy - 10, 28, 4), hc))
        front.append((rect(hx - 8, hy - 14, 16, 3), (0.6, 0.1, 0.1, 1)))
        front.append((circle(hx + 5, hy - 1, 4.0, 12), (0.9, 0.8, 0.3, 0.55)))  # monóculo
    elif style == "brodie":
        bc = (0.35, 0.38, 0.28, 1)
        front.append((dome(hx, hy - 4, 9.5), bc))
        front.append((rect(hx - 15, hy - 5, 30, 3), bc))
    elif style == "spike":
        sc = (0.15, 0.15, 0.16, 1)
        front.append((dome(hx, hy - 2, 11.0), sc))
        front.append((rect(hx - 11, hy - 3, 24, 3), sc))
        front.append((line(H(0, -12), H(0, -22), 3.0), (0.75, 0.7, 0.4, 1)))
    elif style == "officer":
        oc = (0.22, 0.24, 0.25, 1)
        front.append((rect(hx - 11, hy - 15, 24, 8), oc))
        front.append((rect(hx - 9, hy - 8, 18, 3), darken(oc, 0.3)))
        front.append((rect(hx + 5, hy - 6, 11, 3), dark))
        front.append((circle(hx + 2, hy - 11, 2.5, 8), (0.9, 0.8, 0.3, 1)))
    elif style == "beanie":
        front.append((dome(hx, hy - 2, 11.0), (0.15, 0.15, 0.17, 1)))
    elif style == "beret":
        front.append(([H(-12, -6), H(10, -8), H(4, -15), H(-10, -13)], (0.7, 0.1, 0.15, 1)))
    elif style == "shades":
        front.append((rect(hx - 9, hy - 10, 18, 5), hair))
        front.append((rect(hx, hy - 3, 10, 4), dark))
    elif style == "ushanka":
        fur = (0.45, 0.35, 0.25, 1)
        front.append((rect(hx - 13, hy - 16, 26, 10), fur))
        front.append((rect(hx - 12, hy - 6, 6, 12), fur))
        front.append((circle(hx, hy - 11, 2.5, 8), (0.85, 0.2, 0.2, 1)))
    elif style in ("visor", "robot"):
        eye = (0.2, 1, 1, 1) if style == "visor" else (1, 0.15, 0.15, 1)
        front.append((rect(hx - 11, hy - 12, 23, 23), darken(skin, 0.35)))
        front.append((rect(hx - 9, hy - 10, 19, 19), skin))
        front.append((rect(hx - 2, hy - 4, 13, 5), eye))
        front.append((line(H(-4, -11), H(-6, -19), 2.0), darken(skin, 0.3)))
        front.append((circle(hx - 6, hy - 20, 2.5, 8), eye))
    elif style == "halo":
        front += [(pl, cl, "halo") for pl, cl in dots_ring(hx, hy - 16, 10.0, 14, 1.8, (0.5, 1, 1, 0.95), trail=True)]
        front.append((rect(hx - 1, hy - 4, 11, 4), (0.2, 1, 1, 1)))
    elif style == "goggles":
        for i in range(3):
            front.append((line(H(-5 + i * 5, -9), H(-6 + i * 5, -17), 3.0), (0.9, 0.3, 0.1, 1)))
        front.append((rect(hx - 10, hy - 7, 21, 4), (0.3, 0.25, 0.2, 1)))
        front.append((circle(hx + 7, hy - 5, 4.0, 12), (0.4, 0.9, 0.4, 1)))
    elif style == "crown":
        front.append(([H(-10, -8), H(10, -8), H(11, -20), H(5, -14), H(0, -22), H(-5, -14), H(-11, -20)], (1, 0.8, 0.15, 1)))
        front.append((circle(hx, hy - 11, 2.0, 8), (0.9, 0.1, 0.3, 1)))
    elif style == "eon":
        gold = (1, 0.82, 0.3, 1)
        y0 = -26.0
        front.append(([H(-9, y0 - 10), H(9, y0 - 10), H(0, y0)], gold, "hourglass"))
        front.append(([H(-9, y0 + 10), H(9, y0 + 10), H(0, y0)], gold, "hourglass"))
        front += [(pl, cl, "eon_ring") for pl, cl in dots_ring(hx, hy + y0, 15.0, 16, 1.2, (1, 0.85, 0.4, 0.8), trail=True)]
        front.append((rect(hx + 2, hy - 3, 4, 3), (0.4, 1, 1, 1)))
        front.append((rect(hx + 7, hy - 3, 3, 3), (0.4, 1, 1, 1)))
        for k in range(3):
            a = k * 2 * math.pi / 3
            front.append((circle(hx + math.cos(a) * 18, hy + y0 + math.sin(a) * 8, 2.0, 8), (0.7, 0.9, 1, 0.8), "orb_%d" % k))
    if f and style not in ("luchamask", "headwrap"):
        front.append((rect(hx + 5, hy + 0.3, 2.5, 1.4), (0.05, 0.05, 0.05, 1)))  # cílios
    return back, front


# ---------------------------------------------------------------------------
# Esqueleto


def rest_layout():
    """Posições de repouso (jogo) de todas as juntas, a partir da pose neutra."""
    r = P.pose("idle", 0.0, 0.0)
    hip, sh, head = r["hip"], r["shoulder"], r["head"]
    j = {"hip": hip, "shoulder": sh, "head": head}
    j["sh_b"] = (sh[0] - 3, sh[1] + 2)
    j["sh_f"] = (sh[0] + 3, sh[1] + 2)
    j["hip_b"] = (hip[0] - 4, hip[1])
    j["hip_f"] = (hip[0] + 4, hip[1])
    j["hb"], j["hf"], j["bf"], j["ff"] = tuple(r["hb"]), tuple(r["hf"]), tuple(r["bf"]), tuple(r["ff"])
    # cotovelos para baixo, joelhos para a frente
    j["el_b"] = two_bone(j["sh_b"], j["hb"], P.UPPER_ARM, P.FOREARM, -1)
    j["el_f"] = two_bone(j["sh_f"], j["hf"], P.UPPER_ARM, P.FOREARM, -1)
    j["kn_b"] = two_bone(j["hip_b"], j["bf"], P.THIGH, P.SHIN, -1)
    j["kn_f"] = two_bone(j["hip_f"], j["ff"], P.THIGH, P.SHIN, -1)
    return j


def fix_bend(j):
    # Em coordenadas do jogo (y para baixo), "para baixo" = y maior; "frente" = x maior.
    for side in ("b", "f"):
        sh, hd = j["sh_" + side], j["h" + side]
        a = two_bone(sh, hd, P.UPPER_ARM, P.FOREARM, 1)
        b = two_bone(sh, hd, P.UPPER_ARM, P.FOREARM, -1)
        j["el_" + side] = a if a[1] > b[1] else b
        hp, ft = j["hip_" + side], j[side + "f"]
        a = two_bone(hp, ft, P.THIGH, P.SHIN, 1)
        b = two_bone(hp, ft, P.THIGH, P.SHIN, -1)
        j["kn_" + side] = a if a[0] > b[0] else b
    return j


def _mid(a, b):
    return ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)


def cape_points(j):
    hip, sh = j["hip"], j["shoulder"]
    A, B = (sh[0] - 8, sh[1] - 2), (sh[0] + 6, sh[1] - 2)
    D, E = (hip[0] - 14, hip[1] + 22), (hip[0] - 30, hip[1] + 18)
    return A, B, _mid(B, D), D, E, _mid(A, E)


# Ossos de efeito (animados em loop pelo FXPlayer, independentes da pose do corpo)
FX_LEN = 4.0 * math.pi / 3.0   # 1 volta das órbitas; 2 subidas da ampulheta; 4 ondas da capa
FX_SAMPLES = 64
POS_TRACK_BONES = {"pelvis", "hourglass", "orb_0", "orb_1", "orb_2"}


def fx_bone_specs(c, j):
    out = []
    head = j["head"]
    if c.get("cape", (0, 0, 0, 0))[3] > 0:
        A, B, C, D, E, F = cape_points(j)
        top, mid, bot = _mid(A, B), _mid(C, F), _mid(D, E)
        out += [("cape_1", top, mid, "spine", False, True, True),
                ("cape_2", mid, bot, "cape_1", True, True, True)]
    # cabelo e faixas que balançam (pivô na raiz, preso à cabeça)
    for hat, bone, root, tip in (("ponytail", "tail", (-8, -4), (-15, 15)),
                                 ("band", "band_tail", (-9, -4), (-18, 2)),
                                 ("ninja", "ninja_tail", (-9, -4), (-17, 0)),
                                 ("braidcrown", "braid", (-8, 0), (-10, 22)),
                                 ("luchamask", "braid", (-8, -2), (-14, 18)),
                                 ("longhair", "hair_long", (-5, -4), (-5, 22))):
        if c["hat"] == hat:
            out.append((bone, (head[0] + root[0], head[1] + root[1]), (head[0] + tip[0], head[1] + tip[1]), "head", False, True, True))
    if c["hat"] == "halo":
        hc = (head[0], head[1] - 16)
        out.append(("halo", hc, (hc[0], hc[1] - 6), "head", False, True, True))
    if c["hat"] == "eon":
        g = (head[0], head[1] - 26)
        out += [("hourglass", g, (g[0], g[1] - 6), "head", False, True, True),
                ("eon_ring", g, (g[0], g[1] - 6), "hourglass", False, True, True)]
        for k in range(3):
            a = k * 2 * math.pi / 3
            o = (g[0] + math.cos(a) * 18, g[1] + math.sin(a) * 8)
            out.append(("orb_%d" % k, o, (o[0], o[1] - 4), "hourglass", False, True, True))
    return out


# (nome, cabeça, cauda, pai, conectado, herda_rotação, exporta)
def bone_specs(j):
    wa = P.weapon_angle("idle", 0.0)
    hf = j["hf"]
    return [
        ("root", (0, 0), (0, -10), None, False, True, True),
        ("pelvis", j["hip"], (j["hip"][0], j["hip"][1] - 4), "root", False, True, True),
        ("spine", j["hip"], j["shoulder"], "pelvis", False, True, True),
        ("head", j["shoulder"], j["head"], "spine", False, True, True),
        ("arm_b_up", j["sh_b"], j["el_b"], "spine", False, True, True),
        ("arm_b_lo", j["el_b"], j["hb"], "arm_b_up", True, True, True),
        ("arm_f_up", j["sh_f"], j["el_f"], "spine", False, True, True),
        ("arm_f_lo", j["el_f"], j["hf"], "arm_f_up", True, True, True),
        ("weapon", hf, (hf[0] + math.cos(wa) * 12, hf[1] + math.sin(wa) * 12), "arm_f_lo", False, False, True),
        ("leg_b_up", j["hip_b"], j["kn_b"], "pelvis", False, True, True),
        ("leg_b_lo", j["kn_b"], j["bf"], "leg_b_up", True, True, True),
        ("foot_b", j["bf"], (j["bf"][0] + 8, j["bf"][1]), "leg_b_lo", False, False, True),
        ("leg_f_up", j["hip_f"], j["kn_f"], "pelvis", False, True, True),
        ("leg_f_lo", j["kn_f"], j["ff"], "leg_f_up", True, True, True),
        ("foot_f", j["ff"], (j["ff"][0] + 8, j["ff"][1]), "leg_f_lo", False, False, True),
        # controles do animador (não vão para o Godot)
        ("ctrl_hand_b", j["hb"], (j["hb"][0], j["hb"][1] - 6), "root", False, True, False),
        ("ctrl_hand_f", j["hf"], (j["hf"][0], j["hf"][1] - 6), "root", False, True, False),
        ("ctrl_foot_b", j["bf"], (j["bf"][0], j["bf"][1] - 6), "root", False, True, False),
        ("ctrl_foot_f", j["ff"], (j["ff"][0], j["ff"][1] - 6), "root", False, True, False),
        ("pole_arm_b", (j["sh_b"][0] - 4, j["sh_b"][1] + 46), (j["sh_b"][0] - 4, j["sh_b"][1] + 40), "spine", False, True, False),
        ("pole_arm_f", (j["sh_f"][0] - 4, j["sh_f"][1] + 46), (j["sh_f"][0] - 4, j["sh_f"][1] + 40), "spine", False, True, False),
        ("pole_leg_b", (j["hip_b"][0] + 44, j["hip_b"][1] + 16), (j["hip_b"][0] + 44, j["hip_b"][1] + 10), "pelvis", False, True, False),
        ("pole_leg_f", (j["hip_f"][0] + 44, j["hip_f"][1] + 16), (j["hip_f"][0] + 44, j["hip_f"][1] + 10), "pelvis", False, True, False),
    ]


IK_CHAINS = [("arm_b_lo", "ctrl_hand_b", "pole_arm_b"), ("arm_f_lo", "ctrl_hand_f", "pole_arm_f"),
             ("leg_b_lo", "ctrl_foot_b", "pole_leg_b"), ("leg_f_lo", "ctrl_foot_f", "pole_leg_f")]


def set_active(obj):
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)


def build_armature(name, j, offset_x, extra_specs=()):
    arm_data = bpy.data.armatures.new(name + "_armature")
    arm = bpy.data.objects.new(name + "_RIG", arm_data)
    arm.location = (offset_x, 0, 0)
    bpy.context.scene.collection.objects.link(arm)
    arm.show_in_front = True
    set_active(arm)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    specs = bone_specs(j) + list(extra_specs)
    for nm, h, t, parent, conn, inh, exp in specs:
        b = eb.new(nm)
        b.head = g2b(*h)
        b.tail = g2b(*t)
        # eixo Z local de todos os ossos perpendicular ao plano 2D (para o IK e as rotações ficarem no plano)
        b.align_roll(Vector((0.0, -1.0, 0.0)))
        b.use_deform = exp
    for nm, h, t, parent, conn, inh, exp in specs:
        b = eb[nm]
        if parent:
            b.parent = eb[parent]
            b.use_connect = conn
        b.use_inherit_rotation = inh
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
    return arm, specs


def add_ik(arm, pole_angle):
    for bone, target, pole in IK_CHAINS:
        c = arm.pose.bones[bone].constraints.new("IK")
        c.target = arm
        c.subtarget = target
        c.pole_target = arm
        c.pole_subtarget = pole
        c.pole_angle = pole_angle
        c.chain_count = 2
        c.use_tail = True


# ---------------------------------------------------------------------------
# Convenções do Blender (descobertas na prática, não supostas)

CONV = {}


def detect_conventions(arm):
    """Descobre como 'location' e 'rotation_euler' locais se traduzem no plano XZ."""
    scn = bpy.context.scene
    pb = arm.pose.bones["pelvis"]
    pb.location = (0, 0, 0)
    bpy.context.view_layer.update()
    h0 = arm.pose.bones["pelvis"].head.copy()
    pb.location = (0.1, 0, 0)
    bpy.context.view_layer.update()
    d = arm.pose.bones["pelvis"].head - h0
    CONV["locx"] = ("x", 1 if d.x > 0 else -1) if abs(d.x) > abs(d.z) else ("z", 1 if d.z > 0 else -1)
    pb.location = (0, 0.1, 0)
    bpy.context.view_layer.update()
    d = arm.pose.bones["pelvis"].head - h0
    CONV["locy"] = ("x", 1 if d.x > 0 else -1) if abs(d.x) > abs(d.z) else ("z", 1 if d.z > 0 else -1)
    pb.location = (0, 0, 0)
    # rotação: girar a coluna em +0,3 no eixo Z local; ver para que lado o ombro foi
    sp = arm.pose.bones["spine"]
    bpy.context.view_layer.update()
    t0 = sp.tail.copy()
    sp.rotation_euler = (0, 0, 0.3)
    bpy.context.view_layer.update()
    t1 = sp.tail.copy()
    sp.rotation_euler = (0, 0, 0)
    bpy.context.view_layer.update()
    a0 = math.atan2(t0.z - sp.head.z, t0.x - sp.head.x)
    a1 = math.atan2(t1.z - sp.head.z, t1.x - sp.head.x)
    CONV["rot_sign"] = 1 if (a1 - a0) > 0 else -1  # +1: rotação local Z positiva = anti-horária no XZ
    scn.frame_set(0)


def loc_vec(dx_b, dz_b):
    """Delta em XZ do Blender -> vetor 'location' local (ossos que apontam para cima)."""
    v = [0.0, 0.0, 0.0]
    for idx, key in ((0, "locx"), (1, "locy")):
        axis, sign = CONV[key]
        v[idx] = (dx_b if axis == "x" else dz_b) * sign
    return Vector(v)


def choose_pole_angles(arm):
    """Para cada cadeia de IK, testa ângulos de polo e fica com o que reproduz a pose de
    repouso (cotovelo/joelho no plano 2D e do lado certo). Retorna {osso: (ângulo, erro_px)}."""
    result = {}
    for bone, _t, _p in IK_CHAINS:
        cns = arm.pose.bones[bone].constraints[0]
        up = arm.pose.bones[bone].parent.name
        rest = arm.data.bones[up].tail_local
        best = None
        for pa in (0.0, math.pi, -math.pi / 2, math.pi / 2):
            cns.pole_angle = pa
            bpy.context.view_layer.update()
            err = (arm.pose.bones[up].tail - rest).length / PX
            if best is None or err < best[1]:
                best = (pa, err)
        cns.pole_angle = best[0]
        result[bone] = best
    bpy.context.view_layer.update()
    return result


# ---------------------------------------------------------------------------
# Peças (malhas) presas aos ossos


def material(color):
    key = "M_%.3f_%.3f_%.3f_%.2f" % color
    if key in bpy.data.materials:
        return bpy.data.materials[key]
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = color
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    if color[3] < 1.0:
        tr = nt.nodes.new("ShaderNodeBsdfTransparent")
        mix = nt.nodes.new("ShaderNodeMixShader")
        mix.inputs["Fac"].default_value = color[3]
        nt.links.new(tr.outputs[0], mix.inputs[1])
        nt.links.new(em.outputs[0], mix.inputs[2])
        nt.links.new(mix.outputs[0], out.inputs["Surface"])
    else:
        nt.links.new(em.outputs[0], out.inputs["Surface"])
    m.diffuse_color = color
    return m


def build_parts(c, j):
    """Lista de peças: (nome, osso, ordem_z, cor, polígono em coordenadas do jogo)."""
    skin, hair, shirt, pants, shoes = c["skin"], c["hair"], c["shirt"], c["pants"], c["shoes"]
    skin_d, pants_d, shoe_d = darken(skin, 0.2), darken(pants, 0.3), darken(shoes, 0.2)
    hip, sh, head = j["hip"], j["shoulder"], j["head"]
    sw = 9.0 if c["f"] else 11.0
    parts = []
    add = lambda nm, bone, z, col, poly: parts.append((nm, bone, z, col, poly))  # noqa: E731
    # braço de trás
    add("arm_b_up", "arm_b_up", 0, skin_d, capsule(j["sh_b"], j["el_b"], 6.5))
    add("arm_b_lo", "arm_b_lo", 0, skin_d, capsule(j["el_b"], j["hb"], 6.5))
    add("hand_b", "arm_b_lo", 0, skin_d, circle(j["hb"][0], j["hb"][1], 5.0, 12))
    # perna de trás
    add("leg_b_up", "leg_b_up", 1, pants_d, capsule(j["hip_b"], j["kn_b"], 9.0))
    add("leg_b_lo", "leg_b_lo", 1, pants_d, capsule(j["kn_b"], j["bf"], 9.0))
    add("shoe_b", "foot_b", 1, shoe_d, rect(j["bf"][0] - 4, j["bf"][1] - 4, 12, 5))
    # perna da frente
    add("leg_f_up", "leg_f_up", 2, pants, capsule(j["hip_f"], j["kn_f"], 9.0))
    add("leg_f_lo", "leg_f_lo", 2, pants, capsule(j["kn_f"], j["ff"], 9.0))
    add("shoe_f", "foot_f", 2, shoes, rect(j["ff"][0] - 4, j["ff"][1] - 4, 13, 5))
    # tronco e cinto
    add("torso", "spine", 3, shirt, [(hip[0] - 9, hip[1] + 2), (hip[0] + 9, hip[1] + 2), (sh[0] + sw, sh[1]), (sh[0] - sw, sh[1])])
    add("belt", "pelvis", 3, (0.12, 0.1, 0.08, 1), rect(hip[0] - 9, hip[1] - 1.5, 18, 3))
    # cabelo de trás, pescoço e cabeça
    back, front = hair_parts(c["hat"], head, hair, skin, c["f"], shirt)
    # capa (chefes) atrás de tudo
    if c.get("cape", (0, 0, 0, 0))[3] > 0:
        cp = c["cape"]
        A, B, C, D, E, F = cape_points(j)
        # topo preso ao tronco; meio no osso cape_1; barra no cape_2 (ondula)
        parts.insert(0, ("cape", "spine", -1, cp, [A, B, C, D, E, F], ["spine", "spine", "cape_1", "cape_2", "cape_2", "cape_1"]))
    for i, item in enumerate(back):
        add("hair_back_%d" % i, item[2] if len(item) > 2 else "head", 4, item[1], item[0])
    add("neck", "head", 5, skin, capsule(sh, head, 6.0, 3))
    add("head_hair", "head", 5, skin if c["hat"] == "bald" else hair, circle(head[0], head[1], 10.0))
    add("face", "head", 5, skin, circle(head[0] + 2, head[1] + 2, 8.5))
    add("eye", "head", 5, (0.05, 0.05, 0.05, 1), rect(head[0] + 4, head[1] - 2, 3, 3))
    for i, item in enumerate(front):
        add("hair_%d" % i, item[2] if len(item) > 2 else "head", 6, item[1], item[0])
    # braço da frente
    add("arm_f_up", "arm_f_up", 7, skin, capsule(j["sh_f"], j["el_f"], 6.5))
    add("arm_f_lo", "arm_f_lo", 7, skin, capsule(j["el_f"], j["hf"], 6.5))
    add("hand_f", "arm_f_lo", 9, skin, circle(j["hf"][0], j["hf"][1], 5.5, 12))
    return parts


def make_part_objects(arm, parts, name):
    """Cria as malhas no Blender, presas aos ossos (BONE parent)."""
    for part in parts:
        nm, bone_name, z, col, poly = part[:5]
        if len(part) > 5:
            _weighted_part(arm, name, nm, z, col, poly, part[5])
            continue
        me = bpy.data.meshes.new("%s_%s" % (name, nm))
        bone = arm.data.bones[bone_name]
        # espaço local de um filho de osso: origem na CAUDA do osso, eixos do osso
        m_tail = Matrix.Translation(bone.tail_local) @ bone.matrix_local.to_3x3().to_4x4()
        inv = m_tail.inverted()
        verts = [inv @ (g2b(x, y) + Vector((0, -0.001 * z, 0))) for x, y in poly]
        me.from_pydata([tuple(v) for v in verts], [], [list(range(len(verts)))])
        me.materials.append(material(col))
        ob = bpy.data.objects.new("%s_%s" % (name, nm), me)
        bpy.context.scene.collection.objects.link(ob)
        ob.parent = arm
        ob.parent_type = "BONE"
        ob.parent_bone = bone_name
        ob.matrix_parent_inverse = Matrix.Identity(4)
        ob["z_order"] = z


def _weighted_part(arm, name, nm, z, col, poly, weights):
    """Peça deformada por vários ossos (ex.: capa): grupos de vértices + modificador Armature."""
    me = bpy.data.meshes.new("%s_%s" % (name, nm))
    verts = [g2b(x, y) + Vector((0, -0.001 * z, 0)) for x, y in poly]
    me.from_pydata([tuple(v) for v in verts], [], [list(range(len(verts)))])
    me.materials.append(material(col))
    ob = bpy.data.objects.new("%s_%s" % (name, nm), me)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = arm
    ob.matrix_parent_inverse = Matrix.Identity(4)
    for bone_name in sorted(set(weights)):
        vg = ob.vertex_groups.new(name=bone_name)
        vg.add([i for i, w in enumerate(weights) if w == bone_name], 1.0, "REPLACE")
    mod = ob.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    ob["z_order"] = z


def make_fx_action(arm, name, fx_names):
    """Loop dos efeitos: capa ondulando, halo girando, ampulheta flutuando e órbitas do ÉON."""
    act = bpy.data.actions.new("%s_fx" % name)
    act.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = act
    pbs = arm.pose.bones
    rs = CONV["rot_sign"]
    frames = []
    for i in range(FX_SAMPLES + 1):
        t = FX_LEN * i / FX_SAMPLES
        f = i  # 1 quadro por amostra; o tempo real vai no JSON
        if "cape_1" in fx_names:
            pbs["cape_1"].rotation_euler = (0, 0, 0.05 * math.sin(t * 6.0) * rs)
            pbs["cape_2"].rotation_euler = (0, 0, 0.08 * math.sin(t * 6.0 - 0.9) * rs)
            pbs["cape_1"].keyframe_insert("rotation_euler", frame=f)
            pbs["cape_2"].keyframe_insert("rotation_euler", frame=f)
        # balanços (frequências múltiplas de 1,5 rad/s para o loop fechar sem pulo)
        for bone, amp, w in (("tail", 0.15, 7.5), ("band_tail", 0.28, 10.5), ("ninja_tail", 0.35, 9.0),
                             ("braid", 0.12, 6.0), ("hair_long", 0.07, 4.5)):
            if bone in fx_names:
                pbs[bone].rotation_euler = (0, 0, amp * math.sin(t * w) * rs)
                pbs[bone].keyframe_insert("rotation_euler", frame=f)
        if "halo" in fx_names:
            pbs["halo"].rotation_euler = (0, 0, -t * 1.5 * rs)
            pbs["halo"].keyframe_insert("rotation_euler", frame=f)
        if "hourglass" in fx_names:
            dy = math.sin(t * 3.0) * 2.0  # px, y do jogo (para baixo)
            pbs["hourglass"].location = loc_vec(0.0, -dy * PX)
            pbs["hourglass"].keyframe_insert("location", frame=f)
            pbs["eon_ring"].rotation_euler = (0, 0, t * 1.5 * rs)
            pbs["eon_ring"].keyframe_insert("rotation_euler", frame=f)
            for k in range(3):
                a0 = k * 2 * math.pi / 3
                a = t * 1.5 + a0
                dx = (math.cos(a) - math.cos(a0)) * 18
                dyo = (math.sin(a) - math.sin(a0)) * 8
                pbs["orb_%d" % k].location = loc_vec(dx * PX, -dyo * PX)
                pbs["orb_%d" % k].keyframe_insert("location", frame=f)
        frames.append((t, f))
    _linear(act)
    return act, frames


def _linear(act):
    try:
        curves = act.fcurves
    except AttributeError:  # Actions em camadas (Blender 4.4+)
        curves = [fc for layer in act.layers for strip in layer.strips for bag in strip.channelbags for fc in bag.fcurves]
    for fc in curves:
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"


# ---------------------------------------------------------------------------
# Animações: animam os controles; o Blender resolve o IK


def key_pose(arm, j, ps, frame):
    pbs = arm.pose.bones
    # quadril (sobe/desce)
    dh = (ps["hip"][0] - j["hip"][0], ps["hip"][1] - j["hip"][1])
    pbs["pelvis"].location = loc_vec(dh[0] * PX, -dh[1] * PX)
    # inclinação do tronco (ombro relativo ao quadril)
    sv = (ps["shoulder"][0] - ps["hip"][0], ps["shoulder"][1] - ps["hip"][1])
    rv = (j["shoulder"][0] - j["hip"][0], j["shoulder"][1] - j["hip"][1])
    spine_rot = ang_b(*sv) - ang_b(*rv)
    pbs["spine"].rotation_euler = (0, 0, spine_rot * CONV["rot_sign"])
    # cabeça: direção ombro->cabeça é absoluta no jogo; desconta a rotação do tronco
    hv = (ps["head"][0] - ps["shoulder"][0], ps["head"][1] - ps["shoulder"][1])
    hr = (j["head"][0] - j["shoulder"][0], j["head"][1] - j["shoulder"][1])
    pbs["head"].rotation_euler = (0, 0, (ang_b(*hv) - ang_b(*hr) - spine_rot) * CONV["rot_sign"])
    # arma (não herda rotação: ângulo absoluto)
    wa_rest = P.weapon_angle("idle", 0.0)
    pbs["weapon"].rotation_euler = (0, 0, (-ps["weapon"] - (-wa_rest)) * CONV["rot_sign"])
    # alvos de IK de mãos e pés
    for ctrl, key, rest in (("ctrl_hand_b", "hb", j["hb"]), ("ctrl_hand_f", "hf", j["hf"]),
                            ("ctrl_foot_b", "bf", j["bf"]), ("ctrl_foot_f", "ff", j["ff"])):
        tx, ty = ps[key]
        pbs[ctrl].location = loc_vec((tx - rest[0]) * PX, -(ty - rest[1]) * PX)
    for nm in ("pelvis", "ctrl_hand_b", "ctrl_hand_f", "ctrl_foot_b", "ctrl_foot_f"):
        pbs[nm].keyframe_insert("location", frame=frame)
    for nm in ("spine", "head", "weapon"):
        pbs[nm].keyframe_insert("rotation_euler", frame=frame)


def make_action(arm, j, cname, anim):
    act = bpy.data.actions.new("%s_%s" % (cname, anim))
    act.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = act
    smp = P.samples(anim)
    frames = []
    for t, ps in smp:
        f = round(t * FPS)
        key_pose(arm, j, ps, f)
        frames.append((t, f))
    # interpolação linear (o jogo controla o tempo; o Godot interpola entre as amostras)
    try:
        curves = act.fcurves
    except AttributeError:  # Actions em camadas (Blender 4.4+)
        curves = [fc for layer in act.layers for strip in layer.strips for bag in strip.channelbags for fc in bag.fcurves]
    for fc in curves:
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    return act, frames


def bone_global(arm, name):
    pb = arm.pose.bones[name]
    h, t = pb.head, pb.tail
    return h, math.atan2(-(t.z - h.z), t.x - h.x)  # ângulo em coordenadas do jogo (y para baixo)


def export_frame(arm, specs, only=None, skip=()):
    out = {}
    for nm, _h, _t, parent, _c, _i, exp in specs:
        if not exp or nm in skip or (only is not None and nm not in only):
            continue
        h, a = bone_global(arm, nm)
        if parent:
            ph, pa = bone_global(arm, parent)
            d = Vector(((h.x - ph.x) / PX, -(h.z - ph.z) / PX))
            ca, sa = math.cos(-pa), math.sin(-pa)
            pos = [d.x * ca - d.y * sa, d.x * sa + d.y * ca]
            rot = a - pa
        else:
            pos = [h.x / PX, -h.z / PX]
            rot = a
        rot = (rot + math.pi) % (2 * math.pi) - math.pi
        out[nm] = {"pos": [round(pos[0], 3), round(pos[1], 3)], "rot": round(rot, 5)}
    return out


def rest_frame(arm, specs):
    """Transformações de repouso (do próprio Blender: bone.head_local/tail_local)."""
    data = {}
    bones = arm.data.bones

    def g(name):
        b = bones[name]
        h, t = b.head_local, b.tail_local
        return h, math.atan2(-(t.z - h.z), t.x - h.x), (t - h).length / PX

    for nm, _h, _t, parent, _c, _i, exp in specs:
        if not exp:
            continue
        h, a, ln = g(nm)
        if parent:
            ph, pa, _ = g(parent)
            d = Vector(((h.x - ph.x) / PX, -(h.z - ph.z) / PX))
            ca, sa = math.cos(-pa), math.sin(-pa)
            pos = [d.x * ca - d.y * sa, d.x * sa + d.y * ca]
            rot = a - pa
        else:
            pos, rot = [h.x / PX, -h.z / PX], a
        rot = (rot + math.pi) % (2 * math.pi) - math.pi
        data[nm] = {"parent": parent, "pos": [round(pos[0], 3), round(pos[1], 3)], "rot": round(rot, 5),
                    "length": round(ln, 3), "global": [b2g(h), a]}
    return data


def parts_to_local(parts, rest):
    """Converte os polígonos (coordenadas do jogo) para o espaço local de cada osso no Godot."""
    out = []
    for part in parts:
        nm, bone, z, col, poly = part[:5]
        (gx, gy), ga = rest[bone]["global"]
        ca, sa = math.cos(-ga), math.sin(-ga)
        loc = [[round((x - gx) * ca - (y - gy) * sa, 3), round((x - gx) * sa + (y - gy) * ca, 3)] for x, y in poly]
        item = {"name": nm, "bone": bone, "z": z, "color": [round(v, 4) for v in col], "polygon": loc,
                "rest_polygon": [[round(x, 3), round(y, 3)] for x, y in poly]}
        if len(part) > 5:
            item["weights"] = part[5]
        out.append(item)
    return out


# ---------------------------------------------------------------------------


def render_preview(rigs, path, cols):
    """Prévia renderizada no Blender (Cycles), com os rigs em grade."""
    scn = bpy.context.scene
    for arm, c in rigs:
        arm.animation_data.action = bpy.data.actions["%s_idle" % c["slug"]]
    scn.frame_set(0)
    rows = (len(rigs) + cols - 1) // cols
    step_x, step_z = 1.4, 1.5
    w = (min(cols, len(rigs)) - 1) * step_x + 1.6
    h = (rows - 1) * step_z + 1.5
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = max(w, h)
    cam = bpy.data.objects.new("cam", cam_data)
    scn.collection.objects.link(cam)
    cam.location = ((min(cols, len(rigs)) - 1) * step_x / 2, -10, 0.6 - (rows - 1) * step_z / 2)
    cam.rotation_euler = (math.pi / 2, 0, 0)
    scn.camera = cam
    scn.render.engine = "CYCLES"
    scn.cycles.samples = 8
    scn.cycles.device = "CPU"
    px_per_bu = 130
    scn.render.resolution_x = int(w * px_per_bu)
    scn.render.resolution_y = int(h * px_per_bu)
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.02, 0.015, 0.04, 1)
    scn.world = world
    scn.view_settings.view_transform = "Standard"
    scn.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


# Animações por grupo: jogadores usam todas; inimigos só as que o jogo usa para eles.
ENEMY_ANIMS = ["idle", "walk", "jab", "kick", "slam", "charge", "special", "throw", "swing", "hurt", "down"]


def build_group(characters, blend_name, json_dir, preview_name, cols, anims):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scn = bpy.context.scene
    scn.render.fps = FPS
    CONV.clear()
    j = fix_bend(rest_layout())
    json_dir.mkdir(parents=True, exist_ok=True)
    rigs = []
    for i, c in enumerate(characters):
        name = c["slug"]
        ox, oz = (i % cols) * 1.4, -(i // cols) * 1.5
        fx_specs = fx_bone_specs(c, j)
        fx_names = [sp[0] for sp in fx_specs]
        arm, specs = build_armature(name, j, ox, fx_specs)
        arm.location.z = oz
        if not CONV:
            detect_conventions(arm)
            print("Convenções do Blender:", CONV)
        add_ik(arm, 0.0)
        if i == 0:
            CONV["poles"] = choose_pole_angles(arm)
            print("Polos do IK (ângulo, erro na pose de repouso em px):",
                  {k: (round(v[0], 2), round(v[1], 3)) for k, v in CONV["poles"].items()})
        else:
            for bone, (pa, _e) in CONV["poles"].items():
                arm.pose.bones[bone].constraints[0].pole_angle = pa
        parts = build_parts(c, j)
        make_part_objects(arm, parts, name)
        rest = rest_frame(arm, specs)
        data_anims = {}
        for anim in anims:
            _act, frames = make_action(arm, j, name, anim)
            keys = []
            for t, f in frames:
                scn.frame_set(f)
                keys.append({"t": round(t, 5), "bones": export_frame(arm, specs, skip=fx_names)})
            data_anims[anim] = {"length": round(P.anim_length(anim), 5), "loop": P.ANIMATIONS[anim]["kind"] == "loop", "keys": keys}
        if fx_names:
            fx_act, frames = make_fx_action(arm, name, fx_names)
            keys = []
            for t, f in frames:
                scn.frame_set(f)
                keys.append({"t": round(t, 5), "bones": export_frame(arm, specs, only=fx_names)})
            data_anims["fx"] = {"length": round(FX_LEN, 5), "loop": True, "fx": True, "keys": keys}
        arm.animation_data.action = bpy.data.actions["%s_idle" % name]
        if fx_names:
            # no .blend, os efeitos tocam por cima do corpo numa faixa de NLA
            try:
                tr = arm.animation_data.nla_tracks.new()
                tr.name = "efeitos"
                tr.strips.new("fx", 0, bpy.data.actions["%s_fx" % name])
            except Exception as e:  # noqa: BLE001
                print("aviso: NLA dos efeitos não criada:", e)
        data = {"name": c["name"], "slug": c["slug"], "size": c["size"], "group": c.get("group", "players"),
                "bones": rest, "parts": parts_to_local(parts, rest), "animations": data_anims, "fps": FPS}
        if "era" in c:
            data["era"] = c["era"]
            data["kind"] = c["kind"]
        (json_dir / ("%s.json" % c["slug"])).write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
        rigs.append((arm, c))
        print("Rig %-22s ossos=%d peças=%d animações=%d%s" % (c["slug"], len(rest), len(parts), len(data_anims),
                                                         "  efeitos: " + ", ".join(fx_names) if fx_names else ""))
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT / blend_name))
    if "--no-render" not in sys.argv:
        render_preview(rigs, OUT / preview_name, cols)
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT / blend_name))
    blend1 = OUT / (blend_name + "1")
    if blend1.exists():
        blend1.unlink()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    only = [a.split("=", 1)[1] for a in sys.argv if a.startswith("--only=")]
    group = only[0] if only else "all"
    if group in ("all", "players"):
        players = chars_mod.load_characters()
        for c in players:
            c["slug"] = chars_mod.slug(c["name"])
            c["group"] = "players"
        build_group(players, "punho_rigs.blend", OUT / "json", "preview.png", 14, list(P.ANIMATIONS))
    if group in ("all", "enemies"):
        build_group(looks_mod.enemy_rigs(), "punho_rigs_inimigos.blend", OUT / "json" / "enemies",
                    "preview_inimigos.png", 5, ENEMY_ANIMS)
    print("OK:", OUT)


if __name__ == "__main__":
    main()
