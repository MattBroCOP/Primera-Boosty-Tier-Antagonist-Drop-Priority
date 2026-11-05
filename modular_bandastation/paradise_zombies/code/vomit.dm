/** Source vomiting applies confusion and movement slowdown, with no native stun or stomach purge. */
/mob/living/carbon/proc/paradise_vomit(lost_nutrition = 10, blood = FALSE, should_confuse = TRUE, distance = 0, message = TRUE, vomit_type_override = null)
	if(stat == DEAD || (mob_biotypes & MOB_ROBOTIC))
		return FALSE
	if(should_confuse)
		if(blood)
			Knockdown(10 SECONDS)
		adjust_confusion(8 SECONDS)
		apply_status_effect(/datum/status_effect/paradise_vomit_slow)
	if(!blood && nutrition < 100)
		if(message)
			visible_message(span_warning("[src] мучается от сухих рвотных позывов!"), span_userdanger("Вы пытаетесь вырвать, но желудок пуст!"))
		if(should_confuse)
			Knockdown(20 SECONDS)
			adjust_confusion(20 SECONDS)
		return TRUE
	if(message)
		visible_message(span_danger("[src] блюёт!"), span_userdanger("Вас рвёт!"))
	playsound(src, 'sound/effects/splat.ogg', 50, TRUE)
	var/turf/location = get_turf(src)
	for(var/index in 0 to distance)
		if(blood)
			if(location)
				add_splatter_floor(location)
			blood_volume = max(0, blood_volume - lost_nutrition)
			if(should_confuse)
				adjust_brute_loss(3)
		else
			if(location)
				location.add_vomit_floor(null, vomit_type_override || /obj/effect/decal/cleanable/vomit, NONE, 0)
			adjust_nutrition(-lost_nutrition)
			if(should_confuse)
				adjust_tox_loss(-3)
		if(location)
			for(var/mob/living/carbon/recipient in location)
				for(var/datum/disease/infection as anything in diseases)
					if(infection.spread_flags & (DISEASE_SPREAD_AIRBORNE|DISEASE_SPREAD_CONTACT_SKIN|DISEASE_SPREAD_CONTACT_FLUIDS))
						recipient.ContactContractDisease(infection)
		location = get_step(location, dir)
		if(!location || location.is_blocked_turf())
			break
	return TRUE

/** Fake vomiting is purely cosmetic and never changes nutrition, medicine, damage or mobility. */
/mob/proc/paradise_fakevomit(green = FALSE, no_text = FALSE)
	var/turf/open/location = loc
	if(stat == DEAD || !istype(location) || isspaceturf(location))
		return FALSE
	if(!no_text)
		if(green)
			visible_message(span_warning("[src] извергает зелёную жижу!"), span_warning("Вас рвёт зелёной жижей!"))
		else
			visible_message(span_warning("[src] заблёвывает себя!"), span_warning("Вы заблёвываете себя!"))
	location.add_vomit_floor(null, green ? /obj/effect/decal/cleanable/vomit/toxic : /obj/effect/decal/cleanable/vomit, NONE, 0)
	return TRUE

/** Paradise's eight-second Slowed(1) effect has a dedicated source and is cleared by rejuvenation. */
/datum/status_effect/paradise_vomit_slow
	id = "paradise_vomit_slow"
	alert_type = null
	duration = 8 SECONDS
	status_type = STATUS_EFFECT_REFRESH
	remove_on_fullheal = TRUE
	heal_flag_necessary = HEAL_CC_STATUS

/datum/status_effect/paradise_vomit_slow/on_apply()
	owner.add_movespeed_modifier(/datum/movespeed_modifier/paradise_vomit)
	return TRUE

/datum/status_effect/paradise_vomit_slow/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/paradise_vomit)

/datum/movespeed_modifier/paradise_vomit
	multiplicative_slowdown = 1
