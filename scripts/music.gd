extends Node
## Trilha sonora gerada por algoritmo, em tempo de execução.
## Cada era tem tempo, escala, instrumentos e ritmo próprios; a melodia é
## composta a partir de uma semente fixa, então a música de cada fase é sempre a mesma.
## Tudo é original (não usa nenhuma gravação ou composição de terceiros).
## A geração roda numa thread para não travar o jogo.

const RATE := 22050
const W_SINE := 0
const W_SQUARE := 1
const W_PULSE := 2
const W_SAW := 3
const W_TRI := 4

static var cache := {}  # chave -> AudioStreamWAV (sobrevive à troca de fase)

var player: AudioStreamPlayer
var thread: Thread
var queue: Array = []  # [chave, estilo, semente, intenso]
var want := ""
var current := ""


func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.volume_db = -9.0
	add_child(player)


## Pede uma música; se ainda não foi gerada, entra na fila e toca quando ficar pronta.
func play(style: String, seed_val: int, intense := false) -> void:
	var key := _key(style, seed_val, intense)
	want = key
	if current == key and player.playing:
		return
	if cache.has(key):
		_start(key)
	else:
		prefetch(style, seed_val, intense, true)


## Gera uma música antecipadamente (sem tocar).
func prefetch(style: String, seed_val: int, intense := false, front := false) -> void:
	var key := _key(style, seed_val, intense)
	if cache.has(key):
		return
	for q in queue:
		if q[0] == key:
			return
	var item := [key, style, seed_val, intense]
	if front:
		queue.push_front(item)
	else:
		queue.append(item)


func stop() -> void:
	want = ""
	current = ""
	player.stop()


func _key(style: String, seed_val: int, intense: bool) -> String:
	return "%s:%d:%s" % [style, seed_val, "boss" if intense else "normal"]


func _start(key: String) -> void:
	current = key
	player.stream = cache[key]
	player.play()


func _process(_delta: float) -> void:
	if thread != null and not thread.is_alive():
		var res: Array = thread.wait_to_finish()
		thread = null
		cache[res[0]] = res[1]
		if res[0] == want:
			_start(res[0])
	if thread == null and not queue.is_empty():
		if not threads_ok():
			_process_no_threads()
			return
		var item: Array = queue.pop_front()
		if not cache.has(item[0]):
			thread = Thread.new()
			thread.start(_worker.bind(item))


## Na versão web (sem threads, para rodar em qualquer navegador e no GitHub Pages) não dá para
## gerar em segundo plano: gera uma música por vez no próprio quadro, e só a que vai tocar agora
## (as pré-carregadas esperam), para a pausa acontecer uma vez só, na troca de fase.
static func threads_ok() -> bool:
	return not OS.has_feature("web") or OS.has_feature("threads")


func _process_no_threads() -> void:
	for k in queue.size():
		var item: Array = queue[k]
		if item[0] != want:
			continue
		queue.remove_at(k)
		if not cache.has(item[0]):
			cache[item[0]] = generate(item[1], item[2], item[3])
		_start(item[0])
		return


func _worker(item: Array) -> Array:
	return [item[0], generate(item[1], item[2], item[3])]


func _exit_tree() -> void:
	if thread != null:
		thread.wait_to_finish()


# ============================ COMPOSIÇÃO ============================

## Definição musical de cada era.
static func style_def(style: String) -> Dictionary:
	var minor := [0, 2, 3, 5, 7, 8, 10]
	var major := [0, 2, 4, 5, 7, 9, 11]
	match style:
		"stone":
			return {"bpm": 96, "root": 45, "scale": [0, 3, 5, 7, 10], "prog": [0, 0, 3, 2],
				"lead": W_SINE, "vib": true, "lead_oct": 2, "density": 0.5,
				"bass": W_TRI, "bass_pat": "x.......x.......", "bass_mode": "root",
				"drums": {"tom": "x..x..x.x..x.x..", "taiko": "x.......x.......", "shaker": "..x...x...x...x."}}
		"crusade":
			return {"bpm": 108, "root": 50, "scale": [0, 1, 4, 5, 7, 8, 10], "prog": [0, 6, 5, 0],
				"lead": W_PULSE, "vib": true, "lead_oct": 1, "density": 0.6,
				"bass": W_SQUARE, "bass_pat": "x...x...x...x...", "bass_mode": "root",
				"drums": {"tom": "x..x..x...x.x...", "shaker": "x.x.x.x.x.x.x.x.", "snare": "............x..."}}
		"japan":
			return {"bpm": 88, "root": 50, "scale": [0, 1, 5, 7, 8], "prog": [0, 0, 3, 2],
				"lead": W_TRI, "pluck": true, "lead_oct": 1, "density": 0.6,
				"arp": W_TRI, "arp_rate": 2,
				"bass": W_TRI, "bass_pat": "x.......x.......", "bass_mode": "root",
				"drums": {"taiko": "x.....x.x.......", "clank": ".....x.......x.."}}
		"ships":
			return {"bpm": 124, "root": 48, "scale": major, "prog": [0, 3, 4, 0],
				"lead": W_PULSE, "vib": true, "lead_oct": 1, "density": 0.65,
				"bass": W_SQUARE, "bass_pat": "x...x...x...x...", "bass_mode": "oompah",
				"drums": {"kick": "x.......x.......", "snare": "....x.......x...", "hat": "..x...x...x...x."}}
		"industrial":
			return {"bpm": 122, "root": 45, "scale": minor, "prog": [0, 0, 5, 4],
				"lead": W_SAW, "lead_oct": 1, "density": 0.5,
				"bass": W_SQUARE, "bass_pat": "x.x.x.x.x.x.x.x.", "bass_mode": "root",
				"drums": {"kick": "x...x...x...x...", "clank": "..x...x...x..x.x", "snare": "....x.......x...", "hat": "x.x.x.x.x.x.x.x."}}
		"ww1":
			return {"bpm": 104, "root": 46, "scale": [0, 2, 3, 5, 7, 8, 11], "prog": [0, 3, 4, 0],
				"lead": W_SAW, "vib": true, "lead_oct": 1, "density": 0.45, "pad": W_TRI,
				"bass": W_TRI, "bass_pat": "x.......x...x...", "bass_mode": "root",
				"drums": {"snare": "x.xxx.x.x.xxx.x.", "kick": "x.......x......."}}
		"ww2":
			return {"bpm": 112, "root": 43, "scale": minor, "prog": [0, 5, 3, 4],
				"lead": W_SAW, "vib": true, "lead_oct": 1, "density": 0.5, "pad": W_TRI,
				"bass": W_SQUARE, "bass_pat": "x...x...x...x...", "bass_mode": "root",
				"drums": {"kick": "x.......x.x.....", "snare": "....x.......x.xx", "hat": "x.x.x.x.x.x.x.x."}}
		"coldwar":
			return {"bpm": 100, "root": 45, "scale": [0, 3, 5, 6, 7, 10], "prog": [0, 0, 3, 2],
				"lead": W_TRI, "vib": true, "lead_oct": 1, "density": 0.5,
				"bass": W_SQUARE, "bass_pat": "x.x.x.x.x.x.x.x.", "bass_mode": "walk",
				"drums": {"kick": "x.......x.......", "snare": "....x.......x...", "hat": "x.xxx.xxx.xxx.xx"}}
		"utopia":
			return {"bpm": 116, "root": 48, "scale": [0, 2, 4, 6, 7, 9, 11], "prog": [0, 1, 5, 4],
				"lead": W_SINE, "bell": true, "lead_oct": 2, "density": 0.55, "pad": W_SINE,
				"arp": W_TRI, "arp_rate": 1,
				"bass": W_TRI, "bass_pat": "x.......x.x.....", "bass_mode": "root",
				"drums": {"kick": "x.......x.......", "snare": "....x.......x...", "hat": "x.x.x.x.x.x.x.x."}}
		"dystopia":
			return {"bpm": 134, "root": 40, "scale": [0, 1, 3, 5, 7, 8, 10], "prog": [0, 1, 0, 6],
				"lead": W_PULSE, "lead_oct": 2, "density": 0.45,
				"bass": W_SAW, "bass_pat": "x.xx.xx.x.xx.x.x", "bass_mode": "root",
				"drums": {"kick": "x..x..x...x..x..", "clank": "....x.......x...", "snare": "....x.......x...", "hat": "xxxxxxxxxxxxxxxx"}}
		"apocalypse":
			return {"bpm": 146, "root": 38, "scale": [0, 1, 3, 5, 6, 8, 10], "prog": [0, 1, 4, 1],
				"lead": W_SQUARE, "lead_oct": 2, "density": 0.55, "pad": W_SAW,
				"bass": W_SAW, "bass_pat": "x.x.x.x.x.x.x.x.", "bass_mode": "root",
				"drums": {"kick": "x.x.x.x.x.x.x.x.", "snare": "....x.......x...", "tom": "............xxxx", "hat": "x.x.x.x.x.x.x.x."}}
		"void":
			return {"bpm": 132, "root": 41, "scale": [0, 2, 4, 6, 8, 10], "prog": [0, 1, 3, 2],
				"lead": W_SINE, "bell": true, "lead_oct": 2, "density": 0.55, "pad": W_SAW,
				"arp": W_TRI, "arp_rate": 1,
				"bass": W_SAW, "bass_pat": "x..x..x.x..x..x.", "bass_mode": "octave",
				"drums": {"kick": "x...x...x...x...", "snare": "....x.......x...", "tom": "..........x.x.xx", "hat": "x.x.x.x.x.x.x.x."}}
		"title":
			return {"bpm": 120, "root": 48, "scale": major, "prog": [0, 5, 3, 4],
				"lead": W_SQUARE, "vib": true, "lead_oct": 1, "density": 0.6,
				"arp": W_TRI, "arp_rate": 1,
				"bass": W_SQUARE, "bass_pat": "x.x.x.x.x.x.x.x.", "bass_mode": "octave",
				"drums": {"kick": "x...x...x...x...", "snare": "....x.......x...", "hat": "..x...x...x...x."}}
	# "modern" (tempo atual): synthwave
	return {"bpm": 128, "root": 45, "scale": minor, "prog": [0, 5, 2, 6],
		"lead": W_SAW, "lead_oct": 1, "density": 0.55,
		"arp": W_SQUARE, "arp_rate": 1,
		"bass": W_SQUARE, "bass_pat": "x.x.x.x.x.x.x.x.", "bass_mode": "octave",
		"drums": {"kick": "x...x...x...x...", "snare": "....x.......x...", "hat": "..x...x...x...x."}}


static func _midi_hz(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


static func _deg_midi(deg: int, root: int, scale: Array) -> int:
	var sz := scale.size()
	return root + int(scale[posmod(deg, sz)]) + 12 * int(floor(float(deg) / sz))


static func generate(style: String, seed_val: int, intense: bool) -> AudioStreamWAV:
	var d := style_def(style)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val * 7919 + 13
	var bpm: float = float(d.bpm) * (1.1 if intense else 1.0)
	var step := 60.0 / bpm / 4.0  # semicolcheia
	var bars := 8
	var n := int(bars * 16 * step * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	buf.fill(0.0)
	var scale: Array = d.scale
	var root: int = d.root
	var sz := scale.size()
	var prog: Array = d.prog

	# --- Melodia: frase A (4 compassos) + frase B (variação) ---
	var lead_oct: int = d.get("lead_oct", 1) + (1 if intense else 0)
	var density: float = float(d.density) + (0.15 if intense else 0.0)
	var phrase_a := _compose(rng, prog, sz, density)
	var phrase_b := phrase_a.duplicate(true)
	var tail := _compose(rng, prog, sz, density)
	for j in range(16, 32):
		phrase_b[j] = tail[j]
	var melody := phrase_a + phrase_b  # 64 colcheias
	var lead_wave: int = d.lead
	var i := 0
	while i < melody.size():
		var deg = melody[i]
		if deg == null or deg == -999:
			i += 1
			continue
		var length := 1
		while i + length < melody.size() and melody[i + length] == -999:
			length += 1
		var t0 := i * 2 * step
		var dur := length * 2 * step * 0.92
		var midi := _deg_midi(int(deg), root + 12 * lead_oct, scale)
		var decay := 0.0
		if d.get("pluck", false):
			decay = 5.0
		elif d.get("bell", false):
			decay = 3.0
		_tone(buf, t0, dur, _midi_hz(midi), lead_wave, 0.2, 0.01, 0.05, d.get("vib", false), decay)
		i += length

	# --- Acordes por compasso ---
	for bar in bars:
		var chord_deg: int = prog[bar % prog.size()]
		var bar_t := bar * 16 * step
		var tones := [chord_deg, chord_deg + 2, chord_deg + 4]
		# Pad
		if d.has("pad"):
			for td in tones:
				_tone(buf, bar_t, 16 * step, _midi_hz(_deg_midi(td, root + 12, scale)), d.pad, 0.05, 0.2, 0.2, false, 0.0)
		# Arpejo
		if d.has("arp"):
			var rate: int = d.arp_rate
			var k := 0
			for s in range(0, 16, rate):
				var td: int = tones[k % 3] + (sz if (k / 3) % 2 == 1 else 0)
				_tone(buf, bar_t + s * step, rate * step * 0.8, _midi_hz(_deg_midi(td, root + 24, scale)), d.arp, 0.07, 0.005, 0.03, false, 6.0)
				k += 1
		# Baixo
		var pat: String = d.bass_pat
		var hit := 0
		for s in 16:
			if pat[s] != "x":
				continue
			var bd := chord_deg
			match d.bass_mode:
				"oompah":
					bd = chord_deg + (4 if hit % 2 == 1 else 0)
				"octave":
					bd = chord_deg + (sz if hit % 2 == 1 else 0)
				"walk":
					bd = chord_deg + [0, 2, 4, 2][hit % 4]
			var blen := 1
			while s + blen < 16 and pat[s + blen] != "x":
				blen += 1
			_tone(buf, bar_t + s * step, blen * step * 0.85, _midi_hz(_deg_midi(bd, root - 12, scale)), d.bass, 0.24, 0.005, 0.04, false, 0.0)
			hit += 1
		# Bateria
		var drums: Dictionary = d.drums
		for kind in drums:
			var dp: String = drums[kind]
			for s in 16:
				if dp[s] == "x":
					_drum(buf, bar_t + s * step, kind, rng)
		if intense:
			for s in 16:
				_drum(buf, bar_t + s * step, "hat", rng)
				if s % 4 == 2:
					_drum(buf, bar_t + s * step, "kick", rng)
			if bar % 2 == 1:
				for s in range(12, 16):
					_drum(buf, bar_t + s * step, "snare", rng)

	return _finish(buf)


## Compõe 4 compassos de colcheias (32 notas). null = pausa, -999 = sustentar.
static func _compose(rng: RandomNumberGenerator, prog: Array, sz: int, density: float) -> Array:
	var out: Array = []
	var cur := 0
	for bar in 4:
		var chord: int = prog[bar % prog.size()]
		for e in 8:
			var strong := e % 4 == 0
			if not strong and rng.randf() > density:
				out.append(null if rng.randf() < 0.5 or out.is_empty() else -999)
				continue
			if strong:
				# notas do acorde nos tempos fortes
				var tones := [chord, chord + 2, chord + 4, chord + sz]
				var best: int = tones[0]
				for tn in tones:
					if absi(tn - cur) < absi(best - cur):
						best = tn
				cur = best if rng.randf() < 0.75 else tones[rng.randi() % tones.size()]
			else:
				cur += [-2, -1, -1, 1, 1, 2][rng.randi() % 6]
			cur = clampi(cur, -2, sz + 4)
			out.append(cur)
	# termina a frase na tônica do último acorde
	out[28] = prog[3 % prog.size()]
	out[29] = -999
	out[30] = -999
	out[31] = null
	return out


static func _tone(buf: PackedFloat32Array, start: float, dur: float, freq: float, wave: int, vol: float,
		attack: float, release: float, vib: bool, decay: float) -> void:
	var n := buf.size()
	var s0 := int(start * RATE)
	var length := int(dur * RATE)
	var inc := freq / RATE
	var phase := 0.0
	var inv_a := 1.0 / maxf(attack, 0.0001)
	var inv_r := 1.0 / maxf(release, 0.0001)
	for k in length:
		var t := float(k) / RATE
		var env := minf(1.0, t * inv_a) * minf(1.0, (dur - t) * inv_r)
		if decay > 0.0:
			env *= exp(-t * decay)
		if vib:
			phase += inc * (1.0 + 0.006 * sin(TAU * 5.5 * t) * minf(1.0, t * 3.0))
		else:
			phase += inc
		var p := phase - floorf(phase)
		var v := 0.0
		if wave == W_SINE:
			v = sin(TAU * p)
		elif wave == W_SQUARE:
			v = 0.7 if p < 0.5 else -0.7
		elif wave == W_PULSE:
			v = 0.7 if p < 0.25 else -0.7
		elif wave == W_SAW:
			v = (2.0 * p - 1.0) * 0.7
		else:
			v = 4.0 * absf(p - 0.5) - 1.0
		buf[(s0 + k) % n] += v * env * vol


static func _drum(buf: PackedFloat32Array, start: float, kind: String, rng: RandomNumberGenerator) -> void:
	var n := buf.size()
	var s0 := int(start * RATE)
	var dur := 0.2
	match kind:
		"hat": dur = 0.05
		"shaker": dur = 0.08
		"clank": dur = 0.12
		"taiko": dur = 0.5
		"tom": dur = 0.3
	var length := int(dur * RATE)
	var phase := 0.0
	var prev := 0.0
	for k in length:
		var t := float(k) / RATE
		var noise := rng.randf() * 2.0 - 1.0
		var v := 0.0
		match kind:
			"kick":
				phase += (45.0 + 90.0 * exp(-t * 30.0)) / RATE
				v = sin(TAU * phase) * exp(-t * 16.0) * 0.6
			"snare":
				v = (noise * 0.6 + sin(TAU * 185.0 * t) * 0.4) * exp(-t * 20.0) * 0.32
			"hat":
				v = (noise - prev) * 0.5 * exp(-t * 70.0) * 0.14
			"shaker":
				v = (noise - prev) * 0.5 * exp(-t * 40.0) * 0.1
			"tom":
				phase += (95.0 + 80.0 * exp(-t * 12.0)) / RATE
				v = sin(TAU * phase) * exp(-t * 11.0) * 0.4
			"taiko":
				phase += (55.0 + 50.0 * exp(-t * 8.0)) / RATE
				v = (sin(TAU * phase) * 0.9 + noise * 0.15 * exp(-t * 30.0)) * exp(-t * 6.0) * 0.55
			"clank":
				v = (noise * 0.4 + (0.5 if sin(TAU * 1250.0 * t) > 0.0 else -0.5)) * exp(-t * 35.0) * 0.18
		prev = noise
		buf[(s0 + k) % n] += v


static func _finish(buf: PackedFloat32Array) -> AudioStreamWAV:
	var n := buf.size()
	# filtro passa-baixa suave + normalização
	var y := 0.0
	var peak := 0.001
	for k in n:
		y += (buf[k] - y) * 0.7
		buf[k] = y
		peak = maxf(peak, absf(y))
	var gain := 0.85 / peak
	var data := PackedByteArray()
	data.resize(n * 2)
	for k in n:
		data.encode_s16(k * 2, int(clampf(buf[k] * gain, -1.0, 1.0) * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	s.loop_begin = 0
	s.loop_end = n
	return s
