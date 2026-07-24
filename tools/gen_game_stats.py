#!/usr/bin/env python3
"""
Generates addons/game/autoloads/GameStats.gd from story/stats.yaml.

GameStats is a typed Godot autoload singleton. Because autoloads live for the
whole game session, stats persist across cutscenes automatically, and the
ending cutscene can read them via conditions (Dialogic passes every autoload
into its Expression engine, so `GameStats.crush_fondness` works in `if`).

The dotted `group.stat` path in story scripts flattens to `group_stat`
(GDScript identifier). Writers use the dotted form; the compiler maps it.

Usage:
    python3 tools/gen_game_stats.py
"""
import os
import re

import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCHEMA = os.path.join(ROOT, "story", "stats.yaml")
OUT = os.path.join(ROOT, "addons", "game", "autoloads", "GameStats.gd")

GD_TYPES = {"int": "int", "float": "float", "bool": "bool", "String": "String"}
GD_DEFAULTS = {"int": "0", "float": "0.0", "bool": "false", "String": '""'}


def to_prop(group: str, stat: str) -> str:
    return f"{group}_{stat}"


def main() -> int:
    with open(SCHEMA) as f:
        schema = yaml.safe_load(f)
    stats = schema["stats"]

    lines: list[str] = []
    lines.append('extends Node')
    lines.append('# AUTO-GENERATED from story/stats.yaml by tools/gen_game_stats.py — do not edit by hand.')
    lines.append('# Dotted script path `group.stat` maps to property `group_stat`.')
    lines.append('')
    lines.append('# Persisted game stats (see story/stats.yaml):')
    props = []  # (group, stat, type, default)
    for group, members in stats.items():
        lines.append(f'# ── {group} ──')
        for stat, spec in members.items():
            t = spec.get("type", "int")
            if t not in GD_TYPES:
                raise SystemExit(f"unsupported type {t!r} for {group}.{stat}")
            default = spec.get("default", GD_DEFAULTS[t])
            prop = to_prop(group, stat)
            props.append((group, stat, t, default))
            lines.append(f'var {prop}: {GD_TYPES[t]} = {default}')
        lines.append('')

    # Runtime economy fields (not in the schema)
    lines.append('# Per-cutscene word budget. Set by CutsceneRunner from the manifest; resets per cutscene.')
    lines.append('var cutscene_budget: int = 0')
    lines.append('var cutscene_spent: int = 0')
    lines.append('')
    lines.append('')

    # reset_for_new_game
    lines.append('func reset_for_new_game() -> void:')
    for group, stat, t, d in props:
        lines.append(f'\t{to_prop(group, stat)} = {d}')
    lines.append('\tcutscene_budget = 0')
    lines.append('\tcutscene_spent = 0')
    lines.append('')
    lines.append('')

    # cutscene lifecycle
    lines.append('func begin_cutscene(budget: int) -> void:')
    lines.append('\tcutscene_budget = budget')
    lines.append('\tcutscene_spent = 0')
    lines.append('')
    lines.append('func spend(amount: int) -> void:')
    lines.append('\tcutscene_spent += amount')
    lines.append('')
    lines.append('func remaining_budget() -> int:')
    lines.append('\treturn cutscene_budget - cutscene_spent')
    lines.append('')
    lines.append('# Bank unspent budget as lifetime savings. Call at cutscene end.')
    lines.append('func end_cutscene() -> void:')
    lines.append('\tmoney_total_saved += max(0, cutscene_budget - cutscene_spent)')
    lines.append('')
    lines.append('')

    # snapshot / restore
    lines.append('func snapshot() -> Dictionary:')
    lines.append('\treturn {')
    for group, stat, t, d in props:
        p = to_prop(group, stat)
        lines.append(f'\t\t"{p}": {p},')
    lines.append('\t\t"cutscene_budget": cutscene_budget,')
    lines.append('\t\t"cutscene_spent": cutscene_spent,')
    lines.append('\t}')
    lines.append('')
    lines.append('func restore(data: Dictionary) -> void:')
    for group, stat, t, d in props:
        p = to_prop(group, stat)
        lines.append(f'\t{p} = data.get("{p}", {d})')
    lines.append('\tcutscene_budget = data.get("cutscene_budget", 0)')
    lines.append('\tcutscene_spent = data.get("cutscene_spent", 0)')
    lines.append('')

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        f.write("\n".join(lines) + "\n")
    print(f"wrote {OUT} ({len(props)} stats)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
