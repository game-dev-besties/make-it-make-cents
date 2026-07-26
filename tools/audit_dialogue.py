#!/usr/bin/env python3
"""Enumerate phrase-cut paths and surface suspicious dialogue coverage.

The compiler proves that a script is syntactically valid. This tool answers a
different set of writer-facing questions:

* Which phrase selections and delivery modes are actually reachable?
* Which response branch handles each selection?
* Which budget, score, and story-flag states can survive each prompt?
* Are broad fallbacks, unreachable branches, default-choice surprises, or
  sharp one-toggle score changes hiding likely writing mistakes?

Enumeration is exact for loop-free scripts. Scripts with goto labels are
expanded to a configurable per-label visit bound. Histories still inside a
retry cycle at that bound are reported and excluded from terminal-state
findings. Findings prefixed with HEURISTIC are review prompts, not proof that
the writing is wrong.
"""

from __future__ import annotations

import argparse
import ast
from collections import Counter, defaultdict
from dataclasses import dataclass, field, replace
from functools import lru_cache
from itertools import product
import json
from pathlib import Path
import re
import sys
from typing import Iterable, Mapping, Sequence

PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from tools.compile_dialogue import (
    CompileError,
    EPISODES_DIR,
    PHRASE_CONFIG_KINDS,
    ROOT,
    ScriptParser,
    discover_sources,
    load_allowed_stats,
    load_flag_definitions,
)


SPONSOR_CREDIT = 3
DEFAULT_SPONSOR_SCORE_DELTA = -3
DEFAULT_RECOVERY_MODES = frozenset({"pity", "sponsor"})
DEFAULT_MAX_LOOP_VISITS = 1
SENTENCE_TERMINATORS = ".?!…"
CLOSING_PUNCTUATION = "\"'”’)]}"
WORD_BOUNDARIES = " \t\r\n.,!?…;:\"'“”‘’()[]{}"


class AuditError(Exception):
    """An episode cannot yet be represented by the finite-state auditor."""


def format_delivery_parts(parts: Sequence[str]) -> str:
    """Mirror the runtime's conservative formatting of retained phrase chunks."""
    return " ".join(format_delivery_part_labels(parts)).replace("  ", " ").strip()


def format_delivery_part_labels(parts: Sequence[str]) -> list[str]:
    """Return the exact display form for each non-empty retained phrase chunk."""
    formatted_parts: list[str] = []
    capitalize_next = True
    for raw_part in parts:
        part = str(raw_part).strip()
        if not part:
            continue
        if capitalize_next:
            part = _uppercase_first_cased_character(part)
        formatted_parts.append(part)
        capitalize_next = _ends_sentence(part)
    if formatted_parts:
        formatted_parts[-1] = _replace_terminal_comma(formatted_parts[-1])
    return formatted_parts


def _uppercase_first_cased_character(text: str) -> str:
    for index, character in enumerate(text):
        lower = character.lower()
        upper = character.upper()
        if lower == upper:
            if character.isdigit():
                return text
            continue
        if character == lower and not _word_has_internal_uppercase(text, index):
            return text[:index] + upper + text[index + 1 :]
        return text
    return text


def _word_has_internal_uppercase(text: str, first_index: int) -> bool:
    for character in text[first_index + 1 :]:
        if character in WORD_BOUNDARIES:
            return False
        lower = character.lower()
        upper = character.upper()
        if lower != upper and character == upper:
            return True
    return False


def _ends_sentence(text: str) -> bool:
    index = len(text) - 1
    while index >= 0 and text[index] in CLOSING_PUNCTUATION:
        index -= 1
    return index >= 0 and text[index] in SENTENCE_TERMINATORS


def _replace_terminal_comma(text: str) -> str:
    index = len(text) - 1
    while index >= 0 and text[index] in CLOSING_PUNCTUATION:
        index -= 1
    if index < 0 or text[index] != ",":
        return text
    return text[:index] + "." + text[index + 1 :]


@dataclass(frozen=True)
class PhraseMemory:
    line_id: str
    source_line: int
    known_ids: tuple[str, ...]
    kept_ids: tuple[str, ...]
    kept_indices: tuple[int, ...]
    delivery: str
    cost: int
    text: str


@dataclass(frozen=True)
class SimState:
    budget: int
    stats: tuple[tuple[str, object], ...]
    flags: tuple[tuple[str, object], ...]
    phrase: PhraseMemory | None = None
    halted: bool = False
    truncated_at: str = ""

    def stat_map(self) -> dict[str, object]:
        return dict(self.stats)

    def flag_map(self) -> dict[str, object]:
        return dict(self.flags)

    def mechanics_key(self) -> tuple[object, ...]:
        return (
            self.budget,
            self.stats,
            self.flags,
            self.halted,
            self.truncated_at,
        )


@dataclass
class Reach:
    paths: int
    example: tuple[str, ...] = ()


Frontier = dict[SimState, Reach]


@dataclass(frozen=True)
class CaseKey:
    delivery: str
    kept_indices: tuple[int, ...]
    cost: int


@dataclass
class CaseResult:
    paths: int = 0
    branches: set[int] = field(default_factory=set)
    effects: set[str] = field(default_factory=set)


@dataclass
class QuestionAudit:
    line_id: str
    source_path: Path
    source_line: int
    speaker: str
    phrases: tuple[dict, ...]
    full_cost: int
    input_paths: int = 0
    input_budgets: set[int] = field(default_factory=set)
    available_deliveries: set[str] = field(default_factory=set)
    cases: dict[CaseKey, CaseResult] = field(default_factory=dict)
    response_if_line: int | None = None
    unconditional_response: str | None = None
    response_branches: tuple[tuple[str | None, list[dict], object], ...] = ()
    post_states: dict[tuple[object, ...], Reach] = field(default_factory=dict)


@dataclass
class IfAudit:
    source_path: Path
    source_line: int
    conditions: tuple[str | None, ...]
    selected_paths: Counter[int] = field(default_factory=Counter)
    independently_true_paths: Counter[int] = field(default_factory=Counter)
    overlap_paths: int = 0
    overlap_cases: set[CaseKey] = field(default_factory=set)
    overlap_examples: list[str] = field(default_factory=list)


@dataclass
class CheckAudit:
    source_path: Path
    source_line: int
    name: str
    operator: str
    expected: object
    branch: str
    pass_paths: int = 0
    fail_paths: int = 0
    passing_states: dict[tuple[object, ...], Reach] = field(default_factory=dict)


@dataclass
class ControlFlowExpansion:
    statements: list[dict]
    jump_targets: set[str] = field(default_factory=set)
    bounded_targets: set[str] = field(default_factory=set)


def _initial_stat_value(stat: str) -> object:
    """Mirror current project conventions without making them compiler rules."""
    if stat.endswith(".success"):
        return 5
    if stat.endswith(".silly"):
        return 0
    if stat.startswith("money."):
        return 0
    return False


def _bounded_stat_value(stat: str, value: object) -> object:
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        return value
    if stat.endswith(".success"):
        return max(1, min(10, value))
    if stat.endswith(".silly"):
        return max(0, min(10, value))
    return value


def _literal(raw: str) -> object:
    aliases = {"true": True, "false": False, "null": None}
    if raw in aliases:
        return aliases[raw]
    return ast.literal_eval(raw)


def _add(frontier: Frontier, state: SimState, reach: Reach) -> None:
    existing = frontier.get(state)
    if existing is None:
        frontier[state] = Reach(reach.paths, reach.example)
    else:
        existing.paths += reach.paths


def _merge(*frontiers: Frontier) -> Frontier:
    result: Frontier = {}
    for frontier in frontiers:
        for state, reach in frontier.items():
            _add(result, state, reach)
    return result


def _active_and_halted(frontier: Frontier) -> tuple[Frontier, Frontier]:
    active: Frontier = {}
    halted: Frontier = {}
    for state, reach in frontier.items():
        _add(halted if state.halted else active, state, reach)
    return active, halted


def _clear_phrase_and_collapse(frontier: Frontier) -> Frontier:
    collapsed: Frontier = {}
    for state, reach in frontier.items():
        _add(collapsed, replace(state, phrase=None), reach)
    return collapsed


def _state_summary(state: SimState) -> str:
    stats = ", ".join(f"{name}={value}" for name, value in state.stats)
    flags = ", ".join(f"{name}={value}" for name, value in state.flags)
    return f"${state.budget}; {stats}; {flags}"


class ConditionEvaluator:
    def __init__(self, state: SimState):
        self.state = state
        self.stats = state.stat_map()
        self.flags = state.flag_map()
        self.phrase = state.phrase

    def evaluate(self, expression: str) -> object:
        return self._visit(self._parse(expression))

    @staticmethod
    @lru_cache(maxsize=None)
    def _parse(expression: str) -> ast.AST:
        normalized = re.sub(r"\btrue\b", "True", expression)
        normalized = re.sub(r"\bfalse\b", "False", normalized)
        normalized = re.sub(r"\bnull\b", "None", normalized)
        return ast.parse(normalized, mode="eval").body

    def _visit(self, node: ast.AST) -> object:
        if isinstance(node, ast.Constant):
            return node.value
        if isinstance(node, ast.Name):
            if node.id == "True":
                return True
            if node.id == "False":
                return False
            if node.id == "None":
                return None
            raise AuditError(f"unsupported name in condition: {node.id}")
        if isinstance(node, ast.Attribute) and isinstance(node.value, ast.Name):
            return self.stats[f"{node.value.id}.{node.attr}"]
        if isinstance(node, ast.BoolOp):
            values = [bool(self._visit(value)) for value in node.values]
            return all(values) if isinstance(node.op, ast.And) else any(values)
        if isinstance(node, ast.UnaryOp):
            value = self._visit(node.operand)
            if isinstance(node.op, ast.Not):
                return not bool(value)
            if isinstance(node.op, ast.USub):
                return -value
        if isinstance(node, ast.Compare):
            left = self._visit(node.left)
            for operator, comparator in zip(node.ops, node.comparators):
                right = self._visit(comparator)
                if isinstance(operator, ast.Eq):
                    matched = left == right
                elif isinstance(operator, ast.NotEq):
                    matched = left != right
                elif isinstance(operator, ast.Lt):
                    matched = left < right
                elif isinstance(operator, ast.LtE):
                    matched = left <= right
                elif isinstance(operator, ast.Gt):
                    matched = left > right
                elif isinstance(operator, ast.GtE):
                    matched = left >= right
                else:
                    raise AuditError("unsupported comparison operator")
                if not matched:
                    return False
                left = right
            return True
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name):
            function = node.func.id
            argument = self._visit(node.args[0]) if node.args else None
            if function == "flag":
                return self.flags[str(argument)]
            if function == "budget":
                return self.state.budget
            if self.phrase is None:
                if function == "kept_count":
                    return 0
                return False
            if function == "kept":
                return str(argument) in self.phrase.kept_ids
            if function == "removed":
                return (
                    str(argument) in self.phrase.known_ids
                    and str(argument) not in self.phrase.kept_ids
                )
            if function == "kept_count":
                return len(self.phrase.kept_ids)
            if function == "delivery":
                return self.phrase.delivery == str(argument)
        raise AuditError(f"unsupported condition node: {ast.dump(node)}")


@lru_cache(maxsize=None)
def _condition_is_phrase_local(expression: str) -> bool:
    for node in ast.walk(ConditionEvaluator._parse(expression)):
        if isinstance(node, ast.Attribute):
            return False
        if (
            isinstance(node, ast.Call)
            and isinstance(node.func, ast.Name)
            and node.func.id in {"flag", "budget"}
        ):
            return False
    return True


@lru_cache(maxsize=None)
def _condition_uses_phrase(expression: str) -> bool:
    return any(
        isinstance(node, ast.Call)
        and isinstance(node.func, ast.Name)
        and node.func.id in {"kept", "removed", "kept_count", "delivery"}
        for node in ast.walk(ConditionEvaluator._parse(expression))
    )


def _statements_reference_current_phrase(statements: Sequence[dict]) -> bool:
    for statement in statements:
        kind = statement["kind"]
        if kind in PHRASE_CONFIG_KINDS:
            return False
        if kind == "dialogue" and "phrases" in statement:
            return False
        if kind == "if":
            if any(
                condition is not None and _condition_uses_phrase(condition)
                for condition, _body, _line in statement["branches"]
            ):
                return True
            if any(
                _statements_reference_current_phrase(body)
                for _condition, body, _line in statement["branches"]
            ):
                return True
        elif kind in {"flag_check", "choice"}:
            if _statements_reference_current_phrase(statement["body"]):
                return True
        elif kind == "jump" and statement["target"] == "end":
            return False
    return False


def _has_phrase_reset_or_end(statements: Sequence[dict]) -> bool:
    return any(
        statement["kind"] in PHRASE_CONFIG_KINDS
        or (
            statement["kind"] == "dialogue"
            and "phrases" in statement
        )
        or (
            statement["kind"] == "jump"
            and statement["target"] == "end"
        )
        for statement in statements
    )


def _can_discard_current_phrase(statements: Sequence[dict]) -> bool:
    return (
        _has_phrase_reset_or_end(statements)
        and not _statements_reference_current_phrase(statements)
    )


def _is_simple_transition(statements: Sequence[dict]) -> bool:
    for statement in statements:
        kind = statement["kind"]
        if kind in PHRASE_CONFIG_KINDS or kind in {
            "if",
            "flag_check",
            "choice",
            "recovery",
            "audit_loop_cutoff",
        }:
            return False
        if kind == "dialogue" and "phrases" in statement:
            return False
    return True


def _expand_control_flow(
    statements: Sequence[dict],
    *,
    max_loop_visits: int,
) -> ControlFlowExpansion:
    """Inline goto destinations while bounding retry cycles.

    The writer format only permits top-level labels, so a jump can be modeled
    by replacing it with the destination's remaining top-level statements.
    A synthetic terminal statement prevents the caller's surrounding block
    from continuing after that inlined destination finishes.

    Visit counts are local to one statically expanded history. Forward jumps
    therefore remain exact, while a backward jump eventually becomes an
    ``audit_loop_cutoff`` statement instead of recursing forever.
    """
    if max_loop_visits < 1:
        raise AuditError("max_loop_visits must be at least 1")

    top_level = list(statements)
    labels = {
        statement["name"]: index
        for index, statement in enumerate(top_level)
        if statement["kind"] == "label"
    }
    result = ControlFlowExpansion(statements=[])

    def expand_sequence(
        sequence: Sequence[dict],
        visits: Mapping[str, int],
    ) -> list[dict]:
        expanded: list[dict] = []
        for statement in sequence:
            kind = statement["kind"]
            if kind == "jump":
                target = statement["target"]
                if target == "end":
                    expanded.append(statement)
                    break

                result.jump_targets.add(target)
                target_visits = visits.get(target, 0) + 1
                if target_visits > max_loop_visits:
                    result.bounded_targets.add(target)
                    expanded.append(
                        {
                            "kind": "audit_loop_cutoff",
                            "target": target,
                            "line": statement["line"],
                        }
                    )
                    break

                next_visits = dict(visits)
                next_visits[target] = target_visits
                expanded.extend(
                    expand_sequence(
                        top_level[labels[target] :],
                        next_visits,
                    )
                )
                # The inlined tail belongs to the jump, not to the block that
                # contained it. Halt any destination path that naturally
                # reaches the end of the episode without an explicit `-> end`.
                expanded.append(
                    {
                        "kind": "jump",
                        "target": "end",
                        "line": statement["line"],
                        "audit_synthetic": True,
                    }
                )
                break

            if kind == "if":
                expanded.append(
                    {
                        **statement,
                        "branches": [
                            (
                                condition,
                                expand_sequence(body, visits),
                                branch_line,
                            )
                            for condition, body, branch_line in statement["branches"]
                        ],
                    }
                )
            elif kind in {"flag_check", "choice"}:
                expanded.append(
                    {
                        **statement,
                        "body": expand_sequence(statement["body"], visits),
                    }
                )
            else:
                expanded.append(statement)
        return expanded

    result.statements = expand_sequence(top_level, {})
    return result


class EpisodeAuditor:
    def __init__(
        self,
        episode_id: str,
        statements: Sequence[dict],
        *,
        source_root: Path,
        allowed_stats: frozenset[str],
        flag_defaults: Mapping[str, object],
        initial_flag_variants: Sequence[Mapping[str, object]] = (),
        initial_budget: int,
        score_owner: str,
        expected_phrase_lines: int | None = None,
        max_loop_visits: int = DEFAULT_MAX_LOOP_VISITS,
    ):
        self.episode_id = episode_id
        self.statements = list(statements)
        self.source_root = source_root
        self.allowed_stats = allowed_stats
        self.flag_defaults = dict(flag_defaults)
        self.initial_flag_variants = [
            dict(variant)
            for variant in initial_flag_variants
        ] or [{}]
        self.initial_budget = initial_budget
        self.score_owner = score_owner
        self.expected_phrase_lines = expected_phrase_lines
        self.max_loop_visits = max_loop_visits
        self.questions: dict[str, QuestionAudit] = {}
        self.if_audits: dict[tuple[str, int], IfAudit] = {}
        self.check_audits: dict[tuple[str, int], CheckAudit] = {}
        self.loop_cutoff_paths: Counter[str] = Counter()
        self.loop_cutoff_examples: dict[str, tuple[str, ...]] = {}
        self._phrase_ids: dict[int, str] = {}
        self._index_phrase_lines(self.statements)
        self.control_flow = _expand_control_flow(
            self.statements,
            max_loop_visits=max_loop_visits,
        )
        self.statements = self.control_flow.statements

    def _index_phrase_lines(self, statements: Sequence[dict]) -> None:
        sequence = len(self._phrase_ids)
        for statement in statements:
            if statement["kind"] == "dialogue" and "phrases" in statement:
                sequence += 1
                self._phrase_ids[id(statement)] = (
                    f"{self.episode_id}_L{sequence:03d}"
                )
            elif statement["kind"] == "if":
                for _condition, body, _line in statement["branches"]:
                    self._index_phrase_lines(body)
                    sequence = len(self._phrase_ids)
            elif statement["kind"] in {"flag_check", "choice"}:
                self._index_phrase_lines(statement["body"])
                sequence = len(self._phrase_ids)

    def run(self) -> dict:
        initial_stats = tuple(
            (stat, _initial_stat_value(stat))
            for stat in sorted(self.allowed_stats)
        )
        initial_frontier: Frontier = {}
        for variant in self.initial_flag_variants:
            flags = {**self.flag_defaults, **variant}
            description = ", ".join(
                f"{name}={json.dumps(value, ensure_ascii=False)}"
                for name, value in sorted(variant.items())
            )
            initial = SimState(
                budget=self.initial_budget,
                stats=initial_stats,
                flags=tuple(sorted(flags.items())),
            )
            _add(
                initial_frontier,
                initial,
                Reach(
                    1,
                    (f"initial flags: {description}",)
                    if description
                    else (),
                ),
            )
        frontier = self._execute_sequence(
            self.statements,
            initial_frontier,
        )
        return self._build_report(frontier)

    def _execute_sequence(
        self,
        statements: Sequence[dict],
        frontier: Frontier,
    ) -> Frontier:
        position = 0
        while position < len(statements):
            active, halted = _active_and_halted(frontier)
            if not active:
                return frontier

            statement = statements[position]
            kind = statement["kind"]
            if kind in PHRASE_CONFIG_KINDS:
                configs: dict[str, dict] = {}
                while (
                    position < len(statements)
                    and statements[position]["kind"] in PHRASE_CONFIG_KINDS
                ):
                    config = statements[position]
                    configs[config["kind"]] = config
                    position += 1
                phrase_statement = statements[position]
                active = self._execute_phrase(phrase_statement, active, configs)
            elif kind == "dialogue" and "phrases" in statement:
                active = self._execute_phrase(statement, active, {})
            elif kind == "if":
                active = self._execute_if(statement, active)
            elif kind == "flag_check":
                active = self._execute_flag_check(statement, active)
            elif kind == "flag_set":
                active = self._execute_flag_set(statement, active)
            elif kind == "set":
                active = self._execute_stat_set(statement, active)
            elif kind == "budget":
                active = {
                    replace(state, budget=statement["amount"]): reach
                    for state, reach in active.items()
                }
            elif kind == "choice":
                choices: list[dict] = []
                while (
                    position < len(statements)
                    and statements[position]["kind"] == "choice"
                ):
                    choices.append(statements[position])
                    position += 1
                choice_frontiers: list[Frontier] = []
                for choice in choices:
                    seeded: Frontier = {}
                    for state, reach in active.items():
                        _add(
                            seeded,
                            state,
                            Reach(
                                reach.paths,
                                reach.example + (f'choice "{choice["text"]}"',),
                            ),
                        )
                    choice_frontiers.append(
                        self._execute_sequence(choice["body"], seeded)
                    )
                active = _merge(*choice_frontiers)
                frontier = _merge(active, halted)
                continue
            elif kind == "jump":
                if statement["target"] != "end":
                    raise AssertionError("non-terminal jump was not expanded")
                active = {
                    replace(state, halted=True): reach
                    for state, reach in active.items()
                }
            elif kind == "audit_loop_cutoff":
                target = statement["target"]
                self.loop_cutoff_paths[target] += sum(
                    reach.paths for reach in active.values()
                )
                if target not in self.loop_cutoff_examples and active:
                    example_reach = next(iter(active.values()))
                    self.loop_cutoff_examples[target] = (
                        example_reach.example + (f"loop limit at {target}",)
                    )
                active = {
                    replace(
                        state,
                        halted=True,
                        truncated_at=target,
                    ): Reach(
                        reach.paths,
                        reach.example + (f"loop limit at {target}",),
                    )
                    for state, reach in active.items()
                }
            elif kind == "dialogue":
                self._record_unconditional_response(statement, active)
            elif kind in {
                "label",
                "narration",
                "wait",
                "cue",
                "speaker_name",
                "background",
                "music",
                "sfx",
            }:
                pass
            elif kind == "recovery":
                raise AssertionError("recovery directive was not paired")
            else:
                raise AuditError(f"unsupported statement kind: {kind}")

            frontier = _merge(active, halted)
            position += 1
            remaining_statements = statements[position:]
            if (
                remaining_statements
                and any(state.phrase is not None for state in active)
            ):
                self._record_upcoming_unconditional_response(
                    remaining_statements,
                    active,
                )
            if (
                remaining_statements
                and _can_discard_current_phrase(remaining_statements)
                and any(state.phrase is not None for state in active)
            ):
                active = _clear_phrase_and_collapse(active)
                frontier = _merge(active, halted)
        return frontier

    def _execute_phrase(
        self,
        statement: dict,
        frontier: Frontier,
        configs: Mapping[str, dict],
    ) -> Frontier:
        frontier = _clear_phrase_and_collapse(frontier)
        phrases = tuple(statement["phrases"])
        line = statement["line"]
        line_id = self._phrase_ids[id(statement)]
        question = self.questions.get(line_id)
        if question is None:
            question = QuestionAudit(
                line_id=line_id,
                source_path=line.path,
                source_line=line.number,
                speaker=statement["speaker"],
                phrases=phrases,
                full_cost=sum(int(phrase["cost"]) for phrase in phrases),
            )
            self.questions[line_id] = question

        recovery = DEFAULT_RECOVERY_MODES
        if "recovery" in configs:
            policy = configs["recovery"]["policy"]
            recovery = (
                frozenset()
                if policy == "none"
                else frozenset(policy.split(","))
            )
        sponsor_score = int(
            configs.get(
                "sponsor_score",
                {"delta": DEFAULT_SPONSOR_SCORE_DELTA},
            )["delta"]
        )
        required_delivery = str(
            configs.get(
                "required_delivery",
                {"delivery": ""},
            )["delivery"]
        )

        result: Frontier = {}
        question.input_paths += sum(reach.paths for reach in frontier.values())
        question.input_budgets.update(state.budget for state in frontier)
        for state, reach in frontier.items():
            for case in self._available_cases(
                phrases,
                state,
                recovery,
            ):
                if (
                    required_delivery
                    and case.delivery != required_delivery
                ):
                    continue
                next_state = self._apply_delivery(
                    state,
                    statement["speaker"],
                    case,
                    sponsor_score,
                )
                phrase_memory = PhraseMemory(
                    line_id=line_id,
                    source_line=line.number,
                    known_ids=tuple(
                        str(phrase["id"])
                        for phrase in phrases
                        if phrase["id"] is not None
                    ),
                    kept_ids=tuple(
                        str(phrases[index]["id"])
                        for index in case.kept_indices
                        if phrases[index]["id"] is not None
                    ),
                    kept_indices=case.kept_indices,
                    delivery=case.delivery,
                    cost=case.cost,
                    text=self._case_text(phrases, case),
                )
                next_state = replace(next_state, phrase=phrase_memory)
                selection = self._case_label(question, case)
                _add(
                    result,
                    next_state,
                    Reach(
                        reach.paths,
                        reach.example + (f"{line_id}: {selection}",),
                    ),
                )
                question.available_deliveries.add(case.delivery)
                case_result = question.cases.setdefault(case, CaseResult())
                case_result.paths += reach.paths
        return result

    def _record_unconditional_response(
        self,
        statement: dict,
        frontier: Frontier,
    ) -> None:
        for state in frontier:
            if state.phrase is None:
                continue
            question = self.questions[state.phrase.line_id]
            if (
                question.response_if_line is None
                and question.unconditional_response is None
            ):
                question.unconditional_response = statement["text"]

    def _record_upcoming_unconditional_response(
        self,
        statements: Sequence[dict],
        frontier: Frontier,
    ) -> None:
        for statement in statements:
            kind = statement["kind"]
            if kind == "dialogue":
                if "phrases" not in statement:
                    self._record_unconditional_response(statement, frontier)
                return
            if kind in PHRASE_CONFIG_KINDS or kind in {
                "if",
                "flag_check",
                "choice",
                "jump",
                "audit_loop_cutoff",
            }:
                return

    def _available_cases(
        self,
        phrases: tuple[dict, ...],
        state: SimState,
        recovery: frozenset[str],
    ) -> Iterable[CaseKey]:
        selectable = (
            tuple(range(len(phrases)))
            if state.budget > 0
            else tuple(
                index
                for index, phrase in enumerate(phrases)
                if int(phrase["cost"]) == 0
            )
        )
        for mask in range(1 << len(selectable)):
            kept = tuple(
                selectable[offset]
                for offset in range(len(selectable))
                if mask & (1 << offset)
            )
            cost = sum(int(phrases[index]["cost"]) for index in kept)
            if cost > state.budget:
                continue
            if not kept:
                yield CaseKey("silence", (), 0)
            else:
                yield CaseKey("normal", kept, cost)
        if "pity" in recovery:
            yield CaseKey("pity", (), 0)
        if "sponsor" in recovery:
            yield CaseKey("sponsor", (), 0)

    def _apply_delivery(
        self,
        state: SimState,
        speaker: str,
        case: CaseKey,
        sponsor_score: int,
    ) -> SimState:
        if case.delivery == "normal":
            return replace(state, budget=state.budget - case.cost)
        if case.delivery == "pity":
            return state
        if case.delivery != "sponsor":
            return state

        next_state = replace(
            state,
            budget=state.budget + SPONSOR_CREDIT,
        )
        score_group = {
            "percy": "son",
            "marco": "dad",
            "rosa": "grandma",
        }.get(speaker.lower(), speaker.lower())
        stat = f"{score_group}.success"
        if stat not in self.allowed_stats:
            return next_state
        stats = next_state.stat_map()
        stats[stat] = _bounded_stat_value(
            stat,
            stats[stat] + sponsor_score,
        )
        return replace(next_state, stats=tuple(sorted(stats.items())))

    def _execute_if(self, statement: dict, frontier: Frontier) -> Frontier:
        line = statement["line"]
        audit_key = (str(line.path), line.number)
        audit = self.if_audits.get(audit_key)
        if audit is None:
            audit = IfAudit(
                source_path=line.path,
                source_line=line.number,
                conditions=tuple(
                    condition
                    for condition, _body, _branch_line in statement["branches"]
                ),
            )
            self.if_audits[audit_key] = audit

        result: Frontier = {}
        associated_questions = {
            state.phrase.line_id
            for state in frontier
            if state.phrase is not None
            and self.questions[state.phrase.line_id].response_if_line is None
            and self.questions[
                state.phrase.line_id
            ].unconditional_response is None
        }
        response_question_id = (
            next(iter(associated_questions))
            if len(associated_questions) == 1
            else None
        )
        response_question = (
            self.questions[response_question_id]
            if response_question_id is not None
            else None
        )
        if response_question is not None:
            response_question.response_if_line = line.number
            response_question.response_branches = tuple(statement["branches"])

        conditions = tuple(
            condition
            for condition, _body, _branch_line in statement["branches"]
        )
        phrase_local_conditions = all(
            condition is None or _condition_is_phrase_local(condition)
            for condition in conditions
        )
        phrase_condition_cache: dict[
            PhraseMemory | None,
            tuple[int, ...],
        ] = {}
        simple_branches = tuple(
            _is_simple_transition(body)
            for _condition, body, _branch_line in statement["branches"]
        )
        transition_cache: dict[
            tuple[int, tuple[object, ...]],
            Frontier,
        ] = {}

        for state, reach in frontier.items():
            cached_true_indices = (
                phrase_condition_cache.get(state.phrase)
                if phrase_local_conditions
                else None
            )
            if cached_true_indices is None:
                evaluator = ConditionEvaluator(state)
                true_indices = tuple(
                    index
                    for index, condition in enumerate(conditions)
                    if condition is not None
                    and bool(evaluator.evaluate(condition))
                )
                if phrase_local_conditions:
                    phrase_condition_cache[state.phrase] = true_indices
            else:
                true_indices = cached_true_indices
            for index in true_indices:
                audit.independently_true_paths[index] += reach.paths
            if len(true_indices) > 1:
                audit.overlap_paths += reach.paths
                if state.phrase is not None:
                    audit.overlap_cases.add(
                        CaseKey(
                            state.phrase.delivery,
                            state.phrase.kept_indices,
                            state.phrase.cost,
                        )
                    )
                if len(audit.overlap_examples) < 3:
                    audit.overlap_examples.append(_state_summary(state))

            selected_index: int | None = true_indices[0] if true_indices else None
            if selected_index is None:
                selected_index = next(
                    (
                        index
                        for index, (condition, _body, _branch_line) in enumerate(
                            statement["branches"]
                        )
                        if condition is None
                    ),
                    None,
                )
            if selected_index is None:
                _add(result, state, reach)
                continue

            audit.selected_paths[selected_index] += reach.paths
            _condition, body, _branch_line = statement["branches"][selected_index]
            before = state
            if simple_branches[selected_index]:
                transition_key = (selected_index, state.mechanics_key())
                branch_frontier = transition_cache.get(transition_key)
                if branch_frontier is None:
                    mechanical_state = replace(state, phrase=None)
                    branch_frontier = self._execute_sequence(
                        body,
                        {mechanical_state: Reach(1)},
                    )
                    transition_cache[transition_key] = branch_frontier
                branch_frontier = {
                    replace(next_state, phrase=state.phrase): Reach(
                        next_reach.paths * reach.paths,
                        reach.example + next_reach.example,
                    )
                    for next_state, next_reach in branch_frontier.items()
                }
            else:
                branch_frontier = self._execute_sequence(
                    body,
                    {state: Reach(reach.paths, reach.example)},
                )
            for next_state, next_reach in branch_frontier.items():
                _add(result, next_state, next_reach)
                if response_question is not None and state.phrase is not None:
                    case = CaseKey(
                        state.phrase.delivery,
                        state.phrase.kept_indices,
                        state.phrase.cost,
                    )
                    case_result = response_question.cases[case]
                    case_result.branches.add(selected_index)
                    case_result.effects.add(self._effect_summary(before, next_state))

        if response_question is not None:
            for state, reach in result.items():
                key = state.mechanics_key()
                existing = response_question.post_states.get(key)
                if existing is None:
                    response_question.post_states[key] = Reach(
                        reach.paths,
                        reach.example,
                    )
                else:
                    existing.paths += reach.paths
        return result

    def _execute_flag_check(
        self,
        statement: dict,
        frontier: Frontier,
    ) -> Frontier:
        line = statement["line"]
        key = (str(line.path), line.number)
        audit = self.check_audits.get(key)
        if audit is None:
            audit = CheckAudit(
                source_path=line.path,
                source_line=line.number,
                name=statement["flag"],
                operator=statement["operator"],
                expected=statement["value"],
                branch=statement["branch"]
                or (
                    f'{statement["flag"]} {statement["operator"]} '
                    f'{json.dumps(statement["value"], ensure_ascii=False)}'
                ),
            )
            self.check_audits[key] = audit

        passed: Frontier = {}
        failed: Frontier = {}
        for state, reach in frontier.items():
            actual = state.flag_map()[statement["flag"]]
            matches = actual == statement["value"]
            if statement["operator"] == "!=":
                matches = not matches
            if matches:
                audit.pass_paths += reach.paths
                mechanics = state.mechanics_key()
                existing = audit.passing_states.get(mechanics)
                if existing is None:
                    audit.passing_states[mechanics] = Reach(
                        reach.paths,
                        reach.example,
                    )
                else:
                    existing.paths += reach.paths
                _add(passed, state, reach)
            else:
                audit.fail_paths += reach.paths
                _add(failed, state, reach)
        return _merge(
            self._execute_sequence(statement["body"], passed),
            failed,
        )

    def _execute_flag_set(
        self,
        statement: dict,
        frontier: Frontier,
    ) -> Frontier:
        result: Frontier = {}
        for state, reach in frontier.items():
            flags = state.flag_map()
            flags[statement["flag"]] = statement["value"]
            _add(result, replace(state, flags=tuple(sorted(flags.items()))), reach)
        return result

    def _execute_stat_set(
        self,
        statement: dict,
        frontier: Frontier,
    ) -> Frontier:
        result: Frontier = {}
        for state, reach in frontier.items():
            stats = state.stat_map()
            value = _literal(statement["value"])
            if statement["operator"] == "+=":
                value = stats[statement["stat"]] + value
            elif statement["operator"] == "-=":
                value = stats[statement["stat"]] - value
            stats[statement["stat"]] = _bounded_stat_value(
                statement["stat"],
                value,
            )
            _add(result, replace(state, stats=tuple(sorted(stats.items()))), reach)
        return result

    def _case_text(
        self,
        phrases: tuple[dict, ...],
        case: CaseKey,
    ) -> str:
        if case.delivery == "silence":
            return "(silence)"
        if case.delivery in {"pity", "sponsor"}:
            return f"({case.delivery})"
        return format_delivery_parts(
            [str(phrases[index]["text"]) for index in case.kept_indices]
        )

    def _case_label(
        self,
        question: QuestionAudit,
        case: CaseKey,
    ) -> str:
        if case.delivery != "normal":
            return case.delivery.upper()
        ids = [
            str(question.phrases[index]["id"] or f"phrase_{index + 1}")
            for index in case.kept_indices
        ]
        return f"{'+'.join(ids)} (${case.cost})"

    def _effect_summary(self, before: SimState, after: SimState) -> str:
        changes: list[str] = []
        before_stats = before.stat_map()
        for stat, value in after.stats:
            previous = before_stats[stat]
            if value != previous:
                delta = value - previous
                changes.append(f"{stat}{delta:+g}")
        before_flags = before.flag_map()
        for flag, value in after.flags:
            if value != before_flags[flag]:
                changes.append(f"{flag}={value}")
        return ", ".join(changes) if changes else "no state change"

    def _budget_pressure(self) -> dict:
        full_cost_by_line = {
            question.line_id: question.full_cost
            for question in self.questions.values()
        }
        cheapest_non_silent_cost_by_line = {
            question.line_id: min(
                int(phrase["cost"])
                for phrase in question.phrases
            )
            for question in self.questions.values()
        }
        total_full_cost = sum(full_cost_by_line.values())
        total_cheapest_non_silent = sum(
            cheapest_non_silent_cost_by_line.values()
        )
        largest_single_full_cost = max(
            full_cost_by_line.values(),
            default=0,
        )
        one_full_plus_cheapest_non_silent_minimum = max(
            (
                total_cheapest_non_silent
                + question.full_cost
                - cheapest_non_silent_cost_by_line[question.line_id]
            )
            for question in self.questions.values()
        ) if self.questions else 0
        return {
            "initial_budget": self.initial_budget,
            "implemented_full_cost": total_full_cost,
            "headroom_over_all_full": self.initial_budget - total_full_cost,
            "largest_single_full_cost": largest_single_full_cost,
            "headroom_over_largest_single_full": (
                self.initial_budget - largest_single_full_cost
            ),
            "implemented_cheapest_non_silent_total": (
                total_cheapest_non_silent
            ),
            "one_full_plus_cheapest_non_silent_minimum": (
                one_full_plus_cheapest_non_silent_minimum
            ),
            "headroom_over_one_full_plus_cheapest_non_silent": (
                self.initial_budget
                - one_full_plus_cheapest_non_silent_minimum
            ),
            "full_cost_by_line": full_cost_by_line,
            "cheapest_non_silent_cost_by_line": (
                cheapest_non_silent_cost_by_line
            ),
        }

    def _build_report(self, frontier: Frontier) -> dict:
        completed_frontier = {
            state: reach
            for state, reach in frontier.items()
            if not state.truncated_at
        }
        truncated_frontier = {
            state: reach
            for state, reach in frontier.items()
            if state.truncated_at
        }
        final_states: dict[tuple[object, ...], Reach] = {}
        for state, reach in completed_frontier.items():
            key = state.mechanics_key()
            existing = final_states.get(key)
            if existing is None:
                final_states[key] = Reach(reach.paths, reach.example)
            else:
                existing.paths += reach.paths

        budget_pressure = self._budget_pressure()
        findings = self._findings(final_states, budget_pressure)
        return {
            "episode": self.episode_id,
            "assumptions": {
                "exact_for": (
                    "loop-free scripts"
                    if not self.control_flow.jump_targets
                    else (
                        "histories within the configured per-label visit bound; "
                        "terminal findings exclude histories still retrying at "
                        "that bound"
                    )
                ),
                "initial_budget": self.initial_budget,
                "score_owner": self.score_owner,
                "initial_flag_variants": self.initial_flag_variants,
                "initial_stats": {
                    stat: _initial_stat_value(stat)
                    for stat in sorted(self.allowed_stats)
                },
                "stat_bounds": {
                    "*.success": [1, 10],
                    "*.silly": [0, 10],
                },
                "sponsor_credit": SPONSOR_CREDIT,
                "counts_are_probabilities": False,
            },
            "control_flow": {
                "jump_targets": sorted(self.control_flow.jump_targets),
                "max_loop_visits": self.max_loop_visits,
                "bounded_targets": [
                    {
                        "target": target,
                        "raw_paths": self.loop_cutoff_paths[target],
                        "example": list(
                            self.loop_cutoff_examples.get(target, ())
                        ),
                    }
                    for target in sorted(self.control_flow.bounded_targets)
                ],
            },
            "summary": {
                "phrase_lines": len(self._phrase_ids),
                "reachable_phrase_lines": len(self.questions),
                "raw_paths": sum(
                    reach.paths for reach in completed_frontier.values()
                ),
                "truncated_raw_paths": sum(
                    reach.paths for reach in truncated_frontier.values()
                ),
                "final_mechanical_states": len(final_states),
                "final_budget": self._value_range(
                    key[0] for key in final_states
                ),
                "reachable_deliveries": sorted(
                    {
                        delivery
                        for question in self.questions.values()
                        for delivery in question.available_deliveries
                    }
                ),
            },
            "budget_pressure": budget_pressure,
            "findings": findings,
            "questions": [
                self._question_to_dict(question)
                for question in self.questions.values()
            ],
            "checks": [
                self._check_to_dict(check)
                for check in self.check_audits.values()
            ],
            "final_states": [
                self._mechanical_state_to_dict(key, reach)
                for key, reach in sorted(
                    final_states.items(),
                    key=lambda item: repr(item[0]),
                )
            ],
        }

    def _findings(
        self,
        final_states: Mapping[tuple[object, ...], Reach],
        budget_pressure: Mapping[str, object],
    ) -> list[dict]:
        findings: list[dict] = []

        if (
            self.expected_phrase_lines is not None
            and len(self._phrase_ids) != self.expected_phrase_lines
        ):
            findings.append(
                {
                    "severity": "high",
                    "code": "PHRASE_LINE_COUNT",
                    "kind": "exact",
                    "message": (
                        f"Expected {self.expected_phrase_lines} phrase prompts "
                        f"but found {len(self._phrase_ids)}."
                    ),
                }
            )

        one_full_minimum = int(
            budget_pressure[
                "one_full_plus_cheapest_non_silent_minimum"
            ]
        )
        if self.questions and self.initial_budget < one_full_minimum:
            shortfall = one_full_minimum - self.initial_budget
            findings.append(
                {
                    "severity": "medium",
                    "code": "BUDGET_BELOW_ONE_FULL_MINIMUM",
                    "kind": "heuristic",
                    "message": (
                        f"Starting budget ${self.initial_budget} is "
                        f"${shortfall} below the static ${one_full_minimum} "
                        "minimum for keeping every prompt eligible as the one "
                        "complete answer while making the cheapest non-silent "
                        "selection on every other prompt. Sponsor credit and "
                        "scripted budget changes may still make those routes "
                        "reachable."
                    ),
                }
            )

        reached_line_ids = set(self.questions)
        for _statement_id, line_id in self._phrase_ids.items():
            if line_id in reached_line_ids:
                continue
            findings.append(
                {
                    "severity": "high",
                    "code": "UNREACHABLE_PHRASE_LINE",
                    "kind": "exact",
                    "line_id": line_id,
                    "message": (
                        "No configured initial flag variant reaches this "
                        "phrase prompt."
                    ),
                }
            )

        for question in self.questions.values():
            full = CaseKey(
                "normal",
                tuple(range(len(question.phrases))),
                question.full_cost,
            )
            if question.cases and full not in question.cases:
                input_min = min(question.input_budgets)
                input_max = max(question.input_budgets)
                incoming_budget = (
                    f"${input_min}"
                    if input_min == input_max
                    else f"${input_min}–${input_max}"
                )
                findings.append(
                    {
                        "severity": "medium",
                        "code": "FULL_SELECTION_UNREACHABLE",
                        "kind": "exact",
                        "line_id": question.line_id,
                        "message": (
                            f"The complete ${question.full_cost} selection is "
                            "unreachable from every enumerated incoming state "
                            f"(incoming budget: {incoming_budget}). Review "
                            "whether forced cutting or recovery is intentional."
                        ),
                    }
                )

            if question.response_if_line is None:
                if question.unconditional_response is None:
                    findings.append(
                        {
                            "severity": "high",
                            "code": "NO_RESPONSE",
                            "kind": "exact",
                            "line_id": question.line_id,
                            "message": (
                                "No conditional or unconditional dialogue "
                                "response follows this phrase prompt."
                            ),
                        }
                    )
                continue

            normal_cases = [
                case
                for case in question.cases
                if case.delivery == "normal"
            ]
            else_index = next(
                (
                    index
                    for index, (condition, _body, _line) in enumerate(
                        question.response_branches
                    )
                    if condition is None
                ),
                None,
            )
            else_cases = [
                case
                for case in normal_cases
                if else_index is not None
                and question.cases[case].branches == {else_index}
            ]
            minimal_else_cases = [
                case
                for case in else_cases
                if not any(
                    set(other.kept_indices) < set(case.kept_indices)
                    for other in else_cases
                )
            ]
            if minimal_else_cases:
                findings.append(
                    {
                        "severity": "low",
                        "code": "MINIMAL_FALLBACK_SELECTIONS",
                        "kind": "heuristic",
                        "line_id": question.line_id,
                        "message": (
                            f"{len(minimal_else_cases)} irreducible normal "
                            "selection(s) use the catch-all response; review "
                            "whether each is an intentional fragment or an "
                            "unsupported meaning."
                        ),
                        "examples": [
                            (
                                f"{self._case_label(question, case)}: "
                                f"“{self._case_text(question.phrases, case)}”"
                            )
                            for case in minimal_else_cases[:8]
                        ],
                    }
                )
            recovery_fallbacks = [
                case.delivery
                for case, result in question.cases.items()
                if case.delivery in {"pity", "sponsor"}
                and else_index is not None
                and result.branches == {else_index}
            ]
            if recovery_fallbacks:
                findings.append(
                    {
                        "severity": "medium",
                        "code": "RECOVERY_FALLS_THROUGH",
                        "kind": "heuristic",
                        "line_id": question.line_id,
                        "message": (
                            "Reachable recovery delivery uses the generic "
                            "catch-all response: "
                            + ", ".join(sorted(recovery_fallbacks))
                            + "."
                        ),
                    }
                )
            if normal_cases and len(else_cases) / len(normal_cases) >= 0.5:
                findings.append(
                    {
                        "severity": "medium",
                        "code": "FALLBACK_DOMINATES",
                        "kind": "heuristic",
                        "line_id": question.line_id,
                        "message": (
                            f"{len(else_cases)}/{len(normal_cases)} "
                            "non-silent normal selections use the catch-all "
                            "response."
                        ),
                    }
                )

            if (
                full in question.cases
                and else_index is not None
                and question.cases[full].branches == {else_index}
            ):
                findings.append(
                    {
                        "severity": "high",
                        "code": "DEFAULT_FALLS_THROUGH",
                        "kind": "heuristic",
                        "line_id": question.line_id,
                        "message": (
                            "The UI's default all-kept sentence reaches the "
                            "catch-all response."
                        ),
                    }
                )

            referenced_deliveries = {
                match.group(2)
                for condition, _body, _line in question.response_branches
                if condition is not None
                for match in re.finditer(
                    r"\bdelivery\(\s*(['\"])([^'\"]+)\1\s*\)",
                    condition,
                )
            }
            for delivery in sorted(
                referenced_deliveries - question.available_deliveries
            ):
                findings.append(
                    {
                        "severity": "high",
                        "code": "UNREACHABLE_DELIVERY",
                        "kind": "exact",
                        "line_id": question.line_id,
                        "message": (
                            f"The response for delivery(\"{delivery}\") is "
                            "unreachable from every incoming state."
                        ),
                    }
                )

            if_audit = self.if_audits.get(
                (str(question.source_path), question.response_if_line)
            )
            if if_audit is not None:
                for index, (
                    condition,
                    _body,
                    branch_line,
                ) in enumerate(question.response_branches):
                    if if_audit.selected_paths[index] == 0:
                        findings.append(
                            {
                                "severity": "high",
                                "code": "UNREACHABLE_RESPONSE_BRANCH",
                                "kind": "exact",
                                "line_id": question.line_id,
                                "source_line": branch_line.number,
                                "message": (
                                    "Response branch is never selected: "
                                    f"{condition or 'else'}"
                                ),
                            }
                        )
                    elif (
                        condition is not None
                        and if_audit.independently_true_paths[index] > 0
                        and if_audit.selected_paths[index] == 0
                    ):
                        findings.append(
                            {
                                "severity": "high",
                                "code": "FULLY_SHADOWED_BRANCH",
                                "kind": "exact",
                                "line_id": question.line_id,
                                "source_line": branch_line.number,
                                "message": (
                                    "Condition can be true but an earlier "
                                    "branch always wins."
                                ),
                            }
                        )
                if if_audit.overlap_paths:
                    unique_case_count = len(if_audit.overlap_cases)
                    unique_case_summary = (
                        f"{unique_case_count} unique selection(s), "
                        if unique_case_count
                        else ""
                    )
                    findings.append(
                        {
                            "severity": "low",
                            "code": "OVERLAPPING_CONDITIONS",
                            "kind": "heuristic",
                            "line_id": question.line_id,
                            "message": (
                                f"{unique_case_summary}"
                                f"{if_audit.overlap_paths} raw history path(s) "
                                "make multiple response conditions true; first "
                                "match wins."
                            ),
                        }
                    )

            cliffs = self._score_cliffs(question)
            if cliffs:
                findings.append(
                    {
                        "severity": "medium",
                        "code": "ONE_TOGGLE_SCORE_CLIFF",
                        "kind": "heuristic",
                        "line_id": question.line_id,
                        "message": (
                            f"{len(cliffs)} adjacent selection pair(s) change "
                            "the success effect by at least 4."
                        ),
                        "examples": cliffs[:3],
                    }
                )

        recovery_referenced = any(
            re.search(
                r"""\bdelivery\(\s*(['"])(?:pity|sponsor)\1\s*\)""",
                condition,
            )
            is not None
            for question in self.questions.values()
            for condition, _body, _line in question.response_branches
            if condition is not None
        )
        effective_zero_reached = any(
            0 in question.input_budgets
            for question in self.questions.values()
        )
        if (
            recovery_referenced
            and self.questions
            and not effective_zero_reached
        ):
            findings.append(
                {
                    "severity": "medium",
                    "code": "BUDGET_NEVER_DEPLETES",
                    "kind": "heuristic",
                    "message": (
                        "No phrase prompt is reached at effective $0; recovery "
                        "remains voluntarily available, but budget pressure "
                        "never forces it."
                    ),
                }
            )

        findings.extend(self._outcome_findings())
        return findings

    def _score_cliffs(self, question: QuestionAudit) -> list[str]:
        normal = {
            case: result
            for case, result in question.cases.items()
            if case.delivery == "normal"
        }
        cliffs: list[tuple[int, str]] = []
        ordered_cases = list(normal)
        for first_index, first in enumerate(ordered_cases):
            first_result = normal[first]
            for second in ordered_cases[first_index + 1 :]:
                second_result = normal[second]
                if len(set(first.kept_indices) ^ set(second.kept_indices)) != 1:
                    continue
                first_deltas = self._case_authored_success_deltas(
                    question,
                    first_result,
                )
                second_deltas = self._case_authored_success_deltas(
                    question,
                    second_result,
                )
                if len(first_deltas) != 1 or len(second_deltas) != 1:
                    continue
                difference = abs(next(iter(first_deltas)) - next(iter(second_deltas)))
                if difference < 4:
                    continue
                cliffs.append(
                    (
                        difference,
                        f"{self._case_label(question, first)} -> "
                        f"{self._case_label(question, second)} "
                        f"(success effect differs by {difference:g})",
                    )
                )
        return [
            description
            for _difference, description in sorted(
                cliffs,
                key=lambda item: (-item[0], item[1]),
            )
        ]

    def _case_authored_success_deltas(
        self,
        question: QuestionAudit,
        result: CaseResult,
    ) -> set[float]:
        stat = f"{self.score_owner}.success"
        deltas: set[float] = set()
        for branch_index in result.branches:
            _condition, body, _line = question.response_branches[branch_index]
            deltas.update(self._authored_stat_deltas(body, stat))
        return deltas

    def _authored_stat_deltas(
        self,
        statements: Sequence[dict],
        stat: str,
    ) -> set[float]:
        totals: set[float] = {0.0}
        position = 0
        while position < len(statements):
            statement = statements[position]
            kind = statement["kind"]
            changes: set[float] = {0.0}
            if kind == "set" and statement["stat"] == stat:
                value = _literal(statement["value"])
                if statement["operator"] == "+=":
                    changes = {float(value)}
                elif statement["operator"] == "-=":
                    changes = {-float(value)}
                else:
                    # An assignment is not a state-independent delta.
                    return set()
            elif kind == "if":
                changes = set()
                has_else = False
                for condition, body, _line in statement["branches"]:
                    has_else = has_else or condition is None
                    changes.update(self._authored_stat_deltas(body, stat))
                if not has_else:
                    changes.add(0.0)
            elif kind == "flag_check":
                changes = self._authored_stat_deltas(
                    statement["body"],
                    stat,
                ) | {0.0}
            elif kind == "choice":
                choice_bodies = []
                while (
                    position < len(statements)
                    and statements[position]["kind"] == "choice"
                ):
                    choice_bodies.append(statements[position]["body"])
                    position += 1
                changes = set().union(
                    *(
                        self._authored_stat_deltas(body, stat)
                        for body in choice_bodies
                    )
                )
                position -= 1
            totals = {
                previous + change
                for previous in totals
                for change in changes
            }
            position += 1
        return totals

    def _authored_actions(self, statements: Sequence[dict]) -> list[str]:
        actions: list[str] = []
        for statement in statements:
            kind = statement["kind"]
            if kind == "set":
                actions.append(
                    f"{statement['stat']} {statement['operator']} "
                    f"{statement['value']}"
                )
            elif kind == "flag_set":
                actions.append(
                    f"SET {statement['flag']} = "
                    f"{json.dumps(statement['value'], ensure_ascii=False)}"
                )
            elif kind == "if":
                nested = {
                    action
                    for _condition, body, _line in statement["branches"]
                    for action in self._authored_actions(body)
                }
                actions.extend(f"maybe {action}" for action in sorted(nested))
            elif kind == "flag_check":
                actions.extend(
                    f"maybe {action}"
                    for action in self._authored_actions(statement["body"])
                )
            elif kind == "choice":
                actions.extend(
                    f"maybe {action}"
                    for action in self._authored_actions(statement["body"])
                )
        return actions

    def _outcome_findings(self) -> list[dict]:
        findings: list[dict] = []
        success_stat = f"{self.score_owner}.success"
        if success_stat not in self.allowed_stats:
            return findings
        for check in self.check_audits.values():
            values: list[object] = []
            for mechanics in check.passing_states:
                stats = dict(mechanics[1])
                values.append(stats[success_stat])
            if not values:
                continue
            lowered = check.branch.lower()
            if "got_the_job" in lowered and "not" not in lowered:
                low_values = [value for value in values if value <= 3]
                if low_values:
                    findings.append(
                        {
                            "severity": "medium",
                            "code": "POSITIVE_OUTCOME_LOW_SUCCESS",
                            "kind": "heuristic",
                            "source_line": check.source_line,
                            "message": (
                                f"Outcome `{check.branch}` is reachable with "
                                f"{success_stat} as low as {min(low_values)}."
                            ),
                        }
                    )
            if (
                "did_not_get_the_job" in lowered
                or "didnt_get_the_job" in lowered
            ):
                high_values = [value for value in values if value >= 7]
                if high_values:
                    findings.append(
                        {
                            "severity": "medium",
                            "code": "NEGATIVE_OUTCOME_HIGH_SUCCESS",
                            "kind": "heuristic",
                            "source_line": check.source_line,
                            "message": (
                                f"Outcome `{check.branch}` is reachable with "
                                f"{success_stat} as high as {max(high_values)}."
                            ),
                        }
                    )
        return findings

    def _question_to_dict(self, question: QuestionAudit) -> dict:
        branches = []
        if question.response_branches:
            for index, (condition, body, branch_line) in enumerate(
                question.response_branches
            ):
                cases = [
                    case
                    for case, result in question.cases.items()
                    if index in result.branches
                ]
                branches.append(
                    {
                        "index": index,
                        "source_line": branch_line.number,
                        "condition": condition or "else",
                        "response": self._first_dialogue(body),
                        "unique_cases": len(cases),
                        "raw_paths": sum(
                            question.cases[case].paths for case in cases
                        ),
                    }
                )
        return {
            "line_id": question.line_id,
            "source": self._display_path(question.source_path),
            "source_line": question.source_line,
            "speaker": question.speaker,
            "phrases": [
                {
                    "index": index,
                    "id": phrase["id"] or f"phrase_{index + 1}",
                    "text": phrase["text"],
                    "cost": phrase["cost"],
                }
                for index, phrase in enumerate(question.phrases)
            ],
            "full_cost": question.full_cost,
            "input_paths": question.input_paths,
            "input_budget": self._value_range(question.input_budgets),
            "available_deliveries": sorted(question.available_deliveries),
            "response_if_line": question.response_if_line,
            "unconditional_response": question.unconditional_response,
            "branches": branches,
            "cases": [
                {
                    "delivery": case.delivery,
                    "kept": [
                        question.phrases[index]["id"] or f"phrase_{index + 1}"
                        for index in case.kept_indices
                    ],
                    "text": self._case_text(question.phrases, case),
                    "cost": case.cost,
                    "branches": sorted(result.branches),
                    "authored_actions": sorted(
                        {
                            action
                            for branch_index in result.branches
                            for action in self._authored_actions(
                                question.response_branches[branch_index][1]
                            )
                        }
                    ),
                    "effects": sorted(result.effects),
                    "raw_paths": result.paths,
                }
                for case, result in sorted(
                    question.cases.items(),
                    key=lambda item: (
                        item[0].delivery,
                        len(item[0].kept_indices),
                        item[0].kept_indices,
                    ),
                )
            ],
            "post_states": [
                self._mechanical_state_to_dict(key, reach)
                for key, reach in sorted(
                    question.post_states.items(),
                    key=lambda item: repr(item[0]),
                )
            ],
        }

    def _check_to_dict(self, check: CheckAudit) -> dict:
        score_stat = f"{self.score_owner}.success"
        success_values = [
            dict(mechanics[1]).get(score_stat)
            for mechanics in check.passing_states
            if score_stat in dict(mechanics[1])
        ]
        return {
            "source": self._display_path(check.source_path),
            "source_line": check.source_line,
            "flag": check.name,
            "operator": check.operator,
            "expected": check.expected,
            "branch": check.branch,
            "pass_paths": check.pass_paths,
            "fail_paths": check.fail_paths,
            "success_range": self._value_range(success_values),
            "passing_states": [
                self._mechanical_state_to_dict(key, reach)
                for key, reach in sorted(
                    check.passing_states.items(),
                    key=lambda item: repr(item[0]),
                )
            ],
        }

    def _mechanical_state_to_dict(
        self,
        mechanics: tuple[object, ...],
        reach: Reach,
    ) -> dict:
        budget, stats, flags, halted, truncated_at = mechanics
        return {
            "budget": budget,
            "stats": dict(stats),
            "flags": dict(flags),
            "halted": halted,
            "truncated_at": truncated_at or None,
            "raw_paths": reach.paths,
            "example": list(reach.example),
        }

    def _first_dialogue(self, statements: Sequence[dict]) -> str:
        for statement in statements:
            if statement["kind"] == "dialogue":
                if "text" in statement:
                    return statement["text"]
                return "[phrase-cut response]"
            if statement["kind"] in {"if", "flag_check", "choice"}:
                bodies = (
                    [body for _condition, body, _line in statement["branches"]]
                    if statement["kind"] == "if"
                    else [statement["body"]]
                )
                for body in bodies:
                    response = self._first_dialogue(body)
                    if response:
                        return response
        return ""

    def _display_path(self, path: Path) -> str:
        try:
            return str(path.resolve().relative_to(self.source_root.resolve()))
        except ValueError:
            return str(path)

    @staticmethod
    def _value_range(values: Iterable[object]) -> dict | None:
        materialized = list(values)
        if not materialized:
            return None
        return {"min": min(materialized), "max": max(materialized)}


def _episode_settings(episode_dir: Path) -> tuple[int, str]:
    resource_path = episode_dir / "episode.tres"
    try:
        text = resource_path.read_text(encoding="utf-8")
    except OSError as exc:
        raise AuditError(f"cannot read {resource_path}: {exc}") from exc
    budget_match = re.search(r"(?m)^word_budget\s*=\s*(\d+)\s*$", text)
    owner_match = re.search(
        r'(?m)^score_owner\s*=\s*&"([A-Za-z_][A-Za-z0-9_]*)"\s*$',
        text,
    )
    return (
        int(budget_match.group(1)) if budget_match else 0,
        owner_match.group(1) if owner_match else "",
    )


def audit_episode(
    episode_id: str,
    *,
    expected_phrase_lines: int | None = None,
    initial_budget_override: int | None = None,
    max_loop_visits: int = DEFAULT_MAX_LOOP_VISITS,
    vary_flags: Sequence[str] = (),
    episodes_dir: Path = EPISODES_DIR,
) -> dict:
    allowed_stats = load_allowed_stats()
    flag_definitions = load_flag_definitions()
    varied_flag_names = tuple(dict.fromkeys(vary_flags))
    unknown_flags = [
        name
        for name in varied_flag_names
        if name not in flag_definitions
    ]
    if unknown_flags:
        raise AuditError(
            "unknown --vary-flag value(s): "
            + ", ".join(unknown_flags)
        )
    initial_flag_variants = [
        dict(zip(varied_flag_names, values))
        for values in product(
            *(
                flag_definitions[name].values
                for name in varied_flag_names
            )
        )
    ] if varied_flag_names else [{}]
    episode_sources = discover_sources([episode_id], episodes_dir)[0]
    statements: list[dict] = []
    parsers: list[ScriptParser] = []
    for source_path in episode_sources.source_paths:
        parser = ScriptParser(
            source_path,
            allowed_stats,
            flag_definitions,
        )
        statements.extend(parser.parse(validate_flow=False))
        parsers.append(parser)
    parsers[0]._validate_flow(statements)
    configured_budget, score_owner = _episode_settings(
        episode_sources.episode_dir
    )
    budget = (
        configured_budget
        if initial_budget_override is None
        else initial_budget_override
    )
    auditor = EpisodeAuditor(
        episode_id,
        statements,
        source_root=ROOT,
        allowed_stats=allowed_stats,
        flag_defaults={
            name: definition.default
            for name, definition in flag_definitions.items()
        },
        initial_flag_variants=initial_flag_variants,
        initial_budget=budget,
        score_owner=score_owner,
        expected_phrase_lines=expected_phrase_lines,
        max_loop_visits=max_loop_visits,
    )
    return auditor.run()


def _format_range(value_range: dict | None, prefix: str = "") -> str:
    if value_range is None:
        return "n/a"
    if value_range["min"] == value_range["max"]:
        return f"{prefix}{value_range['min']}"
    return f"{prefix}{value_range['min']}–{prefix}{value_range['max']}"


def _format_markdown(report: dict, *, include_states: bool) -> str:
    summary = report["summary"]
    pressure = report["budget_pressure"]
    control_flow = report["control_flow"]
    if control_flow["jump_targets"]:
        visit_word = (
            "time"
            if control_flow["max_loop_visits"] == 1
            else "times"
        )
        scope_note = (
            "> Exact within the configured goto bound. Retry labels are "
            f"visited at most {control_flow['max_loop_visits']} {visit_word} per "
            "enumerated history; histories still looping there are excluded "
            "from terminal-state findings. “Raw paths” are combinatorial case "
            "counts, not estimates of player behavior. HEURISTIC findings are "
            "prompts for a writer to review."
        )
    else:
        scope_note = (
            "> Exact for this loop-free script. “Raw paths” are combinatorial "
            "case counts, not estimates of player behavior. HEURISTIC findings "
            "are prompts for a writer to review."
        )
    lines = [
        f"# Dialogue branch audit: `{report['episode']}`",
        "",
        scope_note,
        "",
        "## Summary",
        "",
        f"- Authored phrase prompts: {summary['phrase_lines']}",
        (
            "- Reachable phrase prompts: "
            f"{summary['reachable_phrase_lines']}"
        ),
        (
            "- Initial story-flag variants: "
            f"{len(report['assumptions']['initial_flag_variants'])}"
        ),
        f"- Enumerated raw paths: {summary['raw_paths']:,}",
        (
            "- Loop-bound histories excluded: "
            f"{summary['truncated_raw_paths']:,}"
        ),
        f"- Distinct final mechanical states: {summary['final_mechanical_states']}",
        (
            "- Final budget: "
            f"{_format_range(summary['final_budget'], '$')}"
        ),
        (
            "- Reachable delivery modes: "
            + ", ".join(summary["reachable_deliveries"])
        ),
        (
            "- Implemented all-kept cost: "
            f"${pressure['implemented_full_cost']} "
            f"(budget headroom: ${pressure['headroom_over_all_full']})"
        ),
        (
            "- Cheapest non-silent choice on every implemented prompt: "
            f"${pressure['implemented_cheapest_non_silent_total']} total"
        ),
        (
            "- Largest single complete answer: "
            f"${pressure['largest_single_full_cost']} "
            "(budget headroom: "
            f"${pressure['headroom_over_largest_single_full']})"
        ),
        (
            "- One complete answer plus the cheapest non-silent choice on "
            "every other prompt: "
            f"${pressure['one_full_plus_cheapest_non_silent_minimum']} "
            "minimum (budget headroom: "
            f"${pressure['headroom_over_one_full_plus_cheapest_non_silent']})"
        ),
        "",
    ]
    if control_flow["jump_targets"]:
        lines.extend(
            [
                "## Control-flow bounds",
                "",
                (
                    "- Traversed goto targets: "
                    + ", ".join(
                        f"`{target}`"
                        for target in control_flow["jump_targets"]
                    )
                ),
            ]
        )
        if control_flow["bounded_targets"]:
            for bounded in control_flow["bounded_targets"]:
                lines.append(
                    f"- `{bounded['target']}` reached the visit bound on "
                    f"{bounded['raw_paths']:,} raw history path(s)."
                )
        else:
            lines.append("- No history reached the configured visit bound.")
        lines.extend(["", "## Findings", ""])
    else:
        lines.extend(["## Findings", ""])
    if not report["findings"]:
        lines.append("- No exact or heuristic findings.")
    else:
        for finding in report["findings"]:
            location = (
                f" `{finding['line_id']}`"
                if finding.get("line_id")
                else ""
            )
            lines.append(
                f"- **{finding['severity'].upper()} "
                f"{finding['kind'].upper()} · {finding['code']}**"
                f"{location}: {finding['message']}"
            )
            for example in finding.get("examples", []):
                lines.append(f"  - {example}")

    for question in report["questions"]:
        lines.extend(
            [
                "",
                f"## `{question['line_id']}` — source line "
                f"{question['source_line']}",
                "",
                (
                    "Phrases: "
                    + " · ".join(
                        f"`{phrase['id']}` “{phrase['text']}” (${phrase['cost']})"
                        for phrase in question["phrases"]
                    )
                ),
                "",
                (
                    f"Full cost: ${question['full_cost']}. Incoming budget: "
                    f"{_format_range(question['input_budget'], '$')}. "
                    "Reachable deliveries: "
                    + ", ".join(question["available_deliveries"])
                    + "."
                ),
                "",
                (
                    "Unconditional response: "
                    f"“{question['unconditional_response']}”"
                    if question["unconditional_response"] is not None
                    else "Conditional response branches:"
                ),
                "",
                "| Branch | Condition | Unique cases | Raw paths | Response |",
                "|---:|---|---:|---:|---|",
            ]
        )
        for branch in question["branches"]:
            response = branch["response"].replace("|", "\\|")
            lines.append(
                f"| {branch['index']} | `{branch['condition']}` | "
                f"{branch['unique_cases']} | {branch['raw_paths']:,} | "
                f"{response} |"
            )
        lines.extend(
            [
                "",
                "<details>",
                f"<summary>All {len(question['cases'])} reachable selections</summary>",
                "",
                "| Delivery | Kept | Cost | Branch | Authored actions | Text |",
                "|---|---|---:|---:|---|---|",
            ]
        )
        for case in question["cases"]:
            kept = ", ".join(case["kept"]) or "—"
            branches = ", ".join(str(value) for value in case["branches"]) or "—"
            actions = "; ".join(case["authored_actions"]).replace("|", "\\|")
            text = case["text"].replace("|", "\\|")
            lines.append(
                f"| {case['delivery']} | {kept} | ${case['cost']} | "
                f"{branches} | {actions or '—'} | {text} |"
            )
        lines.extend(["", "</details>"])
        if include_states:
            lines.extend(
                [
                    "",
                    "<details>",
                    (
                        f"<summary>All {len(question['post_states'])} distinct "
                        "mechanical states after this response</summary>"
                    ),
                    "",
                    "| Budget | Stats | Flags | Raw paths | Example |",
                    "|---:|---|---|---:|---|",
                ]
            )
            for state in question["post_states"]:
                stats = ", ".join(
                    f"{name}={value}" for name, value in state["stats"].items()
                )
                flags = ", ".join(
                    f"{name}={value}" for name, value in state["flags"].items()
                )
                example = " → ".join(state["example"]).replace("|", "\\|")
                lines.append(
                    f"| ${state['budget']} | {stats} | {flags} | "
                    f"{state['raw_paths']:,} | {example} |"
                )
            lines.extend(["", "</details>"])

    lines.extend(["", "## Outcome checks", ""])
    if not report["checks"]:
        lines.append("- None.")
    else:
        lines.extend(
            [
                "| Branch | Check | Pass paths | Fail paths | Success range |",
                "|---|---|---:|---:|---|",
            ]
        )
        for check in report["checks"]:
            lines.append(
                f"| `{check['branch']}` | `{check['flag']} "
                f"{check['operator']} {json.dumps(check['expected'])}` | "
                f"{check['pass_paths']:,} | {check['fail_paths']:,} | "
                f"{_format_range(check['success_range'])} |"
            )

    if include_states:
        lines.extend(
            [
                "",
                "<details>",
                (
                    f"<summary>All {len(report['final_states'])} distinct "
                    "final mechanical states</summary>"
                ),
                "",
                "```json",
                json.dumps(report["final_states"], ensure_ascii=False, indent=2),
                "```",
                "",
                "</details>",
            ]
        )
    return "\n".join(lines) + "\n"


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Enumerate phrase-cut choices, response branches, and resulting "
            "story states for one episode, with bounded traversal of retry loops."
        )
    )
    parser.add_argument("episode", help="episode id, such as dad")
    parser.add_argument(
        "--format",
        choices=("markdown", "json"),
        default="markdown",
        help="report format (default: markdown)",
    )
    parser.add_argument(
        "--include-states",
        action="store_true",
        help="include every compressed post-question and final state in Markdown",
    )
    parser.add_argument(
        "--expect-phrase-lines",
        type=int,
        metavar="COUNT",
        help="flag a content-completeness mismatch against an expected prompt count",
    )
    parser.add_argument(
        "--budget",
        type=int,
        metavar="AMOUNT",
        help=(
            "audit a hypothetical starting budget without editing episode.tres"
        ),
    )
    parser.add_argument(
        "--max-loop-visits",
        type=int,
        default=DEFAULT_MAX_LOOP_VISITS,
        metavar="COUNT",
        help=(
            "maximum visits to one goto label along an enumerated history "
            f"(default: {DEFAULT_MAX_LOOP_VISITS})"
        ),
    )
    parser.add_argument(
        "--vary-flag",
        action="append",
        default=[],
        metavar="FLAG",
        help=(
            "enumerate every declared value of an incoming story flag; "
            "repeat for multiple flags"
        ),
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_argument_parser().parse_args(argv)
    try:
        report = audit_episode(
            args.episode,
            expected_phrase_lines=args.expect_phrase_lines,
            initial_budget_override=args.budget,
            max_loop_visits=args.max_loop_visits,
            vary_flags=args.vary_flag,
        )
    except (AuditError, CompileError) as exc:
        print(f"dialogue audit error: {exc}", file=sys.stderr)
        return 1
    if args.format == "json":
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(
            _format_markdown(
                report,
                include_states=args.include_states,
            ),
            end="",
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
