# Dad's job interview proof slice.

## intro
@cue dad_enters
interviewer: Hmm. Thanks for taking the time to interview with us today. Tell me a little about yourself.
dad: [I have]{id=have} [no]{id=no} [experience]{id=experience} [but]{id=but} [I’m a fast learner.]{id=fast}

if delivery("sponsor"):
  interviewer: Advertising during an interview? That does not help your case.
elif kept("have") and kept("no") and kept("experience") and kept_count() == 3:
  interviewer: Tsk, tsk. Not what we are looking for.
  dad.success -= 1
elif kept("fast") and kept_count() == 1:
  interviewer: Ah, I see. Straight to the point.
  dad.success += 1
elif kept("have") and kept("experience") and removed("no") and removed("but") and kept_count() <= 3:
  interviewer: Ah, I see. Straight to the point.
  dad.success += 1
elif kept("have") and kept("but") and removed("experience") and removed("fast") and kept_count() <= 3:
  interviewer: Sir!? That is not something I need to know.
  dad.success -= 2
  dad.silly += 2
else:
  interviewer: Hmm. Not sure I understand what you mean.
  dad.success -= 3

-> motivation

## motivation
interviewer: What makes you want to work here at Paperbox, Inc.?
dad: [Honestly,]{id=honestly} [I just need money,]{id=money} [but]{id=but} [I also think I can contribute a lot.]{id=contribute}

if delivery("sponsor"):
  interviewer: Again with the soda? Please focus on Paperbox, Inc.
elif kept("money") and removed("but") and removed("contribute") and kept_count() <= 2:
  interviewer: Honesty is not always the best policy, sir.
  dad.success -= 1
  dad.silly += 1
elif kept("contribute") and removed("money") and removed("but") and kept_count() <= 2:
  interviewer: Hmm, yes, your resume seems to agree.
  dad.success += 2
elif kept("but") and kept_count() == 1:
  interviewer: Sir, focus less on behinds and more on business.
  dad.success -= 2
  dad.silly += 2
else:
  interviewer: Hmm. Not sure I understand what you mean.
  dad.success -= 3

-> outcome

## outcome
if dad.success > 5:
  interviewer: I like your work ethic. I think you belong here.
elif dad.silly >= 3:
  interviewer: You know, we need more people with your creativity around.
else:
  interviewer: We will be in touch.

-> end
