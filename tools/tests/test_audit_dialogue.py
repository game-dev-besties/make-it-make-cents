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
            expected_phrase_lines=22,
            max_loop_visits=1,
            vary_flags=("dad_offended_interviewer",),
        )
        self.assertEqual(report["summary"]["phrase_lines"], 22)
        self.assertEqual(report["summary"]["reachable_phrase_lines"], 22)
        self.assertEqual(
            {
                state["flags"]["got_the_girl"]
                for state in report["final_states"]
            },
            {"baited", "no", "yes"},
        )
        for state in report["final_states"]:
            outcome = state["flags"]["got_the_girl"]
            heard_jingle = state["flags"]["girl_heard_jingle"]
            if outcome in {"baited", "yes"}:
                self.assertTrue(
                    heard_jingle,
                    "Clem cannot accept or reject Percy romantically before "
                    "he has exposed the jingle.",
                )
            elif outcome == "no":
                self.assertFalse(
                    heard_jingle,
                    "The pre-jingle exits should not be reachable after the "
                    "scene has entered its romantic second half.",
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
        forced_jingle = next(
            question
            for question in report["questions"]
            if [
                phrase["id"]
                for phrase in question["phrases"]
            ] == ["forced_jingle"]
        )
        self.assertEqual(
            forced_jingle["input_budget"],
            {"min": 0, "max": 0},
        )
        self.assertEqual(
            forced_jingle["available_deliveries"],
            ["sponsor"],
        )
        required_jingle = next(
            question
            for question in report["questions"]
            if [
                phrase["id"]
                for phrase in question["phrases"]
            ] == ["required_jingle"]
        )
        self.assertEqual(
            required_jingle["input_budget"],
            {"min": 0, "max": 0},
        )
        self.assertEqual(
            required_jingle["available_deliveries"],
            ["pity", "silence", "sponsor"],
        )
        phone_call = next(
            question
            for question in report["questions"]
            if [phrase["id"] for phrase in question["phrases"]]
            == [
                "it_was",
                "my_grandma",
                "she_wanted",
                "to_know",
                "if_i_had",
                "food",
            ]
        )
        food_only_answer = next(
            case
            for case in phone_call["cases"]
            if (
                case["delivery"] == "normal"
                and case["kept"] == ["it_was", "food"]
            )
        )
        self.assertEqual(
            food_only_answer["branches"],
            [2],
            '"It was food" must not reveal the grandma information Percy cut.',
        )
        for caring_answer in (
            ["my_grandma"],
            ["she_wanted", "to_know", "if_i_had", "food"],
        ):
            selection = next(
                case
                for case in phone_call["cases"]
                if (
                    case["delivery"] == "normal"
                    and case["kept"] == caring_answer
                )
            )
            self.assertEqual(
                selection["branches"],
                [1],
                f"{caring_answer} should support Clem’s authored reaction.",
            )
        dad_disclosure = next(
            question
            for question in report["questions"]
            if question["phrases"][0]["id"] == "my_dad"
        )
        coherent_dad_disclosure = next(
            case
            for case in dad_disclosure["cases"]
            if (
                case["delivery"] == "normal"
                and case["kept"] == ["my_dad", "uprooted"]
            )
        )
        self.assertEqual(
            coherent_dad_disclosure["branches"],
            [2],
            '"My dad uprooted us" should count as opening up.',
        )
        orphaned_dad_disclosure = next(
            case
            for case in dad_disclosure["cases"]
            if (
                case["delivery"] == "normal"
                and case["kept"] == ["my_dad", "sold_everything"]
            )
        )
        self.assertEqual(
            orphaned_dad_disclosure["branches"],
            [3],
            '"My dad and sold everything we had" should get Clem’s “…What?” response.',
        )
        grandma_disclosure = next(
            question
            for question in report["questions"]
            if question["phrases"][0]["id"] == "grandma_sick"
        )
        for meaningful_id in ("ohio_couldnt_help", "medical_experts"):
            selection = next(
                case
                for case in grandma_disclosure["cases"]
                if (
                    case["delivery"] == "normal"
                    and case["kept"] == [meaningful_id]
                )
            )
            self.assertEqual(
                selection["branches"],
                [2],
                f"{meaningful_id} should count as opening up.",
            )
        butts_tease = next(
            question
            for question in report["questions"]
            if [phrase["id"] for phrase in question["phrases"]]
            == ["do_i", "hnf"]
        )
        butts_tease_sponsor = next(
            case
            for case in butts_tease["cases"]
            if case["delivery"] == "sponsor"
        )
        self.assertEqual(
            butts_tease_sponsor["branches"],
            [1],
            "A repeated jingle should get the authored SHUT UP reaction, "
            "not be mistaken for silence.",
        )
        butts_followup = next(
            question
            for question in report["questions"]
            if [phrase["id"] for phrase in question["phrases"]]
            == ["said_nothing"]
        )
        butts_followup_sponsor = next(
            case
            for case in butts_followup["cases"]
            if case["delivery"] == "sponsor"
        )
        self.assertEqual(
            butts_followup_sponsor["branches"],
            [1],
            "The follow-up jingle should not trigger Clem’s response to "
            "Percy saying nothing.",
        )
        confession = next(
            question
            for question in report["questions"]
            if [phrase["id"] for phrase in question["phrases"]]
            == [
                "yes",
                "three_words",
                "for",
                "as_long",
                "let_me",
                "please",
            ]
        )
        for orphan_id in ("for", "as_long"):
            selection = next(
                case
                for case in confession["cases"]
                if (
                    case["delivery"] == "normal"
                    and case["kept"] == [orphan_id]
                )
            )
            self.assertEqual(
                selection["branches"],
                [3],
                f"{orphan_id} alone should make Clem ask for an answer again.",
            )
        for affirmative_id in ("yes", "let_me"):
            selection = next(
                case
                for case in confession["cases"]
                if (
                    case["delivery"] == "normal"
                    and case["kept"] == [affirmative_id]
                )
            )
            self.assertEqual(
                selection["branches"],
                [],
                f"{affirmative_id} should be enough to continue the confession.",
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
