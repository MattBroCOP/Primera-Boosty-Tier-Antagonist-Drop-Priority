/** A lower zombie's short rally; victims own their residue so different screams only refresh it. */
/datum/action/cooldown/paradise_zombie_scream
	name = "Голодный крик"
	desc = "На 10 секунд увеличить свою скорость на 10% и замедлить живых незаражённых в пределах видимости до 5 клеток на 10%. Повторные крики не складываются."
	button_icon = 'icons/mob/actions/actions_spells.dmi'
	button_icon_state = "scream_for_me"
	check_flags = AB_CHECK_CONSCIOUS|AB_CHECK_INCAPACITATED
	cooldown_time = 30 SECONDS
	var/datum/status_effect/paradise_zombie_scream/haste/haste

/datum/action/cooldown/paradise_zombie_scream/Grant(mob/granted_to)
	var/mob/previous_owner = owner
	. = ..()
	if(owner && owner != previous_owner)
		RegisterSignals(owner, list(COMSIG_LIVING_DEATH, COMSIG_MOB_MIND_TRANSFERRED_INTO, COMSIG_MOB_MIND_TRANSFERRED_OUT_OF), PROC_REF(clear_haste))

/datum/action/cooldown/paradise_zombie_scream/Remove(mob/removed_from)
	clear_haste()
	UnregisterSignal(removed_from, list(COMSIG_LIVING_DEATH, COMSIG_MOB_MIND_TRANSFERRED_INTO, COMSIG_MOB_MIND_TRANSFERRED_OUT_OF))
	return ..()

/datum/action/cooldown/paradise_zombie_scream/Destroy()
	clear_haste()
	return ..()

/datum/action/cooldown/paradise_zombie_scream/IsAvailable(feedback = FALSE)
	var/datum/component/paradise_zombie_regen/regeneration = target
	if(QDELETED(regeneration) || regeneration.parent != owner || !HAS_TRAIT(owner, TRAIT_PARADISE_ZOMBIE))
		return FALSE
	var/datum/component/paradise_zombie_mutation/controller = owner.GetComponent(/datum/component/paradise_zombie_mutation)
	return !controller?.form && ..()

/datum/action/cooldown/paradise_zombie_scream/Activate(atom/target)
	if(!IsAvailable() || !isturf(owner.loc))
		return FALSE
	var/mob/living/carbon/human/user = owner
	clear_haste()
	haste = user.apply_status_effect(/datum/status_effect/paradise_zombie_scream/haste)
	if(QDELETED(haste))
		return FALSE
	StartCooldown()
	owner.visible_message(span_danger("[owner] издаёт голодный крик!"))
	playsound(owner, 'modular_bandastation/paradise_zombies/sound/zomboidalert.ogg', 70, TRUE)
	for(var/mob/living/victim in view(5, owner))
		if(victim != owner)
			victim.apply_status_effect(/datum/status_effect/paradise_zombie_scream/fear)
	return TRUE

/datum/action/cooldown/paradise_zombie_scream/proc/clear_haste()
	SIGNAL_HANDLER
	QDEL_NULL(haste)

/datum/status_effect/paradise_zombie_scream
	id = STATUS_EFFECT_ID_ABSTRACT
	duration = 10 SECONDS
	tick_interval = 1 SECONDS
	status_type = STATUS_EFFECT_REFRESH
	alert_type = null
	var/modifier_type

/datum/status_effect/paradise_zombie_scream/on_apply()
	owner.add_movespeed_modifier(modifier_type)
	RegisterSignal(owner, COMSIG_LIVING_DEATH, PROC_REF(end_effect))
	return TRUE

/datum/status_effect/paradise_zombie_scream/on_remove()
	owner.remove_movespeed_modifier(modifier_type)
	UnregisterSignal(owner, COMSIG_LIVING_DEATH)

/datum/status_effect/paradise_zombie_scream/proc/end_effect()
	SIGNAL_HANDLER
	qdel(src)

/datum/status_effect/paradise_zombie_scream/haste
	id = "paradise_zombie_scream_haste"
	modifier_type = /datum/movespeed_modifier/paradise_zombie_scream_haste

/datum/status_effect/paradise_zombie_scream/haste/on_apply()
	if(!HAS_TRAIT(owner, TRAIT_PARADISE_ZOMBIE))
		return FALSE
	return ..()

/datum/status_effect/paradise_zombie_scream/haste/tick(seconds_between_ticks)
	if(!HAS_TRAIT(owner, TRAIT_PARADISE_ZOMBIE))
		qdel(src)

/datum/status_effect/paradise_zombie_scream/fear
	id = "paradise_zombie_scream_fear"
	modifier_type = /datum/movespeed_modifier/paradise_zombie_scream_fear

/datum/status_effect/paradise_zombie_scream/fear/proc/is_susceptible()
	return owner.stat != DEAD && !HAS_TRAIT(owner, TRAIT_PARADISE_ZOMBIE) && !(locate(/datum/disease/paradise_zombie) in owner.diseases)

/datum/status_effect/paradise_zombie_scream/fear/on_apply()
	return is_susceptible() && ..()

/datum/status_effect/paradise_zombie_scream/fear/tick(seconds_between_ticks)
	if(!is_susceptible())
		qdel(src)

/datum/status_effect/paradise_zombie_scream/fear/refresh(effect, ...)
	if(!is_susceptible())
		qdel(src)
		return
	return ..()

/datum/movespeed_modifier/paradise_zombie_scream_haste
	delay_multiplier = 1 / 1.1
	flags = IGNORE_NOSLOW

/datum/movespeed_modifier/paradise_zombie_scream_fear
	delay_multiplier = 1 / 0.9
