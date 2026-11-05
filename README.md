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
Enter confirma nos menus, Esc ou P pausa. No título: O = online, R = ranking, M = conquistas. Cima + Soco faz um gancho; Pulo + Soco, uma voadora.
No título, ◄ ► escolhe a fase inicial.

Detalhes do co-op:
- Os inimigos ficam mais fortes e mais numerosos conforme o número de jogadores.
- A câmera acompanha o grupo sem deixar ninguém para trás.
- Cada jogador tem vida, vidas extras e pontuação próprias. Quem acerta o golpe final leva os pontos do inimigo.
- Quem perde todas as vidas pode **continuar apertando SOCO** enquanto o resto do grupo estiver vivo.
- Muitos teclados não registram várias teclas ao mesmo tempo. Para 3 ou 4 jogadores, controles funcionam melhor.

## Modo Versus (2 a 4 jogadores)

No título, use **▲ ▼ para escolher o modo** (História ou Versus) e **◄ ► para escolher a arena**
(qualquer uma das 12 eras). Os jogadores entram na seleção como no co-op.

- Todos contra todos: socos, combos, golpes especiais, projéteis e armas acertam os outros jogadores.
- Armas da era e maçãs caem do céu durante a luta.
- Quem fica de pé por último vence o round; quem vencer **2 rounds** é o campeão.
- No fim: ENTER ou SOCO para revanche com os mesmos lutadores, ESC para voltar ao título.

## Modo Sobrevivência (1 a 4 jogadores)

No título, escolha **SOBREVIVÊNCIA** com ▲ ▼ e a era inicial com ◄ ►. Ondas infinitas de inimigos:

- Cada onda traz **mais inimigos**, com **mais vida e mais dano**, e os tiers difíceis ficam mais frequentes.
- **Sub-chefe a cada 5 ondas** e **chefe a cada 10**.
- **A cada 5 ondas, uma viagem no tempo**: a arena muda para a próxima era (cenário, inimigos e música novos).
- Cada onda vencida dá pontos extras; comida aparece a cada 3 ondas e armas caem do céu.
- Não há "continuar": quando todos caem, a partida acaba. Dá para jogar em co-op e online.
- Tem **ranking próprio** (pontos e onda alcançada) e conquistas para chegar às ondas 10, 25 e 50.

## Modo Online (pela internet)

Funciona com o modo História (co-op) e com o Versus, para até 4 jogadores no total
(dá para misturar jogadores no mesmo computador com jogadores online).
No título, escolha o modo e a fase/arena e aperte **O** para abrir o menu online:

| Opção | Para quê |
|---|---|
| **Criar sala** | O anfitrião recebe um **código de 4 letras** e passa para os amigos. Ninguém precisa abrir portas. |
| **Entrar em sala** | O convidado digita o código. |
| Hospedar direto | Conexão por IP, sem servidor (o anfitrião libera a porta 7777 UDP, ou todos usam uma VPN de jogos). |
| Entrar direto por IP | Para a opção acima ou para jogar na mesma rede. |
| Configurar servidor | Endereço do servidor intermediário. |

**Criar sala** e **Entrar em sala** usam o **servidor intermediário** oficial do jogo,
`wss://punho-do-tempo-relay.onrender.com` (já configurado por padrão — não precisa fazer nada).
O código dele está na pasta [`relay-server/`](relay-server/README.md). Para usar outro servidor,
mude o endereço em *Configurar servidor* (deixar em branco volta ao padrão).

> O servidor está no plano gratuito do Render: depois de ~15 minutos sem uso ele "dorme" e leva
> cerca de 1 minuto para acordar. Se "Criar sala" falhar, espere um pouco e tente de novo
> (ou abra https://punho-do-tempo-relay.onrender.com no navegador para acordá-lo).

Como funciona: o anfitrião roda a partida; os convidados enviam só os comandos e recebem
o estado do jogo (~30 vezes por segundo, compactado, cerca de 20–25 KB/s por convidado).
Os menus entre as fases podem ser confirmados por qualquer jogador.

## Conquistas

São **37 conquistas desbloqueáveis**, salvas no computador de cada jogador. Um aviso aparece
na tela quando uma é desbloqueada. No título, **M** (ou **Tab**) mostra todas, com o progresso
das que faltam.

| Categoria | Exemplos |
|---|---|
| Jornada | concluir eras, passar pelas 12 eras, chegar ao final, derrotar CRONOS, zerar com os 14 lutadores, reunir os 12 Fragmentos, derrotar o chefe secreto |
| Combate | 1, 100 e 1000 nocautes; combos de 10, 25 e 50 golpes; sub-chefes e chefes (incluindo os 12) |
| Armas e golpes | pegar armas, coletar as 24 armas, acertar arremessos, 50 especiais, quebrar caixas, comer |
| Desafios | concluir uma era sem perder vida, sem levar dano ou com a última vida; 100 mil e 500 mil pontos |
| Sobrevivência | chegar às ondas 10, 25 e 50 |
| Multijogador | co-op com 2 e com 4 jogadores, vencer no Versus (e sem perder round), jogar online, entrar no Top 10 |

Online, cada convidado desbloqueia as conquistas do próprio lutador no próprio computador.

## Ranking online

São dois rankings: **História** e **Sobrevivência** (na tela do ranking, ◄ ► troca entre eles).
No fim de jogo ou no final da história, aperte **R** para enviar a pontuação: cada jogador
digita o nome (no co-op, cada um entra com a própria pontuação). No título, **R** mostra o
**Top 10** com nome, lutador, pontos, até onde chegou e quantos jogadores eram.

O ranking fica no mesmo servidor do modo online. Para que ele não seja zerado quando o servidor
gratuito reinicia, configure o Upstash Redis (gratuito) — veja
[`relay-server/README.md`](relay-server/README.md#ranking-online).

## Conteúdo

**12 fases, uma por período da história:**
Idade da Pedra · Cruzadas · Japão Feudal · Grandes Navegações · Revolução Industrial ·
1ª Guerra Mundial · 2ª Guerra Mundial · Guerra Fria · Tempo Atual ·
Futuro em que tudo deu certo · Futuro em que tudo deu errado · Futuro em que deu muito errado.

Cada fase tem cenário próprio com parallax, inimigos com o visual da época,
**1 sub-chefe** (no meio da fase) e **1 chefe** (no fim). A dificuldade sobe a cada era.

**Chefe secreto (spoiler!):** cada era esconde um **Fragmento do Tempo**, ganho ao concluí-la
**sem perder nenhuma vida** (a abertura de cada era mostra se você já tem o dela). Com os
**12 fragmentos**, derrotar CRONOS abre a fase secreta **ALÉM DO TEMPO**, com os Ecos sombrios,
o sub-chefe CRONOS RENASCIDO e o chefe secreto **ÉON, O ETERNO**: três fases, orbes temporais
em leque, investidas e, a cada terço de vida, ele dobra o tempo, se teletransporta e convoca Ecos.
Vencê-lo leva ao **Final Verdadeiro**. Depois de desbloqueada, a fase aparece como 13ª na escolha de fases.

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

Cada personagem tem um **golpe especial exclusivo** (botão Especial; gasta um pouco de vida):

| Região | Personagem | Golpe especial | Como funciona |
|---|---|---|---|
| América do Sul | Mateus (Brasil) | Meia-lua de compasso | chute giratório que acerta dos dois lados |
| América do Sul | Valentina (Argentina) | Rajada de jabs | sequência rápida de socos + gancho final |
| América do Norte | Jake (EUA) | Esmagador texano | salta e cai com onda de choque em área |
| América do Norte | Itzel (México) | Tope suicida | mergulho voador atravessando a tela |
| Leste Europeu | Dmitri (Rússia) | Moinho siberiano | giro pesado de longo alcance |
| Leste Europeu | Oksana (Ucrânia) | Chute do hopak | salto ascendente com vários chutes |
| Europa | Luca (Itália) | Tornado de chutes | avança girando e chutando |
| Europa | Amélie (França) | Fouetté triplo | três chutes longos seguidos |
| Ásia | Kai (Japão) | Onda Ki | dispara uma bola de energia |
| Ásia | Mei (China) | Chute da fênix | voadora que acerta várias vezes |
| África | Kofi (Gana) | Punho do trovão | soco carregado com avanço explosivo |
| África | Amara (Nigéria) | Onda sísmica | soca o chão e lança ondas para os dois lados |
| Oceania | Tama (Nova Zelândia) | Investida haka | trombada de rúgbi invencível |
| Oceania | Kirra (Austrália) | Joelhada voadora | salto para frente com joelhada |

Com uma arma na mão, o botão Especial arremessa a arma.

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

**Efeitos sonoros por golpe** (`scripts/sfx.gd`, também sintetizados pelo jogo):

| Grupo | Sons |
|---|---|
| Golpe no ar | jab (assobio curto), cruzado, gancho (sobe de tom), chute (grave), lâmina (cortante), arma pesada, pancada (desce de tom), investida, arremesso, giro |
| Impacto | jab (estalo), cruzado e chute (baque grave), gancho, pancada no chão (estrondo), trombada, lâmina ("shing" metálico), arma de madeira ("tonc"), arma de metal ("clang"), energia (zap), arma arremessada, bloqueio |
| Especial de cada lutador | Mateus: berimbau · Valentina: sino do ringue · Jake: urro · Itzel: apito da lucha libre · Dmitri: moinho · Oksana: pandeiro · Luca: tornado · Amélie: chicotadas · Kai: energia carregando e disparando · Mei: pio da fênix · Kofi: trovão · Amara: terremoto · Tama: tambor e brado · Kirra: flauta do muay thai |
| ÉON e outros | orbes temporais, dobra do tempo, onda sísmica |

O tom acompanha o porte: grandalhões e chefes soam mais graves. Online, o convidado ouve
exatamente o mesmo som e tom do anfitrião.

**Vozes e gritos** (`audio/voices/`, geradas por `tools/audio/voices.py` com síntese de formantes
— sem gravações): **22 vozes** (os 14 lutadores, cada um com tom e timbre próprios, e 8 de inimigos:
brigão, ágil, grandalhão rosnando, sub-chefe, chefe com eco, robô, fantasma sussurrado e o ÉON
com voz dupla e eco), cada uma com 12 falas:

| Fala | Quando |
|---|---|
| "hah!", "hyah!", "tah!" | ao golpear (variam; os inimigos falam menos) |
| "hoa-aah!" | golpes fortes |
| grito de assinatura | especial — ex.: Kai "ki-a-i!", Mei "hwa-ta!", Tama "ka-ma-te!", Itzel "a-ri-ba!" |
| "uh!", "agh!" | ao levar dano |
| "waaah" | ao ser derrubado |
| "aaagh" | nocaute |
| "hup!" | pulo |
| "yeah!" | vitória (fim da era, round do Versus) |
| "ha-ha-ha" | chefes e sub-chefes ao chegar; o ÉON ao dobrar o tempo |

As vozes tocam em canais próprios (não cortam os efeitos) e cada personagem tem um intervalo
mínimo entre falas. Para regerar: `python tools/audio/voices.py` (precisa de numpy e scipy).
As trilhas são geradas numa thread, em menos de 1 segundo cada.

## Rigs 2D (Blender + Godot)

Todos os personagens — os 14 lutadores e os 65 inimigos, sub-chefes e chefes das 13 eras —
são animados por um **rig 2D de esqueleto** gerado no Blender por
script Python (armature com IK para mãos e pés e animações de combate com antecipação, impacto
sincronizado com o acerto, excesso e personalidade por estilo de luta) e convertido em cenas do Godot
(`Skeleton2D` + `Polygon2D` com skinning + `AnimationPlayer`). No título, **V** alterna entre o
rig e o visual clássico. Como gerar e editar: [`tools/rig/README.md`](tools/rig/README.md).

## Estrutura

```
scenes/main.tscn        cena principal (só carrega main.gd)
scripts/main.gd         estados do jogo, câmera, ondas, progressão, co-op
scripts/controls.gd     controles dos 4 jogadores (teclados, controles e jogadores online)
scripts/ach.gd          conquistas (autoload "Ach"): lista, progresso e avisos
scripts/net.gd          modo online (autoload "Net"): salas no relay, conexão direta, estado da partida
relay-server/           servidor intermediário (Node.js) para jogar online sem abrir portas
scripts/fighter.gd      base dos lutadores: física pseudo-3D, golpes, desenho
scripts/player.gd       jogador: combo, pulo, voadora, especial
scripts/enemy.gd        IA, tiers, sub-chefes e chefes
scripts/stages.gd       dados das 12 eras + geração das ondas
scripts/characters.gd   os 14 personagens e seus finais
scripts/background.gd   os 12 cenários procedurais
scripts/hud.gd          interface e telas
scripts/music.gd        trilha sonora gerada por algoritmo
scripts/sfx.gd          efeitos sonoros sintetizados e reprodução das vozes
audio/voices/           vozes e gritos (gerados por tools/audio/voices.py)
scripts/weapons.gd      armas de cada era: dados, golpes e desenho
scripts/energy.gd, popup.gd   projéteis dos especiais e texto flutuante
scripts/weapon_item.gd, thrown.gd   arma no chão e arma arremessada
scripts/crate.gd, pickup.gd, spark.gd   caixas, comida, efeitos de impacto
scripts/rig_weapon.gd, rig_viewer.gd     encaixe da arma no rig e visualizador dos rigs
rigs/                   cenas dos rigs 2D (geradas por tools/rig)
art/rigs/               arquivo do Blender, prévia e dados exportados dos rigs
tools/rig/              pipeline Python: Blender (bpy) -> JSON -> cenas do Godot
```

Para ajustar o jogo: as eras, os nomes e as cores ficam em `stages.gd`; os
personagens em `characters.gd`; os golpes do jogador em `player.gd` (constantes `ATK_*`).
