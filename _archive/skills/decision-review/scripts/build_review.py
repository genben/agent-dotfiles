#!/usr/bin/env python3
"""Build an offline decision sheet from review JSON and colocated media."""

import argparse
import hashlib
import html
import json
import re
import shutil
from pathlib import Path, PurePosixPath
from typing import Any
from urllib.parse import urlsplit

SKILL = Path(__file__).resolve().parent.parent
RESERVED = {"custom", "discuss", "defer", "disagree"}


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def text(value: Any, name: str, *, empty: bool = False) -> None:
    require(isinstance(value, str) and (empty or bool(value.strip())), f"{name} must be text")


def identifier(value: Any, name: str) -> None:
    require(
        isinstance(value, str) and bool(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_-]{0,99}", value)),
        f"{name} must be an alphanumeric ID, optionally containing hyphens or underscores",
    )


def strings(value: Any, name: str) -> None:
    require(isinstance(value, list), f"{name} must be a list")
    for entry in value:
        text(entry, name)


def asset_path(value: Any, source_dir: Path) -> Path:
    text(value, "Media path")
    require(bool(re.fullmatch(r"assets/[A-Za-z0-9_./-]+", value)), "Media paths must be under assets/")
    parts = PurePosixPath(value).parts
    require(".." not in parts and "." not in parts, "Media paths cannot traverse directories")
    resolved = (source_dir / value).resolve()
    require(resolved.is_relative_to(source_dir.resolve()), "Media must stay inside the input directory")
    require(resolved.is_file(), f"Missing media file: {value}")
    return resolved


def validate(data: Any, source_dir: Path) -> set[str]:
    require(isinstance(data, dict) and data.get("schemaVersion") == 1, "Expected review schemaVersion 1")
    identifier(data.get("reviewId"), "reviewId")
    for key in ("title", "subtitle", "intro"):
        text(data.get(key), key)
    text(data.setdefault("notice", ""), "notice", empty=True)
    require(isinstance(data.get("items"), list) and bool(data["items"]), "At least one decision is required")
    ids: set[str] = set()
    media_paths: set[str] = set()
    for item in data["items"]:
        require(isinstance(item, dict), "Each decision must be an object")
        identifier(item.get("id"), "Decision id")
        require(item["id"] not in ids, "Decision IDs must be unique")
        ids.add(item["id"])
        for key in ("title", "group", "decision", "problem", "scenario", "recommendation", "question"):
            text(item.get(key), f"{item['id']}.{key}")
        for key in ("definitions", "related", "checks"):
            strings(item.setdefault(key, []), f"{item['id']}.{key}")
        require(bool(item["checks"]), "Each decision needs a verification check")
        require(
            isinstance(item.get("options"), list) and len(item["options"]) >= 2,
            "Each decision needs at least two real choices",
        )
        option_ids: set[str] = set()
        recommended = 0
        for option in item["options"]:
            require(isinstance(option, dict), "Options must be objects")
            identifier(option.get("id"), "Option id")
            require(option["id"] not in option_ids | RESERVED, "Duplicate or reserved option ID")
            option_ids.add(option["id"])
            for key in ("title", "detail", "cost"):
                text(option.get(key), f"Option {key}")
            for key in ("recommended", "requiresComment"):
                require(isinstance(option.setdefault(key, False), bool), f"{key} must be boolean")
            recommended += option["recommended"]
            proposal = option.get("proposal")
            require(isinstance(proposal, dict), "Each real option needs a concrete proposal")
            strings(proposal.get("steps"), "Proposal steps")
            require(bool(proposal["steps"]), "Proposal steps cannot be empty")
            for key in ("failure", "scope"):
                text(proposal.get(key), f"Proposal {key}")
            text(proposal.setdefault("example", ""), "Proposal example", empty=True)
            require(isinstance(proposal.setdefault("data", []), list), "Proposal data must be a list")
            for row in proposal["data"]:
                require(isinstance(row, dict), "Proposal data rows must be objects")
                for key in ("place", "type", "purpose"):
                    text(row.get(key), f"Proposal data {key}")
        require(recommended <= 1, "Mark at most one option recommended")
        require(isinstance(item.get("evidence"), list), "Evidence must be a list")
        for evidence in item["evidence"]:
            require(isinstance(evidence, dict), "Evidence entries must be objects")
            text(evidence.get("note"), "Evidence note")
            require(("url" in evidence) != ("path" in evidence), "Evidence needs either url or path")
            if "url" in evidence:
                text(evidence["url"], "Evidence URL")
                url = urlsplit(evidence["url"])
                require(url.scheme in {"https", "http"} and bool(url.netloc), "Evidence URL must be HTTP(S)")
            else:
                text(evidence["path"], "Evidence source path")
                text(evidence.get("lines", ""), "Evidence lines", empty=True)
        require(isinstance(item.setdefault("media", []), list), "Media must be a list")
        for media in item["media"]:
            require(isinstance(media, dict), "Media entries must be objects")
            require(media.get("kind") in {"screenshot", "diagram", "recording"}, "Unknown media kind")
            for key in ("src", "alt", "caption"):
                text(media.get(key), f"Media {key}")
            path = asset_path(media["src"], source_dir)
            suffixes = {".mp4", ".webm"} if media["kind"] == "recording" else {".png", ".jpg", ".jpeg", ".webp", ".svg"}
            require(path.suffix.lower() in suffixes, "Unsupported media extension")
            media_paths.add(media["src"])
            if "source" in media:
                source = asset_path(media["source"], source_dir)
                require(media["kind"] == "diagram" and source.suffix == ".mmd", "Diagram source must be .mmd")
                media_paths.add(media["source"])
    for item in data["items"]:
        require(set(item["related"]) <= ids, "Related decisions must reference existing IDs")
    return media_paths


def build(source: Path, output: Path) -> Path:
    data = json.loads(source.read_text(encoding="utf-8"))
    paths = validate(data, source.parent)
    canonical = json.dumps(data, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    data["contentHash"] = hashlib.sha256(canonical.encode()).hexdigest()
    assets = SKILL / "assets"
    replacements = {
        "TITLE": html.escape(data["title"]),
        "CSS": (assets / "review.css").read_text(),
        "JS": (assets / "review.js").read_text(),
        "DATA": json.dumps(data, ensure_ascii=False).replace("<", "\\u003c"),
    }
    template = (assets / "review.html").read_text()
    result = re.sub(r"@@(TITLE|CSS|JS|DATA)@@", lambda m: replacements[m[1]], template)
    output.mkdir(parents=True, exist_ok=True)
    for name in paths:
        src, dst = source.parent / name, output / name
        require(dst.resolve().is_relative_to(output.resolve()), "Output media path escapes output directory")
        dst.parent.mkdir(parents=True, exist_ok=True)
        if src.resolve() != dst.resolve():
            shutil.copy2(src, dst)
    target = output / "review.html"
    target.write_text(result, encoding="utf-8")
    if source.resolve() != (output / "review.json").resolve():
        shutil.copy2(source, output / "review.json")
    return target


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        target = build(args.source, args.output)
    except (ValueError, OSError) as exc:
        parser.exit(1, f"Build failed: {exc}\n")
    print(target)


if __name__ == "__main__":
    main()
