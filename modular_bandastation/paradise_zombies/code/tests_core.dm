/** Repeated resurrection survives ordinary death, while Omega really blocks and is consumed in a corpse. */
/datum/unit_test/paradise_zombie_repeated_resurrection/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	patient.mind_initialize()
	var/datum/disease/paradise_zombie/infection = new()
	infection.infect(patient, FALSE)
	infection.stage = 8
	infection.process_infection_cycle()
	var/datum/component/paradise_zombie_regen/regeneration = patient.GetComponent(/datum/component/paradise_zombie_regen)
	TEST_ASSERT_NOTNULL(regeneration, "Transformation omitted the resurrection component.")
	var/obj/item/bodypart/head = patient.get_bodypart(BODY_ZONE_HEAD)
	head.force_wound_upwards(/datum/wound/cranial_fissure)
	TEST_ASSERT_NOTNULL(locate(/datum/wound/cranial_fissure) in head.wounds, "The resurrection fixture did not acquire a real cranial fissure.")
	TEST_ASSERT(LIMB_HAS_SURGERY_STATE(head, SURGERY_SKIN_OPEN|SURGERY_BONE_SAWED), "The real cranial fissure did not open the skull before death.")
	patient.dna.add_mutation(/datum/mutation/mute, MUTATION_SOURCE_MUTATOR)
	patient.dna.add_mutation(/datum/mutation/deaf, MUTATION_SOURCE_MUTATOR)
	patient.dna.add_mutation(/datum/mutation/unintelligible, MUTATION_SOURCE_MUTATOR)
	patient.gain_trauma(/datum/brain_trauma/severe/paralysis/paraplegic, TRAUMA_RESILIENCE_ABSOLUTE)
	TEST_ASSERT(HAS_TRAIT(patient, TRAIT_MUTE) && HAS_TRAIT(patient, TRAIT_DEAF), "The resurrection fixture did not acquire its genetic speech and hearing disabilities.")
	patient.death()
	patient.timeofdeath = world.time - 15 SECONDS
	regeneration.process(1)
	TEST_ASSERT_NOTEQUAL(patient.stat, DEAD, "An undamaged infected corpse did not rise after the original delay.")
	TEST_ASSERT_EQUAL(patient.GetComponent(/datum/component/paradise_zombie_regen), regeneration, "Ordinary death removed the body's ability to rise again.")
	TEST_ASSERT_NULL(locate(/datum/wound/cranial_fissure) in head.wounds, "Resurrection left the actual cranial injury instead of healing its wound effects.")
	TEST_ASSERT(LIMB_HAS_SURGERY_STATE(head, SURGERY_SKIN_OPEN|SURGERY_BONE_SAWED), "Healing the cranial injury closed the infected corpse's exposed skull.")
	TEST_ASSERT(!patient.dna.check_mutation(/datum/mutation/mute) && !patient.dna.check_mutation(/datum/mutation/deaf), "Resurrection left mute or deaf genes able to reapply their disabilities.")
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_MUTE) && !HAS_TRAIT(patient, TRAIT_DEAF), "Resurrection left the body's genetic speech or hearing disability active.")
	TEST_ASSERT_NULL(patient.has_trauma_type(/datum/brain_trauma/severe/paralysis/paraplegic, TRAUMA_RESILIENCE_ABSOLUTE), "Resurrection left the native equivalent of the donor's paraplegia disability active.")
	TEST_ASSERT_NOTNULL(patient.dna.check_mutation(/datum/mutation/unintelligible), "Resurrection removed an unrelated negative mutation.")
	patient.dna.add_mutation(/datum/mutation/mute, MUTATION_SOURCE_MUTATOR)
	patient.dna.add_mutation(/datum/mutation/deaf, MUTATION_SOURCE_MUTATOR)
	patient.death()
	patient.timeofdeath = world.time - 15 SECONDS
	patient.reagents.add_reagent(/datum/reagent/medicine/paradise_zombie_cure/omega, 5)
	var/omega_before = patient.reagents.get_reagent_amount(/datum/reagent/medicine/paradise_zombie_cure/omega)
	regeneration.process(1)
	TEST_ASSERT_EQUAL(patient.stat, DEAD, "Omega failed to suppress a second resurrection.")
	var/omega_consumed = omega_before - patient.reagents.get_reagent_amount(/datum/reagent/medicine/paradise_zombie_cure/omega)
	TEST_ASSERT(abs(omega_consumed - 0.1 * patient.metabolism_efficiency) < 0.0001, "The corpse did not consume the original 0.1 units of Omega per second while preventing resurrection.")
	patient.reagents.remove_reagent(/datum/reagent/medicine/paradise_zombie_cure/omega, 5)
	patient.apply_status_effect(/datum/status_effect/grouped/stasis, STASIS_MACHINE_EFFECT)
	TEST_ASSERT(HAS_TRAIT(patient, TRAIT_STASIS), "The resurrection fixture did not enter stasis.")
	regeneration.process(1)
	TEST_ASSERT_EQUAL(patient.stat, DEAD, "The corpse rose while in stasis.")
	patient.remove_status_effect(/datum/status_effect/grouped/stasis, STASIS_MACHINE_EFFECT)
	regeneration.process(1)
	TEST_ASSERT_NOTEQUAL(patient.stat, DEAD, "The same zombie could not rise again after Omega was removed.")
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_MUTE) && !HAS_TRAIT(patient, TRAIT_DEAF), "A repeated resurrection failed to cure newly acquired speech and hearing mutations.")

/** Native space exposure cannot keep an injured zombie corpse from healing enough to rise. */
/datum/unit_test/paradise_zombie_space_resurrection
	var/turf/space_tile
	var/original_turf_type

/datum/unit_test/paradise_zombie_space_resurrection/Destroy()
	QDEL_LIST(allocated)
	space_tile?.ChangeTurf(original_turf_type, flags = CHANGETURF_IGNORE_AIR)
	space_tile = null
	return ..()

/datum/unit_test/paradise_zombie_space_resurrection/Run()
	var/turf/floor = get_step(run_loc_floor_bottom_left, NORTHEAST)
	original_turf_type = floor.type
	space_tile = floor.ChangeTurf(/turf/open/space, flags = CHANGETURF_IGNORE_AIR)
	var/datum/gas_mixture/space_air = space_tile.return_air()
	TEST_ASSERT(space_air && space_air.return_pressure() < HAZARD_LOW_PRESSURE, "The fixture did not get a native vacuum turf.")
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent, space_tile)
	var/datum/disease/paradise_zombie/infection = new()
	infection.infect(patient, FALSE)
	infection.stage = 8
	infection.process_infection_cycle()
	var/datum/component/paradise_zombie_regen/regeneration = patient.GetComponent(/datum/component/paradise_zombie_regen)
	TEST_ASSERT_NOTNULL(regeneration, "The fixture did not acquire zombie regeneration.")
	patient.adjust_brute_loss(40)
	patient.death()
	patient.timeofdeath = world.time - 15 SECONDS
	patient.seconds_in_low_pressure = 160 SECONDS
	patient.bodytemperature = TCMB
	patient.set_coretemperature(TCMB)
	var/brute_before = patient.get_brute_loss_for_type(BODYTYPE_ORGANIC)
	patient.Life(SSMOBS_DT)
	TEST_ASSERT_EQUAL(patient.get_brute_loss_for_type(BODYTYPE_ORGANIC), brute_before, "Vacuum pressure damaged a regenerating zombie corpse.")
	TEST_ASSERT_EQUAL(patient.get_fire_loss_for_type(BODYTYPE_ORGANIC), 0, "Vacuum cold damaged a regenerating zombie corpse.")
	regeneration.process(SSMOBS_DT)
	TEST_ASSERT_EQUAL(patient.stat, DEAD, "Vacuum resurrection bypassed the normal injury limit.")
	for(var/tick in 1 to 10)
		patient.Life(SSMOBS_DT)
		regeneration.process(SSMOBS_DT)
		if(patient.stat != DEAD)
			break
	TEST_ASSERT_NOTEQUAL(patient.stat, DEAD, "The zombie did not resurrect while still exposed to vacuum.")
	patient.bodytemperature = TCMB
	patient.set_coretemperature(TCMB)
	patient.Life(SSMOBS_DT)
	TEST_ASSERT(patient.get_brute_loss_for_type(BODYTYPE_ORGANIC) > 0, "The revived zombie became immune to vacuum pressure.")
	TEST_ASSERT(patient.get_fire_loss_for_type(BODYTYPE_ORGANIC) > 0, "The revived zombie became immune to vacuum cold.")

/** Transformation suppresses real bleeding and restores blood until the infection is cured. */
/datum/unit_test/paradise_zombie_blood_recovery/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	patient.set_nutrition(0)
	var/obj/item/bodypart/chest = patient.get_bodypart(BODY_ZONE_CHEST)
	var/datum/wound/slash/flesh/wound = chest.force_wound_upwards(/datum/wound/slash/flesh/moderate)
	TEST_ASSERT(wound in chest.wounds, "The fixture could not receive a real bleeding wound.")
	TEST_ASSERT(patient.is_bleeding(), "The fixture has no active bleeding before transformation.")
	var/datum/disease/paradise_zombie/infection = new
	TEST_ASSERT(patient.ForceContractDisease(infection, make_copy = FALSE, del_on_fail = TRUE), "The bleeding fixture could not contract the plague.")
	infection.stage = 8
	infection.process_infection_cycle()
	TEST_ASSERT(HAS_TRAIT(patient, TRAIT_PARADISE_ZOMBIE), "The bleeding fixture did not transform.")
	TEST_ASSERT(!patient.is_bleeding(), "Transformation left the patient's wound bleeding.")
	patient.set_blood_volume(BLOOD_VOLUME_SURVIVE - 1)
	var/blood_before = patient.get_blood_volume()
	patient.bleed(10)
	patient.handle_blood(1)
	TEST_ASSERT_EQUAL(patient.get_blood_volume(), blood_before, "A zombie continued losing blood from an existing wound or direct bleeding.")
	TEST_ASSERT_NOTEQUAL(patient.stat, DEAD, "Low blood volume killed the zombie before it could regenerate.")

	var/datum/component/paradise_zombie_regen/regeneration = patient.GetComponent(/datum/component/paradise_zombie_regen)
	TEST_ASSERT_NOTNULL(regeneration, "The transformed body did not acquire its regeneration component.")
	regeneration.process(1)
	TEST_ASSERT(patient.get_blood_volume() > blood_before, "Zombie regeneration did not restore lost blood.")
	patient.set_blood_volume(patient.default_blood_volume - 0.1)
	regeneration.process(1)
	TEST_ASSERT_EQUAL(patient.get_blood_volume(), patient.default_blood_volume, "Zombie regeneration failed to cap blood at the body's normal volume.")
	var/obj/item/reagent_containers/cup/beaker/sample = allocate(/obj/item/reagent_containers/cup/beaker)
	TEST_ASSERT_EQUAL(patient.transfer_blood_to(sample, 1), 1, "A nonbleeding zombie could not provide a laboratory sample.")
	var/datum/reagent/blood/blood = sample.reagents.has_reagent(/datum/reagent/blood)
	TEST_ASSERT(locate(/datum/disease/paradise_zombie) in blood?.data?["viruses"], "The laboratory sample did not carry the zombie plague.")

	infection.cure()
	TEST_ASSERT(wound in chest.wounds, "Transformation or cure removed the underlying wound.")
	TEST_ASSERT(patient.is_bleeding(), "Curing the infection did not restore bleeding from the existing wound.")
	blood_before = patient.get_blood_volume()
	patient.handle_blood(1)
	TEST_ASSERT(patient.get_blood_volume() < blood_before, "Curing the infection left the patient immune to blood loss.")

/** A remembered research sequence cannot cure a transformed body after the actual Omega dose is removed. */
/datum/unit_test/paradise_zombie_current_omega_required/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/disease/paradise_zombie/infection = new()
	infection.infect(patient, FALSE)
	infection.stage = 8
	infection.process_infection_cycle()
	infection.cure_stage = 4
	infection.cure_chance = 100
	infection.process_infection_cycle()
	TEST_ASSERT_EQUAL(infection.stage, 7, "A transformed body regressed without any current Omega, using only its remembered research level.")
	patient.reagents.add_reagent(/datum/reagent/medicine/paradise_zombie_cure/omega, 1)
	for(var/cycle in 1 to 7)
		if(QDELETED(infection))
			break
		infection.process_infection_cycle()
	TEST_ASSERT_NULL(locate(/datum/disease/paradise_zombie) in patient.diseases, "Current Omega failed to carry the transformed infection through all seven stages to its cure.")
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_PARADISE_ZOMBIE), "Completing the current Omega sequence left the body transformed.")

/** A physical infected limb follows its recipient, while tumor extraction cleans only the cured body. */
/datum/unit_test/paradise_zombie_limb_and_tumor_lifecycle/Run()
	var/mob/living/carbon/human/donor = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent)
	donor.mind_initialize()
	var/datum/disease/paradise_zombie/infection = new()
	infection.infect(donor, FALSE)
	infection.handle_rot()
	var/obj/item/bodypart/infected_limb
	var/datum/component/paradise_zombie_limb/necrosis
	for(var/obj/item/bodypart/limb as anything in donor.get_bodyparts())
		necrosis = limb.GetComponent(/datum/component/paradise_zombie_limb)
		if(necrosis)
			infected_limb = limb
			break
	TEST_ASSERT_NOTNULL(infected_limb, "Early plague necrosis did not affect any limb.")
	TEST_ASSERT(infected_limb.bodypart_disabled, "A necrotic limb was usable before the host transformed.")
	allocated |= infected_limb
	allocated |= recipient.get_bodypart(infected_limb.body_zone)
	infected_limb.drop_limb(special = TRUE)
	TEST_ASSERT_NULL(infected_limb.owner, "Extracted infected tissue retained its old owner.")
	TEST_ASSERT(infected_limb.replace_limb(recipient), "An infected limb could not be transplanted through the normal bodypart API.")
	TEST_ASSERT(infected_limb.bodypart_disabled, "Necrotic tissue became usable after transplantation into an uninfected body.")
	var/obj/item/bodypart/replacement = allocate(infected_limb.type)
	TEST_ASSERT(replacement.try_attach_limb(donor, special = TRUE), "The donor's missing limb could not be restored before completing transformation.")
	infection.stage = 8
	infection.process_infection_cycle()
	TEST_ASSERT(HAS_TRAIT(donor, TRAIT_BRAINLESS_CARBON), "A transformed body did not acquire brain-independent survival.")
	var/obj/item/paradise_zombie_claw/claw = allocate(/obj/item/paradise_zombie_claw)
	TEST_ASSERT(donor.put_in_hands(claw), "The transformed body could not hold its abstract claws.")
	var/obj/item/organ/paradise_zombie_tumor/tumor = donor.get_organ_slot(ORGAN_SLOT_ZOMBIE)
	TEST_ASSERT_NOTNULL(tumor, "Transformation did not grow the surgical cure target.")
	tumor.Remove(donor)
	TEST_ASSERT(QDELETED(claw), "Surgical cure left an independently created claw in the cured body's hand.")
	TEST_ASSERT_NULL(donor.GetComponent(/datum/component/paradise_zombie_combat), "Surgical cure left zombie combat hooks attached.")
	TEST_ASSERT_NULL(donor.GetComponent(/datum/component/paradise_zombie_regen), "Surgical cure left resurrection active.")
	TEST_ASSERT(!HAS_TRAIT(donor, TRAIT_BRAINLESS_CARBON), "Surgical cure left the body's brain requirement disabled.")
	TEST_ASSERT(!QDELETED(necrosis) && necrosis.necrotic, "Curing the donor unexpectedly repaired tissue now belonging to another body.")
	qdel(necrosis)
	TEST_ASSERT(!HAS_TRAIT(infected_limb, TRAIT_PARADISE_ZOMBIE_LIMB) && !infected_limb.bodypart_disabled, "Removing the transplanted tissue's necrosis left its marker or paralysis behind.")

/** Noninfectious necrosis is not infected tissue until the plague actually reaches and marks the same limb. */
/datum/unit_test/paradise_zombie_noninfectious_necrosis/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/limb = patient.get_bodypart(BODY_ZONE_L_ARM)
	var/datum/component/paradise_zombie_limb/necrosis = limb.AddComponent(/datum/component/paradise_zombie_limb, FALSE)
	TEST_ASSERT(necrosis.necrotic && limb.bodypart_disabled, "Noninfectious necrosis did not disable the dead organic tissue.")
	TEST_ASSERT(!necrosis.infected && !HAS_TRAIT(limb, TRAIT_PARADISE_ZOMBIE_LIMB), "Ordinary corpse necrosis marked the limb as plague-infected.")
	necrosis.heal_necrosis()
	TEST_ASSERT(!limb.bodypart_disabled && !HAS_TRAIT(limb, TRAIT_PARADISE_ZOMBIE_LIMB), "Restoring ordinary dead tissue introduced an infection marker or left paralysis behind.")
	var/datum/disease/paradise_zombie/infection = new()
	infection.infect(patient, FALSE)
	for(var/cycle in 1 to 4)
		if(necrosis.infected)
			break
		infection.handle_rot()
	TEST_ASSERT_EQUAL(limb.GetComponent(/datum/component/paradise_zombie_limb), necrosis, "Infecting existing corpse necrosis replaced its physical tissue component.")
	TEST_ASSERT(necrosis.infected && necrosis.necrotic && HAS_TRAIT(limb, TRAIT_PARADISE_ZOMBIE_LIMB), "The plague did not promote the existing necrotic limb to infected tissue.")
	necrosis.heal_necrosis()
	TEST_ASSERT(HAS_TRAIT(limb, TRAIT_PARADISE_ZOMBIE_LIMB), "Healing dead tissue erased the plague marker after actual infection.")
	infection.stage = 8
	infection.process_infection_cycle()
	TEST_ASSERT_EQUAL(limb.GetComponent(/datum/component/paradise_zombie_limb), necrosis, "Immediate transformation replaced the already-marked tissue component.")
	TEST_ASSERT(!necrosis.necrotic && HAS_TRAIT(limb, TRAIT_PARADISE_ZOMBIE_LIMB), "Immediate transformation failed to heal necrosis while keeping the limb's infection marker.")

/** Historical map paths create real carbon zombies and retain their outfits without a basic-mob AI backend. */
/datum/unit_test/paradise_zombie_mapped_corpses/Run()
	for(var/spawn_type in list(/mob/living/basic/zombie, /mob/living/basic/zombie/rotten, /mob/living/basic/zombie/rotten/assistant))
		var/mob/living/carbon/human/zombie = allocate(spawn_type)
		TEST_ASSERT(ishuman(zombie) && !istype(zombie, /mob/living/basic), "The historical map type [spawn_type] still uses a basic-mob zombie body.")
		TEST_ASSERT(HAS_TRAIT(zombie, TRAIT_PARADISE_ZOMBIE) && HAS_TRAIT(zombie, TRAIT_PARADISE_NPC_ZOMBIE), "The historical map type [spawn_type] did not activate the common plague and NPC fallback.")
		TEST_ASSERT(HAS_TRAIT(zombie, TRAIT_PARADISE_NON_INFECTIOUS_ZOMBIE), "A space-ruin corpse lost its noninfectious spawn contract.")
		TEST_ASSERT_NOTNULL(zombie.GetComponent(/datum/component/paradise_zombie_combat), "A mapped corpse has no common zombie combat component.")
		TEST_ASSERT_NOTNULL(zombie.GetComponent(/datum/component/paradise_zombie_regen), "A mapped corpse has no common resurrection component.")
		if(spawn_type == /mob/living/basic/zombie/rotten/assistant)
			TEST_ASSERT(istype(zombie.w_uniform, /obj/item/clothing/under/color/grey), "The mapped assistant's real body did not receive its outfit.")
		else
			TEST_ASSERT(istype(zombie.w_uniform, /obj/item/clothing/under/rank/medical/doctor), "The mapped doctor's real body did not receive its outfit.")

/** A headless infected body must not attempt to implant an organ into a missing bodypart. */
/datum/unit_test/paradise_zombie_headless_transformation/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/head/head = patient.get_bodypart(BODY_ZONE_HEAD)
	allocated |= head
	head.drop_limb(special = TRUE)
	var/datum/disease/paradise_zombie/infection = new()
	infection.infect(patient, FALSE)
	infection.stage = 8
	infection.process_infection_cycle()
	TEST_ASSERT(HAS_TRAIT(patient, TRAIT_PARADISE_ZOMBIE), "A missing head prevented the remaining body from transforming.")
	TEST_ASSERT_NULL(patient.get_organ_slot(ORGAN_SLOT_ZOMBIE), "Transformation installed a head tumor without a head to contain it.")
	TEST_ASSERT(head.try_attach_limb(patient, special = TRUE), "The original head could not be reattached to the infected body.")
	infection.stage = 8
	infection.process_infection_cycle()
	TEST_ASSERT_NOTNULL(patient.get_organ_slot(ORGAN_SLOT_ZOMBIE), "The infection did not grow its surgical cure target after a head was restored.")

/** A bite-advanced infection is discovered without waiting a minute, and treatment does not hide a discovered strain. */
/datum/unit_test/paradise_zombie_medical_discovery/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/disease/paradise_zombie/infection = new()
	infection.infect(patient, FALSE)
	TEST_ASSERT_NULL(patient.check_virus(), "The early incubating plague appeared on the medical HUD.")
	infection.stage = 4
	infection.cure_stage = 3
	infection.cure_chance = 100
	infection.process_infection_cycle()
	TEST_ASSERT_EQUAL(infection.stage, 3, "The treated stage-four strain did not regress during its normal disease cycle.")
	TEST_ASSERT(infection.discovered, "A directly advanced stage-four strain remained undiscovered while its minute timer was running.")
	TEST_ASSERT_EQUAL(patient.check_virus(), DISEASE_SEVERITY_BIOHAZARD, "Regressing a discovered strain hid it from the medical HUD.")

/** An abandoned one-armed body attacks without attempting to equip a two-handed item. */
/datum/unit_test/paradise_zombie_one_armed_fallback/Run()
	var/mob/living/carbon/human/zombie = allocate(/mob/living/basic/zombie)
	allocate(/mob/living/carbon/human/consistent, get_step(zombie, EAST))
	var/obj/item/bodypart/arm = zombie.get_bodypart(BODY_ZONE_L_ARM)
	allocated |= arm
	arm.drop_limb(special = TRUE)
	var/datum/component/paradise_zombie_regen/regeneration = zombie.GetComponent(/datum/component/paradise_zombie_regen)
	regeneration.mindless_hunger()
	TEST_ASSERT(!zombie.is_holding_item_of_type(/obj/item/paradise_zombie_claw), "A one-armed body attempted to retain two-handed claws.")
	TEST_ASSERT(zombie.has_active_hand(), "NPC fallback failed to select the surviving arm.")

/** Curing an early plague must not repair unrelated noninfectious necrosis. */
/datum/unit_test/paradise_zombie_cure_preserves_unrelated_necrosis/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/arm = patient.get_bodypart(BODY_ZONE_L_ARM)
	var/datum/component/paradise_zombie_limb/necrosis = arm.AddComponent(/datum/component/paradise_zombie_limb, FALSE)
	necrosis.necrotize()
	TEST_ASSERT(necrosis && necrosis.necrotic && !necrosis.infected && arm.bodypart_disabled, "The fixture did not acquire independent, noninfectious necrosis.")
	var/datum/disease/paradise_zombie/infection = new()
	infection.infect(patient, FALSE)
	infection.cure()
	TEST_ASSERT_EQUAL(arm.GetComponent(/datum/component/paradise_zombie_limb), necrosis, "Curing a stage-one infection deleted an unrelated necrosis component.")
	TEST_ASSERT(necrosis.necrotic && !necrosis.infected && arm.bodypart_disabled, "Curing an early plague repaired tissue the infection never reached.")
	allocated |= arm
	arm.drop_limb(special = TRUE)
	infection = new()
	infection.infect(patient, FALSE)
	infection.stage = 8
	infection.process_infection_cycle()
	TEST_ASSERT(arm.try_attach_limb(patient, special = TRUE), "The independent necrotic arm could not be restored before surgical cure.")
	var/obj/item/organ/paradise_zombie_tumor/tumor = patient.get_organ_slot(ORGAN_SLOT_ZOMBIE)
	TEST_ASSERT_NOTNULL(tumor, "The transformed fixture had no tumor to remove.")
	tumor.Remove(patient)
	TEST_ASSERT_EQUAL(arm.GetComponent(/datum/component/paradise_zombie_limb), necrosis, "Tumor extraction deleted unrelated transplanted necrosis.")
	TEST_ASSERT(necrosis.necrotic && arm.bodypart_disabled, "Tumor extraction healed unrelated transplanted necrosis.")

#ifdef UNIT_TESTS

/** Cursed still scatters an ordinary corpse, but never removes a mature zombie's physical limbs. */
/datum/unit_test/paradise_zombie_cursed_death
	parent_type = /datum/unit_test/paradise_zombie_mutation_test

/datum/unit_test/paradise_zombie_cursed_death/Run()
	for(var/scenario in list("zombie", "human", "cured"))
		var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
		patient.mind_initialize()
		TEST_ASSERT(patient.add_quirk(/datum/quirk/cursed), "The [scenario] fixture could not acquire the real Cursed quirk.")
		var/datum/quirk/original_curse = patient.get_quirk(/datum/quirk/cursed)
		if(scenario != "human")
			var/datum/disease/paradise_zombie/infection = new()
			infection.infect(patient, FALSE)
			TEST_ASSERT_EQUAL(patient.get_quirk(/datum/quirk/cursed), original_curse, "Early infection removed a quirk before transformation.")
			infection.stage = 8
			infection.process_infection_cycle()
			TEST_ASSERT(!length(patient.quirks) && !HAS_TRAIT(patient, TRAIT_CURSED), "Transformation left active quirks or their traits on the zombie.")
			TEST_ASSERT_NULL(patient.GetComponent(/datum/component/omen), "Transformation left Cursed's accident and death hooks on the zombie.")
			infection.process_infection_cycle()
			if(scenario == "cured")
				infection.cure()
				TEST_ASSERT_EQUAL(patient.get_quirk(/datum/quirk/cursed), original_curse, "Curing the plague did not restore the original quirk.")
		var/list/original_limbs = patient.get_bodyparts()
		original_limbs = original_limbs.Copy()
		patient.death()
		TEST_ASSERT_EQUAL(patient.stat, DEAD, "The [scenario] fixture did not enter actual death.")
		if(scenario == "zombie")
			TEST_ASSERT_EQUAL(length(patient.get_bodyparts()), length(original_limbs), "Cursed scattered a mature zombie's limbs on death.")
			for(var/obj/item/bodypart/limb as anything in original_limbs)
				TEST_ASSERT_EQUAL(limb.owner, patient, "Cursed detached an original zombie limb without changing the bodypart count.")
		else
			TEST_ASSERT(length(patient.get_bodyparts()) < length(original_limbs), "The [scenario] control retained zombie-only protection from Cursed limb scattering.")

/** A pending quirk effect cannot return while the body is a zombie. */
/datum/unit_test/paradise_zombie_spacer_quirk/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	TEST_ASSERT(patient.add_quirk(/datum/quirk/spacer_born, add_unique = FALSE), "The fixture could not acquire Spacer.")
	var/datum/quirk/spacer_born/spacer = patient.get_quirk(/datum/quirk/spacer_born)
	spacer.in_space(patient, skip_timers = TRUE)
	spacer.planet_period = 1 SECONDS
	spacer.on_planet(patient)
	TEST_ASSERT(spacer.planetside_timer, "The fixture did not schedule gravity sickness.")
	var/datum/disease/paradise_zombie/infection = new()
	infection.infect(patient, FALSE)
	infection.stage = 8
	infection.process_infection_cycle()
	TEST_ASSERT(HAS_TRAIT(patient, TRAIT_PARADISE_ZOMBIE), "The fixture did not transform.")
	sleep(2 SECONDS)
	TEST_ASSERT_NULL(patient.has_status_effect(/datum/status_effect/spacer/gravity_sickness), "A detached quirk applied delayed gravity sickness to a zombie.")

/** The native resist action breaks a zombie's cuffs in five real seconds, cancels on movement and resets on cure. */
/datum/unit_test/paradise_zombie_cuff_escape
	parent_type = /datum/unit_test/paradise_zombie_mutation_test
	var/escape_finished = FALSE
	var/escape_finished_at

/datum/unit_test/paradise_zombie_cuff_escape/proc/resist_cuffs(mob/living/carbon/human/host)
	escape_finished = FALSE
	host.resist_restraints()
	escape_finished_at = world.time
	escape_finished = TRUE

/datum/unit_test/paradise_zombie_cuff_escape/Run()
	var/mob/living/carbon/human/host = make_zombie(run_loc_floor_bottom_left)
	host.mob_mood.set_enabled(FALSE)
	host.add_or_update_variable_actionspeed_modifier(/datum/actionspeed_modifier/base, multiplicative_slowdown = 1)
	var/mob/living/carbon/human/officer = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	var/obj/item/restraints/handcuffs/cuffs = allocate(/obj/item/restraints/handcuffs)
	TEST_ASSERT(officer.put_in_active_hand(cuffs), "The ordinary cuff fixture could not hold its handcuffs.")
	click_wrapper(officer, host)
	TEST_ASSERT_EQUAL(host.handcuffed, cuffs, "A lower zombie could not be restrained through the real cuff attack.")
	INVOKE_ASYNC(src, PROC_REF(resist_cuffs), host)
	sleep(1 SECONDS)
	TEST_ASSERT(!escape_finished && host.handcuffed == cuffs, "A zombie escaped before its native five-second breakout.")
	TEST_ASSERT(host.Move(get_step(host, EAST), EAST), "The restrained zombie could not perform its cancelling movement.")
	var/deadline = world.time + 1 SECONDS
	UNTIL(escape_finished || world.time >= deadline)
	TEST_ASSERT(escape_finished && host.handcuffed == cuffs && !QDELETED(cuffs), "Movement failed to cancel the native cuff breakout.")
	var/started_at = world.time
	INVOKE_ASYNC(src, PROC_REF(resist_cuffs), host)
	sleep(4 SECONDS)
	if(world.time < started_at + 5 SECONDS)
		TEST_ASSERT(!escape_finished && host.handcuffed == cuffs, "The retry broke cuffs before five real seconds elapsed.")
	deadline = started_at + 6 SECONDS
	UNTIL(escape_finished || world.time >= deadline)
	TEST_ASSERT(escape_finished && escape_finished_at >= started_at + 5 SECONDS, "The native five-second cuff retry did not finish within its expected boundary.")
	TEST_ASSERT(QDELETED(cuffs) && !host.handcuffed, "A successful zombie breakout did not destroy and unequip the real cuffs.")
	var/datum/disease/paradise_zombie/infection = locate() in host.diseases
	infection.cure()
	cuffs = allocate(/obj/item/restraints/handcuffs)
	TEST_ASSERT(officer.put_in_active_hand(cuffs), "The cured control could not receive fresh handcuffs.")
	click_wrapper(officer, host)
	TEST_ASSERT_EQUAL(host.handcuffed, cuffs, "The cured control was not actually handcuffed.")
	INVOKE_ASYNC(src, PROC_REF(resist_cuffs), host)
	sleep(5.5 SECONDS)
	TEST_ASSERT(!escape_finished && host.handcuffed == cuffs, "Curing the infection retained the zombie's fast cuff breakout.")
	TEST_ASSERT(host.Move(get_step(host, EAST), EAST), "The cured control could not cancel its ordinary long escape.")
	deadline = world.time + 1 SECONDS
	UNTIL(escape_finished || world.time >= deadline)
	TEST_ASSERT(escape_finished && host.handcuffed == cuffs, "The cured control left an unfinished escape callback.")

/// Counts real sight updates without replacing the native calculation, which requires a connected client.
/mob/living/carbon/human/consistent/paradise_zombie_sight_test
	var/sight_updates = 0

/mob/living/carbon/human/consistent/paradise_zombie_sight_test/update_sight()
	. = ..()
	sight_updates++

/** Night vision belongs to a mature physical body and updates native sight on transformation and cure. */
/datum/unit_test/paradise_zombie_night_vision_lifecycle
	parent_type = /datum/unit_test/paradise_zombie_mutation_test

/datum/unit_test/paradise_zombie_night_vision_lifecycle/Run()
	var/mob/living/carbon/human/consistent/paradise_zombie_sight_test/patient = allocate(/mob/living/carbon/human/consistent/paradise_zombie_sight_test)
	patient.mind_initialize()
	var/obj/item/organ/eyes/original_eyes = patient.get_organ_slot(ORGAN_SLOT_EYES)
	var/datum/disease/paradise_zombie/infection = new()
	TEST_ASSERT(patient.ForceContractDisease(infection, make_copy = FALSE, del_on_fail = TRUE), "The night vision fixture could not contract its real infection.")
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_TRUE_NIGHT_VISION), "An incubating infection granted mature zombie night vision.")
	var/updates_before = patient.sight_updates
	infection.stage = 8
	infection.process_infection_cycle()
	var/datum/component/paradise_zombie_regen/regeneration = patient.GetComponent(/datum/component/paradise_zombie_regen)
	TEST_ASSERT_NOTNULL(regeneration, "The mature body omitted its regeneration component.")
	var/vision_source = REF(regeneration)
	TEST_ASSERT(HAS_TRAIT_FROM(patient, TRAIT_TRUE_NIGHT_VISION, vision_source), "Transformation omitted source-owned native night vision.")
	TEST_ASSERT(patient.sight_updates > updates_before, "Transformation did not invoke the native sight update through its vision trait.")
	TEST_ASSERT_EQUAL(patient.get_organ_slot(ORGAN_SLOT_EYES), original_eyes, "Night vision replaced the patient's actual eyes.")
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_XRAY_VISION) && !HAS_TRAIT(patient, TRAIT_THERMAL_VISION) && !HAS_TRAIT(patient, TRAIT_MESON_VISION), "Zombie night vision also granted vision through walls.")
	var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent)
	patient.mind.transfer_to(recipient)
	TEST_ASSERT(HAS_TRAIT_FROM(patient, TRAIT_TRUE_NIGHT_VISION, vision_source), "Abandoning the infected body removed its physical night vision.")
	TEST_ASSERT(!HAS_TRAIT(recipient, TRAIT_TRUE_NIGHT_VISION), "A departing mind carried the infected body's night vision into a healthy body.")
	updates_before = patient.sight_updates
	var/obj/item/organ/paradise_zombie_tumor/tumor = patient.get_organ_slot(ORGAN_SLOT_ZOMBIE)
	TEST_ASSERT_NOTNULL(tumor, "The vision fixture has no real tumor to remove.")
	tumor.Remove(patient)
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_TRUE_NIGHT_VISION), "Surgical cure retained the zombie's night vision.")
	TEST_ASSERT(patient.sight_updates > updates_before, "Cure did not invoke the native sight update when removing night vision.")
	TEST_ASSERT_EQUAL(patient.get_organ_slot(ORGAN_SLOT_EYES), original_eyes, "Curing night vision replaced the patient's actual eyes.")

/** All production forms, plague servants and mapped corpses share source-owned vision and normal cleanup. */
/datum/unit_test/paradise_zombie_night_vision_variants
	parent_type = /datum/unit_test/paradise_zombie_mutation_test

/datum/unit_test/paradise_zombie_night_vision_variants/Run()
	for(var/support_index in 1 to 7)
		make_zombie(run_loc_floor_top_right)
	GLOB.paradise_zombie_mutation_progression.first_infection_at = world.time - 20 MINUTES
	for(var/form_id in list("slasher", "twitcher", "hunter", "brute", "spitter", "exploder"))
		var/mob/living/carbon/human/host = make_zombie(run_loc_floor_bottom_left)
		var/datum/component/paradise_zombie_mutation/controller = host.GetComponent(/datum/component/paradise_zombie_mutation)
		TEST_ASSERT(controller.apply_form(form_id), "The night vision fixture could not apply its real [form_id] form.")
		TEST_ASSERT(HAS_TRAIT(host, TRAIT_TRUE_NIGHT_VISION), "Applying [form_id] lost the body's night vision.")
		var/datum/disease/paradise_zombie/infection = locate() in host.diseases
		infection.cure()
		TEST_ASSERT(!HAS_TRAIT(host, TRAIT_TRUE_NIGHT_VISION), "Curing [form_id] retained zombie night vision.")
	var/mob/living/carbon/human/npc = allocate(/mob/living/basic/zombie)
	TEST_ASSERT(HAS_TRAIT(npc, TRAIT_TRUE_NIGHT_VISION), "The mapped NPC corpse omitted native night vision.")
	var/datum/disease/paradise_zombie/npc_infection = locate() in npc.diseases
	npc_infection.cure()
	TEST_ASSERT(!HAS_TRAIT(npc, TRAIT_TRUE_NIGHT_VISION), "Curing the mapped NPC retained zombie night vision.")
	var/mob/living/carbon/human/servant = allocate(/mob/living/carbon/human/consistent)
	ADD_TRAIT(servant, TRAIT_PARADISE_PLAGUE_ZOMBIE, PARADISE_ZOMBIE_TRAIT)
	var/datum/disease/paradise_zombie/wizard/plague = new /datum/disease/paradise_zombie/wizard(/datum/disease/anxiety/paradise_plague, TRUE)
	TEST_ASSERT(servant.ForceContractDisease(plague, make_copy = FALSE, del_on_fail = TRUE), "The plague servant could not receive its real magic infection.")
	plague.process_infection_cycle()
	TEST_ASSERT(HAS_TRAIT(servant, TRAIT_TRUE_NIGHT_VISION), "A mature magic plague servant omitted native night vision.")
	plague.cure()
	TEST_ASSERT(HAS_TRAIT(servant, TRAIT_TRUE_NIGHT_VISION), "A forbidden ordinary cure removed the magic servant's night vision.")
	qdel(plague)
	TEST_ASSERT(!HAS_TRAIT(servant, TRAIT_TRUE_NIGHT_VISION), "Forcibly clearing the magic infection retained its night vision.")

/** Cure preserves the race's own night-vision eyes, their chosen settings and independent trait sources. */
/datum/unit_test/paradise_zombie_night_vision_sources
	parent_type = /datum/unit_test/paradise_zombie_mutation_test

/datum/unit_test/paradise_zombie_night_vision_sources/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	patient.set_species(/datum/species/mush)
	var/datum/species/original_species = patient.dna.species
	var/obj/item/organ/eyes/night_vision/mushroom/eyes = patient.get_organ_slot(ORGAN_SLOT_EYES)
	TEST_ASSERT(istype(eyes), "The racial vision fixture has no native mushroom eyes.")
	eyes.ui_action_click()
	eyes.ui_action_click()
	var/original_level = eyes.light_level
	var/list/original_cutoffs = eyes.color_cutoffs.Copy()
	ADD_TRAIT(patient, TRAIT_TRUE_NIGHT_VISION, MAGIC_TRAIT)
	var/datum/disease/paradise_zombie/infection = new()
	TEST_ASSERT(patient.ForceContractDisease(infection, make_copy = FALSE, del_on_fail = TRUE), "The racial vision fixture could not contract its real infection.")
	infection.stage = 8
	infection.process_infection_cycle()
	var/datum/component/paradise_zombie_regen/regeneration = patient.GetComponent(/datum/component/paradise_zombie_regen)
	TEST_ASSERT_NOTNULL(regeneration, "The racial vision fixture did not become a mature zombie.")
	var/vision_source = REF(regeneration)
	TEST_ASSERT(HAS_TRAIT_FROM(patient, TRAIT_TRUE_NIGHT_VISION, vision_source), "An existing vision source prevented the zombie's independent grant.")
	infection.cure()
	TEST_ASSERT(!HAS_TRAIT_FROM(patient, TRAIT_TRUE_NIGHT_VISION, vision_source), "Cure retained the zombie's own vision source.")
	TEST_ASSERT(HAS_TRAIT_FROM(patient, TRAIT_TRUE_NIGHT_VISION, MAGIC_TRAIT), "Cure removed another source of true night vision.")
	TEST_ASSERT_EQUAL(patient.dna.species, original_species, "Cure replaced the race supplying the patient's original vision.")
	TEST_ASSERT_EQUAL(patient.get_organ_slot(ORGAN_SLOT_EYES), eyes, "Transformation or cure replaced native racial night-vision eyes.")
	TEST_ASSERT_EQUAL(eyes.light_level, original_level, "Cure reset the racial eyes' chosen vision mode.")
	for(var/index in 1 to 3)
		TEST_ASSERT_EQUAL(eyes.color_cutoffs[index], original_cutoffs[index], "Transformation or cure overwrote the racial eyes' color cutoffs.")
	REMOVE_TRAIT(patient, TRAIT_TRUE_NIGHT_VISION, MAGIC_TRAIT)
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_TRUE_NIGHT_VISION), "Removing the last independent source revealed leaked zombie night vision.")

#endif
