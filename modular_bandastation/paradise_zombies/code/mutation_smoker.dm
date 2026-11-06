/** A dodgeable tongue delivers one short yank, without a persistent grab or a changeling's follow-up attacks. */
/datum/action/cooldown/paradise_zombie_mutation/tongue
	name = "Хватательный язык"
	desc = "Выстрелить видимым языком до 8 клеток и подтянуть жертву по свободному пути. Попадание по вам, потеря сознания или препятствие срывают тягу."
	button_icon = 'icons/mob/actions/actions_changeling.dmi'
	button_icon_state = "tentacle"
	required_form = "slasher"
	cooldown_time = 18 SECONDS
	click_to_activate = TRUE
	/// Direct burn and other health losses need not pass through apply_damage().
	var/previous_health

/datum/action/cooldown/paradise_zombie_mutation/tongue/Grant(mob/granted_to)
	var/mob/previous_owner = owner
	. = ..()
	if(!owner || owner == previous_owner)
		return .
	RegisterSignal(owner, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_owner_damaged))
	var/mob/living/user = owner
	previous_health = user.health
	RegisterSignal(owner, COMSIG_LIVING_HEALTH_UPDATE, PROC_REF(on_owner_health_changed))

/datum/action/cooldown/paradise_zombie_mutation/tongue/Remove(mob/removed_from)
	UnregisterSignal(removed_from, list(COMSIG_MOB_AFTER_APPLY_DAMAGE, COMSIG_LIVING_HEALTH_UPDATE))
	return ..()

/// Reuse the action's existing status listeners so cancellation preserves native HUD updates.
/datum/action/cooldown/paradise_zombie_mutation/tongue/update_status_on_signal(datum/source, new_stat, old_stat)
	. = ..()
	if(!is_active())
		clear_effects()

/datum/action/cooldown/paradise_zombie_mutation/tongue/is_active()
	if(!..() || HAS_TRAIT(owner, TRAIT_PACIFISM) || HAS_TRAIT(owner, TRAIT_INCAPACITATED))
		return FALSE
	var/mob/living/user = owner
	return user.stat == STABLE && user.body_position == STANDING_UP

/datum/action/cooldown/paradise_zombie_mutation/tongue/can_hit(mob/living/victim)
	return ..() && !victim.anchored && !victim.buckled && !victim.has_status_effect(/datum/status_effect/paradise_zombie_pin) && !victim.has_status_effect(/datum/status_effect/paradise_zombie_pin_recovery)

/datum/action/cooldown/paradise_zombie_mutation/tongue/Activate(atom/target)
	var/mob/living/carbon/human/user = owner
	var/turf/destination = get_turf(target)
	if(!IsAvailable() || !isturf(user.loc) || !destination || destination.z != user.z || destination == user.loc || get_dist_euclidean(user, destination) > 8)
		return FALSE
	if(isliving(target) && (!can_hit(target) || get_dist(user, target) <= 1))
		return FALSE
	var/obj/projectile/paradise_zombie_tongue/tongue = new(get_turf(user))
	tongue.action_ref = WEAKREF(src)
	tongue.firer = user
	tongue.fired_from = src
	tongue.def_zone = BODY_ZONE_CHEST
	tongue.aim_projectile(target, get_turf(user))
	track_effect(tongue)
	StartCooldown()
	playsound(user, 'sound/items/weapons/whip.ogg', 55, TRUE)
	var/obj/effect/temp_visual/paradise_zombie_wave/mouth_wave = new(get_turf(user), BLOOD_COLOR_RED, 0.85)
	mouth_wave.pixel_y += 10
	tongue.fire()
	return TRUE

/datum/action/cooldown/paradise_zombie_mutation/tongue/proc/on_owner_damaged(datum/source, damage)
	SIGNAL_HANDLER
	if(damage > 0)
		clear_effects()

/datum/action/cooldown/paradise_zombie_mutation/tongue/proc/on_owner_health_changed(mob/living/source)
	SIGNAL_HANDLER
	if(source.health < previous_health)
		clear_effects()
	previous_health = source.health

/** Reuses the native tentacle projectile's artwork and beam, with ordinary projectile hit handling. */
/obj/projectile/paradise_zombie_tongue
	name = "хватательный язык"
	icon_state = "tentacle_end"
	damage = 0
	range = 8
	speed = 0.7
	hitsound = 'modular_bandastation/paradise_zombies/sound/mutations/slasher_attack.ogg'
	/// The physical mutation owns both the outgoing tongue and its short return flight.
	var/datum/weakref/action_ref
	var/datum/beam/tongue_beam

/// Displacement is an attack even though this projectile causes no direct damage or native stun.
/obj/projectile/paradise_zombie_tongue/is_hostile_projectile()
	return TRUE

/obj/projectile/paradise_zombie_tongue/vol_by_damage()
	return suppressed ? ..() : 45

/obj/projectile/paradise_zombie_tongue/fire(setAngle)
	if(firer)
		tongue_beam = firer.Beam(src, icon_state = "tentacle", beam_color = "#8A263C", emissive = NONE)
	return ..()

/obj/projectile/paradise_zombie_tongue/Destroy()
	QDEL_NULL(tongue_beam)
	action_ref = null
	return ..()

/obj/projectile/paradise_zombie_tongue/process()
	var/datum/action/cooldown/paradise_zombie_mutation/tongue/action = action_ref?.resolve()
	if(!action?.is_active())
		qdel(src)
		return PROCESS_KILL
	return ..()

/obj/projectile/paradise_zombie_tongue/can_hit_target(atom/target, direct_target = FALSE, ignore_loc = FALSE, cross_failed = FALSE)
	var/datum/action/cooldown/paradise_zombie_mutation/tongue/action = action_ref?.resolve()
	if(!action?.is_active() || (isliving(target) && !action.can_hit(target)))
		return FALSE
	return ..()

/obj/projectile/paradise_zombie_tongue/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	var/datum/action/cooldown/paradise_zombie_mutation/tongue/action = action_ref?.resolve()
	if(. != BULLET_ACT_HIT || blocked >= 100 || !isliving(target) || !action?.can_hit(target))
		return .
	var/mob/living/victim = target
	var/mob/living/user = action.owner
	if(victim.throwing || !isturf(victim.loc) || !isturf(user.loc) || get_dist(user, victim) <= 1 || get_dist_euclidean(user, victim) > initial(range) || !los_check(user, victim, PASSMOB))
		return BULLET_ACT_BLOCK
	if(!victim.throw_at(get_step_towards(user, victim), initial(range), 1, spin = FALSE, gentle = TRUE, quickstart = FALSE, throw_type_path = /datum/thrownthing/paradise_zombie_tongue))
		return BULLET_ACT_BLOCK
	var/datum/thrownthing/paradise_zombie_tongue/flight = victim.throwing
	flight.action_ref = WEAKREF(action)
	flight.tongue_beam = user.Beam(victim, icon_state = "tentacle", beam_color = "#8A263C", emissive = NONE)
	action.track_effect(flight)
	var/hit_direction = get_dir(user, victim)
	for(var/spray_direction in list(turn(hit_direction, 45), turn(hit_direction, -45)))
		new /obj/effect/temp_visual/dir_setting/bloodsplatter(get_turf(victim), spray_direction)
	new /obj/effect/temp_visual/paradise_zombie_splash(get_turf(victim), BLOOD_COLOR_RED)
	victim.visible_message(span_danger("Язык [user.declent_ru(GENITIVE)] подхватывает [victim.declent_ru(ACCUSATIVE)] и тянет к себе!"), span_userdanger("Язык [user.declent_ru(GENITIVE)] подхватывает и тянет вас!"))

/** Native collision-checked movement ends adjacent to the caster and never becomes a lasting hold. */
/datum/thrownthing/paradise_zombie_tongue
	var/datum/weakref/action_ref
	var/datum/beam/tongue_beam
	/// Pauses cannot turn a short yank into an indefinite restraint.
	var/expires_at

/datum/thrownthing/paradise_zombie_tongue/New(thrownthing, target, init_dir, maxrange, speed, thrower, diagonals_first, force, gentle, callback, target_zone)
	. = ..()
	expires_at = world.time + 2 SECONDS
	RegisterSignals(thrownthing, list(COMSIG_MOVABLE_PRE_THROW, COMSIG_LIVING_RESIST), PROC_REF(cancel_yank))
	RegisterSignal(thrownthing, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(check_endpoint))

/datum/thrownthing/paradise_zombie_tongue/Destroy()
	if(thrownthing)
		UnregisterSignal(thrownthing, list(COMSIG_MOVABLE_PRE_THROW, COMSIG_LIVING_RESIST, COMSIG_MOVABLE_PRE_MOVE))
		if(!QDELETED(thrownthing))
			var/mob/living/victim = thrownthing
			victim.apply_status_effect(/datum/status_effect/paradise_zombie_pin_recovery)
	QDEL_NULL(tongue_beam)
	action_ref = null
	return ..()

/datum/thrownthing/paradise_zombie_tongue/tick()
	var/datum/action/cooldown/paradise_zombie_mutation/tongue/action = action_ref?.resolve()
	var/mob/living/victim = thrownthing
	var/mob/living/user = action?.owner
	if(!action?.can_hit(victim) || !isturf(victim.loc) || !isturf(user.loc) || world.time >= expires_at || get_dist(user, victim) <= 1 || !los_check(user, victim, PASSMOB))
		qdel(src)
		return
	return ..()

/// A yank stops without an impact attack or an extra zero-gravity landing impulse.
/datum/thrownthing/paradise_zombie_tongue/finalize(hit = FALSE, target = null)
	qdel(src)

/// Native throws otherwise keep flying past their destination in zero gravity.
/datum/thrownthing/paradise_zombie_tongue/proc/check_endpoint(atom/movable/source)
	SIGNAL_HANDLER
	if(source.loc == target_turf || dist_travelled >= maxrange)
		return COMPONENT_MOVABLE_BLOCK_PRE_MOVE

/datum/thrownthing/paradise_zombie_tongue/proc/cancel_yank()
	SIGNAL_HANDLER
	qdel(src)
