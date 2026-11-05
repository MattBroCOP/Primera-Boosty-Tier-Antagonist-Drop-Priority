/** Reagent holders exercise research eligibility and the actual instant reactions. */
/datum/unit_test/paradise_zombie_research_reactions/Run()
	build_chemical_reactions_lists()
	var/list/reaction_types = list(
		/datum/chemical_reaction/randomized/paradise_zombie_cure/alpha,
		/datum/chemical_reaction/randomized/paradise_zombie_cure/beta,
		/datum/chemical_reaction/randomized/paradise_zombie_cure/gamma,
		/datum/chemical_reaction/randomized/paradise_zombie_cure/omega,
	)
	for(var/reaction_type in reaction_types)
		var/datum/chemical_reaction/randomized/paradise_zombie_cure/reaction = GLOB.chemical_reactions_list[reaction_type]
		TEST_ASSERT_NOTNULL(reaction, "Anti-plague research recipe [reaction_type] was not registered.")
		var/obj/item/reagent_containers/cup/beaker/beaker = allocate(/obj/item/reagent_containers/cup/beaker)
		var/datum/reagents/holder = beaker.reagents
		holder.flags |= NO_REACT
		holder.add_reagent(/datum/reagent/blood, 1)
		var/datum/reagent/blood/blood = holder.has_reagent(/datum/reagent/blood)
		TEST_ASSERT(!reaction.pre_reaction_other_checks(holder), "Ordinary blood must not produce [reaction_type].")
		var/datum/disease/paradise_zombie/infection = allocate(/datum/disease/paradise_zombie)
		blood.data["viruses"] = list(infection)
		if(reaction.required_symptom)
			TEST_ASSERT(!reaction.pre_reaction_other_checks(holder), "[reaction_type] ignored its virology requirement.")
			var/datum/disease/advance/advanced = allocate(/datum/disease/advance)
			advanced.symptoms += new reaction.required_symptom()
			blood.data["viruses"] += advanced
		TEST_ASSERT(reaction.pre_reaction_other_checks(holder), "A valid research sample was rejected by [reaction_type].")
		infection.cure_stage = reaction.cure_level
		TEST_ASSERT(!reaction.pre_reaction_other_checks(holder), "Blood already treated to this research level produced the same cure.")
		infection.cure_stage = 0
		for(var/ingredient in reaction.required_reagents)
			if(ingredient != /datum/reagent/blood)
				holder.add_reagent(ingredient, reaction.required_reagents[ingredient])
		holder.flags &= ~NO_REACT
		holder.handle_reactions()
		for(var/product in reaction.results)
			TEST_ASSERT(holder.has_reagent(product), "Valid infected blood and ingredients did not synthesize [product].")

/** Duplication selects the strongest seed and keeps it as a catalyst. */
/datum/unit_test/paradise_zombie_cure_duplication/Run()
	var/obj/item/reagent_containers/cup/beaker/beaker = allocate(/obj/item/reagent_containers/cup/beaker)
	var/datum/reagents/holder = beaker.reagents
	holder.flags |= NO_REACT
	holder.add_reagent(/datum/reagent/medicine/paradise_zombie_cure/alpha, 1)
	holder.add_reagent(/datum/reagent/medicine/paradise_zombie_cure/omega, 1)
	holder.add_reagent(/datum/reagent/toxin/sulfonal, 5)
	holder.add_reagent(/datum/reagent/consumable/sugar, 5)
	holder.flags &= ~NO_REACT
	holder.handle_reactions()
	TEST_ASSERT_EQUAL(holder.get_reagent_amount(/datum/reagent/medicine/paradise_zombie_cure/omega), 6, "Duplication did not expand the strongest sequence from its seed.")
	TEST_ASSERT_EQUAL(holder.get_reagent_amount(/datum/reagent/medicine/paradise_zombie_cure/alpha), 1, "Duplication consumed or expanded a weaker seed.")
	TEST_ASSERT_EQUAL(holder.get_reagent_amount(/datum/reagent/toxin/sulfonal), 0, "Duplication did not consume its substrate.")

/** Cloning injury remains separate from common damage and responds to real medicine. */
/datum/unit_test/paradise_lazarus_cloning_damage/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/original_max_health = patient.maxHealth
	var/datum/status_effect/paradise_cloning_damage/injury = patient.apply_status_effect(/datum/status_effect/paradise_cloning_damage, 25)
	patient.apply_status_effect(/datum/status_effect/paradise_cloning_damage, 25)
	TEST_ASSERT_EQUAL(patient.maxHealth, original_max_health - 50, "Cellular injury did not accumulate its independent health penalty.")
	patient.adjust_brute_loss(10)
	patient.adjust_tox_loss(10)
	patient.adjust_brute_loss(-10)
	patient.adjust_tox_loss(-10)
	TEST_ASSERT_EQUAL(injury.amount, 50, "Ordinary damage healing removed cellular injury.")
	patient.reagents.add_reagent(/datum/reagent/medicine/rezadone, 2)
	patient.reagents.metabolize(patient, 2)
	injury.tick(2)
	TEST_ASSERT(!patient.has_status_effect(/datum/status_effect/paradise_cloning_damage), "Metabolized Rezadone did not heal cellular injury.")
	TEST_ASSERT_EQUAL(patient.maxHealth, original_max_health, "Healing cellular injury did not restore the original health capacity.")

/** Verifies each research ingredient can actually be made in TG's competing reaction engine. */
/datum/unit_test/paradise_zombie_ingredient_synthesis/Run()
	check_synthesis("Teporone", list(/datum/reagent/acetone = 1, /datum/reagent/silicon = 1, /datum/reagent/toxin/plasma = 1), /datum/reagent/medicine/paradise_teporone, 2)
	check_synthesis("Charcoal", list(/datum/reagent/ash = 1, /datum/reagent/consumable/salt = 5), /datum/reagent/medicine/paradise_charcoal, 6, T0C + 100)
	check_synthesis("Charcoal at Multiver temperature", list(/datum/reagent/ash = 1, /datum/reagent/consumable/salt = 5), /datum/reagent/medicine/paradise_charcoal, 6, 400)
	check_synthesis("Mitocholide", list(/datum/reagent/medicine/c2/synthflesh = 1, /datum/reagent/medicine/cryoxadone = 1, /datum/reagent/toxin/plasma = 1), /datum/reagent/medicine/paradise_mitocholide, 3)
	check_synthesis("Jenkem", list(/datum/reagent/water/paradise_toilet = 1, /datum/reagent/ammonia = 1, /datum/reagent/water = 1), /datum/reagent/drug/paradise_jenkem, 3)
	check_synthesis("Surge", list(/datum/reagent/thermite = 3, /datum/reagent/uranium = 1, /datum/reagent/fluorosurfactant = 1, /datum/reagent/toxin/acid = 1), /datum/reagent/drug/paradise_surge, 6)
	check_synthesis("Ultra-Lube", list(/datum/reagent/lube = 2, /datum/reagent/toxin/formaldehyde = 1, /datum/reagent/cryostylane = 1), /datum/reagent/lube/paradise_ultra, 2)
	check_synthesis("Glyphosate", list(/datum/reagent/chlorine = 1, /datum/reagent/phosphorus = 1, /datum/reagent/toxin/formaldehyde = 1, /datum/reagent/ammonia = 1), /datum/reagent/paradise_glyphosate, 4)
	check_synthesis("Atrazine", list(/datum/reagent/chlorine = 1, /datum/reagent/hydrogen = 1, /datum/reagent/nitrogen = 1), /datum/reagent/paradise_glyphosate/atrazine, 3)
	check_synthesis("Sarin", list(/datum/reagent/chlorine = 1, /datum/reagent/fuel = 1, /datum/reagent/oxygen = 1, /datum/reagent/phosphorus = 1, /datum/reagent/fluorine = 1, /datum/reagent/hydrogen = 1, /datum/reagent/acetone = 1, /datum/reagent/paradise_glyphosate/atrazine = 1), /datum/reagent/toxin/paradise_sarin, 3, T0C + 100)
	check_synthesis("Lazarus Reagent", list(/datum/reagent/medicine/omnizine = 1, /datum/reagent/water/holywater = 1, /datum/reagent/toxin/mutagen = 1), /datum/reagent/medicine/strange_reagent, 3)

/** Supplies the original quantities and observes the real holder's product yield. */
/datum/unit_test/paradise_zombie_ingredient_synthesis/proc/check_synthesis(label, list/ingredients, product, expected_amount, temperature = 300)
	var/obj/item/reagent_containers/cup/beaker/beaker = allocate(/obj/item/reagent_containers/cup/beaker)
	var/datum/reagents/holder = beaker.reagents
	holder.flags |= NO_REACT
	for(var/ingredient in ingredients)
		holder.add_reagent(ingredient, ingredients[ingredient])
	holder.set_temperature(temperature)
	holder.flags &= ~NO_REACT
	holder.handle_reactions()
	TEST_ASSERT_EQUAL(holder.get_reagent_amount(product), expected_amount, "[label] could not be synthesized with its original ingredients, quantities and temperature.")

/** The 1:1 native recipe remains available beside the 1:5 Paradise recipe. */
/datum/unit_test/paradise_charcoal_multiver_compatibility/Run()
	var/obj/item/reagent_containers/cup/beaker/beaker = allocate(/obj/item/reagent_containers/cup/beaker)
	var/datum/reagents/holder = beaker.reagents
	holder.flags |= NO_REACT
	holder.add_reagent(/datum/reagent/ash, 1)
	holder.add_reagent(/datum/reagent/consumable/salt, 1)
	holder.set_temperature(400)
	holder.flags &= ~NO_REACT
	holder.handle_reactions()
	TEST_ASSERT(holder.has_reagent(/datum/reagent/medicine/c2/multiver), "Native Multiver could not start from its original 1:1 mixture.")
	TEST_ASSERT(!holder.has_reagent(/datum/reagent/medicine/paradise_charcoal), "Charcoal stole reactants from the native 1:1 Multiver mixture.")

/** Kingston blood retains its chosen mutation, which preserves damage and absent limbs. */
/datum/unit_test/paradise_plague_kingstons/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/disease/paradise_kingstons_advanced/infection = allocate(/datum/disease/paradise_kingstons_advanced)
	infection.infect(patient, FALSE)
	infection.chosen_species = /datum/species/vulpkanin
	var/obj/item/bodypart/missing = patient.get_bodypart(BODY_ZONE_L_ARM)
	missing.drop_limb(special = TRUE)
	qdel(missing)
	patient.adjust_brute_loss(20)
	var/damage_before = patient.get_brute_loss()
	TEST_ASSERT(infection.mutate_host(), "Kingston failed to perform its actual species mutation.")
	TEST_ASSERT(istype(patient.dna.species, /datum/species/vulpkanin), "Kingston mutated the host into the wrong species.")
	TEST_ASSERT_NULL(patient.get_bodypart(BODY_ZONE_L_ARM), "Kingston regrew a missing arm.")
	TEST_ASSERT_EQUAL(patient.get_brute_loss(), damage_before, "Kingston healed existing damage during its species change.")
	var/datum/disease/paradise_kingstons_advanced/sample = infection.Copy()
	var/same_target = sample.chosen_species == infection.chosen_species
	qdel(sample)
	TEST_ASSERT(same_target, "A blood copy rerolled the strain's Kingston species.")

/** Secondary plagues become visible midway and retain discovery through regression and blood copies. */
/datum/unit_test/paradise_plague_medical_discovery/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/disease/paradise_wand_rot/infection = allocate(/datum/disease/paradise_wand_rot)
	infection.infect(patient, FALSE)
	TEST_ASSERT_NULL(patient.check_virus(), "An early secondary plague appeared on the medical HUD.")
	infection.update_stage(CEILING(infection.max_stages * infection.discovery_threshold, 1))
	TEST_ASSERT_EQUAL(patient.check_virus(), DISEASE_SEVERITY_DANGEROUS, "The secondary plague stayed hidden at its discovery threshold.")
	infection.update_stage(1)
	TEST_ASSERT_EQUAL(patient.check_virus(), DISEASE_SEVERITY_DANGEROUS, "Treatment hid a discovered secondary plague from the medical HUD.")
	var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent)
	var/datum/disease/paradise_wand_rot/sample = infection.Copy()
	sample.infect(recipient, FALSE)
	TEST_ASSERT_EQUAL(recipient.check_virus(), DISEASE_SEVERITY_DANGEROUS, "A copied blood strain lost its prior medical discovery.")
	infection.discovered = FALSE
	infection.stage = 3
	infection.stage_act(0)
	TEST_ASSERT(infection.discovered, "A manually advanced secondary plague stayed hidden before its next timed symptom cycle.")

/** Removing the appendix through the actual surgery API cures its disease. */
/datum/unit_test/paradise_plague_appendectomy/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/disease/paradise_appendicitis/infection = allocate(/datum/disease/paradise_appendicitis)
	infection.infect(patient, FALSE)
	infection.stage = 2
	infection.on_plague_cycle()
	var/obj/item/organ/appendix/appendix = patient.get_organ_slot(ORGAN_SLOT_APPENDIX)
	TEST_ASSERT_NOTNULL(appendix, "The fixture had no appendix for surgery.")
	appendix.Remove(patient)
	qdel(appendix)
	TEST_ASSERT_NULL(locate(/datum/disease/paradise_appendicitis) in patient.diseases, "Appendectomy did not cure the talisman's appendicitis.")

/** Wand Rot fires real projectiles, rejects a stale stage, and cancels its queued sneeze. */
/datum/unit_test/paradise_plague_wand_rot/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/disease/paradise_wand_rot/infection = allocate(/datum/disease/paradise_wand_rot)
	infection.infect(patient, FALSE)
	infection.stage = 5
	var/obj/projectile/magic/fireball/fireball = infection.sneeze_fireballs(WEAKREF(patient))
	TEST_ASSERT_NOTNULL(fireball, "Wand Rot did not launch a real fireball.")
	var/correct_firer = fireball.firer == patient
	qdel(fireball)
	TEST_ASSERT(correct_firer, "Wand Rot's projectile lost its original firer.")
	infection.stage = 4
	TEST_ASSERT_NULL(infection.sneeze_fireballs(WEAKREF(patient)), "A sneeze fired after the infection regressed below stage five.")
	infection.stage = 5
	infection.queue_sneeze()
	var/timer_id = infection.sneeze_timer
	TEST_ASSERT_NOTNULL(timer_id, "Wand Rot did not schedule its audio lead.")
	infection.cure()
	TEST_ASSERT_NULL(timeleft(timer_id), "Curing Wand Rot left an armed projectile timer.")

/** Vacuum vomit removes actual atmospheric gas and cannot be collected in a cup. */
/datum/unit_test/paradise_plague_spacematter/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/disease/paradise_mystic_malaise/infection = allocate(/datum/disease/paradise_mystic_malaise)
	infection.infect(patient, FALSE)
	var/turf/open/tile = get_turf(patient)
	var/datum/gas_mixture/original_air = tile.air
	var/datum/gas_mixture/test_air = new(2500)
	test_air.set_gas(/datum/gas/oxygen, 10)
	tile.air = test_air
	var/obj/effect/decal/cleanable/vomit/paradise_spacematter/spill = infection.spawn_spacematter()
	spill.process(1)
	var/remaining_gas = test_air.total_moles()
	var/obj/item/reagent_containers/cup/beaker/beaker = allocate(/obj/item/reagent_containers/cup/beaker)
	spill.item_interaction(patient, beaker, list())
	var/collected_volume = beaker.reagents.total_volume
	tile.air = original_air
	qdel(spill)
	TEST_ASSERT(abs(remaining_gas - 4) < 0.001, "Spacematter failed to remove the original 1500/2500 atmospheric share.")
	TEST_ASSERT_EQUAL(collected_volume, 0, "The unscoopable vacuum spill could be collected as a reagent.")

/** The bile eruption starts a real recoil throw rather than only an emote. */
/datum/unit_test/paradise_plague_grut_fling/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/disease/paradise_grut_gut/infection = allocate(/datum/disease/paradise_grut_gut)
	infection.infect(patient, FALSE)
	infection.do_fling()
	TEST_ASSERT(patient.throwing, "Grut Gut did not throw the host backward.")

/** Omega restores physical transplanted necrosis without requiring an infection in the recipient. */
/datum/unit_test/paradise_omega_transplanted_necrosis/Run()
	var/mob/living/carbon/human/donor = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/bodypart/arm = donor.get_bodypart(BODY_ZONE_L_ARM)
	var/datum/component/paradise_zombie_limb/necrosis = arm.AddComponent(/datum/component/paradise_zombie_limb)
	allocated |= arm
	allocated |= recipient.get_bodypart(BODY_ZONE_L_ARM)
	arm.drop_limb(special = TRUE)
	TEST_ASSERT(arm.replace_limb(recipient), "The necrotic arm could not be transplanted.")
	TEST_ASSERT(arm.bodypart_disabled, "The transplanted arm unexpectedly worked before treatment.")
	recipient.reagents.add_reagent(/datum/reagent/medicine/paradise_zombie_cure/omega, 1)
	var/datum/reagent/medicine/paradise_zombie_cure/omega/treatment = recipient.reagents.has_reagent(/datum/reagent/medicine/paradise_zombie_cure/omega)
	TEST_ASSERT(treatment.heal_necrotic_limb(recipient), "Omega ignored necrotic tissue because its recipient had no disease.")
	TEST_ASSERT(!necrosis.necrotic && !arm.bodypart_disabled, "Omega did not restore use of the transplanted arm.")
	TEST_ASSERT(HAS_TRAIT(arm, TRAIT_PARADISE_ZOMBIE_LIMB), "Omega erased the persistent infected-tissue marker.")

/** The source vomiting paths preserve their different effects and leave swallowed medicine in the stomach. */
/datum/unit_test/paradise_vomit_effects/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	patient.set_nutrition(400)
	patient.set_tox_loss(12)
	var/obj/item/organ/stomach/stomach = patient.get_organ_slot(ORGAN_SLOT_STOMACH)
	stomach.reagents.add_reagent(/datum/reagent/water, 10)
	var/stomach_volume_before = stomach.reagents.total_volume
	TEST_ASSERT(patient.paradise_vomit(), "Normal source vomiting failed on a living, fed human.")
	TEST_ASSERT(!patient.IsStun() && !patient.IsKnockdown(), "Normal source vomiting introduced a native hard stun or knockdown.")
	TEST_ASSERT(patient.has_status_effect(/datum/status_effect/confusion) && patient.has_status_effect(/datum/status_effect/paradise_vomit_slow), "Normal vomiting lost the source confusion and slowdown.")
	TEST_ASSERT_EQUAL(patient.nutrition, 390, "Normal vomiting changed its original nutrition loss.")
	TEST_ASSERT_EQUAL(patient.get_tox_loss(), 9, "Normal vomiting changed its original toxin healing.")
	TEST_ASSERT_EQUAL(stomach.reagents.total_volume, stomach_volume_before, "Source vomiting purged swallowed medicine through TG's stomach machinery.")
	TEST_ASSERT_EQUAL(stomach.reagents.get_reagent_amount(/datum/reagent/water), 10, "Source vomiting removed part of the swallowed dose.")
	patient.remove_status_effect(/datum/status_effect/confusion)
	patient.remove_status_effect(/datum/status_effect/paradise_vomit_slow)
	patient.paradise_fakevomit(no_text = TRUE)
	TEST_ASSERT_EQUAL(patient.nutrition, 390, "Cosmetic vomiting consumed nutrition.")
	TEST_ASSERT_EQUAL(patient.get_tox_loss(), 9, "Cosmetic vomiting healed toxins.")
	TEST_ASSERT(!patient.has_status_effect(/datum/status_effect/confusion), "Cosmetic vomiting confused its host.")
	var/blood_before = patient.blood_volume
	patient.paradise_vomit(20, blood = TRUE)
	TEST_ASSERT_EQUAL(patient.blood_volume, blood_before - 20, "Source blood vomiting failed to consume its blood volume.")
	TEST_ASSERT(patient.IsKnockdown() && !patient.IsStun(), "Blood vomiting did not apply its source knockdown independently of hard stun.")
	TEST_ASSERT_EQUAL(patient.get_brute_loss(), 3, "Blood vomiting lost its original tissue damage.")

/** The soda source supplies an actual blood-borne cure alongside the build's chicken soup. */
/datum/unit_test/paradise_food_poisoning_cures/Run()
	var/obj/machinery/vending/cola/vendor = allocate(/obj/machinery/vending/cola)
	var/stocked = FALSE
	for(var/datum/data/vending_product/record as anything in vendor.product_records)
		if(record.product_path == /obj/item/reagent_containers/cup/soda_cans/paradise_ginger_ale && record.amount > 0)
			stocked = TRUE
	TEST_ASSERT(stocked, "The soft-drink machine did not stock the otherwise uncraftable Ginger Ale cure.")
	var/obj/item/reagent_containers/cup/soda_cans/paradise_ginger_ale/can = allocate(/obj/item/reagent_containers/cup/soda_cans/paradise_ginger_ale)
	TEST_ASSERT_EQUAL(can.reagents.get_reagent_amount(/datum/reagent/consumable/paradise_ginger_ale), 30, "Ginger Ale's obtainable can did not contain its original soda.")
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/disease/paradise_food_poisoning/poisoning = allocate(/datum/disease/paradise_food_poisoning)
	poisoning.infect(patient, FALSE)
	poisoning.stage = 3
	poisoning.cure_chance = 100
	patient.reagents.add_reagent(/datum/reagent/consumable/nutriment/soup/chicken_noodle_soup, 1)
	TEST_ASSERT(!poisoning.has_cure(), "Food poisoning ignored the donor's two-ingredient cure requirement.")
	can.reagents.trans_to(patient.reagents, 1)
	TEST_ASSERT(poisoning.has_cure(), "The obtainable Ginger Ale and native chicken soup did not satisfy food poisoning's cure.")
	poisoning.stage_act(2)
	TEST_ASSERT_NULL(locate(/datum/disease/paradise_food_poisoning) in patient.diseases, "The actual disease cycle could not cure food poisoning with its two original ingredients.")

/** Embalming preserves reached decay levels, while revival necrosis affects only nonvital organic tissue. */
/datum/unit_test/paradise_lazarus_corpse_decay/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/component/paradise_corpse_decay/decay = patient.GetComponent(/datum/component/paradise_corpse_decay)
	TEST_ASSERT_NOTNULL(decay, "A newly created human had no source decay observer.")
	patient.death()
	patient.timeofdeath = world.time - 8 MINUTES
	decay.update_decay()
	TEST_ASSERT_EQUAL(decay.decay_level, 0, "The source's strict eight-minute boundary advanced early.")
	patient.timeofdeath -= 1
	decay.update_decay()
	TEST_ASSERT_EQUAL(decay.decay_level, 1, "The source's first decay stage did not advance after eight minutes.")
	patient.reagents.add_reagent(/datum/reagent/toxin/formaldehyde, 1)
	patient.timeofdeath = world.time - 25 MINUTES
	decay.update_decay()
	TEST_ASSERT_EQUAL(decay.decay_level, 1, "Embalming erased or advanced the corpse's previously reached decay level.")
	patient.reagents.remove_reagent(/datum/reagent/toxin/formaldehyde, 1)
	decay.update_decay()
	TEST_ASSERT_EQUAL(decay.decay_level, 3, "Removing embalming fluid did not resume the donor's elapsed-time decay stage.")
	ADD_TRAIT(patient, TRAIT_NODECAY, REF(src))
	patient.timeofdeath = world.time - 46 MINUTES
	decay.update_decay()
	TEST_ASSERT_EQUAL(decay.decay_level, 3, "NODECAY failed to preserve its existing decay level.")
	REMOVE_TRAIT(patient, TRAIT_NODECAY, REF(src))
	decay.update_decay()
	TEST_ASSERT_EQUAL(decay.decay_level, 4, "The corpse did not reach its original final decay level.")
	var/obj/item/bodypart/arm = patient.get_bodypart(BODY_ZONE_L_ARM)
	TEST_ASSERT(patient.paradise_lazarus_necrotize(arm), "Lazarus could not necrotize a nonvital organic arm.")
	TEST_ASSERT(!HAS_TRAIT(arm, TRAIT_PARADISE_ZOMBIE_LIMB), "Lazarus necrosis incorrectly added a plague infection marker.")
	TEST_ASSERT(arm.bodypart_disabled, "The necrotic arm remained usable.")
	TEST_ASSERT(!patient.paradise_lazarus_necrotize(patient.get_bodypart(BODY_ZONE_HEAD)), "Lazarus necrotized vital head tissue.")
	var/obj/item/organ/brain/brain = patient.get_organ_slot(ORGAN_SLOT_BRAIN)
	TEST_ASSERT(!patient.paradise_lazarus_necrotize(brain), "Lazarus necrotized a vital brain.")
	var/obj/item/organ/appendix/appendix = patient.get_organ_slot(ORGAN_SLOT_APPENDIX)
	TEST_ASSERT(patient.paradise_lazarus_necrotize(appendix), "Lazarus could not necrotize a nonvital organic organ.")
	TEST_ASSERT(appendix.organ_flags & ORGAN_FAILING, "Necrotic internal tissue did not enter native organ failure.")
	patient.set_oxy_loss(300)
	TEST_ASSERT(!patient.revive(), "The oxygen-damage fixture unexpectedly passed native revival before its damage was treated.")
	TEST_ASSERT_EQUAL(decay.decay_level, 4, "An unsuccessful native revival reset the corpse's reached decay level.")
	patient.paradise_lazarus_revival()
	TEST_ASSERT_NOTEQUAL(patient.stat, DEAD, "Lazarus could not revive the decayed corpse through its real revival callback.")
	TEST_ASSERT_EQUAL(patient.get_oxy_loss(), 0, "Lazarus failed to clear the suffocation that native revival initially rejected.")
	TEST_ASSERT_EQUAL(decay.decay_level, 0, "Lazarus revival did not reset its source decay level.")
	TEST_ASSERT(patient.has_status_effect(/datum/status_effect/paradise_cloning_damage), "Lazarus revival lost its separate cellular-injury effect.")

/** Lazarus must restart the heart stopped by the normal human death path. */
/datum/unit_test/paradise_lazarus_restarts_heart/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/reagent/medicine/strange_reagent/instant/lazarus = allocate(/datum/reagent/medicine/strange_reagent/instant)
	patient.death()
	lazarus.expose_mob(patient, INGEST, 1)
	TEST_ASSERT_NOTEQUAL(patient.stat, DEAD, "An otherwise healthy human was not revived by Lazarus.")
	TEST_ASSERT(!patient.undergoing_cardiac_arrest(), "Lazarus left the revived human's heart stopped by death, causing immediate suffocation and tissue damage.")

/** Cryo must continue administering medicine after ordinary damage heals but cellular injury remains. */
/datum/unit_test/paradise_lazarus_cryo_cellular_damage/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/status_effect/paradise_cloning_damage/injury = patient.apply_status_effect(/datum/status_effect/paradise_cloning_damage, 50)
	patient.set_brute_loss(10)
	patient.heal_overall_damage(10)
	TEST_ASSERT_EQUAL(patient.get_brute_loss(), 0, "The ordinary damage fixture was not fully healed.")
	patient.bodytemperature = 200
	var/obj/machinery/cryo_cell/cryo = allocate(/obj/machinery/cryo_cell)
	cryo.set_machine_stat(cryo.machine_stat & ~NOPOWER)
	var/datum/gas_mixture/internal_air = cryo.internal_connector.gas_connector.airs[1]
	internal_air.set_gas(/datum/gas/oxygen, 20)
	internal_air.temperature = 200
	var/obj/item/reagent_containers/cup/beaker/beaker = allocate(/obj/item/reagent_containers/cup/beaker, cryo)
	beaker.reagents.add_reagent(/datum/reagent/medicine/cryoxadone, 10)
	cryo.beaker = beaker
	cryo.open_machine()
	cryo.close_machine(patient)
	cryo.process(2)
	TEST_ASSERT(cryo.on && cryo.occupant == patient, "Cryo declared a patient with untreated cellular injury fully recovered and stopped before administering cryoxadone.")
	TEST_ASSERT(patient.reagents.has_reagent(/datum/reagent/medicine/cryoxadone), "Cryo did not administer cryoxadone for the remaining cellular injury.")
	patient.reagents.metabolize(patient, 2)
	injury.tick(2)
	TEST_ASSERT(injury.amount < 50, "Real cryogenic administration and metabolism did not reduce the remaining cellular injury.")
	injury.change_amount(-injury.amount)
	cryo.process(2)
	TEST_ASSERT(!cryo.on, "Cryo did not finish treatment after all cellular injury was healed.")
