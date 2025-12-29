#!/usr/bin/env python3
"""Check CircleCI pipeline/workflow/job status for a branch and show failure output."""

import json
import sys
from pathlib import Path
from urllib.parse import urlencode
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


def api_get(token: str, base: str, path: str, params=None):
    url = f"{base}{path}"
    if params:
        url = f"{url}?{urlencode(params)}"
    req = Request(url)
    req.add_header("Circle-Token", token)
    with urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))


def main() -> int:
    if len(sys.argv) < 3:
        print("Usage: cc_status_branch.py <gh/org/repo> <branch>")
        return 2

    slug = f"gh/{sys.argv[1].strip()}"
    branch = sys.argv[2].strip()
    base = "https://circleci.com/api/v2"
    token = load_token()

    pipelines = api_get(token, base, f"/project/{slug}/pipeline", params={"branch": branch})
    items = pipelines.get("items", [])
    if not items:
        print("No pipelines found for branch")
        return 1

    latest = items[0]
    pipeline_id = latest["id"]
    print(f"pipeline_id {pipeline_id} created_at {latest.get('created_at')}")

    workflows = api_get(token, base, f"/pipeline/{pipeline_id}/workflow")
    workflow_items = workflows.get("items", [])
    for wf in workflow_items:
        print(f"workflow {wf['name']} {wf['status']}")
        jobs = api_get(token, base, f"/workflow/{wf['id']}/job")
        for job in jobs.get("items", []):
            print(f"job {job['name']} {job['status']} {job.get('job_number')}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
