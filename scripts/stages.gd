extends RefCounted
## Dados das 12 fases — uma em cada período da história (e do futuro).
## Cada fase define: cenário (style), paleta, visual dos inimigos e o chefe.

static func _look(name: String, shirt: Color, pants: Color, hat: String, skin := Color(0.96, 0.76, 0.6), hair := Color(0.15, 0.1, 0.05)) -> Dictionary:
	return {"name": name, "shirt": shirt, "pants": pants, "hat": hat, "skin": skin, "hair": hair}


## Sub-chefes (meio da fase), um por era, na mesma ordem das fases.
static func _subbosses() -> Array:
	return [
		_look("RAKK, O QUEBRA-OSSOS", Color(0.55, 0.35, 0.15), Color(0.4, 0.28, 0.12), "wild", Color(0.7, 0.5, 0.35), Color(0.5, 0.25, 0.1)),
		_look("SIR GODOFREDO", Color(0.8, 0.8, 0.85), Color(0.5, 0.5, 0.55), "helmet"),
		_look("HANZO, O ONI", Color(0.6, 0.08, 0.1), Color(0.1, 0.1, 0.12), "ninja"),
		_look("BARBA-RUIVA", Color(0.3, 0.2, 0.15), Color(0.2, 0.15, 0.1), "bandana", Color(0.95, 0.75, 0.6), Color(0.85, 0.3, 0.1)),
		_look("CAPATAZ BRUTUS", Color(0.4, 0.3, 0.22), Color(0.25, 0.2, 0.18), "flatcap", Color(0.85, 0.65, 0.5)),
		_look("SARGENTO TROVÃO", Color(0.42, 0.4, 0.28), Color(0.35, 0.33, 0.24), "brodie"),
		_look("TENENTE LOBO", Color(0.3, 0.33, 0.27), Color(0.25, 0.27, 0.22), "helmet2"),
		_look("CAMARADA URSO", Color(0.28, 0.32, 0.28), Color(0.2, 0.22, 0.2), "ushanka", Color(0.95, 0.8, 0.7)),
		_look("MC CAOS", Color(0.95, 0.6, 0.1), Color(0.15, 0.15, 0.2), "cap", Color(0.55, 0.38, 0.25)),
		_look("GUARDIÃO ÔMEGA", Color(0.95, 0.95, 1.0), Color(0.8, 0.85, 0.9), "robot", Color(0.75, 0.8, 0.88)),
		_look("VÍBORA DE CROMO", Color(0.2, 0.2, 0.25), Color(0.15, 0.12, 0.12), "goggles", Color(0.65, 0.65, 0.7)),
		_look("ARAUTO DO VAZIO", Color(0.25, 0.05, 0.35), Color(0.1, 0.02, 0.15), "hood", Color(0.7, 0.6, 0.9)),
	]


static func list() -> Array:
	var arr := _list_base()
	var subs := _subbosses()
	for i in arr.size():
		arr[i]["subboss"] = subs[i]
	return arr


static func _list_base() -> Array:
	var tan := Color(0.8, 0.58, 0.4)
	var dark := Color(0.55, 0.38, 0.26)
	var metal := Color(0.7, 0.74, 0.8)
	return [
		{
			"name": "IDADE DA PEDRA", "year": "10.000 a.C.", "style": "stone",
			"intro": "{p} cai no passado distante. Uma tribo hostil bloqueia o caminho!",
			"sky": [Color(0.35, 0.6, 0.9), Color(0.5, 0.7, 0.92), Color(0.85, 0.75, 0.6), Color(0.95, 0.6, 0.35)],
			"sun": Color(1, 0.95, 0.6),
			"thug": _look("TRIBAL", Color(0.75, 0.55, 0.2), Color(0.6, 0.42, 0.15), "wild", tan, Color(0.3, 0.18, 0.08)),
			"knife": _look("CAÇADOR", Color(0.85, 0.65, 0.25), Color(0.5, 0.35, 0.12), "wild", tan, Color(0.12, 0.08, 0.05)),
			"brute": _look("BRUTAMONTES", Color(0.6, 0.4, 0.15), Color(0.45, 0.3, 0.1), "wild", dark, Color(0.2, 0.12, 0.05)),
			"boss": _look("GRUG, O CHEFE MAMUTE", Color(0.5, 0.45, 0.4), Color(0.4, 0.3, 0.15), "horns", dark, Color(0.35, 0.2, 0.1)),
			"cape": Color(0.55, 0.5, 0.45),
		},
		{
			"name": "AS CRUZADAS", "year": "1190 d.C.", "style": "crusade",
			"intro": "Desertos escaldantes e muralhas de pedra. Soldados enfeitiçados pelo tempo atacam!",
			"sky": [Color(0.3, 0.55, 0.85), Color(0.55, 0.72, 0.9), Color(0.92, 0.82, 0.6), Color(0.98, 0.75, 0.45)],
			"sun": Color(1, 1, 0.8),
			"thug": _look("SOLDADO", Color(0.85, 0.85, 0.8), Color(0.45, 0.45, 0.5), "helmet"),
			"knife": _look("ARQUEIRO", Color(0.35, 0.5, 0.25), Color(0.4, 0.3, 0.2), "hood"),
			"brute": _look("SARGENTO", Color(0.6, 0.6, 0.65), Color(0.35, 0.35, 0.4), "helmet"),
			"boss": _look("CAVALEIRO NEGRO", Color(0.15, 0.15, 0.18), Color(0.1, 0.1, 0.12), "greathelm"),
			"cape": Color(0.5, 0.05, 0.08),
		},
		{
			"name": "JAPÃO FEUDAL", "year": "1600 d.C.", "style": "japan",
			"intro": "Cerejeiras e lâminas afiadas. Os ronins juraram deter o viajante!",
			"sky": [Color(0.35, 0.2, 0.45), Color(0.75, 0.35, 0.45), Color(0.95, 0.6, 0.45), Color(1, 0.8, 0.55)],
			"sun": Color(0.95, 0.25, 0.2),
			"thug": _look("RONIN", Color(0.3, 0.35, 0.55), Color(0.2, 0.2, 0.3), "topknot"),
			"knife": _look("NINJA", Color(0.12, 0.12, 0.15), Color(0.1, 0.1, 0.12), "ninja"),
			"brute": _look("SUMÔ", Color(0.95, 0.85, 0.7), Color(0.9, 0.9, 0.95), "topknot", Color(0.95, 0.8, 0.65)),
			"boss": _look("SHOGUN SOMBRIO", Color(0.55, 0.08, 0.1), Color(0.15, 0.1, 0.1), "kabuto"),
			"cape": Color(0, 0, 0, 0),
		},
		{
			"name": "GRANDES NAVEGAÇÕES", "year": "1500 d.C.", "style": "ships",
			"intro": "Em alto-mar, a bordo de uma nau. Piratas tomam o convés!",
			"sky": [Color(0.25, 0.45, 0.8), Color(0.45, 0.65, 0.9), Color(0.7, 0.82, 0.95), Color(0.85, 0.9, 0.95)],
			"sun": Color(1, 0.98, 0.85),
			"thug": _look("MARUJO", Color(0.9, 0.9, 0.85), Color(0.25, 0.3, 0.5), "bandana"),
			"knife": _look("PIRATA", Color(0.7, 0.15, 0.15), Color(0.2, 0.15, 0.1), "bandana"),
			"brute": _look("CONTRAMESTRE", Color(0.4, 0.3, 0.2), Color(0.25, 0.2, 0.15), "bald", dark),
			"boss": _look("CAPITÃO TORMENTA", Color(0.2, 0.2, 0.45), Color(0.15, 0.12, 0.1), "tricorn"),
			"cape": Color(0.15, 0.12, 0.3),
		},
		{
			"name": "REVOLUÇÃO INDUSTRIAL", "year": "1850 d.C.", "style": "industrial",
			"intro": "Fumaça, engrenagens e carvão. A gangue das fábricas quer briga!",
			"sky": [Color(0.3, 0.28, 0.27), Color(0.45, 0.4, 0.36), Color(0.6, 0.52, 0.42), Color(0.72, 0.6, 0.45)],
			"sun": Color(0.9, 0.75, 0.5, 0.6),
			"thug": _look("OPERÁRIO", Color(0.55, 0.45, 0.35), Color(0.3, 0.28, 0.25), "flatcap"),
			"knife": _look("BATEDOR", Color(0.3, 0.3, 0.32), Color(0.2, 0.2, 0.2), "flatcap"),
			"brute": _look("FOGUISTA", Color(0.35, 0.25, 0.2), Color(0.25, 0.2, 0.18), "bald", Color(0.75, 0.55, 0.45)),
			"boss": _look("BARÃO DO VAPOR", Color(0.15, 0.15, 0.18), Color(0.12, 0.12, 0.14), "tophat"),
			"cape": Color(0.25, 0.08, 0.1),
		},
		{
			"name": "PRIMEIRA GUERRA MUNDIAL", "year": "1916 d.C.", "style": "ww1",
			"intro": "Lama, trincheiras e arame farpado. Atravesse a terra de ninguém!",
			"sky": [Color(0.4, 0.42, 0.45), Color(0.5, 0.5, 0.5), Color(0.58, 0.56, 0.52), Color(0.65, 0.6, 0.5)],
			"sun": Color(0.85, 0.85, 0.8, 0.4),
			"thug": _look("RECRUTA", Color(0.45, 0.42, 0.3), Color(0.4, 0.37, 0.27), "brodie"),
			"knife": _look("BATEDOR", Color(0.4, 0.4, 0.35), Color(0.35, 0.33, 0.28), "brodie"),
			"brute": _look("GRANADEIRO", Color(0.38, 0.4, 0.42), Color(0.3, 0.32, 0.34), "spike"),
			"boss": _look("GENERAL FERRO", Color(0.32, 0.35, 0.38), Color(0.2, 0.2, 0.22), "spike"),
			"cape": Color(0.2, 0.22, 0.25),
		},
		{
			"name": "SEGUNDA GUERRA MUNDIAL", "year": "1944 d.C.", "style": "ww2",
			"intro": "Uma cidade em ruínas sob holofotes. Avance pelos escombros!",
			"sky": [Color(0.08, 0.08, 0.15), Color(0.15, 0.13, 0.2), Color(0.35, 0.2, 0.18), Color(0.6, 0.3, 0.15)],
			"sun": Color(0.9, 0.9, 0.85, 0.7),
			"thug": _look("INFANTE", Color(0.35, 0.4, 0.3), Color(0.3, 0.33, 0.25), "helmet2"),
			"knife": _look("SABOTADOR", Color(0.2, 0.2, 0.22), Color(0.15, 0.15, 0.17), "beanie"),
			"brute": _look("ARTILHEIRO", Color(0.4, 0.42, 0.35), Color(0.3, 0.3, 0.27), "helmet2"),
			"boss": _look("CORONEL AÇO", Color(0.25, 0.27, 0.28), Color(0.15, 0.15, 0.17), "officer"),
			"cape": Color(0.15, 0.15, 0.17),
		},
		{
			"name": "GUERRA FRIA", "year": "1962 d.C.", "style": "coldwar",
			"intro": "Espiões, muros e segredos. Ninguém atravessa a fronteira sem lutar!",
			"sky": [Color(0.05, 0.06, 0.14), Color(0.08, 0.1, 0.2), Color(0.14, 0.15, 0.26), Color(0.22, 0.2, 0.3)],
			"sun": Color(0.95, 0.95, 1.0),
			"thug": _look("AGENTE", Color(0.15, 0.15, 0.18), Color(0.12, 0.12, 0.15), "shades"),
			"knife": _look("ESPIÃ", Color(0.45, 0.1, 0.15), Color(0.12, 0.1, 0.12), "beret"),
			"brute": _look("GUARDA", Color(0.3, 0.35, 0.3), Color(0.25, 0.28, 0.24), "ushanka"),
			"boss": _look("AGENTE ZERO", Color(0.85, 0.85, 0.85), Color(0.1, 0.1, 0.12), "shades"),
			"cape": Color(0.25, 0.22, 0.18),
		},
		{
			"name": "TEMPO ATUAL", "year": "2026 d.C.", "style": "modern",
			"intro": "De volta ao presente... mas as ruas foram tomadas por gangues!",
			"sky": [Color(0.16, 0.08, 0.3), Color(0.35, 0.12, 0.38), Color(0.62, 0.2, 0.38), Color(0.92, 0.42, 0.3)],
			"sun": Color(1.0, 0.75, 0.35),
			"thug": _look("GALO", Color(0.45, 0.55, 0.25), Color(0.25, 0.22, 0.2), "mohawk"),
			"knife": _look("VÍBORA", Color(0.55, 0.2, 0.65), Color(0.15, 0.12, 0.2), "cap", Color(0.96, 0.76, 0.6), Color(0.9, 0.8, 0.2)),
			"brute": _look("TANQUE", Color(0.3, 0.3, 0.35), Color(0.35, 0.2, 0.12), "bald", Color(0.62, 0.42, 0.3)),
			"boss": _look("CHEFE MARRETA", Color(0.75, 0.1, 0.15), Color(0.1, 0.1, 0.12), "bald", Color(0.85, 0.62, 0.48)),
			"cape": Color(0, 0, 0, 0),
		},
		{
			"name": "FUTURO: TUDO DEU CERTO", "year": "2250 d.C.", "style": "utopia",
			"intro": "Uma utopia limpa e brilhante... onde os androides de segurança enlouqueceram!",
			"sky": [Color(0.35, 0.7, 0.95), Color(0.55, 0.82, 0.98), Color(0.8, 0.93, 1.0), Color(0.95, 0.98, 1.0)],
			"sun": Color(1, 1, 0.92),
			"thug": _look("ANDROIDE", Color(0.92, 0.94, 0.97), Color(0.75, 0.8, 0.88), "visor", metal),
			"knife": _look("DRONE-K", Color(0.3, 0.85, 0.9), Color(0.85, 0.9, 0.95), "visor", metal),
			"brute": _look("SENTINELA", Color(0.85, 0.88, 0.92), Color(0.6, 0.65, 0.72), "robot", metal),
			"boss": _look("IA AURORA", Color(0.95, 0.95, 1.0), Color(0.5, 0.85, 0.95), "halo", Color(0.85, 0.95, 1.0)),
			"cape": Color(0.6, 0.95, 1.0, 0.7),
		},
		{
			"name": "FUTURO: TUDO DEU ERRADO", "year": "2350 d.C.", "style": "dystopia",
			"intro": "Megacorporações, chuva ácida e saqueadores. O futuro apodreceu.",
			"sky": [Color(0.12, 0.04, 0.06), Color(0.3, 0.08, 0.08), Color(0.5, 0.15, 0.1), Color(0.65, 0.3, 0.12)],
			"sun": Color(0.9, 0.3, 0.15, 0.6),
			"thug": _look("SAQUEADOR", Color(0.4, 0.3, 0.25), Color(0.25, 0.2, 0.18), "goggles"),
			"knife": _look("CIBORGUE", Color(0.25, 0.25, 0.3), Color(0.15, 0.15, 0.18), "robot", Color(0.6, 0.55, 0.55)),
			"brute": _look("CARNIÇA", Color(0.35, 0.25, 0.2), Color(0.3, 0.2, 0.15), "goggles", Color(0.7, 0.5, 0.4)),
			"boss": _look("REI DA SUCATA", Color(0.55, 0.4, 0.15), Color(0.25, 0.2, 0.15), "crown", Color(0.65, 0.55, 0.5)),
			"cape": Color(0.4, 0.12, 0.08),
		},
		{
			"name": "FUTURO: DEU MUITO ERRADO", "year": "3000 d.C.", "style": "apocalypse",
			"intro": "O fim dos tempos. A Lua se partiu. CRONOS espera no centro do caos.",
			"sky": [Color(0.03, 0.0, 0.05), Color(0.1, 0.02, 0.15), Color(0.25, 0.04, 0.2), Color(0.5, 0.1, 0.1)],
			"sun": Color(0.85, 0.8, 0.95),
			"thug": _look("MUTANTE", Color(0.3, 0.25, 0.3), Color(0.2, 0.15, 0.2), "horns", Color(0.5, 0.75, 0.4)),
			"knife": _look("ESPECTRO", Color(0.2, 0.1, 0.3), Color(0.12, 0.05, 0.18), "hood", Color(0.6, 0.55, 0.75)),
			"brute": _look("ABOMINAÇÃO", Color(0.4, 0.2, 0.25), Color(0.25, 0.12, 0.15), "horns", Color(0.45, 0.6, 0.35)),
			"boss": _look("CRONOS", Color(0.15, 0.05, 0.25), Color(0.08, 0.02, 0.12), "crown", Color(0.55, 0.5, 0.7)),
			"cape": Color(0.45, 0.0, 0.6),
		},
	]


## Gera as ondas de inimigos da fase (dificuldade cresce com o índice).
static func waves_for(idx: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + idx * 77
	var trig := [700.0, 1450.0, 2250.0, 3050.0]
	var result: Array = []
	for w in 4:
		var count := 3 + int((idx + w) / 3)
		var spawn: Array = []
		var delay := 0.0
		for n in count:
			var r := rng.randf()
			var kind := "thug"
			if w >= 2 and r < 0.18 + idx * 0.02:
				kind = "brute"
			elif r < 0.45 + idx * 0.02 and (w >= 1 or idx >= 2):
				kind = "knife"
			# Garante os 3 tiers: difícil na onda 2, muito difícil na onda 4
			if n == 0 and w == 1:
				kind = "knife"
			elif n == 0 and w == 3:
				kind = "brute"
			var side := 1 if n % 2 == 0 else -1
			spawn.append([kind, side, delay])
			delay += rng.randf_range(0.6, 1.8)
		if w == 2:
			# Sub-chefe no meio da fase
			for e in spawn:
				e[2] += 2.5
			spawn.insert(0, ["subboss", 1, 0.0])
		result.append({"x": trig[w], "spawn": spawn})
	var boss_wave := [["boss", 1, 0.5], ["thug", -1, 4.0], ["knife", 1, 9.0]]
	if idx >= 6:
		boss_wave.append(["brute", -1, 14.0])
	result.append({"x": 3920.0, "spawn": boss_wave})
	return result
