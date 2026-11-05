/** Shows the original TGMC zombie anatomy without changing Paradise infection, native husking or real tissue. */
/datum/component/paradise_zombie_appearance
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// Pinned TGMC source sheets, retained as complete unmodified DMI files.
	var/static/body_file = 'modular_bandastation/paradise_zombies/icons/tgmc/body.dmi'
	/// TGMC adds its eyes_s state after composing all bodyparts, with default black eye color.
	var/static/face_file = 'modular_bandastation/paradise_zombies/icons/tgmc/face.dmi'
	/// Native body layers hidden by this appearance; clothing, restraints and held claws stay visible.
	var/static/list/hidden_layers = list(BODYPARTS_LAYER, HAIR_LAYER, EYES_LAYER)
	/// Real TG anatomy controlling each of TGMC's eleven visible pieces.
	var/static/list/state_zones = list(
		"torso" = BODY_ZONE_CHEST,
		"groin" = BODY_ZONE_CHEST,
		"head" = BODY_ZONE_HEAD,
		"l_arm" = BODY_ZONE_L_ARM,
		"r_arm" = BODY_ZONE_R_ARM,
		"l_leg" = BODY_ZONE_L_LEG,
		"r_leg" = BODY_ZONE_R_LEG,
		"l_hand" = BODY_ZONE_L_ARM,
		"r_hand" = BODY_ZONE_R_ARM,
		"l_foot" = BODY_ZONE_L_LEG,
		"r_foot" = BODY_ZONE_R_LEG,
	)
	/// The donor underlays the far leg and foot in side views.
	var/static/list/front_order = list("torso", "groin", "head", "l_arm", "r_arm", "l_leg", "r_leg", "l_hand", "r_hand", "l_foot", "r_foot")
	/// Original TGMC EAST composition, from back to front.
	var/static/list/east_order = list("l_foot", "l_leg", "torso", "groin", "head", "l_arm", "r_arm", "r_leg", "l_hand", "r_hand", "r_foot")
	/// Original TGMC WEST composition, from back to front.
	var/static/list/west_order = list("r_foot", "r_leg", "torso", "groin", "head", "l_arm", "r_arm", "l_leg", "l_hand", "r_hand", "l_foot")
	/// The component owns this appearance only; native overlay caches remain intact.
	var/mutable_appearance/body_appearance
	/// Anatomy and physique signature of the cached directional composition.
	var/body_icon_key
	/// All four directions are composed once per anatomy change, never once per turn or healing update.
	var/icon/cached_body_icon

/datum/component/paradise_zombie_appearance/Initialize()
	if(!ishuman(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/paradise_zombie_appearance/RegisterWithParent()
	RegisterSignal(parent, COMSIG_CARBON_APPLY_OVERLAY, PROC_REF(on_overlay_applied))
	RegisterSignals(parent, list(COMSIG_CARBON_POST_ATTACH_LIMB, COMSIG_CARBON_POST_REMOVE_LIMB), PROC_REF(on_anatomy_changed))
	RegisterSignal(parent, COMSIG_COMPONENT_ADDED, PROC_REF(on_component_added))
	RegisterSignal(parent, COMSIG_COMPONENT_REMOVING, PROC_REF(on_component_removed))
	var/mob/living/carbon/human/host = parent
	for(var/hidden_layer in hidden_layers)
		host.cut_overlay(host.overlays_standing[hidden_layer])
	redraw_body()

/datum/component/paradise_zombie_appearance/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_CARBON_APPLY_OVERLAY, COMSIG_CARBON_POST_ATTACH_LIMB, COMSIG_CARBON_POST_REMOVE_LIMB, COMSIG_COMPONENT_ADDED, COMSIG_COMPONENT_REMOVING))
	var/mob/living/carbon/human/host = parent
	host.cut_overlay(body_appearance)
	body_appearance = null
	if(QDELETED(host))
		return
	// Creating updates would recolor transplanted limbs from the current owner's DNA.
	host.update_body()
	for(var/hidden_layer in hidden_layers)
		host.cut_overlay(host.overlays_standing[hidden_layer])
		host.apply_overlay(hidden_layer)

/datum/component/paradise_zombie_appearance/proc/on_overlay_applied(mob/living/carbon/human/source, cache_index, list/applied_overlays)
	SIGNAL_HANDLER
	if(!(cache_index in hidden_layers))
		return
	source.cut_overlay(applied_overlays)
	if(cache_index == BODYPARTS_LAYER)
		redraw_body()

/datum/component/paradise_zombie_appearance/proc/on_anatomy_changed()
	SIGNAL_HANDLER
	body_icon_key = null
	redraw_body()

/datum/component/paradise_zombie_appearance/proc/on_component_added(datum/source, datum/component/added)
	SIGNAL_HANDLER
	if(istype(added, /datum/component/paradise_zombie_mutation_body))
		redraw_body()

/datum/component/paradise_zombie_appearance/proc/on_component_removed(datum/source, datum/component/removed)
	SIGNAL_HANDLER
	if(istype(removed, /datum/component/paradise_zombie_mutation_body))
		// Removal is announced after the DS renderer has restored its native cached layers.
		redraw_body(removed)

/** Removes the previous image before either painting TGMC anatomy or yielding to a DS13 mutation. */
/datum/component/paradise_zombie_appearance/proc/redraw_body(datum/component/paradise_zombie_mutation_body/removed_mutation)
	var/mob/living/carbon/human/host = parent
	host.cut_overlay(body_appearance)
	body_appearance = null
	var/datum/component/paradise_zombie_mutation_body/mutation = host.GetComponent(/datum/component/paradise_zombie_mutation_body)
	if(mutation && mutation != removed_mutation && !QDELETED(mutation))
		return
	body_appearance = mutable_appearance(get_body_icon(), layer = -BODYPARTS_LAYER)
	host.apply_height(body_appearance, ENTIRE_BODY)
	host.add_overlay(body_appearance)

/** Rebuilds the donor's real bodypart composition only when attached visible anatomy or physique changes. */
/datum/component/paradise_zombie_appearance/proc/get_body_icon()
	var/mob/living/carbon/human/host = parent
	var/body_sex = host.physique == FEMALE ? "f" : "m"
	var/list/visible_zones = list()
	var/new_key = body_sex
	for(var/zone in list(BODY_ZONE_CHEST, BODY_ZONE_HEAD, BODY_ZONE_L_ARM, BODY_ZONE_R_ARM, BODY_ZONE_L_LEG, BODY_ZONE_R_LEG))
		var/obj/item/bodypart/limb = host.get_bodypart(zone)
		var/visible = limb && !IS_STUMP(limb) && !limb.is_invisible
		new_key += "[!!visible]"
		if(visible)
			visible_zones += zone
	if(cached_body_icon && body_icon_key == new_key)
		return cached_body_icon
	var/icon/composite = icon('icons/blanks/32x32.dmi', "nothing")
	for(var/direction in GLOB.cardinals)
		var/list/draw_order = front_order
		if(direction == EAST)
			draw_order = east_order
		else if(direction == WEST)
			draw_order = west_order
		var/icon/frame = icon('icons/blanks/32x32.dmi', "nothing")
		for(var/state in draw_order)
			if(!(state_zones[state] in visible_zones))
				continue
			var/body_state = (state in list("torso", "groin", "head")) ? "[state]_[body_sex]" : state
			frame.Blend(icon(body_file, body_state, direction), ICON_OVERLAY)
		if(BODY_ZONE_HEAD in visible_zones)
			var/icon/eyes = icon(face_file, "eyes_s", direction)
			eyes.Blend("#000000", ICON_ADD)
			frame.Blend(eyes, ICON_OVERLAY)
		composite.Insert(frame, "", direction)
	body_icon_key = new_key
	cached_body_icon = composite
	return cached_body_icon
