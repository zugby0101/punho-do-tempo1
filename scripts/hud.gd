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
	_draw_main()
	if game.mode != "achievements":
		_draw_toasts()


func _draw_toasts() -> void:
	var i := 0
	for tt in Ach.toasts:
		var k := clampf((4.0 - tt[2]) * 4.0, 0.0, 1.0) * clampf(tt[2] * 3.0, 0.0, 1.0)
		var x := W - 330.0 * k
		var y := 96.0 + i * 62.0
		var c: Color = tt[1]
		draw_rect(Rect2(x, y, 320, 54), Color(0.05, 0.03, 0.1, 0.92))
		draw_rect(Rect2(x, y, 320, 54), c, false, 2.0)
		_trophy(Vector2(x + 28, y + 27), c, true)
		_text(Vector2(x + 54, y + 22), "CONQUISTA DESBLOQUEADA!", 12, Color(0.8, 0.8, 0.9))
		_text(Vector2(x + 54, y + 43), tt[0], 17, c)
		i += 1


## Ícone de troféu.
func _trophy(c: Vector2, col: Color, on: bool) -> void:
	var cc := col if on else Color(0.3, 0.3, 0.35)
	draw_circle(c, 18.0, Color(cc.r, cc.g, cc.b, 0.18))
	draw_colored_polygon(PackedVector2Array([c + Vector2(-10, -10), c + Vector2(10, -10), c + Vector2(7, 2), c + Vector2(-7, 2)]), cc)
	draw_circle(c + Vector2(0, 0), 7.0, cc)
	draw_rect(Rect2(c + Vector2(-2, 6), Vector2(4, 5)), cc)
	draw_rect(Rect2(c + Vector2(-7, 10), Vector2(14, 3)), cc)
	draw_arc(c + Vector2(-10, -5), 4.0, PI * 0.5, PI * 1.5, 6, cc, 2.0)
	draw_arc(c + Vector2(10, -5), 4.0, -PI * 0.5, PI * 0.5, 6, cc, 2.0)
	if not on:
		draw_rect(Rect2(c + Vector2(-5, -3), Vector2(10, 8)), Color(0.15, 0.15, 0.18))


func _draw_achievements() -> void:
	draw_rect(Rect2(0, 0, W, 540), Color(0.03, 0.0, 0.08, 0.92))
	var total: int = Ach.LIST.size()
	_center(48, "CONQUISTAS", 36, Color(1, 0.85, 0.3))
	_center(76, "%d de %d desbloqueadas" % [Ach.unlocked_count(), total], 15, Color(0.8, 0.8, 0.9))
	var per := 16
	var pages := int(ceil(total / float(per)))
	var start: int = game.ach_page * per
	for k in range(start, mini(start + per, total)):
		var a: Array = Ach.LIST[k]
		var j := k - start
		var x := 24.0 + (j % 2) * 468.0
		var y := 96.0 + (j / 2) * 52.0
		var on: bool = Ach.is_unlocked(a[0])
		var col: Color = a[6]
		draw_rect(Rect2(x, y, 456, 46), Color(col.r, col.g, col.b, 0.12) if on else Color(1, 1, 1, 0.04))
		draw_rect(Rect2(x, y, 456, 46), col if on else Color(0.3, 0.3, 0.35), false, 1.5)
		_trophy(Vector2(x + 24, y + 23), col, on)
		_text(Vector2(x + 50, y + 20), a[1], 15, col if on else Color(0.75, 0.75, 0.8))
		_text(Vector2(x + 50, y + 38), a[2], 12, Color(0.85, 0.85, 0.9) if on else Color(0.6, 0.6, 0.65))
		if on:
			_text(Vector2(x + 300, y + 20), "✔ " + String(Ach.unlocked[a[0]]), 11, Color(0.5, 1, 0.6), HORIZONTAL_ALIGNMENT_RIGHT, 150)
		elif a[3] != "flag":
			var goal := int(a[5])
			var prog := mini(Ach.progress(a), goal)
			_text(Vector2(x + 300, y + 20), "%d / %d" % [prog, goal], 12, Color(0.8, 0.8, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 150)
			_bar(Vector2(x + 350, y + 30), 96, 5, float(prog) / goal, col)
	_center(520, "Página %d/%d  •  ◄ ► trocar página  •  ESC voltar" % [game.ach_page + 1, pages], 14, Color(0.8, 0.8, 0.9))


func _draw_main() -> void:
	_draw_cinematic()
	if game.mode in ["play", "stageclear", "gameover", "roundstart", "roundend", "match", "dialog"] and not game.players.is_empty():
		_draw_game_hud()
	if message_timer > 0.0 and game.mode == "play":
		_center(230, message, 40, Color(1, 0.95, 0.4))
	_draw_net_status()
	match game.mode:
		"title": _draw_title()
		"online_menu": _draw_online_menu()
		"ranking": _draw_ranking()
		"dialog": _draw_dialog()
		"achievements": _draw_achievements()
		"name_entry":
			draw_rect(Rect2(0, 0, W, 540), Color(0.03, 0.0, 0.08, 0.85))
			if not game.name_queue.is_empty():
				var p = game.name_queue[0]
				_center(170, "RANKING ONLINE", 40, Color(1, 0.85, 0.3))
				var who: String = ("P%d " % (p.pid + 1)) if game.players.size() > 1 else ""
				_center(225, "%s%s — %d pontos" % [who, p.display_name, p.score], 24, PLAYER_COLORS[p.pid] if game.players.size() > 1 else Color(1, 1, 1))
				_center(270, "Digite seu nome e aperte ENTER", 18, Color(1, 1, 1))
			_center(380, "ESC para cancelar", 15, Color(0.8, 0.8, 0.9))
		"join_input":
			draw_rect(Rect2(0, 0, W, 540), Color(0.03, 0.0, 0.08, 0.85))
			match game.input_purpose:
				"code":
					_center(200, "ENTRAR EM SALA", 40, Color(0.5, 0.9, 1))
					_center(260, "Digite o código de 4 letras da sala e aperte ENTER", 20, Color(1, 1, 1))
				"url":
					_center(190, "SERVIDOR INTERMEDIÁRIO", 40, Color(0.5, 0.9, 1))
					_center(240, "Endereço do relay (ex.: wss://punho-relay.onrender.com)", 18, Color(1, 1, 1))
					_center(266, "Veja relay-server/README.md para publicar o seu servidor de graça.", 15, Color(0.75, 0.75, 0.85))
				_:
					_center(200, "ENTRAR DIRETO POR IP", 40, Color(0.5, 0.9, 1))
					_center(260, "Digite o IP do anfitrião e aperte ENTER", 20, Color(1, 1, 1))
					_center(430, "Mesma rede: use o IP local que aparece na tela do anfitrião.", 14, Color(0.75, 0.75, 0.85))
					_center(452, "Pela internet: porta 7777 (UDP) liberada no roteador, ou uma VPN de jogos.", 14, Color(0.75, 0.75, 0.85))
			_center(380, "ESC para voltar", 16, Color(0.8, 0.8, 0.9))
		"connecting":
			draw_rect(Rect2(0, 0, W, 540), Color(0.03, 0.0, 0.08, 0.85))
			_center(250, "CRIANDO SALA..." if not game.net_client else "CONECTANDO...", 44, Color(0.5, 0.9, 1))
			_center(300, Net.status if Net.status != "" else "Aguardando o anfitrião", 18, Color(1, 1, 1))
			_center(350, "ESC para cancelar", 15, Color(0.8, 0.8, 0.9))
		"select": _draw_select()
		"intro": _draw_intro()
		"stageclear":
			draw_rect(Rect2(0, 0, W, 540), Color(0, 0, 0, 0.55))
			_center(170, "ERA CONCLUÍDA!", 64, Color(0.4, 1, 0.5))
			_center(215, game.stage.name, 24, Color(1, 1, 1))
			_scores_block(265)
			if game.fragment_got:
				_center(380, "✦ FRAGMENTO DO TEMPO OBTIDO! (%d/12) ✦" % game.fragments(), 20, Color(1, 0.85, 0.4))
			var nxt: Dictionary = game.stages[game.stage_idx + 1]
			if game.stage_idx + 1 == game.SECRET_IDX:
				_center(410, "Os 12 Fragmentos brilham... uma fenda se abre: ??? (%s)" % nxt.year, 20, Color(0.85, 0.6, 1))
			else:
				_center(410, "Próxima viagem: %s (%s)" % [nxt.name, nxt.year], 22, Color(0.6, 0.9, 1))
			if int(t * 2.0) % 2 == 0:
				_center(455, "ENTER ou SOCO para viajar no tempo", 22, Color(1, 0.9, 0.3))
		"gameover":
			draw_rect(Rect2(0, 0, W, 540), Color(0, 0, 0, 0.6))
			_center(200, "FIM DE JOGO", 72, Color(1, 0.2, 0.2))
			if game.survival:
				_center(240, "Vocês chegaram à ONDA %d" % game.surv_wave, 26, Color(1, 0.85, 0.3))
			_scores_block(275)
			_center(420, "ENTER ou SOCO para tentar de novo (onda 1)" if game.survival else "ENTER ou SOCO para continuar nesta era", 22, Color(1, 0.9, 0.3))
			if not game.score_sent and not game.versus:
				_center(455, "R: enviar a pontuação ao RANKING ONLINE", 18, Color(0.5, 0.9, 1))
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
				_text(Vector2(x, 54), "FORA" if game.survival else "SOCO p/ continuar", 15, Color(1, 0.5, 0.5) if game.survival else Color(1, 1, 1))
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
	elif game.survival:
		footer = "SOBREVIVÊNCIA · ONDA %d · ERA: %s" % [game.surv_wave, game.stage.name]
		if game.surv_wave > 0:
			_text(Vector2(0, 104), "ONDA %d" % game.surv_wave, 26, Color(1, 0.85, 0.3), HORIZONTAL_ALIGNMENT_CENTER, W)
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
	var gm: String = game.game_mode
	var names := {"story": "HISTÓRIA", "versus": "VERSUS", "survival": "SOBREVIVÊNCIA"}
	var parts: Array = []
	for k in ["story", "versus", "survival"]:
		parts.append("[ %s ]" % names[k] if k == gm else names[k])
	_center(318, "Modo (▲ ▼):   " + "    ".join(parts), 19, Color(1, 0.6, 0.8))
	_center(342, "Arena (◄ ►):" if vs or gm == "survival" else "Fase inicial (◄ ►):", 15, Color(0.8, 0.8, 0.9))
	_center(372, "◄  %d. %s  (%s)  ►" % [game.stage_idx + 1, game.stage.name, game.stage.year], 26, Color(0.5, 1, 0.6))
	if int(t * 2.0) % 2 == 0:
		_center(450, "Aperte SOCO ou ENTER para começar", 28, Color(1, 0.9, 0.3))
	if game.fragments() > 0:
		var ftxt := "✦ Fragmentos do Tempo: %d/12" % game.fragments()
		if game.secret_unlocked():
			ftxt += " — FASE SECRETA DESBLOQUEADA (13ª na lista de fases)"
		_center(395, ftxt, 14, Color(1, 0.85, 0.4))
	_center(415, "ONLINE: O = criar/entrar numa sala  •  R = ranking  •  M = conquistas (%d/%d)" % [Ach.unlocked_count(), Ach.LIST.size()], 16, Color(0.5, 0.9, 1))
	_center(507, "V: visual — %s     P: partículas — %s" % ["[ RIG 2D ]  clássico" if game.rig_mode else "rig 2D  [ CLÁSSICO ]",
		"[ LIGADAS ]  desligadas" if game.fx_enabled else "ligadas  [ DESLIGADAS ]"], 13, Color(0.75, 0.75, 0.85))
	if gm == "survival":
		_center(485, "Sobrevivência: ondas infinitas que ficam cada vez mais difíceis. Até onde você chega?", 15, Color(0.8, 0.8, 0.9))
	elif vs:
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
	var ws: Array = game.Weapons.for_stage(mini(game.stage_idx, game.LAST_ERA))
	_center(422, "Armas da era: %s e %s" % [ws[0].name, ws[1].name], 15, Color(0.6, 0.95, 1, k))
	if game.stage_idx <= game.LAST_ERA and not game.versus and not game.survival:
		if game.has_fragment(game.stage_idx):
			_center(446, "✦ Fragmento do Tempo desta era: obtido", 14, Color(1, 0.85, 0.4, k))
		else:
			_center(446, "✧ Fragmento do Tempo: conclua esta era sem perder nenhuma vida (%d/12)" % game.fragments(), 14, Color(0.85, 0.75, 0.5, k))


func _draw_ending() -> void:
	draw_rect(Rect2(0, 0, 640, 540), Color(0, 0, 0, 0.72))
	draw_rect(Rect2(640, 0, W - 640, 130), Color(0, 0, 0, 0.72))
	var p = game.players[game.ending_page]
	var ch: Dictionary = game.characters[game._char_of(p)]
	var true_end: bool = game.stage_idx == game.SECRET_IDX
	if true_end:
		_center(62, "FINAL VERDADEIRO", 44, Color(0.85, 0.6, 1))
		_center(96, "%s derrotou ÉON, O ETERNO. O tempo está livre para sempre." % game.party_names(), 17, Color(1, 0.85, 0.4))
	else:
		_center(70, "A LINHA DO TEMPO FOI SALVA!", 44, Color(1, 0.85, 0.3))
		_center(108, "%s derrotou CRONOS e atravessou as 12 eras." % game.party_names(), 18, Color(0.7, 0.9, 1))
	if not true_end:
		var missing: int = 12 - game.fragments()
		if missing > 0:
			_text(Vector2(40, 470), "Ainda faltam %d Fragmentos do Tempo... algo espera além do tempo." % missing, 15, Color(0.85, 0.6, 1))
	var title := "FINAL DE %s" % ch.name
	if game.players.size() > 1:
		title = "P%d · " % (game.ending_page + 1) + title
	_text(Vector2(40, 170), title, 26, PLAYER_COLORS[game.ending_page] if game.players.size() > 1 else Color(1, 0.5, 0.7))
	var ending: Array = ch.ending
	var shown := int(game.mode_time / 1.2) + 1
	for i in mini(shown, ending.size()):
		_text(Vector2(40, 215 + i * 34), ending[i], 18, Color(1, 1, 1))
	_text(Vector2(40, 380), "PONTUAÇÃO: %d" % p.score, 28, Color(0.4, 1, 0.5))
	if not game.score_sent:
		_text(Vector2(40, 420), "R: enviar ao RANKING ONLINE", 18, Color(0.5, 0.9, 1))
	if game.mode_time > 2.0 and int(t * 2.0) % 2 == 0:
		var more: bool = game.ending_page < game.players.size() - 1
		_center(500, "ENTER: próximo final" if more else "ENTER para voltar ao título", 22, Color(1, 0.9, 0.3))


func _draw_net_status() -> void:
	if Net.status_timer > 0.0 and game.mode != "connecting":
		var sy := 100.0
		match game.mode:
			"play": sy = 160.0
			"select": sy = 290.0
			"title": sy = 180.0
		_text(Vector2(0, sy), Net.status, 15, Color(0.5, 0.9, 1), HORIZONTAL_ALIGNMENT_CENTER, W)
	if not Net.online() or game.mode in ["connecting", "join_input"]:
		return
	var txt := ""
	if Net.is_host() and Net.transport == "relay":
		txt = "ONLINE · SALA %s · passe o código para os amigos · convidados: %d" % [Net.room_code, Net.connected_count()]
	elif Net.is_host():
		txt = "ONLINE · anfitrião · IP %s · porta %d · convidados: %d" % [Net.local_ip(), Net.PORT, Net.connected_count()]
	elif Net.transport == "relay":
		txt = "ONLINE · sala %s" % Net.room_code
	else:
		txt = "ONLINE · conectado a %s" % Net.server_ip
	var y := 512.0 if game.mode in ["play", "roundstart", "roundend"] else 290.0
	if game.mode == "select":
		y = 14.0
	_text(Vector2(0, y), txt, 13, Color(0.5, 0.9, 1, 0.9), HORIZONTAL_ALIGNMENT_CENTER, W)


func _draw_online_menu() -> void:
	draw_rect(Rect2(0, 0, W, 540), Color(0.03, 0.0, 0.08, 0.85))
	_center(80, "JOGAR ONLINE", 44, Color(0.5, 0.9, 1))
	var mode_txt := "Modo: %s   •   %s: %s" % ["VERSUS" if game.game_mode == "versus" else "HISTÓRIA", "Arena" if game.game_mode == "versus" else "Fase", game.stage.name]
	_center(112, mode_txt, 15, Color(0.8, 0.8, 0.9))
	var opts: Array = game.ONLINE_OPTIONS
	for i in opts.size():
		var sel: bool = i == game.online_choice
		var y := 170.0 + i * 58.0
		if sel:
			draw_rect(Rect2(170, y - 30, 620, 52), Color(0.3, 0.6, 1, 0.25))
			draw_rect(Rect2(170, y - 30, 620, 52), Color(0.5, 0.9, 1), false, 2.0)
		_center(y, ("► " if sel else "") + opts[i][0], 22, Color(1, 0.9, 0.3) if sel else Color(1, 1, 1))
		_center(y + 17, opts[i][1], 13, Color(0.75, 0.75, 0.85))
	var srv: String = Net.relay_url if Net.has_relay() else "nenhum servidor configurado (opção CONFIGURAR SERVIDOR)"
	_center(470, "Servidor: " + srv, 13, Color(0.5, 0.9, 1) if Net.has_relay() else Color(1, 0.6, 0.5))
	_center(505, "▲▼ escolher   •   SOCO/ENTER confirmar   •   ESC voltar", 15, Color(0.8, 0.8, 0.9))


func _draw_ranking() -> void:
	draw_rect(Rect2(0, 0, W, 540), Color(0.03, 0.0, 0.08, 0.9))
	var surv: bool = Net.ranking_board == "survival"
	_center(60, "RANKING ONLINE — " + ("SOBREVIVÊNCIA" if surv else "MODO HISTÓRIA"), 34, Color(1, 0.85, 0.3))
	_center(484, "◄ ► trocar entre História e Sobrevivência", 13, Color(0.6, 0.9, 1))
	var st: String = Net.ranking_status
	if st == "carregando":
		_center(270, "Carregando..." + ".".repeat(int(t * 3.0) % 3), 24, Color(1, 1, 1))
		_center(305, "(se o servidor estava dormindo, pode levar até 1 minuto)", 14, Color(0.75, 0.75, 0.85))
	elif st != "ok":
		_center(270, st, 18, Color(1, 0.6, 0.5))
	else:
		# minhas posições do último envio
		var mine: Array = []
		for r in Net.last_ranks:
			if r.get("ok", false):
				mine.append("%s ficou em %dº" % [r.name, int(r.rank)])
		if not mine.is_empty():
			_center(92, " • ".join(mine), 16, Color(0.4, 1, 0.5))
		var cols := [60.0, 120.0, 330.0, 480.0, 640.0, 760.0]
		var heads := ["#", "NOME", "LUTADOR", "PONTOS", "ONDA" if surv else "ERA", "JOG."]
		for k in heads.size():
			_text(Vector2(cols[k], 128), heads[k], 15, Color(0.6, 0.9, 1))
		if Net.ranking.is_empty():
			_center(270, "Ainda não há pontuações. Seja o primeiro!", 20, Color(1, 1, 1))
		for i in mini(Net.ranking.size(), 10):
			var e: Dictionary = Net.ranking[i]
			var y := 162.0 + i * 30.0
			var col := Color(1, 0.85, 0.3) if i == 0 else (Color(0.85, 0.85, 0.9) if i < 3 else Color(1, 1, 1))
			_text(Vector2(cols[0], y), "%d" % (i + 1), 18, col)
			_text(Vector2(cols[1], y), String(e.get("name", "?")), 18, col)
			_text(Vector2(cols[2], y), String(e.get("char", "")), 16, col)
			_text(Vector2(cols[3], y), "%d" % int(e.get("score", 0)), 18, col)
			var era := "FINAL ★" if e.get("done", false) else "Fase %d" % int(e.get("stage", 1))
			if surv:
				era = "%d" % int(e.get("wave", 0))
			_text(Vector2(cols[4], y), era, 16, Color(0.4, 1, 0.5) if e.get("done", false) and not surv else col)
			_text(Vector2(cols[5], y), "%dP" % int(e.get("players", 1)), 16, col)
	_center(510, "ESC, ENTER ou SOCO para voltar", 15, Color(0.8, 0.8, 0.9))


# =================== Diálogos ===================
func _draw_dialog() -> void:
	var d: Dictionary = game.dialog_line
	if d.is_empty():
		return
	draw_rect(Rect2(0, 0, W, 540), Color(0, 0, 0, 0.25))
	var box := Rect2(24, 372, W - 48, 138)
	draw_rect(box, Color(0.04, 0.02, 0.09, 0.93))
	var col: Color = d.color
	draw_rect(box, col, false, 3.0)
	var left: bool = d.side == "left"
	var px := box.position.x + 14.0 if left else box.end.x - 14.0 - 104.0
	var pr := Rect2(px, box.position.y + 16, 104, 104)
	draw_rect(pr, Color(col.r * 0.25, col.g * 0.25, col.b * 0.3, 1))
	draw_rect(pr, col, false, 2.0)
	_portrait(pr, d.portrait, not left)
	var tx := box.position.x + 134.0 if left else box.position.x + 20.0
	var tw := box.size.x - 154.0
	_text(Vector2(tx, box.position.y + 30), String(d.name), 20, col)
	var shown := String(d.text).substr(0, int(game.dialog_chars))
	draw_multiline_string_outline(font, Vector2(tx, box.position.y + 60), shown, HORIZONTAL_ALIGNMENT_LEFT, tw, 18, 3, 4, Color(0, 0, 0, 0.9))
	draw_multiline_string(font, Vector2(tx, box.position.y + 60), shown, HORIZONTAL_ALIGNMENT_LEFT, tw, 18, 3, Color(1, 1, 1))
	if int(game.dialog_chars) >= String(d.text).length() and int(t * 2.5) % 2 == 0:
		draw_colored_polygon(PackedVector2Array([box.end - Vector2(28, 22), box.end - Vector2(14, 22), box.end - Vector2(21, 14)]), col)
	var hx := box.position.x + 134.0 if left else box.position.x + 20.0
	_text(Vector2(hx, box.end.y - 10), "SOCO/ENTER: avançar   •   PULO: pular o diálogo", 11, Color(0.6, 0.6, 0.72))


## Retrato simples de quem fala, com as cores e o chapéu do personagem.
func _portrait(r: Rect2, p: Dictionary, flip: bool) -> void:
	var c := r.get_center() + Vector2(0, 8)
	var dx := -1.0 if flip else 1.0
	var skin: Color = p.skin
	var hair: Color = p.hair
	var hat: String = p.hat
	# ombros e roupa
	draw_colored_polygon(PackedVector2Array([c + Vector2(-40, 46), c + Vector2(40, 46), c + Vector2(30, 22), c + Vector2(-30, 22)]), p.shirt)
	draw_rect(Rect2(c + Vector2(-7, 12), Vector2(14, 12)), skin.darkened(0.1))
	# cabeça
	var bald := hat in ["bald", "visor", "robot"]
	draw_circle(c, 27.0, skin if bald else hair)
	draw_circle(c + Vector2(4 * dx, 4), 23.0, skin)
	if hat in ["visor", "robot"]:
		draw_rect(Rect2(c + Vector2(-26, -26), Vector2(52, 52)), skin)
		draw_rect(Rect2(c + Vector2(-16, -6), Vector2(32, 10)), Color(0.2, 1, 1) if hat == "visor" else Color(1, 0.2, 0.2))
	else:
		draw_rect(Rect2(c + Vector2(8 * dx - 3, -6), Vector2(6, 6)), Color(0.05, 0.05, 0.05))
		draw_rect(Rect2(c + Vector2(-6 * dx - 3, -6), Vector2(6, 6)), Color(0.05, 0.05, 0.05))
		draw_line(c + Vector2(-6, 12), c + Vector2(6, 12), skin.darkened(0.45), 2.0)
	var gold := Color(1, 0.82, 0.25)
	match hat:
		"crown":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-24, -20), c + Vector2(24, -20), c + Vector2(26, -46), c + Vector2(12, -32), c + Vector2(0, -50), c + Vector2(-12, -32), c + Vector2(-26, -46)]), gold)
		"eon":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-16, -64), c + Vector2(16, -64), c + Vector2(0, -46)]), gold)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-16, -28), c + Vector2(16, -28), c + Vector2(0, -46)]), gold)
			draw_rect(Rect2(c + Vector2(-14, -6), Vector2(10, 6)), Color(0.4, 1, 1))
			draw_rect(Rect2(c + Vector2(4, -6), Vector2(10, 6)), Color(0.4, 1, 1))
		"horns":
			draw_line(c + Vector2(-14, -18), c + Vector2(-26, -46), Color(0.92, 0.88, 0.75), 6.0)
			draw_line(c + Vector2(12, -20), c + Vector2(20, -48), Color(0.92, 0.88, 0.75), 6.0)
		"greathelm":
			draw_rect(Rect2(c + Vector2(-26, -28), Vector2(52, 52)), Color(0.2, 0.2, 0.24))
			draw_rect(Rect2(c + Vector2(-4, -6), Vector2(26 * dx, 6)).abs(), Color(0.9, 0.2, 0.1))
		"kabuto":
			draw_arc(c + Vector2(0, -6), 28.0, PI, TAU, 16, Color(0.45, 0.06, 0.08), 12.0)
			draw_line(c + Vector2(0, -30), c + Vector2(-18, -58), gold, 5.0)
			draw_line(c + Vector2(0, -30), c + Vector2(20, -58), gold, 5.0)
		"tricorn":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-40, -14), c + Vector2(40, -14), c + Vector2(20, -44), c + Vector2(-20, -44)]), Color(0.08, 0.08, 0.1))
		"tophat":
			draw_rect(Rect2(c + Vector2(-20, -70), Vector2(40, 48)), Color(0.06, 0.06, 0.08))
			draw_rect(Rect2(c + Vector2(-32, -26), Vector2(64, 8)), Color(0.06, 0.06, 0.08))
		"spike", "helmet", "helmet2", "brodie":
			var hc := Color(0.15, 0.15, 0.16) if hat == "spike" else (Color(0.62, 0.64, 0.68) if hat == "helmet" else Color(0.34, 0.37, 0.28))
			draw_arc(c + Vector2(0, -4), 26.0, PI, TAU, 16, hc, 14.0)
			if hat == "spike":
				draw_line(c + Vector2(0, -30), c + Vector2(0, -54), Color(0.75, 0.7, 0.4), 5.0)
		"officer":
			draw_rect(Rect2(c + Vector2(-26, -40), Vector2(52, 18)), Color(0.22, 0.24, 0.25))
			draw_rect(Rect2(c + Vector2(-20, -24), Vector2(40, 6)), Color(0.08, 0.08, 0.1))
		"shades":
			draw_rect(Rect2(c + Vector2(-18, -10), Vector2(36, 9)), Color(0.05, 0.05, 0.05))
		"halo":
			draw_arc(c + Vector2(0, -42), 22.0, 0, TAU, 24, Color(0.5, 1, 1, 0.9), 4.0)
		"band":
			draw_line(c + Vector2(-26, -12), c + Vector2(26, -14), Color(0.95, 0.1, 0.15), 7.0)
		"luchamask":
			draw_circle(c + Vector2(2, 2), 25.0, Color(0.95, 0.15, 0.5))
			draw_circle(c + Vector2(10 * dx, -4), 8.0, Color(1, 1, 1))
			draw_circle(c + Vector2(-8 * dx, -4), 8.0, Color(1, 1, 1))
		"headwrap":
			draw_arc(c + Vector2(0, -10), 26.0, PI * 0.9, TAU + 0.1, 16, Color(0.95, 0.6, 0.1), 16.0)
		"ninja":
			draw_circle(c + Vector2(2, 2), 26.0, Color(0.1, 0.1, 0.12))
			draw_rect(Rect2(c + Vector2(-18, -12), Vector2(36, 12)), skin)
		"wild":
			for k in 7:
				var a := PI + k * PI / 6.0
				draw_circle(c + Vector2(cos(a), sin(a)) * 24.0, 10.0, hair)
			draw_circle(c + Vector2(0, 22), 14.0, hair)


# =================== Câmera lenta do golpe final ===================
## Faixas de cinema, leve escurecimento das bordas e o clarão branco do impacto.
func _draw_cinematic() -> void:
	var c: float = game.cine
	if c > 0.0:
		var e := ease(c, 0.5)
		var bar := 48.0 * e
		draw_rect(Rect2(0, 0, W, bar), Color(0, 0, 0, 0.92))
		draw_rect(Rect2(0, 540.0 - bar, W, bar), Color(0, 0, 0, 0.92))
		for i in 6:  # vinheta simples nas laterais
			var w := 90.0 - i * 15.0
			draw_rect(Rect2(0, bar, w, 540.0 - 2.0 * bar), Color(0, 0, 0, 0.05 * e))
			draw_rect(Rect2(W - w, bar, w, 540.0 - 2.0 * bar), Color(0, 0, 0, 0.05 * e))
	if game.ko_flash > 0.0:
		draw_rect(Rect2(0, 0, W, 540), Color(1, 1, 1, 0.75 * game.ko_flash * game.ko_flash))
