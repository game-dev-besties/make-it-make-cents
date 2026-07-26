# Clem now understands that every jingle buys Percy only three words.

crush (neutral): So you dance for Big Sam, you sing about how you’re a sucker for their Soda, la la la, great.
crush (neutral): How many words does that give you?

## word_count
@sponsor_score 0
@sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
son (neutral): [One]{id=one} [two]{id=two} [three.]{id=three}

if delivery("silence") or delivery("sponsor"):
  crush (neutral): Okay, not that many. I can see that.
elif delivery("pity"):
  crush (nervous): Huh? How many?
  -> word_count
elif kept_count() == 1 or kept_count() == 3:
  crush (neutral): So basically, every sentence, you go bankrupt again.

  @sponsor_score 0
  @sponsor_text "BOP TO THE TOP WITH SAM’S SODA POP!"
  son (neutral): [Pretty much.]{id=pretty_much}

  if kept("pretty_much"):
    crush (nervous): Wow. So that means you’re down to nothing again?
  elif delivery("silence"):
    crush (nervous): …you just said a whole lot of nothing and somehow… that’s a lot.
    crush (neutral): Cool. Cool cool cool.
  elif delivery("pity"):
    crush (nervous): Okay, that “hnf” was kind of-
    crush (neutral): Ahem, …nothing. Forget it. It was a good hnf. MOVING ON.
  elif delivery("sponsor"):
    crush (happy): Pffft, you didn’t have to—
    crush (neutral): Must mean you’re zeroed out again, right?
else:
  crush (nervous): Huh? How many?
  -> word_count

@budget 0
crush (neutral): That’s a bummer… I really wanted to ask you about a lot of things.

if flag("son_mentioned_uprooted"):
  crush (neutral): Like what’s it like to get pulled out of your previous life?
  crush (neutral): I’ve only ever been stuck in one place, I really want to see more of the world…

if flag("son_mentioned_sold_everything"):
  crush (neutral): What does it feel like to lose something?

if flag("son_mentioned_grandma_sick"):
  crush (neutral): Your grandma, does she know how much got moved around for her?

if flag("son_mentioned_mixed_feelings"):
  crush (neutral): I wanted to ask you about how you can stand to be mad and sad and grateful, all at once.
  crush (nervous): I feel awful when people are kind to me and I can’t help feeling angry anyway, see…
  crush (nervous): I hate feeling like that, because I feel like a bad person.

crush (neutral): How to make it suck less, huh…
crush (happy): Okay, new rule! I talk, and you don’t spend a thing if you don’t want to.
crush (neutral): Saying nothing means no, grunting means yes.
crush (neutral): Question one, do you hate it here?

@budget 0
@recovery pity,sponsor
@sponsor_score 0
@sponsor_text "YOU! CAN’T! STOP! SAM’S SODA POP!"
son (neutral): [I did at first…]{id=did_at_first}

if kept("did_at_first"):
  crush (neutral): Yeah, me too, sometimes…
  crush (neutral): …
  crush (happy): I hope you find a reason not to hate it here.
elif delivery("pity"):
  crush (neutral): Yeah, me too, sometimes…
  crush (neutral): I try not to.
elif delivery("silence"):
  crush (happy): …No? Huh!
  crush (neutral): You must be a lot more optimistic than me.
elif delivery("sponsor"):
  crush (happy): What are you- no, answer the question, dummy! That one’s free!

crush (neutral): Question two… was any of the stuff you said back there stuff that you told anyone before?

@budget 0
@recovery pity,sponsor
@sponsor_score 0
@sponsor_text "PRICES BE DROPPIN’ WHILE SAM’S SODA POPPIN’!"
son (nervous): [Sorry, I didn’t mean to overshare…]{id=sorry_overshare}

if kept("sorry_overshare"):
  crush (nervous): No, don’t apologize! I guess we both have that in common. Just nice to have someone that listens, right?
elif delivery("pity"):
  crush (neutral): Ah okay, I was worried that I was hearing something I wasn’t supposed to. Good to know I’m not stealing your secrets.
elif delivery("silence"):
  crush (nervous): …Didn’t think so.
elif delivery("sponsor"):
  crush (neutral): Percy… you don’t have to hide behind that with me. I shouldn’t have asked. I already know the answer, it’s okay.

crush (neutral): Question three, last one.
crush (nervous): Do you want to keep talking to me? Even if it’s three words at a time?

@budget 0
@recovery pity,sponsor
@sponsor_score 0
@sponsor_text "EVERY SINGLE DROP OF SAM’S SODA POP IS THE CREAM OF THE CROP!"
son (shy): [Of course I want to talk to you.]{id=want_to_talk}

if kept("want_to_talk") or delivery("pity"):
  crush (happy): …yeah?
  crush (happy): …Okay. Okay, good. I’m glad.
  SET got_the_girl = "yes"
  -> end
elif delivery("silence"):
  crush (nervous): Oh… right.
  crush (nervous): No, that’s- that’s fair. I guess we’re not as similar as I thought.
  @cue clem_backs_away
  crush (nervous): See you around…
  SET got_the_girl = "baited"
  -> end
elif delivery("sponsor"):
  crush (nervous): You– that wasn’t a yes or no! What does that even mean??

@budget 3
@sponsor_score 0
@sponsor_text "OH MAN, I GOTTA COP THAT SAM’S SODA POP!"
son (shy): [Yes.]{id=yes} [Three words at a time]{id=three_words} [for]{id=for} [as long as]{id=as_long} [you’ll let me.]{id=let_me} [Please don’t make me jingle for that too...]{id=please}

if delivery("pity"):
  crush (nervous): ...yes? That’s a yeah, right?
  crush (happy): …Okay. Okay, good. I’m glad.
  SET got_the_girl = "yes"
  -> end
elif delivery("silence") or delivery("sponsor"):
  crush (nervous): You didn’t have to do the jingle at all! You could’ve just grunted!
else:
  crush (nervous): You didn’t need to spend any money! You could’ve just grunted!

crush (nervous): Instead you stood in the middle of the street and threw out your heart and dignity for Big Sam…
crush (happy): …all so you could say more than a grunt? For me?
crush (happy): …That’s the single sweetest, dumbest thing anyone’s done for me.
SET got_the_girl = "yes"
-> end
