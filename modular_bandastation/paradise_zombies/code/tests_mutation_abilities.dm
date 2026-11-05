#ifdef UNIT_TESTS

/// Fixed armour and integrity isolate a real window attack from unrelated breakage thresholds.
/datum/armor/paradise_zombie_mutation_test

/obj/structure/window/paradise_zombie_mutation_test
	max_integrity = 500
	armor_type = /datum/armor/paradise_zombie_mutation_test

/// A private range has normal gravity without depending on a reserved z-level's area.
/area/paradise_zombie_mutation_ability_test
	name = "Zombie mutation ability range"
	requires_power = FALSE
	default_gravity = STANDARD_GRAVITY

/// Common ability fixtures still use the production infection, claims, controller and granted actions.
/datum/unit_test/paradise_zombie_mutation_ability_test
	parent_type = /datum/unit_test/paradise_zombie_mutation_test
	abstract_type = /datum/unit_test/paradise_zombie_mutation_ability_test
	/// Private floor released only after allocated actors finish normal teardown.
	var/datum/turf_reservation/range_reservation
	/// Supplies station gravity without changing other turf reservations.
	var/area/paradise_zombie_mutation_ability_test/range_area
	/// Restored before the temporary range area is deleted.
	var/area/previous_range_area

/// Keep run_loc unchanged: native teardown must never clear other reservations on this z-level.
/datum/unit_test/paradise_zombie_mutation_ability_test/Destroy()
	. = ..()
	if(range_reservation)
		for(var/turf/tile as anything in range_reservation.reserved_turfs)
			tile.change_area(range_area, previous_range_area)
	QDEL_NULL(range_reservation)
	QDEL_NULL(range_area)
	previous_range_area = null
	return .

/// Only the four long-range scenarios allocate a floor; supporting outbreak bodies stay in the unit room.
/datum/unit_test/paradise_zombie_mutation_ability_test/proc/prepare_range(mob/living/carbon/human/host, offset = 1)
	range_reservation = SSmapping.request_turf_block_reservation(17, 17, turf_type_override = /turf/open/indestructible)
	TEST_ASSERT_NOTNULL(range_reservation, "The private ability range could not be reserved.")
	var/turf/bottom_left = range_reservation.bottom_left_turfs[1]
	previous_range_area = get_area(bottom_left)
	range_area = new
	for(var/turf/tile as anything in range_reservation.reserved_turfs)
		tile.change_area(get_area(tile), range_area)
	host.forceMove(locate(bottom_left.x + offset, bottom_left.y + offset, bottom_left.z))
	TEST_ASSERT(host.has_gravity(), "The private range did not give its caster normal gravity.")
	return TRUE

/datum/unit_test/paradise_zombie_mutation_ability_test/proc/extend_claws(mob/living/carbon/human/host)
	var/datum/action/cooldown/paradise_zombie_claws/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "A real mutant did not retain its Paradise claw action.")
	TEST_ASSERT(action.Trigger(host), "A real mutant could not extend its claws.")
	var/obj/item/paradise_zombie_claw/claws = host.get_active_held_item()
	TEST_ASSERT(istype(claws), "The claw action did not produce its actual weapon.")
	return claws

/// A real claw chain verifies Beta weakening, repeated attacks, barrier damage and form cleanup.
/datum/unit_test/paradise_zombie_mutation_claw_effects
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test

/datum/unit_test/paradise_zombie_mutation_claw_effects/Run()
	var/mob/living/carbon/human/host = make_mutant("brute")
	TEST_ASSERT_NOTNULL(host, "The Brute fixture was not created.")
	host.set_combat_mode(TRUE)
	host.zone_selected = BODY_ZONE_CHEST
	var/obj/item/paradise_zombie_claw/claws = extend_claws(host)
	TEST_ASSERT_NOTNULL(claws, "The Brute fixture could not extend claws.")
	TEST_ASSERT_NOTNULL(claws.GetComponent(/datum/component/paradise_zombie_mutation_claws), "Claw creation did not attach the actual mutation modifier.")
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	victim.forceMove(get_step(host, EAST))
	ADD_TRAIT(victim, TRAIT_NEVER_WOUNDED, TRAIT_GENERIC)
	var/obj/item/bodypart/chest/protected_chest = victim.get_bodypart(BODY_ZONE_CHEST)
	claws.add_infection_bleeding(victim, protected_chest)
	TEST_ASSERT_EQUAL(length(protected_chest.wounds), 0, "Infection bleeding installed a wound on a wound-immune limb.")
	claws.melee_attack_chain(host, victim, list())
	var/normal_force = claws.force
	TEST_ASSERT(abs(normal_force - 31.5) < 0.001, "Brute claws did not apply their actual heavy force.")
	host.reagents.add_reagent(/datum/reagent/medicine/paradise_zombie_cure/beta, 2)
	claws.melee_attack_chain(host, victim, list())
	TEST_ASSERT(abs(claws.force - 15) < 0.001, "Mutation force bypassed Paradise's Beta weakening.")
	claws.melee_attack_chain(host, victim, list())
	TEST_ASSERT(abs(claws.force - 15) < 0.001, "Repeated pre-attack signals compounded the mutation multiplier.")
	var/obj/structure/window/paradise_zombie_mutation_test/barrier = allocate(/obj/structure/window/paradise_zombie_mutation_test, get_step(host, NORTH))
	var/integrity_before = barrier.get_integrity()
	claws.melee_attack_chain(host, barrier, list())
	TEST_ASSERT(abs(integrity_before - barrier.get_integrity() - 75) < 0.001, "A real window attack lost either Beta-weakened force or Brute's barrier-breaking bonus.")
	var/datum/component/paradise_zombie_mutation/controller = host.GetComponent(/datum/component/paradise_zombie_mutation)
	controller.clear_form()
	TEST_ASSERT_NULL(claws.GetComponent(/datum/component/paradise_zombie_mutation_claws), "Clearing a form retained its heavy-claw modifier.")
	TEST_ASSERT_EQUAL(claws.force, 10, "Removing the modifier did not restore the current Beta-weakened force.")

/// Actual attacks consume each form's arm artwork, while both HUD slots remain native two-handed items.
/datum/unit_test/paradise_zombie_mutation_melee_graphics
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test
	/// Observes the production override after its signal handler has run.
	var/empty_attack_image = FALSE

/datum/unit_test/paradise_zombie_mutation_melee_graphics/proc/on_attack_animation(obj/item/source, atom/movable/attacker, atom/target, animation_type, list/image_override)
	SIGNAL_HANDLER
	var/image/replacement = length(image_override) ? image_override[1] : null
	// Native animate_attack later raises alpha, so alpha zero alone cannot hide the old claw.
	empty_attack_image = replacement?.icon == 'icons/blanks/32x32.dmi' && replacement.icon_state == "nothing"

/datum/unit_test/paradise_zombie_mutation_melee_graphics/proc/strike(mob/living/carbon/human/host, mob/living/carbon/human/victim, obj/item/paradise_zombie_claw/claws, form_id)
	empty_attack_image = FALSE
	var/zone = form_id == "exploder" ? BODY_ZONE_R_ARM : host.get_hand_zone_of_item(claws)
	var/obj/item/bodypart/striking_arm = host.get_bodypart(zone)
	var/damage_before = victim.get_brute_loss()
	claws.melee_attack_chain(host, victim, list())
	TEST_ASSERT(victim.get_brute_loss() > damage_before, "The [form_id] visual replaced its real claw damage.")
	var/datum/component/paradise_zombie_mutation_body/body = host.GetComponent(/datum/component/paradise_zombie_mutation_body)
	var/atom/movable/flick_visual/swing = body.melee_visual
	TEST_ASSERT_NOTNULL(swing, "The actual [form_id] attack never created its native swing visual.")
	TEST_ASSERT(swing in host.vis_contents, "The [form_id] swing was not attached to its actual attacking body.")
	TEST_ASSERT(empty_attack_image, "The [form_id] attack retained a floating claw image which native alpha animation can reveal.")
	var/prefix = form_id == "spitter" ? "puker" : form_id
	var/expected_state = form_id == "hunter" ? "hunter_[zone == BODY_ZONE_L_ARM ? "left" : "right"]" : "[prefix]_[zone]"
	var/expected_icon = form_id == "hunter" ? 'modular_bandastation/paradise_zombies/icons/mutations/hunter_swing.dmi' : get_paradise_zombie_form(form_id).body_icon
	TEST_ASSERT_EQUAL(swing.icon, expected_icon, "The [form_id] strike consumed the wrong source sheet.")
	TEST_ASSERT_EQUAL(swing.icon_state, expected_state, "The [form_id] strike did not use its own attacking arm.")
	TEST_ASSERT(icon_exists(swing.icon, swing.icon_state), "The [form_id] strike points at missing source artwork.")
	TEST_ASSERT_EQUAL(body.melee_zone, zone, "The [form_id] strike hid a different resting limb.")
	TEST_ASSERT(host.get_bodypart(zone) == striking_arm && striking_arm?.owner == host, "Drawing the [form_id] swing removed or replaced a real arm.")
	for(var/mutable_appearance/part as anything in body.body_appearances)
		TEST_ASSERT_NOTEQUAL(part.icon_state, "[prefix]_[zone]", "The [form_id] attack drew its resting arm and swing simultaneously.")
	return swing

/datum/unit_test/paradise_zombie_mutation_melee_graphics/Run()
	for(var/support_index in 1 to 7)
		make_zombie(run_loc_floor_top_right)
	GLOB.paradise_zombie_mutation_progression.first_infection_at = world.time - 20 MINUTES
	for(var/form_id in list("slasher", "twitcher", "hunter", "brute", "spitter", "exploder"))
		var/mob/living/carbon/human/host = make_zombie(run_loc_floor_bottom_left)
		var/datum/component/paradise_zombie_mutation/controller = host.GetComponent(/datum/component/paradise_zombie_mutation)
		TEST_ASSERT(controller.apply_form(form_id), "The real outbreak could not apply [form_id] for its melee fixture.")
		host.set_combat_mode(TRUE)
		host.swap_hand(LEFT_HANDS, silent = TRUE)
		var/obj/item/paradise_zombie_claw/claws = extend_claws(host)
		TEST_ASSERT_NOTNULL(claws, "The [form_id] fixture could not extend its actual claws.")
		var/datum/component/two_handed/two_handed = claws.GetComponent(/datum/component/two_handed)
		var/obj/item/offhand/offhand = two_handed.offhand_item
		TEST_ASSERT_NOTNULL(offhand, "The [form_id] HUD cosmetic replaced the native offhand reservation.")
		TEST_ASSERT_EQUAL(claws.icon, 'modular_bandastation/paradise_zombies/icons/mutations/melee_hud.dmi', "The [form_id] primary hand retained its generic claw icon.")
		TEST_ASSERT_EQUAL(offhand.icon, claws.icon, "The [form_id] native offhand retained its generic reservation icon.")
		TEST_ASSERT_EQUAL(claws.icon_state, "[form_id]_left", "The [form_id] primary HUD did not follow the actual left hand.")
		TEST_ASSERT_EQUAL(offhand.icon_state, "[form_id]_right", "The [form_id] offhand HUD did not follow the actual right hand.")
		TEST_ASSERT(two_handed.wielded && length(host.get_held_items()) == 2 && !host.swap_hand(two_handed.offhand_index, silent = TRUE), "The [form_id] cosmetics broke native two-handed wielding.")
		RegisterSignal(claws, COMSIG_ITEM_ATTACK_ANIMATION, PROC_REF(on_attack_animation))
		var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, get_step(host, EAST))
		ADD_TRAIT(victim, TRAIT_NEVER_WOUNDED, TRAIT_SOURCE_UNIT_TESTS)
		var/atom/movable/flick_visual/first_swing = strike(host, victim, claws, form_id)
		TEST_ASSERT_NOTNULL(first_swing, "The [form_id] first swing failed its native attack checks.")
		var/atom/movable/flick_visual/next_swing = strike(host, victim, claws, form_id)
		TEST_ASSERT_NOTNULL(next_swing, "The [form_id] repeated swing failed its native attack checks.")
		TEST_ASSERT(QDELETED(first_swing) && next_swing != first_swing, "The [form_id] repeated attack retained its previous arm visual.")
		if(form_id == "slasher")
			var/datum/component/paradise_zombie_mutation_body/body = controller.body_renderer
			var/deadline = world.time + 2 SECONDS
			UNTIL(QDELETED(next_swing) || world.time >= deadline)
			TEST_ASSERT(QDELETED(next_swing) && !body.melee_visual && !body.melee_zone, "The native timed swing never released its resting arm.")
			var/arm_restored = FALSE
			for(var/mutable_appearance/part as anything in body.body_appearances)
				arm_restored ||= part.icon_state == "slasher_l_arm"
			TEST_ASSERT(arm_restored, "Native swing expiry did not redraw the Slasher's resting arm.")
			next_swing = strike(host, victim, claws, form_id)
			TEST_ASSERT_NOTNULL(next_swing, "The expired native swing prevented a later real attack.")
		var/datum/action/cooldown/paradise_zombie_claws/action = locate() in host.actions
		TEST_ASSERT(action.Trigger(host), "The [form_id] claws could not retract during a swing.")
		TEST_ASSERT(QDELETED(claws) && QDELETED(offhand) && QDELETED(next_swing), "Retraction retained the [form_id] weapon, offhand or swing.")
		TEST_ASSERT_EQUAL(length(host.get_held_items()), 0, "The [form_id] retraction left a phantom hand reservation.")
		host.swap_hand(RIGHT_HANDS, silent = TRUE)
		claws = extend_claws(host)
		two_handed = claws.GetComponent(/datum/component/two_handed)
		offhand = two_handed.offhand_item
		TEST_ASSERT(claws.icon_state == "[form_id]_right" && offhand?.icon_state == "[form_id]_left", "Re-extending [form_id] claws did not rebuild the reversed hand HUDs.")
		RegisterSignal(claws, COMSIG_ITEM_ATTACK_ANIMATION, PROC_REF(on_attack_animation))
		next_swing = strike(host, victim, claws, form_id)
		TEST_ASSERT_NOTNULL(next_swing, "The [form_id] right-hand attack failed its native checks.")
		var/datum/disease/paradise_zombie/infection = locate() in host.diseases
		if(form_id in list("slasher", "hunter", "spitter"))
			controller.clear_form()
			TEST_ASSERT(QDELETED(next_swing), "Clearing [form_id] retained its active swing.")
			TEST_ASSERT(!QDELETED(claws) && !QDELETED(offhand) && two_handed.wielded, "Clearing [form_id] destroyed ordinary native claws or their offhand.")
			TEST_ASSERT(claws.icon == initial(claws.icon) && claws.icon_state == initial(claws.icon_state), "Clearing [form_id] did not restore its primary claw HUD.")
			TEST_ASSERT(offhand.icon == initial(offhand.icon) && offhand.icon_state == initial(offhand.icon_state), "Clearing [form_id] did not restore its native offhand HUD.")
		infection.cure()
		TEST_ASSERT(QDELETED(next_swing) && QDELETED(claws) && QDELETED(offhand), "Curing [form_id] retained a melee visual or either reserved hand.")
		TEST_ASSERT_NULL(host.GetComponent(/datum/component/paradise_zombie_mutation_body), "Curing [form_id] retained its melee renderer.")

/// Movement uses a real capped throw, and an actual cure removes a second in-flight dash.
/datum/unit_test/paradise_zombie_mutation_dash_cleanup
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test

/datum/unit_test/paradise_zombie_mutation_dash_cleanup/Run()
	var/mob/living/carbon/human/host = make_mutant("twitcher")
	TEST_ASSERT_NOTNULL(host, "The Twitcher fixture was not created.")
	TEST_ASSERT(prepare_range(host), "The Twitcher fixture has no private range.")
	var/datum/action/cooldown/paradise_zombie_mutation/dash/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "Twitcher did not receive its real dash action.")
	var/turf/start = get_turf(host)
	var/turf/destination = locate(start.x + 14, start.y, start.z)
	TEST_ASSERT(action.Trigger(host, target = destination), "The dash action rejected a valid distant target.")
	var/deadline = world.time + 5 SECONDS
	UNTIL(!host.throwing || world.time >= deadline)
	TEST_ASSERT_NULL(host.throwing, "The capped dash never ended.")
	TEST_ASSERT_EQUAL(get_dist(start, host), 12, "The dash did not stop at twelve tiles when aimed beyond its range.")
	TEST_ASSERT_EQUAL(host.get_brute_loss(), 0, "The gentle dash damaged its caster.")
	// An unbraced zero-gravity body must stop too, rather than gaining a native landing drift.
	host.AddElement(/datum/element/forced_gravity, 0)
	ADD_TRAIT(host, TRAIT_NOGRAV_ALWAYS_DRIFT, TRAIT_GENERIC)
	TEST_ASSERT(!host.has_gravity() && !host.Process_Spacemove(NORTH, continuous_move = TRUE), "The zero-gravity dash fixture can still brace itself or has gravity.")
	action.ResetCooldown()
	start = get_turf(host)
	destination = locate(host.x, host.y + 14, host.z)
	TEST_ASSERT(action.Trigger(host, target = destination), "The dash could not launch in genuine zero gravity.")
	deadline = world.time + 5 SECONDS
	UNTIL(!host.throwing || world.time >= deadline)
	TEST_ASSERT_NULL(host.throwing, "The zero-gravity dash never finalized.")
	TEST_ASSERT_EQUAL(get_dist(start, host), 12, "The zero-gravity dash did not respect its twelve-tile flight boundary.")
	TEST_ASSERT_NULL(host.drift_handler, "The finished dash created a native inertial drift beyond its range.")
	var/turf/landing = get_turf(host)
	sleep(1 SECONDS)
	TEST_ASSERT_EQUAL(get_turf(host), landing, "The zero-gravity caster drifted away after its dash ended.")
	TEST_ASSERT(host.newtonian_move(dir2angle(EAST)), "A finished dash suppressed a later unrelated inertial impulse.")
	TEST_ASSERT_NOTNULL(host.drift_handler, "A later external impulse did not create its normal native drift handler.")
	QDEL_NULL(host.drift_handler)
	host.RemoveElement(/datum/element/forced_gravity, 0)
	REMOVE_TRAIT(host, TRAIT_NOGRAV_ALWAYS_DRIFT, TRAIT_GENERIC)
	TEST_ASSERT(host.has_gravity(), "Removing the zero-gravity fixture did not restore the range's normal gravity.")
	action.ResetCooldown()
	destination = get_step(host, NORTH)
	TEST_ASSERT(action.Trigger(host, target = destination), "The cleanup fixture could not start a second dash.")
	var/datum/thrownthing/flight = host.throwing
	TEST_ASSERT_NOTNULL(flight, "The deferred dash did not install a real throw datum.")
	var/datum/disease/paradise_zombie/infection = locate() in host.diseases
	infection.cure()
	TEST_ASSERT(QDELETED(action) && QDELETED(flight), "Curing a mutant retained its dash action or in-flight effect.")
	TEST_ASSERT_NULL(host.throwing, "Cure left a stale throwing state on the former mutant.")
	TEST_ASSERT(host.Move(get_step(host, WEST), WEST), "The removed dash left a movement-blocking signal on its former caster.")

/// Actual collision attacks once, while an empty landing really applies and then removes the miss penalty.
/datum/unit_test/paradise_zombie_mutation_pounce
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test
	var/knockdown_duration = 0

/datum/unit_test/paradise_zombie_mutation_pounce/proc/on_knockdown(mob/living/source, amount)
	SIGNAL_HANDLER
	knockdown_duration = amount

/datum/unit_test/paradise_zombie_mutation_pounce/Run()
	var/mob/living/carbon/human/host = make_mutant("hunter")
	TEST_ASSERT_NOTNULL(host, "The Hunter fixture was not created.")
	TEST_ASSERT(prepare_range(host), "The Hunter fixture has no private range.")
	host.set_combat_mode(TRUE)
	var/obj/item/paradise_zombie_claw/claws = extend_claws(host)
	TEST_ASSERT_NOTNULL(claws, "The Hunter fixture could not extend claws.")
	var/datum/action/cooldown/paradise_zombie_mutation/dash/pounce/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "Hunter did not receive its real ambush action.")
	var/turf/launch_tile = get_turf(host)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	victim.forceMove(locate(host.x + 10, host.y, host.z))
	ADD_TRAIT(victim, TRAIT_NEVER_WOUNDED, TRAIT_GENERIC)
	RegisterSignal(victim, COMSIG_LIVING_STATUS_KNOCKDOWN, PROC_REF(on_knockdown))
	TEST_ASSERT(action.Trigger(host, target = victim), "The pounce action rejected its real victim.")
	var/deadline = world.time + 5 SECONDS
	UNTIL(!host.throwing || world.time >= deadline)
	TEST_ASSERT_NULL(host.throwing, "The enemy pounce never finished.")
	var/raw_damage = 0
	for(var/obj/item/bodypart/limb as anything in victim.get_bodyparts())
		raw_damage += limb.brute_dam
	TEST_ASSERT(abs(raw_damage - 18.9) < 0.001, "A pounce did not reach a victim ten tiles away with exactly one actual Hunter claw attack.")
	TEST_ASSERT_EQUAL(knockdown_duration, 1 SECONDS, "A successful ambush did not apply its one-second knockdown.")
	TEST_ASSERT(!host.has_status_effect(/datum/status_effect/paradise_zombie_mutation_exposed), "A successful pounce incorrectly applied the miss penalty.")
	// The clicked victim remains a valid target after losing the density that normally causes a collision.
	host.forceMove(launch_tile)
	victim.Knockdown(1 MINUTES)
	TEST_ASSERT(!victim.density, "The prone-pounce fixture still has a dense victim.")
	knockdown_duration = 0
	action.ResetCooldown()
	TEST_ASSERT(action.Trigger(host, target = victim), "The pounce action rejected its prone victim.")
	deadline = world.time + 5 SECONDS
	UNTIL(!host.throwing || world.time >= deadline)
	TEST_ASSERT_NULL(host.throwing, "The targeted prone pounce never finished.")
	var/damage_after_prone_pounce = 0
	for(var/obj/item/bodypart/limb as anything in victim.get_bodyparts())
		damage_after_prone_pounce += limb.brute_dam
	TEST_ASSERT(abs(damage_after_prone_pounce - raw_damage - 18.9) < 0.001, "The pounce passed over its clicked prone victim without one real claw attack.")
	TEST_ASSERT_EQUAL(knockdown_duration, 1 SECONDS, "Hitting a prone victim did not deliver the pounce's knockdown.")
	TEST_ASSERT(!host.has_status_effect(/datum/status_effect/paradise_zombie_mutation_exposed), "Hitting the clicked prone victim was treated as a miss.")
	UnregisterSignal(victim, COMSIG_LIVING_STATUS_KNOCKDOWN)
	// A clicked prone victim one tile beyond the boundary must remain unharmed, despite being adjacent at landing.
	host.forceMove(launch_tile)
	victim.forceMove(locate(host.x + 11, host.y, host.z))
	action.ResetCooldown()
	TEST_ASSERT(action.Trigger(host, target = victim), "The capped miss fixture could not launch toward a victim beyond its range.")
	deadline = world.time + 5 SECONDS
	UNTIL(!host.throwing || world.time >= deadline)
	TEST_ASSERT_NULL(host.throwing, "The out-of-range pounce never finished.")
	TEST_ASSERT_EQUAL(get_dist(launch_tile, host), 10, "A pounce aimed at an eleven-tile victim did not stop at ten tiles.")
	var/damage_after_miss = 0
	for(var/obj/item/bodypart/limb as anything in victim.get_bodyparts())
		damage_after_miss += limb.brute_dam
	TEST_ASSERT(abs(damage_after_miss - damage_after_prone_pounce) < 0.001, "The capped pounce still attacked its out-of-range clicked victim.")
	TEST_ASSERT(host.has_status_effect(/datum/status_effect/paradise_zombie_mutation_exposed), "Missing an ambush did not actually expose the Hunter.")
	TEST_ASSERT(host.has_movespeed_modifier(/datum/movespeed_modifier/paradise_zombie_mutation_exposed), "The miss penalty did not actually slow movement.")
	var/obj/item/bodypart/chest/chest = host.get_bodypart(BODY_ZONE_CHEST)
	var/damage_before = chest.brute_dam
	host.apply_damage(8, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND)
	TEST_ASSERT(abs(chest.brute_dam - damage_before - 10) < 0.001, "The miss penalty did not increase actual incoming brute damage by twenty-five percent.")
	deadline = world.time + 4 SECONDS
	UNTIL(!host.has_status_effect(/datum/status_effect/paradise_zombie_mutation_exposed) || world.time >= deadline)
	TEST_ASSERT(!host.has_status_effect(/datum/status_effect/paradise_zombie_mutation_exposed), "The miss vulnerability did not expire.")
	TEST_ASSERT(!host.has_movespeed_modifier(/datum/movespeed_modifier/paradise_zombie_mutation_exposed), "The expired miss penalty retained its movement modifier.")
	damage_before = chest.brute_dam
	host.apply_damage(8, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND)
	TEST_ASSERT(abs(chest.brute_dam - damage_before - 8) < 0.001, "The expired miss penalty retained its damage multiplier.")

/// A real projectile passes allies, leaves washable timed bile, and cure destroys remaining world effects.
/datum/unit_test/paradise_zombie_mutation_bile_lifecycle
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test

/datum/unit_test/paradise_zombie_mutation_bile_lifecycle/Run()
	var/mob/living/carbon/human/host = make_mutant("spitter")
	TEST_ASSERT_NOTNULL(host, "The Spitter fixture was not created.")
	TEST_ASSERT(prepare_range(host), "The Spitter fixture has no private range.")
	var/datum/action/cooldown/paradise_zombie_mutation/bile/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "Spitter did not receive its real bile action.")
	var/cooldown_before = action.next_use_time
	TEST_ASSERT(!action.Trigger(host, target = locate(host.x + 14, host.y, host.z)), "Bile accepted a target fourteen tiles away.")
	TEST_ASSERT_EQUAL(action.next_use_time, cooldown_before, "Rejecting a fourteen-tile shot consumed its cooldown.")
	TEST_ASSERT_EQUAL(length(action.owned_effects), 0, "Rejecting an out-of-range shot created a projectile or residue.")
	var/mob/living/carbon/human/friend = make_zombie(locate(host.x + 2, host.y, host.z))
	TEST_ASSERT_NOTNULL(friend, "The friendly-fire fixture was not created.")
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	victim.forceMove(locate(host.x + 13, host.y, host.z))
	TEST_ASSERT(isopenturf(get_turf(victim)), "The bile fixture put its victim inside a closed turf instead of on a floor.")
	var/friendly_damage_before = friend.get_fire_loss()
	TEST_ASSERT(action.Trigger(host, target = victim), "The bile action did not launch its projectile.")
	var/deadline = world.time + 5 SECONDS
	UNTIL(victim.get_fire_loss() > 0 || world.time >= deadline)
	TEST_ASSERT(victim.get_fire_loss() > 0, "The actual bile projectile never reached its enemy thirteen tiles away.")
	TEST_ASSERT_EQUAL(friend.get_fire_loss(), friendly_damage_before, "A bile projectile damaged the allied zombie in its flight path.")
	var/obj/effect/decal/cleanable/paradise_zombie_bile/puddle = locate() in get_turf(victim)
	TEST_ASSERT_NOTNULL(puddle, "The real projectile impact left no visible bile residue.")
	TEST_ASSERT(victim.has_status_effect(/datum/status_effect/paradise_zombie_mutation_bile_slow), "Standing on actual bile did not slow the enemy.")
	TEST_ASSERT(victim.has_movespeed_modifier(/datum/movespeed_modifier/paradise_zombie_mutation_bile), "Bile's status did not apply its real movement modifier.")
	TEST_ASSERT_NULL(puddle.decal_reagent, "Hostile bile became a farmable reagent source.")
	var/expiry = puddle.expiry_timer
	TEST_ASSERT(timeleft(expiry) > 0, "Bile did not own an active expiry timer.")
	var/turf/puddle_turf = get_turf(puddle)
	puddle_turf.wash(CLEAN_TYPE_LIGHT_DECAL)
	TEST_ASSERT(QDELETED(puddle), "Ordinary cleaning could not wash away the hostile bile.")
	TEST_ASSERT_NULL(timeleft(expiry), "Cleaning bile left a timer retaining its deleted world object.")

	victim.forceMove(locate(host.x + 4, host.y + 2, host.z))
	victim.Knockdown(1 MINUTES)
	TEST_ASSERT(!victim.density, "The prone-bile fixture still has a dense victim.")
	var/damage_before_prone_shot = victim.get_fire_loss()
	action.ResetCooldown()
	TEST_ASSERT(action.Trigger(host, target = victim), "The second bile shot did not launch.")
	deadline = world.time + 5 SECONDS
	UNTIL((locate(/obj/effect/decal/cleanable/paradise_zombie_bile) in get_turf(victim)) || world.time >= deadline)
	puddle = locate() in get_turf(victim)
	TEST_ASSERT_NOTNULL(puddle, "The cleanup fixture never produced its second bile puddle.")
	TEST_ASSERT(victim.get_fire_loss() > damage_before_prone_shot, "The actual bile projectile passed over its clicked prone victim.")
	expiry = puddle.expiry_timer
	action.ResetCooldown()
	TEST_ASSERT(action.Trigger(host, target = locate(host.x + 13, host.y + 3, host.z)), "The cleanup fixture could not launch a still-flying third shot.")
	var/obj/projectile/paradise_zombie_bile/in_flight = locate() in action.owned_effects
	TEST_ASSERT_NOTNULL(in_flight, "The action did not retain its actual in-flight projectile.")
	var/datum/disease/paradise_zombie/infection = locate() in host.diseases
	infection.cure()
	TEST_ASSERT(QDELETED(action) && QDELETED(puddle) && QDELETED(in_flight), "Cure retained a mutation action, projectile or hostile puddle.")
	TEST_ASSERT_NULL(timeleft(expiry), "Cure left a live expiry timer for its deleted bile.")
	deadline = world.time + 4 SECONDS
	UNTIL(!victim.has_status_effect(/datum/status_effect/paradise_zombie_mutation_bile_slow) || world.time >= deadline)
	TEST_ASSERT(!victim.has_movespeed_modifier(/datum/movespeed_modifier/paradise_zombie_mutation_bile), "The final contact's natural three-second residue never expired after cure.")

/// Overlapping pools keep independent ownership instead of merging into the first caster's residue.
/datum/unit_test/paradise_zombie_mutation_bile_two_sources
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test

/datum/unit_test/paradise_zombie_mutation_bile_two_sources/Run()
	var/mob/living/carbon/human/first = make_mutant("spitter")
	TEST_ASSERT_NOTNULL(first, "The first Spitter fixture was not created.")
	var/mob/living/carbon/human/second = make_zombie(get_step(first, NORTH))
	TEST_ASSERT_NOTNULL(second, "The second Spitter fixture was not created.")
	var/datum/component/paradise_zombie_mutation/controller = second.GetComponent(/datum/component/paradise_zombie_mutation)
	TEST_ASSERT(controller.apply_form("spitter"), "The real outbreak rejected its permitted second special-form slot.")
	var/datum/action/cooldown/paradise_zombie_mutation/bile/first_action = locate() in first.actions
	var/datum/action/cooldown/paradise_zombie_mutation/bile/second_action = locate() in second.actions
	TEST_ASSERT_NOTNULL(first_action, "The first caster lacks its bile action.")
	TEST_ASSERT_NOTNULL(second_action, "The second caster lacks its bile action.")
	var/turf/tile = get_step(first, EAST)
	var/obj/effect/decal/cleanable/paradise_zombie_bile/first_pool = new(tile, first_action)
	first_action.track_effect(first_pool)
	var/obj/effect/decal/cleanable/paradise_zombie_bile/second_pool = new(tile, second_action)
	second_action.track_effect(second_pool)
	TEST_ASSERT(!QDELETED(first_pool) && !QDELETED(second_pool), "Native decal merging discarded one caster's independently owned residue.")
	var/second_expiry = second_pool.expiry_timer
	var/datum/disease/paradise_zombie/infection = locate() in first.diseases
	infection.cure()
	TEST_ASSERT(QDELETED(first_pool), "Cure did not clean its own caster's pool.")
	TEST_ASSERT(!QDELETED(second_pool) && timeleft(second_expiry) > 0, "Curing the first caster removed or untimed the second caster's overlapping pool.")
	second_pool.wash(CLEAN_TYPE_LIGHT_DECAL)
	TEST_ASSERT(QDELETED(second_pool), "The independent second pool could not be washed off.")
	TEST_ASSERT_NULL(timeleft(second_expiry), "Cleaning the second pool retained its timer.")

/// A shot at the exposed original target reaches a non-dense nodule sharing the caster's tile.
/datum/unit_test/paradise_zombie_mutation_nodule_counterplay
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test

/datum/unit_test/paradise_zombie_mutation_nodule_counterplay/Run()
	var/mob/living/carbon/human/host = make_mutant("exploder")
	TEST_ASSERT_NOTNULL(host, "The Exploder fixture was not created.")
	// Restore a real windup window instead of the consistent fixture's instant do_after modifier.
	host.add_or_update_variable_actionspeed_modifier(/datum/actionspeed_modifier/base, multiplicative_slowdown = 0.1)
	var/datum/action/cooldown/paradise_zombie_mutation/explode/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "Exploder did not receive its detonation action.")
	var/mob/living/carbon/human/shooter = allocate(/mob/living/carbon/human/consistent)
	shooter.forceMove(locate(host.x + 2, host.y, host.z))
	INVOKE_ASYNC(action, TYPE_PROC_REF(/datum/action/cooldown, Trigger), host)
	var/obj/structure/paradise_zombie_mutation_nodule/nodule = action.nodule
	TEST_ASSERT_NOTNULL(nodule, "The real detonation windup did not expose its targetable nodule.")
	TEST_ASSERT_EQUAL(get_turf(nodule), get_turf(host), "The targetable nodule was detached from the caster's location.")
	var/health_before = host.get_brute_loss()
	var/obj/projectile/bullet/shot = allocate(/obj/projectile/bullet, get_turf(shooter))
	shot.firer = shooter
	shot.original = nodule
	shot.aim_projectile(nodule, get_turf(shooter))
	shot.fire()
	var/deadline = world.time + 5 SECONDS
	UNTIL(QDELETED(nodule) || world.time >= deadline)
	TEST_ASSERT(QDELETED(nodule), "A real projectile could not hit and destroy the non-dense nodule above its caster.")
	TEST_ASSERT(action.ruptured, "Destroying the real nodule did not invalidate the windup.")
	TEST_ASSERT_EQUAL(host.get_brute_loss() - health_before, 40, "Shooting the nodule did not deal its actual forty damage to the host.")
	deadline = world.time + 5 SECONDS
	UNTIL(!action.priming || world.time >= deadline)
	TEST_ASSERT(host.stat != DEAD, "A ruptured nodule still allowed the suicide blast to execute.")
	TEST_ASSERT(action.next_use_time > world.time, "Nodule counterplay refunded the attempted detonation's cooldown.")
	TEST_ASSERT_EQUAL(length(action.owned_effects), 0, "Interrupted detonation retained its exposed weak point.")

/// Completing the real telegraph harms enemies, spares infected allies and leaves an ordinary curable corpse.
/datum/unit_test/paradise_zombie_mutation_detonation
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test

/datum/unit_test/paradise_zombie_mutation_detonation/Run()
	var/mob/living/carbon/human/host = make_mutant("exploder")
	TEST_ASSERT_NOTNULL(host, "The detonation fixture was not created.")
	TEST_ASSERT(prepare_range(host, offset = 8), "The Exploder fixture has no private range.")
	host.add_or_update_variable_actionspeed_modifier(/datum/actionspeed_modifier/base, multiplicative_slowdown = 0.1)
	var/datum/action/cooldown/paradise_zombie_mutation/explode/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "The real Exploder action was not granted.")
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent)
	victim.forceMove(get_step(host, NORTH))
	var/mob/living/carbon/human/center = allocate(/mob/living/carbon/human/consistent, get_turf(host))
	var/mob/living/carbon/human/edge = allocate(/mob/living/carbon/human/consistent, locate(host.x - 5, host.y, host.z))
	var/mob/living/carbon/human/outside = allocate(/mob/living/carbon/human/consistent, locate(host.x - 6, host.y, host.z))
	var/mob/living/carbon/human/friend = make_zombie(locate(host.x + 1, host.y + 1, host.z))
	TEST_ASSERT_NOTNULL(friend, "The blast's allied-zombie fixture was not created.")
	var/mob/living/carbon/human/sheltered = allocate(/mob/living/carbon/human/consistent)
	sheltered.forceMove(locate(host.x + 2, host.y, host.z))
	var/obj/machinery/door/airlock/glass/cover = allocate(/obj/machinery/door/airlock/glass, get_step(host, EAST))
	TEST_ASSERT(cover.density && !cover.opacity, "The cover fixture is not a real closed, transparent glass airlock.")
	TEST_ASSERT(sheltered in view(2, host), "The glass-cover fixture is already excluded by visibility and would not exercise physical cover.")
	var/friendly_damage_before = friend.get_brute_loss()
	TEST_ASSERT(action.Trigger(host), "The real detonation did not complete its windup.")
	TEST_ASSERT_EQUAL(center.get_brute_loss(), 60, "The completed blast did not deal sixty damage at its center.")
	TEST_ASSERT_EQUAL(victim.get_brute_loss(), 54, "The completed blast did not apply its distance falloff to an adjacent enemy.")
	TEST_ASSERT_EQUAL(edge.get_brute_loss(), 30, "The completed blast did not deal thirty damage at its five-tile boundary.")
	TEST_ASSERT_EQUAL(outside.get_brute_loss(), 0, "The completed blast injured a victim six tiles away.")
	TEST_ASSERT(!outside.IsKnockdown(), "The completed blast knocked down a victim beyond its five-tile boundary.")
	TEST_ASSERT_NULL(locate(/datum/disease/paradise_zombie) in outside.diseases, "The completed blast transmitted infection beyond its five-tile boundary.")
	TEST_ASSERT_EQUAL(friend.get_brute_loss(), friendly_damage_before, "The blast injured an allied zombie.")
	TEST_ASSERT_EQUAL(sheltered.get_brute_loss(), 0, "The blast travelled through an intact closed glass airlock.")
	TEST_ASSERT(!sheltered.IsKnockdown(), "The blast knocked down a victim behind physical cover.")
	TEST_ASSERT_NULL(locate(/datum/disease/paradise_zombie) in sheltered.diseases, "The blast transmitted infection through its closed glass cover.")
	TEST_ASSERT(!QDELETED(host) && host.stat == DEAD, "The blast did not leave its caster as an ordinary dead body.")
	TEST_ASSERT_NOTNULL(host.get_organ_slot(ORGAN_SLOT_BRAIN), "The blast bypassed ordinary revival/cure by destroying the caster's brain.")
	TEST_ASSERT_NOTNULL(locate(/datum/disease/paradise_zombie) in host.diseases, "The blast erased the body's underlying Paradise infection.")
	TEST_ASSERT_NULL(action.nodule, "A completed blast retained its windup-only nodule.")
	TEST_ASSERT_EQUAL(length(action.owned_effects), 0, "The dead Exploder retained owned world effects.")
	var/datum/disease/paradise_zombie/infection = locate() in host.diseases
	infection.cure()
	TEST_ASSERT(QDELETED(action), "Curing the Exploder's corpse retained its mutation action.")
	TEST_ASSERT_NULL(host.GetComponent(/datum/component/paradise_zombie_mutation), "Curing the Exploder's corpse retained its mutation controller.")
	TEST_ASSERT(host.stat == DEAD && host.get_organ_slot(ORGAN_SLOT_BRAIN), "Curing the Exploder's ordinary corpse revived it or destroyed its brain.")

/// Harmful mutation actions retain the same pacifist restriction as ordinary claws and bites.
/datum/unit_test/paradise_zombie_mutation_pacifism
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test
	abstract_type = /datum/unit_test/paradise_zombie_mutation_pacifism
	/// The concrete mutation exercised by this pacifist regression.
	var/form_id

/datum/unit_test/paradise_zombie_mutation_pacifism/bile
	form_id = "spitter"

/datum/unit_test/paradise_zombie_mutation_pacifism/explode
	form_id = "exploder"

/datum/unit_test/paradise_zombie_mutation_pacifism/Run()
	var/mob/living/carbon/human/host = make_mutant(form_id)
	TEST_ASSERT_NOTNULL(host, "The pacifist [form_id] fixture was not created.")
	var/datum/action/cooldown/paradise_zombie_mutation/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "The pacifist fixture did not receive its mutation action.")
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, get_step(host, EAST))
	ADD_TRAIT(host, TRAIT_PACIFISM, TRAIT_SOURCE_UNIT_TESTS)
	TEST_ASSERT(!action.Trigger(host, target = victim), "A pacifist activated the harmful [form_id] mutation ability.")
	TEST_ASSERT(action.next_use_time <= world.time, "Rejecting a pacifist mutation attempt still consumed its cooldown.")
	TEST_ASSERT_EQUAL(length(action.owned_effects), 0, "A rejected pacifist action created temporary world effects.")
	TEST_ASSERT_EQUAL(victim.get_brute_loss() + victim.get_fire_loss(), 0, "A rejected pacifist action damaged its target.")
	TEST_ASSERT(host.stat != DEAD, "Rejecting a pacifist action still killed its caster.")

/// Pacification during a real projectile's flight prevents its later damage and residue.
/datum/unit_test/paradise_zombie_mutation_bile_late_pacifism
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test

/datum/unit_test/paradise_zombie_mutation_bile_late_pacifism/Run()
	var/mob/living/carbon/human/host = make_mutant("spitter")
	TEST_ASSERT_NOTNULL(host, "The in-flight pacification fixture was not created.")
	var/datum/action/cooldown/paradise_zombie_mutation/bile/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "The in-flight pacification fixture has no bile action.")
	var/turf/destination = locate(host.x + 4, host.y, host.z)
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, destination)
	TEST_ASSERT(action.Trigger(host, target = victim), "The unpacified caster could not launch its bile shot.")
	var/obj/projectile/paradise_zombie_bile/shot = locate() in action.owned_effects
	TEST_ASSERT_NOTNULL(shot, "The pacification fixture did not retain a real in-flight shot.")
	ADD_TRAIT(host, TRAIT_PACIFISM, TRAIT_SOURCE_UNIT_TESTS)
	var/deadline = world.time + 5 SECONDS
	UNTIL(QDELETED(shot) || world.time >= deadline)
	TEST_ASSERT(QDELETED(shot), "The pacified caster retained its spent bile projectile.")
	TEST_ASSERT_EQUAL(victim.get_fire_loss(), 0, "An in-flight bile projectile damaged its victim after the caster became pacifist.")
	TEST_ASSERT_NULL(locate(/obj/effect/decal/cleanable/paradise_zombie_bile) in destination, "A pacified caster's projectile left hostile bile at its destination.")

/// Pacification while the actual nodule is exposed aborts the blast without refunding its attempt.
/datum/unit_test/paradise_zombie_mutation_explode_late_pacifism
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test

/datum/unit_test/paradise_zombie_mutation_explode_late_pacifism/Run()
	var/mob/living/carbon/human/host = make_mutant("exploder")
	TEST_ASSERT_NOTNULL(host, "The windup pacification fixture was not created.")
	host.add_or_update_variable_actionspeed_modifier(/datum/actionspeed_modifier/base, multiplicative_slowdown = 0.1)
	var/datum/action/cooldown/paradise_zombie_mutation/explode/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "The windup pacification fixture has no detonation action.")
	var/mob/living/carbon/human/victim = allocate(/mob/living/carbon/human/consistent, get_step(host, EAST))
	INVOKE_ASYNC(action, TYPE_PROC_REF(/datum/action/cooldown, Trigger), host)
	TEST_ASSERT(action.priming && !QDELETED(action.nodule), "The pacification fixture did not enter its actual detonation windup.")
	ADD_TRAIT(host, TRAIT_PACIFISM, TRAIT_SOURCE_UNIT_TESTS)
	var/deadline = world.time + 5 SECONDS
	UNTIL(!action.priming || world.time >= deadline)
	TEST_ASSERT(!action.priming, "Pacifying an Exploder left its windup pending.")
	TEST_ASSERT(host.stat != DEAD, "An Exploder detonated after becoming pacifist during its windup.")
	TEST_ASSERT_EQUAL(victim.get_brute_loss(), 0, "The pacified Exploder's delayed blast injured its neighbour.")
	TEST_ASSERT_NULL(action.nodule, "Aborting a pacified detonation retained its exposed nodule.")
	TEST_ASSERT_EQUAL(length(action.owned_effects), 0, "Aborting a pacified detonation retained temporary world effects.")
	TEST_ASSERT(action.next_use_time > world.time, "Pacification refunded an already-started detonation attempt.")

#endif
