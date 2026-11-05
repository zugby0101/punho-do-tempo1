extends RefCounted
## Controles para até 4 jogadores locais.
## Cada "conjunto" de entrada (4 no teclado + 4 controles) gera ações próprias,
## como "k1_attack" ou "j2_left". Cada jogador lê um ou mais conjuntos.
## As ações globais (move_left, attack, start, pause...) servem para os menus.

const ACTIONS := ["left", "right", "up", "down", "attack", "jump", "special", "start"]
const KEYBOARD_SETS := ["k1", "k2", "k3", "k4"]
const JOY_SETS := ["j0", "j1", "j2", "j3"]

const KEYS := {
	"k1": {"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S],
		"attack": [KEY_J], "jump": [KEY_K, KEY_SPACE], "special": [KEY_L], "start": [KEY_ENTER]},
	"k2": {"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN],
		"attack": [KEY_COMMA], "jump": [KEY_PERIOD], "special": [KEY_SLASH], "start": [KEY_BACKSPACE]},
	"k3": {"left": [KEY_F], "right": [KEY_H], "up": [KEY_T], "down": [KEY_G],
		"attack": [KEY_Z], "jump": [KEY_X], "special": [KEY_C], "start": [KEY_V]},
	"k4": {"left": [KEY_KP_4], "right": [KEY_KP_6], "up": [KEY_KP_8], "down": [KEY_KP_5],
		"attack": [KEY_KP_7], "jump": [KEY_KP_9], "special": [KEY_KP_ADD], "start": [KEY_KP_ENTER]},
}
const JOY_BUTTONS := {
	"left": [JOY_BUTTON_DPAD_LEFT], "right": [JOY_BUTTON_DPAD_RIGHT],
	"up": [JOY_BUTTON_DPAD_UP], "down": [JOY_BUTTON_DPAD_DOWN],
	"attack": [JOY_BUTTON_X], "jump": [JOY_BUTTON_A], "special": [JOY_BUTTON_Y, JOY_BUTTON_B],
	"start": [JOY_BUTTON_START],
}
const JOY_AXES := {
	"left": [JOY_AXIS_LEFT_X, -1.0], "right": [JOY_AXIS_LEFT_X, 1.0],
	"up": [JOY_AXIS_LEFT_Y, -1.0], "down": [JOY_AXIS_LEFT_Y, 1.0],
}
const GLOBAL := {
	"move_left": "left", "move_right": "right", "move_up": "up", "move_down": "down",
	"attack": "attack", "jump": "jump", "special": "special", "start": "start",
}


# Jogadores online (só no anfitrião): "n1".."n3" -> estado dos comandos recebidos
static var remote := {}


static func all_sets() -> Array:
	return KEYBOARD_SETS + JOY_SETS


## Conjuntos que podem entrar na partida (locais + online).
static func join_sets() -> Array:
	return all_sets() + remote.keys()


static func new_remote() -> Dictionary:
	return {"bits": 0, "counts": [0, 0, 0, 0, 0, 0, 0, 0], "last": [0, 0, 0, 0, 0, 0, 0, 0], "just": 0, "vec": Vector2.ZERO}


static func set_remote(set_name: String, data: Array) -> void:
	if not remote.has(set_name) or data.size() < 4:
		return
	var r: Dictionary = remote[set_name]
	r.bits = int(data[0])
	r.counts = data[1]
	r.vec = Vector2(float(data[2]), float(data[3])).limit_length(1.0)


## Chamado uma vez por quadro no anfitrião: detecta toques novos dos convidados.
static func net_update() -> void:
	for n in remote:
		var r: Dictionary = remote[n]
		var j := 0
		for i in ACTIONS.size():
			if int(r.counts[i]) > int(r.last[i]):
				j |= 1 << i
		r.just = j
		r.last = r.counts.duplicate()


static func any_remote_just(actions: Array) -> bool:
	return who_pressed(actions, remote.keys()) != "" if not remote.is_empty() else false


static func setup() -> void:
	if InputMap.has_action("k1_attack"):
		return  # já registrado (cena recarregada)
	for set_name in all_sets():
		for a in ACTIONS:
			var action: String = set_name + "_" + a
			InputMap.add_action(action, 0.35)
			for ev in _events(set_name, a, int(set_name[1]) if set_name[0] == "j" else -1):
				InputMap.action_add_event(action, ev)
	# Ações globais dos menus: qualquer teclado e qualquer controle
	for g in GLOBAL:
		var a: String = GLOBAL[g]
		InputMap.add_action(g, 0.35)
		for set_name in KEYBOARD_SETS:
			for ev in _events(set_name, a, -1):
				InputMap.action_add_event(g, ev)
		for ev in _events("j", a, -1):
			InputMap.action_add_event(g, ev)
	# Teclas do modo online (no título)
	for pair in [["net_host", KEY_O], ["net_join", KEY_I]]:
		InputMap.add_action(pair[0])
		var kev := InputEventKey.new()
		kev.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0], kev)
	InputMap.add_action("pause")
	for k in [KEY_ESCAPE, KEY_P]:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event("pause", ev)
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_BACK
	jb.device = -1
	InputMap.action_add_event("pause", jb)


static func _events(set_name: String, a: String, device: int) -> Array:
	var out: Array = []
	if set_name[0] == "k":
		for k in KEYS[set_name][a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			out.append(ev)
	else:
		for b in JOY_BUTTONS[a]:
			var jb := InputEventJoypadButton.new()
			jb.button_index = b
			jb.device = device
			out.append(jb)
		if JOY_AXES.has(a):
			var jm := InputEventJoypadMotion.new()
			jm.axis = JOY_AXES[a][0]
			jm.axis_value = JOY_AXES[a][1]
			jm.device = device
			out.append(jm)
	return out


static func pressed(sets: Array, a: String) -> bool:
	for s in sets:
		if remote.has(s):
			if remote[s].bits & (1 << ACTIONS.find(a)):
				return true
		elif Input.is_action_pressed(s + "_" + a):
			return true
	return false


static func just(sets: Array, a: String) -> bool:
	for s in sets:
		if remote.has(s):
			if remote[s].just & (1 << ACTIONS.find(a)):
				return true
		elif Input.is_action_just_pressed(s + "_" + a):
			return true
	return false


static func strength(sets: Array, a: String) -> float:
	var v := 0.0
	for s in sets:
		if remote.has(s):
			var vec: Vector2 = remote[s].vec
			match a:
				"left": v = maxf(v, -vec.x)
				"right": v = maxf(v, vec.x)
				"up": v = maxf(v, -vec.y)
				"down": v = maxf(v, vec.y)
		else:
			v = maxf(v, Input.get_action_strength(s + "_" + a))
	return v


static func vector(sets: Array) -> Vector2:
	var v := Vector2(strength(sets, "right") - strength(sets, "left"), strength(sets, "down") - strength(sets, "up"))
	return v.limit_length(1.0)


## Retorna o conjunto que acabou de apertar alguma das ações, ou "".
static func who_pressed(actions: Array, among: Array = []) -> String:
	var pool := among if not among.is_empty() else all_sets()
	for s in pool:
		for a in actions:
			if just([s], a):
				return s
	return ""


## Descrição curta de um conjunto, para a tela de seleção.
static func describe(set_name: String) -> String:
	match set_name:
		"k1": return "Teclado: WASD + J K L"
		"k2": return "Teclado: Setas + , . /"
		"k3": return "Teclado: TFGH + Z X C"
		"k4": return "Teclado: Numpad 8456 + 7 9 +"
	if set_name[0] == "n":
		return "Jogador online"
	return "Controle %d" % (int(set_name[1]) + 1)
