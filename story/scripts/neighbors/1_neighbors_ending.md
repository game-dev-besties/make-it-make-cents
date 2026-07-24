---
cutscene: neighbors
budget: 120
bg: neighbor_house
music: warm
---

// The finale. The family visits their new neighbors — and discovers that
// the crush (Mira), the interviewer (Mr. Reed), and the doctor (Dr. Park)
// are all ONE family. The scene branches on the stats accumulated all day.

## door

mom (happy): We brought cookies! To welcome ourselves to the neighborhood.

interviewer (happy): How lovely! Come in, come in. I'm Reed, this is my wife \
Park, and our daughter Mira.

// The reveal — each neighbor reacts to the family member they met earlier.

if crush.fondness >= 4:
  crush (happy): Wait — you're that sweet kid from the park! Leo!
  son (surprised):
      [Mira]
      [you live here]
  crush (happy): I told you I'd see you tomorrow. Guess it's today!
  -> warm
elif crush.creeped_out >= 3:
  crush (nervous): ...You. You're the one from the park, aren't you.
  son (sad):
      [I'm sorry]
      [I didn't mean]
      [to be strange]
  -> chilly
else:
  crush (neutral): ...Huh. You look familiar. Have we met?
  son (nervous):
      [Maybe]
      [at the park]
  -> neutral_end

## warm

if interviewer.weirded_out >= 2:
  interviewer (confused): Wait — you're the fellow who applied with us. The...
  dad (sad):
      [The overseller]
      [yes]
      [that was me]
      [I'm sorry]
  -> mixed
else:
  interviewer (happy): And you must be Marco! Welcome to the team, neighbor.
  dad (happy):
      [Thank you]
      [Mr Reed]
      [this is wonderful]
  -> good_end

## chilly

interviewer (neutral): Hm. So you're the father. We met at the office, didn't we.

if interviewer.weirded_out >= 2:
  interviewer (nervous): ...Both of you, quite the impression.
  -> bad_end
else:
  interviewer (happy): Marco! Welcome to the team. Don't mind Mira, she's shy.
  dad (happy):
      [Thank you]
      [I appreciate it]
  -> mixed

## neutral_end

interviewer (happy): And you're Marco — welcome to the team, neighbor!
dad (happy):
    [Thank you]
    [so much]
-> good_end

## mixed

mom (happy): What a small world! Let's all have tea.
doctor (happy): Rosa! I didn't expect to see you so soon.
grandma (happy):
    [Dr Park]
    [what a surprise]
-> end

## good_end

mom (happy): What a wonderful welcome. I think we're going to like it here.
doctor (happy): Rosa, nice to see you again! How's the back?
grandma (happy):
    [Much better]
    [thank you doctor]
-> end

## bad_end

mom (sad): Well. Thank you for the cookies... reception.
crush (nervous): ...Please go now.
-> end
