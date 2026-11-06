extends Node2D
## Visualização de depuração das hitboxes sincronizadas com a animação (F3 durante o jogo).
##  - verde: hurtbox do corpo (onde o lutador pode ser atingido);
##  - vermelho: hitbox do golpe neste quadro (faixa de alcance na altura da ponta que acerta);
##  - círculo amarelo: a ponta (punho, pé ou arma) tirada da animação.
## Fica por cima do rig (último filho do lutador).

var f  # lutador


func _process(_delta: float) -> void:
	visible = f.hitbox_debug_on()
	if visible:
		queue_redraw()


func _draw() -> void:
	draw_rect(f.hurtbox(), Color(0.2, 1, 0.3, 0.8), false, 1.0)
	if f.attack.is_empty():
		return
	var hb: Dictionary = f.hitbox_now()
	if hb.is_empty() or hb.has("off_window"):
		return
	var dir: float = f.facing
	var x0: float = float(hb.x0) * dir
	var x1: float = float(hb.x1) * dir
	var r := Rect2(minf(x0, x1), -float(hb.h1), absf(x1 - x0), float(hb.h1) - float(hb.h0))
	draw_rect(r, Color(1, 0.15, 0.1, 0.25), true)
	draw_rect(r, Color(1, 0.15, 0.1, 0.9), false, 1.0)
	var tip: Vector2 = hb.tip
	var p := Vector2(tip.x * dir, tip.y - f.height)
	draw_arc(p, float(hb.r), 0.0, TAU, 20, Color(1, 0.9, 0.2), 1.5)
	draw_string(ThemeDB.fallback_font, r.position + Vector2(0, -2), "%s %.2f" % [hb.anim, hb.u],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(1, 0.9, 0.2))
