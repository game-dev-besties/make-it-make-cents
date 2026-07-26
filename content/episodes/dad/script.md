# Chapter 2: Dad's job interview.

## intro
@cue dad_enters
SET dad_offended_interviewer = "none"
SET dad_mentioned_family = false
interviewer: Hmm. Thanks for taking the time to interview with us today. Why don’t you tell me a little bit about yourself?

## question_1
@sponsor_text "I LOVE SAM’S SODA POP! NOW WITH ZERO SUGAR!"
dad: [I am]{id=iam} [the best]{id=best} [candidate]{id=candidate} [you will ever meet]{id=ever} [guaranteed.]{id=guaranteed}

if delivery("sponsor"):
  interviewer: A-alright. I was hoping for some explanation of your past experience, but if you love soda that much…
  SET dad_offended_interviewer = "soda"
elif delivery("silence") or delivery("pity"):
  interviewer: Nothing? You have nothing to say about yourself? Not a good start, sir.
  dad.success -= 3
elif kept("best") and (kept("iam") or kept("candidate")):
  interviewer: Right. Straight to the point, I see. I like it.
  dad.success += 1
elif kept("candidate"):
  interviewer: You…certainly are.
  dad.silly += 1
elif kept("best"):
  interviewer: Right. Straight to the point, I see. I like it.
  dad.silly += 1
elif kept("iam") and removed("ever"):
  interviewer: You…certainly are.
  dad.silly += 1
elif kept("guaranteed"):
  interviewer: Right. Straight to the point, I see. I like it.
  dad.silly += 1
else:
  interviewer: Hmm. Not sure I understand what you mean. You might try saying more next time.
  dad.success -= 3

## question_2
interviewer: We’ll move onto the next question. What makes you want to work here at Paperbox, Inc.?
@sponsor_score -1
@sponsor_text "SAM’S SODA POP! WITH OVER 500 DIFFERENT FLAVORS!"
dad: [Honestly,]{id=honestly} [I just need money,]{id=money} [but]{id=but} [I also think I can contribute a lot.]{id=contribute}

if delivery("sponsor"):
  interviewer: That’s…a reason. I suppose you heard about the free beverages in the break room? At least you did your research.
  dad.silly += 1
  if flag("dad_offended_interviewer") == "none":
    SET dad_offended_interviewer = "soda"
elif delivery("silence") or delivery("pity"):
  interviewer: You really can’t think of a reason? Hmph, not very professional.
  dad.success -= 3
elif kept("money") and kept("contribute"):
  interviewer: Hmm, yes, your resume seems to agree.
  dad.success += 1
elif kept("money"):
  interviewer: Sir, honesty is not always the best policy. We were hoping for someone with more passion.
  dad.success -= 1
  dad.silly += 1
elif kept("contribute"):
  interviewer: Hmm, yes, your resume seems to agree.
  dad.success += 2
elif kept("but"):
  interviewer: Sir, I suggest you focus less on behinds and more on business.
  dad.success -= 2
  dad.silly += 2
  if flag("dad_offended_interviewer") == "none":
    SET dad_offended_interviewer = "butts"
elif kept("honestly"):
  interviewer: Sir, honesty is not always the best policy. We were hoping for someone with more passion.
  dad.success -= 1
  dad.silly += 1

## question_3
interviewer: Let’s move on. I was wondering about this gap in your resume. Why did you leave your last job?
@sponsor_score -1
@sponsor_text "I’D DIE WITHOUT SAM’S SODA POP!"
dad: [I wanted to]{id=wanted} [balance]{id=balance} [my family]{id=family} [and]{id=and} [my career.]{id=career} [Unfortunately,]{id=unfortunately} [the workload was too much.]{id=workload}

if delivery("sponsor"):
  interviewer: Hmm…soda clearly means a lot to you. I’m assuming this kind of attitude is why you were let go…
  if flag("dad_offended_interviewer") == "none":
    SET dad_offended_interviewer = "soda"
elif delivery("silence") or delivery("pity"):
  interviewer: I see you don’t want to get into it. Don’t worry, I understand. I was a Twitch streamer in my past life.
  dad.success += 1
  dad.silly += 1
elif kept("workload"):
  interviewer: Happens to the best of us. Even I have trouble balancing my family and work sometimes.
  dad.success += 2
elif kept("career"):
  interviewer: Your career got in the way of your job? What kind of career were you going for…nevermind. Let’s not get off-topic.
  dad.success -= 1
elif kept("balance") and kept("family"):
  interviewer: Yes, balance is very important during your past as a circus trapeze artist. Taking risks like that is certainly admirable.
  dad.silly += 1
elif kept("balance"):
  interviewer: Yes, balance is very important during your past as a circus trapeze artist. Taking risks like that is certainly admirable.
  dad.silly += 1
elif kept("family"):
  interviewer: Erm. That’s interesting. I suppose we can’t choose our family.
  dad.success -= 1
  dad.silly += 1
  SET dad_mentioned_family = true
elif kept("wanted"):
  interviewer: You wanted to be unemployed? In this economy? I suppose you must be one of those risk-taking types.
  dad.silly += 1
else:
  interviewer: Hmm. Not sure I understand what you mean. Think your meaning got a little jumbled there.
  dad.success -= 3

## question_4
interviewer: Next question. What do you think is your greatest weakness?
@sponsor_score -2
@sponsor_text "THE POP OF SAM’S SODA IS IRRESISTIBLE!"
dad: [I have]{id=have} [no]{id=no} [experience]{id=experience} [but]{id=but} [I’m a fast learner.]{id=fast}

if delivery("sponsor"):
  interviewer: I find soda as enjoyable as the next, but I wouldn’t go that far. It seems to me your weakness is a lack of self-control.
  if flag("dad_offended_interviewer") == "none":
    SET dad_offended_interviewer = "soda"
elif delivery("silence") or delivery("pity"):
  interviewer: No weaknesses!? Very impressive.
  dad.success += 1
elif kept("no") and kept("experience") and kept("fast"):
  interviewer: Ah, I see! It’s always useful to have someone quick on their toes around here.
  dad.success += 2
elif kept("have") and kept("no") and kept("experience"):
  interviewer: Tsk, tsk. Not what we’re looking for. If you did a little research on interviews, you’d know you’re not supposed to say an actual weakness here.
  dad.success -= 1
elif kept("fast"):
  interviewer: I can see why being fast might be a weakness with you, considering you don’t seem to think before speaking.
  dad.success -= 2
elif kept("have") and kept("experience"):
  interviewer: That’s…a weakness? What kind of experience are you talking about? Ah… nevermind.
  dad.success -= 1
  dad.silly += 1
elif kept("but") and (kept("have") or kept("no")):
  interviewer: Sir!? That’s-that’s not something I need to know. Please don’t continue talking about your butt…
  dad.success -= 2
  dad.silly += 2
  if flag("dad_offended_interviewer") == "none":
    SET dad_offended_interviewer = "butts"
elif kept("no") and kept_count() == 1:
  interviewer: No weaknesses!? Very impressive.
else:
  interviewer: Hmm. Not sure I understand what you mean.
  dad.success -= 3

## question_5
interviewer: Moving on. For your final question, I want to give you a hypothetical situation. Say you don’t get along with a co-worker. What do you do?
@sponsor_score -2
@sponsor_text "TELL ALL YOUR FRIENDS AND FAMILY ABOUT SAM’S ROCKIN’ SODA POP!"
dad: [First, I would]{id=first} [try to]{id=try} [talk]{id=talk} [it out.]{id=out} [If they start to]{id=if_start} [escalate,]{id=escalate} [then]{id=then} [I would]{id=i_would} [bring it up to my manager.]{id=manager}

if delivery("sponsor"):
  interviewer: Sir, that is not an appropriate response to this question! What if your coworker doesn’t like soda? Some people are very sensitive about their teeth. Ah…nevermind.
  if flag("dad_offended_interviewer") == "none":
    SET dad_offended_interviewer = "soda"
elif delivery("silence") or delivery("pity"):
  interviewer: Hmm, are you blanking? This is a very common scenario. I’d recommend you do more research next time.
  dad.success -= 2
elif kept("talk") and kept("out") and kept("manager"):
  interviewer: A detailed plan, I see. You’ve certainly thought this one through.
  dad.success += 3
elif kept("talk") and kept("out"):
  interviewer: A fairly reasonable answer. I’m glad you know how to use your words.
  dad.success += 1
elif kept("manager"):
  interviewer: I suppose that’s a fair response…Although I hope your manager has more patience for your spats than I do.
  dad.success += 1
elif kept("talk"):
  interviewer: I see you’re a simple man. Talking can certainly be very effective, but I’m not sure it would be in your case…
elif kept("escalate"):
  interviewer: Oh…erm. Escalate how? Nevermind. I don’t want to know.
  dad.success -= 2
else:
  interviewer: Hmm, not sure I understand what you mean. Seems like another weakness of yours is your lack of eloquence.
  dad.success -= 2

## outcome
interviewer: Well then, that concludes our interview. As for your position…

if dad.success >= 5 and flag("dad_offended_interviewer") == "none":
  CHECK dad_offended_interviewer == "none" as dad_got_the_job:
    interviewer: You got the job!
    interviewer: We need more people with your humor and creativity around. You belong here!
    interviewer: You start tomorrow!
elif flag("dad_offended_interviewer") != "none":
  CHECK dad_offended_interviewer != "none" as dad_did_not_get_the_job:
    interviewer: You didn’t get the job.
    interviewer: Too many of your answers were…strange, to say the least.
    interviewer: We will not be in touch with you.
    interviewer: Please leave before I have to contact security.
else:
  CHECK dad_offended_interviewer == "none" as dad_did_not_get_the_job_low_success:
    interviewer: You didn’t get the job.
    interviewer: Too many of your answers were…strange, to say the least.
    interviewer: We will not be in touch with you.
    interviewer: Please leave before I have to contact security.

-> end
