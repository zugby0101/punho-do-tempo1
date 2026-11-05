extends "res://scripts/fighter.gd"
## Jogador: combo de 4 golpes, pulo, voadora e especial giratório.

const Controls = preload("res://scripts/controls.gd")
const SPECIAL_COST := 6
const PLAYER_COLORS := [Color(1, 0.3, 0.3), Color(0.35, 0.6, 1), Color(0.35, 0.95, 0.4), Color(1, 0.85, 0.2)]

const ATK_JAB := {"pose": "jab", "dmg": 5, "reach": 58, "startup": 0.04, "active": 0.07, "recovery": 0.14, "knock": false, "lunge": 50.0}
const ATK_JAB2 := {"pose": "jab", "dmg": 5, "reach": 58, "startup": 0.04, "active": 0.07, "recovery": 0.14, "knock": false, "lunge": 50.0}
const ATK_CROSS := {"pose": "cross", "dmg": 7, "reach": 62, "startup": 0.05, "active": 0.08, "recovery": 0.16, "knock": false, "lunge": 70.0}
const ATK_KICK := {"pose": "kick", "dmg": 12, "reach": 74, "startup": 0.08, "active": 0.1, "recovery": 0.28, "knock": true, "lunge": 110.0, "heavy": true}
const ATK_UPPER := {"pose": "upper", "dmg": 10, "reach": 56, "startup": 0.06, "active": 0.1, "recovery": 0.3, "knock": true, "lunge": 30.0, "heavy": true}
const ATK_JUMPKICK := {"pose": "jumpkick", "dmg": 13, "reach": 66, "startup": 0.03, "active": 0.6, "recovery": 0.0, "knock": true, "heavy": true}
const ATK_SPECIAL := {"pose": "special", "dmg": 14, "reach": 100, "startup": 0.06, "active": 0.3, "recovery": 0.18, "knock": true, "radial": true, "depth": 42.0, "heavy": true}

const ATK_THROW := {"pose": "throw", "dmg": 0, "reach": -99, "startup": 0.05, "active": 0.05, "recovery": 0.2, "knock": false}
const BASE_COMBO := [ATK_JAB, ATK_JAB2, ATK_CROSS, ATK_KICK]

var combo: Array = BASE_COMBO
var combo_step := 0
var combo_timer := 0.0
var buffered := false
var air_t := 0.0
var air_attacked := false
var hits_taken := 0
var hits_taken_timer := 0.0

# Co-op
var pid := 0              # 0..3 (P1..P4)
var sets: Array = ["k1"]  # conjuntos de controle que este jogador usa
var lives := 3
var score := 0
var out := false          # sem vidas (pode continuar apertando soco)

# Golpe especial do personagem
var special_def: Dictionary = {}
var sp_tick := -1
var sp_fired := false
var sp_land_t := -1.0


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
	special_def = c.get("special", {})
	queue_redraw()


func _targets() -> Array:
	return game.hit_targets_for(self)


func _update(delta: float) -> void:
	combo_timer -= delta
	hits_taken_timer -= delta
	if hits_taken_timer <= 0.0:
		hits_taken = 0

	match state:
		"idle", "walk":
			var input := Controls.vector(sets)
			vel = Vector2(input.x * move_speed.x, input.y * move_speed.y)
			if absf(input.x) > 0.1:
				facing = 1 if input.x > 0.0 else -1
			state = "walk" if input.length() > 0.1 else "idle"

			var atk_pressed := Controls.just(sets, "attack")
			var item = game.weapon_near(self) if weapon.is_empty() and atk_pressed else null
			if item != null:
				# Pegar a arma do chão
				equip_weapon(item.weapon)
				item.queue_free()
				game.sfx.play("pickup", 0.0)
				game.spawn_spark(position + Vector2(0, -20), Color(1, 1, 0.6), 0.6)
			elif Controls.just(sets, "special") and not weapon.is_empty():
				# Arremessar a arma
				game.throw_weapon(self, weapon)
				weapon = {}
				_on_weapon_changed()
				vel = Vector2.ZERO
				start_attack(ATK_THROW)
				game.sfx.play("whoosh")
			elif Controls.just(sets, "special") and not special_def.is_empty() and hp > int(special_def.cost):
				_start_special()
			elif Controls.just(sets, "special") and special_def.is_empty() and hp > SPECIAL_COST:
				hp -= SPECIAL_COST
				invuln = 0.45
				vel = Vector2.ZERO
				start_attack(ATK_SPECIAL)
				game.sfx.play("special")
			elif Controls.just(sets, "jump"):
				set_state("jump")
				vz = 640.0
				height = 0.1
				vel *= 1.15
				attack = {}
				air_attacked = false
				game.sfx.play("jump")
			elif atk_pressed:
				if combo_timer <= 0.0:
					combo_step = 0
				# Para cima + soco = gancho
				if Controls.pressed(sets, "up") and absf(input.x) < 0.3 and combo_step == 0:
					_do_attack(ATK_UPPER)
					combo_step = 0
				else:
					_do_attack(combo[combo_step])
		"jump":
			# Pequeno controle no ar
			var ix := Controls.vector(sets).x
			vel.x = move_toward(vel.x, ix * move_speed.x, 400.0 * delta)
			if Controls.just(sets, "attack") and not air_attacked:
				air_attacked = true
				attack = ATK_JUMPKICK
				hit_list.clear()
				air_t = 0.0
				game.sfx.play("whoosh")
			if not attack.is_empty():
				air_t += delta
				if air_t >= float(attack.startup) and air_t < float(attack.startup) + float(attack.active):
					_check_hits(_targets())
		"special":
			_process_special(delta)
		"attack":
			if Controls.just(sets, "attack"):
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


# ---------- Golpes especiais ----------
func _start_special() -> void:
	var sp := special_def
	hp -= int(sp.cost)
	set_state("special")
	vel = Vector2.ZERO
	sp_tick = -1
	sp_fired = false
	sp_land_t = -1.0
	hit_list.clear()
	attack = {"pose": sp.get("pose", "special"), "dmg": int(sp.get("dmg", 10)), "reach": float(sp.get("reach", 70)),
		"knock": false, "radial": sp.type == "spin", "depth": 28.0, "heavy": true, "phase": 1.0,
		"spin": sp.get("spin", sp.type == "spin")}
	match sp.type:
		"spin":
			invuln = float(sp.dur) + 0.1
		"slam", "rise":
			vz = float(sp.jump_v)
			height = 0.1
			vel.x = facing * float(sp.move)
			invuln = 0.5
			if sp.type == "slam":
				attack.pose = "slam"
				attack.phase = -1.0
		"dive":
			invuln = float(sp.dur) + 0.2
			if not sp.has("pose"):
				attack.pose = "dive"
		"dash":
			invuln = float(sp.startup) + float(sp.dur) + 0.1
			attack.phase = -1.0
		"projectile":
			attack.pose = "jab"
			attack.phase = -1.0
		"quake":
			attack.pose = "slam"
			attack.phase = -1.0
	game.sfx.play("special")
	game.popup(sp.name + "!", position + Vector2(0, -130.0 * body_scale), sp.color)


## Reinicia a lista de acertos a cada `interval` segundos (golpes de vários acertos).
func _multi_tick(interval: float) -> bool:
	if interval <= 0.0:
		return false
	var tick := int(state_time / interval)
	if tick != sp_tick:
		sp_tick = tick
		hit_list.clear()
		return true
	return false


func _end_special() -> void:
	attack = {}
	vel = Vector2.ZERO
	set_state("idle")


func _process_special(delta: float) -> void:
	var sp := special_def
	var t := state_time
	var targets := _targets()
	match sp.type:
		"spin":
			vel = Vector2(facing * float(sp.move), 0)
			_multi_tick(float(sp.interval))
			attack.knock = t >= float(sp.dur) - float(sp.interval)
			_check_hits(targets)
			if t >= float(sp.dur):
				_end_special()
		"flurry":
			var dur := float(sp.dur)
			if t < dur:
				if _multi_tick(float(sp.interval)):
					attack.pose = sp.pose_a if sp_tick % 2 == 0 else sp.pose_b
					vel.x = facing * float(sp.lunge)
					game.sfx.play("whoosh")
				vel.x = move_toward(vel.x, 0.0, 600.0 * delta)
				attack.phase = 1.0 if fmod(t, float(sp.interval)) < float(sp.interval) * 0.6 else 0.3
				_check_hits(targets)
			elif t < dur + 0.15:
				if not sp_fired:
					sp_fired = true
					hit_list.clear()
					attack.pose = "upper"
					attack.dmg = int(sp.final_dmg)
					attack.knock = true
					attack.phase = 1.0
					vel.x = facing * 60.0
				_check_hits(targets)
			elif t >= dur + 0.45:
				_end_special()
		"slam":
			if sp_land_t < 0.0:
				attack.phase = -1.0 if vz > 0.0 else 1.0
			elif t - sp_land_t > 0.3:
				_end_special()
		"dive":
			var startup := 0.08
			var dur := float(sp.dur)
			if t < startup:
				vel = Vector2.ZERO
			elif t < startup + dur:
				height = 32.0
				vz = 0.0
				vel = Vector2(facing * float(sp.speed), 0)
				var iv := float(sp.interval)
				_multi_tick(iv)
				attack.knock = iv <= 0.0 or t >= startup + dur - iv
				_check_hits(targets)
			else:
				vel.x = move_toward(vel.x, 0.0, 900.0 * delta)
				if height <= 0.0:
					_end_special()
		"rise":
			var iv := float(sp.interval)
			if vz > 0.0:
				_multi_tick(iv)
				attack.knock = iv <= 0.0 or vz < 200.0
				_check_hits(targets)
		"dash":
			var st := float(sp.startup)
			var dur := float(sp.dur)
			if t < st:
				vel = Vector2.ZERO
				attack.phase = -1.0
			elif t < st + dur:
				attack.phase = 1.0
				vel = Vector2(facing * float(sp.speed), 0)
				var iv := float(sp.interval)
				_multi_tick(iv)
				attack.knock = iv <= 0.0 or t >= st + dur - iv
				_check_hits(targets)
			else:
				vel.x = move_toward(vel.x, 0.0, 1200.0 * delta)
				if t >= st + dur + 0.25:
					_end_special()
		"projectile":
			if t >= 0.16 and not sp_fired:
				sp_fired = true
				attack.phase = 1.0
				game.spawn_energy(self, "ki", facing, sp)
			if t >= 0.5:
				_end_special()
		"quake":
			if t >= 0.3 and not sp_fired:
				sp_fired = true
				attack.phase = 1.0
				game.spawn_energy(self, "wave", 1, sp)
				game.spawn_energy(self, "wave", -1, sp)
				game.shake(8.0)
				game.sfx.play("thud", 0.0)
			if t >= 0.65:
				_end_special()


func _on_weapon_changed() -> void:
	combo = Weapons.player_combo(weapon) if not weapon.is_empty() else BASE_COMBO
	combo_step = 0


func _do_attack(a: Dictionary) -> void:
	buffered = false
	combo_timer = 0.45
	start_attack(a)


func _on_land() -> void:
	if state == "special":
		var ty: String = special_def.type
		if ty == "slam" and sp_land_t < 0.0:
			# Onda de choque ao cair
			sp_land_t = state_time
			attack.radial = true
			attack.knock = true
			attack.dmg = int(special_def.dmg)
			attack.reach = float(special_def.reach)
			attack.depth = 50.0
			attack.phase = 1.0
			hit_list.clear()
			_check_hits(_targets())
			game.shake(10.0)
			game.sfx.play("thud", 0.0)
			for k in 6:
				var a := k * TAU / 6.0
				game.spawn_spark(position + Vector2(cos(a) * 60.0, sin(a) * 18.0 - 10.0), special_def.color, 0.9)
			vel = Vector2.ZERO
		elif ty in ["dive", "rise"]:
			_end_special()
		return
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
	game.player_died(self)


func _on_dead_done() -> void:
	pass  # o corpo do jogador nunca é removido


func color() -> Color:
	return PLAYER_COLORS[pid]


func _draw() -> void:
	if out and not game.versus:
		return
	if game != null and game.players.size() > 1 and game.mode in ["play", "roundstart", "roundend"] and not out:
		var c := color()
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
		draw_arc(Vector2.ZERO, 26.0 * body_scale, 0, TAU, 24, c, 4.0)
		draw_set_transform(Vector2.ZERO)
		var top := -100.0 * body_scale - height
		draw_string(ThemeDB.fallback_font, Vector2(-14, top), "P%d" % (pid + 1), HORIZONTAL_ALIGNMENT_CENTER, 28, 15, c)
		draw_colored_polygon(PackedVector2Array([Vector2(-5, top + 4), Vector2(5, top + 4), Vector2(0, top + 10)]), c)
	super._draw()


func respawn() -> void:
	hp = max_hp
	set_state("knockdown")
	bounced = true
	height = 300.0
	vz = 0.0
	vel = Vector2.ZERO
	attack = {}
	invuln = 2.5
	out = false
	position.x = clampf(game.cam_x - 150.0 + pid * 60.0, game.cam_left() + 40.0, game.cam_right() - 40.0)
