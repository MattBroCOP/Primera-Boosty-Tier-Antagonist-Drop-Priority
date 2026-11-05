/** Paradise's seven-stage necrotizing plague. */
/datum/disease/paradise_zombie
	name = "Некротическая чума"
	desc = "Этот вирус заражает гуманоидов, сводит их с ума от жажды плоти и наделяет способностью к регенерации."
	form = "Вирусная инфекция"
	agent = ""
	max_stages = 7
	spread_text = "Кровь и слюна"
	spread_flags = DISEASE_SPREAD_BLOOD
	cure_text = "Противочумные препараты"
	disease_flags = CAN_CARRY
	viable_mobtypes = list(/mob/living/carbon/human)
	severity = DISEASE_SEVERITY_BIOHAZARD
	process_dead = TRUE
	stage_prob = 100
	cure_chance = 80
	/// The highest anti-plague sequence this strain has been exposed to, including in blood samples.
	var/cure_stage = 0
	/// Whether this infection has reached the stage visible on medical HUDs.
	var/discovered = FALSE
	/// Disease transmitted by the wizard's plague claws.
	var/plague_disease
	/// Wizard/admin creation can skip the incubation and necrotize every limb immediately.
	var/instant_zombie = FALSE
	/// Prevents tumor extraction and antagonist cleanup from recursively curing the same disease.
	var/clearing_infection = FALSE
	/// Original disease processing runs once every two seconds.
	var/cycle_accumulator = 0
	/// Deadline for the next ordinary infection stage increase.
	COOLDOWN_DECLARE(stage_timer)

/datum/disease/paradise_zombie/New(chosen_plague, plague_zomb = FALSE)
	. = ..()
	if(plague_zomb)
		plague_disease = chosen_plague
		instant_zombie = TRUE

/datum/disease/paradise_zombie/Copy()
	var/datum/disease/paradise_zombie/copied = ..()
	copied.cure_stage = cure_stage
	copied.discovered = discovered
	copied.plague_disease = plague_disease
	copied.instant_zombie = instant_zombie
	copied.update_cure_stage()
	return copied

/datum/disease/paradise_zombie/after_add()
	. = ..()
	COOLDOWN_START(src, stage_timer, 1 MINUTES)
	if(instant_zombie)
		stage = 8
	GLOB.paradise_zombie_mutation_progression.note_infection(affected_mob)

/datum/disease/paradise_zombie/Destroy()
	if(affected_mob && !clearing_infection && !QDELETED(affected_mob))
		clear_zombie_effects()
	return ..()

/datum/disease/paradise_zombie/stage_act(seconds_per_tick = 2)
	if(!ishuman(affected_mob) || clearing_infection)
		return FALSE
	cycle_accumulator += seconds_per_tick
	while(cycle_accumulator >= 2 && !QDELETED(src))
		cycle_accumulator -= 2
		if(!process_infection_cycle())
			return FALSE
	return TRUE

/** Runs one original Paradise disease tick without TG's unrelated natural recovery rules. */
/datum/disease/paradise_zombie/proc/process_infection_cycle()
	var/mob/living/carbon/human/host = affected_mob
	if(stage >= 8)
		for(var/obj/item/bodypart/limb as anything in host.get_bodyparts())
			if(limb.bodytype & BODYTYPE_ORGANIC)
				var/datum/component/paradise_zombie_limb/rot = limb.GetComponent(/datum/component/paradise_zombie_limb)
				if(!rot)
					rot = limb.AddComponent(/datum/component/paradise_zombie_limb)
				rot.infect_limb()
				rot.necrotize()
		stage = max_stages

	var/has_treatment = has_cure()
	if(carrier && !has_treatment)
		return FALSE
	handle_stage_advance(has_treatment)
	if(!handle_cure_testing(has_treatment))
		return FALSE
	if(HAS_TRAIT(host, TRAIT_PARADISE_ZOMBIE) || host.mind?.has_antag_datum(/datum/antagonist/paradise_zombie))
		if(host.reagents.has_reagent(/datum/reagent/medicine/paradise_zombie_cure/omega))
			return TRUE
		handle_rot()
		stage = max_stages
		return TRUE

	switch(stage)
		if(1)
			if(prob(4))
				to_chat(host, span_warning(pick("У вас чешется кожа головы.", "Ваша кожа шелушится.")))
			else if(prob(5))
				to_chat(host, span_warning(pick("У вас чешется спина.", "У вас чешется рука.", "У вас чешется нога.", "У вас чешется локоть.", "У вас чешется голова.")))
		if(2)
			if(prob(2))
				to_chat(host, span_danger("Слизь стекает по задней стенке горла."))
			else if(prob(5))
				to_chat(host, span_warning(pick("Вы чувствуете голод.", "Вам ужасно хочется что-нибудь съесть.")))
		if(3)
			if(prob(2))
				INVOKE_ASYNC(host, TYPE_PROC_REF(/mob, emote), "sneeze")
			else if(prob(2))
				INVOKE_ASYNC(host, TYPE_PROC_REF(/mob, emote), "cough")
			else if(prob(5))
				to_chat(host, span_warning("<i>[pick("Как же хочется есть...", "Вы готовы убить за кусочек еды...", "Вас скручивает от голода...")]</i>"))
			if(prob(5))
				host.adjust_tox_loss(1)
		if(4)
			if(prob(2))
				INVOKE_ASYNC(host, TYPE_PROC_REF(/mob, emote), "stare")
			else if(prob(2))
				INVOKE_ASYNC(host, TYPE_PROC_REF(/mob, emote), "drool")
			else if(prob(5))
				to_chat(host, span_danger("Вас прошибает холодный пот."))
			if(prob(25))
				host.adjust_tox_loss(1)
		if(5, 6)
			var/turf/host_turf = get_turf(host)
			if(host_turf?.get_lumcount() >= 0.5)
				if(prob(5))
					to_chat(host, span_danger("Свет кажется слишком ярким. Он обжигает."))
				if(prob(25))
					host.adjust_fire_loss(2)
			if(prob(2))
				INVOKE_ASYNC(host, TYPE_PROC_REF(/mob, emote), "drool")
			if(stage == 6 && !host.reagents.has_reagent(/datum/reagent/medicine/paradise_zombie_cure/gamma))
				if(prob(10))
					to_chat(host, span_danger("Вы чувствуете, как гниёт ваша плоть."))
				if(prob(10) || host.stat != DEAD)
					handle_rot()
		if(7)
			if(!handle_rot())
				stage = 6
	return TRUE

/** Advances once per minute; dead infected bodies additionally have the original 30% advancement chance. */
/datum/disease/paradise_zombie/proc/handle_stage_advance(has_treatment = FALSE)
	if(!stage_timer)
		COOLDOWN_START(src, stage_timer, 1 MINUTES)
	if(COOLDOWN_FINISHED(src, stage_timer) || (affected_mob.stat == DEAD && prob(30)))
		COOLDOWN_START(src, stage_timer, 1 MINUTES)
		if(!has_treatment)
			stage = min(stage + 1, max_stages)
	if(!discovered && stage >= 4)
		discovered = TRUE
		affected_mob.med_hud_set_status()

/** Regresses one stage per successful cure check, retaining previously achieved treatment levels. */
/datum/disease/paradise_zombie/proc/handle_cure_testing(has_treatment = FALSE)
	if(has_treatment && prob(cure_chance))
		stage = max(stage - 1, 0)
	if(stage <= 0 && has_treatment)
		cure()
		return FALSE
	return TRUE

/** Necrotizes extremities before head/chest, then gives the fully transformed body its tumor and regeneration. */
/datum/disease/paradise_zombie/proc/handle_rot()
	var/mob/living/carbon/human/host = affected_mob
	if(!istype(host) || clearing_infection)
		return FALSE
	for(var/obj/item/bodypart/limb as anything in host.get_bodyparts())
		if(!(limb.bodytype & BODYTYPE_ORGANIC) || (limb.body_zone in list(BODY_ZONE_HEAD, BODY_ZONE_CHEST)))
			continue
		var/datum/component/paradise_zombie_limb/rot = limb.GetComponent(/datum/component/paradise_zombie_limb)
		if(!rot)
			limb.AddComponent(/datum/component/paradise_zombie_limb)
			return FALSE
		rot.necrotize()
		if(rot.infect_limb())
			return FALSE
	for(var/obj/item/bodypart/limb as anything in host.get_bodyparts())
		if(!(limb.bodytype & BODYTYPE_ORGANIC))
			continue
		var/datum/component/paradise_zombie_limb/rot = limb.GetComponent(/datum/component/paradise_zombie_limb)
		if(!rot)
			limb.AddComponent(/datum/component/paradise_zombie_limb)
			return FALSE
		rot.necrotize()
		if(rot.infect_limb())
			return FALSE

	host.LoadComponent(/datum/component/paradise_zombie_regen)
	host.LoadComponent(/datum/component/paradise_zombie_combat)
	ADD_TRAIT(host, TRAIT_PARADISE_ZOMBIE, PARADISE_ZOMBIE_TRAIT)
	ADD_TRAIT(host, TRAIT_BRAINLESS_CARBON, PARADISE_ZOMBIE_TRAIT)
	ADD_TRAIT(host, TRAIT_NOBREATH, PARADISE_ZOMBIE_TRAIT)
	host.become_husk(PARADISE_ZOMBIE_TRAIT)
	if(host.get_bodypart(BODY_ZONE_HEAD) && !host.get_organ_by_type(/obj/item/organ/paradise_zombie_tumor))
		var/obj/item/organ/paradise_zombie_tumor/tumor = new()
		tumor.Insert(host)
	host.med_hud_set_health()
	host.med_hud_set_status()
	host.update_body_parts()
	if(host.mind && !host.mind.has_antag_datum(/datum/antagonist/paradise_zombie))
		var/datum/antagonist/paradise_zombie/antagonist = new()
		if(HAS_TRAIT(host, TRAIT_PARADISE_PLAGUE_ZOMBIE))
			antagonist.chosen_disease = plague_disease
			antagonist.silent = TRUE
		host.mind.add_antag_datum(antagonist)
	if(GLOB.paradise_zombie_mutation_progression.is_mature_zombie(host))
		host.LoadComponent(/datum/component/paradise_zombie_mutation)
	host.LoadComponent(/datum/component/paradise_zombie_appearance)
	return TRUE

/** Remembers exposure to an anti-plague sequence in the body and updates this strain's research name. */
/datum/disease/paradise_zombie/proc/update_cure_stage()
	for(var/datum/reagent/medicine/paradise_zombie_cure/medicine in affected_mob?.reagents?.reagent_list)
		cure_stage = max(cure_stage, medicine.cure_level)
	if(cure_stage)
		var/static/list/stage_names = list("Стабилизированная", "Ослабленная", "Угасающая", "Подавленная")
		name = "[stage_names[cure_stage]] [LOWER_TEXT(initial(name))]"

/datum/disease/paradise_zombie/has_cure()
	update_cure_stage()
	return cure_stage >= (stage + 1) / 2

/datum/disease/paradise_zombie/cure(add_resistance = FALSE)
	if(clearing_infection)
		return
	clear_zombie_effects()
	return ..(add_resistance = FALSE)

/** Removes only this plague's effects, including on direct deletion and surgical tumor extraction. */
/datum/disease/paradise_zombie/proc/clear_zombie_effects()
	clearing_infection = TRUE
	var/mob/living/carbon/human/host = affected_mob
	if(!istype(host) || QDELETED(host))
		return
	qdel(host.GetComponent(/datum/component/paradise_zombie_appearance))
	qdel(host.GetComponent(/datum/component/paradise_zombie_mutation))
	for(var/obj/item/paradise_zombie_claw/claw in host.get_held_items())
		qdel(claw)
	host.mind?.remove_antag_datum(/datum/antagonist/wizard_minion/paradise_plague_zombie)
	host.mind?.remove_antag_datum(/datum/antagonist/paradise_zombie)
	REMOVE_TRAIT(host, TRAIT_PARADISE_PLAGUE_ZOMBIE, PARADISE_ZOMBIE_TRAIT)
	REMOVE_TRAIT(host, TRAIT_PARADISE_NON_INFECTIOUS_ZOMBIE, PARADISE_ZOMBIE_TRAIT)
	REMOVE_TRAIT(host, TRAIT_VIRUSIMMUNE, PARADISE_ZOMBIE_TRAIT)
	REMOVE_TRAIT(host, TRAIT_PARADISE_ZOMBIE, PARADISE_ZOMBIE_TRAIT)
	REMOVE_TRAIT(host, TRAIT_BRAINLESS_CARBON, PARADISE_ZOMBIE_TRAIT)
	REMOVE_TRAIT(host, TRAIT_NOBREATH, PARADISE_ZOMBIE_TRAIT)
	host.cure_husk(PARADISE_ZOMBIE_TRAIT)
	for(var/obj/item/bodypart/limb as anything in host.get_bodyparts())
		var/datum/component/paradise_zombie_limb/rot = limb.GetComponent(/datum/component/paradise_zombie_limb)
		if(rot?.infected)
			qdel(rot)
	for(var/obj/item/organ/paradise_zombie_tumor/tumor in host.organs.Copy())
		tumor.Remove(host)
	qdel(host.GetComponent(/datum/component/paradise_zombie_regen))
	qdel(host.GetComponent(/datum/component/paradise_zombie_combat))
	host.update_body_parts()
	host.med_hud_set_health()
	host.med_hud_set_status()

/** Wizard plague zombies are noncontagious and resist ordinary disease-removal effects. */
/datum/disease/paradise_zombie/wizard
	spread_flags = DISEASE_SPREAD_NON_CONTAGIOUS
	bypasses_immunity = TRUE
	spread_text = "Не передаётся"
	cure_text = "Антимагия"

/datum/disease/paradise_zombie/wizard/cure(add_resistance = FALSE)
	return
