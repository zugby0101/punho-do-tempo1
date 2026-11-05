extends Node2D
## Gerenciador do jogo: entrada, câmera, ondas, pontuação, progressão das 12 fases
## e co-op local para até 4 jogadores.

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const CrateScript = preload("res://scripts/crate.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const SparkScript = preload("res://scripts/spark.gd")
const SfxScript = preload("res://scripts/sfx.gd")
const BgScript = preload("res://scripts/background.gd")
const HudScript = preload("res://scripts/hud.gd")
const MusicScript = preload("res://scripts/music.gd")
const Stages = preload("res://scripts/stages.gd")
const Characters = preload("res://scripts/characters.gd")
const Controls = preload("res://scripts/controls.gd")
const Weapons = preload("res://scripts/weapons.gd")
const WeaponItemScript = preload("res://scripts/weapon_item.gd")
const ThrownScript = preload("res://scripts/thrown.gd")
const EnergyScript = preload("res://scripts/energy.gd")
const PopupScript = preload("res://scripts/popup.gd")

const DEPTH_MIN := 360.0
const DEPTH_MAX := 520.0
const STAGE_LEN := 4400.0
const HALF_W := 480.0
const MAX_PLAYERS := 4
const LAST_ERA := 11     # última era normal (CRONOS)
const SECRET_IDX := 12   # fase secreta (ÉON)
const DEFAULT_CHARS := [8, 9, 0, 3]

# Progresso que sobrevive ao recarregar a cena entre fases.
# party: [{char, sets, lives, score}] — um item por jogador.
static var stage_idx := 0
static var party: Array = []
static var skip_title := false
static var game_mode := "story"  # "story" (história/co-op), "versus" ou "survival"
static var survival_start := 0    # era em que a sobrevivência começou (para recomeçar)

const VERSUS_WINS := 2  # rounds para vencer a partida

var stages: Array
var characters: Array
var stage: Dictionary
var waves: Array
var crate_spots := [[480.0, 400.0, "apple"], [900.0, 470.0, "weapon"], [1180.0, 470.0, "chicken"], [1980.0, 390.0, "apple"], [2780.0, 480.0, "chicken"], [3620.0, 420.0, "chicken"]]

var mode := "title"  # title, select, intro, play, stageclear, gameover, ending, roundstart, roundend, match
var versus := false
var round_num := 1
var round_wins: Array = [0, 0, 0, 0]
var round_winner := -1   # -1 = empate
var drop_timer := 0.0

# Sobrevivência
var fragment_got := false   # ganhou um Fragmento do Tempo nesta era
var survival := false
var surv_wave := 0
var surv_queue: Array = []    # [tipo, lado, atraso]
var surv_break := 0.0         # pausa entre ondas
var surv_in_wave := false

# Online
var net_client := false   # este computador é convidado (só desenha o que recebe)
var net_nodes := {}       # convidado: id do anfitrião -> nó local
var net_events: Array = []  # anfitrião: sons/efeitos a repassar
var ip_edit: LineEdit
var input_purpose := "ip"  # ip, code, url
var online_choice := 0
# Ranking online
var ranking_return := "title"   # tela para onde voltar
var score_sent := false
var name_queue: Array = []       # jogadores que ainda vão digitar o nome
var name_entries: Array = []
var ach_page := 0
static var last_names := {}      # pid -> último nome usado
const ONLINE_OPTIONS := [
	["CRIAR SALA", "pelo servidor intermediário — ninguém precisa abrir portas"],
	["ENTRAR EM SALA", "digite o código de 4 letras que o anfitrião recebeu"],
	["HOSPEDAR DIRETO", "conexão por IP (precisa liberar a porta 7777 UDP)"],
	["ENTRAR DIRETO POR IP", "na mesma rede, ou com a porta liberada / VPN"],
	["CONFIGURAR SERVIDOR", "endereço do servidor intermediário (relay)"],
]
var hud_layer: CanvasLayer
var paused := false
var mode_time := 0.0
var cam_x := HALF_W
var locked := false
var wave_idx := 0
var pending: Array = []
var show_go := false
var go_timer := 0.0
var hitstop := 0.0
var shake_amt := 0.0
var combo_count := 0
var combo_timer := 0.0
var ending_page := 0

var players: Array = []
var slots: Array = []   # tela de seleção: [{sets, char, ready, node}]
var player              # atalho para o P1
var entities: Node2D
var effects: Node2D
var camera: Camera2D
var hud
var sfx
var music
var bg


func _ready() -> void:
	randomize()
	Controls.setup()
	stages = Stages.list() + [Stages.secret()]
	characters = Characters.list()
	stage = stages[stage_idx]
	waves = Stages.waves_for(stage_idx)

	sfx = SfxScript.new()
	add_child(sfx)
	music = MusicScript.new()
	add_child(music)
	bg = BgScript.new()
	bg.game = self
	bg.stage = stage
	bg.z_index = -100
	add_child(bg)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	effects = Node2D.new()
	effects.z_index = 50
	add_child(effects)
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud_layer = layer
	hud = HudScript.new()
	hud.game = self
	layer.add_child(hud)
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)

	versus = game_mode == "versus"
	survival = game_mode == "survival"
	Net.game = self
	if Net.is_client():
		Net.close()
	if Net.is_host() and not skip_title:
		Net.close()  # voltou ao título: encerra a partida online
	sfx.hook = func(n):
		if Net.is_host() and not Net.peer_sets.is_empty():
			net_events.append(["s", n])
	for c in crate_spots:
		if versus or survival:
			break
		var cr = CrateScript.new()
		cr.game = self
		cr.position = Vector2(c[0], c[1])
		cr.drop = c[2]
		cr.add_to_group("breakables")
		entities.add_child(cr)
	_update_camera(0.0)
	if skip_title and not party.is_empty():
		_spawn_party()
		if versus:
			_start_round()
		elif survival:
			_start_survival()
		else:
			_set_mode("intro")
			_play_stage_music(false)
	else:
		party = []
		_set_mode("title")
		music.play("title", 0)
	music.prefetch(stage.style, stage_idx, false)
	music.prefetch(stage.style, stage_idx, true)


# ---------- Jogadores ----------
func _make_player(pid: int, char_i: int, sets: Array):
	var p = PlayerScript.new()
	p.game = self
	p.pid = pid
	p.sets = sets
	p.add_to_group("players")
	p.apply_character(characters[char_i])
	entities.add_child(p)
	return p


func _flag_online() -> void:
	if Net.online():
		for p in players:
			Ach.flag(p, "online")


func _spawn_party() -> void:
	for i in party.size():
		var info: Dictionary = party[i]
		var p = _make_player(i, info.char, info.sets)
		p.lives = info.lives
		p.score = info.score
		p.start_lives = info.lives
		p.position = Vector2(200.0 + i * 25.0, 375.0 + i * 40.0)
		players.append(p)
	player = players[0]


func _save_party() -> void:
	party = []
	for p in players:
		party.append({"char": _char_of(p), "sets": p.sets, "lives": p.lives, "score": p.score})


func _char_of(p) -> int:
	for i in characters.size():
		if characters[i].name == p.display_name:
			return i
	return 0


## Jogadores em campo (não eliminados).
func active_players() -> Array:
	var arr: Array = []
	for p in players:
		if is_instance_valid(p) and not p.out and p.is_alive():
			arr.append(p)
	return arr


## Jogador mais próximo que pode ser perseguido (ignora quem está caído).
func nearest_player(pos: Vector2):
	var best = null
	var bd := INF
	for p in active_players():
		if p.state in ["down", "dead"]:
			continue
		var d := pos.distance_squared_to(p.position)
		if d < bd:
			bd = d
			best = p
	return best


func _set_mode(m: String) -> void:
	mode = m
	mode_time = 0.0


func is_frozen() -> bool:
	return mode in ["title", "select", "intro", "ending", "roundstart", "match", "ranking", "name_entry", "achievements"] or paused or hitstop > 0.0


func cam_left() -> float:
	return cam_x - HALF_W


func cam_right() -> float:
	return cam_x + HALF_W


func _confirm() -> bool:
	return Input.is_action_just_pressed("start") or Input.is_action_just_pressed("attack") or Controls.any_remote_just(["attack", "start"])


func _physics_process(delta: float) -> void:
	if net_client:
		_client_tick(delta)
		return
	if Net.is_host():
		Controls.net_update()
		Net.host_tick()
	mode_time += delta
	match mode:
		"join_input":
			if Input.is_physical_key_pressed(KEY_ESCAPE):
				_close_ip_edit()
				_set_mode("online_menu")
			return
		"ranking":
			if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
				Net.fetch_ranking("survival" if Net.ranking_board == "story" else "story")
				sfx.play("whoosh", 0.0)
				return
			if mode_time > 0.4 and (Input.is_physical_key_pressed(KEY_ESCAPE) or _confirm() or Input.is_action_just_pressed("ranking")):
				_set_mode(ranking_return)
				mode_time = 2.0  # volta direto, sem esperar a animação
			return
		"achievements":
			var pages := int(ceil(Ach.LIST.size() / 16.0))
			if Input.is_action_just_pressed("move_right"):
				ach_page = (ach_page + 1) % pages
				sfx.play("whoosh", 0.0)
			elif Input.is_action_just_pressed("move_left"):
				ach_page = posmod(ach_page - 1, pages)
				sfx.play("whoosh", 0.0)
			elif mode_time > 0.4 and (Input.is_physical_key_pressed(KEY_ESCAPE) or _confirm() or Input.is_action_just_pressed("achievements")):
				_set_mode("title")
			return
		"name_entry":
			if Input.is_physical_key_pressed(KEY_ESCAPE):
				_close_ip_edit()
				_set_mode(ranking_return)
				mode_time = 2.0
			return
		"online_menu":
			_update_online_menu()
			return
		"connecting":
			# anfitrião esperando o servidor criar a sala
			if Input.is_physical_key_pressed(KEY_ESCAPE):
				Net.close()
				_set_mode("title")
			return
		"title":
			if Input.is_action_just_pressed("ranking"):
				_open_ranking("title")
				return
			if Input.is_action_just_pressed("achievements"):
				ach_page = 0
				_set_mode("achievements")
				sfx.play("go", 0.0)
				return
			if Input.is_action_just_pressed("net_host") or Input.is_action_just_pressed("net_join"):
				online_choice = 0
				_set_mode("online_menu")
				sfx.play("go", 0.0)
				return
			if Input.is_action_just_pressed("move_up") or Input.is_action_just_pressed("move_down"):
				var modes := ["story", "versus", "survival"]
				var step := 1 if Input.is_action_just_pressed("move_down") else -1
				game_mode = modes[posmod(modes.find(game_mode) + step, modes.size())]
				versus = game_mode == "versus"
				survival = game_mode == "survival"
				sfx.play("whoosh", 0.0)
			elif Input.is_action_just_pressed("move_right"):
				_change_stage(1)
			elif Input.is_action_just_pressed("move_left"):
				_change_stage(-1)
			elif mode_time > 0.3:
				var who := Controls.who_pressed(["attack", "start"])
				if who != "":
					sfx.play("go", 0.0)
					_set_mode("select")
					_add_slot(who)
			return
		"select":
			_update_select()
			return
		"intro":
			if mode_time > 3.5 or (mode_time > 0.6 and _confirm()):
				_set_mode("play")
				hud.show_message("LUTE!", 1.2)
				_flag_online()
			return
		"stageclear":
			if mode_time > 1.5 and _confirm():
				_save_party()
				stage_idx += 1
				skip_title = true
				get_tree().reload_current_scene()
			return
		"gameover":
			if Input.is_action_just_pressed("ranking") and not score_sent and not versus:
				_start_score_entry("gameover")
				Net.ranking_board = "survival" if survival else "story"
				return
			if mode_time > 1.0 and _confirm():
				# Continua na mesma fase, com vidas cheias (na sobrevivência, recomeça da onda 1)
				if survival:
					stage_idx = survival_start
				_save_party()
				for info in party:
					info.lives = 3
					info.score = 0
				skip_title = true
				get_tree().reload_current_scene()
			return
		"roundstart":
			if mode_time > 1.8:
				_set_mode("play")
				hud.show_message("LUTEM!", 0.9)
				_flag_online()
				sfx.play("go", 0.0)
			return
		"match":
			if mode_time > 1.5 and _confirm():
				# Revanche com os mesmos lutadores
				_save_party()
				skip_title = true
				get_tree().reload_current_scene()
			elif mode_time > 1.0 and Input.is_action_just_pressed("pause"):
				party = []
				skip_title = false
				get_tree().reload_current_scene()
			return
		"ending":
			if Input.is_action_just_pressed("ranking") and not score_sent:
				_start_score_entry("ending")
				return
			if mode_time > 2.0 and _confirm():
				ending_page += 1
				if ending_page >= players.size():
					stage_idx = 0
					party = []
					skip_title = false
					get_tree().reload_current_scene()
				else:
					_show_ending_page()
			return

	if Input.is_action_just_pressed("pause"):
		paused = not paused
	if paused:
		return

	if versus:
		_update_versus(delta)
		return
	if survival:
		_update_survival(delta)
		return

	# Jogador eliminado pode continuar enquanto o grupo segue vivo
	for p in players:
		if p.out and Controls.just(p.sets, "attack"):
			p.lives = 3
			p.score = 0
			p.start_lives = 99  # continuou: não vale "Sobrevivente" nesta era
			p.respawn()
			hud.show_message("P%d VOLTOU!" % (p.pid + 1), 1.2)
			sfx.play("go", 0.0)

	if hitstop > 0.0:
		hitstop -= delta
		_update_camera(delta)
		return

	combo_timer -= delta
	if combo_timer <= 0.0:
		combo_count = 0

	_update_camera(delta)
	_update_waves(delta)
	_assign_aggression()
	_check_pickups()

	if show_go:
		go_timer -= delta
		if go_timer <= 0.0:
			show_go = false


# ---------- Tela de seleção (entrar no jogo) ----------
func _set_owned(set_name: String) -> bool:
	for sl in slots:
		if set_name in sl.sets:
			return true
	return false


func _add_slot(set_name: String) -> void:
	if slots.size() >= MAX_PLAYERS:
		return
	var idx := slots.size()
	var char_i: int = DEFAULT_CHARS[idx]
	if _taken(char_i, -1):
		char_i = _next_free(char_i, 1, -1)
	var node = _make_player(idx, char_i, [set_name])
	slots.append({"sets": [set_name], "char": char_i, "ready": false, "node": node, "t": mode_time})
	_update_preview(idx)
	sfx.play("go", 0.0)


## Cada personagem só pode ser escolhido por um jogador.
func _taken(char_i: int, except_slot: int) -> bool:
	for k in slots.size():
		if k != except_slot and slots[k].char == char_i:
			return true
	return false


func _next_free(from: int, step: int, slot: int) -> int:
	var c := from
	for _n in characters.size():
		c = posmod(c + step, characters.size())
		if not _taken(c, slot):
			return c
	return from


func _update_preview(i: int) -> void:
	var sl: Dictionary = slots[i]
	var node = sl.node
	node.apply_character(characters[sl.char])
	node.body_scale *= 1.25
	node.position = Vector2(cam_left() + 8.0 + i * 238.0 + 190.0, 522.0)
	node.facing = -1


func _update_select() -> void:
	# Novos jogadores entram apertando soco/start no próprio controle
	var free: Array = []
	for s in Controls.join_sets():
		if not _set_owned(s):
			free.append(s)
	var joiner := Controls.who_pressed(["attack", "start"], free)
	if joiner != "" and mode_time > 0.2:
		_add_slot(joiner)

	for i in slots.size():
		var sl: Dictionary = slots[i]
		var sets: Array = sl.sets
		if sl.ready:
			if Controls.just(sets, "jump"):
				sl.ready = false
				sfx.play("whoosh", 0.0)
			continue
		var moved := -1
		if Controls.just(sets, "right"):
			moved = _next_free(sl.char, 2, i)
		elif Controls.just(sets, "left"):
			moved = _next_free(sl.char, -2, i)
		elif Controls.just(sets, "down") or Controls.just(sets, "up"):
			moved = sl.char ^ 1
			if _taken(moved, i):
				moved = -1
		if moved >= 0:
			sl.char = moved
			_update_preview(i)
			sfx.play("whoosh", 0.0)
		elif mode_time - float(sl.t) > 0.3 and (Controls.just(sets, "attack") or Controls.just(sets, "start")):
			sl.ready = true
			sfx.play("pickup", 0.0)

	var all_ready := not slots.is_empty()
	for sl in slots:
		all_ready = all_ready and sl.ready
	if versus and slots.size() < 2:
		all_ready = false
	if all_ready:
		_start_game()


func _start_game() -> void:
	party = []
	for sl in slots:
		party.append({"char": sl.char, "sets": sl.sets, "lives": 3, "score": 0})
		sl.node.queue_free()
	slots = []
	# Jogando sozinho, todos os teclados e controles comandam o P1
	if party.size() == 1 and not Net.online():
		party[0].sets = Controls.all_sets()
	_spawn_party()
	sfx.play("start", 0.0)
	if versus:
		_start_round()
	elif survival:
		survival_start = stage_idx
		_start_survival()
	else:
		_play_stage_music(false)
		_set_mode("intro")


func party_names() -> String:
	var names: Array = []
	for p in players:
		names.append(p.display_name)
	if names.size() <= 1:
		return names[0] if names.size() == 1 else ""
	return ", ".join(names.slice(0, names.size() - 1)) + " e " + names[-1]


func _play_stage_music(intense: bool) -> void:
	music.play(stage.style, stage_idx, intense)


func _change_stage(d: int) -> void:
	# a fase secreta só aparece na lista depois de desbloqueada
	stage_idx = posmod(stage_idx + d, stages.size() if secret_unlocked() else SECRET_IDX)
	stage = stages[stage_idx]
	waves = Stages.waves_for(stage_idx)
	bg.stage = stage
	sfx.play("whoosh", 0.0)


# ---------- Câmera e ondas ----------
func _update_camera(delta: float) -> void:
	var act := active_players()
	if not locked and not act.is_empty():
		var min_x := INF
		var max_x := -INF
		for p in act:
			min_x = minf(min_x, p.position.x)
			max_x = maxf(max_x, p.position.x)
		# avança com quem está na frente, sem deixar ninguém para trás
		var desired := minf(max_x + 60.0, min_x + HALF_W - 40.0)
		if desired > cam_x:
			cam_x = move_toward(cam_x, desired, 500.0 * delta)
		cam_x = minf(cam_x, STAGE_LEN - HALF_W)
	shake_amt = move_toward(shake_amt, 0.0, 40.0 * delta)
	var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt
	camera.position = Vector2(cam_x, 270.0) + off


func _update_waves(delta: float) -> void:
	if not locked:
		if wave_idx < waves.size() and cam_x >= waves[wave_idx].x:
			cam_x = waves[wave_idx].x
			locked = true
			show_go = false
			pending = []
			var base: Array = waves[wave_idx].spawn
			for s in base:
				pending.append(s.duplicate())
			# Mais jogadores = mais capangas
			var grunts: Array = base.filter(func(s): return s[0] in ["thug", "knife", "brute"])
			if grunts.is_empty():
				grunts = [["thug", 1, 0.0], ["knife", -1, 0.0]]
			for extra in (players.size() - 1) * 2:
				var src: Array = grunts[extra % grunts.size()].duplicate()
				src[1] = -src[1] if extra % 2 == 0 else src[1]
				src[2] = float(src[2]) + 1.2 + extra * 0.9
				pending.append(src)
		return

	for s in pending:
		s[2] -= delta
		if s[2] <= 0.0:
			_spawn_enemy(s[0], s[1])
	pending = pending.filter(func(item): return item[2] > 0.0)

	if pending.is_empty() and _alive_enemies().is_empty():
		locked = false
		wave_idx += 1
		if wave_idx >= waves.size():
			_stage_cleared()
		else:
			show_go = true
			go_timer = 3.5
			sfx.play("go", 0.0)


func _stage_cleared() -> void:
	for p in players:
		if not p.out:
			p.score += 2000 + p.lives * 1000
			# Conquistas de fim de era
			Ach.track(p, "stages")
			Ach.collect(p, "eras", stage_idx)
			Ach.collect(p, "chars", p.display_name)
			Ach.best(p, "score", p.score)
			if p.lives >= p.start_lives:
				Ach.flag(p, "no_death")
			if p.damage_taken == 0:
				Ach.flag(p, "untouched")
			if p.lives == 1:
				Ach.flag(p, "last_life")
			if players.size() >= 2:
				Ach.flag(p, "coop2")
			if players.size() >= 4:
				Ach.flag(p, "coop4")
			if stage_idx == LAST_ERA or stage_idx == SECRET_IDX:
				Ach.flag(p, "ending")
			if stage_idx == SECRET_IDX:
				Ach.flag(p, "eon")
			# Fragmento do Tempo: concluir a era sem perder nenhuma vida
			if stage_idx <= LAST_ERA and p.lives >= p.start_lives:
				if not (stage_idx in Ach.stats.get("fragments", [])):
					fragment_got = true
				Ach.collect(p, "fragments", stage_idx)
			p.start_lives = p.lives
			p.damage_taken = 0
	music.stop()
	sfx.play("start", 0.0)
	# Depois de CRONOS: com os 12 fragmentos, a fenda para a fase secreta se abre
	var finished := stage_idx == SECRET_IDX or (stage_idx == LAST_ERA and not secret_unlocked())
	if finished:
		_set_mode("ending")
		music.play("title", 0)
		ending_page = 0
		_show_ending_page()
	else:
		_set_mode("stageclear")


## Tela final: uma página com o final de cada jogador.
func _show_ending_page() -> void:
	mode_time = 0.0
	for i in players.size():
		var p = players[i]
		p.out = i != ending_page
		if i == ending_page:
			p.apply_character(characters[_char_of(p)])
			p.body_scale *= 2.0
			p.position = Vector2(cam_left() + 780.0, 480.0)
			p.facing = -1
			p.height = 0.0
			p.vz = 0.0
			p.set_state("idle")
			p.vel = Vector2.ZERO
		p.queue_redraw()


func _spawn_enemy(kind: String, side: int):
	var e = EnemyScript.new()
	e.game = self
	e.add_to_group("enemies")
	e.setup(kind, stage, stage_idx)
	# Mais vida com mais jogadores
	var mult := 1.0 + 0.35 * (players.size() - 1)
	e.max_hp = int(e.max_hp * mult)
	e.hp = e.max_hp
	e.position = Vector2(cam_x + side * (HALF_W + 60.0), randf_range(DEPTH_MIN + 10.0, DEPTH_MAX - 10.0))
	e.facing = -side
	entities.add_child(e)
	if e.is_boss():
		_play_stage_music(true)
	if kind == "secret_boss":
		hud.show_message("CHEFE SECRETO: " + e.display_name, 3.0)
		hud.show_enemy(e)
		sfx.play("roar", 0.0)
		shake(12.0)
	elif kind == "boss":
		hud.show_message("CHEFE: " + e.display_name, 2.5)
		hud.show_enemy(e)
		sfx.play("roar", 0.0)
	elif kind == "subboss":
		hud.show_message("SUB-CHEFE: " + e.display_name, 2.2)
		hud.show_enemy(e)
		sfx.play("roar", 0.0)
	return e


func _alive_enemies() -> Array:
	var arr: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive():
			arr.append(e)
	return arr


## Chefes sempre atacam; dos demais, só alguns atacam ao mesmo tempo
## (1 + número de jogadores); os outros rodeiam.
func _assign_aggression() -> void:
	var list := _alive_enemies()
	var dist := func(e) -> float:
		var tg = nearest_player(e.position)
		return e.position.distance_to(tg.position) if tg != null else INF
	list.sort_custom(func(a, b): return dist.call(a) < dist.call(b))
	var slots_left := 1 + active_players().size()
	for e in list:
		if e.is_boss():
			e.aggressive = true
		elif slots_left > 0:
			e.aggressive = true
			slots_left -= 1
		else:
			e.aggressive = false


func _check_pickups() -> void:
	for pl in active_players():
		if pl.height > 10.0:
			continue
		for p in get_tree().get_nodes_in_group("pickups"):
			if p.is_queued_for_deletion():
				continue
			if absf(p.position.x - pl.position.x) < 30.0 and absf(p.position.y - pl.position.y) < 18.0:
				pl.hp = mini(pl.max_hp, pl.hp + p.heal)
				pl.score += 200
				Ach.track(pl, "food")
				sfx.play("pickup", 0.0)
				p.queue_free()


# ---------- Eventos de combate ----------
func on_hit(attacker, target, atk: Dictionary) -> void:
	var heavy: bool = atk.get("heavy", false)
	hitstop = 0.09 if heavy else 0.05
	shake(6.0 if heavy else 2.5)
	var s: float = target.get("body_scale") if target.get("body_scale") != null else 1.0
	var pos: Vector2 = target.position + Vector2(-attacker.facing * 6.0, -58.0 * s - target.height)
	var by_player: bool = attacker in players
	spawn_spark(pos, attacker.color() if by_player and players.size() > 1 else (Color(1, 0.95, 0.5) if by_player else Color(1, 0.4, 0.3)), 1.3 if heavy else 1.0)
	sfx.play("heavy" if heavy else "hit")
	if by_player:
		attacker.score += int(atk.dmg) * 10
		combo_count += 1
		combo_timer = 1.2
		Ach.best(attacker, "combo", combo_count)
		if target.get_script() == CrateScript and target.hp <= 0:
			Ach.track(attacker, "crates")
		if "last_hitter" in target:
			target.last_hitter = attacker


func on_enemy_killed(e) -> void:
	var killer = e.last_hitter if e.last_hitter != null and is_instance_valid(e.last_hitter) else null
	if killer != null:
		killer.score += e.score_value
		Ach.track(killer, "kos")
		Ach.best(killer, "score", killer.score)
	# Chefes contam para todo o grupo
	if e.kind in ["boss", "subboss", "secret_boss"]:
		for p in players:
			if e.kind in ["boss", "secret_boss"]:
				Ach.track(p, "bosses_n")
				Ach.collect(p, "bosses", stage_idx)
				if stage_idx == LAST_ERA and e.kind == "boss":
					Ach.flag(p, "cronos")
				if e.kind == "secret_boss":
					Ach.flag(p, "eon")
			else:
				Ach.track(p, "subs")
	sfx.play("ko")
	if e.kind == "subboss":
		hitstop = 0.25
		shake(10.0)
		hud.show_message("SUB-CHEFE DERROTADO!", 2.0)
		_play_stage_music(false)
	elif e.kind in ["boss", "secret_boss"]:
		hitstop = 0.4
		shake(14.0)
		hud.show_message("K.O.!", 2.5)
		pending.clear()
		# Os capangas restantes caem junto com o chefe
		for o in _alive_enemies():
			o.take_hit(999, 1 if o.position.x > e.position.x else -1, true)


func player_died(p) -> void:
	if versus:
		p.set_state("dead")
		p.state_time = -999.0
		p.out = true
		sfx.play("ko", 0.0)
		hitstop = 0.3
		shake(10.0)
		return
	p.lives -= 1
	if p.lives > 0:
		p.respawn()
		hud.show_message("P%d: %d VIDAS" % [p.pid + 1, p.lives] if players.size() > 1 else "VIDAS: %d" % p.lives, 1.5)
		for e in _alive_enemies():
			if absf(e.position.x - p.position.x) < 250.0 and e.can_be_hit():
				e.take_hit(0, 1 if e.position.x > p.position.x else -1, true, 0.8)
	else:
		p.set_state("dead")
		p.state_time = -999.0
		p.out = true
		sfx.play("ko", 0.0)
		if active_players().is_empty():
			if survival:
				for pl in players:
					Ach.best(pl, "score", pl.score)
			_set_mode("gameover")
			music.stop()
		else:
			hud.show_message("P%d FORA! (soco para continuar)" % (p.pid + 1), 2.0)


func shake(amount: float) -> void:
	shake_amt = maxf(shake_amt, amount)


func spawn_spark(pos: Vector2, col: Color, size: float = 1.0) -> void:
	if Net.is_host() and not Net.peer_sets.is_empty():
		net_events.append(["k", pos.x, pos.y, col, size])
	var sp = SparkScript.new()
	sp.position = pos
	sp.col = col
	sp.size = size
	effects.add_child(sp)


func spawn_pickup(kind: String, pos: Vector2) -> void:
	if kind == "weapon":
		spawn_weapon_item(Weapons.equip(Weapons.for_stage(stage_idx)[1]), pos, 1, 10.0)
		return
	var p = PickupScript.new()
	p.kind = kind
	p.heal = 40 if kind == "chicken" else 15
	p.position = pos
	p.add_to_group("pickups")
	entities.add_child(p)


# ---------- Armas ----------
func spawn_weapon_item(w: Dictionary, pos: Vector2, dir: int, h: float = 0.0) -> void:
	var it = WeaponItemScript.new()
	it.game = self
	it.weapon = w
	it.position = pos
	it.add_to_group("weapons")
	entities.add_child(it)
	it.toss(float(dir))
	it.height = maxf(h, 1.0)


func weapon_near(p):
	for it in get_tree().get_nodes_in_group("weapons"):
		if it.is_queued_for_deletion() or not it.can_pick():
			continue
		if absf(it.position.x - p.position.x) < 38.0 and absf(it.position.y - p.position.y) < 20.0:
			return it
	return null


func throw_weapon(p, w: Dictionary) -> void:
	var th = ThrownScript.new()
	th.game = self
	th.owner_player = p
	th.weapon = w
	th.dir = p.facing
	th.position = p.position + Vector2(p.facing * 20.0, 0)
	entities.add_child(th)


# ---------- Golpes especiais ----------
func spawn_energy(p, kind: String, dir: int, sp: Dictionary):
	var e = EnergyScript.new()
	e.game = self
	e.owner_player = p
	e.kind = kind
	e.dir = dir
	e.dmg = int(sp.dmg)
	e.speed = float(sp.get("speed", 500.0))
	e.color = sp.color
	if kind == "wave":
		e.height = 0.0
		e.life = 0.9
	e.position = p.position + Vector2(dir * 30.0, 2.0)
	entities.add_child(e)
	return e


func popup(text: String, pos: Vector2, col: Color) -> void:
	if Net.is_host() and not Net.peer_sets.is_empty():
		net_events.append(["p", text, pos.x, pos.y, col])
	var pp = PopupScript.new()
	pp.text = text
	pp.color = col
	pp.position = pos
	effects.add_child(pp)


# ---------- Modo Versus ----------
## Alvos de um golpe: inimigos e caixas; no Versus, também os outros jogadores.
func hit_targets_for(attacker) -> Array:
	var arr: Array = _alive_enemies()
	arr.append_array(get_tree().get_nodes_in_group("breakables"))
	if versus:
		for p in active_players():
			if p != attacker:
				arr.append(p)
	return arr


func _start_round() -> void:
	# limpa a arena
	for grp in ["weapons", "pickups", "breakables"]:
		for n in get_tree().get_nodes_in_group(grp):
			n.queue_free()
	for n in entities.get_children():
		if n.get_script() in [ThrownScript, EnergyScript]:
			n.queue_free()
	cam_x = HALF_W
	locked = true
	var spots := [Vector2(170, 400), Vector2(790, 400), Vector2(170, 490), Vector2(790, 490)]
	for i in players.size():
		var p = players[i]
		p.out = false
		p.hp = p.max_hp
		p.weapon = {}
		p._on_weapon_changed()
		p.attack = {}
		p.vel = Vector2.ZERO
		p.height = 0.0
		p.vz = 0.0
		p.invuln = 0.0
		p.set_state("idle")
		p.position = spots[i] + Vector2(cam_left(), 0)
		p.facing = 1 if spots[i].x < HALF_W else -1
	drop_timer = 6.0
	round_winner = -1
	music.play(stage.style, stage_idx, true)
	_set_mode("roundstart")


func _update_versus(delta: float) -> void:
	if hitstop > 0.0:
		hitstop -= delta
		_update_camera(delta)
		return
	combo_timer -= delta
	if combo_timer <= 0.0:
		combo_count = 0
	_update_camera(delta)
	_check_pickups()
	if mode == "roundend":
		if mode_time > 2.8:
			if round_winner >= 0 and round_wins[round_winner] >= VERSUS_WINS:
				var champ = _versus_champion()
				if champ != null:
					Ach.flag(champ, "versus_win")
					var others_won := 0
					for p in players:
						if p != champ:
							others_won += round_wins[p.pid]
					if others_won == 0:
						Ach.flag(champ, "versus_perfect")
				_set_mode("match")
				music.play("title", 0)
				sfx.play("start", 0.0)
			else:
				round_num += 1
				_start_round()
		return
	# Armas e comida caem do céu de tempos em tempos
	drop_timer -= delta
	if drop_timer <= 0.0:
		drop_timer = randf_range(7.0, 11.0)
		var pos := Vector2(randf_range(cam_left() + 120.0, cam_right() - 120.0), randf_range(DEPTH_MIN + 20.0, DEPTH_MAX - 20.0))
		if randf() < 0.75:
			var ws := Weapons.for_stage(stage_idx)
			spawn_weapon_item(Weapons.equip(ws[randi() % 2]), pos, 1, 260.0)
		else:
			spawn_pickup("apple", pos)
	# Fim do round: sobrou no máximo um de pé
	var alive := active_players()
	if alive.size() <= 1:
		if alive.size() == 1:
			round_winner = alive[0].pid
			round_wins[round_winner] += 1
			alive[0].invuln = 3.0
		else:
			round_winner = -1
		_set_mode("roundend")
		sfx.play("ko", 0.0)


func _versus_champion():
	for p in players:
		if round_wins[p.pid] >= VERSUS_WINS:
			return p
	return null


# =================== Online ===================
func _update_online_menu() -> void:
	if Input.is_physical_key_pressed(KEY_ESCAPE) and mode_time > 0.2:
		_set_mode("title")
		return
	if Input.is_action_just_pressed("move_down"):
		online_choice = (online_choice + 1) % ONLINE_OPTIONS.size()
		sfx.play("whoosh", 0.0)
	elif Input.is_action_just_pressed("move_up"):
		online_choice = posmod(online_choice - 1, ONLINE_OPTIONS.size())
		sfx.play("whoosh", 0.0)
	elif mode_time > 0.25 and (Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("start")):
		sfx.play("go", 0.0)
		match online_choice:
			0:
				if not Net.has_relay():
					_open_ip_edit("url")
				else:
					Net.relay_host()
					_set_mode("connecting")
			1:
				_open_ip_edit("code" if Net.has_relay() else "url")
			2:
				if Net.host():
					_set_mode("select")
					_add_slot("k1")
			3:
				_open_ip_edit("ip")
			4:
				_open_ip_edit("url")


## Anfitrião pelo relay: o servidor criou a sala.
func on_relay_hosted() -> void:
	_set_mode("select")
	_add_slot("k1")


func _open_ip_edit(purpose := "ip") -> void:
	input_purpose = purpose
	_set_mode("join_input")
	ip_edit = LineEdit.new()
	match purpose:
		"ip":
			ip_edit.text = Net.last_ip
			ip_edit.placeholder_text = "IP do anfitrião (ex.: 192.168.0.10)"
		"code":
			ip_edit.text = Net.last_code
			ip_edit.placeholder_text = "Código da sala (ex.: K7QX)"
			ip_edit.max_length = 4
		"url":
			ip_edit.text = Net.relay_url
			ip_edit.placeholder_text = "wss://seu-relay.onrender.com"
	ip_edit.position = Vector2(230, 300)
	ip_edit.size = Vector2(500, 44)
	ip_edit.add_theme_font_size_override("font_size", 24)
	ip_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_layer.add_child(ip_edit)
	ip_edit.grab_focus()
	ip_edit.select_all()
	ip_edit.text_submitted.connect(_on_ip_submitted)


func _close_ip_edit() -> void:
	if ip_edit != null:
		ip_edit.queue_free()
		ip_edit = null


func _on_ip_submitted(text: String) -> void:
	var v := text.strip_edges()
	if input_purpose == "name":
		_on_name_submitted(v)
		return
	if v == "" and input_purpose != "url":
		return
	_close_ip_edit()
	match input_purpose:
		"ip":
			Net.join(v)
		"code":
			Net.relay_join(v)
		"url":
			Net.set_relay_url(v)
			Net.set_status("Servidor configurado: %s" % (Net.relay_url if Net.relay_url != "" else "(nenhum)"), 4.0)
			_set_mode("online_menu")


## Este computador passa a ser convidado: apaga o mundo local e espera o anfitrião.
func become_client() -> void:
	net_client = true
	for n in entities.get_children():
		n.queue_free()
	players = []
	slots = []
	net_nodes.clear()
	music.stop()
	_set_mode("connecting")


## Saiu do online (conexão caiu ou anfitrião encerrou): volta ao título.
func leave_online() -> void:
	party = []
	skip_title = false
	get_tree().reload_current_scene.call_deferred()


func _client_tick(delta: float) -> void:
	mode_time += delta
	Net.client_tick()
	if Input.is_physical_key_pressed(KEY_ESCAPE) and mode in ["connecting", "title"]:
		Net.close()
		leave_online()
		return
	# suaviza o movimento entre pacotes
	for id in net_nodes:
		var n = net_nodes[id]
		if is_instance_valid(n) and n.has_meta("net_target"):
			var tgt: Vector2 = n.get_meta("net_target")
			n.position = tgt if n.position.distance_to(tgt) > 150.0 else n.position.lerp(tgt, 0.45)
	shake_amt = move_toward(shake_amt, 0.0, 40.0 * delta)
	var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt
	camera.position = Vector2(cam_x, 270.0) + off


func _fighter_fields(f) -> Array:
	return [f.position.x, f.position.y, f.height, f.facing, f.state, f.state_time, f.anim_t, f.flash, f.invuln,
		f._current_pose(), f._attack_phase(), f.draw_facing(), f.body_scale, f.hp, f.max_hp, f.weapon]


## Anfitrião: monta o estado completo da partida.
func net_snapshot() -> Array:
	var ents: Array = []
	for n in entities.get_children():
		if n.is_queued_for_deletion():
			continue
		var id := n.get_instance_id()
		var sc = n.get_script()
		if sc == PlayerScript:
			ents.append(["P", id] + _fighter_fields(n) + [_char_of(n), n.pid, n.lives, n.score, n.out])
		elif sc == EnemyScript:
			ents.append(["E", id] + _fighter_fields(n) + [n.kind, n.block_flash, n.tier, n.display_name])
		elif sc == CrateScript:
			ents.append(["C", id, n.position.x, n.position.y, n.hp, n.flash, n.wobble])
		elif sc == PickupScript:
			ents.append(["K", id, n.position.x, n.position.y, n.kind])
		elif sc == WeaponItemScript:
			ents.append(["W", id, n.position.x, n.position.y, n.height, n.life, n.weapon])
		elif sc == ThrownScript:
			ents.append(["T", id, n.position.x, n.position.y, n.height, n.weapon, n.dir])
		elif sc == EnergyScript:
			ents.append(["X", id, n.position.x, n.position.y, n.kind, n.dir, n.color, n.height])
	var slot_s: Array = []
	for sl in slots:
		slot_s.append([sl.char, sl.ready, sl.sets[0], sl.node.get_instance_id()])
	var pids: Array = []
	for p in players:
		pids.append(p.get_instance_id())
	var enemy_id := 0
	if is_instance_valid(hud.enemy_ref):
		enemy_id = hud.enemy_ref.get_instance_id()
	var music_key: String = music.current if music.player.playing or music.want != "" else ""
	if music.want != "":
		music_key = music.want
	var ev := net_events
	net_events = []
	return [mode, mode_time, stage_idx, paused, combo_count, combo_timer, show_go, cam_x, shake_amt,
		round_num, round_wins, round_winner, ending_page, game_mode, slot_s,
		hud.message, hud.message_timer, enemy_id, hud.enemy_timer, pids, music_key, ev, ents, surv_wave]


func _apply_fighter(n, d: Array, i: int) -> int:
	n.set_meta("net_target", Vector2(d[i], d[i + 1]))
	n.height = d[i + 2]
	n.facing = d[i + 3]
	n.state = d[i + 4]
	n.state_time = d[i + 5]
	n.anim_t = d[i + 6]
	n.flash = d[i + 7]
	n.invuln = d[i + 8]
	n.net_pose = d[i + 9]
	n.net_phase = d[i + 10]
	n.net_df = d[i + 11]
	n.body_scale = d[i + 12]
	n.hp = d[i + 13]
	n.max_hp = d[i + 14]
	n.weapon = d[i + 15]
	return i + 16


## Convidado: aplica o estado recebido do anfitrião.
func net_apply(snap: Array) -> void:
	if snap.size() < 23:
		return
	var new_stage: int = snap[2]
	if new_stage != stage_idx or mode == "connecting":
		stage_idx = new_stage
		stage = stages[stage_idx]
		bg.stage = stage
	mode = snap[0]
	mode_time = snap[1]
	paused = snap[3]
	combo_count = snap[4]
	combo_timer = snap[5]
	show_go = snap[6]
	cam_x = snap[7]
	shake_amt = maxf(shake_amt, snap[8])
	round_num = snap[9]
	round_wins = snap[10]
	round_winner = snap[11]
	ending_page = snap[12]
	game_mode = snap[13]
	versus = game_mode == "versus"
	hud.message = snap[15]
	hud.message_timer = snap[16]
	hud.enemy_timer = snap[18]
	survival = game_mode == "survival"
	if snap.size() > 23:
		surv_wave = snap[23]
	# Entidades
	var seen := {}
	for d in snap[22]:
		var id: int = d[1]
		seen[id] = true
		var n = net_nodes.get(id)
		if n == null or not is_instance_valid(n):
			n = _net_create(d)
			if n == null:
				continue
			net_nodes[id] = n
			n.position = Vector2(d[2], d[3])
		match d[0]:
			"P":
				var i := _apply_fighter(n, d, 2)
				if n.get_meta("char", -1) != d[i]:
					var bs: float = n.body_scale
					n.apply_character(characters[d[i]])
					n.body_scale = bs
					n.set_meta("char", d[i])
				n.pid = d[i + 1]
				n.lives = d[i + 2]
				n.score = d[i + 3]
				n.out = d[i + 4]
			"E":
				var i := _apply_fighter(n, d, 2)
				n.block_flash = d[i + 1]
				n.tier = d[i + 2]
				n.display_name = d[i + 3]
			"C":
				n.set_meta("net_target", Vector2(d[2], d[3]))
				n.hp = d[4]
				n.flash = d[5]
				n.wobble = d[6]
			"K":
				n.set_meta("net_target", Vector2(d[2], d[3]))
			"W":
				n.set_meta("net_target", Vector2(d[2], d[3]))
				n.height = d[4]
				n.life = d[5]
				n.weapon = d[6]
			"T":
				n.set_meta("net_target", Vector2(d[2], d[3]))
				n.height = d[4]
				n.weapon = d[5]
				n.dir = d[6]
			"X":
				n.set_meta("net_target", Vector2(d[2], d[3]))
				n.dir = d[5]
				n.color = d[6]
				n.height = d[7]
	for id in net_nodes.keys():
		if not seen.has(id):
			var old = net_nodes[id]
			if is_instance_valid(old):
				old.queue_free()
			net_nodes.erase(id)
	# Jogadores, seleção e barra do inimigo
	players = []
	for pid in snap[19]:
		var pn = net_nodes.get(pid)
		if pn != null and is_instance_valid(pn):
			players.append(pn)
	player = players[0] if not players.is_empty() else null
	slots = []
	for sl in snap[14]:
		slots.append({"char": sl[0], "ready": sl[1], "sets": [sl[2]], "node": net_nodes.get(sl[3]), "t": 0.0})
	var eid: int = snap[17]
	hud.enemy_ref = net_nodes.get(eid) if eid != 0 else null
	# Música
	var mk: String = snap[20]
	if mk == "":
		if music.current != "" or music.want != "":
			music.stop()
	elif mk != music.want and mk != music.current:
		var parts := mk.split(":")
		music.play(parts[0], int(parts[1]), parts[2] == "boss")
	# Sons e efeitos
	for ev in snap[21]:
		match ev[0]:
			"s": sfx.play(ev[1])
			"k": spawn_spark(Vector2(ev[1], ev[2]), ev[3], ev[4])
			"p": popup(ev[1], Vector2(ev[2], ev[3]), ev[4])
			"a":
				if ev[1] == Net.my_set:
					Ach.apply(ev[2], ev[3], ev[4])


func _net_create(d: Array):
	var n = null
	match d[0]:
		"P":
			n = PlayerScript.new()
			n.game = self
			n.add_to_group("players")
		"E":
			n = EnemyScript.new()
			n.game = self
			n.add_to_group("enemies")
			n.setup(d[18], stage, stage_idx)
		"C":
			n = CrateScript.new()
			n.game = self
		"K":
			n = PickupScript.new()
			n.kind = d[4]
		"W":
			n = WeaponItemScript.new()
			n.game = self
			n.weapon = d[6]
		"T":
			n = ThrownScript.new()
			n.game = self
			n.weapon = d[5]
		"X":
			n = EnergyScript.new()
			n.game = self
			n.kind = d[4]
	if n != null:
		entities.add_child(n)
	return n


# =================== Ranking online ===================
func _open_ranking(back_to: String) -> void:
	ranking_return = back_to
	Net.fetch_ranking("survival" if game_mode == "survival" else "story")
	_set_mode("ranking")
	sfx.play("go", 0.0)


## Fim de partida: cada jogador com pontos digita o nome; depois envia tudo.
func _start_score_entry(back_to: String) -> void:
	ranking_return = back_to
	name_queue = []
	name_entries = []
	for p in players:
		if p.score > 0:
			name_queue.append(p)
	if name_queue.is_empty():
		hud.show_message("Nenhuma pontuação para enviar.", 2.0)
		return
	_ask_next_name()


func _ask_next_name() -> void:
	if name_queue.is_empty():
		_close_ip_edit()
		score_sent = true
		Net.submit_scores(name_entries)
		_set_mode("ranking")
		return
	var p = name_queue[0]
	_set_mode("name_entry")
	_close_ip_edit()
	input_purpose = "name"
	ip_edit = LineEdit.new()
	ip_edit.text = last_names.get(p.pid, p.display_name)
	ip_edit.max_length = 12
	ip_edit.placeholder_text = "Seu nome (até 12 letras)"
	ip_edit.position = Vector2(280, 300)
	ip_edit.size = Vector2(400, 44)
	ip_edit.add_theme_font_size_override("font_size", 24)
	ip_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_layer.add_child(ip_edit)
	ip_edit.grab_focus()
	ip_edit.select_all()
	ip_edit.text_submitted.connect(_on_ip_submitted)


func _on_name_submitted(v: String) -> void:
	if v == "" or name_queue.is_empty():
		return
	var p = name_queue.pop_front()
	last_names[p.pid] = v
	name_entries.append({"name": v, "char": p.display_name, "score": int(p.score), "stage": stage_idx + 1,
		"players": players.size(), "done": ranking_return == "ending"})
	if survival:
		name_entries[-1]["board"] = "survival"
		name_entries[-1]["wave"] = maxi(surv_wave, 1)
	sfx.play("pickup", 0.0)
	_ask_next_name()


# =================== Modo Sobrevivência ===================
func _start_survival() -> void:
	cam_x = HALF_W
	locked = true
	surv_wave = 0
	surv_queue = []
	surv_in_wave = false
	surv_break = 2.5
	drop_timer = 9.0
	var spots := [Vector2(220, 400), Vector2(220, 480), Vector2(300, 440), Vector2(140, 440)]
	for i in players.size():
		players[i].position = spots[i] + Vector2(cam_left(), 0)
		players[i].facing = 1
	_play_stage_music(false)
	hud.show_message("SOBREVIVÊNCIA!", 2.0)
	_set_mode("play")
	_flag_online()


## Monta a onda n: mais inimigos, tiers mais fortes, sub-chefe a cada 5 e chefe a cada 10.
func _survival_wave(n: int) -> Array:
	var q: Array = []
	var count := mini(3 + n, 14) + (players.size() - 1) * 2
	var delay := 0.0
	if n % 10 == 0:
		q.append(["boss", 1, 0.5])
		count = maxi(2, count / 2)
		delay = 3.0
	elif n % 5 == 0:
		q.append(["subboss", 1, 0.5])
		count = maxi(2, count * 2 / 3)
		delay = 2.0
	var brute_p := clampf(0.05 * (n - 3), 0.0, 0.35)
	var knife_p := clampf(0.15 + 0.04 * n, 0.0, 0.45)
	for i in count:
		var r := randf()
		var kind := "thug"
		if n >= 4 and r < brute_p:
			kind = "brute"
		elif n >= 2 and r < brute_p + knife_p:
			kind = "knife"
		q.append([kind, 1 if i % 2 == 0 else -1, delay])
		delay += randf_range(0.5, 1.4) / (1.0 + n * 0.03)
	return q


func _update_survival(delta: float) -> void:
	if hitstop > 0.0:
		hitstop -= delta
		_update_camera(delta)
		return
	combo_timer -= delta
	if combo_timer <= 0.0:
		combo_count = 0
	_update_camera(delta)
	_assign_aggression()
	_check_pickups()
	# Armas caem do céu de vez em quando
	drop_timer -= delta
	if drop_timer <= 0.0:
		drop_timer = randf_range(9.0, 14.0)
		var pos := Vector2(randf_range(cam_left() + 120.0, cam_right() - 120.0), randf_range(DEPTH_MIN + 20.0, DEPTH_MAX - 20.0))
		var ws := Weapons.for_stage(stage_idx)
		spawn_weapon_item(Weapons.equip(ws[randi() % 2]), pos, 1, 260.0)

	if not surv_in_wave:
		surv_break -= delta
		if surv_break <= 0.0:
			surv_wave += 1
			surv_in_wave = true
			surv_queue = _survival_wave(surv_wave)
			var tag := " — CHEFE!" if surv_wave % 10 == 0 else (" — SUB-CHEFE!" if surv_wave % 5 == 0 else "")
			hud.show_message("ONDA %d%s" % [surv_wave, tag], 1.8)
			sfx.play("go", 0.0)
			for p in active_players():
				Ach.best(p, "wave", surv_wave)
		return

	# Solta os inimigos da onda aos poucos (com limite na tela)
	var cap := 5 + players.size() * 2
	var alive := _alive_enemies().size()
	for item in surv_queue:
		item[2] -= delta
		if item[2] <= 0.0 and alive < cap:
			_toughen(_spawn_enemy(item[0], item[1]))
			alive += 1
	surv_queue = surv_queue.filter(func(it): return it[2] > 0.0)

	if surv_queue.is_empty() and _alive_enemies().is_empty():
		_survival_wave_cleared()


## Dificuldade extra conforme a onda (além da força natural de cada era).
func _toughen(e) -> void:
	if e == null or not is_instance_valid(e):
		return
	var hp_mult := 1.0 + 0.07 * (surv_wave - 1)
	e.max_hp = int(e.max_hp * hp_mult)
	e.hp = e.max_hp
	var dmg_mult := 1.0 + 0.03 * (surv_wave - 1)
	for a in e.attacks:
		a.dmg = int(round(float(a.dmg) * dmg_mult))
	for a in e.base_attacks:
		if not (a in e.attacks):
			a.dmg = int(round(float(a.dmg) * dmg_mult))
	if not e.special_attack.is_empty():
		e.special_attack.dmg = int(round(float(e.special_attack.dmg) * dmg_mult))
	e.move_speed *= minf(1.0 + 0.01 * surv_wave, 1.4)
	e.score_value = int(e.score_value * (1.0 + 0.05 * surv_wave))


func _survival_wave_cleared() -> void:
	surv_in_wave = false
	surv_break = 3.5
	var bonus := 500 * surv_wave
	for p in active_players():
		p.score += bonus
		Ach.best(p, "score", p.score)
	hud.show_message("ONDA %d VENCIDA! +%d" % [surv_wave, bonus], 2.0)
	_play_stage_music(false)
	sfx.play("pickup", 0.0)
	# Comida a cada 3 ondas
	if surv_wave % 3 == 0:
		spawn_pickup("chicken", Vector2(cam_x + randf_range(-150, 150), randf_range(DEPTH_MIN + 20, DEPTH_MAX - 20)))
	# Viagem no tempo a cada 5 ondas: nova era, novos inimigos, nova música
	if surv_wave % 5 == 0:
		stage_idx = (stage_idx + 1) % SECRET_IDX
		stage = stages[stage_idx]
		bg.stage = stage
		_play_stage_music(false)
		surv_break = 4.5
		hud.show_message("VIAGEM NO TEMPO: %s" % stage.name, 3.0)
		shake(8.0)
		for k in 8:
			spawn_spark(Vector2(cam_x + randf_range(-400, 400), randf_range(120, 480)), Color(0.6, 0.9, 1), 1.5)


# =================== Chefe secreto ===================
func fragments() -> int:
	var arr: Array = Ach.stats.get("fragments", [])
	return arr.size()


## Os 12 Fragmentos do Tempo (um por era, ganho ao concluí-la sem perder vidas) abrem a fase secreta.
func secret_unlocked() -> bool:
	return fragments() >= 12


func has_fragment(idx: int) -> bool:
	return idx in Ach.stats.get("fragments", [])
