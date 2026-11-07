# Punho do Tempo

Beat 'em up 2D feito do zero em **Godot 4** (testado no 4.3), só com GDScript.
Não usa nenhum asset externo: personagens, cenários, efeitos e sons são todos
gerados por código.

## Como rodar

1. Instale o [Godot 4.3+](https://godotengine.org/download) (versão padrão, sem .NET).
2. Abra o Godot → **Importar** → selecione `project.godot` desta pasta.
3. Aperte **F5**.

## Versão web (jogar no navegador)

O jogo também roda no navegador (Chrome, Edge, Firefox e Safari, no computador), sem instalar nada.
O workflow [`.github/workflows/web.yml`](.github/workflows/web.yml) exporta a versão web a cada push,
testa num Chromium (abre, chega à tela de título, começa a jogar e deixa o agente de teste jogar) e,
na `main`, publica no **GitHub Pages**:

1. Ative uma vez: **Settings → Pages → Build and deployment → Source: GitHub Actions**.
2. Depois de um push na `main` (ou em **Actions → Versão web → Run workflow**), o jogo fica em
   `https://<usuário>.github.io/<repositório>/` — aqui: https://zugby0101.github.io/punho-do-tempo1/

Diferenças em relação à versão para computador:

- **Online só por sala** (código de 4 letras): navegador não abre conexão UDP, então
  *Hospedar direto* / *Entrar direto por IP* não funcionam na web (a sala funciona, inclusive
  misturando quem joga no navegador com quem joga no computador).
- Exportada **sem threads** (roda em qualquer servidor, sem cabeçalhos especiais): a música de cada
  fase é composta na hora em que começa a tocar, o que dá uma pausa curta na troca de fase.
- Progresso, conquistas e opções ficam salvos no próprio navegador.
- Clique no jogo antes de jogar: o navegador só libera teclado, som e controle depois de um clique.

Exportar à mão: no Godot, **Editor → Gerenciar modelos de exportação** (baixe os do 4.3), depois
**Projeto → Exportar → Web → Exportar projeto** (a predefinição já está em `export_presets.cfg`).
Para testar no computador, sirva a pasta por HTTP (abrir o `index.html` direto não funciona):

```bash
python -m http.server 8000 -d build/web
```

e abra http://localhost:8000. Para testar como o CI: `pip install playwright && playwright install chromium`
e `python tools/web/smoke_test.py build/web` (com `--bot`, o agente de teste joga no navegador).

## Telas iniciais

1. **Entrada:** só o título *Punho do Tempo* e "Aperte SOCO ou ENTER para começar".
2. **Escolha de modo:** `[ HISTÓRIA ]  VERSUS  SOBREVIVÊNCIA` (◄ ►), a fase/arena na linha de baixo e,
   abaixo, *Comandos e opções* (C), *Jogar online* (O), *Ranking* (R) e *Conquistas* (M).
   ▲ ▼ escolhe a linha, SOCO/ENTER confirma, ESC ou PULO volta para a entrada.
3. **Comandos e opções:** os controles de cada jogador e as opções (visual, partículas, sangue,
   tremor, vibração) — ▲ ▼ escolhe, ◄ ► ou SOCO muda; ESC, PULO ou ENTER volta.

## Controles e co-op (1 a 4 jogadores)

Até 4 pessoas jogam juntas no mesmo computador. Na tela de seleção, cada jogador
**aperta SOCO no próprio teclado ou controle para entrar**, escolhe o personagem
(cada lutador só pode ser escolhido por um jogador) e confirma com SOCO.
O jogo começa quando todos estão prontos.

| Jogador | Mover | Soco | Pulo | Especial | Bloqueio |
|---|---|---|---|---|---|
| Teclado 1 | W A S D | J | K / Espaço | L | U |
| Teclado 2 | Setas | `,` | `.` | `/` | N |
| Teclado 3 | T F G H | Z | X | C | Q |
| Teclado 4 | Numpad 8 4 5 6 | Numpad 7 | Numpad 9 | Numpad + | Numpad 1 |
| Cada controle | Analógico / D-pad | X / □ | A / ✕ | Y / △ ou B / ○ | LB / RB |

Jogando sozinho, qualquer teclado ou controle comanda o P1.
Enter confirma nos menus (no Teclado 3, a tecla 5), Esc ou P pausa. Na escolha de modo: O = online, R = ranking, M = conquistas, C = comandos e opções;
V = visual (rig definitivo / rig simples / clássico), P = partículas, Y = sangue, E = tremor da câmera (100% / 50% / desligado), B = vibração. Cima + Soco faz um gancho; Pulo + Soco, uma voadora.
Segurar **Bloqueio** ergue a guarda (para golpes de frente; os fortes tiram só um pouco de vida) e
**Bloqueio + Pulo** é uma esquiva: um passo rápido para trás, invencível enquanto está no ar. Quando um
golpe do combo derrubaria de vez um inimigo à frente, sai a **finalização** no lugar dele.
Na escolha de modo, a linha *Fase inicial* (◄ ►) escolhe a fase.

Detalhes do co-op:
- Os inimigos ficam mais fortes e mais numerosos conforme o número de jogadores.
- A câmera acompanha o grupo sem deixar ninguém para trás.
- Cada jogador tem vida, vidas extras e pontuação próprias. Quem acerta o golpe final leva os pontos do inimigo.
- Quem perde todas as vidas pode **continuar apertando SOCO** enquanto o resto do grupo estiver vivo.
  Quem ainda estiver fora quando o grupo concluir a era volta na próxima do mesmo jeito (vidas cheias, pontuação zerada).
- Muitos teclados não registram várias teclas ao mesmo tempo. Para 3 ou 4 jogadores, controles funcionam melhor.

## Modo Versus (2 a 4 jogadores)

Na escolha de modo, deixe **VERSUS** marcado (◄ ► na linha do modo) e escolha a **arena** na linha de baixo
(qualquer uma das 12 eras). Os jogadores entram na seleção como no co-op.

- Todos contra todos: socos, combos, golpes especiais, projéteis e armas acertam os outros jogadores.
- Armas da era e maçãs caem do céu durante a luta.
- Quem fica de pé por último vence o round; quem vencer **2 rounds** é o campeão.
- No fim: ENTER ou SOCO para revanche com os mesmos lutadores, ESC para voltar ao título.

## Modo Sobrevivência (1 a 4 jogadores)

Na escolha de modo, marque **SOBREVIVÊNCIA** (◄ ►) e a era inicial na linha de baixo. Ondas infinitas de inimigos:

- Cada onda traz **mais inimigos**, com **mais vida e mais dano**, e os tiers difíceis ficam mais frequentes.
- **Sub-chefe a cada 5 ondas** e **chefe a cada 10**.
- **A cada 5 ondas, uma viagem no tempo**: a arena muda para a próxima era (cenário, inimigos e música novos).
- Cada onda vencida dá pontos extras; comida aparece a cada 3 ondas e armas caem do céu.
- Não há "continuar": quando todos caem, a partida acaba. Dá para jogar em co-op e online.
- Tem **ranking próprio** (pontos e onda alcançada) e conquistas para chegar às ondas 10, 25 e 50.

## Modo Online (pela internet)

Funciona com o modo História (co-op) e com o Versus, para até 4 jogadores no total
(dá para misturar jogadores no mesmo computador com jogadores online).
Na escolha de modo, escolha o modo e a fase/arena e aperte **O** (ou a linha *Jogar online*) para abrir o menu online:

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
na tela quando uma é desbloqueada. Na escolha de modo, **M** (ou **Tab**) mostra todas, com o progresso
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
digita o nome (no co-op, cada um entra com a própria pontuação). Na escolha de modo, **R** mostra o
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

**Som do corpo de quem apanha** (os 79 personagens): junto com o impacto do golpe toca o som do
material do corpo (o mesmo de `scripts/materials.gd` que decide sangue, óleo, fumaça...), no ponto e no
quadro do contato:

| Material | Som |
|---|---|
| carne | baque surdo do corpo (+ respingo molhado nos golpes de 6+ de dano, com o sangue ligado) |
| máquina | chapa batendo, faíscas estalando e um servo que reclama |
| ciborgue | baque do corpo com metal |
| mutante | baque molhado e gorgolejo grave |
| sombra | chiado que se desfaz e um tom fantasma com vibrato |
| tempo (Cronos, ÉON) | estilhaço de vidro e areia escorrendo |
| luz (IA Aurora) | falha digital, bipes em degraus |

O golpe que derruba de vez usa a versão longa e grave de cada um. O tom é o do porte do corpo com um
ajuste fixo de cada personagem (pelo nome do rig), então os 79 soam diferentes entre si. Golpe que
pega na cabeça (quarto de cima do corpo) de quem usa capacete, elmo ou coroa de metal — cavaleiros,
samurais, soldados das guerras, reis — também tilinta no metal.

**Golpes cortando o ar** (os 79 personagens): o assobio do golpe começa quando a ponta (punho, pé,
arma) entra no trecho rápido que termina no impacto — medido na animação de cada rig e gravado em
`metadata/hitboxes` (`sw`; `wsw` para a ponta da arma) pelo `tools/rig/hitboxes.py`; em quase todos os
golpes isso é u ≈ 0,27, logo depois da antecipação (antes, tocava só no quadro do impacto). O tom
acompanha o porte e o ajuste de cada personagem, e fica mais grave quanto maior o caminho da ponta (jab
de 27 px agudo, arco de arma de até 172 px grave). Por cima do assobio, a camada de quem bate: máquinas
e ciborgue com servo, sombras com sopro fantasma, Cronos e ÉON com varredura de sino, IA Aurora com zumbido
elétrico, e um "vum" grave para quem é pesado.

**Passos** (os 79 personagens): o passo toca no quadro em que o **pé desenhado** volta ao chão — o jogo
lê a altura dos ossos dos pés no esqueleto já posado (AnimationPlayer ou AnimationTree) e, quando um pé
que estava levantado (3+ px) encosta (até 1 px), toca o passo. Por isso soam também a pisada do haka
(Tama) e o toque do muay thai (Kirra) parados, o pé que volta depois do chute, o pouso do pulo e da
esquiva; e o ÉON, que flutua, não pisa. No visual clássico, os passos seguem o balanço das pernas.
Conferido nas animações dos 79 rigs: a caminhada dá 2 passos por ciclo em 78 deles (o ÉON, 0).

| Camada | Som |
|---|---|
| chão da era | terra (Pedra), areia (Cruzadas), cascalho (Japão), madeira do convés (Navios), paralelepípedo (Industrial), lama (1ª Guerra), escombros (2ª Guerra), concreto (Guerra Fria), asfalto (Moderna), vidro (Utopia), grade de metal (Distopia), cinzas (Apocalipse), cristal (Vazio) — duas variações alternadas pé a pé |
| quem pisa | máquinas e ciborgue: clank com servo · Cronos: tique-taque de relógio · IA Aurora: bipe · mutantes: passo molhado · sombras: só um sussurro · porte 1,1+ (Jake, Dmitri, Tama, Kofi, brutos e chefes): baque grave |

O tom é o do porte com o ajuste de cada personagem (como no som do corpo). Os passos têm canais
próprios, mais baixos, que não cortam os golpes, e no máximo ~40 por segundo no total.

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

## Partículas dos golpes

Cada acerto solta partículas conforme o tipo do golpe (`scripts/fx.gd`, com `CPUParticles2D`, que
funciona no renderizador Compatibility e na web):

| Golpe | Efeito |
|---|---|
| jab / cross | faíscas rápidas para a frente; o cross ainda tem anel de impacto |
| gancho | faíscas subindo em leque, que caem com a gravidade |
| chute | faíscas e nuvem de poeira |
| pancada (slam) | explosão de faíscas, anel grande, poeira no chão e pedrinhas voando |
| investida | jato de faíscas na direção do golpe e poeira nos pés |
| lâmina | riscos de corte na diagonal e faíscas de metal |
| arma de metal / de madeira | faíscas laranja caindo / lascas de madeira girando |
| energia (especiais) | partículas brilhantes na cor do especial e onda de choque |
| arma arremessada, defesa, arma quebrando | detritos, estilhaços azuis, pedaços da arma |
| nocaute | explosão grande (maior e rosa nos chefes) com poeira no chão |

Golpes pesados e lutadores grandes geram efeitos maiores; no co-op as faíscas têm a cor do jogador.
No online, o host manda os efeitos para todos. **P** em *Comandos e opções* liga/desliga as partículas e os rastros.

**Impacto, sangue e o material de cada personagem.** Além das partículas do golpe, quem apanha solta
o que é feito o corpo dele (`scripts/materials.gd`, os 79 personagens), saindo do **ponto exato do
contato** — onde a ponta do golpe na animação (punho, pé, arma) encosta no corpo do alvo:

| Material | Quem | O que sai |
|---|---|---|
| carne | os 14 lutadores e os humanos de todas as eras (63) | gotas de sangue que voam para o lado do golpe e mancham o chão |
| máquina | Androide, Drone-K, Sentinela, Guardião Ômega | óleo escuro, faíscas de metal e parafusos |
| ciborgue | Ciborgue | sangue com óleo e faíscas |
| mutante | Mutante, Abominação | sangue verde |
| sombra | Espectro, Arauto do Vazio e os Ecos | fumaça roxa que sobe, sem manchas |
| tempo | Cronos, ÉON | areia dourada que escorre e estilhaços do tempo |
| luz | IA Aurora | quadradinhos de luz (falha digital) |

A quantidade acompanha o dano, e o golpe que derruba de vez solta bem mais. As manchas (`scripts/splat.gd`)
aparecem quando as gotas chegam ao chão, ficam ~9 s numa camada abaixo dos lutadores e somem devagar
(no máximo 90 na tela; trocar de era limpa o chão). Golpe bloqueado não fere. As faíscas do golpe têm a
**assinatura** de quem bate: a cor do especial de cada lutador, ou a cor do material dos inimigos
(máquinas azuis, sombras roxas, Cronos e ÉON dourados). **Y** em *Comandos e opções* liga/desliga o sangue
(desligado, carne, ciborgue e mutante soltam só um sopro de poeira, sem manchas).

**Rastro de movimento nos especiais** (`scripts/trail.gd`): durante os 14 golpes especiais — e nas
investidas e golpes giratórios de sub-chefes e chefes (vermelho; roxo no ÉON) — o lutador deixa
**imagens residuais** (cópias do rig na pose de instantes atrás, translúcidas na cor do especial) e
**fitas de luz** presas às pontas reais dos ossos: pés nos chutes, mãos nos socos e investidas, mão e
pé nos giros, e a ponta da arma quando há uma. No visual clássico ficam só as fitas.

## Tremor de tela e vibração

**Tremor por "trauma"**: cada impacto soma trauma (0..1), que decai sozinho; a tela treme com
amplitude proporcional a trauma², com ruído suave, então socos leves quase não mexem a câmera e
golpes fortes sacodem de verdade. Golpes fortes ainda dão um **tranco na direção do golpe** (para
cima no gancho e na pancada). Golpes seguidos se acumulam.

**Câmera dinâmica: cada um dos 79 treme a tela do seu jeito** (`main.gd` → `shake_profile`). O tremor
leva a marca de quem causou:

| Traço | Vem de | Efeito |
|---|---|---|
| massa | porte do corpo | o mesmo golpe forte: Valentina ~7 px, Dmitri ~10, chefes ~15 |
| ritmo | material do corpo + ajuste fixo de cada personagem | máquinas: tremor rápido e seco · IA Aurora: picotado · mutantes: mais lento · sombras e tempo (Cronos, ÉON): balanço lento |
| inclinação | gigantes (1,3+), tempo e sombra | a câmera gira de leve (ÉON até ~0,8°, chefes ~0,15°); aproxima o bastante para os cantos não aparecerem |

E ainda: **zoom de impacto** (um pulso rápido de zoom em direção ao ponto do contato nos golpes fortes,
maior para quem é grande e na finalização) e **tranco vertical** (a câmera "afunda" a cada passo dos
gigantes — brutos, sub-chefes, chefes —, na pisada do haka do Tama e quando um corpo grande cai). Na
câmera lenta dos chefes, o zoom dela manda. Online, os convidados recebem inclinação, zoom e tranco do
anfitrião.

**E** em *Comandos e opções* troca o **tremor** entre 100%, 50% e desligado (fica salvo). Vale para o tremor, a
inclinação, o zoom de impacto e o tranco vertical — para quem se incomoda com a tela mexendo; online,
cada um usa o próprio ajuste. A câmera lenta do golpe final nos chefes não muda.

**Vibração dos controles** (motor leve / motor pesado):

| Situação | Quem vibra | Intensidade |
|---|---|---|
| acertar um golpe forte | quem bateu | leve, curta |
| levar um golpe forte | quem apanhou | forte (cresce com o dano) |
| cair no chão / perder vida / ser nocauteado | o jogador | forte, longa |
| especial de impacto no chão (pancada, onda sísmica) | quem usou | média |
| chefe entrando em cena | todos | média, longa |
| nocaute de sub-chefe / chefe | todos | forte / máxima |

Teclado não vibra; no online o convidado recebe a vibração no controle dele. **B** em *Comandos e opções*
liga/desliga a vibração (salvo nas configurações).

## Câmera lenta no golpe final

O golpe que derruba um **chefe** (inclusive o ÉON) vira uma cena: congelamento do impacto com clarão
branco, depois o tempo cai para 15% por cerca de 1,5 s, a câmera dá zoom (1,4×) e enquadra o chefe,
entram faixas de cinema e o som e a música ficam graves e lentos (`AudioServer.playback_speed_scale`).
Tudo volta suavemente ao normal. Nos **sub-chefes** é uma versão mais curta (30%, zoom 1,2×). Usa o
`Engine.time_scale`, então personagens, partículas, rastros e animações desaceleram juntos; a
sequência é cronometrada em tempo real e, no online, os convidados recebem o mesmo efeito. Não
acontece no Versus.

## Diálogos com chefes

Na história (e na fase secreta), chefes e sub-chefes **conversam com o lutador** quando entram em cena,
e o chefe tem uma última fala ao ser derrotado — seguida da comemoração do herói:

- **13 chefes** com fala de entrada (2 linhas) e de derrota próprias; **cada sub-chefe** com uma provocação.
- **Cada um dos 14 lutadores** responde no seu jeito (3 respostas a chefes, 2 a sub-chefes, 2 de vitória
  e uma fala especial para o ÉON).
- **Encontros especiais**: alguns pares têm diálogo próprio (Kai e Mei contra o Shogun, Dmitri e Oksana
  na Guerra Fria, Tama e Mateus nas Grandes Navegações, Jake e Valentina no presente...). No co-op,
  responde quem tem diálogo especial com o chefe; senão, um jogador ao acaso.
- Caixa de diálogo com **retrato** (cores e chapéu de quem fala), nome, texto letra a letra com
  “bipes” no tom da voz do personagem e uma fala gravada no início de cada linha.
- **SOCO/ENTER** mostra a fala inteira ou avança; **PULO** pula o diálogo. O jogo fica pausado durante a
  conversa, e a fase só termina depois da fala final do chefe. No online, o diálogo aparece para todos.

## Rigs 2D (Blender + Godot)

Todos os personagens — os 14 lutadores e os 65 inimigos, sub-chefes e chefes das 13 eras —
são animados por um **rig 2D de esqueleto** gerado no Blender por
script Python (armature com IK para mãos e pés e animações de combate com antecipação, impacto
sincronizado com o acerto, excesso e personalidade por estilo de luta) e convertido em cenas do Godot
(`Skeleton2D` + `Polygon2D` com skinning + `AnimationPlayer`). Os modelos têm contorno, luz e sombra,
rosto e, nos 14 lutadores, os detalhes do estilo de luta (luvas, faixas, cordão, joelheiras, tatuagens,
mongkol...). Em *Comandos e opções*, **V** alterna entre o rig definitivo, o rig simples (sem o acabamento, mais leve)
e o visual clássico. Como gerar e editar: [`tools/rig/README.md`](tools/rig/README.md).

Cada rig tem também um **`AnimationTree`** com máquina de estados e **BlendSpaces**:
`locomotion` (BlendSpace1D parado↔andando, sincronizado), `strike` (BlendSpace2D com os golpes
organizados por força × altura), `air` (pulo↔voadora), `damage` (dor↔queda) e `floor`
(caído↔levantando). Trocas de estado ganham **crossfade**; golpes, pulo e dano seguem a fase exata da
jogabilidade (a pose de impacto continua caindo no quadro do acerto).

**Hitboxes sincronizadas com a animação** (todos os 79 rigs): a área que acerta segue a ponta que
golpeia — punho, pé ou a ponta da arma — quadro a quadro, e só existe enquanto essa ponta está lá na
frente. O alcance de cada golpe continua o do jogo (`reach`), mas a altura vem da animação: o gancho
pega quem está pulando (anti-aéreo), o slam só pega quem está no chão e a voadora só acerta depois
que a perna estica. Vale também para os especiais corpo a corpo: as rajadas só acertam com o
membro esticado, os giros acertam dos dois lados, o Tope Suicida acerta com os braços do corpo deitado
e a onda do Esmagador Texano só pega quem está no chão. Os projéteis (Onda Ki, Onda Sísmica, arma
arremessada e as orbes do ÉON) saem da mão no quadro de soltura da animação e acertam só na altura em
que são desenhados — dá para pular a Onda Sísmica. As armas no chão se pegam com a mão no cabo
desenhado (dá para agarrar uma arma ainda quicando), machucam quem estiver embaixo quando caem rápido
e são chutadas pelos golpes que varrem o chão (chute, slam, golpe armado). As caixas quebráveis
apanham no tamanho em que são desenhadas, são sólidas (dá para pular por cima; os inimigos as contornam), escorregam quando o
golpe não as quebra, racham com o dano e se desmontam em tábuas que machucam quem estiver no caminho, e a comida salta para fora junto com as tábuas e é pega quando o corpo encosta no
desenho dela. Inimigos e jogadores apanham na silhueta da animação que está na tela (encolhem na dor e
no pulo, o braço esticado também apanha), o ÉON desce do ar para golpear e os inimigos só soltam um
golpe que alcançaria o jogador de verdade. Na investida, os chefes acertam com o corpo inteiro (não dá
para pular por cima: saia da faixa). O chão onde se anda e a barreira do fim da fase seguem o desenho de
cada era: ninguém mais entra na parede, e armas e projéteis batem nela.
As trajetórias saem das próprias cenas (`tools/rig/hitboxes.py`, gravadas em
`metadata/hitboxes`) e valem também no visual clássico. **F3** durante o jogo mostra as hurtboxes
(verde), a hitbox do quadro (vermelho) e a ponta da animação (amarelo).

## Agente de teste

O jogo tem um **agente que joga sozinho** e confere se nada quebrou (`scripts/test_bot.gd`, ativado só com
`-- --test-bot`): primeiro abre os 79 rigs e toca cada animação; depois joga 14 partidas — cada lutador numa
era, passando pelas 13 — com um controle virtual (anda até os inimigos, soca, faz combos, gancho, voadora,
bloqueia, esquiva, usa o especial, pega e arremessa armas, passa os diálogos), conferindo a cada quadro as
regras do jogo (posições no chão e na fase, vida, estados, animações do rig, hurtbox, câmera) e exigindo
golpes no ar, acertos e passos. Tira capturas de tela e grava um relatório.

```bash
python tools/test/run_game_tests.py            # tudo: Python + importação no Godot + o agente jogando
python tools/test/run_game_tests.py --quick    # 3 partidas curtas
python tools/test/run_game_tests.py --sem-godot
```

O Godot é achado pela variável `GODOT`, pelo `PATH` (`godot4`/`godot`) ou por `--godot /caminho`.
Capturas, `relatorio.json` e `godot.log` ficam em `test_output/`. No GitHub, o workflow
**Teste no Godot** (`.github/workflows/teste-godot.yml`) faz o mesmo a cada push e PR (Godot 4.3 com vídeo
virtual) e publica o resumo na execução e as capturas nos artefatos. No Claude Code, o agente
**testador-godot** (`.claude/agents/testador-godot.md`) roda o teste (ou lê a última execução do CI) e
explica cada falha com arquivo:linha e a correção sugerida.

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
scripts/dialogs.gd      falas dos chefes, sub-chefes e respostas de cada lutador
scripts/fx.gd           partículas dos golpes (fx_ring.gd: anel de choque)
scripts/trail.gd        rastro de movimento dos especiais (imagens residuais + fitas de luz)
scripts/hitbox_view.gd  depuração das hitboxes sincronizadas com a animação (F3)
scripts/test_bot.gd     agente de teste que joga sozinho (só com -- --test-bot; tools/test)
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
