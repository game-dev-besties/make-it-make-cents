---
cutscene: dad
budget: 100
bg: office
music: tense
---

// Dad (Marco) goes through a job interview with Mr. Reed.
// Mr. Reed is secretly the neighbor family's father.

## intro

interviewer (neutral): Good morning. Have a seat. Let's begin.

dad (nervous): okay...

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
      [we just moved here]
      [and money is tight]
  interviewer (happy): I appreciate the honesty. That takes courage.
  interviewer.impression += 3
  -> skills

- "Oversell yourself aggressively"
  dad (confident):
      [I am]
      [the best]
      [candidate]
      [you will ever meet]
      [guaranteed]
  interviewer (confused): ...Right.
  interviewer.impression -= 2
  interviewer.weirded_out += 2
  -> skills

## skills

interviewer (neutral): What experience do you have?

dad (nervous):
    [I worked]
    [for ten years]
    [back home]
    [in logistics]
    [and management]

interviewer (happy): That's exactly what we need. You're a strong candidate.

interviewer.impression += 2

-> outro

## outro

if interviewer.weirded_out >= 2:
  interviewer (nervous): We'll be in touch. ...Eventually.
else:
  interviewer (happy): Welcome to the team, Marco. You start Monday.

-> end
