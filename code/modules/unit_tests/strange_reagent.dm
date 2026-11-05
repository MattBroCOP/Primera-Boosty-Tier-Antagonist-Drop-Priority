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

/datum/unit_test/lazarus_damage_limit/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/reagent/medicine/strange_reagent/instant/lazarus = new
	patient.set_brute_loss(150)
	patient.death()
	lazarus.expose_mob(patient, INGEST, 1)
	TEST_ASSERT_EQUAL(patient.stat, DEAD, "Lazarus revived a body at the original 150-damage limit.")
	TEST_ASSERT_NULL(patient.has_status_effect(/datum/status_effect/paradise_cloning_damage), "A rejected revival applied cellular damage.")
	qdel(lazarus)
