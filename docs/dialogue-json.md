# JSON dialogue authoring

The game loads dialogue JSON directly. There is no compiler, generated timeline,
Python environment, or Dialogic setup step.

## Where things live

- `story/dialogues/*.json` — story content and response rules
- `scripts/dialogue/dialogue_runner.gd` — loading, validation, branching, costs,
  and score state
- `scenes/dialogue/dialogue_screen.tscn` — visual-novel layout
- `scenes/ui/phrase_cut/phrase_cut_panel.tscn` — phrase selection overlay
- `scenes/main.tscn` — title screen and top-level navigation

Open the three `.tscn` files in Godot to adjust their layout visually. To choose
a different opening story, select `Main` in `main.tscn` and change
`Opening Dialogue` in the Inspector.

## Small example

```json
{
  "format_version": 1,
  "id": "interview",
  "start": "question",
  "initial_state": {
    "budget": 20,
    "success": 5,
    "silly": 0
  },
  "nodes": {
    "question": {
      "type": "line",
      "speaker": "interviewer",
      "expression": "neutral",
      "text": "Tell me about yourself.",
      "next": "answer"
    },
    "answer": {
      "type": "phrase",
      "speaker": "dad",
      "expression": "nervous",
      "segments": [
        {"id": "i_have", "text": "I have"},
        {"id": "no", "text": "no"},
        {"id": "experience", "text": "experience"},
        {"id": "fast_learner", "text": "I'm a fast learner."}
      ],
      "responses": [
        {
          "match": {"all": ["fast_learner"]},
          "speaker": "interviewer",
          "expression": "impressed",
          "text": "Straight to the point.",
          "success": 1,
          "next": "done"
        }
      ],
      "fallback": {
        "speaker": "interviewer",
        "expression": "confused",
        "text": "I'm not sure I understand.",
        "success": -3,
        "next": "done"
      }
    },
    "done": {
      "type": "end",
      "speaker": "narrator",
      "text": "The interview ends."
    }
  }
}
```

Node keys such as `question`, `answer`, and `done` are IDs. A `next` field uses
an ID to say which node follows, which is what permits branching without relying
on line numbers.

## Node types

### `line`

Shows an ordinary visual-novel line. Required fields are `speaker`, `text`, and
`next`.

### `phrase`

Shows removable phrase chips. Each segment has a stable `id`, visible `text`,
and an optional numeric `cost`. Cost defaults to the number of space-separated
words in `text`; provide `cost` only when a phrase needs a special
price. A submission checks the optional `responses` list from top to bottom;
the first matching response wins. If none match—or the list is omitted—
`fallback` is used.

Available match rules:

| Rule | Meaning |
| --- | --- |
| `exact` | These and only these phrase IDs were kept |
| `all` | Every listed ID was kept; other IDs are allowed |
| `any` | At least one listed ID was kept |
| `none` | None of the listed IDs were kept |
| `delivery` | `speech` (the default), `silence`, `pity`, or `sponsor` |

Rules in the same `match` object are combined. This handles the useful groups
of the 32 possible five-phrase combinations without listing all 32.

A response may directly adjust `budget`, `success`, and `silly`. Success is
clamped from 1–10 and silly from 0–10. Pity and sponsor delivery can each be
used once per dialogue run.

### `end`

Displays its optional `speaker` and `text`, then returns to the title screen.

## Visual and audio cues

Lines and responses may include:

```json
{
  "expression": "annoyed",
  "background": "res://art/backgrounds/office.png",
  "music": "res://audio/music/interview.ogg",
  "sfx": "res://audio/sfx/door_close.wav"
}
```

The screen already reads these fields. A missing background or music field
keeps the previous cue. Until art exists, the stage displays the speaker and
expression as clear placeholders.

## Testing

Open the project in Godot and press F6 on `main.tscn`, or run:

```bash
godot --headless --path . --script res://tests/dialogue_runner_test.gd
godot --headless --path . --script res://tests/dialogue_screen_test.gd
```

Malformed JSON, unknown node references, duplicate phrase IDs, invalid costs,
and unknown matcher IDs fail with a specific validation message.
