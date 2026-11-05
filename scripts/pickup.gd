extends Node2D
## Comida que recupera vida.

var kind := "chicken"
var heal := 40
var t := 0.0


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 18.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2(0, -8 - absf(sin(t * 3.0)) * 6.0))
	if kind == "chicken":
		draw_rect(Rect2(-18, -6, 36, 8), Color(0.85, 0.85, 0.9))  # prato
		draw_circle(Vector2(-2, -12), 12.0, Color(0.75, 0.42, 0.15))
		draw_circle(Vector2(-6, -16), 5.0, Color(0.9, 0.6, 0.3))
		draw_line(Vector2(8, -14), Vector2(18, -22), Color(0.95, 0.92, 0.85), 4.0)
		draw_circle(Vector2(19, -23), 3.5, Color(0.95, 0.92, 0.85))
	else:
		draw_circle(Vector2(0, -10), 10.0, Color(0.85, 0.1, 0.12))
		draw_circle(Vector2(-3, -13), 3.0, Color(1, 0.6, 0.6))
		draw_line(Vector2(0, -20), Vector2(2, -26), Color(0.4, 0.25, 0.1), 2.0)
		draw_line(Vector2(2, -24), Vector2(8, -27), Color(0.2, 0.7, 0.2), 3.0)
