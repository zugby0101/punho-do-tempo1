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
| `rigs/*.tscn` | lutadores: `Skeleton2D` + `Bone2D` + `Polygon2D` + `AnimationPlayer` + `AnimationTree` |
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
- **Animações de combate (`moves.py`):** poses-chave com a curva de suavização de cada trecho
  (interpolação do Blender: EXPO, BACK, SINE, QUAD, CONSTANT...). O Blender interpola, resolve o
  IK e o resultado é amostrado quadro a quadro. Lutadores têm 18 animações e inimigos 13.
- O script descobre sozinho as convenções de eixo do Blender e escolhe o ângulo de polo de
  cada membro testando qual reproduz a pose de repouso (erro 0 px).

## Animações de combate (`moves.py`)

Princípios de animação aplicados em todas: **antecipação**, golpe acelerado até o **impacto**,
**excesso** (follow-through), sustentação, **recuperação com assentamento**, **arcos** (balanço da
arma, gancho), **contrapeso** (braços no chute), **atraso da cabeça** em relação ao tronco e **peso**
(personagens pesados preparam mais cedo e mais fundo, e assentam com menos excesso).

**Sincronia com a lógica do jogo.** Nos golpes, o tempo da animação (0→1) segue o progresso real
do ataque, calculado em `fighter.gd` (`rig_anim()`):

| Trecho do ataque no jogo | Tempo na animação | O que acontece |
|---|---|---|
| preparação (startup) | 0,00 → 0,30 | antecipação |
| janela de acerto (active) | 0,30 → 0,42 | **impacto exatamente em 0,30** + excesso + sustentação |
| recuperação (recovery) | 0,42 → 1,00 | volta à guarda e assenta |

Assim o quadro de impacto sempre coincide com o primeiro quadro em que o golpe acerta, e a
pausa de impacto (hitstop) congela a pose no ponto certo. Pulo, voadora, dano, queda e levantada
também seguem o estado real (velocidade vertical, tempo de atordoamento etc.).

**Animações:** `idle`, `walk` (ciclo com contato, descida, passagem e subida, braços em oposição),
`jab`, `cross` (giro de quadril, calcanhar de trás sobe), `upper` (agacha e sobe), `kick` (recolhe,
estende, recolhe, apoia), `swing` (arco por cima da cabeça), `slam`, `charge`, `throw`, `special`
(giro), `dive`, `jump` (impulso, encolhe, aterrissa), `jumpkick`, `hurt`, `fall`, `down`, `getup`.

**Personalidade (perfis):**

| Quem | Idle e jeito de lutar |
|---|---|
| Mateus | ginga da capoeira (troca a base, braços cruzando o rosto), chute alto |
| Valentina, Luca, Kofi | quique de boxeador; Kofi com a mão da frente mais à frente |
| Jake, Dmitri, Amara | postura curvada de luta, transferindo o peso; golpes pesados |
| Itzel | quique acrobático, chute alto |
| Oksana | quique alegre do hopak, chute muito alto |
| Amélie | postura alta e leve do savate, chute alto |
| Kai | base baixa e firme do caratê, só a respiração |
| Mei | mão aberta à frente, peso balançando (kung fu) |
| Tama | base larga do haka, com pisada |
| Kirra | ritmo do muay thai marcado com a perna, guarda alta |
| Inimigos ★ | brigão desleixado, chute baixo |
| Inimigos ★★ e ninjas | ágeis e agachados |
| Inimigos ★★★ | respiração pesada, braços caídos, golpes lentos |
| Sub-chefes | quique confiante |
| Chefes | peito estufado, balanço lento e ameaçador |
| Robôs (visor/robot) | movimentos mecânicos, em degraus |
| ÉON | **flutua** com as pernas soltas |

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
| Tranças (Oksana e Itzel) | `braid` | balançam ~5 px, mais devagar que o rabo de cavalo |
| Cabelo comprido (Kirra) | `hair_long` | ondula de leve, ~3,5 px |

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


## AnimationTree e BlendSpaces

`rig_to_godot.py` gera em cada cena um `AnimationTree` (raiz `AnimationNodeStateMachine`, processo
manual: o lutador chama `advance()` no mesmo passo do jogo):

| Estado | Nó | Pontos | Parâmetros |
|---|---|---|---|
| `locomotion` | BlendSpace1D (sync) → TimeScale | idle 0, walk 1 | `locomotion/blend/blend_position`, `locomotion/speed/scale` |
| `strike` | BlendSpace2D (discreto) → TimeScale 0 → TimeSeek | golpes em força (x) × altura (y) | `strike/blend/blend_position`, `strike/seek/seek_request` |
| `air` | BlendSpace1D → TimeScale 0 → TimeSeek | jump 0, jumpkick 1 | `air/blend/...`, `air/seek/...` |
| `damage` | BlendSpace1D → TimeScale 0 → TimeSeek | hurt 0, fall 1 | `damage/blend/...`, `damage/seek/...` |
| `floor` | BlendSpace1D → TimeScale 0 → TimeSeek | down 0, getup 1 | `floor/blend/...`, `floor/seek/...` |

Transições entre todos os estados, com crossfade pelo destino (golpe 0,04 s, dano 0,03 s, pulo
0,08 s, chão 0,10 s, locomoção 0,12 s). Inimigos só têm os estados das animações que possuem (sem
`air`). Os pontos do BlendSpace2D ficam em `metadata/strike_points` e a lista de estados em
`metadata/states` do nó. O jogo (`fighter.gd`, `_drive_tree`) escolhe o estado e a posição no
BlendSpace e passa a fase do golpe (0..1) ao `TimeSeek`; sem a árvore, volta ao `seek` do AnimationPlayer.

**Rotações no espaço da articulação.** O AnimationTree mistura rotações como números, então cada
trilha é colocada na janela (repouso − π, repouso + π] do osso (`joint_space`). Trilhas que passam
por trás da articulação viram cortes instantâneos (`snap_jumps`) em vez de varrer o membro por
dentro do corpo. As trilhas usam interpolação **Linear**: a "Linear Angle" do Godot 4.3 mistura
errado fora de ±π.

Verificações feitas: a pose do AnimationTree é idêntica à do AnimationPlayer em 4.853 poses dos 79
rigs; nos 44.520 quadros de crossfade testados (todos os pares de estados), nenhum osso gira mais que
~1 rad por quadro de 10 ms.


## Hitboxes sincronizadas com a animação (`hitboxes.py`)

```bash
python tools/rig/hitboxes.py            # grava metadata/hitboxes nas 79 cenas (build.py já roda no fim)
python tools/rig/hitboxes.py --check    # só confere; sai com erro se algo estiver fora de sincronia
```

Não precisa do Blender: lê as cenas do Godot (ossos em repouso + trilhas), refaz a cinemática direta
com interpolação linear (a mesma do Godot) e, em cada golpe (`jab`, `cross`, `upper`, `kick`,
`jumpkick`, `swing`, `slam`, `charge`, `throw`, `special`, `dive`), descobre:

| Dado | O que é |
|---|---|
| `bone` | a ponta que acerta: a que mais avança no trecho de acerto (punho da frente/de trás, pé, cabeça...) |
| `on`, `off` | janela de contato (u = 0..1): enquanto a ponta está a pelo menos 75% do alcance máximo (no gancho, da altura) |
| `pts` | trajetória da ponta, 60 amostras por animação, em px do rig (origem nos pés, y para baixo) |
| `peak`, `r` | avanço da ponta no impacto e raio da hitbox (punho 10, pé 12, tronco 16, cabeça 14) |
| `wpn`, `won`, `woff` | golpes armados (`swing`, `slam`): base e ângulo da arma e a janela da ponta da arma |

No jogo (`fighter.gd` → `hitbox_now`), em golpes normais, na voadora e nos especiais:

- a hitbox só existe enquanto a animação está na janela de contato (`on`..`off`), além da janela do jogo;
- vai de 15 px atrás até `reach × (avanço atual da ponta / peak)` à frente, ou seja, o alcance de
  equilíbrio do golpe acompanhando o quanto o membro está esticado naquele quadro;
- na vertical, cobre só a faixa `altura da ponta ± r`, que precisa cruzar a hurtbox do alvo
  (16 × 100 px, vezes a escala do corpo, a partir da altura do pulo dele);
- armado, a ponta é a base da arma + `len` da arma no ângulo do osso `weapon`.

**Especiais.** Os 12 especiais corpo a corpo dos lutadores usam a mesma hitbox: o tempo de cada um
continua o de `player.gd` (giros, rajadas, investidas, subidas e mergulhos), mas a área que acerta vem
da animação que está na tela.

| Especial | Como a animação manda na hitbox |
|---|---|
| giros (Mateus, Dmitri), Tornado de Chutes (Luca), especial básico | acerta dos dois lados (o lutador vira), na altura do pé/punho |
| rajadas (Valentina, Amélie) | só acerta enquanto o punho/pé está esticado; na volta (fase 0,3) não |
| Esmagador Texano (Jake) | onda de choque dos dois lados, só em quem está no chão |
| Tope Suicida (Itzel) | corpo deitado (`BODY_ROT`, 0,45π): os braços esticados viram a ponta que acerta à frente |
| Chute da Fênix (Mei), Joelhada Voadora (Kirra) | a voadora aparece com a perna esticada (u = 1) e acerta na altura do pé |
| Chute do Hopak (Oksana), Punho do Trovão (Kofi), Investida Haka (Tama) | na altura do pé/punho/ombro enquanto sobe ou avança |

**Projéteis.** Saem da mão no quadro de soltura da animação (o mesmo quadro de impacto, u = 0,30 —
`fighter.gd` → `_on_release` / `release_point`) e têm hitbox vertical igual ao que é desenhado:

| Projétil | Soltura | Hitbox |
|---|---|---|
| Onda Ki (Kai) | o soco prepara de verdade por 0,16 s e a bola nasce no punho, na altura dele | bola: altura do centro ± 18 px |
| Onda Sísmica (Amara) | os braços sobem e descem por 0,3 s; as duas ondas nascem onde os punhos batem no chão | pedras: do chão até 34 px (dá para pular por cima) |
| Arma arremessada (todos) | a arma fica na mão na preparação e sai da mão no quadro de soltura do `throw` | arma girando: altura ± metade do comprimento |
| Orbes do ÉON | saem da mão no quadro de soltura do `throw`, na altura da mão (que flutua) | bola: altura do centro ± 18 px |

O `--check` confere que o ponto de soltura de cada rig está à frente e na altura da mão (ou dos punhos no
chão, no slam) e que a Onda Ki acerta um alvo parado no chão.
O `--check` também simula cada especial (lido de `characters.gd`) no quadro em que o jogo confere o acerto.

O `--check` confere em todos os 79 rigs que o impacto da animação cai no começo da janela de acerto
do jogo (u = 0,30) e simula os golpes do jogo (alcances e armas reais): cada um precisa ainda acertar
um alvo parado a 90% do alcance em algum quadro da janela.

**Armas no chão.** A caixa da arma caída é exatamente o que está desenhado (`Weapons.extent` /
`Weapons.bounds`: cabo, lâmina, pá do remo, ponta da lança, lâmina da foice...), deitada no chão ou
girando enquanto quica.

- **Pegar:** a mão precisa encostar no **cabo** desenhado (`weapon_item.gd` → `grip_box`). A mão é a da
  frente na guarda (primeiro quadro do `jab` do rig, `fighter.gd` → `grab_box`), do meio do antebraço até
  o punho, abaixando até o chão — então é preciso estar de frente para a arma, do lado do cabo. Dá para
  agarrar a arma no ar quando o cabo passa na altura da mão. Entre várias, pega a mais próxima.
- **Caindo machuca:** caindo a mais de 300 px/s (do céu, ou solta por quem foi derrubado), a caixa da arma
  acerta quem estiver embaixo (4 a 12 de dano conforme a velocidade; derruba acima de 700 px/s) e
  ricocheteia. Não machuca quem a soltou, quem a arremessou nem quem já foi atingido. A arma de quem é
  derrubado voa na direção do golpe (antes voltava para quem bateu).
- **Chutar:** a ponta do golpe é seguida quadro a quadro (`_sweep_items`, do u do quadro anterior até o
  atual): armas no chão tocadas por ela são chutadas para o lado do golpe — o pé que sobe do chão no
  chute, os punhos do slam, a ponta da arma no golpe armado. Socos passam por cima.
- F3: caixa da arma em amarelo (vermelho enquanto cai machucando), cabo em branco, mão em amarelo.

**Caixas quebráveis.** A hurtbox da caixa é a caixa desenhada (52 × 50 px), balançando junto quando
apanha, mais 8 px de folga acima da tampa (`crate.gd` → `hurt_rect`; sem ela, o jab de quem é grande —
Jake, Dmitri, Kofi, Tama... — passaria por cima da tampa). Qualquer alvo pode ter `hurt_rect()`;
lutadores usam a hurtbox do corpo. A caixa racha conforme o dano e, no golpe final, deixa de ser
atingível e se desmonta em tábuas que voam na direção do golpe (0,45 s). O `--check` confere, com o
tamanho real de cada lutador, que jab, cross, chute e golpe armado quebram a caixa.

**Comidas.** A área de coleta é a comida desenhada no quadro atual (`pickup.gd` → `pick_rect`: frango no
prato 40 × 28 px, maçã 20 × 28 px), subindo e descendo com o balanço. A comida é pega quando a hurtbox
do lutador encosta nela (antes: ±30 px do centro e só com o lutador a até 10 px do chão). Ao aparecer
— de uma caixa quebrada ou no meio da fase — ela salta 34 px para fora (0,35 s), junto com as tábuas,
e a área acompanha o salto. F3 mostra a área em azul-claro.

**Hurtbox animada (inimigos e jogadores).** Os 79 rigs têm `metadata/hurtboxes`, gravada pelo
`hitboxes.py`: a caixa da **silhueta desenhada** (cada vértice das peças do corpo — cabelo e chapéu
incluídos, capas e efeitos de fora — deformado pelos ossos como o Godot faz) a cada 1/30 de `idle`,
`walk`, `hurt`, `jump`, `jumpkick`, `dive` e de cada golpe. No jogo (`fighter.gd` → `hurt_rect`), ela
segue a animação que está na tela: encolhe na dor, cresce quando o braço ou o pé estica, encolhe no pulo
e na voadora, deita no mergulho e sobe quando o ÉON flutua. Os corpos têm de 84 a 103 px de altura
(a caixa fixa tinha 100), conforme o personagem e o penteado.

- **Gancho:** no quadro de impacto o punho já passou do queixo, então a hitbox do `upper` cobre o
  caminho da ponta nos últimos 0,04 da animação (`SWEPT`). Sem isso, 733 combinações de
  inimigo × lutador × escala errariam o gancho.
- **Quem flutua desce para golpear** (`strike_drop`): o ÉON paira 16 px (× 1,6) acima do chão; nos
  golpes ele desce até o chão na preparação, fica no chão na janela de acerto e volta a flutuar na
  recuperação — o desenho e as caixas usam o mesmo valor. Sem isso, o jab, o giro e as orbes passavam
  acima da cabeça de todos os lutadores (37 falhas no `--check`).
- **IA:** o inimigo só solta um golpe que alcançaria o alvo de verdade (`would_hit`: a hitbox da animação
  em 3 quadros da janela de acerto, mais o avanço do lunge, contra a hurtbox do alvo). Antes: 70 px de
  distância e alvo a menos de 40 px do chão.
- O `--check` confere que jab, cross, gancho, chute, voadora e golpe armado de cada lutador acertam
  cada inimigo parado (escalas 1,0, 1,3 e 1,6), e que os golpes normais de cada inimigo — no tamanho do
  tipo dele, lidos de `enemy.gd` — e as orbes do ÉON acertam cada lutador parado.

**Chefes.** Sub-chefes, chefes e o ÉON usam tudo o que vale para os inimigos (golpes, hurtbox animada,
IA). Além disso:

- **Investida** (`special_attack` com `dash`): o chefe avança o corpo inteiro, então a hitbox é a
  silhueta da frente dele naquele quadro (a hurtbox animada do `charge`), não só o punho. Por isso ela
  não dá mais para ser pulada — o pulo sobe até 113 px e o corpo do sub-chefe vai a 116, o do chefe a
  147 e o do ÉON a 139; o jeito é sair da faixa de profundidade.
- **IA:** o chefe só dispara a investida se a faixa de altura dela cruza o corpo do alvo
  (`would_reach_height`).
- **Câmera lenta do golpe final:** foca o centro do corpo desenhado do chefe (`hurt_rect`), não uma
  altura fixa.
- O `--check` simula também a investida de cada tipo de chefe contra cada lutador parado.

**Cenários.** As colisões do cenário saem do desenho de cada era (`background.gd`):

- **Chão:** a faixa onde se anda começa 30 px abaixo da borda de trás do chão desenhado (`floor_top`:
  330 px na maioria das eras, 336 no convés dos navios, 318 na calçada da era moderna) e vai até 20 px
  antes da base da tela (`main.gd` → `_apply_stage_bounds`, a cada troca de era). Antes era fixa
  em 360–520 px em todas as eras.
- **Barreira do fim da fase:** a face desenhada (`wall_x`, `STAGE_LEN - 30`) é a parede. Lutadores
  encostam nela com o corpo (`body_half_w`, antes entravam ~26 px), armas no chão quicam de volta,
  a arma arremessada bate e cai ali e a Onda Ki/Onda Sísmica param nela com uma faísca.
- F3 mostra a faixa do chão (azul) e a barreira (vermelho).
