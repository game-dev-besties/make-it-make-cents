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

## The small language

Ordinary dialogue includes a speaker and optional expression:

```md
interviewer (neutral): Why do you want to work here?
dad (nervous): I would be proud to join the team.
```

An expression names a portrait on that speaker's Dialogic character resource.
Omit `(expression)` until the character and matching portrait exist; Dialogic
otherwise treats the parenthesized value as a fallback speaker color.

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
- `delivery("normal")`, `delivery("silence")`, `delivery("pity")`, and
  `delivery("sponsor")`

Sponsor recovery refills a few words and applies the standard score penalty in
the runtime. A `delivery("sponsor")` branch only supplies a custom reaction;
do not subtract the standard penalty again in the script.

Stats are declared in `story/stats.json`, then written with a dotted name:

```md
dad.success += 2
interviewer.impression -= 1

if dad.success > 5:
  interviewer (happy): I think you belong here.
else:
  interviewer (neutral): We will be in touch.
```

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

Dialogic choices are available for non-phrase decisions:

```md
- Ask about the salary
  dad (neutral): What is the salary range?
- Skip the question
  -> next_question
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

Compiler errors include the source file and line number. It rejects malformed
brackets, negative costs, unknown stats/directives, bad indentation, duplicate
labels, and jumps to missing labels before changing any generated file.
