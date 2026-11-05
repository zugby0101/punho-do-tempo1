# Rigs 2D dos lutadores (Blender + Godot 4 + Python)

Todos os personagens têm um **rig 2D de esqueleto** feito no Blender por script e
convertido em cenas do Godot 4: os **14 lutadores** e os **65 inimigos** — em cada uma das
13 eras (12 + a fase secreta), os 3 tiers (★, ★★, ★★★), o sub-chefe e o chefe (incluindo o ÉON).
No jogo, o rig substitui o desenho procedural (tecla **V** no título alterna entre
"Rig 2D" e "Clássico").

## Como gerar

```bash
pip install bpy                    # Blender 5.1 como módulo Python (ou use o Blender instalado)
python tools/rig/build.py          # ou: blender --background --python tools/rig/build.py
```

Isso gera:

| Arquivo | O que é |
|---|---|
| `art/rigs/punho_rigs.blend` | os 14 lutadores no Blender, editáveis (armatures, IK, malhas, Actions) |
| `art/rigs/punho_rigs_inimigos.blend` | os 65 inimigos, sub-chefes e chefes (uma linha por era) |
| `art/rigs/preview.png`, `preview_inimigos.png` | prévias renderizadas no Blender (Cycles) |
| `art/rigs/json/` | dados intermediários (ossos, peças, animações resolvidas) — não vão para o git |
| `rigs/*.tscn` | lutadores: `Skeleton2D` + `Bone2D` + `Polygon2D` + `AnimationPlayer` |
| `rigs/enemies/<era>_<tipo>.tscn` | inimigos, ex.: `crusade_boss.tscn`, `void_secret_boss.tscn` |

Para gerar só um grupo: `python tools/rig/build.py --only=players` ou `--only=enemies`.
O pipeline completo (79 rigs + prévias) leva cerca de 2 minutos.

Para ver todos os rigs animando no Godot: abra `scenes/rig_viewer.tscn` e aperte **F6**
(◄ ► trocam a animação, ▲ ▼ trocam a página — lutadores ou os inimigos de cada era —, Espaço pausa).

No jogo, o brilho na mão que avisa o golpe de um inimigo é desenhado no encaixe da mão
do rig (`WeaponSlot`), como no desenho original.

## Como o rig é montado (`blender_rig.py`)

- **Esqueleto (15 ossos):** `root`, `pelvis`, `spine`, `head`, braço de trás e da frente
  (`arm_*_up`, `arm_*_lo`), pernas (`leg_*_up`, `leg_*_lo`), pés (`foot_*`, sem herdar rotação,
  então ficam sempre retos) e `weapon` (encaixe da arma, com ângulo próprio).
- **Controles do animador:** alvos de IK para mãos e pés (`ctrl_hand_*`, `ctrl_foot_*`) e
  alvos de polo para cotovelos e joelhos (`pole_*`). As animações animam só os controles,
  o quadril e a inclinação do tronco — o IK do Blender resolve braços e pernas.
- **Peças:** malhas planas coloridas presas aos ossos, com as cores, o penteado e o chapéu
  de cada personagem. Os lutadores vêm de `scripts/characters.gd` (`chars.py`) e os inimigos
  de `scripts/stages.gd` (`looks.py`) — sem duplicar dados. Os chefes ganham capa, e os
  41 penteados, chapéus e capacetes do jogo foram portados para polígonos.
- **16 animações nos lutadores** e as **11 que os inimigos usam** (`idle`, `walk`, `jab`, `kick`,
  `slam`, `charge`, `special`, `throw`, `swing`, `hurt`, `down`). Lista completa: `idle`, `walk` (loops) e `jab`, `cross`, `upper`, `kick`, `swing`, `slam`,
  `charge` (golpes: o tempo 0→1 da animação é a fase do golpe −1→1, preparação → acerto),
  mais as poses `jump`, `jumpkick`, `special`, `throw`, `dive`, `hurt`, `down`.
  As poses vêm de `poses.py`, portado do desenho original (`fighter.gd`).
- O script descobre sozinho as convenções de eixo do Blender e escolhe o ângulo de polo de
  cada membro testando qual reproduz a pose de repouso (erro 0 px).

## Efeitos animados (capas, halo, ÉON, cabelo e faixas)

Alguns acessórios têm **ossos de efeito** e uma Action própria (`<rig>_fx`, um loop de ~4,2 s),
que no `.blend` toca por cima do corpo numa faixa de NLA e no Godot vira um segundo
`AnimationPlayer` (`FXPlayer`, com `autoplay`). Assim eles se movem sempre, inclusive durante
golpes e tombos, seguindo o tronco ou a cabeça:

| Efeito | Ossos | Movimento |
|---|---|---|
| Capas dos chefes | `cape_1` → `cape_2` (corrente presa ao tronco) | a barra ondula ~8 px; o topo fica preso nos ombros (pesos por vértice) |
| Halo da IA Aurora | `halo` | o anel de luz gira (pontos em rastro de cometa para o giro aparecer) |
| ÉON, o Eterno | `hourglass`, `eon_ring`, `orb_0..2` | a ampulheta flutua 2 px, o anel gira e as 3 esferas orbitam em elipse 18×8 |
| Rabo de cavalo (Valentina) | `tail` | balança ~6 px para os lados, com pivô na nuca |
| Faixa do Kai | `band_tail` | a ponta da faixa tremula ~5 px |
| Faixa dos ninjas (Ninja, Hanzo, Eco Veloz) | `ninja_tail` | a ponta da faixa tremula ~5 px |

As frequências são múltiplas de 1,5 rad/s para que todos os efeitos fechem o loop juntos,
sem salto quando ele recomeça.

## Como vira cena do Godot (`rig_to_godot.py`)

- `Bone2D` com `rest` igual à pose de repouso do Blender.
- Peças deformadas por mais de um osso (a capa) recebem os pesos de cada vértice.
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
