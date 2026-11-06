extends Node2D
## Mancha no chão (sangue, óleo, areia): aparece quando as gotas chegam ao chão (delay), fica um
## tempo e some devagar. Achatada como as sombras, numa camada abaixo dos lutadores.

var col := Color(0.5, 0.0, 0.02, 0.85)
var r := 5.0
var delay := 0.3
var life := 9.0
var t := 0.0
var drops: Array = []   # respingos em volta: [deslocamento, raio]


func _ready() -> void:
	for i in randi_range(1, 3):
		drops.append([Vector2(randf_range(-2.2, 2.2) * r, randf_range(-0.8, 0.8) * r), r * randf_range(0.2, 0.45)])


func _process(delta: float) -> void:
	t += delta
	if t > delay + life:
		queue_free()
		return
	if t >= delay:
		queue_redraw()


func _draw() -> void:
	if t < delay:
		return
	var grow := clampf((t - delay) / 0.12, 0.0, 1.0)            # espalha ao cair
	var fade := clampf((delay + life - t) / 2.0, 0.0, 1.0)       # some nos últimos 2 s
	var c := Color(col.r, col.g, col.b, col.a * fade)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, r * grow, c)
	for d in drops:
		draw_circle(d[0] * grow, d[1], c)
	draw_set_transform(Vector2.ZERO)
