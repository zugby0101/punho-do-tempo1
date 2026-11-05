extends RefCounted
## Os 14 personagens jogáveis: um homem e uma mulher de cada região.
## Atributos: hp (vida), speed (velocidade), power (força), size (escala do corpo).

## Final exclusivo de cada personagem (mesma ordem da lista).
static func _endings() -> Array:
	return [
		["Mateus volta para a roda de capoeira em Salvador.", "Ao som do berimbau, ensina às crianças golpes que aprendeu em 12 eras.", "Dizem que sua ginga agora tem um passo da Idade da Pedra."],
		["Valentina vence o título mundial de boxe em Buenos Aires.", "No vestiário, guarda a coroa partida de CRONOS como troféu secreto.", "Na luva esquerda, bordou: \"o tempo não me derruba\"."],
		["Jake recusa a fama e abre uma academia em uma cidadezinha do Texas.", "Na parede, uma foto dele com um capitão pirata e um samurai.", "Ninguém acredita que as fotos são reais."],
		["Itzel volta à Arena México sob aplausos.", "Sua nova máscara tem desenhos de todas as eras que salvou.", "A lenda da Luchadora do Tempo nasce naquela noite."],
		["Dmitri retorna à Sibéria e planta uma floresta inteira.", "\"Vi o futuro que deu errado\", diz. \"Não vou deixar acontecer.\"", "Cada árvore leva o nome de uma era."],
		["Oksana dança o hopak na praça de Kyiv, em paz.", "Os girassóis nunca foram tão altos.", "Ela guarda a ampulheta de CRONOS, vazia, no peitoril da janela."],
		["Luca abre uma trattoria em Roma chamada \"Le Dodici Ere\".", "Cada prato homenageia uma época — o mais pedido é o \"Mamute à Bolonhesa\".", "Às vezes, clientes do futuro aparecem para jantar."],
		["Amélie escreve um livro de memórias em um café de Paris.", "\"Savate através dos séculos\" vira um sucesso mundial.", "A última página está em branco: \"para a próxima viagem\"."],
		["Kai volta ao dojo do seu mestre em Okinawa.", "Ele amarra a faixa vermelha num galho de cerejeira de 1600.", "A árvore floresce até hoje, fora de estação."],
		["Mei abre uma escola de kung fu em Pequim para meninas.", "Suas alunas aprendem um estilo novo: o Punho do Tempo.", "Uma delas, um dia, viajará até 3000 d.C. — e tudo dará certo."],
		["Kofi volta a Acra e é recebido com festa e tambores.", "Ele usa os fragmentos da máquina do tempo para criar energia limpa.", "Gana se torna o coração do futuro que deu certo."],
		["Amara retorna a Lagos e funda um centro comunitário de lutas.", "Seu tecido favorito agora tem padrões de todas as 12 eras.", "\"A história é nossa\", diz ela. \"Ninguém a rouba de novo.\""],
		["Tama volta a Aotearoa e lidera o haka antes da final de rúgbi.", "Os ancestrais que conheceu no passado parecem cantar junto.", "O time vence — e Tama sorri para o céu."],
		["Kirra surfa as ondas de Bondi ao nascer do sol.", "Ela pintou a jornada nas 12 eras em uma grande obra de arte.", "A pintura fica no museu de Sydney: \"Tempo de Sonhar\"."],
	]


## Golpe especial exclusivo de cada personagem (mesma ordem da lista).
## type: spin, flurry, slam, dive, rise, dash, projectile, quake (ver player.gd).
static func _specials() -> Array:
	return [
		{"name": "MEIA-LUA DE COMPASSO", "type": "spin", "pose": "kick", "dur": 0.55, "interval": 0.18, "reach": 96, "dmg": 7, "move": 120.0, "cost": 6, "color": Color(1, 0.9, 0.2)},
		{"name": "RAJADA DE JABS", "type": "flurry", "pose_a": "jab", "pose_b": "cross", "dur": 0.6, "interval": 0.08, "reach": 66, "dmg": 3, "lunge": 40.0, "final_dmg": 12, "cost": 6, "color": Color(0.5, 0.8, 1)},
		{"name": "ESMAGADOR TEXANO", "type": "slam", "jump_v": 720.0, "move": 240.0, "reach": 125, "dmg": 20, "cost": 8, "color": Color(1, 0.7, 0.3)},
		{"name": "TOPE SUICIDA", "type": "dive", "speed": 560.0, "dur": 0.45, "interval": 0.0, "reach": 62, "dmg": 16, "cost": 7, "color": Color(1, 0.3, 0.6)},
		{"name": "MOINHO SIBERIANO", "type": "spin", "pose": "special", "dur": 0.8, "interval": 0.2, "reach": 112, "dmg": 9, "move": 60.0, "cost": 8, "color": Color(1, 0.3, 0.3)},
		{"name": "CHUTE DO HOPAK", "type": "rise", "pose": "kick", "jump_v": 640.0, "move": 140.0, "interval": 0.12, "reach": 72, "dmg": 6, "cost": 6, "color": Color(1, 0.95, 0.5)},
		{"name": "TORNADO DE CHUTES", "type": "dash", "pose": "kick", "spin": true, "startup": 0.05, "speed": 380.0, "dur": 0.5, "interval": 0.1, "reach": 72, "dmg": 5, "cost": 6, "color": Color(0.3, 1, 0.5)},
		{"name": "FOUETTÉ TRIPLO", "type": "flurry", "pose_a": "kick", "pose_b": "kick", "dur": 0.54, "interval": 0.18, "reach": 92, "dmg": 7, "lunge": 70.0, "final_dmg": 10, "cost": 6, "color": Color(0.7, 0.6, 1)},
		{"name": "ONDA KI", "type": "projectile", "proj": "ki", "speed": 520.0, "dmg": 18, "cost": 7, "color": Color(0.4, 0.85, 1)},
		{"name": "CHUTE DA FÊNIX", "type": "dive", "pose": "jumpkick", "speed": 520.0, "dur": 0.5, "interval": 0.12, "reach": 68, "dmg": 6, "cost": 7, "color": Color(1, 0.4, 0.15)},
		{"name": "PUNHO DO TROVÃO", "type": "dash", "pose": "cross", "startup": 0.22, "speed": 470.0, "dur": 0.28, "interval": 0.0, "reach": 70, "dmg": 22, "cost": 8, "color": Color(1, 1, 0.4)},
		{"name": "ONDA SÍSMICA", "type": "quake", "dmg": 14, "speed": 420.0, "cost": 7, "color": Color(0.85, 0.6, 0.3)},
		{"name": "INVESTIDA HAKA", "type": "dash", "pose": "charge", "startup": 0.15, "speed": 430.0, "dur": 0.6, "interval": 0.0, "reach": 60, "dmg": 15, "cost": 8, "color": Color(0.9, 0.9, 0.9)},
		{"name": "JOELHADA VOADORA", "type": "rise", "pose": "jumpkick", "jump_v": 560.0, "move": 320.0, "interval": 0.0, "reach": 66, "dmg": 17, "cost": 7, "color": Color(1, 0.6, 0.1)},
	]


static func list() -> Array:
	var arr := _list_base()
	var ends := _endings()
	var sps := _specials()
	for i in arr.size():
		arr[i]["ending"] = ends[i]
		arr[i]["special"] = sps[i]
	return arr


static func _list_base() -> Array:
	return [
		# --- América do Sul ---
		{"name": "MATEUS", "region": "AMÉRICA DO SUL", "country": "Brasil", "style": "Capoeira", "f": false,
			"skin": Color(0.62, 0.42, 0.28), "hair": Color(0.08, 0.06, 0.05), "hat": "curly",
			"shirt": Color(1.0, 0.85, 0.1), "pants": Color(0.1, 0.55, 0.25), "shoes": Color(0.95, 0.95, 0.95),
			"hp": 95, "speed": 1.15, "power": 0.95, "size": 1.0},
		{"name": "VALENTINA", "region": "AMÉRICA DO SUL", "country": "Argentina", "style": "Boxe", "f": true,
			"skin": Color(0.93, 0.75, 0.6), "hair": Color(0.35, 0.2, 0.1), "hat": "ponytail",
			"shirt": Color(0.45, 0.75, 0.95), "pants": Color(0.95, 0.95, 0.98), "shoes": Color(0.2, 0.2, 0.25),
			"hp": 95, "speed": 1.1, "power": 1.0, "size": 0.95},
		# --- América do Norte ---
		{"name": "JAKE", "region": "AMÉRICA DO NORTE", "country": "EUA", "style": "Luta-livre", "f": false,
			"skin": Color(0.96, 0.78, 0.65), "hair": Color(0.95, 0.8, 0.35), "hat": "short",
			"shirt": Color(0.15, 0.25, 0.6), "pants": Color(0.3, 0.35, 0.45), "shoes": Color(0.4, 0.25, 0.12),
			"hp": 115, "speed": 0.9, "power": 1.15, "size": 1.1},
		{"name": "ITZEL", "region": "AMÉRICA DO NORTE", "country": "México", "style": "Lucha Libre", "f": true,
			"skin": Color(0.78, 0.55, 0.38), "hair": Color(0.06, 0.04, 0.04), "hat": "luchamask",
			"shirt": Color(0.9, 0.15, 0.45), "pants": Color(0.1, 0.6, 0.55), "shoes": Color(0.95, 0.8, 0.2),
			"hp": 100, "speed": 1.05, "power": 1.0, "size": 0.95},
		# --- Leste Europeu ---
		{"name": "DMITRI", "region": "LESTE EUROPEU", "country": "Rússia", "style": "Sambo", "f": false,
			"skin": Color(0.97, 0.82, 0.72), "hair": Color(0.55, 0.4, 0.25), "hat": "buzz",
			"shirt": Color(0.75, 0.15, 0.15), "pants": Color(0.2, 0.2, 0.22), "shoes": Color(0.1, 0.1, 0.1),
			"hp": 125, "speed": 0.85, "power": 1.2, "size": 1.15},
		{"name": "OKSANA", "region": "LESTE EUROPEU", "country": "Ucrânia", "style": "Hopak", "f": true,
			"skin": Color(0.98, 0.84, 0.74), "hair": Color(0.98, 0.88, 0.5), "hat": "braidcrown",
			"shirt": Color(0.98, 0.95, 0.85), "pants": Color(0.2, 0.35, 0.75), "shoes": Color(0.75, 0.15, 0.15),
			"hp": 100, "speed": 1.05, "power": 1.0, "size": 0.95},
		# --- Europa ---
		{"name": "LUCA", "region": "EUROPA", "country": "Itália", "style": "Kickboxing", "f": false,
			"skin": Color(0.93, 0.74, 0.58), "hair": Color(0.12, 0.08, 0.05), "hat": "curly",
			"shirt": Color(0.1, 0.45, 0.25), "pants": Color(0.9, 0.9, 0.9), "shoes": Color(0.6, 0.1, 0.1),
			"hp": 105, "speed": 1.0, "power": 1.05, "size": 1.0},
		{"name": "AMÉLIE", "region": "EUROPA", "country": "França", "style": "Savate", "f": true,
			"skin": Color(0.98, 0.82, 0.72), "hair": Color(0.7, 0.2, 0.1), "hat": "bob",
			"shirt": Color(0.15, 0.2, 0.45), "pants": Color(0.12, 0.12, 0.15), "shoes": Color(0.9, 0.1, 0.2),
			"hp": 90, "speed": 1.15, "power": 1.0, "size": 0.95},
		# --- Ásia ---
		{"name": "KAI", "region": "ÁSIA", "country": "Japão", "style": "Karatê", "f": false,
			"skin": Color(0.96, 0.8, 0.64), "hair": Color(0.08, 0.06, 0.05), "hat": "band",
			"shirt": Color(0.95, 0.95, 0.95), "pants": Color(0.15, 0.3, 0.75), "shoes": Color(0.85, 0.2, 0.2),
			"hp": 100, "speed": 1.05, "power": 1.05, "size": 1.0},
		{"name": "MEI", "region": "ÁSIA", "country": "China", "style": "Kung Fu", "f": true,
			"skin": Color(0.97, 0.82, 0.66), "hair": Color(0.06, 0.04, 0.04), "hat": "buns",
			"shirt": Color(0.85, 0.1, 0.12), "pants": Color(0.95, 0.8, 0.2), "shoes": Color(0.1, 0.1, 0.1),
			"hp": 90, "speed": 1.2, "power": 0.95, "size": 0.92},
		# --- África ---
		{"name": "KOFI", "region": "ÁFRICA", "country": "Gana", "style": "Boxe Dambe", "f": false,
			"skin": Color(0.38, 0.24, 0.15), "hair": Color(0.05, 0.04, 0.04), "hat": "buzz",
			"shirt": Color(0.95, 0.75, 0.1), "pants": Color(0.1, 0.45, 0.2), "shoes": Color(0.75, 0.1, 0.1),
			"hp": 110, "speed": 1.0, "power": 1.1, "size": 1.08},
		{"name": "AMARA", "region": "ÁFRICA", "country": "Nigéria", "style": "Gidigbo", "f": true,
			"skin": Color(0.42, 0.27, 0.17), "hair": Color(0.05, 0.04, 0.04), "hat": "headwrap",
			"shirt": Color(0.1, 0.55, 0.3), "pants": Color(0.95, 0.95, 0.95), "shoes": Color(0.85, 0.55, 0.1),
			"hp": 100, "speed": 1.1, "power": 1.0, "size": 0.97},
		# --- Oceania ---
		{"name": "TAMA", "region": "OCEANIA", "country": "Nova Zelândia", "style": "Mau Rākau", "f": false,
			"skin": Color(0.72, 0.5, 0.35), "hair": Color(0.08, 0.06, 0.05), "hat": "topknot",
			"shirt": Color(0.1, 0.1, 0.12), "pants": Color(0.95, 0.95, 0.95), "shoes": Color(0.1, 0.1, 0.1),
			"hp": 120, "speed": 0.9, "power": 1.15, "size": 1.12},
		{"name": "KIRRA", "region": "OCEANIA", "country": "Austrália", "style": "Muay Thai", "f": true,
			"skin": Color(0.5, 0.33, 0.22), "hair": Color(0.15, 0.1, 0.06), "hat": "longhair",
			"shirt": Color(0.95, 0.45, 0.1), "pants": Color(0.15, 0.15, 0.15), "shoes": Color(0.95, 0.85, 0.2),
			"hp": 95, "speed": 1.1, "power": 1.05, "size": 0.95},
	]
