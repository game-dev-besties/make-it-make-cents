# Chapter 4: Percy and Clementine

@speaker_name crush "Clementine"
SET son_showed_tariff_empathy = false
SET girl_heard_jingle = false
SET percy_opened_up = false
SET son_mentioned_uprooted = false
SET son_mentioned_sold_everything = false
SET son_mentioned_grandma_sick = false
SET son_mentioned_mixed_feelings = false
SET clem_failure_count = 0
SET clem_overshare_failure_count = 0
SET got_the_girl = "unresolved"

CHECK son_defended_self == true as percy_spent_everything_defending_himself:
  son (nervous): (Kasdkfjaskdlfjaslkdjfalksdjfalskdfj… I let my pride get the better of me and I blew all my money to get back at that bully…)

CHECK son_defended_self == false as percy_suspects_the_bully_took_his_money:
  son (nervous): Huh, my pockets are empty… that bully! Did he take my money while I wasn’t looking?

@cue clem_walks_over
@wait 0.75
crush (neutral): That was ugly earlier.
son (nervous): (She saw the whole thing…)

CHECK son_defended_self == true as clem_saw_percy_stand_up_for_himself:
  crush (happy): You gave it right back, though. That was fun to watch.

CHECK son_defended_self == false as clem_respected_percys_restraint:
  crush (neutral): I liked that, you didn’t give him the show he wanted.

crush (neutral): (slides money over) You ran out of money back there too. Here you go.
@budget 21
crush (neutral): Name’s Clem, by the way.
@speaker_name crush "Clem"

@sponsor_score 0
@sponsor_text "SAM’S THE NAME AND SODA POP IS MY GAME!"
son (shy): [I’m]{id=im} [Percy.]{id=percy}

if delivery("sponsor"):
  crush (nervous): ...Okay. Prrrrrretty sure your name is Percy. The teacher introduced you, like, four hours ago.
  SET clem_failure_count = 1
elif delivery("silence") or delivery("pity"):
  crush (nervous): Y-you don’t have to say your name. I know it’s Percy. The teacher introduced you, like, four hours ago.
  SET clem_failure_count = 1
elif kept("percy"):
  crush (neutral): I know your name, dummy. The teacher introduced you, like, four hours ago.
else:
  crush (nervous): Huh? It’s okay. I know your name’s Percy anyway. The teacher introduced you, like, four hours ago.
  SET clem_failure_count = 1

son (shy): (She remembered? But she wasn’t even looking at me.)

crush (neutral): Anyway, that phone call, what was that about? That bully was too busy braying at his stupid Ohio jokes for me to even ask til now.

@sponsor_score 0
@sponsor_text "SAM’S SODA POP CAN’T BE STOPPED!"
son (nervous): [My grandma.]{id=my_grandma} [Grandma wanted to know if I had food.]{id=grandma_food}

if delivery("sponsor"):
  crush (happy): Ha…okay. Funny. I probably shouldn’t have tried to pry, it’s just…
  if flag("clem_failure_count") == 0:
    SET clem_failure_count = 1
  elif flag("clem_failure_count") == 1:
    SET clem_failure_count = 2
  else:
    SET clem_failure_count = 3
elif delivery("silence") or delivery("pity"):
  crush (neutral): It’s okay. I know all about wanting to keep things private. Sometimes I just feel like…
  if flag("clem_failure_count") == 0:
    SET clem_failure_count = 1
  elif flag("clem_failure_count") == 1:
    SET clem_failure_count = 2
  else:
    SET clem_failure_count = 3
elif delivery("normal"):
  CHECK grandma_ignored == true as percy_ignored_someone_who_cares_about_him:
    crush (nervous): And you let it ring out?!
    crush (nervous): When someone cares enough about you to check up on you, how could you ignore them like that?
    if flag("clem_failure_count") == 0:
      SET clem_failure_count = 1
    elif flag("clem_failure_count") == 1:
      SET clem_failure_count = 2
    else:
      SET clem_failure_count = 3

  CHECK grandma_ignored == false as percy_answered_grandmas_call:
    crush (neutral): That’s nice, I wish I had that.

crush (neutral): My dad barely acknowledges my existence.
crush (neutral): He’s really good at his line of work—he treats it as the most important thing any man can do.
crush (neutral): He gets upset when others don't treat… paper…PAPER! …with the reverence he thinks it deserves.
crush (neutral): When one of his employees asked for paternity leave, he threatened to terminate him.
crush (neutral): He said, “When you’re a true Paperboxer, Paperbox IS family.”
crush (neutral): As a matter of fact, he interviewed a candidate this morning!

CHECK dad_mentioned_family == true as clems_dad_mocked_marcos_family_answer:
  crush (neutral): The candidate said he left his job because the workload was too heavy for him to see his family.
  crush (nervous): My dad told me it was the most pathetic excuse he'd heard in years.

CHECK dad_offended_interviewer == "soda" as clem_describes_the_soda_candidate:
  crush (neutral): The candidate was… psychotically obsessed with Sam’s Soda Pop.
  crush (happy): (snorts)
  crush (neutral): Can you believe that? My dad came home convinced the guy had lost his mind.
  @sponsor_score 0
  @sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
  son (nervous): [That’s hilarious.]{id=hilarious} [He was]{id=he_was} [probably]{id=probably} [an immigrant.]{id=immigrant} [The tariff]{id=tariff} [does that.]{id=does_that}
  if (kept("he_was") and kept("immigrant")) or (kept("probably") and kept("immigrant")) or kept("tariff"):
    crush (nervous): …Huh. I forgot about the tariff.
    crush (nervous): I was laughing and you’re saying…
    crush (neutral): You’re right, it sucks how big gov turned these immigrants into billboards for Sam’s Soda, and everyone just points and laughs.
    crush (neutral): Most people here wouldn't have caught that, even I forgot.
    SET son_showed_tariff_empathy = true
  elif kept("hilarious"):
    crush (happy): I know, crazy!
  elif delivery("silence"):
    crush (neutral): ...yeah, I’d be speechless too!
    if flag("clem_failure_count") == 0:
      SET clem_failure_count = 1
    elif flag("clem_failure_count") == 1:
      SET clem_failure_count = 2
    else:
      SET clem_failure_count = 3
  elif delivery("sponsor"):
    crush (happy): Yeah, just like that! That was a really good impression.
    if flag("clem_failure_count") == 0:
      SET clem_failure_count = 1
    elif flag("clem_failure_count") == 1:
      SET clem_failure_count = 2
    else:
      SET clem_failure_count = 3
  else:
    crush (nervous): Um…not really sure I understood that? I hope I’m not boring you. I just don’t really have anyone to talk to.
    if flag("clem_failure_count") == 0:
      SET clem_failure_count = 1
    elif flag("clem_failure_count") == 1:
      SET clem_failure_count = 2
    else:
      SET clem_failure_count = 3

CHECK dad_offended_interviewer == "butts" as clem_describes_the_butts_candidate:
  crush (neutral): The candidate, quoting my dad here, “would not stop bringing up his own butt.”
  crush (happy): Can you believe that? That was one of the few times I saw my dad so flustered…
  @sponsor_score 0
  @sponsor_text "SAM’S SODA POP! A SUCKER FOR SODA, THAT’S ME!"
  son (nervous): [That’s hilarious.]{id=hilarious} [He was]{id=he_was} [probably]{id=probably} [an immigrant.]{id=immigrant} [The tariff]{id=tariff} [does that.]{id=does_that}
  if (kept("he_was") and kept("immigrant")) or (kept("probably") and kept("immigrant")) or kept("tariff"):
    crush (nervous): Oh…so he probably wasn’t a creep. It was just the tariff!
    SET son_showed_tariff_empathy = true
  elif kept("hilarious"):
    crush (happy): I know, crazy!
  elif delivery("silence"):
    crush (neutral): ...yeah, I’d be speechless too!
    if flag("clem_failure_count") == 0:
      SET clem_failure_count = 1
    elif flag("clem_failure_count") == 1:
      SET clem_failure_count = 2
    else:
      SET clem_failure_count = 3
  elif delivery("sponsor"):
    crush (nervous): Oh, um…cool. Nice of you to share, I guess.
    if flag("clem_failure_count") == 0:
      SET clem_failure_count = 1
    elif flag("clem_failure_count") == 1:
      SET clem_failure_count = 2
    else:
      SET clem_failure_count = 3
  else:
    crush (nervous): Um…not really sure I understood that? I hope I’m not boring you. I just don’t really have anyone to talk to.
    if flag("clem_failure_count") == 0:
      SET clem_failure_count = 1
    elif flag("clem_failure_count") == 1:
      SET clem_failure_count = 2
    else:
      SET clem_failure_count = 3

CHECK dad_offended_interviewer == "none" as clem_hopes_her_dad_was_kind:
  crush (neutral): When he came home and I asked how it went, and he looked at me like he'd forgotten I lived there.
  crush (neutral): Whoever the poor guy was, I hope my dad was kind to him.

if flag("clem_failure_count") >= 3:
  crush (nervous): I was hoping to have a genuine conversation, but I guess if you’re not going to take me seriously…
  crush (nervous): I’m just going to head out now.
  SET got_the_girl = "no"
  -> end

crush (neutral): My dad can be hardheaded, and I’m not sure I always agree with him…
crush (neutral): …
crush (nervous): God, I didn’t mean to kill the vibes by talking about myself the whole time.
crush (neutral): I still don’t know a thing about you.
crush (neutral): Your turn. You’ve barely talked this whole time, and I don’t like it.
