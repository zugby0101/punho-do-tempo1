extends Node
## Rede (autoload "Net"): modo online com o anfitrião sendo a autoridade.
##
## - O ANFITRIÃO roda o jogo inteiro. Cada convidado conectado vira um conjunto
##   de controle remoto ("n1", "n2", "n3") — para o jogo é como um controle a mais.
## - O CONVIDADO envia só os seus comandos e desenha o estado que recebe
##   (cerca de 30 vezes por segundo, compactado).
##
## Pela internet, o anfitrião precisa liberar a porta UDP no roteador
## (ou os jogadores usam uma VPN de jogos, como Tailscale/ZeroTier/Radmin).

const Controls = preload("res://scripts/controls.gd")
const PORT := 7777
const MAX_CLIENTS := 3

var game                     # main.gd atual (troca a cada fase)
var role := ""               # "", "host" ou "client"
var peer_sets := {}          # (anfitrião) id do convidado -> conjunto remoto "n1".."n3"
var server_ip := ""
var status := ""             # mensagem para a interface
var status_timer := 0.0
var frame := 0

# Convidado: contadores de toques (para o anfitrião detectar "acabou de apertar")
var press_counts: Array = [0, 0, 0, 0, 0, 0, 0, 0]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_lost)


func is_host() -> bool:
	return role == "host"


func is_client() -> bool:
	return role == "client"


func online() -> bool:
	return role != ""


func set_status(s: String, dur := 4.0) -> void:
	status = s
	status_timer = dur


func _process(delta: float) -> void:
	status_timer -= delta


# ---------------- Anfitrião ----------------
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
	set_status("Partida aberta na porta %d" % PORT)
	return true


func local_ip() -> String:
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254"):
			return a
	return "127.0.0.1"


func connected_count() -> int:
	return peer_sets.size()


func _on_peer_connected(id: int) -> void:
	if not is_host():
		return
	var used: Array = peer_sets.values()
	for n in ["n1", "n2", "n3"]:
		if not (n in used):
			peer_sets[id] = n
			Controls.remote[n] = Controls.new_remote()
			set_status("Um jogador online entrou! (aperte SOCO para escolher o lutador)")
			return


func _on_peer_disconnected(id: int) -> void:
	if not is_host():
		return
	if peer_sets.has(id):
		var n: String = peer_sets[id]
		Controls.remote[n] = Controls.new_remote()  # fica parado
		peer_sets.erase(id)
		set_status("Um jogador online saiu da partida.")


## Recebe os comandos de um convidado.
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
	snapshot.rpc(packed, raw.size())


# ---------------- Convidado ----------------
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
	server_ip = ip.strip_edges()
	set_status("Conectando a %s..." % server_ip, 10.0)
	if game != null:
		game.become_client()


func _on_connected() -> void:
	set_status("Conectado! Aperte SOCO para entrar na partida.")


func _on_failed() -> void:
	set_status("Não foi possível conectar a %s" % server_ip, 6.0)
	_back_to_title()


func _on_server_lost() -> void:
	set_status("O anfitrião encerrou a partida.", 6.0)
	_back_to_title()


func _back_to_title() -> void:
	close()
	if game != null:
		game.leave_online()


## Convidado: envia os comandos locais (qualquer teclado/controle deste computador).
func client_tick() -> void:
	if not is_client() or multiplayer.multiplayer_peer == null:
		return
	if multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
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
	client_input.rpc_id(1, [bits, press_counts.duplicate(), v.x, v.y])


@rpc("authority", "unreliable_ordered")
func snapshot(packed: PackedByteArray, size: int) -> void:
	if not is_client() or game == null:
		return
	var raw := packed.decompress(size, FileAccess.COMPRESSION_ZSTD)
	var snap = bytes_to_var(raw)
	if snap is Array:
		game.net_apply(snap)


func close() -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	role = ""
	peer_sets.clear()
	Controls.remote.clear()
	press_counts = [0, 0, 0, 0, 0, 0, 0, 0]
