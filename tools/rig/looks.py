"""Lê o visual dos inimigos, sub-chefes e chefes de scripts/stages.gd (fonte única dos dados).

Cada era define _look(nome, camisa, calça, chapéu[, pele][, cabelo]) para os tipos
thug (★), knife (★★), brute (★★★), boss, a lista _subbosses() e a fase secreta secret().
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STAGES_GD = ROOT / "scripts" / "stages.gd"

DEFAULT_SKIN = (0.96, 0.76, 0.6, 1.0)
DEFAULT_HAIR = (0.15, 0.1, 0.05, 1.0)
ENEMY_SHOES = (0.1, 0.1, 0.1, 1.0)  # padrão de fighter.gd

_COLOR = re.compile(r"Color\(\s*([-\d.]+)\s*,\s*([-\d.]+)\s*,\s*([-\d.]+)\s*(?:,\s*([-\d.]+))?\s*\)")


def _color(text, variables):
    text = text.strip()
    if text in variables:
        return variables[text]
    m = _COLOR.fullmatch(text)
    if not m:
        raise ValueError("cor não reconhecida: %r" % text)
    r, g, b, a = m.groups()
    return (float(r), float(g), float(b), float(a) if a else 1.0)


def _args(s):
    out, depth, cur, q = [], 0, "", False
    for ch in s:
        if ch == '"':
            q = not q
        if not q:
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            elif ch == "," and depth == 0:
                out.append(cur.strip())
                cur = ""
                continue
        cur += ch
    if cur.strip():
        out.append(cur.strip())
    return out


def _look(call, variables):
    a = _args(call)
    return {
        "name": a[0].strip('"'),
        "shirt": _color(a[1], variables),
        "pants": _color(a[2], variables),
        "hat": a[3].strip('"'),
        "skin": _color(a[4], variables) if len(a) > 4 else DEFAULT_SKIN,
        "hair": _color(a[5], variables) if len(a) > 5 else DEFAULT_HAIR,
    }


def _calls(block, key, variables):
    """Encontra '"key": _look(...)' e devolve o visual (com parênteses balanceados)."""
    i = block.find('"%s": _look(' % key)
    if i < 0:
        return None
    j = block.index("(", i) + 1
    depth, k = 1, j
    while depth:
        depth += {"(": 1, ")": -1}.get(block[k], 0)
        k += 1
    return _look(block[j:k - 1], variables)


def _variables(func_text):
    return {m.group(1): _color(m.group(2), {}) for m in re.finditer(r"var (\w+) := (Color\([^)]*\))", func_text)}


def _func(src, name):
    i = src.index("static func %s(" % name)
    j = src.find("\nstatic func ", i + 1)
    return src[i:j if j > 0 else len(src)]


def load_enemy_looks():
    """Lista de eras: {style, name, idx, looks: {thug, knife, brute, subboss, boss|secret_boss}, cape}."""
    src = STAGES_GD.read_text(encoding="utf-8")
    base = _func(src, "_list_base")
    bvars = _variables(base)
    subs_fn = _func(src, "_subbosses")
    sub_calls = []
    for m in re.finditer(r"_look\(", subs_fn):
        j = m.end()
        depth, k = 1, j
        while depth:
            depth += {"(": 1, ")": -1}.get(subs_fn[k], 0)
            k += 1
        sub_calls.append(_look(subs_fn[j:k - 1], bvars))
    eras = []
    blocks = re.split(r'\n\t\t\{\n', base)[1:]
    for i, block in enumerate(blocks):
        style = re.search(r'"style": "(\w+)"', block).group(1)
        name = re.search(r'"name": "([^"]+)"', block).group(1)
        cape = re.search(r'"cape": (Color\([^)]*\))', block)
        looks = {k: _calls(block, k, bvars) for k in ("thug", "knife", "brute", "boss")}
        looks["subboss"] = sub_calls[i]
        eras.append({"idx": i, "style": style, "name": name, "looks": looks,
                     "cape": _color(cape.group(1), {}) if cape else (0, 0, 0, 0)})
    # fase secreta
    sec = _func(src, "secret")
    svars = _variables(sec)
    looks = {k: _calls(sec, k, svars) for k in ("thug", "knife", "brute", "subboss", "secret_boss")}
    cape = re.search(r'"cape": (Color\([^)]*\))', sec)
    eras.append({"idx": len(eras), "style": re.search(r'"style": "(\w+)"', sec).group(1),
                 "name": re.search(r'"name": "([^"]+)"', sec).group(1), "looks": looks,
                 "cape": _color(cape.group(1), {}) if cape else (0, 0, 0, 0)})
    return eras


# Porte de cada tipo (body_scale em enemy.gd) — o jogo aplica a escala; aqui só para a prévia.
KIND_SCALE = {"thug": 1.0, "knife": 1.0, "brute": 1.3, "subboss": 1.3, "boss": 1.5, "secret_boss": 1.6}


def enemy_rigs():
    """Todos os rigs de inimigos como 'personagens' para o blender_rig.py."""
    out = []
    for era in load_enemy_looks():
        for kind, look in era["looks"].items():
            out.append({
                "name": look["name"], "slug": "%s_%s" % (era["style"], kind), "group": "enemies",
                "era": era["name"], "era_idx": era["idx"], "kind": kind,
                "skin": look["skin"], "hair": look["hair"], "hat": look["hat"], "shirt": look["shirt"],
                "pants": look["pants"], "shoes": ENEMY_SHOES, "f": False, "size": KIND_SCALE[kind],
                "cape": era["cape"] if kind in ("boss", "secret_boss") else (0, 0, 0, 0),
            })
    return out


if __name__ == "__main__":
    rigs = enemy_rigs()
    for r in rigs:
        print("%-22s %-26s %-10s %s" % (r["slug"], r["name"], r["hat"], "capa" if r["cape"][3] > 0 else ""))
    print(len(rigs), "rigs de inimigos")
