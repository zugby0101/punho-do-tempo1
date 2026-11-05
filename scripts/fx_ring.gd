extends Node2D
## Anel de choque que se expande e some (flat < 1 achata o anel em elipse, para o chão).

var col := Color(1, 1, 1)
var radius := 30.0
var life := 0.2
var flat := 1.0
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	if t >= life:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := t / life
	var e := 1.0 - pow(1.0 - k, 3.0)  # expande rápido e desacelera
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, flat))
	draw_arc(Vector2.ZERO, radius * (0.3 + 0.7 * e), 0.0, TAU, 32, Color(col.r, col.g, col.b, col.a * (1.0 - k)), 4.0 * (1.0 - k) + 1.0 / flat, true)
