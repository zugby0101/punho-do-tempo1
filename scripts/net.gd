extends Node
## Rede (autoload "Net"): modo online com o anfitrião sendo a autoridade.
##
## - O ANFITRIÃO roda o jogo inteiro. Cada convidado conectado vira um conjunto
##   de controle remoto ("n1", "n2", "n3") — para o jogo é como um controle a mais.
## - O CONVIDADO envia só os seus comandos e desenha o estado que recebe
##   (cerca de 30 vezes por segundo, compactado).
##
## Dois jeitos de conectar:
##   "relay": pelo servidor intermediário (pasta relay-server/), com código de sala.
##            Todos só fazem conexões de saída: ninguém precisa abrir portas.
##   "enet":  conexão direta por IP (o anfitrião precisa liberar a porta UDP 7777).

const Controls = preload("res://scripts/controls.gd")
const PORT := 7777
const MAX_CLIENTS := 3
const CONFIG_PATH := "user://online.cfg"

## Endereço padrão do servidor intermediário. Depois de publicar o relay-server,
## coloque o endereço aqui (ex.: "wss://punho-relay.onrender.com") para que todos
## que baixarem o jogo já usem o seu servidor. Também dá para configurar pelo menu.
const DEFAULT_RELAY_URL := "wss://punho-do-tempo-relay.onrender.com"

var game                     # main.gd atual (troca a cada fase)
var role := ""               # "", "host" ou "client"
var transport := ""          # "", "enet" ou "relay"
var peer_sets := {}          # (anfitrião) id do convidado -> conjunto remoto "n1".."n3"
var server_ip := ""
var my_set := ""             # (convidado) qual conjunto remoto é o meu ("n1".."n3")
var room_code := ""
var relay_url := ""
var last_ip := "127.0.0.1"
var last_code := ""
var status := ""             # mensagem para a interface
var status_timer := 0.0
var frame := 0

# Relay (WebSocket)
var ws: WebSocketPeer
var ws_was_open := false
var ws_pending := {}         # mensagem de controle a enviar quando abrir

# Convidado: contadores de toques (para o anfitrião detectar "acabou de apertar")
var press_counts: Array = [0, 0, 0, 0, 0, 0, 0, 0]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_lost)
	_load_config()


func is_host() -> bool:
	return role == "host"


func is_client() -> bool:
	return role == "client"


func online() -> bool:
	return role != ""


func set_status(s: String, dur := 4.0) -> void:
	status = s
	status_timer = dur


# ---------------- Configuração ----------------
func _load_config() -> void:
	var cfg := ConfigFile.new()
	relay_url = DEFAULT_RELAY_URL
	if cfg.load(CONFIG_PATH) == OK:
		relay_url = cfg.get_value("online", "relay_url", relay_url)
		if relay_url == "":
			relay_url = DEFAULT_RELAY_URL
		last_ip = cfg.get_value("online", "last_ip", last_ip)
		last_code = cfg.get_value("online", "last_code", last_code)


func save_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("online", "relay_url", relay_url)
	cfg.set_value("online", "last_ip", last_ip)
	cfg.set_value("online", "last_code", last_code)
	cfg.save(CONFIG_PATH)


## Aceita "meuservidor.com", "ws://..." ou "wss://...".
func set_relay_url(url: String) -> void:
	var u := url.strip_edges()
	if u != "" and not (u.begins_with("ws://") or u.begins_with("wss://")):
		u = ("ws://" if u.begins_with("localhost") or u.begins_with("127.") or u.begins_with("192.168.") else "wss://") + u
	relay_url = u if u != "" else DEFAULT_RELAY_URL  # vazio = volta ao servidor padrão
	save_config()


func has_relay() -> bool:
	return relay_url != ""


# ---------------- Conexão direta (ENet) ----------------
func host() -> bool:
	close()
	var p := ENetMultiplayerPeer.new()
	var err := p.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		set_status("Não foi possível abrir a porta %d (erro %d)" % [PORT, err], 6.0)
		return false
	p.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = p
	role = "host"
	transport = "enet"
	set_status("Partida aberta na porta %d" % PORT)
	return true


func join(ip: String) -> void:
	close()
	var p := ENetMultiplayerPeer.new()
	var err := p.create_client(ip.strip_edges(), PORT)
	if err != OK:
		set_status("Endereço inválido: %s" % ip, 5.0)
		return
	p.host.compress(ENetConnection.COMPRESS_RANGE_CODER)
	multiplayer.multiplayer_peer = p
	role = "client"
	transport = "enet"
	server_ip = ip.strip_edges()
	last_ip = server_ip
	save_config()
	set_status("Conectando a %s..." % server_ip, 10.0)
	if game != null:
		game.become_client()


func local_ip() -> String:
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254"):
			return a
	return "127.0.0.1"


func connected_count() -> int:
	return peer_sets.size()


func _on_connected() -> void:
	set_status("Conectado! Aperte SOCO para entrar na partida.")


func _on_failed() -> void:
	set_status("Não foi possível conectar a %s" % server_ip, 6.0)
	_back_to_title()


func _on_server_lost() -> void:
	set_status("O anfitrião encerrou a partida.", 6.0)
	_back_to_title()


# ---------------- Servidor intermediário (relay) ----------------
func relay_host() -> void:
	close()
	_relay_open({"op": "host"})
	set_status("Criando sala no servidor...", 15.0)


func relay_join(code: String) -> void:
	close()
	last_code = code.strip_edges().to_upper()
	save_config()
	_relay_open({"op": "join", "room": last_code})
	role = "client"
	transport = "relay"
	set_status("Entrando na sala %s..." % last_code, 15.0)
	if game != null:
		game.become_client()


func _relay_open(first_msg: Dictionary) -> void:
	ws = WebSocketPeer.new()
	ws.outbound_buffer_size = 4 * 1024 * 1024
	ws.inbound_buffer_size = 4 * 1024 * 1024
	ws_was_open = false
	ws_pending = first_msg
	transport = "relay"
	var err := ws.connect_to_url(relay_url)
	if err != OK:
		set_status("Endereço do servidor inválido: %s" % relay_url, 6.0)
		ws = null
		_back_to_title()


func _relay_poll() -> void:
	if ws == null:
		return
	ws.poll()
	var st := ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not ws_was_open:
			ws_was_open = true
			if not ws_pending.is_empty():
				ws.send_text(JSON.stringify(ws_pending))
				ws_pending = {}
		while ws != null and ws.get_available_packet_count() > 0:
			var pkt := ws.get_packet()
			if ws.was_string_packet():
				# pode encerrar a conexão (ws vira null) — por isso o laço confere ws
				_relay_control(JSON.parse_string(pkt.get_string_from_utf8()))
			else:
				_relay_data(pkt)
	elif st == WebSocketPeer.STATE_CLOSED:
		var had := ws_was_open
		ws = null
		if role == "client" or role == "host" or not had:
			set_status("Conexão com o servidor perdida." if had else "Não foi possível falar com o servidor (%s)." % relay_url, 6.0)
			_back_to_title()


func _relay_control(msg) -> void:
	if not (msg is Dictionary):
		return
	match msg.get("op", ""):
		"hosted":
			role = "host"
			room_code = msg.room
			set_status("Sala %s criada! Passe o código para os amigos." % room_code, 8.0)
			if game != null:
				game.on_relay_hosted()
		"joined":
			room_code = msg.get("room", last_code)
			set_status("Conectado à sala %s! Aperte SOCO para entrar." % room_code)
		"peer_join":
			_on_peer_connected(int(msg.id))
		"peer_leave":
			_on_peer_disconnected(int(msg.id))
		"room_closed":
			set_status("O anfitrião encerrou a sala.", 6.0)
			_back_to_title()
		"error":
			set_status(String(msg.get("msg", "Erro no servidor.")), 6.0)
			_back_to_title()


func _relay_data(pkt: PackedByteArray) -> void:
	if role == "host":
		if pkt.size() < 3:
			return
		var sender := (pkt[0] << 8) | pkt[1]
		var msg = bytes_to_var(pkt.slice(2))
		if msg is Array and msg.size() == 2 and msg[0] == "in" and peer_sets.has(sender):
			Controls.set_remote(peer_sets[sender], msg[1])
	elif role == "client":
		var msg = bytes_to_var(pkt)
		if msg is Array and msg.size() == 3 and msg[0] == "snap":
			_apply_snapshot(msg[1], msg[2])
		elif msg is Array and msg.size() == 2 and msg[0] == "welcome":
			my_set = String(msg[1])


# ---------------- Comum aos dois meios ----------------
func _process(delta: float) -> void:
	status_timer -= delta
	_relay_poll()


func _on_peer_connected(id: int) -> void:
	if not is_host():
		return
	var used: Array = peer_sets.values()
	for n in ["n1", "n2", "n3"]:
		if not (n in used):
			peer_sets[id] = n
			Controls.remote[n] = Controls.new_remote()
			_send_welcome(id, n)
			set_status("Um jogador online entrou! (ele aperta SOCO para escolher o lutador)")
			return


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	if peer_sets.has(id):
		var n: String = peer_sets[id]
		Controls.remote[n] = Controls.new_remote()  # fica parado
		peer_sets.erase(id)
		set_status("Um jogador online saiu da partida.")


## Diz ao convidado qual conjunto de controle é o dele (para as conquistas).
func _send_welcome(id: int, n: String) -> void:
	if transport == "relay":
		if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			var out := PackedByteArray([(id >> 8) & 255, id & 255])
			out.append_array(var_to_bytes(["welcome", n]))
			ws.put_packet(out)
	else:
		welcome.rpc_id(id, n)


@rpc("authority", "reliable")
func welcome(n: String) -> void:
	my_set = n


## Recebe os comandos de um convidado (conexão direta).
@rpc("any_peer", "unreliable_ordered")
func client_input(data: Array) -> void:
	if not is_host():
		return
	var id := multiplayer.get_remote_sender_id()
	if peer_sets.has(id):
		Controls.set_remote(peer_sets[id], data)


## Chamado pelo main.gd do anfitrião a cada quadro de física.
func host_tick() -> void:
	if not is_host() or peer_sets.is_empty() or game == null:
		return
	frame += 1
	if frame % 2 != 0:
		return
	var snap: Array = game.net_snapshot()
	var raw := var_to_bytes(snap)
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	if transport == "relay":
		if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
			var out := PackedByteArray([0, 0])  # destino 0 = todos os convidados
			out.append_array(var_to_bytes(["snap", packed, raw.size()]))
			ws.put_packet(out)
	else:
		snapshot.rpc(packed, raw.size())


## Convidado: envia os comandos locais (qualquer teclado/controle deste computador).
func client_tick() -> void:
	if not is_client():
		return
	var sets := Controls.all_sets()
	var bits := 0
	for i in Controls.ACTIONS.size():
		var a: String = Controls.ACTIONS[i]
		if Controls.pressed(sets, a):
			bits |= 1 << i
		if Controls.just(sets, a):
			press_counts[i] += 1
	var v := Controls.vector(sets)
	var data := [bits, press_counts.duplicate(), v.x, v.y]
	if transport == "relay":
		if ws != null and ws.get_ready_state() == WebSocketPeer.STATE_OPEN and room_code != "":
			ws.put_packet(var_to_bytes(["in", data]))
	elif multiplayer.multiplayer_peer != null and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		client_input.rpc_id(1, data)


@rpc("authority", "unreliable_ordered")
func snapshot(packed: PackedByteArray, size: int) -> void:
	_apply_snapshot(packed, size)


func _apply_snapshot(packed: PackedByteArray, size: int) -> void:
	if not is_client() or game == null or size <= 0 or size > 8 * 1024 * 1024:
		return
	var raw := packed.decompress(size, FileAccess.COMPRESSION_ZSTD)
	var snap = bytes_to_var(raw)
	if snap is Array:
		game.net_apply(snap)


func _back_to_title() -> void:
	close()
	if game != null:
		game.leave_online()


func close() -> void:
	if ws != null:
		ws.close()
		ws = null
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	role = ""
	transport = ""
	room_code = ""
	my_set = ""
	peer_sets.clear()
	Controls.remote.clear()
	press_counts = [0, 0, 0, 0, 0, 0, 0, 0]


# ================= Ranking online =================
## Mesma chave do servidor (SCORE_KEY). Dificulta envios falsos casuais.
const SCORE_KEY := "punho-do-tempo-ranking-v1"

var ranking: Array = []        # última lista recebida
var ranking_status := ""       # "carregando", "ok" ou mensagem de erro
var last_ranks: Array = []     # posições obtidas no último envio


## Endereço HTTP do servidor (o mesmo do relay: wss:// vira https://).
func scores_url() -> String:
	var u := relay_url if relay_url != "" else DEFAULT_RELAY_URL
	u = u.replace("wss://", "https://").replace("ws://", "http://")
	return u.trim_suffix("/") + "/scores"


func _sign(e: Dictionary) -> String:
	var msg := "%s|%s|%d|%d|%d|%d|%d" % [e.name, e.char, e.score, e.stage, e.players, 1 if e.done else 0, e.ts]
	var ctx := HMACContext.new()
	ctx.start(HashingContext.HASH_SHA256, SCORE_KEY.to_utf8_buffer())
	ctx.update(msg.to_utf8_buffer())
	return ctx.finish().hex_encode()


func fetch_ranking() -> void:
	ranking_status = "carregando"
	_http(scores_url() + "?limit=10", HTTPClient.METHOD_GET, "", _on_ranking)


## entries: [{name, char, score, stage, players, done}]
func submit_scores(entries: Array) -> void:
	ranking_status = "carregando"
	last_ranks = []
	var ts := int(Time.get_unix_time_from_system())
	var out: Array = []
	for e in entries:
		var x: Dictionary = e.duplicate()
		x.ts = ts
		x.sig = _sign(x)
		out.append(x)
	_http(scores_url(), HTTPClient.METHOD_POST, JSON.stringify({"entries": out}), _on_submitted)


func _http(url: String, method: int, body: String, cb: Callable) -> void:
	var req := HTTPRequest.new()
	req.timeout = 75.0  # o servidor gratuito pode levar ~1 min para acordar
	add_child(req)
	req.request_completed.connect(func(result, code, _h, data):
		req.queue_free()
		var parsed = JSON.parse_string(data.get_string_from_utf8()) if data.size() > 0 else null
		cb.call(result == HTTPRequest.RESULT_SUCCESS, code, parsed))
	var err := req.request(url, ["Content-Type: application/json"], method, body)
	if err != OK:
		req.queue_free()
		ranking_status = "Não foi possível acessar o ranking (erro %d)." % err


func _on_ranking(ok: bool, code: int, data) -> void:
	if ok and code == 200 and data is Dictionary:
		ranking = data.get("scores", [])
		ranking_status = "ok"
	else:
		ranking_status = "Ranking indisponível agora (servidor fora do ar ou acordando). Tente de novo em 1 minuto."


func _on_submitted(ok: bool, code: int, data) -> void:
	if ok and data is Dictionary:
		last_ranks = data.get("results", [])
		for r in last_ranks:
			if r.get("ok", false) and int(r.get("rank", 999)) <= 10:
				Ach.flag(null, "top10")
		if not data.get("ok", false):
			var msg := "Pontuação recusada."
			if not last_ranks.is_empty():
				msg = String(last_ranks[0].get("error", msg))
			elif data.has("error"):
				msg = String(data.error)
			ranking_status = msg
			return
		fetch_ranking()
	else:
		ranking_status = "Não foi possível enviar (servidor fora do ar ou acordando). Tente de novo em 1 minuto."
