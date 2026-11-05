extends Node
## Conquistas desbloqueáveis (autoload "Ach").
## O progresso fica salvo neste computador (user://achievements.cfg).
##
## Os eventos do jogo chamam track/best/collect/flag com o jogador que fez a ação.
## Jogadores locais atualizam este computador; jogadores online (no anfitrião)
## têm o evento repassado ao computador do convidado, que atualiza o dele.

const SAVE_PATH := "user://achievements.cfg"

## [id, nome, descrição, tipo, estatística, meta, cor]
## tipo: "count" (contador), "max" (melhor valor), "set" (itens diferentes), "flag" (feito único)
const LIST := [
	# Jornada
	["first_stage", "PRIMEIRO SALTO", "Conclua uma era.", "count", "stages", 1, Color(0.5, 0.9, 1)],
	["traveler", "VIAJANTE DO TEMPO", "Conclua 6 eras diferentes.", "set", "eras", 6, Color(0.5, 0.9, 1)],
	["all_eras", "MESTRE DAS ERAS", "Conclua as 12 eras.", "set", "eras", 12, Color(0.4, 0.7, 1)],
	["ending", "GUARDIÃO DO TEMPO", "Chegue ao final da história.", "flag", "ending", 1, Color(1, 0.85, 0.3)],
	["cronos", "O FIM DE CRONOS", "Derrote CRONOS, o chefe final.", "flag", "cronos", 1, Color(0.75, 0.3, 1)],
	["all_chars", "CIDADÃO DO MUNDO", "Conclua uma era com cada um dos 14 lutadores.", "set", "chars", 14, Color(1, 0.6, 0.2)],
	# Combate
	["ko_1", "PRIMEIRO NOCAUTE", "Derrote um inimigo.", "count", "kos", 1, Color(1, 0.5, 0.4)],
	["ko_100", "CEM NOCAUTES", "Derrote 100 inimigos.", "count", "kos", 100, Color(1, 0.45, 0.35)],
	["ko_1000", "MIL NOCAUTES", "Derrote 1000 inimigos.", "count", "kos", 1000, Color(1, 0.3, 0.25)],
	["combo_10", "EMBALADO", "Faça um combo de 10 golpes.", "max", "combo", 10, Color(1, 0.7, 0.3)],
	["combo_25", "IMPARÁVEL", "Faça um combo de 25 golpes.", "max", "combo", 25, Color(1, 0.6, 0.2)],
	["combo_50", "FÚRIA TEMPORAL", "Faça um combo de 50 golpes.", "max", "combo", 50, Color(1, 0.45, 0.1)],
	["sub_1", "CAÇA AO SUB-CHEFE", "Derrote um sub-chefe.", "count", "subs", 1, Color(0.9, 0.5, 0.9)],
	["boss_1", "CAÇADOR DE CHEFES", "Derrote um chefe.", "count", "bosses_n", 1, Color(0.95, 0.35, 0.9)],
	["boss_all", "TERROR DOS TIRANOS", "Derrote os 12 chefes.", "set", "bosses", 12, Color(0.85, 0.2, 0.85)],
	# Armas e golpes
	["weapon_10", "ARSENAL", "Pegue 10 armas.", "count", "weapons", 10, Color(0.6, 0.95, 1)],
	["weapon_all", "COLECIONADOR", "Pegue as 24 armas diferentes das eras.", "set", "weapon_types", 24, Color(0.4, 0.85, 1)],
	["throw_20", "BRAÇO DE OURO", "Acerte 20 inimigos com armas arremessadas.", "count", "throws", 20, Color(0.7, 0.9, 0.5)],
	["special_50", "ESPECIALISTA", "Use 50 golpes especiais.", "count", "specials", 50, Color(1, 0.9, 0.4)],
	["crates_25", "QUEBRA-TUDO", "Quebre 25 caixas.", "count", "crates", 25, Color(0.8, 0.6, 0.35)],
	["food_20", "COMILÃO", "Coma 20 vezes.", "count", "food", 20, Color(0.95, 0.55, 0.3)],
	# Desafios
	["no_death", "SOBREVIVENTE", "Conclua uma era sem perder nenhuma vida.", "flag", "no_death", 1, Color(0.5, 1, 0.6)],
	["untouched", "INTOCÁVEL", "Conclua uma era sem levar nenhum dano.", "flag", "untouched", 1, Color(0.3, 1, 0.8)],
	["last_life", "POR UM FIO", "Conclua uma era com a última vida.", "flag", "last_life", 1, Color(1, 0.4, 0.5)],
	["score_100k", "DONO DA RUA", "Some 100.000 pontos numa partida.", "max", "score", 100000, Color(1, 0.85, 0.3)],
	["score_500k", "LENDA VIVA", "Some 500.000 pontos numa partida.", "max", "score", 500000, Color(1, 0.75, 0.1)],
	# Sobrevivência
	["wave_10", "RESISTENTE", "Chegue à onda 10 da Sobrevivência.", "max", "wave", 10, Color(0.6, 1, 0.5)],
	["wave_25", "INQUEBRÁVEL", "Chegue à onda 25 da Sobrevivência.", "max", "wave", 25, Color(0.45, 0.95, 0.4)],
	["wave_50", "ETERNO", "Chegue à onda 50 da Sobrevivência.", "max", "wave", 50, Color(0.3, 0.85, 0.3)],
	# Multijogador
	["coop_2", "JUNTOS SOMOS FORTES", "Conclua uma era em co-op.", "flag", "coop2", 1, Color(0.5, 0.75, 1)],
	["coop_4", "ESQUADRÃO COMPLETO", "Conclua uma era com 4 jogadores.", "flag", "coop4", 1, Color(0.35, 0.6, 1)],
	["versus_win", "CAMPEÃO DA ARENA", "Vença uma partida no Versus.", "flag", "versus_win", 1, Color(1, 0.5, 0.5)],
	["versus_perfect", "VITÓRIA PERFEITA", "Vença no Versus sem perder nenhum round.", "flag", "versus_perfect", 1, Color(1, 0.3, 0.3)],
	["online", "CONEXÃO GLOBAL", "Jogue uma partida online.", "flag", "online", 1, Color(0.4, 0.9, 1)],
	["top10", "NO PÓDIO", "Entre no Top 10 do ranking online.", "flag", "top10", 1, Color(1, 0.85, 0.3)],
]

var stats := {}       # estatística -> número, ou Array (para "set")
var unlocked := {}    # id -> data (texto)
var toasts: Array = []  # avisos pendentes: [nome, cor, tempo]
var dirty := false
var save_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		stats = cfg.get_value("ach", "stats", {})
		unlocked = cfg.get_value("ach", "unlocked", {})


func _process(delta: float) -> void:
	for tt in toasts:
		tt[2] -= delta
	toasts = toasts.filter(func(x): return x[2] > 0.0)
	save_timer -= delta
	if dirty and save_timer <= 0.0:
		save_now()


func save_now() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ach", "stats", stats)
	cfg.set_value("ach", "unlocked", unlocked)
	cfg.save(SAVE_PATH)
	dirty = false
	save_timer = 1.0


# ---------- API usada pelo jogo ----------
func track(player, stat: String, amount := 1) -> void:
	_route(player, "count", stat, amount)


func best(player, stat: String, value: int) -> void:
	_route(player, "max", stat, value)


func collect(player, stat: String, item) -> void:
	_route(player, "set", stat, item)


func flag(player, stat: String) -> void:
	_route(player, "flag", stat, 1)


## Jogador online (só no anfitrião): repassa ao convidado. Senão, aplica aqui.
func _route(player, kind: String, stat: String, value) -> void:
	if player != null and is_instance_valid(player) and "sets" in player and not player.sets.is_empty():
		var s: String = player.sets[0]
		if s.begins_with("n"):
			if Net.is_host() and Net.game != null:
				Net.game.net_events.append(["a", s, kind, stat, value])
			return
	apply(kind, stat, value)


func apply(kind: String, stat: String, value) -> void:
	match kind:
		"count", "flag":
			stats[stat] = int(stats.get(stat, 0)) + (int(value) if kind == "count" else 0)
			if kind == "flag":
				stats[stat] = 1
		"max":
			stats[stat] = maxi(int(stats.get(stat, 0)), int(value))
		"set":
			var arr: Array = stats.get(stat, [])
			if not (value in arr):
				arr.append(value)
			stats[stat] = arr
	dirty = true
	_check()


func progress(a: Array) -> int:
	var v = stats.get(a[4], 0)
	if v is Array:
		return v.size()
	return int(v)


func is_unlocked(id: String) -> bool:
	return unlocked.has(id)


func unlocked_count() -> int:
	return unlocked.size()


func _check() -> void:
	for a in LIST:
		if unlocked.has(a[0]):
			continue
		if progress(a) >= int(a[5]):
			unlocked[a[0]] = Time.get_date_string_from_system()
			toasts.append([a[1], a[6], 4.0])
			dirty = true
			if Net.game != null and Net.game.sfx != null:
				Net.game.sfx.play("pickup", 0.0)
