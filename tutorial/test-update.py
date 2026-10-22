"""Update lifecycle test with real servers; package installation is stubbed."""

import json
import os
import shutil
import subprocess
import tempfile
import urllib.request
from pathlib import Path

repo = Path(__file__).resolve().parent.parent
with tempfile.TemporaryDirectory(prefix="tutorial-update-") as temp:
    root = Path(temp)
    tutorial = root / "tutorial"
    tutorial.mkdir()
    shutil.copytree(repo / "killercoda/demo1-steps", root / "killercoda/demo1-steps")
    shutil.copytree(repo / "demos/demo1/play", root / "demos/demo1/play")
    shutil.copy(repo / "demos/demo1/version.js", root / "demos/demo1/version.js")
    shutil.copy(repo / "demos/demo1/release.js", root / "demos/demo1/release.js")
    (root / "kit").mkdir()
    shutil.copy(repo / "kit/revision", root / "kit/revision")
    shutil.copy(repo / "flake.nix", root / "flake.nix")
    for name in [
        "server.py",
        "shell-rc.sh",
        "start.sh",
        "open.sh",
        "stop.py",
        "update.sh",
        "install-kit.sh",
        "welcome.md",
        "finish.md",
        "requirements.txt",
        "package.json",
    ]:
        shutil.copy(repo / "tutorial" / name, tutorial / name)
    (tutorial / ".venv").symlink_to(repo / "tutorial/.venv", target_is_directory=True)
    (tutorial / "static/vendor").mkdir(parents=True)
    (tutorial / "static/vendor/xterm.js").touch()
    # Stub only package installation; use the real server and update lifecycle.
    (tutorial / "setup.sh").write_text(
        "#!/bin/bash\nset -e\necho installed >> setup-calls\nsha256sum requirements.txt package.json setup.sh | sha256sum | cut -d ' ' -f1 > .setup-fingerprint\n"
    )
    home = root / "home"
    home.mkdir()
    release = subprocess.run(
        ["node", "-p", "require('" + str(root / "demos/demo1/release.js") + "')"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()
    kit = home / ("singular-demo-" + release + "-x86_64-linux")
    (kit / "bin").mkdir(parents=True)
    (kit / "bin/singular").write_text("#!/bin/sh\n")
    (kit / "bin/singular").chmod(0o755)
    (kit / ".verified").touch()
    (home / "keep-me").write_text("existing learner file")
    env = {**os.environ, "HOME": str(home), "CODESPACE_NAME": "upgrade-test"}

    def run(name):
        return subprocess.run(
            ["bash", str(tutorial / name)],
            env=env,
            cwd=root,
            capture_output=True,
            text=True,
            timeout=20,
            check=True,
        )

    def data():
        return json.load(urllib.request.urlopen("http://127.0.0.1:8765/api/lessons"))

    try:
        first = run("update.sh")
        token = data()["token"]
        pid = int((tutorial / "server.pid").read_text())
        second = run("update.sh")
        assert data()["token"] != token
        assert int((tutorial / "server.pid").read_text()) != pid
        assert "https://upgrade-test-8765.app.github.dev" in second.stdout
        assert (tutorial / "setup-calls").read_text().splitlines() == ["installed"]
        assert (home / "keep-me").read_text() == "existing learner file"
        assert len(data()["lessons"]) == 25
        print(
            "PASS: first setup, live server replacement, dependency reuse, exact URL and file preservation"
        )
    finally:
        subprocess.run(
            [str(tutorial / ".venv/bin/python"), str(tutorial / "stop.py")], cwd=root, check=True
        )
    (tutorial / "server.pid").write_text(str(os.getpid()))
    refused = subprocess.run(
        [str(tutorial / ".venv/bin/python"), str(tutorial / "stop.py")],
        cwd=root,
        capture_output=True,
        text=True,
    )
    assert refused.returncode != 0 and "another process" in refused.stderr
    print("PASS: stale PID cannot stop an unrelated process")
