extends Node2D
## Caixa quebrável que pode esconder comida.

var game
var hp := 10
var height := 0.0
var flash := 0.0
var wobble := 0.0
var drop := "chicken"


func can_be_hit() -> bool:
	return hp > 0


func take_hit(dmg: int, _dir: int, _knock: bool, _launch: float = 1.0) -> void:
	hp -= dmg
	flash = 0.1
	wobble = 0.25
	if hp <= 0:
		game.sfx.play("break")
		for i in 3:
			game.spawn_spark(position + Vector2(randf_range(-20, 20), randf_range(-50, -10)), Color(0.8, 0.55, 0.25))
		if drop != "":
			game.spawn_pickup(drop, position)
		queue_free()


func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	wobble = maxf(0.0, wobble - delta)
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 30.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2(sin(wobble * 60.0) * 3.0 * (wobble / 0.25), 0))
	var base := Color(1, 1, 1) if flash > 0.0 else Color(0.62, 0.4, 0.2)
	var dark := Color(1, 1, 1) if flash > 0.0 else Color(0.4, 0.25, 0.12)
	draw_rect(Rect2(-26, -50, 52, 50), base)
	draw_rect(Rect2(-26, -50, 52, 50), dark, false, 3.0)
	draw_line(Vector2(-24, -48), Vector2(24, -2), dark, 4.0)
	draw_line(Vector2(-24, -2), Vector2(24, -48), dark, 4.0)
	draw_rect(Rect2(-26, -28, 52, 4), dark)
