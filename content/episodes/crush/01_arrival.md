# Chapter 4: Son Talks 2 Gril

@speaker_name crush "Clementine"
SET son_showed_tariff_empathy = false
SET girl_heard_jingle = false
SET percy_opened_up = false
SET son_mentioned_uprooted = false
SET son_mentioned_sold_everything = false
SET son_mentioned_grandma_sick = false
SET son_mentioned_mixed_feelings = false
SET got_the_girl = "unresolved"

CHECK son_defended_self == true as percy_spent_everything_defending_himself:
  son (nervous): (Kasdkfjaskdlfjaslkdjfalksdjfalskdfj… I let my pride get the better of me and I blew all my money to get back at that bully…)

CHECK son_defended_self == false as percy_suspects_the_bully_took_his_money:
  son (nervous): (Huh, my pockets are empty… that bully! Did he take my money while I wasn’t looking?)

@cue clem_walks_over
@wait 0.75
crush (neutral): That was ugly earlier.
son (nervous): (She saw the whole thing…)

CHECK son_defended_self == true as clem_saw_percy_stand_up_for_himself:
  crush (happy): You gave it right back, though. That was fun to watch.

CHECK son_defended_self == false as clem_respected_percys_restraint:
  crush (neutral): I liked that, you didn’t give him the show he wanted.

crush (neutral): (slides money over) You ran out of money back there too. Here you go.
@budget 18
crush (neutral): Name’s Clem, by the way.
@speaker_name crush "Clem"

@sponsor_score 0
@sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
son (shy): [I’m]{id=im} [Percy.]{id=percy}

if delivery("sponsor"):
  -> first_jingle

crush (neutral): I know your name, dummy. The teacher introduced you, like, four hours ago.

son (shy): (She remembered? But she wasn’t even looking at me.)
crush (neutral): Anyway, that phone call, what was that about? That bully was too busy braying at his stupid Ohio jokes for me to even ask til now.

@sponsor_score 0
@sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
son (nervous): [It was]{id=it_was} [my grandma.]{id=my_grandma} [She wanted]{id=she_wanted} [to know]{id=to_know} [if I had]{id=if_i_had} [food.]{id=food}

if delivery("sponsor"):
  -> first_jingle
elif kept("my_grandma") or (kept("she_wanted") and kept("to_know") and kept("if_i_had") and kept("food")):
  CHECK grandma_ignored == true as percy_ignored_someone_who_cares_about_him:
    crush (nervous): And you let it ring out?!
    crush (nervous): When someone cares enough about you to check up on you, how could you ignore them like that?
    son.success -= 1

  CHECK grandma_ignored == false as percy_answered_grandmas_call:
    crush (neutral): That’s nice, I wish I had that.
else:
  crush (nervous): …What?

crush (neutral): My dad barely acknowledges my existence.
crush (neutral): He’s really good at his line of work; he treats it as the most important thing any man can do.
crush (neutral): He gets upset when others don’t treat… paper… paper! …with the reverence he thinks it deserves.
crush (neutral): When one of his reports asked for paternity leave, he threatened to terminate him and said, “I suppose we can’t choose our family. When you’re a true Paperboxer, Paperbox IS family.”

CHECK dad_mentioned_family == true as clems_dad_mocked_marcos_family_answer:
  crush (neutral): As a matter of fact, he said this to an interview candidate this morning!
  crush (neutral): The candidate said he left his job because the workload was too heavy for him to see his family.
  crush (nervous): My dad told me it was the most pathetic excuse he’d heard in years.

CHECK dad_mentioned_family == false as clems_dad_interviewed_marco:
  crush (neutral): As a matter of fact, he interviewed a candidate this morning!

CHECK dad_offended_interviewer == "soda" as clem_describes_the_soda_candidate:
  crush (neutral): The candidate was… psychotically obsessed with Sam’s Soda.
  crush (happy): (snorts)
  crush (neutral): Can you believe that? My dad came home convinced the guy had lost his mind.
  @sponsor_score 0
  @sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
  son (nervous): [Ha,]{id=laugh} [that’s hilarious.]{id=hilarious} [He was]{id=he_was} [probably]{id=probably} [an immigrant.]{id=immigrant} [The tariff]{id=tariff} [does that.]{id=does_that}
  if delivery("sponsor"):
    -> first_jingle
  elif kept("immigrant") or (kept("tariff") and kept("does_that")):
    crush (nervous): …Huh.
    crush (nervous): I was laughing and you’re saying…
    crush (neutral): You’re right, it sucks how big gov turned these immigrants into billboards for Sam’s Soda, and everyone just points and laughs.
    crush (neutral): Most people here wouldn’t have caught that, even I forgot.
    son.success += 3
    SET son_showed_tariff_empathy = true
  elif kept("laugh") or kept("hilarious"):
    crush (happy): I know, crazy!

CHECK dad_offended_interviewer == "butts" as clem_describes_the_butts_candidate:
  crush (neutral): The candidate, quoting my dad here, “would not stop bringing up his own butt.”
  crush (happy): Can you believe that? That was one of the few times I saw my dad so flustered…
  @sponsor_score 0
  @sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
  son (nervous): [Ha,]{id=laugh} [that’s hilarious.]{id=hilarious} [He]{id=he} [probably]{id=probably} [got cut off]{id=cut_off} [if]{id=if} [he was an immigrant.]{id=immigrant} [The tariff]{id=tariff} [does that.]{id=does_that}
  if delivery("sponsor"):
    -> first_jingle
  elif kept("cut_off") or kept("immigrant") or (kept("tariff") and kept("does_that")):
    crush (nervous): …Oh. So he probably wasn’t being a creep, he was just getting tariffed…
    son.success += 3
    SET son_showed_tariff_empathy = true
  elif kept("laugh") or kept("hilarious"):
    crush (happy): I know, crazy!

CHECK dad_offended_interviewer == "none" as clem_hopes_her_dad_was_kind:
  crush (neutral): When he came home and I asked how it went, he looked at me like he’d forgotten I lived there.
  crush (neutral): Whoever the poor guy was, I hope my dad was kind to him.

crush (neutral): My dad can be hardheaded, and I’m not sure I always agree with him…
crush (neutral): …
crush (nervous): God, I dumped my entire childhood on some random guy I met.
crush (neutral): I still don’t know a thing about you.
crush (neutral): Your turn. You’ve barely talked this whole time, and I don’t like it.
