extends Node2D
## Encaixe da arma no rig 2D: recebe o transform do osso "weapon" (RemoteTransform2D)
## e desenha a arma que o lutador estiver segurando.

const Weapons = preload("res://scripts/weapons.gd")

var weapon: Dictionary = {}
var white := false
var glow := false  # punho brilhando: inimigo que acabou de acertar uma finalização no jogador


func set_weapon(w: Dictionary, flash: bool) -> void:
	if w != weapon or flash != white:
		weapon = w
		white = flash
		queue_redraw()


func set_glow(on: bool) -> void:
	if on or glow:
		glow = on
		queue_redraw()


func _draw() -> void:
	if not weapon.is_empty():
		Weapons.draw(self, weapon, Vector2.ZERO, 0.0, white)
	if glow:
		var pulse := 0.35 + 0.3 * sin(Time.get_ticks_msec() / 1000.0 * 40.0)
		draw_circle(Vector2.ZERO, 8.0, Color(1, 0.9, 0.2, pulse))
