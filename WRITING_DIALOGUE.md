# Writing dialogue

Each writable episode has one source file beside its Godot scene:

```text
content/episodes/dad/
├── episode.tres       # order, budget, routes: edit in Godot
├── stage.tscn         # visual composition: edit in Godot
└── script.md          # words and story branches: edit as text
```

Run:

```sh
python3 tools/compile_dialogue.py
```

That compiles every `script.md` into the adjacent `dialogue.dtl` and
`phrases.json` consumed by Dialogic. It needs Python 3 and no packages. Compile
just one episode with `python3 tools/compile_dialogue.py dad`. CI can use
`python3 tools/compile_dialogue.py --check` to detect stale generated files.

Generated files are committed so a fresh Godot checkout opens without a
separate content bootstrap. Do not edit `dialogue.dtl` or `phrases.json` by
hand when the folder has a `script.md`.

## Auditing branches and budgets

Compilation proves that dialogue is valid, but it does not prove that its
responses are complete or enjoyable. Run the branch auditor while drafting a
phrase-cut episode:

```sh
python3 tools/audit_dialogue.py dad
```

The Markdown report groups every reachable phrase selection by response and
flags exact reachability problems alongside writer-review heuristics. It
surfaces:

- all selectable phrase subsets and the branch each one reaches;
- compressed budget, stat, recovery, and story-flag states after every prompt;
- unreachable and shadowed responses;
- catch-all responses that absorb most selections;
- smallest phrase selections that still reach a catch-all;
- an all-kept default sentence that unexpectedly reaches `else`;
- large score changes caused by toggling one phrase;
- inaccessible pity or sponsor responses;
- reachable pity or sponsor deliveries that use a generic fallback; and
- suspiciously low or high scores reaching a named outcome.

Use `--include-states` to put every compressed state into the Markdown report,
or `--format json` for tooling and custom queries. Counts are exhaustive
combinatorial paths, not predictions about how frequently players will make
each choice.

Budget experiments do not require editing the episode resource:

```sh
python3 tools/audit_dialogue.py dad --budget 40
```

If an outline specifies how many phrase prompts the finished scene should
contain, make missing content explicit:

```sh
python3 tools/audit_dialogue.py dad --expect-phrase-lines 5
```

The auditor currently provides exact path counts for loop-free scripts.
Episodes with retry `->` jumps are rejected rather than reported
incompletely. Findings marked `EXACT` are mechanical facts; findings marked
`HEURISTIC` are review prompts and do not make the build fail.

### Splitting a long episode

`script.md` remains the default and is all most episodes need. To split one
episode across several files, add `scripts.json` beside `episode.tres`:

```json
{
  "sources": [
    "01_arrival.md",
    "02_tutorial.md",
    "03_customs.md"
  ]
}
```

The compiler reads those adjacent Markdown files in exactly that order and
produces the same single `dialogue.dtl` and `phrases.json`. Labels and jumps
may cross file boundaries. Filenames must be unique, end in `.md`, and stay in
the episode folder. When `scripts.json` exists, its list is authoritative;
without it, the compiler continues to use `script.md`.

## The small language

Ordinary dialogue includes a speaker and optional expression:

```md
interviewer (neutral): Why do you want to work here?
dad (nervous): I would be proud to join the team.
dad (serious): Percy, [speed=2]do not say one word.[speed]
```

An expression names a portrait on that speaker's Dialogic character resource.
Omit `(expression)` until the character and matching portrait exist; Dialogic
otherwise treats the parenthesized value as a fallback speaker color.

Dialogic inline text effects are preserved on ordinary dialogue. Put any
opening effect after some ordinary text, as in the `[speed]` example above. A
spoken line whose first character is `[` is deliberately reserved for
phrase-cut dialogue.

Useful Dialogic effects include `[pause=0.5]`, `[speed=2]... [speed]`,
`[lspeed=0.03]... [lspeed]`, `[n]` for a new line, and `[aa]` to auto-advance
one line. Use them sparingly; the ordinary click/keyboard advance behavior
should remain predictable.

End a physical source line with `\` to continue it on the next line. The
compiler replaces the backslash and newline with one space, so this changes
source formatting only:

```md
dad (neutral): This is one long sentence that is easier \
  to review across two physical lines.
```

The same continuation works between bracketed chunks on a phrase-cut line.

Bare lines are narration. `// comments` and Markdown `# comments` are ignored.

A phrase-cut line puts every deletable chunk inline in brackets:

```md
dad (nervous): [I have]{id=have} [no]{id=no} [experience]{id=experience} [but]{id=but} [I’m a fast learner.]{id=fast}
```

Cost defaults to whitespace-separated word count. Override it only when the
fiction needs a special tariff:

```md
son (nervous): [Hello,]{id=hello} [your honor]{id=honor, cost=5}
```

`id` is optional, but a phrase needs one if later branches refer to it. Cost
must be a nonnegative whole number. Punctuation may sit just after a bracket
and is attached to that phrase, although keeping punctuation inside the
bracket is usually clearer.

Branch on the latest phrase-cut result:

```md
if kept("experience") and removed("no"):
  interviewer (happy): Good.
elif delivery("sponsor"):
  interviewer (annoyed): Please do not advertise during an interview.
elif delivery("pity"):
  interviewer (confused): Was that a grunt?
elif delivery("silence"):
  interviewer (neutral): Moving on.
else:
  interviewer (confused): I did not follow that.
```

Available helpers are:

- `kept("id")` and `removed("id")`
- `kept_count()`
- `budget()` for the current remaining word budget
- `could_afford_speech()` for whether the pre-delivery balance could afford at
  least one phrase chip
- `delivery("normal")`, `delivery("silence")`, `delivery("pity")`, and
  `delivery("sponsor")`

Sponsor recovery refills a few words and applies the standard score penalty in
the runtime. A `delivery("sponsor")` branch only supplies a custom reaction;
do not subtract the standard penalty again in the script.

If a particular sponsor response has a different success modifier in the
story outline, put `@sponsor_score` immediately before that phrase-cut line:

```md
@sponsor_score -1
dad: [Honestly,]{id=honestly} [I just need money.]{id=money}
```

The declared delta replaces the standard `-3` for that delivery; it is not an
additional adjustment. This applies the outline score once, so success
clamping remains correct. The directive accepts whole numbers from -10 to 10
and is consumed by the following phrase-cut line.

Question-specific recovery copy uses quoted `@sponsor_text` or `@pity_text`
directly before the same phrase-cut line:

```md
@sponsor_score -1
@sponsor_text "SAM’S SODA POP! WITH OVER 500 DIFFERENT FLAVORS!"
dad: [Honestly,]{id=honestly} [I just need money.]{id=money}
```

These directives replace the default sponsor or pity delivery text for that
line. They may be combined with `@recovery` and `@sponsor_score` in any order,
but each directive can appear only once before a line.

Stats are declared in `story/stats.json`, then written with a dotted name:

```md
dad.success += 2
dad.silly += 1

if dad.success > 5:
  interviewer (happy): I think you belong here.
else:
  interviewer (neutral): We will be in touch.
```

`GameStateStore` owns the matching flattened properties, such as
`dad_success`. `bash scripts/check.sh` verifies that every compiler-visible
stat exists in the runtime state and is serialized, and that every serialized
story stat is declared in `story/stats.json`. Update both files when adding a
new stat; CI fails with the mismatched name otherwise.

Persistent story flags are declared in `story/flags.json`. Each flag has a
default, an allowed value list, and optional plain-English descriptions for
the History view. Set one with the outline-style uppercase syntax:

```md
SET dad_offended_interviewer = "none"

interviewer: Advertising during an interview? That does not help your case.
SET dad_offended_interviewer = "soda"
```

`SET` adds a debug entry to History after changing the flag. Put it after the
dialogue reaction that triggered the change so the transcript stays in story
order. Unknown flags and values fail compilation.

Ordinary implementation conditions can read a flag without adding a history
entry:

```md
if flag("dad_offended_interviewer") == "none":
  SET dad_offended_interviewer = "butts"
```

Use uppercase `CHECK` for a player-meaningful branch that should be recorded
in History:

```md
CHECK dad_offended_interviewer != "none" as dad_did_not_get_the_job:
  interviewer: You didn’t get the job.

CHECK dad_offended_interviewer == "none" as dad_got_the_job:
  interviewer: You got the job!
```

Only the selected `CHECK` body runs. Its debug entry includes the actual flag
value, the branch name, and any plain-English value description from the flag
schema. Branch names use identifier syntax and should read clearly when
underscores become spaces.

Indent child lines consistently with spaces. The compiler accepts any
indentation width, but two spaces is easiest to scan.

Labels and jumps make longer branches readable:

```md
## next_question
interviewer (neutral): What is your greatest weakness?
-> outcome

## outcome
interviewer (happy): Thank you for your time.
-> end
```

`-> label_name` is a one-way goto and does not return to the arrow afterward.
Use it for retries and for converging branches. `-> end` ends the timeline.

Dialogic choices are available for non-phrase decisions:

```md
- Ask about the salary
  dad (neutral): What is the salary range?
- Skip the question
  -> next_question
```

## Budget and recovery controls

Tutorials can set the current word budget immediately:

```md
@budget 0
```

The amount must be a nonnegative whole number. This emits:

```text
budget_set 0
```

After the tutorial, silence, pity-grunt, and sponsor responses are available on
every phrase-cut prompt, regardless of the remaining word budget. The grunt and
sponsor are repeatable across prompts. These alternatives are visible before
the player cuts any phrase, then hide once phrase editing begins. They also
remain visible immediately when the budget is empty.

Use `@recovery` immediately before a phrase-cut line to override which recovery
buttons that line offers. This is primarily useful while teaching the responses
in the tutorial:

```md
@recovery sponsor, pity
son: [Please]{id=please} [let me speak.]{id=speak}
```

The allowed modes are `pity` and `sponsor`. Use `@recovery none` for neither.
Modes cannot be repeated, and `none` cannot be combined with another mode.
Silence remains the normal zero-cost delivery rather than a recovery mode.
Policies are canonicalized and consumed by only the following phrase-cut
line. For example, the source above emits:

```text
recovery_policy pity,sponsor
phrase_cut son intro_L001
```

The other exact policy forms are `recovery_policy pity`,
`recovery_policy sponsor`, and `recovery_policy none`.

Use `@speaker_name` to change a registered character's player-facing name at
an authored reveal:

```md
crush: Name’s Clem, by the way.
@speaker_name crush "Clem"
```

## Presentation and audio cues

These are optional and compile to Dialogic or the game's presentation-cue
event:

```md
@cue dad_enters
@background office
@music tense
@sfx door_close
@wait 0.5
@music stop
```

Short asset ids map to `res://art/backgrounds/<id>.png`,
`res://audio/music/<id>.ogg`, and `res://audio/sfx/<id>.ogg`. A full
`res://...` path is also accepted. The compiler validates the syntax but does
not require an asset to exist yet, so writers can work ahead of art and audio.

Background, music, and sound directives use Dialogic's native Alpha 20 events.
The project style bridges Dialogic background changes into the active
editor-authored stage, keeping the image behind its props and actor slots.
Music and sound effects play through Dialogic's audio subsystem.

Dialogic's History button shows delivered dialogue and selected choices. It is
enabled across the current playthrough and resets when a new campaign starts.

The generated `.dtl` may be opened in Dialogic to inspect the compiled result,
but do not author changes there. Custom compiler events are intentionally
hidden from Dialogic's add-event menu, and the next compile replaces generated
timelines.

Compiler errors include the source file and line number. It rejects malformed
brackets, negative costs, invalid budgets or recovery policies, unknown
stats/directives, bad indentation, duplicate labels, and jumps to missing
labels before changing any generated file.
