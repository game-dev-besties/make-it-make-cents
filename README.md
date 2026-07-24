# Money Where Your Mouth Is

A Godot 4 narrative game built around self-contained, Inspector-editable episodes.

## Open the project

Open `project.godot` with Godot 4.7 or newer and press **Play**. Dialogic is
vendored under `addons/dialogic` and is the only required third-party plugin.
Generated timelines are committed, so opening a fresh checkout does not require
a setup command.

To compile changed dialogue, run `python3 tools/compile_dialogue.py`. It uses
only Python's standard library—there is no uv environment or package install.
See [WRITING_DIALOGUE.md](WRITING_DIALOGUE.md) for the format.

Run `bash scripts/check.sh` for compiler and Godot checks. To produce the Web
build, run `bash scripts/build-web.sh` with `godot` on your PATH (or set
`GODOT_BIN`). The Vercel build downloads checksum-verified Godot 4.7.1 binaries
and export templates into its cache.

## Where work belongs

| If you are changing… | Start here |
| --- | --- |
| The order of the story | `content/campaign/campaign.tres` |
| A scene's title, budget, or routes | `content/episodes/<episode>/episode.tres` |
| Backgrounds, actors, props, and animation | `content/episodes/<episode>/stage.tscn` |
| Dialogue and branches | `content/episodes/<episode>/script.md` |
| Shared character art | `content/characters/` |
| Reusable UI or stage parts | `ui/` and `game/components/` |
| Runtime behaviour | `game/runtime/` |

Every episode is a vertical slice: duplicate the `content/episodes/intro/`
folder, edit its Godot assets, then register its `episode.tres` in the campaign
resource. Each episode's `script.md` generates the adjacent `dialogue.dtl` and
`phrases.json`; do not hand-edit those two files.

## Architecture

`app/` owns the application shell. `CampaignPlayer` chooses an episode, mounts
its stage, and asks Dialogic to play its timeline. Stage scenes only own their
visuals and named animations; they do not know campaign order. The single
`GameStats` autoload owns persistent stats, cutscene budgets, and recovery
choices.

The small writer compiler emits Dialogic timelines plus phrase metadata.
Dialogic remains the presentation layer for typed text, speaker names,
portraits, expression changes, music, and sound. The custom phrase-cut event
only pauses that timeline long enough for the player to trim and pay for a
line.

`addons/` is reserved for third-party plugins or true Godot editor plugins.
Application code belongs in `game/`, and authored game content belongs in
`content/`.
