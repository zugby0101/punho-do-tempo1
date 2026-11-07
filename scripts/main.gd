extends Node2D
## Gerenciador do jogo: entrada, câmera, ondas, pontuação, progressão das 12 fases
## e co-op local para até 4 jogadores.

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const FighterBase = preload("res://scripts/fighter.gd")
const CrateScript = preload("res://scripts/crate.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const SparkScript = preload("res://scripts/spark.gd")
const Fx = preload("res://scripts/fx.gd")
const SfxScript = preload("res://scripts/sfx.gd")
const BgScript = preload("res://scripts/background.gd")
const HudScript = preload("res://scripts/hud.gd")
const MusicScript = preload("res://scripts/music.gd")
const Stages = preload("res://scripts/stages.gd")
const Characters = preload("res://scripts/characters.gd")
const Controls = preload("res://scripts/controls.gd")
const Weapons = preload("res://scripts/weapons.gd")
const Dialogs = preload("res://scripts/dialogs.gd")
const WeaponItemScript = preload("res://scripts/weapon_item.gd")
const ThrownScript = preload("res://scripts/thrown.gd")
const EnergyScript = preload("res://scripts/energy.gd")
const PopupScript = preload("res://scripts/popup.gd")

# Faixa do chão onde se anda (pés): começa FLOOR_BACK px abaixo da borda do chão desenhado na era
# (background.gd -> floor_top) e vai até FLOOR_FRONT px antes da base da tela.
var DEPTH_MIN := 360.0
var DEPTH_MAX := 520.0
const FLOOR_BACK := 30.0
const FLOOR_FRONT := 20.0
const SCREEN_H := 540.0
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
static var back_to_modes := false  # a pausa pediu para voltar ao menu (escolha de modo)
static var game_mode := "story"  # "story" (história/co-op), "versus" ou "survival"
static var survival_start := 0    # era em que a sobrevivência começou (para recomeçar)

const VERSUS_WINS := 2  # rounds para vencer a partida

var stages: Array
var characters: Array
var stage: Dictionary
var waves: Array
var crate_spots := [[480.0, 400.0, "apple"], [900.0, 470.0, "weapon"], [1180.0, 470.0, "chicken"], [1980.0, 390.0, "apple"], [2780.0, 480.0, "chicken"], [3620.0, 420.0, "chicken"]]

var mode := "title"  # title, modes, options, select, intro, play, stageclear, gameover, ending, roundstart, roundend, match
var versus := false
var round_num := 1
var round_wins: Array = [0, 0, 0, 0]
var round_winner := -1   # -1 = empate
var drop_timer := 0.0

# Sobrevivência
var fragment_got := false   # ganhou um Fragmento do Tempo nesta era
var survival := false

# Diálogos com chefes e sub-chefes
var dialog_queue: Array = []   # falas na fila
var dialog_line: Dictionary = {}  # fala atual: {name, text, color, portrait, side, voice}
var dialog_chars := 0.0         # quantas letras já apareceram
var dialog_wait := -1.0         # espera antes de abrir o diálogo (o chefe entra em cena)
var dialog_pending := false     # segura o fim da fase até o diálogo terminar
const DIALOG_CPS := 42.0        # letras por segundo
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
var _c_held := false
var _keys_held := {}
var _f3_held := false
var _esc_held := false
var _esc_just := false   # ESC acabou de ser apertado (segurar não conta de novo na tela seguinte)
static var last_names := {}      # pid -> último nome usado
static var rig_mode := true      # visual dos lutadores: rig 2D (true) ou desenho clássico
static var model_detail := true  # rig definitivo (contorno, luz e sombra, rosto, detalhes de estilo) ou simples
static var fx_enabled := true    # partículas dos golpes (P no título)
static var blood_enabled := true # sangue e manchas no chão (Y no título); desligado vira poeira
static var shake_level := 2      # tremor da câmera (E no título): 2 = 100%, 1 = 50%, 0 = desligado
const SHAKE_LEVELS := [0.0, 0.5, 1.0]
const Materials = preload("res://scripts/materials.gd")
var decals: Node2D               # manchas no chão (sangue, óleo, areia), abaixo dos lutadores
var _step_ms := 0
static var vibration := true     # vibração dos controles (B no título)
static var settings_loaded := false
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

# Câmera lenta do golpe final em chefes (tudo em tempo real: o Engine.time_scale desacelera o resto)
const SLOWMO_BOSS := {"freeze": 0.16, "in": 0.14, "hold": 1.5, "out": 0.65, "low": 0.15, "zoom": 1.4, "audio": 0.62}
const SLOWMO_SUB := {"freeze": 0.10, "in": 0.10, "hold": 0.7, "out": 0.45, "low": 0.3, "zoom": 1.2, "audio": 0.78}
var slowmo_t := -999.0         # tempo real desde o início (negativo = congelamento do impacto)
var slowmo_cfg: Dictionary = {}
var slowmo_focus := Vector2.ZERO
var slowmo_usec := 0
var cine := 0.0                # 0..1: faixas de cinema / intensidade (lido pelo HUD)
var ko_flash := 0.0            # clarão branco do impacto final
var shake_amt := 0.0           # amplitude atual do tremor (px), derivada do trauma
var trauma := 0.0              # 0..1: soma dos impactos recentes; tremor = trauma² (fortes tremem muito mais)
var shake_kick := Vector2.ZERO # tranco da câmera na direção do golpe
# Câmera dinâmica: cada um dos 79 personagens treme a tela do seu jeito (shake_profile)
var shake_freq := 1.0          # ritmo do tremor (máquinas rápido e seco, sombras/tempo balanço lento)
var shake_phase := 0.0
var roll_trauma := 0.0         # inclinação da câmera (gigantes, tempo, sombra)
var cam_roll := 0.0
var punch := 0.0               # pulso de zoom no impacto
var punch_focus := Vector2.ZERO
var bump_amp := 0.0            # tranco vertical (passos de gigantes, pisadas, quedas)
var bump_t := 0.0
const MAX_ROLL := 0.035        # rad (~2°)
var snap_zoom := 1.0           # convidado: zoom da câmera lenta do anfitrião
const SHAKE_FREQ := {"machine": 1.6, "cyborg": 1.3, "mutant": 0.85, "shadow": 0.6, "time": 0.55, "light": 2.0}
const SHAKE_ROLL := {"time": 0.8, "shadow": 0.5}
var shake_t := 0.0
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
	_reset_slowmo()
	randomize()
	Controls.setup()
	_load_settings()
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
	_apply_stage_bounds()
	add_child(bg)
	decals = Node2D.new()
	decals.z_index = -10
	add_child(decals)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	effects = Node2D.new()
	effects.z_index = 50
	add_child(effects)
	camera = Camera2D.new()
	camera.ignore_rotation = false  # a câmera dinâmica inclina a tela
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
	sfx.hook = func(n, pitch):
		if Net.is_host() and not Net.peer_sets.is_empty():
			net_events.append(["s", n, pitch])
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
		# "Voltar ao menu" da pausa cai direto na escolha de modo
		_set_mode("modes" if back_to_modes else "title")
		back_to_modes = false
		music.play("title", 0)
	music.prefetch(stage.style, stage_idx, false)
	music.prefetch(stage.style, stage_idx, true)
	# agente de teste (tools/test): só existe com "-- --test-bot" na linha de comando
	if "--test-bot" in OS.get_cmdline_user_args():
		add_child(load("res://scripts/test_bot.gd").new())


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
	return mode in ["title", "modes", "options", "select", "intro", "ending", "roundstart", "match", "ranking", "name_entry", "achievements", "dialog"] or paused or hitstop > 0.0


## Colisões do cenário tiradas do desenho da era: a faixa do chão e a barreira do fim da fase.
## (Troca de era: as manchas no chão da era anterior também saem.)
func _apply_stage_bounds() -> void:
	_clear_decals()
	if bg == null:
		return
	DEPTH_MIN = bg.floor_top() + FLOOR_BACK
	DEPTH_MAX = SCREEN_H - FLOOR_FRONT


## Face esquerda da barreira desenhada no fim da fase (background.gd).
func wall_x() -> float:
	return STAGE_LEN - 30.0


## Limite horizontal para algo com meia largura `half`: não entra na barreira do fim da fase.
func clamp_x(x: float, half: float) -> float:
	return clampf(x, half, wall_x() - half)


func cam_left() -> float:
	return cam_x - HALF_W


func cam_right() -> float:
	return cam_x + HALF_W


func _confirm() -> bool:
	return Input.is_action_just_pressed("start") or Input.is_action_just_pressed("attack") or Controls.any_remote_just(["attack", "start"])


func _physics_process(delta: float) -> void:
	var esc := Input.is_physical_key_pressed(KEY_ESCAPE)
	_esc_just = esc and not _esc_held
	_esc_held = esc
	if net_client:
		_client_tick(delta)
		return
	if Net.is_host():
		Controls.net_update()
		Net.host_tick()
	mode_time += delta
	match mode:
		"join_input":
			if _esc_just:
				_close_ip_edit()
				_set_mode("online_menu")
			return
		"ranking":
			if Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right"):
				Net.fetch_ranking("survival" if Net.ranking_board == "story" else "story")
				sfx.play("whoosh", 0.0)
				return
			if mode_time > 0.4 and (_esc_just or _confirm() or Input.is_action_just_pressed("ranking")):
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
			elif mode_time > 0.4 and (_esc_just or _confirm() or Input.is_action_just_pressed("achievements")):
				_set_mode("modes")
			return
		"name_entry":
			if _esc_just:
				_close_ip_edit()
				_set_mode(ranking_return)
				mode_time = 2.0
			return
		"online_menu":
			_update_online_menu()
			return
		"connecting":
			# anfitrião esperando o servidor criar a sala
			if _esc_just:
				Net.close()
				_set_mode("modes")
			return
		"title":
			# tela de entrada: só o título; SOCO ou ENTER vai para a escolha de modo
			if mode_time > 0.3:
				var who0 := Controls.who_pressed(["attack", "start"])
				if who0 != "":
					title_who = who0
					menu_row = 0
					sfx.play("go", 0.0)
					_set_mode("modes")
			return
		"modes":
			_update_modes_menu()
			return
		"options":
			_update_options_menu()
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
				# Quem terminou a era fora (sem vidas) volta na próxima como num "continuar":
				# vidas cheias e pontuação zerada (senão entraria com 0 vidas, morrendo de vez no 1º nocaute)
				for i in players.size():
					if players[i].out:
						party[i].lives = 3
						party[i].score = 0
				stage_idx += 1
				skip_title = true
				get_tree().reload_current_scene()
			return
		"gameover":
			if Input.is_action_just_pressed("ranking") and not score_sent and not versus:
				_start_score_entry("gameover")
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
		"dialog":
			_update_dialog(delta)
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

	if paused:
		_update_pause_menu()
		return
	if Input.is_action_just_pressed("pause"):
		_open_pause()
		return

	if versus:
		_update_versus(delta)
		return
	if survival:
		_update_survival(delta)
		return

	# Diálogo agendado (o chefe já entrou em cena)
	if dialog_wait >= 0.0 and hitstop <= 0.0:
		dialog_wait -= delta
		if dialog_wait < 0.0:
			_open_dialog()
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


## Tela de escolha de modo: ▲▼ escolhe a linha, ◄► muda o modo/fase, SOCO/ENTER confirma.
const MODE_ROWS := ["modo", "fase", "comandos", "online", "ranking", "conquistas"]
const OPTION_ROWS := ["visual", "particulas", "sangue", "tremor", "vibracao"]
var menu_row := 0
var option_row := 0
var title_who := "k1"   # quem apertou na tela de entrada (entra como P1 na seleção)


func _update_modes_menu() -> void:
	if mode_time < 0.15:
		return
	if _esc_just or Controls.who_pressed(["jump"]) != "":
		sfx.play("whoosh", 0.0)
		_set_mode("title")
		return
	if Input.is_action_just_pressed("ranking"):
		_open_ranking("modes")
		return
	if Input.is_action_just_pressed("achievements"):
		ach_page = 0
		_set_mode("achievements")
		sfx.play("go", 0.0)
		return
	if Input.is_action_just_pressed("net_host") or Input.is_action_just_pressed("net_join"):
		_open_online_menu()
		return
	if Input.is_physical_key_pressed(KEY_C) and not _c_held:
		_c_held = true
		_open_options()
		return
	elif not Input.is_physical_key_pressed(KEY_C):
		_c_held = false
	if Input.is_action_just_pressed("move_down"):
		menu_row = (menu_row + 1) % MODE_ROWS.size()
		sfx.play("whoosh", 0.0)
	elif Input.is_action_just_pressed("move_up"):
		menu_row = posmod(menu_row - 1, MODE_ROWS.size())
		sfx.play("whoosh", 0.0)
	elif Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("move_left"):
		var step := 1 if Input.is_action_just_pressed("move_right") else -1
		match MODE_ROWS[menu_row]:
			"modo":
				var modes := ["story", "versus", "survival"]
				game_mode = modes[posmod(modes.find(game_mode) + step, modes.size())]
				versus = game_mode == "versus"
				survival = game_mode == "survival"
				sfx.play("whoosh", 0.0)
			"fase":
				_change_stage(step)
	else:
		var who := Controls.who_pressed(["attack", "start"])
		if who == "":
			return
		match MODE_ROWS[menu_row]:
			"modo", "fase":
				sfx.play("go", 0.0)
				_set_mode("select")
				_add_slot(who)
			"comandos":
				_open_options()
			"online":
				_open_online_menu()
			"ranking":
				_open_ranking("modes")
			"conquistas":
				ach_page = 0
				_set_mode("achievements")
				sfx.play("go", 0.0)


## ---------- Tela de pausa ----------
## ESC/P (ou Back no controle) pausa; ▲▼ escolhe, SOCO/ENTER confirma, ESC/P de novo continua.
const PAUSE_ROWS := ["continuar", "comandos", "menu"]
var pause_row := 0
var pause_confirm := false  # pedindo confirmação para sair da partida
var options_return := "modes"


func _open_pause() -> void:
	paused = true
	pause_row = 0
	pause_confirm = false
	sfx.play("whoosh", 0.0)


func _update_pause_menu() -> void:
	if Input.is_action_just_pressed("pause"):
		if pause_confirm:
			pause_confirm = false
		else:
			paused = false
		sfx.play("whoosh", 0.0)
		return
	if pause_confirm:
		if Controls.who_pressed(["attack", "start"]) != "":
			_quit_to_menu()
		elif Controls.who_pressed(["jump"]) != "":
			pause_confirm = false
			sfx.play("whoosh", 0.0)
		return
	if Input.is_action_just_pressed("move_down"):
		pause_row = (pause_row + 1) % PAUSE_ROWS.size()
		sfx.play("whoosh", 0.0)
	elif Input.is_action_just_pressed("move_up"):
		pause_row = posmod(pause_row - 1, PAUSE_ROWS.size())
		sfx.play("whoosh", 0.0)
	elif Controls.who_pressed(["jump"]) != "":
		paused = false
		sfx.play("whoosh", 0.0)
	elif Controls.who_pressed(["attack", "start"]) != "":
		match PAUSE_ROWS[pause_row]:
			"continuar":
				paused = false
				sfx.play("go", 0.0)
			"comandos":
				option_row = 0
				options_return = mode
				_set_mode("options")
				sfx.play("go", 0.0)
			"menu":
				pause_confirm = true
				sfx.play("whoosh", 0.0)


## Abandona a partida e volta para a escolha de modo (no online, fecha a sala/conexão).
func _quit_to_menu() -> void:
	sfx.play("go", 0.0)
	_reset_slowmo()
	Engine.time_scale = 1.0
	paused = false
	party = []
	skip_title = false
	back_to_modes = true
	if Net.online():
		Net.close()
	get_tree().reload_current_scene.call_deferred()


func _open_online_menu() -> void:
	online_choice = 0
	_set_mode("online_menu")
	sfx.play("go", 0.0)


func _open_options() -> void:
	option_row = 0
	options_return = "modes"
	_set_mode("options")
	sfx.play("go", 0.0)


## Menu de comandos e opções: mostra os controles; ▲▼ escolhe uma opção, ◄► ou SOCO muda.
## Os atalhos de antes (V, P, Y, E, B) continuam valendo aqui.
func _update_options_menu() -> void:
	if mode_time < 0.15:
		return
	if _esc_just or Controls.who_pressed(["jump"]) != "" or Input.is_action_just_pressed("start"):
		sfx.play("whoosh", 0.0)
		_set_mode(options_return)
		return
	for k in [[KEY_V, "visual"], [KEY_P, "particulas"], [KEY_Y, "sangue"], [KEY_E, "tremor"], [KEY_B, "vibracao"]]:
		var held: bool = Input.is_physical_key_pressed(k[0])
		if held and not _keys_held.get(k[0], false):
			_toggle_option(k[1])
		_keys_held[k[0]] = held
	if Input.is_action_just_pressed("move_down"):
		option_row = (option_row + 1) % OPTION_ROWS.size()
		sfx.play("whoosh", 0.0)
	elif Input.is_action_just_pressed("move_up"):
		option_row = posmod(option_row - 1, OPTION_ROWS.size())
		sfx.play("whoosh", 0.0)
	elif Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("move_left") or Controls.who_pressed(["attack"]) != "":
		_toggle_option(OPTION_ROWS[option_row])


func _toggle_option(which: String) -> void:
	match which:
		"visual":
			# rig definitivo -> rig simples -> clássico -> rig definitivo
			if rig_mode and model_detail:
				model_detail = false
			elif rig_mode:
				rig_mode = false
			else:
				rig_mode = true
				model_detail = true
		"particulas":
			fx_enabled = not fx_enabled
			if fx_enabled:
				spawn_fx("energy", Vector2(cam_x, 470), Vector2(cam_x, 500), 1, Color(1, 0.8, 0.3))
		"sangue":
			blood_enabled = not blood_enabled
		"tremor":
			shake_level = (shake_level + 2) % 3  # 100% -> 50% -> desligado -> 100%
			shake(10.0)  # amostra do nível escolhido
		"vibracao":
			vibration = not vibration
			if vibration:
				for j in Input.get_connected_joypads():
					Input.start_joy_vibration(j, 0.5, 0.7, 0.25)
	_save_settings()
	sfx.play("whoosh", 0.0)


func _change_stage(d: int) -> void:
	# a fase secreta só aparece na lista depois de desbloqueada
	stage_idx = posmod(stage_idx + d, stages.size() if secret_unlocked() else SECRET_IDX)
	stage = stages[stage_idx]
	waves = Stages.waves_for(stage_idx)
	bg.stage = stage
	_apply_stage_bounds()
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
	camera.position = Vector2(cam_x, 270.0) + _shake_offset(delta)
	_dynamic_camera(delta)


## Tremor: ruído suave (não pulos aleatórios) com amplitude trauma², mais o tranco direcional, no ritmo
## de quem causou (shake_freq), mais o tranco vertical dos passos e quedas pesadas.
func _shake_offset(delta: float) -> Vector2:
	if not net_client:
		trauma = maxf(0.0, trauma - 1.5 * delta)
		shake_amt = trauma * trauma * 20.0
		roll_trauma = maxf(0.0, roll_trauma - 1.2 * delta)
		shake_freq = move_toward(shake_freq, 1.0, 0.8 * delta)
	else:
		shake_amt = move_toward(shake_amt, 0.0, 30.0 * delta)
	shake_kick = shake_kick.lerp(Vector2.ZERO, 1.0 - exp(-12.0 * delta))
	shake_t += delta
	shake_phase += delta * shake_freq
	var ph := shake_phase
	var n := Vector2(sin(ph * 47.0) + 0.6 * sin(ph * 83.0 + 1.3), sin(ph * 53.0 + 2.1) + 0.6 * sin(ph * 97.0 + 0.4)) / 1.6
	if not net_client:
		cam_roll = roll_trauma * roll_trauma * MAX_ROLL * sin(ph * 29.0 + 0.7)
	bump_t += delta
	var bump := bump_amp * exp(-bump_t * 10.0) * cos(bump_t * 38.0)
	# opção Tremor (E no título): escala tudo na saída, aqui e nos convidados online
	return (n * shake_amt + shake_kick + Vector2(0.0, bump)) * SHAKE_LEVELS[shake_level]


## Zoom de impacto e inclinação (a câmera lenta dos chefes, quando ativa, cuida do zoom).
func _dynamic_camera(delta: float) -> void:
	if not net_client:
		punch *= exp(-delta * 9.0)
	var lvl: float = SHAKE_LEVELS[shake_level]
	var roll := cam_roll * lvl
	camera.rotation = roll
	if not slowmo_cfg.is_empty() or (net_client and snap_zoom > 1.001):
		return  # câmera lenta (aqui ou a do anfitrião) cuida do zoom
	# girar mostraria os cantos de fora da tela: aproxima o bastante para cobrir
	var cover := cos(absf(roll)) + (float(HALF_W) / 270.0) * sin(absf(roll))
	var z := maxf(1.0 + punch * lvl, cover)
	camera.zoom = Vector2(z, z)
	var view := Vector2(HALF_W, 270.0) / z
	var center := Vector2(cam_x, 270.0)
	var want := (center.lerp(punch_focus, 0.35) - center) * lvl if punch > 0.002 else Vector2.ZERO
	camera.offset = Vector2(clampf(want.x, -(HALF_W - view.x), HALF_W - view.x), clampf(want.y, -(270.0 - view.y), 270.0 - view.y))


## Como cada um dos 79 treme a tela: massa (porte), ritmo (material + ajuste fixo de cada personagem)
## e inclinação (gigantes 1,3+, seres do tempo e da sombra).
func shake_profile(f) -> Dictionary:
	var s: float = f.body_scale
	var mat := Materials.of(f)
	var ident := 0.92 + float(absi(String(f.rig_scene_path).hash()) % 17) / 100.0
	return {"mass": clampf(0.75 + (s - 0.9) * 1.1, 0.8, 1.55),
		"freq": float(SHAKE_FREQ.get(mat, 1.0)) * ident / sqrt(s),
		"roll": (0.6 if s >= 1.3 else 0.0) + float(SHAKE_ROLL.get(mat, 0.0))}


## Pulso de zoom em direção ao ponto do impacto (golpes fortes, finalização).
func punch_zoom(amount: float, focus: Vector2) -> void:
	if amount > punch:
		punch = minf(amount, 0.09)
		punch_focus = focus


## Tranco vertical da câmera (px): passos de gigantes, pisada do haka, corpo grande caindo.
func bump(px: float) -> void:
	bump_amp = bump_amp * exp(-bump_t * 10.0) + px
	bump_amp = minf(bump_amp, 9.0)
	bump_t = 0.0


# ---------- Câmera lenta (golpe final em chefes) ----------
func start_slowmo(focus: Vector2, boss: bool) -> void:
	slowmo_cfg = SLOWMO_BOSS if boss else SLOWMO_SUB
	slowmo_t = -float(slowmo_cfg.freeze)
	slowmo_focus = focus
	slowmo_usec = Time.get_ticks_usec()
	ko_flash = 1.0


func _reset_slowmo() -> void:
	slowmo_t = -999.0
	slowmo_cfg = {}
	cine = 0.0
	ko_flash = 0.0
	Engine.time_scale = 1.0
	AudioServer.playback_speed_scale = 1.0
	if camera != null:
		camera.zoom = Vector2.ONE
		camera.offset = Vector2.ZERO


func _process(_delta: float) -> void:
	# F3: mostra as hitboxes sincronizadas com a animação (depuração)
	if Input.is_physical_key_pressed(KEY_F3) and not _f3_held:
		_f3_held = true
		FighterBase.show_hitboxes = not FighterBase.show_hitboxes
	elif not Input.is_physical_key_pressed(KEY_F3):
		_f3_held = false
	var now := Time.get_ticks_usec()
	var real_dt := clampf((now - slowmo_usec) / 1000000.0, 0.0, 0.1)
	slowmo_usec = now
	ko_flash = maxf(0.0, ko_flash - real_dt * 3.0)
	if net_client or slowmo_cfg.is_empty():
		return
	if paused:
		return
	slowmo_t += real_dt
	var c := slowmo_cfg
	var low: float = c.low
	var scale := 1.0
	var t := slowmo_t
	if t < 0.0:
		scale = 1.0  # congelamento do impacto (hitstop)
	elif t < c.in:
		scale = lerpf(1.0, low, ease(t / c.in, 0.4))
	elif t < c.in + c.hold:
		scale = lerpf(low, low * 1.4, (t - c.in) / c.hold)  # quase parado, voltando aos poucos
	elif t < c.in + c.hold + c.out:
		scale = lerpf(low * 1.4, 1.0, smoothstep(0.0, 1.0, (t - c.in - c.hold) / c.out))
	else:
		_reset_slowmo()
		return
	var a := clampf((1.0 - scale) / (1.0 - low), 0.0, 1.0) if t >= 0.0 else 0.0
	if t < 0.0:
		a = 0.0
	Engine.time_scale = scale
	AudioServer.playback_speed_scale = lerpf(1.0, c.audio, a)
	cine = maxf(cine, a) if t < c.in + c.hold else a
	var z := lerpf(1.0, c.zoom, a)
	camera.zoom = Vector2(z, z)
	# enquadra o chefe sem mostrar fora da tela atual
	var view := Vector2(HALF_W, 270.0) / z
	var center := Vector2(cam_x, 270.0)
	var want := center.lerp(slowmo_focus, 0.85 * a) - center
	camera.offset = Vector2(clampf(want.x, -(HALF_W - view.x), HALF_W - view.x), clampf(want.y, -(270.0 - view.y), 270.0 - view.y))


## Estado da câmera lenta para os convidados online.
func _slowmo_snap() -> Array:
	return [Engine.time_scale, camera.zoom.x, camera.offset, cine, ko_flash, AudioServer.playback_speed_scale]


func _apply_slowmo_snap(s: Array) -> void:
	Engine.time_scale = s[0]
	snap_zoom = s[1]
	camera.zoom = Vector2(s[1], s[1])
	camera.offset = s[2]
	cine = s[3]
	ko_flash = maxf(ko_flash, s[4])
	AudioServer.playback_speed_scale = s[5]


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

	if pending.is_empty() and _alive_enemies().is_empty() and not dialog_pending:
		locked = false
		wave_idx += 1
		if wave_idx >= waves.size():
			_stage_cleared()
		else:
			show_go = true
			go_timer = 3.5
			sfx.play("go", 0.0)


func _stage_cleared() -> void:
	for p in active_players():
		sfx.voice(p, "win", 1.0, 0.0)
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
	if e.is_boss():
		sfx.voice(e, "laugh", 1.0, 0.0)
	if not versus and not survival:
		if e.is_boss() and kind != "subboss":
			_dialog_boss_intro(e)
		elif kind == "subboss":
			_dialog_subboss(e)
	if kind == "secret_boss":
		hud.show_message("CHEFE SECRETO: " + e.display_name, 3.0)
		hud.show_enemy(e)
		sfx.play("roar", 0.0)
		shake(12.0)
		rumble_all(0.4, 0.6, 0.6)
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
	# a comida é pega quando o corpo do lutador (hurtbox) encosta na comida desenhada neste quadro
	for pl in active_players():
		var body: Rect2 = pl.hurt_rect()
		for p in get_tree().get_nodes_in_group("pickups"):
			if p.is_queued_for_deletion():
				continue
			if absf(p.position.y - pl.position.y) >= PickupScript.DEPTH:
				continue
			var food: Rect2 = p.pick_rect()
			food.position.x += p.position.x - pl.position.x
			if body.intersects(food, true):
				pl.hp = mini(pl.max_hp, pl.hp + p.heal)
				pl.score += 200
				Ach.track(pl, "food")
				sfx.play("pickup", 0.0)
				p.queue_free()


# ---------- Eventos de combate ----------
func on_hit(attacker, target, atk: Dictionary) -> void:
	var heavy: bool = atk.get("heavy", false)
	# os punhos do inimigo só brilham quando ele acerta uma finalização no jogador
	if atk.get("finisher", false) and target in players and attacker.is_in_group("enemies"):
		attacker.fist_glow = attacker.FIST_GLOW_TIME
	hitstop = 0.09 if heavy else 0.05
	# golpe forte: tremor grande com tranco na direção do golpe e vibração em quem bate e em quem apanha
	var power := clampf(float(atk.get("dmg", 8)) / 14.0, 0.6, 1.4)
	var hit_dir := Vector2(attacker.facing, -0.25 if atk.get("pose", "") in ["upper", "slam"] else 0.0)
	if heavy:
		shake(7.0 * power, hit_dir, attacker)
		punch_zoom(0.028 * power * (shake_profile(attacker).mass if attacker.get("rig_scene_path") != null else 1.0),
			atk.get("hit_at", target.position + Vector2(0, -50.0)))
		if attacker in players:
			rumble(attacker, 0.35, 0.5 * power, 0.13)
		if target in players:
			rumble(target, 0.7, minf(1.0, 0.85 * power), 0.24)
	else:
		shake(1.6, hit_dir * 0.4, attacker)
	var s: float = target.get("body_scale") if target.get("body_scale") != null else 1.0
	# ponto do contato: onde a ponta do golpe (animação) encosta no corpo do alvo; sem ele, altura fixa
	var pos: Vector2 = atk.get("hit_at", target.position + Vector2(-attacker.facing * 6.0, -58.0 * s - target.height))
	var wk := clampf(float(atk.get("dmg", 8)) / 12.0, 0.4, 2.2) * (1.6 if target.get("hp") != null and target.hp <= 0 else 1.0)
	spawn_wound(target, pos, attacker.facing, wk)
	var by_player: bool = attacker in players
	# cor das faíscas: em co-op a cor do jogador (para saber quem bateu); senão a assinatura de quem bateu
	var sig: Color = attacker.hit_color() if attacker.has_method("hit_color") else (Color(1, 0.95, 0.5) if by_player else Color(1, 0.4, 0.3))
	spawn_spark(pos, attacker.color() if by_player and players.size() > 1 else sig, 1.3 if heavy else 1.0)
	var wpn: Dictionary = attacker.weapon if "weapon" in attacker else {}
	var bs: float = attacker.body_scale if "body_scale" in attacker else 1.0
	var impact: String = sfx.impact_for(atk, wpn)
	sfx.play(impact, 0.07, sfx.body_pitch(bs))
	body_hit_sound(target, pos, int(atk.get("dmg", 8)))
	# partículas do golpe: o tipo segue o impacto (soco, chute, pancada, lâmina, metal, madeira, energia...)
	var fx_col: Color = atk.get("color", attacker.color()) if atk.get("energy", false) else (attacker.color() if by_player and players.size() > 1 else sig)
	spawn_fx(impact.substr(2), pos, target.position, attacker.facing, fx_col, (1.35 if heavy else 1.0) * clampf(bs, 0.8, 1.6))
	if by_player:
		attacker.score += int(atk.dmg) * 10
		combo_count += 1
		combo_timer = 1.2
		Ach.best(attacker, "combo", combo_count)
		if target.get_script() == CrateScript and target.hp <= 0:
			Ach.track(attacker, "crates")
		if "last_hitter" in target:
			target.last_hitter = attacker
	# finalização que derruba de vez: câmera lenta (os chefes já têm a deles ao cair)
	if atk.get("finisher", false) and target.get("hp") != null and target.hp <= 0 and not versus:
		var boss_ko: bool = target.get("kind") in ["boss", "subboss", "secret_boss"]
		if not boss_ko and target.has_method("hurt_rect"):
			start_slowmo(target.position + target.hurt_rect().get_center(), false)
		shake(9.0, hit_dir, attacker)
		punch_zoom(0.06, atk.get("hit_at", target.position + Vector2(0, -50.0)))


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
	if e.kind in ["boss", "subboss", "secret_boss"] and not versus:
		start_slowmo(e.position + e.hurt_rect().get_center(), e.kind != "subboss")  # centro do corpo desenhado
	var big := 1.6 if e.kind in ["boss", "subboss", "secret_boss"] else 1.0
	spawn_fx("ko", e.position + Vector2(0, -50.0 * e.body_scale - e.height), e.position, -e.facing, Color(1, 0.75, 0.3) if big == 1.0 else Color(1, 0.4, 0.9), big)
	if e.kind == "subboss":
		hitstop = maxf(hitstop, SLOWMO_SUB.freeze)
		shake(11.0, Vector2(-e.facing, -0.3))
		rumble_all(0.7, 0.8, 0.4)
		shake(10.0)
		hud.show_message("SUB-CHEFE DERROTADO!", 2.0)
		_play_stage_music(false)
	elif e.kind in ["boss", "secret_boss"]:
		hitstop = maxf(hitstop, SLOWMO_BOSS.freeze)
		shake(16.0, Vector2(-e.facing, -0.3))
		rumble_all(1.0, 1.0, 0.7)
		hud.show_message("K.O.!", 2.5)
		pending.clear()
		if not versus and not survival:
			_dialog_boss_defeat(e)
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
		rumble(p, 1.0, 1.0, 0.5)
		return
	p.lives -= 1
	rumble(p, 0.9, 1.0, 0.45)
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
		# Só acaba quando todos estão fora: quem ainda tem vidas pode estar caído com 0 de vida,
		# esperando renascer (active_players() não conta esse jogador)
		if players.all(func(q): return q.out):
			if survival:
				for pl in players:
					Ach.best(pl, "score", pl.score)
			_set_mode("gameover")
			music.stop()
		else:
			hud.show_message("P%d FORA! (soco para continuar)" % (p.pid + 1), 2.0)


## Tremor de tela. amount ~2 (leve) .. 14 (enorme); dir dá um tranco da câmera para aquele lado.
## Tremor de tela. src: quem causou (lutador): o tremor ganha a massa, o ritmo e a inclinação dele.
func shake(amount: float, dir := Vector2.ZERO, src = null) -> void:
	var k := 1.0
	if src != null and is_instance_valid(src) and src.get("rig_scene_path") != null:
		var pr := shake_profile(src)
		k = pr.mass
		shake_freq = lerpf(shake_freq, pr.freq, clampf(amount / 10.0, 0.2, 1.0))
		roll_trauma = minf(1.0, roll_trauma + amount * float(pr.roll) / 16.0)
	trauma = minf(1.0, trauma + amount * k / 16.0)
	shake_kick = (shake_kick + dir * amount * k * 0.9).limit_length(18.0)


## Vibração no(s) controle(s) de um jogador: fraco = motor leve, forte = motor pesado (0..1).
## Teclado não vibra; convidados online recebem um evento e vibram o controle deles.
func rumble(p, weak: float, strong: float, dur: float) -> void:
	if p == null or not ("sets" in p):
		return
	for s in p.sets:
		var st := String(s)
		if st.begins_with("j"):
			if vibration:
				Input.start_joy_vibration(int(st.substr(1)), clampf(weak, 0, 1), clampf(strong, 0, 1), dur)
		elif st.begins_with("n") and Net.is_host():
			net_events.append(["v", st, weak, strong, dur])


func rumble_all(weak: float, strong: float, dur: float) -> void:
	for p in players:
		if not p.out:
			rumble(p, weak, strong, dur)


func spawn_spark(pos: Vector2, col: Color, size: float = 1.0) -> void:
	if Net.is_host() and not Net.peer_sets.is_empty():
		net_events.append(["k", pos.x, pos.y, col, size])
	var sp = SparkScript.new()
	sp.position = pos
	sp.col = col
	sp.size = size
	effects.add_child(sp)


## Ferimento: o que sai do corpo de quem apanha, conforme o material dele (materials.gd), no ponto do
## contato. k = força (dano / 12; KO maior). No online o anfitrião repassa (cada um aplica o próprio
## ajuste de sangue).
func spawn_wound(target, pos: Vector2, dir: int, k: float) -> void:
	var mat := Materials.of(target)
	if mat == "wood":
		return  # caixas: já têm lascas e tábuas
	var feet: Vector2 = target.position
	_wound(mat, pos, feet, dir, k)
	if Net.is_host() and not Net.peer_sets.is_empty():
		net_events.append(["w", mat, pos.x, pos.y, feet.x, feet.y, dir, k])


## Som do corpo de quem apanha (sfx.gd -> body_sound): o material, no tom de cada um dos 79; respingo
## molhado com sangue ligado; e o tilintar do capacete/coroa quando o contato foi na cabeça.
func body_hit_sound(target, pos: Vector2, dmg: int) -> void:
	var mat := Materials.of(target)
	if mat == "wood":
		return
	var ko: bool = target.hp <= 0
	var slug: String = String(target.rig_scene_path).get_file().get_basename()
	var bs: Array = SfxScript.body_sound(mat, float(target.body_scale), slug, ko)
	sfx.play(bs[0], 0.05, bs[1])
	if blood_enabled and mat in Materials.BLEEDS and dmg >= 6:
		sfx.play("m_wet", 0.12, bs[1])
	if target.get("hat") in SfxScript.METAL_HATS:
		var r: Rect2 = target.hurt_rect()
		r.position += target.position
		if pos.y < r.position.y + r.size.y * 0.25:  # contato no quarto de cima do corpo: a cabeça
			sfx.play("m_helmet", 0.06, bs[1])


## Passo de um lutador (fighter.gd: no quadro em que o pé desenhado volta ao chão). Rápido demais
## (pés tocando quase juntos) vira um passo só.
func footstep(f, front: bool) -> void:
	var now := Time.get_ticks_msec()
	if now - int(f.get_meta("step_ms", -1000)) < 90 or now - _step_ms < 25:
		return  # no máximo ~40 passos por segundo no total (muita gente andando junto)
	_step_ms = now
	f.set_meta("step_ms", now)
	var slug: String = String(f.rig_scene_path).get_file().get_basename()
	for st in SfxScript.step_sounds(stage.get("style", "modern"), Materials.of(f), float(f.body_scale), slug, front):
		sfx.play(st[0], 0.04, st[1])
	# gigantes fazem o chão (e a câmera) tremer a cada passo; a pisada do haka (parado) também
	var s: float = f.body_scale
	if s >= 1.3:
		bump((s - 1.2) * 5.0)
	elif s >= 1.1 and f.state == "idle":
		bump(1.6)


func _wound(mat: String, pos: Vector2, feet: Vector2, dir: int, k: float) -> void:
	if fx_enabled:
		Fx.wound(effects, decals, mat, pos, feet, dir, k, blood_enabled)


## Partículas (fx.gd); no online o host repassa aos clientes.
func spawn_fx(kind: String, pos: Vector2, feet: Vector2, dir: int, col: Color, k: float = 1.0) -> void:
	if Net.is_host() and not Net.peer_sets.is_empty():
		net_events.append(["x", kind, pos.x, pos.y, feet.x, feet.y, dir, col, k])
	if not fx_enabled:
		return
	Fx.burst(effects, kind, pos, feet, dir, col, k)


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
func spawn_weapon_item(w: Dictionary, pos: Vector2, dir: int, h: float = 0.0, ignore: Array = []):
	var it = WeaponItemScript.new()
	it.ignore = ignore.duplicate()
	it.game = self
	it.weapon = w
	it.position = pos
	it.add_to_group("weapons")
	entities.add_child(it)
	it.toss(float(dir))
	it.height = maxf(h, 1.0)
	return it


## Golpe varrendo o chão: a ponta (pés, punhos, arma) passou pelos pontos `pts` (relativos aos pés do
## lutador, y para baixo) com raio `r` neste quadro; armas no chão tocadas por ela são chutadas.
func kick_weapons(by, pts: Array, r: float) -> void:
	for it in get_tree().get_nodes_in_group("weapons"):
		if it.is_queued_for_deletion() or it in by.hit_list:
			continue
		if absf(it.position.y - by.position.y) >= WeaponItemScript.PICK_DEPTH:
			continue
		var box: Rect2 = it.pick_box().grow(r)
		box.position.x += it.position.x - by.position.x
		for p in pts:
			if box.has_point(p):
				by.hit_list.append(it)
				it.kick(by.facing, by)
				sfx.play("i_metal" if it.weapon.get("kind", "") == "blade" else "i_wood", 0.08)
				spawn_spark(it.position + Vector2(0, -8.0), Color(1, 0.95, 0.7), 0.5)
				break

## Arma ao alcance da mão: a mão do lutador (da guarda do rig, abaixando até o chão) encosta no cabo
## da arma — no chão ou ainda quicando, se ela estiver na altura da mão. Pega a mais próxima.
func weapon_near(p):
	var grab: Rect2 = p.grab_box()
	var best = null
	var best_d := INF
	for it in get_tree().get_nodes_in_group("weapons"):
		if it.is_queued_for_deletion() or not it.can_pick():
			continue
		if absf(it.position.y - p.position.y) >= WeaponItemScript.PICK_DEPTH:
			continue
		var box: Rect2 = it.grip_box()  # a mão precisa encostar no cabo
		box.position += Vector2(it.position.x - p.position.x, 0.0)
		if not grab.intersects(box, true):
			continue
		var dd := absf(box.get_center().x - grab.get_center().x)
		if dd < best_d:
			best_d = dd
			best = it
	return best


## rp = ponto de soltura (à frente dos pés, altura), tirado da animação de arremesso (fighter.release_point).
func throw_weapon(p, w: Dictionary, rp := Vector2(20.0, 46.0)) -> void:
	var th = ThrownScript.new()
	th.game = self
	th.owner_player = p
	th.weapon = w
	th.dir = p.facing
	th.height = rp.y
	th.position = p.position + Vector2(p.facing * rp.x, 0)
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


func _clear_decals() -> void:
	if decals != null:
		for d in decals.get_children():
			d.queue_free()


func _start_round() -> void:
	_clear_decals()
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
			sfx.voice(alive[0], "win", 1.0, 0.0)
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
	if _esc_just and mode_time > 0.2:
		_set_mode("modes")
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
	_reset_slowmo()
	party = []
	skip_title = false
	get_tree().reload_current_scene.call_deferred()


func _client_tick(delta: float) -> void:
	mode_time += delta
	Net.client_tick()
	if _esc_just and mode in ["connecting", "title", "modes", "options"]:
		Net.close()
		leave_online()
		return
	# suaviza o movimento entre pacotes
	for id in net_nodes:
		var n = net_nodes[id]
		if is_instance_valid(n) and n.has_meta("net_target"):
			var tgt: Vector2 = n.get_meta("net_target")
			n.position = tgt if n.position.distance_to(tgt) > 150.0 else n.position.lerp(tgt, 0.45)
	camera.position = Vector2(cam_x, 270.0) + _shake_offset(delta)
	_dynamic_camera(delta)


func _fighter_fields(f) -> Array:
	return [f.position.x, f.position.y, f.height, f.facing, f.state, f.state_time, f.anim_t, f.flash, f.invuln,
		f._current_pose(), f._attack_phase(), f.draw_facing(), f.body_scale, f.hp, f.max_hp, f.weapon] + f.rig_anim() + [f.trail_color()]


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
			ents.append(["E", id] + _fighter_fields(n) + [n.kind, n.block_flash, n.tier, n.display_name, n.fist_glow])
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
	return [mode, mode_time, stage_idx, paused, combo_count, combo_timer, show_go, cam_x, Vector3(shake_amt, shake_kick.x, shake_kick.y),
		round_num, round_wins, round_winner, ending_page, game_mode, slot_s,
		hud.message, hud.message_timer, enemy_id, hud.enemy_timer, pids, music_key, ev, ents, surv_wave,
		dialog_line, dialog_chars, _slowmo_snap(), [cam_roll, punch, punch_focus, bump_amp * exp(-bump_t * 10.0), shake_freq]]


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
	n.net_rig_anim = d[i + 16]
	n.net_rig_u = d[i + 17]
	n.net_trail = d[i + 18]
	return i + 19


## Convidado: aplica o estado recebido do anfitrião.
func net_apply(snap: Array) -> void:
	if snap.size() < 23:
		return
	var new_stage: int = snap[2]
	if new_stage != stage_idx or mode == "connecting":
		stage_idx = new_stage
		stage = stages[stage_idx]
		bg.stage = stage
		_apply_stage_bounds()
	mode = snap[0]
	mode_time = snap[1]
	paused = snap[3]
	combo_count = snap[4]
	combo_timer = snap[5]
	show_go = snap[6]
	cam_x = snap[7]
	if snap[8] is Vector3:
		shake_amt = maxf(shake_amt, snap[8].x)
		if Vector2(snap[8].y, snap[8].z).length() > shake_kick.length():
			shake_kick = Vector2(snap[8].y, snap[8].z)
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
	if snap.size() > 25:
		dialog_line = snap[24]
		dialog_chars = snap[25]
	if snap.size() > 26:
		_apply_slowmo_snap(snap[26])
	if snap.size() > 27 and snap[27] is Array and snap[27].size() >= 5:
		# câmera dinâmica do anfitrião: inclinação, zoom de impacto, tranco vertical e ritmo do tremor
		cam_roll = snap[27][0]
		punch = snap[27][1]
		punch_focus = snap[27][2]
		if float(snap[27][3]) > bump_amp * exp(-bump_t * 10.0) + 0.5:
			bump_amp = snap[27][3]
			bump_t = 0.0
		shake_freq = snap[27][4]
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
				if d.size() > i + 4:
					n.fist_glow = d[i + 4]
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
			"s": sfx.play_exact(ev[1], float(ev[2]) if ev.size() > 2 else 1.0)
			"k": spawn_spark(Vector2(ev[1], ev[2]), ev[3], ev[4])
			"v":
				if ev[1] == Net.my_set and vibration:
					for j in Input.get_connected_joypads():
						Input.start_joy_vibration(j, ev[2], ev[3], ev[4])
			"x": spawn_fx(ev[1], Vector2(ev[2], ev[3]), Vector2(ev[4], ev[5]), ev[6], ev[7], ev[8])
			"w": _wound(ev[1], Vector2(ev[2], ev[3]), Vector2(ev[4], ev[5]), ev[6], ev[7])
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
			n.setup(d[21], stage, stage_idx)  # "E", id, 19 campos do lutador, tipo
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
	# depois de enviar, mostra o quadro deste modo (no final da História também, não o último aberto)
	Net.ranking_board = "survival" if survival else "story"
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
		_apply_stage_bounds()
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


# =================== Configurações ===================
func rigs_enabled() -> bool:
	return rig_mode


func _load_settings() -> void:
	if settings_loaded:
		return
	settings_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		rig_mode = cfg.get_value("visual", "rig_mode", true)
		model_detail = cfg.get_value("visual", "model_detail", true)
		fx_enabled = cfg.get_value("visual", "particles", true)
		blood_enabled = cfg.get_value("visual", "blood", true)
		shake_level = clampi(int(cfg.get_value("visual", "shake", 2)), 0, 2)
		vibration = cfg.get_value("controls", "vibration", true)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("visual", "rig_mode", rig_mode)
	cfg.set_value("visual", "model_detail", model_detail)
	cfg.set_value("visual", "particles", fx_enabled)
	cfg.set_value("visual", "blood", blood_enabled)
	cfg.set_value("visual", "shake", shake_level)
	cfg.set_value("controls", "vibration", vibration)
	cfg.save("user://settings.cfg")


# =================== Diálogos com chefes ===================
const PLAYER_TEXT_COLORS := [Color(1, 0.45, 0.45), Color(0.5, 0.7, 1), Color(0.5, 1, 0.55), Color(1, 0.9, 0.35)]


func _speaker(f, color: Color) -> Dictionary:
	# Dados de quem fala, guardados na hora (o chefe pode sumir antes do fim da fala).
	return {"name": f.display_name, "color": color, "voice": f.voice_id,
		"pitch": sfx.body_pitch(f.body_scale),
		"portrait": {"skin": f.skin, "hair": f.hair, "shirt": f.shirt, "hat": f.hat, "f": f.feminine}}


func _line(spk: Dictionary, text: String, side: String, voice_line: String) -> Dictionary:
	var d := spk.duplicate()
	d["text"] = text
	d["side"] = side
	d["voice_line"] = voice_line
	return d


## Quem responde: de preferência um lutador com encontro especial com este chefe.
func _responder(style: String):
	var act := active_players()
	if act.is_empty():
		return null
	for p in act:
		if Dialogs.PAIRS.has("%s_%s" % [style, p.voice_id]):
			return p
	return act[randi() % act.size()]


func _boss_color(e) -> Color:
	return Color(0.85, 0.6, 1) if e.kind == "secret_boss" else Color(1, 0.4, 0.35)


func _fill(text: String) -> String:
	return text.replace("{era}", stage.name)


func _dialog_boss_intro(e) -> void:
	var style: String = stage.style
	var data: Dictionary = Dialogs.BOSSES.get(style, {})
	var p = _responder(style)
	if data.is_empty() or p == null:
		return
	var boss := _speaker(e, _boss_color(e))
	var hero := _speaker(p, PLAYER_TEXT_COLORS[p.pid] if players.size() > 1 else Color(1, 0.85, 0.3))
	var mine: Dictionary = Dialogs.PLAYERS.get(p.voice_id, {})
	var pair_key := "%s_%s" % [style, p.voice_id]
	var lines: Array = []
	if Dialogs.PAIRS.has(pair_key):
		var pr: Array = Dialogs.PAIRS[pair_key]
		lines = [_line(boss, pr[0], "left", "laugh"), _line(hero, pr[1], "right", "atk2"), _line(boss, data.intro[1], "left", "")]
	else:
		var reply: String = mine.get("eon", "") if e.kind == "secret_boss" else Dialogs.pick(mine.get("retort", []))
		lines = [_line(boss, data.intro[0], "left", "laugh"), _line(hero, reply, "right", "atk2"), _line(boss, data.intro[1], "left", "")]
	_queue_dialog(lines, 1.6)


func _dialog_subboss(e) -> void:
	var line: String = Dialogs.SUBBOSSES.get(stage.style, "")
	var p = _responder(stage.style)
	if line == "" or p == null:
		return
	var sub := _speaker(e, Color(1, 0.6, 0.9))
	var hero := _speaker(p, PLAYER_TEXT_COLORS[p.pid] if players.size() > 1 else Color(1, 0.85, 0.3))
	var mine: Dictionary = Dialogs.PLAYERS.get(p.voice_id, {})
	_queue_dialog([_line(sub, line, "left", "laugh"), _line(hero, Dialogs.pick(mine.get("sub", [])), "right", "atk1")], 1.3)


func _dialog_boss_defeat(e) -> void:
	var data: Dictionary = Dialogs.BOSSES.get(stage.style, {})
	var p = _responder(stage.style)
	if data.is_empty():
		return
	var lines: Array = [_line(_speaker(e, _boss_color(e)), data.defeat, "left", "")]
	if p != null:
		var mine: Dictionary = Dialogs.PLAYERS.get(p.voice_id, {})
		lines.append(_line(_speaker(p, PLAYER_TEXT_COLORS[p.pid] if players.size() > 1 else Color(1, 0.85, 0.3)), Dialogs.pick(mine.get("victory", [])), "right", "win"))
	_queue_dialog(lines, 1.1)


func _queue_dialog(lines: Array, delay: float) -> void:
	if lines.is_empty():
		return
	dialog_queue = lines
	dialog_wait = delay
	dialog_pending = true


func _open_dialog() -> void:
	_set_mode("dialog")
	_next_line()


func _next_line() -> void:
	if dialog_queue.is_empty():
		_close_dialog()
		return
	dialog_line = dialog_queue.pop_front()
	dialog_line.text = _fill(String(dialog_line.text))
	dialog_chars = 0.0
	if String(dialog_line.voice_line) != "":
		sfx.play("vo_%s_%s" % [dialog_line.voice, dialog_line.voice_line], 0.03)


func _close_dialog() -> void:
	dialog_queue = []
	dialog_line = {}
	dialog_pending = false
	dialog_wait = -1.0
	_set_mode("play")


func _update_dialog(delta: float) -> void:
	if dialog_line.is_empty():
		_close_dialog()
		return
	var total: int = String(dialog_line.text).length()
	var before := int(dialog_chars)
	dialog_chars = minf(dialog_chars + delta * DIALOG_CPS, float(total))
	# "bipes" da fala no tom de quem fala (a cada 2 letras, sem contar espaços)
	if int(dialog_chars) > before and int(dialog_chars) % 2 == 0:
		var ch := String(dialog_line.text)[mini(int(dialog_chars), total - 1)]
		if ch != " ":
			sfx.play("blip", 0.06, float(dialog_line.pitch))
	if mode_time < 0.25:
		return
	# PULO pula o diálogo inteiro; SOCO/ENTER mostra a fala toda ou avança
	if Input.is_action_just_pressed("jump") or Controls.any_remote_just(["jump"]):
		_close_dialog()
	elif _confirm():
		if dialog_chars < total:
			dialog_chars = total
		else:
			_next_line()
