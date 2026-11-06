"""Animações de combate dos 79 rigs (lutadores, inimigos, sub-chefes e chefes).

Cada animação é uma lista de POSES-CHAVE com a curva de suavização do trecho seguinte
(interpolação do Blender: SINE, EXPO, BACK, CUBIC, CONSTANT...). O Blender interpola e
resolve o IK; o resultado é amostrado e exportado para o Godot.

Princípios aplicados: antecipação, golpe rápido até o impacto, excesso (overshoot),
sustentação, recuperação com assentamento, arcos, contrapeso, atraso da cabeça (overlap),
peso por tipo de personagem e personalidade por estilo de luta.

Linha do tempo dos golpes (u = 0..1), igual à que o jogo usa (fighter.gd -> _rig_anim):
    0.00 ........ 0.30   preparação (startup do golpe)  -> antecipação
    0.30 ........ 0.42   janela de acerto (active)       -> impacto + excesso + sustentação
    0.42 ........ 1.00   recuperação (recovery)          -> volta à guarda com assentamento

Coordenadas do jogo: pixels, origem nos pés, x para a frente, y para BAIXO.
"""
import math
from dataclasses import dataclass, field, replace

SPINE = 32.0  # distância quadril -> ombro (comprimento do osso spine)

# Marcos da linha do tempo dos golpes
U_ANT, U_HIT, U_OVER, U_HOLD = 0.26, 0.30, 0.345, 0.42


@dataclass
class Profile:
    """Personalidade de movimento de um rig."""
    idle: str = "bounce"           # tipo de idle (ver idle_keys)
    crouch: float = 2.0            # base mais baixa (px)
    lean: float = 2.0              # inclinação do tronco para a frente (px no ombro)
    hip_x: float = 0.0
    ff: float = 10.0               # pé da frente (x)
    bf: float = -9.0               # pé de trás (x)
    gf: tuple = (18.0, 3.0)        # mão da frente, relativa ao ombro
    gb: tuple = (9.0, 7.0)         # mão de trás, relativa ao ombro
    tempo: float = 1.0             # duração do loop de idle (s)
    bounce: float = 2.0            # amplitude do idle (px)
    weight: float = 0.5            # 0 leve ... 1 pesado (antecipação mais funda, menos excesso)
    kick_h: float = 44.0           # altura do pé no chute (px acima do chão)
    reach: float = 1.0             # alcance dos socos
    stride: float = 12.0           # passada da caminhada
    lift: float = 5.0              # altura do pé na passada
    hover: bool = False            # flutua (ÉON)
    mech: bool = False             # movimento mecânico (robôs)
    tags: list = field(default_factory=list)


def _rot(v, a):
    """Gira um vetor (y para baixo): a > 0 gira no sentido horário da tela."""
    return (v[0] * math.cos(a) - v[1] * math.sin(a), v[0] * math.sin(a) + v[1] * math.cos(a))


def pose(pr, hip_dx=0.0, crouch=0.0, lean=0.0, hf=None, hb=None, ff=None, bf=None, tilt=0.0, weapon=-1.05, lift=0.0):
    """Monta uma pose completa a partir do perfil e de ajustes.
    Mãos são relativas ao ombro (acompanham o tronco); pés são absolutos (plantados)."""
    hy = -36.0 + pr.crouch + crouch - (10.0 if pr.hover else 0.0) - lift
    hip = [pr.hip_x + hip_dx, hy]
    lt = max(-24.0, min(24.0, pr.lean + lean))
    sh = [hip[0] + lt, hip[1] - math.sqrt(SPINE * SPINE - lt * lt)]
    torso = math.atan2(lt, SPINE)
    hd = _rot((3.0, -15.0), torso * 0.45 + tilt)  # a cabeça acompanha só metade da inclinação
    head = [sh[0] + hd[0], sh[1] + hd[1]]
    rf = hf if hf is not None else pr.gf
    rb = hb if hb is not None else pr.gb
    fy = -10.0 if pr.hover else 0.0
    out = {
        "hip": hip, "shoulder": sh, "head": head,
        "hf": [sh[0] + rf[0], sh[1] + rf[1]], "hb": [sh[0] + rb[0], sh[1] + rb[1]],
        "ff": list(ff) if ff is not None else [pr.ff, fy], "bf": list(bf) if bf is not None else [pr.bf, fy],
        "weapon": weapon,
    }
    if pr.hover:  # pernas soltas: os pés acompanham o corpo
        for k in ("ff", "bf"):
            if ff is None and k == "ff" or bf is None and k == "bf":
                out[k][1] = hy + 26.0
    return out


def K(u, ps, interp="SINE", easing="EASE_IN_OUT", **kw):
    """Pose-chave: tempo, pose e curva do trecho que COMEÇA nesta chave."""
    d = {"t": u, "pose": ps, "interp": interp, "easing": easing}
    d.update(kw)
    return d


# ---------------------------------------------------------------------------
# Perfis: um por estilo de luta dos lutadores; inimigos por tipo


def player_profile(slug):
    P = Profile
    table = {
        "mateus": P(idle="ginga", crouch=7, lean=3, ff=13, bf=-13, gf=(16, 12), gb=(12, -6), tempo=1.6, bounce=5, weight=0.3, kick_h=62, stride=14, tags=["acrobat"]),
        "valentina": P(idle="bounce", crouch=3, lean=4, gf=(15, 0), gb=(10, -2), tempo=0.55, bounce=2.5, weight=0.35, reach=1.05),
        "jake": P(idle="wrestler", crouch=6, lean=7, ff=12, bf=-11, gf=(22, 16), gb=(16, 20), tempo=1.4, bounce=2, weight=0.8, kick_h=34, stride=11),
        "itzel": P(idle="bounce", crouch=4, lean=3, gf=(17, 4), gb=(10, 4), tempo=0.5, bounce=3.5, weight=0.3, kick_h=52, tags=["acrobat"]),
        "dmitri": P(idle="wrestler", crouch=7, lean=8, ff=12, bf=-12, gf=(20, 14), gb=(14, 18), tempo=1.6, bounce=2, weight=0.9, kick_h=34, stride=10),
        "oksana": P(idle="dance", crouch=2, lean=1, gf=(18, 2), gb=(8, 6), tempo=0.8, bounce=3, weight=0.25, kick_h=62, tags=["acrobat"]),
        "luca": P(idle="bounce", crouch=3, lean=3, gf=(16, 2), gb=(10, 0), tempo=0.6, bounce=2.5, weight=0.45, kick_h=54),
        "amelie": P(idle="bounce", crouch=1, lean=1, ff=11, bf=-10, gf=(18, 6), gb=(10, 8), tempo=0.7, bounce=2, weight=0.25, kick_h=60),
        "kai": P(idle="still", crouch=8, lean=2, ff=15, bf=-14, gf=(24, 2), gb=(8, 12), tempo=2.4, bounce=1, weight=0.5, kick_h=48),
        "mei": P(idle="open", crouch=6, lean=0, ff=14, bf=-12, gf=(26, -6), gb=(4, 12), tempo=2.0, bounce=1.5, weight=0.3, kick_h=58, tags=["acrobat"]),
        "kofi": P(idle="bounce", crouch=4, lean=5, gf=(22, 4), gb=(9, 0), tempo=0.7, bounce=2, weight=0.65, reach=1.08),
        "amara": P(idle="wrestler", crouch=5, lean=5, ff=11, bf=-11, gf=(19, 10), gb=(12, 12), tempo=1.2, bounce=2, weight=0.5, kick_h=40),
        "tama": P(idle="haka", crouch=9, lean=4, ff=16, bf=-15, gf=(20, 12), gb=(12, 14), tempo=1.2, bounce=3, weight=0.85, kick_h=36, stride=11),
        "kirra": P(idle="muaythai", crouch=2, lean=2, gf=(14, -3), gb=(9, -2), tempo=0.9, bounce=2, weight=0.4, kick_h=58),
    }
    return table.get(slug, Profile())


def enemy_profile(kind, hat):
    P = Profile
    if kind == "secret_boss":
        pr = P(idle="hover", crouch=0, lean=1, ff=8, bf=-8, gf=(20, 10), gb=(10, 12), tempo=2.1, bounce=3, weight=0.7, kick_h=40, hover=True)
    elif kind == "boss":
        pr = P(idle="menace", crouch=3, lean=-1, ff=12, bf=-11, gf=(17, 14), gb=(10, 16), tempo=1.8, bounce=1.5, weight=0.85, kick_h=40, stride=10)
    elif kind == "subboss":
        pr = P(idle="bounce", crouch=4, lean=4, gf=(17, 2), gb=(10, 2), tempo=0.8, bounce=2, weight=0.6, kick_h=48)
    elif kind == "brute":
        pr = P(idle="heavy", crouch=5, lean=7, ff=12, bf=-11, gf=(14, 22), gb=(7, 24), tempo=1.6, bounce=2, weight=1.0, kick_h=30, stride=9, lift=4)
    elif kind == "knife":
        pr = P(idle="agile", crouch=8, lean=5, ff=14, bf=-13, gf=(20, 6), gb=(8, 8), tempo=0.8, bounce=2.5, weight=0.2, kick_h=50, stride=14)
    else:  # thug
        pr = P(idle="brawler", crouch=2, lean=3, gf=(16, 9), gb=(8, 12), tempo=1.3, bounce=1.5, weight=0.55, kick_h=32)
    if hat == "ninja":
        pr = replace(pr, idle="agile", crouch=9, weight=min(pr.weight, 0.3), kick_h=max(pr.kick_h, 52))
    if hat in ("robot", "visor"):
        pr = replace(pr, mech=True, idle="mech")
    return pr


# ---------------------------------------------------------------------------
# Idle e caminhada (loops: tempo em segundos)


def idle_keys(pr):
    T = pr.tempo
    b = pr.bounce
    kind = pr.idle
    if kind == "ginga":  # capoeira: troca de base, braços cruzando o rosto
        a = pose(pr, hip_dx=-3, crouch=2, lean=-1, ff=(14, 0), bf=(-14, 0), hf=(16, 14), hb=(14, -8), tilt=-0.05)
        mid = pose(pr, hip_dx=0, crouch=b + 2, lean=2, ff=(6, 0), bf=(-4, 0), hf=(18, 4), hb=(16, 2))
        c = pose(pr, hip_dx=3, crouch=2, lean=4, ff=(-12, 0), bf=(12, 0), hf=(14, -8), hb=(12, 14), tilt=0.06)
        return [K(0, a), K(T * 0.25, mid), K(T * 0.5, c), K(T * 0.75, mid), K(T, a)]
    if kind == "bounce":  # boxe: quique leve na ponta dos pés
        up = pose(pr)
        down = pose(pr, crouch=b, hf=(pr.gf[0], pr.gf[1] + b * 0.4), hb=(pr.gb[0], pr.gb[1] + b * 0.4))
        return [K(0, up, "SINE", "EASE_IN"), K(T * 0.5, down, "SINE", "EASE_OUT"), K(T, up)]
    if kind == "still":  # caratê: base baixa, só a respiração
        a = pose(pr)
        bb = pose(pr, crouch=b, lean=0.6, hf=(pr.gf[0], pr.gf[1] - 1), hb=(pr.gb[0], pr.gb[1] - 1))
        return [K(0, a), K(T * 0.5, bb), K(T, a)]
    if kind == "open":  # kung fu: peso balança entre as pernas, mão aberta à frente
        a = pose(pr, hip_dx=-2, hf=(26, -6), hb=(4, 12), tilt=-0.04)
        bb = pose(pr, hip_dx=2, crouch=b, hf=(24, -2), hb=(6, 10), tilt=0.03)
        return [K(0, a), K(T * 0.5, bb), K(T, a)]
    if kind == "wrestler":  # luta: transfere o peso de lado a lado, braços abertos baixos
        a = pose(pr, hip_dx=-3, lean=1, tilt=-0.03)
        bb = pose(pr, hip_dx=3, crouch=b, lean=-1, hf=(pr.gf[0] + 2, pr.gf[1] - 2), tilt=0.03)
        return [K(0, a), K(T * 0.5, bb), K(T, a)]
    if kind == "dance":  # hopak: quique alto e alegre
        up = pose(pr, crouch=-1, hf=(18, 0), hb=(8, 4))
        down = pose(pr, crouch=b + 2, hf=(18, 4), hb=(8, 8))
        return [K(0, up, "QUAD", "EASE_OUT"), K(T * 0.5, down, "QUAD", "EASE_IN"), K(T, up)]
    if kind == "muaythai":  # muay thai: ritmo marcado com a perna da frente
        a = pose(pr)
        tap = pose(pr, crouch=b, ff=(pr.ff - 2, -6), hip_dx=-1)
        return [K(0, a, "SINE", "EASE_OUT"), K(T * 0.35, tap, "SINE", "EASE_IN"), K(T * 0.7, a), K(T, a)]
    if kind == "haka":  # haka: base larga, pisada forte
        a = pose(pr)
        lift = pose(pr, crouch=-2, ff=(pr.ff, -10), lean=-2, hf=(24, 6), hb=(16, 8))
        stomp = pose(pr, crouch=b + 3, lean=3, hf=(20, 14), hb=(12, 16))
        return [K(0, a), K(T * 0.35, lift, "QUAD", "EASE_IN"), K(T * 0.5, stomp, "SINE", "EASE_OUT"), K(T, a)]
    if kind == "hover":  # ÉON: flutua, pernas soltas, braços abertos
        a = pose(pr, lift=0, hf=(22, 12), hb=(-12, 12))
        bb = pose(pr, lift=b * 2, hf=(24, 8), hb=(-14, 8), tilt=0.04)
        return [K(0, a), K(T * 0.5, bb), K(T, a)]
    if kind == "mech":  # robô: ajustes bruscos, em degraus
        a = pose(pr)
        s1 = pose(pr, crouch=1, hf=(pr.gf[0] + 2, pr.gf[1]), tilt=0.06)
        s2 = pose(pr, crouch=0, hb=(pr.gb[0] + 2, pr.gb[1] - 1), tilt=-0.06)
        return [K(0, a, "CONSTANT"), K(T * 0.25, s1, "CONSTANT"), K(T * 0.5, a, "CONSTANT"), K(T * 0.75, s2, "CONSTANT"), K(T, a)]
    if kind == "heavy":  # grandalhão: respiração pesada, ombros sobem
        a = pose(pr)
        bb = pose(pr, crouch=b, lean=2, hf=(pr.gf[0], pr.gf[1] + 2), hb=(pr.gb[0], pr.gb[1] + 2))
        return [K(0, a, "SINE", "EASE_OUT"), K(T * 0.6, bb, "SINE", "EASE_IN_OUT"), K(T, a)]
    if kind == "menace":  # chefe: peito estufado, balanço lento e ameaçador
        a = pose(pr, tilt=-0.05)
        bb = pose(pr, crouch=b, lean=3, hip_dx=1, hf=(pr.gf[0] + 2, pr.gf[1] - 2), tilt=0.03)
        return [K(0, a), K(T * 0.5, bb), K(T, a)]
    if kind == "agile":  # ágil: agachado, troca o peso rápido
        a = pose(pr, hip_dx=-2)
        bb = pose(pr, hip_dx=2, crouch=b)
        return [K(0, a, "QUAD", "EASE_IN_OUT"), K(T * 0.5, bb, "QUAD", "EASE_IN_OUT"), K(T, a)]
    # brawler: desleixado, ombros rolando
    a = pose(pr, hip_dx=-1, lean=0, tilt=-0.03)
    bb = pose(pr, hip_dx=1, crouch=b, lean=2, hf=(pr.gf[0] + 2, pr.gf[1] + 2), hb=(pr.gb[0] - 1, pr.gb[1]), tilt=0.04)
    return [K(0, a), K(T * 0.5, bb), K(T, a)]


WALK_LEN = 2.0 * math.pi / 12.0  # mesmo ritmo do jogo


def walk_keys(pr):
    T = WALK_LEN
    s, l = pr.stride, pr.lift
    ff0, bf0 = pr.ff, pr.bf
    fy = -10.0 if pr.hover else 0.0
    if pr.hover:  # desliza: pernas soltas balançando
        a = pose(pr, lift=1, lean=4, ff=(ff0 + 4, fy - 2), bf=(bf0 - 2, fy))
        bb = pose(pr, lift=3, lean=5, ff=(ff0 - 2, fy), bf=(bf0 + 4, fy - 2))
        return [K(0, a), K(T * 0.5, bb), K(T, a)]
    arm = 4.0
    # contato A (pé da frente à frente), descida, passagem, subida, contato B (espelhado)...
    cA = pose(pr, crouch=0.5, ff=(ff0 + s * 0.5, 0), bf=(bf0 - s * 0.5, 0), hf=(pr.gf[0] - arm, pr.gf[1]), hb=(pr.gb[0] + arm, pr.gb[1]))
    dA = pose(pr, crouch=2.5, ff=(ff0 + s * 0.3, 0), bf=(bf0 - s * 0.2, -1), hf=(pr.gf[0] - arm * 0.5, pr.gf[1] + 1), hb=(pr.gb[0] + arm * 0.5, pr.gb[1] + 1))
    pA = pose(pr, crouch=0, ff=(ff0, 0), bf=((ff0 + bf0) / 2, -l), hf=(pr.gf[0], pr.gf[1]), hb=(pr.gb[0], pr.gb[1]))
    uA = pose(pr, crouch=-1.5, ff=(ff0 - s * 0.3, 0), bf=(bf0 + s * 0.4, -l * 0.6), hf=(pr.gf[0] + arm * 0.5, pr.gf[1]), hb=(pr.gb[0] - arm * 0.5, pr.gb[1]))
    cB = pose(pr, crouch=0.5, ff=(ff0 - s * 0.5, 0), bf=(bf0 + s * 0.5, 0), hf=(pr.gf[0] + arm, pr.gf[1]), hb=(pr.gb[0] - arm, pr.gb[1]))
    dB = pose(pr, crouch=2.5, ff=(ff0 - s * 0.2, -1), bf=(bf0 + s * 0.3, 0), hf=(pr.gf[0] + arm * 0.5, pr.gf[1] + 1), hb=(pr.gb[0] - arm * 0.5, pr.gb[1] + 1))
    pB = pose(pr, crouch=0, ff=((ff0 + bf0) / 2 + 4, -l), bf=(bf0, 0))
    uB = pose(pr, crouch=-1.5, ff=(ff0 + s * 0.4, -l * 0.6), bf=(bf0 - s * 0.3, 0), hf=(pr.gf[0] - arm * 0.5, pr.gf[1]), hb=(pr.gb[0] + arm * 0.5, pr.gb[1]))
    ip = "LINEAR" if pr.mech else "SINE"
    n = T / 8.0
    return [K(0, cA, ip), K(n, dA, ip), K(2 * n, pA, ip), K(3 * n, uA, ip), K(4 * n, cB, ip), K(5 * n, dB, ip),
            K(6 * n, pB, ip), K(7 * n, uB, ip), K(T, cA)]


# ---------------------------------------------------------------------------
# Golpes (u = 0..1)


def _fp(pr, **kw):
    """pose() das animações novas (bloqueio, esquiva, finalização): quem flutua (ÉON) não pisa no
    chão — os pés acompanham o corpo em vez de ir para as posições pedidas."""
    if pr.hover:
        kw.pop("ff", None)
        kw.pop("bf", None)
    return pose(pr, **kw)


def _strike(pr, guard, ant, hit, over, mid, settle_back=1.4):
    """Estrutura padrão: guarda -> antecipação -> IMPACTO -> excesso -> sustenta -> recupera -> assenta."""
    w = pr.weight
    u_ant = U_ANT - 0.05 * w  # pesados preparam mais cedo (antecipação mais longa)
    keys = [
        K(0.0, guard, "SINE", "EASE_IN_OUT"),
        K(u_ant, ant, "EXPO", "EASE_IN"),          # solta o golpe acelerando
        K(U_HIT, hit, "QUAD", "EASE_OUT"),          # impacto exatamente no início da janela de acerto
        K(U_OVER, over, "SINE", "EASE_IN_OUT"),     # excesso (follow-through)
        K(U_HOLD, over, "CUBIC", "EASE_IN_OUT"),    # sustenta durante o acerto
        K(0.68, mid, "BACK", "EASE_OUT", back=settle_back * (1.0 - 0.5 * w)),  # volta e assenta com leve excesso
        K(1.0, guard),
    ]
    if pr.mech:
        for k in keys:
            if k["interp"] in ("SINE", "CUBIC", "BACK"):
                k["interp"] = "LINEAR"
    return keys


def attack_keys(anim, pr):
    g = pose(pr)
    w = pr.weight
    r = pr.reach
    deep = 1.0 + w  # profundidade da antecipação
    if anim == "jab":
        ant = pose(pr, lean=-2 * deep, hip_dx=-1, hf=(pr.gf[0] - 5 * deep, pr.gf[1] + 1), tilt=-0.04)
        hit = pose(pr, lean=6, hip_dx=2, hf=(37 * r, 1), hb=(pr.gb[0] + 1, pr.gb[1] - 2), ff=(pr.ff + 3, 0), tilt=0.06)
        over = pose(pr, lean=7, hip_dx=2.5, hf=(40 * r, 2), hb=(pr.gb[0] + 1, pr.gb[1] - 2), ff=(pr.ff + 3, 0), tilt=0.07)
        mid = pose(pr, lean=2, hf=(pr.gf[0] + 4, pr.gf[1] + 3))
        return _strike(pr, g, ant, hit, over, mid)
    if anim == "cross":
        ant = pose(pr, lean=-3 * deep, hip_dx=-2, hb=(pr.gb[0] - 6 * deep, pr.gb[1] + 2), tilt=-0.05)
        hit = pose(pr, lean=10, hip_dx=4, hb=(39 * r, 0), hf=(pr.gf[0] - 6, pr.gf[1] + 4), bf=(pr.bf + 5, -3), tilt=0.1)
        over = pose(pr, lean=11, hip_dx=4.5, hb=(42 * r, 1), hf=(pr.gf[0] - 6, pr.gf[1] + 4), bf=(pr.bf + 5, -3), tilt=0.11)
        mid = pose(pr, lean=3, hip_dx=1, hb=(pr.gb[0] + 6, pr.gb[1] + 2))
        return _strike(pr, g, ant, hit, over, mid)
    if anim == "upper":
        ant = pose(pr, crouch=5 * deep, lean=-1, hf=(10, 24), tilt=0.05)
        hit = pose(pr, crouch=-3, lean=5, hf=(24, -30), hb=(pr.gb[0], pr.gb[1] - 2), tilt=-0.12)
        over = pose(pr, crouch=-4, lean=6, hf=(22, -36), hb=(pr.gb[0], pr.gb[1] - 2), tilt=-0.14)
        mid = pose(pr, crouch=1, lean=3, hf=(20, -6))
        return _strike(pr, g, ant, hit, over, mid)
    if anim == "kick":
        kh = pr.kick_h
        chamber = pose(pr, lean=-4, ff=(18, -kh * 0.5), hf=(12, 12), hb=(-2, 4), tilt=0.03)
        hit = pose(pr, lean=-12, hip_dx=-2, ff=(54, -kh), hf=(22, 14), hb=(-14, 2), tilt=0.12)
        over = pose(pr, lean=-13, hip_dx=-2, ff=(56, -kh - 3), hf=(22, 16), hb=(-16, 2), tilt=0.13)
        rechamber = pose(pr, lean=-5, ff=(20, -kh * 0.45), hf=(14, 10), hb=(0, 4))
        keys = _strike(pr, g, chamber, hit, over, rechamber, settle_back=1.0)
        return keys
    if anim == "swing":
        ant = pose(pr, lean=-6, hip_dx=-2, hf=(-14, -26), hb=(-8, -16), weapon=-2.6, tilt=-0.08)
        top = pose(pr, lean=1, hf=(12, -28), hb=(4, -14), weapon=-1.3)  # arco: passa por cima
        hit = pose(pr, lean=9, hip_dx=3, crouch=1, hf=(33, 6), hb=(24, 8), weapon=0.35, tilt=0.08)
        over = pose(pr, lean=10, hip_dx=3, crouch=3, hf=(28, 20), hb=(20, 18), weapon=0.8, tilt=0.1)
        mid = pose(pr, lean=3, hf=(20, 2), weapon=-0.6)
        keys = _strike(pr, g, ant, hit, over, mid)
        keys.insert(2, K(U_HIT - 0.02, top, "LINEAR"))
        keys[1]["interp"] = "QUAD"
        return keys
    if anim == "slam":
        ant = pose(pr, crouch=-4, lean=-6, hf=(4, -34), hb=(-4, -32), tilt=-0.12)
        hit = pose(pr, crouch=8, lean=11, hf=(33, 26), hb=(28, 28), tilt=0.12)
        over = pose(pr, crouch=11, lean=12, hf=(32, 30), hb=(27, 32), tilt=0.14)
        mid = pose(pr, crouch=4, lean=5, hf=(22, 14), hb=(16, 16))
        keys = _strike(pr, g, ant, hit, over, mid, settle_back=0.8)
        keys.insert(1, K(0.1, pose(pr, crouch=4 + 3 * w, lean=-2, hf=(14, 18), hb=(8, 18)), "QUAD", "EASE_OUT"))  # agacha antes de subir
        return keys
    if anim == "charge":
        ant = pose(pr, crouch=8, lean=-6, hf=(-6, 14), hb=(-12, 10), ff=(pr.ff + 2, 0), bf=(pr.bf - 4, 0), tilt=0.05)
        hit = pose(pr, crouch=4, lean=15, hf=(30, 6), hb=(24, 10), ff=(18, 0), bf=(-18, -5), tilt=0.05)
        over = pose(pr, crouch=4, lean=16, hf=(31, 8), hb=(25, 12), ff=(14, -4), bf=(-12, 0), tilt=0.06)
        mid = pose(pr, crouch=6, lean=-2, ff=(pr.ff + 6, 0), bf=(pr.bf - 2, 0))  # freia derrapando
        keys = _strike(pr, g, ant, hit, over, mid, settle_back=0.6)
        return keys
    if anim == "throw":
        ant = pose(pr, lean=-6, hf=(-22, -14), hb=(16, 4), tilt=-0.08)
        hit = pose(pr, lean=9, hip_dx=3, hf=(38, 2), hb=(-6, 8), bf=(pr.bf + 4, -2), tilt=0.08)
        over = pose(pr, lean=10, hip_dx=3, hf=(33, 16), hb=(-8, 10), bf=(pr.bf + 4, -2), tilt=0.1)
        mid = pose(pr, lean=3, hf=(24, 8))
        return _strike(pr, g, ant, hit, over, mid)
    if anim == "special":  # giro (o jogo espelha o corpo durante o giro)
        ant = pose(pr, crouch=6, lean=-2, hf=(10, 12), hb=(6, 12))
        hit = pose(pr, crouch=4, lean=0, hf=(43, -1), hb=(-43, -1), ff=(16, 0), bf=(-16, 0))
        over = pose(pr, crouch=5, lean=0, hf=(42, 3), hb=(-42, 3), ff=(17, 0), bf=(-17, 0))
        mid = pose(pr, crouch=3, hf=(26, 8), hb=(-10, 8))
        return _strike(pr, g, ant, hit, over, mid)
    if anim == "dive":  # mergulho voador (o jogo gira o corpo para a horizontal)
        ant = pose(pr, crouch=8, lean=-4, hf=(-6, 10), hb=(-10, 8))
        hit = pose(pr, crouch=0, lean=0, hf=(4, -30), hb=(-2, -28), ff=(6, 4), bf=(-6, 4))
        over = pose(pr, crouch=0, lean=0, hf=(5, -31), hb=(-1, -29), ff=(7, 3), bf=(-5, 5))
        mid = pose(pr, crouch=3, hf=(18, -6))
        return _strike(pr, g, ant, hit, over, mid)
    if anim == "finisher":  # finalização: preparação funda e golpe final com o corpo todo
        if pr.kick_h >= 54 or "acrobat" in pr.tags:
            # quem chuta alto finaliza com um chute alto girando o tronco
            kh = pr.kick_h
            ant = _fp(pr, crouch=6 + 3 * w, lean=-7, hip_dx=-2, ff=(pr.ff + 6, -kh * 0.3), hf=(6, 6), hb=(-12, 2), tilt=-0.12)
            hit = _fp(pr, lean=-15, hip_dx=-3, ff=(54, -kh - 12), hf=(22, 12), hb=(-18, 0), tilt=0.16)
            over = _fp(pr, lean=-16, hip_dx=-3, ff=(56, -kh - 16), hf=(22, 14), hb=(-20, 0), tilt=0.17)
            mid = _fp(pr, lean=-5, crouch=3, ff=(22, -kh * 0.4), hf=(14, 10), hb=(0, 4))
            return _strike(pr, g, ant, hit, over, mid, settle_back=0.9)
        # os outros: os dois braços lá atrás e as duas mãos à frente, com o peso do corpo
        ant = _fp(pr, crouch=5 + 3 * w, lean=-8, hip_dx=-3, hf=(-14, -20), hb=(-18, -14), bf=(pr.bf - 4, 0), tilt=-0.12)
        hit = _fp(pr, crouch=2, lean=14, hip_dx=5, hf=(38 * r, 6), hb=(35 * r, 10), ff=(pr.ff + 6, 0), bf=(pr.bf + 6, -3), tilt=0.12)
        over = _fp(pr, crouch=3, lean=15, hip_dx=5.5, hf=(40 * r, 8), hb=(37 * r, 12), ff=(pr.ff + 6, 0), bf=(pr.bf + 6, -3), tilt=0.13)
        mid = _fp(pr, crouch=2, lean=4, hf=(pr.gf[0] + 4, pr.gf[1] + 4), hb=(pr.gb[0] + 2, pr.gb[1] + 2))
        return _strike(pr, g, ant, hit, over, mid, settle_back=0.8)
    raise KeyError(anim)


# ---------------------------------------------------------------------------
# Defesa: bloqueio e esquiva (u = 0..1, o jogo informa o progresso)


def defense_keys(anim, pr):
    g = pose(pr)
    w = pr.weight
    if anim == "block":
        # sobe a guarda rápido (0 -> 0,18), segura os antebraços na frente do rosto (até 0,75) e baixa
        up = _fp(pr, crouch=3 + 2 * w, lean=-3, hip_dx=-2, hf=(16, -10), hb=(12, -6), ff=(pr.ff - 2, 0), bf=(pr.bf - 3, 0), tilt=0.12)
        hold = _fp(pr, crouch=4 + 2 * w, lean=-2, hip_dx=-2, hf=(16, -8), hb=(12, -4), ff=(pr.ff - 2, 0), bf=(pr.bf - 3, 0), tilt=0.1)
        keys = [K(0.0, g, "EXPO", "EASE_OUT"), K(0.18, up, "SINE", "EASE_IN_OUT"), K(0.75, hold, "SINE", "EASE_IN_OUT"), K(1.0, g)]
    elif anim == "dodge":
        # passo para trás: abaixa, salta inclinado para trás com os pés soltos e aterrissa assentando
        crouch = _fp(pr, crouch=6 + 2 * w, lean=4, hf=(pr.gf[0] - 2, pr.gf[1] + 2), hb=(pr.gb[0] - 2, pr.gb[1] + 2))
        air = _fp(pr, crouch=-3, lean=-10, hip_dx=-6, ff=(pr.ff - 4, -8), bf=(pr.bf - 6, -4), hf=(14, -6), hb=(8, -4), tilt=-0.15)
        land = _fp(pr, crouch=7 + 2 * w, lean=3, hip_dx=-2, ff=(pr.ff, 0), bf=(pr.bf - 2, 0))
        keys = [K(0.0, g, "QUAD", "EASE_OUT"), K(0.12, crouch, "EXPO", "EASE_OUT"), K(0.4, air, "SINE", "EASE_IN"),
                K(0.7, land, "BACK", "EASE_OUT", back=1.2), K(1.0, g)]
    else:
        raise KeyError(anim)
    if pr.mech:
        for k in keys:
            if k["interp"] in ("SINE", "CUBIC", "BACK", "EXPO", "QUAD"):
                k["interp"] = "LINEAR"
    return keys


# ---------------------------------------------------------------------------
# Ar, dano, queda e levantada (u = 0..1, o jogo informa o progresso)


def state_keys(anim, pr):
    g = pose(pr)
    if anim == "jump":  # impulso -> encolhe no alto -> estende para aterrissar
        take = pose(pr, crouch=-2, lean=1, ff=(6, 2), bf=(-4, 2), hf=(10, -24), hb=(2, -20))
        tuck = pose(pr, crouch=0, ff=(12, -16), bf=(-8, -12), hf=pr.gf, hb=pr.gb)
        land = pose(pr, crouch=0, lean=-2, ff=(12, 0), bf=(-9, 0), hf=(26, -4), hb=(-10, -2))
        return [K(0, take, "QUAD", "EASE_OUT"), K(0.5, tuck, "SINE", "EASE_IN_OUT"), K(1.0, land)]
    if anim == "jumpkick":
        tuck = pose(pr, ff=(14, -20), bf=(-8, -16), hf=(8, -2), hb=(-6, 2))
        kick = pose(pr, lean=-8, ff=(46, -22), bf=(-12, -16), hf=(6, -2), hb=(-16, 2), tilt=0.1)
        return [K(0, tuck, "EXPO", "EASE_IN"), K(0.4, kick, "SINE", "EASE_IN_OUT"), K(1.0, kick)]
    if anim == "hurt":  # estalo para trás e recuperação com assentamento
        snap = pose(pr, lean=-14, hip_dx=-3, crouch=2, hf=(-2, -14), hb=(-12, -8), bf=(pr.bf - 4, 0), tilt=-0.35)
        back = pose(pr, lean=-8, hip_dx=-2, crouch=3, hf=(6, 4), hb=(-4, 4), tilt=-0.15)
        return [K(0, g, "EXPO", "EASE_OUT"), K(0.14, snap, "SINE", "EASE_IN_OUT"), K(0.45, back, "BACK", "EASE_OUT", back=1.2), K(1.0, g)]
    if anim == "fall":  # arremessado: membros abrem e depois encolhem
        hit = pose(pr, lean=-14, crouch=2, hf=(-2, -14), hb=(-12, -8), tilt=-0.35)
        spread = pose(pr, lean=-10, hf=(22, -22), hb=(-24, -16), ff=(16, -12), bf=(-14, -4), tilt=-0.2)
        curl = pose(pr, lean=-4, crouch=4, hf=(14, 10), hb=(6, 12), ff=(14, -14), bf=(-2, -12), tilt=-0.1)
        return [K(0, hit, "QUAD", "EASE_OUT"), K(0.4, spread, "SINE", "EASE_IN_OUT"), K(1.0, curl)]
    if anim == "down":  # deitado (o jogo gira o corpo): relaxado
        d = pose(pr, crouch=-2 - pr.crouch, lean=-pr.lean, hf=(6, 22), hb=(-4, 24), ff=(10, -2), bf=(-6, 0), tilt=-0.1)
        return [K(0, d, "CONSTANT")]
    if anim == "getup":  # apoia as mãos, ajoelha e volta à guarda
        d = state_keys("down", pr)[0]["pose"]
        kneel = pose(pr, crouch=14, lean=10, hf=(20, 32), hb=(14, 32), ff=(12, 0), bf=(-6, -2))
        return [K(0, d, "QUAD", "EASE_OUT"), K(0.5, kneel, "BACK", "EASE_OUT", back=1.0), K(1.0, g)]
    raise KeyError(anim)


# ---------------------------------------------------------------------------

LOOPS = ("idle", "walk")
ATTACKS = ("jab", "cross", "upper", "kick", "swing", "slam", "charge", "throw", "special", "dive", "finisher")
STATES = ("jump", "jumpkick", "hurt", "fall", "down", "getup")
DEFENSE = ("block", "dodge")
NEW_ANIMS = ("block", "dodge", "finisher")  # esquiva, bloqueio e finalização (todos os 79 rigs)

PLAYER_ANIMS = list(LOOPS) + list(ATTACKS) + list(STATES) + list(DEFENSE)
ENEMY_ANIMS = ["idle", "walk", "jab", "kick", "slam", "charge", "special", "throw", "swing", "hurt", "fall", "down", "getup",
               "block", "dodge", "finisher"]


def build(anim, pr):
    """{'loop': bool, 'length': s, 'keys': [...]} para uma animação deste perfil."""
    if anim == "idle":
        return {"loop": True, "length": pr.tempo, "keys": idle_keys(pr)}
    if anim == "walk":
        return {"loop": True, "length": WALK_LEN, "keys": walk_keys(pr)}
    if anim in ATTACKS:
        return {"loop": False, "length": 1.0, "keys": attack_keys(anim, pr)}
    if anim in DEFENSE:
        return {"loop": False, "length": 1.0, "keys": defense_keys(anim, pr)}
    return {"loop": False, "length": 1.0, "keys": state_keys(anim, pr)}
