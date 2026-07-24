#!/usr/bin/env python3
"""
Compiles writer-friendly Markdown cutscene scripts (story/scripts/*.md) into
Dialogic text timelines (generated/timelines/*.dtl) + per-cutscene
phrase-cut metadata (generated/timelines/*.phrases.json), driven by
story/manifest.yaml.

See DESIGN.md for the source format. Writers only touch story/; this tool
produces the Dialogic artifacts.

Usage:
    python3 tools/compile_scenes.py            # compile all cutscenes
    python3 tools/compile_scenes.py dad        # compile one cutscene by id
"""
import json
import os
import re
import sys

import yaml

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STORY = os.path.join(ROOT, "story")
SCRIPTS = os.path.join(STORY, "scripts")
TIMELINES = os.path.join(ROOT, "generated", "timelines")
MANIFEST = os.path.join(STORY, "manifest.yaml")
CHARACTERS = os.path.join(STORY, "characters.yaml")
STATS = os.path.join(STORY, "stats.yaml")

BG_RES = "res://art/backgrounds/{id}.png"
MUSIC_RES = "res://audio/music/{id}.ogg"
SFX_RES = "res://audio/sfx/{id}.ogg"


# ── loading ──────────────────────────────────────────────────────────────────

def load_yaml(path):
    with open(path) as f:
        return yaml.safe_load(f)


def load_character_ids():
    data = load_yaml(CHARACTERS)
    ids = {c["id"] for c in data.get("characters", [])}
    exprs = set(data.get("expressions", []))
    return ids, exprs


def load_stat_props():
    schema = load_yaml(STATS)
    props = set()
    for group, members in schema["stats"].items():
        for stat in members:
            props.add(f"{group}_{stat}")
    return props


def load_stat_dotted():
    """Return the set of writer-facing dotted stat paths (group.stat)."""
    schema = load_yaml(STATS)
    dotted = set()
    for group, members in schema["stats"].items():
        for stat in members:
            dotted.add(f"{group}.{stat}")
    return dotted


# ── front matter + tokenizer ─────────────────────────────────────────────────

FM_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n(.*)$", re.DOTALL)


def split_front_matter(text):
    m = FM_RE.match(text)
    if not m:
        return {}, text
    return yaml.safe_load(m.group(1)) or {}, m.group(2)


def tokenize(body):
    out = []
    for raw in body.splitlines():
        if not raw.strip():
            continue
        stripped = raw.lstrip()
        indent = len(raw) - len(stripped)
        text = stripped.rstrip()
        # trailing backslash = line continuation (join with next, keep indent of first)
        if out and out[-1][1].endswith('\\'):
            prev_ind, prev_text = out.pop()
            out.append((prev_ind, prev_text[:-1].rstrip() + ' ' + text))
        else:
            out.append((indent, text))
    return out


# ── statement parsing ────────────────────────────────────────────────────────

LABEL_RE = re.compile(r"^##\s+(\w+)")
JUMP_RE = re.compile(r"^->\s+(\S+)")
CHOICE_RE = re.compile(r'^-\s+(.*)$')
DIALOGUE_RE = re.compile(r'^(\w+)(?:\s*\(([^)]*)\))?\s*:\s*(.*)$')
SET_RE = re.compile(r'^([A-Za-z_][\w.]*)\s*(\+=|-=|\*=|/=|=)\s*(.+)$')
IF_RE = re.compile(r'^if\s+(.+):\s*$')
ELIF_RE = re.compile(r'^elif\s+(.+):\s*$')
ELSE_RE = re.compile(r'^else:\s*$')

# One deletable phrase per line, e.g.:
#   [to your car] = (:guilty, 3)
#   [while you were away]
# A phrase only carries a cost if it also carries a label (used later for
# `if kept("guilty"):` branching) — so the annotation is a single
# label+cost tuple, not two independent optional fields.
PHRASE_LINE_RE = re.compile(
    r'^\[(?P<text>[^\]]*)\]\s*(?:=\s*\(\s*:(?P<label>\w+)\s*,\s*(?P<cost>-?\d+)\s*\)\s*)?$')


def parse_phrase_block(lines, i, parent_indent):
    """Parse the indented block of [phrase] lines following a bare
    `speaker (expr):` header. Returns (phrases, next_i)."""
    n = len(lines)
    j = i
    while j < n and (lines[j][1].startswith('//')
                     or (lines[j][1].startswith('#') and not lines[j][1].startswith('##'))):
        j += 1
    if j >= n or lines[j][0] <= parent_indent:
        raise SystemExit(f"phrase block after line {i} has no [phrase] lines")
    body_indent = lines[j][0]
    phrases = []
    while i < n:
        ind, text = lines[i]
        if text.startswith('//') or (text.startswith('#') and not text.startswith('##')):
            i += 1
            continue
        if ind != body_indent:
            break
        m = PHRASE_LINE_RE.match(text)
        if not m:
            raise SystemExit(f"invalid phrase line (expected `[text]` or `[text] = (:label, cost)`): {text!r}")
        ptext = m.group('text').strip()
        if m.group('label'):
            phrases.append({"text": ptext, "cost": int(m.group('cost')), "id": m.group('label')})
        else:
            phrases.append({"text": ptext, "cost": len(ptext.split()), "id": None})
        i += 1
    return phrases, i


def parse_stage(text):
    body = text[1:].strip()
    parts = body.split(None, 1)
    cmd = parts[0]
    arg = parts[1].strip() if len(parts) > 1 else ""
    if cmd == 'bg':
        return {"kind": "bg", "id": arg}
    if cmd == 'music':
        return {"kind": "music", "id": arg}
    if cmd == 'sfx':
        return {"kind": "sfx", "id": arg}
    if cmd == 'wait':
        return {"kind": "wait", "seconds": float(arg) if arg else 1.0}
    raise SystemExit(f"unknown stage directive: {text!r}")


def parse_block(lines, i, indent):
    """Parse statements at the given indent. Returns (stmts, next_i)."""
    stmts = []
    n = len(lines)
    while i < n:
        ind, text = lines[i]
        # skip writer comments wherever they are (before indent check)
        if text.startswith('//') or (text.startswith('#') and not text.startswith('##')):
            i += 1
            continue
        if ind != indent:
            break  # dedent (or unrelated over-indent) ends this block
        m = LABEL_RE.match(text)
        if m:
            stmts.append({"kind": "label", "name": m.group(1)}); i += 1; continue
        m = JUMP_RE.match(text)
        if m:
            stmts.append({"kind": "jump", "target": m.group(1)}); i += 1; continue
        if text.startswith('@'):
            stmts.append(parse_stage(text)); i += 1; continue
        m = CHOICE_RE.match(text)
        if m:
            ct = m.group(1).strip()
            if len(ct) >= 2 and ct[0] == '"' and ct[-1] == '"':
                ct = ct[1:-1]
            i += 1
            body, i = parse_body(lines, i, indent)
            stmts.append({"kind": "choice", "text": ct, "body": body}); continue
        if IF_RE.match(text):
            branches = []
            cond = IF_RE.match(text).group(1).strip()
            i += 1
            body, i = parse_body(lines, i, indent)
            branches.append((cond, body))
            while i < n:
                ind2, text2 = lines[i]
                if ind2 != indent:
                    break
                if ELIF_RE.match(text2):
                    c = ELIF_RE.match(text2).group(1).strip(); i += 1
                    b, i = parse_body(lines, i, indent)
                    branches.append((c, b))
                elif ELSE_RE.match(text2):
                    i += 1
                    b, i = parse_body(lines, i, indent)
                    branches.append((None, b))
                else:
                    break
            stmts.append({"kind": "if", "branches": branches}); continue
        m = SET_RE.match(text)
        if m and '.' in m.group(1):
            stmts.append({"kind": "set", "stat": m.group(1),
                          "op": m.group(2), "value": m.group(3).strip()})
            i += 1; continue
        m = DIALOGUE_RE.match(text)
        if m:
            speaker, expr = m.group(1), (m.group(2) or "").strip()
            if m.group(3).strip():
                stmts.append({"kind": "dialogue", "speaker": speaker, "expr": expr, "text": m.group(3)})
                i += 1
            else:
                phrases, i = parse_phrase_block(lines, i + 1, indent)
                stmts.append({"kind": "dialogue", "speaker": speaker, "expr": expr, "phrases": phrases})
            continue
        stmts.append({"kind": "narration", "text": text}); i += 1
    return stmts, i


def parse_body(lines, i, parent_indent):
    """Parse an indented body under a choice/condition. The body indent is
    taken from the first significant line (any indent > parent_indent), so
    writers can use 2-space, 4-space, or tab indentation freely."""
    n = len(lines)
    j = i
    while j < n:
        _, t = lines[j]
        if t.startswith('//') or (t.startswith('#') and not t.startswith('##')):
            j += 1
            continue
        break
    if j >= n or lines[j][0] <= parent_indent:
        return [], i  # empty body
    body_indent = lines[j][0]
    return parse_block(lines, i, body_indent)


def parse_script(path):
    with open(path) as f:
        raw = f.read()
    fm, body = split_front_matter(raw)
    lines = tokenize(body)
    stmts, _ = parse_block(lines, 0, 0)
    return fm, stmts


# ── emission ─────────────────────────────────────────────────────────────────

def stat_to_ref(stat_path):
    return "GameStats." + stat_path.replace('.', '_')


# Rewrite writer-facing expressions into forms Dialogic's Expression engine can
# resolve (it sees autoloads, not dotted paths or bare helpers):
#   crush.fondness                       -> GameStats.crush_fondness
#   kept("id") / removed("id") / kept_count() -> PhraseMemory.kept(...)/...
# Used for if/elif conditions.
def translate_expr(expr, stat_dotted):
    out = expr
    for dotted in sorted(stat_dotted, key=len, reverse=True):
        flat = dotted.replace('.', '_')
        out = re.sub(r'\b' + re.escape(dotted) + r'\b', 'GameStats.' + flat, out)
    # order matters: kept_count before kept so 'kept(' doesn't grab 'kept_count('
    out = re.sub(r'(?<![\w.])kept_count\(\)', 'PhraseMemory.kept_count()', out)
    out = re.sub(r'(?<![\w.])kept\(', 'PhraseMemory.kept(', out)
    out = re.sub(r'(?<![\w.])removed\(', 'PhraseMemory.removed(', out)
    return out


def esc_choice(s):
    return s.replace('\\', '\\\\').replace('|', '\\|')


class Emitter:
    def __init__(self, cutscene_id, stat_props, stat_dotted):
        self.cutscene_id = cutscene_id
        self.stat_props = stat_props
        self.stat_dotted = stat_dotted
        self.lines = []
        self.phrases = {}
        self.seq = 0

    def emit(self, depth, text):
        self.lines.append('\t' * depth + text)

    def next_line_id(self):
        self.seq += 1
        return f"{self.cutscene_id}_L{self.seq:03d}"

    def check_stat(self, stat):
        if stat.replace('.', '_') not in self.stat_props:
            print(f"  ! warning: unknown stat '{stat}' (not in story/stats.yaml)", file=sys.stderr)

    def emit_stmts(self, stmts, depth):
        for s in stmts:
            self.emit_stmt(s, depth)

    def emit_stmt(self, s, depth):
        k = s["kind"]
        if k == 'label':
            self.emit(depth, f'label {s["name"]}')
        elif k == 'jump':
            self.emit(depth, 'end_timeline' if s["target"] == 'end' else f'jump {s["target"]}')
        elif k == 'set':
            self.check_stat(s["stat"])
            self.emit(depth, f'set {{{stat_to_ref(s["stat"])}}} {s["op"]} {s["value"]}')
        elif k == 'bg':
            self.emit(depth, f'[background arg="{BG_RES.format(id=s["id"])}" fade="0.5"]')
        elif k == 'music':
            if s["id"] == 'stop':
                self.emit(depth, 'audio music -')
            else:
                self.emit(depth, f'audio music "{MUSIC_RES.format(id=s["id"])}" [fade="1.0" loop="true"]')
        elif k == 'sfx':
            self.emit(depth, f'audio "{SFX_RES.format(id=s["id"])}"')
        elif k == 'wait':
            self.emit(depth, f'[wait time="{s["seconds"]}"]')
        elif k == 'narration':
            self.emit(depth, s["text"])
        elif k == 'dialogue':
            self.emit_dialogue(s, depth)
        elif k == 'choice':
            self.emit(depth, f'- {esc_choice(s["text"])}')
            if s["body"]:
                self.emit_stmts(s["body"], depth + 1)
            else:
                self.emit(depth + 1, '# (empty choice)')
        elif k == 'if':
            first = True
            for cond, body in s["branches"]:
                if cond is None:
                    self.emit(depth, 'else:')
                elif first:
                    self.emit(depth, f'if {translate_expr(cond, self.stat_dotted)}:')
                else:
                    self.emit(depth, f'elif {translate_expr(cond, self.stat_dotted)}:')
                first = False
                if body:
                    self.emit_stmts(body, depth + 1)
                else:
                    self.emit(depth + 1, '# (empty branch)')
        else:
            raise SystemExit(f"unknown stmt kind {k}")

    def emit_dialogue(self, s, depth):
        prefix = f'{s["speaker"]} ({s["expr"]})' if s["expr"] else s["speaker"]
        phrases = s.get("phrases")
        if phrases is None:
            self.emit(depth, f'{prefix}: {s["text"]}' if prefix else s["text"])
            return
        segments = []
        for p in phrases:
            seg = {"type": "phrase", "text": p["text"], "cost": p["cost"]}
            if p["id"]:
                seg["id"] = p["id"]
            segments.append(seg)
        line_id = self.next_line_id()
        self.phrases[line_id] = {
            "speaker": s["speaker"], "expr": s["expr"],
            "segments": segments, "min_keep": 1,
        }
        self.emit(depth, f'phrase_cut {prefix} {line_id}' if prefix else f'phrase_cut _ {line_id}')


# ── orchestration ────────────────────────────────────────────────────────────

def compile_cutscene(entry, stat_props, stat_dotted):
    cid = entry["id"]
    em = Emitter(cid, stat_props, stat_dotted)
    em.lines.append(f'# compiled from story/{cid} (do not edit by hand)')
    budget = entry.get("budget", 0)
    # stitch scripts in order
    first_fm = None
    for script_name in entry.get("scripts", [cid]):
        path = os.path.join(SCRIPTS, cid, f"{script_name}.md")
        if not os.path.exists(path):
            print(f"  ! missing script {path}", file=sys.stderr)
            continue
        fm, stmts = parse_script(path)
        if first_fm is None:
            first_fm = fm
            if fm.get("bg"):
                em.emit(0, f'[background arg="{BG_RES.format(id=fm["bg"])}" fade="0.5"]')
            if fm.get("music"):
                em.emit(0, f'audio music "{MUSIC_RES.format(id=fm["music"])}" [fade="1.0" loop="true"]')
        em.emit_stmts(stmts, 0)
    # write .dtl
    os.makedirs(TIMELINES, exist_ok=True)
    dtl_path = os.path.join(TIMELINES, f"{cid}.dtl")
    with open(dtl_path, "w") as f:
        f.write("\n".join(em.lines) + "\n")
    # write phrase json
    pj_path = os.path.join(TIMELINES, f"{cid}.phrases.json")
    with open(pj_path, "w") as f:
        json.dump(em.phrases, f, indent=2)
    print(f"  ok {cid}: {len(em.lines)} timeline lines, {len(em.phrases)} phrase-cut lines (budget {budget})")
    return {
        "id": cid,
        "name": entry.get("name", cid),
        "budget": budget,
        "timeline": f"res://generated/timelines/{cid}.dtl",
        "phrases": f"res://generated/timelines/{cid}.phrases.json",
    }


def main():
    only = sys.argv[1:]
    manifest = load_yaml(MANIFEST)
    stat_props = load_stat_props()
    stat_dotted = load_stat_dotted()
    index = []
    for entry in manifest["cutscenes"]:
        if only and entry["id"] not in only:
            continue
        index.append(compile_cutscene(entry, stat_props, stat_dotted))
    with open(os.path.join(TIMELINES, "index.json"), "w") as f:
        json.dump({"cutscenes": index}, f, indent=2)
    print(f"\nCompiled {len(index)} cutscene(s) → generated/timelines/")


if __name__ == "__main__":
    raise SystemExit(main())
