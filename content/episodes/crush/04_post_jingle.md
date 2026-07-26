# Clem now understands that every jingle buys Percy only three words.

crush (neutral): So you dance for Big Sam, you sing about how you’re a sucker for their Soda, la la la, great.
crush (neutral): How many words does that give you?

@sponsor_score 0
@sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
son (neutral): [One.]{id=one} [Two.]{id=two} [Three.]{id=three}

if delivery("sponsor") or delivery("pity") or delivery("silence"):
  crush (neutral): Okay, not much. I can see that.

crush (neutral): So basically, every sentence, you go bankrupt again.

@sponsor_score 0
@sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
son (neutral): [Pretty much.]{id=pretty_much}

@budget 0
crush (happy): (giggles)

@recovery pity,sponsor
@sponsor_score 0
@sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
son (shy): […]{id=post_jingle_response}

if delivery("sponsor"):
  crush (nervous): Oh my god, you didn’t have to-
elif delivery("pity"):
  crush (nervous): Okay, that “hnf” was kind of-
  crush (neutral): Ahem, …nothing. Forget it. It was a good hnf. MOVING ON.
elif delivery("silence"):
  crush (nervous): …you just said a whole lot of nothing and somehow… that’s a lot.
  crush (neutral): Cool. Cool cool cool.

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
crush (happy): Okay, new rule! I talk, and you don’t spend a thing.
crush (neutral): Saying nothing means no, grunting means yes.
crush (neutral): Question one, do you hate it here?

@budget 0
@recovery pity,sponsor
@sponsor_score 0
@sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
son (neutral): [Yes.]{id=yes}

if delivery("pity"):
  crush (neutral): Yeah, me too, sometimes…
  crush (neutral): I try not to.
elif delivery("silence"):
  crush (happy): …No? Huh!
  crush (neutral): Either you’re an optimist or you haven’t met the neighbors yet.
elif delivery("sponsor"):
  crush (happy): (laughs) What are you— no, answer the question, dummy! That one’s free!

crush (neutral): Question two… was any of the stuff you said back there stuff that you told anyone before?

@budget 0
@recovery pity,sponsor
@sponsor_score 0
@sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
son (neutral): [Yes.]{id=yes}

if delivery("pity"):
  crush (neutral): Ah okay, I was worried that I was hearing something I wasn’t supposed to. Good to know I’m not stealing your secrets.
elif delivery("silence"):
  crush (nervous): …Didn’t think so.
elif delivery("sponsor"):
  crush (neutral): (gentle) Percy… you don’t have to hide behind that with me. I shouldn’t have asked. I already know the answer, it’s okay.

crush (neutral): Question three, last one.
crush (nervous): Do you want to keep talking to me? Even if it’s three words at a time?

@budget 0
@recovery pity,sponsor
@sponsor_score 0
@sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
son (shy): [Yes.]{id=yes}

if delivery("pity"):
  -> yes_outcome
elif delivery("sponsor"):
  -> jingle_confession
else:
  crush (nervous): …Nothing?
  crush (nervous): I’m asking again, okay?
  @budget 0
  @recovery pity,sponsor
  @sponsor_score 0
  @sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
  son (shy): [Yes.]{id=yes}
  if delivery("pity"):
    -> yes_outcome
  elif delivery("sponsor"):
    -> jingle_confession
  else:
    crush (nervous): Percy…
    crush (nervous): One last time.
    @budget 0
    @recovery pity,sponsor
    @sponsor_score 0
    @sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
    son (shy): [Yes.]{id=yes}
    if delivery("pity"):
      -> yes_outcome
    elif delivery("sponsor"):
      -> jingle_confession
    else:
      crush (nervous): Oh… right.
      crush (nervous): No, that’s- that’s fair. I talk a lot.
      @cue clem_backs_away
      crush (nervous): See you around…
      SET got_the_girl = "baited"
      -> end

## yes_outcome
crush (happy): Yeah?
crush (happy): …Okay. Okay, good. I’m glad.
SET got_the_girl = "yes"
-> end

## jingle_confession
crush (nervous): You- that wasn’t a yes or no! What does that even mean??

## jingle_confession_answer
@budget 3
@sponsor_score 0
@sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
son (shy): [Yes.]{id=yes} [Three words at a time]{id=three_words} [for]{id=for} [as long as]{id=as_long} [you’ll let me.]{id=let_me} [Please don’t make me jingle for that too…]{id=please}

if delivery("pity"):
  -> yes_outcome
elif delivery("silence"):
  crush (nervous): Percy… I still need an answer.
  -> jingle_confession_answer
elif delivery("sponsor"):
  crush (happy): That is still not a yes or no, soda guy!
  -> jingle_confession_answer

crush (nervous): You could’ve just grunted!
crush (nervous): Instead you stood in the middle of the street and threw out your heart and dignity for Big Sam…
crush (happy): …all so you could say more than a grunt? For me?
crush (happy): …That’s the single sweetest, dumbest thing anyone’s done for me.
SET got_the_girl = "yes"
-> end
