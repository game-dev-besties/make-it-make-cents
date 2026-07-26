from __future__ import annotations

import json
import os
from pathlib import Path
import tempfile
import unittest

from tools.audit_dialogue import (
    audit_episode,
    format_delivery_part_labels,
    format_delivery_parts,
)

PROJECT_ROOT = Path(__file__).resolve().parents[2]


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
        for question in report["questions"]:
            pity_branches = {
                tuple(case["branches"])
                for case in question["cases"]
                if case["delivery"] == "pity"
            }
            silence_branches = {
                tuple(case["branches"])
                for case in question["cases"]
                if case["delivery"] == "silence"
            }
            self.assertEqual(
                pity_branches,
                silence_branches,
                f"{question['line_id']} should treat grunting as silence.",
            )

        weakness = next(
            question
            for question in report["questions"]
            if [phrase["id"] for phrase in question["phrases"]]
            == ["have", "no", "experience", "but", "fast"]
        )

        def weakness_case(*kept_ids: str) -> dict:
            return next(
                case
                for case in weakness["cases"]
                if case["delivery"] == "normal"
                and case["kept"] == list(kept_ids)
            )

        no_experience = weakness_case("have", "no", "experience")
        self.assertEqual(no_experience["branches"], [3])
        self.assertEqual(
            no_experience["authored_actions"],
            ["dad.success -= 1"],
        )

        for kept_ids in (
            ("no", "experience", "fast"),
            ("have", "no", "experience", "fast"),
            ("have", "no", "experience", "but", "fast"),
        ):
            fast_learner = weakness_case(*kept_ids)
            self.assertEqual(fast_learner["branches"], [2])
            self.assertEqual(
                fast_learner["authored_actions"],
                ["dad.success += 2"],
            )
        self.assertEqual(
            weakness["branches"][2]["response"],
            (
                "Ah, I see! It’s always useful to have someone quick on "
                "their toes around here."
            ),
        )

        experience = weakness_case("have", "experience")
        self.assertEqual(experience["branches"], [5])
        self.assertCountEqual(
            experience["authored_actions"],
            ["dad.success -= 1", "dad.silly += 1"],
        )

        for kept_ids in (("fast",), ("have", "experience", "fast")):
            fast = weakness_case(*kept_ids)
            self.assertEqual(fast["branches"], [4])
            self.assertEqual(
                fast["authored_actions"],
                ["dad.success -= 2"],
            )

        for kept_ids in (
            ("have", "no", "but"),
            ("have", "but"),
            ("no", "but"),
        ):
            butts = weakness_case(*kept_ids)
            self.assertEqual(butts["branches"], [6])
            self.assertCountEqual(
                butts["authored_actions"],
                [
                    "dad.success -= 2",
                    "dad.silly += 2",
                    'maybe SET dad_offended_interviewer = "butts"',
                ],
            )

        no_weakness = weakness_case("no")
        self.assertEqual(no_weakness["branches"], [7])
        self.assertFalse(no_weakness["authored_actions"])

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

    def test_grandma_opening_question_matches_authored_outcomes(self) -> None:
        report = audit_episode("grandma", expected_phrase_lines=5)
        opening = next(
            question
            for question in report["questions"]
            if [phrase["id"] for phrase in question["phrases"]]
            == [
                "why_dont_you",
                "wild_guess",
                "lady",
                "im",
                "at_a",
                "doctors_office",
            ]
        )

        def opening_case(*kept_ids: str) -> dict:
            return next(
                case
                for case in opening["cases"]
                if case["delivery"] == "normal"
                and case["kept"] == list(kept_ids)
            )

        all_answer = opening_case(
            "why_dont_you",
            "wild_guess",
            "lady",
            "im",
            "at_a",
            "doctors_office",
        )
        self.assertEqual(all_answer["branches"], [2])
        self.assertEqual(
            all_answer["authored_actions"],
            ["grandma.success -= 2"],
        )

        for kept_ids in (
            ("wild_guess",),
            ("why_dont_you", "wild_guess"),
            ("wild_guess", "lady"),
        ):
            wild_guess = opening_case(*kept_ids)
            self.assertEqual(wild_guess["branches"], [3])
            self.assertEqual(
                wild_guess["authored_actions"],
                ["grandma.success += 2"],
            )

        lady = opening_case("lady")
        self.assertEqual(lady["branches"], [4])
        self.assertFalse(lady["authored_actions"])

        for kept_ids in (
            ("doctors_office",),
            ("at_a", "doctors_office"),
            ("im", "at_a", "doctors_office"),
        ):
            doctors_office = opening_case(*kept_ids)
            self.assertEqual(doctors_office["branches"], [5])
            self.assertEqual(
                doctors_office["authored_actions"],
                ["grandma.success -= 1"],
            )

        self.assertEqual(
            [branch["response"] for branch in opening["branches"][2:6]],
            [
                (
                    "Ha, I-I guess you’re right…wow, wasn’t expecting such "
                    "a…strong voice of yours."
                ),
                (
                    "Oh. Well, I suppose you’re here to talk about the "
                    "medication we called about."
                ),
                (
                    "A lady…brought you here? That’s very nice of her. Tell "
                    "her I said thank you."
                ),
                (
                    "Yes…that’s where we are right now. Nevermind, it’s not "
                    "important. That was just for pleasantries."
                ),
            ],
        )

    def test_budget_findings_cover_static_floor_and_preserved_remainder(
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
                            "son: [SECOND RESPONSE]{id=second} "
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
            5,
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
            1,
            {
                state["budget"]
                for state in unreachable_full["final_states"]
            },
            "An unaffordable positive remainder should remain available.",
        )
        self.assertIn(
            "BUDGET_NEVER_DEPLETES",
            {
                finding["code"]
                for finding in never_forced["findings"]
            },
        )

    @unittest.skipIf(
        os.environ.get("CI", "").lower() == "true",
        "The exhaustive Chapter 4 path audit is a local/manual regression.",
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
            if (
                state["flags"]["clem_failure_count"] == 3
                or state["flags"]["clem_overshare_failure_count"] == 3
            )
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
            set(),
            "Carried sponsor credit should keep every post-jingle response "
            "structurally reachable.",
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
                [3],
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
        for case in confession["cases"]:
            if case["delivery"] == "pity":
                expected_branch = [0]
            elif case["delivery"] in {"silence", "sponsor"}:
                expected_branch = [1]
            elif case["delivery"] == "normal":
                expected_branch = [2]
            else:
                continue
            self.assertEqual(
                case["branches"],
                expected_branch,
                (
                    f"The confession follow-up should preserve its authored "
                    f"{case['delivery']} response for {case['kept']}."
                ),
            )

    def test_crush_first_jingle_is_confined_to_the_opening_up_rail(self) -> None:
        crush_dir = PROJECT_ROOT / "content" / "episodes" / "crush"
        jump_sources = {
            source.name
            for source in crush_dir.glob("*.md")
            if "-> first_jingle" in source.read_text(encoding="utf-8")
        }
        self.assertEqual(jump_sources, {"02_opening_up.md"})

        arrival = (crush_dir / "01_arrival.md").read_text(encoding="utf-8")
        self.assertNotIn("son.success += 1", arrival)
        self.assertIn('if flag("clem_failure_count") >= 3:', arrival)
        self.assertIn(
            "SET clem_failure_count = 0\n"
            "SET clem_overshare_failure_count = 0\n",
            arrival,
        )
        self.assertNotIn("SET clem_failure_count = 0\ncrush", arrival)

        opening_up = (crush_dir / "02_opening_up.md").read_text(
            encoding="utf-8"
        )
        self.assertNotIn('if flag("percy_opened_up"):', opening_up)
        self.assertIn('if budget() == 0 and flag("percy_opened_up"):', opening_up)
        self.assertNotIn('flag("clem_failure_count")', opening_up)
        self.assertIn('flag("clem_overshare_failure_count")', opening_up)
        self.assertIn(
            'if delivery("sponsor") and not could_afford_speech():\n'
            "  -> first_jingle\n"
            'elif delivery("sponsor"):\n',
            opening_up,
        )
        self.assertEqual(
            opening_up.count(
                'if delivery("sponsor") and '
                '(flag("percy_opened_up") or not could_afford_speech()):\n'
                "  -> first_jingle"
            ),
            6,
        )
        self.assertNotIn("@budget 0", opening_up)

        post_jingle = (crush_dir / "04_post_jingle.md").read_text(
            encoding="utf-8"
        )
        jingle = (crush_dir / "03_jingle.md").read_text(encoding="utf-8")
        self.assertNotIn("@budget", jingle)
        self.assertNotIn("@budget", post_jingle)
        self.assertIn(
            'if delivery("pity"):\n'
            '  crush (nervous): ...yes? That’s a yeah, right?\n'
            '  crush (happy): …Okay. Okay, good. I’m glad.\n'
            '  SET got_the_girl = "yes"\n'
            "  -> end\n"
            'elif delivery("silence") or delivery("sponsor"):',
            post_jingle,
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
