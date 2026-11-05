extends Control
## Interface: painéis dos jogadores (1 a 4), barra do inimigo, combo, mensagens
## e telas (título, seleção/entrada de jogadores, abertura da era, fim de fase, final).

const Controls = preload("res://scripts/controls.gd")
const PLAYER_COLORS := [Color(1, 0.3, 0.3), Color(0.35, 0.6, 1), Color(0.35, 0.95, 0.4), Color(1, 0.85, 0.2)]
const W := 960.0

var game
var enemy_ref = null
var enemy_timer := 0.0
var message := ""
var message_timer := 0.0
var t := 0.0
var font: Font


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


func _scores_block(y: float) -> void:
	for i in game.players.size():
		var p = game.players[i]
		var label: String = "Pontos: %d" % p.score if game.players.size() == 1 else "P%d %s: %d pontos" % [i + 1, p.display_name, p.score]
		_center(y + i * 30, label, 24 if game.players.size() == 1 else 20, PLAYER_COLORS[i] if game.players.size() > 1 else Color(1, 1, 1))


func _draw() -> void:
	if game.mode in ["play", "stageclear", "gameover", "roundstart", "roundend", "match"] and not game.players.is_empty():
		_draw_game_hud()
	if message_timer > 0.0 and game.mode == "play":
		_center(230, message, 40, Color(1, 0.95, 0.4))
	match game.mode:
		"title": _draw_title()
		"select": _draw_select()
		"intro": _draw_intro()
		"stageclear":
			draw_rect(Rect2(0, 0, W, 540), Color(0, 0, 0, 0.55))
			_center(170, "ERA CONCLUÍDA!", 64, Color(0.4, 1, 0.5))
			_center(215, game.stage.name, 24, Color(1, 1, 1))
			_scores_block(265)
			var nxt: Dictionary = game.stages[game.stage_idx + 1]
			_center(410, "Próxima viagem: %s (%s)" % [nxt.name, nxt.year], 22, Color(0.6, 0.9, 1))
			if int(t * 2.0) % 2 == 0:
				_center(455, "ENTER ou SOCO para viajar no tempo", 22, Color(1, 0.9, 0.3))
		"gameover":
			draw_rect(Rect2(0, 0, W, 540), Color(0, 0, 0, 0.6))
			_center(200, "FIM DE JOGO", 72, Color(1, 0.2, 0.2))
			_scores_block(260)
			_center(420, "ENTER ou SOCO para continuar nesta era", 22, Color(1, 0.9, 0.3))
		"ending": _draw_ending()
		"roundstart":
			var k := clampf(game.mode_time * 4.0, 0.0, 1.0)
			_center(250, "ROUND %d" % game.round_num, int(70 * k) + 1, Color(1, 0.85, 0.3))
			if game.mode_time > 0.9:
				_center(310, "PREPAREM-SE...", 26, Color(1, 1, 1))
		"roundend":
			if game.round_winner >= 0:
				var w = game.players[game.round_winner]
				_center(240, "P%d %s VENCE O ROUND!" % [w.pid + 1, w.display_name], 44, PLAYER_COLORS[w.pid])
			else:
				_center(240, "EMPATE!", 56, Color(1, 1, 1))
		"match":
			draw_rect(Rect2(0, 0, W, 540), Color(0, 0, 0, 0.6))
			var champ = game._versus_champion()
			if champ != null:
				_center(170, "CAMPEÃO!", 40, Color(1, 0.85, 0.3))
				_center(240, "P%d %s" % [champ.pid + 1, champ.display_name], 64, PLAYER_COLORS[champ.pid])
			for i in game.players.size():
				var p = game.players[i]
				_center(310 + i * 28, "P%d %s — %d round(s)" % [i + 1, p.display_name, game.round_wins[i]], 20, PLAYER_COLORS[i])
			if game.mode_time > 1.5 and int(t * 2.0) % 2 == 0:
				_center(460, "ENTER ou SOCO: revanche   •   ESC: voltar ao título", 20, Color(1, 0.9, 0.3))


func _draw_game_hud() -> void:
	var n: int = game.players.size()
	var pw := 236.0 if n > 1 else 360.0
	for i in n:
		var pl = game.players[i]
		var x := 12.0 + i * 238.0
		var col: Color = PLAYER_COLORS[i] if n > 1 else Color(1, 0.9, 0.3)
		var tag: String = "P%d %s" % [i + 1, pl.display_name] if n > 1 else pl.display_name
		if pl.out and game.versus:
			_text(Vector2(x, 28), tag, 16 if n > 1 else 20, col)
			_text(Vector2(x, 50), "NOCAUTEADO", 15, Color(1, 0.4, 0.4))
			continue
		if pl.out:
			_text(Vector2(x, 30), "P%d" % (i + 1), 18, col)
			if int(t * 2.0) % 2 == 0:
				_text(Vector2(x, 54), "SOCO p/ continuar", 15, Color(1, 1, 1))
			continue
		_text(Vector2(x, 28), tag, 16 if n > 1 else 20, col)
		_bar(Vector2(x, 36), pw - 60.0, 12, float(pl.hp) / pl.max_hp, Color(1, 0.85, 0.15))
		if game.versus:
			for k in game.VERSUS_WINS:
				var won: bool = k < game.round_wins[i]
				draw_circle(Vector2(x + pw - 46.0 + k * 16.0, 42), 6.0, Color(1, 0.85, 0.2) if won else Color(0.2, 0.2, 0.25))
				draw_arc(Vector2(x + pw - 46.0 + k * 16.0, 42), 6.0, 0, TAU, 12, Color(0, 0, 0), 1.5)
		else:
			_text(Vector2(x + pw - 50.0, 48), "x%d" % pl.lives, 16, Color(1, 1, 1))
			_text(Vector2(x, 70), "%07d" % pl.score, 15, Color(1, 1, 1))
		if not pl.weapon.is_empty():
			var wtxt: String = "%s ×%d" % [pl.weapon.name, int(pl.weapon.uses)]
			_text(Vector2(x + 78, 70), wtxt, 12 if n > 1 else 14, Color(0.6, 0.95, 1))
	var footer := "FASE %d · %s · %s" % [game.stage_idx + 1, game.stage.name, game.stage.year]
	if game.versus:
		footer = "VERSUS · ROUND %d · ARENA: %s" % [game.round_num, game.stage.name]
	_text(Vector2(0, 530), footer, 14, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER, W)
	# Inimigo atual (na parte de baixo da tela)
	if enemy_timer > 0.0 and is_instance_valid(enemy_ref) and game.mode == "play":
		var boss: bool = enemy_ref.is_boss()
		var tier_cols := [Color(1, 0.4, 0.9), Color(0.6, 1, 0.5), Color(1, 0.85, 0.3), Color(1, 0.4, 0.3)]
		var tc: Color = tier_cols[enemy_ref.tier]
		var bw := 360.0 if boss else 280.0
		var bx := (W - bw) * 0.5
		_text(Vector2(bx, 487), enemy_ref.display_name, 16, Color(1, 0.6, 0.6))
		_text(Vector2(bx, 487), enemy_ref.tier_label(), 13, tc, HORIZONTAL_ALIGNMENT_RIGHT, bw)
		_bar(Vector2(bx, 494), bw, 10, float(enemy_ref.hp) / enemy_ref.max_hp, Color(0.95, 0.3, 0.2) if not boss else Color(0.9, 0.2, 0.9))
	if game.combo_count >= 2 and game.combo_timer > 0.0:
		var sc := 1.0 + clampf(game.combo_timer - 0.9, 0.0, 0.3)
		_text(Vector2(16, 120), "%d GOLPES!" % game.combo_count, int(28 * sc), Color(1, 0.6, 0.2))
	if game.show_go and int(t * 3.0) % 2 == 0:
		_text(Vector2(W - 170, 270), "VAI ►", 44, Color(1, 0.95, 0.3))
	if game.paused:
		draw_rect(Rect2(0, 0, W, 540), Color(0, 0, 0, 0.5))
		_center(280, "PAUSADO", 56, Color(1, 1, 1))


func _draw_title() -> void:
	draw_rect(Rect2(0, 0, W, 540), Color(0.03, 0.0, 0.08, 0.72))
	_center(110, "PUNHO DO TEMPO", 80, Color(1, 0.3, 0.6))
	_center(150, "um beat 'em up através de 12 eras — 1 a 4 jogadores", 19, Color(0.6, 0.9, 1))
	var lines := [
		"P1: WASD + J soco, K pulo, L especial      P2: Setas + , soco  . pulo  / especial",
		"P3: TFGH + Z soco, X pulo, C especial      P4: Numpad 8456 + 7 soco, 9 pulo, + especial",
		"Controles: X soco, A pulo, Y/B especial (cada controle é um jogador)",
		"Cima + Soco: gancho  |  Pulo + Soco: voadora  |  Soco sobre arma: pegar  |  Especial armado: arremessar",
	]
	for i in lines.size():
		_center(200 + i * 26, lines[i], 15, Color(1, 1, 1))
	var vs: bool = game.game_mode == "versus"
	_center(318, "Modo (▲ ▼):   %s     %s" % ["[ HISTÓRIA ]" if not vs else "HISTÓRIA", "[ VERSUS ]" if vs else "VERSUS"], 19, Color(1, 0.6, 0.8))
	_center(342, "Arena (◄ ►):" if vs else "Fase inicial (◄ ►):", 15, Color(0.8, 0.8, 0.9))
	_center(372, "◄  %d. %s  (%s)  ►" % [game.stage_idx + 1, game.stage.name, game.stage.year], 26, Color(0.5, 1, 0.6))
	if int(t * 2.0) % 2 == 0:
		_center(450, "Aperte SOCO ou ENTER para começar", 28, Color(1, 0.9, 0.3))
	if vs:
		_center(485, "Versus: 2 a 4 jogadores, todos contra todos. Vence quem ganhar 2 rounds.", 15, Color(0.8, 0.8, 0.9))
	else:
		_center(485, "Os outros jogadores entram na tela de seleção apertando SOCO", 15, Color(0.8, 0.8, 0.9))


func _draw_select() -> void:
	draw_rect(Rect2(0, 0, W, 292), Color(0.03, 0.0, 0.08, 0.6))
	_center(40, "VERSUS — ESCOLHAM SEUS LUTADORES" if game.versus else "ESCOLHAM SEUS LUTADORES", 34, Color(1, 0.85, 0.3))
	if game.versus and game.slots.size() < 2 and int(t * 2.0) % 2 == 0:
		_center(292, "O Versus precisa de pelo menos 2 jogadores — o P2 aperta SOCO para entrar", 15, Color(1, 0.5, 0.5))
	var chars: Array = game.characters
	var cw := 74.0
	var ch := 84.0
	var ox := 24.0
	var oy := 72.0
	for i in chars.size():
		var c: Dictionary = chars[i]
		var col := i / 2
		var row := i % 2
		var r := Rect2(ox + col * 130.0, oy + row * (ch + 22), cw, ch)
		draw_rect(r, c.shirt.darkened(0.45))
		var hp_pos := r.position + Vector2(cw * 0.5, 40)
		draw_rect(Rect2(hp_pos + Vector2(-20, 14), Vector2(40, 30)), c.shirt)
		draw_circle(hp_pos, 17.0, c.hair)
		draw_circle(hp_pos + Vector2(0, 3), 14.0, c.skin)
		draw_rect(Rect2(hp_pos + Vector2(-7, 0), Vector2(4, 4)), Color(0.05, 0.05, 0.05))
		draw_rect(Rect2(hp_pos + Vector2(4, 0), Vector2(4, 4)), Color(0.05, 0.05, 0.05))
		draw_rect(r, Color(0, 0, 0, 0.8), false, 2.0)
		_text(r.position + Vector2(0, ch + 15), c.name, 12, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, cw)
		# cursores dos jogadores neste card
		for s in game.slots.size():
			if game.slots[s].char == i:
				var inset: float = 2.0 + s * 4.0
				draw_rect(Rect2(r.position + Vector2(inset, inset), r.size - Vector2(inset, inset) * 2.0), PLAYER_COLORS[s], false, 3.0)
				_text(r.position + Vector2(cw + 2, 14 + s * 15), "P%d" % (s + 1), 12, PLAYER_COLORS[s])
	for k in 7:
		var reg: String = String(chars[k * 2].region).replace("AMÉRICA", "AMÉR.")
		_text(Vector2(ox + k * 130.0 - 8, oy - 5), reg, 10, Color(0.6, 0.9, 1), HORIZONTAL_ALIGNMENT_CENTER, cw + 16)

	# Painéis dos 4 jogadores
	for i in 4:
		var px := 8.0 + i * 238.0
		var py := 300.0
		var col: Color = PLAYER_COLORS[i]
		draw_rect(Rect2(px, py, 140, 232), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(px + 140, py, 90, 232), Color(0, 0, 0, 0.15))
		draw_rect(Rect2(px, py, 230, 232), col, false, 2.0)
		_text(Vector2(px + 8, py + 22), "P%d" % (i + 1), 20, col)
		if i >= game.slots.size():
			if int(t * 2.0) % 2 == 0:
				_text(Vector2(px, py + 110), "Aperte SOCO", 18, Color(1, 1, 1), HORIZONTAL_ALIGNMENT_CENTER, 230)
			_text(Vector2(px, py + 134), "para entrar", 15, Color(0.8, 0.8, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 230)
			continue
		var sl: Dictionary = game.slots[i]
		var c: Dictionary = chars[sl.char]
		_text(Vector2(px + 44, py + 22), Controls.describe(sl.sets[0]), 10, Color(0.75, 0.75, 0.85))
		_text(Vector2(px + 8, py + 50), c.name, 20, Color(1, 0.9, 0.3))
		_text(Vector2(px + 8, py + 70), c.country, 13, Color(0.6, 0.9, 1))
		_text(Vector2(px + 8, py + 88), c.style, 12, Color(1, 1, 1))
		var stats := [["VIDA", (float(c.hp) - 70.0) / 60.0], ["VELOC.", (float(c.speed) - 0.7) / 0.55], ["FORÇA", (float(c.power) - 0.8) / 0.45]]
		for k in stats.size():
			_text(Vector2(px + 8, py + 116 + k * 20), stats[k][0], 11, Color(1, 1, 1))
			_bar(Vector2(px + 58, py + 107 + k * 20), 70, 8, stats[k][1], Color(0.3, 0.9, 1))
		_text(Vector2(px + 8, py + 178), "ESPECIAL:", 10, Color(0.8, 0.8, 0.9))
		_text(Vector2(px + 8, py + 190), c.special.name, 11, c.special.color)
		if sl.ready:
			_text(Vector2(px + 8, py + 210), "PRONTO!", 20, Color(0.4, 1, 0.5))
			_text(Vector2(px + 8, py + 226), "pulo: cancelar", 10, Color(0.8, 0.8, 0.9))
		else:
			_text(Vector2(px + 8, py + 210), "◄► ▲▼ escolher", 10, Color(0.8, 0.8, 0.9))
			_text(Vector2(px + 8, py + 226), "SOCO: confirmar", 11, Color(1, 0.9, 0.3))


func _draw_intro() -> void:
	var st: Dictionary = game.stage
	var k := clampf(game.mode_time * 3.0, 0.0, 1.0)
	draw_rect(Rect2(0, 120, W, 320), Color(0, 0, 0, 0.7 * k))
	_center(180, "FASE %d de %d" % [game.stage_idx + 1, game.stages.size()], 26, Color(0.6, 0.9, 1, k))
	_center(245, st.name, 54, Color(1, 0.85, 0.3, k))
	_center(285, st.year, 26, Color(1, 1, 1, k))
	_center(330, String(st.intro).replace("{p}", game.party_names()), 18, Color(1, 1, 1, k))
	_center(375, "Sub-chefe: %s   •   Chefe: %s" % [st.subboss.name, st.boss.name], 16, Color(1, 0.55, 0.55, k))
	_center(400, "Inimigos: ★ %s   ★★ %s   ★★★ %s" % [st.thug.name, st.knife.name, st.brute.name], 15, Color(0.8, 0.9, 0.8, k))
	var ws: Array = game.Weapons.for_stage(game.stage_idx)
	_center(422, "Armas da era: %s e %s" % [ws[0].name, ws[1].name], 15, Color(0.6, 0.95, 1, k))


func _draw_ending() -> void:
	draw_rect(Rect2(0, 0, 640, 540), Color(0, 0, 0, 0.72))
	draw_rect(Rect2(640, 0, W - 640, 130), Color(0, 0, 0, 0.72))
	var p = game.players[game.ending_page]
	var ch: Dictionary = game.characters[game._char_of(p)]
	_center(70, "A LINHA DO TEMPO FOI SALVA!", 44, Color(1, 0.85, 0.3))
	_center(108, "%s derrotou CRONOS e atravessou as 12 eras." % game.party_names(), 18, Color(0.7, 0.9, 1))
	var title := "FINAL DE %s" % ch.name
	if game.players.size() > 1:
		title = "P%d · " % (game.ending_page + 1) + title
	_text(Vector2(40, 170), title, 26, PLAYER_COLORS[game.ending_page] if game.players.size() > 1 else Color(1, 0.5, 0.7))
	var ending: Array = ch.ending
	var shown := int(game.mode_time / 1.2) + 1
	for i in mini(shown, ending.size()):
		_text(Vector2(40, 215 + i * 34), ending[i], 18, Color(1, 1, 1))
	_text(Vector2(40, 380), "PONTUAÇÃO: %d" % p.score, 28, Color(0.4, 1, 0.5))
	if game.mode_time > 2.0 and int(t * 2.0) % 2 == 0:
		var more: bool = game.ending_page < game.players.size() - 1
		_center(500, "ENTER: próximo final" if more else "ENTER para voltar ao título", 22, Color(1, 0.9, 0.3))
