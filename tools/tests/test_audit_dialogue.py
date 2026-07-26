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

    def test_grandma_budget_supports_one_full_answer_plus_participation(
        self,
    ) -> None:
        report = audit_episode("grandma", expected_phrase_lines=5)
        pressure = report["budget_pressure"]

        self.assertEqual(pressure["initial_budget"], 40)
        self.assertEqual(pressure["implemented_full_cost"], 75)
        self.assertEqual(pressure["largest_single_full_cost"], 23)
        self.assertEqual(
            pressure["implemented_cheapest_non_silent_total"],
            5,
        )
        self.assertEqual(
            pressure["one_full_plus_cheapest_non_silent_minimum"],
            27,
        )
        self.assertEqual(
            pressure[
                "headroom_over_one_full_plus_cheapest_non_silent"
            ],
            13,
        )
        self.assertFalse(
            [
                finding
                for finding in report["findings"]
                if finding["code"] in {
                    "BUDGET_BELOW_ONE_FULL_MINIMUM",
                    "FULL_SELECTION_UNREACHABLE",
                }
            ],
            "Every Grandma prompt should remain eligible as the one complete "
            "answer.",
        )

    def test_budget_findings_cover_static_floor_and_effective_zero(
        self,
    ) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            episodes_dir = Path(temporary_directory)
            episode_dir = episodes_dir / "budget"
            episode_dir.mkdir()
            (episode_dir / "episode.tres").write_text(
                "\n".join(
                    [
                        '[gd_resource type="Resource" format=3]',
                        "",
                        "[resource]",
                        "word_budget = 3",
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
                        '@speaker_name dad "Dad"',
                        "",
                        "son: [FIRST]{id=first} [ANSWER]{id=answer}",
                        'if delivery("sponsor"):',
                        "  dad: Sponsor.",
                        "else:",
                        "  dad: First response.",
                        "",
                        (
                            "son: [SECOND]{id=second} "
                            "[LONG ANSWER]{id=long_answer}"
                        ),
                        'if delivery("sponsor"):',
                        "  dad: Sponsor.",
                        "else:",
                        "  dad: Second response.",
                        "-> end",
                        "",
                    ]
                ),
                encoding="utf-8",
            )

            below_floor = audit_episode(
                "budget",
                episodes_dir=episodes_dir,
            )
            unreachable_full = audit_episode(
                "budget",
                initial_budget_override=1,
                episodes_dir=episodes_dir,
            )
            never_forced = audit_episode(
                "budget",
                initial_budget_override=10,
                episodes_dir=episodes_dir,
            )

        self.assertEqual(
            below_floor["budget_pressure"][
                "one_full_plus_cheapest_non_silent_minimum"
            ],
            4,
        )
        self.assertIn(
            "BUDGET_BELOW_ONE_FULL_MINIMUM",
            {
                finding["code"]
                for finding in below_floor["findings"]
            },
        )
        self.assertIn(
            "FULL_SELECTION_UNREACHABLE",
            {
                finding["code"]
                for finding in unreachable_full["findings"]
            },
        )
        self.assertIn(
            "BUDGET_NEVER_DEPLETES",
            {
                finding["code"]
                for finding in never_forced["findings"]
            },
        )

    def test_crush_chapter_audit_covers_conditional_prompt_variants(self) -> None:
        report = audit_episode(
            "crush",
            expected_phrase_lines=20,
            max_loop_visits=1,
            vary_flags=("dad_offended_interviewer",),
        )
        self.assertEqual(report["summary"]["phrase_lines"], 20)
        self.assertEqual(report["summary"]["reachable_phrase_lines"], 20)
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
        failure_exits = [
            state
            for state in report["final_states"]
            if state["flags"]["clem_failure_count"] == 3
        ]
        self.assertTrue(
            failure_exits,
            "Three failed pre-jingle replies should reach Clem’s early exit.",
        )
        self.assertTrue(
            all(
                state["flags"]["got_the_girl"] == "no"
                and not state["flags"]["girl_heard_jingle"]
                for state in failure_exits
            ),
            "The three-strike exit must happen before the romantic jingle reveal.",
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
        self.assertEqual(
            {
                (
                    finding["code"],
                    finding["line_id"],
                    finding["message"],
                )
                for finding in report["findings"]
                if finding["severity"] == "high"
                and finding["kind"] == "exact"
            },
            {
                (
                    "UNREACHABLE_RESPONSE_BRANCH",
                    "crush_L017",
                    'Response branch is never selected: kept("did_at_first")',
                ),
                (
                    "UNREACHABLE_RESPONSE_BRANCH",
                    "crush_L018",
                    'Response branch is never selected: kept("sorry_overshare")',
                ),
            },
            "Only the two intentionally unaffordable post-jingle full-sentence "
            "responses should be structurally unreachable.",
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
            == ["my_grandma", "grandma_food"]
        )
        for caring_answer in (["my_grandma"], ["grandma_food"]):
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
                [2],
                f"{caring_answer} should support Clem’s authored reaction.",
            )
        dad_disclosure = next(
            question
            for question in report["questions"]
            if question["phrases"][0]["id"] == "uprooted"
        )
        for independent_id in ("uprooted", "sold_everything"):
            selection = next(
                case
                for case in dad_disclosure["cases"]
                if case["delivery"] == "normal"
                and case["kept"] == [independent_id]
            )
            self.assertEqual(
                selection["branches"],
                [2],
                f"{independent_id} should count as opening up.",
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
        orphan_examples = (
            ("dont_want", ["dont_want"]),
            ("because", ["because"]),
            ("just_wish", ["just_wish"]),
            ("those_moments", ["those_moments"]),
            ("if", ["if"]),
        )
        for first_phrase_id, kept_ids in orphan_examples:
            question = next(
                item
                for item in report["questions"]
                if item["phrases"][0]["id"] == first_phrase_id
                or any(
                    phrase["id"] == first_phrase_id
                    for phrase in item["phrases"]
                )
            )
            selection = next(
                case
                for case in question["cases"]
                if case["delivery"] == "normal"
                and case["kept"] == kept_ids
            )
            self.assertEqual(
                selection["branches"],
                [3],
                f"{kept_ids} alone should get Clem’s “…What?” response.",
            )
        coherent_fragments = (
            ("dont_want", ["dont_want", "feel_like_this"]),
            ("stay_mad", ["stay_mad", "gave_up", "for_you"]),
            ("just_wish", ["just_wish", "normal"]),
            ("those_moments", ["those_moments", "feel_so", "far_away"]),
            ("feel_happy", ["feel_happy"]),
        )
        for identifying_id, kept_ids in coherent_fragments:
            question = next(
                item
                for item in report["questions"]
                if any(
                    phrase["id"] == identifying_id
                    for phrase in item["phrases"]
                )
            )
            selection = next(
                case
                for case in question["cases"]
                if case["delivery"] == "normal"
                and case["kept"] == kept_ids
            )
            self.assertEqual(
                selection["branches"],
                [2],
                f"{kept_ids} should count as a coherent disclosure.",
            )
        butts_tease = next(
            question
            for question in report["questions"]
            if [phrase["id"] for phrase in question["phrases"]]
            == ["do_i"]
        )
        butts_tease_sponsor = next(
            case
            for case in butts_tease["cases"]
            if case["delivery"] == "sponsor"
        )
        self.assertEqual(
            butts_tease_sponsor["branches"],
            [3],
            "A repeated jingle should get Clem’s authored smile response.",
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
                [1],
                f"{orphan_id} now follows the authored paid-word response.",
            )

    def test_neighbors_chapter_audit_covers_every_ending_combination(self) -> None:
        report = audit_episode(
            "neighbors",
            expected_phrase_lines=0,
            vary_flags=(
                "dad_offended_interviewer",
                "got_the_girl",
                "got_prescription",
            ),
        )
        self.assertEqual(report["summary"]["phrase_lines"], 0)
        self.assertEqual(report["summary"]["raw_paths"], 24)
        self.assertEqual(len(report["final_states"]), 24)
        self.assertFalse(report["findings"])

        for state in report["final_states"]:
            flags = state["flags"]
            happy_family_members = sum(
                (
                    flags["dad_offended_interviewer"] == "none",
                    flags["got_the_girl"] == "yes",
                    flags["got_prescription"],
                )
            )
            self.assertEqual(
                flags["family_stays"],
                happy_family_members >= 2,
                f"Wrong Chapter 6 ending for incoming flags: {flags}",
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
        self.assertEqual(report["budget_pressure"]["initial_budget"], 0)
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
