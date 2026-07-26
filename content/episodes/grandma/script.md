# Chapter 5: Grandma visits the doctor.

SET got_prescription = false

doctor (neutral): Hello, Mrs. Leiton. It’s nice to finally meet you. Please, take a seat. What brings you here today?

## question_1
@sponsor_score -3
@sponsor_text "I JUST CAN’T STOP THINKING ABOUT SAM’S SODA POP!"
grandma (hospital): [WHY DON’T YOU]{id=why_dont_you} [TAKE A WILD GUESS,]{id=wild_guess} [LADY?]{id=lady} [I’M]{id=im} [AT A]{id=at_a} [DOCTOR’S OFFICE!]{id=doctors_office}

if delivery("sponsor"):
  doctor (neutral): …Okay. That is certainly unusual. I’m not sure that accounts for a doctor’s appointment, but I’ll try my best to figure out what you need.
elif delivery("silence") or delivery("pity"):
  doctor (neutral): My apologies, I forgot about your condition. I have you marked as trying to find the right prescription for new medication.
  grandma.success += 1
elif kept_count() == 6:
  doctor (neutral): Ha, I-I guess you’re right…wow, wasn’t expecting such a…strong voice of yours.
  grandma.success -= 2
elif kept("wild_guess") and removed("im") and removed("at_a") and removed("doctors_office"):
  doctor (neutral): Oh. Well, I suppose you’re here to talk about the medication we called about.
  grandma.success += 2
elif kept("lady") and kept_count() == 1:
  doctor (neutral): A lady…brought you here? That’s very nice of her. Tell her I said thank you.
elif (kept("doctors_office") and kept_count() == 1) or (kept("at_a") and kept("doctors_office") and kept_count() == 2) or (kept("im") and kept("at_a") and kept("doctors_office") and kept_count() == 3):
  doctor (neutral): Yes…that’s where we are right now. Nevermind.
  grandma.success -= 1
else:
  doctor (neutral): Ah…sorry, I’m not exactly sure what you mean. But, let’s see here…I have you marked as trying to find the right prescription for new medication.
  grandma.success += 1

doctor (neutral): Let’s get started, shall we? Can I take a look at your previous prescription pills?

CHECK has_meds == false as grandma_does_not_have_her_previous_pills:
  doctor (neutral): Ah…I see you don’t have them with you.
  doctor (neutral): I suppose we’ll have to start from scratch, then.

CHECK has_meds == true as grandma_has_her_previous_pills:
  doctor (happy): Ah, I see you have them right here! Glad you didn’t have any trouble taking them across the border.

doctor (neutral): I just need some more information about you first. Do you have any family history of disease?

## question_2
@sponsor_score -3
@sponsor_text "FEELING THIRSTY? IN NEED OF FIZZ? TRY SAM’S SODA POP NOW!"
grandma (hospital): [NOT THAT I KNOW OF.]{id=no_history} [ALTHOUGH]{id=although} [I THINK]{id=i_think} [MY SON]{id=my_son} [MIGHT HAVE]{id=might_have} [BRAIN DAMAGE]{id=brain_damage} [BECAUSE]{id=because} [HE DRAGGED US ALL HERE]{id=dragged_here} [FOR NO REASON!]{id=no_reason}

if delivery("sponsor"):
  doctor (neutral): Oh…thank you for thinking about me, but I want to focus on you right now, not soda. We’ll come back to this question another time if soda’s all that’s on your mind.
elif delivery("silence") or delivery("pity"):
  doctor (neutral): …Okay, so you don’t want to talk about it. I understand it might be hard, but I do need to know eventually…
  grandma.success -= 2
elif kept("my_son") and kept("brain_damage") and kept("dragged_here"):
  doctor (neutral): Ah…haha. Yes, family can be very difficult. A big environmental change can sometimes worsen your health. I’ll make note of that in your records.
  grandma.success += 2
elif kept("brain_damage") and removed("dragged_here"):
  doctor (neutral): Oh! Oh no…that is very unfortunate. I’m so sorry. Brain damage…hmm…I’ll make note of that in your records.
  grandma.success -= 2
elif kept("no_history") and kept_count() == 1:
  doctor (happy): Excellent. That’s always good to hear. I’ll make note of that in your records.
  grandma.success += 2
elif kept("my_son") and kept_count() == 1:
  doctor (neutral): Your son…is the disease? Or, no, you meant your son has a disease? Surely the latter, ha ha. I’ll make note of that in your records.
  grandma.success += 1
elif (kept("dragged_here") and kept_count() == 1) or (kept("dragged_here") and kept("no_reason") and kept_count() == 2):
  doctor (neutral): Who? Where? I think your meaning might have gotten a little mixed up there.
  grandma.success -= 3
else:
  doctor (neutral): Oh…I’m sorry, I didn’t really understand that. Maybe we’ll come back to it another time.
  grandma.success -= 2

doctor (neutral): Alright…next on the list…do you have any allergies?

## question_3
@sponsor_score -2
@sponsor_text "SAAAAAAAM’S SODA POP! POP! POP! POP!"
grandma (hospital): [I’M ALLERGIC TO]{id=allergic_to} [SLOW, INCOMPETENT PEOPLE]{id=slow_people} [LIKE]{id=like} [YOU!]{id=you} [PICK UP THE PACE,]{id=pick_up_pace} [LADY!]{id=lady}

if delivery("sponsor"):
  doctor (neutral): So you’re allergic to Sam’s Soda…I see. It’s quite unfortunate that you moved here, then. Well, I can’t help you with that.
elif delivery("silence") or delivery("pity"):
  doctor (neutral): I’ll…take that as a no? Are you allergic to speech? No, that can’t be right…Um. I’ll just mark you down as none.
  grandma.success -= 1
elif kept("slow_people") and kept("like") and kept("you") and kept("pick_up_pace"):
  doctor (neutral): E-excuse me! That’s—I’m just—alright. I know this can be a frustrating process, but please stay patient. I’m only trying to help you.
  grandma.success -= 2
elif kept("slow_people") and kept("like") and kept("you") and removed("pick_up_pace"):
  doctor (neutral): I-I’m sorry. I’m only trying to help. Figuring out your prescription takes time. I promise you I am very competent though, if you just give me a chance…
  grandma.success -= 2
elif kept("slow_people") and not (kept("like") and kept("you")):
  doctor (happy): Ha ha…that’s a good one. Wouldn’t we all agree some people should be a little faster? I can see where you’re coming from.
  grandma.success += 2
elif (kept("allergic_to") and kept("lady") and kept_count() == 2) or (kept("lady") and kept_count() == 1):
  doctor (neutral): Huh? I’ve never heard of a “lady” allergy before. If you so insist, though, I guess I’ll make note of it…
elif kept("pick_up_pace") and removed("allergic_to") and removed("slow_people") and removed("like"):
  doctor (neutral): I-I’m going as fast as I can! These processes take time. Please be more patient.
  grandma.success -= 1
elif (kept("allergic_to") and kept("you") and kept_count() == 2) or (kept("you") and kept_count() == 1):
  doctor (neutral): You’re allergic to me? I…I assume you’re joking…I would hate to cause your symptoms to flare up more severely. I-I think I’ll assume you’re joking, ha ha.
else:
  doctor (neutral): I…don’t quite understand what you mean by that. I’m not sure that’s an allergy.
  grandma.success -= 3

doctor (neutral): Well, moving on from allergies, let’s hear about your symptoms. How have you been feeling lately?

## question_4
@sponsor_score -3
@sponsor_text "WHEN I FEEL TIRED, I TAKE A SIP OF SAM’S SODA POP. NOW THAT’S THE STUFF!"
grandma (hospital): [I’M]{id=im} [SICK]{id=sick} [OF]{id=of} [THIS PLACE!]{id=this_place} [EVERYTHING]{id=everything} [ABOUT IT]{id=about_it} [MAKES ME]{id=makes_me} [FURIOUS]{id=furious} [BEYOND MEASURE!]{id=beyond_measure}

if delivery("sponsor"):
  doctor (neutral): Er…I suppose we all need something to calm us down every now and again. Some of us more than others. That doesn’t exactly help me with your prescription, though.
elif delivery("silence") or delivery("pity"):
  doctor (neutral): Well, you’re certainly not feeling very chatty. I suppose that’s something I can write down…
  grandma.success += 1
elif kept("sick") and kept("this_place") and kept("everything") and kept("makes_me") and kept("furious"):
  doctor (neutral): W-wow. Such a strong sentiment…I’m so sorry you feel this way. Although…maybe you should lower your voice a little. These walls are very thin.
  grandma.success += 3
elif kept("sick") and kept("of") and kept("this_place") and not (kept("everything") and kept("makes_me") and kept("furious")):
  doctor (neutral): I see, I see. Moving to a new place where people have difficulty understanding you can definitely be very frustrating. I think I’m starting to understand what you’re going through.
  grandma.success += 2
elif kept("im") and kept("sick") and kept("of") and kept("everything") and removed("this_place"):
  doctor (neutral): You’re sick of everything? I-I’m not sure that falls under my domain.
  grandma.success -= 1
elif (kept("im") and kept("sick") and kept_count() == 2) or (kept("sick") and kept_count() == 1):
  doctor (neutral): Yes…that’s why you’re here. Because you feel sick. I-if you’re not going to give me any symptoms, it’s going to be very difficult for me to prescribe you medication.
  grandma.success -= 2
elif kept("furious") and not (kept("sick") and kept("this_place") and kept("everything") and kept("makes_me")) and not (kept("sick") and kept("of") and kept("this_place")) and not (kept("im") and kept("sick") and kept("of") and kept("everything") and removed("this_place")):
  doctor (neutral): Alright, I’ll factor that into your medication. Maybe…just take some deep breaths for now.
  grandma.success += 1
elif kept("im") and kept("of") and kept("this_place") and kept_count() == 3:
  doctor (neutral): Huh? With that robot companion, I thought you were a non-citizen under the Verbal Tariff Act…I think our records may be a bit jumbled here.
  grandma.success -= 3
else:
  doctor (neutral): I’m afraid I didn’t catch your meaning. I understand emotions can be very difficult to describe…especially yours, it seems.
  grandma.success -= 2

doctor (neutral): I’ll just move on to our final check-up question. What are your symptoms?

## question_5
@sponsor_score -2
@sponsor_text "SAM’S SODA POP! I JUST CAN’T GET ENOUGH!"
grandma (hospital): [MY MIND]{id=my_mind} [IS]{id=is} [CONSUMED BY]{id=consumed_by} [A MURDEROUS RAGE!]{id=murderous_rage} [I AM]{id=i_am} [FILLED WITH]{id=filled_with} [BLOODLUST!]{id=bloodlust}

if delivery("sponsor"):
  doctor (neutral): So…an uncontrollable urge for Sam’s Soda Pop? Hmm…you might need a different medication than what I was thinking of.
elif delivery("silence") or delivery("pity"):
  doctor (neutral): Hmm…guess I’ll write foggy-minded as a symptom? No shame in being slow, especially at your age. Er—I mean, no shame in being slow, I suppose.
  grandma.success += 1
elif kept("murderous_rage") or kept("bloodlust"):
  doctor (neutral): Um…should I be worried about my safety? Do you need to talk to someone? I…er…I think…
  grandma.success -= 4
elif (kept("my_mind") and kept("is") and kept_count() == 2) or (kept("my_mind") and kept_count() == 1):
  doctor (neutral): Your mind is…your symptom. Huh. Okay…I will…I will write that down…I guess…
  grandma.success += 1
elif kept("i_am") and kept_count() == 1:
  doctor (neutral): You are the symptom? I…haven’t heard that one before. I suppose I’ll write that down, but keep in mind that’s not a symptom we’re trying to get rid of.
  grandma.success += 1
else:
  doctor (neutral): Ah…I couldn’t exactly understand that. I’m not sure what to write down here.
  grandma.success -= 2

if grandma.success >= 5:
  SET got_prescription = true
else:
  SET got_prescription = false

doctor (neutral): That’s going to be the end of your check-up appointment with me today.
doctor (neutral): Let me just look over my notes…
doctor (neutral): And…

CHECK got_prescription == true as grandma_received_a_prescription:
  doctor (happy): I think I understand you well enough.
  doctor (neutral): Most of the time anyway…
  doctor (happy): Here’s your prescription!
  doctor (happy): I hope it helps!

CHECK got_prescription == false as grandma_did_not_receive_a_prescription:
  doctor (neutral): I’m so sorry, I just don’t know what prescription to give you.
  doctor (neutral): I just couldn’t quite understand what you were saying a lot of the time.
  doctor (neutral): My best suggestion would be…
  doctor (neutral): Try therapy?

-> end
