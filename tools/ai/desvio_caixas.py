"""Simulação do desvio de caixas da IA dos inimigos.

    python tools/ai/desvio_caixas.py

Porta em Python de enemy.gd -> _avoid_crates (desvio) e fighter.gd -> _collide_crates (caixa sólida),
com as medidas de crate.gd. Roda centenas de trajetos (inimigo de um lado da caixa, objetivo do outro,
em todas as faixas de profundidade) com e sem o desvio e conta quantos inimigos ficam presos.
Se mudar o desvio ou a colisão no jogo, mude aqui também e rode de novo.
"""
import math, sys
W, SD = 52.0, 14.0          # crate.gd: largura e meia profundidade da base sólida
DMIN, DMAX = 360.0, 520.0
MARGIN = 6.0

def solid(cr, hw):
    # retângulo que o CENTRO do lutador não pode ocupar (base da caixa + meia largura do corpo)
    return (cr[0] - W / 2 - hw, cr[1] - SD, cr[0] + W / 2 + hw, cr[1] + SD)

def inside(r, p, pad=0.0):
    return r[0] - pad < p[0] < r[2] + pad and r[1] - pad < p[1] < r[3] + pad

def seg_hits(r, a, b, pad):
    for k in range(1, 13):
        t = k / 12.0
        if inside(r, (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t), pad):
            return True
    return False

def avoid(pos, goal, crates, hw, mem):
    for i, cr in enumerate(crates):
        r = solid(cr, hw)
        # objetivo dentro da caixa: troca para a borda de frente/trás mais perto
        if inside(r, goal, MARGIN):
            up, dn = r[1] - MARGIN - 2, r[3] + MARGIN + 2
            goal = (goal[0], up if (abs(goal[1] - up) <= abs(goal[1] - dn) and up >= DMIN) or dn > DMAX else dn)
        if not seg_hits(r, pos, goal, MARGIN - 1):
            if mem.get("c") == i:
                mem.clear()
            continue
        up, dn = r[1] - MARGIN, r[3] + MARGIN
        if mem.get("c") == i:
            ty = mem["y"]
        else:
            cost_up = abs(pos[1] - up) + abs(goal[1] - up) + (1e9 if up < DMIN else 0)
            cost_dn = abs(pos[1] - dn) + abs(goal[1] - dn) + (1e9 if dn > DMAX else 0)
            ty = up if cost_up <= cost_dn else dn
            mem.update(c=i, y=ty)
        far_x = r[2] + MARGIN if goal[0] > cr[0] else r[0] - MARGIN
        near_x = r[0] - MARGIN if pos[0] < cr[0] else r[2] + MARGIN
        if abs(pos[1] - ty) > 3.0 and not (r[0] - MARGIN < pos[0] < r[2] + MARGIN):
            return (near_x, ty)
        return (far_x, ty)
    return goal

def collide(pos, crates, hw, facing=1):
    x, y = pos
    for cr in crates:
        dx, dy = x - cr[0], y - cr[1]
        px = (W / 2 + hw) - abs(dx)
        py = SD - abs(dy)
        if px <= 0 or py <= 0:
            continue
        if px < py:
            x = cr[0] + math.copysign(W / 2 + hw, dx if dx else -facing)
        else:
            y = cr[1] + math.copysign(SD, dy if dy else 1.0)
    return (x, y)

def run(start, goal, crates, smart, speed=(110, 70), hw=16.0, T=6.0, dt=1/60):
    pos, mem = start, {}
    for step in range(int(T / dt)):
        g = avoid(pos, goal, crates, hw, mem) if smart else goal
        to = (g[0] - pos[0], g[1] - pos[1])
        l = math.hypot(*to)
        if math.hypot(goal[0] - pos[0], goal[1] - pos[1]) <= 6.0:
            return step * dt
        if l > 0.001:
            v = (to[0] / l * speed[0], to[1] / l * speed[1])
            pos = (pos[0] + v[0] * dt, pos[1] + v[1] * dt)
        pos = collide(pos, crates, hw)
        pos = (pos[0], min(max(pos[1], DMIN), DMAX))
    return None

crates = [(0.0, 440.0)]
cases = []
for sy in range(380, 505, 15):
    for gy in range(380, 505, 15):
        cases.append(((-200.0, float(sy)), (150.0, float(gy))))
        cases.append(((200.0, float(sy)), (-150.0, float(gy))))
# objetivo colado na caixa (jogador encostado nela)
for gy in (430.0, 440.0, 450.0):
    cases.append(((-200.0, 440.0), (60.0, gy)))
# duas caixas lado a lado em profundidade, e caixa encostada no chão de trás
crates2 = [(0.0, 420.0), (0.0, 460.0)]
crates3 = [(0.0, 368.0)]
for name, crs, cs in (("1 caixa", crates, cases),
                      ("2 caixas empilhadas em profundidade", crates2, [((-200.0, 440.0), (150.0, 440.0)), ((-200.0, 400.0), (150.0, 480.0))]),
                      ("caixa encostada no fundo", crates3, [((-200.0, 370.0), (150.0, 370.0)), ((-200.0, 400.0), (150.0, 365.0))])):
    for smart in (False, True):
        res = [run(s, g, crs, smart) for s, g in cs]
        stuck = sum(r is None for r in res)
        ok = [r for r in res if r is not None]
        print("%-38s %-8s presos: %3d de %3d   tempo médio: %.2f s" % (name, "desvio" if smart else "antes", stuck, len(res), sum(ok) / max(len(ok), 1)))
