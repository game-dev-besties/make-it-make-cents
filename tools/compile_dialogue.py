#!/usr/bin/env python3
"""Compile writer-authored episode scripts into Dialogic timelines.

The source for an episode lives beside its Godot resources:

    content/episodes/<episode-id>/script.md

This compiler writes `dialogue.dtl` and `phrases.json` into the same folder.
It deliberately uses only the Python standard library so a normal Python 3
installation is enough.
"""

from __future__ import annotations

import argparse
import ast
from dataclasses import dataclass
import json
from pathlib import Path
import re
import sys
from typing import Iterable, Sequence


ROOT = Path(__file__).resolve().parents[1]
EPISODES_DIR = ROOT / "content" / "episodes"
STATS_PATH = ROOT / "story" / "stats.json"
SOURCE_NAME = "script.md"
TIMELINE_NAME = "dialogue.dtl"
PHRASES_NAME = "phrases.json"

IDENTIFIER_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
LABEL_RE = re.compile(r"^##\s+([A-Za-z_][A-Za-z0-9_]*)\s*$")
JUMP_RE = re.compile(r"^->\s+([A-Za-z_][A-Za-z0-9_]*|end)\s*$")
CHOICE_RE = re.compile(r'^-\s+(.+?)\s*$')
DIALOGUE_RE = re.compile(
    r"^(?P<speaker>[A-Za-z_][A-Za-z0-9_-]*)"
    r"(?:\s*\((?P<expression>[A-Za-z_][A-Za-z0-9_-]*)\))?"
    r"\s*:\s*(?P<text>.*)$"
)
SET_RE = re.compile(
    r"^(?P<stat>[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*)"
    r"\s*(?P<operator>\+=|-=|=)\s*(?P<value>.+?)\s*$"
)
IF_RE = re.compile(r"^if\s+(.+):\s*$")
ELIF_RE = re.compile(r"^elif\s+(.+):\s*$")
ELSE_RE = re.compile(r"^else:\s*$")
VALUE_RE = re.compile(
    r"""^(?:-?\d+(?:\.\d+)?|true|false|null|"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')$"""
)
ASSET_ID_RE = re.compile(r"^[A-Za-z0-9_./:-]+$")
OUTSIDE_PHRASE_RE = re.compile(r"^[\s,.;:!?…—-]*$")

DELIVERY_MODES = frozenset({"normal", "silence", "pity", "sponsor"})
CONDITION_FUNCTIONS = frozenset({"kept", "removed", "kept_count", "delivery"})


class CompileError(Exception):
    """An author-facing compiler error with a source location."""

    def __init__(self, path: Path, line: int, message: str):
        self.path = path
        self.line = line
        self.message = message
        super().__init__(f"{path}:{line}: error: {message}")


@dataclass(frozen=True)
class SourceLine:
    path: Path
    number: int
    indent: int
    text: str


@dataclass(frozen=True)
class Artifact:
    episode_id: str
    timeline: str
    phrases: str
    phrase_line_count: int


def _fail(line: SourceLine, message: str) -> None:
    raise CompileError(line.path, line.number, message)


def _tokenize(path: Path) -> list[SourceLine]:
    try:
        raw_text = path.read_text(encoding="utf-8")
    except OSError as exc:
        raise CompileError(path, 1, f"cannot read source: {exc}") from exc

    lines: list[SourceLine] = []
    for number, raw in enumerate(raw_text.splitlines(), start=1):
        if "\t" in raw[: len(raw) - len(raw.lstrip())]:
            raise CompileError(path, number, "use spaces for indentation, not tabs")
        content = raw.lstrip(" ")
        if not content.strip():
            continue
        stripped = content.rstrip()
        if stripped.startswith("//") or stripped == "#" or stripped.startswith("# "):
            continue
        lines.append(
            SourceLine(
                path=path,
                number=number,
                indent=len(raw) - len(content),
                text=stripped,
            )
        )
    return lines


class ScriptParser:
    def __init__(self, path: Path, allowed_stats: frozenset[str]):
        self.path = path
        self.lines = _tokenize(path)
        self.allowed_stats = allowed_stats
        self.position = 0

    def parse(self) -> list[dict]:
        if not self.lines:
            raise CompileError(self.path, 1, "script is empty")
        if self.lines[0].indent != 0:
            _fail(self.lines[0], "the first statement must not be indented")
        statements = self._parse_block(0)
        if self.position != len(self.lines):
            leftover = self.lines[self.position]
            if ELIF_RE.fullmatch(leftover.text) or ELSE_RE.fullmatch(leftover.text):
                _fail(leftover, "`elif`/`else` has no matching `if`")
            _fail(leftover, "unexpected indentation")
        self._validate_flow(statements)
        return statements

    def _parse_block(self, indent: int) -> list[dict]:
        statements: list[dict] = []
        while self.position < len(self.lines):
            line = self.lines[self.position]
            if line.indent < indent:
                break
            if line.indent > indent:
                _fail(
                    line,
                    f"unexpected indentation; expected {indent} spaces at this level",
                )
            if ELIF_RE.fullmatch(line.text) or ELSE_RE.fullmatch(line.text):
                break
            statements.append(self._parse_statement(indent))
        return statements

    def _parse_body(self, parent: SourceLine) -> list[dict]:
        if self.position >= len(self.lines):
            _fail(parent, "expected an indented body")
        next_line = self.lines[self.position]
        if next_line.indent <= parent.indent:
            _fail(parent, "expected an indented body")
        body = self._parse_block(next_line.indent)
        if not body:
            _fail(parent, "body cannot be empty")
        return body

    def _parse_statement(self, indent: int) -> dict:
        line = self.lines[self.position]
        text = line.text

        label_match = LABEL_RE.fullmatch(text)
        if label_match:
            self.position += 1
            return {"kind": "label", "name": label_match.group(1), "line": line}
        if text.startswith("##"):
            _fail(line, "invalid label; use `## label_name`")

        jump_match = JUMP_RE.fullmatch(text)
        if jump_match:
            self.position += 1
            return {"kind": "jump", "target": jump_match.group(1), "line": line}
        if text.startswith("->"):
            _fail(line, "invalid jump; use `-> label_name` or `-> end`")

        if text.startswith("@"):
            self.position += 1
            return self._parse_directive(line)

        choice_match = CHOICE_RE.fullmatch(text)
        if choice_match:
            choice_text = choice_match.group(1).strip()
            if (
                len(choice_text) >= 2
                and choice_text[0] == choice_text[-1]
                and choice_text[0] in "\"'"
            ):
                choice_text = choice_text[1:-1]
            if not choice_text:
                _fail(line, "choice text cannot be empty")
            self.position += 1
            body = self._parse_body(line)
            return {
                "kind": "choice",
                "text": choice_text,
                "body": body,
                "line": line,
            }

        if_match = IF_RE.fullmatch(text)
        if if_match:
            branches: list[tuple[str | None, list[dict], SourceLine]] = []
            condition = if_match.group(1).strip()
            self._validate_condition(condition, line)
            self.position += 1
            branches.append((condition, self._parse_body(line), line))
            saw_else = False
            while self.position < len(self.lines):
                branch_line = self.lines[self.position]
                if branch_line.indent != indent:
                    break
                elif_match = ELIF_RE.fullmatch(branch_line.text)
                if elif_match:
                    if saw_else:
                        _fail(branch_line, "`elif` cannot follow `else`")
                    condition = elif_match.group(1).strip()
                    self._validate_condition(condition, branch_line)
                    self.position += 1
                    branches.append(
                        (condition, self._parse_body(branch_line), branch_line)
                    )
                    continue
                if ELSE_RE.fullmatch(branch_line.text):
                    if saw_else:
                        _fail(branch_line, "condition already has an `else` branch")
                    saw_else = True
                    self.position += 1
                    branches.append((None, self._parse_body(branch_line), branch_line))
                    continue
                break
            return {"kind": "if", "branches": branches, "line": line}
        if text.startswith("if ") or text.startswith("elif") or text.startswith("else"):
            _fail(line, "malformed condition; conditions must end with `:`")

        set_match = SET_RE.fullmatch(text)
        if set_match:
            stat = set_match.group("stat")
            if stat not in self.allowed_stats:
                _fail(line, f"unknown stat `{stat}`; add it to story/stats.json first")
            value = set_match.group("value").strip()
            if not VALUE_RE.fullmatch(value):
                _fail(
                    line,
                    "stat values must be a number, true/false/null, or a quoted string",
                )
            self.position += 1
            return {
                "kind": "set",
                "stat": stat,
                "operator": set_match.group("operator"),
                "value": value,
                "line": line,
            }

        dialogue_match = DIALOGUE_RE.fullmatch(text)
        if dialogue_match:
            spoken_text = dialogue_match.group("text")
            if not spoken_text:
                _fail(
                    line,
                    "dialogue cannot be empty; put deletable phrases on the same line",
                )
            self.position += 1
            statement = {
                "kind": "dialogue",
                "speaker": dialogue_match.group("speaker"),
                "expression": dialogue_match.group("expression") or "",
                "line": line,
            }
            if "[" in spoken_text or "]" in spoken_text:
                statement["phrases"] = _parse_phrases(spoken_text, line)
            else:
                statement["text"] = spoken_text
            return statement

        if ":" in text:
            _fail(
                line,
                "invalid dialogue; use `speaker (expression): text`",
            )
        if re.match(r"^[A-Za-z_][A-Za-z0-9_.]*\s*[+\-]?=", text):
            _fail(line, "invalid stat change; use a declared `group.stat` name")

        self.position += 1
        return {"kind": "narration", "text": text, "line": line}

    def _parse_directive(self, line: SourceLine) -> dict:
        parts = line.text[1:].split(None, 1)
        command = parts[0]
        argument = parts[1].strip() if len(parts) == 2 else ""
        aliases = {"bg": "background", "presentation": "cue"}
        command = aliases.get(command, command)

        if command == "wait":
            try:
                seconds = float(argument)
            except ValueError:
                _fail(line, "`@wait` needs a nonnegative number of seconds")
            if seconds < 0:
                _fail(line, "`@wait` cannot be negative")
            return {"kind": "wait", "seconds": seconds, "line": line}

        if command == "cue":
            if not IDENTIFIER_RE.fullmatch(argument):
                _fail(line, "`@cue` needs an identifier such as `dad_enters`")
            return {"kind": "cue", "id": argument, "line": line}

        if command in {"background", "music", "sfx"}:
            if not argument:
                _fail(line, f"`@{command}` needs an asset id or `res://` path")
            if command == "music" and argument == "stop":
                return {"kind": command, "asset": argument, "line": line}
            if not ASSET_ID_RE.fullmatch(argument) or '"' in argument:
                _fail(line, f"invalid asset id/path for `@{command}`")
            return {"kind": command, "asset": argument, "line": line}

        _fail(
            line,
            "unknown directive; supported directives are "
            "@background, @music, @sfx, @cue, and @wait",
        )

    def _validate_condition(self, condition: str, line: SourceLine) -> None:
        python_condition = re.sub(r"\btrue\b", "True", condition)
        python_condition = re.sub(r"\bfalse\b", "False", python_condition)
        python_condition = re.sub(r"\bnull\b", "None", python_condition)
        try:
            tree = ast.parse(python_condition, mode="eval")
        except SyntaxError as exc:
            _fail(line, f"invalid condition: {exc.msg}")

        allowed_node_types = (
            ast.Expression,
            ast.BoolOp,
            ast.And,
            ast.Or,
            ast.UnaryOp,
            ast.Not,
            ast.USub,
            ast.Compare,
            ast.Eq,
            ast.NotEq,
            ast.Lt,
            ast.LtE,
            ast.Gt,
            ast.GtE,
            ast.Call,
            ast.Name,
            ast.Load,
            ast.Attribute,
            ast.Constant,
        )
        for node in ast.walk(tree):
            if not isinstance(node, allowed_node_types):
                _fail(
                    line,
                    "conditions only support comparisons, and/or/not, stats, "
                    "kept/removed/kept_count, and delivery",
                )
            if isinstance(node, ast.Attribute):
                if not isinstance(node.value, ast.Name):
                    _fail(line, "stats must use the form `group.stat`")
                stat = f"{node.value.id}.{node.attr}"
                if stat not in self.allowed_stats:
                    _fail(
                        line,
                        f"unknown stat `{stat}`; add it to story/stats.json first",
                    )
            elif isinstance(node, ast.Call):
                if not isinstance(node.func, ast.Name):
                    _fail(line, "condition helpers cannot be chained")
                function = node.func.id
                if function not in CONDITION_FUNCTIONS:
                    _fail(line, f"unknown condition helper `{function}`")
                if node.keywords:
                    _fail(line, f"`{function}` does not accept named arguments")
                if function == "kept_count":
                    if node.args:
                        _fail(line, "`kept_count()` takes no arguments")
                else:
                    if (
                        len(node.args) != 1
                        or not isinstance(node.args[0], ast.Constant)
                        or not isinstance(node.args[0].value, str)
                    ):
                        _fail(line, f"`{function}` takes one quoted string")
                    argument = node.args[0].value
                    if function == "delivery" and argument not in DELIVERY_MODES:
                        _fail(
                            line,
                            "`delivery()` mode must be normal, silence, pity, or sponsor",
                        )
                    if function in {"kept", "removed"} and not IDENTIFIER_RE.fullmatch(
                        argument
                    ):
                        _fail(line, f"`{function}()` needs a valid phrase id")
            elif isinstance(node, ast.Name):
                if isinstance(getattr(node, "ctx", None), ast.Load):
                    parent_is_attribute_base = any(
                        isinstance(parent, ast.Attribute) and parent.value is node
                        for parent in ast.walk(tree)
                    )
                    parent_is_function = any(
                        isinstance(parent, ast.Call) and parent.func is node
                        for parent in ast.walk(tree)
                    )
                    if (
                        not parent_is_attribute_base
                        and not parent_is_function
                        and node.id not in {"True", "False", "None"}
                    ):
                        _fail(line, f"unknown name `{node.id}` in condition")

    def _validate_flow(self, statements: Sequence[dict]) -> None:
        labels: dict[str, SourceLine] = {}
        jumps: list[tuple[str, SourceLine]] = []

        def referenced_phrase_ids(condition: str) -> list[str]:
            return [
                match.group(2)
                for match in re.finditer(
                    r"\b(?:kept|removed)\(\s*(['\"])([A-Za-z_][A-Za-z0-9_]*)\1\s*\)",
                    condition,
                )
            ]

        def visit(
            items: Sequence[dict],
            latest_phrase_ids: frozenset[str] = frozenset(),
        ) -> frozenset[str]:
            current_phrase_ids = latest_phrase_ids
            position = 0
            while position < len(items):
                statement = items[position]
                kind = statement["kind"]
                line = statement["line"]
                if kind == "label":
                    current_phrase_ids = frozenset()
                    name = statement["name"]
                    if name in labels:
                        previous = labels[name]
                        _fail(
                            line,
                            f"duplicate label `{name}`; first declared on line "
                            f"{previous.number}",
                        )
                    labels[name] = line
                elif kind == "jump":
                    jumps.append((statement["target"], line))
                    current_phrase_ids = frozenset()
                elif kind == "dialogue" and "phrases" in statement:
                    current_phrase_ids = frozenset(
                        phrase["id"]
                        for phrase in statement["phrases"]
                        if phrase["id"]
                    )
                elif kind == "if":
                    branch_results: list[frozenset[str]] = []
                    has_else = False
                    for condition, body, branch_line in statement["branches"]:
                        if condition is not None:
                            for phrase_id in referenced_phrase_ids(condition):
                                if phrase_id not in current_phrase_ids:
                                    _fail(
                                        branch_line,
                                        "condition references phrase id "
                                        f"`{phrase_id}` that is not on the latest "
                                        "phrase-cut line",
                                    )
                        else:
                            has_else = True
                        branch_results.append(visit(body, current_phrase_ids))
                    if not has_else:
                        branch_results.append(current_phrase_ids)
                    current_phrase_ids = (
                        branch_results[0]
                        if branch_results
                        and all(result == branch_results[0] for result in branch_results)
                        else frozenset()
                    )
                elif kind == "choice":
                    choice_results: list[frozenset[str]] = []
                    while position < len(items) and items[position]["kind"] == "choice":
                        choice_results.append(
                            visit(items[position]["body"], current_phrase_ids)
                        )
                        position += 1
                    current_phrase_ids = (
                        choice_results[0]
                        if choice_results
                        and all(result == choice_results[0] for result in choice_results)
                        else frozenset()
                    )
                    continue
                position += 1
            return current_phrase_ids

        visit(statements)
        for target, line in jumps:
            if target != "end" and target not in labels:
                _fail(line, f"jump targets missing label `{target}`")


def _parse_phrases(text: str, line: SourceLine) -> list[dict]:
    phrases: list[dict] = []
    position = 0
    seen_ids: set[str] = set()

    while position < len(text):
        if text[position] != "[":
            next_open = text.find("[", position)
            end = len(text) if next_open < 0 else next_open
            outside = text[position:end]
            if "]" in outside:
                _fail(line, "unmatched `]` in phrase-cut dialogue")
            if "{" in outside or "}" in outside:
                _fail(
                    line,
                    "phrase annotations must immediately follow a phrase, "
                    "for example `[hello]{id=greeting, cost=1}`",
                )
            if not OUTSIDE_PHRASE_RE.fullmatch(outside):
                _fail(
                    line,
                    "all words in phrase-cut dialogue must be inside `[brackets]`",
                )
            punctuation = outside.strip()
            if punctuation:
                if not phrases:
                    _fail(line, "punctuation cannot appear before the first phrase")
                phrases[-1]["text"] += punctuation
            position = end
            continue

        close = text.find("]", position + 1)
        if close < 0:
            _fail(line, "unmatched `[` in phrase-cut dialogue")
        if text.find("[", position + 1, close) >= 0:
            _fail(line, "nested `[` is not allowed in a phrase")
        phrase_text = text[position + 1 : close].strip()
        if not phrase_text:
            _fail(line, "a deletable phrase cannot be empty")
        position = close + 1

        phrase_id: str | None = None
        cost: int | None = None
        if position < len(text) and text[position] == "{":
            annotation_end = text.find("}", position + 1)
            if annotation_end < 0:
                _fail(line, "unmatched `{` in phrase annotation")
            annotation = text[position + 1 : annotation_end].strip()
            if not annotation:
                _fail(line, "phrase annotation cannot be empty")
            seen_keys: set[str] = set()
            for item in annotation.split(","):
                pair = item.strip().split("=", 1)
                if len(pair) != 2:
                    _fail(
                        line,
                        "phrase annotations use `id=name` and/or `cost=number`",
                    )
                key, value = pair[0].strip(), pair[1].strip()
                if key in seen_keys:
                    _fail(line, f"duplicate `{key}` in phrase annotation")
                seen_keys.add(key)
                if key == "id":
                    if not IDENTIFIER_RE.fullmatch(value):
                        _fail(line, f"invalid phrase id `{value}`")
                    phrase_id = value
                elif key == "cost":
                    try:
                        cost = int(value)
                    except ValueError:
                        _fail(line, "phrase cost must be a whole number")
                    if cost < 0:
                        _fail(line, "phrase cost cannot be negative")
                else:
                    _fail(line, f"unknown phrase annotation key `{key}`")
            position = annotation_end + 1

        if phrase_id is not None:
            if phrase_id in seen_ids:
                _fail(line, f"duplicate phrase id `{phrase_id}` on this line")
            seen_ids.add(phrase_id)
        if cost is None:
            cost = len(phrase_text.split())
        phrases.append({"text": phrase_text, "cost": cost, "id": phrase_id})

    if not phrases:
        _fail(line, "phrase-cut dialogue needs at least one `[phrase]`")
    return phrases


def _asset_path(kind: str, asset: str) -> str:
    if asset.startswith("res://"):
        return asset
    if kind == "background":
        return f"res://art/backgrounds/{asset}.png"
    if kind == "music":
        return f"res://audio/music/{asset}.ogg"
    return f"res://audio/sfx/{asset}.ogg"


def _translate_condition(condition: str, allowed_stats: Iterable[str]) -> str:
    translated = condition
    for stat in sorted(allowed_stats, key=len, reverse=True):
        translated = re.sub(
            rf"\b{re.escape(stat)}\b",
            "GameStats." + stat.replace(".", "_"),
            translated,
        )
    translated = re.sub(
        r"(?<![\w.])kept_count\(\)",
        "PhraseMemory.kept_count()",
        translated,
    )
    translated = re.sub(
        r"(?<![\w.])kept\(",
        "PhraseMemory.kept(",
        translated,
    )
    translated = re.sub(
        r"(?<![\w.])removed\(",
        "PhraseMemory.removed(",
        translated,
    )
    translated = re.sub(
        r"(?<![\w.])delivery\(",
        "PhraseMemory.delivery_is(",
        translated,
    )
    return translated


def _escape_choice(text: str) -> str:
    return text.replace("\\", "\\\\").replace("|", "\\|")


class Emitter:
    def __init__(
        self,
        episode_id: str,
        source_path: Path,
        allowed_stats: frozenset[str],
    ):
        self.episode_id = episode_id
        self.source_path = source_path
        self.allowed_stats = allowed_stats
        self.timeline_lines: list[str] = []
        self.phrase_lines: dict[str, dict] = {}
        self.sequence = 0

    def build(self, statements: Sequence[dict]) -> Artifact:
        # Use the logical project path rather than an absolute filesystem path
        # so output is byte-for-byte identical on every contributor's machine.
        source_name = f"content/episodes/{self.episode_id}/{SOURCE_NAME}"
        self.timeline_lines.append(
            f"# Generated from {source_name}; edit script.md, not this file."
        )
        self._emit_statements(statements, 0)
        timeline = "\n".join(self.timeline_lines) + "\n"
        phrases = json.dumps(
            self.phrase_lines,
            ensure_ascii=False,
            indent=2,
        ) + "\n"
        return Artifact(
            episode_id=self.episode_id,
            timeline=timeline,
            phrases=phrases,
            phrase_line_count=len(self.phrase_lines),
        )

    def _emit(self, depth: int, text: str) -> None:
        self.timeline_lines.append("\t" * depth + text)

    def _emit_statements(self, statements: Sequence[dict], depth: int) -> None:
        for statement in statements:
            kind = statement["kind"]
            if kind == "label":
                self._emit(depth, f"label {statement['name']}")
            elif kind == "jump":
                target = statement["target"]
                self._emit(depth, "end_timeline" if target == "end" else f"jump {target}")
            elif kind == "set":
                stat = statement["stat"].replace(".", "_")
                self._emit(
                    depth,
                    f"set {{GameStats.{stat}}} {statement['operator']} "
                    f"{statement['value']}",
                )
            elif kind == "narration":
                self._emit(depth, statement["text"])
            elif kind == "dialogue":
                self._emit_dialogue(statement, depth)
            elif kind == "choice":
                self._emit(depth, f"- {_escape_choice(statement['text'])}")
                self._emit_statements(statement["body"], depth + 1)
            elif kind == "if":
                for index, (condition, body, _line) in enumerate(statement["branches"]):
                    if condition is None:
                        self._emit(depth, "else:")
                    else:
                        keyword = "if" if index == 0 else "elif"
                        translated = _translate_condition(
                            condition,
                            self.allowed_stats,
                        )
                        self._emit(depth, f"{keyword} {translated}:")
                    self._emit_statements(body, depth + 1)
            elif kind == "wait":
                self._emit(depth, f'[wait time="{statement["seconds"]:g}"]')
            elif kind == "cue":
                self._emit(depth, f"presentation_cue {statement['id']}")
            elif kind == "background":
                path = _asset_path(kind, statement["asset"])
                self._emit(depth, f'[background arg="{path}" fade="0.5"]')
            elif kind == "music":
                if statement["asset"] == "stop":
                    self._emit(depth, "audio music -")
                else:
                    path = _asset_path(kind, statement["asset"])
                    self._emit(
                        depth,
                        f'audio music "{path}" [fade="1" loop="true"]',
                    )
            elif kind == "sfx":
                path = _asset_path(kind, statement["asset"])
                self._emit(depth, f'audio "{path}" [loop="false"]')
            else:
                raise AssertionError(f"unsupported statement kind: {kind}")

    def _emit_dialogue(self, statement: dict, depth: int) -> None:
        speaker = statement["speaker"]
        expression = statement["expression"]
        prefix = f"{speaker} ({expression})" if expression else speaker
        phrases = statement.get("phrases")
        if phrases is None:
            self._emit(depth, f"{prefix}: {statement['text']}")
            return

        self.sequence += 1
        line_id = f"{self.episode_id}_L{self.sequence:03d}"
        segments: list[dict] = []
        for phrase in phrases:
            segment = {
                "type": "phrase",
                "text": phrase["text"],
                "cost": phrase["cost"],
            }
            if phrase["id"] is not None:
                segment["id"] = phrase["id"]
            segments.append(segment)
        self.phrase_lines[line_id] = {
            "speaker": speaker,
            "expr": expression,
            "segments": segments,
        }
        self._emit(depth, f"phrase_cut {prefix} {line_id}")


def load_allowed_stats(path: Path = STATS_PATH) -> frozenset[str]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError as exc:
        raise CompileError(path, 1, "missing stat schema") from exc
    except json.JSONDecodeError as exc:
        raise CompileError(path, exc.lineno, f"invalid JSON: {exc.msg}") from exc
    except OSError as exc:
        raise CompileError(path, 1, f"cannot read stat schema: {exc}") from exc

    raw_stats = data.get("stats") if isinstance(data, dict) else None
    if not isinstance(raw_stats, list) or not raw_stats:
        raise CompileError(path, 1, "`stats` must be a nonempty array")
    stats: set[str] = set()
    for stat in raw_stats:
        if not isinstance(stat, str) or not re.fullmatch(
            r"[A-Za-z_][A-Za-z0-9_]*\.[A-Za-z_][A-Za-z0-9_]*",
            stat,
        ):
            raise CompileError(path, 1, f"invalid stat name: {stat!r}")
        if stat in stats:
            raise CompileError(path, 1, f"duplicate stat name: {stat}")
        stats.add(stat)
    return frozenset(stats)


def compile_source(
    source_path: Path,
    episode_id: str,
    allowed_stats: frozenset[str],
) -> Artifact:
    if not IDENTIFIER_RE.fullmatch(episode_id):
        raise CompileError(source_path, 1, f"invalid episode id `{episode_id}`")
    statements = ScriptParser(source_path, allowed_stats).parse()
    return Emitter(episode_id, source_path, allowed_stats).build(statements)


def discover_sources(
    requested_ids: Sequence[str],
    episodes_dir: Path = EPISODES_DIR,
) -> list[tuple[str, Path]]:
    if requested_ids:
        sources: list[tuple[str, Path]] = []
        for episode_id in requested_ids:
            source = episodes_dir / episode_id / SOURCE_NAME
            if not source.is_file():
                raise CompileError(
                    source,
                    1,
                    f"episode `{episode_id}` has no {SOURCE_NAME}",
                )
            sources.append((episode_id, source))
        return sources

    sources = [
        (folder.name, folder / SOURCE_NAME)
        for folder in sorted(episodes_dir.iterdir(), key=lambda path: path.name)
        if folder.is_dir() and (folder / SOURCE_NAME).is_file()
    ]
    if not sources:
        raise CompileError(
            episodes_dir,
            1,
            f"no episode sources named {SOURCE_NAME} were found",
        )
    return sources


def _write_or_check(
    artifacts: Sequence[tuple[Path, Artifact]],
    check: bool,
) -> int:
    stale_paths: list[Path] = []
    for episode_dir, artifact in artifacts:
        expected = {
            episode_dir / TIMELINE_NAME: artifact.timeline,
            episode_dir / PHRASES_NAME: artifact.phrases,
        }
        for path, content in expected.items():
            if check:
                try:
                    current = path.read_text(encoding="utf-8")
                except FileNotFoundError:
                    current = ""
                if current != content:
                    stale_paths.append(path)
            else:
                path.write_text(content, encoding="utf-8", newline="\n")

    if stale_paths:
        for path in stale_paths:
            print(
                f"{path}:1: error: generated file is stale; "
                "run `python3 tools/compile_dialogue.py`",
                file=sys.stderr,
            )
        return 1
    return 0


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Compile episode script.md files into Dialogic content.",
    )
    parser.add_argument(
        "episodes",
        nargs="*",
        metavar="EPISODE",
        help="episode ids to compile (default: every episode with script.md)",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="fail if committed generated files do not match their sources",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_argument_parser().parse_args(argv)
    try:
        allowed_stats = load_allowed_stats()
        sources = discover_sources(args.episodes)
        # Compile everything before writing anything. An author error therefore
        # cannot leave half the episodes updated.
        artifacts = [
            (source.parent, compile_source(source, episode_id, allowed_stats))
            for episode_id, source in sources
        ]
    except CompileError as exc:
        print(exc, file=sys.stderr)
        return 1

    result = _write_or_check(artifacts, args.check)
    if result != 0:
        return result
    verb = "checked" if args.check else "compiled"
    for _episode_dir, artifact in artifacts:
        print(
            f"{verb} {artifact.episode_id}: "
            f"{artifact.phrase_line_count} phrase-cut line(s)"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
