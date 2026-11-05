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
	regeneration.process(1)
	TEST_ASSERT_NOTEQUAL(patient.stat, DEAD, "The same zombie could not rise again after Omega was removed.")
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_MUTE) && !HAS_TRAIT(patient, TRAIT_DEAF), "A repeated resurrection failed to cure newly acquired speech and hearing mutations.")

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

/** Lazarus necrosis is not infected tissue until the plague actually reaches and marks the same limb. */
/datum/unit_test/paradise_zombie_noninfectious_necrosis/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/limb = patient.get_bodypart(BODY_ZONE_L_ARM)
	var/datum/component/paradise_zombie_limb/necrosis = limb.AddComponent(/datum/component/paradise_zombie_limb, FALSE)
	TEST_ASSERT(necrosis.necrotic && limb.bodypart_disabled, "Lazarus necrosis did not disable the dead organic tissue.")
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
	TEST_ASSERT(necrosis.necrotic && HAS_TRAIT(limb, TRAIT_PARADISE_ZOMBIE_LIMB), "Immediate transformation lost the existing limb's necrosis or infection marker.")

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

/** Curing an early plague must not repair unrelated tissue killed by a previous Lazarus revival. */
/datum/unit_test/paradise_zombie_cure_preserves_unrelated_necrosis/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/arm = patient.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT(patient.paradise_lazarus_necrotize(arm), "The Lazarus fixture did not necrotize its arm.")
	var/datum/component/paradise_zombie_limb/necrosis = arm.GetComponent(/datum/component/paradise_zombie_limb)
	TEST_ASSERT(necrosis && necrosis.necrotic && !necrosis.infected && arm.bodypart_disabled, "The fixture did not acquire independent, noninfectious necrosis.")
	var/datum/disease/paradise_zombie/infection = new()
	infection.infect(patient, FALSE)
	infection.cure()
	TEST_ASSERT_EQUAL(arm.GetComponent(/datum/component/paradise_zombie_limb), necrosis, "Curing a stage-one infection deleted an unrelated Lazarus necrosis component.")
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
