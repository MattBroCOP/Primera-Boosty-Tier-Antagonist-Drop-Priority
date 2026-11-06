#ifdef UNIT_TESTS

/** A real charge hits one victim after landing, expires its short hold and retains the original dash. */
/datum/unit_test/paradise_zombie_charger_impact
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test

/datum/unit_test/paradise_zombie_charger_impact/Run()
	var/mob/living/carbon/human/host = make_mutant("twitcher")
	TEST_ASSERT(prepare_range(host), "The Charger fixture could not reserve its actual flight range.")
	var/turf/launch_tile = get_turf(host)
	var/datum/action/cooldown/paradise_zombie_mutation/dash/charge/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "Twitcher did not receive its separate charge action.")
	var/original_dash = FALSE
	for(var/datum/action/cooldown/paradise_zombie_mutation/dash/dash in host.actions)
		original_dash ||= dash.type == /datum/action/cooldown/paradise_zombie_mutation/dash
	TEST_ASSERT(original_dash, "Adding Charger removed the original Twitcher dash.")
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, locate(host.x + 5, host.y, host.z))
	var/mob/living/carbon/human/behind = allocate(/mob/living/carbon/human/consistent, locate(host.x + 7, host.y, host.z))
	var/old_cooldown = action.next_use_time
	ADD_TRAIT(host, TRAIT_PACIFISM, "charger_pacifism_test")
	TEST_ASSERT(!action.Trigger(host, target = victim), "A pacifist launched the real charge action.")
	TEST_ASSERT(!host.throwing && !length(action.owned_effects), "A rejected pacifist charge created a real flight or hold.")
	TEST_ASSERT_EQUAL(action.next_use_time, old_cooldown, "A rejected pacifist charge spent its cooldown.")
	REMOVE_TRAIT(host, TRAIT_PACIFISM, "charger_pacifism_test")
	var/started_at = world.time
	TEST_ASSERT(action.Trigger(host, target = victim), "The native charge button did not launch its real flight.")
	var/deadline = world.time + 5 SECONDS
	UNTIL(victim.has_status_effect(/datum/status_effect/paradise_zombie_pin) || world.time >= deadline)
	var/datum/status_effect/paradise_zombie_pin/pin = victim.has_status_effect(/datum/status_effect/paradise_zombie_pin)
	TEST_ASSERT_NOTNULL(pin, "The real charge never applied its two-second hold.")
	TEST_ASSERT_NULL(host.throwing, "The hold began before native landing had stopped the caster.")
	TEST_ASSERT_EQUAL(victim.get_brute_loss(), 20, "The charge delivered duplicate impacts or used claw damage instead of its twenty-point strike.")
	TEST_ASSERT_EQUAL(behind.get_brute_loss(), 0, "The charge struck a second enemy behind its first victim.")
	TEST_ASSERT(pin in action.owned_effects, "The landed charge did not own its real pin.")
	TEST_ASSERT_EQUAL(action.next_use_time, started_at + 20 SECONDS, "The real charge did not spend its twenty-second cooldown.")
	deadline = world.time + 3 SECONDS
	UNTIL(QDELETED(pin) || world.time >= deadline)
	TEST_ASSERT(QDELETED(pin) && !HAS_TRAIT(victim, TRAIT_IMMOBILIZED), "The short charge hold became permanent.")
	TEST_ASSERT_EQUAL(victim.get_brute_loss(), 20, "The short Charger hold inflicted unrequested periodic damage.")
	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/paradise_zombie_pin_recovery), "Charge expiry did not grant the shared recovery period.")

	qdel(victim)
	qdel(behind)
	host.forceMove(launch_tile)
	var/mob/living/carbon/human/friend = make_zombie(locate(host.x + 2, host.y, host.z))
	action.ResetCooldown()
	TEST_ASSERT(action.Trigger(host, target = locate(host.x + 14, host.y, host.z)), "The charge could not launch toward a point beyond its cap.")
	deadline = world.time + 5 SECONDS
	UNTIL(!host.throwing || world.time >= deadline)
	TEST_ASSERT_EQUAL(friend.get_brute_loss(), 0, "The charge damaged an allied zombie in its path.")
	TEST_ASSERT(!friend.has_status_effect(/datum/status_effect/paradise_zombie_pin), "The charge captured an allied zombie.")
	qdel(friend)
	host.forceMove(launch_tile)
	var/obj/structure/window/window = allocate(/obj/structure/window/reinforced/fulltile, locate(host.x + 3, host.y, host.z))
	var/integrity_before = window.get_integrity()
	action.ResetCooldown()
	TEST_ASSERT(action.Trigger(host, target = locate(host.x + 14, host.y, host.z)), "The obstacle charge did not launch.")
	deadline = world.time + 5 SECONDS
	UNTIL(!host.throwing || world.time >= deadline)
	TEST_ASSERT(!host.throwing && get_dist(host, launch_tile) <= 3, "The charge passed through its first solid obstacle.")
	TEST_ASSERT_EQUAL(window.get_integrity(), integrity_before, "The charge reused the plague leap's destructive obstacle impact.")
	qdel(window)
	host.forceMove(launch_tile)
	action.ResetCooldown()
	TEST_ASSERT(action.Trigger(host, target = locate(host.x + 14, host.y, host.z)), "The capped empty-lane charge did not launch.")
	deadline = world.time + 5 SECONDS
	UNTIL(!host.throwing || world.time >= deadline)
	TEST_ASSERT(!host.throwing && get_dist(host, launch_tile) == 12, "The real charge did not stop at twelve tiles.")

/** Both a pending flight and a landed hold obey their physical owner's real interruption paths. */
/datum/unit_test/paradise_zombie_charger_cleanup
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test
	abstract_type = /datum/unit_test/paradise_zombie_charger_cleanup
	var/interruption

/datum/unit_test/paradise_zombie_charger_cleanup/damage
	interruption = "damage"

/datum/unit_test/paradise_zombie_charger_cleanup/cure
	interruption = "cure"

/datum/unit_test/paradise_zombie_charger_cleanup/mind_transfer
	interruption = "mind_transfer"

/datum/unit_test/paradise_zombie_charger_cleanup/flight_cure
	interruption = "flight_cure"

/datum/unit_test/paradise_zombie_charger_cleanup/flight_pacifism
	interruption = "flight_pacifism"

/datum/unit_test/paradise_zombie_charger_cleanup/pacifism
	interruption = "pacifism"

/datum/unit_test/paradise_zombie_charger_cleanup/Run()
	var/mob/living/carbon/human/host = make_mutant("twitcher")
	TEST_ASSERT(prepare_range(host), "The interruption fixture could not reserve its flight range.")
	var/datum/action/cooldown/paradise_zombie_mutation/dash/charge/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "The interruption fixture did not receive its charge action.")
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, locate(host.x + 4, host.y, host.z))
	TEST_ASSERT(action.Trigger(host, target = victim), "The interrupted charge did not launch through its native button.")
	if(interruption in list("flight_cure", "flight_pacifism"))
		var/datum/thrownthing/flight = host.throwing
		TEST_ASSERT_NOTNULL(flight, "The [interruption] fixture did not retain a real pending flight.")
		if(interruption == "flight_cure")
			var/datum/disease/paradise_zombie/infection = locate() in host.diseases
			infection.cure()
			TEST_ASSERT(QDELETED(flight) && !host.throwing, "Cure retained the charge's actual flight.")
			sleep(1 SECONDS)
		else
			ADD_TRAIT(host, TRAIT_PACIFISM, "charger_pacifism_test")
			var/deadline = world.time + 5 SECONDS
			UNTIL(!host.throwing || world.time >= deadline)
			TEST_ASSERT(!host.throwing && QDELETED(flight), "The newly pacifist caster's real flight did not finish naturally.")
		TEST_ASSERT_EQUAL(victim.get_brute_loss(), 0, "The real [interruption] flight delivered a stale impact later.")
		TEST_ASSERT(!victim.has_status_effect(/datum/status_effect/paradise_zombie_pin), "The real [interruption] flight created a delayed hold.")
		return
	var/deadline = world.time + 5 SECONDS
	UNTIL(victim.has_status_effect(/datum/status_effect/paradise_zombie_pin) || world.time >= deadline)
	var/datum/status_effect/paradise_zombie_pin/pin = victim.has_status_effect(/datum/status_effect/paradise_zombie_pin)
	TEST_ASSERT_NOTNULL(pin, "The interruption fixture never acquired its real short hold.")
	switch(interruption)
		if("damage")
			host.adjust_fire_loss(1)
		if("cure")
			var/datum/disease/paradise_zombie/infection = locate() in host.diseases
			infection.cure()
		if("mind_transfer")
			var/datum/mind/original_mind = host.mind
			var/mob/living/carbon/human/destination = allocate(/mob/living/carbon/human/consistent, run_loc_floor_top_right)
			original_mind.transfer_to(destination)
			original_mind.transfer_to(host)
		if("pacifism")
			ADD_TRAIT(host, TRAIT_PACIFISM, "charger_pacifism_test")
			deadline = world.time + 1.5 SECONDS
			UNTIL(QDELETED(pin) || world.time >= deadline)
	TEST_ASSERT(QDELETED(pin), "The real [interruption] path retained the charge's hold.")
	TEST_ASSERT(!HAS_TRAIT(victim, TRAIT_IMMOBILIZED) && !HAS_TRAIT(victim, TRAIT_HANDS_BLOCKED), "An interrupted charge left restraint traits on its victim.")

#endif
