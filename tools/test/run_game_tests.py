"""Roda todos os testes do Punho do Tempo, inclusive o agente que joga no Godot 4.

    python tools/test/run_game_tests.py                      # acha o Godot sozinho
    python tools/test/run_game_tests.py --godot /caminho/godot
    python tools/test/run_game_tests.py --quick              # 3 partidas curtas em vez de 14
    python tools/test/run_game_tests.py --sem-godot          # só as verificações em Python
    python tools/test/run_game_tests.py --only=5 --trace=5   # só a partida 5, com a linha do tempo no log

Etapas:
  1. verificações em Python (sem Godot): hitboxes/hurtboxes dos 79 rigs, resolvedor de animações,
     desvio de caixas da IA e indentação de todos os scripts;
  2. importação do projeto no Godot (pega erros de sintaxe de todos os scripts);
  3. o agente de teste joga (scripts/test_bot.gd): varredura dos 79 rigs e 14 partidas;
  4. resumo (tools/test/check_log.py). Capturas de tela, relatorio.json e godot.log ficam em test_output/.
Sai com código 0 se tudo passou.
"""
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "test_output"


def find_godot(arg):
    if arg:
        return arg
    if os.environ.get("GODOT"):
        return os.environ["GODOT"]
    for name in ("godot4", "godot", "Godot", "godot-4", "Godot_v4.3-stable_linux.x86_64", "Godot_v4.3-stable_win64.exe"):
        p = shutil.which(name)
        if p:
            return p
    for p in ("/Applications/Godot.app/Contents/MacOS/Godot", str(ROOT / "godot")):
        if os.path.exists(p):
            return p
    return None


def run(cmd, log=None, timeout=None):
    print("$", " ".join(str(c) for c in cmd), flush=True)
    try:
        r = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=timeout)
        out = r.stdout + r.stderr
        code = r.returncode
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b"").decode(errors="replace") + (e.stderr or b"").decode(errors="replace") if isinstance(e.stdout, bytes) else (e.stdout or "") + (e.stderr or "")
        out += "\nERROR: tempo esgotado (%s s): o jogo travou?\n" % timeout
        code = 124
    if log:
        with open(log, "a", encoding="utf-8") as f:
            f.write(out)
    return code, out


def python_checks():
    ok = True
    for cmd in (["tools/rig/hitboxes.py", "--check"], ["tools/rig/extra_anims.py", "--check"], ["tools/ai/desvio_caixas.py"]):
        code, out = run([sys.executable] + cmd)
        print(out.strip().splitlines()[-1] if out.strip() else "", flush=True)
        ok &= code == 0
    scripts = sorted(str(p) for p in (ROOT / "scripts").glob("*.gd"))
    code, out = run([sys.executable, "tools/test/indent_check.py"] + scripts)
    print(out.strip(), flush=True)
    ok &= code == 0 and out.strip().endswith("suspeitas: 0")
    return ok


def main():
    quick = "--quick" in sys.argv
    gi = sys.argv.index("--godot") + 1 if "--godot" in sys.argv else 0
    print("== 1. verificações em Python ==", flush=True)
    ok = python_checks()
    if "--sem-godot" in sys.argv:
        sys.exit(0 if ok else 1)
    godot = find_godot(sys.argv[gi] if gi else None)
    if not godot:
        print("Godot 4 não encontrado: use --godot /caminho, a variável GODOT ou ponha 'godot' no PATH.")
        sys.exit(2)
    OUT.mkdir(exist_ok=True)
    (OUT / ".gdignore").touch()
    log = OUT / "godot.log"
    log.write_text("", encoding="utf-8")
    print("== 2. importação do projeto ==", flush=True)
    run([godot, "--headless", "--path", str(ROOT), "--import"], log, timeout=900)
    print("== 3. o agente joga ==", flush=True)
    game = [godot, "--path", str(ROOT), "--fixed-fps", "60", "--audio-driver", "Dummy", "--resolution", "960x540",
            "--", "--test-bot", "--out=res://test_output"] + (["--quick"] if quick else []) + \
        [a for a in sys.argv[1:] if a.startswith(("--only=", "--trace="))]
    if platform.system() == "Linux" and not os.environ.get("DISPLAY") and not os.environ.get("WAYLAND_DISPLAY"):
        if shutil.which("xvfb-run"):
            game = ["xvfb-run", "-a", "-s", "-screen 0 1280x720x24"] + game[:1] + ["--rendering-driver", "opengl3"] + game[1:]
        else:
            game = game[:1] + ["--headless"] + game[1:]
            print("(sem vídeo nem xvfb-run: rodando com --headless; sem capturas de tela e sem conferir passos)")
    code, _out = run(game, log, timeout=600 if quick else 2400)
    print("== 4. resumo ==", flush=True)
    rc = subprocess.run([sys.executable, "tools/test/check_log.py", str(log), "--need-report"], cwd=ROOT).returncode
    print("\nCapturas, relatorio.json e godot.log em:", OUT)
    sys.exit(0 if ok and rc == 0 and code == 0 else 1)


if __name__ == "__main__":
    main()
