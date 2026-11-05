extends Node
## Efeitos sonoros sintetizados em tempo de execução (sem arquivos de áudio).

const RATE := 22050
var streams := {}
var players: Array = []
var idx := 0


func _ready() -> void:
	for i in 10:
		var pl := AudioStreamPlayer.new()
		pl.volume_db = -6.0
		add_child(pl)
		players.append(pl)
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


func _noise() -> float:
	return randf() * 2.0 - 1.0


func _gen(dur: float, f: Callable) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v: float = clampf(f.call(t, t / dur), -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 30000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	return s


var hook: Callable  # online: o anfitrião repassa os sons aos convidados


func play(name: String, pitch_var: float = 0.08) -> void:
	if not streams.has(name):
		return
	if hook.is_valid():
		hook.call(name)
	var p: AudioStreamPlayer = players[idx]
	idx = (idx + 1) % players.size()
	p.stream = streams[name]
	p.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	p.play()
