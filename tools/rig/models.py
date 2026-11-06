"""Modelos definitivos dos 79 personagens: acabamento final de arte sobre as peças dos rigs.

    python tools/rig/models.py            # aplica em rigs/**/*.tscn (pode rodar de novo: refaz do zero)

Sobre as peças geradas pelo Blender (Polygon2D com skinning no nó Parts), acrescenta:
  * contorno em cada peça (um tom bem escuro da própria cor, ~1,3 px), desenhado logo atrás dela;
  * sombreamento cel: o lado da peça longe da luz (luz vindo de cima e da frente) num tom mais escuro,
    e um brilho estreito no lado iluminado;
  * rosto: branco do olho, sobrancelha (franzida nos inimigos) e boca — robôs, visores e o ÉON mantêm
    o rosto deles; ninjas mascarados ficam sem boca;
  * detalhes do estilo de luta de cada um dos 14 lutadores (luvas, faixas, cordão, joelheiras, tatuagens,
    mongkol...).

As peças novas têm nomes com prefixo (ol_, sh_, hl_, fc_, dt_) e são refeitas a cada execução a partir das
originais; cores trocadas guardam a original em metadata/base_color. Todas usam o skinning da peça de
origem, então acompanham as animações. Depois, rode tools/rig/hitboxes.py (as hurtboxes usam a silhueta).
"""
import math
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import chars  # noqa: E402
import hitboxes as H  # noqa: E402
import looks  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
RIGS = ROOT / "rigs"
GEN = ("ol_", "sh_", "hl_", "fc_", "dt_")
LIGHT = (0.45, -0.89)           # de onde vem a luz (x para a frente, y para baixo): cima e frente
OUTLINE = 1.3                   # px
NO_OUTLINE = ("eye",)
NO_FACE = ("robot", "visor", "eon")


# ---------------------------------------------------------------------------
# Cena: peças do nó Parts


def _f(x):
    s = ("%.3f" % x).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def _fc(x):
    """Cor com 5 casas (como o rig_to_godot.py): regravar a cena não muda as cores."""
    s = ("%.5f" % x).rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def parse(text):
    """Peças em ordem: dicionários com nome, texto bruto, cor, vértices, linha de ossos e pesos."""
    start = text.index('[node name="Parts" type="Node2D" parent="."]')
    end = text.index('[node name="AnimationPlayer"', start)
    blocks = re.split(r"\n(?=\[node )", text[start:end].rstrip("\n"))
    items = []
    for blk in blocks[1:]:
        m = re.match(r'\[node name="(\w+)" type="(\w+)" parent="([^"]+)"\]', blk)
        it = {"name": m.group(1), "type": m.group(2) if m.group(3) == "Parts" else "other", "raw": blk.strip("\n")}
        if it["type"] == "Polygon2D":
            col = re.search(r"^color = Color\(([^)]*)\)", blk, re.M)
            base = re.search(r"^metadata/base_color = Color\(([^)]*)\)", blk, re.M)
            poly = re.search(r"^polygon = PackedVector2Array\(([^)]*)\)", blk, re.M)
            bl = re.search(r"^bones = (\[.*\])$", blk, re.M)
            c = [float(x) for x in (base or col).group(1).split(",")]
            v = H._floats(poly.group(1))
            ws = [(p, H._floats(w)) for p, w in re.findall(r'NodePath\("([^"]+)"\), PackedFloat32Array\(([^)]*)\)', bl.group(1))]
            it.update({"color": c, "verts": list(zip(v[0::2], v[1::2])), "bones_line": bl.group(1), "weights": ws})
        items.append(it)
    return start, end, blocks[0].rstrip("\n"), items


def poly_node(name, color, verts, bone_path, base_color=None):
    """Polygon2D novo preso (peso 1) a um osso."""
    lines = ['[node name="%s" type="Polygon2D" parent="Parts"]' % name,
             "color = Color(%s)" % ", ".join(_fc(c) for c in color),
             'skeleton = NodePath("../../Skeleton2D")',
             "polygon = PackedVector2Array(%s)" % ", ".join("%s, %s" % (_f(x), _f(y)) for x, y in verts),
             'bones = [NodePath("%s"), PackedFloat32Array(%s)]' % (bone_path, ", ".join("1" for _ in verts))]
    if base_color:
        lines.append("metadata/base_color = Color(%s)" % ", ".join(_fc(c) for c in base_color))
    return "\n".join(lines)


def part_node(it, color=None, verts=None, name=None):
    """Mesma peça (mesmos ossos e pesos por vértice) com cor/vértices trocados (mesmo nº de vértices)."""
    verts = verts if verts is not None else it["verts"]
    color = color if color is not None else it["color"]
    bones = "[" + ", ".join('NodePath("%s"), PackedFloat32Array(%s)' % (p, ", ".join(_f(x) for x in w)) for p, w in it["weights"]) + "]"
    lines = ['[node name="%s" type="Polygon2D" parent="Parts"]' % (name or it["name"]),
             "color = Color(%s)" % ", ".join(_fc(c) for c in color),
             'skeleton = NodePath("../../Skeleton2D")',
             "polygon = PackedVector2Array(%s)" % ", ".join("%s, %s" % (_f(x), _f(y)) for x, y in verts),
             "bones = %s" % bones]
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Geometria


def area(vs):
    return 0.5 * sum(vs[i][0] * vs[(i + 1) % len(vs)][1] - vs[(i + 1) % len(vs)][0] * vs[i][1] for i in range(len(vs)))


def centroid(vs):
    return (sum(x for x, _ in vs) / len(vs), sum(y for _, y in vs) / len(vs))


def offset(vs, d):
    """Polígono afastado d px para fora (bissetriz das arestas, com limite de quina)."""
    n = len(vs)
    sgn = 1.0 if area(vs) > 0 else -1.0
    out = []
    for i in range(n):
        p0, p1, p2 = vs[i - 1], vs[i], vs[(i + 1) % n]
        e1 = (p1[0] - p0[0], p1[1] - p0[1])
        e2 = (p2[0] - p1[0], p2[1] - p1[1])
        l1, l2 = math.hypot(*e1) or 1e-6, math.hypot(*e2) or 1e-6
        n1 = (e1[1] / l1 * sgn, -e1[0] / l1 * sgn)   # normal para fora
        n2 = (e2[1] / l2 * sgn, -e2[0] / l2 * sgn)
        b = (n1[0] + n2[0], n1[1] + n2[1])
        bl = math.hypot(*b)
        if bl < 1e-6:
            b, bl = n1, 1.0
        b = (b[0] / bl, b[1] / bl)
        cos_h = max(0.5, b[0] * n1[0] + b[1] * n1[1])   # limite de quina: até 2 d
        out.append((p1[0] + b[0] * d / cos_h, p1[1] + b[1] * d / cos_h))
    return out


def clip(vs, nx, ny, c):
    """Parte do polígono com nx*x + ny*y >= c (Sutherland–Hodgman com um semiplano)."""
    out = []
    n = len(vs)
    for i in range(n):
        a, b = vs[i], vs[(i + 1) % n]
        da, db = nx * a[0] + ny * a[1] - c, nx * b[0] + ny * b[1] - c
        if da >= 0:
            out.append(a)
        if (da >= 0) != (db >= 0):
            t = da / (da - db)
            out.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
    return out


def circle(cx, cy, r, n=14):
    return [(cx + math.cos(i * 2 * math.pi / n) * r, cy + math.sin(i * 2 * math.pi / n) * r) for i in range(n)]


def quad(a, b, w):
    """Faixa de largura w de a até b."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    l = math.hypot(dx, dy) or 1e-6
    nx, ny = -dy / l * w / 2, dx / l * w / 2
    return [(a[0] + nx, a[1] + ny), (b[0] + nx, b[1] + ny), (b[0] - nx, b[1] - ny), (a[0] - nx, a[1] - ny)]


def band_across(bone, rest, bones, t, width, thick):
    """Faixa atravessando um osso a t (0..1) do comprimento (pulseiras, tatuagens, joelheiras)."""
    x, y, a = rest[bone]
    ln = bones[bone]["len"]
    cx, cy = x + math.cos(a) * ln * t, y + math.sin(a) * ln * t
    px, py = -math.sin(a), math.cos(a)
    p0 = (cx - px * width / 2, cy - py * width / 2)
    p1 = (cx + px * width / 2, cy + py * width / 2)
    return quad(p0, p1, thick)


def darker(c, k, blue=0.0):
    return [c[0] * k, c[1] * k, min(1.0, c[2] * k + blue), c[3]]


def lighter(c, k):
    return [c[0] + (1 - c[0]) * k, c[1] + (1 - c[1]) * k, c[2] + (1 - c[2]) * k, c[3]]


# ---------------------------------------------------------------------------
# Acabamento: contorno, sombra e brilho de uma peça


def finish(it, outline=True):
    """[texto do contorno, (a peça vem depois), sombra, brilho] desta peça."""
    vs, c = it["verts"], it["color"]
    if len(vs) < 3 or abs(area(vs)) < 1.0:
        return [], []
    before, after = [], []
    single = len(it["weights"]) == 1
    if outline and it["name"] not in NO_OUTLINE and abs(area(vs)) >= 6.0:
        oc = [c[0] * 0.22 + 0.02, c[1] * 0.22 + 0.02, c[2] * 0.22 + 0.04, c[3]]
        before.append(part_node(it, oc, offset(vs, OUTLINE), "ol_" + it["name"]))
    if single and abs(area(vs)) >= 10.0:
        cx, cy = centroid(vs)
        lx, ly = LIGHT
        proj = [(x - cx) * lx + (y - cy) * ly for x, y in vs]
        R = max(abs(p) for p in proj) or 1.0
        bone = it["weights"][0][0]
        shade = clip(vs, -lx, -ly, -(lx * cx + ly * cy) + 0.12 * R)   # lado longe da luz
        if len(shade) >= 3 and abs(area(shade)) > 1.0:
            after.append(poly_node("sh_" + it["name"], darker(c, 0.72, 0.03), shade, bone))
        hi = clip(vs, lx, ly, lx * cx + ly * cy + 0.62 * R)              # brilho no lado da luz
        if len(hi) >= 3 and abs(area(hi)) > 0.6:
            after.append(poly_node("hl_" + it["name"], lighter(c, 0.22), hi, bone))
    return before, after


# ---------------------------------------------------------------------------
# Rosto e detalhes de estilo


def bone_path(it_by_name, bone):
    """Caminho do osso (NodePath relativo ao Skeleton2D), tirado de uma peça presa a ele."""
    for it in it_by_name.values():
        if it.get("weights"):
            for p, _w in it["weights"]:
                if p.split("/")[-1] == bone:
                    return p
    return None


def bbox(vs):
    xs, ys = [x for x, _ in vs], [y for _, y in vs]
    return min(xs), min(ys), max(xs), max(ys)


def face_parts(by, enemy, hat):
    """Branco do olho (antes do olho), sobrancelha e boca (depois do olho)."""
    if hat in NO_FACE or "eye" not in by:
        return [], []
    eye, face = by["eye"], by.get("face")
    head = bone_path(by, "head")
    x0, y0, x1, y1 = bbox(eye["verts"])
    skin = face["color"] if face else [0.9, 0.7, 0.55, 1]
    before = [poly_node("fc_white", [0.97, 0.96, 0.92, 1], [(x0 - 1.2, y0 - 0.6), (x1 + 0.6, y0 - 0.6), (x1 + 0.6, y1 + 0.6), (x0 - 1.2, y1 + 0.6)], head)]
    after = []
    if hat != "luchamask":
        brow = [0.08, 0.06, 0.05, 1]
        if enemy:   # franzida: a ponta da frente desce
            pts = quad((x0 - 1.8, y0 - 3.3), (x1 + 1.2, y0 - 1.6), 1.3)
        else:       # determinada
            pts = quad((x0 - 1.8, y0 - 2.9), (x1 + 1.2, y0 - 2.4), 1.2)
        after.append(poly_node("fc_brow", brow, pts, head))
    if hat != "ninja":
        lip = darker(skin, 0.42)
        my = y1 + 4.4
        after.append(poly_node("fc_mouth", lip, quad((x0 - 0.2, my + (0.4 if enemy else 0.0)), (x1 + 1.8, my), 1.0), head))
    return before, after


# Detalhes de estilo dos 14 lutadores: (peça depois da qual entra, função) e trocas de cor
GLOVE = {"valentina": [0.82, 0.08, 0.1, 1], "luca": [0.12, 0.3, 0.85, 1], "amelie": [0.12, 0.14, 0.38, 1], "kirra": [0.8, 0.06, 0.08, 1]}
BELT = {"kai": [0.06, 0.06, 0.07, 1], "mei": [0.82, 0.1, 0.1, 1], "oksana": [0.85, 0.1, 0.12, 1], "dmitri": [0.8, 0.1, 0.1, 1],
        "mateus": [0.95, 0.82, 0.1, 1], "itzel": [0.95, 0.75, 0.2, 1]}
BELT_TAILS = ("kai", "mei", "oksana", "mateus")
SLEEVES = ("kai", "mei", "dmitri")   # jaqueta/kimono: o braço de cima com a cor do tronco


def style_details(slug, by, bones, rest):
    """{nome da peça: [nós novos depois dela]} e {nome da peça: cor nova}."""
    add, recolor = {}, {}
    if slug in GLOVE:
        for side in ("b", "f"):
            h = by.get("hand_" + side)
            if h:
                cx, cy = centroid(h["verts"])
                r = max(math.hypot(x - cx, y - cy) for x, y in h["verts"])
                g = GLOVE[slug] if side == "f" else darker(GLOVE[slug], 0.85)
                path = h["weights"][0][0]
                add.setdefault("hand_" + side, []).append(("dt_glove_" + side, g, circle(cx + 0.6, cy, r * 1.45), path))
                # punho branco da luva
                add["hand_" + side].append(("dt_cuff_" + side, [0.95, 0.95, 0.92, 1],
                                            band_across("arm_%s_lo" % side, rest, bones, 0.78, 7.5, 2.4), bone_path(by, "arm_%s_lo" % side)))
    if slug in BELT and "belt" in by:
        recolor["belt"] = BELT[slug]
        x0, y0, x1, y1 = bbox(by["belt"]["verts"])
        pel = bone_path(by, "pelvis")
        if slug in BELT_TAILS:
            tails = [("dt_tail_1", quad((x1 - 3, y1), (x1 - 1, y1 + 9), 2.2)), ("dt_tail_2", quad((x1 - 5, y1), (x1 - 6, y1 + 8), 2.0))]
            for nm, pts in tails:
                add.setdefault("belt", []).append((nm, BELT[slug], pts, pel))
        if slug == "mateus":   # cordão da capoeira: duas cores trançadas
            add.setdefault("belt", []).append(("dt_cord", [0.15, 0.6, 0.2, 1], quad((x0, (y0 + y1) / 2), (x1, (y0 + y1) / 2), 1.0), pel))
        if slug == "itzel":    # cinturão de campeã: placa dourada na frente
            cx = (x0 + x1) / 2 + 3
            add.setdefault("belt", []).append(("dt_plate", [1.0, 0.86, 0.3, 1], circle(cx, (y0 + y1) / 2, 4.2, 10), pel))
    if slug in SLEEVES and "torso" in by:
        for side in ("b", "f"):
            if "arm_%s_up" % side in by:
                recolor["arm_%s_up" % side] = by["torso"]["color"] if side == "f" else darker(by["torso"]["color"], 0.9)
    if slug == "jake":         # joelheiras
        for side in ("b", "f"):
            add.setdefault("leg_%s_lo" % side, []).append(("dt_knee_" + side, [0.1, 0.1, 0.12, 1],
                                                          band_across("leg_%s_lo" % side, rest, bones, 0.12, 9.5, 6.0), bone_path(by, "leg_%s_lo" % side)))
    if slug == "kofi":         # dambe: a mão da frente enfaixada (a "lança")
        h = by.get("hand_f")
        if h:
            cx, cy = centroid(h["verts"])
            r = max(math.hypot(x - cx, y - cy) for x, y in h["verts"])
            add.setdefault("hand_f", []).append(("dt_wrap_h", [0.93, 0.9, 0.82, 1], circle(cx, cy, r * 1.15), h["weights"][0][0]))
            for k, t in enumerate((0.45, 0.65, 0.85)):
                add["hand_f"].append(("dt_wrap_%d" % k, [0.93, 0.9, 0.82, 1], band_across("arm_f_lo", rest, bones, t, 8.0, 2.2), bone_path(by, "arm_f_lo")))
    if slug == "amara":        # pulseiras de contas
        for side in ("b", "f"):
            add.setdefault("hand_" + side, []).append(("dt_beads_" + side, [0.95, 0.55, 0.1, 1],
                                                       band_across("arm_%s_lo" % side, rest, bones, 0.8, 8.0, 2.6), bone_path(by, "arm_%s_lo" % side)))
    if slug == "tama":         # tatuagens (faixas) nos braços e coxas
        for side in ("b", "f"):
            for limb, ts in (("arm_%s_up" % side, (0.35, 0.6)), ("arm_%s_lo" % side, (0.3,)), ("leg_%s_up" % side, (0.45, 0.65))):
                if limb in by:
                    for k, t in enumerate(ts):
                        add.setdefault(limb, []).append(("dt_tattoo_%s_%d" % (limb, k), [0.12, 0.09, 0.09, 1],
                                                         band_across(limb, rest, bones, t, 9.0, 1.4), bone_path(by, limb)))
    if slug == "kirra":        # prajioud no braço e mongkol na cabeça
        for side in ("b", "f"):
            limb = "arm_%s_up" % side
            if limb in by:
                add.setdefault(limb, []).append(("dt_praj_" + side, [0.85, 0.1, 0.12, 1], band_across(limb, rest, bones, 0.3, 9.5, 3.0), bone_path(by, limb)))
        if "face" in by:
            x0, y0, x1, y1 = bbox(by["face"]["verts"])
            hy = y0 + 2.5
            add.setdefault("face", []).append(("dt_mongkol", [0.96, 0.94, 0.88, 1], quad((x0 - 1.5, hy + 1.5), (x1 + 0.8, hy - 0.5), 2.6), bone_path(by, "head")))
            add["face"].append(("dt_mongkol_r", [0.85, 0.1, 0.12, 1], quad((x0 - 1.5, hy + 1.5), (x1 + 0.8, hy - 0.5), 0.9), bone_path(by, "head")))
    return add, recolor


# ---------------------------------------------------------------------------


def info():
    """{slug: (é inimigo, chapéu)} dos 79."""
    out = {}
    for c in chars.load_characters():
        out[chars.slug(c["name"])] = (False, c["hat"])
    for c in looks.enemy_rigs():
        out[c["slug"]] = (True, c["hat"])
    return out


def build(text, slug, enemy, hat):
    start, end, head, items = parse(text)
    bones, _anims = H.parse_scene(text)
    rest = H.pose_at(bones, {"length": 1.0, "tracks": {}}, 0.0)
    base = [it for it in items if not it["name"].startswith(GEN)]
    by = {it["name"]: it for it in base if it["type"] == "Polygon2D"}
    add, recolor = style_details(slug, by, bones, rest)
    f_before, f_after = face_parts(by, enemy, hat)
    out = [head]
    for it in base:
        if it["type"] != "Polygon2D":
            out.append(it["raw"])
            continue
        orig = list(it["color"])
        if it["name"] in recolor:
            it = dict(it, color=recolor[it["name"]])
        before, after = finish(it)
        out += before
        if it["name"] == "eye":
            out += f_before
        node = part_node(it) if it["name"] not in recolor else part_node(it) + "\nmetadata/base_color = Color(%s)" % ", ".join(_fc(c) for c in orig)
        out.append(node)
        out += after
        if it["name"] == "eye":
            out += f_after
        for nm, col, pts, path in add.get(it["name"], []):
            # acessório também ganha contorno e sombra (menos as faixas finas)
            acc = {"name": nm, "color": col, "verts": pts, "weights": [(path, [1.0] * len(pts))]}
            thin = nm.startswith(("dt_tattoo", "dt_cord", "dt_mongkol_r", "dt_wrap_", "dt_cuff"))
            b2, a2 = finish(acc, outline=not thin)
            out += b2
            out.append(poly_node(nm, col, pts, path))
            out += a2
    return text[:start] + "\n\n".join(out) + "\n\n" + text[end:]


def main():
    inf = info()
    files = sorted(RIGS.glob("*.tscn")) + sorted((RIGS / "enemies").glob("*.tscn"))
    for fp in files:
        enemy, hat = inf.get(fp.stem, (fp.parent != RIGS, "none"))
        fp.write_text(build(fp.read_text(encoding="utf-8"), fp.stem, enemy, hat), encoding="utf-8")
    print("%d modelos acabados" % len(files))


if __name__ == "__main__":
    main()
