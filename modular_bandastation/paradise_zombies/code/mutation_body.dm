/** Renders DS13 flesh mutations over the current anatomy without replacing any biological state. */
/datum/component/paradise_zombie_mutation_body
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// Mutation selected by the progression controller.
	var/form_id
	/// Original DS13 bodypart sheet; its complete directional and animation metadata is retained.
	var/body_icon
	/// DS13 state prefix; the bile mutation uses the original Puker artwork.
	var/state_prefix
	/// Complete bodypart appearances currently added to the host.
	var/list/body_appearances = list()
	/// Attached native flick visual, owned here so cure and anatomy changes can cancel it.
	var/atom/movable/flick_visual/melee_visual
	/// Resting arm hidden only while its attack image is visible.
	var/melee_zone
	/// Horizontal anchor of the selected source artwork.
	var/form_pixel_x = -8
	/// The body's pre-mutation resting horizontal anchor.
	var/old_base_pixel_x
	/// The body's pre-mutation resting vertical anchor.
	var/old_base_pixel_y
	/// Appearance flags added by this component, removed without touching pre-existing flags.
	var/added_appearance_flags = NONE
	/// Whether the component has applied its appearance and must restore it during teardown.
	var/appearance_applied = FALSE
	/// These human overlays are retained in the native cache but hidden while flesh has another shape.
	var/static/list/hidden_layers = list(BODYPARTS_LAYER, BODY_LAYER, HAIR_LAYER, EYES_LAYER, DAMAGE_LAYER, WOUND_LAYER, HANDS_LAYER)

/datum/component/paradise_zombie_mutation_body/Initialize(new_form_id)
	if(!ishuman(parent) || !set_form(new_form_id))
		return COMPONENT_INCOMPATIBLE
	var/mob/living/carbon/human/host = parent
	old_base_pixel_x = host.base_pixel_x
	old_base_pixel_y = host.base_pixel_y

/datum/component/paradise_zombie_mutation_body/RegisterWithParent()
	RegisterSignal(parent, COMSIG_CARBON_APPLY_OVERLAY, PROC_REF(on_overlay_applied))
	RegisterSignals(parent, list(COMSIG_CARBON_POST_ATTACH_LIMB, COMSIG_CARBON_POST_REMOVE_LIMB), PROC_REF(on_anatomy_changed))
	appearance_applied = TRUE
	var/mob/living/carbon/human/host = parent
	added_appearance_flags = (KEEP_TOGETHER | TILE_BOUND | PIXEL_SCALE | LONG_GLIDE) & ~host.appearance_flags
	host.appearance_flags |= added_appearance_flags
	apply_anchor()
	for(var/hidden_layer in hidden_layers)
		host.cut_overlay(host.overlays_standing[hidden_layer])
	redraw_body()

/datum/component/paradise_zombie_mutation_body/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_CARBON_APPLY_OVERLAY, COMSIG_CARBON_POST_ATTACH_LIMB, COMSIG_CARBON_POST_REMOVE_LIMB))
	if(!appearance_applied)
		return
	appearance_applied = FALSE
	clear_melee_visual()
	var/mob/living/carbon/human/host = parent
	host.cut_overlay(body_appearances)
	body_appearances.Cut()
	if(QDELETED(host))
		return
	host.base_pixel_x = old_base_pixel_x
	host.base_pixel_y = old_base_pixel_y
	host.update_offsets()
	host.appearance_flags &= ~added_appearance_flags
	// A creating update would recolor transplanted tissue from the recipient's DNA.
	host.update_body()
	for(var/hidden_layer in hidden_layers)
		host.cut_overlay(host.overlays_standing[hidden_layer])
		host.apply_overlay(hidden_layer)

/** Switches an existing visual mutation while keeping the same real limbs, organs and DNA. */
/datum/component/paradise_zombie_mutation_body/proc/set_form(new_form_id)
	var/datum/paradise_zombie_form/chosen = get_paradise_zombie_form(new_form_id)
	if(!chosen)
		return FALSE
	clear_melee_visual()
	form_id = chosen.id
	body_icon = chosen.body_icon
	state_prefix = form_id == "spitter" ? "puker" : form_id
	form_pixel_x = form_id == "brute" ? -16 : -8
	if(appearance_applied)
		apply_anchor()
		redraw_body()
	return TRUE

/** Uses the source's resting anchor without changing race, body height, physical size or limb data. */
/datum/component/paradise_zombie_mutation_body/proc/apply_anchor()
	var/mob/living/carbon/human/host = parent
	host.pixel_x = form_pixel_x
	host.base_pixel_x = form_pixel_x
	host.pixel_y = 0
	host.base_pixel_y = 0

/datum/component/paradise_zombie_mutation_body/proc/on_overlay_applied(mob/living/carbon/human/source, cache_index, list/applied_overlays)
	SIGNAL_HANDLER
	if(!(cache_index in hidden_layers))
		return
	source.cut_overlay(applied_overlays)
	if(cache_index == BODYPARTS_LAYER)
		redraw_body()

/datum/component/paradise_zombie_mutation_body/proc/on_anatomy_changed()
	SIGNAL_HANDLER
	clear_melee_visual()
	redraw_body()

/** Draws actual attached limbs, so removal and transplantation remain native anatomy operations. */
/datum/component/paradise_zombie_mutation_body/proc/redraw_body()
	var/mob/living/carbon/human/host = parent
	host.cut_overlay(body_appearances)
	body_appearances.Cut()
	for(var/obj/item/bodypart/limb as anything in host.get_bodyparts())
		if(IS_STUMP(limb) || limb.is_invisible)
			continue
		if(limb.body_zone == melee_zone)
			continue
		// The source Exploder's fused legs are painted into its chest, not separate limb states.
		if(form_id == "exploder" && (limb.body_zone in list(BODY_ZONE_L_LEG, BODY_ZONE_R_LEG)))
			continue
		var/body_state = "[state_prefix]_[limb.body_zone]"
		if(!icon_exists(body_icon, body_state))
			continue
		body_appearances += mutable_appearance(body_icon, body_state, layer = -BODYPARTS_LAYER)
	host.add_overlay(body_appearances)

/** Animates original DS13 arm pixels without changing the limb, attack range, timing or damage. */
/datum/component/paradise_zombie_mutation_body/proc/animate_melee(atom/target, hand_index)
	var/mob/living/carbon/human/host = parent
	if(!appearance_applied || !hand_index || QDELETED(target))
		return FALSE
	var/arm_zone = IS_RIGHT_INDEX(hand_index) ? BODY_ZONE_R_ARM : BODY_ZONE_L_ARM
	// The Exploder's left limb is its explosive bag; melee always uses its free arm.
	if(form_id == "exploder")
		arm_zone = BODY_ZONE_R_ARM
	var/obj/item/bodypart/arm = host.get_bodypart(arm_zone)
	if(!arm || IS_STUMP(arm) || arm.is_invisible)
		return FALSE
	clear_melee_visual()
	melee_zone = arm_zone
	var/mutable_appearance/swing = mutable_appearance(body_icon, "[state_prefix]_[arm_zone]", layer = ABOVE_MOB_LAYER)
	swing.dir = host.dir
	var/hand_sign = arm_zone == BODY_ZONE_R_ARM ? -1 : 1
	var/matrix/start = matrix()
	var/matrix/finish = matrix()
	if(form_id == "hunter")
		swing.icon = 'modular_bandastation/paradise_zombies/icons/mutations/hunter_swing.dmi'
		swing.icon_state = "hunter_[hand_sign == 1 ? "left" : "right"]"
		swing.pixel_x = -40 - form_pixel_x
		swing.pixel_y = -32
		start.Turn(dir2angle(get_dir(host, target)) - 55 * hand_sign)
		finish = matrix(start).Turn(110 * hand_sign)
	else
		start.Turn(-12 * hand_sign)
		finish.Turn(18 * hand_sign)
		var/direction = get_dir(host, target)
		finish.Translate(direction & EAST ? 6 : direction & WEST ? -6 : 0, direction & NORTH ? 6 : direction & SOUTH ? -6 : 0)
	swing.transform = start
	melee_visual = host.flick_overlay_view(swing, 0.3 SECONDS)
	RegisterSignal(melee_visual, COMSIG_QDELETING, PROC_REF(on_melee_visual_deleted))
	redraw_body()
	animate(melee_visual, transform = finish, time = 0.15 SECONDS, easing = CIRCULAR_EASING)
	if(form_id == "hunter")
		animate(alpha = 0, time = 0.15 SECONDS)
	else
		animate(transform = matrix(), time = 0.15 SECONDS)
	return TRUE

/// A timed flick's deletion returns the resting arm only if this renderer still owns the body.
/datum/component/paradise_zombie_mutation_body/proc/on_melee_visual_deleted()
	SIGNAL_HANDLER
	melee_visual = null
	melee_zone = null
	if(appearance_applied)
		redraw_body()

/// Cancel cosmetic movement without touching native two-handing, anatomy or body transforms.
/datum/component/paradise_zombie_mutation_body/proc/clear_melee_visual()
	if(melee_visual)
		UnregisterSignal(melee_visual, COMSIG_QDELETING)
		QDEL_NULL(melee_visual)
	melee_zone = null
	if(appearance_applied)
		redraw_body()
