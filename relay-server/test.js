// Teste automático do relay: cria sala, entra, troca mensagens e encerra.
"use strict";
process.env.PORT = process.env.PORT || "18080";
const assert = require("assert");
const WebSocket = require("ws");
const { server, wss } = require("./server");

const URL = `ws://127.0.0.1:${process.env.PORT}`;
const open = (ws) => new Promise((r) => ws.once("open", r));
const nextText = (ws) => new Promise((r) => ws.once("message", (d, bin) => r(JSON.parse(d.toString()))));
const nextBin = (ws) => new Promise((r) => ws.once("message", (d) => r(d)));

(async () => {
  await new Promise((r) => server.listening ? r() : server.once("listening", r));
  const host = new WebSocket(URL);
  await open(host);
  host.send(JSON.stringify({ op: "host" }));
  const hosted = await nextText(host);
  assert.equal(hosted.op, "hosted");
  assert.match(hosted.room, /^[A-Z2-9]{4}$/);

  const guest = new WebSocket(URL);
  await open(guest);
  const hostSees = nextText(host);
  guest.send(JSON.stringify({ op: "join", room: hosted.room.toLowerCase() }));
  const joined = await nextText(guest);
  assert.equal(joined.op, "joined");
  const pj = await hostSees;
  assert.deepEqual(pj, { op: "peer_join", id: joined.id });

  // convidado -> anfitrião (com id no cabeçalho)
  const hb = nextBin(host);
  guest.send(Buffer.from([1, 2, 3]), { binary: true });
  const fromGuest = await hb;
  assert.equal(fromGuest.readUInt16BE(0), joined.id);
  assert.deepEqual([...fromGuest.subarray(2)], [1, 2, 3]);

  // anfitrião -> todos
  const gb = nextBin(guest);
  host.send(Buffer.from([0, 0, 9, 8]), { binary: true });
  assert.deepEqual([...(await gb)], [9, 8]);

  // sala inexistente
  const g2 = new WebSocket(URL);
  await open(g2);
  g2.send(JSON.stringify({ op: "join", room: "ZZZZ" }));
  assert.equal((await nextText(g2)).op, "error");

  // anfitrião sai -> convidado recebe room_closed
  const closed = nextText(guest);
  host.close();
  assert.equal((await closed).op, "room_closed");

  console.log("OK: todos os testes do relay passaram");
  g2.close();
  wss.close();
  server.close();
  process.exit(0);
})().catch((e) => { console.error("FALHOU:", e); process.exit(1); });
