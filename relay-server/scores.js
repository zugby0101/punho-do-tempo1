// Ranking online: dois quadros, "story" (modo História) e "survival" (Sobrevivência).
//
// Armazenamento:
//  - Upstash Redis (recomendado, gratuito): defina UPSTASH_REDIS_REST_URL e
//    UPSTASH_REDIS_REST_TOKEN. Os dados sobrevivem a reinícios do servidor.
//  - Arquivo local (padrão): data/scores.json. Em hospedagens com disco
//    temporário (ex.: Render gratuito) o ranking é apagado quando o servidor reinicia.
//
// Proteção: assinatura HMAC com uma chave compartilhada com o jogo (SCORE_KEY),
// validação dos valores e limite de envios por IP. Isso dificulta trapaças
// casuais, mas como a chave fica dentro do jogo, não impede um trapaceiro determinado.

"use strict";
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const SCORE_KEY = process.env.SCORE_KEY || "punho-do-tempo-ranking-v1";
const MAX_ENTRIES = 100;
const MAX_SCORE = 3000000;
const BOARDS = ["story", "survival"];
const redisKey = (board) => `punho:scores:${board}`;
const UP_URL = process.env.UPSTASH_REDIS_REST_URL || "";
const UP_TOKEN = process.env.UPSTASH_REDIS_REST_TOKEN || "";
const DATA_FILE = process.env.SCORES_FILE || path.join(__dirname, "data", "scores.json");
// o quadro "story" continua no arquivo/chave original (compatível com a versão anterior)
const dataFile = (board) => (board === "story" ? DATA_FILE : DATA_FILE.replace(/\.json$/, `-${board}.json`));

const storage = UP_URL && UP_TOKEN ? "upstash" : "file";
const cache = {};          // quadro -> lista em memória
const rate = new Map();    // ip -> [timestamps]

async function load(board) {
  if (cache[board]) return cache[board];
  try {
    if (storage === "upstash") {
      const key = board === "story" ? "punho:scores:story" : redisKey(board);
      const r = await fetch(`${UP_URL}/get/${key}`, { headers: { Authorization: `Bearer ${UP_TOKEN}` } });
      const j = await r.json();
      cache[board] = j.result ? JSON.parse(j.result) : [];
    } else {
      const f = dataFile(board);
      cache[board] = fs.existsSync(f) ? JSON.parse(fs.readFileSync(f, "utf8")) : [];
    }
  } catch (e) {
    console.error("ranking: falha ao carregar", e.message);
    cache[board] = [];
  }
  return cache[board];
}

async function save(board, list) {
  cache[board] = list;
  const body = JSON.stringify(list);
  if (storage === "upstash") {
    await fetch(`${UP_URL}/set/${redisKey(board)}`, { method: "POST", headers: { Authorization: `Bearer ${UP_TOKEN}` }, body });
  } else {
    const f = dataFile(board);
    fs.mkdirSync(path.dirname(f), { recursive: true });
    const tmp = f + ".tmp";
    fs.writeFileSync(tmp, body);
    fs.renameSync(tmp, f);
  }
}

function sign(e) {
  const parts = [e.name, e.char, e.score, e.stage, e.players, e.done ? 1 : 0, e.ts];
  if (e.board !== undefined) parts.push(e.board, e.wave); // formato novo (com quadro e onda)
  const msg = parts.join("|");
  return crypto.createHmac("sha256", SCORE_KEY).update(msg).digest("hex");
}

function cleanName(s) {
  return String(s || "").normalize("NFC").replace(/[^\p{L}\p{N} _.\-]/gu, "").trim().toUpperCase().slice(0, 12);
}

function limited(ip) {
  const now = Date.now();
  const list = (rate.get(ip) || []).filter((t) => now - t < 60000);
  list.push(now);
  rate.set(ip, list);
  return list.length > 12; // no máximo 12 envios por minuto por IP
}

function validate(b) {
  const e = {
    name: cleanName(b.name),
    char: String(b.char || "").toUpperCase().replace(/[^\p{L} ]/gu, "").slice(0, 12),
    score: Number(b.score),
    stage: Number(b.stage),
    players: Number(b.players),
    done: !!b.done,
    ts: Number(b.ts),
    board: b.board === undefined ? "story" : String(b.board),
    wave: b.wave === undefined ? 0 : Number(b.wave),
  };
  if (!BOARDS.includes(e.board)) return [null, "Ranking desconhecido."];
  if (e.board === "survival" && (!Number.isInteger(e.wave) || e.wave < 1 || e.wave > 9999)) return [null, "Onda inválida."];
  if (!e.name) return [null, "Nome inválido."];
  if (!Number.isInteger(e.score) || e.score <= 0 || e.score > MAX_SCORE) return [null, "Pontuação inválida."];
  // 12 eras + a fase secreta (ÉON) = 13
  if (!Number.isInteger(e.stage) || e.stage < 1 || e.stage > 13) return [null, "Fase inválida."];
  if (!Number.isInteger(e.players) || e.players < 1 || e.players > 4) return [null, "Número de jogadores inválido."];
  if (!Number.isInteger(e.ts) || Math.abs(Date.now() / 1000 - e.ts) > 600) return [null, "Horário inválido (confira o relógio do computador)."];
  // a assinatura é feita com os valores exatamente como o jogo enviou
  const raw = { name: String(b.name), char: String(b.char), score: e.score, stage: e.stage, players: e.players, done: e.done, ts: e.ts };
  if (b.board !== undefined) { raw.board = e.board; raw.wave = e.wave; }
  const expected = sign(raw);
  const got = String(b.sig || "");
  if (got.length !== expected.length || !crypto.timingSafeEqual(Buffer.from(got), Buffer.from(expected))) return [null, "Assinatura inválida."];
  return [e, null];
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    let data = "";
    req.on("data", (c) => {
      data += c;
      if (data.length > 16384) { reject(new Error("grande demais")); req.destroy(); }
    });
    req.on("end", () => resolve(data));
    req.on("error", reject);
  });
}

function reply(res, code, obj) {
  res.writeHead(code, { "Content-Type": "application/json; charset=utf-8", "Cache-Control": "no-store" });
  res.end(JSON.stringify(obj));
}

// Trata /scores. Retorna true se a requisição foi atendida aqui.
async function handle(req, res) {
  const url = new URL(req.url, "http://x");
  if (url.pathname !== "/scores") return false;
  try {
    if (req.method === "GET") {
      const limit = Math.max(1, Math.min(MAX_ENTRIES, parseInt(url.searchParams.get("limit") || "10", 10) || 10));
      const board = BOARDS.includes(url.searchParams.get("board")) ? url.searchParams.get("board") : "story";
      const list = await load(board);
      reply(res, 200, { board, scores: list.slice(0, limit).map(({ name, char, score, stage, players, done, date, wave }) => ({ name, char, score, stage, players, done, date, wave })), storage });
    } else if (req.method === "POST") {
      const ip = String(req.headers["x-forwarded-for"] || req.socket.remoteAddress || "").split(",")[0].trim();
      if (limited(ip)) return reply(res, 429, { ok: false, error: "Muitos envios, espere um minuto." }), true;
      let body;
      try { body = JSON.parse(await readBody(req)); } catch { return reply(res, 400, { ok: false, error: "JSON inválido." }), true; }
      const entries = Array.isArray(body.entries) ? body.entries.slice(0, 4) : [body];
      const lists = {};
      const ranks = [];
      for (const b of entries) {
        const [e, err] = validate(b);
        if (err) { ranks.push({ ok: false, error: err }); continue; }
        const list = lists[e.board] || (lists[e.board] = [...(await load(e.board))]);
        const item = { name: e.name, char: e.char, score: e.score, stage: e.stage, players: e.players, done: e.done, date: new Date().toISOString().slice(0, 10), id: crypto.randomUUID() };
        if (e.board === "survival") item.wave = e.wave;
        list.push(item);
        list.sort((a, b2) => b2.score - a.score);
        const pos = list.findIndex((x) => x.id === item.id);
        ranks.push({ ok: true, rank: pos + 1, name: e.name, board: e.board });
      }
      for (const board of Object.keys(lists)) {
        lists[board].length = Math.min(lists[board].length, MAX_ENTRIES);
        await save(board, lists[board]);
      }
      reply(res, 200, { ok: ranks.some((r) => r.ok), results: ranks });
    } else {
      reply(res, 405, { ok: false, error: "Método não suportado." });
    }
  } catch (e) {
    console.error("ranking:", e);
    reply(res, 500, { ok: false, error: "Erro no servidor." });
  }
  return true;
}

module.exports = { handle, sign, storage };
