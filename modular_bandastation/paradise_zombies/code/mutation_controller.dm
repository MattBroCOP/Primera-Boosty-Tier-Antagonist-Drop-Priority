#define PARADISE_ZOMBIE_MUTATION_ANIMATION_TAG "paradise_zombie_evolution"

/// Ranged mutation exposure retains the source strain and Paradise's ordinary resistance rolls.
/proc/paradise_zombie_mutation_expose(mob/living/carbon/human/victim, mob/living/carbon/human/source)
	if(QDELETED(victim) || QDELETED(source) || HAS_TRAIT(victim, TRAIT_PARADISE_ZOMBIE) || victim.reagents?.has_reagent(/datum/reagent/medicine/paradise_zombie_cure/alpha))
		return FALSE
	if(!GLOB.paradise_zombie_mutation_progression.is_mature_zombie(source))
		return FALSE
	var/datum/disease/paradise_zombie/infection = locate() in source.diseases
	return paradise_zombie_blood_infect(victim, infection.Copy())

/** Owns a physical body's mutation until the infection is cured, including through ordinary death. */
/datum/component/paradise_zombie_mutation
	dupe_mode = COMPONENT_DUPE_UNIQUE
	var/datum/paradise_zombie_form/form
	var/datum/component/paradise_zombie_mutation_body/body_renderer
	var/datum/action/cooldown/paradise_zombie_choose_mutation/selection_action
	var/list/granted_actions = list()
	/// Actual additive change, which may be clamped on bodies with severe cellular injury.
	var/applied_health_bonus = 0
	var/mutating = FALSE
	/// Owns only the tagged pulse, never the host's current transform or other animations.
	var/mutation_visual_active = FALSE

/datum/component/paradise_zombie_mutation/Initialize()
	if(!ishuman(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/paradise_zombie_mutation/RegisterWithParent()
	RegisterSignals(parent, list(COMSIG_MOB_MIND_INITIALIZED, COMSIG_MOB_MIND_TRANSFERRED_INTO), PROC_REF(on_mind_arrived))
	RegisterSignal(parent, COMSIG_MOB_EQUIPPED_ITEM, PROC_REF(on_item_equipped))
	RegisterSignal(parent, COMSIG_HUMAN_EQUIPPING_ITEM, PROC_REF(on_equipping_item))
	on_mind_arrived()

/datum/component/paradise_zombie_mutation/UnregisterFromParent()
	stop_mutation_visuals()
	UnregisterSignal(parent, list(COMSIG_MOB_MIND_INITIALIZED, COMSIG_MOB_MIND_TRANSFERRED_INTO, COMSIG_MOB_EQUIPPED_ITEM, COMSIG_HUMAN_EQUIPPING_ITEM))
	QDEL_NULL(selection_action)
	clear_form()
	GLOB.paradise_zombie_mutation_progression.release_body(parent)

/datum/component/paradise_zombie_mutation/proc/on_mind_arrived()
	SIGNAL_HANDLER
	var/mob/living/carbon/human/host = parent
	GLOB.paradise_zombie_mutation_progression.note_infection(host)
	GLOB.paradise_zombie_mutation_progression.register_zombie(host)
	if(!form && !selection_action && GLOB.paradise_zombie_mutation_progression.is_mature_zombie(host))
		selection_action = new(src)
		selection_action.Grant(host)

/datum/component/paradise_zombie_mutation/proc/is_active(form_id)
	return !QDELETED(src) && GLOB.paradise_zombie_mutation_progression.is_mature_zombie(parent) && (!form_id || form?.id == form_id)

/datum/component/paradise_zombie_mutation/proc/can_begin()
	var/mob/living/carbon/human/host = parent
	if(!is_active() || form || IS_UNCONSCIOUS_OR_CRIT(host) || host.incapacitated || host.handcuffed || host.legcuffed || host.buckled || !isturf(host.loc) || !host.mind || host.mind.current != host)
		return FALSE
	for(var/obj/item/item as anything in host.get_equipped_items(INCLUDE_POCKETS|INCLUDE_HELD))
		if(!host.canUnEquip(item))
			return FALSE
	return TRUE

/// The menu and ritual may yield; ownership and population are checked again at the final claim.
/datum/component/paradise_zombie_mutation/proc/choose_form()
	if(mutating || !can_begin())
		return FALSE
	mutating = TRUE
	var/mob/living/carbon/human/host = parent
	var/datum/mind/choosing_mind = host.mind
	var/list/choices = list()
	var/list/ids_by_name = list()
	for(var/form_id in GLOB.paradise_zombie_mutation_forms)
		var/datum/paradise_zombie_form/choice = get_paradise_zombie_form(form_id)
		choices[choice.name] = image(choice.body_icon, "preview")
		ids_by_name[choice.name] = form_id
	var/selected = show_radial_menu(host, host, choices, radius = 48, require_near = TRUE, tooltips = TRUE)
	if(QDELETED(src))
		return FALSE
	var/datum/paradise_zombie_form/chosen = get_paradise_zombie_form(ids_by_name[selected])
	if(!chosen || host.mind != choosing_mind || !can_begin())
		mutating = FALSE
		return FALSE
	var/reason = GLOB.paradise_zombie_mutation_progression.get_unavailability_reason(host, chosen.id)
	if(reason)
		to_chat(host, span_warning(reason))
		mutating = FALSE
		return FALSE
	var/confirmed = tgui_alert(host, "[chosen.desc]\nОдежда и снаряжение упадут на пол. Этот разум сохранит выбранную специализацию даже после лечения.", chosen.name, list("Мутировать", "Отмена"))
	if(QDELETED(src))
		return FALSE
	if(confirmed != "Мутировать" || host.mind != choosing_mind || !can_begin())
		mutating = FALSE
		return FALSE
	mutating = FALSE
	return perform_mutation(chosen.id)

/// Runs the interruptible physical ritual after the menu's synchronous lock handoff.
/datum/component/paradise_zombie_mutation/proc/perform_mutation(form_id)
	if(mutating || !can_begin())
		return FALSE
	var/mob/living/carbon/human/host = parent
	var/reason = GLOB.paradise_zombie_mutation_progression.get_unavailability_reason(host, form_id)
	if(reason)
		to_chat(host, span_warning(reason))
		return FALSE
	mutating = TRUE
	var/datum/mind/choosing_mind = host.mind
	mutation_visual_active = TRUE
	RegisterSignals(host, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_DEATH, COMSIG_MOB_MIND_TRANSFERRED_OUT_OF), PROC_REF(stop_mutation_visuals))
	// Relative steps cancel out on the server while the client visibly swells and contracts.
	animate(host, transform = matrix().Scale(1.5), time = 0.5 SECONDS, loop = -1, flags = ANIMATION_RELATIVE|ANIMATION_PARALLEL, tag = PARADISE_ZOMBIE_MUTATION_ANIMATION_TAG)
	animate(transform = matrix().Scale(1 / 1.5), time = 0.5 SECONDS, flags = ANIMATION_RELATIVE)
	playsound(host, 'sound/effects/wounds/crack1.ogg', 60, TRUE)
	host.visible_message(span_warning("Тело [host] начинает болезненно перестраиваться!"))
	var/completed = do_after(host, 6 SECONDS, target = host)
	if(QDELETED(src))
		return FALSE
	var/visual_was_active = mutation_visual_active
	stop_mutation_visuals()
	mutating = FALSE
	if(!completed || !visual_was_active || host.mind != choosing_mind || !can_begin())
		return FALSE
	if(!apply_form(form_id))
		return FALSE
	playsound(host, 'sound/effects/goresplat.ogg', 75, TRUE)
	host.gib_animation()
	for(var/direction in GLOB.alldirs)
		new /obj/effect/temp_visual/dir_setting/bloodsplatter(get_turf(host), direction)
	return TRUE

/// Cancels just the evolution pulse, including while a do_after is still unwinding.
/datum/component/paradise_zombie_mutation/proc/stop_mutation_visuals()
	SIGNAL_HANDLER
	if(!mutation_visual_active)
		return
	mutation_visual_active = FALSE
	UnregisterSignal(parent, list(COMSIG_MOVABLE_MOVED, COMSIG_LIVING_DEATH, COMSIG_MOB_MIND_TRANSFERRED_OUT_OF))
	if(!QDELETED(parent))
		animate(parent, tag = PARADISE_ZOMBIE_MUTATION_ANIMATION_TAG)

/// Synchronous final application: no slot is held while a menu or transformation delay is pending.
/datum/component/paradise_zombie_mutation/proc/apply_form(form_id)
	if(!can_begin())
		return FALSE
	var/mob/living/carbon/human/host = parent
	var/datum/paradise_zombie_form/chosen = get_paradise_zombie_form(form_id)
	var/reason = GLOB.paradise_zombie_mutation_progression.get_unavailability_reason(host, form_id)
	if(!chosen || reason || !GLOB.paradise_zombie_mutation_progression.claim(host, form_id))
		if(reason)
			to_chat(host, span_warning(reason))
		return FALSE
	for(var/obj/item/item as anything in host.get_equipped_items(INCLUDE_POCKETS|INCLUDE_HELD))
		if(!host.dropItemToGround(item) || QDELETED(src) || !is_active())
			GLOB.paradise_zombie_mutation_progression.release_body(host)
			return FALSE
	form = chosen
	body_renderer = host.AddComponent(/datum/component/paradise_zombie_mutation_body, form_id)
	if(!body_renderer || !GLOB.paradise_zombie_mutation_progression.commit_choice(host, form_id))
		clear_form()
		GLOB.paradise_zombie_mutation_progression.release_body(host)
		return FALSE
	applied_health_bonus = max(chosen.health_bonus, 30 - host.maxHealth)
	host.setMaxHealth(host.maxHealth + applied_health_bonus)
	host.updatehealth()
	host.add_or_update_variable_movespeed_modifier(/datum/movespeed_modifier/paradise_zombie_mutation, multiplicative_slowdown = chosen.slowdown)
	for(var/ability_type in chosen.ability_types)
		var/datum/action/cooldown/paradise_zombie_mutation/ability = new ability_type(src)
		ability.controller_ref = WEAKREF(src)
		ability.Grant(host)
		granted_actions += ability
	for(var/obj/item/paradise_zombie_claw/claw in host.get_held_items())
		modify_claws(claw)
	QDEL_NULL(selection_action)
	host.visible_message(span_danger("Тело [host] превращается в чудовищную форму!"))
	to_chat(host, span_notice("Мутация: [chosen.name]. [chosen.desc]"))
	return TRUE

/datum/component/paradise_zombie_mutation/proc/clear_form()
	stop_mutation_visuals()
	QDEL_LIST(granted_actions)
	QDEL_NULL(body_renderer)
	var/mob/living/carbon/human/host = parent
	if(!QDELETED(host))
		for(var/obj/item/paradise_zombie_claw/claw in host.get_held_items())
			qdel(claw.GetComponent(/datum/component/paradise_zombie_mutation_claws))
		host.remove_movespeed_modifier(/datum/movespeed_modifier/paradise_zombie_mutation)
		if(applied_health_bonus)
			host.setMaxHealth(host.maxHealth - applied_health_bonus)
			host.updatehealth()
	applied_health_bonus = 0
	form = null

/datum/component/paradise_zombie_mutation/proc/modify_claws(obj/item/paradise_zombie_claw/claw)
	if(form && !claw.GetComponent(/datum/component/paradise_zombie_mutation_claws))
		claw.AddComponent(/datum/component/paradise_zombie_mutation_claws, form)

/datum/component/paradise_zombie_mutation/proc/on_item_equipped(mob/living/carbon/human/host, obj/item/item, slot)
	SIGNAL_HANDLER
	if(istype(item, /obj/item/paradise_zombie_claw))
		modify_claws(item)

/datum/component/paradise_zombie_mutation/proc/on_equipping_item(mob/living/carbon/human/host, obj/item/item, slot)
	SIGNAL_HANDLER
	if(form && !(slot & (ITEM_SLOT_HANDS|ITEM_SLOT_HANDCUFFED|ITEM_SLOT_LEGCUFFED)))
		return COMPONENT_BLOCK_EQUIP

/datum/action/cooldown/paradise_zombie_choose_mutation
	name = "Мутация чумы"
	desc = "Выбрать одну специализацию по мере развития эпидемии. После мутации одежда падает на пол."
	button_icon = 'icons/mob/actions/actions_spells.dmi'
	button_icon_state = "mutate"
	check_flags = AB_CHECK_CONSCIOUS|AB_CHECK_INCAPACITATED|AB_CHECK_HANDS_BLOCKED
	cooldown_time = 0

/datum/action/cooldown/paradise_zombie_choose_mutation/Activate(atom/target)
	var/datum/component/paradise_zombie_mutation/controller = src.target
	return IsAvailable() && controller.choose_form()

#undef PARADISE_ZOMBIE_MUTATION_ANIMATION_TAG
