/** A separate straight charge retains Twitcher's original repositioning dash. */
/datum/action/cooldown/paradise_zombie_mutation/dash/charge
	name = "Таран"
	desc = "Протаранить до 12 клеток до первой преграды: ударить врага на 20 физического урона до учёта брони и прижать максимум на 2 секунды. Сопротивление, помощь союзника, наше движение или полученный урон освобождают жертву. Перезарядка — 20 секунд."
	cooldown_time = 20 SECONDS

/datum/action/cooldown/paradise_zombie_mutation/dash/charge/is_active()
	return ..() && !HAS_TRAIT(owner, TRAIT_PACIFISM)

/datum/action/cooldown/paradise_zombie_mutation/dash/charge/Activate(atom/target)
	var/mob/living/carbon/human/user = owner
	var/turf/destination = get_turf(target)
	if(!IsAvailable() || !destination || destination.z != user.z || destination == user.loc || !isturf(user.loc) || user.throwing || user.buckled)
		return FALSE
	if(isliving(target))
		var/mob/living/victim = target
		if(!can_hit(victim) || victim.has_status_effect(/datum/status_effect/paradise_zombie_pin) || victim.has_status_effect(/datum/status_effect/paradise_zombie_pin_recovery))
			return FALSE
	if(!user.throw_at(target, travel_range, 2, spin = FALSE, gentle = TRUE, quickstart = FALSE, throw_type_path = /datum/thrownthing/paradise_zombie_leap/mutation/charger))
		return FALSE
	var/datum/thrownthing/paradise_zombie_leap/mutation/charger/flight = user.throwing
	flight.action_ref = WEAKREF(src)
	track_effect(flight)
	playsound(user, 'sound/items/weapons/punchmiss.ogg', 40, TRUE)
	StartCooldown()
	return TRUE

/// Apply the impact only after native landing, so landing movement cannot instantly break the hold.
/datum/action/cooldown/paradise_zombie_mutation/dash/charge/proc/on_charge_landed(mob/living/carbon/human/user, mob/living/victim)
	if(user != owner || !can_hit(victim) || !user.Adjacent(victim))
		return
	if(victim.check_block(user, 20, "таран", attack_type = LEAP_ATTACK))
		return
	var/blocked = victim.run_armor_check(BODY_ZONE_CHEST, MELEE)
	victim.apply_damage(20, BRUTE, BODY_ZONE_CHEST, blocked = blocked, wound_bonus = CANT_WOUND)
	if(blocked >= 100 || !can_hit(victim) || victim.has_status_effect(/datum/status_effect/paradise_zombie_pin) || victim.has_status_effect(/datum/status_effect/paradise_zombie_pin_recovery))
		return
	var/datum/status_effect/paradise_zombie_pin/pin = victim.apply_status_effect(/datum/status_effect/paradise_zombie_pin, src, user, 2 SECONDS, 0)
	if(pin)
		track_effect(pin)
	log_combat(user, victim, "протаранил (мутация зомби Paradise)")

/** Scoped native collisions stop the body without invoking the original plague leap's wall destruction. */
/datum/thrownthing/paradise_zombie_leap/mutation/charger
	var/datum/weakref/first_victim_ref
	var/impact_resolved = FALSE

/datum/thrownthing/paradise_zombie_leap/mutation/charger/Destroy()
	first_victim_ref = null
	return ..()

/datum/thrownthing/paradise_zombie_leap/mutation/charger/hit_target(mob/living/carbon/human/user, atom/target)
	var/datum/action/cooldown/paradise_zombie_mutation/dash/charge/action = action_ref?.resolve()
	if(!impact_resolved && !first_victim_ref && isliving(target) && action?.can_hit(target))
		first_victim_ref = WEAKREF(target)

/datum/thrownthing/paradise_zombie_leap/mutation/charger/finalize(hit = FALSE, atom/target = null)
	if(impact_resolved)
		return
	impact_resolved = TRUE
	var/datum/action/cooldown/paradise_zombie_mutation/dash/charge/action = action_ref?.resolve()
	var/mob/living/carbon/human/user = thrownthing
	var/mob/living/victim = first_victim_ref?.resolve()
	if(!victim && hit && isliving(target) && action?.can_hit(target))
		victim = target
	. = ..()
	if(!QDELETED(action) && !QDELETED(user) && !QDELETED(victim))
		action.on_charge_landed(user, victim)
