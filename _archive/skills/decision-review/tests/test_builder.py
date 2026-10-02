"""Portable bundles preserve authored content and reject unsafe asset references."""

import copy
import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SKILL = Path(__file__).resolve().parent.parent
BUILDER = SKILL / "scripts" / "build_review.py"
EXAMPLE = json.loads((SKILL / "references" / "example.json").read_text())


class BundleTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "review.json"
        self.output = self.root / "result"

    def build(self, data: dict) -> subprocess.CompletedProcess[str]:
        self.source.write_text(json.dumps(data))
        return subprocess.run(
            [sys.executable, str(BUILDER), str(self.source), "--output", str(self.output)],
            text=True,
            capture_output=True,
            check=False,
        )

    def test_offline_bundle_keeps_media_separate_and_text_inert(self) -> None:
        """A review carries linked images without executing authored HTML."""
        data = copy.deepcopy(EXAMPLE)
        data["title"] = "</script><script>window.unwanted=true</script>"
        data["intro"] = "Literal @@TITLE@@ must not be replaced."
        (self.root / "assets").mkdir()
        image = b"separate image payload"
        (self.root / "assets" / "capture.png").write_bytes(image)
        data["items"][0]["media"] = [
            {"kind": "screenshot", "src": "assets/capture.png", "alt": "Capture", "caption": "Test capture"}
        ]
        result = self.build(data)
        self.assertEqual(result.returncode, 0, result.stderr)
        page = (self.output / "review.html").read_text()
        embedded = json.loads(
            re.search(r'<script id="review-data" type="application/json">(.*?)</script>', page, re.S)[1]
        )
        self.assertEqual(embedded["title"], data["title"])
        self.assertEqual(embedded["intro"], data["intro"])
        self.assertNotIn(data["title"], page)
        self.assertEqual((self.output / "assets" / "capture.png").read_bytes(), image)
        self.assertNotIn(image.decode(), page)
        self.assertEqual(json.loads((self.output / "review.json").read_text()), data)

    def test_changed_proposal_has_a_different_feedback_identity(self) -> None:
        """A choice cannot silently approve a proposal whose meaning changed."""
        data = copy.deepcopy(EXAMPLE)
        first = self.build(data)
        self.assertEqual(first.returncode, 0, first.stderr)
        first_page = (self.output / "review.html").read_text()
        original_hash = re.search(r'"contentHash": "([a-f0-9]+)"', first_page)[1]
        data["items"][0]["options"][0]["proposal"]["failure"] = "The complete export is rejected."
        second = self.build(data)
        self.assertEqual(second.returncode, 0, second.stderr)
        changed_hash = re.search(r'"contentHash": "([a-f0-9]+)"', (self.output / "review.html").read_text())[1]
        self.assertNotEqual(original_hash, changed_hash)

    def test_invalid_review_does_not_write_an_artifact(self) -> None:
        """Broken relationships, executable URLs, and escaped assets fail before output."""
        for kind in ("related", "url", "asset", "duplicate"):
            with self.subTest(kind=kind):
                data = copy.deepcopy(EXAMPLE)
                if kind == "related":
                    data["items"][0]["related"] = ["missing"]
                elif kind == "url":
                    data["items"][0]["evidence"] = [{"note": "Bad link", "url": "javascript:alert(1)"}]
                elif kind == "asset":
                    data["items"][0]["media"] = [
                        {"kind": "screenshot", "src": "assets/../../secret.png", "alt": "Invalid", "caption": "Invalid"}
                    ]
                else:
                    data["items"][1]["id"] = data["items"][0]["id"]
                result = self.build(data)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Build failed:", result.stderr)
                self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
