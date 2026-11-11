/// An inert seat inside the body, like a split personality, with no controllable body/actions.
/mob/living/cyberpsychosis_backseat
	name = "cyberpsychosis"
	/// Weak references avoid keeping deleted bodies/effects alive.
	var/datum/weakref/body_ref
	var/datum/weakref/episode_ref

/mob/living/cyberpsychosis_backseat/sync_mind()
	return // The original mind must remain current in the real body.

/mob/living/cyberpsychosis_backseat/Login()
	. = ..()
	if(!. || !client)
		return FALSE
	update_body_view()
	var/datum/status_effect/forced_combat/cyberpsychosis/episode = episode_ref?.resolve()
	episode?.play_ambience()

/mob/living/cyberpsychosis_backseat/Destroy()
	var/datum/status_effect/forced_combat/cyberpsychosis/episode = episode_ref?.resolve()
	if(!QDELETED(episode))
		qdel(episode)
	mind = null // Shared with the body, never owned by this temporary seat.
	body_ref = null
	episode_ref = null
	return ..()

/mob/living/cyberpsychosis_backseat/Logout()
	var/datum/status_effect/forced_combat/cyberpsychosis/episode = episode_ref?.resolve()
	episode?.stop_ambience()
	return ..()

/mob/living/cyberpsychosis_backseat/Move()
	return FALSE

/mob/living/cyberpsychosis_backseat/ClickOn()
	return

/mob/living/cyberpsychosis_backseat/try_speak(message, ignore_spam, forced, filterproof)
	SHOULD_CALL_PARENT(FALSE)
	return FALSE

/mob/living/cyberpsychosis_backseat/emote(act, type_override = NONE, message = null, intentional = FALSE, force_silence = FALSE, forced = FALSE)
	return FALSE

/// Mirror the body's sight, without observer vision or a movable camera.
/mob/living/cyberpsychosis_backseat/proc/update_body_view()
	var/mob/living/body = body_ref?.resolve()
	if(!body || !client)
		return
	sight = body.sight
	see_in_dark = body.see_in_dark
	see_invisible = body.see_invisible
	if(HAS_TRAIT(body, TRAIT_DEAF))
		ADD_TRAIT(src, TRAIT_DEAF, "cyberpsychosis")
	else
		REMOVE_TRAIT(src, TRAIT_DEAF, "cyberpsychosis")
	if(body.is_blind() || IS_UNCONSCIOUS_OR_CRIT(body))
		overlay_fullscreen("cyberpsychosis_blind", /atom/movable/screen/fullscreen/blind)
	else
		clear_fullscreen("cyberpsychosis_blind", animated = FALSE)
	reset_perspective(body)

/// Restore even disconnected keys, but never steal a client from a different body/mind.
/mob/living/cyberpsychosis_backseat/proc/return_to_body()
	var/mob/living/body = body_ref?.resolve()
	if(key && body && !QDELETED(body) && !body.key && (!mind || mind.current == body))
		body.key = key
	else if(key)
		ghostize(FALSE)
	if(!QDELETED(src))
		qdel(src)
