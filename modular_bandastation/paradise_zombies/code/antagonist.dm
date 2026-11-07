/** The antagonist is attached to a mind; the infection and necrotic tissue belong to its body. */
/datum/antagonist/paradise_zombie
	name = "Зомби"
	roundend_category = "Зомби"
	antagpanel_category = ANTAG_GROUP_ABOMINATIONS
	pref_flag = ROLE_ZOMBIE
	antag_hud_name = "hudzombie"
	hud_icon = 'modular_bandastation/paradise_zombies/icons/antaghud.dmi'
	show_to_ghosts = TRUE
	stinger_sound = 'modular_bandastation/paradise_zombies/sound/zomboidalert.ogg'
	/// Granted actions are owned by this antagonist, including across mind transfers.
	var/list/zombie_actions = list()
	/// Guards cleanup when a mind leaves an infected body for an uninfected one.
	var/datum/weakref/applied_body_ref

/datum/antagonist/paradise_zombie/can_be_owned(datum/mind/new_owner)
	var/datum/mind/tested = new_owner || owner
	return ishuman(tested?.current) && ..()

/datum/antagonist/paradise_zombie/on_gain()
	if(!HAS_TRAIT(owner.current, TRAIT_PARADISE_PLAGUE_ZOMBIE))
		var/datum/objective/paradise_zombie/objective = new
		objective.owner = owner
		objectives += objective
	return ..()

/datum/antagonist/paradise_zombie/Destroy()
	QDEL_LIST(zombie_actions)
	return ..()

/datum/antagonist/paradise_zombie/greet()
	if(HAS_TRAIT(owner.current, TRAIT_PARADISE_PLAGUE_ZOMBIE))
		return
	. = ..()
	to_chat(owner.current, "<span class='userdanger zombie'>Мы — зомби!</span>")
	to_chat(owner.current, span_notice("Когтями можно ломать двери и вскрывать повреждённые черепа. Когда череп вскрыт, атакуйте жертву пустой рукой, чтобы съесть её мозг. Также можно крепко схватить жертву и атаковать её, чтобы укусить и заразить. В темноте вы восстанавливаетесь быстрее. После смерти ваше тело постепенно восстанавливается, и вы оживаете."))
	owner.announce_objectives()

/datum/antagonist/paradise_zombie/apply_innate_effects(mob/living/mob_override)
	. = ..()
	var/mob/living/carbon/human/zombie = mob_override || owner.current
	if(!istype(zombie))
		return
	applied_body_ref = WEAKREF(zombie)
	handle_clown_mutation(zombie, "М-мо-о-озги... Хонк...", removing = TRUE)
	ADD_TRAIT(zombie, TRAIT_NOBREATH, REF(src))
	MODIFY_PHYSIOLOGY(zombie, STAMINA, 0.5)
	zombie.LoadComponent(/datum/component/paradise_zombie_combat)
	RegisterSignal(zombie, COMSIG_LIVING_SET_BODY_POSITION, PROC_REF(update_slowdown))
	update_slowdown(zombie, zombie.body_position)
	var/datum/disease/paradise_zombie/infection = locate() in zombie.diseases
	var/datum/action/cooldown/paradise_zombie_claws/claws
	if(HAS_TRAIT(zombie, TRAIT_PARADISE_PLAGUE_ZOMBIE))
		claws = new /datum/action/cooldown/paradise_zombie_claws/plague
		claws.disease = infection?.plague_disease
		var/datum/action/cooldown/paradise_zombie_leap/leap = new
		leap.Grant(zombie)
		zombie_actions += leap
	else
		claws = new
		shadow_demon_extinguish(zombie)
	claws.Grant(zombie)
	zombie_actions += claws
	if(!infection)
		infection = new
		infection.stage = 7
		infection.infect(zombie, FALSE)
	add_team_hud(zombie)

/datum/antagonist/paradise_zombie/remove_innate_effects(mob/living/mob_override)
	. = ..()
	var/mob/living/carbon/human/zombie = mob_override || owner.current
	QDEL_LIST(zombie_actions)
	if(!istype(zombie) || applied_body_ref?.resolve() != zombie)
		return
	applied_body_ref = null
	if(length(owner.antag_datums) <= 1)
		handle_clown_mutation(zombie, "К вам возвращается чувство юмора.", removing = FALSE)
	REMOVE_TRAIT(zombie, TRAIT_NOBREATH, REF(src))
	MODIFY_PHYSIOLOGY(zombie, STAMINA, 2)
	UnregisterSignal(zombie, COMSIG_LIVING_SET_BODY_POSITION)
	zombie.remove_movespeed_modifier(/datum/movespeed_modifier/paradise_zombie)
	if(!HAS_TRAIT(zombie, TRAIT_PARADISE_ZOMBIE))
		qdel(zombie.GetComponent(/datum/component/paradise_zombie_combat))
	QDEL_NULL(team_hud_ref)

/datum/antagonist/paradise_zombie/on_body_transfer(mob/living/old_body, mob/living/new_body)
	var/datum/disease/paradise_zombie/infection = locate() in new_body.diseases
	if(!infection)
		if(old_body)
			remove_innate_effects(old_body)
			if(old_body.stat != DEAD && !LAZYLEN(old_body.mind?.antag_datums))
				old_body.remove_from_current_living_antags()
		owner.remove_antag_datum(type)
		return
	return ..()

/datum/antagonist/paradise_zombie/proc/update_slowdown(mob/living/source, new_position)
	SIGNAL_HANDLER
	if(new_position == STANDING_UP)
		source.add_movespeed_modifier(/datum/movespeed_modifier/paradise_zombie)
	else
		source.remove_movespeed_modifier(/datum/movespeed_modifier/paradise_zombie)

/datum/movespeed_modifier/paradise_zombie
	multiplicative_slowdown = 1

/datum/objective/paradise_zombie
	name = "Распространить чуму"
	objective_name = "Цель"
	explanation_text = "Пожирайте мозги и распространяйте заразу."
	completed = TRUE
	no_failure = TRUE
