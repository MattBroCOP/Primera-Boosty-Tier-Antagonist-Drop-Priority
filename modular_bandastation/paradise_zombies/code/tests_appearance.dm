#ifdef UNIT_TESTS

/** Real infection fixtures isolate the renderer without replacing the body's disease or physiology. */
/datum/unit_test/paradise_zombie_appearance_test
	parent_type = /datum/unit_test/paradise_zombie_mutation_test
	abstract_type = /datum/unit_test/paradise_zombie_appearance_test

/** Counts actual world overlays, rather than trusting a component's bookkeeping alone. */
/datum/unit_test/paradise_zombie_appearance_test/proc/count_body_overlays(mob/living/carbon/human/host, icon_file)
	var/count = 0
	for(var/mutable_appearance/overlay as anything in host.overlays)
		if(overlay.icon == icon_file)
			count++
	return count

/** Male and female bodies use TGMC's real directional parts and retain native Paradise husk mechanics. */
/datum/unit_test/paradise_zombie_tgmc_body
	parent_type = /datum/unit_test/paradise_zombie_appearance_test

/datum/unit_test/paradise_zombie_tgmc_body/Run()
	var/mob/living/carbon/human/host = make_zombie(run_loc_floor_bottom_left)
	var/datum/component/paradise_zombie_appearance/appearance = host.GetComponent(/datum/component/paradise_zombie_appearance)
	TEST_ASSERT_NOTNULL(appearance, "Full Paradise transformation did not attach its TGMC appearance.")
	TEST_ASSERT_NOTNULL(appearance.body_appearance, "The ordinary zombie has no live TGMC body overlay.")
	TEST_ASSERT_EQUAL(count_body_overlays(host, appearance.body_appearance.icon), 1, "The ordinary zombie has missing or duplicated TGMC body overlays.")
	TEST_ASSERT(HAS_TRAIT_FROM(host, TRAIT_HUSK, PARADISE_ZOMBIE_TRAIT), "Changing the sprite removed native husk gameplay state.")
	for(var/obj/item/bodypart/limb as anything in host.get_bodyparts())
		var/datum/component/paradise_zombie_limb/rot = limb.GetComponent(/datum/component/paradise_zombie_limb)
		TEST_ASSERT(rot?.necrotic && rot.infected, "Changing the sprite removed a limb's infected necrosis.")
		TEST_ASSERT_EQUAL(limb.is_husked, HUSKED_ZOMBIE, "Changing the sprite removed a limb's native zombie state.")
	var/icon/old_cached_icon = appearance.cached_body_icon
	host.update_body()
	TEST_ASSERT_EQUAL(appearance.cached_body_icon, old_cached_icon, "A normal icon refresh needlessly rebuilt all directional source parts.")
	test_screenshot("male", get_flat_icon_for_all_directions(host))
	host.death()
	host.timeofdeath = world.time - 15 SECONDS
	var/datum/component/paradise_zombie_regen/regeneration = host.GetComponent(/datum/component/paradise_zombie_regen)
	regeneration.process(1)
	TEST_ASSERT_NOTEQUAL(host.stat, DEAD, "The ordinary TGMC zombie did not survive its real Paradise resurrection.")
	TEST_ASSERT_EQUAL(host.GetComponent(/datum/component/paradise_zombie_appearance), appearance, "Resurrection replaced or removed the ordinary TGMC renderer.")
	TEST_ASSERT_NOTNULL(appearance.body_appearance, "Resurrection removed the ordinary TGMC body image.")
	TEST_ASSERT_EQUAL(count_body_overlays(host, appearance.body_appearance.icon), 1, "Native healing and revival left a missing or duplicated TGMC body image.")
	host.physique = FEMALE
	host.update_body(TRUE)
	TEST_ASSERT_NOTEQUAL(appearance.cached_body_icon, old_cached_icon, "Changing physique did not invalidate the directional body cache.")
	TEST_ASSERT_EQUAL(count_body_overlays(host, appearance.body_appearance.icon), 1, "Changing physique left a previous male body overlay behind.")
	test_screenshot("female", get_flat_icon_for_all_directions(host))

/** Missing tissue stays missing, a transplanted arm remains donor tissue, and tumor extraction restores native anatomy. */
/datum/unit_test/paradise_zombie_tgmc_anatomy_and_cure
	parent_type = /datum/unit_test/paradise_zombie_appearance_test

/datum/unit_test/paradise_zombie_tgmc_anatomy_and_cure/Run()
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	host.set_species(/datum/species/lizard)
	host.mind_initialize()
	var/datum/dna/original_dna = host.dna
	var/datum/species/original_species = host.dna.species
	var/list/original_organs = host.organs.Copy()
	var/datum/disease/paradise_zombie/infection = new
	TEST_ASSERT(host.ForceContractDisease(infection, make_copy = FALSE, del_on_fail = TRUE), "The appearance fixture could not contract the actual infection.")
	infection.stage = 8
	infection.process_infection_cycle()
	var/datum/component/paradise_zombie_appearance/appearance = host.GetComponent(/datum/component/paradise_zombie_appearance)
	TEST_ASSERT_NOTNULL(appearance, "The infected nonhuman has no ordinary TGMC appearance.")
	var/icon/complete_body = appearance.cached_body_icon
	var/obj/item/bodypart/leg = host.get_bodypart(BODY_ZONE_L_LEG)
	allocated |= leg
	leg.drop_limb(special = TRUE)
	TEST_ASSERT_NOTEQUAL(appearance.cached_body_icon, complete_body, "Losing a real leg left a cached complete body.")
	var/mob/living/carbon/human/donor = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/arm = donor.get_bodypart(BODY_ZONE_L_ARM)
	allocated |= arm
	allocated |= host.get_bodypart(BODY_ZONE_L_ARM)
	var/donor_skin_tone = arm.skin_tone
	var/donor_species_color = arm.species_color
	arm.drop_limb(special = TRUE)
	TEST_ASSERT(arm.replace_limb(host), "Real donor tissue could not attach while TGMC appearance was active.")
	arm.receive_damage(brute = 9, burn = 3, forced = TRUE, wound_bonus = CANT_WOUND)
	var/brute_before = arm.brute_dam
	var/burn_before = arm.burn_dam
	var/obj/item/bodypart/head/head = host.get_bodypart(BODY_ZONE_HEAD)
	head.add_surgical_state(SURGERY_SKIN_OPEN | SURGERY_BONE_SAWED)
	var/source_overlay_icon = appearance.body_appearance.icon
	test_screenshot("missing_leg_transplant", get_flat_icon_for_all_directions(host))
	var/obj/item/organ/paradise_zombie_tumor/tumor = host.get_organ_slot(ORGAN_SLOT_ZOMBIE)
	TEST_ASSERT_NOTNULL(tumor, "The TGMC appearance removed the Paradise surgical cure target.")
	tumor.Remove(host)
	TEST_ASSERT_NULL(host.GetComponent(/datum/component/paradise_zombie_appearance), "Surgical cure retained the ordinary zombie renderer.")
	TEST_ASSERT_EQUAL(count_body_overlays(host, source_overlay_icon), 0, "Surgical cure retained a TGMC body image.")
	TEST_ASSERT_EQUAL(host.dna, original_dna, "TGMC appearance replaced the original DNA datum.")
	TEST_ASSERT_EQUAL(host.dna.species, original_species, "TGMC appearance replaced the original species datum.")
	for(var/obj/item/organ/organ as anything in original_organs)
		TEST_ASSERT(organ in host.organs, "TGMC appearance replaced an original internal organ.")
	TEST_ASSERT_NULL(host.get_bodypart(BODY_ZONE_L_LEG), "Surgical cure regrew a leg missing during TGMC appearance.")
	TEST_ASSERT_EQUAL(host.get_bodypart(BODY_ZONE_L_ARM), arm, "Surgical cure replaced the actual donor arm.")
	TEST_ASSERT_EQUAL(arm.skin_tone, donor_skin_tone, "Appearance cleanup recolored donor tissue from recipient DNA.")
	TEST_ASSERT_EQUAL(arm.species_color, donor_species_color, "Appearance cleanup replaced the donor's species color.")
	TEST_ASSERT_EQUAL(arm.brute_dam, brute_before, "Appearance cleanup healed unrelated brute damage.")
	TEST_ASSERT_EQUAL(arm.burn_dam, burn_before, "Appearance cleanup healed unrelated burn damage.")
	TEST_ASSERT(LIMB_HAS_SURGERY_STATE(head, SURGERY_SKIN_OPEN | SURGERY_BONE_SAWED), "Appearance cleanup closed an actual surgical opening.")
	test_screenshot("restored_lizard_transplant", get_flat_icon_for_all_directions(host))

/** Production mutation transitions prefer DS13 and return TGMC only while the ordinary infection survives. */
/datum/unit_test/paradise_zombie_tgmc_mutation_priority
	parent_type = /datum/unit_test/paradise_zombie_appearance_test

/datum/unit_test/paradise_zombie_tgmc_mutation_priority/Run()
	var/mob/living/carbon/human/host = make_mutant("hunter")
	var/datum/component/paradise_zombie_appearance/appearance = host.GetComponent(/datum/component/paradise_zombie_appearance)
	var/datum/component/paradise_zombie_mutation/controller = host.GetComponent(/datum/component/paradise_zombie_mutation)
	TEST_ASSERT_NOTNULL(appearance, "Selecting a DS13 form deleted the ordinary renderer instead of hiding it.")
	TEST_ASSERT_NULL(appearance.body_appearance, "TGMC and DS13 bodies were drawn simultaneously after mutation.")
	test_screenshot("hunter", paradise_zombie_mutation_screenshot(host))
	controller.clear_form()
	TEST_ASSERT_NULL(host.GetComponent(/datum/component/paradise_zombie_mutation_body), "The actual controller clear left a DS13 renderer behind.")
	TEST_ASSERT_NOTNULL(appearance.body_appearance, "Removing the actual DS13 renderer did not return TGMC appearance.")
	var/source_overlay_icon = appearance.body_appearance.icon
	TEST_ASSERT_EQUAL(count_body_overlays(host, source_overlay_icon), 1, "DS13 cleanup restored a duplicated TGMC body.")
	test_screenshot("ordinary_returned", get_flat_icon_for_all_directions(host))
	TEST_ASSERT(controller.apply_form("hunter"), "The same controller could not reapply its permitted physical form.")
	TEST_ASSERT_NULL(appearance.body_appearance, "Reapplying a DS13 form retained ordinary TGMC appearance.")
	TEST_ASSERT_EQUAL(count_body_overlays(host, source_overlay_icon), 0, "Reapplying a DS13 form left its former TGMC body in world overlays.")
	host.update_body()
	TEST_ASSERT_NULL(appearance.body_appearance, "A native icon refresh drew TGMC over an active DS13 form.")
	var/obj/item/organ/paradise_zombie_tumor/tumor = host.get_organ_slot(ORGAN_SLOT_ZOMBIE)
	tumor.Remove(host)
	TEST_ASSERT_NULL(host.GetComponent(/datum/component/paradise_zombie_appearance), "Curing an active DS13 mutation retained its hidden TGMC renderer.")
	TEST_ASSERT_NULL(host.GetComponent(/datum/component/paradise_zombie_mutation_body), "Curing an active DS13 mutation retained its DS13 renderer.")
	TEST_ASSERT_EQUAL(count_body_overlays(host, source_overlay_icon), 0, "DS13 cure briefly restored TGMC appearance permanently.")
	test_screenshot("cured_native", get_flat_icon_for_all_directions(host))

/** Ordinary visual replacement keeps equipped clothing and Paradise's actual held claws. */
/datum/unit_test/paradise_zombie_tgmc_keeps_inventory
	parent_type = /datum/unit_test/paradise_zombie_appearance_test

/datum/unit_test/paradise_zombie_tgmc_keeps_inventory/Run()
	var/mob/living/carbon/human/host = make_zombie(run_loc_floor_bottom_left)
	var/obj/item/storage/backpack/backpack = allocate(/obj/item/storage/backpack)
	var/obj/item/clothing/glasses/sunglasses/glasses = allocate(/obj/item/clothing/glasses/sunglasses)
	TEST_ASSERT(host.equip_to_slot_if_possible(backpack, ITEM_SLOT_BACK, disable_warning = TRUE, bypass_equip_delay_self = TRUE), "The ordinary TGMC zombie could not equip its backpack.")
	TEST_ASSERT(host.equip_to_slot_if_possible(glasses, ITEM_SLOT_EYES, disable_warning = TRUE, bypass_equip_delay_self = TRUE), "The ordinary TGMC zombie could not equip its glasses.")
	var/datum/action/cooldown/paradise_zombie_claws/claws_action = locate() in host.actions
	TEST_ASSERT_NOTNULL(claws_action, "The ordinary TGMC zombie lost its Paradise claw action.")
	TEST_ASSERT(claws_action.Trigger(host), "The ordinary TGMC zombie could not wield its actual Paradise claws.")
	var/obj/item/paradise_zombie_claw/claws = host.get_active_held_item()
	TEST_ASSERT(istype(claws), "The actual claw item was not held after activation.")
	var/datum/component/paradise_zombie_appearance/appearance = host.GetComponent(/datum/component/paradise_zombie_appearance)
	appearance.redraw_body()
	TEST_ASSERT_EQUAL(host.back, backpack, "Ordinary body redraw removed equipped storage.")
	TEST_ASSERT_EQUAL(host.glasses, glasses, "Ordinary body redraw removed equipped eyewear.")
	TEST_ASSERT_EQUAL(host.get_active_held_item(), claws, "Ordinary body redraw replaced the real Paradise claw item.")
	TEST_ASSERT_EQUAL(length(host.get_held_items()), 2, "Ordinary body redraw broke the two-handed claw reservation.")
	test_screenshot("equipped_claws", get_flat_icon_for_all_directions(host))

/** Live TGMC and clothing overlays must use the same native height treatment after a height change. */
/datum/unit_test/paradise_zombie_tgmc_height
	parent_type = /datum/unit_test/paradise_zombie_appearance_test

/datum/unit_test/paradise_zombie_tgmc_height/Run()
	var/mob/living/carbon/human/host = make_zombie(run_loc_floor_bottom_left)
	var/obj/item/clothing/under/color/grey/uniform = allocate(/obj/item/clothing/under/color/grey)
	var/obj/item/clothing/glasses/sunglasses/glasses = allocate(/obj/item/clothing/glasses/sunglasses)
	TEST_ASSERT(host.equip_to_slot_if_possible(uniform, ITEM_SLOT_ICLOTHING, disable_warning = TRUE, bypass_equip_delay_self = TRUE), "The height fixture could not equip its uniform.")
	TEST_ASSERT(host.equip_to_slot_if_possible(glasses, ITEM_SLOT_EYES, disable_warning = TRUE, bypass_equip_delay_self = TRUE), "The height fixture could not equip its glasses.")
	var/datum/component/paradise_zombie_appearance/appearance = host.GetComponent(/datum/component/paradise_zombie_appearance)
	for(var/height in list(HUMAN_HEIGHT_SHORTEST, HUMAN_HEIGHT_TALLEST))
		host.set_mob_height(height)
		var/mutable_appearance/live_body
		var/mutable_appearance/live_uniform
		var/mutable_appearance/live_glasses
		for(var/mutable_appearance/overlay as anything in host.overlays)
			if(overlay.icon == appearance.body_appearance.icon)
				live_body = overlay
			else if(overlay.layer == -UNIFORM_LAYER)
				live_uniform = overlay
			else if(overlay.layer == -GLASSES_LAYER)
				live_glasses = overlay
		TEST_ASSERT_NOTNULL(live_body, "Changing height removed the live TGMC body overlay.")
		TEST_ASSERT_NOTNULL(live_uniform, "Changing height removed the equipped uniform's live overlay.")
		TEST_ASSERT_NOTNULL(live_glasses, "Changing height removed the equipped glasses' live overlay.")
		var/height_filter = height == HUMAN_HEIGHT_SHORTEST ? "Cut_Legs" : "Lenghten_Legs"
		TEST_ASSERT_NOTNULL(live_uniform.filters[height_filter], "The uniform fixture has no native height filter.")
		TEST_ASSERT_NOTEQUAL(live_glasses.pixel_z, 0, "The eyewear fixture has no native height offset.")
		TEST_ASSERT_NOTNULL(live_body.filters[height_filter], "The TGMC body ignores the height treatment applied to its clothing and eyewear.")
	// getFlatIcon does not render displacement filters; client rendering needs separate visual verification.

#endif
