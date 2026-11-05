"""Converte os rigs exportados pelo Blender (art/rigs/json/*.json) em cenas do Godot 4.

    python tools/rig/rig_to_godot.py            # gera rigs/<personagem>.tscn
    python tools/rig/rig_to_godot.py --check    # também confere a cinemática (mãos/pés nos alvos)

Cada cena tem:
  Rig_<NOME> (Node2D)
    Skeleton2D -> Bone2D (root, pelvis, spine, head, braços, pernas, pés, arma)
    Parts      -> Polygon2D na ordem de desenho, com skinning no Skeleton2D (peso 1 no osso da peça)
               -> WeaponSlot (Node2D, recebe o transform do osso "weapon" via RemoteTransform2D)
    AnimationPlayer com as 16 animações (rotação de todos os ossos + posição do quadril)
"""
import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import poses as P  # noqa: E402

POS_TRACK_BONES = {"pelvis", "hourglass", "orb_0", "orb_1", "orb_2"}  # ossos com trilha de posição

ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / "art" / "rigs" / "json"
DST = ROOT / "rigs"


def f(x):
    return ("%.5f" % x).rstrip("0").rstrip(".") if abs(x) > 1e-9 else "0"


def vec(v):
    return "Vector2(%s, %s)" % (f(v[0]), f(v[1]))


def color(c):
    return "Color(%s, %s, %s, %s)" % tuple(f(x) for x in c)


def bone_paths(bones):
    paths = {}

    def path(nm):
        if nm in paths:
            return paths[nm]
        par = bones[nm]["parent"]
        paths[nm] = nm if par is None else path(par) + "/" + nm
        return paths[nm]

    for nm in bones:
        path(nm)
    return paths


def unwrap(values):
    out = []
    for v in values:
        if out:
            while v - out[-1] > math.pi:
                v -= 2 * math.pi
            while v - out[-1] < -math.pi:
                v += 2 * math.pi
        out.append(v)
    return out


def reduce_keys(times, values, tol):
    """Redução de keyframes (Douglas-Peucker no tempo): mantém só as chaves necessárias para
    reproduzir a curva amostrada dentro da tolerância. Valores: float ou [x, y]."""
    n = len(times)
    if n <= 2:
        return list(range(n))

    def dist(i, a, b):
        tt = (times[i] - times[a]) / max(times[b] - times[a], 1e-9)
        va, vb, vi = values[a], values[b], values[i]
        if isinstance(vi, (list, tuple)):
            return max(abs(va[c] + (vb[c] - va[c]) * tt - vi[c]) for c in range(len(vi)))
        return abs(va + (vb - va) * tt - vi)

    keep = {0, n - 1}
    stack = [(0, n - 1)]
    while stack:
        a, b = stack.pop()
        best, bi = 0.0, -1
        for i in range(a + 1, b):
            d = dist(i, a, b)
            if d > best:
                best, bi = d, i
        if bi >= 0 and best > tol:
            keep.add(bi)
            stack += [(a, bi), (bi, b)]
    return sorted(keep)


ROT_TOL = 0.004   # rad (~0,2°)
POS_TOL = 0.06    # px


def build_scene(rig):
    bones = rig["bones"]
    paths = bone_paths(bones)
    subs = []  # (id, texto)
    anim_ids = []
    fx_ids = []
    for an, a in rig["animations"].items():
        aid = "Animation_%s" % an
        (fx_ids if a.get("fx") else anim_ids).append((an, aid))
        # loops: segundos; golpes: 0..1 = fase -1..1; poses paradas: 0
        times = [k["t"] for k in a["keys"]]
        lines = ['[sub_resource type="Animation" id="%s"]' % aid, 'resource_name = "%s"' % an,
                 "length = %s" % f(max(a["length"], 0.001))]
        if a["loop"]:
            lines.append("loop_mode = 1")
        ti = 0
        for bn in bones:
            if bn == "root" or bn not in a["keys"][0]["bones"]:
                continue
            rots = unwrap([k["bones"][bn]["rot"] for k in a["keys"]])
            tracks = [("rotation", rots, 3)]
            if bn in POS_TRACK_BONES:
                tracks.append(("position", [k["bones"][bn]["pos"] for k in a["keys"]], 1))
            for prop, vals, interp in tracks:
                idx = reduce_keys(times, vals, ROT_TOL if prop == "rotation" else POS_TOL)
                tk = [times[i] for i in idx]
                vals = [vals[i] for i in idx]
                lines += [
                    'tracks/%d/type = "value"' % ti,
                    "tracks/%d/imported = false" % ti,
                    "tracks/%d/enabled = true" % ti,
                    'tracks/%d/path = NodePath("Skeleton2D/%s:%s")' % (ti, paths[bn], prop),
                    "tracks/%d/interp = %d" % (ti, interp),
                    "tracks/%d/loop_wrap = true" % ti,
                    "tracks/%d/keys = {" % ti,
                    '"times": PackedFloat32Array(%s),' % ", ".join(f(t) for t in tk),
                    '"transitions": PackedFloat32Array(%s),' % ", ".join("1" for _ in tk),
                    '"update": 0,',
                    '"values": [%s]' % ", ".join(f(v) if prop == "rotation" else vec(v) for v in vals),
                    "}",
                ]
                ti += 1
        subs.append((aid, "\n".join(lines)))
    lib = ['[sub_resource type="AnimationLibrary" id="AnimationLibrary_rig"]', "_data = {"]
    lib.append(",\n".join('"%s": SubResource("%s")' % (an, aid) for an, aid in anim_ids))
    lib.append("}")
    subs.append(("AnimationLibrary_rig", "\n".join(lib)))
    if fx_ids:
        subs.append(("AnimationLibrary_fx", "\n".join(['[sub_resource type="AnimationLibrary" id="AnimationLibrary_fx"]', "_data = {",
                     ",\n".join('"%s": SubResource("%s")' % (an, aid) for an, aid in fx_ids), "}"])))

    out = ['[gd_scene load_steps=%d format=3]' % (len(subs) + 2), "",
           '[ext_resource type="Script" path="res://scripts/rig_weapon.gd" id="1_weapon"]', ""]
    for _id, txt in subs:
        out += [txt, ""]
    out += ['[node name="Rig_%s" type="Node2D"]' % rig["slug"], 'metadata/character = "%s"' % rig["name"], ""]
    out += ['[node name="Skeleton2D" type="Skeleton2D" parent="."]', ""]
    for bn, b in bones.items():
        par = "Skeleton2D" + ("/" + paths[b["parent"]] if b["parent"] else "")
        c, s = math.cos(b["rot"]), math.sin(b["rot"])
        out += ['[node name="%s" type="Bone2D" parent="%s"]' % (bn, par),
                "position = %s" % vec(b["pos"]),
                "rotation = %s" % f(b["rot"]),
                "rest = Transform2D(%s, %s, %s, %s, %s, %s)" % (f(c), f(s), f(-s), f(c), f(b["pos"][0]), f(b["pos"][1])),
                "auto_calculate_length_and_angle = false",
                "length = %s" % f(max(b["length"], 1.0)),
                "bone_angle = 0.0", ""]
    weapon_path = "Skeleton2D/" + paths["weapon"]
    out += ['[node name="WeaponRemote" type="RemoteTransform2D" parent="%s"]' % weapon_path,
            'remote_path = NodePath("%sParts/WeaponSlot")' % ("../" * (len(paths["weapon"].split("/")) + 2)), ""]
    out += ['[node name="Parts" type="Node2D" parent="."]', ""]
    parts = sorted(rig["parts"], key=lambda p: p["z"])  # sort estável: mantém a ordem dentro da camada
    weapon_done = False
    for p in parts:
        if not weapon_done and p["z"] >= 9:
            out += ['[node name="WeaponSlot" type="Node2D" parent="Parts"]', 'script = ExtResource("1_weapon")', ""]
            weapon_done = True
        n = len(p["rest_polygon"])
        weights = p.get("weights") or [p["bone"]] * n
        bone_arr = []
        for bn in dict.fromkeys(weights):  # ossos na ordem em que aparecem
            bone_arr.append('NodePath("%s"), PackedFloat32Array(%s)' % (paths[bn], ", ".join("1" if w == bn else "0" for w in weights)))
        out += ['[node name="%s" type="Polygon2D" parent="Parts"]' % p["name"],
                "color = %s" % color(p["color"]),
                'skeleton = NodePath("../../Skeleton2D")',
                "polygon = PackedVector2Array(%s)" % ", ".join("%s, %s" % (f(x), f(y)) for x, y in p["rest_polygon"]),
                "bones = [%s]" % ", ".join(bone_arr),
                ""]
    if not weapon_done:
        out += ['[node name="WeaponSlot" type="Node2D" parent="Parts"]', 'script = ExtResource("1_weapon")', ""]
    out += ['[node name="AnimationPlayer" type="AnimationPlayer" parent="."]', "libraries = {",
            '"": SubResource("AnimationLibrary_rig")', "}", ""]
    if fx_ids:
        # efeitos (capa, halo, ampulheta): tocam sozinhos em loop, por cima da pose do corpo
        out += ['[node name="FXPlayer" type="AnimationPlayer" parent="."]', "libraries = {",
                '"": SubResource("AnimationLibrary_fx")', "}", 'autoplay = "fx"', ""]
    return "\n".join(out)


def fk(bones, frame, name):
    """Cinemática direta a partir dos dados locais (o mesmo cálculo que o Godot fará)."""
    chain = []
    n = name
    while n is not None:
        chain.append(n)
        n = bones[n]["parent"]
    x = y = a = 0.0
    for n in reversed(chain):
        loc = frame[n] if frame and n in frame else bones[n]
        px, py = loc["pos"]
        x, y = x + px * math.cos(a) - py * math.sin(a), y + px * math.sin(a) + py * math.cos(a)
        a += loc["rot"]
    return x, y, a


def check(rig):
    """Confere, com a cinemática direta dos dados exportados (o mesmo cálculo do Godot), se mãos
    e pés chegam aos alvos de IK do Blender — descontando quando o alvo está além do alcance."""
    bones = rig["bones"]
    reach = {"hf": ("arm_f_lo", P.FOREARM, P.UPPER_ARM), "hb": ("arm_b_lo", P.FOREARM, P.UPPER_ARM),
             "ff": ("leg_f_lo", P.SHIN, P.THIGH), "bf": ("leg_b_lo", P.SHIN, P.THIGH)}
    worst = (0.0, "")
    for an, a in rig["animations"].items():
        if a.get("fx"):
            continue
        for key in a["keys"]:
            for target, (bone, ln, up_ln) in reach.items():
                x, y, ang = fk(bones, key["bones"], bone)
                tip = (x + math.cos(ang) * ln, y + math.sin(ang) * ln)
                ux, uy, _ = fk(bones, key["bones"], bones[bone]["parent"])
                want = key["targets"][target]
                expected = max(0.0, math.hypot(want[0] - ux, want[1] - uy) - (ln + up_ln))
                err = math.hypot(tip[0] - want[0], tip[1] - want[1]) - expected
                if err > worst[0]:
                    worst = (err, "%s/%s/%.2f" % (an, target, key["t"]))
    return worst


def main():
    DST.mkdir(exist_ok=True)
    (DST / "enemies").mkdir(exist_ok=True)
    files = sorted(SRC.glob("*.json")) + sorted((SRC / "enemies").glob("*.json"))
    if not files:
        sys.exit("Nenhum rig em %s. Rode antes: blender --background --python tools/rig/blender_rig.py" % SRC)
    for fp in files:
        rig = json.loads(fp.read_text(encoding="utf-8"))
        sub = "enemies/" if rig.get("group") == "enemies" else ""
        (DST / ("%s%s.tscn" % (sub, rig["slug"]))).write_text(build_scene(rig), encoding="utf-8")
        msg = "rigs/%s%s.tscn" % (sub, rig["slug"])
        if "--check" in sys.argv:
            err, where = check(rig)
            msg += "  (erro máx. da cinemática além do alcance do membro: %.2f px em %s)" % (err, where or "-")
        print(msg)


if __name__ == "__main__":
    main()
