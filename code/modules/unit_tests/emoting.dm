/datum/unit_test/emoting
	var/emotes_used = 0

/datum/unit_test/emoting/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	RegisterSignal(human, COMSIG_MOB_EMOTE, PROC_REF(on_emote_used))

	human.say("*shrug")
	TEST_ASSERT_EQUAL(emotes_used, 1, "Human did not shrug")

	human.say("*beep")
	TEST_ASSERT_EQUAL(emotes_used, 1, "Human beeped, when that should be restricted to silicons")

	human.set_oxy_loss(140)

	TEST_ASSERT(IS_UNCONSCIOUS_OR_CRIT(human), "Human is somehow conscious after receiving suffocation damage")

	human.say("*shrug")
	TEST_ASSERT_EQUAL(emotes_used, 1, "Human shrugged while unconscious")

	human.say("*deathgasp")
	TEST_ASSERT_EQUAL(emotes_used, 2, "Human could not deathgasp while unconscious")

/datum/unit_test/emoting/proc/on_emote_used()
	SIGNAL_HANDLER
	emotes_used += 1

/// A contagious yawn may outlive its recipient while waiting on the emote's timer.
/datum/unit_test/emoting_yawn_deleted/Run()
	var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent)
	var/datum/emote/living/yawn/yawn = allocate(/datum/emote/living/yawn)
	var/runtimes_before = GLOB.total_runtimes
	var/propagation_timer = addtimer(CALLBACK(yawn, TYPE_PROC_REF(/datum/emote/living/yawn, propagate_yawn), recipient), 1, TIMER_STOPPABLE)
	qdel(recipient)
	var/deadline = world.time + 5 SECONDS
	UNTIL(isnull(timeleft(propagation_timer)) || world.time >= deadline)
	TEST_ASSERT_NULL(timeleft(propagation_timer), "The delayed yawn never completed.")
	TEST_ASSERT_EQUAL(GLOB.total_runtimes, runtimes_before, "A delayed yawn tried to emote on its deleted recipient.")

/// Only an actual previous use may impose a manual emote cooldown, including a use at time zero.
/datum/unit_test/emote_cooldown_first_use/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/datum/emote/living/deathgasp/emote = allocate(/datum/emote/living/deathgasp)
	var/datum/emote/living/yawn/other_emote = allocate(/datum/emote/living/yawn)
	emote.cooldown = world.time + 1 MINUTES
	human.emotes_used = list()
	human.emotes_used[other_emote] = world.time
	var/first_use_allowed = emote.check_cooldown(human, intentional = TRUE)
	var/repeated_use_allowed = emote.check_cooldown(human, intentional = TRUE)
	human.emotes_used[emote] = 0
	var/time_zero_use_allowed = emote.check_cooldown(human, intentional = TRUE)
	human.emotes_used = null
	TEST_ASSERT(first_use_allowed, "An unused emote inherited a cooldown from world startup.")
	TEST_ASSERT(!repeated_use_allowed, "A repeated emote bypassed its cooldown.")
	TEST_ASSERT(!time_zero_use_allowed, "An emote last used at time zero bypassed its cooldown.")
