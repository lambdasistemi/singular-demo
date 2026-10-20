"""Integration checks against a real Bash PTY and HTTP/WebSocket server."""
import asyncio
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import aiohttp

ROOT = Path(__file__).resolve().parent
BASE = "http://127.0.0.1:8765"


class TutorialTest(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.home = tempfile.TemporaryDirectory()
        self.process = subprocess.Popen(
            [sys.executable, str(ROOT / "server.py")],
            env={**os.environ, "HOME": self.home.name},
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE,
        )
        self.session = aiohttp.ClientSession()
        for _ in range(100):
            try:
                async with self.session.get(BASE + "/api/lessons") as response:
                    self.data = await response.json()
                break
            except aiohttp.ClientError:
                await asyncio.sleep(.05)
        else:
            self.fail("Server did not become ready")
        self.url = BASE + "/ws?token=" + self.data["token"]

    async def asyncTearDown(self):
        await self.session.close()
        self.process.terminate()
        _, errors = self.process.communicate(timeout=5)
        self.home.cleanup()
        self.assertNotIn(b"Traceback", errors)

    async def connect(self):
        ws = await self.session.ws_connect(self.url, origin=BASE)
        output = await self.until_ready(ws)
        return ws, output

    async def until_ready(self, ws):
        output = ""
        while True:
            message = await asyncio.wait_for(ws.receive_json(), 5)
            self.assertNotEqual(message["type"], "error", message)
            if message["type"] == "output":
                output += message["data"]
            if message["type"] == "state" and message["ready"]:
                return output

    async def test_clicks_state_prompt_reconnect_and_interrupt(self):
        self.assertEqual(len(self.data["lessons"]), 25)
        ws, _ = await self.connect()
        await ws.send_json({"type": "resize", "cols": 100, "rows": 30})
        await ws.send_json({"type": "input", "data": "printf 'Hello from your Singular tutorial!\\n'\r"})
        self.assertIn("Hello from your Singular tutorial!\r\n", await self.until_ready(ws))
        await ws.send_json({"type": "input", "data": "export learner='Cardano explorer'; mkdir -p ~/tutorial-playground; cd ~/tutorial-playground\r"})
        await self.until_ready(ws)
        await ws.send_json({"type": "input", "data": 'printf "Welcome, %s\\n%s\\n" "$learner" "$PWD"\r'})
        output = await self.until_ready(ws)
        self.assertIn("Welcome, Cardano explorer", output)
        self.assertIn(self.home.name + "/tutorial-playground", output)

        # The click must not enqueue another command into a password prompt.
        await ws.send_json({"type": "input", "data": "read -r -s -p 'Type a throwaway word, then Enter: ' practice; printf '\\nReceived %s characters.\\n' \"${#practice}\"; unset practice\r"})
        while True:
            event = await asyncio.wait_for(ws.receive_json(), 5)
            if event["type"] == "output" and "then Enter: " in event["data"]:
                break
        await ws.send_json({"type": "run", "id": "0"})
        while True:
            event = await asyncio.wait_for(ws.receive_json(), 5)
            if event["type"] == "error":
                self.assertIn("busy", event["message"])
                break
        await ws.send_json({"type": "input", "data": "testing-secret\r"})
        output = await self.until_ready(ws)
        self.assertIn("Received 14 characters", output)
        self.assertNotIn("testing-secret", output)

        await ws.close()
        await asyncio.sleep(.05)
        ws, history = await self.connect()
        self.assertIn("Welcome, Cardano explorer", history)
        self.assertNotIn("testing-secret", history)
        await ws.send_json({"type": "input", "data": "printf 'still:%s\\n' \"$learner\"\r"})
        self.assertIn("still:Cardano explorer", await self.until_ready(ws))
        await ws.send_json({"type": "input", "data": "sleep 60\r"})
        await asyncio.sleep(.1)
        await ws.send_json({"type": "input", "data": "\x03"})
        await self.until_ready(ws)
        await ws.close()

    async def test_origin_token_and_second_tab(self):
        async with self.session.get(BASE + "/api/lessons", headers={"Origin": "https://evil.example"}) as r:
            self.assertEqual(r.status, 403)
        async with self.session.get(BASE + "/", headers={"Host": "evil.example"}) as r:
            self.assertEqual(r.status, 403)
        for url, origin in [(self.url, "https://evil.example"), (BASE + "/ws?token=bad", BASE)]:
            with self.assertRaises(aiohttp.WSServerHandshakeError) as error:
                await self.session.ws_connect(url, origin=origin)
            self.assertEqual(error.exception.status, 403)
        ws, _ = await self.connect()
        with self.assertRaises(aiohttp.WSServerHandshakeError) as error:
            await self.session.ws_connect(self.url, origin=BASE)
        self.assertEqual(error.exception.status, 409)
        await ws.close()


if __name__ == "__main__":
    unittest.main(verbosity=2)
