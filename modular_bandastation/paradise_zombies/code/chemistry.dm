/** Four persistent steps of Paradise's anti-plague treatment. */
/datum/reagent/medicine/paradise_zombie_cure
	abstract_type = /datum/reagent/medicine/paradise_zombie_cure
	metabolization_rate = 0.05
	taste_description = "горечи"
	/// Highest infection stage treatment unlocked by this sequence.
	var/cure_level = 0

/** Prevents scratch infections and treats stage one infections. */
/datum/reagent/medicine/paradise_zombie_cure/alpha
	name = "Противочумная формула «Альфа»"
	description = "Первый шаг к лечению зомби. Предотвращает заражение через царапины."
	color = "#003602"
	cure_level = 1

/** Treats early infections and weakens zombie claws. */
/datum/reagent/medicine/paradise_zombie_cure/beta
	name = "Противочумная формула «Бета»"
	description = "Лечит инфекцию на ранних стадиях. Ослабляет зомби, пока находится в их организме."
	color = "#006238"
	cure_level = 2

/** Treats moderate infections and slows zombie regeneration. */
/datum/reagent/medicine/paradise_zombie_cure/gamma
	name = "Противочумная формула «Гамма»"
	description = "Замедляет регенерацию зомби в три раза. Лечит инфекцию на средних стадиях."
	color = "#029779"
	cure_level = 3

/** Treats all plague stages and restores necrotic limbs one at a time. */
/datum/reagent/medicine/paradise_zombie_cure/omega
	name = "Противочумная формула «Омега»"
	description = "Лечит некротическую чуму на любой стадии. Не даёт зомби воскресать."
	color = "#001d4d"
	cure_level = 4

/datum/reagent/medicine/paradise_zombie_cure/omega/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()
	if(!ishuman(affected_mob) || !SPT_PROB(20, seconds_per_tick / 2))
		return
	heal_necrotic_limb(affected_mob)

/** Transplanted dead tissue can be treated even when its recipient has no plague. */
/datum/reagent/medicine/paradise_zombie_cure/omega/proc/heal_necrotic_limb(mob/living/carbon/affected_mob)
	for(var/obj/item/bodypart/limb as anything in affected_mob.get_bodyparts())
		var/datum/component/paradise_zombie_limb/rot = limb.GetComponent(/datum/component/paradise_zombie_limb)
		if(rot?.necrotic)
			rot.heal_necrosis()
			return TRUE
	return FALSE

/**
 * Anti-plague research: each round chooses the donor's ingredient subsets.
 * Randomized chemistry keeps the recipe out of the ordinary reagent lookup.
 */
/datum/chemical_reaction/randomized/paradise_zombie_cure
	abstract_type = /datum/chemical_reaction/randomized/paradise_zombie_cure
	reaction_flags = REACTION_INSTANT|REACTION_IGNORE_PURITY
	mix_message = "Смесь превращается в тёмно-зелёную пасту."
	required_temp = 0
	/// Cure progress the infected blood must not already exceed.
	var/cure_level = 0
	/// Number of distinct chemicals sampled from the ingredient pool.
	var/ingredient_count = 0
	/// An additional advanced-disease symptom required in the same blood sample.
	var/required_symptom

/datum/chemical_reaction/randomized/paradise_zombie_cure/New(recipe_data)
	// These sequences change every round, unlike persistent randomized reagents.
	return ..(null)

/datum/chemical_reaction/randomized/paradise_zombie_cure/generate_recipe()
	created = world.realtime
	required_reagents = list()
	var/list/possible_ingredients = get_possible_ingredients()
	if(!length(possible_ingredients))
		return TRUE
	if(length(possible_ingredients) < ingredient_count)
		return FALSE
	required_reagents[/datum/reagent/blood] = 1
	for(var/i in 1 to ingredient_count)
		required_reagents[pick_n_take(possible_ingredients)] = 1
	return TRUE

/** Returns the complete ingredient pool for this research step. */
/datum/chemical_reaction/randomized/paradise_zombie_cure/proc/get_possible_ingredients()
	return list()

/datum/chemical_reaction/randomized/paradise_zombie_cure/pre_reaction_other_checks(datum/reagents/holder)
	var/datum/reagent/blood/blood = locate() in holder.reagent_list
	if(!blood?.data)
		return FALSE
	var/datum/disease/paradise_zombie/infection = locate() in blood.data["viruses"]
	if(!infection || infection.cure_stage >= cure_level)
		return FALSE
	if(isnull(required_symptom))
		return TRUE
	for(var/datum/disease/advance/advanced in blood.data["viruses"])
		for(var/datum/symptom/symptom as anything in advanced.symptoms)
			if(istype(symptom, required_symptom))
				return TRUE
	return FALSE

/** The known first sequence, mixed from infected blood and diphenhydramine. */
/datum/chemical_reaction/randomized/paradise_zombie_cure/alpha
	results = list(/datum/reagent/medicine/paradise_zombie_cure/alpha = 1)
	cure_level = 1
	ingredient_count = 1

/datum/chemical_reaction/randomized/paradise_zombie_cure/alpha/get_possible_ingredients()
	return list(/datum/reagent/medicine/diphenhydramine)

/** Three reagents chosen from the original eight Beta candidates. */
/datum/chemical_reaction/randomized/paradise_zombie_cure/beta
	results = list(/datum/reagent/medicine/paradise_zombie_cure/beta = 1)
	cure_level = 2
	ingredient_count = 3

/datum/chemical_reaction/randomized/paradise_zombie_cure/beta/get_possible_ingredients()
	return list(
		/datum/reagent/medicine/salglu_solution,
		/datum/reagent/toxin,
		/datum/reagent/medicine/atropine,
		/datum/reagent/lye,
		/datum/reagent/consumable/sodawater,
		/datum/reagent/drug/happiness,
		/datum/reagent/medicine/morphine,
		/datum/reagent/medicine/paradise_teporone,
	)

/** Three of nine Gamma ingredients, plus a flesh-eating advanced virus. */
/datum/chemical_reaction/randomized/paradise_zombie_cure/gamma
	results = list(/datum/reagent/medicine/paradise_zombie_cure/gamma = 1)
	cure_level = 3
	ingredient_count = 3
	required_symptom = /datum/symptom/flesh_eating

/datum/chemical_reaction/randomized/paradise_zombie_cure/gamma/get_possible_ingredients()
	return list(
		/datum/reagent/paradise_vomit,
		/datum/reagent/drug/paradise_jenkem,
		/datum/reagent/medicine/paradise_charcoal,
		/datum/reagent/consumable/eggyolk,
		/datum/reagent/toxin/acid,
		/datum/reagent/toxin/acid/fluacid,
		/datum/reagent/drug/paradise_surge,
		/datum/reagent/lube/paradise_ultra,
		/datum/reagent/medicine/paradise_mitocholide,
	)

/** Two of twelve Omega ingredients, plus any advanced healing symptom. */
/datum/chemical_reaction/randomized/paradise_zombie_cure/omega
	results = list(/datum/reagent/medicine/paradise_zombie_cure/omega = 1)
	cure_level = 4
	ingredient_count = 2
	required_symptom = /datum/symptom/heal

/datum/chemical_reaction/randomized/paradise_zombie_cure/omega/get_possible_ingredients()
	return list(
		/datum/reagent/colorful_reagent,
		/datum/reagent/consumable/ethanol/bacchus_blessing,
		/datum/reagent/medicine/pen_acid,
		/datum/reagent/paradise_glyphosate,
		/datum/reagent/medicine/strange_reagent,
		/datum/reagent/medicine/omnizine,
		/datum/reagent/toxin/paradise_sarin,
		/datum/reagent/ants,
		/datum/reagent/clf3,
		/datum/reagent/sorium,
		/datum/reagent/paradise_questionmark,
		/datum/reagent/drug/aranesp,
	)

/** Copies the highest sequence in a beaker without consuming the seed cure. */
/datum/chemical_reaction/paradise_duplicate_cure
	abstract_type = /datum/chemical_reaction/paradise_duplicate_cure
	reaction_flags = REACTION_INSTANT|REACTION_IGNORE_PURITY
	required_temp = 0
	required_reagents = list(/datum/reagent/toxin/sulfonal = 1, /datum/reagent/consumable/sugar = 1)
	/// Cure type copied by this reaction; the catalyst is never consumed.
	var/cure_type

/datum/chemical_reaction/paradise_duplicate_cure/New()
	. = ..()
	// The chemistry index instantiates abstract parents as well as concrete recipes.
	if(type == /datum/chemical_reaction/paradise_duplicate_cure)
		required_reagents = null

/datum/chemical_reaction/paradise_duplicate_cure/pre_reaction_other_checks(datum/reagents/holder)
	for(var/sequence in list(
		/datum/reagent/medicine/paradise_zombie_cure/omega,
		/datum/reagent/medicine/paradise_zombie_cure/gamma,
		/datum/reagent/medicine/paradise_zombie_cure/beta,
		/datum/reagent/medicine/paradise_zombie_cure/alpha,
	))
		if(holder.has_reagent(sequence))
			return sequence == cure_type
	return FALSE

/datum/chemical_reaction/paradise_duplicate_cure/alpha
	results = list(/datum/reagent/medicine/paradise_zombie_cure/alpha = 1)
	required_catalysts = list(/datum/reagent/medicine/paradise_zombie_cure/alpha = 0.01)
	cure_type = /datum/reagent/medicine/paradise_zombie_cure/alpha

/datum/chemical_reaction/paradise_duplicate_cure/beta
	results = list(/datum/reagent/medicine/paradise_zombie_cure/beta = 1)
	required_catalysts = list(/datum/reagent/medicine/paradise_zombie_cure/beta = 0.01)
	cure_type = /datum/reagent/medicine/paradise_zombie_cure/beta

/datum/chemical_reaction/paradise_duplicate_cure/gamma
	results = list(/datum/reagent/medicine/paradise_zombie_cure/gamma = 1)
	required_catalysts = list(/datum/reagent/medicine/paradise_zombie_cure/gamma = 0.01)
	cure_type = /datum/reagent/medicine/paradise_zombie_cure/gamma

/datum/chemical_reaction/paradise_duplicate_cure/omega
	results = list(/datum/reagent/medicine/paradise_zombie_cure/omega = 1)
	required_catalysts = list(/datum/reagent/medicine/paradise_zombie_cure/omega = 0.01)
	cure_type = /datum/reagent/medicine/paradise_zombie_cure/omega
