extends Node2D
## Cenário procedural com parallax. Cada era tem seu próprio estilo:
## camada distante (parallax 0.35), camada do meio (fachadas/paredes) e chão.

var game
var stage: Dictionary
var style := "modern"
var t := 0.0
var left := 0.0
var right := 0.0


func _h(i: int, salt: float) -> float:
	return fposmod(sin(float(i) * 12.9898 + salt * 78.233) * 43758.5453, 1.0)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


## Itera sobre os segmentos visíveis de uma camada (com parallax).
func _segments(w: float, parallax: float) -> Array:
	var shift: float = game.cam_x * (1.0 - parallax)
	var arr: Array = []
	for i in range(int(floor((left - shift) / w)) - 1, int(ceil((right - shift) / w)) + 1):
		arr.append([i, i * w + shift])
	return arr


func _poly(pts: Array, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), col)


func _draw() -> void:
	var cx: float = game.cam_x
	left = cx - 520.0
	right = cx + 520.0
	style = stage.style

	# Céu em faixas
	var sky: Array = stage.sky
	for i in sky.size():
		draw_rect(Rect2(left, i * 45.0 - 10.0, right - left, 46.0), sky[i])
	_draw_celestial(cx)

	match style:
		"stone": _stone()
		"crusade": _crusade()
		"japan": _japan()
		"ships": _ships()
		"industrial": _industrial()
		"ww1": _ww1()
		"ww2": _ww2()
		"coldwar": _coldwar()
		"utopia": _utopia()
		"dystopia": _dystopia()
		"apocalypse": _apocalypse()
		_: _modern()

	# Barreira no fim da fase
	var end_x: float = game.STAGE_LEN
	if right > end_x - 40.0:
		var wc := _end_color()
		draw_rect(Rect2(end_x - 30, 40, 400, 520), wc)
		for r in 14:
			for c in 5:
				draw_rect(Rect2(end_x - 30 + c * 60 + (r % 2) * 30, 40 + r * 36, 56, 32), wc.lightened(0.15))


func _end_color() -> Color:
	match style:
		"stone": return Color(0.35, 0.28, 0.22)
		"utopia": return Color(0.8, 0.85, 0.9)
		"apocalypse": return Color(0.12, 0.05, 0.15)
		"japan", "ships": return Color(0.35, 0.22, 0.12)
	return Color(0.28, 0.16, 0.14)


func _draw_celestial(cx: float) -> void:
	var sc: Color = stage.sun
	var pos := Vector2(cx * 0.97 + 220.0, 95.0)
	if style == "apocalypse":
		# Lua partida
		draw_circle(pos, 50.0, sc)
		_poly([pos + Vector2(-10, -52), pos + Vector2(6, -10), pos + Vector2(-6, 12), pos + Vector2(8, 52), pos + Vector2(14, 52), pos + Vector2(2, 12), pos + Vector2(14, -10), pos + Vector2(-2, -52)], stage.sky[1])
		for k in 5:
			draw_circle(pos + Vector2(70 + k * 22, -20 + k * 9 + sin(t + k) * 4.0), 8.0 - k, sc.darkened(0.2))
	elif style in ["coldwar", "ww2"]:
		draw_circle(pos, 26.0, sc)
		draw_circle(pos + Vector2(-8, -4), 22.0, stage.sky[0] if style == "coldwar" else Color(0, 0, 0, 0))
	else:
		draw_circle(pos, 46.0, sc)
		draw_circle(pos, 70.0, Color(sc.r, sc.g, sc.b, sc.a * 0.15))


func _floor(top: float, c1: Color, c2: Color) -> void:
	draw_rect(Rect2(left, top, right - left, 560.0 - top), c1)
	draw_rect(Rect2(left, top, right - left, 6), c2)


func _scatter(top: float, count_w: float, col: Color, r: float, salt: float) -> void:
	for s in _segments(count_w, 1.0):
		var i: int = s[0]
		var x: float = s[1] + _h(i, salt) * count_w
		var y := top + 20.0 + _h(i, salt + 1.0) * (520.0 - top)
		draw_circle(Vector2(x, y), r * (0.5 + _h(i, salt + 2.0)), col)


# ====================== IDADE DA PEDRA ======================
func _stone() -> void:
	for s in _segments(300.0, 0.3):
		var x: float = s[1]
		var i: int = s[0]
		if i % 3 == 0:
			_poly([Vector2(x, 260), Vector2(x + 120, 90), Vector2(x + 160, 90), Vector2(x + 300, 260)], Color(0.35, 0.25, 0.25))
			_poly([Vector2(x + 120, 90), Vector2(x + 160, 90), Vector2(x + 150, 110), Vector2(x + 130, 108)], Color(1, 0.4, 0.1))
			for k in 4:
				var ph := fposmod(t * 0.3 + k * 0.25, 1.0)
				draw_circle(Vector2(x + 140 + sin(ph * 6.0 + k) * 10.0, 85 - ph * 80.0), 10.0 + ph * 18.0, Color(0.4, 0.38, 0.38, 0.6 * (1.0 - ph)))
		else:
			draw_circle(Vector2(x + 150, 290), 130.0, Color(0.3, 0.5, 0.3))
	for s in _segments(260.0, 1.0):
		var x: float = s[1]
		var i: int = s[0]
		var top := 120.0 + _h(i, 1.0) * 60.0
		_poly([Vector2(x - 10, 330), Vector2(x + 20, top), Vector2(x + 140, top - 20), Vector2(x + 270, top + 10), Vector2(x + 270, 330)], Color(0.5, 0.38, 0.28))
		_poly([Vector2(x + 20, top), Vector2(x + 140, top - 20), Vector2(x + 140, top), Vector2(x + 30, top + 14)], Color(0.6, 0.48, 0.35))
		if _h(i, 2.0) > 0.4:
			draw_set_transform(Vector2(x + 130, 290), 0.0, Vector2(1.0, 1.3))
			draw_circle(Vector2.ZERO, 34.0, Color(0.12, 0.08, 0.06))
			draw_set_transform(Vector2.ZERO)
			draw_circle(Vector2(x + 128, 318), 6.0 + sin(t * 12.0 + i) * 1.5, Color(1, 0.6, 0.1))
		# pinturas rupestres
		draw_line(Vector2(x + 60, top + 60), Vector2(x + 90, top + 60), Color(0.7, 0.25, 0.1), 3.0)
		draw_line(Vector2(x + 66, top + 60), Vector2(x + 64, top + 72), Color(0.7, 0.25, 0.1), 3.0)
		draw_line(Vector2(x + 86, top + 60), Vector2(x + 88, top + 72), Color(0.7, 0.25, 0.1), 3.0)
		# samambaias
		for f in 5:
			var a := -PI * 0.5 + (f - 2) * 0.35
			draw_line(Vector2(x + 220, 332), Vector2(x + 220, 332) + Vector2(cos(a), sin(a)) * 40.0, Color(0.2, 0.55, 0.2), 4.0)
	_floor(330.0, Color(0.55, 0.42, 0.28), Color(0.4, 0.3, 0.2))
	_scatter(330.0, 90.0, Color(0.45, 0.4, 0.36), 6.0, 5.0)
	for s in _segments(700.0, 1.0):
		var bx: float = s[1] + 300.0
		draw_line(Vector2(bx, 500), Vector2(bx + 24, 494), Color(0.95, 0.92, 0.85), 4.0)
		draw_circle(Vector2(bx, 500), 4.0, Color(0.95, 0.92, 0.85))
		draw_circle(Vector2(bx + 24, 494), 4.0, Color(0.95, 0.92, 0.85))


# ====================== CRUZADAS ======================
func _crusade() -> void:
	for s in _segments(260.0, 0.3):
		var x: float = s[1]
		var i: int = s[0]
		draw_circle(Vector2(x + 130, 330), 160.0, Color(0.88, 0.72, 0.45))
		if i % 4 == 0:
			draw_rect(Rect2(x + 100, 150, 40, 120), Color(0.75, 0.62, 0.45))
			draw_circle(Vector2(x + 120, 150), 22.0, Color(0.75, 0.62, 0.45))
	var stone := Color(0.7, 0.62, 0.5)
	for s in _segments(240.0, 1.0):
		var x: float = s[1]
		var i: int = s[0]
		draw_rect(Rect2(x, 140, 240, 190), stone)
		for k in 6:
			draw_rect(Rect2(x + k * 40, 120, 26, 22), stone)
		for r in 6:
			for c in 5:
				draw_rect(Rect2(x + c * 48 + (r % 2) * 24, 146 + r * 30, 46, 28), stone.darkened(0.08), false, 1.5)
		# arco
		draw_rect(Rect2(x + 150, 230, 60, 100), Color(0.2, 0.15, 0.1))
		draw_circle(Vector2(x + 180, 230), 30.0, Color(0.2, 0.15, 0.1))
		# estandarte
		var wv := sin(t * 3.0 + i) * 3.0
		_poly([Vector2(x + 40, 160), Vector2(x + 90, 160), Vector2(x + 90 + wv, 260), Vector2(x + 65, 245), Vector2(x + 40 + wv, 260)], Color(0.75, 0.1, 0.12))
		draw_rect(Rect2(x + 60, 180, 10, 50), Color(0.95, 0.9, 0.8))
		draw_rect(Rect2(x + 48, 196, 34, 10), Color(0.95, 0.9, 0.8))
		# tocha
		draw_rect(Rect2(x + 125, 200, 6, 24), Color(0.35, 0.22, 0.1))
		draw_circle(Vector2(x + 128, 196), 7.0 + sin(t * 14.0 + i) * 2.0, Color(1, 0.6, 0.1))
	_floor(330.0, Color(0.86, 0.72, 0.48), Color(0.6, 0.5, 0.35))
	for s in _segments(80.0, 1.0):
		var x: float = s[1]
		draw_rect(Rect2(x + 6, 400 + _h(s[0], 3.0) * 100.0, 34, 14), Color(0.75, 0.62, 0.42))


# ====================== JAPÃO FEUDAL ======================
func _japan() -> void:
	for s in _segments(1100.0, 0.2):
		var x: float = s[1]
		_poly([Vector2(x, 280), Vector2(x + 480, 90), Vector2(x + 560, 90), Vector2(x + 1040, 280)], Color(0.35, 0.3, 0.5))
		_poly([Vector2(x + 430, 110), Vector2(x + 480, 90), Vector2(x + 560, 90), Vector2(x + 610, 110), Vector2(x + 570, 122), Vector2(x + 520, 108), Vector2(x + 470, 124)], Color(0.97, 0.95, 1.0))
	for s in _segments(300.0, 0.5):
		var x: float = s[1]
		if s[0] % 3 == 1:
			draw_rect(Rect2(x + 120, 130, 60, 150), Color(0.3, 0.15, 0.18))
			for k in 4:
				var y := 130.0 + k * 38.0
				_poly([Vector2(x + 100 - k * 4, y + 8), Vector2(x + 200 + k * 4, y + 8), Vector2(x + 180, y - 6), Vector2(x + 120, y - 6)], Color(0.2, 0.08, 0.1))
	var wood := Color(0.35, 0.2, 0.12)
	for s in _segments(260.0, 1.0):
		var x: float = s[1]
		var i: int = s[0]
		if i % 3 == 2:
			# cerejeira
			draw_line(Vector2(x + 130, 330), Vector2(x + 120, 200), Color(0.3, 0.18, 0.12), 12.0)
			draw_line(Vector2(x + 122, 230), Vector2(x + 80, 190), Color(0.3, 0.18, 0.12), 6.0)
			for k in 7:
				draw_circle(Vector2(x + 70 + _h(i * 9 + k, 1.0) * 110.0, 150 + _h(i * 9 + k, 2.0) * 70.0), 26.0, Color(1, 0.72, 0.82))
			continue
		draw_rect(Rect2(x + 10, 170, 240, 160), wood)
		for k in 4:
			draw_rect(Rect2(x + 22 + k * 56, 186, 48, 120), Color(0.95, 0.9, 0.78))
			draw_line(Vector2(x + 46 + k * 56, 186), Vector2(x + 46 + k * 56, 306), wood, 2.0)
			draw_line(Vector2(x + 22 + k * 56, 246), Vector2(x + 70 + k * 56, 246), wood, 2.0)
		_poly([Vector2(x - 20, 176), Vector2(x + 280, 176), Vector2(x + 240, 130), Vector2(x + 20, 130)], Color(0.18, 0.16, 0.2))
		draw_circle(Vector2(x + 30, 200 + sin(t * 2.0 + i) * 2.0), 11.0, Color(0.9, 0.15, 0.1))
		draw_circle(Vector2(x + 30, 200 + sin(t * 2.0 + i) * 2.0), 18.0, Color(1, 0.4, 0.2, 0.2))
	_floor(330.0, Color(0.58, 0.45, 0.33), Color(0.4, 0.3, 0.22))
	# pétalas caindo
	for k in 30:
		var px := left + fposmod(k * 97.0 + t * (20.0 + k), right - left)
		var py := fposmod(k * 53.0 + t * (30.0 + k % 5 * 6.0), 540.0)
		draw_circle(Vector2(px, py), 2.5, Color(1, 0.75, 0.85, 0.85))


# ====================== GRANDES NAVEGAÇÕES ======================
func _ships() -> void:
	draw_rect(Rect2(left, 200, right - left, 130), Color(0.15, 0.35, 0.6))
	for s in _segments(70.0, 0.4):
		var x: float = s[1]
		var y := 215.0 + float(s[0] % 5) * 22.0
		draw_line(Vector2(x, y + sin(t * 2.0 + s[0]) * 3.0), Vector2(x + 30, y + sin(t * 2.0 + s[0]) * 3.0), Color(0.7, 0.85, 1, 0.6), 2.0)
	for s in _segments(900.0, 0.25):
		var x: float = s[1] + 300.0
		_poly([Vector2(x, 200), Vector2(x + 60, 200), Vector2(x + 50, 210), Vector2(x + 10, 210)], Color(0.2, 0.15, 0.15))
		draw_line(Vector2(x + 30, 200), Vector2(x + 30, 165), Color(0.2, 0.15, 0.15), 2.0)
		_poly([Vector2(x + 30, 168), Vector2(x + 48, 185), Vector2(x + 30, 195)], Color(0.9, 0.9, 0.85))
	# mastros e velas do próprio navio
	for s in _segments(520.0, 1.0):
		var x: float = s[1] + 200.0
		var i: int = s[0]
		draw_rect(Rect2(x - 7, -20, 14, 360), Color(0.4, 0.26, 0.14))
		var bl := sin(t * 1.5 + i) * 6.0
		_poly([Vector2(x - 90, 20), Vector2(x + 90, 20), Vector2(x + 100 + bl, 170), Vector2(x - 100 + bl, 170)], Color(0.95, 0.92, 0.82))
		draw_rect(Rect2(x - 92, 14, 184, 8), Color(0.35, 0.22, 0.12))
		draw_rect(Rect2(x - 12, 60, 24, 70), Color(0.75, 0.1, 0.1))
		draw_rect(Rect2(x - 30, 84, 60, 22), Color(0.75, 0.1, 0.1))
		draw_line(Vector2(x, 0), Vector2(x - 260, 300), Color(0.2, 0.15, 0.1), 2.0)
		draw_line(Vector2(x, 0), Vector2(x + 260, 300), Color(0.2, 0.15, 0.1), 2.0)
	# amurada
	draw_rect(Rect2(left, 296, right - left, 40), Color(0.45, 0.28, 0.14))
	for s in _segments(48.0, 1.0):
		draw_rect(Rect2(s[1], 270, 10, 30), Color(0.4, 0.25, 0.12))
	draw_rect(Rect2(left, 266, right - left, 8), Color(0.5, 0.32, 0.16))
	_floor(336.0, Color(0.6, 0.42, 0.24), Color(0.4, 0.26, 0.14))
	for r in 8:
		draw_line(Vector2(left, 360 + r * 24), Vector2(right, 360 + r * 24), Color(0.45, 0.3, 0.16), 2.0)
	for s in _segments(150.0, 1.0):
		for r in 8:
			var xx: float = s[1] + fposmod(r * 47.0, 150.0)
			draw_line(Vector2(xx, 336 + r * 24), Vector2(xx, 360 + r * 24), Color(0.45, 0.3, 0.16), 2.0)


# ====================== REVOLUÇÃO INDUSTRIAL ======================
func _industrial() -> void:
	for s in _segments(200.0, 0.35):
		var x: float = s[1]
		var i: int = s[0]
		draw_rect(Rect2(x, 180, 190, 120), Color(0.25, 0.2, 0.18))
		if i % 2 == 0:
			draw_rect(Rect2(x + 80, 60, 26, 130), Color(0.3, 0.22, 0.2))
			for k in 5:
				var ph := fposmod(t * 0.25 + k * 0.2 + i * 0.1, 1.0)
				draw_circle(Vector2(x + 93 + ph * 60.0, 55 - ph * 70.0), 12.0 + ph * 26.0, Color(0.25, 0.23, 0.22, 0.7 * (1.0 - ph)))
	var brick := Color(0.55, 0.25, 0.18)
	for s in _segments(240.0, 1.0):
		var x: float = s[1]
		var i: int = s[0]
		draw_rect(Rect2(x, 100, 240, 230), brick)
		for r in 11:
			for c in 6:
				draw_rect(Rect2(x + c * 40 + (r % 2) * 20, 100 + r * 20, 38, 18), brick.darkened(0.12), false, 1.0)
		for k in 2:
			var wx := x + 30 + k * 110
			draw_rect(Rect2(wx, 130, 80, 90), Color(0.9, 0.75, 0.35) if _h(i * 3 + k, 1.0) > 0.4 else Color(0.15, 0.15, 0.18))
			for g in 3:
				draw_line(Vector2(wx + 20 + g * 20, 130), Vector2(wx + 20 + g * 20, 220), Color(0.2, 0.15, 0.12), 2.0)
			draw_line(Vector2(wx, 175), Vector2(wx + 80, 175), Color(0.2, 0.15, 0.12), 2.0)
		# engrenagem
		var gp := Vector2(x + 120, 270)
		var rot := t * (1.0 if i % 2 == 0 else -1.0)
		for k in 8:
			var a := rot + k * TAU / 8.0
			draw_line(gp, gp + Vector2(cos(a), sin(a)) * 36.0, Color(0.45, 0.42, 0.4), 10.0)
		draw_circle(gp, 28.0, Color(0.5, 0.47, 0.45))
		draw_circle(gp, 9.0, Color(0.25, 0.23, 0.22))
		draw_rect(Rect2(x, 232, 240, 8), Color(0.4, 0.4, 0.42))
	_floor(330.0, Color(0.38, 0.36, 0.35), Color(0.25, 0.24, 0.24))
	for s in _segments(36.0, 1.0):
		for r in 9:
			var xx: float = s[1] + (r % 2) * 18.0
			draw_rect(Rect2(xx, 338 + r * 23, 32, 19), Color(0.43, 0.41, 0.4))


# ====================== 1ª GUERRA MUNDIAL ======================
func _ww1() -> void:
	for s in _segments(400.0, 0.3):
		var x: float = s[1]
		var i: int = s[0]
		draw_circle(Vector2(x + 200, 380), 260.0, Color(0.4, 0.36, 0.3))
		draw_line(Vector2(x + 120, 160), Vector2(x + 118, 110), Color(0.2, 0.18, 0.15), 4.0)
		draw_line(Vector2(x + 119, 130), Vector2(x + 100, 115), Color(0.2, 0.18, 0.15), 3.0)
		# explosões distantes
		var ph := fposmod(t * 0.4 + _h(i, 1.0), 1.0)
		if ph < 0.25:
			draw_circle(Vector2(x + 260, 160), 20.0 + ph * 120.0, Color(1, 0.7, 0.3, 0.5 * (1.0 - ph * 4.0)))
	# parede da trincheira (sacos de areia e tábuas)
	draw_rect(Rect2(left, 230, right - left, 100), Color(0.36, 0.28, 0.2))
	for s in _segments(60.0, 1.0):
		draw_line(Vector2(s[1], 230), Vector2(s[1], 330), Color(0.28, 0.2, 0.14), 4.0)
	for s in _segments(44.0, 1.0):
		for r in 3:
			var xx: float = s[1] + (r % 2) * 22.0
			draw_set_transform(Vector2(xx, 212 + r * 14), 0.0, Vector2(1.0, 0.45))
			draw_circle(Vector2.ZERO, 22.0, Color(0.6, 0.55, 0.4))
			draw_set_transform(Vector2.ZERO)
	# arame farpado
	for s in _segments(30.0, 1.0):
		var x: float = s[1]
		draw_line(Vector2(x, 178), Vector2(x + 15, 192), Color(0.25, 0.25, 0.25), 1.5)
		draw_line(Vector2(x + 15, 192), Vector2(x + 30, 178), Color(0.25, 0.25, 0.25), 1.5)
	for s in _segments(200.0, 1.0):
		draw_line(Vector2(s[1], 170), Vector2(s[1], 205), Color(0.3, 0.22, 0.15), 4.0)
	_floor(330.0, Color(0.33, 0.27, 0.2), Color(0.25, 0.2, 0.15))
	_scatter(330.0, 150.0, Color(0.26, 0.22, 0.18), 18.0, 9.0)
	for s in _segments(60.0, 1.0):
		draw_rect(Rect2(s[1], 420, 50, 34), Color(0.45, 0.35, 0.22))


# ====================== 2ª GUERRA MUNDIAL ======================
func _ww2() -> void:
	for s in _segments(120.0, 0.35):
		var x: float = s[1]
		var i: int = s[0]
		var top := 120.0 + _h(i, 1.0) * 80.0
		_poly([Vector2(x, 300), Vector2(x, top), Vector2(x + 30, top - 15), Vector2(x + 60, top + 10), Vector2(x + 90, top - 5), Vector2(x + 118, top + 20), Vector2(x + 118, 300)], Color(0.12, 0.1, 0.14))
	# holofotes
	for k in 3:
		var base := Vector2(game.cam_x - 350.0 + k * 350.0, 300)
		var a := -PI * 0.5 + sin(t * 0.5 + k * 2.0) * 0.6
		var dir := Vector2(cos(a), sin(a))
		var perp := Vector2(-dir.y, dir.x)
		_poly([base, base + dir * 400.0 + perp * 40.0, base + dir * 400.0 - perp * 40.0], Color(1, 1, 0.8, 0.08))
	for s in _segments(240.0, 1.0):
		var x: float = s[1]
		var i: int = s[0]
		var top := 110.0 + _h(i, 2.0) * 50.0
		_poly([Vector2(x, 330), Vector2(x, top), Vector2(x + 70, top - 20), Vector2(x + 120, top + 30), Vector2(x + 180, top), Vector2(x + 240, top + 40), Vector2(x + 240, 330)], Color(0.38, 0.35, 0.33))
		for r in 2:
			for c in 3:
				var hole := _h(i * 11 + r * 3 + c, 3.0) > 0.6
				draw_rect(Rect2(x + 25 + c * 72, top + 60 + r * 70, 44, 50), Color(0.9, 0.45, 0.15) if hole else Color(0.1, 0.1, 0.12))
		draw_circle(Vector2(x + 200, 320), 30.0, Color(0.3, 0.28, 0.27))
		if _h(i, 4.0) > 0.5:
			draw_circle(Vector2(x + 60, 310), 12.0 + sin(t * 10.0 + i) * 3.0, Color(1, 0.5, 0.1, 0.9))
			draw_circle(Vector2(x + 60, 298), 8.0 + sin(t * 13.0 + i) * 2.0, Color(1, 0.85, 0.3, 0.9))
	_floor(330.0, Color(0.3, 0.28, 0.28), Color(0.2, 0.19, 0.19))
	_scatter(330.0, 70.0, Color(0.45, 0.25, 0.2), 7.0, 11.0)
	_scatter(330.0, 110.0, Color(0.4, 0.38, 0.36), 9.0, 12.0)


# ====================== GUERRA FRIA ======================
func _coldwar() -> void:
	for s in _segments(150.0, 0.35):
		var x: float = s[1]
		var i: int = s[0]
		var hgt := 80.0 + _h(i, 1.0) * 90.0
		draw_rect(Rect2(x, 270 - hgt, 130, hgt + 30), Color(0.1, 0.11, 0.18))
		for r in int(hgt / 20.0):
			for c in 4:
				if _h(i * 41 + r * 4 + c, 2.0) > 0.7:
					draw_rect(Rect2(x + 12 + c * 28, 280 - hgt + r * 20, 10, 8), Color(1, 0.9, 0.6, 0.6))
		if i % 7 == 0:
			draw_rect(Rect2(x + 60, 40, 8, 230), Color(0.15, 0.15, 0.22))
			draw_circle(Vector2(x + 64, 90), 16.0, Color(0.2, 0.2, 0.3))
			draw_circle(Vector2(x + 64, 40), 3.0, Color(1, 0.2, 0.2) if int(t * 2.0) % 2 == 0 else Color(0.4, 0.1, 0.1))
	var graffiti := [Color(1, 0.2, 0.5), Color(0.2, 0.8, 1), Color(1, 0.85, 0.1), Color(0.3, 1, 0.4)]
	for s in _segments(160.0, 1.0):
		var x: float = s[1]
		var i: int = s[0]
		draw_rect(Rect2(x, 160, 156, 170), Color(0.62, 0.62, 0.6))
		draw_circle(Vector2(x + 78, 160), 0.1, Color.WHITE)
		draw_rect(Rect2(x - 4, 150, 164, 14), Color(0.7, 0.7, 0.68))
		for k in 3:
			var gc: Color = graffiti[int(_h(i * 5 + k, 1.0) * 4.0) % 4]
			var gx := x + 20 + _h(i * 5 + k, 2.0) * 100.0
			var gy := 200 + _h(i * 5 + k, 3.0) * 90.0
			draw_arc(Vector2(gx, gy), 14.0 + _h(i + k, 4.0) * 10.0, 0, PI * 1.6, 12, gc, 5.0)
			draw_line(Vector2(gx - 10, gy + 20), Vector2(gx + 30, gy - 5), gc, 4.0)
		if i % 4 == 0:
			draw_rect(Rect2(x + 60, 40, 40, 30), Color(0.4, 0.42, 0.4))
			draw_rect(Rect2(x + 74, 70, 12, 80), Color(0.4, 0.42, 0.4))
			draw_rect(Rect2(x + 64, 46, 32, 12), Color(1, 0.95, 0.6))
	for s in _segments(26.0, 1.0):
		draw_arc(Vector2(s[1], 146), 9.0, PI, TAU, 8, Color(0.3, 0.3, 0.3), 1.5)
	_floor(330.0, Color(0.32, 0.33, 0.36), Color(0.5, 0.5, 0.5))
	for s in _segments(160.0, 1.0):
		draw_line(Vector2(s[1], 336), Vector2(s[1] - 40, 540), Color(0.26, 0.27, 0.3), 2.0)
	draw_rect(Rect2(left, 440, right - left, 4), Color(0.85, 0.85, 0.85, 0.7))


# ====================== TEMPO ATUAL ======================
func _modern() -> void:
	for s in _segments(80.0, 0.35):
		var x: float = s[1]
		var i: int = s[0]
		var bh := 90.0 + _h(i, 1.0) * 120.0
		draw_rect(Rect2(x, 240.0 - bh, 76.0, bh), Color(0.13, 0.08, 0.22))
		for wy in range(int(bh / 18.0) - 1):
			for wx in 3:
				if _h(i * 31 + wy * 7 + wx, 2.0) > 0.6:
					draw_rect(Rect2(x + 10.0 + wx * 22.0, 250.0 - bh + wy * 18.0, 8, 8), Color(1.0, 0.85, 0.4, 0.5))
	var neon := [Color(1, 0.2, 0.6), Color(0.2, 0.9, 1), Color(0.6, 1, 0.3), Color(1, 0.8, 0.2)]
	for s in _segments(240.0, 1.0):
		var x: float = s[1]
		var i: int = s[0]
		var col := Color.from_hsv(_h(i, 3.0), 0.35, 0.35 + _h(i, 4.0) * 0.15)
		draw_rect(Rect2(x, 90, 240, 230), col)
		draw_rect(Rect2(x, 90, 6, 230), col.darkened(0.35))
		for wx in 3:
			var lit := _h(i * 5 + wx, 5.0) > 0.4
			draw_rect(Rect2(x + 30 + wx * 66, 110, 40, 44), Color(1, 0.9, 0.55) if lit else Color(0.1, 0.1, 0.18))
			draw_rect(Rect2(x + 30 + wx * 66, 110, 40, 44), col.darkened(0.5), false, 3.0)
		var nc: Color = neon[int(_h(i, 6.0) * 4.0) % 4]
		var on := sin(t * (2.0 + _h(i, 7.0) * 5.0) + i) > -0.7
		var sign_c := nc if on else nc.darkened(0.7)
		draw_rect(Rect2(x + 40, 172, 160, 26), Color(0.05, 0.03, 0.08))
		draw_rect(Rect2(x + 40, 172, 160, 26), sign_c, false, 3.0)
		for k in 6:
			draw_rect(Rect2(x + 54 + k * 24, 180, 14, 10), sign_c)
		draw_rect(Rect2(x + 20, 214, 130, 90), Color(0.15, 0.25, 0.35))
		draw_rect(Rect2(x + 20, 214, 130, 90), col.darkened(0.5), false, 4.0)
		draw_line(Vector2(x + 30, 290), Vector2(x + 70, 224), Color(1, 1, 1, 0.15), 6.0)
		draw_rect(Rect2(x + 165, 224, 50, 96), col.darkened(0.55))
		draw_circle(Vector2(x + 205, 274), 3.0, Color(0.9, 0.8, 0.3))
	draw_rect(Rect2(left, 318, right - left, 26), Color(0.42, 0.4, 0.45))
	for s in _segments(60.0, 1.0):
		draw_line(Vector2(s[1], 318), Vector2(s[1] - 10, 344), Color(0.32, 0.3, 0.35), 2.0)
	draw_rect(Rect2(left, 344, right - left, 8), Color(0.6, 0.58, 0.6))
	draw_rect(Rect2(left, 352, right - left, 200), Color(0.2, 0.19, 0.24))
	for s in _segments(120.0, 1.0):
		draw_rect(Rect2(s[1], 440, 60, 6), Color(0.85, 0.8, 0.4, 0.8))
	for s in _segments(480.0, 1.0):
		var px: float = s[1] + 120.0
		draw_rect(Rect2(px - 3, 150, 6, 190), Color(0.15, 0.15, 0.18))
		draw_rect(Rect2(px - 3, 150, 34, 5), Color(0.15, 0.15, 0.18))
		draw_circle(Vector2(px + 30, 158), 6.0, Color(1, 0.95, 0.7))
		draw_circle(Vector2(px + 30, 158), 16.0, Color(1, 0.9, 0.5, 0.15))


# ====================== FUTURO: TUDO DEU CERTO ======================
func _utopia() -> void:
	for s in _segments(180.0, 0.3):
		var x: float = s[1]
		var i: int = s[0]
		var hgt := 120.0 + _h(i, 1.0) * 120.0
		draw_rect(Rect2(x + 40, 280 - hgt, 60, hgt), Color(0.88, 0.93, 0.97))
		draw_circle(Vector2(x + 70, 280 - hgt), 30.0, Color(0.88, 0.93, 0.97))
		draw_circle(Vector2(x + 70, 280 - hgt + 30), 22.0, Color(0.45, 0.8, 0.45))
		draw_rect(Rect2(x + 66, 280 - hgt, 8, hgt), Color(0.6, 0.95, 1.0, 0.6))
	# carros voadores
	for k in 6:
		var fx := left + fposmod(k * 210.0 + t * (60.0 + k * 25.0) * (1 if k % 2 == 0 else -1), right - left)
		var fy := 60.0 + k * 22.0
		draw_rect(Rect2(fx, fy, 30, 9), Color(1, 1, 1))
		draw_rect(Rect2(fx + 18, fy - 5, 10, 6), Color(0.4, 0.85, 1))
	for s in _segments(240.0, 1.0):
		var x: float = s[1]
		var i: int = s[0]
		draw_rect(Rect2(x, 150, 236, 180), Color(0.95, 0.97, 1.0))
		draw_rect(Rect2(x, 150, 236, 180), Color(0.75, 0.82, 0.9), false, 2.0)
		var glow := 0.6 + sin(t * 2.0 + i) * 0.3
		draw_rect(Rect2(x, 200, 236, 4), Color(0.3, 0.9, 1, glow))
		draw_rect(Rect2(x + 30, 220, 80, 100), Color(0.6, 0.85, 0.95, 0.5))
		# holograma
		var hc := Color(0.3, 1, 0.9, 0.35 + sin(t * 5.0 + i) * 0.1)
		draw_rect(Rect2(x + 130, 165, 80, 26), hc)
		draw_circle(Vector2(x + 170, 260 + sin(t * 2.0 + i) * 5.0), 16.0, hc)
		# planta
		draw_rect(Rect2(x + 140, 300, 50, 30), Color(0.85, 0.88, 0.92))
		draw_circle(Vector2(x + 165, 286), 22.0, Color(0.35, 0.75, 0.35))
	_floor(330.0, Color(0.86, 0.9, 0.94), Color(0.4, 0.9, 1.0))
	for s in _segments(100.0, 1.0):
		draw_line(Vector2(s[1], 336), Vector2(s[1] - 60, 540), Color(0.75, 0.82, 0.88), 2.0)
	draw_rect(Rect2(left, 438, right - left, 3), Color(0.3, 0.9, 1, 0.5 + sin(t * 3.0) * 0.3))


# ====================== FUTURO: TUDO DEU ERRADO ======================
func _dystopia() -> void:
	for s in _segments(160.0, 0.3):
		var x: float = s[1]
		var i: int = s[0]
		var hgt := 150.0 + _h(i, 1.0) * 120.0
		draw_rect(Rect2(x + 20, 290 - hgt, 110, hgt), Color(0.1, 0.05, 0.06))
		draw_circle(Vector2(x + 75, 290 - hgt), 3.0, Color(1, 0.1, 0.1) if int(t * 2.0 + i) % 2 == 0 else Color(0.3, 0.05, 0.05))
		if i % 3 == 0:
			draw_rect(Rect2(x + 30, 300 - hgt + 30, 90, 40), Color(0.9, 0.2, 0.5, 0.35 + sin(t * 7.0 + i) * 0.2))
	var rust := Color(0.38, 0.24, 0.18)
	for s in _segments(240.0, 1.0):
		var x: float = s[1]
		var i: int = s[0]
		draw_rect(Rect2(x, 120, 240, 210), rust)
		for k in 4:
			draw_line(Vector2(x + k * 60, 120), Vector2(x + k * 60, 330), rust.darkened(0.3), 3.0)
		for k in 6:
			draw_circle(Vector2(x + _h(i * 7 + k, 1.0) * 240.0, 140 + _h(i * 7 + k, 2.0) * 180.0), 4.0 + _h(i + k, 3.0) * 8.0, Color(0.5, 0.3, 0.15))
		draw_rect(Rect2(x, 150, 240, 12), Color(0.3, 0.3, 0.32))
		# letreiro quebrado
		var on := sin(t * 11.0 + i * 3.0) > 0.3 or _h(i, 5.0) > 0.7
		draw_rect(Rect2(x + 40, 180, 120, 24), Color(0.2, 1, 0.4) if on else Color(0.1, 0.25, 0.12), false, 3.0)
		# barril com fogo
		draw_rect(Rect2(x + 190, 290, 30, 40), Color(0.3, 0.3, 0.33))
		draw_circle(Vector2(x + 205, 284), 10.0 + sin(t * 12.0 + i) * 3.0, Color(1, 0.45, 0.1))
		draw_circle(Vector2(x + 205, 274), 6.0 + sin(t * 15.0 + i) * 2.0, Color(1, 0.85, 0.2))
	_floor(330.0, Color(0.18, 0.14, 0.14), Color(0.3, 0.2, 0.18))
	for s in _segments(130.0, 1.0):
		var x: float = s[1]
		var y := 380.0 + _h(s[0], 7.0) * 130.0
		draw_line(Vector2(x, y), Vector2(x + 30, y + 10), Color(0.08, 0.06, 0.06), 2.0)
		draw_line(Vector2(x + 30, y + 10), Vector2(x + 50, y - 4), Color(0.08, 0.06, 0.06), 2.0)
		draw_set_transform(Vector2(x + 80, y + 20), 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 30.0, Color(0.5, 0.15, 0.3, 0.35))
		draw_set_transform(Vector2.ZERO)
	# chuva ácida
	for k in 70:
		var rx := left + fposmod(k * 131.0 + t * 80.0, right - left)
		var ry := fposmod(k * 71.0 + t * 600.0, 560.0)
		draw_line(Vector2(rx, ry), Vector2(rx - 4, ry + 14), Color(0.6, 1, 0.4, 0.35), 1.5)


# ====================== FUTURO: DEU MUITO ERRADO ======================
func _apocalypse() -> void:
	# meteoros
	for k in 3:
		var ph := fposmod(t * 0.35 + k * 0.33, 1.0)
		var mp := Vector2(left + 200.0 + k * 300.0 + ph * 300.0, ph * 260.0)
		draw_line(mp, mp - Vector2(60, 50), Color(1, 0.6, 0.2, 0.5), 3.0)
		draw_circle(mp, 4.0, Color(1, 0.85, 0.5))
	draw_rect(Rect2(left, 240, right - left, 40), Color(0.7, 0.2, 0.05, 0.6))
	for s in _segments(220.0, 0.3):
		var x: float = s[1]
		var i: int = s[0]
		var fy := 150.0 + sin(t * 0.8 + i) * 8.0
		_poly([Vector2(x + 30, fy), Vector2(x + 150, fy - 10), Vector2(x + 120, fy + 40), Vector2(x + 60, fy + 50)], Color(0.12, 0.05, 0.12))
		draw_rect(Rect2(x + 70, fy - 60, 20, 55), Color(0.12, 0.05, 0.12))
	for s in _segments(200.0, 1.0):
		var x: float = s[1]
		var i: int = s[0]
		var top := 80.0 + _h(i, 1.0) * 80.0
		_poly([Vector2(x, 330), Vector2(x + 40, top + 40), Vector2(x + 70, top), Vector2(x + 90, top + 70), Vector2(x + 150, top + 20), Vector2(x + 200, 330)], Color(0.08, 0.03, 0.1))
		var glow := 0.6 + sin(t * 3.0 + i) * 0.3
		_poly([Vector2(x + 60, 330), Vector2(x + 75, 250), Vector2(x + 90, 330)], Color(0.7, 0.2, 1.0, glow))
		_poly([Vector2(x + 130, 330), Vector2(x + 145, 270), Vector2(x + 155, 330)], Color(0.7, 0.2, 1.0, glow * 0.8))
		draw_circle(Vector2(x + 170, 316), 9.0, Color(0.9, 0.88, 0.8))
		draw_rect(Rect2(x + 165, 314, 3, 3), Color(0.1, 0.05, 0.1))
		draw_rect(Rect2(x + 172, 314, 3, 3), Color(0.1, 0.05, 0.1))
	_floor(330.0, Color(0.1, 0.07, 0.1), Color(0.5, 0.15, 0.6))
	for s in _segments(180.0, 1.0):
		var x: float = s[1]
		var y := 360.0 + _h(s[0], 7.0) * 150.0
		var lava := Color(1, 0.45 + sin(t * 4.0 + s[0]) * 0.15, 0.1, 0.9)
		draw_line(Vector2(x, y), Vector2(x + 40, y + 12), lava, 3.0)
		draw_line(Vector2(x + 40, y + 12), Vector2(x + 70, y - 2), lava, 3.0)
		draw_line(Vector2(x + 40, y + 12), Vector2(x + 50, y + 30), lava, 2.0)
	# cinzas
	for k in 40:
		var ax := left + fposmod(k * 113.0 - t * 30.0, right - left)
		var ay := fposmod(k * 61.0 - t * (25.0 + k % 4 * 8.0), 560.0)
		draw_circle(Vector2(ax, ay), 2.0, Color(1, 0.5, 0.2, 0.6))
