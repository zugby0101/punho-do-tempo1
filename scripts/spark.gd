extends Node2D
## Efeito visual de impacto.

var life := 0.18
var max_life := 0.18
var col := Color(1, 0.95, 0.5)
var size := 1.0
var rot := 0.0


func _ready() -> void:
	rot = randf() * TAU
	max_life = life


func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := 1.0 - life / max_life
	var r := (14.0 + k * 22.0) * size
	var a := 1.0 - k
	for i in 8:
		var ang := rot + i * TAU / 8.0
		var len := r if i % 2 == 0 else r * 0.55
		var d := Vector2(cos(ang), sin(ang))
		draw_line(d * r * 0.3, d * len, Color(col.r, col.g, col.b, a), 3.0 * size)
	draw_circle(Vector2.ZERO, r * 0.35 * (1.0 - k), Color(1, 1, 1, a))
