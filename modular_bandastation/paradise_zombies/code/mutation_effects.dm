/** Short cosmetic pulses; native temp-visual timers own every effect's lifetime. */
/obj/effect/temp_visual/paradise_zombie_wave
	parent_type = /obj/effect/temp_visual/circle_wave
	duration = 0.6 SECONDS
	max_alpha = 190

/obj/effect/temp_visual/paradise_zombie_wave/Initialize(mapload, set_color = BLOOD_COLOR_RED, wave_scale = 2)
	amount_to_scale = wave_scale
	return ..(mapload, set_color)

/** The native bubble-pop artwork has no venom, reagents or collision effects attached. */
/obj/effect/temp_visual/paradise_zombie_splash
	icon = 'icons/obj/weapons/guns/projectiles.dmi'
	icon_state = "leaper_bubble_pop"
	duration = 0.4 SECONDS
	randomdir = FALSE

/obj/effect/temp_visual/paradise_zombie_splash/Initialize(mapload, set_color = "#99BB22")
	. = ..()
	color = set_color
	transform = matrix().Scale(1.4)
	animate(src, alpha = 0, transform = matrix().Scale(1.8), time = duration)

/** Snapshot actual DS13 overlays, including a currently swinging arm, without sharing live visuals. */
/obj/effect/temp_visual/paradise_zombie_afterimage
	parent_type = /obj/effect/temp_visual/decoy/fading/halfsecond

/obj/effect/temp_visual/paradise_zombie_afterimage/Initialize(mapload, mob/living/carbon/human/actor, shade = "#BA5368")
	if(QDELETED(actor) || actor.alpha <= 0)
		return INITIALIZE_HINT_QDEL
	. = ..(mapload, actor, min(actor.alpha, 110))
	invisibility = actor.invisibility
	color = shade
	var/datum/component/paradise_zombie_mutation_body/body = actor.GetComponent(/datum/component/paradise_zombie_mutation_body)
	if(body && !QDELETED(body.melee_visual))
		var/mutable_appearance/swing = new(body.melee_visual.appearance)
		add_overlay(swing)
