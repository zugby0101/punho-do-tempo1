extends Node
## Agente de teste: joga o Punho do Tempo sozinho e confere se nada quebrou.
##
##   godot --path . --fixed-fps 60 --audio-driver Dummy -- --test-bot [--quick] [--out=pasta]
##
## Só existe quando o jogo é aberto com --test-bot (main.gd carrega este script em tempo de execução).
## Etapas:
##   1. VARREDURA DOS RIGS: abre as 79 cenas de rig, toca cada animação em vários pontos e confere os
##      ossos (posições finitas e perto do corpo) e os dados de hitbox/hurtbox de cada uma.
##   2. PARTIDAS: para cada um dos 14 lutadores (cada um numa era, passando pelas 13), joga uma partida de
##      verdade com um controle virtual (como um jogador online): anda até os inimigos, soca, faz combos,
##      gancho, voadora, bloqueia, esquiva, usa o especial, pega e arremessa armas, passa os diálogos.
##      A cada quadro confere as regras do jogo (posições no chão, vida, estados, animações do rig,
##      câmera) e conta o que aconteceu (acertos, inimigos derrubados, sons de golpe, passos...).
##      Tira capturas de tela (quando há vídeo).
##   3. RELATÓRIO: imprime "[TESTBOT] RELATORIO {json}", grava <out>/relatorio.json e sai com código 1
##      se alguma regra falhou (0 se tudo passou). Erros de script do Godot aparecem no log; o
##      tools/test/check_log.py junta tudo.

const Controls = preload("res://scripts/controls.gd")
const SET := "bot"
const PLAY_TIME := 25.0       # segundos de luta por partida
const MAX_TIME := 70.0        # limite por partida (intro, diálogos, chefes...)
const KNOWN_STATES := ["idle", "walk", "attack", "jump", "special", "hurt", "knockdown", "down", "getup",
	"dead", "block", "dodge"]

static var run_idx := -1          # -1 = varredura dos rigs; 0.. = partidas
static var results: Array = []
static var rig_report := {}
static var failures: Array = []
static var started_ms := 0

var game
var quick := false
var out_dir := "user://test_output"
var t_play := 0.0
var t_total := 0.0
var rng := RandomNumberGenerator.new()
var counts := {}
var seen_states := {}
var press_cd := 0.0
var special_cd := 3.0
var mode_hold := ""
var plan := ""
var plan_t := 0.0
var prev_enemies := {}
var shots_taken := 0
var orig_hook: Callable
static var seed_base := 1  # --seed=N: outra sequência de sorteios (mesma N = mesmas partidas)
var only := 0                 # --only=N: joga só a partida N (sem a varredura dos rigs)
var trace := 0                # --trace=N: linha do tempo da partida N no log, a cada 0,5 s
var trace_t := 0.0
var branch := ""              # o que o robô está fazendo: luta, arma, defesa, caixa, sem_alvo
var last_target_desc := ""
var enemy_hp := {}
var enemy_state := {}
var item_speed := {}
var had_weapon := false
var my_hp := -1


static func wanted() -> bool:
	return "--test-bot" in OS.get_cmdline_user_args()


func _ready() -> void:
	game = get_parent()
	for a in OS.get_cmdline_user_args():
		if a == "--quick":
			quick = true
		elif a.begins_with("--out="):
			out_dir = a.substr(6)
		elif a.begins_with("--only="):
			only = int(a.substr(7))
		elif a.begins_with("--trace="):
			trace = int(a.substr(8))
		elif a.begins_with("--seed="):
			seed_base = int(a.substr(7))
	# Sorteios repetíveis: a mesma partida sempre joga igual (o jogo chama randomize() ao abrir).
	# Antes cada execução sorteava diferente, e uma partida azarada parecia defeito do lutador.
	seed(seed_base * 1000 + run_idx + 2)
	DirAccess.make_dir_recursive_absolute(_abs(out_dir))
	if not FileAccess.file_exists(_abs(out_dir + "/.gdignore")):
		var gi := FileAccess.open(_abs(out_dir + "/.gdignore"), FileAccess.WRITE)  # o Godot não importa as capturas
		if gi != null:
			gi.close()
	if started_ms == 0:
		started_ms = Time.get_ticks_msec()
	Controls.remote[SET] = Controls.new_remote()
	rng.seed = 1234 + run_idx
	process_physics_priority = 100  # depois do jogo: os comandos valem no próximo quadro
	if run_idx < 0:
		if only > 0:
			run_idx = only - 2  # pula a varredura dos rigs e as partidas antes da pedida
			call_deferred("_next")
		else:
			call_deferred("_rig_sweep")
		return
	if run_idx >= _scenarios().size():
		_finish()
		return
	# conta os sons tocados (o gancho original continua sendo chamado)
	orig_hook = game.sfx.hook
	game.sfx.hook = func(n, pitch):
		counts[_sound_group(n)] = int(counts.get(_sound_group(n), 0)) + 1
		if orig_hook.is_valid():
			orig_hook.call(n, pitch)
	_log("partida %d: %s na era %d" % [run_idx + 1, game.characters[_scenarios()[run_idx][0]].name, _scenarios()[run_idx][1]])


func _abs(p: String) -> String:
	return ProjectSettings.globalize_path(p) if p.begins_with("user://") or p.begins_with("res://") else p


func _log(msg: String) -> void:
	print("[TESTBOT] ", msg)


func _fail(msg: String) -> void:
	if failures.size() < 300 and not msg in failures:
		failures.append(msg)
		print("[TESTBOT] FALHA: ", msg)


## [lutador, era] de cada partida: os 14 lutadores, passando pelas 13 eras.
func _scenarios() -> Array:
	var out: Array = []
	var n := 3 if quick else 14
	for i in n:
		out.append([i, i % 13])
	return out


static func _sound_group(n: String) -> String:
	for pre in ["st_", "w_", "i_", "m_", "vo_", "sp_"]:
		if n.begins_with(pre):
			return "som_" + pre.trim_suffix("_")
	return "som_" + n


# =================== 1. Varredura dos rigs ===================
func _rig_paths() -> Array:
	var out: Array = []
	for dir in ["res://rigs", "res://rigs/enemies"]:
		var d := DirAccess.open(dir)
		if d == null:
			_fail("pasta de rigs não abre: " + dir)
			continue
		for f in d.get_files():
			var fn := f.trim_suffix(".remap")
			if fn.ends_with(".tscn"):
				out.append(dir + "/" + fn)
	out.sort()
	return out


func _rig_sweep() -> void:
	var paths := _rig_paths()
	var anims_total := 0
	var bad_rigs := 0
	for path in paths:
		var ps = load(path)
		if ps == null:
			_fail("rig não carrega: " + path)
			bad_rigs += 1
			continue
		var rig: Node2D = ps.instantiate()
		add_child(rig)
		var ap: AnimationPlayer = rig.get_node_or_null("AnimationPlayer")
		var sk := rig.get_node_or_null("Skeleton2D")
		if ap == null or sk == null:
			_fail("rig sem AnimationPlayer/Skeleton2D: " + path)
			rig.queue_free()
			continue
		if not rig.has_meta("hitboxes") or not rig.has_meta("hurtboxes"):
			_fail("rig sem metadata de hitboxes/hurtboxes: " + path)
		var bones: Array = sk.find_children("*", "Bone2D", true, false)
		for an in ap.get_animation_list():
			anims_total += 1
			var anim := ap.get_animation(an)
			ap.play(an)
			ap.pause()
			for k in 5:
				ap.seek(anim.length * k / 4.0, true)
				for b in bones:
					var p: Vector2 = rig.to_local(b.global_position)
					if not (is_finite(p.x) and is_finite(p.y)) or p.length() > 400.0:
						_fail("%s: osso %s fora do lugar em '%s' (%.2f)" % [path.get_file(), b.name, an, k / 4.0])
						break
		for strike in ["jab", "kick", "slam", "finisher"]:
			if ap.has_animation(strike) and not rig.get_meta("hitboxes", {}).has(strike):
				_fail("%s: sem hitbox do golpe %s" % [path.get_file(), strike])
		rig.queue_free()
	rig_report = {"rigs": paths.size(), "animacoes": anims_total, "rigs_com_erro": bad_rigs}
	_log("varredura dos rigs: %d rigs, %d animações" % [paths.size(), anims_total])
	if paths.size() != 79:
		_fail("esperava 79 rigs, achei %d" % paths.size())
	_next()


# =================== 2. Partidas ===================
func _next() -> void:
	run_idx += 1
	var sc := _scenarios()
	if run_idx >= sc.size() or (only > 0 and run_idx != only - 1):
		_finish()
		return
	var S = game.get_script()
	S.game_mode = "story"
	S.stage_idx = sc[run_idx][1]
	S.party = [{"char": sc[run_idx][0], "sets": [SET], "lives": 9, "score": 0}]
	S.skip_title = true
	S.rig_mode = true
	S.model_detail = true
	get_tree().call_deferred("reload_current_scene")


func _physics_process(delta: float) -> void:
	if run_idx < 0 or run_idx >= _scenarios().size() or game == null:
		return
	t_total += delta
	var r: Dictionary = Controls.remote[SET]
	var held := 0
	var vec := Vector2.ZERO
	match String(game.mode):
		"title", "select":
			pass
		"intro", "dialog", "stageclear":
			if press_cd <= 0.0:
				_press(r, "attack")
				press_cd = 0.4
			if game.mode == "stageclear":
				_end_scenario("fase concluída")
				return
		"gameover":
			_end_scenario("derrotado")
			return
		"play":
			t_play += delta
			var res := _play_policy(delta)
			held = res[0]
			vec = res[1]
			_check_rules()
			_maybe_shot()
	press_cd -= delta
	r.bits = held
	r.vec = vec
	Controls.net_update()
	if t_play >= (8.0 if quick else PLAY_TIME) or t_total >= MAX_TIME:
		_end_scenario("tempo")


func _bit(a: String) -> int:
	return 1 << Controls.ACTIONS.find(a)


func _press(r: Dictionary, a: String) -> void:
	var i := Controls.ACTIONS.find(a)
	r.counts[i] = int(r.counts[i]) + 1


## O jogador do robô: [botões segurados, direção].
func _play_policy(delta: float) -> Array:
	var r: Dictionary = Controls.remote[SET]
	var p = game.players[0] if not game.players.is_empty() else null
	if p == null or not is_instance_valid(p):
		return [0, Vector2.ZERO]
	seen_states[p.state] = true
	plan_t -= delta
	special_cd -= delta
	var held := 0
	var vec := Vector2.ZERO
	# alvo: inimigo vivo mais perto; senão uma caixa; senão segue para a direita
	var target = null
	var best := INF
	for e in game._alive_enemies():
		var d: float = e.position.distance_to(p.position)
		if d < best:
			best = d
			target = e
	if target == null:
		for c in get_tree().get_nodes_in_group("breakables"):
			if c.hp > 0 and c.position.distance_to(p.position) < best:
				best = c.position.distance_to(p.position)
				target = c
	# arma no chão por perto e mãos vazias: vai pegar
	var item = null
	if p.weapon.is_empty():
		for w in get_tree().get_nodes_in_group("weapons"):
			if w.position.distance_to(p.position) < 140.0:
				item = w
				break
	# ameaça: inimigo começando um golpe perto
	var threat := false
	for e in game._alive_enemies():
		if e.state == "attack" and e.state_time < float(e.attack.get("startup", 0.2)) and absf(e.position.x - p.position.x) < 95.0 and absf(e.position.y - p.position.y) < 24.0:
			threat = true
	branch = "defesa" if plan != "" and plan_t > 0.0 else ("arma" if item != null else ("sem_alvo" if target == null else ("caixa" if target.get("drop") != null else "luta")))
	if target != null:
		last_target_desc = "%s(hp %d) a dx=%.0f dy=%.0f" % [String(target.get("kind")) if target.get("kind") != null else "caixa", target.hp, target.position.x - p.position.x, target.position.y - p.position.y]
	else:
		last_target_desc = "-"
	counts["t_" + branch] = snappedf(float(counts.get("t_" + branch, 0.0)) + delta, 0.01)
	if threat and plan == "" and rng.randf() < 0.5:
		plan = "dodge" if rng.randf() < 0.35 else "block"
		plan_t = 0.35
	if plan != "" and plan_t > 0.0:
		held |= _bit("block")
		if plan == "dodge" and plan_t < 0.3 and p.state == "block":
			_press(r, "jump")  # BLOQUEIO + PULO = esquiva
			plan = "done"
		return [held, Vector2.ZERO]
	plan = ""
	if item != null:
		var to: Vector2 = item.position + Vector2(-p.facing * 18.0, 0) - p.position
		if to.length() > 10.0:
			vec = to.normalized()
		elif press_cd <= 0.0:
			_press(r, "attack")
			press_cd = 0.25
		return [held, vec]
	if target == null:
		return [held, Vector2(1, 0)]
	var side := -1.0 if target.position.x > p.position.x else 1.0
	var goal: Vector2 = target.position + Vector2(side * 46.0, 0)
	var to2: Vector2 = goal - p.position
	if to2.length() > 12.0:
		vec = Vector2(signf(to2.x) if absf(to2.x) > 8.0 else 0.0, clampf(to2.y / 30.0, -1.0, 1.0))
	if absf(target.position.x - p.position.x) < 80.0 and absf(target.position.y - p.position.y) < 16.0:
		vec.x = 0.0
		if vec.y == 0.0 and absf(target.position.x - p.position.x) > 5.0:
			vec.x = 0.25 * signf(target.position.x - p.position.x)  # vira para o alvo
		if press_cd <= 0.0:
			var roll := rng.randf()
			if not p.weapon.is_empty() and roll < 0.08:
				_press(r, "special")  # arremessa a arma
			elif special_cd <= 0.0 and roll < 0.2:
				_press(r, "special")
				special_cd = 6.0
			elif roll < 0.12:
				held |= _bit("up")
				_press(r, "attack")  # gancho
			elif roll < 0.2:
				_press(r, "jump")    # voadora: o soco vem no próximo toque
				press_cd = 0.12
				return [held, vec]
			else:
				_press(r, "attack")
			press_cd = rng.randf_range(0.1, 0.22)
	return [held, vec]


# =================== Regras conferidas a cada quadro ===================
func _check_rules() -> void:
	var fighters: Array = game.players + game._alive_enemies()
	for f in fighters:
		if not is_instance_valid(f):
			continue
		var tag := "%s (%s)" % [f.display_name, String(f.rig_scene_path).get_file()]
		if not (is_finite(f.position.x) and is_finite(f.position.y) and is_finite(f.height)):
			_fail("%s: posição inválida %s altura %s" % [tag, f.position, f.height])
			continue
		if f.position.y < game.DEPTH_MIN - 2.0 or f.position.y > game.DEPTH_MAX + 2.0:
			_fail("%s: fora do chão (y=%.1f, chão %.0f..%.0f)" % [tag, f.position.y, game.DEPTH_MIN, game.DEPTH_MAX])
		if f.position.x < -40.0 or f.position.x > game.STAGE_LEN + 40.0:
			_fail("%s: fora da fase (x=%.1f)" % [tag, f.position.x])
		if f.height < -0.5:
			_fail("%s: abaixo do chão (altura %.2f)" % [tag, f.height])
		if f.hp < 0 or f.hp > f.max_hp:
			_fail("%s: vida fora dos limites (%d/%d)" % [tag, f.hp, f.max_hp])
		if not f.state in KNOWN_STATES:
			_fail("%s: estado desconhecido '%s'" % [tag, f.state])
		if f.rig_ap != null:
			var an: String = f.rig_anim()[0]
			if not f.rig_ap.has_animation(an):
				_fail("%s: animação '%s' não existe no rig" % [tag, an])
		var hr: Rect2 = f.hurt_rect()
		if not (is_finite(hr.position.x) and is_finite(hr.size.y)) or hr.size.x <= 0.0 or hr.size.y <= 0.0:
			_fail("%s: hurtbox inválida %s" % [tag, hr])
	var cam: Camera2D = game.camera
	if not (is_finite(cam.position.x) and is_finite(cam.position.y) and is_finite(cam.zoom.x) and is_finite(cam.rotation)):
		_fail("câmera inválida")
	# inimigos derrubados
	var alive := {}
	for e in game._alive_enemies():
		alive[e.get_instance_id()] = true
	for id in prev_enemies:
		if not alive.has(id):
			counts["inimigos_derrubados"] = int(counts.get("inimigos_derrubados", 0)) + 1
	prev_enemies = alive
	_diary()


## Diário da partida: dano causado e recebido, defesa dos inimigos, armas pegas e chutadas, tipos vistos.
## Inimigo que some: deixa de ser desenhado dentro da tela, sai da tela depois de ter entrado, ou pula de lugar.
var enemy_pos := {}
var enemy_in := {}
var vanish_logs := 0


func _watch_vanish(e, id: int) -> void:
	var k := String(e.kind)
	var inside: bool = e.position.x > game.cam_left() + 4.0 and e.position.x < game.cam_right() - 4.0
	if enemy_pos.has(id):
		var jump: float = (e.position - Vector2(enemy_pos[id])).length()
		if jump > 40.0:
			_vanish("pulo", k, e, "andou %.0f px num quadro" % jump)
		if bool(enemy_in.get(id, false)) and not inside:
			_vanish("saiu_da_tela", k, e, "saiu da tela")
	if inside:
		enemy_in[id] = true
	elif not bool(enemy_in.get(id, false)):
		enemy_in[id] = false
	if not inside and bool(enemy_in.get(id, false)):
		enemy_in[id] = false
	enemy_pos[id] = e.position
	if inside and e.state != "dead" and e.invuln <= 0.0:
		var drawn := true
		if e.rig != null and game.rigs_enabled():
			drawn = e.rig.visible and e.rig.modulate.a > 0.05 and e.rig.is_visible_in_tree()
		if not e.is_visible_in_tree() or e.modulate.a < 0.05:
			drawn = false
		if not drawn:
			_vanish("invisivel", k, e, "vivo na tela mas sem desenho")


func _vanish(what: String, k: String, e, why: String) -> void:
	counts["%s_%s" % [what, k]] = int(counts.get("%s_%s" % [what, k], 0)) + 1
	if vanish_logs < 40:
		vanish_logs += 1
		print("[TESTBOT] SUMIU %s %s: %s | estado=%s agressivo=%s pos=(%.0f,%.0f) cam=[%.0f,%.0f] alvo_jog=(%.0f,%.0f)" % [what, k, why, e.state,
			str(e.aggressive), e.position.x, e.position.y, game.cam_left(), game.cam_right(),
			game.players[0].position.x if not game.players.is_empty() else 0.0, game.players[0].position.y if not game.players.is_empty() else 0.0])


func _diary() -> void:
	var p = game.players[0] if not game.players.is_empty() else null
	for e in game._alive_enemies():
		var id: int = e.get_instance_id()
		if not enemy_hp.has(id):
			counts["vistos_" + String(e.kind)] = int(counts.get("vistos_" + String(e.kind), 0)) + 1
		elif e.hp < int(enemy_hp[id]):
			counts["dano_causado"] = int(counts.get("dano_causado", 0)) + int(enemy_hp[id]) - e.hp
		if e.state != String(enemy_state.get(id, "")):
			if e.state == "block":
				counts["inimigo_bloqueou"] = int(counts.get("inimigo_bloqueou", 0)) + 1
			elif e.state == "dodge":
				counts["inimigo_esquivou"] = int(counts.get("inimigo_esquivou", 0)) + 1
		enemy_hp[id] = e.hp
		enemy_state[id] = e.state
		_watch_vanish(e, id)
	for w in get_tree().get_nodes_in_group("weapons"):
		var id2: int = w.get_instance_id()
		var sp: float = w.vel.length()
		if sp > 200.0 and float(item_speed.get(id2, 0.0)) < 60.0:
			counts["armas_chutadas"] = int(counts.get("armas_chutadas", 0)) + 1
		item_speed[id2] = sp
	if p != null and is_instance_valid(p):
		var has: bool = not p.weapon.is_empty()
		if has and not had_weapon:
			counts["armas_pegas"] = int(counts.get("armas_pegas", 0)) + 1
		had_weapon = has
		if my_hp >= 0 and p.hp < my_hp:
			counts["dano_recebido"] = int(counts.get("dano_recebido", 0)) + my_hp - p.hp
		my_hp = p.hp
		if trace == run_idx + 1:
			trace_t -= get_physics_process_delta_time()
			if trace_t <= 0.0:
				trace_t = 0.5
				var near_item := INF
				for w in get_tree().get_nodes_in_group("weapons"):
					near_item = minf(near_item, w.position.distance_to(p.position))
				_log("trace t=%.1f eu=(%.0f,%.0f) %s ramo=%s alvo=%s arma=%s item_mais_perto=%s inimigos=%d" % [
					t_play, p.position.x, p.position.y, p.state, branch, last_target_desc,
					p.weapon.get("name", "-"), "%.0f" % near_item if near_item < INF else "-", game._alive_enemies().size()])


func _maybe_shot() -> void:
	var at: Array = [6.0, 16.0] if not quick else [5.0]
	if shots_taken >= at.size() or t_play < at[shots_taken]:
		return
	shots_taken += 1
	var tex := get_viewport().get_texture()
	if tex == null:
		return
	var img := tex.get_image()
	if img == null or img.is_empty():
		return
	var sc: Array = _scenarios()[run_idx]
	var fn := "%s/partida%02d_%s_era%02d_%d.png" % [out_dir, run_idx + 1, String(game.characters[sc[0]].name).to_lower(), sc[1], shots_taken]
	img.save_png(_abs(fn))


func _end_scenario(why: String) -> void:
	var sc: Array = _scenarios()[run_idx]
	var p = game.players[0] if not game.players.is_empty() else null
	var res := {"partida": run_idx + 1, "lutador": game.characters[sc[0]].name, "era": sc[1], "fim": why,
		"tempo_de_luta": snappedf(t_play, 0.1), "pontos": p.score if p != null else 0,
		"vida": p.hp if p != null else 0, "estados": seen_states.keys()}
	res.merge(counts)
	results.append(res)
	# o que precisa ter acontecido numa partida de verdade
	var who := "partida %d (%s)" % [run_idx + 1, res.lutador]
	if t_play < 3.0:
		_fail("%s: não chegou a lutar (%s)" % [who, why])
	else:
		for need in [["som_w", "nenhum golpe cortou o ar"], ["som_i", "nenhum golpe acertou"], ["som_st", "nenhum passo tocou"]]:
			# sem vídeo (--headless) o rig não é desenhado e os passos (que leem o pé desenhado) não tocam
			if need[0] == "som_st" and DisplayServer.get_name() == "headless":
				continue
			if int(counts.get(need[0], 0)) == 0:
				_fail("%s: %s" % [who, need[1]])
	_log("fim da partida %d: %s" % [run_idx + 1, JSON.stringify(res)])
	_next()


# =================== 3. Relatório ===================
func _finish() -> void:
	var rep := {"ok": failures.is_empty(), "falhas": failures, "rigs": rig_report, "partidas": results,
		"duracao_s": snappedf((Time.get_ticks_msec() - started_ms) / 1000.0, 0.1),
		"godot": Engine.get_version_info().string}
	var txt := JSON.stringify(rep, "  ")
	var f := FileAccess.open(_abs(out_dir + "/relatorio.json"), FileAccess.WRITE)
	if f != null:
		f.store_string(txt)
		f.close()
	print("[TESTBOT] RELATORIO ", JSON.stringify(rep))
	_log("tudo passou" if failures.is_empty() else "%d falha(s)" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
