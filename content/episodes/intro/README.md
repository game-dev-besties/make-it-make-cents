# Chapter 1 production notes

`script.md` is a complete playable draft of **Welcome to the Country**. It now
exercises the chapter's full mechanical contract:

- normal dialogue, narration, expressions, text-speed changes, and stage cues;
- phrase deletion with exact kept-phrase branches;
- free silence;
- a forced zero-budget practice section;
- a one-use pity grunt;
- a required sponsor refill that applies the standard success penalty;
- a normal dialogue choice stored in `intro.grandma_praised_for_silence`;
- a faceless customs interaction stored in `intro.pills_confiscated`; and
- a closing branch that carries the pills result into the new-home reveal.

The forced sponsor temporarily lowers Percy's tutorial score. The following Son
episode declares `score_owner = "son"`, so his actual scored conversation still
starts at the intended neutral `success = 5`, `silly = 0`.

The remaining work is deliberately content production rather than plumbing:

- decide whether the optional pills interaction stays in Chapter 1;
- replace the placeholder Sam's Soda blackout with the final jingle/SFX;
- confirm Clementine's final accent color instead of the draft black-and-violet line;
- replace prototype color-card scenery and non-Son portraits as art arrives;
- add final background music and checkpoint/home sound cues; and
- revise draft dialogue without changing the stable IDs, flags, or tutorial
  directives unless the mechanic itself changes.

After editing `script.md`, run `python3 tools/compile_dialogue.py intro` and
commit the regenerated `dialogue.dtl` and `phrases.json` beside it.
