# Chapter 6: Dinner with the neighbors.

@speaker_name crush "Clementine"
@speaker_name penny "Pennybot 3000"
@background res://content/episodes/intro/wall.png

dad (neutral): Alright, everybody, how was your day?
dad (nervous): Oh, wait! No time for talk! We’re late to the neighbors’ place for dinner!
dad (happy): I’m excited to meet them, are you?
son (neutral): Not really…

@cue neighbors_transition_out
@wait 0.4
@background res://content/episodes/neighbors/reeds_home.png
@cue neighbors_transition_in
@wait 0.65

son (surprised): !!
crush (nervous): !!
crush (nervous): YOU’RE my neighbor?

CHECK got_the_girl != "yes" as percy_did_not_connect_with_clementine:
  crush (nervous): Ugh…great.
  crush (nervous): As if I wanted to see more of you…

CHECK got_the_girl == "yes" as percy_connected_with_clementine:
  crush (happy): I can’t believe it!
  crush (happy): I guess that means we’ll be hanging out a lot.
  crush (happy): Pretty exciting, huh?

@cue hosts_enter
@wait 0.5

interviewer (nervous): You…!

CHECK dad_offended_interviewer == "soda" as dad_offended_the_interviewer_with_soda:
  interviewer (nervous): …
  interviewer (neutral): Are you here for more soda?

CHECK dad_offended_interviewer == "butts" as dad_offended_the_interviewer_with_butts:
  interviewer (nervous): Let’s hope you have a more appropriate conversation topic than “butts” this time…

CHECK dad_offended_interviewer == "none" as dad_did_not_offend_the_interviewer:
  interviewer (happy): Our new hire! What a coincidence!
  interviewer (happy): Welcome to the family, neighbor!

@cue grandma_returns
@wait 0.4

doctor (neutral): Oh, hello. I didn’t think I would live right next to one of my patients.

CHECK got_prescription == true as grandma_received_her_prescription:
  doctor (happy): I hope the new medication is working out for you!

CHECK got_prescription == false as grandma_did_not_receive_her_prescription:
  doctor (neutral): I hope the new medication is working…
  doctor (neutral): Sorry I couldn’t be more help…
  doctor (neutral): (This is so awkward.)

CHECK dad_offended_interviewer == "none" as dinner_starts_warmly:
  interviewer (happy): Well, let’s eat!

CHECK dad_offended_interviewer != "none" as dinner_starts_awkwardly:
  interviewer (neutral): Alright, then…let’s eat.

@cue dinner_fade
@wait 0.5
@background res://content/episodes/intro/wall.png
@cue back_at_home
@wait 0.65

Back at home…

CHECK dad_offended_interviewer == "none" as dad_enjoyed_dinner:
  dad (happy): Wow, what a load of fun! I can’t believe we have such nice neighbors!

CHECK dad_offended_interviewer != "none" as dad_found_dinner_awkward:
  dad (neutral): Well…that was awkward. I don’t think we’ll be invited over again.

CHECK got_the_girl == "yes" as percy_enjoyed_dinner_with_clem:
  son (shy): I’ll definitely be over a lot.
  son (shy): I had so much fun talking to Clem.

CHECK got_the_girl != "yes" as percy_regrets_missing_his_chance:
  son (sad): Clem was glaring at me the whole time…
  son (sad): I wish I hadn’t missed my chance with her…

CHECK got_prescription == true as grandma_enjoyed_dinner_with_the_doctor:
  grandma (happy): I THOUGHT THAT WENT WONDERFULLY! THAT DOCTOR LADY IS ACTUALLY QUITE NICE.

CHECK got_prescription == false as grandma_resented_the_doctor:
  grandma (neutral): THAT DOCTOR LADY IS A SHAM! SHE WOULDN’T MEET MY EYES THE ENTIRE MEAL!

son (surprised): W-woah there, Grandma. That was pretty loud. This place has changed you.
grandma (neutral): HAS IT? I DIDN’T REALIZE.

if flag("dad_offended_interviewer") == "none":
  if flag("got_the_girl") == "yes":
    if flag("got_prescription"):
      dad (happy): Huh, so since it seems that all of us are happy here…
      -> staying_ending
    else:
      dad (happy): Huh, so since it seems that most of us are happy here…
      -> staying_ending
  elif flag("got_prescription"):
    dad (happy): Huh, so since it seems that most of us are happy here…
    -> staying_ending
  else:
    dad (neutral): Huh, so since it seems that only one of us is happy here…
    -> ohio_ending
elif flag("got_the_girl") == "yes":
  if flag("got_prescription"):
    dad (happy): Huh, so since it seems that most of us are happy here…
    -> staying_ending
  else:
    dad (neutral): Huh, so since it seems that only one of us is happy here…
    -> ohio_ending
elif flag("got_prescription"):
  dad (neutral): Huh, so since it seems that only one of us is happy here…
  -> ohio_ending
else:
  dad (sad): Huh, so since it seems that none of us are happy here…
  -> ohio_ending

## staying_ending
SET family_stays = true
dad (happy): I have some good news.
dad (happy): I’m upgrading our Pennybot 3000!
dad (happy): I think we’re finally settled in. We’re staying here for good!

CHECK got_the_girl != "yes" as percy_is_unhappy_about_staying:
  son (sad): Just great…

CHECK got_prescription == false as grandma_is_unhappy_about_staying:
  grandma (neutral): WITH THAT INCOMPETENT DOCTOR LADY? GUESS I’LL JUST DIE THEN…

@speaker_name penny "Pennybot 4000"
@cue pennybot_reveal
@wait 0.4
penny: Good job, little robot! Looks like they’re here to stay because of you.
-> end

## ohio_ending
SET family_stays = false
dad (neutral): I have some good news.
dad (neutral): We’re moving back to Ohio.
dad (neutral): I thought this Verbal Tariff Act stuff would teach us important lessons, but it’s just too darn hard!

CHECK got_the_girl == "yes" as percy_is_unhappy_about_leaving:
  son (sad): But…Clem…

CHECK got_prescription == true as grandma_is_unhappy_about_leaving:
  grandma (neutral): BUT…MY MEDICATION! GUESS I’LL JUST DIE THEN…

@speaker_name penny "Scrap Parts"
@cue pennybot_reveal
@wait 0.4
penny: That robot is going straight to the garbage. You couldn’t even do better than Ohio.
-> end
