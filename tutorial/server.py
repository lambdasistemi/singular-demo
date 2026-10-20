"""Single-user tutorial runner. Keep the Codespaces forwarded port PRIVATE."""

import asyncio
import codecs
import fcntl
import json
import os
import pty
import re
import secrets
import shutil
import signal
import struct
import subprocess
import tempfile
import termios
from pathlib import Path

from aiohttp import web

ROOT = Path(__file__).resolve().parent.parent
STATIC = ROOT / "tutorial/static"


def load_lessons():
    # the scenario this tutorial plays: the Killercoda scenario generated in this repository (TUTORIAL_SCENARIO names another)
    directory = ROOT / os.environ.get("TUTORIAL_SCENARIO", "killercoda/demo1-steps")
    index = json.loads((directory / "index.json").read_text())
    pages = [("Start here", ROOT / "tutorial/welcome.md")]
    pages += [(step["title"], directory / step["text"]) for step in index["details"]["steps"]]
    pages.append(("Finish", directory / index["details"]["finish"]["text"]))
    commands, lessons = {}, []
    pattern = re.compile(r"```([^\n]*)\n(.*?)\n```(\{\{exec\}\})?", re.S)
    for title, path in pages:
        source, blocks, end = path.read_text(), [], 0
        if title == "Finish":
            source += (ROOT / "tutorial/finish.md").read_text()
        for match in pattern.finditer(source):
            if match.start() > end:
                blocks.append({"kind": "markdown", "text": source[end : match.start()]})
            command_id = str(len(commands)) if match[3] else None
            if command_id is not None:
                commands[command_id] = match[2]
            blocks.append({"kind": "code", "text": match[2], "id": command_id})
            end = match.end()
        if source[end:]:
            blocks.append({"kind": "markdown", "text": source[end:]})
        lessons.append({"title": title, "blocks": blocks})
    return lessons, commands


class Shell:
    def __init__(self):
        self.ready = False
        self.exited = False
        self.history = ""
        self.clients = set()
        self.decoder = codecs.getincrementaldecoder("utf-8")("replace")

    def start(self):
        self.state_dir = tempfile.TemporaryDirectory(prefix="tutorial-state-")
        self.tmux_socket = "tutorial-" + secrets.token_hex(8)
        self.active_pid = None
        self.rc = str(ROOT / "tutorial/shell-rc.sh")
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.chdir(ROOT)
            os.environ.update(
                TERM="xterm-256color",
                TUTORIAL_ROOT=str(ROOT),
                TUTORIAL_STATE_DIR=self.state_dir.name,
                TUTORIAL_TMUX_SOCKET=self.tmux_socket,
            )
            os.execvp("bash", ["bash", "--rcfile", self.rc, "-i"])
        os.set_blocking(self.fd, False)
        asyncio.get_running_loop().add_reader(self.fd, self.read)
        self.active_pid = self.pid
        self.monitor = asyncio.create_task(self.watch_prompt())

    def emit(self, message):
        for queue in list(self.clients):
            try:
                queue.put_nowait(message)
            except asyncio.QueueFull:
                # Disconnect a slow client instead of retaining unlimited output.
                self.clients.discard(queue)
                while not queue.empty():
                    queue.get_nowait()
                queue.put_nowait({"type": "disconnect"})

    def read(self):
        try:
            data = os.read(self.fd, 16384)
        except BlockingIOError:
            return
        except OSError:
            data = b""
        if not data:
            asyncio.get_running_loop().remove_reader(self.fd)
            self.exited, self.ready = True, False
            self.emit({"type": "state", "ready": False, "exited": True})
            return
        text = self.decoder.decode(data)
        self.history = (self.history + text)[-262144:]
        self.emit({"type": "output", "data": text})

    async def watch_prompt(self):
        while not self.exited:
            active_pid = self.pid
            if shutil.which("tmux"):
                process = await asyncio.create_subprocess_exec(
                    "tmux",
                    "-L",
                    self.tmux_socket,
                    "list-clients",
                    "-F",
                    "#{pane_pid}",
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.DEVNULL,
                )
                output, _ = await process.communicate()
                if output.strip().isdigit():
                    active_pid = int(output.strip())
            self.active_pid = active_pid
            try:
                ready = (Path(self.state_dir.name) / f"{active_pid}.ready").read_text() == "1"
            except FileNotFoundError:
                ready = False
            if ready != self.ready:
                self.ready = ready
                self.emit({"type": "state", "ready": ready, "exited": False})
            await asyncio.sleep(0.1)

    def mark_busy(self):
        self.ready = False
        (Path(self.state_dir.name) / f"{self.active_pid}.ready").write_text("0")
        self.emit({"type": "state", "ready": False})

    async def write(self, text):
        data = text.encode()
        while data and not self.exited:
            try:
                written = os.write(self.fd, data)
                data = data[written:]
            except BlockingIOError:
                await asyncio.sleep(0.01)
        if self.exited:
            raise RuntimeError("Shell exited; restart the tutorial server.")

    def resize(self, cols, rows):
        fcntl.ioctl(self.fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))

    async def stop(self):
        self.monitor.cancel()
        await asyncio.gather(self.monitor, return_exceptions=True)
        if shutil.which("tmux"):
            subprocess.run(
                ["tmux", "-L", self.tmux_socket, "kill-server"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        asyncio.get_running_loop().remove_reader(self.fd)
        try:
            os.kill(self.pid, signal.SIGHUP)
        except ProcessLookupError:
            pass
        os.close(self.fd)
        for _ in range(40):
            try:
                if os.waitpid(self.pid, os.WNOHANG)[0]:
                    break
            except ChildProcessError:
                break
            await asyncio.sleep(0.05)
        self.state_dir.cleanup()


def make_app():
    lessons, commands = load_lessons()
    shell = Shell()
    token = secrets.token_urlsafe(32)
    hosts = {"localhost:8765", "127.0.0.1:8765"}
    if os.getenv("CODESPACE_NAME"):
        domain = os.getenv("GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN", "app.github.dev")
        hosts.add(f"{os.environ['CODESPACE_NAME']}-8765.{domain}")
    origins = {f"{scheme}://{host}" for host in hosts for scheme in ("http", "https")}

    @web.middleware
    async def boundary(request, handler):
        if request.host not in hosts:
            raise web.HTTPForbidden(
                text="Unexpected host. Use the private Codespaces port or localhost."
            )
        if request.headers.get("Origin") and request.headers["Origin"] not in origins:
            raise web.HTTPForbidden(text="Cross-origin access denied.")
        response = await handler(request)
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["Referrer-Policy"] = "no-referrer"
        response.headers["Cache-Control"] = "no-store"
        response.headers["Content-Security-Policy"] = (
            "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; "
            "connect-src 'self'; img-src 'self' data:; frame-ancestors 'none'; object-src 'none'"
        )
        return response

    app = web.Application(middlewares=[boundary])

    async def lifecycle(app):
        shell.start()
        yield
        await shell.stop()

    async def index(request):
        return web.FileResponse(STATIC / "index.html")

    async def lesson_data(request):
        return web.json_response({"lessons": lessons, "token": token})

    async def health(request):
        return web.json_response(
            {
                "service": "singular-tutorial",
                "shell_alive": not shell.exited,
                "pid": os.getpid(),
                "directory": str(ROOT / "tutorial"),
            }
        )

    async def websocket(request):
        if request.headers.get("Origin") not in origins or not secrets.compare_digest(
            request.query.get("token", ""), token
        ):
            raise web.HTTPForbidden(text="Open the tutorial page before connecting.")
        if shell.clients:
            raise web.HTTPConflict(
                text="Terminal already open in another tab. Close that tab first."
            )
        ws = web.WebSocketResponse(max_msg_size=65536, heartbeat=20)
        await ws.prepare(request)
        queue = asyncio.Queue(maxsize=128)
        shell.clients.add(queue)
        await ws.send_json({"type": "output", "data": shell.history})
        await ws.send_json({"type": "state", "ready": shell.ready, "exited": shell.exited})

        async def sender():
            while True:
                message = await queue.get()
                if message["type"] == "disconnect":
                    await ws.close(code=1013, message=b"Output backlog; reconnect")
                    return
                await ws.send_json(message)

        task = asyncio.create_task(sender())
        try:
            async for message in ws:
                if message.type != web.WSMsgType.TEXT:
                    continue
                try:
                    event = json.loads(message.data)
                    if event["type"] == "resize":
                        shell.resize(
                            max(2, min(500, int(event["cols"]))),
                            max(1, min(200, int(event["rows"]))),
                        )
                    elif event["type"] == "input":
                        if "\r" in event["data"] or "\n" in event["data"]:
                            shell.mark_busy()
                        await shell.write(event["data"])
                    elif event["type"] == "run":
                        if not shell.ready:
                            await ws.send_json(
                                {
                                    "type": "error",
                                    "message": "The shell is busy. Finish its prompt or press Ctrl+C.",
                                }
                            )
                            continue
                        command = commands[event["id"]]
                        shell.mark_busy()
                        # Bracketed paste makes multiline code one readline buffer.
                        # Ctrl+U clears any unfinished input before inserting it.
                        await shell.write("\x15\x1b[200~" + command + "\x1b[201~\r")
                        await ws.send_json({"type": "ran", "id": event["id"]})
                except (ValueError, KeyError, TypeError, RuntimeError, OSError) as error:
                    await ws.send_json({"type": "error", "message": str(error)})
        finally:
            shell.clients.discard(queue)
            task.cancel()
            await asyncio.gather(task, return_exceptions=True)
        return ws

    app.cleanup_ctx.append(lifecycle)
    app.router.add_get("/", index)
    app.router.add_get("/health", health)
    app.router.add_get("/api/lessons", lesson_data)
    app.router.add_get("/ws", websocket)
    app.router.add_static("/static/", STATIC)
    return app


if __name__ == "__main__":
    # Loopback is forwarded by Codespaces; never bind a public shell to 0.0.0.0.
    web.run_app(make_app(), host="127.0.0.1", port=8765, access_log=None)
