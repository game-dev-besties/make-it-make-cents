## first_jingle
SET girl_heard_jingle = true
@budget 3

CHECK son_showed_tariff_empathy == true as clem_realizes_percy_defended_another_immigrant:
  crush (nervous): You’re an immigrant too?!
  crush (neutral): I guess that makes sense. I was wondering what that flying robot was for. I’ve not seen one of this make before.
  crush (neutral): This whole time, you were defending that guy my dad laughed at…

  CHECK dad_offended_interviewer == "butts" as percy_was_the_butts_candidate:
    crush (nervous): So you weren’t pitying the butts guy, because…
    crush (nervous): You were the butts guy.
    crush (nervous): (flustered) Oh- I uh- I don’t mean butts guy in that way.
    crush (nervous): I mean-
    crush (nervous): Shut up, you know what I mean.
    @sponsor_score 0
    @sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
    son (shy): [Do I?]{id=do_i} [hnf]{id=hnf}
    if kept("do_i"):
      crush (nervous): SHUT UP!
    else:
      @sponsor_score 0
      @sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
      son (shy): [I said nothin’.]{id=said_nothing}
      if kept("said_nothing"):
        crush (nervous): Shuddup.
        son (shy): ;)
      else:
        crush (nervous): Shut up!!! Your “nothing” is… is obnoxious.
        crush (nervous): (…especially with that look…)
        son (shy): (๑˃ᴗ˂)ﻭ
    son.success += 5

  CHECK dad_offended_interviewer == "soda" as percy_was_the_soda_candidate:
    crush (nervous): So you weren’t pitying the soda guy, because…
    crush (nervous): You were the soda guy.
    crush (neutral): (gently) How many times have you had to do that?
    crush (happy): …I think I might be a fan.
    @sponsor_score 0
    @sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
    son (shy): [hnf]{id=hnf}
    crush (happy): Don’t let it go to your head, soda guy.
    son.success += 5

CHECK son_showed_tariff_empathy == false as clem_learns_percy_is_an_immigrant:
  crush (nervous): …You’re an immigrant?
  crush (neutral): They only make you do the soda jingle when you’re down to nothing.
  crush (neutral): You didn’t have to let me see that. Most people would’ve clammed up and gone home. (I’ve seen many such cases…)
  crush (happy): …Okay, I get it now.
  son.success += 3

@budget 3
