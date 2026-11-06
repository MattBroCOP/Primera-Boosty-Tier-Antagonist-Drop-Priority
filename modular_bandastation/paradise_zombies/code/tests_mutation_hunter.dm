#ifdef UNIT_TESTS

/** The new button uses real claws and the existing flight, while the original jump remains available. */
/datum/unit_test/paradise_zombie_hunter_pin_pounce
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test

/datum/unit_test/paradise_zombie_hunter_pin_pounce/Run()
	var/mob/living/carbon/human/host = make_mutant("hunter")
	TEST_ASSERT_NOTNULL(host, "The Hunter fixture was not created.")
	TEST_ASSERT(prepare_range(host, offset = 8), "The pin fixture has no private range.")
	var/datum/action/cooldown/paradise_zombie_mutation/dash/pounce/pin/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "The Hunter did not receive its separate pin action.")
	var/original_jump_found = FALSE
	for(var/datum/action/cooldown/paradise_zombie_mutation/dash/pounce/jump in host.actions)
		if(jump.type == /datum/action/cooldown/paradise_zombie_mutation/dash/pounce)
			original_jump_found = TRUE
	TEST_ASSERT(original_jump_found, "Adding the pin replaced the original Hunter jump.")
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, locate(host.x + 3, host.y, host.z))
	ADD_TRAIT(victim, TRAIT_NEVER_WOUNDED, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!action.Trigger(host, target = victim), "The pin leap launched without its required claws.")
	TEST_ASSERT(extend_claws(host), "The Hunter could not extend its actual claws.")
	TEST_ASSERT(action.Trigger(host, target = victim), "The new pin leap did not launch through its real action.")
	var/deadline = world.time + 3 SECONDS
	UNTIL(victim.has_status_effect(/datum/status_effect/paradise_zombie_pin) || world.time >= deadline)
	var/datum/status_effect/paradise_zombie_pin/pin = victim.has_status_effect(/datum/status_effect/paradise_zombie_pin)
	TEST_ASSERT_NOTNULL(pin, "A real claw impact never applied its Hunter pin.")
	TEST_ASSERT(victim.get_brute_loss() > 0, "The pin bypassed the real melee impact.")
	TEST_ASSERT(pin in action.owned_effects, "The pin was not owned by its action.")
	TEST_ASSERT(victim.body_position == LYING_DOWN && HAS_TRAIT(victim, TRAIT_IMMOBILIZED) && HAS_TRAIT(victim, TRAIT_HANDS_BLOCKED), "The pin did not hold its victim down.")
	TEST_ASSERT(victim.can_resist(), "The pin disabled the native resistance path.")
	var/brute_before = victim.get_brute_loss()
	deadline = world.time + 2 SECONDS
	UNTIL(victim.get_brute_loss() > brute_before || QDELETED(pin) || world.time >= deadline)
	TEST_ASSERT(!QDELETED(pin) && victim.get_brute_loss() > brute_before, "The real pin timer did not inflict its periodic damage.")
	deadline = world.time + 5 SECONDS
	UNTIL(QDELETED(pin) || world.time >= deadline)
	TEST_ASSERT(QDELETED(pin), "The Hunter's four-second hold became permanent.")
	TEST_ASSERT(!HAS_TRAIT(victim, TRAIT_IMMOBILIZED) && !HAS_TRAIT(victim, TRAIT_HANDS_BLOCKED), "The timed-out hold retained its restraint traits.")
	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/paradise_zombie_pin_recovery), "Timeout did not grant the victim its short recovery.")
	TEST_ASSERT_EQUAL(length(action.owned_effects), 0, "The expired pin retained action-owned effects.")
	TEST_ASSERT(action.next_use_time > world.time, "Resolving the pin refunded its cooldown.")

/** Pacifism rejects the real claw-ready button and ends an already landed hold before its next damage tick. */
/datum/unit_test/paradise_zombie_hunter_pin_pacifism
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test

/datum/unit_test/paradise_zombie_hunter_pin_pacifism/Run()
	var/mob/living/carbon/human/host = make_mutant("hunter")
	TEST_ASSERT_NOTNULL(host, "The pacifism fixture has no Hunter.")
	TEST_ASSERT(prepare_range(host, offset = 8), "The pacifism fixture has no private range.")
	var/datum/action/cooldown/paradise_zombie_mutation/dash/pounce/pin/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "The Hunter has no separate pin action.")
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, locate(host.x + 3, host.y, host.z))
	ADD_TRAIT(victim, TRAIT_NEVER_WOUNDED, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(extend_claws(host), "The pacifism fixture could not ready its real claws.")
	TEST_ASSERT(action.IsAvailable(), "The claw-ready pin action was unavailable before pacifism.")
	ADD_TRAIT(host, TRAIT_PACIFISM, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!action.Trigger(host, target = victim), "Pacifism allowed the real claw-ready pin action to launch.")
	TEST_ASSERT_NULL(host.throwing, "The rejected pacifist action created a flight.")
	TEST_ASSERT_EQUAL(victim.get_brute_loss(), 0, "The rejected pacifist action damaged its target.")
	TEST_ASSERT_EQUAL(length(action.owned_effects), 0, "The rejected pacifist action retained a world effect.")
	REMOVE_TRAIT(host, TRAIT_PACIFISM, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(action.Trigger(host, target = victim), "Removing pacifism did not restore the actual pin jump.")
	var/deadline = world.time + 3 SECONDS
	UNTIL(victim.has_status_effect(/datum/status_effect/paradise_zombie_pin) || world.time >= deadline)
	var/datum/status_effect/paradise_zombie_pin/pin = victim.has_status_effect(/datum/status_effect/paradise_zombie_pin)
	TEST_ASSERT_NOTNULL(pin, "The real claw impact did not establish a hold before late pacifism.")
	TEST_ASSERT(victim.get_brute_loss() > 0, "The late-pacifism fixture bypassed the actual claw impact.")
	var/brute_before = victim.get_brute_loss()
	ADD_TRAIT(host, TRAIT_PACIFISM, TRAIT_SOURCE_UNIT_TESTS)
	deadline = world.time + 2 SECONDS
	UNTIL(QDELETED(pin) || world.time >= deadline)
	TEST_ASSERT(QDELETED(pin), "Late pacifism retained the Hunter's damaging hold.")
	TEST_ASSERT_EQUAL(victim.get_brute_loss(), brute_before, "The Hunter inflicted another pin damage tick after gaining pacifism.")
	TEST_ASSERT(!HAS_TRAIT(victim, TRAIT_IMMOBILIZED) && !HAS_TRAIT(victim, TRAIT_HANDS_BLOCKED), "Late pacifism left the victim restrained.")
	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/paradise_zombie_pin_recovery), "Late-pacifism release omitted the victim's control recovery.")
	TEST_ASSERT_EQUAL(length(action.owned_effects), 0, "Late pacifism retained the action's completed flight or hold.")

/** Each real interruption removes only its own hold, including damage outside apply_damage(). */
/datum/unit_test/paradise_zombie_hunter_pin_release
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test
	abstract_type = /datum/unit_test/paradise_zombie_hunter_pin_release
	var/interruption

/datum/unit_test/paradise_zombie_hunter_pin_release/resist
	interruption = "resist"

/datum/unit_test/paradise_zombie_hunter_pin_release/captor_move
	interruption = "captor_move"

/datum/unit_test/paradise_zombie_hunter_pin_release/victim_move
	interruption = "victim_move"

/datum/unit_test/paradise_zombie_hunter_pin_release/damage
	interruption = "damage"

/datum/unit_test/paradise_zombie_hunter_pin_release/fire
	interruption = "fire"

/datum/unit_test/paradise_zombie_hunter_pin_release/stun
	interruption = "stun"

/datum/unit_test/paradise_zombie_hunter_pin_release/knockdown
	interruption = "knockdown"

/datum/unit_test/paradise_zombie_hunter_pin_release/help
	interruption = "help"

/datum/unit_test/paradise_zombie_hunter_pin_release/death
	interruption = "death"

/datum/unit_test/paradise_zombie_hunter_pin_release/cure
	interruption = "cure"

/datum/unit_test/paradise_zombie_hunter_pin_release/mind_transfer
	interruption = "mind_transfer"

/datum/unit_test/paradise_zombie_hunter_pin_release/victim_death
	interruption = "victim_death"

/datum/unit_test/paradise_zombie_hunter_pin_release/action_removed
	interruption = "action_removed"

/datum/unit_test/paradise_zombie_hunter_pin_release/captor_deleted
	interruption = "captor_deleted"

/datum/unit_test/paradise_zombie_hunter_pin_release/victim_deleted
	interruption = "victim_deleted"

/datum/unit_test/paradise_zombie_hunter_pin_release/Run()
	var/mob/living/carbon/human/host = make_mutant("hunter")
	TEST_ASSERT_NOTNULL(host, "The Hunter fixture was not created.")
	TEST_ASSERT(prepare_range(host, offset = 8), "The release fixture has no private range.")
	var/datum/action/cooldown/paradise_zombie_mutation/dash/pounce/pin/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "The Hunter fixture has no pin action.")
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, get_step(host, NORTH))
	ADD_TRAIT(victim, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	action.on_pounce_hit(host, victim)
	var/datum/status_effect/paradise_zombie_pin/pin = victim.has_status_effect(/datum/status_effect/paradise_zombie_pin)
	TEST_ASSERT_NOTNULL(pin, "The valid impact callback could not begin its bounded hold.")
	var/pin_source = REF(pin)
	switch(interruption)
		if("resist")
			TEST_ASSERT(victim.can_resist(), "The held victim cannot use native Resist.")
			victim.execute_resist()
		if("captor_move")
			TEST_ASSERT(host.Move(get_step(host, WEST), WEST), "The captor could not make its cancelling step.")
		if("victim_move")
			victim.forceMove(get_step(victim, NORTH))
		if("damage")
			host.apply_damage(1, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND)
		if("fire")
			host.adjust_fire_loss(1)
		if("stun")
			host.Stun(1 SECONDS)
			TEST_ASSERT(HAS_TRAIT(host, TRAIT_INCAPACITATED), "The pure-stun fixture did not actually stun its captor.")
		if("knockdown")
			host.Knockdown(1 SECONDS)
			TEST_ASSERT_EQUAL(host.body_position, LYING_DOWN, "The pure-knockdown fixture did not actually floor its captor.")
		if("help")
			var/mob/living/carbon/human/helper = allocate(/mob/living/carbon/human/consistent, get_step(victim, EAST))
			helper.set_combat_mode(FALSE, silent = TRUE)
			click_wrapper(helper, victim)
		if("death")
			host.death()
		if("cure")
			var/datum/disease/paradise_zombie/infection = locate() in host.diseases
			infection.cure()
		if("mind_transfer")
			var/mob/living/carbon/human/destination = allocate(/mob/living/carbon/human/consistent, get_turf(host))
			host.mind.transfer_to(destination)
		if("victim_death")
			victim.death()
		if("action_removed")
			action.Remove(host)
		if("captor_deleted")
			qdel(host)
		if("victim_deleted")
			qdel(victim)
	TEST_ASSERT(QDELETED(pin), "The [interruption] interruption retained a live pin.")
	if(!QDELETED(victim))
		for(var/trait in list(TRAIT_IMMOBILIZED, TRAIT_FLOORED, TRAIT_HANDS_BLOCKED))
			TEST_ASSERT(!HAS_TRAIT_FROM(victim, trait, pin_source), "The [interruption] interruption retained a pin-owned trait.")
		TEST_ASSERT(HAS_TRAIT_FROM(victim, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS), "Pin cleanup removed another source's immobility.")
		if(victim.stat != DEAD)
			TEST_ASSERT(victim.has_status_effect(/datum/status_effect/paradise_zombie_pin_recovery), "The released victim received no recovery window.")
		REMOVE_TRAIT(victim, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	if(!QDELETED(action))
		TEST_ASSERT_EQUAL(length(action.owned_effects), 0, "The [interruption] interruption left an owned effect behind.")

/** Recovery belongs to the victim and blocks repeated captures without suppressing unrelated combat. */
/datum/unit_test/paradise_zombie_hunter_pin_recovery
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test

/datum/unit_test/paradise_zombie_hunter_pin_recovery/Run()
	var/mob/living/carbon/human/host = make_mutant("hunter")
	TEST_ASSERT_NOTNULL(host, "The recovery fixture has no Hunter.")
	TEST_ASSERT(prepare_range(host, offset = 8), "The recovery fixture has no private range.")
	var/datum/action/cooldown/paradise_zombie_mutation/dash/pounce/pin/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "The recovery fixture has no pin action.")
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, get_step(host, NORTH))
	action.on_pounce_hit(host, victim)
	var/datum/status_effect/paradise_zombie_pin/first_pin = victim.has_status_effect(/datum/status_effect/paradise_zombie_pin)
	TEST_ASSERT_NOTNULL(first_pin, "The first capture did not begin.")
	action.on_pounce_hit(host, victim)
	TEST_ASSERT_EQUAL(victim.has_status_effect(/datum/status_effect/paradise_zombie_pin), first_pin, "A repeated capture replaced an active pin.")
	victim.execute_resist()
	TEST_ASSERT(QDELETED(first_pin), "Native resistance did not end the first capture.")
	var/datum/status_effect/paradise_zombie_pin_recovery/recovery = victim.has_status_effect(/datum/status_effect/paradise_zombie_pin_recovery)
	TEST_ASSERT_NOTNULL(recovery, "The first release created no victim-owned recovery.")
	action.on_pounce_hit(host, victim)
	TEST_ASSERT_NULL(victim.has_status_effect(/datum/status_effect/paradise_zombie_pin), "A new capture ignored the victim's recovery.")
	TEST_ASSERT_EQUAL(victim.has_status_effect(/datum/status_effect/paradise_zombie_pin_recovery), recovery, "Rejecting a capture replaced the recovery effect.")
	var/deadline = world.time + 3 SECONDS
	UNTIL(QDELETED(recovery) || world.time >= deadline)
	TEST_ASSERT(QDELETED(recovery), "The two-second recovery never expired.")
	action.on_pounce_hit(host, victim)
	var/datum/status_effect/paradise_zombie_pin/next_pin = victim.has_status_effect(/datum/status_effect/paradise_zombie_pin)
	TEST_ASSERT_NOTNULL(next_pin, "A recovered victim could not be captured again.")
	action.Remove(host)
	TEST_ASSERT(QDELETED(next_pin), "Removing the action did not release its second victim.")
	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/paradise_zombie_pin_recovery), "Removing a captor removed the victim's recovery too.")

/** A second attack can request a shorter hold without inheriting the Hunter's periodic damage. */
/datum/unit_test/paradise_zombie_pin_short_hold
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test

/datum/unit_test/paradise_zombie_pin_short_hold/Run()
	var/mob/living/carbon/human/host = make_mutant("hunter")
	TEST_ASSERT_NOTNULL(host, "The short-hold fixture has no active mutation.")
	TEST_ASSERT(prepare_range(host, offset = 8), "The short-hold fixture has no private range.")
	var/datum/action/cooldown/paradise_zombie_mutation/dash/pounce/pin/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "The short-hold fixture has no owning action.")
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, get_step(host, NORTH))
	var/datum/status_effect/paradise_zombie_pin/pin = victim.apply_status_effect(/datum/status_effect/paradise_zombie_pin, action, host, 2 SECONDS, 0)
	TEST_ASSERT_NOTNULL(pin, "The shared pin boundary rejected its shorter hold.")
	action.track_effect(pin)
	var/started_at = world.time
	sleep(1 SECONDS)
	TEST_ASSERT(!QDELETED(pin), "A two-second pin ended in its first second.")
	var/deadline = started_at + 3 SECONDS
	UNTIL(QDELETED(pin) || world.time >= deadline)
	TEST_ASSERT(QDELETED(pin), "The shorter shared hold retained the Hunter's four-second duration.")
	TEST_ASSERT_EQUAL(victim.get_brute_loss(), 0, "A control-only pin inherited the Hunter's damage.")
	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/paradise_zombie_pin_recovery), "The shorter hold omitted anti-chain recovery.")

#endif
