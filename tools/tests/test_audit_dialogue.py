from __future__ import annotations

import json
from pathlib import Path
import unittest

from tools.audit_dialogue import (
    audit_episode,
    format_delivery_part_labels,
    format_delivery_parts,
)


class PhraseTextFormatterTests(unittest.TestCase):
    def test_shared_formatting_fixtures(self) -> None:
        fixture_path = (
            Path(__file__).parent / "fixtures" / "phrase_text_formatter.json"
        )
        cases = json.loads(fixture_path.read_text(encoding="utf-8"))
        for case in cases:
            with self.subTest(case=case["name"]):
                self.assertEqual(
                    format_delivery_part_labels(case["parts"]),
                    case["expected_parts"],
                )
                self.assertEqual(
                    format_delivery_parts(case["parts"]),
                    case["expected"],
                )


class ChapterAuditSmokeTests(unittest.TestCase):
    def test_dad_chapter_audit_completes_without_exact_errors(self) -> None:
        report = audit_episode("dad", expected_phrase_lines=5)
        self.assertEqual(report["summary"]["phrase_lines"], 5)
        self.assertGreater(report["summary"]["raw_paths"], 0)
        self.assertGreater(report["summary"]["final_mechanical_states"], 0)
        self.assertFalse(
            [
                finding
                for finding in report["findings"]
                if finding["severity"] == "high"
                and finding["kind"] == "exact"
            ],
            "The Dad audit should have no structural errors.",
        )
