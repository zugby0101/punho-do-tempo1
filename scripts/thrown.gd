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
		if absf(e.position.x - position.x) < 34.0 and absf(e.position.y - position.y) < 24.0:
			var p: float = owner_player.power if is_instance_valid(owner_player) else 1.0
			var atk := {"dmg": 16, "heavy": true, "knock": true}
			e.take_hit(int(16 * p), dir, true)
			if is_instance_valid(owner_player):
				game.on_hit(owner_player, e, atk)
			_land(true)
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
