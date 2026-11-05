// Servidor intermediário (relay) do modo online do Punho do Tempo.
//
// Anfitrião e convidados se conectam a este servidor (conexões de SAÍDA,
// por WebSocket), então ninguém precisa abrir portas no roteador.
// O servidor só repassa mensagens; o jogo roda no computador do anfitrião.
//
// Protocolo:
//   Texto (JSON) para controle:
//     -> {"op":"host"}                 <- {"op":"hosted","room":"ABCD"}
//     -> {"op":"join","room":"ABCD"}   <- {"op":"joined","id":N} | {"op":"error","msg":"..."}
//     <- (anfitrião) {"op":"peer_join","id":N} / {"op":"peer_leave","id":N}
//     <- (convidados) {"op":"room_closed"}
//   Binário para dados do jogo:
//     anfitrião -> servidor: [2 bytes: destino (0 = todos)] + dados  -> convidado(s): dados
//     convidado -> servidor: dados  -> anfitrião: [2 bytes: id do convidado] + dados

"use strict";
const http = require("http");
const { WebSocketServer } = require("ws");
const scores = require("./scores");

const PORT = parseInt(process.env.PORT || "8080", 10);
const MAX_GUESTS = 3;                 // anfitrião + 3 = 4 jogadores
const MAX_ROOMS = parseInt(process.env.MAX_ROOMS || "500", 10);
const MAX_MESSAGE = 256 * 1024;       // bytes por mensagem
const ROOM_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // sem letras confusas (I, O, 0, 1)

const rooms = new Map();              // código -> { host, guests: Map<id, ws>, nextId }
const stats = { up: 0, down: 0 };     // bytes recebidos do anfitrião / dos convidados (STATS=1)

function newCode() {
  for (let tries = 0; tries < 1000; tries++) {
    let c = "";
    for (let i = 0; i < 4; i++) c += ROOM_CHARS[Math.floor(Math.random() * ROOM_CHARS.length)];
    if (!rooms.has(c)) return c;
  }
  return null;
}

function send(ws, obj) {
  if (ws.readyState === ws.OPEN) ws.send(JSON.stringify(obj));
}

function closeRoom(code, reason) {
  const room = rooms.get(code);
  if (!room) return;
  rooms.delete(code);
  for (const g of room.guests.values()) {
    send(g, { op: "room_closed", msg: reason });
    g.close(1000, "room closed");
  }
  log(`sala ${code} encerrada (${reason}); salas abertas: ${rooms.size}`);
}

function log(msg) {
  console.log(new Date().toISOString(), msg);
}

const server = http.createServer(async (req, res) => {
  // Ranking online (GET/POST /scores)
  if (await scores.handle(req, res)) return;
  // Página simples para checagem de saúde (útil para hospedagens como Render)
  res.writeHead(200, { "Content-Type": "text/plain; charset=utf-8" });
  res.end(`Punho do Tempo relay OK - salas abertas: ${rooms.size}\n`);
});

const wss = new WebSocketServer({ server, maxPayload: MAX_MESSAGE, perMessageDeflate: false });

wss.on("connection", (ws) => {
  ws.isAlive = true;
  ws.role = null;   // "host" | "guest"
  ws.room = null;
  ws.peerId = 0;
  ws.on("pong", () => { ws.isAlive = true; });

  ws.on("message", (data, isBinary) => {
    if (!isBinary) {
      let msg;
      try { msg = JSON.parse(data.toString()); } catch { return; }
      handleControl(ws, msg);
      return;
    }
    const room = ws.room && rooms.get(ws.room);
    if (!room) return;
    if (ws.role === "host") stats.up += data.length; else stats.down += data.length;
    if (ws.role === "host") {
      if (data.length < 2) return;
      const target = data.readUInt16BE(0);
      const payload = data.subarray(2);
      if (target === 0) {
        for (const g of room.guests.values()) if (g.readyState === g.OPEN) g.send(payload, { binary: true });
      } else {
        const g = room.guests.get(target);
        if (g && g.readyState === g.OPEN) g.send(payload, { binary: true });
      }
    } else if (ws.role === "guest") {
      if (room.host.readyState !== room.host.OPEN) return;
      const header = Buffer.alloc(2);
      header.writeUInt16BE(ws.peerId, 0);
      room.host.send(Buffer.concat([header, data]), { binary: true });
    }
  });

  ws.on("close", () => {
    if (!ws.room) return;
    const room = rooms.get(ws.room);
    if (!room) return;
    if (ws.role === "host") {
      closeRoom(ws.room, "o anfitrião saiu");
    } else if (ws.role === "guest") {
      room.guests.delete(ws.peerId);
      send(room.host, { op: "peer_leave", id: ws.peerId });
      log(`convidado ${ws.peerId} saiu da sala ${ws.room}`);
    }
  });
});

function handleControl(ws, msg) {
  if (ws.role) return; // cada conexão só cria ou entra uma vez
  if (msg.op === "host") {
    if (rooms.size >= MAX_ROOMS) return send(ws, { op: "error", msg: "Servidor cheio, tente mais tarde." });
    const code = newCode();
    if (!code) return send(ws, { op: "error", msg: "Não foi possível criar a sala." });
    rooms.set(code, { host: ws, guests: new Map(), nextId: 2 });
    ws.role = "host";
    ws.room = code;
    send(ws, { op: "hosted", room: code });
    log(`sala ${code} criada; salas abertas: ${rooms.size}`);
  } else if (msg.op === "join") {
    const code = String(msg.room || "").trim().toUpperCase();
    const room = rooms.get(code);
    if (!room) return send(ws, { op: "error", msg: `Sala ${code} não encontrada.` });
    if (room.guests.size >= MAX_GUESTS) return send(ws, { op: "error", msg: "A sala está cheia (4 jogadores)." });
    const id = room.nextId++;
    room.guests.set(id, ws);
    ws.role = "guest";
    ws.room = code;
    ws.peerId = id;
    send(ws, { op: "joined", id, room: code });
    send(room.host, { op: "peer_join", id });
    log(`convidado ${id} entrou na sala ${code}`);
  }
}

// Derruba conexões mortas (e mantém as vivas ativas em hospedagens com proxy)
const heartbeat = setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.isAlive) { ws.terminate(); continue; }
    ws.isAlive = false;
    ws.ping();
  }
}, 20000);
wss.on("close", () => clearInterval(heartbeat));

if (process.env.STATS === "1") {
  setInterval(() => {
    if (stats.up || stats.down) log(`tráfego (10s): anfitrião ${(stats.up / 10240).toFixed(1)} KB/s, convidados ${(stats.down / 10240).toFixed(1)} KB/s`);
    stats.up = 0; stats.down = 0;
  }, 10000).unref();
}

server.listen(PORT, () => log(`Relay do Punho do Tempo ouvindo na porta ${PORT} (ranking: ${scores.storage})`));

module.exports = { server, wss, rooms };
