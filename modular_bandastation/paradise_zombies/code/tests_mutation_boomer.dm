#ifdef UNIT_TESTS

/** Actual five-tile shots preserve allies, native blindness ownership, washing and finite expiry. */
/datum/unit_test/paradise_zombie_boomer_vomit
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test

/datum/unit_test/paradise_zombie_boomer_vomit/Run()
	var/mob/living/carbon/human/host = make_mutant("exploder")
	TEST_ASSERT(prepare_range(host), "The Boomer fixture could not reserve a projectile range.")
	var/datum/action/cooldown/paradise_zombie_mutation/vomit_bile/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "Exploder did not receive its separate bile-vomit action.")
	TEST_ASSERT(locate(/datum/action/cooldown/paradise_zombie_mutation/explode) in host.actions, "Adding bile vomit removed the original self-detonation.")
	var/old_cooldown = action.next_use_time
	TEST_ASSERT(!action.Trigger(host, target = locate(host.x + 6, host.y, host.z)), "Bile vomit accepted a target beyond five tiles.")
	TEST_ASSERT_EQUAL(action.next_use_time, old_cooldown, "Rejecting a distant target consumed bile vomit's cooldown.")
	TEST_ASSERT(!action.Trigger(host, target = locate(host.x + 4, host.y + 4, host.z)), "Bile vomit accepted a diagonal target beyond its real projectile flight range.")
	TEST_ASSERT_EQUAL(action.next_use_time, old_cooldown, "Rejecting a distant diagonal target consumed bile vomit's cooldown.")
	TEST_ASSERT_EQUAL(length(action.owned_effects), 0, "Rejecting distant targets created a projectile or vision effect.")
	var/mob/living/carbon/human/friend = make_zombie(locate(host.x + 2, host.y, host.z))
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, locate(host.x + 5, host.y, host.z))
	victim.mock_client = new()
	TEST_ASSERT(!action.Trigger(host, target = friend), "Bile vomit accepted an allied zombie as its direct target.")
	var/started_at = world.time
	TEST_ASSERT(action.Trigger(host, target = victim), "The real bile-vomit button did not launch its visible projectile.")
	var/deadline = world.time + 4 SECONDS
	UNTIL(victim.has_status_effect(/datum/status_effect/paradise_zombie_boomer_bile) || world.time >= deadline)
	var/datum/status_effect/paradise_zombie_boomer_bile/bile = victim.has_status_effect(/datum/status_effect/paradise_zombie_boomer_bile)
	TEST_ASSERT_NOTNULL(bile, "The actual vomit projectile did not reach its enemy five tiles away.")
	TEST_ASSERT(bile in action.owned_effects, "The action did not own its landed vision effect.")
	var/bile_source = REF(bile)
	TEST_ASSERT(victim.is_blind_from(bile_source), "Bile did not enter the native grouped blindness system.")
	TEST_ASSERT(locate(/atom/movable/screen/fullscreen/blind) in assoc_to_values(victim.screens), "The native blind effect did not create its real fullscreen overlay.")
	TEST_ASSERT(!friend.is_blind(), "The vomit projectile blinded the allied zombie in its path.")
	TEST_ASSERT_EQUAL(victim.get_brute_loss() + victim.get_fire_loss(), 0, "The blinding vomit inflicted unrequested physical damage.")
	TEST_ASSERT_EQUAL(action.next_use_time, started_at + 20 SECONDS, "Bile vomit did not spend its twenty-second cooldown.")
	victim.become_blind("foreign_boomer_test_source")
	victim.wash(CLEAN_TYPE_BLOOD)
	TEST_ASSERT(QDELETED(bile) && !victim.is_blind_from(bile_source), "Native washing failed to remove the bile's own blindness source.")
	TEST_ASSERT(victim.is_blind_from("foreign_boomer_test_source"), "Washing bile erased unrelated native blindness.")
	victim.cure_blind("foreign_boomer_test_source")
	TEST_ASSERT(!victim.is_blind(), "Washing left the victim permanently blind after all external sources were removed.")
	action.ResetCooldown()
	TEST_ASSERT(action.Trigger(host, target = victim), "The finite-expiry shot did not launch.")
	deadline = world.time + 4 SECONDS
	UNTIL(victim.has_status_effect(/datum/status_effect/paradise_zombie_boomer_bile) || world.time >= deadline)
	bile = victim.has_status_effect(/datum/status_effect/paradise_zombie_boomer_bile)
	TEST_ASSERT_NOTNULL(bile, "The expiry fixture did not receive its actual vomit hit.")
	deadline = world.time + 6 SECONDS
	UNTIL(QDELETED(bile) || world.time >= deadline)
	TEST_ASSERT(QDELETED(bile) && !victim.is_blind(), "The five-second vomit blindness became permanent.")
	TEST_ASSERT(!(locate(/atom/movable/screen/fullscreen/blind) in assoc_to_values(victim.screens)), "Expired bile retained its native blind overlay.")

/** Solid cover and complete BIO armour stop actual projectiles from applying the blind. */
/datum/unit_test/paradise_zombie_boomer_cover
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test

/datum/unit_test/paradise_zombie_boomer_cover/Run()
	var/mob/living/carbon/human/host = make_mutant("exploder")
	TEST_ASSERT(prepare_range(host), "The cover fixture could not reserve its projectile range.")
	var/datum/action/cooldown/paradise_zombie_mutation/vomit_bile/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "The cover fixture did not receive the bile-vomit action.")
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, locate(host.x + 5, host.y, host.z))
	var/obj/structure/window/window = allocate(/obj/structure/window/reinforced/fulltile, locate(host.x + 3, host.y, host.z))
	TEST_ASSERT(action.Trigger(host, target = victim), "The covered shot did not launch.")
	var/deadline = world.time + 4 SECONDS
	UNTIL(!length(action.owned_effects) || world.time >= deadline)
	TEST_ASSERT(!length(action.owned_effects) && !victim.is_blind(), "A vomit projectile crossed solid glass cover.")
	qdel(window)
	victim.add_inner_armor(get_armor_by_type(/datum/armor/paradise_zombie_test_bio))
	action.ResetCooldown()
	TEST_ASSERT(action.Trigger(host, target = victim), "The BIO-armour shot did not launch.")
	deadline = world.time + 4 SECONDS
	UNTIL(!length(action.owned_effects) || world.time >= deadline)
	TEST_ASSERT(!length(action.owned_effects) && !victim.is_blind(), "Complete BIO armour failed to stop the real vomit projectile's blind.")

/** Death, cure and mind transfer clean both an airborne shot and its already-applied native vision source. */
/datum/unit_test/paradise_zombie_boomer_cleanup
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test
	abstract_type = /datum/unit_test/paradise_zombie_boomer_cleanup
	var/interruption

/datum/unit_test/paradise_zombie_boomer_cleanup/cure
	interruption = "cure"

/datum/unit_test/paradise_zombie_boomer_cleanup/death
	interruption = "death"

/datum/unit_test/paradise_zombie_boomer_cleanup/mind_transfer
	interruption = "mind_transfer"

/datum/unit_test/paradise_zombie_boomer_cleanup/Run()
	var/mob/living/carbon/human/host = make_mutant("exploder")
	TEST_ASSERT(prepare_range(host), "The cleanup fixture could not reserve its projectile range.")
	var/datum/action/cooldown/paradise_zombie_mutation/vomit_bile/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "The cleanup fixture did not receive its real vomit action.")
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, locate(host.x + 5, host.y, host.z))
	TEST_ASSERT(action.Trigger(host, target = victim), "The cleanup fixture's first shot did not launch.")
	var/deadline = world.time + 4 SECONDS
	UNTIL(victim.has_status_effect(/datum/status_effect/paradise_zombie_boomer_bile) || world.time >= deadline)
	var/datum/status_effect/paradise_zombie_boomer_bile/bile = victim.has_status_effect(/datum/status_effect/paradise_zombie_boomer_bile)
	TEST_ASSERT_NOTNULL(bile, "The cleanup fixture did not receive its actual first hit.")
	victim.become_blind("foreign_boomer_cleanup")
	action.ResetCooldown()
	TEST_ASSERT(action.Trigger(host, target = locate(host.x + 4, host.y + 2, host.z)), "The cleanup fixture could not launch an airborne second shot.")
	var/obj/projectile/paradise_zombie_boomer_vomit/shot = locate() in action.owned_effects
	TEST_ASSERT_NOTNULL(shot, "The actual second shot was not owned while airborne.")
	switch(interruption)
		if("cure")
			var/datum/disease/paradise_zombie/infection = locate() in host.diseases
			infection.cure()
		if("death")
			host.death()
		if("mind_transfer")
			var/datum/mind/original_mind = host.mind
			var/mob/living/carbon/human/destination = allocate(/mob/living/carbon/human/consistent, run_loc_floor_top_right)
			original_mind.transfer_to(destination)
			original_mind.transfer_to(host)
	TEST_ASSERT(QDELETED(bile) && QDELETED(shot), "The real [interruption] path retained owned vomit effects.")
	TEST_ASSERT(victim.is_blind_from("foreign_boomer_cleanup"), "Caster cleanup erased the victim's foreign blindness source.")
	victim.cure_blind("foreign_boomer_cleanup")
	TEST_ASSERT(!victim.is_blind(), "Caster cleanup retained its temporary blindness after the external source was removed.")

#endif
