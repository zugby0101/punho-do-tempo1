extends Control
## Interface: barras de vida, placar, combo, mensagens e telas
## (título, seleção de personagem, abertura da era, fim de fase, final).

var game
var enemy_ref = null
var enemy_timer := 0.0
var message := ""
var message_timer := 0.0
var t := 0.0
var font: Font

const W := 960.0


func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_enemy(e) -> void:
	enemy_ref = e
	enemy_timer = 2.5


func show_message(text: String, dur: float = 2.0) -> void:
	message = text
	message_timer = dur


func _process(delta: float) -> void:
	t += delta
	enemy_timer -= delta
	message_timer -= delta
	queue_redraw()


func _text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string_outline(font, pos, s, align, width, size, 6, Color(0, 0, 0, 0.9))
	draw_string(font, pos, s, align, width, size, col)


func _center(y: float, s: String, size: int, col: Color) -> void:
	_text(Vector2(0, y), s, size, col, HORIZONTAL_ALIGNMENT_CENTER, W)


func _bar(pos: Vector2, w: float, h: float, ratio: float, col: Color) -> void:
	draw_rect(Rect2(pos - Vector2(3, 3), Vector2(w + 6, h + 6)), Color(0, 0, 0, 0.8))
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0.45, 0.05, 0.08))
	draw_rect(Rect2(pos, Vector2(w * clampf(ratio, 0.0, 1.0), h)), col)
	draw_rect(Rect2(pos, Vector2(w * clampf(ratio, 0.0, 1.0), h * 0.35)), Color(1, 1, 1, 0.25))


func _draw() -> void:
	var pl = game.player
	if game.mode in ["play", "stageclear", "gameover"] and pl != null:
		_draw_game_hud(pl)
	if message_timer > 0.0 and game.mode == "play":
		_center(230, message, 46, Color(1, 0.95, 0.4))
	match game.mode:
		"title": _draw_title()
		"select": _draw_select()
		"intro": _draw_intro()
		"stageclear":
			draw_rect(Rect2(0, 0, W, 540), Color(0, 0, 0, 0.55))
			_center(200, "ERA CONCLUÍDA!", 64, Color(0.4, 1, 0.5))
			_center(250, game.stage.name, 26, Color(1, 1, 1))
			_center(300, "Pontos: %d" % game.score, 28, Color(1, 1, 1))
			var nxt: Dictionary = game.stages[game.stage_idx + 1]
			_center(370, "Próxima viagem: %s (%s)" % [nxt.name, nxt.year], 22, Color(0.6, 0.9, 1))
			if int(t * 2.0) % 2 == 0:
				_center(420, "ENTER para viajar no tempo", 24, Color(1, 0.9, 0.3))
		"gameover":
			draw_rect(Rect2(0, 0, W, 540), Color(0, 0, 0, 0.6))
			_center(240, "FIM DE JOGO", 72, Color(1, 0.2, 0.2))
			_center(300, "Pontos: %d" % game.score, 28, Color(1, 1, 1))
			_center(360, "ENTER para continuar nesta era", 24, Color(1, 0.9, 0.3))
		"ending":
			draw_rect(Rect2(0, 0, 640, 540), Color(0, 0, 0, 0.72))
			draw_rect(Rect2(640, 0, W - 640, 130), Color(0, 0, 0, 0.72))
			var ch: Dictionary = game.characters[game.char_idx]
			_center(80, "A LINHA DO TEMPO FOI SALVA!", 44, Color(1, 0.85, 0.3))
			_center(118, "%s derrotou CRONOS e atravessou as 12 eras." % ch.name, 20, Color(0.7, 0.9, 1))
			_text(Vector2(40, 170), "FINAL DE %s" % ch.name, 26, Color(1, 0.5, 0.7))
			var ending: Array = ch.ending
			var shown := int(game.mode_time / 1.2) + 1  # linhas surgem aos poucos
			for i in mini(shown, ending.size()):
				_text(Vector2(40, 215 + i * 34), ending[i], 18, Color(1, 1, 1))
			_text(Vector2(40, 380), "PONTUAÇÃO FINAL: %d" % game.score, 28, Color(0.4, 1, 0.5))
			if game.mode_time > 2.0 and int(t * 2.0) % 2 == 0:
				_center(500, "ENTER para voltar ao título", 22, Color(1, 0.9, 0.3))


func _draw_game_hud(pl) -> void:
	_text(Vector2(20, 34), pl.display_name, 20, Color(1, 0.9, 0.3))
	_bar(Vector2(130, 18), 220, 18, float(pl.hp) / pl.max_hp, Color(1, 0.85, 0.15))
	_text(Vector2(362, 34), "x%d" % game.lives, 20, Color(1, 1, 1))
	_text(Vector2(20, 62), "PONTOS  %07d" % game.score, 18, Color(1, 1, 1))
	_text(Vector2(0, 528), "FASE %d · %s · %s" % [game.stage_idx + 1, game.stage.name, game.stage.year], 15, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, W)
	if enemy_timer > 0.0 and is_instance_valid(enemy_ref):
		var boss: bool = enemy_ref.is_boss()
		var tier_cols := [Color(1, 0.4, 0.9), Color(0.6, 1, 0.5), Color(1, 0.85, 0.3), Color(1, 0.4, 0.3)]
		var tc: Color = tier_cols[enemy_ref.tier]
		var bw := 320.0 if boss else 260.0
		_text(Vector2(W - bw - 30, 34), enemy_ref.display_name, 18, Color(1, 0.55, 0.55), HORIZONTAL_ALIGNMENT_RIGHT, bw)
		_text(Vector2(W - bw - 30, 74), enemy_ref.tier_label(), 15, tc, HORIZONTAL_ALIGNMENT_RIGHT, bw)
		_bar(Vector2(W - bw - 30, 42), bw, 14, float(enemy_ref.hp) / enemy_ref.max_hp, Color(0.95, 0.3, 0.2) if not boss else Color(0.9, 0.2, 0.9))
	if game.combo_count >= 2 and game.combo_timer > 0.0:
		var sc := 1.0 + clampf(game.combo_timer - 0.9, 0.0, 0.3)
		_text(Vector2(24, 120), "%d GOLPES!" % game.combo_count, int(28 * sc), Color(1, 0.6, 0.2))
	if game.show_go and int(t * 3.0) % 2 == 0:
		_text(Vector2(W - 170, 270), "VAI ►", 44, Color(1, 0.95, 0.3))
	if game.paused:
		draw_rect(Rect2(0, 0, W, 540), Color(0, 0, 0, 0.5))
		_center(280, "PAUSADO", 56, Color(1, 1, 1))


func _draw_title() -> void:
	draw_rect(Rect2(0, 0, W, 540), Color(0.03, 0.0, 0.08, 0.72))
	_center(130, "PUNHO DO TEMPO", 80, Color(1, 0.3, 0.6))
	_center(172, "um beat 'em up através de 12 eras — feito em Godot 4", 19, Color(0.6, 0.9, 1))
	var lines := [
		"Mover: WASD / Setas / Analógico",
		"Soco (combo): J ou Z   |   Cima + Soco: gancho",
		"Pular: K, X ou Espaço   |   Pulo + Soco: voadora",
		"Especial giratório (gasta vida): L ou C   |   Pausa: Esc / P",
	]
	for i in lines.size():
		_center(225 + i * 28, lines[i], 18, Color(1, 1, 1))
	_center(365, "Fase inicial (◄ ►):", 18, Color(0.8, 0.8, 0.9))
	_center(400, "◄  %d. %s  (%s)  ►" % [game.stage_idx + 1, game.stage.name, game.stage.year], 26, Color(0.5, 1, 0.6))
	if int(t * 2.0) % 2 == 0:
		_center(470, "Pressione ENTER", 30, Color(1, 0.9, 0.3))


func _draw_select() -> void:
	draw_rect(Rect2(0, 0, W, 540), Color(0.03, 0.0, 0.08, 0.6))
	_center(48, "ESCOLHA SEU LUTADOR", 40, Color(1, 0.85, 0.3))
	var chars: Array = game.characters
	var cw := 74.0
	var ch := 92.0
	var ox := 24.0
	var oy := 80.0
	for i in chars.size():
		var c: Dictionary = chars[i]
		var col := i / 2
		var row := i % 2
		var r := Rect2(ox + col * (cw + 8), oy + row * (ch + 26), cw, ch)
		var sel: bool = i == game.char_idx
		draw_rect(r, c.shirt.darkened(0.45))
		# mini retrato
		var hp_pos := r.position + Vector2(cw * 0.5, 44)
		draw_rect(Rect2(hp_pos + Vector2(-20, 14), Vector2(40, 34)), c.shirt)
		draw_circle(hp_pos, 17.0, c.hair)
		draw_circle(hp_pos + Vector2(0, 3), 14.0, c.skin)
		draw_rect(Rect2(hp_pos + Vector2(-7, 0), Vector2(4, 4)), Color(0.05, 0.05, 0.05))
		draw_rect(Rect2(hp_pos + Vector2(4, 0), Vector2(4, 4)), Color(0.05, 0.05, 0.05))
		draw_rect(r, Color(1, 0.9, 0.2) if sel else Color(0, 0, 0, 0.8), false, 4.0 if sel else 2.0)
		_text(r.position + Vector2(0, ch + 17), c.name, 13, Color(1, 0.9, 0.3) if sel else Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, cw)
	# regiões
	for k in 7:
		var reg: String = String(chars[k * 2].region).replace("AMÉRICA", "AMÉR.")
		_text(Vector2(ox + k * (cw + 8) - 4, oy - 6), reg, 9, Color(0.6, 0.9, 1), HORIZONTAL_ALIGNMENT_CENTER, cw + 8)
	# painel de informações
	var c: Dictionary = chars[game.char_idx]
	var px := 24.0
	var py := 340.0
	draw_rect(Rect2(px - 8, py - 30, 590, 190), Color(0, 0, 0, 0.55))
	_text(Vector2(px, py), c.name, 34, Color(1, 0.9, 0.3))
	_text(Vector2(px, py + 30), "%s · %s" % [c.country, c.region], 18, Color(0.6, 0.9, 1))
	_text(Vector2(px, py + 54), "Estilo de luta: %s" % c.style, 17, Color(1, 1, 1))
	var stats := [["VIDA", (float(c.hp) - 70.0) / 60.0], ["VELOCIDADE", (float(c.speed) - 0.7) / 0.55], ["FORÇA", (float(c.power) - 0.8) / 0.45]]
	for k in stats.size():
		_text(Vector2(px, py + 88 + k * 26), stats[k][0], 15, Color(1, 1, 1))
		_bar(Vector2(px + 120, py + 75 + k * 26), 200, 12, stats[k][1], Color(0.3, 0.9, 1))
	_text(Vector2(px + 340, py + 140), "◄ ► região   ▲ ▼ troca", 14, Color(0.8, 0.8, 0.9))
	if int(t * 2.0) % 2 == 0:
		_text(Vector2(620, 525), "ENTER para confirmar", 22, Color(1, 0.9, 0.3), HORIZONTAL_ALIGNMENT_CENTER, 330)


func _draw_intro() -> void:
	var st: Dictionary = game.stage
	var k := clampf(game.mode_time * 3.0, 0.0, 1.0)
	draw_rect(Rect2(0, 120, W, 300), Color(0, 0, 0, 0.7 * k))
	_center(180, "FASE %d de %d" % [game.stage_idx + 1, game.stages.size()], 26, Color(0.6, 0.9, 1, k))
	_center(245, st.name, 54, Color(1, 0.85, 0.3, k))
	_center(285, st.year, 26, Color(1, 1, 1, k))
	_center(330, String(st.intro).replace("{p}", game.player.display_name), 18, Color(1, 1, 1, k))
	_center(375, "Sub-chefe: %s   •   Chefe: %s" % [st.subboss.name, st.boss.name], 16, Color(1, 0.55, 0.55, k))
	_center(400, "Inimigos: ★ %s   ★★ %s   ★★★ %s" % [st.thug.name, st.knife.name, st.brute.name], 15, Color(0.8, 0.9, 0.8, k))
