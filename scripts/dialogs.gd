extends RefCounted
## Diálogos entre chefes, sub-chefes e os lutadores.
## {p} = nome do lutador que responde; {era} = nome da era.
## A história: CRONOS quebrou a linha do tempo, e os tiranos de cada era foram
## "enfeitiçados pelo tempo" — servem a ele e querem deter o viajante.

## Chefes: falas ao chegar (antes e depois da resposta do lutador) e ao cair.
const BOSSES := {
	"stone": {
		"intro": ["GRUG ESMAGA! Pedra quente cair do céu e trazer comida... você!", "Grug chefe da tribo. Grug chefe de TUDO. Até do tempo!"],
		"defeat": "Grug... ver estrelas de dia...",
	},
	"crusade": {
		"intro": ["Alto, forasteiro. Nenhum viajante atravessa estas muralhas.", "Uma voz no tempo me prometeu um reino sem fim. Não vou devolvê-lo a você."],
		"defeat": "Esta armadura... pesava mais do que eu imaginava...",
	},
	"japan": {
		"intro": ["Um estrangeiro de outra era ousa pisar no meu castelo.", "CRONOS me deu mil anos de poder. Você terá mil segundos de vida."],
		"defeat": "Então... a lâmina do tempo corta para os dois lados...",
	},
	"ships": {
		"intro": ["Homem ao mar! Ou melhor... VIAJANTE ao mar!", "Este navio, este oceano e este século são meus, marujo!"],
		"defeat": "Arriar as velas... a maré virou...",
	},
	"industrial": {
		"intro": ["Ora, ora. Uma engrenagem fora do lugar na minha fábrica.", "O progresso não para — e você vai virar combustível dele."],
		"defeat": "Minhas caldeiras... perdendo... pressão...",
	},
	"ww1": {
		"intro": ["Daqui ninguém passa. Esta trincheira é a minha fortaleza.", "Mandaram mil soldados. Mandaram você. Dá no mesmo."],
		"defeat": "Retirada... retirada geral...",
	},
	"ww2": {
		"intro": ["Holofotes no intruso! Você entrou na cidade errada.", "Minhas ordens vêm de muito além deste século. E dizem: pare o viajante."],
		"defeat": "Impossível... minhas ordens eram perfeitas...",
	},
	"coldwar": {
		"intro": ["Seu arquivo é curto, viajante. E está prestes a ser encerrado.", "Sou o Agente Zero. Não existo — e você logo também não."],
		"defeat": "Essa luta... nunca aconteceu. Entendido?",
	},
	"modern": {
		"intro": ["Ei! Isto aqui é o MEU bairro. Quem te convidou?", "Um velho de capa me prometeu a cidade inteira. Sai da frente!"],
		"defeat": "Tá bom, tá bom... a rua é de vocês...",
	},
	"utopia": {
		"intro": ["Bem-vindo à cidade perfeita. Você é a única imperfeição detectada.", "Correção iniciada. Probabilidade de vitória do visitante: 0,0001%."],
		"defeat": "Recalculando... a perfeição... era um erro...",
	},
	"dystopia": {
		"intro": ["Ajoelha diante do Rei da Sucata! Tudo aqui é meu: o lixo, o céu, a chuva!", "Vou fazer uma coroa nova com os seus parafusos!"],
		"defeat": "Minha coroa... é só sucata...",
	},
	"apocalypse": {
		"intro": ["Então você chegou ao fim dos tempos. Eu sou CRONOS.", "Cada era que você salvou só atrasou o inevitável. Agora o relógio é meu."],
		"defeat": "Não... o tempo... escapa entre os meus dedos...",
	},
	"void": {
		"intro": ["Os doze fragmentos te trouxeram até mim. Fui eu quem deu a CRONOS o seu poder.", "Eu sou ÉON. Eu sou o antes e o depois. Você é só um instante."],
		"defeat": "Um instante... que se recusou a acabar... Interessante.",
	},
}

## Sub-chefes: uma fala ao chegar.
const SUBBOSSES := {
	"stone": "RAKK QUEBRA OSSO! Rakk quebrar o seu primeiro!",
	"crusade": "Sir Godofredo, a seu serviço... e a serviço da sua derrota!",
	"japan": "Hanzo não faz barulho. Você também não fará.",
	"ships": "Arrr! Barba-Ruiva vai te jogar aos tubarões!",
	"industrial": "Hora extra, forasteiro! E quem paga é você!",
	"ww1": "Sargento Trovão na linha! Ninguém sai desta trincheira!",
	"ww2": "Tenente Lobo. Fui treinado para caçar gente como você.",
	"coldwar": "Camarada Urso sente cheiro de espião. E você cheira MUITO.",
	"modern": "MC Caos na área! Essa batida vai te derrubar!",
	"utopia": "Guardião Ômega ativo. Protocolo: remoção do visitante.",
	"dystopia": "Víbora de Cromo... rápida, brilhante e mortal.",
	"apocalypse": "O Arauto do Vazio anuncia: seu fim chegou.",
	"void": "CRONOS RENASCIDO! O mestre ÉON me trouxe de volta só para você!",
}

## Lutadores: respostas aos chefes, aos sub-chefes, frases de vitória e a fala para o ÉON.
const PLAYERS := {
	"mateus": {
		"retort": ["Calma, meu chapa. Primeiro a gente ginga, depois a gente conversa.", "Já vi roda mais difícil que essa lá em Salvador.", "O berimbau já tocou. Agora é a sua vez de dançar."],
		"sub": ["Mais um pra roda!", "Vem que tem!"],
		"victory": ["Isso foi só um aú, imagina o resto.", "Axé! Próxima era!"],
		"eon": "Pode ser o dono do tempo, mas a ginga é minha.",
	},
	"valentina": {
		"retort": ["Fala muito. Vamos ver como fica depois do primeiro round.", "Sobe no ringue e para de enrolar.", "Já derrubei gente maior que você em Buenos Aires."],
		"sub": ["Aquecimento. Ótimo.", "Luvas prontas."],
		"victory": ["Nocaute. Contagem encerrada.", "Próximo desafiante!"],
		"eon": "Você é o último round. Eu sempre ganho o último round.",
	},
	"jake": {
		"retort": ["Grandão, hein? Eu já levantei touro mais pesado.", "Sabe o que acontece com quem enfrenta o Jake? Lona.", "Chega de conversa. Hora do agarrão!"],
		"sub": ["Mais um pro chão!", "Ah, isso vai ser divertido."],
		"victory": ["E o cinturão continua comigo!", "Fácil como laçar bezerro."],
		"eon": "Antes e depois, é? Então agora é a hora do 'depois de apanhar'.",
	},
	"itzel": {
		"retort": ["¡Ándale! Mais um vilão para a minha coleção de máscaras.", "A arena está lotada... de gente torcendo contra você!", "Prepare-se para voar, que eu vou de cima da corda!"],
		"sub": ["¡Vamos!", "Mais uma luta, mais uma festa!"],
		"victory": ["¡La victoria es mía!", "A Luchadora do Tempo não perde!"],
		"eon": "Eterno? Então vai ter tempo de sobra pra lembrar dessa derrota.",
	},
	"dmitri": {
		"retort": ["Já enfrentei o inverno da Sibéria. Você não assusta.", "Palavras, palavras. Eu prefiro chave de braço.", "Venha. Rápido. Estou com frio."],
		"sub": ["Hm. Pequeno.", "Próximo."],
		"victory": ["Como esperado.", "Agora, chá."],
		"eon": "Você é velho como as montanhas. Eu já derrubei montanhas.",
	},
	"oksana": {
		"retort": ["Que discurso! Agora veja os meus passos.", "Na minha terra, a gente dança até o último soldado cair.", "Vai ser rápido. A música já começou."],
		"sub": ["Mais um par para a dança!", "Hop!"],
		"victory": ["E a dança termina com você no chão!", "Viva! Mais uma era livre!"],
		"eon": "Sem fim? Ótimo. Eu também tenho fôlego para dançar para sempre.",
	},
	"luca": {
		"retort": ["Mamma mia, quanta conversa. Vamos ao que interessa.", "Que tal um chute com molho especial?", "Você é tão bom quanto uma pizza sem queijo."],
		"sub": ["Mais um prato do dia!", "Andiamo!"],
		"victory": ["Perfetto! Está servido.", "Agora sim, buon appetito!"],
		"eon": "Antes e depois... e no meio, o meu chute.",
	},
	"amelie": {
		"retort": ["Que cafona. Até o seu discurso está fora de moda.", "Un, deux, trois... e você estará no chão.", "Savate é elegância. Você vai aprender da pior forma."],
		"sub": ["Que entediante.", "En garde!"],
		"victory": ["Voilà. Simples e elegante.", "C'est fini."],
		"eon": "O tempo é infinito? Então ainda dá tempo de você aprender boas maneiras.",
	},
	"kai": {
		"retort": ["Um verdadeiro lutador não precisa ameaçar.", "Meu mestre dizia: o oponente que fala muito tem pouco a mostrar.", "Respire. Concentre-se. Agora!"],
		"sub": ["Uma lição de cada vez.", "Osu!"],
		"victory": ["O caminho continua.", "Que o tempo volte a correr livre."],
		"eon": "Até o tempo tem um ponto fraco. Eu vim encontrar o seu.",
	},
	"mei": {
		"retort": ["A garça não discute com a tempestade. Ela voa.", "Seu kung fu é fraco, sua língua é forte.", "Mostre o que sabe — se souber alguma coisa."],
		"sub": ["Rápido como a fênix!", "Hai-ya!"],
		"victory": ["Equilíbrio restaurado.", "A fênix sempre renasce."],
		"eon": "Antes e depois? A fênix vive nos dois.",
	},
	"kofi": {
		"retort": ["Em Acra, chamamos isso de muita fumaça e pouco fogo.", "Fala alto. Eu bato mais alto.", "Vamos ver se o seu queixo é tão firme quanto a sua voz."],
		"sub": ["Esquenta!", "Vem!"],
		"victory": ["Trovão nunca erra duas vezes. Nem precisa.", "Mais uma era em pé!"],
		"eon": "Você criou o caos. Eu vim trazer a calmaria — com os punhos.",
	},
	"amara": {
		"retort": ["Já ouvi histórias sobre gente como você. Todas terminam igual.", "A história não é sua para roubar.", "De pé, tirano. A luta é justa aqui."],
		"sub": ["Mais um desafio!", "Pode vir!"],
		"victory": ["A história continua sendo de todos.", "Ninguém rouba o tempo de ninguém."],
		"eon": "Você acha que é o dono da história. A história é feita por pessoas.",
	},
	"tama": {
		"retort": ["Meus ancestrais lutam ao meu lado. Você está sozinho.", "Ouça o chão tremer. É o haka chegando.", "Sua força é emprestada. A minha é de família."],
		"sub": ["Kia kaha!", "Mais um para o haka!"],
		"victory": ["Os ancestrais sorriem hoje.", "Ka pai! Seguimos em frente."],
		"eon": "Eterno? Meus ancestrais também. E estão todos aqui comigo.",
	},
	"kirra": {
		"retort": ["Já surfei ondas mais assustadoras que você.", "Oito membros, oito golpes. Escolhe qual quer primeiro.", "Respira fundo, que essa onda vai te derrubar."],
		"sub": ["Mais uma onda!", "Bora!"],
		"victory": ["Onda pegada!", "Fácil. Próxima maré."],
		"eon": "Até o oceano tem ritmo. Vou te mostrar o meu.",
	},
}

## Encontros especiais (era_lutador): substituem a troca padrão de abertura.
const PAIRS := {
	"japan_kai": ["Um karateca de Okinawa. Seu mestre te ensinou a se curvar diante de um shogun?", "Ele me ensinou a me curvar diante de quem tem honra. Não é o seu caso."],
	"japan_mei": ["Uma lutadora do outro lado do mar. Veio buscar uma derrota exótica?", "Vim mostrar que a fênix não respeita fronteiras."],
	"crusade_amelie": ["Uma dama... de calça e sapatilha de luta? Que época é a sua?", "A época em que cavaleiros de armadura perdem para chutes de savate."],
	"ships_tama": ["Terra à vista! Mais uma ilha para pôr no meu mapa!", "Estas águas já tinham nome muito antes do seu mapa, capitão."],
	"ships_mateus": ["Um capoeirista no meu convés? Vai dançar até a prancha!", "Prancha, convés, mastro... pra quem ginga, tudo é roda."],
	"coldwar_dmitri": ["Camarada... você está do lado errado do muro.", "Não existe lado certo de um muro. Só existe o soco que derruba ele."],
	"coldwar_oksana": ["Uma bailarina? Que disfarce mais óbvio.", "Não é disfarce. É aviso: meus pés são mais rápidos que suas balas."],
	"modern_jake": ["Um cowboy no meu bairro? Aqui não tem rodeio!", "Agora tem. E o touro é você."],
	"modern_valentina": ["Ih, a boxeadora. Quer luta de rua? Aqui não tem juiz!", "Melhor. Sem juiz, ninguém interrompe a contagem."],
	"dystopia_itzel": ["Que máscara bonita! Vai ficar ótima pendurada no meu trono!", "Uma luchadora nunca perde a máscara. Mas você vai perder a coroa."],
	"industrial_luca": ["Um italiano! Ótimo, minhas máquinas precisam de um mecânico.", "Eu conserto as coisas de outro jeito: chutando."],
	"stone_kirra": ["GRUG nunca ver gente igual! Você vir de onde?", "De muito longe, Grug. E vim pra te ensinar o que é muay thai."],
	"utopia_amara": ["Cidadã, sua luta é ineficiente. Submeta-se à ordem perfeita.", "Uma ordem que ninguém escolheu não é perfeita. É uma prisão."],
	"ww1_kofi": ["Mais um recruta para a minha trincheira.", "Não sou recruta de ninguém, general. Vim fechar essa trincheira."],
	"apocalypse_kai": ["O pequeno karateca. Você atravessou doze eras só para morrer aqui?", "Atravessei doze eras aprendendo. Esta é a última lição — a sua."],
}


static func pick(arr: Array) -> String:
	return arr[randi() % arr.size()] if not arr.is_empty() else ""
