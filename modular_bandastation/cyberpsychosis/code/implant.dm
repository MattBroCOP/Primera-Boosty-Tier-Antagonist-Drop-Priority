/// Manually toggled cyberpsychosis; the user controls only when the episode starts/stops.
/obj/item/implant/cyberpsychopath
	name = "Cyberpsychopath"
	desc = "Контрабандный имплант управляемого запуска киберпсихоза. Приступ длится до 20 секунд; после выключения требуется 20 секунд на восстановление. Уязвим к ЭМИ: сбой вызывает длительный неконтролируемый приступ с повреждением мозга."
	icon = 'modular_bandastation/cyberpsychosis/icons/cyberpsychopath.dmi'
	icon_state = "implant"
	implant_color = "r"
	cyberpsychosis_load = 0
	actions_types = list(/datum/action/item_action/hands_free/cyberpsychopath)
	implant_info = "В штатном режиме доступны ручное включение и выключение; движение и атаки выполняются автоматически. ЭМИ вызывает сбой, который нельзя отключить вручную."
	/// Track this implant's episode for cleanup/cooldown; EMP-locked episodes cannot be stopped.
	var/datum/weakref/active_episode_ref
	/// Separate action on the backseat; the body's other actions are never granted there.
	var/datum/action/cyberpsychopath_stop/stop_action
	/// Retained across extraction, transplantation and client disconnects.
	COOLDOWN_DECLARE(reactivation_cooldown)

/obj/item/implant/cyberpsychopath/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_CONTRABAND, INNATE_TRAIT)

/obj/item/implant/cyberpsychopath/Destroy()
	stop_episode()
	var/datum/status_effect/forced_combat/cyberpsychosis/episode = active_episode_ref?.resolve()
	if(episode)
		UnregisterSignal(episode, COMSIG_QDELETING)
	QDEL_NULL(stop_action)
	active_episode_ref = null
	return ..()

/obj/item/implant/cyberpsychopath/can_be_implanted_in(mob/living/target)
	return ..() && ishuman(target)

/// Both unshielded EMP strengths force the same fault, bypassing manual cooldown and controls.
/obj/item/implant/cyberpsychopath/emp_act(severity)
	. = ..()
	if((. & EMP_PROTECT_SELF) || cybernetic_rejection || !ishuman(imp_in) || imp_in.stat == DEAD)
		return
	var/datum/status_effect/forced_combat/cyberpsychosis/episode = imp_in.has_status_effect(/datum/status_effect/forced_combat/cyberpsychosis)
	var/created_episode = !episode
	if(created_episode)
		episode = imp_in.apply_status_effect(/datum/status_effect/forced_combat/cyberpsychosis)
	if(QDELETED(episode))
		return
	if(QDELETED(src) || imp_in != episode.owner || cybernetic_rejection)
		if(created_episode)
			qdel(episode)
		return
	if(!episode.begin_emp_overload())
		return
	var/datum/status_effect/forced_combat/cyberpsychosis/previous_episode = active_episode_ref?.resolve()
	if(previous_episode != episode)
		if(previous_episode)
			UnregisterSignal(previous_episode, COMSIG_QDELETING)
		active_episode_ref = WEAKREF(episode)
		RegisterSignal(episode, COMSIG_QDELETING, PROC_REF(on_episode_ended))
	QDEL_NULL(stop_action)
	to_chat(episode.backseat, span_userdanger("ЭМИ выводит Cyberpsychopath из-под контроля! Приступ невозможно остановить вручную!"))

/obj/item/implant/cyberpsychopath/on_activate()
	. = ..()
	var/datum/status_effect/forced_combat/cyberpsychosis/active_episode = active_episode_ref?.resolve()
	if(active_episode?.emp_overloaded)
		if(imp_in)
			to_chat(imp_in, span_warning("Cyberpsychopath заблокирован сбоем ЭМИ. Дождитесь окончания приступа."))
		return FALSE
	if(stop_episode())
		return TRUE
	if(!ishuman(imp_in) || imp_in.stat == DEAD)
		return FALSE
	if(imp_in.has_status_effect(/datum/status_effect/forced_combat/cyberpsychosis))
		to_chat(imp_in, span_warning("Cyberpsychopath не может управлять приступом, вызванным другим источником."))
		return FALSE
	if(!COOLDOWN_FINISHED(src, reactivation_cooldown))
		to_chat(imp_in, span_warning("Cyberpsychopath восстанавливается: осталось [DisplayTimeText(COOLDOWN_TIMELEFT(src, reactivation_cooldown))]."))
		return FALSE
	var/datum/status_effect/forced_combat/cyberpsychosis/controlled/episode = imp_in.apply_status_effect(/datum/status_effect/forced_combat/cyberpsychosis/controlled)
	if(QDELETED(episode))
		return FALSE
	if(QDELETED(src) || imp_in != episode.owner || cybernetic_rejection)
		qdel(episode)
		return FALSE
	active_episode_ref = WEAKREF(episode)
	RegisterSignal(episode, COMSIG_QDELETING, PROC_REF(on_episode_ended))
	stop_action = new(src)
	var/datum/action/item_action/hands_free/cyberpsychopath/toggle = locate() in actions
	stop_action.set_key(toggle?.full_key)
	stop_action.Grant(episode.backseat)
	return TRUE

/obj/item/implant/cyberpsychopath/on_remove(mob/living/source, silent = FALSE, special = FALSE)
	stop_episode()
	return ..()

/// Any completed episode starts cooldown, including death during an otherwise locked EMP fault.
/obj/item/implant/cyberpsychopath/proc/on_episode_ended(datum/source)
	SIGNAL_HANDLER
	UnregisterSignal(source, COMSIG_QDELETING)
	active_episode_ref = null
	QDEL_NULL(stop_action)
	COOLDOWN_START(src, reactivation_cooldown, 20 SECONDS)

/// Never remove an EMP-locked episode, a spontaneous episode or another implant's effect.
/obj/item/implant/cyberpsychopath/proc/stop_episode()
	var/datum/status_effect/forced_combat/cyberpsychosis/episode = active_episode_ref?.resolve()
	if(QDELETED(episode) || episode.emp_overloaded)
		return FALSE
	qdel(episode)
	return TRUE

/obj/item/implanter/cyberpsychopath
	name = "implanter (Cyberpsychopath)"
	imp_type = /obj/item/implant/cyberpsychopath

/obj/item/implanter/cyberpsychopath/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_CONTRABAND, INNATE_TRAIT)

/datum/uplink_item/implants/cyberpsychopath
	name = "Cyberpsychopath"
	desc = "Имплант с инъектором. Пока имплант установлен, самопроизвольные приступы киберпсихоза не возникают. По команде запускает управляемый приступ на 20 секунд: тело само преследует и атакует окружающих. Управление телом недоступно; можно только досрочно отключить имплант отдельной кнопкой. Уязвим к ЭМИ: сбой вызывает неотключаемый приступ на 40 секунд с повреждением мозга. После любого завершения — перезарядка 20 секунд."
	item = /obj/item/implanter/cyberpsychopath
	cost = 8

/// Shares the natural episode's identity, preventing overlapping or refreshed episodes.
/datum/status_effect/forced_combat/cyberpsychosis/controlled
	duration = 20 SECONDS

/datum/status_effect/forced_combat/cyberpsychosis/controlled/on_creation(mob/living/new_owner)
	return ..(new_owner, 20 SECONDS)

/datum/action/item_action/hands_free/cyberpsychopath
	name = "Cyberpsychopath: включить / выключить"
	desc = "Запустить приступ на 20 секунд. После выключения имплант восстанавливается 20 секунд."
	can_be_shared = FALSE
	button_icon = 'modular_bandastation/cyberpsychosis/icons/cyberpsychopath.dmi'
	button_icon_state = "action"

/datum/action/item_action/hands_free/cyberpsychopath/Trigger(mob/clicker, trigger_flags)
	if(clicker && clicker != owner)
		return FALSE
	return ..()

/// The only body-control action exposed during a manually started episode.
/datum/action/cyberpsychopath_stop
	name = "Cyberpsychopath: выключить"
	desc = "Немедленно завершить управляемый приступ и начать перезарядку на 20 секунд."
	button_icon = 'modular_bandastation/cyberpsychosis/icons/cyberpsychopath.dmi'
	button_icon_state = "action"
	can_be_shared = FALSE

/datum/action/cyberpsychopath_stop/Trigger(mob/clicker, trigger_flags)
	if((clicker && clicker != owner) || !..())
		return FALSE
	var/obj/item/implant/cyberpsychopath/implant = target
	if(QDELETED(implant) || implant.cybernetic_rejection)
		return FALSE
	var/datum/status_effect/forced_combat/cyberpsychosis/controlled/episode = implant.active_episode_ref?.resolve()
	if(QDELETED(episode) || episode.backseat != owner || episode.owner != implant.imp_in)
		return FALSE
	return implant.activate("action_button")
