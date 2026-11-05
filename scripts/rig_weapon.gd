extends Node2D
## Encaixe da arma no rig 2D: recebe o transform do osso "weapon" (RemoteTransform2D)
## e desenha a arma que o lutador estiver segurando.

const Weapons = preload("res://scripts/weapons.gd")

var weapon: Dictionary = {}
var white := false


func set_weapon(w: Dictionary, flash: bool) -> void:
	if w != weapon or flash != white:
		weapon = w
		white = flash
		queue_redraw()


func _draw() -> void:
	if not weapon.is_empty():
		Weapons.draw(self, weapon, Vector2.ZERO, 0.0, white)
