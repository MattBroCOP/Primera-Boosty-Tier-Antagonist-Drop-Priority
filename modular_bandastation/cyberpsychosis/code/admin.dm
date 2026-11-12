/// The existing admin Smite menu can trigger any overload outcome without installing hardware.
/datum/smite/cyberpsychosis
	name = "Киберпсихоз"
	/// Keep the selected label so it can be validated again after the configuration prompt.
	var/selected_mode = "Случайный исход"
	/// Labels are shown to admins; values select the shared production outcome.
	var/static/list/modes = list(
		"Случайный исход" = "random",
		"Берсерк — 40 секунд" = "berserk",
		"Локальный взрыв" = "explosion",
		"Жеребьёвка призракам — 10 секунд" = "possession",
	)

/datum/smite/cyberpsychosis/configure(client/user)
	if(!check_rights_for(user, R_ADMIN|R_FUN))
		return FALSE
	var/choice = tgui_input_list(user, "Какой исход киберпсихоза вызвать?", name, modes)
	if(!(choice in modes))
		return FALSE
	selected_mode = choice
	return TRUE

/datum/smite/cyberpsychosis/effect(client/user, mob/living/target)
	// Configuration yields, and buildmode may reuse this smite after the admin's rights change.
	if(!check_rights_for(user, R_ADMIN|R_FUN) || !(selected_mode in modes))
		return FALSE
	if(QDELETED(target) || !ishuman(target) || target.stat == DEAD)
		to_chat(user, span_warning("Киберпсихоз можно вызвать только у живого гуманоида."), confidential = TRUE)
		return FALSE
	var/datum/component/cyberpsychosis/load = target.GetComponent(/datum/component/cyberpsychosis)
	if(!load || target.has_status_effect(/datum/status_effect/forced_combat/cyberpsychosis))
		to_chat(user, span_warning("Киберпсихоз недоступен или уже активен у этого персонажа."), confidential = TRUE)
		return FALSE
	var/outcome = modes[selected_mode]
	if(outcome == "random")
		outcome = pick("berserk", "explosion", "possession")
	..()
	return load.trigger_overload(outcome, forced = TRUE)
