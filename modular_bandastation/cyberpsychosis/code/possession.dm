/// A spontaneous episode offers the remaining part of its forty seconds to a ghost.
/datum/status_effect/forced_combat/cyberpsychosis/possession
	/// No automatic combat while the ten-second lottery is pending.
	var/poll_pending = TRUE
	/// Absolute deadline, including time spent preparing the player's backseat.
	var/poll_ends_at
	/// Owns the borrowed client's identity until its asynchronous return finishes.
	var/datum/cyberpsychosis_possession/control_lease

/datum/status_effect/forced_combat/cyberpsychosis/possession/on_apply()
	. = ..()
	if(!.)
		return
	poll_ends_at = world.time + 10 SECONDS
	notify_ghosts(
		"У [owner.real_name] начинается киберпсихоз! В течение 10 секунд можно записаться на временное управление телом.",
		source = owner,
		header = "Киберпсихоз",
		notify_flags = NOTIFY_CATEGORY_NOFLASH,
	)
	INVOKE_ASYNC(src, PROC_REF(poll_for_controller))

/// Use the station's opt-in lottery, role bans and ghost-role preferences.
/datum/status_effect/forced_combat/cyberpsychosis/possession/proc/poll_for_controller()
	var/mob/dead/observer/volunteer = SSpolling.poll_ghosts_for_target(
		question = "Хотите временно управлять [owner.real_name] во время киберпсихоза? Атакуйте окружающих; управление закончится вместе с приступом.",
		check_jobban = ROLE_PAI,
		poll_time = max(0, poll_ends_at - world.time),
		checked_target = owner,
		ignore_category = POLL_IGNORE_SPLITPERSONALITY,
		alert_pic = owner,
		role_name_text = "киберпсихоз",
	)
	// Disabled ghost roles or an empty candidate list may return immediately.
	if(!QDELETED(src) && world.time < poll_ends_at)
		sleep(poll_ends_at - world.time)
	finish_poll(volunteer)

/// Revalidate after the poll: expiry, death or an EMP fault invalidates a late offer.
/datum/status_effect/forced_combat/cyberpsychosis/possession/proc/finish_poll(mob/dead/observer/volunteer)
	if(QDELETED(src) || !poll_pending || emp_overloaded || QDELETED(owner) || owner.stat == DEAD || duration <= 0 || world.time < poll_ends_at)
		return FALSE
	poll_pending = FALSE
	if(!isobserver(volunteer) || QDELETED(volunteer) || !GET_CLIENT(volunteer))
		return FALSE
	var/mob/living/body = owner
	var/volunteer_identity = key_name(volunteer)
	var/datum/cyberpsychosis_possession/lease = new(body, volunteer)
	control_lease = lease
	var/took_control = lease.begin()
	if(QDELETED(src) || QDELETED(body) || !took_control || emp_overloaded || control_lease != lease)
		if(!QDELETED(lease))
			INVOKE_ASYNC(lease, TYPE_PROC_REF(/datum/cyberpsychosis_possession, end), body)
		return FALSE
	lease.play_ambience(src)
	to_chat(owner, span_userdanger("Киберпсихоз! Временно управляйте этим телом и атакуйте окружающих. Не убивайте себя намеренно. По окончании приступа вы вернётесь призраком."))
	owner.log_message("is temporarily controlled by [volunteer_identity] during cyberpsychosis.", LOG_GAME)
	return TRUE

/datum/status_effect/forced_combat/cyberpsychosis/possession/take_control()
	if(control_lease && !QDELETED(control_lease))
		if(control_lease.is_controlling())
			return
		if(owner.key && owner.ckey != ckey(control_lease.original_key))
			qdel(src)
			return
	if(backseat?.key && owner.key && ckey(owner.key) != ckey(backseat.key))
		qdel(src)
		return
	return ..()

/datum/status_effect/forced_combat/cyberpsychosis/possession/uses_automatic_combat()
	return !poll_pending && (QDELETED(control_lease) || !control_lease.is_controlling())

/datum/status_effect/forced_combat/cyberpsychosis/possession/tick(seconds_between_ticks)
	if(control_lease && !QDELETED(control_lease) && (!control_lease.is_controlling() || !GET_CLIENT(owner)))
		INVOKE_ASYNC(control_lease, TYPE_PROC_REF(/datum/cyberpsychosis_possession, end), owner)
	return ..()

/datum/status_effect/forced_combat/cyberpsychosis/possession/begin_emp_overload()
	. = ..()
	if(!.)
		return
	poll_pending = FALSE
	if(control_lease && !QDELETED(control_lease))
		INVOKE_ASYNC(control_lease, TYPE_PROC_REF(/datum/cyberpsychosis_possession, end), owner)

/datum/status_effect/forced_combat/cyberpsychosis/possession/on_remove()
	poll_pending = FALSE
	if(control_lease && !QDELETED(control_lease))
		// The lease survives this effect to return the ghost before returning the owner.
		control_lease.return_seat = backseat
		backseat.episode_ref = null
		backseat = null
		INVOKE_ASYNC(control_lease, TYPE_PROC_REF(/datum/cyberpsychosis_possession, end), owner)
	control_lease = null
	return ..()

/// Temporarily borrows a client, never its old mind or the character's roles.
/datum/cyberpsychosis_possession
	/// The character's body and the volunteer's original observer are not owned by this lease.
	var/datum/weakref/body_ref
	var/datum/weakref/origin_ref
	/// Preserve the volunteer's original corpse association if a replacement observer is needed.
	var/datum/weakref/origin_mind_ref
	/// The character's identity stays in the body throughout the borrowed control.
	var/datum/mind/body_mind
	/// Login must not replace the character owner's key with the volunteer's key.
	var/original_key
	/// Keys also let a disconnected volunteer return to their original observer.
	var/controller_key
	/// Identifies voluntary ghosting without taking a client from an unrelated new body.
	var/client/controller_client
	/// The volunteer's loop must stop independently of the original player's backseat audio.
	var/sound_channel
	/// Re-entry rights belong to the volunteer's original character, not the borrowed body.
	var/origin_can_reenter
	/// Prevent duplicate expiry/death/disconnect cleanup.
	var/ending = FALSE
	/// On final expiry the ghost must leave before the owner can return from this seat.
	var/mob/living/cyberpsychosis_backseat/return_seat

/datum/cyberpsychosis_possession/New(mob/living/body, mob/dead/observer/volunteer)
	body_ref = WEAKREF(body)
	origin_ref = WEAKREF(volunteer)
	origin_mind_ref = WEAKREF(volunteer.mind)
	origin_can_reenter = volunteer.can_reenter_corpse
	controller_key = volunteer.key
	controller_client = GET_CLIENT(volunteer)
	sound_channel = SSsounds.reserve_sound_channel_for_datum(src)

/// Start only after a successful handoff; the reserved channel belongs to this lease.
/datum/cyberpsychosis_possession/proc/play_ambience(datum/status_effect/forced_combat/cyberpsychosis/episode)
	if(ending || !is_controlling() || !istype(controller_client, /client) || !sound_channel)
		return
	SEND_SOUND(controller_client, episode.get_ambience_sound(sound_channel))

/// Stop the saved recipient even if they have already returned to an observer or changed bodies.
/datum/cyberpsychosis_possession/proc/stop_ambience()
	if(sound_channel && istype(controller_client, /client))
		SEND_SOUND(controller_client, sound(null, channel = sound_channel))
	sound_channel = null

/// The original player must already be backseated before a volunteer can enter.
/datum/cyberpsychosis_possession/proc/begin()
	var/mob/living/body = body_ref?.resolve()
	var/mob/dead/observer/volunteer = origin_ref?.resolve()
	if(QDELETED(body) || body.stat == DEAD || body.key || !controller_key || QDELETED(volunteer) || !GET_CLIENT(volunteer) || volunteer.key != controller_key)
		return FALSE
	if(!body.mind)
		body.mind_initialize()
	body_mind = body.mind
	original_key = body_mind.key
	RegisterSignal(body, COMSIG_MOB_MIND_INITIALIZED, PROC_REF(preserve_character))
	RegisterSignal(body, COMSIG_QDELETING, PROC_REF(on_body_deleted))
	body.key = controller_key
	return !QDELETED(src) && is_controlling()

/// Login synchronizes mind.key; keep the real owner registered for revival and reconnection.
/datum/cyberpsychosis_possession/proc/preserve_character(datum/source, datum/mind/initialized_mind)
	SIGNAL_HANDLER
	if(initialized_mind == body_mind)
		body_mind.key = original_key

/datum/cyberpsychosis_possession/proc/is_controlling()
	var/mob/living/body = body_ref?.resolve()
	return controller_key && body && ckey(body.key) == ckey(controller_key) && body.mind == body_mind && body_mind?.current == body

/datum/cyberpsychosis_possession/proc/on_body_deleted(mob/living/source)
	SIGNAL_HANDLER
	INVOKE_ASYNC(src, PROC_REF(end), source)

/// Key changes can yield in Login, so cleanup owns its state separately from the expired effect.
/datum/cyberpsychosis_possession/proc/end(mob/living/body)
	if(ending)
		return
	ending = TRUE
	stop_ambience()
	if(!body)
		body = body_ref?.resolve()
	var/mob/dead/observer/origin = origin_ref?.resolve()
	var/mob/dead/observer/returned_ghost
	if(body && ckey(body.key) == ckey(controller_key) && (!body.mind || (body.mind == body_mind && body_mind?.current == body)))
		if(origin && !origin.key)
			origin.key = body.key
			// Disconnected/fake keys need releasing even when no Login moved a real client.
			if(body && body.key == controller_key && (!body.mind || body.mind == body_mind))
				body.key = null
		else
			returned_ghost = body.ghostize(FALSE, forced = TRUE)
	else if(isobserver(controller_client?.mob))
		// A volunteer may have ghosted voluntarily while the episode was running.
		var/mob/dead/observer/current_ghost = controller_client.mob
		var/datum/mind/origin_mind = origin_mind_ref?.resolve()
		if(current_ghost.mind == body_mind || !current_ghost.mind || current_ghost.mind == origin_mind)
			if(origin && current_ghost != origin && !origin.key)
				origin.key = current_ghost.key
				if(!QDELETED(current_ghost) && !current_ghost.key)
					current_ghost.mind = null
					qdel(current_ghost)
			else if(current_ghost.mind == body_mind)
				returned_ghost = current_ghost
	else if(!controller_client && !GLOB.directory[ckey(controller_key)] && origin && !origin.key && (!body || (body.mind == body_mind && body_mind?.current == body && !body.key)))
		// A fully disconnected client has no key on the body to move; preserve its rejoin target.
		origin.key = controller_key
	if(returned_ghost && !QDELETED(returned_ghost))
		returned_ghost.mind = origin_mind_ref?.resolve()
		returned_ghost.can_reenter_corpse = origin_can_reenter
	if(body)
		UnregisterSignal(body, list(COMSIG_MOB_MIND_INITIALIZED, COMSIG_QDELETING))
	if(body_mind && !QDELETED(body_mind) && body_mind.current == body)
		body_mind.key = original_key
	if(return_seat && !QDELETED(return_seat))
		return_seat.clear_fullscreen("cyberpsychosis_vignette", animated = FALSE)
		return_seat.clear_fullscreen("cyberpsychosis_static", animated = FALSE)
		return_seat.return_to_body()
	qdel(src)

/datum/cyberpsychosis_possession/Destroy()
	stop_ambience()
	body_ref = null
	origin_ref = null
	origin_mind_ref = null
	body_mind = null
	controller_client = null
	return_seat = null
	return ..()
