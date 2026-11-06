extends Node2D
## Arma caída no chão. O jogador pega apertando SOCO com a mão no cabo dela.
## Caindo rápido (do céu, ou solta por quem foi derrubado), acerta quem estiver embaixo;
## no chão, golpes que varrem por ela (chute, slam, golpe armado) a chutam para longe.

const Weapons = preload("res://scripts/weapons.gd")
const LIFETIME := 18.0
const FighterBase = preload("res://scripts/fighter.gd")
const PICK_DEPTH := 20.0  # diferença de profundidade (chão) máxima para alcançar a arma
const FALL_HURT_VZ := 300.0  # caindo mais rápido que isso (px/s), machuca quem está embaixo
const KICK_SPEED := 300.0
const KICK_VZ := 240.0

var game
var weapon: Dictionary
var height := 0.0
var vz := 0.0
var vel := Vector2.ZERO
var life := LIFETIME
var t := 0.0
var ignore: Array = []  # quem a arma não machuca ao cair (quem a soltou, quem já foi atingido)


func toss(dir: float) -> void:
	vz = 320.0
	height = 30.0
	vel = Vector2(dir * 110.0, 0.0)


func can_pick() -> bool:
	return life > 0.0


## Mão (cabo) e ângulo em que a arma está desenhada agora: deitada no chão ou girando no ar.
func grip() -> Vector2:
	return Vector2(-float(weapon.len) * 0.45, -5.0 - height)


func draw_angle() -> float:
	return -0.12 + (t * 14.0 if height > 0.0 else 0.0)


## Caixa da arma desenhada (relativa à posição da arma, y para baixo): acerta ao cair, é chutada.
func pick_box() -> Rect2:
	return Weapons.bounds(weapon, grip(), draw_angle())


## Cabo da arma desenhado: é aqui que a mão precisa encostar para pegar (da mão até ~10 px de cabo).
func grip_box() -> Rect2:
	var e := Weapons.extent(weapon)
	var a := draw_angle()
	var d := Vector2(cos(a), sin(a))
	var h := grip()
	return Rect2(h - d * e.x, Vector2.ZERO).expand(h + d * 10.0).grow(5.0)


## Chutada por um golpe: sai voando baixo para o lado do golpe (não machuca: não cai rápido).
func kick(dir: int, by) -> void:
	vel = Vector2(dir * KICK_SPEED, 0.0)
	vz = KICK_VZ
	height = maxf(height, 1.0)
	ignore = [by]


func _hit_below() -> void:
	var box := pick_box()
	var targets: Array = game.active_players() + game._alive_enemies()
	for tg in targets:
		if tg in ignore or not is_instance_valid(tg) or not tg.can_be_hit():
			continue
		if absf(tg.position.y - position.y) >= PICK_DEPTH:
			continue
		var body: Rect2 = tg.hurt_rect()
		body.position.x += tg.position.x - position.x
		if not body.intersects(box, true):
			continue
		ignore.append(tg)
		var dir := 1 if tg.position.x >= position.x else -1
		var dmg := clampi(int(-vz / 80.0), 4, 12)
		var at := position + Vector2(0, -height - 10.0)
		tg.take_hit(dmg, dir, -vz > 700.0)
		game.spawn_spark(at, Color(1, 1, 0.8), 1.0)
		game.spawn_wound(tg, at, dir, float(dmg) / 12.0)
		game.body_hit_sound(tg, at, dmg)
		game.sfx.play("i_thrown", 0.06)
		game.shake(3.0, Vector2(0, 0.6))
		# ricocheteia na cabeça de quem acertou
		vz = 180.0
		vel.x = -dir * 90.0
		return


func _process(delta: float) -> void:
	if game != null and game.net_client:
		t += delta
		queue_redraw()
		return
	if game != null and game.is_frozen():
		return  # pausa, hitstop e telas sem jogo: a arma para junto com o resto (não some nem machuca)
	t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if height > 0.0 or vz != 0.0:
		vz -= 1500.0 * delta
		height += vz * delta
		position += vel * delta
		if vz < -FALL_HURT_VZ and height > 0.0 and game != null:
			_hit_below()
		if height <= 0.0:
			height = 0.0
			if vz < -200.0:
				vz = -vz * 0.3
				height = 0.1
			else:
				vz = 0.0
				vel = Vector2.ZERO
	if game != null:
		position.x = clampf(position.x, game.cam_left() + 20.0, game.cam_right() - 20.0)
		# o desenho da arma não entra na barreira: quica de volta
		var box := pick_box()
		if position.x + box.end.x > game.wall_x():
			position.x = game.wall_x() - box.end.x
			vel.x = -absf(vel.x) * 0.5
		position.y = clampf(position.y, game.DEPTH_MIN, game.DEPTH_MAX)
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	if life < 3.0 and int(life * 10.0) % 2 == 0:
		return
	var L: float = weapon.len
	Weapons.draw(self, weapon, grip(), draw_angle())
	# brilho para chamar atenção
	if height <= 0.0:
		var g := 0.5 + 0.5 * sin(t * 5.0)
		draw_circle(Vector2(L * 0.35, -9.0), 2.5 + g * 2.0, Color(1, 1, 0.8, 0.5 * g))
	if FighterBase.show_hitboxes:
		var r := pick_box()
		var falling := vz < -FALL_HURT_VZ and height > 0.0
		var c := Color(1, 0.15, 0.1) if falling else Color(1, 0.85, 0.2)  # vermelho: caindo, machuca
		draw_rect(r, Color(c.r, c.g, c.b, 0.2), true)
		draw_rect(r, Color(c.r, c.g, c.b, 0.9), false, 1.0)
		draw_rect(grip_box(), Color(1, 1, 1, 0.9), false, 1.0)  # cabo: onde a mão pega
