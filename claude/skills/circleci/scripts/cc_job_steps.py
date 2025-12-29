#!/usr/bin/env python3
"""List CircleCI job steps and action statuses (API v1.1)."""

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
        print("Usage: cc_job_steps.py <gh/org/repo> <job-number>")
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
    for step in data.get("steps", []):
        name = step.get("name")
        for action in step.get("actions", []):
            status = action.get("status")
            action_name = action.get("name")
            output_url = action.get("output_url")
            message = action.get("message")
            print(f"step {name} | action {action_name} | status {status}")
            if message:
                print(f"message {message}")
            if output_url:
                print(f"output_url {output_url}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
