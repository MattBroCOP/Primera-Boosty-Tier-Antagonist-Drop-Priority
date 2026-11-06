/** A separate shot turns the existing visible bile impact into a short-lived area hazard. */
/datum/action/cooldown/paradise_zombie_mutation/bile/acid
	name = "Кислотный плевок"
	desc = "Плюнуть кислотой до 13 клеток. Попадание оставляет на 12 секунд смываемые лужи в пределах одной клетки. Они обжигают стоящих в них противников на 4 единицы в секунду до учёта биологической защиты."
	button_icon_state = "acid"
	cooldown_time = 20 SECONDS
	projectile_type = /obj/projectile/paradise_zombie_bile/acid

/obj/projectile/paradise_zombie_bile/acid
	name = "кислотная желчь"
	color = "#66CC22"
	hitsound = 'sound/effects/wounds/sizzle2.ogg'
	puddle_type = /obj/effect/decal/cleanable/paradise_zombie_bile/acid

/obj/projectile/paradise_zombie_bile/acid/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	var/datum/action/cooldown/paradise_zombie_mutation/action = action_ref?.resolve()
	var/turf/impact_tile = get_turf(target)
	if(. == BULLET_ACT_BLOCK || !action?.is_active() || !isopenturf(impact_tile) || impact_tile.is_blocked_turf(exclude_mobs = TRUE))
		return .
	for(var/turf/open/tile in view(1, impact_tile))
		if(tile == impact_tile || tile.is_blocked_turf(exclude_mobs = TRUE) || !tile.Adjacent(impact_tile))
			continue
		var/obj/effect/decal/cleanable/paradise_zombie_bile/acid/puddle = new(tile, action)
		if(!QDELETED(puddle))
			action.track_effect(puddle)

/** Independent ownership survives overlapping casts; native cleaning and the inherited timer remove each pool. */
/obj/effect/decal/cleanable/paradise_zombie_bile/acid
	name = "кислотная желчь"
	desc = "Едкая лужа обжигает живых противников, пока они находятся в ней. Её можно смыть."
	icon = 'icons/effects/acid.dmi'
	icon_state = "default"
	color = "#66CC22"
	alpha = 225

/obj/effect/decal/cleanable/paradise_zombie_bile/acid/Initialize(mapload, datum/action/cooldown/paradise_zombie_mutation/action)
	. = ..()
	if(. != INITIALIZE_HINT_QDEL)
		animate(src, transform = matrix().Scale(1.03), alpha = 235, time = 0.6 SECONDS, loop = -1)
		animate(transform = matrix().Scale(0.97), alpha = 205, time = 0.6 SECONDS)
		START_PROCESSING(SSprocessing, src)

/obj/effect/decal/cleanable/paradise_zombie_bile/acid/Destroy()
	STOP_PROCESSING(SSprocessing, src)
	return ..()

/obj/effect/decal/cleanable/paradise_zombie_bile/acid/process(seconds_per_tick)
	var/datum/action/cooldown/paradise_zombie_mutation/action = action_ref?.resolve()
	if(!action?.is_active())
		qdel(src)
		return
	for(var/mob/living/victim in loc)
		slow_target(victim)

/// Acid has its own damage status; the original bile remains the separate slowing attack.
/obj/effect/decal/cleanable/paradise_zombie_bile/acid/slow_target(mob/living/victim)
	var/datum/action/cooldown/paradise_zombie_mutation/action = action_ref?.resolve()
	if(action?.can_hit(victim))
		victim.apply_status_effect(/datum/status_effect/paradise_zombie_acid)

/** One victim-owned status samples current pools, so overlapping sources never multiply damage. */
/datum/status_effect/paradise_zombie_acid
	id = "paradise_zombie_acid"
	duration = 3 SECONDS
	tick_interval = 1 SECONDS
	status_type = STATUS_EFFECT_REFRESH
	alert_type = null

/datum/status_effect/paradise_zombie_acid/on_apply()
	return !isnull(find_active_pool())

/datum/status_effect/paradise_zombie_acid/proc/find_active_pool()
	if(!isturf(owner.loc) || owner.stat == DEAD)
		return null
	for(var/obj/effect/decal/cleanable/paradise_zombie_bile/acid/puddle in owner.loc)
		var/datum/action/cooldown/paradise_zombie_mutation/action = puddle.action_ref?.resolve()
		if(!QDELETED(puddle) && action?.can_hit(owner))
			return puddle
	return null

/datum/status_effect/paradise_zombie_acid/tick(seconds_between_ticks)
	if(!find_active_pool())
		qdel(src)
		return
	var/blocked = owner.run_armor_check(BODY_ZONE_CHEST, BIO, silent = TRUE)
	owner.apply_damage(4 * seconds_between_ticks, BURN, BODY_ZONE_CHEST, blocked = blocked, wound_bonus = CANT_WOUND)
