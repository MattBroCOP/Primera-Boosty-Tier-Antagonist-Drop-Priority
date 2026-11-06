#ifdef UNIT_TESTS

/// Native view() must respect an opaque object without changing the private range's turfs.
/obj/structure/paradise_zombie_scream_test_cover
	density = TRUE
	opacity = TRUE
	anchored = TRUE

/// A separate additive delay must remain independent of the scream's final speed factor.
/datum/movespeed_modifier/paradise_zombie_scream_test
	multiplicative_slowdown = 2

/** Evolution removes the lower form's scream; curing and reinfecting gives a fresh ordinary action. */
/datum/unit_test/paradise_zombie_scream_lifecycle
	parent_type = /datum/unit_test/paradise_zombie_mutation_test

/datum/unit_test/paradise_zombie_scream_lifecycle/Run()
	var/mob/living/carbon/human/host = make_zombie(run_loc_floor_bottom_left)
	var/datum/action/cooldown/paradise_zombie_scream/scream = locate() in host.actions
	TEST_ASSERT_NOTNULL(scream, "A mature ordinary zombie did not receive its real scream action.")
	TEST_ASSERT(scream.Trigger(host), "The ordinary zombie could not use its real scream.")
	TEST_ASSERT(host.has_status_effect(/datum/status_effect/paradise_zombie_scream/haste), "The real scream did not apply haste.")
	var/datum/component/paradise_zombie_mutation/controller = host.GetComponent(/datum/component/paradise_zombie_mutation)
	GLOB.paradise_zombie_mutation_progression.first_infection_at = world.time - 2 MINUTES
	TEST_ASSERT_NULL(GLOB.paradise_zombie_mutation_progression.get_unavailability_reason(host, "slasher"), "The lifecycle fixture did not satisfy the real Slasher unlock requirements.")
	TEST_ASSERT(controller.apply_form("slasher"), "The lifecycle fixture could not evolve into its actual Slasher form.")
	TEST_ASSERT(QDELETED(scream), "Evolution retained the old lower zombie's scream action.")
	TEST_ASSERT_NULL(host.has_status_effect(/datum/status_effect/paradise_zombie_scream/haste), "Evolution retained the old scream's haste.")
	TEST_ASSERT_NULL(locate(/datum/action/cooldown/paradise_zombie_scream) in host.actions, "An evolved form still has a scream action.")
	var/datum/disease/paradise_zombie/infection = locate() in host.diseases
	infection.cure()
	TEST_ASSERT_NULL(locate(/datum/action/cooldown/paradise_zombie_scream) in host.actions, "Curing the mutated body granted a zombie action to a healthy human.")
	infection = new()
	TEST_ASSERT(host.ForceContractDisease(infection, make_copy = FALSE, del_on_fail = TRUE), "The cured body could not receive a fresh infection.")
	infection.stage = 8
	infection.process_infection_cycle()
	scream = locate() in host.actions
	controller = host.GetComponent(/datum/component/paradise_zombie_mutation)
	TEST_ASSERT_NOTNULL(scream, "Reinfection did not grant a fresh lower zombie's scream.")
	TEST_ASSERT_NULL(controller.form, "Reinfection silently restored the body's former special form.")
	TEST_ASSERT(scream.Trigger(host), "A new ordinary scream retained the previous action's cooldown.")
	infection.cure()
	TEST_ASSERT(QDELETED(scream), "Ordinary cure retained its scream action.")
	TEST_ASSERT_NULL(host.has_status_effect(/datum/status_effect/paradise_zombie_scream/haste), "Ordinary cure retained its own haste.")
	var/mob/living/carbon/human/npc = allocate(/mob/living/basic/zombie)
	scream = locate() in npc.actions
	TEST_ASSERT_NOTNULL(scream, "A mature mapped NPC did not receive its lower zombie scream.")
	TEST_ASSERT(scream.Trigger(npc), "A mature mapped NPC could not trigger its lower zombie scream.")
	var/mob/living/carbon/human/servant = allocate(/mob/living/carbon/human/consistent)
	ADD_TRAIT(servant, TRAIT_PARADISE_PLAGUE_ZOMBIE, PARADISE_ZOMBIE_TRAIT)
	var/datum/disease/paradise_zombie/wizard/plague = new /datum/disease/paradise_zombie/wizard(/datum/disease/anxiety/paradise_plague, TRUE)
	TEST_ASSERT(servant.ForceContractDisease(plague, make_copy = FALSE, del_on_fail = TRUE), "The magic scream fixture could not receive its real plague.")
	plague.process_infection_cycle()
	scream = locate() in servant.actions
	TEST_ASSERT_NOTNULL(scream, "A mature magic plague zombie did not receive its lower zombie scream.")
	TEST_ASSERT(scream.Trigger(servant), "A mature magic plague zombie could not trigger its lower zombie scream.")
	qdel(plague)
	TEST_ASSERT(QDELETED(scream), "Forcibly clearing a magic plague retained its scream action.")
	TEST_ASSERT_NULL(servant.has_status_effect(/datum/status_effect/paradise_zombie_scream/haste), "Forcibly clearing a magic plague retained its haste.")

/** Native visibility, the five-tile boundary and every infection stage control fear eligibility. */
/datum/unit_test/paradise_zombie_scream_targets
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test

/datum/unit_test/paradise_zombie_scream_targets/Run()
	var/mob/living/carbon/human/host = make_zombie(run_loc_floor_bottom_left)
	TEST_ASSERT(prepare_range(host, 8), "The scream fixture has no private native range.")
	var/mob/living/carbon/human/near = allocate(/mob/living/carbon/human/consistent, locate(host.x, host.y + 5, host.z))
	var/mob/living/carbon/human/far = allocate(/mob/living/carbon/human/consistent, locate(host.x, host.y + 6, host.z))
	var/mob/living/carbon/human/covered = allocate(/mob/living/carbon/human/consistent, locate(host.x + 2, host.y, host.z))
	allocate(/obj/structure/paradise_zombie_scream_test_cover, get_step(host, EAST))
	var/mob/living/carbon/human/incubating = allocate(/mob/living/carbon/human/consistent, locate(host.x - 2, host.y, host.z))
	var/datum/disease/paradise_zombie/infection = new()
	TEST_ASSERT(incubating.ForceContractDisease(infection, make_copy = FALSE, del_on_fail = TRUE), "The target fixture could not receive its incubating plague.")
	TEST_ASSERT_EQUAL(infection.stage, 1, "The immunity fixture skipped the earliest infection stage.")
	TEST_ASSERT_NULL(locate(/datum/action/cooldown/paradise_zombie_scream) in incubating.actions, "An early infection received a mature zombie's scream.")
	var/mob/living/carbon/human/zombie = make_zombie(locate(host.x - 3, host.y, host.z))
	var/mob/living/carbon/human/dead = allocate(/mob/living/carbon/human/consistent, locate(host.x, host.y - 2, host.z))
	dead.death()
	TEST_ASSERT(near in view(5, host), "The five-tile target is not actually visible in the native fixture.")
	TEST_ASSERT(!(covered in view(5, host)), "The opaque fixture does not actually block native vision.")
	var/datum/action/cooldown/paradise_zombie_scream/scream = locate() in host.actions
	TEST_ASSERT(scream.Trigger(host), "The target fixture could not trigger its real scream.")
	TEST_ASSERT(near.has_status_effect(/datum/status_effect/paradise_zombie_scream/fear), "The real scream missed a visible target exactly five tiles away.")
	for(var/mob/living/immune as anything in list(far, covered, incubating, zombie, dead, host))
		TEST_ASSERT_NULL(immune.has_status_effect(/datum/status_effect/paradise_zombie_scream/fear), "The scream incorrectly frightened [immune] outside its eligible targets.")
	infection = new()
	TEST_ASSERT(near.ForceContractDisease(infection, make_copy = FALSE, del_on_fail = TRUE), "The frightened target could not become infected.")
	var/deadline = world.time + 2 SECONDS
	UNTIL(!near.has_status_effect(/datum/status_effect/paradise_zombie_scream/fear) || world.time >= deadline)
	TEST_ASSERT_NULL(near.has_status_effect(/datum/status_effect/paradise_zombie_scream/fear), "Becoming infected did not clear existing fear through its native tick.")

/** Final delay factors remain exact with foreign additives; a second caster refreshes one ten-second fear. */
/datum/unit_test/paradise_zombie_scream_speed_duration
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test

/datum/unit_test/paradise_zombie_scream_speed_duration/Run()
	var/mob/living/carbon/human/host = make_zombie(run_loc_floor_bottom_left)
	TEST_ASSERT(prepare_range(host, 8), "The speed fixture has no private native range.")
	var/mob/living/carbon/human/other = make_zombie(get_step(host, NORTH))
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, get_step(host, EAST))
	host.mob_mood.set_enabled(FALSE)
	victim.mob_mood.set_enabled(FALSE)
	host.update_movespeed()
	victim.update_movespeed()
	var/host_base = host.cached_multiplicative_slowdown
	var/victim_base = victim.cached_multiplicative_slowdown
	TEST_ASSERT(host_base > 0 && victim_base > 0, "The speed fixture has no positive native movement delay.")
	var/datum/action/cooldown/paradise_zombie_scream/scream = locate() in host.actions
	var/started_at = world.time
	TEST_ASSERT(scream.Trigger(host), "The speed fixture could not trigger its first real scream.")
	TEST_ASSERT(abs(host.cached_multiplicative_slowdown - host_base / 1.1) < 0.0001, "Haste did not increase actual cached movement speed by exactly ten percent.")
	TEST_ASSERT(abs(victim.cached_multiplicative_slowdown - victim_base / 0.9) < 0.0001, "Fear did not reduce actual cached movement speed by exactly ten percent.")
	TEST_ASSERT_EQUAL(scream.next_use_time, started_at + 30 SECONDS, "The real scream did not start its thirty-second cooldown.")
	TEST_ASSERT(!scream.Trigger(host), "The real scream ignored its active cooldown.")
	var/datum/movespeed_modifier/foreign = get_cached_movespeed_modifier(/datum/movespeed_modifier/paradise_zombie_scream_test)
	host.add_movespeed_modifier(foreign)
	victim.add_movespeed_modifier(foreign)
	TEST_ASSERT(abs(host.cached_multiplicative_slowdown - (host_base + foreign.get_rp_speed()) / 1.1) < 0.0001, "Haste stopped scaling the final delay after another source added a slowdown.")
	TEST_ASSERT(abs(victim.cached_multiplicative_slowdown - (victim_base + foreign.get_rp_speed()) / 0.9) < 0.0001, "Fear stopped scaling the final delay after another source added a slowdown.")
	var/datum/status_effect/paradise_zombie_scream/fear/fear = victim.has_status_effect(/datum/status_effect/paradise_zombie_scream/fear)
	sleep(1 SECONDS)
	var/remaining_before = fear.duration
	var/datum/action/cooldown/paradise_zombie_scream/second_scream = locate() in other.actions
	TEST_ASSERT(second_scream.Trigger(other), "A different zombie could not trigger its independent scream.")
	TEST_ASSERT_EQUAL(victim.has_status_effect(/datum/status_effect/paradise_zombie_scream/fear), fear, "A second caster replaced fear with a stacking instance.")
	TEST_ASSERT(fear.duration > remaining_before, "A different caster did not refresh the existing fear duration.")
	var/fear_count = 0
	for(var/datum/status_effect/paradise_zombie_scream/fear/effect in victim.status_effects)
		fear_count++
	TEST_ASSERT_EQUAL(fear_count, 1, "Different screams stacked multiple fear status effects.")
	TEST_ASSERT(abs(victim.cached_multiplicative_slowdown - (victim_base + foreign.get_rp_speed()) / 0.9) < 0.0001, "A different scream stacked a second movement factor.")
	var/refreshed_at = world.time
	sleep(8 SECONDS)
	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/paradise_zombie_scream/fear), "Refreshed fear expired before its real ten seconds elapsed.")
	var/deadline = refreshed_at + 12 SECONDS
	UNTIL(!victim.has_status_effect(/datum/status_effect/paradise_zombie_scream/fear) || world.time >= deadline)
	TEST_ASSERT_NULL(victim.has_status_effect(/datum/status_effect/paradise_zombie_scream/fear), "Refreshed fear did not expire through the native status subsystem.")
	TEST_ASSERT_NULL(host.has_status_effect(/datum/status_effect/paradise_zombie_scream/haste), "The original ten-second haste did not expire.")
	TEST_ASSERT(host.has_movespeed_modifier(foreign) && victim.has_movespeed_modifier(foreign), "Scream expiry removed an independent movement modifier.")
	TEST_ASSERT(abs(host.cached_multiplicative_slowdown - host_base - foreign.get_rp_speed()) < 0.0001, "Haste expiry failed to restore the independent baseline delay.")
	TEST_ASSERT(abs(victim.cached_multiplicative_slowdown - victim_base - foreign.get_rp_speed()) < 0.0001, "Fear expiry failed to restore the independent baseline delay.")
	TEST_ASSERT(!scream.Trigger(host), "The expired ten-second effect incorrectly refunded its thirty-second cooldown.")

/** Native NOSLOW still blocks fear, while the caster's explicit IGNORE_NOSLOW boost remains effective. */
/datum/unit_test/paradise_zombie_scream_noslow
	parent_type = /datum/unit_test/paradise_zombie_mutation_test

/datum/unit_test/paradise_zombie_scream_noslow/Run()
	var/mob/living/carbon/human/host = make_zombie(run_loc_floor_bottom_left)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, get_step(host, EAST))
	host.ignore_slowdown(TRAIT_GENERIC)
	victim.ignore_slowdown(TRAIT_GENERIC)
	var/host_base = host.cached_multiplicative_slowdown
	var/victim_base = victim.cached_multiplicative_slowdown
	TEST_ASSERT(host_base > 0, "The NOSLOW fixture has no positive native baseline to boost.")
	var/datum/action/cooldown/paradise_zombie_scream/scream = locate() in host.actions
	TEST_ASSERT(scream.Trigger(host), "The NOSLOW caster could not use its real scream.")
	TEST_ASSERT(abs(host.cached_multiplicative_slowdown - host_base / 1.1) < 0.0001, "NOSLOW incorrectly filtered the caster's explicit haste boost.")
	TEST_ASSERT_EQUAL(victim.cached_multiplicative_slowdown, victim_base, "Fear bypassed the victim's native NOSLOW protection.")

/** Death and a real mind transfer cancel only the departing caster's current haste. */
/datum/unit_test/paradise_zombie_scream_interruptions
	parent_type = /datum/unit_test/paradise_zombie_mutation_test

/datum/unit_test/paradise_zombie_scream_interruptions/Run()
	for(var/scenario in list("death", "mind"))
		var/mob/living/carbon/human/host = make_zombie(run_loc_floor_bottom_left)
		var/datum/action/cooldown/paradise_zombie_scream/scream = locate() in host.actions
		host.add_movespeed_modifier(/datum/movespeed_modifier/paradise_zombie_scream_test)
		TEST_ASSERT(scream.Trigger(host), "The [scenario] fixture could not trigger its real scream.")
		TEST_ASSERT(host.has_status_effect(/datum/status_effect/paradise_zombie_scream/haste), "The [scenario] fixture has no real haste to cancel.")
		var/mob/living/carbon/human/recipient
		if(scenario == "death")
			host.death()
		else
			recipient = allocate(/mob/living/carbon/human/consistent, get_step(host, EAST))
			host.mind.transfer_to(recipient)
		TEST_ASSERT_NULL(host.has_status_effect(/datum/status_effect/paradise_zombie_scream/haste), "[scenario] retained the old caster's haste.")
		TEST_ASSERT(host.has_movespeed_modifier(/datum/movespeed_modifier/paradise_zombie_scream_test), "[scenario] removed another source's movement modifier.")
		if(recipient)
			TEST_ASSERT_NULL(recipient.has_status_effect(/datum/status_effect/paradise_zombie_scream/haste), "The departing mind carried haste into its healthy new body.")

#endif
