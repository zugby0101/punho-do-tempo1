extends Node2D
## Caixa quebrável que pode esconder comida.
## A hurtbox é exatamente a caixa desenhada (52 × 50 px), balançando junto quando apanha; ao quebrar,
## a caixa se desmonta em tábuas (animação de BREAK_TIME s) e deixa de ser atingível no mesmo quadro.

const FighterBase = preload("res://scripts/fighter.gd")
const W := 52.0           # largura da caixa desenhada
const H := 50.0           # altura da caixa desenhada
const MAX_HP := 10
const BREAK_TIME := 0.45  # duração da animação de quebra (tábuas voando)
const LID_MARGIN := 8.0   # folga acima da tampa: o soco na altura do peito ainda pega a borda da caixa

var game
var hp := 10
var height := 0.0
var flash := 0.0
var wobble := 0.0
var drop := "chicken"
var break_t := -1.0       # >= 0: quebrando (tempo desde o golpe final)
var break_dir := 1        # para onde as tábuas voam (direção do golpe final)


func can_be_hit() -> bool:
	return hp > 0


## Balanço lateral do desenho quando apanha (o mesmo deslocamento do _draw).
func wobble_dx() -> float:
	return sin(wobble * 60.0) * 3.0 * (wobble / 0.25)


## Hurtbox: a caixa desenhada neste quadro (relativa à base, y para baixo), com a folga da tampa.
func hurt_rect() -> Rect2:
	return Rect2(-W * 0.5 + wobble_dx(), -H - LID_MARGIN - height, W, H + LID_MARGIN)


func take_hit(dmg: int, dir: int, _knock: bool, _launch: float = 1.0) -> void:
	if hp <= 0:
		return
	hp -= dmg
	flash = 0.1
	wobble = 0.25
	if hp <= 0:
		break_t = 0.0
		break_dir = dir if dir != 0 else 1
		game.sfx.play("break")
		for i in 3:
			game.spawn_spark(position + Vector2(randf_range(-20, 20), randf_range(-50, -10)), Color(0.8, 0.55, 0.25))
		if drop != "":
			game.spawn_pickup(drop, position)


func _process(delta: float) -> void:
	flash = maxf(0.0, flash - delta)
	wobble = maxf(0.0, wobble - delta)
	if hp <= 0:
		# também no convidado online: o hp chega do anfitrião e a quebra anima aqui
		break_t = maxf(break_t, 0.0) + delta
		if break_t >= BREAK_TIME and (game == null or not game.net_client):
			queue_free()
	queue_redraw()


# Tábuas da caixa: [centro, tamanho, velocidade (px/s), giro (rad/s)]
const PLANKS := [
	[Vector2(0, -48), Vector2(52, 6), Vector2(40, -260), 6.0],    # tampa
	[Vector2(0, -26), Vector2(52, 6), Vector2(120, -180), -5.0],  # travessa do meio
	[Vector2(-23, -25), Vector2(6, 50), Vector2(-110, -220), -4.0],  # lado de trás
	[Vector2(23, -25), Vector2(6, 50), Vector2(170, -200), 7.0],  # lado da frente
	[Vector2(0, -25), Vector2(46, 5), Vector2(80, -300), 9.0],    # tábua em X
]


func _draw() -> void:
	var dark := Color(1, 1, 1) if flash > 0.0 else Color(0.4, 0.25, 0.12)
	var base := Color(1, 1, 1) if flash > 0.0 else Color(0.62, 0.4, 0.2)
	if break_t >= 0.0:
		_draw_break(base, dark)
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 30.0, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2(wobble_dx(), 0))
	draw_rect(Rect2(-26, -50, 52, 50), base)
	draw_rect(Rect2(-26, -50, 52, 50), dark, false, 3.0)
	draw_line(Vector2(-24, -48), Vector2(24, -2), dark, 4.0)
	draw_line(Vector2(-24, -2), Vector2(24, -48), dark, 4.0)
	draw_rect(Rect2(-26, -28, 52, 4), dark)
	# rachaduras conforme o dano
	if hp < MAX_HP:
		var k := clampf(1.0 - float(hp) / MAX_HP, 0.0, 1.0)
		draw_polyline(PackedVector2Array([Vector2(-14, -50), Vector2(-9, -41), Vector2(-13, -34), Vector2(-7, -30)]), dark, 2.0)
		if k > 0.45:
			draw_polyline(PackedVector2Array([Vector2(26, -14), Vector2(17, -11), Vector2(12, -4), Vector2(15, 0)]), dark, 2.0)
	draw_set_transform(Vector2.ZERO)
	if FighterBase.show_hitboxes:
		draw_rect(hurt_rect(), Color(0.2, 1, 0.3, 0.8), false, 1.0)


func _draw_break(base: Color, dark: Color) -> void:
	var t := break_t
	var a := clampf(1.0 - t / BREAK_TIME, 0.0, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 30.0 * a, Color(0, 0, 0, 0.35 * a))
	for pl in PLANKS:
		var v: Vector2 = pl[2]
		v.x *= break_dir
		var c: Vector2 = pl[0] + v * t + Vector2(0, 900.0 * t * t)  # gravidade
		c.y = minf(c.y, -float(pl[1].y) * 0.5)  # não atravessa o chão
		var sz: Vector2 = pl[1]
		draw_set_transform(c, float(pl[3]) * break_dir * t)
		draw_rect(Rect2(-sz * 0.5, sz), Color(base.r, base.g, base.b, a))
		draw_rect(Rect2(-sz * 0.5, sz), Color(dark.r, dark.g, dark.b, a), false, 2.0)
	draw_set_transform(Vector2.ZERO)
