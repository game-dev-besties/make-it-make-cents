from __future__ import annotations

import tempfile
from pathlib import Path
import unittest

from tools.compile_dialogue import (
    CompileError,
    FlagDefinition,
    compile_source,
    compile_sources,
    discover_sources,
)


STATS = frozenset(
    {
        "dad.success",
        "dad.silly",
    }
)
FLAGS = {
    "dad_offended_interviewer": FlagDefinition(
        name="dad_offended_interviewer",
        default="none",
        values=("none", "soda", "butts"),
        descriptions={},
    ),
    "dad_mentioned_family": FlagDefinition(
        name="dad_mentioned_family",
        default=False,
        values=(False, True),
        descriptions={},
    )
}


class CompilerTests(unittest.TestCase):
    def compile(self, text: str):
        with tempfile.TemporaryDirectory() as temporary_directory:
            path = Path(temporary_directory) / "script.md"
            path.write_text(text, encoding="utf-8")
            return compile_source(path, "dad", STATS)

    def assert_compile_error(self, text: str, expected: str) -> None:
        with self.assertRaises(CompileError) as raised:
            self.compile(text)
        self.assertIn(expected, str(raised.exception))
        self.assertRegex(str(raised.exception), r"script\.md:\d+: error:")

    def compile_with_flags(self, text: str):
        with tempfile.TemporaryDirectory() as temporary_directory:
            path = Path(temporary_directory) / "script.md"
            path.write_text(text, encoding="utf-8")
            return compile_source(path, "dad", STATS, FLAGS)

    def test_compiles_inline_phrases_conditions_stats_and_cues(self) -> None:
        artifact = self.compile(
            """\
## start
@cue dad_enters
dad (nervous): [I have]{id=have} [experience]{id=experience, cost=1}.
if kept("experience") and delivery("normal"):
  dad.success += 2
else:
  dad.silly += 1
-> end
"""
        )

        self.assertIn("presentation_cue dad_enters", artifact.timeline)
        self.assertIn("phrase_cut dad (nervous) dad_L001", artifact.timeline)
        self.assertIn("PhraseMemory.kept(\"experience\")", artifact.timeline)
        self.assertIn("PhraseMemory.delivery_is(\"normal\")", artifact.timeline)
        self.assertIn("set {GameStats.dad_success} += 2", artifact.timeline)
        self.assertIn('"text": "experience."', artifact.phrases)
        self.assertIn('"cost": 1', artifact.phrases)
        self.assertNotIn("min_keep", artifact.phrases)

    def test_compiles_story_flag_sets_checks_and_silent_conditions(self) -> None:
        artifact = self.compile_with_flags(
            """\
SET dad_offended_interviewer = "none"
SET dad_mentioned_family = true
if flag("dad_offended_interviewer") == "none":
  SET dad_offended_interviewer = "soda"
CHECK dad_offended_interviewer != "none" as dad_did_not_get_the_job:
  interviewer: You did not get the job.
CHECK dad_offended_interviewer == "none" as dad_got_the_job:
  interviewer: You got the job!
"""
        )

        self.assertIn(
            'story_flag_set {"name":"dad_offended_interviewer","value":"none"}',
            artifact.timeline,
        )
        self.assertIn(
            'story_flag_set {"name":"dad_mentioned_family","value":true}',
            artifact.timeline,
        )
        self.assertIn(
            'if GameStats.get_story_flag("dad_offended_interviewer") == "none":',
            artifact.timeline,
        )
        self.assertIn(
            'if not GameStats.story_flag_equals("dad_offended_interviewer", "none"):',
            artifact.timeline,
        )
        self.assertIn(
            '"branch":"dad_did_not_get_the_job"',
            artifact.timeline,
        )
        self.assertIn(
            'if GameStats.story_flag_equals("dad_offended_interviewer", "none"):',
            artifact.timeline,
        )

    def test_story_flags_reject_unknown_names_and_values(self) -> None:
        invalid_sources = {
            'SET missing_flag = "none"\n': "unknown flag `missing_flag`",
            'SET dad_offended_interviewer = "angry"\n': (
                'invalid value "angry" for flag `dad_offended_interviewer`'
            ),
            'SET dad_mentioned_family = "true"\n': (
                'invalid value "true" for flag `dad_mentioned_family`'
            ),
            'if flag("missing_flag") == "none":\n  dad: Hello.\n': (
                "unknown flag `missing_flag`"
            ),
            'CHECK dad_offended_interviewer = "none":\n  dad: Hello.\n': (
                "malformed flag check"
            ),
        }
        for source, expected in invalid_sources.items():
            with self.subTest(source=source):
                with self.assertRaises(CompileError) as raised:
                    self.compile_with_flags(source)
                self.assertIn(expected, str(raised.exception))

    def test_cost_defaults_to_word_count(self) -> None:
        artifact = self.compile("dad: [one two three]\n")
        self.assertIn('"cost": 3', artifact.phrases)

    def test_compiles_budget_and_canonical_recovery_policy_events(self) -> None:
        artifact = self.compile(
            """\
@budget 0
@recovery sponsor, pity
dad: [Use]{id=use} [the sponsor.]{id=sponsor}
-> end
"""
        )

        self.assertEqual(
            artifact.timeline,
            """\
# Generated from content/episodes/dad/script.md; edit script.md, not this file.
budget_set 0
recovery_policy pity,sponsor
phrase_cut dad dad_L001
[end_timeline]
""",
        )

    def test_recovery_none_emits_an_explicit_empty_policy(self) -> None:
        artifact = self.compile(
            """\
@recovery none
dad: [Say nothing.]{id=nothing}
"""
        )
        self.assertIn("recovery_policy none\nphrase_cut dad dad_L001", artifact.timeline)

    def test_sponsor_score_is_stored_with_the_following_phrase_line(self) -> None:
        artifact = self.compile(
            """\
@recovery sponsor
@sponsor_score -1
@sponsor_text "SAM'S CUSTOM SODA!"
@pity_text "mrrf"
dad: [Drink the soda.]{id=soda}
"""
        )

        self.assertIn("recovery_policy sponsor", artifact.timeline)
        self.assertNotIn("sponsor_score", artifact.timeline)
        self.assertIn('"sponsor_success_delta": -1', artifact.phrases)
        self.assertIn(
            "\"sponsor_text\": \"SAM'S CUSTOM SODA!\"",
            artifact.phrases,
        )
        self.assertIn('"pity_text": "mrrf"', artifact.phrases)

    def test_sponsor_score_requires_a_bounded_integer_and_phrase_line(self) -> None:
        invalid_directives = {
            "@sponsor_score half\ndad: [Hello.]\n": "whole-number success delta",
            "@sponsor_score -11\ndad: [Hello.]\n": "must be between -10 and 10",
            "@sponsor_score -1\ndad: Hello.\n": (
                "must be immediately followed by a phrase-cut dialogue line"
            ),
            "@sponsor_score -1\n@sponsor_score -2\ndad: [Hello.]\n": (
                "cannot be repeated"
            ),
            "@sponsor_text unquoted\ndad: [Hello.]\n": "needs one quoted string",
            '@pity_text ""\ndad: [Hello.]\n': "needs one nonempty quoted string",
        }
        for source, expected in invalid_directives.items():
            with self.subTest(source=source):
                self.assert_compile_error(source, expected)

    def test_budget_requires_a_nonnegative_integer(self) -> None:
        for source in ("@budget\n", "@budget -1\n", "@budget 1.5\n", "@budget free\n"):
            with self.subTest(source=source):
                self.assert_compile_error(
                    source,
                    "`@budget` needs a nonnegative whole number",
                )

    def test_recovery_policy_rejects_invalid_mode_lists(self) -> None:
        invalid_policies = {
            "@recovery\n": "`@recovery` needs `none`",
            "@recovery pity,\n": "cannot contain an empty mode",
            "@recovery pity,pity\n": "cannot repeat a recovery mode",
            "@recovery none,pity\n": "`none` cannot be combined",
            "@recovery pity,magic\n": "unknown recovery mode `magic`",
        }
        for directive, expected in invalid_policies.items():
            with self.subTest(directive=directive):
                self.assert_compile_error(
                    directive + "dad: [Hello.]\n",
                    expected,
                )

    def test_recovery_policy_must_directly_precede_a_phrase_line(self) -> None:
        self.assert_compile_error(
            """\
@recovery sponsor
dad: This is ordinary dialogue.
dad: [This is deletable.]
""",
            "must be immediately followed by a phrase-cut dialogue line",
        )
        self.assert_compile_error(
            "@recovery none\n",
            "must be immediately followed by a phrase-cut dialogue line",
        )

    def test_inline_dialogic_text_effects_remain_ordinary_dialogue(self) -> None:
        artifact = self.compile(
            "dad (serious): Son, [speed=2]do not say one word.[speed]\n"
        )

        self.assertIn(
            "\\dad (serious): Son, [speed=2]do not say one word.[speed]",
            artifact.timeline,
        )
        self.assertEqual(artifact.phrase_line_count, 0)
        self.assertEqual(artifact.phrases, "{}\n")

    def test_trailing_backslash_joins_physical_source_lines(self) -> None:
        artifact = self.compile(
            "dad: This sentence is easier to edit \\\n"
            "  across two physical lines.\n"
        )

        self.assertIn(
            "\\dad: This sentence is easier to edit across two physical lines.",
            artifact.timeline,
        )
        self.assertNotIn("\\\n", artifact.timeline)
        self.assertEqual(artifact.phrase_line_count, 0)

    def test_text_lines_cannot_be_misparsed_as_dialogic_calls(self) -> None:
        artifact = self.compile(
            "doctor (happy): Grandma, nice to see you again!\n"
            "doorways can also begin narration.\n"
        )

        self.assertIn(
            "\\doctor (happy): Grandma, nice to see you again!",
            artifact.timeline,
        )
        self.assertIn("\\doorways can also begin narration.", artifact.timeline)

    def test_trailing_backslash_can_continue_phrase_cut_dialogue(self) -> None:
        artifact = self.compile(
            "dad: [This is one phrase.]{id=first} \\\n"
            "  [This is another.]{id=second}\n"
        )

        self.assertIn("phrase_cut dad dad_L001", artifact.timeline)
        self.assertIn('"id": "first"', artifact.phrases)
        self.assertIn('"id": "second"', artifact.phrases)

    def test_dangling_line_continuation_is_an_author_error(self) -> None:
        self.assert_compile_error(
            "dad: This line never finishes " + "\\",
            "line continuation has no following physical line",
        )

    def test_dialogue_beginning_with_a_bracket_remains_phrase_cut(self) -> None:
        artifact = self.compile(
            "dad: [I have]{id=have} [experience.]{id=experience}\n"
        )
        self.assertIn("phrase_cut dad dad_L001", artifact.timeline)
        self.assertEqual(artifact.phrase_line_count, 1)

    def test_negative_cost_is_an_author_error(self) -> None:
        self.assert_compile_error(
            "dad: [hello]{cost=-1}\n",
            "phrase cost cannot be negative",
        )

    def test_unbalanced_bracket_is_an_author_error(self) -> None:
        self.assert_compile_error(
            "dad: [hello\n",
            "unmatched `[`",
        )

    def test_unknown_directive_is_an_author_error(self) -> None:
        self.assert_compile_error(
            "@camera shake\n",
            "unknown directive",
        )

    def test_unexpected_indentation_is_an_author_error(self) -> None:
        self.assert_compile_error(
            "dad: Hello\n  dad: Surprise\n",
            "unexpected indentation",
        )

    def test_missing_jump_label_is_an_author_error(self) -> None:
        self.assert_compile_error(
            "dad: Hello\n-> nowhere\n",
            "missing label `nowhere`",
        )

    def test_writer_jump_emits_goto_without_a_return_frame(self) -> None:
        artifact = self.compile(
            """\
## retry
dad: Try again.
-> retry
"""
        )

        self.assertIn(
            "label retry\n\\dad: Try again.\ngoto_label retry\n",
            artifact.timeline,
        )
        self.assertNotIn("jump retry", artifact.timeline)

    def test_ordered_episode_source_manifest_compiles_as_one_flow(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            episodes_dir = Path(temporary_directory)
            episode_dir = episodes_dir / "dad"
            episode_dir.mkdir()
            (episode_dir / "scripts.json").write_text(
                '{"sources": ["20_opening.md", "10_ending.md"]}\n',
                encoding="utf-8",
            )
            (episode_dir / "20_opening.md").write_text(
                "## opening\n"
                "dad: [First.]{id=first}\n"
                "-> ending\n",
                encoding="utf-8",
            )
            (episode_dir / "10_ending.md").write_text(
                "## ending\n"
                "dad: [Second.]{id=second}\n"
                "-> end\n",
                encoding="utf-8",
            )

            episode_sources = discover_sources(["dad"], episodes_dir)[0]
            artifact = compile_sources(
                episode_sources.source_paths,
                episode_sources.episode_id,
                STATS,
                source_label=episode_sources.source_label,
            )

        self.assertLess(
            artifact.timeline.index("label opening"),
            artifact.timeline.index("label ending"),
        )
        self.assertIn("goto_label ending", artifact.timeline)
        self.assertIn("phrase_cut dad dad_L001", artifact.timeline)
        self.assertIn("phrase_cut dad dad_L002", artifact.timeline)
        self.assertTrue(
            artifact.timeline.startswith(
                "# Generated from content/episodes/dad/scripts.json;"
            )
        )

    def test_script_md_remains_the_default_without_a_manifest(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            episodes_dir = Path(temporary_directory)
            episode_dir = episodes_dir / "dad"
            episode_dir.mkdir()
            script_path = episode_dir / "script.md"
            script_path.write_text("dad: Hello.\n", encoding="utf-8")

            episode_sources = discover_sources(["dad"], episodes_dir)[0]

        self.assertEqual(episode_sources.source_paths, (script_path,))
        self.assertEqual(episode_sources.source_label, "script.md")

    def test_source_manifest_rejects_non_adjacent_and_missing_sources(self) -> None:
        invalid_manifests = {
            '{"sources": ["../outside.md"]}\n': "must be an adjacent `.md` filename",
            '{"sources": ["missing.md"]}\n': "listed source does not exist",
            '{"sources": ["one.md", "one.md"]}\n': "duplicate source `one.md`",
        }
        for manifest, expected in invalid_manifests.items():
            with self.subTest(manifest=manifest):
                with tempfile.TemporaryDirectory() as temporary_directory:
                    episodes_dir = Path(temporary_directory)
                    episode_dir = episodes_dir / "dad"
                    episode_dir.mkdir()
                    (episode_dir / "scripts.json").write_text(
                        manifest,
                        encoding="utf-8",
                    )
                    (episode_dir / "one.md").write_text(
                        "dad: Hello.\n",
                        encoding="utf-8",
                    )

                    with self.assertRaises(CompileError) as raised:
                        discover_sources(["dad"], episodes_dir)

                self.assertIn(expected, str(raised.exception))

    def test_duplicate_label_is_an_author_error(self) -> None:
        self.assert_compile_error(
            "## same\ndad: One\n## same\ndad: Two\n",
            "duplicate label `same`",
        )

    def test_unknown_phrase_id_is_an_author_error(self) -> None:
        self.assert_compile_error(
            """\
dad: [hello]{id=hello}
if kept("missing"):
  dad: What?
""",
            "phrase id `missing` that is not on the latest phrase-cut line",
        )

    def test_condition_cannot_reference_an_older_phrase_line(self) -> None:
        self.assert_compile_error(
            """\
dad: [hello]{id=hello}
dad: [goodbye]{id=goodbye}
if kept("hello"):
  dad: What?
""",
            "phrase id `hello` that is not on the latest phrase-cut line",
        )

    def test_consecutive_conditions_can_inspect_the_same_phrase_line(self) -> None:
        artifact = self.compile(
            """\
dad: [hello]{id=hello}
if kept("hello"):
  dad: First reaction.
if removed("hello"):
  dad: Second reaction.
"""
        )
        self.assertEqual(artifact.timeline.count('PhraseMemory.kept("hello")'), 1)
        self.assertEqual(artifact.timeline.count('PhraseMemory.removed("hello")'), 1)

    def test_choice_arms_can_inspect_the_same_phrase_line(self) -> None:
        artifact = self.compile(
            """\
dad: [hello]{id=hello}
- First
  if kept("hello"):
    dad: First reaction.
- Second
  if removed("hello"):
    dad: Second reaction.
"""
        )
        self.assertIn("- First", artifact.timeline)
        self.assertIn("- Second", artifact.timeline)
        self.assertIn('PhraseMemory.kept("hello")', artifact.timeline)
        self.assertIn('PhraseMemory.removed("hello")', artifact.timeline)

    def test_unknown_stat_is_an_author_error(self) -> None:
        self.assert_compile_error(
            "dad.charisma += 1\n",
            "unknown stat `dad.charisma`",
        )

    def test_all_sources_compile_before_any_writes_is_supported(self) -> None:
        first = self.compile("dad: [hello]{id=hello}\n")
        second = self.compile("dad: [hello]{id=hello}\n")
        self.assertEqual(first.timeline, second.timeline)
        self.assertEqual(first.phrases, second.phrases)


if __name__ == "__main__":
    unittest.main()
