/// Physical installation, native IPC hardware and inherited exceptions must use the agreed costs.
/datum/unit_test/cyberpsychosis_load/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/datum/component/cyberpsychosis/load = human.GetComponent(/datum/component/cyberpsychosis)
	TEST_ASSERT_EQUAL(load.load, 0, "An unaugmented body has burden.")
	var/obj/item/organ/heart/cybernetic/heart = allocate(/obj/item/organ/heart/cybernetic)
	heart.Insert(human)
	TEST_ASSERT_EQUAL(load.load, 0, "A basic cybernetic heart is not safe.")
	var/obj/item/organ/heart/cybernetic/tier2/tier2 = allocate(/obj/item/organ/heart/cybernetic/tier2)
	tier2.Insert(human)
	TEST_ASSERT_EQUAL(load.load, 1, "Tier 2 heart must count once, as 1.")
	var/obj/item/organ/heart/cybernetic/tier3/tier3 = allocate(/obj/item/organ/heart/cybernetic/tier3)
	tier3.Insert(human)
	TEST_ASSERT_EQUAL(load.load, 2, "Tier 3 heart must replace, not add to, tier 2 burden.")
	var/obj/item/implant/tracking/tracker = allocate(/obj/item/implant/tracking)
	TEST_ASSERT_EQUAL(load.load, 2, "An uninstalled implant contributed burden.")
	tracker.implant(human, silent = TRUE, force = TRUE)
	TEST_ASSERT_EQUAL(load.load, 4, "An ordinary installed implant must add 2.")
	tracker.removed(human)
	TEST_ASSERT_EQUAL(load.load, 2, "Removed implant retained burden.")
	tier3.Remove(human)
	TEST_ASSERT_EQUAL(load.load, 0, "Removed organ retained burden.")
	human.set_species(/datum/species/ipc)
	TEST_ASSERT_EQUAL(load.load, 0, "Native IPC body/organs/charging cord must be safe.")
	var/obj/item/organ/cyberimp/chest/ipc_upgrade/repair/upgrade = allocate(/obj/item/organ/cyberimp/chest/ipc_upgrade/repair)
	upgrade.Insert(human)
	TEST_ASSERT_EQUAL(load.load, 1, "An IPC upgrade must add exactly 1.")

/// Guard the exceptions which inherit from otherwise burdened families.
/datum/unit_test/cyberpsychosis_exceptions/Run()
	var/list/cases = list(
		/obj/item/organ/cyberimp/arm/toolkit/mantis = 4,
		/obj/item/organ/cyberimp/arm/strongarm = 3,
		/obj/item/organ/cyberimp/arm/toolkit/centcom = 0,
		/obj/item/organ/cyberimp/arm/toolkit/shard = 0,
		/obj/item/organ/cyberimp/arm/toolkit/medibeam = 0,
		/obj/item/organ/cyberimp/arm/toolkit/custom = 0,
		/obj/item/organ/cyberimp/chest/pump/centcom = 0,
		/obj/item/organ/cyberimp/chest/pump/sansufentanyl = 3,
		/obj/item/organ/cyberimp/eyes/hud/security/shielded = 0,
		/obj/item/organ/eyes/robotic/shield = 2,
		/obj/item/organ/eyes/robotic/tacvisor/centcom = 0,
		/obj/item/organ/eyes/robotic/tacvisor/deathsquad = 0,
		/obj/item/organ/eyes/robotic/kaleido = 4,
		/obj/item/implant/abductor = 0,
		/obj/item/implant/nuclear_operative = 0,
		/obj/item/implant/radio/slime = 0,
		/obj/item/implant/radio/antenna = 0,
		/obj/item/implant/spell = 0,
		/obj/item/implant/sad_trombone = 2,
	)
	for(var/obj/item/item_type as anything in cases)
		TEST_ASSERT_EQUAL(initial(item_type.cyberpsychosis_load), cases[item_type], "Incorrect burden for [item_type].")
	for(var/obj/item/implant/explosive/bomb_type as anything in typesof(/obj/item/implant/explosive))
		TEST_ASSERT_EQUAL(initial(bomb_type.cyberpsychosis_load), 0, "A bomb variant inherited burden: [bomb_type].")
	for(var/obj/item/skillchip/chip_type as anything in typesof(/obj/item/skillchip))
		TEST_ASSERT_EQUAL(initial(chip_type.cyberpsychosis_load), 0, "A skillchip inherited burden: [chip_type].")
	for(var/obj/item/bodypart/limb_type as anything in typesof(/obj/item/bodypart))
		TEST_ASSERT_EQUAL(initial(limb_type.cyberpsychosis_load), 0, "A bodypart inherited burden: [limb_type].")

/// Exercise the production callbacks with physically implanted hardware, including death/revival.
/datum/unit_test/cyberpsychosis_buildup/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/datum/component/cyberpsychosis/load = human.GetComponent(/datum/component/cyberpsychosis)
	for(var/index in 1 to 10)
		var/obj/item/implant/tracking/tracker = allocate(/obj/item/implant/tracking)
		tracker.allow_multiple = TRUE
		tracker.implant(human, silent = TRUE, force = TRUE)
	TEST_ASSERT_EQUAL(load.load, 20, "Ten ordinary implants must total 20.")
	TEST_ASSERT_NULL(load.buildup_timer, "Safe load started an interval.")
	var/obj/item/organ/heart/cybernetic/tier2/heart = allocate(/obj/item/organ/heart/cybernetic/tier2)
	heart.Insert(human)
	TEST_ASSERT_EQUAL(load.load, 21, "Expected 21 after installing tier 2 heart.")
	TEST_ASSERT_NOTNULL(load.buildup_timer, "Crossing the limit did not start an interval.")
	TEST_ASSERT_EQUAL(load.buildup_interval, 30 SECONDS, "Wrong buildup interval.")
	var/interval = load.buildup_timer
	load.update_load()
	TEST_ASSERT_EQUAL(load.buildup_timer, interval, "Recalculation postponed an existing interval.")
	load.stop_timer()
	load.advance_buildup()
	TEST_ASSERT_EQUAL(load.buildup, 1, "Load 21 must add exactly 1 per interval.")
	var/obj/item/organ/cyberimp/brain/anti_drop/combat_implant = allocate(/obj/item/organ/cyberimp/brain/anti_drop)
	combat_implant.Insert(human)
	TEST_ASSERT_EQUAL(load.load, 24, "Expected 24 with combat implant.")
	load.stop_timer()
	load.advance_buildup()
	TEST_ASSERT_EQUAL(load.buildup, 5, "Load 24 must add exactly 4 per interval.")
	load.buildup = 96
	load.stop_timer()
	load.advance_buildup()
	var/datum/status_effect/forced_combat/cyberpsychosis/episode = human.has_status_effect(/datum/status_effect/forced_combat/cyberpsychosis)
	TEST_ASSERT_NOTNULL(episode, "Reaching 100 failed to start an episode.")
	TEST_ASSERT_EQUAL(episode.duration, 40 SECONDS, "Episode does not last 40 seconds.")
	TEST_ASSERT_NULL(load.buildup_timer, "Buildup continued during an episode.")
	load.advance_buildup()
	TEST_ASSERT_EQUAL(load.buildup, 100, "Episode accrued more burden.")
	combat_implant.Remove(human)
	heart.Remove(human)
	TEST_ASSERT_EQUAL(load.buildup, 0, "Returning to safe load did not clear buildup.")
	TEST_ASSERT(!QDELETED(episode), "Removing implants prematurely ended the active episode.")
	episode.process(39)
	TEST_ASSERT(!QDELETED(episode), "Episode ended before 40 seconds.")
	episode.process(1)
	TEST_ASSERT(QDELETED(episode), "Episode did not end after its duration.")
	TEST_ASSERT_NULL(load.buildup_timer, "Safe body restarted buildup after episode.")
	heart.Insert(human)
	load.buildup = 99
	load.stop_timer()
	load.advance_buildup()
	episode = human.has_status_effect(/datum/status_effect/forced_combat/cyberpsychosis)
	human.death()
	TEST_ASSERT(QDELETED(episode), "Death did not immediately end cyberpsychosis.")
	TEST_ASSERT_EQUAL(load.buildup, 0, "Death retained buildup.")
	TEST_ASSERT_NULL(load.buildup_timer, "A corpse kept its buildup timer.")
	load.advance_buildup()
	TEST_ASSERT_EQUAL(load.buildup, 0, "A corpse accumulated buildup.")
	human.revive(ADMIN_HEAL_ALL)
	TEST_ASSERT_NOTNULL(load.buildup_timer, "Revival did not start a fresh interval.")
	TEST_ASSERT_EQUAL(load.buildup, 0, "Revival inherited the previous meter.")

/// Retargeting, held-weapon attacks, speed modifiers and teardown use real mobs/items.
/datum/unit_test/cyberpsychosis_combat/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/current = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/closer = allocate(/mob/living/carbon/human/consistent)
	var/turf/origin = run_loc_floor_bottom_left
	human.forceMove(origin)
	current.forceMove(locate(origin.x + 3, origin.y, origin.z))
	closer.forceMove(locate(origin.x, origin.y + 1, origin.z))
	human.changeNext_move(10)
	var/baseline_delay = human.next_move - world.time
	var/datum/status_effect/forced_combat/cyberpsychosis/episode = human.apply_status_effect(/datum/status_effect/forced_combat/cyberpsychosis)
	episode.target_ref = WEAKREF(current)
	TEST_ASSERT_EQUAL(episode.select_target(), current, "A target closer than four tiles was abandoned.")
	current.forceMove(locate(origin.x + 4, origin.y, origin.z))
	TEST_ASSERT_EQUAL(episode.select_target(), closer, "Did not switch to a closer target at four tiles.")
	closer.death()
	TEST_ASSERT_EQUAL(episode.select_target(), current, "Selected a dead target.")
	closer.revive(ADMIN_HEAL_ALL)
	episode.target_ref = WEAKREF(closer)
	var/obj/item/crowbar/weapon = allocate(/obj/item/crowbar)
	human.put_in_active_hand(weapon)
	human.next_move = 0
	episode.perform_attack()
	TEST_ASSERT(closer.get_brute_loss() > 0, "Forced attack failed to use the held weapon.")
	TEST_ASSERT_EQUAL(human.get_active_held_item(), weapon, "Forced attack lost the active item.")
	human.changeNext_move(10)
	TEST_ASSERT_EQUAL(human.next_move - world.time, baseline_delay * 0.8, "Episode did not multiply the attack cooldown by 0.8.")
	var/mob/living/cyberpsychosis_backseat/seat = episode.backseat
	TEST_ASSERT(!seat.Move(get_step(origin, NORTH)), "The backseat can move independently.")
	TEST_ASSERT(!seat.try_speak("test"), "The backseat can speak.")
	episode.tick(0.5)
	var/datum/move_loop/loop = episode.pursuit
	if(loop)
		ADD_TRAIT(human, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
		TEST_ASSERT_EQUAL(episode.before_move(loop), MOVELOOP_SKIP_STEP, "Pursuit ignored immobilization.")
		REMOVE_TRAIT(human, TRAIT_IMMOBILIZED, TRAIT_SOURCE_UNIT_TESTS)
	qdel(episode)
	TEST_ASSERT(QDELETED(seat), "Temporary seat leaked after removal.")
	TEST_ASSERT(!loop || QDELETED(loop), "Pursuit remained active after episode removal.")
	human.changeNext_move(10)
	TEST_ASSERT_EQUAL(human.next_move - world.time, baseline_delay, "Attack speed did not return to normal.")

/// Key handoff must retain the original mind and restore disconnected players too.
/datum/unit_test/cyberpsychosis_control/Run()
	var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
	human.ckey = "CyberpsychosisUnitTest"
	human.mind_initialize()
	var/datum/mind/original_mind = human.mind
	var/original_key = human.ckey
	var/datum/status_effect/forced_combat/cyberpsychosis/episode = human.apply_status_effect(/datum/status_effect/forced_combat/cyberpsychosis)
	var/mob/living/cyberpsychosis_backseat/seat = episode.backseat
	TEST_ASSERT_EQUAL(human.mind, original_mind, "Handoff replaced the character's mind.")
	TEST_ASSERT_EQUAL(original_mind.current, human, "Handoff moved the mind out of the body.")
	TEST_ASSERT_NULL(human.key, "Player retained direct control of the body.")
	TEST_ASSERT_EQUAL(seat.ckey, original_key, "The seat did not retain the disconnected player's key.")
	qdel(episode)
	TEST_ASSERT_EQUAL(human.ckey, original_key, "Ending the episode did not restore the disconnected player's key.")
	TEST_ASSERT_EQUAL(original_mind.current, human, "Ending the episode changed the mind's body.")
	episode = human.apply_status_effect(/datum/status_effect/forced_combat/cyberpsychosis)
	human.death()
	TEST_ASSERT(QDELETED(episode), "Death retained the control lock.")
	TEST_ASSERT_EQUAL(human.ckey, original_key, "Death did not return control to the dead body.")
	human.key = null

/// Borgs and the station AI must not accumulate burden or accept a forced episode.
/datum/unit_test/cyberpsychosis_silicon_exclusion/Run()
	var/mob/living/carbon/human/brain_donor = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/silicon/ai/ai = allocate(/mob/living/silicon/ai, run_loc_floor_bottom_left, brain_donor, /datum/ai_laws/default/asimov)
	var/mob/living/silicon/robot/borg = allocate(/mob/living/silicon/robot)
	for(var/mob/living/silicon/silicon as anything in list(ai, borg))
		TEST_ASSERT(!QDELETED(silicon), "The silicon fixture was deleted during initialization.")
		TEST_ASSERT_NULL(silicon.GetComponent(/datum/component/cyberpsychosis), "[silicon.type] received burden tracking.")
		silicon.apply_status_effect(/datum/status_effect/forced_combat/cyberpsychosis)
		TEST_ASSERT(!silicon.has_status_effect(/datum/status_effect/forced_combat/cyberpsychosis), "[silicon.type] accepted cyberpsychosis.")
		TEST_ASSERT_NULL(locate(/mob/living/cyberpsychosis_backseat) in silicon.contents, "An excluded silicon received a control lock.")

/// Native organs and biology must not add burden or bypass the shared episode lifecycle.
/datum/unit_test/cyberpsychosis_species/Run()
	var/list/species_types = list(
		/datum/species/human, /datum/species/human/felinid, /datum/species/lizard,
		/datum/species/moth, /datum/species/vox, /datum/species/ipc,
		/datum/species/vulpkanin, /datum/species/tajaran, /datum/species/skrell,
		/datum/species/resomi, /datum/species/ethereal, /datum/species/plasmaman,
		/datum/species/jelly, /datum/species/pod, /datum/species/skeleton,
		/datum/species/android, /datum/species/dullahan, /datum/species/golem,
	)
	for(var/species_type in species_types)
		var/mob/living/carbon/human/human = allocate(/mob/living/carbon/human/consistent)
		human.set_species(species_type)
		var/datum/component/cyberpsychosis/load = human.GetComponent(/datum/component/cyberpsychosis)
		var/native_load = species_type == /datum/species/android ? 1 : 0
		TEST_ASSERT_EQUAL(load.load, native_load, "Unexpected native organ burden for [species_type].")
		for(var/index in 1 to 11)
			var/obj/item/implant/tracking/tracker = allocate(/obj/item/implant/tracking)
			tracker.allow_multiple = TRUE
			tracker.implant(human, silent = TRUE, force = TRUE)
		TEST_ASSERT_EQUAL(load.load, 22 + native_load, "Implants counted incorrectly for [species_type].")
		TEST_ASSERT_NOTNULL(load.buildup_timer, "No buildup timer for [species_type].")
		load.stop_timer()
		load.buildup = 98
		load.advance_buildup()
		var/datum/status_effect/forced_combat/cyberpsychosis/episode = human.has_status_effect(/datum/status_effect/forced_combat/cyberpsychosis)
		TEST_ASSERT_NOTNULL(episode, "Episode failed to start for [species_type].")
		TEST_ASSERT_EQUAL(episode.nextmove_modifier(), 0.8, "Wrong attack speed for [species_type].")
		episode.laugh()
		TEST_ASSERT_EQUAL(episode.next_laugh, world.time + 5 SECONDS, "Wrong laugh interval for [species_type].")
		qdel(episode)
		TEST_ASSERT_EQUAL(load.buildup, 0, "Episode left buildup for [species_type].")
		TEST_ASSERT_NOTNULL(load.buildup_timer, "No fresh interval after episode for [species_type].")
		human.death()
		TEST_ASSERT_NULL(load.buildup_timer, "Dead [species_type] kept accumulating.")
		qdel(human)
