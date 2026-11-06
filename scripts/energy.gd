extends Node2D
## Projéteis dos golpes especiais: "ki" (bola de energia) e "wave" (onda pelo chão).

var game
var owner_player
var kind := "ki"
var dir := 1
var speed := 520.0
var dmg := 18
var color := Color(0.4, 0.85, 1)
var height := 50.0
var life := 1.2
var t := 0.0
var hit_list: Array = []
var hostile := false  # disparado por um inimigo: acerta os jogadores
const FighterBase = preload("res://scripts/fighter.gd")
const KI_R := 18.0      # raio da bola desenhada (hitbox vertical: centro ± raio)
const WAVE_H := 34.0    # altura das pedras da onda (acerta só quem está abaixo disso)


## Faixa de altura que o projétil ocupa, igual ao desenho: [baixo, cima] acima do chão.
func band() -> Vector2:
	if kind == "ki":
		return Vector2(height - KI_R, height + KI_R)
	return Vector2(0.0, WAVE_H)


func _physics_process(delta: float) -> void:
	if game != null and game.net_client:
		t += delta
		queue_redraw()
		return
	if game == null or game.is_frozen():
		return
	t += delta
	life -= delta
	position.x += dir * speed * delta
	if dir > 0 and position.x + (KI_R if kind == "ki" else 9.0) >= game.wall_x():
		# a barreira do fim da fase segura o projétil
		game.spawn_spark(Vector2(game.wall_x(), position.y - (height if kind == "ki" else 12.0)), color, 1.2)
		queue_free()
		return
	if life <= 0.0 or position.x < game.cam_left() - 40.0 or position.x > game.cam_right() + 40.0:
		queue_free()
		return
	var targets: Array = game.active_players() if hostile else game.hit_targets_for(owner_player)
	for e in targets:
		if e in hit_list or not e.can_be_hit():
			continue
		var reach := 34.0 if kind == "ki" else 30.0
		var b := band()
		if absf(e.position.x - position.x) < reach and absf(e.position.y - position.y) < 26.0 \
				and FighterBase.band_hits(e, b.x, b.y):
			hit_list.append(e)
			var p: float = owner_player.power if is_instance_valid(owner_player) else 1.0
			e.take_hit(int(dmg * p), dir, true)
			if is_instance_valid(owner_player) and not e.get("blocked_last"):
				game.on_hit(owner_player, e, {"dmg": dmg, "heavy": true, "knock": true, "energy": true})
			if kind == "ki":
				game.spawn_spark(position + Vector2(0, -height), color, 1.6)
				queue_free()
				return
	queue_redraw()


func _draw() -> void:
	if kind == "ki":
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, 16.0, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO)
		var c := Vector2(0, -height)
		for k in 4:
			draw_circle(c - Vector2(dir * k * 12.0, 0), 14.0 - k * 3.0, Color(color.r, color.g, color.b, 0.25 - k * 0.05))
		var pulse := 2.0 * sin(t * 30.0)
		draw_circle(c, 18.0 + pulse, Color(color.r, color.g, color.b, 0.45))
		draw_circle(c, 11.0 + pulse * 0.5, color)
		draw_circle(c, 6.0, Color(1, 1, 1))
	else:
		# pedras saltando do chão
		for k in 4:
			var x := -dir * k * 16.0
			var hgt := 34.0 * (1.0 - k * 0.22) * (0.8 + 0.2 * sin(t * 40.0 + k))
			draw_colored_polygon(PackedVector2Array([Vector2(x - 9, 0), Vector2(x + 9, 0), Vector2(x + 2, -hgt), Vector2(x - 3, -hgt * 0.8)]), color.darkened(0.15 * k))
		draw_circle(Vector2(-dir * 24.0, -6), 12.0, Color(0.75, 0.65, 0.5, 0.4))
	if FighterBase.show_hitboxes:
		var b := band()
		var reach := 34.0 if kind == "ki" else 30.0
		var r := Rect2(-reach, -b.y, reach * 2.0, b.y - b.x)
		draw_rect(r, Color(1, 0.15, 0.1, 0.25), true)
		draw_rect(r, Color(1, 0.15, 0.1, 0.9), false, 1.0)
