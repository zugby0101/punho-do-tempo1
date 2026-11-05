extends "res://scripts/fighter.gd"
## Inimigos com IA simples: cercam o jogador, revezam quem ataca
## e telegrafam os golpes antes de bater.

var kind := "thug"
var tier := 0  # 1 = fácil, 2 = difícil, 3 = muito difícil, 0 = chefe
var block_flash := 0.0
var blocked_last := false
var aggressive := false
var attack_cd := 1.0
var special_cd := 3.0
var lane_offset := 0.0
var hover_dist := 170.0
var score_value := 100
var attacks: Array = []
var special_attack: Dictionary = {}


func setup(k: String, stage: Dictionary = {}, stage_idx: int = 0) -> void:
	kind = k
	lane_offset = randf_range(-40.0, 40.0)
	hover_dist = randf_range(140.0, 220.0)
	attack_cd = randf_range(0.6, 1.4)
	match kind:
		"thug":
			tier = 1
			display_name = "GALO"
			max_hp = 40
			move_speed = Vector2(110, 70)
			shirt = Color(0.45, 0.55, 0.25)
			pants = Color(0.25, 0.22, 0.2)
			hat = "mohawk"
			score_value = 100
			attacks = [{"pose": "jab", "dmg": 6, "reach": 56, "startup": 0.32, "active": 0.08, "recovery": 0.35, "knock": false, "lunge": 60.0}]
		"knife":
			tier = 2
			display_name = "VÍBORA"
			max_hp = 30
			move_speed = Vector2(165, 105)
			shirt = Color(0.55, 0.2, 0.65)
			pants = Color(0.15, 0.12, 0.2)
			hair = Color(0.9, 0.8, 0.2)
			hat = "cap"
			score_value = 150
			hurt_time = 0.25
			attacks = [
				{"pose": "jab", "dmg": 7, "reach": 60, "startup": 0.22, "active": 0.07, "recovery": 0.3, "knock": false, "lunge": 120.0},
				{"pose": "kick", "dmg": 9, "reach": 70, "startup": 0.3, "active": 0.1, "recovery": 0.4, "knock": true, "lunge": 90.0},
			]
		"brute":
			tier = 3
			display_name = "TANQUE"
			max_hp = 110
			body_scale = 1.3
			move_speed = Vector2(75, 50)
			shirt = Color(0.3, 0.3, 0.35)
			pants = Color(0.35, 0.2, 0.12)
			skin = Color(0.62, 0.42, 0.3)
			hat = "bald"
			score_value = 300
			hurt_time = 0.2
			attacks = [
				{"pose": "slam", "dmg": 15, "reach": 64, "startup": 0.5, "active": 0.1, "recovery": 0.5, "knock": true, "lunge": 40.0, "heavy": true},
				{"pose": "jab", "dmg": 9, "reach": 60, "startup": 0.35, "active": 0.08, "recovery": 0.4, "knock": false, "lunge": 30.0},
			]
		"subboss":
			display_name = "SUB-CHEFE"
			max_hp = 130
			body_scale = 1.3
			move_speed = Vector2(120, 80)
			score_value = 1500
			hurt_time = 0.2
			aggressive = true
			attacks = [
				{"pose": "jab", "dmg": 8, "reach": 60, "startup": 0.26, "active": 0.08, "recovery": 0.3, "knock": false, "lunge": 70.0},
				{"pose": "kick", "dmg": 12, "reach": 72, "startup": 0.34, "active": 0.1, "recovery": 0.4, "knock": true, "lunge": 90.0, "heavy": true},
			]
			special_attack = {"pose": "charge", "dmg": 12, "reach": 56, "startup": 0.5, "active": 0.55, "recovery": 0.5, "knock": true, "dash": 430.0, "depth": 28.0, "heavy": true}
		"boss":
			display_name = "CHEFE MARRETA"
			max_hp = 220
			body_scale = 1.5
			move_speed = Vector2(105, 70)
			shirt = Color(0.75, 0.1, 0.15)
			pants = Color(0.1, 0.1, 0.12)
			skin = Color(0.85, 0.62, 0.48)
			hat = "bald"
			score_value = 5000
			hurt_time = 0.18
			aggressive = true
			attacks = [
				{"pose": "jab", "dmg": 10, "reach": 62, "startup": 0.28, "active": 0.08, "recovery": 0.3, "knock": false, "lunge": 60.0},
				{"pose": "slam", "dmg": 18, "reach": 66, "startup": 0.45, "active": 0.1, "recovery": 0.45, "knock": true, "lunge": 50.0, "heavy": true},
			]
			special_attack = {"pose": "charge", "dmg": 16, "reach": 60, "startup": 0.55, "active": 0.7, "recovery": 0.5, "knock": true, "dash": 520.0, "depth": 30.0, "heavy": true}
	# Visual e dificuldade da era
	var look: Dictionary = stage.get(kind, {})
	if not look.is_empty():
		display_name = look.name
		shirt = look.shirt
		pants = look.pants
		hat = look.hat
		skin = look.skin
		hair = look.hair
	if kind == "boss":
		cape = stage.get("cape", Color(0, 0, 0, 0))
	max_hp = int(max_hp * (1.0 + stage_idx * 0.1))
	score_value = int(score_value * (1.0 + stage_idx * 0.25))
	var dmg_mult := 1.0 + stage_idx * 0.05
	for a in attacks:
		a.dmg = int(round(a.dmg * dmg_mult))
	if not special_attack.is_empty():
		special_attack.dmg = int(round(special_attack.dmg * dmg_mult))
	move_speed *= 1.0 + stage_idx * 0.02
	hp = max_hp


func _update(delta: float) -> void:
	var target = game.player
	match state:
		"idle", "walk":
			if target == null or not target.is_alive() or target.state == "down":
				vel = vel.move_toward(Vector2.ZERO, 600.0 * delta)
				state = "idle"
				return
			attack_cd -= delta
			special_cd -= delta
			var side := 1.0 if position.x >= target.position.x else -1.0
			facing = -int(side)
			var dist := 48.0 * body_scale if aggressive else hover_dist
			var goal := Vector2(target.position.x + side * dist,
					target.position.y + (0.0 if aggressive else lane_offset))
			# Mantém o alvo dentro da tela quando o inimigo já entrou
			goal.x = clampf(goal.x, game.cam_left() + 30.0, game.cam_right() - 30.0)
			var to := goal - position
			if to.length() > 6.0:
				var dirv := to.normalized()
				vel = Vector2(dirv.x * move_speed.x, dirv.y * move_speed.y)
				state = "walk"
			else:
				vel = Vector2.ZERO
				state = "idle"
			_separate()

			var dx := absf(target.position.x - position.x)
			var dy := absf(target.position.y - position.y)
			if not special_attack.is_empty() and special_cd <= 0.0 and dx > 200.0 and dy < 25.0:
				special_cd = randf_range(4.0, 6.0)
				start_attack(special_attack)
				game.sfx.play("roar")
			elif aggressive and attack_cd <= 0.0 and dx < 70.0 * body_scale and dy < 18.0 and target.height < 40.0:
				start_attack(attacks[randi() % attacks.size()])
				attack_cd = randf_range(0.4, 0.9) if is_boss() else randf_range(0.7, 1.5)
		"attack":
			if _process_attack(delta, [target]):
				attack = {}
				set_state("idle")


## Tier 2 bloqueia golpes leves às vezes; tier 3 tem super armadura.
func take_hit(dmg: int, dir: int, knock: bool, launch: float = 1.0) -> void:
	var idle := state in ["idle", "walk"]
	blocked_last = false
	if tier == 2 and idle and not knock and randf() < 0.3:
		facing = -dir
		block_flash = 0.2
		blocked_last = true
		vel = Vector2(dir * 90.0, 0)
		game.sfx.play("thud")
		game.spawn_spark(position + Vector2(-dir * 14.0, -60.0), Color(0.4, 0.8, 1.0), 0.8)
		return
	if tier == 3 and not knock and hp - dmg > 0:
		hp -= dmg
		flash = 0.1
		game.hud.show_enemy(self)
		return
	super.take_hit(dmg, dir, knock, launch)


func _draw() -> void:
	super._draw()
	if block_flash > 0.0:
		block_flash -= get_physics_process_delta_time()
		var c := 0.0 if facing == 1 else PI
		draw_arc(Vector2(facing * 18.0 * body_scale, -60.0 * body_scale), 22.0 * body_scale, c - 1.2, c + 1.2, 10, Color(0.4, 0.8, 1.0, block_flash * 5.0), 4.0)


func tier_label() -> String:
	match tier:
		1: return "★ FÁCIL"
		2: return "★★ DIFÍCIL"
		3: return "★★★ MUITO DIFÍCIL"
	return "SUB-CHEFE" if kind == "subboss" else "CHEFE"


func is_boss() -> bool:
	return kind == "boss" or kind == "subboss"


func _separate() -> void:
	for o in get_tree().get_nodes_in_group("enemies"):
		if o == self or not o.is_alive():
			continue
		var d: Vector2 = position - o.position
		d.y *= 2.0
		var l := d.length()
		if l < 36.0 and l > 0.01:
			vel += d / l * 60.0


func _on_hurt() -> void:
	game.hud.show_enemy(self)


func _die() -> void:
	set_state("dead")
	game.on_enemy_killed(self)
