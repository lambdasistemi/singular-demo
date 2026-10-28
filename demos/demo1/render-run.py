#!/usr/bin/env python3
"""Render the Demo 1 run page from a tutorial-stepper transcript.

Takes the transcript of ``tutorial-stepper play --auto demos/demo1``
(a real run of the tutorial, one entry per command and observation that
ran, in order) and writes the ``run`` documentation page: the tutorial's
steps with, under each command, what it printed in that run.

Usage: render-run.py TRANSCRIPT OUT.md
"""

import re
import sys
import tomllib
from pathlib import Path


def version() -> str:
    """The Singular release pinned in flake.nix (the only place it is written)."""
    flake = Path(__file__).resolve().parent.parent.parent / "flake.nix"
    match = re.search(r'singularRelease = "(v\d+\.\d+\.\d+)"', flake.read_text())
    if not match:
        raise SystemExit("render-run.py: no Singular release found in flake.nix")
    return match.group(1)


def release(ver: str) -> str:
    """The kit release: the Singular release and kit/revision."""
    revision = (Path(__file__).resolve().parent.parent.parent / "kit" / "revision").read_text().strip()
    if not re.fullmatch(r"[1-9][0-9]*", revision):
        raise SystemExit("render-run.py: kit/revision is not a whole number from 1")
    return f"{ver}-{revision}"


def entries(transcript: Path):
    """The transcript's commands and observations, in the order they ran.

    tomllib groups the tables by kind, which loses the run order, so the
    file is cut at each table header and every chunk is parsed on its own.
    """
    chunks: list[tuple[str, dict]] = []
    header: str | None = None
    body: list[str] = []

    def flush() -> None:
        if header is not None:
            doc = tomllib.loads(header + "".join(body))
            kind = header.strip().strip("[]")
            chunks.append((kind, doc[kind][0]))

    for line in transcript.read_text().splitlines(keepends=True):
        if line in ("[[command]]\n", "[[observation]]\n"):
            flush()
            header = line
            body = []
        else:
            body.append(line)
    flush()
    return chunks


def main() -> None:
    if len(sys.argv) != 3:
        print("usage: render-run.py TRANSCRIPT OUT.md", file=sys.stderr)
        sys.exit(2)
    transcript, out_file = Path(sys.argv[1]), Path(sys.argv[2])
    demo = Path(__file__).resolve().parent
    ver = version()
    rel = release(ver)

    titles: dict[str, str] = {}

    def title(page: str) -> str:
        if page not in titles:
            first = (demo / page).read_text().split("\n", 1)[0]
            titles[page] = first.removeprefix("# ").strip()
        return titles[page]

    fences: dict[tuple[str, int], str] = {}

    def fence(page: str, block: int) -> str:
        if (page, block) not in fences:
            line = (demo / page).read_text().splitlines()[block - 1]
            if not line.startswith("```"):
                raise SystemExit(f"render-run.py: {page} line {block} is not a fence: {line}")
            fences[(page, block)] = line
        return fences[(page, block)]

    md = (
        "# Demo 1, a run\n\n"
        "The tutorial's steps as they ran on a private chain, with the result under each command. "
        f"The target release is {ver}, kit {rel}. Commands and results come from the supplied transcript. "
        "Local filesystem paths are shown as <local>; transaction IDs, tokens and addresses are unchanged.\n"
    )
    current = ""
    blocks = with_result = 0
    for kind, entry in entries(transcript):
        page = entry["page"]
        if page != current:
            current = page
            md += f"\n## {title(page)}\n"
        command = entry["command"]
        if isinstance(command, list):
            command = "".join(command)
        text = command[:-1] if command.endswith("\n") else command
        if kind == "observation" and entry.get("position") == "end of path":
            md += "\nRun again at the end of the path:\n"
        md += f"\n{fence(page, entry['block'])}\n{text}\n```\n"
        blocks += 1
        output = entry.get("output", "")
        if isinstance(output, list):
            output = "".join(output)
        clean = "\n".join(
            line.split("\r")[0] if "\r" not in line else [p for p in line.split("\r") if p][-1]
            for line in output.split("\n")
        ).strip("\n")
        clean = re.sub(
            r"/(?:nix/store|code|tmp|home|build|scratch|out)/[^\s\"'<>]+",
            "<local>",
            clean,
        )
        if clean:
            with_result += 1
            md += f"\nResult:\n\n```text\n{clean}\n```\n"
    out_file.parent.mkdir(parents=True, exist_ok=True)
    out_file.write_text(md)
    print(f"render-run.py: {blocks} blocks, {with_result} with a result, written to {out_file}")


if __name__ == "__main__":
    main()
