from __future__ import annotations

import json
from pathlib import Path
import tempfile
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

    def test_crush_chapter_audit_covers_conditional_prompt_variants(self) -> None:
        report = audit_episode(
            "crush",
            expected_phrase_lines=21,
            max_loop_visits=1,
            vary_flags=("dad_offended_interviewer",),
        )
        self.assertEqual(report["summary"]["phrase_lines"], 21)
        self.assertEqual(report["summary"]["reachable_phrase_lines"], 21)
        self.assertEqual(
            {
                state["flags"]["got_the_girl"]
                for state in report["final_states"]
            },
            {"baited", "no", "yes"},
        )
        self.assertFalse(
            [
                finding
                for finding in report["findings"]
                if finding["code"] in {
                    "PHRASE_LINE_COUNT",
                    "UNREACHABLE_PHRASE_LINE",
                }
            ]
        )
        self.assertFalse(
            [
                finding
                for finding in report["findings"]
                if finding["severity"] == "high"
                and finding["kind"] == "exact"
            ]
        )

    def test_presentation_directive_and_retry_loop_are_auditable(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            episodes_dir = Path(temporary_directory)
            episode_dir = episodes_dir / "loop"
            episode_dir.mkdir()
            (episode_dir / "episode.tres").write_text(
                "\n".join(
                    [
                        '[gd_resource type="Resource" format=3]',
                        "",
                        "[resource]",
                        "word_budget = 0",
                        'score_owner = &"son"',
                        "",
                    ]
                ),
                encoding="utf-8",
            )
            (episode_dir / "script.md").write_text(
                "\n".join(
                    [
                        '@speaker_name son "Percy"',
                        "",
                        "## retry",
                        "@recovery pity,sponsor",
                        "@sponsor_score 0",
                        "son: [Yes.]{id=yes}",
                        "",
                        'if delivery("sponsor"):',
                        "  -> accepted",
                        "else:",
                        "  -> retry",
                        "",
                        "## accepted",
                        "SET got_the_girl = \"yes\"",
                        "-> end",
                        "",
                    ]
                ),
                encoding="utf-8",
            )

            report = audit_episode(
                "loop",
                expected_phrase_lines=1,
                max_loop_visits=2,
                episodes_dir=episodes_dir,
            )

        self.assertEqual(report["summary"]["phrase_lines"], 1)
        self.assertGreater(report["summary"]["raw_paths"], 0)
        self.assertGreater(report["summary"]["truncated_raw_paths"], 0)
        self.assertEqual(
            report["control_flow"]["jump_targets"],
            ["accepted", "retry"],
        )
        self.assertEqual(
            [
                bounded["target"]
                for bounded in report["control_flow"]["bounded_targets"]
            ],
            ["retry"],
        )
        self.assertEqual(
            {
                state["flags"]["got_the_girl"]
                for state in report["final_states"]
            },
            {"yes"},
        )
