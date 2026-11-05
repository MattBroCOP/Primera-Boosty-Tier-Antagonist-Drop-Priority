GLOBAL_DATUM_INIT(paradise_zombie_mutation_progression, /datum/paradise_zombie_mutation_progression, new)

/** Unlocks forms from the current outbreak and reserves rare forms on physical infected bodies. */
/datum/paradise_zombie_mutation_progression
	/// The first ordinary infection starts the clock, including an infection at world.time zero.
	var/first_infection_at
	/// Weak body references map to a reserved form ID, or null for an ordinary mature zombie.
	var/list/zombie_bodies = list()
	/// Pending reservations remember the choosing mind until its form has successfully applied.
	var/list/claiming_minds = list()
	/// Weak mind references retain their one permitted form across cures and body transfers.
	var/list/fixed_choices = list()

/** Starts the outbreak clock for an infected mind, without advancing it again on reinfection. */
/datum/paradise_zombie_mutation_progression/proc/note_infection(mob/living/carbon/human/host)
	if(!is_ordinary_infection(host) || HAS_TRAIT(host, TRAIT_PARADISE_NPC_ZOMBIE))
		return FALSE
	if(!host.mind || QDELETED(host.mind) || host.mind.current != host)
		return FALSE
	if(isnull(first_infection_at))
		first_infection_at = world.time
	return TRUE

/** Registers transformed bodies once; a corpse's existing reservation is never overwritten. */
/datum/paradise_zombie_mutation_progression/proc/register_zombie(mob/living/carbon/human/host)
	if(!is_mature_zombie(host))
		return FALSE
	if(isnull(first_infection_at) && host.mind && !QDELETED(host.mind) && host.mind.current == host)
		note_infection(host)
	var/datum/weakref/body_ref = WEAKREF(host)
	if(!(body_ref in zombie_bodies))
		zombie_bodies[body_ref] = null
	return TRUE

/** Returns current population, elapsed ticks, unlock tier and occupied physical-body limits. */
/datum/paradise_zombie_mutation_progression/proc/get_progress()
	var/list/current_minds = list()
	var/special_claimed = 0
	var/brute_claimed = 0
	for(var/datum/weakref/body_ref as anything in zombie_bodies.Copy())
		var/mob/living/carbon/human/host = body_ref.resolve()
		if(!is_mature_zombie(host))
			zombie_bodies -= body_ref
			claiming_minds -= body_ref
			continue
		if(host.mind && !QDELETED(host.mind) && host.mind.current == host)
			current_minds |= host.mind
		var/form_id = zombie_bodies[body_ref]
		if(form_id && form_id != "slasher")
			special_claimed++
			if(form_id == "brute")
				brute_claimed++
	for(var/datum/weakref/mind_ref as anything in fixed_choices.Copy())
		if(!mind_ref.resolve())
			fixed_choices -= mind_ref
	var/zombies = length(current_minds)
	var/elapsed = isnull(first_infection_at) ? 0 : max(0, world.time - first_infection_at)
	var/tier = 0
	if(zombies >= 1 && elapsed >= 2 MINUTES)
		tier = 1
	if(zombies >= 4 && elapsed >= 10 MINUTES)
		tier = 2
	if(zombies >= 8 && elapsed >= 20 MINUTES)
		tier = 3
	return list(
		"tier" = tier,
		"zombies" = zombies,
		"elapsed" = elapsed,
		"special_limit" = max(1, FLOOR(zombies / 4, 1)),
		"brute_limit" = max(1, FLOOR(zombies / 8, 1)),
		"special_claimed" = special_claimed,
		"brute_claimed" = brute_claimed,
	)

/datum/paradise_zombie_mutation_progression/proc/can_choose(mob/living/carbon/human/host, form_id)
	return isnull(get_unavailability_reason(host, form_id))

/** Every final claim repeats these checks after the player's selection dialog has yielded. */
/datum/paradise_zombie_mutation_progression/proc/get_unavailability_reason(mob/living/carbon/human/host, form_id)
	var/datum/paradise_zombie_form/form = get_paradise_zombie_form(form_id)
	if(!form)
		return "Неизвестная мутация."
	if(!is_mature_zombie(host))
		return "Нужно полностью превратиться в обычного зомби."
	if(!host.mind || QDELETED(host.mind) || host.mind.current != host)
		return "У тела нет действующего разума."
	var/datum/weakref/mind_ref = WEAKREF(host.mind)
	if(fixed_choices[mind_ref] && fixed_choices[mind_ref] != form_id)
		return "Этот разум уже выбрал другую мутацию."
	var/list/progress = get_progress()
	var/datum/weakref/body_ref = WEAKREF(host)
	var/reserved_form = zombie_bodies[body_ref]
	if(reserved_form)
		if(claiming_minds[body_ref] != mind_ref)
			return "Мутация этого тела уже закреплена за другим выбором."
		return reserved_form == form_id ? null : "Это тело уже занимает место другой мутации."
	if(form.tier > progress["tier"])
		var/requirements
		switch(form.tier)
			if(1)
				requirements = "1 обычный зомби и 2 минуты с первого заражения"
			if(2)
				requirements = "4 обычных зомби и 10 минут с первого заражения"
			if(3)
				requirements = "8 обычных зомби и 20 минут с первого заражения"
		return "Для этой формы нужны [requirements]. Сейчас зомби: [progress["zombies"]]; прошло [FLOOR(progress["elapsed"] / (1 MINUTES), 1)] мин."
	if(form_id != "slasher" && progress["special_claimed"] >= progress["special_limit"])
		return "Все места для особых мутаций заняты."
	if(form_id == "brute" && progress["brute_claimed"] >= progress["brute_limit"])
		return "Все места для Брутов заняты."
	return null

/** Reserves synchronously before applying a form; it does not spend the mind's fixed choice. */
/datum/paradise_zombie_mutation_progression/proc/claim(mob/living/carbon/human/host, form_id)
	if(!can_choose(host, form_id))
		return FALSE
	var/datum/weakref/body_ref = WEAKREF(host)
	if(!zombie_bodies[body_ref])
		zombie_bodies[body_ref] = form_id
		claiming_minds[body_ref] = WEAKREF(host.mind)
	return TRUE

/** Commits only after successful application, while the original choosing mind still owns the body. */
/datum/paradise_zombie_mutation_progression/proc/commit_choice(mob/living/carbon/human/host, form_id)
	if(!is_mature_zombie(host) || !host.mind || QDELETED(host.mind) || host.mind.current != host)
		return FALSE
	var/datum/weakref/body_ref = WEAKREF(host)
	var/datum/weakref/mind_ref = WEAKREF(host.mind)
	if(zombie_bodies[body_ref] != form_id || claiming_minds[body_ref] != mind_ref)
		return FALSE
	if(fixed_choices[mind_ref] && fixed_choices[mind_ref] != form_id)
		return FALSE
	fixed_choices[mind_ref] = form_id
	return TRUE

/** Releases a form after failure or cure, retaining a still-infected body's population registration. */
/datum/paradise_zombie_mutation_progression/proc/release_body(mob/living/carbon/human/host)
	var/datum/weakref/body_ref = WEAKREF(host)
	if(!body_ref)
		return
	claiming_minds -= body_ref
	if(is_mature_zombie(host))
		zombie_bodies[body_ref] = null
	else
		zombie_bodies -= body_ref

/datum/paradise_zombie_mutation_progression/proc/is_ordinary_infection(mob/living/carbon/human/host)
	if(!istype(host) || QDELETED(host) || HAS_TRAIT(host, TRAIT_PARADISE_PLAGUE_ZOMBIE) || HAS_TRAIT(host, TRAIT_PARADISE_NON_INFECTIOUS_ZOMBIE))
		return FALSE
	var/datum/disease/paradise_zombie/infection = locate() in host.diseases
	return infection && !QDELETED(infection) && !infection.clearing_infection && !istype(infection, /datum/disease/paradise_zombie/wizard)

/datum/paradise_zombie_mutation_progression/proc/is_mature_zombie(mob/living/carbon/human/host)
	return is_ordinary_infection(host) && HAS_TRAIT(host, TRAIT_PARADISE_ZOMBIE)
