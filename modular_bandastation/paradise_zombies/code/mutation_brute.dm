/** Dragon-style wall damage with cancellation owned by the physical Brute form. */
/datum/action/cooldown/paradise_zombie_mutation/tear_wall
	name = "Выломать стену"
	desc = "Выломать соседнюю стену в три этапа: обычную за 4 секунды, укреплённую за 12. Можно двигаться рядом со стеной; отход, потеря сознания и лечение прерывают работу."
	button_icon_state = "mutate"
	required_form = "brute"
	cooldown_time = 0
	click_to_activate = TRUE
	/// Keep the lock until the original yielding call returns, including after cancellation.
	var/tearing = FALSE
	var/cancel_requested = FALSE
	var/datum/weakref/tearing_mind_ref

/datum/action/cooldown/paradise_zombie_mutation/tear_wall/clear_effects()
	cancel_requested = TRUE
	return ..()

/// Match Dragon's target family while preserving this form's ownership after every yield.
/datum/action/cooldown/paradise_zombie_mutation/tear_wall/proc/can_tear(atom/target)
	var/mob/living/carbon/human/user = owner
	return tearing && !cancel_requested && is_active() && !IS_UNCONSCIOUS_OR_CRIT(user) && !user.incapacitated \
		&& user.body_position == STANDING_UP && isturf(user.loc) && user.Adjacent(target) \
		&& user.mind && user.mind.current == user && tearing_mind_ref?.resolve() == user.mind \
		&& isclosedturf(target) && !isindestructiblewall(target)

/datum/action/cooldown/paradise_zombie_mutation/tear_wall/Activate(atom/target)
	if(tearing || !IsAvailable())
		return FALSE
	var/mob/living/carbon/human/user = owner
	if(!user.mind || user.mind.current != user)
		return FALSE
	tearing = TRUE
	cancel_requested = FALSE
	tearing_mind_ref = WEAKREF(user.mind)
	var/completed = FALSE
	for(var/step in 1 to 3)
		if(!can_tear(target))
			break
		var/rip_time = (istype(target, /turf/closed/wall/r_wall) ? 12 SECONDS : 4 SECONDS) / 3
		user.visible_message(span_warning("[capitalize(user.declent_ru(NOMINATIVE))] начинает выламывать [target.declent_ru(ACCUSATIVE)]!"))
		playsound(user, 'sound/machines/airlock/airlock_alien_prying.ogg', 100, TRUE)
		target.balloon_alert(user, "выламываем...")
		var/finished_step = do_after(user, rip_time, target = target, timed_action_flags = IGNORE_USER_LOC_CHANGE, extra_checks = CALLBACK(src, PROC_REF(can_tear), target), interaction_key = src)
		if(QDELETED(src))
			return FALSE
		if(!finished_step || !can_tear(target))
			break
		user.do_attack_animation(target)
		target.AddComponent(/datum/component/torn_wall)
		if(QDELETED(target) || !isclosedturf(target))
			completed = TRUE
			break
	tearing = FALSE
	tearing_mind_ref = null
	return completed
