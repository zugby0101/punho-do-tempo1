extends Node2D
## Rastro de movimento dos golpes especiais.
##  - fitas de luz que seguem as pontas dos membros (ou da arma) pelos últimos instantes;
##  - imagens residuais: cópias do rig na pose de instantes atrás, como silhuetas translúcidas.
## Fica atrás do lutador (show_behind_parent) e trabalha em coordenadas do mundo (top_level).

const RIBBON_TIME := 0.16      # quanto tempo de movimento cada fita mostra
const GHOST_EVERY := 0.05     # intervalo entre imagens residuais
const GHOST_LIFE := 0.24
const MAX_GHOSTS := 4

const GHOST_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	COLOR = vec4(mix(COLOR.rgb, tint.rgb, 0.8), COLOR.a);
}
"""

static var shader: Shader = null

var f  # lutador dono do rastro
var ribbons: Array = []        # [{line: Line2D, pts: [[t, Vector2]]}]
var ghosts: Array = []         # [{node, life}]
var ghost_scene: PackedScene = null
var ghost_mat: ShaderMaterial = null
var clock := 0.0
var ghost_timer := 0.0
var was_on := false
var color := Color(1, 1, 1)


func _ready() -> void:
	top_level = true
	show_behind_parent = true
	global_position = Vector2.ZERO
	for i in 3:
		var l := Line2D.new()
		l.joint_mode = Line2D.LINE_JOINT_ROUND
		l.begin_cap_mode = Line2D.LINE_CAP_ROUND
		l.end_cap_mode = Line2D.LINE_CAP_ROUND
		l.antialiased = true
		var wc := Curve.new()
		wc.add_point(Vector2(0, 0.05))
		wc.add_point(Vector2(1, 1))
		l.width_curve = wc
		var add := CanvasItemMaterial.new()
		add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		l.material = add
		add_child(l)
		ribbons.append({"line": l, "pts": []})


func _process(delta: float) -> void:
	if f == null or not is_instance_valid(f):
		queue_free()
		return
	clock += delta
	global_position = Vector2.ZERO
	var col: Color = f.current_trail()
	var on: bool = col.a > 0.0 and f.visible and f.game != null and f.game.fx_enabled
	if on:
		color = col
		if not was_on:
			for r in ribbons:
				r.pts.clear()
			ghost_timer = 0.0
		_sample_ribbons()
		_sample_ghost(delta)
	was_on = on
	_update_ribbons()
	_update_ghosts(delta)


# ---------------- fitas ----------------
func _sample_ribbons() -> void:
	var tips: Array = f.trail_tips()
	for i in ribbons.size():
		var r: Dictionary = ribbons[i]
		if i < tips.size():
			r.pts.append([clock, tips[i]])
		else:
			r.pts.clear()


func _update_ribbons() -> void:
	var w: float = 11.0 * (f.body_scale if f != null else 1.0)
	for r in ribbons:
		while not r.pts.is_empty() and clock - r.pts[0][0] > RIBBON_TIME:
			r.pts.pop_front()
		var l: Line2D = r.line
		if r.pts.size() < 2:
			l.visible = false
			continue
		l.visible = true
		var pv := PackedVector2Array()
		for p in r.pts:
			pv.append(p[1])
		l.points = pv
		l.width = w
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
		g.colors = PackedColorArray([Color(color.r, color.g, color.b, 0.0), Color(color.r, color.g, color.b, 0.5), color.lightened(0.5) * Color(1, 1, 1, 0.75)])
		l.gradient = g


# ---------------- imagens residuais ----------------
func _sample_ghost(delta: float) -> void:
	ghost_timer -= delta
	if ghost_timer > 0.0:
		return
	ghost_timer = GHOST_EVERY
	if f.rig == null or not f.rig.visible or f.rig_scene_path == "" or f.rig_pose.is_empty():
		return
	var g := _free_ghost()
	if g.is_empty():
		return
	var node: Node2D = g.node
	node.global_transform = f.rig.global_transform
	node.visible = true
	var ap: AnimationPlayer = node.get_node("AnimationPlayer")
	if ap.has_animation(f.rig_pose[0]):
		ap.play(f.rig_pose[0])
		ap.pause()
		ap.seek(f.rig_pose[1], true)
	ghost_mat.set_shader_parameter("tint", color)
	g.life = GHOST_LIFE


func reset_ghosts() -> void:
	for g in ghosts:
		g.node.queue_free()
	ghosts.clear()
	ghost_scene = null


func _free_ghost() -> Dictionary:
	for g in ghosts:
		if g.life <= 0.0:
			return g
	if ghosts.size() >= MAX_GHOSTS:
		return {}
	if ghost_scene == null:
		ghost_scene = load(f.rig_scene_path)
		if shader == null:
			shader = Shader.new()
			shader.code = GHOST_SHADER
		ghost_mat = ShaderMaterial.new()
		ghost_mat.shader = shader
	var node: Node2D = ghost_scene.instantiate()
	var tree := node.get_node_or_null("AnimationTree")
	if tree != null:
		tree.queue_free()
	_set_material(node)
	add_child(node)
	move_child(node, 0)  # fantasmas atrás das fitas
	var g := {"node": node, "life": 0.0}
	ghosts.append(g)
	return g


func _set_material(n: Node) -> void:
	if n is CanvasItem:
		n.material = ghost_mat
	for c in n.get_children():
		_set_material(c)


func _update_ghosts(delta: float) -> void:
	for g in ghosts:
		if g.life <= 0.0:
			continue
		g.life -= delta
		var node: Node2D = g.node
		if g.life <= 0.0:
			node.visible = false
		else:
			var k: float = g.life / GHOST_LIFE
			node.modulate = Color(1, 1, 1, 0.5 * k * k)
