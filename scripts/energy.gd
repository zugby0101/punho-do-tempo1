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
	if life <= 0.0 or position.x < game.cam_left() - 40.0 or position.x > game.cam_right() + 40.0:
		queue_free()
		return
	var targets: Array = game.active_players() if hostile else game.hit_targets_for(owner_player)
	for e in targets:
		if e in hit_list or not e.can_be_hit():
			continue
		var reach := 34.0 if kind == "ki" else 30.0
		if absf(e.position.x - position.x) < reach and absf(e.position.y - position.y) < 26.0:
			hit_list.append(e)
			var p: float = owner_player.power if is_instance_valid(owner_player) else 1.0
			e.take_hit(int(dmg * p), dir, true)
			if is_instance_valid(owner_player):
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
