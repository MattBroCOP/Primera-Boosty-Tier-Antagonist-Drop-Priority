/** A second Hunter leap uses the existing scoped flight and claw impact, then briefly pins its victim. */
/datum/action/cooldown/paradise_zombie_mutation/dash/pounce/pin
	name = "Прыжок с захватом"
	desc = "С выпущенными когтями прыгнуть до 10 клеток и прижать жертву максимум на четыре секунды, нанося 3 единицы урона в секунду до учёта брони. Сопротивление, помощь союзника, ваше движение или полученный урон прерывают захват."
	button_icon_state = "the_traps"

/datum/action/cooldown/paradise_zombie_mutation/dash/pounce/pin/is_active()
	return ..() && !HAS_TRAIT(owner, TRAIT_PACIFISM)

/datum/action/cooldown/paradise_zombie_mutation/dash/pounce/pin/IsAvailable(feedback = FALSE)
	if(!..())
		return FALSE
	if(!istype(owner.get_active_held_item(), /obj/item/paradise_zombie_claw))
		if(feedback)
			owner.balloon_alert(owner, "выпустите когти!")
		return FALSE
	return TRUE

/datum/action/cooldown/paradise_zombie_mutation/dash/pounce/pin/on_pounce_hit(mob/living/carbon/human/user, mob/living/victim)
	if(owner != user || !can_hit(victim))
		return
	var/datum/status_effect/paradise_zombie_pin/pin = victim.apply_status_effect(/datum/status_effect/paradise_zombie_pin, src, user)
	if(!pin)
		return
	track_effect(pin)
	show_pounce_impact(user, victim)
	log_combat(user, victim, "прижал прыжком (мутация зомби Paradise)")

/** The victim owns this short grace period, so removing a captor cannot refund a second capture. */
/datum/status_effect/paradise_zombie_pin_recovery
	id = "paradise_zombie_pin_recovery"
	duration = 2 SECONDS
	tick_interval = STATUS_EFFECT_NO_TICK
	alert_type = null

/** One bounded, source-owned hold shared by zombie attacks; it never suppresses the native Resist verb. */
/datum/status_effect/paradise_zombie_pin
	id = "paradise_zombie_pin"
	duration = 4 SECONDS
	tick_interval = 1 SECONDS
	alert_type = /atom/movable/screen/alert/status_effect/paradise_zombie_pin
	show_duration = TRUE
	on_remove_on_mob_delete = TRUE
	var/datum/weakref/action_ref
	var/datum/weakref/captor_ref
	var/list/captor_damage
	var/pin_applied = FALSE
	var/damage_per_second = 3

/datum/status_effect/paradise_zombie_pin/on_creation(mob/living/new_owner, datum/action/cooldown/paradise_zombie_mutation/action, mob/living/captor, hold_duration = 4 SECONDS, damage_per_second = 3)
	action_ref = WEAKREF(action)
	captor_ref = WEAKREF(captor)
	duration = clamp(hold_duration, 1 SECONDS, 4 SECONDS)
	src.damage_per_second = max(0, damage_per_second)
	return ..()

/datum/status_effect/paradise_zombie_pin/on_apply()
	if(owner.has_status_effect(/datum/status_effect/paradise_zombie_pin_recovery) || !valid_hold())
		return FALSE
	var/mob/living/captor = captor_ref.resolve()
	captor_damage = damage_snapshot(captor)
	RegisterSignals(captor, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_DEATH, COMSIG_MOB_MIND_TRANSFERRED_INTO, COMSIG_MOB_MIND_TRANSFERRED_OUT_OF, COMSIG_QDELETING), PROC_REF(on_interrupted))
	RegisterSignal(captor, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_captor_hurt))
	RegisterSignal(captor, SIGNAL_ADDTRAIT(TRAIT_INCAPACITATED), PROC_REF(on_interrupted))
	RegisterSignal(captor, COMSIG_LIVING_SET_BODY_POSITION, PROC_REF(on_captor_posture))
	RegisterSignals(captor, list(COMSIG_LIVING_HEALTH_UPDATE, COMSIG_LIVING_STAMINA_UPDATE), PROC_REF(on_captor_health_changed))
	RegisterSignals(owner, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_DEATH, COMSIG_MOB_MIND_TRANSFERRED_INTO, COMSIG_MOB_MIND_TRANSFERRED_OUT_OF), PROC_REF(on_interrupted))
	RegisterSignal(owner, COMSIG_LIVING_RESIST, PROC_REF(on_resist))
	RegisterSignal(owner, COMSIG_CARBON_PRE_MISC_HELP, PROC_REF(on_helped))
	pin_applied = TRUE
	owner.add_traits(list(TRAIT_IMMOBILIZED, TRAIT_FLOORED, TRAIT_HANDS_BLOCKED), REF(src))
	owner.balloon_alert_to_viewers("прижат!")
	return TRUE

/datum/status_effect/paradise_zombie_pin/proc/valid_hold()
	var/datum/action/cooldown/paradise_zombie_mutation/action = action_ref?.resolve()
	var/mob/living/captor = captor_ref?.resolve()
	return action?.is_active() && action.owner == captor && !QDELETED(captor) && !IS_UNCONSCIOUS_OR_CRIT(captor) && !captor.incapacitated && captor.body_position == STANDING_UP && action.can_hit(owner) && isturf(captor.loc) && isturf(owner.loc) && captor.Adjacent(owner)

/datum/status_effect/paradise_zombie_pin/tick(seconds_between_ticks)
	if(!valid_hold())
		qdel(src)
		return
	on_captor_health_changed()
	if(QDELETED(src))
		return
	if(damage_per_second)
		var/blocked = owner.run_armor_check(BODY_ZONE_CHEST, MELEE, silent = TRUE)
		owner.apply_damage(damage_per_second * seconds_between_ticks, BRUTE, BODY_ZONE_CHEST, blocked = blocked, wound_bonus = CANT_WOUND)

/datum/status_effect/paradise_zombie_pin/proc/on_interrupted()
	SIGNAL_HANDLER
	qdel(src)

/datum/status_effect/paradise_zombie_pin/proc/on_captor_posture(mob/living/source, new_position)
	SIGNAL_HANDLER
	if(new_position != STANDING_UP)
		qdel(src)

/datum/status_effect/paradise_zombie_pin/proc/on_resist()
	SIGNAL_HANDLER
	qdel(src)
	return COMPONENT_BLOCK_RESIST

/datum/status_effect/paradise_zombie_pin/proc/on_helped(mob/living/source, mob/living/helper)
	SIGNAL_HANDLER
	if(QDELETED(helper) || helper == owner || helper == captor_ref?.resolve() || !helper.Adjacent(owner))
		return
	qdel(src)
	return COMPONENT_BLOCK_MISC_HELP

/datum/status_effect/paradise_zombie_pin/proc/on_captor_hurt(mob/living/source, damage)
	SIGNAL_HANDLER
	if(damage > 0)
		qdel(src)

/// Raw damage adjustments also include fire and stamina damage that does not pass through apply_damage().
/datum/status_effect/paradise_zombie_pin/proc/damage_snapshot(mob/living/captor)
	return list(captor.get_brute_loss(), captor.get_fire_loss(), captor.get_tox_loss(), captor.get_oxy_loss(), captor.get_stamina_loss())

/datum/status_effect/paradise_zombie_pin/proc/on_captor_health_changed()
	SIGNAL_HANDLER
	var/mob/living/captor = captor_ref?.resolve()
	if(QDELETED(captor))
		qdel(src)
		return
	var/list/current_damage = damage_snapshot(captor)
	for(var/index in 1 to length(current_damage))
		if(current_damage[index] > captor_damage[index])
			qdel(src)
			return
	captor_damage = current_damage

/datum/status_effect/paradise_zombie_pin/on_remove()
	var/mob/living/captor = captor_ref?.resolve()
	if(captor)
		UnregisterSignal(captor, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_DEATH, COMSIG_MOB_MIND_TRANSFERRED_INTO, COMSIG_MOB_MIND_TRANSFERRED_OUT_OF, COMSIG_QDELETING, COMSIG_MOB_AFTER_APPLY_DAMAGE, COMSIG_LIVING_HEALTH_UPDATE, COMSIG_LIVING_STAMINA_UPDATE, SIGNAL_ADDTRAIT(TRAIT_INCAPACITATED), COMSIG_LIVING_SET_BODY_POSITION))
	UnregisterSignal(owner, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_DEATH, COMSIG_MOB_MIND_TRANSFERRED_INTO, COMSIG_MOB_MIND_TRANSFERRED_OUT_OF, COMSIG_LIVING_RESIST, COMSIG_CARBON_PRE_MISC_HELP))
	if(pin_applied)
		owner.remove_traits(list(TRAIT_IMMOBILIZED, TRAIT_FLOORED, TRAIT_HANDS_BLOCKED), REF(src))
		if(!QDELETED(owner) && owner.stat != DEAD)
			owner.apply_status_effect(/datum/status_effect/paradise_zombie_pin_recovery)
	action_ref = null
	captor_ref = null
	captor_damage = null
	return ..()

/atom/movable/screen/alert/status_effect/paradise_zombie_pin
	name = "Прижат зомби"
	desc = "Зомби удерживает вас. Нажмите «Сопротивляться» или попросите союзника помочь."
	icon_state = "buckled"
