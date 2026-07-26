# Percy is supposed to overshare until his balance forces the jingle.

## disclosure_uprooted
@sponsor_score 0
@sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
son (nervous): [My dad]{id=my_dad} [uprooted us]{id=uprooted} [and sold everything we had]{id=sold_everything}

if delivery("sponsor"):
  -> first_jingle
elif delivery("silence") or delivery("pity"):
  if flag("percy_opened_up"):
    -> required_jingle
  else:
    -> cold_exit
elif kept("my_dad") and (kept("uprooted") or kept("sold_everything")):
  crush (neutral): Go on…
  if not flag("percy_opened_up"):
    SET percy_opened_up = true
  if kept("uprooted"):
    SET son_mentioned_uprooted = true
  if kept("sold_everything"):
    SET son_mentioned_sold_everything = true
else:
  crush (nervous): …What?

## disclosure_grandma
@sponsor_score 0
@sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
son (nervous): [My grandma is sick.]{id=grandma_sick} [And Ohio couldn’t help her]{id=ohio_couldnt_help} [and this country has the right medical experts]{id=medical_experts} [so here we are.]{id=here_we_are}

if delivery("sponsor"):
  -> first_jingle
elif delivery("silence") or delivery("pity"):
  if flag("percy_opened_up"):
    -> required_jingle
  else:
    -> cold_exit
elif kept("grandma_sick") or ((kept("ohio_couldnt_help") or kept("medical_experts")) and kept("here_we_are")):
  crush (neutral): Go on…
  if not flag("percy_opened_up"):
    SET percy_opened_up = true
  if kept("grandma_sick") or kept("ohio_couldnt_help"):
    SET son_mentioned_grandma_sick = true
else:
  crush (nervous): …What?

## disclosure_feelings
@sponsor_score 0
@sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
son (sad): [I’m mad.]{id=mad} [No.]{id=no} [I’m sad.]{id=sad} [I just don’t want to]{id=dont_want} [feel like this.]{id=feel_like_this} [I’m not mad at him.]{id=not_mad_at_him} [I’m mad at the situation.]{id=mad_at_situation}

if delivery("sponsor"):
  -> first_jingle
elif delivery("silence") or delivery("pity"):
  if flag("percy_opened_up"):
    -> required_jingle
  else:
    -> cold_exit
elif kept("mad") or kept("sad") or kept("not_mad_at_him") or kept("mad_at_situation") or (kept("dont_want") and kept("feel_like_this")):
  crush (neutral): Go on…
  if not flag("percy_opened_up"):
    SET percy_opened_up = true
  SET son_mentioned_mixed_feelings = true
else:
  crush (nervous): …What?

## disclosure_sacrifice
@sponsor_score 0
@sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
son (sad): [The thing is,]{id=the_thing_is} [I know why he did it.]{id=know_why} [And that’s so much worse.]{id=much_worse} [How do you stay mad]{id=stay_mad} [at someone who gave up so much]{id=gave_up} [for you?]{id=for_you}

if delivery("sponsor"):
  -> first_jingle
elif delivery("silence") or delivery("pity"):
  if flag("percy_opened_up"):
    -> required_jingle
  else:
    -> cold_exit
elif kept("know_why") or (kept("stay_mad") and kept("gave_up") and kept("for_you")):
  crush (neutral): Go on…
  if not flag("percy_opened_up"):
    SET percy_opened_up = true
  SET son_mentioned_mixed_feelings = true
else:
  crush (nervous): …What?

if budget() == 0 and flag("percy_opened_up"):
  -> required_jingle
else:
  -> polite_exit

## required_jingle
@recovery pity,sponsor
@sponsor_score 0
@sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
son (nervous): […]{id=required_jingle}

if delivery("sponsor"):
  -> first_jingle
else:
  crush (neutral): Go on…
  -> required_jingle

## cold_exit
crush (nervous): Uh… I’m going to go.
SET got_the_girl = "no"
-> end

## polite_exit
crush (neutral): Well, nice to meet you… I’m going to head out now.
SET got_the_girl = "no"
-> end
