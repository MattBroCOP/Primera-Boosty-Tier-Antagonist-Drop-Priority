#ifdef UNIT_TESTS

/** Exports actual world overlays on a full-size transparent canvas; the stock screenshot helper clips large bodies. */
/proc/paradise_zombie_mutation_screenshot(mob/living/carbon/human/host)
	var/mutable_appearance/export_appearance = new(host.appearance)
	export_appearance.dir = SOUTH
	var/datum/component/paradise_zombie_mutation_body/body = host.GetComponent(/datum/component/paradise_zombie_mutation_body)
	if(body)
		var/list/dimensions = get_icon_dimensions(body.body_icon)
		var/icon/canvas = icon('icons/blanks/32x32.dmi', "nothing")
		canvas.Scale(dimensions["width"], dimensions["height"])
		export_appearance.icon = canvas
		export_appearance.icon_state = "nothing"
	var/icon/output
	for(var/direction in GLOB.cardinals)
		var/icon/partial = getFlatIcon(export_appearance, defdir = direction, no_anim = TRUE)
		if(!output)
			output = icon(partial)
		output.Insert(partial, dir = direction)
	return output

/** Every mutation draws real DS13 limb states in all directions, rather than its interface preview. */
/datum/unit_test/paradise_zombie_mutation_body_forms/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/component/paradise_zombie_mutation_body/body = patient.AddComponent(/datum/component/paradise_zombie_mutation_body, "slasher")
	for(var/form_id in list("slasher", "twitcher", "hunter", "brute", "spitter", "exploder"))
		TEST_ASSERT(body.set_form(form_id), "The rendering component rejected [form_id].")
		var/expected_parts = form_id == "exploder" ? 4 : 6
		var/rendered_parts = 0
		for(var/mutable_appearance/part as anything in patient.overlays)
			if(part.icon != body.body_icon)
				continue
			rendered_parts++
			TEST_ASSERT_NOTEQUAL(part.icon_state, "preview", "The live [form_id] body was replaced by a UI preview.")
		TEST_ASSERT_EQUAL(rendered_parts, expected_parts, "The live [form_id] body has missing or duplicated DS13 limb overlays.")
		TEST_ASSERT_EQUAL(patient.pixel_x, form_id == "brute" ? -16 : -8, "The live [form_id] body lost its source anchor.")
		var/icon/screenshot = paradise_zombie_mutation_screenshot(patient)
		var/list/dimensions = get_icon_dimensions(body.body_icon)
		TEST_ASSERT_EQUAL(screenshot.Width(), dimensions["width"], "The native [form_id] screenshot cropped the source body's width.")
		TEST_ASSERT_EQUAL(screenshot.Height(), dimensions["height"], "The native [form_id] screenshot cropped the source body's height.")
		test_screenshot(form_id, screenshot)
	qdel(body)

/** Appearance cleanup preserves a nonhuman's DNA, missing anatomy, surgical opening and transplanted tissue. */
/datum/unit_test/paradise_zombie_mutation_body_anatomy/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	patient.set_species(/datum/species/lizard)
	var/mob/living/carbon/human/donor = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent)
	var/datum/dna/original_dna = patient.dna
	var/datum/species/original_species = patient.dna.species
	var/original_identity = patient.dna.unique_identity
	var/list/original_features = patient.dna.features.Copy()
	var/list/original_organs = patient.organs.Copy()
	var/obj/item/organ/paradise_zombie_tumor/tumor = allocate(/obj/item/organ/paradise_zombie_tumor)
	tumor.Insert(patient)
	var/obj/item/bodypart/head/head = patient.get_bodypart(BODY_ZONE_HEAD)
	head.add_surgical_state(SURGERY_SKIN_OPEN | SURGERY_BONE_SAWED)
	var/original_surgery = head.surgery_state
	var/obj/item/bodypart/leg = patient.get_bodypart(BODY_ZONE_L_LEG)
	allocated |= leg
	leg.drop_limb(special = TRUE)
	var/old_pixel_x = patient.pixel_x
	var/old_pixel_y = patient.pixel_y
	var/old_base_pixel_x = patient.base_pixel_x
	var/old_base_pixel_y = patient.base_pixel_y
	var/old_flags = patient.appearance_flags
	var/datum/component/paradise_zombie_mutation_body/body = patient.AddComponent(/datum/component/paradise_zombie_mutation_body, "slasher")
	TEST_ASSERT_EQUAL(length(body.body_appearances), 5, "Mutation drew a leg that was already missing.")
	var/obj/item/bodypart/transplanted_arm = donor.get_bodypart(BODY_ZONE_L_ARM)
	allocated |= transplanted_arm
	allocated |= patient.get_bodypart(BODY_ZONE_L_ARM)
	var/transplant_skin_tone = transplanted_arm.skin_tone
	var/transplant_species_color = transplanted_arm.species_color
	var/transplant_limb_id = transplanted_arm.limb_id
	transplanted_arm.drop_limb(special = TRUE)
	TEST_ASSERT(transplanted_arm.replace_limb(patient), "A donor arm could not be transplanted into the mutated body.")
	transplanted_arm.receive_damage(brute = 9, burn = 3, forced = TRUE, wound_bonus = CANT_WOUND)
	var/transplant_brute = transplanted_arm.brute_dam
	var/transplant_burn = transplanted_arm.burn_dam
	body.set_form("hunter")
	TEST_ASSERT_EQUAL(patient.get_bodypart(BODY_ZONE_L_ARM), transplanted_arm, "Changing mutation replaced the actual transplanted arm.")
	TEST_ASSERT_EQUAL(length(body.body_appearances), 5, "Changing form regenerated a missing bodypart.")
	test_screenshot("hunter_missing_leg", paradise_zombie_mutation_screenshot(patient))
	qdel(body)
	TEST_ASSERT_EQUAL(patient.dna, original_dna, "Clearing a mutation replaced the original DNA datum.")
	TEST_ASSERT_EQUAL(patient.dna.species, original_species, "Clearing a mutation replaced the original species datum.")
	TEST_ASSERT_EQUAL(patient.dna.unique_identity, original_identity, "Mutation changed the body's genetic identity.")
	for(var/feature in original_features)
		TEST_ASSERT_EQUAL(patient.dna.features[feature], original_features[feature], "Mutation changed the DNA feature [feature].")
	for(var/obj/item/organ/organ as anything in original_organs)
		TEST_ASSERT(organ in patient.organs, "Mutation replaced or removed the original [organ.slot] organ.")
	TEST_ASSERT_EQUAL(patient.get_organ_slot(ORGAN_SLOT_ZOMBIE), tumor, "Visual cleanup replaced or removed the existing tumor.")
	TEST_ASSERT_EQUAL(head.surgery_state, original_surgery, "Visual cleanup changed the head's open surgical state.")
	TEST_ASSERT_NULL(patient.get_bodypart(BODY_ZONE_L_LEG), "Visual cleanup regrew a pre-existing missing leg.")
	TEST_ASSERT_EQUAL(patient.get_bodypart(BODY_ZONE_L_ARM), transplanted_arm, "Visual cleanup replaced the transplanted arm.")
	TEST_ASSERT_EQUAL(transplanted_arm.skin_tone, transplant_skin_tone, "Visual cleanup recolored donor skin from recipient DNA.")
	TEST_ASSERT_EQUAL(transplanted_arm.species_color, transplant_species_color, "Visual cleanup changed the transplant's species color.")
	TEST_ASSERT_EQUAL(transplanted_arm.limb_id, transplant_limb_id, "Visual cleanup changed the transplant's biological limb identity.")
	TEST_ASSERT_EQUAL(transplanted_arm.brute_dam, transplant_brute, "Visual cleanup healed or damaged the donor arm.")
	TEST_ASSERT_EQUAL(transplanted_arm.burn_dam, transplant_burn, "Visual cleanup healed or burned the donor arm.")
	TEST_ASSERT_EQUAL(patient.pixel_x, old_pixel_x, "Visual cleanup retained the mutation's horizontal offset.")
	TEST_ASSERT_EQUAL(patient.pixel_y, old_pixel_y, "Visual cleanup retained the mutation's vertical offset.")
	TEST_ASSERT_EQUAL(patient.base_pixel_x, old_base_pixel_x, "Visual cleanup retained the mutation's resting horizontal offset.")
	TEST_ASSERT_EQUAL(patient.base_pixel_y, old_base_pixel_y, "Visual cleanup retained the mutation's resting vertical offset.")
	TEST_ASSERT_EQUAL(patient.appearance_flags, old_flags, "Visual cleanup retained mutation-only appearance flags.")
	test_screenshot("restored_lizard_transplant", paradise_zombie_mutation_screenshot(patient))
	var/datum/component/paradise_zombie_mutation_body/second_body = patient.AddComponent(/datum/component/paradise_zombie_mutation_body, "brute")
	allocated |= recipient.get_bodypart(BODY_ZONE_L_ARM)
	transplanted_arm.drop_limb(special = TRUE)
	TEST_ASSERT_EQUAL(length(second_body.body_appearances), 4, "Removing an arm left its mutated body image behind.")
	TEST_ASSERT(transplanted_arm.replace_limb(recipient), "An arm removed during mutation could not be transplanted into another body.")
	qdel(second_body)
	TEST_ASSERT_EQUAL(transplanted_arm.owner, recipient, "Clearing the old body's mutation took back its former transplant.")
	TEST_ASSERT_EQUAL(transplanted_arm.skin_tone, transplant_skin_tone, "Clearing the old body's mutation recolored tissue now in a different body.")

/** Curing a dead mutant must retain current native posture offsets rather than its old standing pixels. */
/datum/unit_test/paradise_zombie_mutation_body_posture
	parent_type = /datum/unit_test/paradise_zombie_mutation_test

/datum/unit_test/paradise_zombie_mutation_body_posture/Run()
	var/mob/living/carbon/human/host = make_mutant("hunter")
	var/datum/component/paradise_zombie_mutation_body/body = host.GetComponent(/datum/component/paradise_zombie_mutation_body)
	var/original_base_x = body.old_base_pixel_x
	var/original_base_y = body.old_base_pixel_y
	host.death()
	// Settle the native falling animation without making this cleanup test depend on wall-clock interpolation.
	host.update_offsets()
	TEST_ASSERT_EQUAL(host.body_position, LYING_DOWN, "The normal death path did not put the mutant on the floor.")
	TEST_ASSERT_NOTEQUAL(host.has_offset(LYING_DOWN_TRAIT, PIXEL_Y_OFFSET), 0, "The dead mutant has no native lying offset.")
	var/obj/item/organ/paradise_zombie_tumor/tumor = host.get_organ_slot(ORGAN_SLOT_ZOMBIE)
	TEST_ASSERT_NOTNULL(tumor, "The mutant fixture has no tumor for the actual surgical cure.")
	tumor.Remove(host)
	TEST_ASSERT_NULL(host.GetComponent(/datum/component/paradise_zombie_mutation_body), "Tumor extraction retained the mutation renderer.")
	TEST_ASSERT_EQUAL(host.body_position, LYING_DOWN, "Visual cleanup changed the dead body's native posture.")
	TEST_ASSERT_EQUAL(host.pixel_x, original_base_x + host.has_offset(null, PIXEL_X_OFFSET), "Visual cleanup restored stale standing X pixels instead of current native offsets.")
	TEST_ASSERT_EQUAL(host.pixel_y, original_base_y + host.has_offset(null, PIXEL_Y_OFFSET), "Visual cleanup restored stale standing Y pixels instead of the corpse's native lying offset.")
	TEST_ASSERT(host.revive(ADMIN_HEAL_ALL), "The cured posture fixture could not be revived for its standing check.")
	host.get_up(TRUE)
	host.update_offsets()
	TEST_ASSERT_EQUAL(host.body_position, STANDING_UP, "The cured body could not stand after recovery.")
	TEST_ASSERT_EQUAL(host.pixel_x, original_base_x, "Standing after recovery retained the mutation's horizontal anchor.")
	TEST_ASSERT_EQUAL(host.pixel_y, original_base_y, "Standing after recovery retained a stale lying or mutation offset.")

#endif
