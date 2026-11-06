#ifdef UNIT_TESTS

/** Tripling Brute health must retain independent max-health changes and cellular injury through cure. */
/datum/unit_test/paradise_zombie_brute_health
	parent_type = /datum/unit_test/paradise_zombie_mutation_test

/datum/unit_test/paradise_zombie_brute_health/Run()
	var/mob/living/carbon/human/standard = make_mutant("brute")
	TEST_ASSERT_EQUAL(standard.maxHealth, 750, "An ordinary human's Brute form did not triple its former 250 maximum health.")
	var/datum/disease/paradise_zombie/infection = locate() in standard.diseases
	infection.cure()
	TEST_ASSERT_EQUAL(standard.maxHealth, 100, "Curing Brute failed to restore an ordinary human's original maximum health.")

	var/mob/living/carbon/human/host = make_zombie(run_loc_floor_bottom_left)
	host.setMaxHealth(140)
	var/datum/status_effect/paradise_cloning_damage/cellular_injury = host.apply_status_effect(/datum/status_effect/paradise_cloning_damage, 20)
	TEST_ASSERT_EQUAL(host.maxHealth, 120, "The health fixture did not acquire real independent cellular injury.")
	var/datum/component/paradise_zombie_mutation/controller = host.GetComponent(/datum/component/paradise_zombie_mutation)
	TEST_ASSERT(controller.apply_form("brute"), "The nonstandard injured body could not become a Brute.")
	TEST_ASSERT_EQUAL(host.maxHealth, 810, "Brute did not triple this body's existing 270 form maximum health.")
	host.setMaxHealth(host.maxHealth + 25)
	cellular_injury.change_amount(10)
	TEST_ASSERT_EQUAL(host.maxHealth, 825, "Independent health changes did not apply normally after mutation.")
	infection = locate() in host.diseases
	infection.cure()
	TEST_ASSERT_EQUAL(host.maxHealth, 135, "Cure erased a foreign health bonus or new cellular damage instead of subtracting only the applied mutation delta.")
	TEST_ASSERT_EQUAL(cellular_injury.amount, 30, "Curing the infection changed the separate cellular damage channel.")
	cellular_injury.change_amount(-30)
	TEST_ASSERT_EQUAL(host.maxHealth, 165, "Treating cellular injury after cure failed to retain both foreign health bonuses.")

/** Uses one reversible wall tile on the native unit-test level, retaining its original turf type. */
/datum/unit_test/paradise_zombie_brute_wall_test
	parent_type = /datum/unit_test/paradise_zombie_mutation_test
	abstract_type = /datum/unit_test/paradise_zombie_brute_wall_test
	var/old_wall_turf_type
	var/list/wall_coordinates
	var/tear_finished = FALSE
	var/tear_succeeded = FALSE
	var/tear_finished_at

/datum/unit_test/paradise_zombie_brute_wall_test/Destroy()
	if(wall_coordinates)
		var/turf/tile = locate(wall_coordinates[1], wall_coordinates[2], wall_coordinates[3])
		tile.ChangeTurf(old_wall_turf_type)
	return ..()

/datum/unit_test/paradise_zombie_brute_wall_test/proc/make_wall(wall_type)
	var/turf/tile = get_step(run_loc_floor_bottom_left, EAST)
	if(!wall_coordinates)
		old_wall_turf_type = tile.type
		wall_coordinates = list(tile.x, tile.y, tile.z)
	return tile.ChangeTurf(wall_type)

/datum/unit_test/paradise_zombie_brute_wall_test/proc/prepare_brute()
	var/mob/living/carbon/human/host = make_mutant("brute")
	host.mob_mood.set_enabled(FALSE)
	host.add_or_update_variable_actionspeed_modifier(/datum/actionspeed_modifier/base, multiplicative_slowdown = 1)
	return host

/datum/unit_test/paradise_zombie_brute_wall_test/proc/tear(datum/action/cooldown/paradise_zombie_mutation/tear_wall/action, atom/target)
	tear_finished = FALSE
	tear_succeeded = action.Trigger(action.owner, target = target)
	tear_finished_at = world.time
	tear_finished = TRUE

/** Real armed casts use Dragon's three-stage damage and four/twelve-second timings, excluding indestructible walls. */
/datum/unit_test/paradise_zombie_brute_wall_cast
	parent_type = /datum/unit_test/paradise_zombie_brute_wall_test

/datum/unit_test/paradise_zombie_brute_wall_cast/Run()
	var/mob/living/carbon/human/host = prepare_brute()
	var/datum/action/cooldown/paradise_zombie_mutation/tear_wall/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "Brute did not receive its actual wall-tearing action.")
	var/datum/action/cooldown/paradise_zombie_claws/claws = locate() in host.actions
	TEST_ASSERT(claws.Activate(host), "The Brute fixture could not extend its actual claws.")
	TEST_ASSERT(istype(host.get_active_held_item(), /obj/item/paradise_zombie_claw), "The cast fixture was not actually holding its two-handed claws.")
	var/turf/wall = make_wall(/turf/closed/wall)
	var/started_at = world.time
	INVOKE_ASYNC(src, TYPE_PROC_REF(/datum/unit_test/paradise_zombie_brute_wall_test, tear), action, wall)
	TEST_ASSERT(action.tearing && !tear_finished, "The wall button did not begin a real yielding cast.")
	TEST_ASSERT(!action.Activate(wall), "A second wall interaction bypassed the first cast's lock.")
	sleep(0.5 SECONDS)
	TEST_ASSERT(host.Move(get_step(host, NORTH), NORTH), "The Brute could not move along its target wall.")
	sleep(1 SECONDS)
	TEST_ASSERT(!tear_finished && isclosedturf(wall), "An ordinary wall disappeared before all three native stages.")
	TEST_ASSERT_NOTNULL(wall.GetComponent(/datum/component/torn_wall), "The real cast never applied its first native tear stage.")
	var/deadline = started_at + 6 SECONDS
	UNTIL(tear_finished || world.time >= deadline)
	TEST_ASSERT(tear_finished && tear_succeeded && tear_finished_at >= started_at + 4 SECONDS, "The ordinary wall cast did not complete its actual four-second tear while moving adjacently.")
	TEST_ASSERT(isopenturf(locate(wall_coordinates[1], wall_coordinates[2], wall_coordinates[3])), "Three real tear stages did not remove the ordinary wall.")

	wall = make_wall(/turf/closed/wall/r_wall)
	started_at = world.time
	INVOKE_ASYNC(src, TYPE_PROC_REF(/datum/unit_test/paradise_zombie_brute_wall_test, tear), action, wall)
	sleep(4.5 SECONDS)
	TEST_ASSERT(!tear_finished && isclosedturf(wall), "Reinforced wall protection did not delay the real cast.")
	TEST_ASSERT_NOTNULL(wall.GetComponent(/datum/component/torn_wall), "The reinforced cast never applied its first four-second native stage.")
	deadline = started_at + 14 SECONDS
	UNTIL(tear_finished || world.time >= deadline)
	TEST_ASSERT(tear_finished && tear_succeeded && tear_finished_at >= started_at + 12 SECONDS, "Reinforced wall teardown did not retain Dragon's twelve-second duration.")
	TEST_ASSERT(isopenturf(locate(wall_coordinates[1], wall_coordinates[2], wall_coordinates[3])), "The reinforced wall survived its three real tear stages.")
	wall = make_wall(/turf/closed/indestructible)
	TEST_ASSERT(!action.Trigger(host, target = wall), "The wall action accepted an indestructible wall.")
	TEST_ASSERT_NULL(wall.GetComponent(/datum/component/torn_wall), "An indestructible wall acquired destructive tear damage.")
	TEST_ASSERT(!action.tearing, "Rejecting an indestructible target retained the cast lock.")

/** Losing adjacency or the original active body must not deliver a delayed wall stage. */
/datum/unit_test/paradise_zombie_brute_wall_cancel
	parent_type = /datum/unit_test/paradise_zombie_brute_wall_test
	abstract_type = /datum/unit_test/paradise_zombie_brute_wall_cancel
	var/cancellation

/datum/unit_test/paradise_zombie_brute_wall_cancel/movement
	cancellation = "movement"

/datum/unit_test/paradise_zombie_brute_wall_cancel/cure
	cancellation = "cure"

/datum/unit_test/paradise_zombie_brute_wall_cancel/death
	cancellation = "death"

/datum/unit_test/paradise_zombie_brute_wall_cancel/mind_transfer
	cancellation = "mind_transfer"

/datum/unit_test/paradise_zombie_brute_wall_cancel/Run()
	var/mob/living/carbon/human/host = prepare_brute()
	var/datum/action/cooldown/paradise_zombie_mutation/tear_wall/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "The cancellation fixture did not receive its actual wall action.")
	var/turf/wall = make_wall(/turf/closed/wall)
	var/started_at = world.time
	INVOKE_ASYNC(src, TYPE_PROC_REF(/datum/unit_test/paradise_zombie_brute_wall_test, tear), action, wall)
	sleep(0.5 SECONDS)
	TEST_ASSERT(action.tearing && !tear_finished, "The cancellation case never entered its real preparation.")
	switch(cancellation)
		if("movement")
			host.forceMove(get_step(get_step(host, NORTH), NORTH))
		if("cure")
			var/datum/disease/paradise_zombie/infection = locate() in host.diseases
			infection.cure()
			TEST_ASSERT(QDELETED(action), "Cure did not delete the wall action.")
		if("death")
			host.death()
			TEST_ASSERT(host.revive(force_grab_ghost = FALSE), "The otherwise healthy cancellation body could not revive.")
		if("mind_transfer")
			var/datum/mind/original_mind = host.mind
			var/mob/living/carbon/human/destination = allocate(/mob/living/carbon/human/consistent, run_loc_floor_top_right)
			original_mind.transfer_to(destination)
			original_mind.transfer_to(host)
	var/deadline = started_at + 3 SECONDS
	UNTIL(tear_finished || world.time >= deadline)
	TEST_ASSERT(tear_finished && !tear_succeeded, "The [cancellation]-cancelled wall cast succeeded or never returned.")
	TEST_ASSERT(isclosedturf(wall), "A cancelled cast removed its wall after the interruption.")
	TEST_ASSERT_NULL(wall.GetComponent(/datum/component/torn_wall), "The [cancellation]-cancelled cast delivered a delayed native tear stage.")
	if(!QDELETED(action))
		TEST_ASSERT(!action.tearing, "A cancelled wall cast retained its lock.")

#endif
