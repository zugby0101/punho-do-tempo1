"""Esquiva, bloqueio e finalização nos 79 rigs, sem o Blender.

    python tools/rig/extra_anims.py            # grava block, dodge e finisher em rigs/**/*.tscn
    python tools/rig/extra_anims.py --check    # só confere o resolvedor contra as animações do Blender

As poses-chave vêm de moves.py (defense_keys e attack_keys("finisher")), com o perfil de cada
personagem (estilo de luta, peso, altura do chute, robôs, ÉON flutuando). resolve.py interpola os
controles com as curvas do Blender e resolve o IK; as trilhas são escritas como rig_to_godot.py faz
(espaço da articulação, redução de chaves, cortes instantâneos, posição do quadril).

Com o Blender instalado, build.py gera as mesmas animações pelo caminho normal (elas estão em
moves.PLAYER_ANIMS / ENEMY_ANIMS); este script serve para as cenas já existentes no repositório.
Depois dele, rode tools/rig/hitboxes.py para gravar as hitboxes e hurtboxes das animações novas.
"""
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import looks  # noqa: E402
import moves as M  # noqa: E402
import resolve as R  # noqa: E402
import rig_to_godot as RG  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
RIGS = ROOT / "rigs"
POS_TRACK_BONES = {"pelvis"}


def profiles():
    """{caminho da cena: perfil de movimento} dos 79 rigs."""
    out = {}
    for fp in sorted(RIGS.glob("*.tscn")):
        out[fp] = M.player_profile(fp.stem)
    for c in looks.enemy_rigs():
        out[RIGS / "enemies" / ("%s.tscn" % c["slug"])] = M.enemy_profile(c["kind"], c["hat"])
    return out


def anim_block(rig, name, samples, length):
    """Texto do sub_resource Animation, no mesmo formato de rig_to_godot.build_scene."""
    bones = rig.bones
    paths = RG.bone_paths(bones)
    times = [t for t, _ in samples]
    lines = ['[sub_resource type="Animation" id="Animation_%s"]' % name, 'resource_name = "%s"' % name,
             "length = %s" % RG.f(length)]
    ti = 0
    for bn, b in bones.items():
        if bn == "root" or bn not in samples[0][1]:
            continue
        rots = RG.unwrap([fr[bn][1] for _, fr in samples])
        rots = RG.joint_space(rots, b["rot"])
        tracks = [("rotation", rots)]
        if bn in POS_TRACK_BONES:
            tracks.append(("position", [list(fr[bn][0]) for _, fr in samples]))
        for prop, vals in tracks:
            idx = RG.reduce_keys(times, vals, RG.ROT_TOL if prop == "rotation" else RG.POS_TOL)
            tk = [times[i] for i in idx]
            vv = [vals[i] for i in idx]
            if prop == "rotation":
                tk, vv = RG.snap_jumps(times, rots, tk, vv)
            lines += [
                'tracks/%d/type = "value"' % ti,
                "tracks/%d/imported = false" % ti,
                "tracks/%d/enabled = true" % ti,
                'tracks/%d/path = NodePath("Skeleton2D/%s:%s")' % (ti, paths[bn], prop),
                "tracks/%d/interp = 1" % ti,
                "tracks/%d/loop_wrap = true" % ti,
                "tracks/%d/keys = {" % ti,
                '"times": PackedFloat32Array(%s),' % ", ".join(RG.f(t) for t in tk),
                '"transitions": PackedFloat32Array(%s),' % ", ".join("1" for _ in tk),
                '"update": 0,',
                '"values": [%s]' % ", ".join(RG.f(v) if prop == "rotation" else RG.vec(v) for v in vv),
                "}",
            ]
            ti += 1
    return "\n".join(lines)


def put_anim(text, name, block):
    """Insere (ou troca) a animação na cena e no AnimationLibrary_rig."""
    sid = "Animation_%s" % name
    had = ('id="%s"]' % sid) in text
    text = re.sub(r'\[sub_resource type="Animation" id="%s"\]\n.*?\n\n(?=\[)' % sid, "", text, flags=re.S)
    lib = '[sub_resource type="AnimationLibrary" id="AnimationLibrary_rig"]'
    text = text.replace(lib, block + "\n\n" + lib, 1)
    if not had:
        m = re.search(re.escape(lib) + r'\n_data = \{\n(.*?)\n\}', text, re.S)
        entries = m.group(1) + ',\n"%s": SubResource("%s")' % (name, sid)
        text = text[:m.start(1)] + entries + text[m.end(1):]
        text = re.sub(r"\[gd_scene load_steps=(\d+)", lambda mm: "[gd_scene load_steps=%d" % (int(mm.group(1)) + 1), text, count=1)
    return text


def check(profs):
    """Erro máximo do resolvedor contra o Blender nas animações de golpe que já existem."""
    worst = (0.0, 0.0, "")
    for fp, pr in profs.items():
        text = fp.read_text(encoding="utf-8")
        for an in ("jab", "kick", "slam"):
            er, ep, where = R.validate(text, an, M.build(an, pr))
            if er > worst[0]:
                worst = (er, ep, "%s/%s %s" % (fp.stem, an, where))
    return worst


def main():
    profs = profiles()
    if "--check" in sys.argv:
        er, ep, where = check(profs)
        print("resolvedor x Blender (jab, chute, slam nos 79 rigs): erro máx. %.4f rad, %.3f px (%s)" % (er, ep, where))
        return
    for fp, pr in profs.items():
        text = fp.read_text(encoding="utf-8")
        rig = R.Rig(text)
        for an in M.NEW_ANIMS:
            mv = M.build(an, pr)
            samples = R.sample_move(rig, mv)
            text = put_anim(text, an, anim_block(rig, an, samples, mv["length"]))
        fp.write_text(text, encoding="utf-8")
        print(fp.relative_to(ROOT), "+", ", ".join(M.NEW_ANIMS))
    print("%d rigs" % len(profs))


if __name__ == "__main__":
    main()
