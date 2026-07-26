# Chapter 4: Son Talks 2 Gril — implementation plan

## Decision

The existing dialogue system is adequate for most of this chapter. It already
supports:

- branching on every Chapter 2 and Chapter 3 input flag;
- phrase-level reactions with `kept()`, `removed()`, and `kept_count()`;
- silence, grunt, and sponsor deliveries;
- budget changes in the middle of a scene;
- persistent boolean and enum outcomes;
- score changes;
- labels, jumps, stage cues, expressions, and split source files.

It is not quite adequate for the intended zero-budget interaction. One small,
general-purpose runtime behavior change is needed:

1. Outside the staged tutorial, grunt and sponsor responses must always be
   available on every phrase prompt that permits them. They are currently each
   limited to one use per episode.

No new general dialogue engine, local-variable system, or custom Chapter 4
minigame is warranted. One small read-only `budget()` condition helper is
useful for choosing between the required-jingle and polite-exit paths. A
positive balance remains positive even when no offered phrase is affordable;
the UI simply disables the unaffordable chips.

The branch auditor needs two general-purpose additions for this chapter:

1. presentation-only directives such as `@speaker_name` must be mechanically
   ignored; and
2. goto destinations must be followed with a configurable per-label visit
   bound, with histories still retrying at the bound excluded from terminal
   findings and reported separately.

The audit also needs explicit incoming-flag variation so the soda, butts, and
neutral histories can be covered in one report.

## What maps directly to the current system

| Chapter requirement | Existing mechanism |
| --- | --- |
| Check whether Percy defended himself | `CHECK son_defended_self == ...` |
| Check whether Grandma's call was ignored | `CHECK grandma_ignored == ...` |
| Check Dad's family answer | `flag("dad_mentioned_family")` |
| Branch among Dad's soda, butts, and neutral interview outcomes | `flag("dad_offended_interviewer")` |
| Detect laugh versus tariff empathy | IDs on the latest phrase line plus `kept()` |
| Detect coherent disclosure versus orphaned chunks | Explicit `kept()` combinations per disclosure line |
| Remember disclosures for later Clem questions | Persistent boolean story flags |
| Add +3/+5 empathy | Reset and reuse `son.success`, with the sponsor penalty overridden to zero |
| Fail, baited, and success outcomes | An enum story flag |
| Move Clem on, off, or across the park stage | `@cue` plus authored `AnimationPlayer` cues |
| Reuse the park | Reference `content/episodes/son/park.png` from a new stage |
| Keep a long script reviewable | `scripts.json` with four ordered Markdown sources |

The script should use the registered speaker IDs `son` and `crush`; Dialogic
will display them as Percy and Clementine.

## Required system additions

### 1. Make grunt and sponsor repeatable outside tutorial gating

Remove the per-episode consumption rule. The existing writer syntax remains:

```md
@recovery pity,sponsor
@sponsor_score 0
@pity_text "hnf"
@sponsor_text "SAM'S SODA POP..."
son: [Yes.]{id=yes}
```

Semantics:

- By default, silence, grunt, and sponsor are available on every phrase prompt.
- `@recovery` only controls which of grunt and sponsor are shown on the
  following prompt. It no longer controls eligibility or consumption.
- `@recovery none`, `@recovery pity`, and `@recovery sponsor` remain useful for
  the tutorial and authored special cases.
- Every sponsor use adds exactly `$3`.
- Every sponsor use applies that line's `@sponsor_score`.
  Chapter 4 should use `0` so repeated jingles do not silently destroy Percy's
  empathy score.
- Silence remains free and always available.

Implementation surface:

- make `GameStateStore.can_use_pity()` and `can_use_sponsor()` depend only on
  whether a cutscene is open;
- make `use_pity()` non-consuming and let every successful
  `use_sponsor(3)` add sponsor credit;
- remove `pity_used` and `sponsor_used` from active state and new save data,
  while harmlessly ignoring those keys in legacy saves;
- remove those two dimensions from `tools/audit_dialogue.py`;
- update global recovery copy/tooltips so neither claims a grunt or sponsor is
  limited to one use;
- keep Chapter 1's staged exercise with its existing
  `@recovery none|pity|sponsor` policies and retry labels; scope any "one"
  wording to that practice step rather than the game's permanent rule;
- add an explicit `@recovery none` to any later Chapter 1 phrase prompt that
  currently inherits the default, so repeatable responses do not leak into the
  tutorial episode after its staged demonstrations;
- preserve `@recovery` as the existing one-prompt visibility policy;
- add regression tests for repeated use.

Keep the internal delivery names `pity` and `sponsor` for compatibility.
Chapter prose can call them a grunt and a jingle.

### 2. Budget condition around retries

Add `budget()` to writer conditions as a read-only shorthand for
`GameStats.remaining_budget()`. After the final opening-up prompt, use it to
route a Percy who has opened up and reached `$0` into the required-jingle beat,
while a player who conserved money receives the polite failure exit.

The first required-jingle prompt permits silence, grunt, or sponsor. A refusal
advances to a second `$0` prompt using `@required_delivery sponsor`: silence,
grunt, and paid phrase chips remain visible but disabled, and only the jingle
can advance. This one-prompt restriction does not consume or disable those
responses anywhere else in the episode.

## Episode and campaign structure

Create `content/episodes/crush/` as a new episode with:

```text
content/episodes/crush/
├── episode.tres
├── stage.tscn
├── scripts.json
├── 01_arrival.md
├── 02_opening_up.md
├── 03_jingle.md
├── 04_post_jingle.md
├── dialogue.dtl          # generated
└── phrases.json          # generated
```

Recommended episode resource:

- id: `crush`
- title: `Chapter 4: Son Talks 2 Gril`
- initial `word_budget`: `0`
- `score_owner`: `son`
- automatic route: `grandma`

The episode starts at `$0`. Place `@budget <chapter allotment>` immediately
after Clem slides the money over, so the mechanical refill happens at the same
story beat.

Campaign changes:

- change the Chapter 3 route from `son -> grandma` to `son -> crush`;
- route `crush -> grandma`;
- insert the new resource after `son` in `campaign.tres`;
- register `crush/dialogue` in Dialogic's timeline directory in
  `project.godot`.

## Story-state contract

### Inputs already present

- `son_defended_self: bool`
- `grandma_ignored: bool`
- `dad_mentioned_family: bool`
- `dad_offended_interviewer: "none" | "soda" | "butts"`

### New outputs and remembered facts

Add these to `story/flags.json`:

- `son_showed_tariff_empathy: bool`
- `girl_heard_jingle: bool`
- `percy_opened_up: bool`
- `son_mentioned_uprooted: bool`
- `son_mentioned_sold_everything: bool`
- `son_mentioned_grandma_sick: bool`
- `son_mentioned_mixed_feelings: bool`
- `clem_overshare_failure_count: 0 | 1 | 2 | 3`
- `got_the_girl: "unresolved" | "no" | "baited" | "yes"`

Use `unresolved` as the enum default. It lets old saves fall back to the
existing `son.success`/`son.silly` behavior in the neighbors scene instead of
silently becoming a "no".

The topic flags are set only when the retained chunks actually communicate the
topic. An orphaned `and`, `for you`, or similar fragment must not set them.
`percy_opened_up` becomes true on the first coherent disclosure.

Use `son.success` as the chapter's empathy score:

- tariff insight: `+3`;
- first-jingle connection: `+3` or `+5`, depending on the Dad interview branch;
- all Chapter 4 sponsor prompts: `@sponsor_score 0`.

The explicit `got_the_girl` flag, not the score, decides the ending.

## Dialogue flow

```text
Arrival and prior-chapter checks
  -> Clem funds Percy
  -> Grandma reaction
  -> Dad/interview reaction
  -> optional tariff-empathy score and flag
  -> seven disclosure prompts
       sponsor:         enter the first-jingle reveal
       coherent phrase: remember topic, percy_opened_up = true, "Go on..."
       silence/grunt/orphans: advance the shared failure counter
       third failure:   cold exit
       exact zero after opening up: required-jingle retry
       enough money left after all seven: polite failure
  -> first jingle
       empathy + Dad soda/butts/none reaction
       girl_heard_jingle = true
  -> establish the three-word budget
  -> force balance back to $0 after "Pretty much"
  -> react to silence/grunt/jingle
  -> ask remembered-topic follow-ups
  -> zero-cost yes/no protocol
       question 1: silence=no, grunt=yes, jingle=teasing retry
       question 2: silence=no, grunt=yes, jingle=gentle response
       question 3:
         grunt -> yes
         jingle -> paid confession -> yes
         silence -> baited
```

### Arrival

- Use internal Percy narration for the empty-pocket line.
- Branch on `son_defended_self`.
- Cue Clem walking into the right actor slot.
- Set the chapter budget only after the money handoff.
- Phrase-cut the name and Grandma explanation normally.
- Sponsor responses before the opening-up rail do not enter the romantic
  first-jingle reveal. Every one increments `clem_failure_count` and the
  conversation continues.
- Only reveal the caring caller to Clem when Percy retains `my_grandma` or
  the complete `She wanted to know if I had food` thought. Other grammatical
  recombinations, including `It was food`, get `...What?` and must not make
  Clem act on words Percy cut.
- Branch on `grandma_ignored` only after that information was communicated.
- Branch first on `dad_mentioned_family`, then on
  `dad_offended_interviewer`.
- Give the candidate response stable IDs for laugh, cutoff/immigrant, and
  tariff meanings. The tariff meanings take precedence over a retained laugh.

### Opening up

Author a coherent-response predicate for each of the four lines. Do not add a
generic grammar system; four explicit predicates are clearer and match the
handwritten reactions.

On a coherent response:

- say `Go on...`;
- set `percy_opened_up = true`;
- set any topic flags supported by the retained chunks.

On normal delivery with only dependent fragments, say `...What?`.

Silence, grunt, and incoherent paid fragments all advance the same failure
counter, even after Percy has opened up. The third failure sets
`got_the_girl = "no"` and ends the scene. This ladder uses
`clem_overshare_failure_count`, separate from Part I's `clem_failure_count`, so
earlier awkward answers do not skip the first overshare warning or lose their
own tally. `could_afford_speech()` records whether the balance before a delivery
could afford at least one chip on that prompt. A jingle begins Part II whenever
that value is false, without discarding a positive remainder. On the first
disclosure, an affordable voluntary jingle is another failed attempt. On later
disclosures, a jingle also begins Part II after at least one earlier coherent
disclosure has set `percy_opened_up`; otherwise it follows the ordinary failure
ladder. If Percy communicates coherently and reaches exact zero, enter the
required-jingle beat; its first prompt still accepts silence, grunt, or sponsor,
while a refusal advances to the prompt where only the jingle can continue.

After all seven prompts, if no jingle occurred, use the polite exit and set
`got_the_girl = "no"`. This is the conservative-player failure described in
the outline.

### First jingle

The first sponsor delivery during the opening-up rail, including its
required-jingle fallback, converges here and sets `girl_heard_jingle = true`.
Earlier sponsor responses remain failed or teasing conversation beats in
Part I.

Branch on `son_showed_tariff_empathy`, then on Dad's interview outcome:

- `butts`: full flustered exchange and `+5`;
- `soda`: gentler fan exchange and `+5`;
- no tariff empathy: immigrant realization and `+3`.

The nested butts-only line must remain inside the butts branch; the supplied
outline visually nests it under the empathy section but not under soda.
If Percy jingles again during the butts exchange, reuse Clem's `SHUT UP!`
reaction rather than routing the sponsor through dialogue written for silence.

### Post-jingle

- The sponsor grants `$3`.
- The `[One][two][three]` prompt naturally demonstrates that cap.
- Let `[Pretty much.]` spend what remains if affordable.
- Immediately use `@budget 0` after that response so all paths reach the next
  three-option panel at zero, as required by "REGARDLESS".
- Use the normal repeatable recovery responses for the reaction and all three
  questions.
- One silence on the third question is Percy's explicit no and sets
  `got_the_girl = "baited"`.
- The jingle response opens the paid confession follow-up. A grunt receives
  Clem's short confirmation and sets `yes`; silence, another jingle, or any
  paid subset receives the authored romantic payoff and also sets `yes`.

## Budget selection

Do not choose the chapter allotment from raw word totals alone. The early name,
Grandma, and interview responses also spend from Clem's money, so they affect
where the first jingle occurs.

Tune the amount after all phrase boundaries and coherent predicates exist.
Search candidate budgets and choose one satisfying these acceptance rules:

1. A player who communicates coherent information through the intended
   sequence reaches exact zero and the first jingle.
2. A player who repeatedly uses silence, grunt, or extremely cheap fragments
   can still reach the explicit no-jingle failure.
3. No successful `got_the_girl = "yes"` path skips
   `girl_heard_jingle = true`.
4. Any overshare sponsor response begins Part II when the preceding balance
   could not afford a single chip. The insufficient positive remainder remains
   intact; an affordable first-disclosure sponsor is a strike instead of an
   early romantic reveal.
5. Repeated post-jingle sponsor credit cannot become family savings.

The outline's "guarantee" is therefore conditional on talking enough; it
cannot include a player who is deliberately silent, and the outline explicitly
defines that as a failure mode.

## Stage and art

Build a new stage rather than mutating Chapter 3's:

- reference the existing park texture;
- place Percy on the left and Clementine on the right;
- reuse the Pennybot prop;
- start Clem hidden or off-position;
- add `clem_walks_over` and `clem_backs_away` cues;
- optionally add a jingle embarrassment cue/blackout if the existing intro cue
  is not visually reusable.

Percy already has neutral, nervous, sad, shy/blush, and surprised aliases.
Clementine's neutral portrait remains the default; the supplied smile and
frown art now back her `happy`/`smile` and `nervous`/`frown` expressions.

## Downstream integration

Update `content/episodes/neighbors/script.md` to prefer the explicit outcome:

- `got_the_girl == "yes"` -> warm branch;
- `got_the_girl == "baited"` -> chilly/heartbroken branch;
- `got_the_girl == "no"` -> neutral branch;
- `unresolved` -> retain the current score-based fallback for old saves and
  chapter-skipping debug starts.

Keep `girl_heard_jingle` available for later callbacks even though it is
implied by a successful Chapter 4 route.

## Validation and completion criteria

Keep automated coverage focused on the shared behavior:

- retain the compiler's existing `@recovery` checks and add one `budget()`
  translation assertion;
- assert that `@required_delivery sponsor` compiles into the next phrase line
  and visibly disables every competing delivery;
- assert repeated grunt and sponsor use in the existing runtime test;
- assert that the auditor preserves a positive-but-unaffordable remainder;
- run the existing content resource/timeline validation for the new episode.

No separate hand-authored Chapter 4 branch matrix is necessary. The auditor
varies the four incoming flags and verifies reachability of all 20 prompts and
the `no`, `baited`, and `yes` outcomes. Focused semantic assertions cover the
phone-call disclosure, orphan classification, required-jingle lock, and final
confession. During content review, still play one tariff-empathy path and one
positive-but-unaffordable path to confirm the remainder is retained and the
first-overshare jingle gate feels right.

### Final validation

Run:

```sh
python3 tools/compile_dialogue.py
python3 tools/compile_dialogue.py --check
python3 tools/audit_dialogue.py crush \
  --expect-phrase-lines 20 \
  --vary-flag son_defended_self \
  --vary-flag grandma_ignored \
  --vary-flag dad_mentioned_family \
  --vary-flag dad_offended_interviewer
bash scripts/check.sh
```

The audit reports bounded histories for `jingle_confession_answer`; that is an
intentional retry cycle, not an ending.
Manually confirm the stage walk/back-away cues, preserved remainder plus `$3`
sponsor credit, and neighbors callback while reviewing the representative
endings.

## Recommended implementation order

1. Make recovery responses repeatable outside tutorial gating and cover the
   repeatable behavior in the existing runtime checks.
2. Add the Chapter 4 flags and scaffold the episode/stage/campaign route.
3. Author the four source files and compile them.
4. Tune the initial budget against compiled phrase costs.
5. Update the neighbors callback.
6. Run automated validation, then play the three endings and the affordability
   edge case.
