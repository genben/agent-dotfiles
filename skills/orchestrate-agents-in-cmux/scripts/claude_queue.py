#!/usr/bin/env python3
"""Queue a message into a local Claude Code session for cmux orchestration.

Reverse-engineered for Claude Code 2.1.246. This is not a public API.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import socket
import stat
import sys
import time
from typing import Any, NoReturn, Sequence
import uuid


MAX_LINE_BYTES = 1_048_576


def fail(message: str) -> NoReturn:
    raise SystemExit(f"claude-queue: {message}")


def read_object(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        fail(f"{label} does not exist: {path}")
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        fail(f"{label} is not readable JSON: {path}")

    if not isinstance(value, dict):
        fail(f"{label} must contain a JSON object: {path}")
    return value


def required_string(data: dict[str, Any], field: str, label: str) -> str:
    value = data.get(field)
    if not isinstance(value, str) or not value:
        fail(f"{label} has no valid {field}")
    return value


def encode_line(value: dict[str, Any], label: str) -> bytes:
    line = json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8") + b"\n"
    if len(line) > MAX_LINE_BYTES:
        fail(f"{label} exceeds Claude's 1 MiB line limit")
    return line


def message_from_args(words: Sequence[str]) -> str:
    if words:
        return " ".join(words)
    if sys.stdin.isatty():
        fail("message is required as an argument or on standard input")
    message = sys.stdin.read()
    if not message:
        fail("message is empty")
    return message


def queue_message(pid: int, message: str, priority: str, config_dir: Path) -> str:
    if not message:
        fail("message is empty")

    sessions_dir = config_dir / "sessions"
    session_file = sessions_dir / f"{pid}.json"
    session = read_object(session_file, "session record")

    if session.get("pid") != pid:
        fail("PID does not match the session record")

    session_id = required_string(session, "sessionId", "session record")
    proc_start = required_string(session, "procStart", "session record")
    pid_domain = required_string(session, "pidDomain", "session record")
    raw_socket_path = required_string(session, "messagingSocketPath", "session record")

    # Match Node path.resolve(), not realpath(). On macOS, /tmp must stay /tmp.
    socket_path = Path(os.path.abspath(os.path.expanduser(raw_socket_path)))
    try:
        socket_mode = os.lstat(socket_path).st_mode
    except OSError:
        fail(f"Claude inbox socket does not exist: {socket_path}")
    if not stat.S_ISSOCK(socket_mode):
        fail(f"Claude inbox path is not a socket: {socket_path}")

    socket_hash = hashlib.sha256(os.fsencode(socket_path)).hexdigest()
    key_file = sessions_dir / f"{pid}.{socket_hash}.key"
    key = read_object(key_file, "peer key")

    if required_string(key, "procStart", "peer key") != proc_start:
        fail("peer key belongs to another process lifetime")
    if required_string(key, "pidDomain", "peer key") != pid_domain:
        fail("peer key PID domain does not match the session")

    peer_token = required_string(key, "peerToken", "peer key")
    if len(peer_token) != 32 or any(character not in "0123456789abcdefABCDEF" for character in peer_token):
        fail("peer key has no valid peerToken")

    message_id = str(uuid.uuid4())
    payload = encode_line(
        {"type": "auth", "token": peer_token},
        "authentication line",
    ) + encode_line(
        {
            "msgV": 1,
            "msg_id": message_id,
            "type": "user",
            "message": {"role": "user", "content": message},
            "priority": priority,
            "session_id": session_id,
        },
        "message line",
    )

    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
            client.settimeout(5)
            client.connect(str(socket_path))
            client.sendall(payload)
            if sys.platform == "darwin":
                time.sleep(0.15)
            client.shutdown(socket.SHUT_WR)
    except OSError as exc:
        fail(f"could not send to Claude process {pid}: {exc}")

    return message_id


def parser() -> argparse.ArgumentParser:
    argument_parser = argparse.ArgumentParser(
        prog="claude-queue",
        description="Queue a message for a local Claude Code session.",
    )
    argument_parser.add_argument("pid", type=int, help="target Claude process ID")
    argument_parser.add_argument("message", nargs="*", help="message text; reads stdin when omitted")
    argument_parser.add_argument(
        "--priority",
        choices=("now", "next", "later"),
        default="next",
        help="delivery priority (default: next)",
    )
    argument_parser.add_argument(
        "--config-dir",
        type=Path,
        default=None,
        help="Claude config directory (default: CLAUDE_CONFIG_DIR or ~/.claude)",
    )
    return argument_parser


def main() -> int:
    args = parser().parse_args()
    if args.pid <= 0:
        fail("PID must be greater than zero")

    config_dir = args.config_dir
    if config_dir is None:
        config_dir = Path(os.environ.get("CLAUDE_CONFIG_DIR", "~/.claude")).expanduser()

    message_id = queue_message(
        args.pid,
        message_from_args(args.message),
        args.priority,
        config_dir,
    )
    print(message_id)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
