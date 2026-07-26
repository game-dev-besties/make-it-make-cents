# Chapter 3: Percy's Opponent

SET son_said_soda = false
SET grandma_ignored = false
SET son_defended_self = false

son (nervous): (First day at school…ugh. And I have to use this dumb bot…)
bully (neutral): Yo, new kid! What’s that dumb bot you have hanging around you?

## question_1
@sponsor_text "I NEVER LEAVE THE HOUSE WITHOUT SAM’S SODA POP!"
son (nervous): [The only]{id=only} [dumb]{id=dumb} [thing]{id=thing} [around here]{id=around} [is]{id=is} [your face]{id=face}.

if delivery("sponsor"):
  bully (neutral): That thing sure doesn’t look like soda. What are you even talking about, loser?
  SET son_said_soda = true
elif delivery("silence") or delivery("pity"):
  bully (neutral): Trying to ignore me? Guess you’re just too scared to speak up.
  son.success -= 1
elif kept("dumb") and kept("thing") and kept("face"):
  bully (angry): M-my face is fine! My mom says I look beautiful!
  son.success += 3
elif kept("face") and kept_count() == 1:
  bully (neutral): What about it, huh? Sure looks a lot better than yours.
  son.success -= 1
elif (kept("dumb") and kept_count() == 1) or (kept("dumb") and kept("thing") and kept_count() == 2):
  bully (neutral): Yeah, that’s what I said. Thing’s dumb, just like you.
else:
  bully (neutral): Wow, I can see why you needed to move schools. Clearly they didn’t teach you how to talk properly over there. That didn’t make ANY sense.
  son.success -= 2

bully (neutral): Wait a second, that’s that Pennybot non-citizens have to use to speak, ha! So you can’t even speak up to defend yourself?

## question_2
@sponsor_text "SAM’S SODA POP BE POPPING ALL THE TIME!"
son (nervous): [I can]{id=i_can} [speak]{id=speak} [better]{id=better} [than]{id=than} [you]{id=you}. [You have]{id=you_have} [the vocabulary of]{id=vocabulary} [a brick]{id=brick}.

if delivery("sponsor"):
  bully (neutral): Hahaha, that’s GOLD! You’re just a walking advertisement! Sam’s Soda Pop buy you off, huh? What’d it cost, $2? Ha!
  SET son_said_soda = true
elif delivery("silence") or delivery("pity"):
  bully (neutral): Ha, that’s GOLD! Maybe you should start using that lunch money of yours on some actual WORDS.
  son.success -= 2
elif kept("vocabulary") and kept("brick") and ((kept("better") and kept("than") and kept("you") and (removed("i_can") or kept("speak"))) or (kept("you_have") and kept_count() == 3) or kept_count() == 2):
  bully (angry): That’s not true, I know a lot of big words! Like…like…you’re a dumb loser!
  son.success += 3
elif (kept("i_can") and kept("speak") and kept("better") and kept("than") and kept("you") and kept_count() == 5) or (kept("speak") and kept("better") and kept("than") and kept("you") and kept_count() == 4) or (kept("better") and kept("than") and kept("you") and kept_count() == 3):
  bully (neutral): Wow, congratulations for stringing together something that actually makes sense. Do you want a prize?
  son.success += 2
elif (kept("i_can") and kept("speak") and kept("better") and kept("than") and kept("brick") and kept_count() == 5) or (kept("speak") and kept("better") and kept("than") and kept("brick") and kept_count() == 4):
  bully (neutral): Am I supposed to be scared? Ha!
  son.success -= 1
elif (kept("i_can") and kept_count() == 1) or (kept("i_can") and kept("speak") and kept_count() == 2) or (kept("i_can") and kept("speak") and kept("better") and kept_count() == 3):
  bully (neutral): Yeah, barely. Guess you can’t afford an actual brain, either.
  son.success -= 1
elif kept("speak") and kept("better") and kept_count() == 2:
  bully (neutral): You’re telling ME to speak better? That’s rich! Which apparently you aren’t!
elif kept("you_have") and kept("brick") and removed("vocabulary"):
  bully (angry): What are you even talking about? I don’t have a brick. If I did, I would throw it at you!
  son.success += 1
else:
  bully (neutral): Better use some cents to make some sense because you’re not making neither! Get it? Ha!
  son.success -= 2

bully (neutral): Anyway, I heard you were from OHIO, ha!
bully (neutral): …
bully (neutral): That’s it. That’s the insult.

## question_3
@sponsor_text "SAAAAAM’S SODA POP! AVAILABLE IN A STORE NEAR YOU!"
son (nervous): [What’s wrong with]{id=whats_wrong} [Ohio?]{id=ohio} [Ohio is]{id=ohio_is} [not]{id=not} [that bad]{id=bad}.

if delivery("sponsor"):
  bully (neutral): Yeah, you’re a real soda lover, aren’tcha? All those bubbles clearly rose to your head.
  SET son_said_soda = true
elif delivery("silence") or delivery("pity"):
  bully (neutral): Too ashamed to speak? I would be, too.
elif kept_count() == 5 or (kept("whats_wrong") and kept("ohio") and kept_count() == 2) or (kept("whats_wrong") and kept("ohio") and kept("not") and kept("bad") and kept_count() == 4):
  bully (neutral): You’re really gonna try to defend Ohio of all places? Ha! Even I know that’s a bad financial decision.
  son.success -= 1
elif (kept("bad") and kept_count() == 1) or (kept("ohio_is") and kept("bad") and kept_count() == 2) or (kept("ohio") and kept("bad") and kept_count() == 2) or (kept("ohio") and kept("ohio_is") and kept("bad") and kept_count() == 3):
  bully (neutral): Ha…at least you’re self-aware about it. I’d go broke if it meant getting out of there, too.
  son.success += 2
elif (kept("ohio_is") and kept("not") and kept("bad") and kept_count() == 3) or (kept("not") and kept("bad") and kept_count() == 2) or (kept("ohio") and kept("not") and kept("bad") and kept_count() == 3) or (kept("ohio") and kept("ohio_is") and kept("not") and kept("bad") and kept_count() == 4):
  bully (neutral): Suuuuuure. And you’re not a broke kid who can’t even speak without the help of Nannybot 3000!
elif kept("ohio") and kept_count() == 1:
  bully (neutral): Yeah, that’s what I said. Didn’t you hear me? Do you need to pay to listen to each word now, too?
  son.success -= 1
else:
  bully (neutral): Yeah…you’re not making any sense. Ohio will do that to you.
  son.success -= 2

@cue incoming_call
Percy’s Pennybot buzzes. Incoming call from Grandma.

## question_4
@sponsor_text "POP POP POP! WHAT’S THAT? MUST BE SAM’S SODA POP!"
son (nervous): [Hello?]{id=hello} [Grandma?]{id=grandma}

if delivery("sponsor"):
  bully (neutral): You’re shilling out soda to any random call now? How desperate ARE you?
  SET grandma_ignored = true
  SET son_said_soda = true
elif delivery("silence") or delivery("pity"):
  bully (neutral): Who’s that, huh? The bank calling about your single-digit balance? Bet you couldn’t even afford to ask for a loan!
  son.success -= 2
  SET grandma_ignored = true
elif kept("grandma"):
  bully (neutral): Oh no! Your grandma’s calling? Do you want her to pick you up from school? Maybe hold your hand while you cry into some cookies? Ha!
  son.success -= 1
  SET grandma_ignored = false
elif kept("hello") and kept_count() == 1:
  bully (angry): Trying to ignore me, huh? You’ll pay for that! Literally!
  SET grandma_ignored = false

@cue dismiss_call
bully (neutral): Your balance must be looking real low right now. Do you need me to spot you a couple pennies? I’m sure those would be a life-saver for you!

## question_5
@sponsor_text "SAM’S SODA POP IS CHEAPER THAN EVER BEFORE! ONLY $9.99 A CASE!"
son (nervous): [My balance is completely, utterly, absolutely, fine. It has literally never been better.]{id=balance} [I’m]{id=im} [not]{id=not} [stupid]{id=stupid}, [I wouldn’t]{id=wouldnt} [blow it all]{id=blow} [on you]{id=on_you}.

if delivery("sponsor"):
  bully (neutral): I’m almost starting to feel sorry for you. Being this broke can’t be easy. You can’t even afford a case of the soda you’re raving on about.
  SET son_said_soda = true
elif delivery("silence") or delivery("pity"):
  bully (neutral): Aw, poor thing. Don’t even have a dollar left to spend, huh? Classic Ohio.
  son.success -= 2
elif kept("balance") and flag("son_said_soda"):
  bully (neutral): Maybe, but only because you’re just a Sam’s Soda SLAVE!
  son.success += 2
elif kept("balance"):
  bully (angry): …Oh.
  son.success += 10
elif (kept("wouldnt") and kept("blow")) or (kept("not") and kept("stupid")):
  bully (neutral): Huh, guess you didn’t blow ALL of it. Congrats to you on not being broke and whatever.
  son.success += 2
elif kept("stupid"):
  bully (neutral): Yeah, glad we’re in agreement about your intelligence! Hey, we always need more people like you around to help the curve, right? HA!
  son.success -= 3
elif kept("not") and kept_count() == 1:
  bully (neutral): Not? You mean no? It sure seems like you need every penny you can get!
  son.success -= 2
else:
  bully (neutral): Wow, you STILL haven’t got the hang of using Nannybot 3000 to talk, huh? That made no sense.
  son.success -= 2

## outcome
if son.success >= 5:
  SET son_defended_self = true
else:
  SET son_defended_self = false

CHECK son_defended_self == true as son_stood_up_to_the_bully:
  bully (angry): Whatever.
  bully (angry): I didn’t want to talk to boring losers like you anyway.
  bully (angry): …
  bully (angry): (I’m not gonna mess with that guy again…I’m lucky no one saw that.)

CHECK son_defended_self == false as son_will_be_bullied_again:
  bully (neutral): Well, it was nice talking to you!
  bully (neutral): You saved me a LOT of effort making fun of you.
  bully (neutral): You basically just bullied yourself with that bot! I didn’t even have to try!
  bully (neutral): We’re gonna have a REALLY fun school year together, HAHA!

-> end
