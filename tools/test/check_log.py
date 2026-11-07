"""Lê o log do Godot (importação e/ou agente de teste) e diz se o jogo passou.

    python tools/test/check_log.py godot.log [outro.log] [--need-report]

Falha (código 1) se houver:
  * erro de script (SCRIPT ERROR, Parse Error) ou erro do motor (ERROR:) — com o arquivo:linha;
  * falha do agente de teste ([TESTBOT] FALHA) ou relatório com "ok": false;
  * --need-report e o relatório do agente não apareceu (o jogo travou ou nem abriu).
Imprime um resumo em Markdown (também em $GITHUB_STEP_SUMMARY, no GitHub Actions).
"""
import json
import os
import re
import sys

# avisos do ambiente (CI sem som, sem controle...) que não são do jogo
IGNORE = [r"ALSA", r"PulseAudio", r"XOpenIM", r"joypad", r"Joypad", r"udev", r"libdecor", r"Wayland",
          r"No such file or directory.*(pulse|alsa)", r"Couldn't open audio", r"glXCreateContextAttribsARB",
          r"Shader cache", r"--rendering-driver",
          r"resources still in use at exit"]  # aviso do Godot ao fechar (música ainda gerando), não é erro do jogo
ERR = re.compile(r"(SCRIPT ERROR|Parse Error|^ERROR:|USER ERROR|^\s*ERROR:)")
AT = re.compile(r"(res://[\w/\.]+\.(?:gd|tscn)):(\d+)")


def scan(lines):
    errors, fails, report = [], [], None
    for i, ln in enumerate(lines):
        s = ln.rstrip("\n")
        if s.startswith("[TESTBOT] RELATORIO "):
            try:
                report = json.loads(s[len("[TESTBOT] RELATORIO "):])
            except json.JSONDecodeError:
                errors.append(("relatório do agente ilegível", ""))
        elif s.startswith("[TESTBOT] FALHA: "):
            fails.append(s[len("[TESTBOT] FALHA: "):])
        elif ERR.search(s) and not any(re.search(p, s) for p in IGNORE):
            where = ""
            for nxt in lines[i:i + 4]:      # o Godot põe "at: função (res://...:linha)" logo depois
                m = AT.search(nxt)
                if m:
                    where = "%s:%s" % (m.group(1).replace("res://", ""), m.group(2))
                    break
            errors.append((s.strip(), where))
    return errors, fails, report


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    need = "--need-report" in sys.argv
    lines = []
    for fp in args:
        with open(fp, encoding="utf-8", errors="replace") as f:
            lines += f.readlines()
    errors, fails, report = scan(lines)
    uniq = []
    for e in errors:
        if e not in uniq:
            uniq.append(e)
    md = ["## Agente de teste do Punho do Tempo", ""]
    ok = not uniq and not fails and (report is not None or not need) and (report is None or report.get("ok", False))
    md.append("**%s**" % ("✅ tudo passou" if ok else "❌ falhou"))
    if uniq:
        md += ["", "### Erros do Godot (%d)" % len(uniq), "", "| Erro | Onde |", "|---|---|"]
        md += ["| %s | %s |" % (e.replace("|", "\\|")[:180], w or "—") for e, w in uniq[:60]]
    if fails:
        md += ["", "### Regras do jogo que falharam (%d)" % len(fails), ""] + ["- %s" % f for f in fails[:80]]
    sumiu = [l.strip() for l in lines if "[TESTBOT] SUMIU" in l]
    if sumiu:
        md += ["", "### Inimigos que sumiram (%d registros)" % len(sumiu), "", "```"] + [l[l.index("SUMIU"):][:240] for l in sumiu[:40]] + ["```"]
    if report is None and need:
        md += ["", "O relatório do agente não apareceu: o jogo travou, fechou antes ou nem abriu (veja os erros acima)."]
    if report:
        rg = report.get("rigs", {})
        md += ["", "Rigs conferidos: %s, animações: %s · duração: %s s · %s" % (rg.get("rigs"), rg.get("animacoes"), report.get("duracao_s"), report.get("godot", ""))]
        md += ["", "| # | Lutador | Era | Fim | Luta (s) | Pontos | Golpes no ar | Acertos | Passos | Derrubados | Dano causado | Inim. bloq./esq. | Armas pegas/chutadas | Tempo: luta/arma/defesa/caixa/sem alvo |",
               "|---|---|---|---|---|---|---|---|---|---|---|---|---|---|"]
        for p in report.get("partidas", []):
            md.append("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s/%s | %s/%s | %s/%s/%s/%s/%s |" % (
                p.get("partida"), p.get("lutador"), p.get("era"), p.get("fim"), p.get("tempo_de_luta"), p.get("pontos"),
                p.get("som_w", 0), p.get("som_i", 0), p.get("som_st", 0), p.get("inimigos_derrubados", 0),
                p.get("dano_causado", 0), p.get("inimigo_bloqueou", 0), p.get("inimigo_esquivou", 0),
                p.get("armas_pegas", 0), p.get("armas_chutadas", 0),
                p.get("t_luta", 0), p.get("t_arma", 0), p.get("t_defesa", 0), p.get("t_caixa", 0), p.get("t_sem_alvo", 0)))
    text = "\n".join(md)
    print(text)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as f:
            f.write(text + "\n")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
