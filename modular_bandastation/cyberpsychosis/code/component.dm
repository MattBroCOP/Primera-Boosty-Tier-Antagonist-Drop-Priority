/// Tracks installed hardware independently of mood and of the player's connection.
/datum/component/cyberpsychosis
	/// Current installed burden, excluding carried items and bodyparts.
	var/load = 0
	/// Buildup towards an episode (0..100).
	var/buildup = 0
	/// Physical installation of Cyberpsychopath suppresses spontaneous overload buildup.
	var/buildup_blocked = FALSE
	/// One stoppable timer, only scheduled while alive, overloaded and outside an episode.
	var/buildup_timer
	/// Largest safe installed burden.
	var/static/safe_load = 20
	/// Interval between discrete buildup increments.
	var/static/buildup_interval = 30 SECONDS

/datum/component/cyberpsychosis/Initialize()
	if(!ishuman(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/cyberpsychosis/RegisterWithParent()
	RegisterSignals(parent, list(COMSIG_CARBON_GAIN_ORGAN, COMSIG_CARBON_LOSE_ORGAN, COMSIG_LIVING_IMPLANTS_CHANGED), PROC_REF(update_load))
	RegisterSignal(parent, COMSIG_LIVING_DEATH, PROC_REF(on_death))
	RegisterSignal(parent, COMSIG_LIVING_REVIVE, PROC_REF(update_load))
	RegisterSignal(parent, COMSIG_LIVING_STATUS_APPLIED, PROC_REF(on_episode_started))
	RegisterSignal(parent, COMSIG_LIVING_STATUS_REMOVED, PROC_REF(on_episode_ended))
	update_load()

/datum/component/cyberpsychosis/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_CARBON_GAIN_ORGAN, COMSIG_CARBON_LOSE_ORGAN, COMSIG_LIVING_IMPLANTS_CHANGED, COMSIG_LIVING_DEATH, COMSIG_LIVING_REVIVE, COMSIG_LIVING_STATUS_APPLIED, COMSIG_LIVING_STATUS_REMOVED))
	stop_timer()

/datum/component/cyberpsychosis/Destroy(force)
	stop_timer()
	return ..()

/// Recompute only when the physical installation changes; rejected hardware still counts.
/datum/component/cyberpsychosis/proc/update_load()
	SIGNAL_HANDLER
	var/mob/living/carbon/human/human = parent
	load = 0
	buildup_blocked = FALSE
	for(var/obj/item/organ/organ as anything in human.organs)
		load += max(0, organ.cyberpsychosis_load)
	for(var/obj/item/implant/implant as anything in human.implants)
		load += max(0, implant.cyberpsychosis_load)
		if(istype(implant, /obj/item/implant/cyberpsychopath))
			buildup_blocked = TRUE
	if(buildup_blocked || load <= safe_load || human.stat == DEAD)
		buildup = 0
		stop_timer()
	else
		schedule_buildup()

/// Start a fresh interval without postponing an interval already underway.
/datum/component/cyberpsychosis/proc/schedule_buildup()
	var/mob/living/human = parent
	if(QDELETED(human) || human.stat == DEAD || buildup_blocked || load <= safe_load || buildup_timer || human.has_status_effect(/datum/status_effect/forced_combat/cyberpsychosis))
		return
	buildup_timer = addtimer(CALLBACK(src, PROC_REF(advance_buildup)), buildup_interval, TIMER_STOPPABLE)

/// Apply a single 30-second increment using the currently installed burden.
/datum/component/cyberpsychosis/proc/advance_buildup()
	buildup_timer = null
	var/mob/living/human = parent
	if(QDELETED(human) || human.stat == DEAD || buildup_blocked || load <= safe_load || human.has_status_effect(/datum/status_effect/forced_combat/cyberpsychosis))
		return
	buildup = min(100, buildup + load - safe_load)
	if(buildup >= 100)
		human.apply_status_effect(/datum/status_effect/forced_combat/cyberpsychosis)
	else
		schedule_buildup()

/// Cancel a pending increment on death, safe burden or episode start.
/datum/component/cyberpsychosis/proc/stop_timer()
	if(buildup_timer)
		deltimer(buildup_timer)
		buildup_timer = null

/datum/component/cyberpsychosis/proc/on_death()
	SIGNAL_HANDLER
	buildup = 0
	stop_timer()
	var/mob/living/human = parent
	human.remove_status_effect(/datum/status_effect/forced_combat/cyberpsychosis)

/datum/component/cyberpsychosis/proc/on_episode_started(datum/source, datum/status_effect/effect)
	SIGNAL_HANDLER
	if(istype(effect, /datum/status_effect/forced_combat/cyberpsychosis))
		stop_timer()

/datum/component/cyberpsychosis/proc/on_episode_ended(datum/source, datum/status_effect/effect)
	SIGNAL_HANDLER
	if(!istype(effect, /datum/status_effect/forced_combat/cyberpsychosis))
		return
	buildup = 0
	schedule_buildup()

/// Shared analyzer report: reveal the condition without disclosing hidden hardware or burden.
/datum/component/cyberpsychosis/proc/get_scan_report()
	var/mob/living/human = parent
	if(buildup_timer || human.has_status_effect(/datum/status_effect/forced_combat/cyberpsychosis))
		return "<span class='ml-2'><font color='#ff3333'>Наблюдается аномалия, возможно наличие киберпсихоза</font></span><br>"
	return "<span class='ml-2'><font color='#5599ff'>Состояние организма в норме, аномалий не наблюдается</font></span><br>"
