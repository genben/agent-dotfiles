#!/usr/bin/env python3
"""Detect whether this process belongs to a live cmux terminal surface."""

from __future__ import annotations

import os
import subprocess
import sys


UNKNOWN = 2


def cmux_process_ids(inventory: str) -> set[int]:
    process_ids: set[int] = set()
    for line in inventory.splitlines():
        fields = line.split("\t")
        if len(fields) < 5 or fields[3] != "process":
            continue
        try:
            process_ids.add(int(fields[4]))
        except ValueError:
            continue
    return process_ids


def main() -> int:
    try:
        result = subprocess.run(
            ("cmux", "top", "--all", "--processes", "--flat", "--format", "tsv"),
            check=False,
            capture_output=True,
            text=True,
            timeout=10,
        )
    except FileNotFoundError:
        print("cmux detection unavailable: cmux CLI not found", file=sys.stderr)
        return UNKNOWN
    except subprocess.TimeoutExpired:
        print("cmux detection unavailable: process inventory timed out", file=sys.stderr)
        return UNKNOWN

    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip() or f"cmux top exited {result.returncode}"
        print(f"cmux detection unavailable: {detail}", file=sys.stderr)
        return UNKNOWN

    candidates = {os.getpid(), os.getppid()}
    if candidates & cmux_process_ids(result.stdout):
        print("inside cmux")
        return 0

    print("not inside cmux")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
