/// A timed loss of control using the same attacks as an EMP-induced forced combat effect.
/datum/status_effect/forced_combat/cyberpsychosis
	id = "cyberpsychosis"
	status_type = STATUS_EFFECT_UNIQUE
	duration = 40 SECONDS
	tick_interval = 0.5 SECONDS
	on_remove_on_mob_delete = TRUE
	/// The player's temporary seat. Their mind remains attached to the body.
	var/mob/living/cyberpsychosis_backseat/backseat
	/// Weak reference to the currently pursued victim.
	var/datum/weakref/target_ref
	/// Movement owned exclusively by this episode.
	var/datum/move_loop/has_target/jps/pursuit
	/// Existing AI paused for the episode, if it was not already forced off.
	var/datum/weakref/paused_ai_ref
	/// Personal audio channel, reserved for this effect's lifetime.
	var/sound_channel
	/// Remember the actual recipient so transferring to a ghost also stops the loop.
	var/client/sound_listener
	/// Timer for the next attack; independent of target selection frequency.
	var/attack_timer
	/// Time of the next involuntary laugh.
	var/next_laugh = 0
	/// Match the normal movement-based grab escape cooldown without a client on the body.
	var/next_grab_resist = 0
	/// Temporarily unreachable targets are skipped until this time.
	var/list/failed_targets = list()

/datum/status_effect/forced_combat/cyberpsychosis/on_creation(mob/living/new_owner, duration = 40 SECONDS)
	return ..(new_owner, duration)

/datum/status_effect/forced_combat/cyberpsychosis/on_apply()
	if(!ishuman(owner) || owner.stat == DEAD)
		return FALSE
	ADD_TRAIT(owner, TRAIT_SSD_SUPPRESSED, TRAIT_STATUS_EFFECT(id))
	if(owner.ai_controller && !owner.ai_controller.forced_off)
		paused_ai_ref = WEAKREF(owner.ai_controller)
		owner.ai_controller.force_ai_off()
	sound_channel = SSsounds.reserve_sound_channel_for_datum(src)
	backseat = new(owner)
	backseat.body_ref = WEAKREF(owner)
	backseat.episode_ref = WEAKREF(src)
	backseat.static_until = world.time + 2 SECONDS
	backseat.update_body_view()
	backseat.copy_languages(owner.get_language_holder())
	RegisterSignal(owner, COMSIG_MOB_CLIENT_LOGIN, PROC_REF(on_login))
	RegisterSignal(owner, COMSIG_LIVING_DEATH, PROC_REF(on_death))
	INVOKE_ASYNC(src, PROC_REF(take_control))
	attack_timer = addtimer(CALLBACK(src, PROC_REF(attack)), world.tick_lag, TIMER_STOPPABLE)
	laugh()
	return TRUE

/datum/status_effect/forced_combat/cyberpsychosis/on_remove()
	UnregisterSignal(owner, list(COMSIG_MOB_CLIENT_LOGIN, COMSIG_LIVING_DEATH))
	if(attack_timer)
		deltimer(attack_timer)
		attack_timer = null
	QDEL_NULL(pursuit)
	target_ref = null
	failed_targets.Cut()
	stop_ambience()
	var/datum/ai_controller/paused_ai = paused_ai_ref?.resolve()
	paused_ai?.clear_forced_off()
	paused_ai_ref = null
	if(backseat)
		backseat.clear_fullscreen("cyberpsychosis_vignette", animated = FALSE)
		backseat.clear_fullscreen("cyberpsychosis_static", animated = FALSE)
		// Login can yield. Restore outside signal dispatch, with ownership rechecked there.
		backseat.episode_ref = null
		INVOKE_ASYNC(backseat, TYPE_PROC_REF(/mob/living/cyberpsychosis_backseat, return_to_body))
		backseat = null
	REMOVE_TRAIT(owner, TRAIT_SSD_SUPPRESSED, TRAIT_STATUS_EFFECT(id))

/// 1 / 1.25: 25% more attacks per second, while retaining other cooldown modifiers.
/datum/status_effect/forced_combat/cyberpsychosis/nextmove_modifier()
	return 0.8

/datum/status_effect/forced_combat/cyberpsychosis/proc/on_death()
	SIGNAL_HANDLER
	qdel(src)

/datum/status_effect/forced_combat/cyberpsychosis/proc/on_login()
	SIGNAL_HANDLER
	INVOKE_ASYNC(src, PROC_REF(take_control))

/// Move only the client/key, never the character's mind, job or antagonist datums.
/datum/status_effect/forced_combat/cyberpsychosis/proc/take_control()
	if(QDELETED(src) || QDELETED(owner) || owner.stat == DEAD || QDELETED(backseat) || !owner.key)
		return
	backseat.name = owner.real_name
	backseat.real_name = owner.real_name
	backseat.mind = owner.mind
	backseat.key = owner.key
	if(!QDELETED(src) && backseat?.client)
		to_chat(backseat, span_userdanger("Киберпсихоз! Вы потеряли контроль над своим телом!"))

/// Start/restart a private looping track, including after reconnecting to the seat.
/datum/status_effect/forced_combat/cyberpsychosis/proc/play_ambience()
	if(!backseat?.client || QDELETED(owner))
		return
	var/track = owner.gender == FEMALE ? 'modular_bandastation/cyberpsychosis/sound/edgerunner-fury-female.ogg' : 'modular_bandastation/cyberpsychosis/sound/edgerunner-fury-male.ogg'
	stop_ambience()
	sound_listener = backseat.client
	SEND_SOUND(sound_listener, sound(track, repeat = TRUE, channel = sound_channel, volume = 60))

/// Stop only this episode's channel, including if the listener has become a ghost.
/datum/status_effect/forced_combat/cyberpsychosis/proc/stop_ambience()
	if(sound_listener && sound_channel)
		SEND_SOUND(sound_listener, sound(null, channel = sound_channel))
	sound_listener = null

/datum/status_effect/forced_combat/cyberpsychosis/tick(seconds_between_ticks)
	if(owner.stat == DEAD || duration <= 0)
		qdel(src)
		return
	if(world.time >= next_laugh)
		laugh()
	backseat?.update_body_view()
	var/mob/living/target = select_target()
	if(target != target_ref?.resolve())
		QDEL_NULL(pursuit)
		target_ref = target ? WEAKREF(target) : null
	if(target && QDELETED(pursuit))
		pursuit = GLOB.move_manager.jps_move(owner, target, delay = owner.cached_multiplicative_slowdown, repath_delay = 1 SECONDS, max_path_length = 30, minimum_distance = 1, access = owner.get_access(), simulated_only = !HAS_TRAIT(owner, TRAIT_SPACEWALK), skip_first = TRUE, diagonal_handling = DIAGONAL_REMOVE_CLUNKY, extra_info = src)
		if(pursuit)
			RegisterSignal(pursuit, COMSIG_MOVELOOP_PREPROCESS_CHECK, PROC_REF(before_move))
			RegisterSignal(pursuit, COMSIG_MOVELOOP_JPS_FINISHED_PATHING, PROC_REF(on_path))

/// Keep a close target; beyond four tiles prefer a closer visible living target.
/datum/status_effect/forced_combat/cyberpsychosis/proc/select_target()
	var/list/mob/living/candidates = list()
	for(var/mob/living/candidate in oview(7, owner))
		if(!owner.in_fov(candidate))
			continue
		if(candidate.stat == DEAD || !isturf(candidate.loc) || candidate.invisibility > owner.see_invisible)
			continue
		if(failed_targets[REF(candidate)] > world.time)
			continue
		candidates += candidate
	var/mob/living/current = target_ref?.resolve()
	if(!(current in candidates))
		current = null
	var/distance = current ? get_dist(owner, current) : INFINITY
	if(distance < 4)
		return current
	for(var/mob/living/candidate as anything in candidates)
		var/candidate_distance = get_dist(owner, candidate)
		if(candidate_distance < distance)
			current = candidate
			distance = candidate_distance
	return current

/// Preserve normal mobility, grabs and restraints instead of force-moving the body.
/datum/status_effect/forced_combat/cyberpsychosis/proc/before_move(datum/move_loop/source)
	SIGNAL_HANDLER
	source.delay = max(world.tick_lag, owner.cached_multiplicative_slowdown)
	if(IS_UNCONSCIOUS_OR_CRIT(owner) || !(owner.mobility_flags & MOBILITY_MOVE) || !isturf(owner.loc) || owner.buckled || HAS_TRAIT(owner, TRAIT_NO_TRANSFORM))
		return MOVELOOP_SKIP_STEP
	if(owner.pulledby)
		if(owner.incapacitated || HAS_TRAIT(owner, TRAIT_RESTRAINED) || world.time < next_grab_resist)
			return MOVELOOP_SKIP_STEP
		if(!owner.resist_grab(TRUE))
			next_grab_resist = world.time + 4 SECONDS
			return MOVELOOP_SKIP_STEP
	var/mob/living/target = target_ref?.resolve()
	if(!target || owner.Adjacent(target))
		return MOVELOOP_SKIP_STEP

/// Don't repeatedly choose a visible target sealed behind inaccessible obstacles.
/datum/status_effect/forced_combat/cyberpsychosis/proc/on_path(datum/move_loop/source, list/path)
	SIGNAL_HANDLER
	var/mob/living/target = target_ref?.resolve()
	if(target && !length(path) && !owner.Adjacent(target))
		failed_targets[REF(target)] = world.time + 3 SECONDS
		target_ref = null
		QDEL_NULL(pursuit)

/// Reuse forced_combat's held-item/unarmed ClickOn attack and its normal attack range.
/datum/status_effect/forced_combat/cyberpsychosis/proc/attack()
	attack_timer = null
	if(QDELETED(owner) || owner.stat == DEAD || duration <= 0)
		qdel(src)
		return
	if(owner.next_move <= world.time && !IS_UNCONSCIOUS_OR_CRIT(owner))
		perform_attack()
	if(!QDELETED(src))
		attack_timer = addtimer(CALLBACK(src, PROC_REF(attack)), max(world.tick_lag, owner.next_move - world.time), TIMER_STOPPABLE)

/// Select one target for the inherited EMP attack implementation.
/datum/status_effect/forced_combat/cyberpsychosis/proc/perform_attack()
	var/mob/living/target = target_ref?.resolve()
	var/search_radius = isgun(owner.get_active_held_item()) ? 3 : 1
	if(target && target.stat != DEAD && (target in oview(search_radius, owner)))
		var/previous_throw_mode = owner.throw_mode
		owner.throw_mode = FALSE
		force_attack(target)
		owner.throw_mode = previous_throw_mode

/// Organic species use their normal laugh; IPCs get an audible involuntary laugh too.
/datum/status_effect/forced_combat/cyberpsychosis/proc/laugh()
	next_laugh = world.time + 5 SECONDS
	if(IS_UNCONSCIOUS_OR_CRIT(owner))
		return
	if(is_species(owner, /datum/species/ipc))
		owner.visible_message(span_warning("[owner] разражается механическим смехом!"))
		playsound(owner, 'sound/misc/insane_low_laugh.ogg', 50, TRUE)
	else
		owner.emote("laugh", forced = TRUE)
