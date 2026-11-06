extends Node2D
## Arma arremessada pelo jogador: atravessa a tela e derruba o primeiro inimigo.

const Weapons = preload("res://scripts/weapons.gd")

var game
var owner_player
var weapon: Dictionary
var dir := 1
var height := 46.0
var traveled := 0.0
var t := 0.0
const SPEED := 620.0
const RANGE := 560.0
const FighterBase = preload("res://scripts/fighter.gd")


func band_half() -> float:
	return float(weapon.get("len", 36.0)) * 0.5


## Faixa de altura que a arma girando ocupa (centro ± meio comprimento), acima do chão.
func band() -> Vector2:
	var half := float(weapon.get("len", 36.0)) * 0.5
	return Vector2(height - half, height + half)


func _physics_process(delta: float) -> void:
	if game != null and game.net_client:
		t += delta
		queue_redraw()
		return
	if game == null or game.is_frozen():
		return
	t += delta
	var step := SPEED * delta
	position.x += dir * step
	traveled += step
	var targets: Array = game.hit_targets_for(owner_player)
	for e in targets:
		if not e.can_be_hit():
			continue
		var b := band()
		if absf(e.position.x - position.x) < 34.0 and absf(e.position.y - position.y) < 24.0 \
				and FighterBase.band_hits(e, b.x, b.y):
			var p: float = owner_player.power if is_instance_valid(owner_player) else 1.0
			var atk := {"dmg": 16, "heavy": true, "knock": true, "thrown": true}
			e.take_hit(int(16 * p), dir, true)
			if is_instance_valid(owner_player) and e.is_in_group("enemies"):
				Ach.track(owner_player, "throws")
			if is_instance_valid(owner_player):
				game.on_hit(owner_player, e, atk)
			_land(true)
			return
	if dir > 0 and position.x + band_half() >= game.wall_x():
		# bate na barreira do fim da fase e cai ali
		position.x = game.wall_x() - band_half()
		game.spawn_spark(position + Vector2(band_half() * dir, -height), Color(0.9, 0.9, 1.0), 0.6)
		_land(false)
		return
	if traveled > RANGE or position.x < game.cam_left() + 10.0 or position.x > game.cam_right() - 10.0:
		_land(false)
		return
	queue_redraw()


## Ao acertar ou ao fim do alcance, a arma cai no chão (se ainda tiver uso).
func _land(hit: bool) -> void:
	weapon.uses = int(weapon.uses) - (3 if hit else 1)
	if weapon.uses > 0:
		game.spawn_weapon_item(weapon, position, -dir if hit else dir, height)
	else:
		game.spawn_spark(position + Vector2(0, -height), Color(0.9, 0.9, 1.0), 0.8)
		game.sfx.play("break")
	queue_free()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO)
	var L: float = weapon.len
	var ang := t * 22.0 * dir
	var c := Vector2(0, -height)
	Weapons.draw(self, weapon, c - Vector2(cos(ang), sin(ang)) * L * 0.5, ang)
	if FighterBase.show_hitboxes:
		var b := band()
		var r := Rect2(-34.0, -b.y, 68.0, b.y - b.x)
		draw_rect(r, Color(1, 0.15, 0.1, 0.25), true)
		draw_rect(r, Color(1, 0.15, 0.1, 0.9), false, 1.0)
