#!/usr/bin/env python3
"""Fetch failing CircleCI job step output (API v1.1 for output_url support)."""

import json
import sys
from pathlib import Path
from urllib.request import Request, urlopen

try:
    import yaml
except Exception as exc:  # pragma: no cover - used as a CLI helper
    print(f"Missing yaml dependency: {exc}")
    sys.exit(1)


def load_token() -> str:
    config_path = Path.home() / ".circleci" / "cli.yml"
    if not config_path.exists():
        raise RuntimeError("CircleCI CLI config not found at ~/.circleci/cli.yml")
    data = yaml.safe_load(config_path.read_text())
    if not isinstance(data, dict) or not data.get("token"):
        raise RuntimeError("CircleCI token missing in ~/.circleci/cli.yml")
    return data["token"]


def main() -> int:
    if len(sys.argv) < 3:
        print("Usage: cc_job_failure.py <gh/org/repo> <job-number>")
        return 2

    slug = sys.argv[1].strip()
    job_number = sys.argv[2].strip()
    token = load_token()

    url = f"https://circleci.com/api/v1.1/project/github/{slug}/{job_number}"
    req = Request(url)
    req.add_header("Circle-Token", token)
    with urlopen(req) as resp:
        data = json.loads(resp.read().decode("utf-8"))

    print(f"status {data.get('status')}")
    output_url = None
    step_name = None
    for step in data.get("steps", []):
        for action in step.get("actions", []):
            if action.get("status") == "failed":
                output_url = action.get("output_url")
                step_name = step.get("name")
                break
        if output_url:
            break

    if not output_url:
        print("No failed step output url found.")
        return 0

    with urlopen(output_url) as resp:
        output_data = json.loads(resp.read().decode("utf-8"))

    print(f"failed-step {step_name}")
    for item in output_data:
        message = item.get("message", "").strip()
        if message:
            print(message)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
