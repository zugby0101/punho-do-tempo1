extends "res://scripts/fighter.gd"
## Jogador: combo de 4 golpes, pulo, voadora e especial giratório.

const SPECIAL_COST := 6

const ATK_JAB := {"pose": "jab", "dmg": 5, "reach": 58, "startup": 0.04, "active": 0.07, "recovery": 0.14, "knock": false, "lunge": 50.0}
const ATK_JAB2 := {"pose": "jab", "dmg": 5, "reach": 58, "startup": 0.04, "active": 0.07, "recovery": 0.14, "knock": false, "lunge": 50.0}
const ATK_CROSS := {"pose": "cross", "dmg": 7, "reach": 62, "startup": 0.05, "active": 0.08, "recovery": 0.16, "knock": false, "lunge": 70.0}
const ATK_KICK := {"pose": "kick", "dmg": 12, "reach": 74, "startup": 0.08, "active": 0.1, "recovery": 0.28, "knock": true, "lunge": 110.0, "heavy": true}
const ATK_UPPER := {"pose": "upper", "dmg": 10, "reach": 56, "startup": 0.06, "active": 0.1, "recovery": 0.3, "knock": true, "lunge": 30.0, "heavy": true}
const ATK_JUMPKICK := {"pose": "jumpkick", "dmg": 13, "reach": 66, "startup": 0.03, "active": 0.6, "recovery": 0.0, "knock": true, "heavy": true}
const ATK_SPECIAL := {"pose": "special", "dmg": 14, "reach": 100, "startup": 0.06, "active": 0.3, "recovery": 0.18, "knock": true, "radial": true, "depth": 42.0, "heavy": true}

var combo := [ATK_JAB, ATK_JAB2, ATK_CROSS, ATK_KICK]
var combo_step := 0
var combo_timer := 0.0
var buffered := false
var air_t := 0.0
var air_attacked := false
var hits_taken := 0
var hits_taken_timer := 0.0


func _ready() -> void:
	if display_name == "???":
		apply_character(preload("res://scripts/characters.gd").list()[8])


## Aplica visual e atributos de um personagem de characters.gd
func apply_character(c: Dictionary) -> void:
	display_name = c.name
	skin = c.skin
	hair = c.hair
	hat = c.hat
	shirt = c.shirt
	pants = c.pants
	shoes = c.shoes
	feminine = c.f
	body_scale = c.size
	power = c.power
	max_hp = c.hp
	hp = max_hp
	move_speed = Vector2(230, 140) * float(c.speed)
	queue_redraw()


func _targets() -> Array:
	var arr: Array = []
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.is_alive():
			arr.append(e)
	arr.append_array(get_tree().get_nodes_in_group("breakables"))
	return arr


func _update(delta: float) -> void:
	combo_timer -= delta
	hits_taken_timer -= delta
	if hits_taken_timer <= 0.0:
		hits_taken = 0

	match state:
		"idle", "walk":
			var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
			vel = Vector2(input.x * move_speed.x, input.y * move_speed.y)
			if absf(input.x) > 0.1:
				facing = 1 if input.x > 0.0 else -1
			state = "walk" if input.length() > 0.1 else "idle"

			if Input.is_action_just_pressed("special") and hp > SPECIAL_COST:
				hp -= SPECIAL_COST
				invuln = 0.45
				vel = Vector2.ZERO
				start_attack(ATK_SPECIAL)
				game.sfx.play("special")
			elif Input.is_action_just_pressed("jump"):
				set_state("jump")
				vz = 640.0
				height = 0.1
				vel *= 1.15
				attack = {}
				air_attacked = false
				game.sfx.play("jump")
			elif Input.is_action_just_pressed("attack"):
				if combo_timer <= 0.0:
					combo_step = 0
				# Para cima + soco = gancho
				if Input.is_action_pressed("move_up") and absf(input.x) < 0.3 and combo_step == 0:
					_do_attack(ATK_UPPER)
					combo_step = 0
				else:
					_do_attack(combo[combo_step])
		"jump":
			# Pequeno controle no ar
			var ix := Input.get_axis("move_left", "move_right")
			vel.x = move_toward(vel.x, ix * move_speed.x, 400.0 * delta)
			if Input.is_action_just_pressed("attack") and not air_attacked:
				air_attacked = true
				attack = ATK_JUMPKICK
				hit_list.clear()
				air_t = 0.0
				game.sfx.play("whoosh")
			if not attack.is_empty():
				air_t += delta
				if air_t >= float(attack.startup) and air_t < float(attack.startup) + float(attack.active):
					_check_hits(_targets())
		"attack":
			if Input.is_action_just_pressed("attack"):
				buffered = true
			var act_end: float = float(attack.startup) + float(attack.active)
			var done := _process_attack(delta, _targets())
			var is_combo: bool = attack in combo and attack != combo[combo.size() - 1]
			if buffered and is_combo and state_time >= act_end:
				combo_step = (combo_step + 1) % combo.size()
				_do_attack(combo[combo_step])
			elif done:
				if attack == combo[combo.size() - 1]:
					combo_step = 0
				attack = {}
				set_state("idle")


func _do_attack(a: Dictionary) -> void:
	buffered = false
	combo_timer = 0.45
	start_attack(a)


func _on_land() -> void:
	if state == "jump":
		attack = {}
		vel = Vector2.ZERO
		set_state("idle")


func take_hit(dmg: int, dir: int, knock: bool, launch: float = 1.0) -> void:
	hits_taken += 1
	hits_taken_timer = 1.2
	if hits_taken >= 3:
		knock = true
		hits_taken = 0
	super.take_hit(dmg, dir, knock, launch)
	game.sfx.play("hurt")


func _clamp_position() -> void:
	position.y = clampf(position.y, game.DEPTH_MIN, game.DEPTH_MAX)
	position.x = clampf(position.x, game.cam_left() + 24.0, game.cam_right() - 24.0)


func _die() -> void:
	game.player_died()


func respawn() -> void:
	hp = max_hp
	set_state("knockdown")
	bounced = true
	height = 300.0
	vz = 0.0
	vel = Vector2.ZERO
	attack = {}
	invuln = 2.5
	position.x = game.cam_x - 150.0
