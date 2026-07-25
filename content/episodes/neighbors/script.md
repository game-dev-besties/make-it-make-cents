# The families discover how their conversations overlap.

## door
mom (happy): We brought cookies! To welcome ourselves to the neighborhood.
interviewer (happy): How lovely! Come in, come in. I'm Clementine's dad, this is her mom, and you already know our daughter.

if crush.fondness >= 4:
  crush (happy): Wait — you're that sweet kid from the park! Percy!
  son (surprised): [Clementine] [you live here]
  crush (happy): I told you I'd see you tomorrow. Guess it's today!
  -> warm
elif crush.creeped_out >= 3:
  crush (nervous): ...You. You're the one from the park, aren't you.
  son (sad): [I'm sorry] [I didn't mean] [to be strange]
  -> chilly
else:
  crush (neutral): ...Huh. You look familiar. Have we met?
  son (nervous): [Maybe] [at the park]
  -> neutral_end

## warm
if dad.success > 5:
  interviewer (happy): And you must be our new hire! Welcome to the team, neighbor.
  dad (happy): [Thank you] [sir] [this is wonderful]
  -> good_end
elif dad.silly >= 3:
  interviewer (happy): And here is our new creative hire. I knew you looked familiar.
  dad (happy): [I look forward] [to Monday]
  -> good_end
elif interviewer.weirded_out >= 2:
  interviewer (confused): Wait — you're the fellow who applied with us. The...
  dad (sad): [The overseller] [yes] [that was me] [I'm sorry]
  -> mixed
else:
  interviewer (neutral): I am afraid the position was not the right fit.
  dad (sad): [I understand] [thank you for considering me]
  -> mixed

## chilly
interviewer (neutral): Hm. So you're the father. We met at the office, didn't we.
if dad.success > 5:
  interviewer (happy): Welcome to the team! Don't mind Clementine, she's shy.
  dad (happy): [Thank you] [I appreciate it]
  -> mixed
elif dad.silly >= 3:
  interviewer (happy): Our unexpected creative hire. Quite the family.
  dad (happy): [That is us]
  -> mixed
elif interviewer.weirded_out >= 2:
  interviewer (nervous): ...Both of you, quite the impression.
  -> bad_end
else:
  interviewer (neutral): We did. I am afraid I do not have better news about the position.
  -> bad_end

## neutral_end
if dad.success > 5:
  interviewer (happy): And you're our new hire — welcome to the team, neighbor!
  dad (happy): [Thank you] [so much]
  -> good_end
elif dad.silly >= 3:
  interviewer (happy): And you are our new creative hire. Small world.
  dad (happy): [Very small] [indeed]
  -> good_end
else:
  interviewer (neutral): And I recognize you from the office.
  dad (nervous): [Good evening] [sir]
  -> mixed

## mixed
mom (happy): What a small world! Let's all have tea.
doctor (happy): There is my patient! I didn't expect to see you so soon.
grandma (happy): [Doctor] [what a surprise]
-> end

## good_end
mom (happy): What a wonderful welcome. I think we're going to like it here.
doctor (happy): Nice to see you again! How's the back?
grandma (happy): [Much better] [thank you doctor]
-> end

## bad_end
mom (sad): Well. Thank you for the cookies... reception.
crush (nervous): ...Please go now.
-> end
