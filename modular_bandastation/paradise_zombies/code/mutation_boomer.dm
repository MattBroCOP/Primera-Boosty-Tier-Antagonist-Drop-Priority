/** A short, visible blinding shot complements the original Exploder suicide blast. */
/datum/action/cooldown/paradise_zombie_mutation/vomit_bile
	name = "Извергнуть желчь"
	desc = "Выплеснуть видимую желчь до 5 клеток. Попадание полностью закрывает зрение на 5 секунд; желчь можно смыть с лица. Преграды и полная биозащита останавливают попадание. Зомби не страдают. Перезарядка — 20 секунд."
	button_icon_state = "vomit"
	required_form = "exploder"
	cooldown_time = 20 SECONDS
	click_to_activate = TRUE

/datum/action/cooldown/paradise_zombie_mutation/vomit_bile/is_active()
	return ..() && !HAS_TRAIT(owner, TRAIT_PACIFISM)

/datum/action/cooldown/paradise_zombie_mutation/vomit_bile/Activate(atom/target)
	var/mob/living/carbon/human/user = owner
	var/turf/destination = get_turf(target)
	if(!IsAvailable() || !destination || !isturf(user.loc) || destination.z != user.z || destination == user.loc || get_dist_euclidean(user, destination) > 5)
		return FALSE
	if(isliving(target) && !can_hit(target))
		return FALSE
	var/obj/projectile/paradise_zombie_boomer_vomit/shot = new(get_turf(user))
	shot.action_ref = WEAKREF(src)
	shot.firer = user
	shot.fired_from = src
	shot.def_zone = BODY_ZONE_HEAD
	shot.aim_projectile(target, get_turf(user))
	track_effect(shot)
	new /obj/effect/temp_visual/paradise_zombie_wave(get_turf(user), "#BBAA22", 0.8)
	playsound(user, 'sound/mobs/humanoids/human/gag_vomit/crack_vomit.ogg', 55, TRUE)
	StartCooldown()
	shot.fire()
	return TRUE

/obj/projectile/paradise_zombie_boomer_vomit
	name = "густая желчь"
	icon_state = "neurotoxin"
	color = "#BBAA22"
	hitsound = 'sound/misc/moist_impact.ogg'
	damage = 0
	armor_flag = BIO
	range = 5
	speed = 0.8
	var/datum/weakref/action_ref

/obj/projectile/paradise_zombie_boomer_vomit/is_hostile_projectile()
	return TRUE

/obj/projectile/paradise_zombie_boomer_vomit/can_hit_target(atom/target, direct_target = FALSE, ignore_loc = FALSE, cross_failed = FALSE)
	var/datum/action/cooldown/paradise_zombie_mutation/action = action_ref?.resolve()
	if(!action?.is_active() || (isliving(target) && !action.can_hit(target)))
		return FALSE
	return ..()

/obj/projectile/paradise_zombie_boomer_vomit/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	var/datum/action/cooldown/paradise_zombie_mutation/action = action_ref?.resolve()
	var/turf/impact_tile = get_turf(target)
	if(. != BULLET_ACT_BLOCK && action?.is_active() && impact_tile)
		new /obj/effect/temp_visual/paradise_zombie_splash(impact_tile, "#BBAA22")
	if(. == BULLET_ACT_BLOCK || blocked >= 100 || !action?.is_active() || !isliving(target) || !action.can_hit(target))
		return .
	var/mob/living/victim = target
	var/datum/status_effect/paradise_zombie_boomer_bile/blind = victim.apply_status_effect(/datum/status_effect/paradise_zombie_boomer_bile, action)
	if(blind)
		action.track_effect(blind)

/obj/projectile/paradise_zombie_boomer_vomit/Destroy()
	action_ref = null
	return ..()

/** Unique native blindness sources let washing, expiry and caster cleanup preserve everyone else's blindness. */
/datum/status_effect/paradise_zombie_boomer_bile
	id = "paradise_zombie_boomer_bile"
	duration = 5 SECONDS
	tick_interval = 1 SECONDS
	status_type = STATUS_EFFECT_MULTIPLE
	alert_type = null
	on_remove_on_mob_delete = TRUE
	remove_on_fullheal = TRUE
	var/datum/weakref/action_ref

/datum/status_effect/paradise_zombie_boomer_bile/on_creation(mob/living/new_owner, datum/action/cooldown/paradise_zombie_mutation/action)
	action_ref = WEAKREF(action)
	return ..()

/datum/status_effect/paradise_zombie_boomer_bile/on_apply()
	var/datum/action/cooldown/paradise_zombie_mutation/action = action_ref?.resolve()
	if(!action?.can_hit(owner) || !owner.become_blind(REF(src)))
		return FALSE
	RegisterSignals(owner, list(COMSIG_COMPONENT_CLEAN_ACT, COMSIG_COMPONENT_CLEAN_FACE_ACT), PROC_REF(on_cleaned))
	RegisterSignals(owner, list(COMSIG_LIVING_DEATH, COMSIG_MOB_MIND_TRANSFERRED_INTO, COMSIG_MOB_MIND_TRANSFERRED_OUT_OF, SIGNAL_ADDTRAIT(TRAIT_PARADISE_ZOMBIE)), PROC_REF(on_interrupted))
	to_chat(owner, span_userdanger("Желчь заливает глаза! Можно смыть её с лица."))
	return TRUE

/datum/status_effect/paradise_zombie_boomer_bile/tick(seconds_between_ticks)
	var/datum/action/cooldown/paradise_zombie_mutation/action = action_ref?.resolve()
	if(!action?.can_hit(owner))
		qdel(src)

/datum/status_effect/paradise_zombie_boomer_bile/proc/on_cleaned(datum/source, clean_types)
	SIGNAL_HANDLER
	if(clean_types & CLEAN_TYPE_BLOOD)
		qdel(src)
		return COMPONENT_CLEANED

/datum/status_effect/paradise_zombie_boomer_bile/proc/on_interrupted()
	SIGNAL_HANDLER
	qdel(src)

/datum/status_effect/paradise_zombie_boomer_bile/on_remove()
	UnregisterSignal(owner, list(COMSIG_COMPONENT_CLEAN_ACT, COMSIG_COMPONENT_CLEAN_FACE_ACT, COMSIG_LIVING_DEATH, COMSIG_MOB_MIND_TRANSFERRED_INTO, COMSIG_MOB_MIND_TRANSFERRED_OUT_OF, SIGNAL_ADDTRAIT(TRAIT_PARADISE_ZOMBIE)))
	owner.cure_blind(REF(src))
	action_ref = null
