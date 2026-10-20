"""Stop only the tutorial process recorded by start.sh, never an unrelated PID."""

import json
import os
import signal
import time
import urllib.error
import urllib.request
from pathlib import Path

root = Path(__file__).resolve().parent
pidfile = root / "server.pid"


def health():
    try:
        with urllib.request.urlopen("http://127.0.0.1:8765/health", timeout=1) as response:
            return json.load(response)
    except (OSError, ValueError, urllib.error.URLError):
        return {}


if pidfile.exists():
    pid = int(pidfile.read_text().strip())
    if pid <= 1:
        raise SystemExit("Invalid tutorial PID; leaving it untouched.")
    status = health()
    owned = status.get("pid") == pid and status.get("directory") == str(root)
    if not owned:
        # Compatibility with the original prototype, whose health response had no PID.
        process = Path(f"/proc/{pid}")
        try:
            args = (process / "cmdline").read_bytes().split(b"\0")
            owned = (process / "cwd").resolve() == root and any(
                Path(os.fsdecode(arg)).name == "server.py" for arg in args if arg
            )
        except OSError:
            pass
        if not owned:
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                pidfile.unlink(missing_ok=True)
                raise SystemExit(0) from None
    if not owned:
        raise SystemExit(
            "Recorded PID belongs to another process; leaving it untouched. Remove tutorial/server.pid after checking it."
        )
    print("Restarting the tutorial: the live shell and private chain will end; files remain.")
    os.kill(pid, signal.SIGTERM)
    for _ in range(100):
        current = health()
        if not current or (current.get("pid") is not None and current["pid"] != pid):
            break
        time.sleep(0.05)
    else:
        raise SystemExit("Tutorial did not stop. Check its terminal before retrying.")
    pidfile.unlink(missing_ok=True)
