extends Node
## Efeitos sonoros sintetizados em tempo de execução (sem arquivos de áudio).
##
## Biblioteca:
##   w_*   som do golpe cortando o ar (um por tipo de golpe)
##   i_*   som do impacto (um por tipo de golpe / arma)
##   sp_*  som de início do golpe especial de cada lutador
##   + sons gerais (pulo, dano, queda, KO, menus, bloqueio, ÉON...)
## Os sons são gerados uma vez e guardados (static) para as próximas fases.

const RATE := 22050
static var streams := {}
var players: Array = []
var idx := 0
var hook: Callable  # online: o anfitrião repassa os sons (nome, tom) aos convidados


func _ready() -> void:
	for i in 14:
		var pl := AudioStreamPlayer.new()
		pl.volume_db = -6.0
		add_child(pl)
		players.append(pl)
	if streams.is_empty():
		_build_all()


# ============================ Reprodução ============================
## pitch: tom base (ex.: personagens grandes mais graves); pitch_var: variação aleatória.
func play(name: String, pitch_var: float = 0.08, pitch: float = 1.0) -> void:
	if not streams.has(name):
		return
	var final := pitch * (1.0 + randf_range(-pitch_var, pitch_var))
	if hook.is_valid():
		hook.call(name, final)
	play_exact(name, final)


func play_exact(name: String, pitch: float) -> void:
	if not streams.has(name):
		return
	var p: AudioStreamPlayer = players[idx]
	idx = (idx + 1) % players.size()
	p.stream = streams[name]
	p.pitch_scale = clampf(pitch, 0.4, 2.5)
	p.play()


# ============================ Síntese ============================
func _noise() -> float:
	return randf() * 2.0 - 1.0


func _gen(dur: float, f: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var b := PackedFloat32Array()
	b.resize(n)
	for i in n:
		var t := float(i) / RATE
		b[i] = f.call(t, t / dur)
	return _to_wav(b, 0.0)


func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * RATE))
	b.fill(0.0)
	return b


## Ruído filtrado (passa-faixa simples) com o corte variando de c0 a c1 Hz.
## env: "swell" (cresce e some: golpe no ar) ou "hit" (estalo que decai).
func _noise_band(b: PackedFloat32Array, start: float, dur: float, c0: float, c1: float, amp: float, env := "swell", am := 0.0, decay := 18.0) -> void:
	var s0 := int(start * RATE)
	var n := int(dur * RATE)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		if s0 + i >= b.size():
			break
		var p := float(i) / n
		var t := float(i) / RATE
		var cut := lerpf(c0, c1, p)
		var a := 1.0 - exp(-TAU * cut / RATE)
		lp += (_noise() - lp) * a
		lp2 += (lp - lp2) * a * 0.25  # tira os graves: fica uma faixa
		var e := sin(p * PI) if env == "swell" else exp(-t * decay)
		if am > 0.0:
			e *= 0.55 + 0.45 * sin(TAU * am * t)
		b[s0 + i] += (lp - lp2) * e * amp * 2.2


## Tom com variação de frequência (f0 -> f1), decaimento exponencial e forma de onda.
func _tone(b: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, amp: float, decay := 10.0, wave := "sine", attack := 0.002) -> void:
	var s0 := int(start * RATE)
	var n := int(dur * RATE)
	var ph := 0.0
	for i in n:
		if s0 + i >= b.size():
			break
		var p := float(i) / n
		var t := float(i) / RATE
		var f := lerpf(f0, f1, p)
		ph += f / RATE
		var x := ph - floorf(ph)
		var v := sin(TAU * x)
		match wave:
			"square": v = 1.0 if x < 0.5 else -1.0
			"tri": v = 4.0 * absf(x - 0.5) - 1.0
			"saw": v = 2.0 * x - 1.0
		var e := minf(1.0, t / attack) * exp(-t * decay)
		b[s0 + i] += v * e * amp


## Parciais inarmônicos (metal, sino, pandeiro).
func _ring(b: PackedFloat32Array, start: float, dur: float, freqs: Array, amp: float, decay := 8.0) -> void:
	for k in freqs.size():
		_tone(b, start, dur, freqs[k], freqs[k] * 0.995, amp / (1.0 + k * 0.6), decay * (1.0 + k * 0.5))


## Corda dedilhada (Karplus-Strong) com o tom mudando aos poucos (berimbau).
func _pluck(b: PackedFloat32Array, start: float, dur: float, freq: float, amp: float, bend := 0.0) -> void:
	var s0 := int(start * RATE)
	var n := int(dur * RATE)
	var period := int(RATE / freq)
	var line := PackedFloat32Array()
	line.resize(period)
	for i in period:
		line[i] = _noise()
	var pos := 0
	for i in n:
		if s0 + i >= b.size():
			break
		var nxt := (pos + 1) % period
		var v := line[pos]
		line[pos] = (line[pos] + line[nxt]) * 0.498
		pos = nxt
		if bend != 0.0 and i % 900 == 0 and period > 8:
			pos = (pos + int(bend)) % period
		b[s0 + i] += v * amp


func _to_wav(b: PackedFloat32Array, normalize_to := 0.85) -> AudioStreamWAV:
	var n := b.size()
	var gain := 1.0
	if normalize_to > 0.0:
		var peak := 0.001
		for i in n:
			peak = maxf(peak, absf(b[i]))
		gain = normalize_to / peak
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(b[i] * gain, -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


func _store(name: String, b: PackedFloat32Array, level := 0.85) -> void:
	streams[name] = _to_wav(b, level)


# ============================ Biblioteca ============================
func _build_all() -> void:
	# --- sons gerais (os mesmos de antes) ---
	streams["hit"] = _gen(0.09, func(t, p): return _noise() * pow(1.0 - p, 2.0) * 0.7 + sin(TAU * 110.0 * t) * (1.0 - p) * 0.6)
	streams["heavy"] = _gen(0.2, func(t, p): return _noise() * pow(1.0 - p, 3.0) * 0.8 + sin(TAU * (90.0 - 50.0 * p) * t) * (1.0 - p) * 0.9)
	streams["whoosh"] = _gen(0.11, func(_t, p): return _noise() * sin(p * PI) * 0.18)
	streams["jump"] = _gen(0.14, func(t, p): return sin(TAU * (250.0 + 400.0 * p) * t) * (1.0 - p) * 0.3)
	streams["hurt"] = _gen(0.15, func(t, p): return signf(sin(TAU * (220.0 - 120.0 * p) * t)) * (1.0 - p) * 0.2)
	streams["thud"] = _gen(0.16, func(t, p): return sin(TAU * (70.0 - 30.0 * p) * t) * (1.0 - p) * 0.9 + _noise() * (1.0 - p) * 0.2)
	streams["break"] = _gen(0.25, func(t, p): return _noise() * pow(1.0 - p, 2.0) * 0.6 + sin(TAU * 180.0 * t) * (1.0 - p) * 0.3)
	streams["pickup"] = _gen(0.25, func(t, p): return signf(sin(TAU * [523.0, 659.0, 784.0, 1046.0][mini(int(p * 4.0), 3)] * t)) * 0.15 * (1.0 - p * 0.5))
	streams["ko"] = _gen(0.45, func(t, p): return signf(sin(TAU * (400.0 - 330.0 * p) * t)) * (1.0 - p) * 0.22)
	streams["special"] = _gen(0.3, func(t, p): return (_noise() * 0.3 + sin(TAU * (150.0 + 300.0 * p) * t) * 0.4) * sin(p * PI))
	streams["roar"] = _gen(0.5, func(t, p): return (signf(sin(TAU * (80.0 + sin(t * 40.0) * 10.0) * t)) * 0.25 + _noise() * 0.15) * sin(p * PI))
	streams["go"] = _gen(0.3, func(t, p): return signf(sin(TAU * (660.0 if p < 0.5 else 880.0) * t)) * 0.15)
	streams["start"] = _gen(0.6, func(t, p): return (sin(TAU * 262.0 * t) + sin(TAU * 330.0 * t) + sin(TAU * 392.0 * t)) * 0.18 * (1.0 - p))

	# --- golpes cortando o ar ---
	var b := _buf(0.08); _noise_band(b, 0, 0.08, 2600, 5200, 1.0); _store("w_jab", b, 0.35)
	b = _buf(0.12); _noise_band(b, 0, 0.12, 1500, 3600, 1.0); _store("w_cross", b, 0.42)
	b = _buf(0.15); _noise_band(b, 0, 0.15, 900, 4200, 1.0); _store("w_upper", b, 0.42)
	b = _buf(0.18); _noise_band(b, 0, 0.18, 350, 900, 1.0); _tone(b, 0, 0.18, 120, 90, 0.25, 6.0); _store("w_kick", b, 0.5)
	b = _buf(0.2); _noise_band(b, 0, 0.2, 2200, 6000, 1.0); _tone(b, 0.05, 0.15, 2400, 3100, 0.12, 14.0); _store("w_blade", b, 0.45)
	b = _buf(0.24); _noise_band(b, 0, 0.24, 280, 800, 1.0); _store("w_blunt", b, 0.55)
	b = _buf(0.24); _noise_band(b, 0, 0.24, 1600, 250, 1.0); _store("w_slam", b, 0.55)
	b = _buf(0.34); _noise_band(b, 0, 0.34, 180, 600, 1.0, "swell", 22.0); _tone(b, 0, 0.34, 60, 80, 0.5, 4.0); _store("w_charge", b, 0.6)
	b = _buf(0.18); _noise_band(b, 0, 0.18, 1200, 2600, 1.0, "swell", 28.0); _store("w_throw", b, 0.45)
	b = _buf(0.32); _noise_band(b, 0, 0.32, 800, 2400, 1.0, "swell", 14.0); _store("w_spin", b, 0.55)

	# --- impactos ---
	b = _buf(0.07); _noise_band(b, 0, 0.07, 3000, 1500, 1.0, "hit", 0.0, 60.0); _tone(b, 0, 0.07, 240, 160, 0.7, 45.0); _store("i_jab", b, 0.6)
	b = _buf(0.12); _noise_band(b, 0, 0.1, 1600, 600, 0.45, "hit", 0.0, 45.0); _tone(b, 0, 0.12, 150, 90, 1.0, 26.0); _store("i_cross", b, 0.75)
	b = _buf(0.12); _noise_band(b, 0, 0.1, 4000, 2000, 1.0, "hit", 0.0, 35.0); _tone(b, 0, 0.12, 170, 260, 0.7, 26.0); _store("i_upper", b, 0.75)
	b = _buf(0.18); _noise_band(b, 0, 0.1, 900, 300, 0.35, "hit", 0.0, 40.0); _tone(b, 0, 0.18, 95, 55, 1.0, 15.0); _tone(b, 0, 0.18, 190, 110, 0.3, 22.0); _store("i_kick", b, 0.85)
	b = _buf(0.34); _noise_band(b, 0, 0.3, 1200, 200, 0.45, "hit", 0.0, 10.0); _tone(b, 0, 0.34, 70, 38, 1.0, 8.0); _store("i_slam", b, 0.9)
	b = _buf(0.24); _noise_band(b, 0, 0.18, 800, 250, 0.4, "hit", 0.0, 20.0); _tone(b, 0, 0.24, 80, 50, 1.0, 11.0); _tone(b, 0.03, 0.12, 300, 180, 0.3, 30.0, "square"); _store("i_charge", b, 0.9)
	b = _buf(0.32); _noise_band(b, 0, 0.06, 6000, 3500, 1.0, "hit", 0.0, 70.0); _ring(b, 0, 0.32, [2350.0, 3720.0, 5110.0], 0.5, 9.0); _store("i_blade", b, 0.7)
	b = _buf(0.2); _noise_band(b, 0, 0.05, 1500, 800, 0.6, "hit", 0.0, 60.0); _tone(b, 0, 0.2, 330, 210, 0.9, 22.0, "tri"); _tone(b, 0, 0.2, 660, 420, 0.25, 30.0); _store("i_wood", b, 0.8)
	b = _buf(0.45); _noise_band(b, 0, 0.05, 4000, 2000, 0.7, "hit", 0.0, 60.0); _ring(b, 0, 0.45, [523.0, 1170.0, 1873.0, 2701.0], 0.6, 6.0); _store("i_metal", b, 0.75)
	b = _buf(0.28); _tone(b, 0, 0.28, 1400, 180, 0.6, 9.0, "saw"); _noise_band(b, 0, 0.2, 5000, 1500, 0.8, "hit", 0.0, 14.0); _store("i_energy", b, 0.75)
	b = _buf(0.22); _noise_band(b, 0, 0.15, 2500, 900, 1.0, "hit", 0.0, 25.0); _tone(b, 0, 0.12, 400, 260, 0.4, 35.0, "tri"); _tone(b, 0.07, 0.12, 360, 240, 0.3, 40.0, "tri"); _store("i_thrown", b, 0.75)
	b = _buf(0.12); _ring(b, 0, 0.12, [1800.0, 2900.0], 0.6, 30.0); _noise_band(b, 0, 0.04, 3000, 2000, 0.5, "hit", 0.0, 80.0); _store("block", b, 0.6)

	# --- especiais: um som de identidade para cada lutador ---
	b = _buf(0.7); _pluck(b, 0, 0.7, 196.0, 1.0, 3.0); _tone(b, 0.0, 0.05, 900, 600, 0.3, 60.0, "tri"); _store("sp_mateus", b, 0.8)          # berimbau
	b = _buf(0.9); _ring(b, 0, 0.9, [1046.0, 2614.0, 4180.0], 0.8, 3.0); _store("sp_valentina", b, 0.6)                                       # sino do ringue
	b = _buf(0.45); _tone(b, 0, 0.45, 70, 55, 0.9, 4.0, "saw"); _noise_band(b, 0, 0.45, 200, 450, 0.3, "swell"); _store("sp_jake", b, 0.8)  # urro da luta-livre
	b = _buf(0.5); _tone(b, 0, 0.22, 2600, 2600, 0.5, 3.0, "square"); _tone(b, 0.24, 0.24, 3100, 3100, 0.5, 3.0, "square"); _store("sp_itzel", b, 0.45)  # apito da lucha libre
	b = _buf(0.5); _noise_band(b, 0, 0.5, 500, 1500, 1.0, "swell", 9.0); _tone(b, 0, 0.5, 90, 70, 0.5, 3.0); _store("sp_dmitri", b, 0.7)    # moinho pesado
	b = _buf(0.5)
	for k in 5:
		_ring(b, k * 0.08, 0.18, [3800.0, 5300.0, 7100.0], 0.4, 22.0)
		_noise_band(b, k * 0.08, 0.06, 7000, 5000, 0.4, "hit", 0.0, 60.0)
	_store("sp_oksana", b, 0.5)                                                                                                              # pandeiro
	b = _buf(0.5); _noise_band(b, 0, 0.5, 1200, 3800, 1.0, "swell", 18.0); _store("sp_luca", b, 0.6)                                          # tornado
	b = _buf(0.3); _noise_band(b, 0, 0.12, 3500, 6500, 1.0); _noise_band(b, 0.13, 0.12, 3500, 6500, 1.0); _store("sp_amelie", b, 0.5)      # duas chicotadas
	b = _buf(0.6); _tone(b, 0, 0.35, 180, 620, 0.45, 1.5, "saw"); _tone(b, 0.33, 0.27, 620, 150, 0.7, 8.0, "square"); _noise_band(b, 0.33, 0.27, 4000, 900, 0.8, "hit", 0.0, 10.0); _store("sp_kai", b, 0.7)  # energia carrega e dispara
	b = _buf(0.5); _tone(b, 0, 0.5, 700, 2600, 0.6, 2.0, "tri"); _tone(b, 0.05, 0.45, 1400, 3600, 0.25, 3.0); _store("sp_mei", b, 0.55)   # pio da fênix
	b = _buf(0.7); _noise_band(b, 0, 0.7, 6000, 300, 1.0, "hit", 0.0, 5.0); _tone(b, 0.02, 0.6, 55, 35, 0.9, 4.0); _store("sp_kofi", b, 0.9)  # trovão
	b = _buf(0.8); _tone(b, 0, 0.8, 42, 34, 1.0, 2.5); _noise_band(b, 0, 0.8, 120, 350, 0.35, "swell", 16.0); _store("sp_amara", b, 0.9)   # terremoto
	b = _buf(0.6); _tone(b, 0, 0.25, 65, 45, 1.0, 12.0); _tone(b, 0.18, 0.4, 140, 120, 0.6, 4.0, "saw"); _noise_band(b, 0.18, 0.4, 250, 600, 0.25, "swell"); _store("sp_tama", b, 0.85)  # tambor e brado
	b = _buf(0.6); _tone(b, 0, 0.18, 880, 880, 0.5, 2.0, "square"); _tone(b, 0.18, 0.18, 988, 988, 0.5, 2.0, "square"); _tone(b, 0.36, 0.24, 1174, 1100, 0.5, 3.0, "square"); _store("sp_kirra", b, 0.4)  # flauta do muay thai

	# --- ÉON e outros ---
	b = _buf(0.35); _tone(b, 0, 0.35, 300, 1200, 0.5, 4.0, "tri"); _ring(b, 0, 0.35, [1500.0, 2250.0], 0.3, 6.0); _store("orb", b, 0.55)
	b = _buf(0.9); _tone(b, 0, 0.9, 900, 120, 0.6, 1.5, "saw"); _noise_band(b, 0, 0.9, 200, 4000, 0.7, "swell"); _store("warp", b, 0.8)
	b = _buf(0.6); _tone(b, 0, 0.6, 50, 38, 1.0, 3.5); _noise_band(b, 0, 0.6, 150, 450, 0.35, "hit", 0.0, 4.0); _store("quake", b, 0.9)


# ============================ Escolha do som ============================
## Som do golpe cortando o ar, conforme a pose do ataque e a arma.
static func swing_for(atk: Dictionary, weapon: Dictionary) -> String:
	if atk.get("weapon", false) and not weapon.is_empty():
		return "w_blade" if weapon.get("kind", "") == "blade" else "w_blunt"
	match atk.get("pose", ""):
		"jab": return "w_jab"
		"cross": return "w_cross"
		"upper": return "w_upper"
		"kick", "jumpkick": return "w_kick"
		"slam": return "w_slam"
		"charge", "dive": return "w_charge"
		"throw": return "w_throw"
		"special": return "w_spin"
		"swing": return "w_blunt"
	return "w_cross"


const METAL_SHAPES := ["wrench", "pipe", "mace", "shovel", "energystaff"]


## Som do impacto, conforme o golpe, a arma ou a origem (energia, arma arremessada).
static func impact_for(atk: Dictionary, weapon: Dictionary) -> String:
	if atk.get("energy", false):
		return "i_energy"
	if atk.get("thrown", false):
		return "i_thrown"
	if atk.get("weapon", false) and not weapon.is_empty():
		if weapon.get("kind", "") == "blade":
			return "i_blade"
		return "i_metal" if weapon.get("shape", "") in METAL_SHAPES else "i_wood"
	match atk.get("pose", ""):
		"jab": return "i_jab"
		"cross": return "i_cross"
		"upper": return "i_upper"
		"kick", "jumpkick", "dive": return "i_kick"
		"slam": return "i_slam"
		"charge": return "i_charge"
		"special": return "i_kick"
	return "i_cross" if atk.get("heavy", false) else "i_jab"


## Tom do corpo: personagens maiores soam mais graves.
static func body_pitch(scale: float) -> float:
	return 1.0 / sqrt(maxf(scale, 0.5))
