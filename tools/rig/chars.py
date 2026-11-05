"""Lê os 14 personagens jogáveis de scripts/characters.gd (fonte única dos dados).

Uso: from chars import load_characters
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CHARS_GD = ROOT / "scripts" / "characters.gd"

_COLOR = re.compile(r"Color\(([^)]*)\)")


def _parse_value(v: str):
    v = v.strip()
    m = _COLOR.fullmatch(v)
    if m:
        parts = [float(x) for x in m.group(1).split(",")]
        if len(parts) == 3:
            parts.append(1.0)
        return tuple(parts)
    if v in ("true", "false"):
        return v == "true"
    if v.startswith('"'):
        return v.strip('"')
    return float(v) if "." in v else int(v)


def _split_top(s: str):
    """Divide 'k: v, k: v' respeitando parênteses e aspas."""
    out, depth, cur, quote = [], 0, "", False
    for ch in s:
        if ch == '"':
            quote = not quote
        if not quote:
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
            elif ch == "," and depth == 0:
                out.append(cur)
                cur = ""
                continue
        cur += ch
    if cur.strip():
        out.append(cur)
    return out


def load_characters():
    src = CHARS_GD.read_text(encoding="utf-8")
    body = src[src.index("func _list_base()"):]
    chars = []
    for m in re.finditer(r'\{"name":(.*?)\}', body, re.S):
        text = '"name":' + m.group(1)
        d = {}
        for item in _split_top(text.replace("\n", " ")):
            if ":" not in item:
                continue
            k, v = item.split(":", 1)
            d[k.strip().strip('"')] = _parse_value(v)
        chars.append(d)
    return chars


def slug(name: str) -> str:
    table = str.maketrans("ÁÀÂÃÉÊÍÓÔÕÚÇ", "AAAAEEIOOOUC")
    return re.sub(r"[^a-z0-9]+", "_", name.upper().translate(table).lower()).strip("_")


if __name__ == "__main__":
    for c in load_characters():
        print(c["name"], slug(c["name"]), c["hat"], c["f"], c["size"], c["skin"])
