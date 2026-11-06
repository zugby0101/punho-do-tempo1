"""Procura linhas de GDScript mais indentadas que a anterior sem ':' no fim (erro "Unexpected indent")."""
import sys, re
bad = 0
for fp in sys.argv[1:]:
    prev_ind, prev_line, depth = 0, "", 0
    for n, line in enumerate(open(fp, encoding="utf-8"), 1):
        code = line.rstrip("\n")
        if not code.strip() or code.strip().startswith("#"):
            continue
        ind = len(code) - len(code.lstrip("\t"))
        stripped = re.sub(r'"(\\.|[^"\\])*"', '""', prev_line.split("#")[0]).rstrip()
        cont = depth > 0 or stripped.endswith("\\") or stripped.endswith(":") or stripped.endswith(",") or stripped.endswith("(") or stripped.endswith("[") or stripped.endswith("{")
        if ind > prev_ind and not cont:
            print("%s:%d: %s" % (fp, n, code.strip()[:70])); bad += 1
        s2 = re.sub(r'"(\\.|[^"\\])*"', '""', code.split("#")[0])
        depth += s2.count("(") + s2.count("[") + s2.count("{") - s2.count(")") - s2.count("]") - s2.count("}")
        depth = max(depth, 0)
        prev_ind, prev_line = ind, code
print("suspeitas:", bad)
