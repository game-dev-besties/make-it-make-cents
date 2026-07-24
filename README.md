# Money Where Your Mouth Is

A Godot 4 narrative game built around self-contained, Inspector-editable episodes.

## Open the project

Open `project.godot` with Godot 4.7 or newer and press **Play**. Dialogic is
vendored under `addons/dialogic` and is the only required third-party plugin.

To produce the web build, run `bash scripts/build-web.sh` with `godot` on your
PATH (or set `GODOT_BIN` to its executable). The Vercel build script downloads
the pinned Godot release and export templates into Vercel's cache.

## Where work belongs

| If you are changing… | Start here |
| --- | --- |
| The order of the story | `content/campaign/campaign.tres` |
| A scene's title, budget, stage, or dialogue | `content/episodes/<episode>/episode.tres` |
| Backgrounds, actors, props, and animation | `content/episodes/<episode>/stage.tscn` |
| Dialogue | `content/episodes/<episode>/dialogue.dtl` in Dialogic's editor |
| Shared character art | `content/characters/` |
| Reusable UI or stage parts | `ui/` and `game/components/` |
| Runtime behaviour | `game/runtime/` |

Every episode is a vertical slice: duplicate the `content/episodes/intro/`
folder, edit its Godot assets, then register its `episode.tres` in the campaign
resource. There is no content compiler and no generated source directory.

## Architecture

`app/` owns the application shell. `CampaignPlayer` chooses an episode, mounts
its stage, and asks Dialogic to play its timeline. Stage scenes only own their
visuals and animations; they do not know campaign order. `GameState` contains
the small amount of game-wide state and budget accounting.

`addons/` is reserved for third-party plugins or true Godot editor plugins.
Application code belongs in `game/`, and authored game content belongs in
`content/`.
