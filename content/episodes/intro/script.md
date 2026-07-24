# Border tutorial proof slice. Keep this short while the scene art is evolving.

@cue intro_reveal
The line has not moved in forty minutes. Nobody in it has uttered a single word.
dad: Son, the second we cross that line, you do not say one word.
son (neutral): What? Why?
dad: The Verbal Tariff Act. Non-citizens get billed by the word.
son (shy): Understood. Somehow that is not the strangest part of moving.

@cue center_focus
dad: That is why we brought Penny. She trims what you say before it gets expensive.
penny: Good morning, son of Dad.
son (shy): [Hello,]{id=hello} [my name is Leo.]{id=name} [I am]{id=i_am} [pleased to be]{id=pleased} [here]{id=here} [in your beautiful country.]{id=beautiful}

if delivery("silence"):
  dad: Sweet, sweet nothing. Free, flexible, and impossible to misquote.
elif kept("hello") and kept("name") and kept_count() == 2:
  dad: You are getting the hang of it.
elif kept("beautiful"):
  dad: Did you seriously pay to call this parking lot beautiful?
else:
  dad: A little scrambled, but cheap. You will get the hang of it.

dad: Okay, one more. The customs officer asks whether you have anything to declare.
son (neutral): [No,]{id=no} [I don’t]{id=dont} [think]{id=think} [so.]{id=so} [What counts]{id=what_counts} [as a declaration?]{id=declaration}

if delivery("sponsor"):
  dad: The sponsor bought you three words, but that sales pitch tanked your score.
elif delivery("pity"):
  dad: One free grunt. Spend it with dignity.
elif delivery("silence"):
  dad: Exactly. They cannot tax what Penny never says.
else:
  dad: That works, but remember: saying nothing is always free.

dad: Last check. Tell the officer we are ready.
son (neutral): [Ready]{id=ready} [to go.]{id=go}

if delivery("sponsor"):
  dad: Three more words, one worse first impression. That is the trade.
elif delivery("pity"):
  dad: The grunt is gone now. Next time, silence or the sponsor.
elif delivery("silence"):
  dad: Frugal to the end. I respect it.
else:
  dad: There. If the sponsor refilled three words, that is exactly where they went.

-> end
