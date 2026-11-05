extends Node2D
## Gerenciador do jogo: entrada, câmera, ondas, pontuação, progressão das 12 fases.

const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const CrateScript = preload("res://scripts/crate.gd")
const PickupScript = preload("res://scripts/pickup.gd")
const SparkScript = preload("res://scripts/spark.gd")
const SfxScript = preload("res://scripts/sfx.gd")
const BgScript = preload("res://scripts/background.gd")
const HudScript = preload("res://scripts/hud.gd")
const Stages = preload("res://scripts/stages.gd")
const Characters = preload("res://scripts/characters.gd")

const DEPTH_MIN := 360.0
const DEPTH_MAX := 520.0
const STAGE_LEN := 4400.0
const HALF_W := 480.0

# Progresso que sobrevive ao recarregar a cena entre fases
static var stage_idx := 0
static var char_idx := 8
static var carry_score := 0
static var carry_lives := 3
static var skip_title := false

var stages: Array
var characters: Array
var stage: Dictionary
var waves: Array
var crate_spots := [[480.0, 400.0, "apple"], [1180.0, 470.0, "chicken"], [1980.0, 390.0, "apple"], [2780.0, 480.0, "chicken"], [3620.0, 420.0, "chicken"]]

var mode := "title"  # title, select, intro, play, stageclear, gameover, ending
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
var score := 0
var lives := 3
var combo_count := 0
var combo_timer := 0.0
var boss_ref = null

var player
var entities: Node2D
var effects: Node2D
var camera: Camera2D
var hud
var sfx
var bg


func _ready() -> void:
	randomize()
	_setup_inputs()
	stages = Stages.list()
	characters = Characters.list()
	stage = stages[stage_idx]
	waves = Stages.waves_for(stage_idx)
	score = carry_score
	lives = carry_lives

	sfx = SfxScript.new()
	add_child(sfx)
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
	hud = HudScript.new()
	hud.game = self
	layer.add_child(hud)
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)

	player = PlayerScript.new()
	player.game = self
	player.apply_character(characters[char_idx])
	player.position = Vector2(220, 430)
	entities.add_child(player)
	for c in crate_spots:
		var cr = CrateScript.new()
		cr.game = self
		cr.position = Vector2(c[0], c[1])
		cr.drop = c[2]
		cr.add_to_group("breakables")
		entities.add_child(cr)
	_update_camera(0.0)
	if skip_title:
		_set_mode("intro")
	else:
		_set_mode("title")


func _setup_inputs() -> void:
	var keys := {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"attack": [KEY_J, KEY_Z],
		"jump": [KEY_K, KEY_X, KEY_SPACE],
		"special": [KEY_L, KEY_C],
		"start": [KEY_ENTER, KEY_KP_ENTER],
		"pause": [KEY_ESCAPE, KEY_P],
	}
	var buttons := {
		"move_left": [JOY_BUTTON_DPAD_LEFT], "move_right": [JOY_BUTTON_DPAD_RIGHT],
		"move_up": [JOY_BUTTON_DPAD_UP], "move_down": [JOY_BUTTON_DPAD_DOWN],
		"attack": [JOY_BUTTON_X], "jump": [JOY_BUTTON_A], "special": [JOY_BUTTON_Y, JOY_BUTTON_B],
		"start": [JOY_BUTTON_START], "pause": [JOY_BUTTON_BACK],
	}
	var axes := {
		"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0],
	}
	for action in keys:
		if InputMap.has_action(action):
			continue  # já registrado (cena recarregada)
		InputMap.add_action(action, 0.3)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
		for b in buttons.get(action, []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = b
			InputMap.action_add_event(action, jb)
		if axes.has(action):
			var jm := InputEventJoypadMotion.new()
			jm.axis = axes[action][0]
			jm.axis_value = axes[action][1]
			InputMap.action_add_event(action, jm)


func _set_mode(m: String) -> void:
	mode = m
	mode_time = 0.0


func is_frozen() -> bool:
	return mode in ["title", "select", "intro", "ending"] or paused or hitstop > 0.0


func cam_left() -> float:
	return cam_x - HALF_W


func cam_right() -> float:
	return cam_x + HALF_W


func _confirm() -> bool:
	return Input.is_action_just_pressed("start") or Input.is_action_just_pressed("attack")


func _physics_process(delta: float) -> void:
	mode_time += delta
	match mode:
		"title":
			# Esquerda/direita escolhe a fase inicial
			if Input.is_action_just_pressed("move_right"):
				_change_stage(1)
			elif Input.is_action_just_pressed("move_left"):
				_change_stage(-1)
			elif _confirm() and mode_time > 0.3:
				sfx.play("go", 0.0)
				_set_mode("select")
				_preview_character()
			return
		"select":
			# Colunas = regiões (homem em cima, mulher embaixo)
			var moved := -1
			if Input.is_action_just_pressed("move_right"):
				moved = posmod(char_idx + 2, characters.size())
			elif Input.is_action_just_pressed("move_left"):
				moved = posmod(char_idx - 2, characters.size())
			elif Input.is_action_just_pressed("move_down") or Input.is_action_just_pressed("move_up"):
				moved = char_idx ^ 1
			if moved >= 0:
				char_idx = moved
				_preview_character()
				sfx.play("whoosh", 0.0)
			if _confirm() and mode_time > 0.3:
				sfx.play("start", 0.0)
				player.apply_character(characters[char_idx])
				player.position = Vector2(220, 430)
				player.facing = 1
				_set_mode("intro")
			return
		"intro":
			if mode_time > 3.5 or (mode_time > 0.6 and _confirm()):
				_set_mode("play")
				hud.show_message("LUTE!", 1.2)
			return
		"stageclear":
			if mode_time > 1.5 and Input.is_action_just_pressed("start"):
				carry_score = score
				carry_lives = lives
				stage_idx += 1
				skip_title = true
				get_tree().reload_current_scene()
			return
		"gameover":
			if mode_time > 1.0 and Input.is_action_just_pressed("start"):
				# Continua na mesma fase
				carry_score = 0
				carry_lives = 3
				skip_title = true
				get_tree().reload_current_scene()
			return
		"ending":
			if mode_time > 2.0 and Input.is_action_just_pressed("start"):
				stage_idx = 0
				carry_score = 0
				carry_lives = 3
				skip_title = false
				get_tree().reload_current_scene()
			return

	if Input.is_action_just_pressed("pause"):
		paused = not paused
	if paused:
		return

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


func _preview_character() -> void:
	player.apply_character(characters[char_idx])
	player.body_scale *= 1.8
	player.position = Vector2(cam_left() + 790.0, 470.0)
	player.facing = -1


func _change_stage(d: int) -> void:
	stage_idx = posmod(stage_idx + d, stages.size())
	stage = stages[stage_idx]
	waves = Stages.waves_for(stage_idx)
	bg.stage = stage
	sfx.play("whoosh", 0.0)


func _update_camera(delta: float) -> void:
	if not locked and player != null:
		var desired: float = player.position.x + 60.0
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
			for s in waves[wave_idx].spawn:
				pending.append(s.duplicate())
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
	score += 2000 + lives * 1000
	sfx.play("start", 0.0)
	if stage_idx >= stages.size() - 1:
		_set_mode("ending")
		# Personagem em destaque na tela final
		player.apply_character(characters[char_idx])
		player.body_scale *= 2.0
		player.position = Vector2(cam_left() + 780.0, 480.0)
		player.facing = -1
		player.set_state("idle")
		player.vel = Vector2.ZERO
	else:
		_set_mode("stageclear")


func _spawn_enemy(kind: String, side: int) -> void:
	var e = EnemyScript.new()
	e.game = self
	e.add_to_group("enemies")
	e.setup(kind, stage, stage_idx)
	e.position = Vector2(cam_x + side * (HALF_W + 60.0), randf_range(DEPTH_MIN + 10.0, DEPTH_MAX - 10.0))
	e.facing = -side
	entities.add_child(e)
	if kind == "boss":
		hud.show_message("CHEFE: " + e.display_name, 2.5)
		hud.show_enemy(e)
		sfx.play("roar", 0.0)
	elif kind == "subboss":
		hud.show_message("SUB-CHEFE: " + e.display_name, 2.2)
		hud.show_enemy(e)
		sfx.play("roar", 0.0)


func _alive_enemies() -> Array:
	var arr: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive():
			arr.append(e)
	return arr


## Chefes sempre atacam; dos demais, no máximo 2 atacam ao mesmo tempo.
func _assign_aggression() -> void:
	var list := _alive_enemies()
	list.sort_custom(func(a, b): return a.position.distance_to(player.position) < b.position.distance_to(player.position))
	var slots := 2
	for e in list:
		if e.is_boss():
			e.aggressive = true
		elif slots > 0:
			e.aggressive = true
			slots -= 1
		else:
			e.aggressive = false


func _check_pickups() -> void:
	if player == null or not player.is_alive() or player.height > 10.0:
		return
	for p in get_tree().get_nodes_in_group("pickups"):
		if absf(p.position.x - player.position.x) < 30.0 and absf(p.position.y - player.position.y) < 18.0:
			player.hp = mini(player.max_hp, player.hp + p.heal)
			score += 200
			sfx.play("pickup", 0.0)
			p.queue_free()


# ---------- Eventos de combate ----------
func on_hit(attacker, target, atk: Dictionary) -> void:
	var heavy: bool = atk.get("heavy", false)
	hitstop = 0.09 if heavy else 0.05
	shake(6.0 if heavy else 2.5)
	var s: float = target.get("body_scale") if target.get("body_scale") != null else 1.0
	var pos: Vector2 = target.position + Vector2(-attacker.facing * 6.0, -58.0 * s - target.height)
	spawn_spark(pos, Color(1, 0.95, 0.5) if attacker == player else Color(1, 0.4, 0.3), 1.3 if heavy else 1.0)
	sfx.play("heavy" if heavy else "hit")
	if attacker == player:
		score += int(atk.dmg) * 10
		combo_count += 1
		combo_timer = 1.2


func on_enemy_killed(e) -> void:
	score += e.score_value
	sfx.play("ko")
	if e.kind == "subboss":
		hitstop = 0.25
		shake(10.0)
		hud.show_message("SUB-CHEFE DERROTADO!", 2.0)
	elif e.kind == "boss":
		hitstop = 0.4
		shake(14.0)
		hud.show_message("K.O.!", 2.5)
		pending.clear()
		# Os capangas restantes caem junto com o chefe
		for o in _alive_enemies():
			o.take_hit(999, 1 if o.position.x > player.position.x else -1, true)


func player_died() -> void:
	lives -= 1
	if lives > 0:
		player.respawn()
		hud.show_message("VIDAS: %d" % lives, 1.5)
		for e in _alive_enemies():
			if absf(e.position.x - player.position.x) < 250.0 and e.can_be_hit():
				e.take_hit(0, 1 if e.position.x > player.position.x else -1, true, 0.8)
	else:
		player.set_state("dead")
		player.state_time = -999.0  # mantém o corpo na tela
		_set_mode("gameover")


func shake(amount: float) -> void:
	shake_amt = maxf(shake_amt, amount)


func spawn_spark(pos: Vector2, col: Color, size: float = 1.0) -> void:
	var sp = SparkScript.new()
	sp.position = pos
	sp.col = col
	sp.size = size
	effects.add_child(sp)


func spawn_pickup(kind: String, pos: Vector2) -> void:
	var p = PickupScript.new()
	p.kind = kind
	p.heal = 40 if kind == "chicken" else 15
	p.position = pos
	p.add_to_group("pickups")
	entities.add_child(p)
