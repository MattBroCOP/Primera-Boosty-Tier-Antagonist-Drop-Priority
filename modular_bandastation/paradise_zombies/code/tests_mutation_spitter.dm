#ifdef UNIT_TESTS

/** Actual acid projectiles leave an area which keeps burning a stationary enemy and stops after leaving it. */
/datum/unit_test/paradise_zombie_acid_projectile
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test

/datum/unit_test/paradise_zombie_acid_projectile/Run()
	var/mob/living/carbon/human/host = make_mutant("spitter")
	TEST_ASSERT_NOTNULL(host, "The acid fixture has no Spitter.")
	TEST_ASSERT(prepare_range(host), "The acid fixture has no private range.")
	var/datum/action/cooldown/paradise_zombie_mutation/bile/acid/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "Spitter did not receive its separate acid action.")
	var/original_spit_found = FALSE
	for(var/datum/action/cooldown/paradise_zombie_mutation/bile/spit in host.actions)
		if(spit.type == /datum/action/cooldown/paradise_zombie_mutation/bile)
			original_spit_found = TRUE
	TEST_ASSERT(original_spit_found, "Adding acid replaced the original slowing spit.")
	TEST_ASSERT(!action.Trigger(host, target = locate(host.x + 14, host.y, host.z)), "Acid accepted a shot beyond its thirteen-tile range.")
	var/mob/living/carbon/human/friend = make_zombie(locate(host.x + 2, host.y, host.z))
	TEST_ASSERT_NOTNULL(friend, "The acid projectile fixture has no infected ally.")
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, locate(host.x + 13, host.y, host.z))
	TEST_ASSERT(isopenturf(get_turf(victim)), "The real acid projectile's target is inside a wall.")
	TEST_ASSERT(action.Trigger(host, target = victim), "The actual acid action did not fire.")
	var/deadline = world.time + 5 SECONDS
	UNTIL((locate(/obj/effect/decal/cleanable/paradise_zombie_bile/acid) in get_turf(victim)) || world.time >= deadline)
	var/obj/effect/decal/cleanable/paradise_zombie_bile/acid/pool = locate() in get_turf(victim)
	TEST_ASSERT_NOTNULL(pool, "The actual projectile left no central acid pool.")
	var/turf/impact_tile = get_turf(victim)
	var/pool_count = 0
	for(var/obj/effect/decal/cleanable/paradise_zombie_bile/acid/other_pool in action.owned_effects)
		pool_count++
		TEST_ASSERT(get_dist(impact_tile, other_pool) <= 1, "Acid spread beyond its three-by-three impact area.")
	TEST_ASSERT_EQUAL(pool_count, 9, "An unobstructed acid impact did not cover its actual three-by-three area.")
	TEST_ASSERT(victim.get_fire_loss() > 0, "Acid bypassed the native projectile impact damage.")
	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/paradise_zombie_acid), "Standing on impact residue did not activate acid.")
	TEST_ASSERT_NULL(victim.has_status_effect(/datum/status_effect/paradise_zombie_mutation_bile_slow), "The new acid attack inherited the original spit's slowing effect.")
	var/burn_after_impact = victim.get_fire_loss()
	sleep(3.2 SECONDS)
	TEST_ASSERT(victim.get_fire_loss() > burn_after_impact && victim.has_status_effect(/datum/status_effect/paradise_zombie_acid), "Standing still let acid expire instead of receiving ongoing damage.")
	TEST_ASSERT_EQUAL(friend.get_fire_loss(), 0, "An actual acid projectile damaged an infected ally in its path.")
	TEST_ASSERT(victim.Move(get_step(victim, EAST), EAST), "The acid victim could not leave its central tile.")
	TEST_ASSERT(victim.Move(get_step(victim, EAST), EAST), "The acid victim could not leave the edge of its pool area.")
	var/burn_after_leaving = victim.get_fire_loss()
	deadline = world.time + 2 SECONDS
	UNTIL(!victim.has_status_effect(/datum/status_effect/paradise_zombie_acid) || world.time >= deadline)
	TEST_ASSERT_NULL(victim.has_status_effect(/datum/status_effect/paradise_zombie_acid), "Leaving acid retained its damage effect.")
	TEST_ASSERT_EQUAL(victim.get_fire_loss(), burn_after_leaving, "Acid continued burning an enemy after leaving its tile.")
	var/expiry = pool.expiry_timer
	TEST_ASSERT(timeleft(expiry) > 0 && timeleft(expiry) <= 12 SECONDS, "Acid did not retain the native twelve-second expiry.")
	pool.wash(CLEAN_TYPE_LIGHT_DECAL)
	TEST_ASSERT(QDELETED(pool) && isnull(timeleft(expiry)), "Cleaning acid retained its pool or expiry timer.")

/** Two casters contribute one damage effect; curing one source keeps the other pool effective. */
/datum/unit_test/paradise_zombie_acid_overlap
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test

/datum/unit_test/paradise_zombie_acid_overlap/Run()
	var/mob/living/carbon/human/first = make_mutant("spitter")
	TEST_ASSERT_NOTNULL(first, "The overlap fixture has no first Spitter.")
	var/mob/living/carbon/human/second = make_zombie(get_step(first, NORTH))
	TEST_ASSERT_NOTNULL(second, "The overlap fixture has no second Spitter.")
	var/datum/component/paradise_zombie_mutation/controller = second.GetComponent(/datum/component/paradise_zombie_mutation)
	TEST_ASSERT(controller.apply_form("spitter"), "The real outbreak rejected its second Spitter.")
	TEST_ASSERT(prepare_range(first, offset = 8), "The overlap fixture has no private range.")
	second.forceMove(get_step(first, WEST))
	var/datum/action/cooldown/paradise_zombie_mutation/bile/acid/first_action = locate() in first.actions
	var/datum/action/cooldown/paradise_zombie_mutation/bile/acid/second_action = locate() in second.actions
	TEST_ASSERT_NOTNULL(first_action, "The first Spitter has no acid action.")
	TEST_ASSERT_NOTNULL(second_action, "The second Spitter has no acid action.")
	var/turf/tile = get_step(first, EAST)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, tile)
	var/obj/effect/decal/cleanable/paradise_zombie_bile/acid/first_pool = new(tile, first_action)
	first_action.track_effect(first_pool)
	var/obj/effect/decal/cleanable/paradise_zombie_bile/acid/second_pool = new(tile, second_action)
	second_action.track_effect(second_pool)
	TEST_ASSERT(!QDELETED(first_pool) && !QDELETED(second_pool), "Overlapping acid pools merged away their independent owners.")
	var/effect_count = 0
	for(var/datum/status_effect/paradise_zombie_acid/active_effect in victim.status_effects)
		if(!QDELETED(active_effect))
			effect_count++
	TEST_ASSERT_EQUAL(effect_count, 1, "Overlapping sources stacked multiple damaging acid statuses.")
	var/datum/status_effect/paradise_zombie_acid/effect = victim.has_status_effect(/datum/status_effect/paradise_zombie_acid)
	effect.tick(1)
	TEST_ASSERT_EQUAL(victim.get_fire_loss(), 4, "Overlapping sources did not produce one four-damage acid tick.")
	var/datum/disease/paradise_zombie/infection = locate() in first.diseases
	infection.cure()
	TEST_ASSERT(QDELETED(first_pool) && !QDELETED(second_pool), "Curing one source removed the other caster's pool.")
	TEST_ASSERT_EQUAL(victim.has_status_effect(/datum/status_effect/paradise_zombie_acid), effect, "Curing one source deleted a victim-owned overlapping acid effect.")
	effect.tick(1)
	TEST_ASSERT_EQUAL(victim.get_fire_loss(), 8, "The surviving source failed to keep its acid damaging.")
	second_pool.wash(CLEAN_TYPE_LIGHT_DECAL)
	effect.tick(1)
	TEST_ASSERT(QDELETED(effect), "Cleaning the final pool retained its damage effect.")
	TEST_ASSERT_EQUAL(victim.get_fire_loss(), 8, "A cleaned acid pool dealt another damage tick.")

/** Real biological protection blocks the pool's burns, and infected bodies never acquire its damage effect. */
/datum/unit_test/paradise_zombie_acid_protection
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test

/datum/unit_test/paradise_zombie_acid_protection/Run()
	var/mob/living/carbon/human/host = make_mutant("spitter")
	TEST_ASSERT_NOTNULL(host, "The protection fixture has no Spitter.")
	TEST_ASSERT(prepare_range(host, offset = 8), "The protection fixture has no private range.")
	var/datum/action/cooldown/paradise_zombie_mutation/bile/acid/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "The protection fixture has no acid action.")
	var/turf/tile = get_step(host, EAST)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, tile)
	var/obj/item/clothing/suit/bio_suit/suit = allocate(/obj/item/clothing/suit/bio_suit)
	TEST_ASSERT(victim.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING, bypass_equip_delay_self = TRUE), "The protection fixture could not wear its real biosuit.")
	TEST_ASSERT_EQUAL(victim.getarmor(BODY_ZONE_CHEST, BIO), 100, "The real protection fixture does not have full biological armour.")
	var/obj/effect/decal/cleanable/paradise_zombie_bile/acid/pool = new(tile, action)
	action.track_effect(pool)
	var/datum/status_effect/paradise_zombie_acid/effect = victim.has_status_effect(/datum/status_effect/paradise_zombie_acid)
	TEST_ASSERT_NOTNULL(effect, "The protection fixture did not enter actual acid.")
	effect.tick(1)
	TEST_ASSERT_EQUAL(victim.get_fire_loss(), 0, "Acid burns bypassed full biological protection.")
	var/mob/living/carbon/human/friend = make_zombie(get_step(tile, NORTH))
	TEST_ASSERT_NOTNULL(friend, "The friendly acid control could not become infected.")
	friend.forceMove(tile)
	pool.process(1)
	TEST_ASSERT_NULL(friend.has_status_effect(/datum/status_effect/paradise_zombie_acid), "Acid affected an infected ally.")
	TEST_ASSERT_EQUAL(friend.get_fire_loss(), 0, "Acid damaged an infected ally.")

/** Source lifecycle changes stop damage even though the victim's timed status owns no caster references. */
/datum/unit_test/paradise_zombie_acid_interrupted
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test
	abstract_type = /datum/unit_test/paradise_zombie_acid_interrupted
	var/interruption

/datum/unit_test/paradise_zombie_acid_interrupted/cure
	interruption = "cure"

/datum/unit_test/paradise_zombie_acid_interrupted/death
	interruption = "death"

/datum/unit_test/paradise_zombie_acid_interrupted/mind_transfer
	interruption = "mind_transfer"

/datum/unit_test/paradise_zombie_acid_interrupted/pacifism
	interruption = "pacifism"

/datum/unit_test/paradise_zombie_acid_interrupted/clear_form
	interruption = "clear_form"

/datum/unit_test/paradise_zombie_acid_interrupted/Run()
	var/mob/living/carbon/human/host = make_mutant("spitter")
	TEST_ASSERT_NOTNULL(host, "The interruption fixture has no Spitter.")
	TEST_ASSERT(prepare_range(host, offset = 8), "The interruption fixture has no private range.")
	var/datum/action/cooldown/paradise_zombie_mutation/bile/acid/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "The interruption fixture has no acid action.")
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, get_step(host, EAST))
	var/obj/effect/decal/cleanable/paradise_zombie_bile/acid/pool = new(get_turf(victim), action)
	action.track_effect(pool)
	var/datum/status_effect/paradise_zombie_acid/effect = victim.has_status_effect(/datum/status_effect/paradise_zombie_acid)
	TEST_ASSERT_NOTNULL(effect, "The interruption fixture never entered acid.")
	switch(interruption)
		if("cure")
			var/datum/disease/paradise_zombie/infection = locate() in host.diseases
			infection.cure()
		if("death")
			host.death()
		if("mind_transfer")
			var/mob/living/carbon/human/destination = allocate(/mob/living/carbon/human/consistent, get_turf(host))
			host.mind.transfer_to(destination)
		if("pacifism")
			ADD_TRAIT(host, TRAIT_PACIFISM, TRAIT_SOURCE_UNIT_TESTS)
		if("clear_form")
			var/datum/component/paradise_zombie_mutation/controller = host.GetComponent(/datum/component/paradise_zombie_mutation)
			controller.clear_form()
	var/deadline = world.time + 2 SECONDS
	UNTIL(QDELETED(effect) || world.time >= deadline)
	TEST_ASSERT(QDELETED(effect), "The [interruption] interruption retained an active acid status.")
	TEST_ASSERT_EQUAL(victim.get_fire_loss(), 0, "Acid dealt damage after its [interruption] interruption.")
	TEST_ASSERT(QDELETED(pool), "The [interruption] interruption left an active pool behind.")

/** A projectile stopped by transparent cover cannot splash acid onto the adjacent floor behind it. */
/datum/unit_test/paradise_zombie_acid_cover
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test
	var/diagonal_corner = FALSE

/datum/unit_test/paradise_zombie_acid_cover/diagonal
	diagonal_corner = TRUE

/datum/unit_test/paradise_zombie_acid_cover/Run()
	var/mob/living/carbon/human/host = make_mutant("spitter")
	TEST_ASSERT_NOTNULL(host, "The cover fixture has no Spitter.")
	TEST_ASSERT(prepare_range(host, offset = 8), "The cover fixture has no private range.")
	var/datum/action/cooldown/paradise_zombie_mutation/bile/acid/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "The cover fixture has no acid action.")
	var/turf/impact_tile = locate(host.x + 2, host.y, host.z)
	var/mob/living/carbon/human/victim
	var/atom/target
	var/obj/machinery/door/airlock/glass/cover
	if(diagonal_corner)
		target = allocate(/mob/living/carbon/human/consistent, impact_tile)
		cover = allocate(/obj/machinery/door/airlock/glass, get_step(impact_tile, EAST))
		allocate(/obj/machinery/door/airlock/glass, get_step(impact_tile, NORTH))
		victim = allocate(/mob/living/carbon/human/consistent, get_step(impact_tile, NORTHEAST))
		TEST_ASSERT(victim in view(1, impact_tile), "Opaque cover hid the corner fixture before physical adjacency was tested.")
	else
		cover = allocate(/obj/machinery/door/airlock/glass, impact_tile)
		victim = allocate(/mob/living/carbon/human/consistent, get_step(impact_tile, EAST))
		target = victim
	TEST_ASSERT(cover.density && !cover.opacity, "The cover fixture is not a real closed transparent airlock.")
	TEST_ASSERT(action.Trigger(host, target = target), "The real cover-test projectile did not fire.")
	var/obj/projectile/paradise_zombie_bile/acid/shot = locate() in action.owned_effects
	TEST_ASSERT_NOTNULL(shot, "The cover test never launched its actual projectile.")
	var/deadline = world.time + 5 SECONDS
	UNTIL(QDELETED(shot) || world.time >= deadline)
	TEST_ASSERT(QDELETED(shot), "The real cover-test projectile did not resolve.")
	TEST_ASSERT(cover.density, "The test destroyed its cover before checking acid propagation.")
	TEST_ASSERT_NULL(locate(/obj/effect/decal/cleanable/paradise_zombie_bile/acid) in get_turf(victim), "Acid spread through closed cover onto the protected floor.")
	TEST_ASSERT_NULL(victim.has_status_effect(/datum/status_effect/paradise_zombie_acid), "Acid reached a victim behind physical cover.")
	TEST_ASSERT_EQUAL(victim.get_fire_loss(), 0, "A victim behind physical cover received acid damage.")

#endif
