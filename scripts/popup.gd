extends Node2D
## Texto flutuante (nome do golpe especial).

var text := ""
var color := Color(1, 1, 1)
var life := 1.0
var max_life := 1.0


func _process(delta: float) -> void:
	life -= delta
	position.y -= 30.0 * delta
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var a := clampf(life / max_life * 2.0, 0.0, 1.0)
	var f := ThemeDB.fallback_font
	var w := 300.0
	draw_string_outline(f, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_CENTER, w, 17, 5, Color(0, 0, 0, 0.85 * a))
	draw_string(f, Vector2(-w * 0.5, 0), text, HORIZONTAL_ALIGNMENT_CENTER, w, 17, Color(color.r, color.g, color.b, a))
