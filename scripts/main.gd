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

const DEPTH_MIN := 360.0
const DEPTH_MAX := 520.0
const STAGE_LEN := 4400.0
const HALF_W := 480.0
const MAX_PLAYERS := 4
const DEFAULT_CHARS := [8, 9, 0, 3]

# Progresso que sobrevive ao recarregar a cena entre fases.
# party: [{char, sets, lives, score}] — um item por jogador.
static var stage_idx := 0
static var party: Array = []
static var skip_title := false

var stages: Array
var characters: Array
var stage: Dictionary
var waves: Array
var crate_spots := [[480.0, 400.0, "apple"], [900.0, 470.0, "weapon"], [1180.0, 470.0, "chicken"], [1980.0, 390.0, "apple"], [2780.0, 480.0, "chicken"], [3620.0, 420.0, "chicken"]]

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
	stages = Stages.list()
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
	hud = HudScript.new()
	hud.game = self
	layer.add_child(hud)
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)

	for c in crate_spots:
		var cr = CrateScript.new()
		cr.game = self
		cr.position = Vector2(c[0], c[1])
		cr.drop = c[2]
		cr.add_to_group("breakables")
		entities.add_child(cr)
	_update_camera(0.0)
	if skip_title and not party.is_empty():
		_spawn_party()
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


func _spawn_party() -> void:
	for i in party.size():
		var info: Dictionary = party[i]
		var p = _make_player(i, info.char, info.sets)
		p.lives = info.lives
		p.score = info.score
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
			if Input.is_action_just_pressed("move_right"):
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
			return
		"stageclear":
			if mode_time > 1.5 and _confirm():
				_save_party()
				stage_idx += 1
				skip_title = true
				get_tree().reload_current_scene()
			return
		"gameover":
			if mode_time > 1.0 and _confirm():
				# Continua na mesma fase, com vidas cheias
				_save_party()
				for info in party:
					info.lives = 3
					info.score = 0
				skip_title = true
				get_tree().reload_current_scene()
			return
		"ending":
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

	# Jogador eliminado pode continuar enquanto o grupo segue vivo
	for p in players:
		if p.out and Controls.just(p.sets, "attack"):
			p.lives = 3
			p.score = 0
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
	for s in Controls.all_sets():
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
	if all_ready:
		_start_game()


func _start_game() -> void:
	party = []
	for sl in slots:
		party.append({"char": sl.char, "sets": sl.sets, "lives": 3, "score": 0})
		sl.node.queue_free()
	slots = []
	# Jogando sozinho, todos os teclados e controles comandam o P1
	if party.size() == 1:
		party[0].sets = Controls.all_sets()
	_spawn_party()
	sfx.play("start", 0.0)
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
	stage_idx = posmod(stage_idx + d, stages.size())
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
	music.stop()
	sfx.play("start", 0.0)
	if stage_idx >= stages.size() - 1:
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


func _spawn_enemy(kind: String, side: int) -> void:
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
		if "last_hitter" in target:
			target.last_hitter = attacker


func on_enemy_killed(e) -> void:
	if e.last_hitter != null and is_instance_valid(e.last_hitter):
		e.last_hitter.score += e.score_value
	sfx.play("ko")
	if e.kind == "subboss":
		hitstop = 0.25
		shake(10.0)
		hud.show_message("SUB-CHEFE DERROTADO!", 2.0)
		_play_stage_music(false)
	elif e.kind == "boss":
		hitstop = 0.4
		shake(14.0)
		hud.show_message("K.O.!", 2.5)
		pending.clear()
		# Os capangas restantes caem junto com o chefe
		for o in _alive_enemies():
			o.take_hit(999, 1 if o.position.x > e.position.x else -1, true)


func player_died(p) -> void:
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
			_set_mode("gameover")
			music.stop()
		else:
			hud.show_message("P%d FORA! (soco para continuar)" % (p.pid + 1), 2.0)


func shake(amount: float) -> void:
	shake_amt = maxf(shake_amt, amount)


func spawn_spark(pos: Vector2, col: Color, size: float = 1.0) -> void:
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
