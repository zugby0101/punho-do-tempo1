extends RefCounted
## Efeitos de partículas dos golpes (CPUParticles2D: funciona no renderizador Compatibility e na web).
## Cada tipo de impacto tem a sua receita: faíscas, poeira, lascas, anel de choque...
##   Fx.burst(parent, "slam", ponto_do_acerto, pé_do_alvo, direção, cor, escala)

const Ring = preload("res://scripts/fx_ring.gd")

static var tex := {}
static var mat_add: CanvasItemMaterial = null

const DUST := Color(0.82, 0.76, 0.64, 0.75)
const WHITE := Color(1, 1, 1)


static func _textures() -> void:
	if not tex.is_empty():
		return
	# ponto suave
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var dot := GradientTexture2D.new()
	dot.gradient = g
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.width = 16
	dot.height = 16
	tex["dot"] = dot
	# risco de faísca (alinhado com a velocidade)
	var gs := Gradient.new()
	gs.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	gs.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var streak := GradientTexture2D.new()
	streak.gradient = gs
	streak.fill_from = Vector2(0.5, 0.0)
	streak.fill_to = Vector2(0.5, 1.0)
	streak.width = 4
	streak.height = 30
	tex["streak"] = streak
	# lasca / pedrinha
	var img := Image.create(6, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1))
	tex["chunk"] = ImageTexture.create_from_image(img)
	mat_add = CanvasItemMaterial.new()
	mat_add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD


static func _fade(c0: Color, c1: Color) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	g.colors = PackedColorArray([c0, c1, Color(c1.r, c1.g, c1.b, 0.0)])
	return g


static func _shrink() -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0.15))
	return c


## Um emissor de uma vez só, que se apaga quando termina.
static func _emit(parent: Node, pos: Vector2, o: Dictionary) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.explosiveness = o.get("explosive", 1.0)
	p.amount = maxi(1, int(o.get("amount", 10)))
	p.lifetime = o.get("life", 0.3)
	p.randomness = 0.4
	p.lifetime_randomness = 0.4
	p.local_coords = false
	p.texture = tex[o.get("tex", "streak")]
	p.direction = o.get("dir", Vector2(1, 0))
	p.spread = o.get("spread", 45.0)
	p.initial_velocity_min = o.get("v0", 150.0)
	p.initial_velocity_max = o.get("v1", 300.0)
	p.gravity = Vector2(0, o.get("gravity", 0.0))
	p.damping_min = o.get("damp", 0.0)
	p.damping_max = o.get("damp", 0.0) * 1.4
	p.scale_amount_min = o.get("s0", 0.6)
	p.scale_amount_max = o.get("s1", 1.0)
	p.scale_amount_curve = _shrink()
	p.color_ramp = _fade(o.get("c0", WHITE), o.get("c1", WHITE))
	if o.get("emit_box", Vector2.ZERO) != Vector2.ZERO:
		p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		p.emission_rect_extents = o.emit_box
	if o.get("align", false):
		p.particle_flag_align_y = true
	if o.get("spin", 0.0) > 0.0:
		p.angular_velocity_min = -o.spin
		p.angular_velocity_max = o.spin
		p.angle_min = 0.0
		p.angle_max = 360.0
	if o.get("add", false):
		p.material = mat_add
	p.z_index = o.get("z", 0)
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


static func _ring(parent: Node, pos: Vector2, col: Color, radius: float, life: float, flat := 1.0) -> void:
	var r = Ring.new()
	r.position = pos
	r.col = col
	r.radius = radius
	r.life = life
	r.flat = flat
	parent.add_child(r)


## kind: jab, cross, upper, kick, slam, charge, blade, metal, wood, energy, thrown, block, ko, break
## pos: ponto do acerto; feet: chão sob o alvo (poeira); dir: lado do golpe (1/-1); col: cor do golpe
static func burst(parent: Node, kind: String, pos: Vector2, feet: Vector2, dir: int, col: Color, k: float = 1.0) -> void:
	_textures()
	var fwd := Vector2(dir, 0)
	var hot := Color(1, 0.97, 0.75)
	var spark := {"tex": "streak", "align": true, "add": true, "c0": hot, "c1": col, "life": 0.22}
	match kind:
		"jab":
			_emit(parent, pos, spark.merged({"amount": 9 * k, "dir": fwd + Vector2(0, -0.2), "spread": 50, "v0": 180, "v1": 340, "damp": 500, "s0": 0.5, "s1": 0.8}))
			_emit(parent, pos, {"tex": "dot", "add": true, "amount": 4, "spread": 180, "v0": 20, "v1": 60, "life": 0.15, "s0": 0.8, "s1": 1.3, "c0": hot, "c1": col})
		"cross":
			_emit(parent, pos, spark.merged({"amount": 14 * k, "dir": fwd, "spread": 45, "v0": 220, "v1": 420, "damp": 600, "s0": 0.6, "s1": 1.0}))
			_ring(parent, pos, col, 26.0 * k, 0.16)
		"upper":
			_emit(parent, pos, spark.merged({"amount": 16 * k, "dir": Vector2(dir * 0.35, -1), "spread": 28, "v0": 260, "v1": 500, "gravity": 700, "life": 0.32, "s0": 0.6, "s1": 1.1}))
			_ring(parent, pos, col, 30.0 * k, 0.18)
		"kick":
			_emit(parent, pos, spark.merged({"amount": 12 * k, "dir": fwd + Vector2(0, -0.1), "spread": 60, "v0": 200, "v1": 380, "damp": 500}))
			_emit(parent, pos, {"tex": "dot", "amount": 8, "spread": 180, "v0": 30, "v1": 90, "damp": 80, "life": 0.45, "s0": 1.4, "s1": 2.2, "c0": DUST, "c1": DUST})
		"slam":
			_emit(parent, pos, spark.merged({"amount": 22 * k, "dir": Vector2(0, -1), "spread": 180, "v0": 300, "v1": 560, "gravity": 500, "damp": 300, "life": 0.3, "s0": 0.7, "s1": 1.3}))
			_ring(parent, pos, col, 44.0 * k, 0.22)
			_ground(parent, feet, k * 1.4)
			_emit(parent, feet + Vector2(0, -4), {"tex": "chunk", "amount": 8 * k, "dir": Vector2(0, -1), "spread": 60, "v0": 220, "v1": 420, "gravity": 1300, "life": 0.6, "spin": 720, "s0": 0.7, "s1": 1.2, "c0": Color(0.55, 0.45, 0.35), "c1": Color(0.45, 0.38, 0.3)})
		"charge":
			_emit(parent, pos, spark.merged({"amount": 18 * k, "dir": fwd, "spread": 18, "v0": 420, "v1": 720, "damp": 900, "life": 0.25, "s0": 0.7, "s1": 1.3}))
			_ground(parent, feet, k)
		"blade":
			# corte: riscos longos e finos na diagonal + faíscas de metal caindo
			_emit(parent, pos, spark.merged({"amount": 8 * k, "dir": Vector2(dir, -0.9), "spread": 10, "v0": 380, "v1": 560, "damp": 1400, "life": 0.18, "s0": 1.2, "s1": 1.8, "c0": Color(1, 1, 1), "c1": Color(0.6, 0.9, 1)}))
			_metal(parent, pos, dir, 0.6 * k)
			_ring(parent, pos, Color(0.7, 0.95, 1), 22.0 * k, 0.12, 0.35)
		"metal":
			_metal(parent, pos, dir, k)
			_ring(parent, pos, Color(1, 0.75, 0.35), 30.0 * k, 0.16)
		"wood":
			_emit(parent, pos, {"tex": "chunk", "amount": 12 * k, "dir": fwd + Vector2(0, -0.6), "spread": 55, "v0": 160, "v1": 360, "gravity": 1100, "life": 0.6, "spin": 900, "s0": 0.6, "s1": 1.2, "c0": Color(0.75, 0.55, 0.3), "c1": Color(0.55, 0.38, 0.2)})
			_emit(parent, pos, {"tex": "dot", "amount": 6, "spread": 180, "v0": 20, "v1": 70, "damp": 60, "life": 0.4, "s0": 1.2, "s1": 2.0, "c0": DUST, "c1": DUST})
		"energy":
			_emit(parent, pos, {"tex": "dot", "add": true, "amount": 26 * k, "spread": 180, "v0": 90, "v1": 320, "damp": 380, "life": 0.5, "s0": 0.8, "s1": 1.6, "c0": WHITE, "c1": col})
			_emit(parent, pos, spark.merged({"amount": 10 * k, "spread": 180, "v0": 300, "v1": 520, "damp": 700, "c0": WHITE, "c1": col}))
			_ring(parent, pos, col, 50.0 * k, 0.28)
		"thrown":
			_emit(parent, pos, spark.merged({"amount": 10 * k, "dir": fwd, "spread": 70, "v0": 180, "v1": 340, "damp": 400}))
			_emit(parent, pos, {"tex": "chunk", "amount": 6 * k, "dir": Vector2(-dir, -1), "spread": 50, "v0": 150, "v1": 300, "gravity": 1100, "life": 0.55, "spin": 600, "c0": Color(0.7, 0.7, 0.72), "c1": Color(0.5, 0.5, 0.55)})
		"block":
			# defesa: estilhaços azuis voltando para quem bateu
			_emit(parent, pos, spark.merged({"amount": 10, "dir": Vector2(-dir, -0.3), "spread": 55, "v0": 160, "v1": 320, "damp": 500, "c0": WHITE, "c1": Color(0.4, 0.8, 1)}))
			_ring(parent, pos, Color(0.5, 0.85, 1), 24.0, 0.14, 0.45)
		"ko":
			_emit(parent, pos, spark.merged({"amount": 30 * k, "spread": 180, "v0": 280, "v1": 620, "gravity": 400, "damp": 200, "life": 0.45, "s0": 0.8, "s1": 1.5}))
			_emit(parent, pos, {"tex": "dot", "add": true, "amount": 16 * k, "spread": 180, "v0": 60, "v1": 200, "damp": 150, "life": 0.6, "s0": 1.0, "s1": 2.0, "c0": WHITE, "c1": col})
			_ring(parent, pos, col, 70.0 * k, 0.32)
			_ground(parent, feet, k * 1.6)
		"break":
			_emit(parent, pos, {"tex": "chunk", "amount": 14 * k, "dir": Vector2(0, -1), "spread": 120, "v0": 160, "v1": 360, "gravity": 1200, "life": 0.7, "spin": 900, "s0": 0.8, "s1": 1.4, "c0": col, "c1": col.darkened(0.3)})
			_metal(parent, pos, dir, 0.5)
		_:
			_emit(parent, pos, spark.merged({"amount": 10 * k, "dir": fwd, "spread": 60, "v0": 180, "v1": 340, "damp": 500}))


## Faíscas de metal: laranja, caem com a gravidade.
static func _metal(parent: Node, pos: Vector2, dir: int, k: float) -> void:
	_emit(parent, pos, {"tex": "streak", "align": true, "add": true, "amount": 18 * k, "dir": Vector2(dir, -0.7), "spread": 70,
		"v0": 200, "v1": 460, "gravity": 950, "life": 0.5, "s0": 0.35, "s1": 0.7, "c0": Color(1, 0.95, 0.7), "c1": Color(1, 0.5, 0.1)})


## Poeira no chão: nuvem baixa que se espalha para os lados.
static func _ground(parent: Node, feet: Vector2, k: float) -> void:
	_emit(parent, feet, {"tex": "dot", "amount": 14 * k, "dir": Vector2(1, 0), "spread": 180, "v0": 60, "v1": 200, "damp": 220, "gravity": -30,
		"life": 0.6, "s0": 1.6, "s1": 2.8, "c0": DUST, "c1": DUST, "emit_box": Vector2(18, 3), "z": -1})
	_ring(parent, feet, Color(DUST.r, DUST.g, DUST.b, 0.6), 40.0 * k, 0.3, 0.3)


# ---------- Ferimentos: o que sai do corpo de quem apanha (material em materials.gd) ----------
const Splat = preload("res://scripts/splat.gd")
const MAT_COLORS := {
	"flesh": [Color(0.78, 0.03, 0.05), Color(0.45, 0.0, 0.02)],
	"mutant": [Color(0.55, 0.95, 0.15), Color(0.25, 0.5, 0.05)],
	"machine": [Color(0.16, 0.13, 0.1), Color(0.06, 0.05, 0.04)],
	"shadow": [Color(0.75, 0.45, 1.0), Color(0.25, 0.08, 0.4)],
	"time": [Color(1.0, 0.85, 0.4), Color(0.75, 0.55, 0.15)],
	"light": [Color(0.7, 1.0, 1.0), Color(0.3, 0.7, 1.0)],
}


## pos: ponto do contato (sincronizado com a animação); feet: chão sob o alvo; dir: lado do golpe;
## k: força (dano/12, KO maior); blood: sangue ligado; decals: camada das manchas no chão.
static func wound(parent: Node, decals: Node, mat: String, pos: Vector2, feet: Vector2, dir: int, k: float, blood: bool) -> void:
	_textures()
	if mat in ["flesh", "mutant", "cyborg"] and not blood:
		# sem sangue: só um sopro de poeira clara no ponto do golpe
		_emit(parent, pos, {"tex": "dot", "amount": 6 * k, "dir": Vector2(dir, -0.3), "spread": 70, "v0": 40, "v1": 140, "damp": 160,
			"life": 0.35, "s0": 1.0, "s1": 1.8, "c0": Color(1, 1, 1, 0.7), "c1": Color(0.85, 0.85, 0.9, 0.5)})
		return
	var fwd := Vector2(dir, -0.45)
	match mat:
		"flesh", "mutant":
			_drops(parent, decals, pos, feet, dir, k, MAT_COLORS[mat])
		"cyborg":
			_drops(parent, decals, pos, feet, dir, k * 0.6, MAT_COLORS["flesh"])
			_drops(parent, decals, pos, feet, dir, k * 0.5, MAT_COLORS["machine"])
			_metal(parent, pos, dir, 0.5 * k)
		"machine":
			_drops(parent, decals, pos, feet, dir, k * 0.8, MAT_COLORS["machine"])
			_metal(parent, pos, dir, k)
			# parafusos e lascas de chapa
			_emit(parent, pos, {"tex": "chunk", "amount": 3 + 3 * k, "dir": fwd, "spread": 60, "v0": 160, "v1": 340, "gravity": 1300,
				"life": 0.7, "spin": 1100, "s0": 0.5, "s1": 0.9, "c0": Color(0.75, 0.77, 0.8), "c1": Color(0.45, 0.47, 0.5)})
		"shadow":
			# fumaça roxa que sobe e se desfaz (sem manchas: não é feito de nada)
			var c: Array = MAT_COLORS.shadow
			_emit(parent, pos, {"tex": "dot", "amount": 8 + 6 * k, "dir": Vector2(dir * 0.4, -1), "spread": 60, "v0": 40, "v1": 150, "gravity": -160,
				"damp": 60, "life": 0.8, "s0": 1.2, "s1": 2.6, "c0": Color(c[0].r, c[0].g, c[0].b, 0.75), "c1": Color(c[1].r, c[1].g, c[1].b, 0.4)})
			_emit(parent, pos, {"tex": "streak", "align": true, "add": true, "amount": 4 + 3 * k, "dir": Vector2(dir, -0.2), "spread": 50,
				"v0": 160, "v1": 320, "damp": 500, "life": 0.25, "c0": Color(1, 0.9, 1), "c1": c[0]})
		"time":
			# areia dourada escorrendo e estilhaços do tempo
			var c: Array = MAT_COLORS.time
			_emit(parent, pos, {"tex": "dot", "add": true, "amount": 14 + 10 * k, "dir": fwd, "spread": 70, "v0": 80, "v1": 260, "gravity": 650,
				"life": 0.8, "s0": 0.25, "s1": 0.5, "c0": Color(1, 0.95, 0.7), "c1": c[0]})
			_emit(parent, pos, {"tex": "chunk", "add": true, "amount": 3 + 2 * k, "dir": fwd, "spread": 80, "v0": 140, "v1": 300, "gravity": 400,
				"life": 0.6, "spin": 800, "s0": 0.6, "s1": 1.1, "c0": Color(0.8, 1, 1), "c1": c[0]})
			_splats(decals, feet, dir, 1 + int(k), c[1], 2.5, 4.5, 4.0)
		"light":
			# falha digital: quadradinhos de luz que se espalham e somem
			var c: Array = MAT_COLORS.light
			_emit(parent, pos, {"tex": "chunk", "add": true, "amount": 10 + 6 * k, "spread": 180, "v0": 60, "v1": 240, "damp": 260,
				"life": 0.4, "s0": 0.8, "s1": 1.6, "c0": Color(1, 1, 1), "c1": c[1]})
			_ring(parent, pos, c[0], 26.0 * k, 0.16, 0.6)


## Gotas que voam para o lado do golpe e caem; manchas no chão onde elas pousam.
static func _drops(parent: Node, decals: Node, pos: Vector2, feet: Vector2, dir: int, k: float, c: Array) -> void:
	_emit(parent, pos, {"tex": "dot", "amount": 5 + 7 * k, "dir": Vector2(dir, -0.55), "spread": 38, "v0": 120, "v1": 330, "gravity": 1150,
		"life": 0.55, "s0": 0.3, "s1": 0.65, "c0": c[0], "c1": c[1]})
	_emit(parent, pos, {"tex": "dot", "amount": 3 + 2 * k, "spread": 180, "v0": 15, "v1": 55, "damp": 80, "life": 0.22,
		"s0": 0.9, "s1": 1.4, "c0": Color(c[0].r, c[0].g, c[0].b, 0.55), "c1": Color(c[1].r, c[1].g, c[1].b, 0.0)})
	_splats(decals, feet, dir, 1 + int(k * 1.5), c[1], 3.0, 6.5 + 2.0 * k, 9.0)


static func _splats(decals: Node, feet: Vector2, dir: int, n: int, col: Color, r0: float, r1: float, life: float) -> void:
	if decals == null:
		return
	for i in n:
		var s = Splat.new()
		s.col = Color(col.r, col.g, col.b, 0.8)
		s.r = randf_range(r0, r1)
		s.delay = randf_range(0.22, 0.45)      # tempo das gotas chegarem ao chão
		s.life = life
		s.position = feet + Vector2(dir * randf_range(8.0, 64.0), randf_range(-5.0, 5.0))
		decals.add_child(s)
	while decals.get_child_count() > 90:      # limite de manchas na tela
		var old := decals.get_child(0)
		decals.remove_child(old)
		old.queue_free()
