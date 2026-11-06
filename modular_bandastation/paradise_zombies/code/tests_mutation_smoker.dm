#ifdef UNIT_TESTS

/// Actual projectiles fly on the shared private ability range with a real Slasher controller.
/datum/unit_test/paradise_zombie_smoker_test
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test
	abstract_type = /datum/unit_test/paradise_zombie_smoker_test
	var/mob/living/carbon/human/host
	var/mob/living/carbon/human/victim
	var/datum/action/cooldown/paradise_zombie_mutation/tongue/action

/datum/unit_test/paradise_zombie_smoker_test/proc/prepare_smoker(distance = 6)
	host = make_mutant("slasher")
	TEST_ASSERT(prepare_range(host), "The tongue fixture has no private native range.")
	victim = allocate(/mob/living/carbon/human/consistent, locate(host.x + distance, host.y, host.z))
	action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "A real Slasher did not receive its tongue action.")
	return TRUE

/// Waits for a real projectile hit; no test calls the hit handler or installs a replacement throw.
/datum/unit_test/paradise_zombie_smoker_test/proc/launch_yank()
	action.ResetCooldown()
	victim.remove_status_effect(/datum/status_effect/paradise_zombie_pin_recovery)
	TEST_ASSERT(action.Trigger(host, target = victim), "The native tongue action did not launch.")
	var/deadline = world.time + 5 SECONDS
	UNTIL(victim.throwing || world.time >= deadline)
	var/datum/thrownthing/paradise_zombie_tongue/flight = victim.throwing
	TEST_ASSERT(istype(flight), "The real tongue projectile never started its own native yank.")
	return flight

/** The eight-tile tongue is visible, collision-driven, harmless and cannot become an aggressive grab. */
/datum/unit_test/paradise_zombie_smoker_hit
	parent_type = /datum/unit_test/paradise_zombie_smoker_test

/datum/unit_test/paradise_zombie_smoker_hit/Run()
	TEST_ASSERT(prepare_smoker(8), "The eight-tile tongue fixture was not prepared.")
	var/original_health = victim.health
	var/started_at = world.time
	TEST_ASSERT(action.Trigger(host, target = victim), "The tongue rejected a target exactly eight tiles away.")
	TEST_ASSERT(action.next_use_time >= started_at + 18 SECONDS, "The tongue did not consume its full eighteen-second cooldown.")
	var/obj/projectile/paradise_zombie_tongue/projectile = locate() in action.owned_effects
	TEST_ASSERT_NOTNULL(projectile, "The ability did not own an actual visible projectile.")
	TEST_ASSERT(projectile.is_hostile_projectile(), "The control projectile is incorrectly classified as a harmless shot.")
	TEST_ASSERT_EQUAL(projectile.icon_state, "tentacle_end", "The projectile lost its native tentacle artwork.")
	TEST_ASSERT_NOTNULL(projectile.tongue_beam, "The outgoing tongue has no native visible beam.")
	var/deadline = world.time + 5 SECONDS
	UNTIL(victim.throwing || world.time >= deadline)
	var/datum/thrownthing/paradise_zombie_tongue/flight = victim.throwing
	TEST_ASSERT(istype(flight), "The eight-tile projectile did not start its native pull.")
	TEST_ASSERT(flight in action.owned_effects, "The action did not own its victim's return flight.")
	TEST_ASSERT_NOTNULL(flight.tongue_beam, "The return flight lost its visible tongue.")
	deadline = world.time + 3 SECONDS
	UNTIL(!victim.throwing || world.time >= deadline)
	TEST_ASSERT_NULL(victim.throwing, "The short yank became an indefinite hold.")
	TEST_ASSERT_EQUAL(get_dist(host, victim), 1, "The collision-driven yank did not stop adjacent to the caster.")
	TEST_ASSERT_EQUAL(victim.health, original_health, "The tongue added an impact attack or damaging landing.")
	TEST_ASSERT_NULL(host.pulling, "The tongue installed a changeling's automatic grab.")
	TEST_ASSERT_NULL(victim.pulledby, "The finished yank left a lasting grab on its victim.")
	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/paradise_zombie_pin_recovery), "The completed yank omitted protection from chained control.")
	TEST_ASSERT(!action.can_hit(victim), "The tongue ignores the victim's shared recovery period.")
	// Reuse the same native range to check the human bullet_act -> check_block -> blocked=100 path.
	victim.forceMove(locate(host.x + 8, host.y, host.z))
	victim.remove_status_effect(/datum/status_effect/paradise_zombie_pin_recovery)
	var/turf/shielded_at = get_turf(victim)
	var/obj/item/shield/riot/shield = allocate(/obj/item/shield/riot)
	shield.block_chance = INFINITY
	TEST_ASSERT(victim.put_in_active_hand(shield, forced = TRUE), "The target could not hold its real projectile-blocking shield.")
	action.ResetCooldown()
	TEST_ASSERT(action.Trigger(host, target = victim), "The shield regression could not launch its real tongue projectile.")
	deadline = world.time + 5 SECONDS
	UNTIL(!length(action.owned_effects) || world.time >= deadline)
	TEST_ASSERT_EQUAL(length(action.owned_effects), 0, "The shielded tongue never finished its actual flight.")
	TEST_ASSERT_EQUAL(victim.loc, shielded_at, "The tongue pulled its target through a successful native shield block.")
	TEST_ASSERT_NULL(victim.throwing, "A shielded tongue still started its native yank.")
	TEST_ASSERT_EQUAL(victim.get_active_held_item(), shield, "The shielded tongue stole the target's held shield.")

/** Moving out of the shot and placing a real glass barrier both defeat the native projectile. */
/datum/unit_test/paradise_zombie_smoker_dodge_wall
	parent_type = /datum/unit_test/paradise_zombie_smoker_test

/datum/unit_test/paradise_zombie_smoker_dodge_wall/Run()
	TEST_ASSERT(prepare_smoker(), "The dodge fixture was not prepared.")
	var/turf/aimed_at = get_turf(victim)
	TEST_ASSERT(action.Trigger(host, target = victim), "The dodge fixture could not fire its real tongue.")
	TEST_ASSERT(victim.Move(get_step(victim, NORTH), NORTH), "The victim could not perform its actual dodging step.")
	var/turf/dodged_to = get_turf(victim)
	var/deadline = world.time + 5 SECONDS
	UNTIL(!length(action.owned_effects) || world.time >= deadline)
	TEST_ASSERT_EQUAL(victim.loc, dodged_to, "The tongue homed onto a victim who dodged its line.")
	TEST_ASSERT_NULL(victim.throwing, "A missed tongue still pulled the dodging victim.")
	TEST_ASSERT_EQUAL(length(action.owned_effects), 0, "The missed projectile or beam never expired.")
	victim.forceMove(aimed_at)
	var/obj/structure/window/fulltile/window = allocate(/obj/structure/window/fulltile, locate(host.x + 3, host.y, host.z))
	action.ResetCooldown()
	TEST_ASSERT(action.Trigger(host, target = victim), "The barrier fixture could not fire toward its blocked target.")
	deadline = world.time + 5 SECONDS
	UNTIL(!length(action.owned_effects) || world.time >= deadline)
	TEST_ASSERT_EQUAL(victim.loc, aimed_at, "The tongue pulled its target through a real full-tile window.")
	TEST_ASSERT_NULL(victim.throwing, "The blocked tongue started a pull behind glass.")
	TEST_ASSERT(!QDELETED(window), "A harmless tongue destroyed its glass counterplay.")
	action.ResetCooldown()
	var/cooldown_before = action.next_use_time
	TEST_ASSERT(!action.Trigger(host, target = locate(host.x + 9, host.y, host.z)), "The tongue accepted a target outside its eight-tile range.")
	TEST_ASSERT_EQUAL(action.next_use_time, cooldown_before, "Rejecting an out-of-range tongue consumed its cooldown.")
	TEST_ASSERT(!action.can_hit(host), "The tongue can hit its own caster.")
	qdel(window)
	TEST_ASSERT(action.Trigger(host, target = victim), "The outgoing cleanup fixture could not launch its tongue.")
	var/obj/projectile/paradise_zombie_tongue/projectile = locate() in action.owned_effects
	TEST_ASSERT_NOTNULL(projectile, "The outgoing cleanup fixture has no actual projectile.")
	var/datum/beam/outgoing_beam = projectile.tongue_beam
	var/datum/disease/paradise_zombie/infection = locate() in host.diseases
	infection.cure()
	TEST_ASSERT(QDELETED(action) && QDELETED(projectile) && QDELETED(outgoing_beam), "Cure retained the action, outgoing projectile or native tongue beam.")

/** Actual pulls end on resist, damage, incapacity, broken sight, death, mind transfer and surgical cure. */
/datum/unit_test/paradise_zombie_smoker_cleanup
	parent_type = /datum/unit_test/paradise_zombie_smoker_test

/datum/unit_test/paradise_zombie_smoker_cleanup/Run()
	TEST_ASSERT(prepare_smoker(), "The cleanup fixture was not prepared.")
	var/turf/victim_start = get_turf(victim)
	for(var/scenario in list("resist", "damage", "direct burn", "incapacity", "line", "death", "mind", "cure"))
		victim.forceMove(victim_start)
		var/datum/thrownthing/paradise_zombie_tongue/flight = launch_yank()
		TEST_ASSERT_NOTNULL(flight, "The [scenario] fixture did not create a real pull to cancel.")
		var/obj/structure/window/fulltile/window
		var/mob/living/carbon/human/recipient
		switch(scenario)
			if("resist")
				victim.execute_resist()
			if("damage")
				host.apply_damage(5, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND)
			if("direct burn")
				host.adjust_fire_loss(5)
			if("incapacity")
				host.Stun(2 SECONDS)
			if("line")
				window = allocate(/obj/structure/window/fulltile, locate(host.x + 1, host.y, host.z))
				flight.tick()
			if("death")
				host.death()
			if("mind")
				recipient = allocate(/mob/living/carbon/human/consistent, get_step(host, SOUTH))
				host.mind.transfer_to(recipient)
			if("cure")
				var/obj/item/organ/paradise_zombie_tumor/tumor = host.get_organ_slot(ORGAN_SLOT_ZOMBIE)
				tumor.Remove(host)
		TEST_ASSERT(QDELETED(flight), "[scenario] left the native yank active.")
		TEST_ASSERT_NULL(victim.throwing, "[scenario] left the victim's native throwing state behind.")
		TEST_ASSERT(victim.has_status_effect(/datum/status_effect/paradise_zombie_pin_recovery), "[scenario] omitted the victim's independent control recovery.")
		var/turf/stopped_at = get_turf(victim)
		sleep(0.2 SECONDS)
		TEST_ASSERT_EQUAL(victim.loc, stopped_at, "[scenario] left movement running after the tongue was severed.")
		qdel(window)
		if(scenario == "incapacity")
			host.SetStun(0)
		if(scenario == "death")
			var/datum/component/paradise_zombie_regen/regeneration = host.GetComponent(/datum/component/paradise_zombie_regen)
			TEST_ASSERT(regeneration.zombie_rejuv(), "The cleanup fixture could not revive between its independent scenarios.")
			host.get_up(TRUE)
		if(scenario == "mind")
			recipient.mind.transfer_to(host)
			var/datum/disease/paradise_zombie/infection = locate() in host.diseases
			infection.handle_rot()
			action = locate() in host.actions
			TEST_ASSERT_NOTNULL(action, "Returning to the still-mutated body did not restore its tongue action.")

#endif
