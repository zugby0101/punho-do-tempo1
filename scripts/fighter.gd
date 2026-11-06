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
var voice_id := ""  # voz em audio/voices (ver tools/audio/voices.py)
var net_rig_u := 0.0
# Rig 2D (Skeleton2D gerado do Blender). Quando existe e está ativo, substitui o desenho procedural.
var rig: Node2D = null
var rig_ap: AnimationPlayer = null
var rig_scene_path := ""
var rig_pose: Array = []   # [animação, tempo] da pose atual (para as imagens residuais do rastro)
# Rastro de movimento dos especiais (trail.gd)
const TrailScript = preload("res://scripts/trail.gd")
var trail = null
var net_trail := Color(0, 0, 0, 0)
# AnimationTree do rig (máquina de estados + BlendSpaces); sem ele, cai no seek direto do AnimationPlayer
static var use_anim_tree := true
var rig_tree: AnimationTree = null
var rig_pb: AnimationNodeStateMachinePlayback = null
var tree_states: PackedStringArray = []
var strike_points: Dictionary = {}
var tree_blend := {"locomotion": 0.0, "air": 0.0, "damage": 0.0, "floor": 0.0}
var tree_usec := 0
const TREE_STATE_OF := {
	"idle": "locomotion", "walk": "locomotion", "jump": "air", "jumpkick": "air",
	"hurt": "damage", "fall": "damage", "down": "floor", "getup": "floor",
}
const TREE_BLEND_TARGET := {"walk": 1.0, "jumpkick": 1.0, "fall": 1.0, "getup": 1.0}
var power := 1.0
# Hitboxes sincronizadas com a animação (metadata/hitboxes do rig, gerada por tools/rig/hitboxes.py):
# a janela de contato e a posição da ponta que acerta (punho, pé ou arma) quadro a quadro.
var hitboxes: Dictionary = {}
var hurtboxes: Dictionary = {}   # metadata/hurtboxes: caixa do corpo quadro a quadro (inimigos)
var anim_hurtbox := false        # usa a hurtbox animada em vez da caixa fixa
var hover_px := 0.0              # quanto o rig flutua no idle (ÉON); desce isso para golpear
static var use_anim_hitboxes := true
static var show_hitboxes := false  # F3 mostra hitboxes (vermelho) e hurtboxes (verde)
const HURT_H := 100.0   # altura da hurtbox do corpo (px, escala 1)
const HURT_W := 16.0    # meia largura da hurtbox
const SWEPT := ["upper"]   # golpes cuja hitbox cobre o caminho da ponta nos últimos SWEEP_U da animação
const SWEEP_U := 0.04
const DIVE_ROT := PI * 0.45  # o corpo deitado no mergulho (tools/rig/hitboxes.py -> BODY_ROT)
const HitboxView = preload("res://scripts/hitbox_view.gd")
var hitbox_view = null


func set_state(s: String) -> void:
	state = s
	state_time = 0.0


func can_be_hit() -> bool:
	if state == "dodge" and state_time >= DODGE_IFRAMES.x and state_time < DODGE_IFRAMES.y:
		return false  # esquivando: o corpo sai do caminho do golpe
	return invuln <= 0.0 and hp > 0 and not (state in ["knockdown", "down", "getup", "dead"])


# ---------- Defesa: bloqueio e esquiva (animações "block" e "dodge" dos 79 rigs) ----------
const BLOCK_RAISE := 0.08   # sobe a guarda (u 0 -> 0,18 da animação)
const BLOCK_DROP := 0.12    # baixa a guarda (u 0,75 -> 1)
const DODGE_TIME := 0.42    # passo para trás inteiro (u 0 -> 1)
const DODGE_IFRAMES := Vector2(0.04, 0.3)  # invencível enquanto está no ar (u ~0,1 .. 0,7)
const DODGE_SPEED := 330.0
var block_release := -1.0   # >= 0: baixando a guarda (tempo desde que soltou)
var block_auto := -1.0      # > 0: solta a guarda sozinho depois desse tempo (inimigos)
var blocked_last := false   # o último golpe recebido foi bloqueado (quem bateu não conta o acerto)


func start_block(hold := -1.0) -> void:
	set_state("block")
	vel = Vector2.ZERO
	attack = {}
	block_release = -1.0
	block_auto = hold


func release_block() -> void:
	if block_release < 0.0:
		block_release = 0.0


## Passo para trás (o rig anima a esquiva; a física leva o corpo). dir = para onde vai.
func start_dodge(dir: int) -> void:
	set_state("dodge")
	attack = {}
	block_release = -1.0
	vel = Vector2(dir * DODGE_SPEED, 0.0)
	if game != null:
		game.sfx.play("jump", 0.1, game.sfx.body_pitch(body_scale) * 1.2)


## Bloqueia um golpe que chega pela frente com a guarda erguida.
func blocks(dir: int) -> bool:
	return state == "block" and block_release < 0.0 and state_time >= BLOCK_RAISE * 0.5 and dir == -facing


## Reação a um golpe bloqueado: recua um pouco, faísca na guarda (na altura das mãos da animação).
func _on_blocked(dir: int) -> void:
	blocked_last = true
	vel = Vector2(dir * 110.0, 0.0)
	if game == null:
		return
	var hand := release_point("block", Vector2(18.0, 64.0))  # antebraços na frente do rosto
	var at := position + Vector2(facing * hand.x, -hand.y)
	game.sfx.play("block", 0.1)
	game.spawn_spark(at, Color(0.4, 0.8, 1.0), 0.8)
	game.spawn_fx("block", at, position, dir, Color(0.4, 0.8, 1.0))


## Bloqueio e esquiva em andamento. Devolve true se cuidou do quadro.
func _update_defense(delta: float) -> bool:
	match state:
		"block":
			vel = vel.move_toward(Vector2.ZERO, 900.0 * delta)
			if block_auto > 0.0 and state_time >= block_auto:
				release_block()
			if block_release >= 0.0:
				block_release += delta
				if block_release >= BLOCK_DROP:
					block_release = -1.0
					set_state("idle")
			return true
		"dodge":
			vel.x = move_toward(vel.x, 0.0, DODGE_SPEED * 1.8 * delta)
			vel.y = 0.0
			if state_time >= DODGE_TIME:
				set_state("idle")
			return true
	return false


## Ponto da animação de bloqueio: sobe rápido, segura (respirando devagar) e baixa ao soltar.
func block_u() -> float:
	if block_release >= 0.0:
		return 0.75 + 0.25 * clampf(block_release / BLOCK_DROP, 0.0, 1.0)
	if state_time < BLOCK_RAISE:
		return 0.18 * state_time / BLOCK_RAISE
	return clampf(0.18 + (state_time - BLOCK_RAISE) * 0.6, 0.18, 0.7)


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
					game.shake(5.0, Vector2(0, 0.5), self)
					game.bump(2.0 * body_scale * body_scale)  # corpo grande caindo pesa mais
					if is_in_group("players"):
						game.rumble(self, 0.4, 0.5, 0.15)
					game.sfx.play("thud")
				else:
					vz = 0.0
					vel = Vector2.ZERO
					set_state("down")
			else:
				vz = 0.0
				_on_land()

	position += vel * delta
	_collide_crates()
	_clamp_position()
	if state in ["attack", "jump", "special"]:
		_sweep_items()
	else:
		_sweep_u = -1.0
	queue_redraw()


## Caminho da ponta do golpe neste quadro (do u do quadro anterior até o atual): armas no chão
## que ela tocar são chutadas — o pé que sobe do chão no chute, os punhos do slam, a arma no golpe armado.
var _sweep_u := -1.0


func _sweep_items() -> void:
	if not use_anim_hitboxes or attack.is_empty():
		_sweep_u = -1.0
		return
	var ra := rig_anim()
	var an: String = ra[0]
	var u: float = ra[1]
	if not hitboxes.has(an) or u < 0.0:
		_sweep_u = -1.0
		return
	var u0 := _sweep_u if _sweep_u >= 0.0 and _sweep_u <= u else u
	_sweep_u = u
	var d: Dictionary = hitboxes[an]
	var s := body_scale
	var armed: bool = not weapon.is_empty() and d.has("wpn") and state != "special"
	var pts: Array = []
	for k in 4:
		var uu := lerpf(u0, u, k / 3.0)
		var tip := _hb_point(d.pts, 3, uu).rotated(body_rot())
		if armed:
			var w := _hb_point(d.wpn, 4, uu)
			var ang := _hb_angle(d.wpn, uu)
			tip = w + Vector2(cos(ang), sin(ang)) * float(weapon.get("len", 40.0))
		pts.append(Vector2(tip.x * s * facing, tip.y * s - height + strike_drop(an, uu)))
	game.kick_weapons(self, pts, (14.0 if armed else float(d.r)) * s)


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
	position.x = game.clamp_x(position.x, body_half_w())  # o corpo encosta na barreira, não entra nela


## Caixas são sólidas: quem anda encosta nelas (sai pelo lado em que entrou menos). Por cima da tampa
## (pulo, voando derrubado) passa livre.
func _collide_crates() -> void:
	var hw := body_half_w()
	for cr in get_tree().get_nodes_in_group("breakables"):
		if not cr.has_method("solid_rect") or cr.hp <= 0 or height >= cr.H:
			continue
		var r: Rect2 = cr.solid_rect()
		var dx: float = position.x - cr.position.x
		var dy: float = position.y - cr.position.y
		var px := (r.size.x * 0.5 + hw) - absf(dx)    # quanto entrou de lado
		var py := (r.size.y * 0.5) - absf(dy)         # quanto entrou em profundidade
		if px <= 0.0 or py <= 0.0:
			continue
		if px < py:
			position.x = cr.position.x + signf(dx if dx != 0.0 else -float(facing)) * (r.size.x * 0.5 + hw)
		else:
			position.y = cr.position.y + signf(dy if dy != 0.0 else 1.0) * r.size.y * 0.5


## Meia largura do corpo para colidir com o cenário (a hurtbox, sem o membro esticado de um golpe).
func body_half_w() -> float:
	return HURT_W * body_scale


# ---------- Armas ----------
func equip_weapon(w: Dictionary) -> void:
	weapon = Weapons.equip(w)
	_on_weapon_changed()


func drop_weapon(dir: int) -> void:
	var w := weapon
	weapon = {}
	# voa na direção do golpe (para longe de quem bateu) e não cai na cabeça de quem soltou
	game.spawn_weapon_item(w, position, dir, maxf(height, 20.0), [self])
	_on_weapon_changed()


func _break_weapon() -> void:
	game.spawn_spark(position + Vector2(facing * 40.0, -60.0 * body_scale), Color(0.9, 0.9, 1.0), 0.9)
	game.spawn_fx("break", position + Vector2(facing * 40.0, -60.0 * body_scale - height), position, facing, weapon.get("color", Color(0.7, 0.7, 0.72)))
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
	if game != null and dmg > 0:
		if hp <= 0:
			game.sfx.voice(self, "ko", 1.0, 0.0)
		elif state == "knockdown":
			game.sfx.voice(self, "fall", 0.85, 0.2)
		else:
			game.sfx.voice(self, "hurt", 0.55, 0.45)


func start_attack(a: Dictionary) -> void:
	attack = a
	lunged = false
	whooshed = false
	hit_list.clear()
	set_state("attack")


## Golpe cortando o ar: começa quando a ponta (punho, pé, arma) entra no trecho rápido que termina no
## impacto, medido na animação de cada um dos 79 rigs (metadata/hitboxes "sw"/"wsw": [u, caminho px]).
var whooshed := false


func _swing_data() -> Array:
	var d: Dictionary = hitboxes.get(attack.get("pose", ""), {})
	if not weapon.is_empty() and d.has("wsw"):
		return Array(d.wsw)  # metadata guarda PackedFloat32Array
	return Array(d.get("sw", PackedFloat32Array()))


func _swing_time() -> float:
	var sw := _swing_data()
	var st := float(attack.startup)
	if sw.is_empty():
		return st  # sem dados: no início da janela de acerto, como antes
	return st * clampf(float(sw[0]) / 0.30, 0.0, 1.0)  # u 0..0,30 da animação = preparação do jogo


func _play_swing() -> void:
	var sw := _swing_data()
	var arc: float = float(sw[1]) if sw.size() > 1 else 40.0
	var slug := rig_scene_path.get_file().get_basename()
	for s in game.sfx.swing_sounds(attack, weapon, Materials.of(self), body_scale, slug, arc):
		game.sfx.play(s[0], 0.06, s[1])


## Processa um golpe em andamento. Retorna true quando o golpe terminou.
func _process_attack(delta: float, targets: Array) -> bool:
	var a := attack
	var t := state_time
	var act_start: float = a.startup
	var act_end: float = a.startup + a.active
	if not whooshed and t >= _swing_time():
		whooshed = true
		_play_swing()
	if t >= act_start and not lunged:
		lunged = true
		vel.x = facing * float(a.get("lunge", 0.0))
		var talk := 0.55 if is_in_group("players") else 0.3
		game.sfx.voice(self, "heavy" if attack.get("heavy", false) else "atk", talk * (1.3 if attack.get("heavy", false) else 1.0))
		_on_release()
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
	var hb := hitbox_now()
	if hb.has("off_window"):
		return false  # a ponta do golpe ainda não chegou (ou já saiu) do ponto de impacto
	for tg in targets:
		if not is_instance_valid(tg) or tg == self or tg in hit_list or not tg.can_be_hit():
			continue
		var dx: float = (tg.position.x - position.x) * facing
		if radial:
			dx = absf(dx)
		var dy: float = absf(tg.position.y - position.y)
		var dz: float = absf(tg.height - height)
		if hb.is_empty():
			if not (dx > -15.0 and dx < float(attack.reach) * body_scale and dy < depth and dz < 60.0):
				continue
		elif not (dy < depth and _hitbox_overlaps(hb, tg)):
			continue
		hit_list.append(tg)
		var dir := facing
		if radial:
			dir = 1 if tg.position.x >= position.x else -1
		var at := _contact_point(hb, tg)  # antes do take_hit: o alvo ainda está na pose em que foi atingido
		tg.take_hit(int(round(float(attack.dmg) * power)), dir, bool(attack.knock))
		if tg.get("blocked_last"):
			continue  # golpe bloqueado
		game.on_hit(self, tg, attack.merged({"hit_at": at}) if at != Vector2.INF else attack)
		hit_any = true
		if attack.get("weapon", false) and not weapon.is_empty() and is_in_group("players"):
			weapon.uses = int(weapon.uses) - 1
			if weapon.uses <= 0:
				_break_weapon()
	return hit_any


## Hitbox do golpe neste quadro, tirada da animação que está tocando.
## Vazio = sem dados de animação (usa a caixa antiga por alcance).
## {"off_window": true} = fora da janela de contato da animação.
## Senão: "x0".."x1" (relativo ao lutador, já virado com facing), "h0".."h1" (altura acima do chão).
func hitbox_now() -> Dictionary:
	if not use_anim_hitboxes or hitboxes.is_empty() or attack.is_empty():
		return {}
	if not state in ["attack", "jump", "special"] or float(attack.get("reach", 0.0)) <= 0.0:
		return {}
	var ra := rig_anim()
	return hitbox_at(attack, ra[0], ra[1])


## Hitbox do golpe `atk` no ponto `u` da animação `an` (o mesmo cálculo de hitbox_now, para qualquer quadro:
## a IA usa para saber se um golpe alcançaria o alvo antes de soltá-lo).
func hitbox_at(atk: Dictionary, an: String, u: float) -> Dictionary:
	if not hitboxes.has(an) or u < 0.0:
		return {}
	var d: Dictionary = hitboxes[an]
	# golpe armado: acerta a ponta da arma (o especial é sempre do corpo, mesmo segurando uma arma)
	var armed: bool = not weapon.is_empty() and d.has("wpn") and state != "special"
	var on: float = d.won if armed else d.on
	var off: float = d.woff if armed else d.off
	if u < on - 0.001 or u > off + 0.001:
		return {"off_window": true}
	var s := body_scale
	var tip := _hb_point(d.pts, 3, u).rotated(body_rot())  # no mergulho o corpo voa deitado
	var r: float = float(d.r)
	var peak: float = maxf(float(d.peak), 1.0)
	if armed:
		var w := _hb_point(d.wpn, 4, u)
		var ang := _hb_angle(d.wpn, u)
		var L := float(weapon.get("len", 40.0))
		tip = Vector2(w.x, w.y) + Vector2(cos(ang), sin(ang)) * L
		var w_pk := _hb_point(d.wpn, 4, on)
		peak = maxf(w_pk.x + cos(_hb_angle(d.wpn, on)) * L, 1.0)
		r = 14.0
	# alcance: o "reach" do golpe (equilíbrio do jogo) acompanhando o quanto a ponta está esticada agora
	var ext := clampf(tip.x / peak, 0.2, 1.15)
	var far := float(atk.reach) * ext * s
	var base_h := height - strike_drop(an, u)  # quem flutua desce para golpear
	var tip_h := base_h - tip.y * s
	var lo_h := tip_h
	var hi_h := tip_h
	var r_s := r * s
	if an in SWEPT:
		# o punho sobe tão rápido que no quadro de impacto já passou do queixo: vale o caminho até ali
		var prev := _hb_point(d.pts, 3, maxf(u - SWEEP_U, 0.0))
		lo_h = minf(lo_h, base_h - prev.y * s)
		hi_h = maxf(hi_h, base_h - prev.y * s)
	if atk.has("dash") and hurtboxes.has(an):
		# investida (chefes): o corpo inteiro avança — acerta com a silhueta da frente, não só com o punho
		var bb := _body_box(hurtboxes[an], u)
		lo_h = minf(lo_h, base_h - float(bb[3]) * s)
		hi_h = maxf(hi_h, base_h - float(bb[1]) * s)
		far = maxf(far, float(bb[2]) * s)
	# golpes giratórios (radial, ou o lutador vira de um lado para o outro): acerta dos dois lados
	var both: bool = atk.get("radial", false) or atk.get("spin", false)
	return {"x0": -far if both else -15.0, "x1": far, "h0": lo_h - r_s, "h1": hi_h + r_s, "base_h": base_h,
		"tip": Vector2(tip.x * s, tip.y * s), "r": r * s, "anim": an, "u": u}


## Cor das faíscas dos golpes de quem bate (assinatura). Inimigos: conforme o material do corpo.
const HIT_COLORS := {"machine": Color(0.45, 0.85, 1.0), "cyborg": Color(0.6, 0.9, 1.0), "mutant": Color(0.6, 1.0, 0.3),
	"shadow": Color(0.8, 0.5, 1.0), "time": Color(1.0, 0.85, 0.35), "light": Color(0.75, 1.0, 1.0)}
const Materials = preload("res://scripts/materials.gd")


func hit_color() -> Color:
	return HIT_COLORS.get(Materials.of(self), Color(1, 0.45, 0.3))


## Onde a ponta do golpe (punho, pé, arma, na pose da animação) encosta no corpo do alvo: a ponta,
## trazida para dentro da hurtbox dele. Vector2.INF sem dados de animação.
func _contact_point(hb: Dictionary, tg) -> Vector2:
	if hb.is_empty() or not hb.has("tip"):
		return Vector2.INF
	var tip: Vector2 = hb.tip
	var p := position + Vector2(tip.x * facing, tip.y - float(hb.base_h))
	var r := hurt_of(tg)
	r.position += tg.position
	r = r.grow(-3.0) if r.size.x > 8.0 and r.size.y > 8.0 else r
	return Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))


## Hurtbox do corpo, relativa aos pés (y para baixo): onde este lutador pode ser atingido.
func hurtbox() -> Rect2:
	var s := body_scale
	return Rect2(-HURT_W * s, -height - HURT_H * s, HURT_W * 2.0 * s, HURT_H * s)


## Área de pegar armas do chão (relativa aos pés, y para baixo): a mão da frente na guarda (primeiro
## quadro do jab do rig), do meio do antebraço até o punho, da altura da mão até o chão.
func grab_box() -> Rect2:
	var s := body_scale
	var hand := Vector2(26.0, -57.0)
	if use_anim_hitboxes and hitboxes.has("jab"):
		hand = _hb_point(hitboxes.jab.pts, 3, 0.0)
	# só a mão: do meio do antebraço até o punho (precisa estar de frente para a arma)
	var back := hand.x * 0.4 * s
	var front := (hand.x + 6.0) * s
	var top := (hand.y - 10.0) * s - height
	var x0 := back if facing > 0 else -front
	var x1 := front if facing > 0 else -back
	return Rect2(x0, top, x1 - x0, -top - height + 4.0)


func hitbox_debug_on() -> bool:
	return show_hitboxes


## Quadro de soltura do golpe (início da janela de acerto = quadro de impacto da animação).
## Arremessos e disparos soltam o projétil aqui, na mão do rig.
func _on_release() -> void:
	pass


## Onde a ponta do golpe `an` está no quadro de contato da animação (impacto):
## x = à frente dos pés (já com a escala, multiplique por facing), y = altura acima do chão.
## Sem dados de animação, usa `fallback` (mesmas unidades, escala 1, altura positiva).
func release_point(an: String, fallback: Vector2) -> Vector2:
	if not use_anim_hitboxes or not hitboxes.has(an):
		return Vector2(fallback.x * body_scale, height + fallback.y * body_scale)
	var d: Dictionary = hitboxes[an]
	var p := _hb_point(d.pts, 3, float(d.on))
	return Vector2(p.x * body_scale, height - strike_drop(an, float(d.on)) - p.y * body_scale)


## Quem flutua (ÉON: pés acima do chão no idle) desce até o chão para golpear: acompanha a preparação
## (u 0 -> 0,30), fica no chão na janela de acerto e volta a flutuar na recuperação. O desenho do rig e as
## caixas usam o mesmo valor, então o soco aparece e acerta na mesma altura.
func strike_drop(an: String, u: float) -> float:
	if hover_px <= 1.0 or u < 0.0 or not hitboxes.has(an):
		return 0.0
	var k := 1.0
	if u < 0.30:
		k = u / 0.30
	elif u > 0.42:
		k = 1.0 - (u - 0.42) / 0.58
	return hover_px * body_scale * clampf(k, 0.0, 1.0)


## Descida deste quadro (só durante golpes).
func strike_drop_now(ra: Array) -> float:
	return strike_drop(ra[0], ra[1]) if state == "attack" else 0.0


## A faixa de altura [h0, h1] (acima do chão) de um projétil cruza a hurtbox do alvo?
static func band_hits(tg, h0: float, h1: float) -> bool:
	if not use_anim_hitboxes:
		return true
	var r := hurt_of(tg)
	return h1 >= -r.end.y and h0 <= -r.position.y


## Rotação do corpo inteiro por cima da animação nos golpes (a mesma do desenho e do rig).
## No referencial "para a frente" (x vezes facing) ela é sempre positiva = tomba para a frente.
func body_rot() -> float:
	if state == "special" and attack.get("pose", "") == "dive":
		return DIVE_ROT
	return 0.0


## Hurtbox de qualquer alvo (lutador, caixa...), relativa à base dele (y para baixo).
## Com hurtbox animada (inimigos), é a caixa em volta do corpo no quadro da animação que está na tela:
## encolhe na dor, cresce quando o braço ou o pé estica, sobe quando o ÉON flutua.
func hurt_rect() -> Rect2:
	if not anim_hurtbox or not use_anim_hitboxes or hurtboxes.is_empty():
		return hurtbox()
	var ra := rig_anim()
	var an: String = ra[0]
	if not hurtboxes.has(an):
		an = "idle"
		if not hurtboxes.has(an):
			return hurtbox()
	var hd: Dictionary = hurtboxes[an]
	var u: float = ra[1]
	if u < 0.0 or an != ra[0]:
		u = fmod(anim_t, maxf(float(hd.len), 0.01)) / maxf(float(hd.len), 0.01)  # loop pelo relógio
	var v := _body_box(hd, u)
	var s := body_scale
	var df := draw_facing()
	var x0: float = v[0] * s * df
	var x1: float = v[2] * s * df
	var drop := strike_drop_now(ra)
	var r := Rect2(minf(x0, x1), v[1] * s - height + drop, absf(x1 - x0), (v[3] - v[1]) * s)
	var rot := body_rot() * df
	if rot != 0.0:
		# corpo deitado (mergulho): gira a caixa em volta dos pés, como o desenho
		var base := Vector2(0.0, -height)
		var g := Rect2(base + (r.position - base).rotated(rot), Vector2.ZERO)
		for c in [Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
			g = g.expand(base + (c - base).rotated(rot))
		r = g
	return r


## Caixa do corpo [x0, y0, x1, y1] (px do rig, virado para a frente, y para baixo) no ponto u.
static func _body_box(hd: Dictionary, u: float) -> Array:
	var arr: PackedFloat32Array = hd.box
	var n := arr.size() / 5
	var f := clampf(u, 0.0, 1.0) * float(n - 1)
	var i := mini(int(f), n - 2)
	var k := f - float(i)
	var v: Array = []
	for j in range(1, 5):
		v.append(lerpf(arr[i * 5 + j], arr[(i + 1) * 5 + j], k))
	return v


## A faixa de altura do golpe `atk` (na janela de acerto) cruza o corpo de `tg`? Para golpes que
## percorrem a distância sozinhos (investida dos chefes), em que a IA não precisa estar perto.
func would_reach_height(atk: Dictionary, tg) -> bool:
	var an: String = atk.get("pose", "jab")
	if not use_anim_hitboxes or not hitboxes.has(an):
		return tg.height < 40.0
	var hb := hitbox_at(atk, an, 0.36)
	if hb.is_empty() or hb.has("off_window"):
		return true
	var r := hurt_of(tg)
	return float(hb.h1) >= -r.end.y and float(hb.h0) <= -r.position.y


## O golpe `atk` alcançaria `tg` agora? Confere a hitbox em alguns quadros da janela de contato
## contra a hurtbox do alvo, com o avanço do lunge. Sem dados de animação, usa a distância antiga.
func would_hit(atk: Dictionary, tg) -> bool:
	var dy := absf(tg.position.y - position.y)
	var an: String = atk.get("pose", "jab")
	if not use_anim_hitboxes or not hitboxes.has(an):
		return absf(tg.position.x - position.x) < 70.0 * body_scale and dy < 18.0 and tg.height < 40.0
	if dy >= float(atk.get("depth", 22.0)) * 0.8:
		return false
	var d: Dictionary = hitboxes[an]
	var armed: bool = not weapon.is_empty() and d.has("wpn")
	var on: float = d.won if armed else d.on
	var off: float = minf(d.woff if armed else d.off, 0.42)  # só a janela de acerto do jogo
	var lunge := float(atk.get("lunge", 0.0))
	var slack := lunge * lunge / 1800.0  # quanto o lunge avança até parar (desacelera 900 px/s²)
	for k in 3:
		var hb := hitbox_at(atk, an, lerpf(on, maxf(off, on), k / 2.0))
		if hb.is_empty() or hb.has("off_window"):
			continue
		hb.x1 = float(hb.x1) + slack
		if _hitbox_overlaps(hb, tg):
			return true
	return false


static func hurt_of(tg) -> Rect2:
	if tg.has_method("hurt_rect"):
		return tg.hurt_rect()
	var ts: float = tg.get("body_scale") if tg.get("body_scale") != null else 1.0
	var th: float = tg.get("height") if tg.get("height") != null else 0.0
	return Rect2(-HURT_W * ts, -th - HURT_H * ts, HURT_W * 2.0 * ts, HURT_H * ts)


func _hitbox_overlaps(hb: Dictionary, tg) -> bool:
	var r := hurt_of(tg)
	# extremos da hurtbox no referencial do golpe (x vezes facing)
	var a: float = (tg.position.x - position.x + r.position.x) * facing
	var b: float = (tg.position.x - position.x + r.end.x) * facing
	if maxf(a, b) < float(hb.x0) or minf(a, b) > float(hb.x1):
		return false
	return float(hb.h1) >= -r.end.y and float(hb.h0) <= -r.position.y


## Interpola a trajetória gravada (amostras a cada 1/60 de u: [u, x, y, ...]).
static func _hb_point(arr: PackedFloat32Array, stride: int, u: float) -> Vector2:
	var n := arr.size() / stride
	var f := clampf(u, 0.0, 1.0) * float(n - 1)
	var i := mini(int(f), n - 2)
	var k := f - float(i)
	var a := Vector2(arr[i * stride + 1], arr[i * stride + 2])
	var b := Vector2(arr[(i + 1) * stride + 1], arr[(i + 1) * stride + 2])
	return a.lerp(b, k)


static func _hb_angle(arr: PackedFloat32Array, u: float) -> float:
	var n := arr.size() / 4
	var f := clampf(u, 0.0, 1.0) * float(n - 1)
	var i := mini(int(f), n - 2)
	return lerp_angle(arr[i * 4 + 3], arr[(i + 1) * 4 + 3], f - float(i))


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
		rot = DIVE_ROT
	if use_rig:
		var ra: Array = [net_rig_anim, net_rig_u] if net else rig_anim()
		off.y += strike_drop_now(ra)
		_sync_rig(off, rot * df, Vector2(df * s, s), ra[0], ra[1], net_phase if net else _attack_phase())
		return
	draw_set_transform(off, rot * df, Vector2(df * s, s))
	_draw_body(pose, net_phase if net else _attack_phase())
	draw_set_transform(Vector2.ZERO)
	_classic_footsteps()


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
			var sp_pose: String = attack.get("pose", "special")
			var ph := float(attack.get("phase", 1.0))
			if sp_pose == "jumpkick" and ph >= 1.0:
				return [sp_pose, 1.0]  # voadora dos especiais: perna esticada, como no pulo
			return [sp_pose, _phase_u(ph)]
		"jump":
			if not attack.is_empty():
				var at: float = get("air_t") if get("air_t") != null else state_time
				return ["jumpkick", clampf(at / 0.16, 0.0, 1.0)]
			return ["jump", clampf(0.5 - vz / 1280.0, 0.0, 1.0)]
		"hurt":
			return ["hurt", clampf(state_time / maxf(hurt_time, 0.01), 0.0, 1.0)]
		"block":
			return ["block", block_u()]
		"dodge":
			return ["dodge", clampf(state_time / DODGE_TIME, 0.0, 1.0)]
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


## Peças de acabamento do modelo definitivo: contorno e detalhes do blender_rig.py (ol_, dt_) e detalhes de
## estilo dos lutadores (tools/rig/models.py, est_). No rig simples (V no título) ficam escondidas.
const DETAIL_PREFIX := ["ol_", "dt_", "est_"]


func _apply_model_detail() -> void:
	var want: bool = game.model_detail
	if rig.has_meta("detail") and bool(rig.get_meta("detail")) == want:
		return
	rig.set_meta("detail", want)
	for n in rig.get_node("Parts").get_children():
		for pre in DETAIL_PREFIX:
			if n.name.begins_with(pre):
				n.visible = want
				break


func _sync_rig(off: Vector2, rot: float, scl: Vector2, an: String, u: float, phase: float) -> void:
	rig.visible = true
	_apply_model_detail()
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
	rig_pose = [an, tpos]
	if _drive_tree(an, u):
		_sync_weapon(phase)
		_rig_footsteps()
		return
	if rig_tree != null:
		rig_tree.active = false
	if rig_ap.assigned_animation != an:
		rig_ap.play(an)
		rig_ap.pause()
	rig_ap.seek(tpos, true)
	_sync_weapon(phase)
	_rig_footsteps()


# ---------- Passos: tocam quando o pé DESENHADO volta ao chão ----------
const STEP_LIFT := 3.0    # px acima do chão (no rig) para contar como pé levantado
const STEP_PLANT := 1.0   # px: pé no chão de novo = passo
const STEP_STATES := ["idle", "walk", "attack", "jump", "block", "dodge", "special", "getup"]
var foot_bones := {}       # "foot_f"/"foot_b" -> Bone2D do rig
var _foot_up := {"foot_f": false, "foot_b": false}
var _classic_w := 0.0


## Lê a altura de cada pé no esqueleto já posado (AnimationPlayer ou AnimationTree) e toca o passo no
## quadro em que um pé levantado encosta no chão: caminhada, pisada do haka, toque da Kirra, o pé que
## volta do chute, o pouso do pulo e da esquiva. Quem flutua (ÉON) nunca pisa.
func _rig_footsteps() -> void:
	if game == null or game.net_client or foot_bones.is_empty() or not state in STEP_STATES:
		return
	for fname in foot_bones:
		var b: Node2D = foot_bones[fname]
		var y := rig.to_local(b.global_position).y  # pés na origem do rig; y para baixo
		if y < -STEP_LIFT:
			_foot_up[fname] = true
		elif y > -STEP_PLANT and _foot_up[fname]:
			_foot_up[fname] = false
			if height <= 1.0:
				game.footstep(self, fname == "foot_f")


## Visual clássico: as pernas seguem sin(anim_t * 12) (_draw_body "walk"); cada troca de sinal é um pé no chão.
func _classic_footsteps() -> void:
	if game == null or game.net_client or state != "walk" or height > 1.0:
		_classic_w = 0.0
		return
	var w := sin(anim_t * 12.0)
	if _classic_w != 0.0 and signf(w) != signf(_classic_w):
		game.footstep(self, w > 0.0)
	_classic_w = w


func _sync_weapon(phase: float) -> void:
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
	rig_scene_path = path
	rig = load(path).instantiate()
	if trail != null:
		trail.reset_ghosts()  # troca de personagem: fantasmas do rig novo
	rig.visible = false
	add_child(rig)
	if hitbox_view != null:
		move_child(hitbox_view, -1)  # a depuração das hitboxes fica sempre por cima do rig
	rig_ap = rig.get_node("AnimationPlayer")
	rig_tree = rig.get_node_or_null("AnimationTree")
	if rig_tree != null:
		rig_pb = rig_tree.get("parameters/playback")
		tree_states = rig_tree.get_meta("states", PackedStringArray())
		strike_points = rig_tree.get_meta("strike_points", {})
	hitboxes = rig.get_meta("hitboxes", {})
	foot_bones = {}
	for fname in ["foot_f", "foot_b"]:
		var fb := rig.get_node("Skeleton2D").find_child(fname, true, false)
		if fb != null:
			foot_bones[fname] = fb
	hurtboxes = rig.get_meta("hurtboxes", {})
	hover_px = 0.0
	if hurtboxes.has("idle"):
		hover_px = maxf(0.0, -float(hurtboxes.idle.box[4]))  # pés acima do chão no primeiro quadro do idle


## Dirige o AnimationTree: escolhe o estado da máquina, a posição nos BlendSpaces e a fase.
## Locomoção mistura idle/andar suavemente; golpes, pulo, dano e chão seguem a fase 0..1 da jogabilidade.
## As trocas de estado ganham crossfade (definido por transição na cena do rig).
func _drive_tree(an: String, u: float) -> bool:
	if rig_tree == null or not use_anim_tree:
		return false
	var st: String = "strike" if strike_points.has(an) else TREE_STATE_OF.get(an, "")
	if st == "" or not st in tree_states:
		return false
	var now := Time.get_ticks_usec()
	var dt := clampf((now - tree_usec) / 1000000.0, 0.0, 0.1)
	tree_usec = now
	if not rig_tree.active:
		rig_tree.active = true
		rig_pb.start(st, true)
		dt = 0.0
	var base := "parameters/%s/" % st
	if st == "strike":
		rig_tree.set(base + "blend/blend_position", strike_points[an])
	else:
		var target: float = TREE_BLEND_TARGET.get(an, 0.0)
		var rate := 5.0 if st == "locomotion" else 12.0
		tree_blend[st] = move_toward(tree_blend[st], target, dt * rate)
		if rig_pb.get_current_node() != st:
			tree_blend[st] = target  # ao entrar no estado, já começa na pose certa
		rig_tree.set(base + "blend/blend_position", tree_blend[st])
	if st == "locomotion":
		rig_tree.set(base + "speed/scale", 1.0)
	else:
		rig_tree.set(base + "seek/seek_request", clampf(u, 0.0, 1.0))
	var entering := rig_pb.get_current_node() != st or dt == 0.0
	if rig_pb.get_current_node() != st:
		rig_pb.travel(st)
	rig_tree.advance(dt)
	if entering and st != "locomotion":
		# ao entrar no estado a máquina reinicia o nó: reaplica a fase no mesmo quadro
		rig_tree.set(base + "seek/seek_request", clampf(u, 0.0, 1.0))
		rig_tree.advance(0.0)
	return true


func _enter_tree() -> void:
	if trail == null:
		call_deferred("_make_trail")


func _make_trail() -> void:
	if trail != null or not is_inside_tree():
		return
	trail = TrailScript.new()
	trail.f = self
	add_child(trail)
	move_child(trail, 0)  # antes do rig: fica atrás do lutador
	hitbox_view = HitboxView.new()
	hitbox_view.f = self
	add_child(hitbox_view)  # por último: desenha por cima do rig


## Cor do rastro de movimento (alfa 0 = sem rastro). Jogador e inimigo definem quando há rastro.
func trail_color() -> Color:
	return Color(0, 0, 0, 0)


func current_trail() -> Color:
	return net_trail if game != null and game.net_client else trail_color()


## Pontas que deixam fitas de luz (coordenadas do mundo): conforme o golpe, mãos, pés ou a arma.
func trail_tips() -> Array:
	var an: String = rig_pose[0] if not rig_pose.is_empty() else "special"
	var pick: Array
	match an:
		"kick", "jumpkick":
			pick = ["leg_f_lo", "leg_b_lo"]
		"jab", "cross", "upper", "charge", "throw":
			pick = ["arm_f_lo", "arm_b_lo"]
		_:
			pick = ["arm_f_lo", "leg_f_lo"]
	var out: Array = []
	if rig != null and rig.visible:
		var sk := rig.get_node("Skeleton2D")
		for bn in pick:
			var b: Bone2D = sk.find_child(bn, true, false)
			if b != null:
				out.append(b.global_transform * Vector2(b.get_length(), 0))
		if not weapon.is_empty():
			var wb: Bone2D = sk.find_child("weapon", true, false)
			if wb != null:
				out.append(wb.global_transform * Vector2(float(weapon.get("len", 40.0)), 0))
	else:
		# visual clássico: pontas aproximadas
		var df := draw_facing()
		var s := body_scale
		var hand := global_position + Vector2(df * 30.0 * s, -64.0 * s - height)
		var foot := global_position + Vector2(df * 26.0 * s, -12.0 * s - height)
		match an:
			"kick", "jumpkick": out = [foot, foot + Vector2(-df * 14.0 * s, -18.0 * s)]
			"jab", "cross", "upper", "charge", "throw": out = [hand, hand + Vector2(-df * 10.0 * s, 10.0 * s)]
			_: out = [hand, foot]
	return out


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
		"block":  # antebraços na frente do rosto
			hf = Vector2(16, -80)
			hb = Vector2(12, -76)
			lean = -2.0
			hip.y = -33
		"dodge":  # passo para trás: inclinado para trás, pés soltos
			var dk := sin(clampf(state_time / DODGE_TIME, 0.0, 1.0) * PI)
			lean = -8.0 * dk
			bf = Vector2(-11, -6.0 * dk)
			ff = Vector2(5, -8.0 * dk)
			hf = Vector2(14, -72)
			hb = Vector2(8, -70)
		"finisher":  # as duas mãos à frente com o peso do corpo
			if p < 0.0:
				hf = Vector2(-10, -84)
				hb = Vector2(-14, -80)
				lean = -6.0
			else:
				hf = Vector2(18.0 + p * 30.0, -64)
				hb = Vector2(14.0 + p * 28.0, -60)
				lean = 9.0 * p
				bf.x -= 4.0 * p
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
