from __future__ import annotations

import tempfile
from pathlib import Path
import unittest

from tools.compile_dialogue import CompileError, compile_source


STATS = frozenset(
    {
        "dad.success",
        "dad.silly",
        "interviewer.impression",
    }
)


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

    def test_cost_defaults_to_word_count(self) -> None:
        artifact = self.compile("dad: [one two three]\n")
        self.assertIn('"cost": 3', artifact.phrases)

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
