"""Abre a versão web exportada num Chromium sem tela e confere se o jogo roda no navegador.

    python tools/web/smoke_test.py build/web            # abre, espera a tela de título, aperta Enter
    python tools/web/smoke_test.py build/web --bot      # além disso, o agente de teste joga 3 partidas curtas

Serve a pasta num servidor local, lê o console do navegador e falha se aparecer erro de script,
se o motor não iniciar ou (com --bot) se o agente de teste reprovar alguma partida.
Capturas de tela vão para test_output/web/. Requer: pip install playwright && playwright install chromium
"""
import functools
import http.server
import json
import re
import sys
import threading
import time
from pathlib import Path

from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "test_output" / "web"
ERR = re.compile(r"SCRIPT ERROR|Parse Error|USER SCRIPT ERROR|Uncaught|RuntimeError|Aborted\(")


class Quiet(http.server.SimpleHTTPRequestHandler):
    extensions_map = {**http.server.SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm", ".pck": "application/octet-stream"}

    def log_message(self, *a):
        pass


def main():
    web = Path(sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else "build/web").resolve()
    bot = "--bot" in sys.argv
    OUT.mkdir(parents=True, exist_ok=True)
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Quiet, directory=str(web)))
    threading.Thread(target=srv.serve_forever, daemon=True).start()
    url = "http://127.0.0.1:%d/index.html" % srv.server_address[1]
    log, errors = [], []
    report = None
    with sync_playwright() as p:
        browser = p.chromium.launch(args=["--autoplay-policy=no-user-gesture-required", "--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader"])
        page = browser.new_page(viewport={"width": 960, "height": 540})

        def on_console(msg):
            line = msg.text
            log.append(line)
            if ERR.search(line):
                errors.append(line)

        page.on("console", on_console)
        page.on("pageerror", lambda e: errors.append("pageerror: %s" % e))
        if bot:
            # o shell do Godot lê os argumentos de GODOT_CONFIG.args: liga o agente de teste
            def patch(route):
                body = route.fetch().text()
                body = body.replace('"args":[]', '"args":["--","--test-bot","--quick"]', 1)
                route.fulfill(body=body, content_type="text/html")
            page.route("**/index.html", patch)
        t0 = time.time()
        page.goto(url)
        started = False
        while time.time() - t0 < 180 and not errors:
            if any("Godot Engine v4" in line for line in log):
                started = True
                break
            page.wait_for_timeout(500)
        print("motor iniciou: %s em %.1f s" % (started, time.time() - t0), flush=True)
        if started and not bot:
            page.wait_for_timeout(8000)
            page.screenshot(path=str(OUT / "1_titulo.png"))
            page.mouse.click(480, 270)
            for key in ("Enter", "Enter", "Enter"):
                page.keyboard.press(key)
                page.wait_for_timeout(2500)
            page.wait_for_timeout(6000)
            page.screenshot(path=str(OUT / "2_jogo.png"))
        elif started:
            limit = time.time() + 1500
            shot = 0
            while time.time() < limit and not errors:
                rep = [l for l in log if l.startswith("[TESTBOT] RELATORIO ")]
                if rep:
                    report = json.loads(rep[-1][len("[TESTBOT] RELATORIO "):])
                    break
                page.wait_for_timeout(5000)
                if int(time.time() - t0) // 60 > shot:
                    shot += 1
                    page.screenshot(path=str(OUT / ("bot_%02d.png" % shot)))
        browser.close()
    srv.shutdown()
    (OUT / "console.log").write_text("\n".join(log), encoding="utf-8")
    ok = started and not errors
    lines = ["## Versão web (navegador)", "", "- motor iniciou: %s" % ("sim" if started else "**não**")]
    for e in errors[:20]:
        lines.append("- erro: `%s`" % e.replace("`", "'")[:300])
    if bot:
        if report is None:
            ok = False
            lines.append("- agente de teste: **não terminou**")
        else:
            fails = report.get("falhas") or report.get("failures") or []
            ok &= not fails
            lines.append("- agente de teste no navegador: %s" % ("passou" if not fails else "**%d falha(s)**" % len(fails)))
            for f in fails[:20]:
                lines.append("  - %s" % f)
    text = "\n".join(lines)
    print(text)
    import os
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as f:
            f.write(text + "\n")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
