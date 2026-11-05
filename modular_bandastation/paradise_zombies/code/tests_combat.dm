#ifdef UNIT_TESTS

/// Uniform protection makes the attack's random hit zone irrelevant to armour checks.
/datum/armor/paradise_zombie_test_half
	melee = 50

/datum/armor/paradise_zombie_test_full
	melee = 100

/datum/armor/paradise_zombie_test_bio
	bio = 100

/// Thirty-four is the first whole armour point guaranteed to stop Paradise's scratch transmission.
/datum/armor/paradise_zombie_test_scratch_threshold
	melee = 34

/// An armoured, immovable obstacle verifies that the original charging impact bypasses weapon armour.
/obj/structure/paradise_zombie_impact_target
	name = "leap impact target"
	icon = 'icons/obj/storage/closet.dmi'
	icon_state = "generic"
	uses_integrity = TRUE
	density = TRUE
	anchored = TRUE
	max_integrity = 500
	armor_type = /datum/armor/paradise_zombie_test_half

/// Disease creation can unlock a shuttle; restore that shared state after each infection fixture.
/datum/unit_test/paradise_zombie_combat
	abstract_type = /datum/unit_test/paradise_zombie_combat
	/// The incoming server state before a fixture creates a biohazard disease.
	var/previous_shuttle_unlock

/datum/unit_test/paradise_zombie_combat/New()
	. = ..()
	previous_shuttle_unlock = SSshuttle.shuttle_purchase_requirements_met[SHUTTLE_UNLOCK_TOMBSTONE]

/datum/unit_test/paradise_zombie_combat/Destroy()
	. = ..()
	if(isnull(previous_shuttle_unlock))
		SSshuttle.shuttle_purchase_requirements_met -= SHUTTLE_UNLOCK_TOMBSTONE
	else
		SSshuttle.shuttle_purchase_requirements_met[SHUTTLE_UNLOCK_TOMBSTONE] = previous_shuttle_unlock
	return .

/// Exercise the actual ability, including the two-handed component and item retraction.
/datum/unit_test/paradise_zombie_claw_action/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/datum/action/cooldown/paradise_zombie_claws/action = allocate(/datum/action/cooldown/paradise_zombie_claws, user)
	action.Grant(user)
	TEST_ASSERT(action.Trigger(user), "The claw ability did not activate with two empty hands.")
	var/obj/item/paradise_zombie_claw/claws = user.get_active_held_item()
	TEST_ASSERT(istype(claws), "The ability did not create its real claw weapon.")
	TEST_ASSERT_EQUAL(length(action.our_claws), 1, "The ability created more than one pair of claws.")
	TEST_ASSERT_EQUAL(length(user.get_held_items()), 2, "Claws did not reserve both hands.")
	TEST_ASSERT(HAS_TRAIT(claws, TRAIT_WIELDED), "The two-handed component did not wield the claws.")
	TEST_ASSERT(action.Trigger(user), "The ability could not retract its held claws.")
	TEST_ASSERT(QDELETED(claws), "Retracting the ability left its claws alive.")
	TEST_ASSERT_EQUAL(length(user.get_held_items()), 0, "Retracting claws left a phantom offhand item.")

	TEST_ASSERT(action.Trigger(user), "Claws could not be extended a second time.")
	claws = user.get_active_held_item()
	claws.attack_self(user)
	TEST_ASSERT(QDELETED(claws), "Activating the held weapon did not retract it.")
	TEST_ASSERT_EQUAL(length(user.get_held_items()), 0, "Self-retraction left the other hand occupied.")

	var/obj/item/bodypart/arm/other_arm = user.get_inactive_hand()
	other_arm.drop_limb(special = TRUE)
	action.Trigger(user)
	TEST_ASSERT_NULL(user.is_holding_item_of_type(/obj/item/paradise_zombie_claw), "The ability allowed its two-handed claws with one hand missing.")
	TEST_ASSERT_EQUAL(length(action.our_claws), 0, "A failed one-handed activation retained a claw weapon.")

/// The real item attack must preserve Paradise's armour formula, including complete protection.
/datum/unit_test/paradise_zombie_claw_armour/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent)
	target.forceMove(get_step(user, EAST))
	target.add_inner_armor(get_armor_by_type(/datum/armor/paradise_zombie_test_half))
	var/obj/item/paradise_zombie_claw/claws = allocate(/obj/item/paradise_zombie_claw)
	var/obj/item/paradise_zombie_claw/plague/plague_claws = allocate(/obj/item/paradise_zombie_claw/plague)
	// BYOND's float multiplication can differ by a few millionths of one armour point.
	TEST_ASSERT(abs(claws.get_melee_armor_block(target, BODY_ZONE_HEAD, "голову") - 60) < 0.0001, "Normal claws did not respect Paradise's negative twenty-percent penetration.")
	TEST_ASSERT(abs(plague_claws.get_melee_armor_block(target, BODY_ZONE_HEAD, "голову") - 45) < 0.0001, "Plague claws lost either the inherited percentage or their fifteen flat penetration.")
	target.remove_inner_armor(get_armor_by_type(/datum/armor/paradise_zombie_test_half))
	target.add_inner_armor(get_armor_by_type(/datum/armor/paradise_zombie_test_full))
	TEST_ASSERT_EQUAL(claws.get_melee_armor_block(target, BODY_ZONE_HEAD, "голову"), 100, "Full armour was reduced to TG's default ninety-percent cap.")
	TEST_ASSERT(user.put_in_hands(claws), "The armour fixture could not wield the real claws.")
	user.set_combat_mode(TRUE)
	claws.melee_attack_chain(user, target, list())
	TEST_ASSERT_EQUAL(target.get_brute_loss(), 0, "The actual melee chain bypassed the claw-specific full armour block.")

/// A real unarmed attack with an aggressive grab must deliver a bite through bio protection and antibiotics.
/datum/unit_test/paradise_zombie_grab_bite
	parent_type = /datum/unit_test/paradise_zombie_combat

/datum/unit_test/paradise_zombie_grab_bite/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	ADD_TRAIT(user, TRAIT_PARADISE_ZOMBIE, TRAIT_GENERIC)
	user.AddComponent(/datum/component/paradise_zombie_combat)
	user.set_combat_mode(TRUE)
	user.zone_selected = BODY_ZONE_CHEST
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent)
	target.forceMove(get_step(user, EAST))
	// Random wounds are unrelated to the bite's fixed damage and transmission contract.
	ADD_TRAIT(target, TRAIT_NEVER_WOUNDED, TRAIT_GENERIC)
	target.add_inner_armor(get_armor_by_type(/datum/armor/paradise_zombie_test_bio))
	target.reagents.add_reagent(/datum/reagent/medicine/paradise_zombie_cure/alpha, 2)
	target.reagents.add_reagent(/datum/reagent/medicine/spaceacillin, 2)
	TEST_ASSERT(user.start_pulling(target), "The bite fixture could not grab the target.")
	user.setGrabState(GRAB_AGGRESSIVE)
	user.UnarmedAttack(target, TRUE, list())
	var/obj/item/bodypart/chest/chest = target.get_bodypart(BODY_ZONE_CHEST)
	TEST_ASSERT_EQUAL(chest.brute_dam, 20, "An aggressive unarmed grab did not deliver the selected-zone bite damage.")
	var/datum/disease/paradise_zombie/infection = locate() in target.diseases
	TEST_ASSERT_NOTNULL(infection, "Bio protection or antibiotics blocked an aggressive zombie bite.")
	TEST_ASSERT(infection.stage >= 3 && infection.stage <= 4, "A bite did not begin at one of Paradise's two permitted stages.")
	TEST_ASSERT_NULL(user.pulling, "A successful bite did not release the grab.")

	var/mob/living/carbon/human/second_target = allocate(/mob/living/carbon/human/consistent)
	second_target.forceMove(get_step(user, NORTH))
	ADD_TRAIT(second_target, TRAIT_NEVER_WOUNDED, TRAIT_GENERIC)
	ADD_TRAIT(user, TRAIT_PARADISE_NON_INFECTIOUS_ZOMBIE, TRAIT_GENERIC)
	user.zone_selected = BODY_ZONE_L_ARM
	TEST_ASSERT(user.start_pulling(second_target), "The non-infectious fixture could not grab its target.")
	user.setGrabState(GRAB_AGGRESSIVE)
	user.UnarmedAttack(second_target, TRUE, list())
	var/obj/item/bodypart/arm/bitten_arm = second_target.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT_EQUAL(bitten_arm.brute_dam, 20, "A non-infectious zombie lost its bite or selected limb.")
	TEST_ASSERT_NULL(locate(/datum/disease/paradise_zombie) in second_target.diseases, "A non-infectious zombie transmitted the virus.")

/// Open a damaged skull through the real weapon chain, then eat through the unarmed signal path.
/datum/unit_test/paradise_zombie_brain_feeding
	parent_type = /datum/unit_test/paradise_zombie_combat

/datum/unit_test/paradise_zombie_brain_feeding/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	ADD_TRAIT(user, TRAIT_PARADISE_ZOMBIE, TRAIT_GENERIC)
	var/datum/component/paradise_zombie_combat/combat = user.AddComponent(/datum/component/paradise_zombie_combat)
	user.set_combat_mode(TRUE)
	user.zone_selected = BODY_ZONE_HEAD
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent)
	target.forceMove(get_step(user, EAST))
	target.maxHealth = 1000
	// A known strain isolates stage advancement from the scratch's intentional infection chance.
	var/datum/disease/paradise_zombie/infection = new
	TEST_ASSERT(target.ForceContractDisease(infection, make_copy = FALSE, del_on_fail = TRUE), "The feeding fixture could not acquire its initial strain.")
	var/obj/item/bodypart/head/head = target.get_bodypart(BODY_ZONE_HEAD)
	head.set_initial_damage(head.max_damage - 4, 0)
	var/obj/item/paradise_zombie_claw/claws = allocate(/obj/item/paradise_zombie_claw)
	// Prevent an incidental wound roll from opening the skull before our ability does.
	claws.wound_bonus = CANT_WOUND
	TEST_ASSERT(user.put_in_hands(claws), "The feeding fixture could not wield its claws.")
	claws.melee_attack_chain(user, target, list())
	var/deadline = world.time + 5 SECONDS
	UNTIL(!claws.opening_skull || world.time >= deadline)
	TEST_ASSERT(!claws.opening_skull, "Skull opening did not finish within its bounded fixture window.")
	TEST_ASSERT(LIMB_HAS_SURGERY_STATE(head, SURGERY_SKIN_OPEN|SURGERY_BONE_SAWED), "Claw attacks did not open the damaged skull for feeding.")
	claws.attack_self(user)
	TEST_ASSERT_EQUAL(length(user.get_held_items()), 0, "The feeding fixture still holds its claws.")
	var/brain_damage_before = target.get_organ_loss(ORGAN_SLOT_BRAIN)
	user.UnarmedAttack(target, TRUE, list())
	deadline = world.time + 5 SECONDS
	UNTIL(!combat.eating || world.time >= deadline)
	TEST_ASSERT(!combat.eating, "Brain feeding did not finish within its bounded fixture window.")
	TEST_ASSERT_EQUAL(target.get_organ_loss(ORGAN_SLOT_BRAIN), brain_damage_before + 5, "The unarmed feeding path did not consume five brain health.")
	TEST_ASSERT(infection in target.diseases, "Feeding lost the victim's known strain.")
	TEST_ASSERT(infection.stage >= 5, "Feeding did not advance the victim to at least stage five.")

	// An organic jelly head cannot receive a bone fracture; opening must still expose its brain.
	target.forceMove(run_loc_floor_top_right)
	var/mob/living/carbon/human/slime_target = allocate(/mob/living/carbon/human/consistent)
	slime_target.set_species(/datum/species/jelly/slime)
	slime_target.forceMove(get_step(user, EAST))
	slime_target.maxHealth = 1000
	var/obj/item/bodypart/head/slime_head = slime_target.get_bodypart(BODY_ZONE_HEAD)
	TEST_ASSERT(!(slime_head.biological_state & BIO_BONE), "The real slime-person fixture unexpectedly has a bony head.")
	TEST_ASSERT(!LIMB_HAS_SURGERY_STATE(slime_head, SURGERY_SKIN_OPEN), "The slime-person fixture already has an open head.")
	infection = new
	TEST_ASSERT(slime_target.ForceContractDisease(infection, make_copy = FALSE, del_on_fail = TRUE), "The slime-person fixture could not acquire its known strain.")
	slime_head.set_initial_damage(slime_head.max_damage - 4, 0)
	claws = allocate(/obj/item/paradise_zombie_claw)
	claws.wound_bonus = CANT_WOUND
	TEST_ASSERT(user.put_in_hands(claws), "The slime-person fixture could not wield its claws.")
	claws.melee_attack_chain(user, slime_target, list())
	deadline = world.time + 5 SECONDS
	UNTIL(!claws.opening_skull || world.time >= deadline)
	TEST_ASSERT(!claws.opening_skull, "Opening the slime-person's damaged head never finished.")
	TEST_ASSERT(LIMB_HAS_SURGERY_STATE(slime_head, SURGERY_SKIN_OPEN|SURGERY_BONE_SAWED), "Claw opening silently failed on a boneless organic brain holder.")
	claws.attack_self(user)
	brain_damage_before = slime_target.get_organ_loss(ORGAN_SLOT_BRAIN)
	user.UnarmedAttack(slime_target, TRUE, list())
	deadline = world.time + 5 SECONDS
	UNTIL(!combat.eating || world.time >= deadline)
	TEST_ASSERT(!combat.eating, "Feeding on the opened slime-person head never finished.")
	TEST_ASSERT_EQUAL(slime_target.get_organ_loss(ORGAN_SLOT_BRAIN), brain_damage_before + 5, "The actual unarmed feeding path could not consume the exposed slime-person brain.")
	TEST_ASSERT(infection.stage >= 5, "Feeding on the slime-person did not advance its known strain to stage five.")

/// Putting armour on during a real three-second opening action must invalidate the effect.
/datum/unit_test/paradise_zombie_skull_revalidation
	parent_type = /datum/unit_test/paradise_zombie_combat

/datum/unit_test/paradise_zombie_skull_revalidation/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent/slow)
	user.set_combat_mode(TRUE)
	user.zone_selected = BODY_ZONE_HEAD
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent)
	target.forceMove(get_step(user, EAST))
	target.maxHealth = 1000
	var/obj/item/bodypart/head/head = target.get_bodypart(BODY_ZONE_HEAD)
	head.set_initial_damage(head.max_damage - 4, 0)
	var/obj/item/paradise_zombie_claw/claws = allocate(/obj/item/paradise_zombie_claw)
	claws.wound_bonus = CANT_WOUND
	TEST_ASSERT(user.put_in_hands(claws), "The interrupted-opening fixture could not wield its claws.")
	claws.melee_attack_chain(user, target, list())
	TEST_ASSERT(claws.opening_skull, "The fixture did not enter the actual delayed skull-opening action.")
	target.add_inner_armor(get_armor_by_type(/datum/armor/paradise_zombie_test_half))
	var/deadline = world.time + 6 SECONDS
	UNTIL(!claws.opening_skull || world.time >= deadline)
	TEST_ASSERT(!claws.opening_skull, "The interrupted skull-opening action never completed.")
	TEST_ASSERT(!LIMB_HAS_SURGERY_STATE(head, SURGERY_BONE_SAWED), "Skull opening ignored armour gained while its action was delayed.")

/// These infection-boundary denials are guaranteed; the scratch's successful-infection probability is irrelevant.
/datum/unit_test/paradise_zombie_scratch_protection
	parent_type = /datum/unit_test/paradise_zombie_combat

/datum/unit_test/paradise_zombie_scratch_protection/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/paradise_zombie_claw/claws = allocate(/obj/item/paradise_zombie_claw)
	user.zone_selected = BODY_ZONE_HEAD
	for(var/reagent_type in list(/datum/reagent/medicine/paradise_zombie_cure/alpha, /datum/reagent/medicine/spaceacillin))
		target.reagents.add_reagent(reagent_type, 2)
		TEST_ASSERT(!claws.try_infect(target, user), "A scratch bypassed [reagent_type] at the infection boundary.")
		TEST_ASSERT_NULL(locate(/datum/disease/paradise_zombie) in target.diseases, "A protected scratch created an infection despite its denial.")
		target.reagents.clear_reagents()

	ADD_TRAIT(target, TRAIT_PIERCEIMMUNE, TRAIT_GENERIC)
	TEST_ASSERT(!claws.try_infect(target, user), "A scratch pierced an immune target.")
	TEST_ASSERT_NULL(locate(/datum/disease/paradise_zombie) in target.diseases, "A pierce-immune target acquired the plague.")
	REMOVE_TRAIT(target, TRAIT_PIERCEIMMUNE, TRAIT_GENERIC)
	target.add_inner_armor(get_armor_by_type(/datum/armor/paradise_zombie_test_scratch_threshold))
	TEST_ASSERT(!claws.try_infect(target, user), "Thirty-four melee armour failed to guarantee scratch protection.")
	TEST_ASSERT_NULL(locate(/datum/disease/paradise_zombie) in target.diseases, "A scratch infected through armour above the original threshold.")
	target.remove_inner_armor(get_armor_by_type(/datum/armor/paradise_zombie_test_scratch_threshold))
	user.zone_selected = BODY_ZONE_L_ARM
	TEST_ASSERT(!claws.try_infect(target, user), "A scratch transmitted through an unsupported limb zone.")
	TEST_ASSERT_NULL(locate(/datum/disease/paradise_zombie) in target.diseases, "An arm scratch created the plague.")

	var/obj/item/bodypart/head/robot/robotic_head = allocate(/obj/item/bodypart/head/robot)
	TEST_ASSERT(robotic_head.replace_limb(target), "The robotic-head fixture could not install its prosthesis.")
	user.zone_selected = BODY_ZONE_HEAD
	TEST_ASSERT(!claws.try_infect(target, user), "A scratch infected through an augmented head.")
	TEST_ASSERT_NULL(locate(/datum/disease/paradise_zombie) in target.diseases, "A robotic head scratch created the plague.")
	var/obj/item/bodypart/chest/robot/robotic_chest = allocate(/obj/item/bodypart/chest/robot)
	TEST_ASSERT(robotic_chest.replace_limb(target), "The robotic-chest fixture could not install its prosthesis.")
	user.zone_selected = BODY_ZONE_CHEST
	TEST_ASSERT(!claws.try_infect(target, user), "A scratch infected through an augmented chest.")
	TEST_ASSERT_NULL(locate(/datum/disease/paradise_zombie) in target.diseases, "A robotic chest scratch created the plague.")

/// Blood delivered into exposed tissue bypasses BIO-only clothing for scratches, feeding and plague claws.
/datum/unit_test/paradise_zombie_blood_transmission
	parent_type = /datum/unit_test/paradise_zombie_combat

/datum/unit_test/paradise_zombie_blood_transmission/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	ADD_TRAIT(user, TRAIT_PARADISE_ZOMBIE, TRAIT_GENERIC)
	var/datum/component/paradise_zombie_combat/combat = user.AddComponent(/datum/component/paradise_zombie_combat)
	user.set_combat_mode(TRUE)
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent)
	target.forceMove(get_step(user, EAST))
	target.maxHealth = 1000
	target.satiety = 0
	var/obj/item/clothing/head/bio_hood/general/hood = allocate(/obj/item/clothing/head/bio_hood/general)
	var/obj/item/clothing/suit/bio_suit/general/suit = allocate(/obj/item/clothing/suit/bio_suit/general)
	TEST_ASSERT(target.equip_to_slot_if_possible(hood, ITEM_SLOT_HEAD), "The blood exposure fixture could not equip its actual bio hood.")
	TEST_ASSERT(target.equip_to_slot_if_possible(suit, ITEM_SLOT_OCLOTHING), "The blood exposure fixture could not equip its actual bio suit.")
	var/obj/item/paradise_zombie_claw/claws = allocate(/obj/item/paradise_zombie_claw)
	for(var/target_zone in list(BODY_ZONE_HEAD, BODY_ZONE_CHEST))
		user.zone_selected = target_zone
		TEST_ASSERT_EQUAL(target.getarmor(target_zone, BIO), 100, "The selected blood exposure zone does not have full bio protection.")
		TEST_ASSERT_EQUAL(target.getarmor(target_zone, MELEE), 0, "The bio clothing unexpectedly supplies scratch-blocking melee armour.")
		var/transmitted = FALSE
		// Bounded retries exercise actual transmission, without asserting the probability distribution.
		for(var/attempt in 1 to 32)
			claws.try_infect(target, user)
			var/datum/disease/paradise_zombie/infection = locate() in target.diseases
			if(infection)
				transmitted = TRUE
				infection.cure(add_resistance = FALSE)
				break
		TEST_ASSERT(transmitted, "Scratches never transmitted into [target_zone] through BIO-only clothing.")
		for(var/reagent_type in list(/datum/reagent/medicine/paradise_zombie_cure/alpha, /datum/reagent/medicine/spaceacillin))
			target.reagents.add_reagent(reagent_type, 2)
			TEST_ASSERT(!claws.try_infect(target, user), "The blood-transfer adaptation bypassed [reagent_type]'s scratch protection.")
			TEST_ASSERT_NULL(locate(/datum/disease/paradise_zombie) in target.diseases, "A medicine-protected scratch created a blood infection.")
			target.reagents.clear_reagents()

	user.zone_selected = BODY_ZONE_HEAD
	var/obj/item/bodypart/head/head = target.get_bodypart(BODY_ZONE_HEAD)
	head.add_surgical_state(SURGERY_SKIN_OPEN|SURGERY_BONE_SAWED)
	var/brain_transmitted = FALSE
	for(var/attempt in 1 to 16)
		user.UnarmedAttack(target, TRUE, list())
		var/deadline = world.time + 5 SECONDS
		UNTIL(!combat.eating || world.time >= deadline)
		TEST_ASSERT(!combat.eating, "The bio-clothed brain exposure never completed its feeding action.")
		var/datum/disease/paradise_zombie/infection = locate() in target.diseases
		if(infection)
			brain_transmitted = infection.stage >= 5
			infection.cure(add_resistance = FALSE)
			break
	TEST_ASSERT(brain_transmitted, "Actual brain feeding never delivered a stage-five strain through the BIO-only hood.")
	var/obj/item/paradise_zombie_claw/plague/plague_claws = allocate(/obj/item/paradise_zombie_claw/plague)
	plague_claws.claw_disease = /datum/disease/cold9/paradise_plague
	var/plague_transmitted = FALSE
	for(var/attempt in 1 to 16)
		plague_claws.try_virus_infect(target, user)
		var/datum/disease/cold9/paradise_plague/infection = locate() in target.diseases
		if(infection)
			plague_transmitted = TRUE
			infection.cure(add_resistance = FALSE)
			break
	TEST_ASSERT(plague_transmitted, "Plague claws never delivered their selected non-contagious disease through BIO-only clothing.")

/// Exercise the real action and throw system; observers record applied knockdown without racing its expiry.
/datum/unit_test/paradise_zombie_plague_leap
	/// Duration delivered through the living knockdown boundary.
	var/observed_knockdown = 0
	/// Whether the actual status effect made the victim prone.
	var/observed_prone = FALSE
	/// Coordinates of the one turf replaced by the wall collision fixture.
	var/list/wall_position
	/// Type restored after the wall collision fixture, including an early assertion failure.
	var/wall_original_type

/datum/unit_test/paradise_zombie_plague_leap/Destroy()
	if(wall_position)
		var/turf/wall_tile = locate(wall_position[1], wall_position[2], wall_position[3])
		wall_tile.ChangeTurf(wall_original_type)
	return ..()

/datum/unit_test/paradise_zombie_plague_leap/proc/on_knockdown(mob/living/source, amount)
	SIGNAL_HANDLER
	observed_knockdown = amount

/datum/unit_test/paradise_zombie_plague_leap/proc/on_position(mob/living/source, new_position)
	SIGNAL_HANDLER
	if(new_position == LYING_DOWN)
		observed_prone = TRUE

/datum/unit_test/paradise_zombie_plague_leap/Run()
	var/mob/living/carbon/human/user = allocate(/mob/living/carbon/human/consistent)
	ADD_TRAIT(user, TRAIT_PARADISE_ZOMBIE, TRAIT_GENERIC)
	ADD_TRAIT(user, TRAIT_PARADISE_PLAGUE_ZOMBIE, TRAIT_GENERIC)
	var/mob/living/carbon/human/target = allocate(/mob/living/carbon/human/consistent)
	target.forceMove(get_step(user, EAST))
	var/obj/item/paradise_zombie_claw/plague/claws = allocate(/obj/item/paradise_zombie_claw/plague)
	claws.wound_bonus = CANT_WOUND
	TEST_ASSERT(user.put_in_hands(claws), "The leap fixture could not wield its plague claws.")
	RegisterSignal(target, COMSIG_LIVING_STATUS_KNOCKDOWN, PROC_REF(on_knockdown))
	RegisterSignal(target, COMSIG_LIVING_SET_BODY_POSITION, PROC_REF(on_position))
	var/datum/action/cooldown/paradise_zombie_leap/leap = allocate(/datum/action/cooldown/paradise_zombie_leap, user)
	leap.Grant(user)
	TEST_ASSERT(leap.Trigger(user, target = target), "The real plague leap action did not start its throw.")
	var/deadline = world.time + 5 SECONDS
	UNTIL(!user.throwing || world.time >= deadline)
	TEST_ASSERT_NULL(user.throwing, "The plague leap never finished.")
	var/target_brute = 0
	for(var/obj/item/bodypart/limb as anything in target.get_bodyparts())
		target_brute += limb.brute_dam
	TEST_ASSERT_EQUAL(target_brute, 13, "The leap failed to attack exactly once with the held plague claws.")
	TEST_ASSERT_EQUAL(observed_knockdown, 1 SECONDS, "The plague leap did not deliver its one-second knockdown.")
	TEST_ASSERT(observed_prone, "The leap requested knockdown but its actual status effect never made the target prone.")
	TEST_ASSERT_EQUAL(user.get_brute_loss(), 0, "The leap applied TG's ordinary throw self-damage to its caster.")
	UnregisterSignal(target, list(COMSIG_LIVING_STATUS_KNOCKDOWN, COMSIG_LIVING_SET_BODY_POSITION))
	target.forceMove(run_loc_floor_top_right)

	// Native human throws have their own impact damage even when gentle; measure an independent control.
	var/mob/living/carbon/human/control_user = allocate(/mob/living/carbon/human/consistent, get_turf(user))
	ADD_TRAIT(control_user, TRAIT_PARADISE_ZOMBIE, TRAIT_GENERIC)
	ADD_TRAIT(control_user, TRAIT_PARADISE_PLAGUE_ZOMBIE, TRAIT_GENERIC)
	var/obj/structure/paradise_zombie_impact_target/control_obstacle = allocate(/obj/structure/paradise_zombie_impact_target, get_step(control_user, NORTH))
	var/control_initial_integrity = control_obstacle.get_integrity()
	TEST_ASSERT(control_user.throw_at(control_obstacle, 1, 1, control_user, spin = FALSE, gentle = TRUE), "The independent ordinary throw could not start.")
	deadline = world.time + 5 SECONDS
	UNTIL(!control_user.throwing || world.time >= deadline)
	TEST_ASSERT_NULL(control_user.throwing, "The independent ordinary throw never finished.")
	var/control_impact_damage = control_initial_integrity - control_obstacle.get_integrity()
	TEST_ASSERT(control_impact_damage > 0, "The independent ordinary throw did not reach its obstacle.")
	qdel(control_user)
	qdel(control_obstacle)

	var/obj/structure/paradise_zombie_impact_target/obstacle = allocate(/obj/structure/paradise_zombie_impact_target, get_step(user, EAST))
	var/initial_integrity = obstacle.get_integrity()
	TEST_ASSERT(user.throw_at(obstacle, 1, 1, user, spin = FALSE, gentle = TRUE), "The unrelated control throw could not start.")
	deadline = world.time + 5 SECONDS
	UNTIL(!user.throwing || world.time >= deadline)
	TEST_ASSERT_NULL(user.throwing, "The unrelated control throw never finished.")
	TEST_ASSERT_EQUAL(initial_integrity - obstacle.get_integrity(), control_impact_damage, "Plague charging leaked into a later ordinary throw, changing its impact from the fresh control.")
	var/before_leap_integrity = obstacle.get_integrity()
	leap.ResetCooldown()
	TEST_ASSERT(leap.Trigger(user, target = obstacle), "The plague leap could not target an obstacle.")
	deadline = world.time + 5 SECONDS
	UNTIL(!user.throwing || world.time >= deadline)
	TEST_ASSERT_NULL(user.throwing, "The obstacle leap never finished.")
	TEST_ASSERT_EQUAL(obstacle.get_integrity(), before_leap_integrity - 150, "The plague leap did not deal exactly one 150-damage obstacle impact.")
	TEST_ASSERT_EQUAL(user.get_brute_loss(), 0, "An obstacle impact damaged the plague leap's caster.")

	var/turf/wall_tile = get_step(user, NORTH)
	wall_original_type = wall_tile.type
	wall_position = list(wall_tile.x, wall_tile.y, wall_tile.z)
	var/turf/closed/wall/wall = wall_tile.ChangeTurf(/turf/closed/wall)
	leap.ResetCooldown()
	TEST_ASSERT(leap.Trigger(user, target = wall), "The plague leap could not target a wall.")
	deadline = world.time + 5 SECONDS
	UNTIL(!user.throwing || world.time >= deadline)
	TEST_ASSERT_NULL(user.throwing, "The wall leap never finished.")
	wall_tile = locate(wall_position[1], wall_position[2], wall_position[3])
	TEST_ASSERT(!iswallturf(wall_tile), "The plague leap failed to dismantle its wall obstacle.")
	TEST_ASSERT_EQUAL(user.get_brute_loss(), 0, "A wall impact damaged the plague leap's caster.")

#endif
