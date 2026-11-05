/datum/unit_test/paradise_zombie_research_and_cure/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/disease/paradise_zombie/infection = new
	infection.infect(patient, FALSE)
	patient.reagents.add_reagent(/datum/reagent/medicine/paradise_zombie_cure/beta, 2)
	infection.update_cure_stage()
	TEST_ASSERT_EQUAL(infection.cure_stage, 2, "Beta must permanently weaken this strain to research level two.")
	patient.reagents.clear_reagents()
	var/datum/disease/paradise_zombie/sample = infection.Copy()
	TEST_ASSERT_EQUAL(sample.cure_stage, 2, "A blood sample lost the strain's researched cure level.")
	qdel(sample)
	infection.stage = 3
	TEST_ASSERT(infection.has_cure(), "A previously Beta-treated stage three strain should remain treatable.")
	infection.stage = 5
	TEST_ASSERT(!infection.has_cure(), "Beta alone must not cure a stage five strain.")

/datum/unit_test/paradise_zombie_transformation_and_surgery/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/disease/paradise_zombie/infection = new
	infection.infect(patient, FALSE)
	infection.stage = 8
	infection.process_infection_cycle()
	TEST_ASSERT(HAS_TRAIT(patient, TRAIT_PARADISE_ZOMBIE), "Immediate zombification failed to transform the body.")
	var/obj/item/organ/paradise_zombie_tumor/tumor = patient.get_organ_slot(ORGAN_SLOT_ZOMBIE)
	TEST_ASSERT_NOTNULL(tumor, "Transformation did not grow the removable necrotic tumor.")
	tumor.Remove(patient)
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_PARADISE_ZOMBIE), "Removing the tumor did not reverse zombification.")
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_NOBREATH), "Surgical cure left the body independent of breathing.")
	TEST_ASSERT_NULL(locate(/datum/disease/paradise_zombie) in patient.diseases, "Tumor extraction left the plague in the patient.")
	qdel(tumor)

/// The new language must be usable with an ordinary tongue and leave no blocks after mind transfer.
/datum/unit_test/paradise_zombie_language_and_transfer/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/new_body = allocate(/mob/living/carbon/human/consistent)
	patient.mind_initialize()
	var/datum/disease/paradise_zombie/infection = new
	infection.infect(patient, FALSE)
	infection.stage = 8
	infection.process_infection_cycle()
	TEST_ASSERT(patient.can_speak_language(/datum/language/paradise_zombie), "The ordinary human tongue prevented zombie speech.")
	TEST_ASSERT(!patient.can_speak_language(/datum/language/common), "A zombie could still speak its old language.")
	var/datum/mind/mind = patient.mind
	mind.transfer_to(new_body)
	TEST_ASSERT(!mind.has_antag_datum(/datum/antagonist/paradise_zombie), "The zombie antagonist crossed into an uninfected body.")
	TEST_ASSERT(new_body.can_speak_language(/datum/language/common), "Zombie language restrictions leaked into the new body.")
	TEST_ASSERT(patient.can_speak_language(/datum/language/common), "The old body's language source was not restored on mind transfer.")
	patient.check_breath(null)
	TEST_ASSERT_EQUAL(patient.get_oxy_loss(), 0, "The abandoned infected body started suffocating after its mind left.")

/// Existing Romerol must contract the replacement plague, including its sticky medical discovery.
/datum/unit_test/paradise_zombie_romerol_and_medhud/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/reagent/romerol/romerol = allocate(/datum/reagent/romerol)
	romerol.expose_mob(patient, INJECT, 2)
	var/datum/disease/paradise_zombie/infection = locate() in patient.diseases
	TEST_ASSERT_NOTNULL(infection, "Romerol did not contract the replacement plague.")
	TEST_ASSERT(!patient.check_virus(), "Medical HUDs detected the early hidden infection.")
	infection.stage = 4
	infection.handle_stage_advance()
	TEST_ASSERT_EQUAL(patient.check_virus(), DISEASE_SEVERITY_BIOHAZARD, "A bite-strength infection stayed hidden until its minute timer elapsed.")
	infection.stage = 2
	TEST_ASSERT_EQUAL(patient.check_virus(), DISEASE_SEVERITY_BIOHAZARD, "A discovered strain became hidden again after partial treatment.")
	infection.cure()
	TEST_ASSERT(!patient.check_virus(), "Curing the plague left a disease marker on medical HUDs.")
