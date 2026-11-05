extends Node2D

const Weapons = preload("res://scripts/weapons.gd")
## Base de todos os lutadores (jogador e inimigos).
## Usa um sistema pseudo-3D clássico de beat 'em up:
##   position.x = posição horizontal, position.y = profundidade (chão),
##   height     = altura do pulo / voo (desenhada para cima).

const GRAVITY := 1800.0

var game  # referência ao main.gd
var max_hp := 100
var hp := 100
var facing := 1
var height := 0.0
var vz := 0.0
var vel := Vector2.ZERO
var state := "idle"
var state_time := 0.0
var anim_t := 0.0
var invuln := 0.0
var flash := 0.0
var hurt_time := 0.3
var bounced := false
var lunged := false
var attack: Dictionary = {}
var hit_list: Array = []
var move_speed := Vector2(200, 120)
var display_name := "???"

# Visual
var body_scale := 1.0
var skin := Color(0.96, 0.76, 0.6)
var shirt := Color(0.9, 0.2, 0.2)
var pants := Color(0.2, 0.25, 0.6)
var hair := Color(0.15, 0.1, 0.05)
var shoes := Color(0.1, 0.1, 0.1)
var hat := "none"  # ver _draw_hat()
var cape := Color(0, 0, 0, 0)
var feminine := false
var weapon: Dictionary = {}  # arma na mão (vazia = desarmado)
# Online: no convidado, a pose vem pronta do anfitrião
var net_pose := ""
var net_phase := 0.0
var net_df := 1
var net_rig_anim := "idle"
var net_rig_u := 0.0
# Rig 2D (Skeleton2D gerado do Blender). Quando existe e está ativo, substitui o desenho procedural.
var rig: Node2D = null
var rig_ap: AnimationPlayer = null
var power := 1.0


func set_state(s: String) -> void:
	state = s
	state_time = 0.0


func can_be_hit() -> bool:
	return invuln <= 0.0 and hp > 0 and not (state in ["knockdown", "down", "getup", "dead"])


func is_alive() -> bool:
	return hp > 0


func _physics_process(delta: float) -> void:
	if game == null:
		return
	if game.net_client:
		# Convidado: só anima entre um pacote e outro
		anim_t += delta
		state_time += delta
		queue_redraw()
		return
	if game.is_frozen():
		if game.mode in ["title", "select", "ending"]:
			anim_t += delta
			queue_redraw()
		return
	state_time += delta
	anim_t += delta
	invuln = maxf(0.0, invuln - delta)
	flash = maxf(0.0, flash - delta)

	match state:
		"hurt":
			vel.x = move_toward(vel.x, 0.0, 900.0 * delta)
			vel.y = 0.0
			if state_time >= hurt_time:
				set_state("idle")
		"knockdown":
			pass
		"down":
			vel = Vector2.ZERO
			if state_time > 0.8:
				if hp <= 0:
					_die()
				else:
					set_state("getup")
		"getup":
			if state_time > 0.4:
				set_state("idle")
				invuln = 0.7
		"dead":
			vel = Vector2.ZERO
			if state_time > 1.0:
				_on_dead_done()
		_:
			_update(delta)

	# Física vertical (pulo / arremesso)
	if height > 0.0 or vz != 0.0:
		vz -= GRAVITY * delta
		height += vz * delta
		if height <= 0.0:
			height = 0.0
			if state == "knockdown":
				if not bounced:
					bounced = true
					vz = 230.0
					height = 0.1
					vel.x *= 0.5
					game.shake(5.0)
					game.sfx.play("thud")
				else:
					vz = 0.0
					vel = Vector2.ZERO
					set_state("down")
			else:
				vz = 0.0
				_on_land()

	position += vel * delta
	_clamp_position()
	queue_redraw()


# ---------- Virtuais ----------
func _update(_delta: float) -> void:
	pass

func _on_land() -> void:
	pass

func _on_hurt() -> void:
	pass

func _die() -> void:
	set_state("dead")

func _on_dead_done() -> void:
	queue_free()

func _clamp_position() -> void:
	position.y = clampf(position.y, game.DEPTH_MIN, game.DEPTH_MAX)
	position.x = clampf(position.x, 20.0, game.STAGE_LEN - 20.0)


# ---------- Armas ----------
func equip_weapon(w: Dictionary) -> void:
	weapon = Weapons.equip(w)
	_on_weapon_changed()


func drop_weapon(dir: int) -> void:
	var w := weapon
	weapon = {}
	game.spawn_weapon_item(w, position, -dir, maxf(height, 20.0))
	_on_weapon_changed()


func _break_weapon() -> void:
	game.spawn_spark(position + Vector2(facing * 40.0, -60.0 * body_scale), Color(0.9, 0.9, 1.0), 0.9)
	game.sfx.play("break")
	if game.hud != null and is_in_group("players"):
		game.hud.show_message("%s QUEBROU!" % weapon.name, 1.0)
	weapon = {}
	_on_weapon_changed()


func _on_weapon_changed() -> void:
	pass


# ---------- Combate ----------
func take_hit(dmg: int, dir: int, knock: bool, launch: float = 1.0) -> void:
	hp = maxi(0, hp - dmg)
	flash = 0.12
	facing = -dir
	attack = {}
	hit_list.clear()
	if hp <= 0 or knock or height > 0.0:
		set_state("knockdown")
		if not weapon.is_empty():
			drop_weapon(dir)
		bounced = false
		vz = 460.0 * launch
		height = maxf(height, 0.1)
		vel = Vector2(dir * 250.0 * launch, 0.0)
	else:
		set_state("hurt")
		vel = Vector2(dir * 130.0, 0.0)
	_on_hurt()


func start_attack(a: Dictionary) -> void:
	attack = a
	lunged = false
	hit_list.clear()
	set_state("attack")


## Processa um golpe em andamento. Retorna true quando o golpe terminou.
func _process_attack(delta: float, targets: Array) -> bool:
	var a := attack
	var t := state_time
	var act_start: float = a.startup
	var act_end: float = a.startup + a.active
	if t >= act_start and not lunged:
		lunged = true
		vel.x = facing * float(a.get("lunge", 0.0))
		game.sfx.play("whoosh")
	elif a.has("dash") and t >= act_start and t < act_end:
		vel.x = facing * float(a.dash)
	else:
		vel.x = move_toward(vel.x, 0.0, 900.0 * delta)
	vel.y = 0.0
	if t >= act_start and t < act_end:
		_check_hits(targets)
	return t >= act_end + float(a.recovery)


func _check_hits(targets: Array) -> bool:
	var hit_any := false
	var radial: bool = attack.get("radial", false)
	var depth: float = attack.get("depth", 22.0)
	for tg in targets:
		if not is_instance_valid(tg) or tg == self or tg in hit_list or not tg.can_be_hit():
			continue
		var dx: float = (tg.position.x - position.x) * facing
		if radial:
			dx = absf(dx)
		var dy: float = absf(tg.position.y - position.y)
		var dz: float = absf(tg.height - height)
		if dx > -15.0 and dx < float(attack.reach) * body_scale and dy < depth and dz < 60.0:
			hit_list.append(tg)
			var dir := facing
			if radial:
				dir = 1 if tg.position.x >= position.x else -1
			tg.take_hit(int(round(float(attack.dmg) * power)), dir, bool(attack.knock))
			if tg.get("blocked_last"):
				continue  # golpe bloqueado
			if attack.get("weapon", false) and not weapon.is_empty() and is_in_group("players"):
				weapon.uses = int(weapon.uses) - 1
				if weapon.uses <= 0:
					_break_weapon()
			game.on_hit(self, tg, attack)
			hit_any = true
	return hit_any


# ---------- Desenho ----------
func _c(col: Color) -> Color:
	return Color(1, 1, 1) if flash > 0.0 else col


## Fase do golpe: negativo = preparação, 1 = ativo, 1→0 = recuperação
func _attack_phase() -> float:
	if attack.is_empty():
		return 0.0
	var t := state_time
	if state == "jump":
		return 1.0
	if state == "special":
		return float(attack.get("phase", 1.0))
	var st: float = attack.startup
	var ae: float = st + float(attack.active)
	if t < st:
		return -t / maxf(st, 0.001)
	if t < ae:
		return 1.0
	return clampf(1.0 - (t - ae) / maxf(float(attack.recovery), 0.001), 0.0, 1.0)


func _current_pose() -> String:
	match state:
		"attack", "special":
			return attack.get("pose", "jab")
		"jump":
			return attack.get("pose", "jump") if not attack.is_empty() else "jump"
		"hurt", "knockdown":
			return "hurt"
		"down", "dead", "getup":
			return "down"
	return state


func _draw() -> void:
	var s := body_scale
	# Sombra
	var shs := clampf(1.0 - height / 260.0, 0.45, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.32))
	draw_circle(Vector2.ZERO, 24.0 * s * shs, Color(0, 0, 0, 0.38))
	draw_set_transform(Vector2.ZERO)

	var use_rig: bool = rig != null and game != null and game.rigs_enabled()
	if rig != null:
		rig.visible = false
	if invuln > 0.0 and not (state in ["attack", "special"]) and int(invuln * 20.0) % 2 == 0:
		return
	if state == "dead" and int(state_time * 16.0) % 2 == 0:
		return

	var rot := 0.0
	var off := Vector2(0, -height)
	match state:
		"knockdown":
			rot = -clampf(state_time * 4.0, 0.0, 1.0) * PI * 0.5
		"down", "dead":
			rot = -PI * 0.5
			off.y -= 6.0 * s
		"getup":
			rot = -PI * 0.5 * (1.0 - state_time / 0.4)
			off.y -= 6.0 * s * (1.0 - state_time / 0.4)
	var net: bool = game != null and game.net_client
	var pose := net_pose if net else _current_pose()
	var df := net_df if net else draw_facing()
	if state == "special" and pose == "dive":
		rot = PI * 0.45
	if use_rig:
		var ra: Array = [net_rig_anim, net_rig_u] if net else rig_anim()
		_sync_rig(off, rot * df, Vector2(df * s, s), ra[0], ra[1], net_phase if net else _attack_phase())
		return
	draw_set_transform(off, rot * df, Vector2(df * s, s))
	_draw_body(pose, net_phase if net else _attack_phase())
	draw_set_transform(Vector2.ZERO)


func _weapon_angle(pose: String, p: float) -> float:
	match pose:
		"swing":
			if p < 0.0:
				return lerpf(-1.2, -2.5, -p)
			if p >= 1.0:
				return 0.35
			return lerpf(-0.9, 0.35, p)
		"hurt": return -2.1
		"down": return -0.2
		"throw": return -0.4
		"jumpkick", "kick": return -1.6
	return -1.05


## Coloca o rig 2D na mesma pose que o desenho procedural teria.
## Idle/andar tocam pelo relógio do lutador; golpes usam a fase (-1..1 -> 0..1 na animação).
## Qual animação do rig tocar e em que ponto (0..1), a partir do estado real do lutador.
## Golpes: preparação -> 0..0.30, janela de acerto -> 0.30..0.42, recuperação -> 0.42..1
## (o quadro de impacto da animação cai no início exato da janela de acerto).
func rig_anim() -> Array:
	match state:
		"idle", "walk":
			return [state, -1.0]  # loop pelo relógio do lutador
		"attack":
			if attack.is_empty():
				return ["idle", -1.0]
			return [attack.get("pose", "jab"), _attack_u()]
		"special":
			return [attack.get("pose", "special"), _phase_u(float(attack.get("phase", 1.0)))]
		"jump":
			if not attack.is_empty():
				var at: float = get("air_t") if get("air_t") != null else state_time
				return ["jumpkick", clampf(at / 0.16, 0.0, 1.0)]
			return ["jump", clampf(0.5 - vz / 1280.0, 0.0, 1.0)]
		"hurt":
			return ["hurt", clampf(state_time / maxf(hurt_time, 0.01), 0.0, 1.0)]
		"knockdown":
			return ["fall", clampf(state_time / 0.5, 0.0, 1.0)]
		"getup":
			return ["getup", clampf(state_time / 0.4, 0.0, 1.0)]
		"down", "dead":
			return ["down", 0.0]
	return ["idle", -1.0]


func _attack_u() -> float:
	var st: float = attack.startup
	var ac: float = attack.active
	var rc: float = attack.recovery
	var t := state_time
	if t < st:
		return 0.30 * t / maxf(st, 0.001)
	if t < st + ac:
		return 0.30 + 0.12 * (t - st) / maxf(ac, 0.001)
	return 0.42 + 0.58 * clampf((t - st - ac) / maxf(rc, 0.001), 0.0, 1.0)


## Especiais controlam a fase à mão (-1 preparando, 1 golpeando, 1->0 recuperando).
func _phase_u(p: float) -> float:
	if p < 0.0:
		return 0.30 * -p
	if p >= 1.0:
		return 0.36
	return 0.42 + 0.58 * (1.0 - p)


func _sync_rig(off: Vector2, rot: float, scl: Vector2, an: String, u: float, phase: float) -> void:
	rig.visible = true
	rig.position = off
	rig.rotation = rot
	rig.scale = scl
	rig.modulate = Color(5, 5, 5) if flash > 0.0 else Color(1, 1, 1)
	if not rig_ap.has_animation(an):
		an = "idle"
		u = -1.0
	var anim := rig_ap.get_animation(an)
	var tpos := 0.0
	if anim.loop_mode != Animation.LOOP_NONE or u < 0.0:
		tpos = fmod(anim_t, anim.length)
	else:
		tpos = clampf(u, 0.0, 1.0) * anim.length
	if rig_ap.assigned_animation != an:
		rig_ap.play(an)
		rig_ap.pause()
	rig_ap.seek(tpos, true)
	var slot = rig.get_node_or_null("Parts/WeaponSlot")
	if slot != null:
		slot.set_weapon(weapon, flash > 0.0)
		slot.set_glow(is_in_group("enemies") and state == "attack" and phase < 0.0)


func attach_rig(path: String) -> void:
	if rig != null:
		rig.queue_free()
		rig = null
		rig_ap = null
	if not ResourceLoader.exists(path):
		return
	rig = load(path).instantiate()
	rig.visible = false
	add_child(rig)
	rig_ap = rig.get_node("AnimationPlayer")


static func rig_slug(n: String) -> String:
	var s := n.to_lower()
	for pair in [["á", "a"], ["à", "a"], ["â", "a"], ["ã", "a"], ["é", "e"], ["ê", "e"], ["í", "i"],
			["ó", "o"], ["ô", "o"], ["õ", "o"], ["ú", "u"], ["ç", "c"]]:
		s = s.replace(pair[0], pair[1])
	return s


## Direção em que o corpo é desenhado (golpes giratórios alternam).
func draw_facing() -> int:
	if state in ["attack", "special"] and (attack.get("pose", "") == "special" or attack.get("spin", false)):
		return facing if int(state_time * 18.0) % 2 == 0 else -facing
	return facing


func _limb(a: Vector2, b: Vector2, bend: Vector2, col: Color, w: float) -> void:
	var mid := (a + b) * 0.5 + bend
	draw_line(a, mid, col, w)
	draw_line(mid, b, col, w)
	draw_circle(mid, w * 0.5, col)


func _draw_body(pose: String, p: float) -> void:
	var bob := 0.0
	var bf := Vector2(-7, 0)   # pé de trás
	var ff := Vector2(9, 0)    # pé da frente
	var hip := Vector2(0, -36)
	var lean := 0.0
	var hb := Vector2(8, -60)  # mão de trás
	var hf := Vector2(18, -64) # mão da frente
	var head_off := Vector2.ZERO

	match pose:
		"idle":
			bob = sin(anim_t * 4.0) * 1.5
		"walk":
			var w := sin(anim_t * 12.0)
			bf = Vector2(-7.0 + w * 10.0, -maxf(0.0, w) * 4.0)
			ff = Vector2(9.0 - w * 10.0, -maxf(0.0, -w) * 4.0)
			bob = absf(w) * 2.0
		"jab":
			hf = Vector2(18.0 + (p * 30.0 if p > 0.0 else p * 14.0), -66)
			lean = 3.0 * p
		"cross":
			hb = Vector2(8.0 + (p * 40.0 if p > 0.0 else p * 16.0), -64)
			hf = Vector2(12, -60)
			lean = 6.0 * maxf(p, 0.0)
			bf.x -= 4.0
		"upper":
			hf = Vector2(20.0 + maxf(p, 0.0) * 10.0, -64.0 - maxf(p, 0.0) * 38.0)
			if p < 0.0:
				hf = Vector2(14, -48)
			lean = 5.0 * p
		"swing":
			if p < 0.0:
				hf = Vector2(-6, -84)
				hb = Vector2(-2, -70)
				lean = -5.0
			else:
				hf = Vector2(lerpf(0.0, 30.0, p), lerpf(-76.0, -60.0, p))
				hb = Vector2(lerpf(-2.0, 22.0, p), -62)
				lean = 7.0 * p
				bf.x -= 5.0 * p
		"dive":
			hf = Vector2(6, -96)
			hb = Vector2(-2, -94)
			bf = Vector2(-6, 4)
			ff = Vector2(6, 4)
		"throw":
			hf = Vector2(34, -72)
			hb = Vector2(-12, -64)
			lean = 8.0
		"kick":
			var k := maxf(p, 0.0)
			ff = Vector2(9.0 + k * 44.0, -k * 44.0)
			lean = -9.0 * k
			hf = Vector2(10, -66)
			hb = Vector2(-6, -62)
		"jumpkick":
			ff = Vector2(44, -24)
			bf = Vector2(-12, -18)
			hip.y = -40
			lean = -7.0
			hf = Vector2(4, -70)
			hb = Vector2(-14, -66)
		"jump":
			bf = Vector2(-10, -12)
			ff = Vector2(12, -16)
			hf = Vector2(16, -78)
			hb = Vector2(-6, -74)
		"special":
			hf = Vector2(44, -70)
			hb = Vector2(-44, -70)
			bf = Vector2(-14, 0)
			ff = Vector2(14, 0)
		"slam":
			if p < 0.0:
				hf = Vector2(4, -100)
				hb = Vector2(-4, -98)
				lean = -6.0
			else:
				hf = Vector2(40, -40)
				hb = Vector2(34, -38)
				lean = 10.0 * p
		"charge":
			lean = 12.0 * maxf(p, 0.0)
			hf = Vector2(26, -66)
			hb = Vector2(20, -60)
			if p < 0.0:
				lean = -6.0
				var w2 := sin(anim_t * 30.0)
				bf.x += w2 * 3.0
		"hurt":
			lean = -10.0
			head_off = Vector2(-4, 2)
			hf = Vector2(-4, -80)
			hb = Vector2(-16, -72)
			bf.x -= 4.0
		"down":
			hf = Vector2(6, -46)
			hb = Vector2(-4, -44)

	hip.y += bob * 0.5
	var shoulder := Vector2(lean, -68.0 + bob)
	var head := shoulder + Vector2(3, -15) + head_off

	var skin_c := _c(skin)
	var skin_d := _c(skin.darkened(0.2))
	var pants_c := _c(pants)
	var pants_d := _c(pants.darkened(0.3))
	var shirt_c := _c(shirt)
	var shoe_c := _c(shoes)

	# Capa (chefes)
	if cape.a > 0.0:
		var wv := sin(anim_t * 6.0) * 4.0
		draw_colored_polygon(PackedVector2Array([shoulder + Vector2(-8, -2), shoulder + Vector2(6, -2),
			hip + Vector2(-14 + wv, 22), hip + Vector2(-30 + wv, 18)]), _c(cape))
	# Braço de trás
	_limb(shoulder + Vector2(-3, 2), hb, Vector2(-2, 7), skin_d, 6.5)
	draw_circle(hb, 5.0, skin_d)
	# Perna de trás
	_limb(hip + Vector2(-4, 0), bf, Vector2(4, 0), pants_d, 9.0)
	draw_rect(Rect2(bf + Vector2(-4, -4), Vector2(12, 5)), shoe_c.darkened(0.2))
	# Perna da frente
	_limb(hip + Vector2(4, 0), ff, Vector2(5, 0), pants_c, 9.0)
	draw_rect(Rect2(ff + Vector2(-4, -4), Vector2(13, 5)), shoe_c)
	# Tronco
	var sw := 9.0 if feminine else 11.0
	var torso := PackedVector2Array([
		hip + Vector2(-9, 2), hip + Vector2(9, 2),
		shoulder + Vector2(sw, 0), shoulder + Vector2(-sw, 0)])
	draw_colored_polygon(torso, shirt_c)
	draw_line(hip + Vector2(-9, 0), hip + Vector2(9, 0), _c(Color(0.12, 0.1, 0.08)), 3.0)
	# Cabelo comprido (atrás da cabeça)
	var hc := _c(hair)
	match hat:
		"ponytail":
			var sway := sin(anim_t * 8.0) * 3.0
			_limb(head + Vector2(-8, -4), head + Vector2(-16 + sway, 16), Vector2(-4, 0), hc, 6.0)
		"longhair":
			draw_rect(Rect2(head + Vector2(-11, -4), Vector2(12, 26)), hc)
		"braidcrown":
			_limb(head + Vector2(-8, 0), head + Vector2(-10, 22), Vector2(-3, 0), hc, 5.0)
	# Cabeça
	draw_line(shoulder, head, skin_c, 6.0)
	draw_circle(head, 10.0, _c(hair) if hat != "bald" else skin_c)
	draw_circle(head + Vector2(2, 2), 8.5, skin_c)
	draw_rect(Rect2(head + Vector2(4, -2), Vector2(3, 3)), _c(Color(0.05, 0.05, 0.05)))
	_draw_hat(head)
	# Braço da frente (com a arma, se tiver)
	_limb(shoulder + Vector2(3, 2), hf, Vector2(-1, 7), skin_c, 6.5)
	if not weapon.is_empty():
		Weapons.draw(self, weapon, hf, _weapon_angle(pose, p), flash > 0.0)
	draw_circle(hf, 5.5, skin_c)
	# Telegrafa o golpe dos inimigos (brilho na mão)
	if state == "attack" and p < 0.0 and is_in_group("enemies"):
		draw_circle(hf, 8.0, Color(1, 0.9, 0.2, 0.35 + 0.3 * sin(anim_t * 40.0)))


func _dome(center: Vector2, r: float, col: Color, from := PI, to := TAU) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := lerpf(from, to, i / 12.0)
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, col)


func _draw_hat(head: Vector2) -> void:
	var dark := _c(Color(0.05, 0.05, 0.05))
	var hc := _c(hair)
	if feminine and not (hat in ["luchamask", "headwrap"]):
		draw_line(head + Vector2(5, 1), head + Vector2(7, 1), _c(Color(0.05, 0.05, 0.05)), 1.5)  # cílios
	match hat:
		"short":
			_dome(head + Vector2(0, -2), 10.0, hc, PI, TAU)
			draw_rect(Rect2(head + Vector2(2, -10), Vector2(9, 4)), hc)
		"buzz":
			_dome(head + Vector2(0, -1), 10.0, Color(hc.r, hc.g, hc.b, 0.75), PI * 1.05, TAU - 0.1)
		"curly":
			for i in 6:
				var a := PI + i * PI / 5.0
				draw_circle(head + Vector2(cos(a), sin(a)) * 9.0 + Vector2(0, -1), 4.5, hc)
		"ponytail", "longhair":
			_dome(head + Vector2(0, -1), 10.5, hc, PI * 0.9, TAU)
			draw_rect(Rect2(head + Vector2(3, -10), Vector2(8, 4)), hc)
		"braidcrown":
			_dome(head + Vector2(0, -1), 10.0, hc, PI, TAU)
			for i in 5:
				draw_circle(head + Vector2(-9 + i * 4.5, -9 + absf(i - 2) * 1.5), 3.2, hc.lightened(0.15))
			draw_circle(head + Vector2(6, -10), 2.5, _c(Color(0.9, 0.2, 0.3)))
		"bob":
			_dome(head + Vector2(0, -1), 11.5, hc, PI * 0.75, TAU + 0.1)
			draw_rect(Rect2(head + Vector2(-11, -2), Vector2(6, 12)), hc)
			draw_rect(Rect2(head + Vector2(2, -11), Vector2(10, 5)), hc)
		"buns":
			_dome(head + Vector2(0, -1), 10.0, hc, PI, TAU)
			draw_circle(head + Vector2(-8, -10), 5.5, hc)
			draw_circle(head + Vector2(7, -11), 5.5, hc)
		"headwrap":
			var wc := _c(Color(0.95, 0.6, 0.1))
			_dome(head + Vector2(-1, -4), 12.0, wc, PI * 0.95, TAU + 0.05)
			draw_circle(head + Vector2(-2, -14), 7.0, wc)
			draw_line(head + Vector2(-10, -6), head + Vector2(8, -9), _c(Color(0.1, 0.5, 0.3)), 3.0)
		"luchamask":
			var mc := _c(Color(0.95, 0.15, 0.5))
			draw_circle(head + Vector2(1, 1), 10.5, mc)
			draw_circle(head + Vector2(5, -1), 3.5, _c(Color(0.98, 0.98, 0.98)))
			draw_rect(Rect2(head + Vector2(5, -2), Vector2(2, 2)), dark)
			draw_line(head + Vector2(-8, -6), head + Vector2(8, -8), _c(Color(0.95, 0.85, 0.2)), 2.5)
			_limb(head + Vector2(-8, -2), head + Vector2(-14, 18), Vector2(-3, 0), hc, 5.0)
		"band":
			var red := _c(Color(0.95, 0.1, 0.15))
			draw_line(head + Vector2(-9, -4), head + Vector2(9, -5), red, 3.5)
			draw_line(head + Vector2(-9, -4), head + Vector2(-18, 2 + sin(anim_t * 10.0) * 3.0), red, 2.5)
		"mohawk":
			for i in 4:
				draw_line(head + Vector2(-6 + i * 4, -8), head + Vector2(-7 + i * 4, -17), _c(Color(0.2, 0.9, 0.3)), 3.0)
		"cap":
			draw_rect(Rect2(head + Vector2(-10, -11), Vector2(20, 7)), _c(Color(0.2, 0.2, 0.25)))
			draw_rect(Rect2(head + Vector2(6, -6), Vector2(9, 3)), _c(Color(0.2, 0.2, 0.25)))
		"bald":
			draw_rect(Rect2(head + Vector2(-2, 4), Vector2(9, 3)), _c(Color(0.3, 0.2, 0.1)))
		"wild":
			for i in 6:
				var a := PI + i * PI / 5.0
				draw_circle(head + Vector2(cos(a), sin(a)) * 9.0 + Vector2(-2, 0), 5.0, _c(hair))
			draw_circle(head + Vector2(3, 8), 6.0, _c(hair))  # barba
		"horns":
			var bone := _c(Color(0.92, 0.88, 0.75))
			draw_line(head + Vector2(-6, -7), head + Vector2(-12, -20), bone, 4.0)
			draw_line(head + Vector2(5, -8), head + Vector2(9, -21), bone, 4.0)
		"helmet", "helmet2":
			var steel := _c(Color(0.62, 0.64, 0.68) if hat == "helmet" else Color(0.32, 0.36, 0.28))
			_dome(head + Vector2(0, -2), 11.5, steel)
			draw_rect(Rect2(head + Vector2(-12, -3), Vector2(24, 3)), steel.darkened(0.2))
			if hat == "helmet":
				draw_line(head + Vector2(6, -2), head + Vector2(6, 6), steel, 2.5)
		"greathelm":
			var st := _c(Color(0.2, 0.2, 0.24))
			draw_rect(Rect2(head + Vector2(-11, -12), Vector2(22, 22)), st)
			draw_rect(Rect2(head + Vector2(0, -3), Vector2(11, 3)), _c(Color(0.9, 0.2, 0.1)))
			draw_line(head + Vector2(-2, -12), head + Vector2(-8, -24), _c(Color(0.8, 0.1, 0.1)), 4.0)
		"hood":
			var hdc := _c(shirt.darkened(0.2))
			_dome(head + Vector2(-1, 0), 12.0, hdc, PI * 0.75, TAU + 0.1)
			draw_line(head + Vector2(-10, 0), head + Vector2(-12, 12), hdc, 5.0)
		"topknot":
			draw_rect(Rect2(head + Vector2(-9, -9), Vector2(16, 4)), _c(hair))
			draw_circle(head + Vector2(-2, -13), 4.0, _c(hair))
		"ninja":
			draw_circle(head + Vector2(1, 1), 10.5, _c(Color(0.1, 0.1, 0.12)))
			draw_rect(Rect2(head + Vector2(-1, -3), Vector2(10, 4)), _c(skin))
			draw_rect(Rect2(head + Vector2(4, -2), Vector2(3, 2)), dark)
			draw_line(head + Vector2(-9, -4), head + Vector2(-17, 0 + sin(anim_t * 9.0) * 3.0), _c(Color(0.1, 0.1, 0.12)), 3.0)
		"kabuto":
			var kc := _c(Color(0.45, 0.06, 0.08))
			_dome(head + Vector2(0, -2), 12.0, kc)
			draw_rect(Rect2(head + Vector2(-14, -3), Vector2(28, 4)), kc.darkened(0.3))
			var gold := _c(Color(1, 0.8, 0.2))
			draw_line(head + Vector2(0, -10), head + Vector2(-8, -24), gold, 3.0)
			draw_line(head + Vector2(0, -10), head + Vector2(10, -24), gold, 3.0)
		"bandana":
			var bc := _c(shirt.darkened(0.1) if shirt.v < 0.8 else Color(0.8, 0.15, 0.15))
			_dome(head + Vector2(0, -1), 10.5, bc)
			draw_line(head + Vector2(-9, -3), head + Vector2(-15, 4), bc, 3.0)
		"tricorn":
			var tc := _c(Color(0.08, 0.08, 0.1))
			draw_colored_polygon(PackedVector2Array([head + Vector2(-17, -5), head + Vector2(17, -5), head + Vector2(8, -20), head + Vector2(-8, -20)]), tc)
			draw_line(head + Vector2(-17, -5), head + Vector2(17, -5), _c(Color(0.9, 0.75, 0.2)), 2.0)
			draw_circle(head + Vector2(0, -13), 3.0, _c(Color(0.95, 0.95, 0.95)))
		"flatcap":
			var fc := _c(Color(0.35, 0.3, 0.26))
			_dome(head + Vector2(0, -3), 10.5, fc)
			draw_rect(Rect2(head + Vector2(4, -5), Vector2(11, 3)), fc.darkened(0.2))
		"tophat":
			var hc2 := _c(Color(0.06, 0.06, 0.08))
			draw_rect(Rect2(head + Vector2(-8, -30), Vector2(16, 22)), hc2)
			draw_rect(Rect2(head + Vector2(-14, -10), Vector2(28, 4)), hc2)
			draw_rect(Rect2(head + Vector2(-8, -14), Vector2(16, 3)), _c(Color(0.6, 0.1, 0.1)))
			draw_circle(head + Vector2(5, -1), 4.0, _c(Color(0.9, 0.8, 0.3)))  # monóculo
		"brodie":
			var bc2 := _c(Color(0.35, 0.38, 0.28))
			_dome(head + Vector2(0, -4), 9.5, bc2)
			draw_rect(Rect2(head + Vector2(-15, -5), Vector2(30, 3)), bc2)
		"spike":
			var sc := _c(Color(0.15, 0.15, 0.16))
			_dome(head + Vector2(0, -2), 11.0, sc)
			draw_rect(Rect2(head + Vector2(-11, -3), Vector2(24, 3)), sc)
			draw_line(head + Vector2(0, -12), head + Vector2(0, -22), _c(Color(0.75, 0.7, 0.4)), 3.0)
		"officer":
			var oc := _c(Color(0.22, 0.24, 0.25))
			draw_rect(Rect2(head + Vector2(-11, -15), Vector2(24, 8)), oc)
			draw_rect(Rect2(head + Vector2(-9, -8), Vector2(18, 3)), oc.darkened(0.3))
			draw_rect(Rect2(head + Vector2(5, -6), Vector2(11, 3)), dark)
			draw_circle(head + Vector2(2, -11), 2.5, _c(Color(0.9, 0.8, 0.3)))
		"beanie":
			_dome(head + Vector2(0, -2), 11.0, _c(Color(0.15, 0.15, 0.17)))
		"beret":
			draw_colored_polygon(PackedVector2Array([head + Vector2(-12, -6), head + Vector2(10, -8), head + Vector2(4, -15), head + Vector2(-10, -13)]), _c(Color(0.7, 0.1, 0.15)))
		"shades":
			draw_rect(Rect2(head + Vector2(-9, -10), Vector2(18, 5)), _c(hair))
			draw_rect(Rect2(head + Vector2(0, -3), Vector2(10, 4)), dark)
		"ushanka":
			var fur := _c(Color(0.45, 0.35, 0.25))
			draw_rect(Rect2(head + Vector2(-13, -16), Vector2(26, 10)), fur)
			draw_rect(Rect2(head + Vector2(-12, -6), Vector2(6, 12)), fur)
			draw_circle(head + Vector2(0, -11), 2.5, _c(Color(0.85, 0.2, 0.2)))
		"visor", "robot":
			var mc := _c(skin)
			draw_rect(Rect2(head + Vector2(-10, -11), Vector2(21, 21)), mc)
			draw_rect(Rect2(head + Vector2(-10, -11), Vector2(21, 21)), mc.darkened(0.35), false, 2.0)
			var eye := Color(0.2, 1, 1) if hat == "visor" else Color(1, 0.15, 0.15)
			draw_rect(Rect2(head + Vector2(-2, -4), Vector2(13, 5)), _c(eye))
			draw_line(head + Vector2(-4, -11), head + Vector2(-6, -19), mc.darkened(0.3), 2.0)
			draw_circle(head + Vector2(-6, -20), 2.5, _c(eye))
		"halo":
			var glow := Color(0.5, 1, 1, 0.8)
			draw_arc(head + Vector2(0, -16), 10.0, 0, TAU, 20, glow, 3.0)
			draw_rect(Rect2(head + Vector2(-1, -4), Vector2(11, 4)), _c(Color(0.2, 1, 1)))
		"goggles":
			for i in 3:
				draw_line(head + Vector2(-5 + i * 5, -9), head + Vector2(-6 + i * 5, -17), _c(Color(0.9, 0.3, 0.1)), 3.0)
			draw_rect(Rect2(head + Vector2(-10, -7), Vector2(21, 4)), _c(Color(0.3, 0.25, 0.2)))
			draw_circle(head + Vector2(7, -5), 4.0, _c(Color(0.4, 0.9, 0.4)))
		"eon":
			# ampulheta flutuante sobre a cabeça e olhos brilhantes
			var gold := _c(Color(1, 0.82, 0.3))
			var hy := -26.0 + sin(anim_t * 3.0) * 2.0
			draw_colored_polygon(PackedVector2Array([head + Vector2(-9, hy - 10), head + Vector2(9, hy - 10), head + Vector2(0, hy)]), gold)
			draw_colored_polygon(PackedVector2Array([head + Vector2(-9, hy + 10), head + Vector2(9, hy + 10), head + Vector2(0, hy)]), gold)
			draw_arc(head + Vector2(0, hy), 15.0, 0, TAU, 20, Color(1, 0.85, 0.4, 0.5), 2.0)
			draw_rect(Rect2(head + Vector2(2, -3), Vector2(4, 3)), _c(Color(0.4, 1, 1)))
			draw_rect(Rect2(head + Vector2(7, -3), Vector2(3, 3)), _c(Color(0.4, 1, 1)))
			for k in 3:
				var a2 := anim_t * 1.5 + k * TAU / 3.0
				draw_circle(head + Vector2(cos(a2) * 18.0, sin(a2) * 8.0 + hy), 2.0, Color(0.7, 0.9, 1, 0.8))
		"crown":
			var gc := _c(Color(1, 0.8, 0.15))
			draw_colored_polygon(PackedVector2Array([head + Vector2(-10, -8), head + Vector2(10, -8), head + Vector2(11, -20),
				head + Vector2(5, -14), head + Vector2(0, -22), head + Vector2(-5, -14), head + Vector2(-11, -20)]), gc)
			draw_circle(head + Vector2(0, -11), 2.0, _c(Color(0.9, 0.1, 0.3)))
