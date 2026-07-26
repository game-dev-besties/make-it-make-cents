# Percy is supposed to overshare until his balance forces the jingle.

## disclosure_uprooted
@sponsor_score 0
@sponsor_text "SAM’S SODA POP IS JUST SODA-MN GOOD!"
son (nervous): [My dad uprooted us.]{id=uprooted} [He sold everything we had.]{id=sold_everything}

if delivery("sponsor") and not could_afford_speech():
  -> first_jingle
elif delivery("sponsor"):
  if flag("clem_overshare_failure_count") == 0:
    crush (nervous): Oh…I don’t think I got that? I’m still listening though, go on.
    SET clem_overshare_failure_count = 1
  elif flag("clem_overshare_failure_count") == 1:
    crush (nervous): Sorry…you’re not making any sense right now…maybe try again one last time?
    SET clem_overshare_failure_count = 2
  else:
    crush (nervous): Um, that didn’t really make much sense…
    crush (nervous): I guess we’re not that similar after all.
    crush (nervous): See you around…
    SET clem_overshare_failure_count = 3
    SET got_the_girl = "no"
    -> end
elif delivery("silence") or delivery("pity"):
  if flag("clem_overshare_failure_count") == 0:
    crush (neutral): Don’t be shy! I’m here to listen.
    SET clem_overshare_failure_count = 1
  elif flag("clem_overshare_failure_count") == 1:
    crush (nervous): ...Do you just not want to talk to me? I’ll give you one more chance…
    SET clem_overshare_failure_count = 2
  else:
    crush (nervous): Okay, well, if you’re just not gonna say anything…
    crush (nervous): I’m just gonna go.
    SET clem_overshare_failure_count = 3
    SET got_the_girl = "no"
    -> end
elif kept("uprooted") or kept("sold_everything"):
  crush (neutral): Go on…
  if not flag("percy_opened_up"):
    SET percy_opened_up = true
  if kept("uprooted"):
    SET son_mentioned_uprooted = true
  if kept("sold_everything"):
    SET son_mentioned_sold_everything = true

## disclosure_grandma
@sponsor_score 0
@sponsor_text "SAM’S SODA POP IS JUST SODA-MN GOOD!"
son (nervous): [My grandma is sick.]{id=grandma_sick} [And Ohio couldn’t help her]{id=ohio_couldnt_help} [and this country has the right medical experts]{id=medical_experts} [so here we are.]{id=here_we_are}

if delivery("sponsor") and (flag("percy_opened_up") or not could_afford_speech()):
  -> first_jingle
elif delivery("silence") or delivery("pity"):
  if flag("clem_overshare_failure_count") == 0:
    crush (neutral): Don’t be shy! I’m here to listen.
    SET clem_overshare_failure_count = 1
  elif flag("clem_overshare_failure_count") == 1:
    crush (nervous): ...Do you just not want to talk to me? I’ll give you one more chance…
    SET clem_overshare_failure_count = 2
  else:
    crush (nervous): Okay, well, if you’re just not gonna say anything…
    crush (nervous): I’m just gonna go.
    SET clem_overshare_failure_count = 3
    SET got_the_girl = "no"
    -> end
elif kept("grandma_sick") or kept("ohio_couldnt_help") or kept("medical_experts"):
  crush (neutral): Go on…
  if not flag("percy_opened_up"):
    SET percy_opened_up = true
  if kept("grandma_sick") or kept("ohio_couldnt_help"):
    SET son_mentioned_grandma_sick = true
else:
  if flag("clem_overshare_failure_count") == 0:
    crush (nervous): Oh…I don’t think I got that? I’m still listening though, go on.
    SET clem_overshare_failure_count = 1
  elif flag("clem_overshare_failure_count") == 1:
    crush (nervous): Sorry…you’re not making any sense right now…maybe try again one last time?
    SET clem_overshare_failure_count = 2
  else:
    crush (nervous): Um, that didn’t really make much sense…
    crush (nervous): I guess we’re not that similar after all.
    crush (nervous): See you around…
    SET clem_overshare_failure_count = 3
    SET got_the_girl = "no"
    -> end

## disclosure_feelings
@sponsor_score 0
@sponsor_text "SAM’S SODA POP IS JUST SODA-MN GOOD!"
son (sad): [I’m mad…no, I’m sad.]{id=mixed_emotion} [I just don’t want to]{id=dont_want} [feel like this.]{id=feel_like_this} [I’m not mad at him]{id=not_mad_at_him} [I’m mad at the situation.]{id=mad_at_situation}

if delivery("sponsor") and (flag("percy_opened_up") or not could_afford_speech()):
  -> first_jingle
elif delivery("silence") or delivery("pity"):
  if flag("clem_overshare_failure_count") == 0:
    crush (neutral): Don’t be shy! I’m here to listen.
    SET clem_overshare_failure_count = 1
  elif flag("clem_overshare_failure_count") == 1:
    crush (nervous): ...Do you just not want to talk to me? I’ll give you one more chance…
    SET clem_overshare_failure_count = 2
  else:
    crush (nervous): Okay, well, if you’re just not gonna say anything…
    crush (nervous): I’m just gonna go.
    SET clem_overshare_failure_count = 3
    SET got_the_girl = "no"
    -> end
elif kept("mixed_emotion") or (kept("dont_want") and kept("feel_like_this")) or kept("not_mad_at_him") or kept("mad_at_situation"):
  crush (neutral): Go on…
  if not flag("percy_opened_up"):
    SET percy_opened_up = true
  SET son_mentioned_mixed_feelings = true
else:
  if flag("clem_overshare_failure_count") == 0:
    crush (nervous): Oh…I don’t think I got that? I’m still listening though, go on.
    SET clem_overshare_failure_count = 1
  elif flag("clem_overshare_failure_count") == 1:
    crush (nervous): Sorry…you’re not making any sense right now…maybe try again one last time?
    SET clem_overshare_failure_count = 2
  else:
    crush (nervous): Um, that didn’t really make much sense…
    crush (nervous): I guess we’re not that similar after all.
    crush (nervous): See you around…
    SET clem_overshare_failure_count = 3
    SET got_the_girl = "no"
    -> end

## disclosure_sacrifice
@sponsor_score 0
@sponsor_text "SAM’S SODA POP IS JUST SODA-MN GOOD!"
son (sad): [The thing is]{id=the_thing_is} [I know why he did it]{id=know_why} [and that’s so much worse]{id=much_worse} [because]{id=because} [how do you stay mad]{id=stay_mad} [at someone who gave up so much]{id=gave_up} [for you?]{id=for_you}

if delivery("sponsor") and (flag("percy_opened_up") or not could_afford_speech()):
  -> first_jingle
elif delivery("silence") or delivery("pity"):
  if flag("clem_overshare_failure_count") == 0:
    crush (neutral): Don’t be shy! I’m here to listen.
    SET clem_overshare_failure_count = 1
  elif flag("clem_overshare_failure_count") == 1:
    crush (nervous): ...Do you just not want to talk to me? I’ll give you one more chance…
    SET clem_overshare_failure_count = 2
  else:
    crush (nervous): Okay, well, if you’re just not gonna say anything…
    crush (nervous): I’m just gonna go.
    SET clem_overshare_failure_count = 3
    SET got_the_girl = "no"
    -> end
elif kept("know_why") or (kept("stay_mad") and kept("gave_up") and kept("for_you")):
  crush (neutral): Go on…
  if not flag("percy_opened_up"):
    SET percy_opened_up = true
  SET son_mentioned_mixed_feelings = true
else:
  if flag("clem_overshare_failure_count") == 0:
    crush (nervous): Oh…I don’t think I got that? I’m still listening though, go on.
    SET clem_overshare_failure_count = 1
  elif flag("clem_overshare_failure_count") == 1:
    crush (nervous): Sorry…you’re not making any sense right now…maybe try again one last time?
    SET clem_overshare_failure_count = 2
  else:
    crush (nervous): Um, that didn’t really make much sense…
    crush (nervous): I guess we’re not that similar after all.
    crush (nervous): See you around…
    SET clem_overshare_failure_count = 3
    SET got_the_girl = "no"
    -> end

## disclosure_normal
@sponsor_score 0
@sponsor_text "SAM’S SODA POP IS JUST SODA-MN GOOD!"
son (sad): [I don’t know...]{id=dont_know} [I just wish]{id=just_wish} [everything was just…normal.]{id=normal} [But I don’t even know]{id=dont_even_know} [what normal is anymore.]{id=what_normal_is}

if delivery("sponsor") and (flag("percy_opened_up") or not could_afford_speech()):
  -> first_jingle
elif delivery("silence") or delivery("pity"):
  if flag("clem_overshare_failure_count") == 0:
    crush (neutral): Don’t be shy! I’m here to listen.
    SET clem_overshare_failure_count = 1
  elif flag("clem_overshare_failure_count") == 1:
    crush (nervous): ...Do you just not want to talk to me? I’ll give you one more chance…
    SET clem_overshare_failure_count = 2
  else:
    crush (nervous): Okay, well, if you’re just not gonna say anything…
    crush (nervous): I’m just gonna go.
    SET clem_overshare_failure_count = 3
    SET got_the_girl = "no"
    -> end
elif kept("dont_know") or (kept("just_wish") and kept("normal")) or (kept("dont_even_know") and kept("what_normal_is")):
  crush (neutral): Go on…
  if not flag("percy_opened_up"):
    SET percy_opened_up = true
else:
  if flag("clem_overshare_failure_count") == 0:
    crush (nervous): Oh…I don’t think I got that? I’m still listening though, go on.
    SET clem_overshare_failure_count = 1
  elif flag("clem_overshare_failure_count") == 1:
    crush (nervous): Sorry…you’re not making any sense right now…maybe try again one last time?
    SET clem_overshare_failure_count = 2
  else:
    crush (nervous): Um, that didn’t really make much sense…
    crush (nervous): I guess we’re not that similar after all.
    crush (nervous): See you around…
    SET clem_overshare_failure_count = 3
    SET got_the_girl = "no"
    -> end

## disclosure_before
@sponsor_score 0
@sponsor_text "SAM’S SODA POP IS JUST SODA-MN GOOD!"
son (sad): [Like, is it]{id=like_is_it} [before Mom left?]{id=before_mom} [Or before]{id=or_before} [Grandma got sick?]{id=grandma_got_sick} [Those moments]{id=those_moments} [just]{id=just} [feel so]{id=feel_so} [far away]{id=far_away} [sometimes.]{id=sometimes}

if delivery("sponsor") and (flag("percy_opened_up") or not could_afford_speech()):
  -> first_jingle
elif delivery("silence") or delivery("pity"):
  if flag("clem_overshare_failure_count") == 0:
    crush (neutral): Don’t be shy! I’m here to listen.
    SET clem_overshare_failure_count = 1
  elif flag("clem_overshare_failure_count") == 1:
    crush (nervous): ...Do you just not want to talk to me? I’ll give you one more chance…
    SET clem_overshare_failure_count = 2
  else:
    crush (nervous): Okay, well, if you’re just not gonna say anything…
    crush (nervous): I’m just gonna go.
    SET clem_overshare_failure_count = 3
    SET got_the_girl = "no"
    -> end
elif (kept("like_is_it") and kept("before_mom")) or (kept("or_before") and kept("grandma_got_sick")) or (kept("those_moments") and kept("feel_so") and kept("far_away")):
  crush (neutral): Go on…
  if not flag("percy_opened_up"):
    SET percy_opened_up = true
  if kept("or_before") and kept("grandma_got_sick"):
    SET son_mentioned_grandma_sick = true
else:
  if flag("clem_overshare_failure_count") == 0:
    crush (nervous): Oh…I don’t think I got that? I’m still listening though, go on.
    SET clem_overshare_failure_count = 1
  elif flag("clem_overshare_failure_count") == 1:
    crush (nervous): Sorry…you’re not making any sense right now…maybe try again one last time?
    SET clem_overshare_failure_count = 2
  else:
    crush (nervous): Um, that didn’t really make much sense…
    crush (nervous): I guess we’re not that similar after all.
    crush (nervous): See you around…
    SET clem_overshare_failure_count = 3
    SET got_the_girl = "no"
    -> end

## disclosure_happiness
@sponsor_score 0
@sponsor_text "SAM’S SODA POP IS JUST SODA-MN GOOD!"
son (sad): [I just wonder]{id=just_wonder} [if]{id=if} [there will ever be]{id=ever_be} [a time]{id=a_time} [I feel happy]{id=feel_happy} [again.]{id=again}

if delivery("sponsor") and (flag("percy_opened_up") or not could_afford_speech()):
  -> first_jingle
elif delivery("silence") or delivery("pity"):
  if flag("clem_overshare_failure_count") == 0:
    crush (neutral): Don’t be shy! I’m here to listen.
    SET clem_overshare_failure_count = 1
  elif flag("clem_overshare_failure_count") == 1:
    crush (nervous): ...Do you just not want to talk to me? I’ll give you one more chance…
    SET clem_overshare_failure_count = 2
  else:
    crush (nervous): Okay, well, if you’re just not gonna say anything…
    crush (nervous): I’m just gonna go.
    SET clem_overshare_failure_count = 3
    SET got_the_girl = "no"
    -> end
elif (kept("feel_happy") and kept_count() == 1) or (kept("feel_happy") and kept("again") and kept_count() == 2) or (kept("just_wonder") and kept("if") and kept("ever_be") and kept("a_time") and kept("feel_happy")):
  crush (neutral): Go on…
  if not flag("percy_opened_up"):
    SET percy_opened_up = true
else:
  if flag("clem_overshare_failure_count") == 0:
    crush (nervous): Oh…I don’t think I got that? I’m still listening though, go on.
    SET clem_overshare_failure_count = 1
  elif flag("clem_overshare_failure_count") == 1:
    crush (nervous): Sorry…you’re not making any sense right now…maybe try again one last time?
    SET clem_overshare_failure_count = 2
  else:
    crush (nervous): Um, that didn’t really make much sense…
    crush (nervous): I guess we’re not that similar after all.
    crush (nervous): See you around…
    SET clem_overshare_failure_count = 3
    SET got_the_girl = "no"
    -> end

if budget() == 0 and flag("percy_opened_up"):
  -> required_jingle
else:
  -> polite_exit

## required_jingle
@recovery pity,sponsor
@sponsor_score 0
@sponsor_text "SAM’S SODA POP IS JUST SODA-MN GOOD!"
son (nervous): […]{id=required_jingle}

if delivery("sponsor"):
  -> first_jingle
else:
  crush (neutral): Go on…
  -> forced_jingle

## forced_jingle
@recovery pity,sponsor
@required_delivery sponsor
@sponsor_score 0
@sponsor_text "SAM’S SODA POP IS JUST SODA-MN GOOD!"
son (nervous): […]{id=forced_jingle}

if delivery("sponsor"):
  -> first_jingle

## polite_exit
crush (neutral): Well, nice to meet you… I’m going to head out now.
SET got_the_girl = "no"
-> end
