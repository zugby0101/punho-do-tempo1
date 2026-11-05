# Rigs 2D dos lutadores (Blender + Godot 4 + Python)

Os 14 lutadores jogáveis têm um **rig 2D de esqueleto** feito no Blender por script e
convertido em cenas do Godot 4. No jogo, o rig substitui o desenho procedural dos
jogadores (tecla **V** no título alterna entre "Rig 2D" e "Clássico").

## Como gerar

```bash
pip install bpy                    # Blender 5.1 como módulo Python (ou use o Blender instalado)
python tools/rig/build.py          # ou: blender --background --python tools/rig/build.py
```

Isso gera:

| Arquivo | O que é |
|---|---|
| `art/rigs/punho_rigs.blend` | os 14 rigs no Blender, editáveis (armatures, IK, malhas, Actions) |
| `art/rigs/preview.png` | prévia renderizada no Blender (Cycles) |
| `art/rigs/json/*.json` | ossos, peças e animações já resolvidas pelo Blender |
| `rigs/*.tscn` | cenas do Godot: `Skeleton2D` + `Bone2D` + `Polygon2D` + `AnimationPlayer` |

Para ver todos os rigs animando no Godot: abra `scenes/rig_viewer.tscn` e aperte **F6**
(◄ ► trocam a animação, Espaço pausa).

## Como o rig é montado (`blender_rig.py`)

- **Esqueleto (15 ossos):** `root`, `pelvis`, `spine`, `head`, braço de trás e da frente
  (`arm_*_up`, `arm_*_lo`), pernas (`leg_*_up`, `leg_*_lo`), pés (`foot_*`, sem herdar rotação,
  então ficam sempre retos) e `weapon` (encaixe da arma, com ângulo próprio).
- **Controles do animador:** alvos de IK para mãos e pés (`ctrl_hand_*`, `ctrl_foot_*`) e
  alvos de polo para cotovelos e joelhos (`pole_*`). As animações animam só os controles,
  o quadril e a inclinação do tronco — o IK do Blender resolve braços e pernas.
- **Peças:** malhas planas coloridas presas aos ossos, com as cores e o penteado de cada
  personagem (lidos de `scripts/characters.gd` por `chars.py`, sem duplicar dados).
- **16 animações:** `idle`, `walk` (loops) e `jab`, `cross`, `upper`, `kick`, `swing`, `slam`,
  `charge` (golpes: o tempo 0→1 da animação é a fase do golpe −1→1, preparação → acerto),
  mais as poses `jump`, `jumpkick`, `special`, `throw`, `dive`, `hurt`, `down`.
  As poses vêm de `poses.py`, portado do desenho original (`fighter.gd`).
- O script descobre sozinho as convenções de eixo do Blender e escolhe o ângulo de polo de
  cada membro testando qual reproduz a pose de repouso (erro 0 px).

## Como vira cena do Godot (`rig_to_godot.py`)

- `Bone2D` com `rest` igual à pose de repouso do Blender.
- As peças são `Polygon2D` com **skinning** no `Skeleton2D` (peso 1 no osso da peça), todas
  num nó `Parts` na ordem de desenho — assim a ordem das camadas não depende de `z_index`
  (que quebraria a ordenação por profundidade entre os lutadores).
- `WeaponSlot` recebe o transform do osso `weapon` por um `RemoteTransform2D` e desenha a arma.
- `--check` refaz a cinemática direta dos dados exportados e confere se mãos e pés chegam
  aos alvos do jogo em todas as amostras.

## Editar ou criar animações

Abra `art/rigs/punho_rigs.blend`, selecione a armature de um personagem e mova os controles
de IK (`ctrl_*`) nas Actions `<NOME>_<animação>`. Para que a mudança vá para o jogo
de forma reprodutível, altere a pose em `poses.py` e rode `build.py` de novo.
