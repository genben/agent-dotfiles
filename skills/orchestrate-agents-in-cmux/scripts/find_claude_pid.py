#!/usr/bin/env python3
"""Resolve a unique live Claude Code session name to its process ID."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import stat
from typing import Any, NoReturn


def fail(message: str) -> NoReturn:
    raise SystemExit(f"find-claude-pid: {message}")


def read_object(path: Path) -> dict[str, Any] | None:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        return None
    return value if isinstance(value, dict) else None


def process_is_live(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def socket_is_live(path: Path) -> bool:
    try:
        return stat.S_ISSOCK(os.lstat(path).st_mode)
    except OSError:
        return False


def find_pids(session_name: str, config_dir: Path) -> list[int]:
    matches: list[int] = []
    for session_file in (config_dir / "sessions").glob("*.json"):
        session = read_object(session_file)
        if session is None or session.get("name") != session_name:
            continue

        pid = session.get("pid")
        socket_path = session.get("messagingSocketPath")
        if not isinstance(pid, int) or pid <= 0 or session_file.stem != str(pid):
            continue
        if not isinstance(socket_path, str) or not socket_path:
            continue
        if process_is_live(pid) and socket_is_live(Path(os.path.abspath(os.path.expanduser(socket_path)))):
            matches.append(pid)
    return sorted(set(matches))


def parser() -> argparse.ArgumentParser:
    argument_parser = argparse.ArgumentParser(
        prog="find-claude-pid",
        description="Resolve an exact Claude Code session name to one reachable process ID.",
    )
    argument_parser.add_argument("session_name", help="exact Claude session name")
    argument_parser.add_argument(
        "--config-dir",
        type=Path,
        default=None,
        help="Claude config directory (default: CLAUDE_CONFIG_DIR or ~/.claude)",
    )
    return argument_parser


def main() -> int:
    args = parser().parse_args()
    config_dir = args.config_dir
    if config_dir is None:
        config_dir = Path(os.environ.get("CLAUDE_CONFIG_DIR", "~/.claude")).expanduser()

    matches = find_pids(args.session_name, config_dir)
    if not matches:
        fail(f"no reachable session named {args.session_name!r}")
    if len(matches) > 1:
        fail(f"more than one reachable session is named {args.session_name!r}: {matches}")
    print(matches[0])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
