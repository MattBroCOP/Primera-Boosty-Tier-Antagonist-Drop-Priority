#ifdef UNIT_TESTS

/// The isolated respiratory diseases retain their original temperature rates and do not require lungs.
/datum/unit_test/paradise_legacy_plague_temperature
	parent_type = /datum/unit_test/paradise_zombie_combat

/datum/unit_test/paradise_legacy_plague_temperature/Run()
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	var/datum/disease/cold9/paradise_plague/cold = allocate(/datum/disease/cold9/paradise_plague)
	cold.infect(host, FALSE)
	cold.stage = 3
	var/initial_temperature = host.bodytemperature
	cold.stage_act(2)
	TEST_ASSERT(abs(host.bodytemperature - (initial_temperature - 15)) < 0.001, "ICE9 cold did not apply its original fifteen-kelvin stage-three cooling per two-second cycle.")
	cold.cure(add_resistance = TRUE)
	TEST_ASSERT(!("[/datum/disease/cold]" in host.disease_resistances), "Curing the isolated ICE9 cold granted TG's unrelated free common-cold immunity.")
	var/datum/disease/fluspanish/paradise_plague/flu = allocate(/datum/disease/fluspanish/paradise_plague)
	flu.infect(host, FALSE)
	flu.stage = 3
	initial_temperature = host.bodytemperature
	flu.stage_act(2)
	TEST_ASSERT(abs(host.bodytemperature - (initial_temperature + 20)) < 0.001, "The original Spanish flu did not heat its host twenty kelvin per stage-three cycle.")
	flu.cure(add_resistance = TRUE)
	TEST_ASSERT(!("[/datum/disease/flu]" in host.disease_resistances), "Curing the isolated Spanish flu granted TG's unrelated free common-flu immunity.")
	var/obj/item/organ/lungs/lungs = host.get_organ_slot(ORGAN_SLOT_LUNGS)
	lungs.Remove(host)
	lungs.forceMove(run_loc_floor_bottom_left)
	var/datum/disease/cold9/paradise_plague/new_cold = allocate(/datum/disease/cold9/paradise_plague)
	var/datum/disease/fluspanish/paradise_plague/new_flu = allocate(/datum/disease/fluspanish/paradise_plague)
	host.disease_resistances.Cut()
	TEST_ASSERT(host.CanContractDisease(new_cold), "The isolated ICE9 cold incorrectly inherited TG's organic-lung infection gate.")
	TEST_ASSERT(host.CanContractDisease(new_flu), "The isolated Spanish flu incorrectly inherited TG's organic-lung infection gate.")

/// Tuberculosis must recognise the original salbutamol combination, not TG's convermol substitution.
/datum/unit_test/paradise_legacy_plague_tuberculosis_cure
	parent_type = /datum/unit_test/paradise_zombie_combat

/datum/unit_test/paradise_legacy_plague_tuberculosis_cure/Run()
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	var/datum/disease/tuberculosis/paradise_plague/infection = allocate(/datum/disease/tuberculosis/paradise_plague)
	infection.infect(host, FALSE)
	host.reagents.add_reagent(/datum/reagent/medicine/spaceacillin, 1)
	host.reagents.add_reagent(/datum/reagent/medicine/c2/convermol, 1)
	TEST_ASSERT(!infection.has_cure(), "TG's convermol combination unexpectedly treats Paradise's fungal tuberculosis.")
	host.reagents.clear_reagents()
	host.reagents.add_reagent(/datum/reagent/medicine/spaceacillin, 1)
	TEST_ASSERT(!infection.has_cure(), "Spaceacillin alone treats a disease requiring both original medicines.")
	host.reagents.add_reagent(/datum/reagent/medicine/salbutamol, 1)
	TEST_ASSERT(infection.has_cure(), "The available salbutamol and spaceacillin did not satisfy the original treatment boundary.")

/// A copied retrovirus strain keeps its selected treatment instead of rerolling its newborn cure.
/datum/unit_test/paradise_legacy_plague_retrovirus_copy
	parent_type = /datum/unit_test/paradise_zombie_combat

/datum/unit_test/paradise_legacy_plague_retrovirus_copy/Run()
	var/datum/disease/dna_retrovirus/paradise_plague/rest_strain = allocate(/datum/disease/dna_retrovirus/paradise_plague)
	rest_strain.restcure = TRUE
	rest_strain.cures = list()
	var/datum/disease/dna_retrovirus/paradise_plague/copied_rest = rest_strain.Copy()
	allocated += copied_rest
	TEST_ASSERT(copied_rest.restcure, "Copying a resting-cure retrovirus rerolled its treatment choice.")
	TEST_ASSERT_EQUAL(length(copied_rest.cures), 0, "Copying a resting-cure retrovirus inserted a mutadone requirement.")
	TEST_ASSERT_EQUAL(copied_rest.agent, rest_strain.agent, "A copied retrovirus changed the strain's original agent identity.")
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	var/datum/disease/dna_retrovirus/paradise_plague/medicine_strain = allocate(/datum/disease/dna_retrovirus/paradise_plague)
	medicine_strain.restcure = FALSE
	medicine_strain.cures = list(/datum/reagent/medicine/mutadone)
	medicine_strain.infect(host, FALSE)
	host.reagents.add_reagent(/datum/reagent/medicine/mutadone, 1)
	TEST_ASSERT(medicine_strain.has_cure(), "The original medicine-cure retrovirus no longer recognises mutadone.")

/// The two spawned butterflies receive finite lifetime timers and really disappear on decomposition.
/datum/unit_test/paradise_legacy_plague_anxiety_butterflies
	parent_type = /datum/unit_test/paradise_zombie_combat

/datum/unit_test/paradise_legacy_plague_anxiety_butterflies/Run()
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	var/datum/disease/anxiety/paradise_plague/infection = allocate(/datum/disease/anxiety/paradise_plague)
	infection.infect(host, FALSE)
	var/start = world.time
	var/list/butterflies = infection.spawn_butterflies()
	TEST_ASSERT_EQUAL(length(butterflies), 2, "Anxiety did not produce the original pair of butterflies.")
	for(var/mob/living/basic/butterfly/paradise_plague/butterfly as anything in butterflies)
		var/lifetime_timer = butterfly.decompose_timer
		var/remaining_lifetime = timeleft(lifetime_timer)
		TEST_ASSERT(remaining_lifetime > 0 && remaining_lifetime <= 25 SECONDS, "An anxiety butterfly has no active lifetime timer or can outlive the original twenty-five-second maximum.")
		TEST_ASSERT(remaining_lifetime + (world.time - start) >= 5 SECONDS, "An anxiety butterfly was scheduled below its original five-second minimum.")
		butterfly.decompose()
		TEST_ASSERT(QDELETED(butterfly), "Decomposition left a live butterfly or a permanent corpse.")
		TEST_ASSERT_NULL(timeleft(lifetime_timer), "An early decomposition left a timer retaining the deleted butterfly.")

/// Wizarditis keeps its disease under magical grounding and creates one disposable item without TG combat spells.
/datum/unit_test/paradise_legacy_plague_wizarditis
	parent_type = /datum/unit_test/paradise_zombie_combat
	/// An observable completed native teleport, independent of which random destination was selected.
	var/teleported = FALSE

/datum/unit_test/paradise_legacy_plague_wizarditis/proc/on_teleport(mob/source)
	SIGNAL_HANDLER
	teleported = TRUE

/datum/unit_test/paradise_legacy_plague_wizarditis/Run()
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	var/datum/disease/wizarditis/paradise_plague/infection = allocate(/datum/disease/wizarditis/paradise_plague)
	infection.infect(host, FALSE)
	infection.stage = 4
	ADD_TRAIT(host, TRAIT_ANTIMAGIC, TRAIT_GENERIC)
	infection.stage_act(2)
	TEST_ASSERT_EQUAL(infection.stage, 4, "Wizarditis inherited TG's magical-grounding stage reset.")
	TEST_ASSERT(!("random_spells" in infection.vars) && !("random_targeted_spells" in infection.vars), "The original Wizarditis acquired TG's automatic combat-spell arsenal.")
	REMOVE_TRAIT(host, TRAIT_ANTIMAGIC, TRAIT_GENERIC)
	var/list/old_equipment = host.get_equipped_items(INCLUDE_HELD|INCLUDE_ABSTRACT)
	TEST_ASSERT(infection.spawn_wizard_clothes(), "Wizarditis could not create original magical attire for an eligible human.")
	var/list/new_equipment = host.get_equipped_items(INCLUDE_HELD|INCLUDE_ABSTRACT) - old_equipment
	TEST_ASSERT_EQUAL(length(new_equipment), 1, "The original clothing effect did not replace exactly one eligible slot.")
	var/obj/item/attire = new_equipment[1]
	TEST_ASSERT(attire.item_flags & DROPDEL, "Wizarditis generated permanent attire instead of the original disposable item.")
	host.dropItemToGround(attire)
	TEST_ASSERT(QDELETED(attire), "Wizarditis attire remained usable after being dropped.")
	RegisterSignal(host, COMSIG_MOVABLE_POST_TELEPORT, PROC_REF(on_teleport))
	TEST_ASSERT(infection.teleport(), "The original eighty-tile area-search teleport could not complete in an unrestricted test room.")
	TEST_ASSERT(teleported, "Wizarditis did not complete the real native teleport pipeline.")
	TEST_ASSERT(!isspaceturf(get_turf(host)), "Wizarditis selected a space destination.")
	UnregisterSignal(host, COMSIG_MOVABLE_POST_TELEPORT)
	host.reagents.add_reagent(/datum/reagent/consumable/ethanol/manly_dorf, 1)
	infection.stage_act(2)
	TEST_ASSERT(QDELETED(infection), "Manly Dorf did not cure original Wizarditis at its guaranteed cure boundary.")

#endif
