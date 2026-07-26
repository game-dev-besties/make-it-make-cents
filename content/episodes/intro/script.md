# Chapter 1 — Welcome to the Country
#
# This is a playable draft. Lines marked DRAFT/TODO can change without
# changing the tutorial mechanics or story-state contract.

@cue intro_reveal
The line has not moved in forty minutes. Nobody in it has uttered a single word.
dad (neutral): Percy, the second we cross that line, [speed=2]you do not say one word.[speed]
son (surprised): What? Why?
dad (neutral): Well, that Verbal Tariff Act is a real son of a gun. Non-citizens get billed by the word.
dad (neutral): Leadership could not repay the war debt, so somebody bought the country.
son (surprised): Somebody bought them? You can buy a country?
dad (happy): Yes! Sam’s Soda Pop Company bought them.
dad (neutral): Now the state charges thousands of people this crazy tax on their own mouths, and every dollar goes to a beverage company in Atlanta.
son (surprised): That’s insane!
son (neutral): Understood. I hate it, but understood.
dad (neutral): So anything you want to say to me, say it now, before “I love you” bills us three dollars.

son (neutral): …
son (neutral): …
son (neutral): …
son (sad): I didn’t want to move! Ohio was FINE! Grandma hates it here already!
Grandma does not respond.
son (sad): See? Even Grandma agrees!
son (sad): Why does Kayla get to stay in Ohio and why must I move with you?
son (sad): Kayla got to keep her car and I got to keep NOTHING.
son (sad): I don’t get to see my friends, I’m going to get mega bullied for having a personality in a country of beige idiots where everybody’s beige and quiet and dressed like hospital patients!
Grandma is, unmistakably, dressed like a hospital patient.
dad (happy): That right there would have cost us seventy-seven dollars!
dad (happy): “I love you” is three dollars. That speech was twenty-five and two-thirds “I love yous.”
dad (happy): Good thing you got it out on the American side, bud. Cheapest therapy in the hemisphere.

@cue penny_reveal
dad (happy): We cannot do things the Ohio way anymore, so I got us a Moneybot to assist with speech.
son (surprised): You brought a robot to the border? Are you sure this thing works?
dad (happy): We’re about to find out.
son (nervous): This stupid robot is going to ruin my life. I can feel it in my BODY!

# Tutorial 1 — basic phrase deletion.
dad (neutral): Okay, here’s how she works.
dad (happy): Good morning, Moneybot.
dad (happy): Moneybot, say hi to my son.
penny: Hi, son of Dad.
@recovery none
son (shy): [Hello,]{id=hello} [my name is Percy.]{id=name} [I am]{id=i_am} [pleased to be]{id=pleased} [here]{id=here} [in your beautiful country.]{id=beautiful}

if delivery("silence"):
  dad (happy): Hah. Very careful of you.
  dad (neutral): Promise me you won’t go mute on me, bud. A couple bucks to say hello never bankrupted anybody.
elif kept("beautiful"):
  dad (neutral): Did you seriously pay to call this parking lot beautiful?
elif kept("hello") and kept("name") and kept_count() == 2:
  dad (happy): You’re getting the hang of it.
else:
  dad (neutral): Your message is a little scrambled at the moment, but you’ll get the hang of it.

dad (neutral): See those chunks? Every word has a price. You can sink fifteen dollars just being polite.
dad (neutral): So you CUT. Cut until it is cheap and still means the thing.
son (nervous): So Moneybot just deletes chunks of what I say?
dad (neutral): You can yell and scream all you want. Everybody else only hears the part we paid for.
son (nervous): S-scary…

# Tutorial 2 — silence is always an option.
dad (neutral): Okay, try this one.
dad (neutral): The customs officer asks whether you have anything to declare.
@recovery none
son (neutral): [No,]{id=no} [I don’t]{id=dont} [think]{id=think} [so.]{id=so} [What counts]{id=what_counts} [as a declaration?]{id=declaration}

if delivery("silence"):
  dad (happy): THAT. That right there! You did the nothing!
else:
  dad (neutral): That’s all right, but you could have said nothing.
  son (surprised): How do they tell what I meant, then?
  dad (neutral): They don’t. It can mean no, yes, or “I agree, and my father is dead.”

dad (happy): Sweet, sweet nothing. It’s free and it means anything.
son (neutral): So I use it when I want to mean something without paying, and hope people understand?
dad (happy): You got it. Even your grandma has been doing it since the airport!

- I don’t think she’s doing it to save money.
  intro.grandma_praised_for_silence = false
  son (sad): I don’t think she’s doing it to save money…
  dad (sad): …Nah. She’s just tired from the flight.
- You’re right.
  intro.grandma_praised_for_silence = true
  son (neutral): You’re right. She has not spent a dollar since Dayton.
  dad (happy): Not ONE dollar. Woman’s a natural!

# Tutorial 3 — zero-budget recovery.
son (neutral): Okay, what if we run out of money?
dad (neutral): Then you have three options, and you are not going to like two of them.
dad (neutral): One, say nothing. Sweet, sweet nothing. Always free, always available.
dad (neutral): Two, the Tariff Office extends one complimentary grunt to accounts in desperation.
dad (neutral): Moneybot, switch us to the zero-dollar practice balance.
@budget 0

## try_pity_grunt
@recovery pity
son (nervous): [I need]{id=need} [to answer.]{id=answer}

if delivery("pity"):
  dad (neutral): Hnf, yeah. It means “I acknowledge you, and I’m broke.”
  dad (neutral): You only get one. After that, it is silence or the sponsor.
else:
  dad (happy): Sweet nothing is the cheapest option, but don’t be shy. Try the complimentary grunt once.
  -> try_pity_grunt

son (surprised): And the third option?
dad (neutral): Tariff relief. The state pays for your words if your words are an advertisement.
son (surprised): An ad? For what?
dad (neutral): Remember how Sam’s Soda Pop Company bought the country?
dad (neutral): When you shill Sam’s Soda Pop, [speed=2]it puts money back in your account.[speed]
dad (neutral): Not much, but enough.
son (neutral): If it’s free money, why are you even looking for a job? Why don’t we all just shill—
dad (sad): Because everybody will know the state paid for your sentence because your family could not.
dad (sad): They’ll be polite. That is the worst part. They won’t say how broke your daddy is, but they will think it.
dad (neutral): Also, the jingle is the single most humiliating noise a human can produce.

## try_sponsor
@recovery sponsor
son (nervous): [Can we]{id=can_we} [afford]{id=afford} [one more sentence?]{id=sentence}

if delivery("sponsor"):
  -> sponsor_aftermath
else:
  dad (happy): Silence is smarter, but this is a demonstration. Press the sponsor button and hear the shame for yourself.
  -> try_sponsor

## sponsor_aftermath
@cue sponsor_blackout
The Sam’s Soda Pop jingle plays. It is worse than advertised.
@wait 0.8
@cue sponsor_return
son (surprised): …Oh my God.
dad (neutral): Yeah. Now you know what it sounds like.
son (nervous): A hundred people have turned around to look at me.
son (nervous): They are appalled, but nobody says anything because that would cost them money.

# DRAFT optional customs-and-pills beat. It proves that the chapter can carry
# a gameplay result into its closing scene without requiring officer artwork.
@cue customs_focus
officer: Are these prescription medications declared?
dad (nervous): They belong to my mother.
officer: Then declare them clearly.
son (nervous): [They are]{id=they_are} [Grandma’s]{id=grandmas} [prescription]{id=prescription} [pills.]{id=pills}

if kept("prescription") and kept("pills"):
  intro.pills_confiscated = false
  officer: Clear enough. You may keep them.
else:
  intro.pills_confiscated = true
  officer: I cannot verify that declaration. The medication stays here.

# Closing — reveal the next three family goals.
@cue home_reveal
@wait 0.5
dad (happy): All right, son. We’re here!
dad (happy): Welcome to our new home.
son (neutral): The house is beige. The lawn is beige.
son (neutral): Except…

@cue clementine_reveal
son (shy): That girl in black and violet is the first thing in this country that is not beige.
son (shy): I want to ask who she is, but that would cost—
@cue clementine_exit
grandma (neutral): My pills…

if intro.pills_confiscated:
  son (sad): Oh, right. The customs officer confiscated them.
else:
  dad (neutral): Here you go, Mom.

dad (neutral): Mom, I’ll find a doctor. Right after I find a job.
son (neutral): Right. Grandma needs a doctor, and Dad needs a job. Best I don’t blow our budget.
son (shy): I’ll talk to that girl another day.

-> end
