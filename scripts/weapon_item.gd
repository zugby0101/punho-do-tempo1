extends Node2D
## Arma caída no chão. O jogador pega apertando SOCO em cima dela.

const Weapons = preload("res://scripts/weapons.gd")
const LIFETIME := 18.0

var game
var weapon: Dictionary
var height := 0.0
var vz := 0.0
var vel := Vector2.ZERO
var life := LIFETIME
var t := 0.0


func toss(dir: float) -> void:
	vz = 320.0
	height = 30.0
	vel = Vector2(dir * 110.0, 0.0)


func can_pick() -> bool:
	return height < 6.0 and life > 0.0


func _process(delta: float) -> void:
	if game != null and game.net_client:
		t += delta
		queue_redraw()
		return
	if game != null and game.is_frozen() and game.mode != "play":
		return
	t += delta
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if height > 0.0 or vz != 0.0:
		vz -= 1500.0 * delta
		height += vz * delta
		position += vel * delta
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
		position.y = clampf(position.y, game.DEPTH_MIN, game.DEPTH_MAX)
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 22.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	if life < 3.0 and int(life * 10.0) % 2 == 0:
		return
	var L: float = weapon.len
	var spin := t * 14.0 if height > 0.0 else 0.0
	Weapons.draw(self, weapon, Vector2(-L * 0.45, -5.0 - height), -0.12 + spin)
	# brilho para chamar atenção
	if height <= 0.0:
		var g := 0.5 + 0.5 * sin(t * 5.0)
		draw_circle(Vector2(L * 0.35, -9.0), 2.5 + g * 2.0, Color(1, 1, 0.8, 0.5 * g))
