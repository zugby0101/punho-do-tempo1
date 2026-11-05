extends RefCounted
## Armas de cada era: dados, golpes e desenho.
## Cada fase tem 2 armas: "blade" (lâmina: rápida, combo de 3) e "blunt" (contundente: lenta, derruba).

const DURABILITY := {"blade": 12, "blunt": 8}


static func _w(name: String, kind: String, shape: String, color: Color, length: float) -> Dictionary:
	return {"name": name, "kind": kind, "shape": shape, "color": color, "len": length}


## Armas por fase, na mesma ordem das 12 eras.
static func for_stage(idx: int) -> Array:
	var steel := Color(0.82, 0.85, 0.9)
	var wood := Color(0.55, 0.36, 0.18)
	var iron := Color(0.45, 0.45, 0.5)
	var table := [
		[_w("LANÇA DE PEDRA", "blade", "spear", wood, 40), _w("CLAVA", "blunt", "club", Color(0.5, 0.32, 0.15), 34)],
		[_w("ESPADA", "blade", "sword", steel, 40), _w("MAÇA", "blunt", "mace", iron, 32)],
		[_w("KATANA", "blade", "katana", steel, 44), _w("BASTÃO BŌ", "blunt", "staff", wood, 34)],
		[_w("SABRE", "blade", "sword", steel, 38), _w("REMO", "blunt", "oar", wood, 36)],
		[_w("FACA", "blade", "knife", steel, 22), _w("CHAVE INGLESA", "blunt", "wrench", iron, 30)],
		[_w("BAIONETA", "blade", "knife", steel, 26), _w("PÁ DE TRINCHEIRA", "blunt", "shovel", Color(0.4, 0.42, 0.35), 34)],
		[_w("FACA DE COMBATE", "blade", "knife", Color(0.35, 0.37, 0.35), 24), _w("PÉ DE CABRA", "blunt", "pipe", Color(0.7, 0.15, 0.12), 34)],
		[_w("ADAGA", "blade", "knife", steel, 22), _w("CASSETETE", "blunt", "pipe", Color(0.12, 0.12, 0.14), 30)],
		[_w("CANIVETE", "blade", "knife", steel, 20), _w("TACO DE BEISEBOL", "blunt", "bat", Color(0.8, 0.62, 0.38), 38)],
		[_w("LÂMINA DE PLASMA", "blade", "energy", Color(0.3, 1, 1), 42), _w("BASTÃO DE PULSO", "blunt", "energystaff", Color(0.85, 0.9, 1), 34)],
		[_w("MACHETE", "blade", "sword", Color(0.6, 0.55, 0.5), 34), _w("CANO DE FERRO", "blunt", "pipe", Color(0.55, 0.35, 0.25), 36)],
		[_w("FOICE", "blade", "scythe", Color(0.7, 0.6, 0.85), 42), _w("MARRETA DE OSSO", "blunt", "club", Color(0.9, 0.88, 0.78), 34)],
	]
	return table[clampi(idx, 0, table.size() - 1)]


## Cópia "equipável" da arma, com durabilidade.
static func equip(def: Dictionary) -> Dictionary:
	var w := def.duplicate()
	if not w.has("uses"):
		w["uses"] = DURABILITY[def.kind]
	return w


## Combo do jogador armado.
static func player_combo(w: Dictionary) -> Array:
	if w.kind == "blade":
		return [
			{"pose": "swing", "dmg": 9, "reach": 82, "startup": 0.05, "active": 0.08, "recovery": 0.15, "knock": false, "lunge": 60.0, "weapon": true},
			{"pose": "swing", "dmg": 9, "reach": 82, "startup": 0.05, "active": 0.08, "recovery": 0.15, "knock": false, "lunge": 60.0, "weapon": true, "alt": true},
			{"pose": "swing", "dmg": 13, "reach": 88, "startup": 0.07, "active": 0.1, "recovery": 0.25, "knock": true, "lunge": 90.0, "weapon": true, "heavy": true},
		]
	return [
		{"pose": "swing", "dmg": 13, "reach": 88, "startup": 0.11, "active": 0.1, "recovery": 0.26, "knock": false, "lunge": 40.0, "weapon": true, "heavy": true},
		{"pose": "swing", "dmg": 17, "reach": 92, "startup": 0.13, "active": 0.1, "recovery": 0.32, "knock": true, "lunge": 60.0, "weapon": true, "heavy": true},
	]


## Desenha a arma a partir da mão `h`, apontando no ângulo `angle` (0 = para frente).
static func draw(ci: CanvasItem, w: Dictionary, h: Vector2, angle: float, white := false) -> void:
	var d := Vector2(cos(angle), sin(angle))
	var n := Vector2(-d.y, d.x)
	var L: float = w.len
	var col: Color = Color(1, 1, 1) if white else w.color
	var dark := Color(1, 1, 1) if white else Color(0.25, 0.15, 0.08)
	var steel := Color(1, 1, 1) if white else Color(0.82, 0.85, 0.9)
	match w.shape:
		"sword", "katana", "knife":
			ci.draw_line(h - d * 6.0, h + d * 4.0, dark, 4.0)
			if w.shape != "knife":
				ci.draw_line(h + d * 4.0 - n * 5.0, h + d * 4.0 + n * 5.0, Color(0.85, 0.7, 0.2) if not white else col, 3.0)
			var tip := h + d * L
			if w.shape == "katana":
				tip += n * 3.0
			ci.draw_line(h + d * 4.0, tip, col, 3.5 if w.shape != "knife" else 3.0)
			ci.draw_line(h + d * 6.0 - n * 1.0, tip - n * 1.0, Color(1, 1, 1, 0.6), 1.0)
		"energy":
			ci.draw_line(h - d * 6.0, h + d * 4.0, Color(0.3, 0.3, 0.35), 5.0)
			ci.draw_line(h + d * 4.0, h + d * L, Color(col.r, col.g, col.b, 0.35), 9.0)
			ci.draw_line(h + d * 4.0, h + d * L, Color(1, 1, 1), 3.0)
		"club", "bat", "mace":
			ci.draw_line(h - d * 6.0, h + d * L * 0.5, col, 4.0)
			ci.draw_line(h + d * L * 0.5, h + d * L, col, 7.0 if w.shape != "mace" else 5.0)
			ci.draw_circle(h + d * L, 5.5 if w.shape == "club" else 4.0, col)
			if w.shape == "mace":
				for k in 6:
					var a := angle + k * TAU / 6.0
					ci.draw_line(h + d * L, h + d * L + Vector2(cos(a), sin(a)) * 9.0, col, 2.0)
		"staff", "energystaff":
			ci.draw_line(h - d * L * 0.9, h + d * L, col, 4.0)
			if w.shape == "energystaff":
				ci.draw_circle(h + d * L, 6.0, Color(0.3, 1, 1, 0.5))
				ci.draw_circle(h - d * L * 0.9, 6.0, Color(0.3, 1, 1, 0.5))
		"spear":
			ci.draw_line(h - d * 20.0, h + d * L, col, 3.5)
			ci.draw_colored_polygon(PackedVector2Array([h + d * (L + 12.0), h + d * L + n * 5.0, h + d * L - n * 5.0]), Color(0.55, 0.55, 0.6) if not white else col)
		"oar":
			ci.draw_line(h - d * 14.0, h + d * L, col, 4.0)
			ci.draw_colored_polygon(PackedVector2Array([h + d * L - n * 4.0, h + d * L + n * 4.0, h + d * (L + 18.0) + n * 7.0, h + d * (L + 18.0) - n * 7.0]), col)
		"wrench":
			ci.draw_line(h - d * 6.0, h + d * L, col, 5.0)
			ci.draw_line(h + d * L, h + d * (L + 7.0) + n * 5.0, col, 4.0)
			ci.draw_line(h + d * L, h + d * (L + 7.0) - n * 5.0, col, 4.0)
		"shovel":
			ci.draw_line(h - d * 8.0, h + d * L, Color(0.5, 0.35, 0.2) if not white else col, 4.0)
			ci.draw_colored_polygon(PackedVector2Array([h + d * L - n * 7.0, h + d * L + n * 7.0, h + d * (L + 14.0) + n * 5.0, h + d * (L + 18.0), h + d * (L + 14.0) - n * 5.0]), col)
		"pipe":
			ci.draw_line(h - d * 8.0, h + d * L, col, 5.0)
			ci.draw_line(h + d * (L - 3.0) - n * 4.0, h + d * (L - 3.0) + n * 4.0, col.darkened(0.3), 3.0)
		"scythe":
			ci.draw_line(h - d * 18.0, h + d * L, Color(0.3, 0.2, 0.25) if not white else col, 3.5)
			var tip := h + d * L
			ci.draw_colored_polygon(PackedVector2Array([tip, tip - n * 24.0 - d * 6.0, tip - n * 20.0 - d * 14.0, tip - d * 4.0]), col)
		_:
			ci.draw_line(h, h + d * L, col, 4.0)
