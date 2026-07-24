# Cutscene DSL — Design & Specification

A writer-friendly cutscene script format that compiles Markdown files into
runnable Godot cutscenes built on [Dialogic 2](https://docs.dialogic.pro).

We support the phrase removal mechanic by rolling our own Dialogic module, phrase_cut, which defines the event and UI for phrase cutting.

## Getting Started

### Writing your cutscene

Each cutscene is one Markdown file in `story/scripts/`, and they look something like this:

```md
---
cutscene: dad              # matches an id in story/manifest.yaml
budget: 100                # word-budget for THIS cutscene (resets here)
bg: office                 # initial background id  (stretch)
music: tense               # initial music track id  (stretch)
---

## intro

interviewer (neutral): Good morning. Have a seat. Let's begin.

dad (nervous):
    [Good morning]
    [thank you]
    [for seeing me]
    [I'm Marco]

interviewer (curious): So, Marco, why do you want this job?

- "Give an honest, humble answer"
  dad (sad):
      [I need]
      [to support]
      [my family]
  interviewer (happy): I appreciate the honesty. That takes courage.
  interviewer.impression += 3
  -> outro

- "Oversell yourself aggressively"
  dad (confident):
      [I am]
      [the best]
      [candidate]
  interviewer (confused): ...Right.
  interviewer.impression -= 2
  -> outro

## outro
interviewer (happy): Welcome to the team, Marco.
-> end
```

The syntax is hopefully self-documenting, we made it as close to human language as possible. However, here's a table if you want any clarifications:

| Element | Syntax | Notes |
|---|---|---|
| **Label** | `## name` | Jump target |
| **Dialogue** | `speaker (expression): text` | a speaker with a name label, specifies the sprite's facial expression too |
| **Narration** | bare `text` line (no `speaker:`) | the omniscient narrator that has no name label |
| **Phrase-cut line** | `speaker (expr):` header + indented `[phrase]` lines | see Phrase-removal section for more |
| **Choice** | `- "option text"` + indented body | choice boxes |
| **Jump** | `-> label` | note that `-> end` ends the cutscene |
| **Stat change** | `crush.fondness += 2`, `= 5`, `-= 1` | routes to `GameStats` |
| **Condition** | `if crush.fondness >= 5:`, `elif ...:`, `else:` | indented body |
| **Background** | `@bg park` | NOT IMPLEMENTED |
| **Music** | `@music calm` / `@music stop` | NOT IMPLEMENTED |
| **SFX** | `@sfx ding` | NOT IMPLEMENTED |
| **Wait** | `@wait 1.5` | pause for N seconds |
| **Comment** | `// note` | ignored by compiler |

### Cost Model for Phrase-Removal

We say that a "phrase-cut line" is a `speaker (expr):` header with nothing after the
colon, followed by one deletable `[phrase]` per indented line below it.

The player deletes phrases to save budget:

```
son (nervous):
    [Don't panic]
    [but]
    [I didn't]
    [do anything]
    [to your car] = (:guilty, 5)
    [while you were away]
```

**Rule 1: The default cost of a phrase is its word count.** For example, the phrases `Don't panic` / `but` / `I didn't` / `do anything` / `while you were away` would default to the costs `2 1 2 2 4`.

**Rule 2: You can give phrases labels, and you can override the default cost of a phrase, too.** 
You do it via the `= (:label, cost)` tuple. The purpose of the label is to give the branch-worthy phrases some kind of identifier. e.g. `[to your car] = (:guilty, 5)` costs 5 (instead of the word-count default of 3) and is tagged `:guilty` for branching. A bare `[phrase]` has no label and can't be branched on.

**Rule 3: You can do branch on kept/removed phrases, as long as they have a label.** If you're branching the story based on which phrases are kept and removed, you can do so with the following syntax:

  ```md
  son (nervous):
      [Don't panic] = (:calm, 2)
      [I didn't] = (:deny, 2)
      [to your car] = (:guilty, 3)

  if kept("guilty"):
      crush (nervous): Wait — you DID something to my car?!
  elif kept("calm") and removed("deny"):
      crush (happy): You seem pretty chill for a new kid!
  else:
      crush (neutral): Oh, hi there.
  ```
  - `kept("id")` / `removed("id")` / `kept_count()` — combine freely with
    `and`/`or`/`not` to case on any combo of kept+removed phrases.
  - Only the _last_ phrase-cut line's result is held (cleared on the next).
  - Phrases without a label aren't queryable; an unknown id is `kept`=`removed`=`false`.
  - You can combine them with stat conditions, like `if kept("guilty") and crush.fondness >= 4:`.

- **At runtime**, the kept phrases' costs sum and are deducted from the
  cutscene budget. The UI prevents confirming a selection whose cost exceeds
  the remaining budget. The player must keep at least one phrase
  (`min_keep = 1`, tunable per line later).

---

## 3. Cutscene manifest (`story/manifest.yaml`)

The list of cutscenes and the order they play. Like ChoiceScript's
`*scene_list`, but typed. Budget resets per cutscene from here.

```yaml
cutscenes:
  - id: dad
    name: "Dad's Job Interview"
    budget: 100
    scripts: [1_dad_job_interview]
  - id: neighbors
    name: "Visiting the Neighbors"
    budget: 120
    scripts: [2_neighbors_ending]   # reads stats accumulated above
```

- `scripts` is an ordered list, so a writer **can split one cutscene across
  multiple files** and the compiler stitches them into a single timeline.
- Script filenames are numbered (`1_`, `2_`, …) to match play order in a
  directory listing; `manifest.yaml`'s `scripts:` entries reference the full
  numbered stem.
- The final `neighbors` cutscene branches on the stats accumulated during
  `dad` (see §5) — other NPC stats (e.g. `crush.*`) stay at their `stats.yaml`
  default until a cutscene that sets them exists again.

---

## 4. Stats — typed schema, persisted, one place

### 4.1 Schema (`story/stats.yaml`)

Single source of truth for every stat in the game

### 4.2 Generated autoload (`GameStats.gd`)

`tools/gen_game_stats.py` emits `addons/game/autoloads/GameStats.gd`, a typed
singleton registered in `project.godot`:

```gdscript
extends Node
# AUTO-GENERATED from story/stats.yaml — do not edit by hand.

# crush
var crush_fondness: int = 0
var crush_creeped_out: int = 0
# interviewer
var interviewer_impression: int = 0
# ...
var money_total_saved: int = 0

# Per-cutscene budget (reset by CutsceneRunner at cutscene start)
var cutscene_budget: int = 0

func reset_for_new_game() -> void: ...
func snapshot() -> Dictionary: ...   # for save/load
```

Because it's an **autoload**, it lives for the whole session → **stats persist
across cutscenes automatically**. The ending cutscene reads them via
conditions (§5). "One place to find stats" = `story/stats.yaml` (schema) +
`GameStats` singleton (runtime).

### 4.3 How scripts touch stats

- `crush.fondness += 2` in Markdown compiles to a Dialogic `set` event that
  writes the autoload property:
  `set {GameStats.crush_fondness} += 2`
- `if crush.fondness >= 5:` compiles to:
  `if {GameStats.crush_fondness} >= 5:`
  (Dialogic resolves `{AutoloadName.prop}` in expressions.)

---

## 5. The ending cutscene (stat-driven branches)

`story/scripts/2_neighbors_ending.md` opens with the family visiting the neighbors,
who are *the same people* as the crush / interviewer / doctor. It branches
on accumulated stats:

```md
## door
neighbor (neutral): Oh! Welcome to the neighborhood. Come in!

if crush.fondness >= 4:
  crush (happy): Wait — you're that sweet kid from the park!
  -> warm
elif crush.creeped_out >= 3:
  crush (nervous): ...You. You're the one from the park, aren't you.
  -> chilly
else:
  crush (neutral): ...Huh. You look familiar.
  -> neutral_end

## warm
  -> end
```

So every choice the player made across the day surfaces here.

# More Thorough Info For the AI Coding Agents

Here's a diagram of how our markdowns and yamls become Godot scenes

```
 story/scripts/<id>/*.md ─┐
 story/*.yaml             ─┤  tools/compile_scenes.py  ──►  generated/timelines/*.dtl            (Dialogic text timelines)
                           │                           ──►  generated/timelines/*.phrases.json   (phrase-cut metadata)
                                                        │
 story/stats.yaml  ──►  tools/gen_game_stats.py  ──►  addons/game/autoloads/GameStats.gd  (typed, persisted)
                                                        │
                                    Dialogic + addons/dialogic_additions/phrase_cut/
                                                        │
                                                        ▼
                                           scenes/main.tscn  ──►  plays the cutscene
```

## 6. Characters

There's no character art or `.dch` Dialogic character resources — `art/characters/`,
`tools/fetch_sprites.py`, and `tools/generate_characters.gd` were all removed
(portraits weren't rendering in the web export and were cut from scope rather
than debugged). `story/characters.yaml` still documents the roster (id,
display name, color) for humans, but nothing in the pipeline reads it —
speaker names come entirely from Dialogic's runtime fallback: when a `.dtl`
line names a speaker with no matching `.dch` resource, Dialogic creates an
ad-hoc character on the fly using that speaker id as the display name (so
names currently render exactly as written in the DSL, e.g. `dad`, `mom`,
lowercase — not the prettified names in `characters.yaml`).

---

## 7. The custom Dialogic event: `PhraseCut`

A dialogue line containing `[phrases]` compiles to a **PhraseCut** event
(our own Dialogic event type), not a plain Text event — because the spoken
text is decided *by the player at runtime*.

- `.dtl` text form:
  `phrase_cut dad (nervous) dad_L001`
  (speaker, expression, and a line id that keys into the sidecar JSON.)
- Sidecar `.generated/timelines/<cutscene>.phrases.json`:
  ```json
  { "dad_L001": {
      "speaker": "dad", "expr": "nervous",
      "segments": [
        {"type": "phrase", "text": "Good morning", "cost": 2},
        {"type": "phrase", "text": "thank you", "cost": 2}
      ],
      "min_keep": 1 } }
  ```
  A segment gets an `"id"` key too if the phrase carried a `(:label, cost)`
  tuple (see §2.3).
- At runtime (`event_phrase_cut.gd`):
  1. set the speaker name label (via `dialogic.Text`; portrait/expression
     switching is still called via `dialogic.Portraits` but has no `.dch`
     portraits to switch between right now — see §6)
  2. open the `PhraseCutUI` overlay listing phrase chips
  3. player toggles phrases off; running cost vs `GameStats.cutscene_budget` shown live
  4. confirm → kept phrases joined → shown in textbox → cost deducted from budget →
     the kept ids are recorded in the **`PhraseMemory`** autoload (so the next
     `if kept("id"):` can branch on them)
  5. `finish()` (advance on next input)

The module lives in `addons/dialogic_additions/phrase_cut/index.gd`
(Dialogic auto-discovers `addons/dialogic_additions/*/index.gd`).

---

## 8. Tooling & iteration

Dialogic is **vendored** in `addons/dialogic` (committed), not a submodule —
Godot double-scans symlinked submodules (duplicate `class_name` errors in 4.7)
and symlinks break on Windows, so vendoring is the robust jam choice.

```bash
# one-time setup
./scripts/setup-godot.sh        # download macOS Godot 4.7.1 (gitignored under .bin/)
./scripts/setup-dialogic.sh    # Dialogic is vendored+enabled; just a sanity check
python3 tools/gen_game_stats.py # story/stats.yaml → addons/game/autoloads/GameStats.gd
python3 tools/compile_scenes.py # story/scripts/<id>/*.md → generated/timelines/*.dtl + .phrases.json
./scripts/dev.sh               # headless import (generates .import files; REQUIRED)

# fast content loop (no Godot needed!)
python3 tools/compile_scenes.py   # the source Markdown reads clearly enough to check story flow

# real game / browser
./scripts/dev.sh run           # launch project window
./scripts/play-web.sh           # web export + local http server (browser playtest, preferred)
# push to a PR → Vercel preview deployment
```

## 9. Status / what is validated vs. needs an editor pass

Validated headless (no GUI):
- Markdown format + compiler → real `.dtl` + phrase JSON (well-formedness checked)
- `story/stats.yaml` + `GameStats.gd` generator
- Godot headless import + autoload init run **with zero script errors** against
  the real vendored Dialogic (so `PhraseCut` event/subsystem/UI, `GameStats`,
  `CutsceneRunner`, `main.gd` all parse cleanly)
- Web export: verified via a real `--export-pack` dry run that everything the
  running game needs (timelines, phrase JSON) is actually bundled

Needs a Godot-editor (GUI) pass to validate visually:
- `PhraseCut` event/UI runtime behaviour (overlay, advance)
- `main.tscn` → `CutsceneRunner.start_game()` → Dialogic timeline launch wiring

These are marked `TODO(editor)` in code.

