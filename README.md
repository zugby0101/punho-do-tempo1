# Punho do Tempo

Beat 'em up 2D feito do zero em **Godot 4** (testado no 4.3), só com GDScript.
Não usa nenhum asset externo: personagens, cenários, efeitos e sons são todos
gerados por código.

## Como rodar

1. Instale o [Godot 4.3+](https://godotengine.org/download) (versão padrão, sem .NET).
2. Abra o Godot → **Importar** → selecione `project.godot` desta pasta.
3. Aperte **F5**.

## Controles e co-op (1 a 4 jogadores)

Até 4 pessoas jogam juntas no mesmo computador. Na tela de seleção, cada jogador
**aperta SOCO no próprio teclado ou controle para entrar**, escolhe o personagem
(cada lutador só pode ser escolhido por um jogador) e confirma com SOCO.
O jogo começa quando todos estão prontos.

| Jogador | Mover | Soco | Pulo | Especial |
|---|---|---|---|---|
| Teclado 1 | W A S D | J | K / Espaço | L |
| Teclado 2 | Setas | `,` | `.` | `/` |
| Teclado 3 | T F G H | Z | X | C |
| Teclado 4 | Numpad 8 4 5 6 | Numpad 7 | Numpad 9 | Numpad + |
| Cada controle | Analógico / D-pad | X / □ | A / ✕ | Y / △ ou B / ○ |

Jogando sozinho, qualquer teclado ou controle comanda o P1.
Enter confirma nos menus, Esc ou P pausa. Cima + Soco faz um gancho; Pulo + Soco, uma voadora.
No título, ◄ ► escolhe a fase inicial.

Detalhes do co-op:
- Os inimigos ficam mais fortes e mais numerosos conforme o número de jogadores.
- A câmera acompanha o grupo sem deixar ninguém para trás.
- Cada jogador tem vida, vidas extras e pontuação próprias. Quem acerta o golpe final leva os pontos do inimigo.
- Quem perde todas as vidas pode **continuar apertando SOCO** enquanto o resto do grupo estiver vivo.
- Muitos teclados não registram várias teclas ao mesmo tempo. Para 3 ou 4 jogadores, controles funcionam melhor.

## Conteúdo

**12 fases, uma por período da história:**
Idade da Pedra · Cruzadas · Japão Feudal · Grandes Navegações · Revolução Industrial ·
1ª Guerra Mundial · 2ª Guerra Mundial · Guerra Fria · Tempo Atual ·
Futuro em que tudo deu certo · Futuro em que tudo deu errado · Futuro em que deu muito errado.

Cada fase tem cenário próprio com parallax, inimigos com o visual da época,
**1 sub-chefe** (no meio da fase) e **1 chefe** (no fim). A dificuldade sobe a cada era.

**3 tiers de inimigos em cada fase:**
- ★ Fácil: lento, um golpe só
- ★★ Difícil: rápido, dois golpes, às vezes **bloqueia**
- ★★★ Muito difícil: grandão com **super armadura** (golpes leves não o interrompem)

**Armas que os inimigos deixam cair** (2 por era, uma lâmina e uma contundente):

| Era | Lâmina | Contundente |
|---|---|---|
| Idade da Pedra | Lança de pedra | Clava |
| Cruzadas | Espada | Maça |
| Japão Feudal | Katana | Bastão bō |
| Grandes Navegações | Sabre | Remo |
| Revolução Industrial | Faca | Chave inglesa |
| 1ª Guerra | Baioneta | Pá de trincheira |
| 2ª Guerra | Faca de combate | Pé de cabra |
| Guerra Fria | Adaga | Cassetete |
| Tempo Atual | Canivete | Taco de beisebol |
| Futuro (deu certo) | Lâmina de plasma | Bastão de pulso |
| Futuro (deu errado) | Machete | Cano de ferro |
| Futuro (muito errado) | Foice | Marreta de osso |

- Alguns inimigos entram armados (golpes com mais alcance e dano) e **deixam a arma cair** quando são derrubados. Uma caixa por fase também esconde uma arma.
- **Soco em cima da arma** para pegar. Lâminas fazem combo rápido de 3 golpes; armas contundentes são lentas e derrubam.
- Cada arma tem **durabilidade** (lâmina: 12 acertos, contundente: 8), mostrada no painel do jogador, e quebra ao acabar.
- **Especial com arma na mão: arremessa** a arma, que derruba o primeiro inimigo no caminho e cai no chão para ser pega de novo.
- Quem é derrubado (jogador ou inimigo) **solta a arma**. Armas no chão somem depois de alguns segundos.

**14 personagens jogáveis** (um homem e uma mulher de cada região), cada um com
vida/velocidade/força próprias e **final exclusivo**:

| Região | Homem | Mulher |
|---|---|---|
| América do Sul | Mateus (Brasil) | Valentina (Argentina) |
| América do Norte | Jake (EUA) | Itzel (México) |
| Leste Europeu | Dmitri (Rússia) | Oksana (Ucrânia) |
| Europa | Luca (Itália) | Amélie (França) |
| Ásia | Kai (Japão) | Mei (China) |
| África | Kofi (Gana) | Amara (Nigéria) |
| Oceania | Tama (Nova Zelândia) | Kirra (Austrália) |

## Música e sons

Toda a trilha sonora e os efeitos sonoros são **compostos e sintetizados pelo próprio jogo**
(`scripts/music.gd` e `scripts/sfx.gd`). Não há nenhuma gravação, sample ou composição de
terceiros, então não existe nenhuma questão de direitos autorais.

Cada fase tem sua própria música, com tempo, escala e instrumentos da época:

| Fase | Clima musical |
|---|---|
| Título | tema heroico em tom maior |
| Idade da Pedra | flauta, tambores tribais e chocalho, escala pentatônica |
| Cruzadas | palheta e tambor de moldura, escala do Oriente Médio |
| Japão Feudal | dedilhado tipo koto e taikô, escala japonesa *in* |
| Grandes Navegações | acordeão e baixo "oom-pah", estilo cantiga de marinheiro |
| Revolução Industrial | percussão metálica de fábrica, ritmo mecânico |
| 1ª Guerra | metais e caixa de marcha militar |
| 2ª Guerra | marcha em tom menor com cordas sustentadas |
| Guerra Fria | baixo caminhante e linha de espionagem |
| Tempo Atual | synthwave com arpejos |
| Futuro (deu certo) | sinos e arpejos brilhantes, escala lídia |
| Futuro (deu errado) | industrial agressivo, escala frígia |
| Futuro (muito errado) | bateria dupla e dissonância, escala lócria |

Quando aparece o sub-chefe ou o chefe, a música muda para uma versão mais rápida e intensa.
As trilhas são geradas numa thread, em menos de 1 segundo cada.

## Estrutura

```
scenes/main.tscn        cena principal (só carrega main.gd)
scripts/main.gd         estados do jogo, câmera, ondas, progressão, co-op
scripts/controls.gd     controles dos 4 jogadores (teclados e controles)
scripts/fighter.gd      base dos lutadores: física pseudo-3D, golpes, desenho
scripts/player.gd       jogador: combo, pulo, voadora, especial
scripts/enemy.gd        IA, tiers, sub-chefes e chefes
scripts/stages.gd       dados das 12 eras + geração das ondas
scripts/characters.gd   os 14 personagens e seus finais
scripts/background.gd   os 12 cenários procedurais
scripts/hud.gd          interface e telas
scripts/music.gd        trilha sonora gerada por algoritmo
scripts/sfx.gd          efeitos sonoros sintetizados
scripts/weapons.gd      armas de cada era: dados, golpes e desenho
scripts/weapon_item.gd, thrown.gd   arma no chão e arma arremessada
scripts/crate.gd, pickup.gd, spark.gd   caixas, comida, efeitos de impacto
```

Para ajustar o jogo: as eras, os nomes e as cores ficam em `stages.gd`; os
personagens em `characters.gd`; os golpes do jogador em `player.gd` (constantes `ATK_*`).
