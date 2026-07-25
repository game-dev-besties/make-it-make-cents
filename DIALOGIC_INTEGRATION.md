# Dialogic integration

The project vendors
[Dialogic 2.0 Alpha 20](https://github.com/dialogic-godot/dialogic/releases/tag/2.0-alpha-20),
upstream commit
[`e301e1bb5e62e6de22c6b7748c4372d0570bb4a7`](https://github.com/dialogic-godot/dialogic/commit/e301e1bb5e62e6de22c6b7748c4372d0570bb4a7).
It requires Godot 4.5 or newer; this project targets Godot 4.7.

The online Dialogic class reference still identifies itself as Alpha 18. Use
the guides for concepts, but check the pinned Alpha 20 source when exact API
or timeline syntax matters. Do not update `addons/dialogic` without recording
the new tag and commit here and running the full checks and Web export.

## Who owns what

Dialogic owns:

- timeline execution, conditions, choices, waits, and jumps;
- typewriter reveal, speaker labels, inline text effects, and typing sounds;
- the textbox, choice, input, glossary/text-input, and history layers from
  `ui/dialogue/dialogue_style.tres`;
- native music, sound-effect, and background event state; and
- the extension point used by the phrase-cut gameplay events.

The game owns:

- campaign order, episode budgets, stats, and endings;
- editor-authored `StoryStage` scenes, actor placement, props, and animation;
- which Dialogic character/expression each stage slot renders; and
- phrase selection, recovery choices, and phrase-result memory.

This boundary is intentional. The stock Dialogic visual-novel style includes
full-screen background and portrait layers that would cover the editor-authored
stage. The project style omits those two layers. `CampaignPlayer` bridges
Dialogic text and background signals into the active `StoryStage`, so writers
still use native Dialogic events while artists retain a normal Godot scene.

## Editing dialogue presentation

Open `ui/dialogue/dialogue_hud.tscn` in Godot to edit the live
dialogue textbox. It is the scene referenced by the active Dialogic style;
every dialogue node is local and can be selected directly in the scene tree.
The local panel resources
`dialogue_textbox_panel.tres` and `dialogue_nameplate_panel.tres` control the
default box and speaker-label styling.

Generated `.dtl` timelines are inspection output, not a second authoring
surface. Compiler-only custom events are hidden from Dialogic's add-event menu
because editing them there would be overwritten and phrase lines also require
generated sidecar metadata.

## Features in use

- Ordinary and phrase-cut deliveries both execute a `DialogicTextEvent`, so
  both get typewriter reveal, speaker names, text effects, typing sounds, and
  backlog entries.
- Simple history is enabled and retained across episodes in one playthrough.
  Starting a new campaign clears the backlog.
- `@background`, `@music`, `@music stop`, `@sfx`, and `@wait` compile to
  Dialogic Alpha 20 syntax. Background images are rendered by the stage bridge;
  audio remains entirely in Dialogic.
- Dialogic characters remain the source of truth for display names,
  expressions, portraits, and future character-specific sound moods.

## Deliberate follow-ups

- Replace Dialogic's generic example typing sounds with game-owned sounds and
  configure character sound moods in the Character editor.
- Add actual Chapter 1 music and sound cues before tuning channels, buses,
  volume, or voice behavior.
- Add save/load only through a wrapper that saves Dialogic state together with
  `GameStats`, `PhraseMemory`, current episode, and stage state. Saving from the
  Dialogic subsystem alone would omit game-specific state.
- Add stable translation IDs to the Markdown compiler before enabling
  Dialogic's CSV localization workflow. Its editor writes IDs into `.dtl`
  files, which this project regenerates.
- Add player-facing text-speed, auto-advance, and read-text skip controls when
  there is a settings screen. Skip should be paired with visited-history
  persistence.
- Add voice events only after deciding how dynamically trimmed phrase lines
  map to recorded audio.
- Keep `export_filter="all_resources"` until a runtime-resource manifest is
  tested. Dialogic discovers modules and content dynamically, but the current
  Web export also carries editor/test files that can later be excluded safely
  with an explicit manifest check.

## Upgrade checklist

1. Replace the vendored addon from an official Dialogic tag; do not patch it in
   place.
2. Update the tag and commit at the top of this file.
3. Check the release notes for save-state, shortcode, and subsystem API
   changes.
4. Run `bash scripts/check.sh`.
5. Run `bash scripts/build-web.sh` and boot the exported game.
6. Confirm the project-owned style still contains textbox, input, choices, and
   history, and still omits Dialogic background and portrait layers.
