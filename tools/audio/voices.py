"""Vozes e gritos dos personagens, por síntese de formantes (sem gravações, sem direitos autorais).

    python tools/audio/voices.py        # precisa de numpy e scipy

Gera audio/voices/<voz>_<fala>.wav (22050 Hz, mono) e audio/voices/index.json.

Como funciona: uma fonte glotal (pulsos com tom variável, jitter, vibrato e sopro) passa
por filtros ressonantes nos formantes das vogais (a, é, i, ó, u); o som desliza entre
vogais. Consoantes: "h" é aspiração; "t"/"k" são estalos curtos; "n" é um murmúrio nasal.
Cada voz tem tom, timbre, rouquidão, sopro e efeitos próprios (eco, robô, voz dupla).
"""
import json
import math
import wave
from pathlib import Path

import numpy as np
from scipy.signal import lfilter

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "audio" / "voices"
RATE = 22050
rng = np.random.default_rng(7)

# Formantes (F1, F2, F3) de uma voz adulta grave; vozes agudas multiplicam por "formant".
VOWELS = {
    "a": (780, 1220, 2500), "e": (520, 1850, 2550), "i": (300, 2250, 3000),
    "o": (560, 860, 2450), "u": (330, 820, 2300), "ah": (850, 1300, 2600), "uh": (620, 1180, 2450),
    "n": (280, 1700, 2600),
}
BW = (90, 110, 160)

# Vozes: tom (Hz), formantes, sopro, rouquidão, brilho, efeito
VOICES = {
    # lutadores
    "mateus": dict(f0=128, formant=1.0, breath=0.10, rough=0.05, bright=0.6),
    "valentina": dict(f0=215, formant=1.17, breath=0.12, rough=0.02, bright=0.65),
    "jake": dict(f0=96, formant=0.94, breath=0.08, rough=0.25, bright=0.5),
    "itzel": dict(f0=238, formant=1.2, breath=0.08, rough=0.0, bright=0.8),
    "dmitri": dict(f0=86, formant=0.9, breath=0.06, rough=0.35, bright=0.4),
    "oksana": dict(f0=248, formant=1.22, breath=0.10, rough=0.0, bright=0.75),
    "luca": dict(f0=132, formant=1.02, breath=0.12, rough=0.05, bright=0.6),
    "amelie": dict(f0=226, formant=1.18, breath=0.25, rough=0.0, bright=0.55),
    "kai": dict(f0=120, formant=1.0, breath=0.06, rough=0.08, bright=0.7),
    "mei": dict(f0=262, formant=1.24, breath=0.08, rough=0.0, bright=0.8),
    "kofi": dict(f0=104, formant=0.96, breath=0.07, rough=0.15, bright=0.55),
    "amara": dict(f0=200, formant=1.14, breath=0.10, rough=0.05, bright=0.65),
    "tama": dict(f0=92, formant=0.93, breath=0.08, rough=0.3, bright=0.5),
    "kirra": dict(f0=212, formant=1.16, breath=0.12, rough=0.02, bright=0.7),
    # inimigos
    "thug": dict(f0=116, formant=1.0, breath=0.12, rough=0.22, bright=0.5),
    "knife": dict(f0=152, formant=1.06, breath=0.15, rough=0.08, bright=0.7),
    "brute": dict(f0=74, formant=0.88, breath=0.06, rough=0.55, bright=0.35),
    "subboss": dict(f0=104, formant=0.97, breath=0.06, rough=0.2, bright=0.55),
    "boss": dict(f0=82, formant=0.9, breath=0.05, rough=0.3, bright=0.45, fx="echo"),
    "robot": dict(f0=112, formant=1.0, breath=0.0, rough=0.0, bright=0.8, fx="robot"),
    "ghost": dict(f0=140, formant=1.05, breath=0.7, rough=0.0, bright=0.5, fx="ghost"),
    "eon": dict(f0=68, formant=0.86, breath=0.05, rough=0.15, bright=0.5, fx="eon"),
}

# Grito de assinatura do especial de cada lutador: sílabas (consoante, vogal(is), duração, tom relativo)
SPECIAL_SHOUT = {
    "mateus": [("", "e", 0.18, 1.1), ("y", "a", 0.45, 1.35)],          # "ê-yaaah!"
    "valentina": [("h", "a", 0.12, 1.15), ("", "a", 0.45, 1.4)],       # "ha-aaah!"
    "jake": [("h", "o", 0.25, 1.0), ("r", "ah", 0.5, 1.25)],           # "hoo-raaah!"
    "itzel": [("", "a", 0.12, 1.2), ("r", "i", 0.12, 1.45), ("b", "a", 0.4, 1.35)],  # "a-ri-baaa!"
    "dmitri": [("h", "uh", 0.6, 1.05)],                                # "hrrraaa" (rouco)
    "oksana": [("h", "e", 0.14, 1.3), ("y", "a", 0.42, 1.5)],         # "he-yaaa!"
    "luca": [("", "a", 0.12, 1.15), ("l", "e", 0.42, 1.35)],          # "a-lééé!"
    "amelie": [("", "a", 0.14, 1.2), ("l", "e", 0.38, 1.45)],         # "al-lééé!"
    "kai": [("k", "i", 0.12, 1.2), ("", "a", 0.12, 1.4), ("", "i", 0.32, 1.3)],     # "ki-a-iii!"
    "mei": [("h", "u", 0.12, 1.3), ("", "a", 0.12, 1.5), ("t", "a", 0.32, 1.6)],    # "hwa-taaa!"
    "kofi": [("h", "o", 0.2, 1.05), ("", "ah", 0.5, 1.3)],            # "ho-aaah!"
    "amara": [("y", "a", 0.16, 1.2), ("", "o", 0.45, 1.4)],           # "ya-ooo!"
    "tama": [("k", "a", 0.16, 1.05), ("m", "a", 0.16, 1.15), ("t", "e", 0.45, 1.3)],  # "ka-ma-tééé!"
    "kirra": [("", "o", 0.14, 1.2), ("", "e", 0.42, 1.45)],           # "ô-ééé!"
}
GENERIC_SPECIAL = [("h", "a", 0.12, 1.15), ("", "ah", 0.5, 1.45)]

# Falas comuns: lista de sílabas (consoante, vogal ou "v1>v2", duração, tom relativo inicial->final)
LINES = {
    "atk1": [("h", "ah", 0.17, (1.15, 0.95))],
    "atk2": [("h", "i>a", 0.24, (1.1, 1.3, 0.95))],
    "atk3": [("t", "a", 0.16, (1.2, 0.95))],
    "heavy": [("h", "o", 0.14, (1.05, 1.15)), ("", "ah", 0.3, (1.35, 1.0))],
    "hurt1": [("", "uh", 0.16, (1.25, 0.85))],
    "hurt2": [("", "a", 0.2, (1.4, 1.0))],
    "fall": [("w", "a", 0.55, (1.5, 0.75))],
    "ko": [("", "a>o", 0.85, (1.35, 0.6))],
    "jump": [("h", "u", 0.11, (1.0, 1.15))],
    "win": [("y", "e>a", 0.38, (1.0, 1.45, 1.2))],
    "laugh": [("h", "a", 0.11, (1.0, 0.95)), ("h", "a", 0.11, (0.98, 0.93)), ("h", "a", 0.14, (0.95, 0.85))],
}


# ---------------------------------------------------------------------------
def resonator(x, f, bw):
    """Filtro ressonante de 2 polos (um formante)."""
    r = math.exp(-math.pi * bw / RATE)
    a1 = -2 * r * math.cos(2 * math.pi * f / RATE)
    a2 = r * r
    return lfilter([1 - r], [1, a1, a2], x)


def time_varying_formants(src, f_tracks, voice):
    """Aplica os formantes em blocos curtos (interpolação suave entre vogais)."""
    out = np.zeros_like(src)
    block = 256
    zi = [np.zeros(2) for _ in range(3)]
    for s in range(0, len(src), block):
        e = min(len(src), s + block)
        seg = src[s:e]
        acc = np.zeros(e - s)
        for k in range(3):
            f = f_tracks[k][s] * voice["formant"]
            bw = BW[k] * (1.3 if voice.get("fx") == "ghost" else 1.0)
            r = math.exp(-math.pi * bw / RATE)
            a = [1, -2 * r * math.cos(2 * math.pi * f / RATE), r * r]
            y, zi[k] = lfilter([1 - r], a, seg, zi=zi[k])
            acc += y * (1.0, 0.55, 0.3)[k] * (1 + voice["bright"] * k * 0.4)
        out[s:e] = acc
    return out


def glottal(n, f0_curve, voice):
    """Fonte da voz: pulsos glotais com jitter, vibrato, rouquidão e sopro."""
    t = np.arange(n) / RATE
    jitter = 1 + rng.normal(0, 0.012 + voice["rough"] * 0.03, n).cumsum() * 0.0
    vib = 1 + 0.012 * np.sin(2 * np.pi * 5.5 * t)
    f = f0_curve * vib * (1 + rng.normal(0, 0.006 + voice["rough"] * 0.02, n))
    if voice.get("fx") == "robot":
        f = np.round(f / 12.0) * 12.0  # tom em degraus
    phase = np.cumsum(f / RATE)
    x = phase - np.floor(phase)
    # pulso tipo Rosenberg: abertura suave, fechamento rápido
    src = np.where(x < 0.6, 0.5 - 0.5 * np.cos(np.pi * x / 0.6), np.cos(np.pi * (x - 0.6) / 0.8))
    src = np.diff(src, prepend=src[0]) * 18.0  # derivada do fluxo (mais natural)
    if voice["rough"] > 0:  # rouquidão: sub-harmônico (pulsos alternados)
        alt = np.where(np.floor(phase) % 2 == 0, 1.0, 1.0 - voice["rough"])
        src *= alt
    if voice.get("fx") == "robot":
        src = np.sign(np.sin(2 * np.pi * phase)) * 0.6
    noise = rng.normal(0, 1, n) * voice["breath"] * 1.4
    return src * (1 - voice["breath"] * 0.6) + noise


def consonant(c, n_vowel_formants, voice):
    """Consoantes curtas antes da vogal."""
    if c in ("", "y", "w", "l", "r", "m", "b"):
        return np.zeros(0)
    if c == "h":
        n = int(0.035 * RATE)
        x = rng.normal(0, 1, n) * np.linspace(0.2, 0.9, n)
        return time_varying_formants(x, [np.full(n, f) for f in n_vowel_formants], {**voice, "bright": 0.3}) * 0.7
    if c in ("t", "k"):
        n = int(0.022 * RATE)
        x = rng.normal(0, 1, n) * np.exp(-np.arange(n) / (n / 4))
        f = 4200 if c == "t" else 2200
        return resonator(x, f, 900) * 3.0
    return np.zeros(0)


def syllable(c, vowel, dur, pitch, voice, loud=1.0):
    n = int(dur * RATE)
    if ">" in vowel:  # ditongo
        v0, v1 = vowel.split(">")
        a, b = VOWELS[v0], VOWELS[v1]
        tt = np.linspace(0, 1, n) ** 0.8
        tracks = [a[k] + (b[k] - a[k]) * tt for k in range(3)]
    else:
        tracks = [np.full(n, VOWELS[vowel][k]) for k in range(3)]
    # semivogais e líquidas: começam numa vogal de passagem
    glide = {"y": "i", "w": "u", "l": "n", "r": "e", "m": "n", "b": "u"}.get(c)
    if glide:
        g = VOWELS[glide]
        m = int(0.05 * RATE)
        for k in range(3):
            tracks[k][:m] = np.linspace(g[k], tracks[k][m], m)
    pts = pitch if isinstance(pitch, tuple) else (pitch, pitch)
    curve = np.interp(np.linspace(0, len(pts) - 1, n), np.arange(len(pts)), pts) * voice["f0"]
    src = glottal(n, curve, voice)
    y = time_varying_formants(src, tracks, voice)
    env = np.minimum(1, np.arange(n) / (0.012 * RATE)) * np.minimum(1, (n - np.arange(n)) / (0.06 * RATE))
    y = y * env * loud
    head = consonant(c, [tracks[k][0] for k in range(3)], voice)
    return np.concatenate([head, y]) if len(head) else y


def effects(y, voice):
    fx = voice.get("fx")
    if fx == "robot":
        t = np.arange(len(y)) / RATE
        y = y * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 38 * t)))
        y = np.round(y * 24) / 24  # "bitcrush"
    if fx in ("echo", "eon", "ghost"):
        d = int((0.11 if fx != "ghost" else 0.16) * RATE)
        out = np.concatenate([y, np.zeros(d * 3)])
        for k, g in enumerate((0.45, 0.25, 0.12)):
            out[d * (k + 1):d * (k + 1) + len(y)] += y * g
        y = out
    if fx == "eon":  # voz dupla: uma oitava abaixo, levemente desafinada
        low = np.interp(np.arange(0, len(y), 0.5), np.arange(len(y)), y)[:len(y)]
        y = y * 0.7 + low * 0.6
    return y


def render(parts, voice, shout=1.0):
    y = np.concatenate([syllable(c, v, d, p, voice) for c, v, d, p in parts] + [np.zeros(int(0.02 * RATE))])
    y = effects(y, voice)
    y = np.tanh(y / (np.max(np.abs(y)) + 1e-9) * (1.4 + shout)) * 0.85  # grito: um pouco saturado
    return y


def save(path, y):
    data = (np.clip(y, -1, 1) * 30000).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    index = {}
    total = 0.0
    for name, voice in VOICES.items():
        lines = dict(LINES)
        sp = SPECIAL_SHOUT.get(name, GENERIC_SPECIAL)
        lines["special"] = [(c, v, d, (p, p * 1.08, p * 0.92)) for c, v, d, p in sp]
        index[name] = []
        for line, parts in lines.items():
            y = render(parts, voice, shout=1.2 if line in ("special", "heavy", "fall") else 0.8)
            save(OUT / ("%s_%s.wav" % (name, line)), y)
            index[name].append(line)
            total += len(y) / RATE
    (OUT / "index.json").write_text(json.dumps(index, ensure_ascii=False, indent=1), encoding="utf-8")
    n = sum(len(v) for v in index.values())
    print("%d falas para %d vozes (%.1f s de áudio) em %s" % (n, len(index), total, OUT))


if __name__ == "__main__":
    main()
