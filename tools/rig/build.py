"""Pipeline completo dos rigs: Blender -> JSON -> cenas do Godot.

    blender --background --python tools/rig/build.py      # com o Blender instalado
    python tools/rig/build.py                              # com "pip install bpy" (Blender como módulo)

Etapas:
  1. blender_rig.py  — monta armatures, IK, peças e animações; salva art/rigs/punho_rigs.blend,
                       art/rigs/json/*.json e art/rigs/preview.png
  2. rig_to_godot.py — gera rigs/*.tscn (Skeleton2D + Polygon2D + AnimationPlayer) e confere a cinemática
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

try:
    import bpy  # noqa: F401
except ImportError:
    sys.exit("Este script precisa do Blender: rode com 'blender --background --python tools/rig/build.py'\n"
             "ou instale o módulo: 'pip install bpy' (Blender como biblioteca Python).")

import blender_rig  # noqa: E402
import rig_to_godot  # noqa: E402

if __name__ == "__main__":
    blender_rig.main()
    if "--check" not in sys.argv:
        sys.argv.append("--check")
    rig_to_godot.main()
