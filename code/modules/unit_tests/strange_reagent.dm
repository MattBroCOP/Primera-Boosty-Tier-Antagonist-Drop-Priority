/// The shared resurrection recipe now follows Paradise Lazarus rather than TG dose-based healing.
/datum/unit_test/strange_reagent/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/reagent/medicine/strange_reagent/instant/lazarus = new
	patient.adjust_brute_loss(20)
	patient.death()
	lazarus.expose_mob(patient, INGEST, 1)
	TEST_ASSERT_NOTEQUAL(patient.stat, DEAD, "One unit of Lazarus should revive an eligible injured body.")
	var/datum/status_effect/paradise_cloning_damage/cell_damage = patient.has_status_effect(/datum/status_effect/paradise_cloning_damage)
	TEST_ASSERT_NOTNULL(cell_damage, "Lazarus revival omitted its cellular damage.")
	TEST_ASSERT_EQUAL(cell_damage.amount, 50, "Lazarus revival must cause fifty cellular damage.")
	qdel(lazarus)

/// Failed Lazarus applications must neither revive ineligible bodies nor damage them.
/datum/unit_test/lazarus_invalid_bodies/Run()
	var/datum/reagent/medicine/strange_reagent/instant/lazarus = allocate(/datum/reagent/medicine/strange_reagent/instant)
	var/mob/living/basic/supermatter_spider/spider = allocate(/mob/living/basic/supermatter_spider)
	spider.death()
	lazarus.expose_mob(spider, TOUCH, 1)
	TEST_ASSERT_EQUAL(spider.stat, DEAD, "Lazarus revived a nonorganic spider.")
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/organ/brain/brain = patient.get_organ_slot(ORGAN_SLOT_BRAIN)
	allocated |= brain
	brain.Remove(patient)
	patient.death()
	lazarus.expose_mob(patient, INGEST, 1)
	TEST_ASSERT_EQUAL(patient.stat, DEAD, "Lazarus revived a brainless body.")
	TEST_ASSERT_NULL(patient.has_status_effect(/datum/status_effect/paradise_cloning_damage), "Lazarus damaged a body that it could not revive.")

/// Eligibility can change during the reagent's five-second revival delay.
/datum/unit_test/lazarus_late_bad_dna/Run()
	var/datum/reagent/medicine/strange_reagent/lazarus = allocate(/datum/reagent/medicine/strange_reagent)
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	patient.death()
	lazarus.expose_mob(patient, INGEST, 1)
	TEST_ASSERT_NOTNULL(patient.paradise_lazarus_pending_death, "The fixture did not schedule delayed Lazarus revival.")
	ADD_TRAIT(patient, TRAIT_BADDNA, TRAIT_SOURCE_UNIT_TESTS)
	var/deadline = world.time + 10 SECONDS
	UNTIL(isnull(patient.paradise_lazarus_pending_death) || world.time >= deadline)
	TEST_ASSERT_NULL(patient.paradise_lazarus_pending_death, "Lazarus did not finish its delayed attempt.")
	TEST_ASSERT_EQUAL(patient.stat, DEAD, "Lazarus revived a body whose DNA became invalid during the delay.")
	TEST_ASSERT_NULL(patient.has_status_effect(/datum/status_effect/paradise_cloning_damage), "Lazarus damaged a body after it became ineligible.")

/// A later death does not inherit the old corpse's pending Lazarus application.
/datum/unit_test/lazarus_stale_death/Run()
	var/datum/reagent/medicine/strange_reagent/lazarus = allocate(/datum/reagent/medicine/strange_reagent)
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	patient.death()
	lazarus.expose_mob(patient, INGEST, 1)
	TEST_ASSERT_NOTNULL(patient.paradise_lazarus_pending_death, "The fixture did not schedule delayed Lazarus revival.")
	sleep(world.tick_lag)
	TEST_ASSERT(patient.revive(), "The fixture could not revive before the Lazarus timer.")
	patient.death()
	var/deadline = world.time + 10 SECONDS
	UNTIL(isnull(patient.paradise_lazarus_pending_death) || world.time >= deadline)
	TEST_ASSERT_NULL(patient.paradise_lazarus_pending_death, "Lazarus did not finish its delayed attempt.")
	TEST_ASSERT_EQUAL(patient.stat, DEAD, "The old Lazarus dose revived a later corpse.")

/// An old pending dose cannot swallow a fresh dose for a later corpse.
/datum/unit_test/lazarus_second_dose/Run()
	var/datum/reagent/medicine/strange_reagent/lazarus = allocate(/datum/reagent/medicine/strange_reagent)
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	patient.death()
	lazarus.expose_mob(patient, INGEST, 1)
	TEST_ASSERT_NOTNULL(patient.paradise_lazarus_pending_death, "The fixture did not schedule delayed Lazarus revival.")
	sleep(world.tick_lag)
	TEST_ASSERT(patient.revive(), "The fixture could not revive before the Lazarus timer.")
	patient.death()
	lazarus.expose_mob(patient, INGEST, 1)
	var/deadline = world.time + 10 SECONDS
	UNTIL(patient.stat != DEAD || world.time >= deadline)
	TEST_ASSERT_NOTEQUAL(patient.stat, DEAD, "An older pending dose prevented the new dose from reviving its corpse.")

/datum/unit_test/lazarus_damage_limit/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/reagent/medicine/strange_reagent/instant/lazarus = new
	patient.set_brute_loss(150)
	patient.death()
	lazarus.expose_mob(patient, INGEST, 1)
	TEST_ASSERT_EQUAL(patient.stat, DEAD, "Lazarus revived a body at the original 150-damage limit.")
	TEST_ASSERT_NULL(patient.has_status_effect(/datum/status_effect/paradise_cloning_damage), "A rejected revival applied cellular damage.")
	qdel(lazarus)
