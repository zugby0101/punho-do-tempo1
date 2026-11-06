extends Node2D
## Comida que recupera vida.
## A área de coleta é exatamente a comida desenhada neste quadro: no tamanho de cada uma (frango no
## prato, maçã) e subindo e descendo junto com o balanço. Ao aparecer (caixa quebrada), a comida salta
## para fora junto com as tábuas, e a área acompanha o salto.

const FighterBase = preload("res://scripts/fighter.gd")
const POP_TIME := 0.35   # duração do salto ao aparecer
const POP_H := 34.0      # altura do salto
const DEPTH := 18.0      # diferença de profundidade (chão) máxima para pegar
# Tamanho do desenho de cada comida (relativo ao centro do balanço, y para baixo)
const BOUNDS := {
	"chicken": Rect2(-18.0, -26.5, 40.5, 28.5),  # prato, coxa e osso
	"apple": Rect2(-10.0, -28.5, 20.0, 28.5),    # maçã, cabinho e folha
}

var kind := "chicken"
var heal := 40
var t := 0.0
var pop_t := 0.0


func _process(delta: float) -> void:
	t += delta
	pop_t = minf(pop_t + delta, POP_TIME)
	queue_redraw()


## Altura do salto de quando aparece (parábola de 0 a POP_H e de volta ao chão).
func height() -> float:
	var k := pop_t / POP_TIME
	return POP_H * 4.0 * k * (1.0 - k)


## Deslocamento vertical do desenho neste quadro: salto + balanço (o mesmo do _draw).
func draw_offset() -> float:
	var bob := absf(sin(t * 3.0)) * 6.0 if pop_t >= POP_TIME else 0.0
	return -8.0 - bob - height()


## Área de coleta: a comida desenhada agora (relativa à base, y para baixo).
func pick_rect() -> Rect2:
	var r: Rect2 = BOUNDS.get(kind, BOUNDS["apple"])
	return Rect2(r.position + Vector2(0.0, draw_offset()), r.size)


func _draw() -> void:
	var sh := clampf(1.0 - height() / 80.0, 0.5, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 18.0 * sh, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2(0, draw_offset()))
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
	draw_set_transform(Vector2.ZERO)
	if FighterBase.show_hitboxes:
		var r := pick_rect()
		draw_rect(r, Color(0.3, 0.9, 1, 0.2), true)
		draw_rect(r, Color(0.3, 0.9, 1, 0.9), false, 1.0)
