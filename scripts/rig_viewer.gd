extends Node2D
## Visualizador dos rigs 2D: os 14 lutadores lado a lado.
## Setas: troca a animação. Espaço: pausa. Abra scenes/rig_viewer.tscn e aperte F6.

const Characters = preload("res://scripts/characters.gd")
const Weapons = preload("res://scripts/weapons.gd")
const ANIMS := ["idle", "walk", "jab", "cross", "upper", "kick", "jumpkick", "jump", "special",
	"swing", "throw", "slam", "charge", "dive", "hurt", "down"]

var rigs: Array = []
var anim_i := 0
var t := 0.0
var paused := false
var auto := true
var font: Font


func _ready() -> void:
	font = ThemeDB.fallback_font
	var chars := Characters.list()
	for i in chars.size():
		var slug := _slug(chars[i].name)
		var scene: PackedScene = load("res://rigs/%s.tscn" % slug)
		var rig: Node2D = scene.instantiate()
		var col := i % 7
		var row := i / 7
		rig.position = Vector2(80 + col * 130, 230 + row * 230)
		rig.scale = Vector2.ONE * 1.5 * float(chars[i].size)
		add_child(rig)
		rigs.append([rig, chars[i].name])
	var ws := Weapons.for_stage(2)
	rigs[8][0].get_node("Parts/WeaponSlot").set_weapon(Weapons.equip(ws[0]), false)


static func _slug(n: String) -> String:
	var s := n.to_lower()
	for pair in [["á", "a"], ["é", "e"], ["í", "i"], ["ó", "o"], ["ú", "u"], ["ã", "a"], ["õ", "o"], ["ç", "c"], ["â", "a"], ["ê", "e"], ["ô", "o"]]:
		s = s.replace(pair[0], pair[1])
	return s


func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_SPACE):
		pass
	if not paused:
		t += delta
	if auto and t > 2.5:
		t = 0.0
		anim_i = (anim_i + 1) % ANIMS.size()
	var an: String = ANIMS[anim_i]
	for r in rigs:
		var ap: AnimationPlayer = r[0].get_node("AnimationPlayer")
		var anim := ap.get_animation(an)
		var pos := fmod(t, anim.length) if anim.loop_mode != Animation.LOOP_NONE else clampf(fmod(t, 1.2) / 1.0, 0.0, anim.length)
		ap.play(an)
		ap.seek(pos, true)
		ap.pause()
	queue_redraw()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed:
		match e.keycode:
			KEY_RIGHT:
				anim_i = (anim_i + 1) % ANIMS.size(); t = 0.0; auto = false
			KEY_LEFT:
				anim_i = posmod(anim_i - 1, ANIMS.size()); t = 0.0; auto = false
			KEY_SPACE:
				paused = not paused


func _draw() -> void:
	draw_rect(Rect2(0, 0, 960, 540), Color(0.08, 0.06, 0.14))
	draw_string(font, Vector2(0, 40), "RIGS 2D — animação: %s" % ANIMS[anim_i].to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 960, 26, Color(1, 0.85, 0.3))
	draw_string(font, Vector2(0, 66), "Skeleton2D + Bone2D + Polygon2D (skinning) + AnimationPlayer, gerados do Blender", HORIZONTAL_ALIGNMENT_CENTER, 960, 14, Color(0.7, 0.8, 1))
	for r in rigs:
		var p: Vector2 = r[0].position
		draw_line(p + Vector2(-50, 0), p + Vector2(50, 0), Color(1, 1, 1, 0.15), 2.0)
		draw_string(font, p + Vector2(-60, 24), r[1], HORIZONTAL_ALIGNMENT_CENTER, 120, 14, Color(1, 1, 1))
	draw_string(font, Vector2(0, 525), "◄ ► troca a animação  •  Espaço pausa", HORIZONTAL_ALIGNMENT_CENTER, 960, 13, Color(0.8, 0.8, 0.9))
