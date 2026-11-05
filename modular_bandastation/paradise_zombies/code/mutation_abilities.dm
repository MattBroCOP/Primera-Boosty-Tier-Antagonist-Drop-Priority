/** Applies a mutation's melee modifiers after Paradise has resolved its antibiotic weakening. */
/datum/component/paradise_zombie_mutation_claws
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// Multiplier of the current normal or Beta-weakened claw force.
	var/claw_multiplier = 1
	/// Additional damage dealt only to actual defensive barriers.
	var/barrier_damage_bonus = 0
	/// Unmodified force restored when this component is removed.
	var/unmodified_force
	/// Mutation artwork used only by the two native hand slots.
	var/form_id
	/// Original primary HUD icon, restored on removal.
	var/old_icon
	/// Original primary HUD state.
	var/old_icon_state
	/// Native reservation remains owned by the two-handed component.
	var/datum/weakref/offhand_ref
	/// Original reserved offhand HUD icon.
	var/old_offhand_icon
	/// Original reserved offhand HUD state.
	var/old_offhand_icon_state

/datum/component/paradise_zombie_mutation_claws/Initialize(datum/paradise_zombie_form/form)
	if(!istype(parent, /obj/item/paradise_zombie_claw) || !istype(form))
		return COMPONENT_INCOMPATIBLE
	claw_multiplier = form.claw_multiplier
	barrier_damage_bonus = form.barrier_damage_bonus
	form_id = form.id
	var/obj/item/paradise_zombie_claw/claws = parent
	old_icon = claws.icon
	old_icon_state = claws.icon_state
	unmodified_force = claws.force
	claws.force *= claw_multiplier

/datum/component/paradise_zombie_mutation_claws/RegisterWithParent()
	RegisterSignal(parent, COMSIG_ITEM_PRE_ATTACK, PROC_REF(on_pre_attack))
	RegisterSignal(parent, COMSIG_ITEM_AFTERATTACK, PROC_REF(on_afterattack))
	RegisterSignal(parent, COMSIG_ITEM_ENTERED_HANDS, PROC_REF(update_hand_icons))
	RegisterSignal(parent, COMSIG_ITEM_ATTACK_ANIMATION, PROC_REF(on_attack_animation))
	var/obj/item/paradise_zombie_claw/claws = parent
	update_hand_icons(claws, claws.loc)

/datum/component/paradise_zombie_mutation_claws/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_ITEM_PRE_ATTACK, COMSIG_ITEM_AFTERATTACK, COMSIG_ITEM_ENTERED_HANDS, COMSIG_ITEM_ATTACK_ANIMATION))
	var/obj/item/paradise_zombie_claw/claws = parent
	var/obj/item/offhand = offhand_ref?.resolve()
	if(offhand)
		offhand.icon = old_offhand_icon
		offhand.icon_state = old_offhand_icon_state
	offhand_ref = null
	if(!QDELETED(claws))
		claws.force = unmodified_force
		claws.icon = old_icon
		claws.icon_state = old_icon_state
	if(ishuman(claws.loc))
		var/mob/living/carbon/human/host = claws.loc
		var/datum/component/paradise_zombie_mutation_body/body = host.GetComponent(/datum/component/paradise_zombie_mutation_body)
		body?.clear_melee_visual()
		host.update_held_items()

/// ENTERED_HANDS runs after native two-handing has created and equipped its reserved offhand.
/datum/component/paradise_zombie_mutation_claws/proc/update_hand_icons(obj/item/paradise_zombie_claw/source, mob/living/carbon/user)
	SIGNAL_HANDLER
	if(!istype(user))
		return
	var/hand_index = user.get_held_index_of_item(source)
	if(!hand_index)
		return
	source.icon = 'modular_bandastation/paradise_zombies/icons/mutations/melee_hud.dmi'
	source.icon_state = "[form_id]_[IS_RIGHT_INDEX(hand_index) ? "right" : "left"]"
	var/datum/component/two_handed/two_handed = source.GetComponent(/datum/component/two_handed)
	var/obj/item/offhand = two_handed?.offhand_item
	if(offhand)
		if(offhand != offhand_ref?.resolve())
			offhand_ref = WEAKREF(offhand)
			old_offhand_icon = offhand.icon
			old_offhand_icon_state = offhand.icon_state
		offhand.icon = source.icon
		offhand.icon_state = "[form_id]_[IS_RIGHT_INDEX(two_handed.offhand_index) ? "right" : "left"]"
	user.update_held_items()

/// Keep the native body lunge and hit chain, replacing only the floating claw image with the form's arm.
/datum/component/paradise_zombie_mutation_claws/proc/on_attack_animation(obj/item/paradise_zombie_claw/source, atom/movable/attacker, atom/target, animation_type, list/image_override)
	SIGNAL_HANDLER
	if(!ishuman(attacker))
		return
	var/mob/living/carbon/human/host = attacker
	var/datum/component/paradise_zombie_mutation_body/body = host.GetComponent(/datum/component/paradise_zombie_mutation_body)
	if(body?.animate_melee(target, host.get_held_index_of_item(source)))
		// Native item animations raise alpha again, so the replacement must contain no pixels.
		var/image/hidden_claw = image('icons/blanks/32x32.dmi', icon_state = "nothing")
		image_override += hidden_claw

/datum/component/paradise_zombie_mutation_claws/proc/on_pre_attack(obj/item/paradise_zombie_claw/source, atom/target, mob/living/user)
	SIGNAL_HANDLER
	unmodified_force = source.force
	source.force *= claw_multiplier

/datum/component/paradise_zombie_mutation_claws/proc/on_afterattack(obj/item/paradise_zombie_claw/source, atom/target, mob/living/user)
	SIGNAL_HANDLER
	if(!barrier_damage_bonus || QDELETED(target) || !user.Adjacent(target))
		return
	if(!istype(target, /obj/machinery/door) && !istype(target, /obj/structure/window) && !istype(target, /obj/structure/barricade))
		return
	if(target.uses_integrity)
		target.take_damage(barrier_damage_bonus, BRUTE, MELEE)

/** Mutation actions own their temporary world effects, including effects already away from their caster. */
/datum/action/cooldown/paradise_zombie_mutation
	abstract_type = /datum/action/cooldown/paradise_zombie_mutation
	button_icon = 'icons/mob/actions/actions_spells.dmi'
	check_flags = AB_CHECK_CONSCIOUS|AB_CHECK_INCAPACITATED|AB_CHECK_LYING
	/// The body's mutation controller owns this action, never the mind or the visual renderer.
	var/datum/weakref/controller_ref
	/// Form required for both activation and delayed effects.
	var/required_form
	/// World effects and the caster's vulnerability, deleted on removal or cure.
	var/list/owned_effects = list()
	/// Stops cleanup callbacks from delivering new effects while the action is being removed.
	var/removing = FALSE

/datum/action/cooldown/paradise_zombie_mutation/Grant(mob/granted_to)
	var/mob/previous_owner = owner
	. = ..()
	if(!owner || owner == previous_owner)
		return .
	removing = FALSE
	RegisterSignal(granted_to, COMSIG_LIVING_DEATH, PROC_REF(on_owner_died))

/datum/action/cooldown/paradise_zombie_mutation/Remove(mob/removed_from)
	removing = TRUE
	clear_effects()
	UnregisterSignal(removed_from, COMSIG_LIVING_DEATH)
	return ..()

/datum/action/cooldown/paradise_zombie_mutation/Destroy()
	removing = TRUE
	clear_effects()
	controller_ref = null
	return ..()

/datum/action/cooldown/paradise_zombie_mutation/IsAvailable(feedback = FALSE)
	return is_active() && ..()

/// Check form ownership without checking cooldown, including after a cast has already committed.
/datum/action/cooldown/paradise_zombie_mutation/proc/is_active()
	var/datum/component/paradise_zombie_mutation/controller = controller_ref?.resolve()
	return !removing && !QDELETED(owner) && controller?.is_active(required_form)

/// Register ownership before an effect can fire or delete itself synchronously.
/datum/action/cooldown/paradise_zombie_mutation/proc/track_effect(datum/effect)
	if(QDELETED(effect) || (effect in owned_effects))
		return
	owned_effects += effect
	RegisterSignal(effect, COMSIG_QDELETING, PROC_REF(on_effect_deleted))

/datum/action/cooldown/paradise_zombie_mutation/proc/on_effect_deleted(datum/source)
	SIGNAL_HANDLER
	owned_effects -= source

/// Snapshotting permits each deletion callback to remove its own reference safely.
/datum/action/cooldown/paradise_zombie_mutation/proc/clear_effects()
	for(var/datum/effect as anything in owned_effects.Copy())
		qdel(effect)
	owned_effects.Cut()

/datum/action/cooldown/paradise_zombie_mutation/proc/on_owner_died()
	SIGNAL_HANDLER
	clear_effects()

/// Friendly and dead bodies cannot be used to generate attack rewards or transmit new infections.
/datum/action/cooldown/paradise_zombie_mutation/proc/can_hit(mob/living/victim)
	return is_active() && !QDELETED(victim) && victim != owner && victim.stat != DEAD && !HAS_TRAIT(victim, TRAIT_PARADISE_ZOMBIE)

/// Ranged exposure must penetrate BIO protection before using the shared strain/immunity boundary.
/datum/action/cooldown/paradise_zombie_mutation/proc/expose_target(mob/living/carbon/human/victim)
	if(can_hit(victim) && prob(100 - victim.getarmor(BODY_ZONE_CHEST, BIO)))
		return paradise_zombie_mutation_expose(victim, owner)
	return FALSE

/** Twitcher's dash and Hunter's ambush use the existing throw-scoped impact suppression. */
/datum/action/cooldown/paradise_zombie_mutation/dash
	name = "Рывок"
	desc = "Рвануть до 12 клеток. Стены и закрытые препятствия останавливают рывок."
	button_icon_state = "blink"
	required_form = "twitcher"
	cooldown_time = 8 SECONDS
	click_to_activate = TRUE
	/// Maximum travel, independent of the clicked target's distance or gravity.
	var/travel_range = 12
	/// Hunter overrides this to deliver an attack instead of merely repositioning.
	var/pounce = FALSE

/datum/action/cooldown/paradise_zombie_mutation/dash/Activate(atom/target)
	var/mob/living/carbon/human/user = owner
	var/turf/destination = get_turf(target)
	if(!IsAvailable() || !destination || destination.z != user.z || destination == user.loc || !isturf(user.loc) || user.throwing || user.buckled)
		return FALSE
	// No thrower argument means walking momentum cannot increase the promised range.
	if(!user.throw_at(target, travel_range, 2, spin = FALSE, gentle = TRUE, quickstart = FALSE, throw_type_path = /datum/thrownthing/paradise_zombie_leap/mutation))
		return FALSE
	var/datum/thrownthing/paradise_zombie_leap/mutation/flight = user.throwing
	flight.action_ref = WEAKREF(src)
	track_effect(flight)
	playsound(user, 'sound/items/weapons/punchmiss.ogg', 40, TRUE)
	StartCooldown()
	return TRUE

/datum/action/cooldown/paradise_zombie_mutation/dash/pounce
	name = "Прыжок из засады"
	desc = "Прыгнуть до 10 клеток и сбить жертву когтями. После промаха на две секунды вы замедлены и получаете на четверть больше урона."
	button_icon_state = "mutate"
	required_form = "hunter"
	cooldown_time = 20 SECONDS
	travel_range = 10
	pounce = TRUE

/// Extends Paradise's existing scoped throw; no persistent mob impact hook is installed.
/datum/thrownthing/paradise_zombie_leap/mutation
	/// Weak ownership permits cure and body transfer to cancel a flight without retaining the action.
	var/datum/weakref/action_ref
	/// Only a successful enemy hit suppresses Hunter's miss penalty.
	var/hit_enemy = FALSE
	/// Suppress only the landing impulse made inside this throw's finalization.
	var/finishing = FALSE

/datum/thrownthing/paradise_zombie_leap/mutation/New(thrownthing, target, init_dir, maxrange, speed, thrower, diagonals_first, force, gentle, callback, target_zone)
	. = ..()
	RegisterSignal(thrownthing, COMSIG_MOVABLE_PRE_MOVE, PROC_REF(check_endpoint))
	RegisterSignal(thrownthing, COMSIG_MOVABLE_PRE_THROW, PROC_REF(on_rethrow))
	RegisterSignal(thrownthing, COMSIG_MOVABLE_SPACEMOVE, PROC_REF(stop_landing_impulse))

/datum/thrownthing/paradise_zombie_leap/mutation/Destroy()
	if(thrownthing)
		UnregisterSignal(thrownthing, list(COMSIG_MOVABLE_PRE_MOVE, COMSIG_MOVABLE_PRE_THROW, COMSIG_MOVABLE_SPACEMOVE))
	action_ref = null
	return ..()

/datum/thrownthing/paradise_zombie_leap/mutation/proc/check_endpoint(atom/movable/source)
	SIGNAL_HANDLER
	if(source.throwing == src && (source.loc == target_turf || dist_travelled >= maxrange))
		return COMPONENT_MOVABLE_BLOCK_PRE_MOVE

/datum/thrownthing/paradise_zombie_leap/mutation/proc/on_rethrow(atom/movable/source)
	SIGNAL_HANDLER
	if(source.throwing == src)
		// A replacement throw cancels this flight without delivering a stale impact or a yielding attack.
		qdel(src)

/// Native finalize clears throwing before it adds an inertial impulse; existing external drift is untouched.
/datum/thrownthing/paradise_zombie_leap/mutation/proc/stop_landing_impulse(atom/movable/source, movement_dir, continuous_move)
	SIGNAL_HANDLER
	if(finishing && continuous_move)
		finishing = FALSE
		return COMSIG_MOVABLE_STOP_SPACEMOVE

/datum/thrownthing/paradise_zombie_leap/mutation/hit_target(mob/living/carbon/human/user, atom/target)
	var/datum/action/cooldown/paradise_zombie_mutation/dash/action = action_ref?.resolve()
	if(!action?.pounce || !isliving(target))
		return
	var/mob/living/victim = target
	if(!action.can_hit(victim))
		return
	var/obj/item/paradise_zombie_claw/claws = user.get_active_held_item()
	if(!istype(claws))
		return
	var/list/attack_modifiers = list()
	claws.melee_attack_chain(user, victim, list(), attack_modifiers)
	if(QDELETED(victim) || !LAZYACCESS(attack_modifiers, DAMAGE_DONE))
		return
	hit_enemy = TRUE
	victim.Knockdown(1 SECONDS)
	log_combat(user, victim, "атаковал прыжком (мутация зомби Paradise)")

/datum/thrownthing/paradise_zombie_leap/mutation/finalize(hit = FALSE, atom/target = null)
	var/datum/action/cooldown/paradise_zombie_mutation/dash/action = action_ref?.resolve()
	var/mob/living/user = thrownthing
	// Resolve before judging a miss, then let the parent's impact deduplication skip this same collision.
	if(hit && !QDELETED(target) && !(REF(target) in struck_atoms))
		struck_atoms += REF(target)
		hit_target(user, target)
	if(action?.pounce && action.is_active() && !hit_enemy && !QDELETED(user) && user.stat != DEAD)
		action.track_effect(user.apply_status_effect(/datum/status_effect/paradise_zombie_mutation_exposed))
	finishing = TRUE
	return ..()

/** A missed ambush leaves the Hunter visibly staggered and temporarily easier to hurt. */
/datum/status_effect/paradise_zombie_mutation_exposed
	id = "paradise_zombie_mutation_exposed"
	alert_type = null
	duration = 2 SECONDS
	status_type = STATUS_EFFECT_REFRESH
	on_remove_on_mob_delete = TRUE

/datum/status_effect/paradise_zombie_mutation_exposed/on_apply()
	MODIFY_PHYSIOLOGY(owner, BRUTE, 1.25)
	MODIFY_PHYSIOLOGY(owner, BURN, 1.25)
	owner.add_movespeed_modifier(/datum/movespeed_modifier/paradise_zombie_mutation_exposed)
	owner.balloon_alert_to_viewers("теряет равновесие!")
	return TRUE

/datum/status_effect/paradise_zombie_mutation_exposed/on_remove()
	MODIFY_PHYSIOLOGY(owner, BRUTE, 0.8)
	MODIFY_PHYSIOLOGY(owner, BURN, 0.8)
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/paradise_zombie_mutation_exposed)

/datum/movespeed_modifier/paradise_zombie_mutation_exposed
	multiplicative_slowdown = 1.5

/** A visible projectile can be dodged or stopped by cover; its residue is separately cleanable. */
/datum/action/cooldown/paradise_zombie_mutation/bile
	name = "Желчный плевок"
	desc = "Плюнуть видимой едкой желчью до 13 клеток. Попадание оставляет смываемую лужу, замедляющую живых противников."
	button_icon_state = "smoke"
	required_form = "spitter"
	cooldown_time = 12 SECONDS
	click_to_activate = TRUE

/// Pacifism blocks this attack at activation and while its delayed effects are resolving.
/datum/action/cooldown/paradise_zombie_mutation/bile/is_active()
	return ..() && !HAS_TRAIT(owner, TRAIT_PACIFISM)

/datum/action/cooldown/paradise_zombie_mutation/bile/Activate(atom/target)
	var/mob/living/carbon/human/user = owner
	var/turf/destination = get_turf(target)
	if(!IsAvailable() || !destination || !isturf(user.loc) || destination.z != user.z || get_dist(user, destination) > 13 || destination == user.loc)
		return FALSE
	if(isliving(target) && !can_hit(target))
		return FALSE
	var/obj/projectile/paradise_zombie_bile/spit = new(get_turf(user))
	spit.action_ref = WEAKREF(src)
	spit.firer = user
	spit.fired_from = src
	spit.def_zone = BODY_ZONE_CHEST
	spit.aim_projectile(target, get_turf(user))
	track_effect(spit)
	playsound(user, 'sound/misc/moist_impact.ogg', 50, TRUE)
	StartCooldown()
	spit.fire()
	return TRUE

/obj/projectile/paradise_zombie_bile
	name = "едкая желчь"
	icon_state = "neurotoxin"
	color = "#99BB22"
	damage = 8
	damage_type = BURN
	armor_flag = BIO
	range = 13
	speed = 0.8
	/// The action owns this shot and any residue it creates.
	var/datum/weakref/action_ref

/obj/projectile/paradise_zombie_bile/can_hit_target(atom/target, direct_target = FALSE, ignore_loc = FALSE, cross_failed = FALSE)
	var/datum/action/cooldown/paradise_zombie_mutation/action = action_ref?.resolve()
	if(!action?.is_active())
		return FALSE
	if(isliving(target))
		if(!action.can_hit(target))
			return FALSE
	return ..()

/obj/projectile/paradise_zombie_bile/on_hit(atom/target, blocked = 0, pierce_hit)
	. = ..()
	var/datum/action/cooldown/paradise_zombie_mutation/action = action_ref?.resolve()
	var/turf/tile = get_turf(target)
	if(. == BULLET_ACT_BLOCK || !action?.is_active() || !isopenturf(tile))
		return .
	if(ishuman(target) && action.can_hit(target) && blocked < 100)
		var/mob/living/carbon/human/victim = target
		action.expose_target(victim)
	var/obj/effect/decal/cleanable/paradise_zombie_bile/puddle = new(tile, action)
	if(!QDELETED(puddle))
		action.track_effect(puddle)

/obj/projectile/paradise_zombie_bile/Destroy()
	action_ref = null
	return ..()

/** No reagent payload or slip component: hostile bile is an area slow, not a source of farmable ingredients. */
/obj/effect/decal/cleanable/paradise_zombie_bile
	name = "едкая желчь"
	desc = "Липкая желчь сковывает движения. Её можно смыть."
	icon_state = "greenglow"
	color = "#99BB22"
	decal_reagent = null
	reagent_amount = 0
	mergeable_decal = FALSE
	/// Ownership is checked on every contact, even if a cure happened during movement.
	var/datum/weakref/action_ref
	/// Expiry must not retain a puddle that was washed off early.
	var/expiry_timer
	var/static/list/loc_connections = list(COMSIG_ATOM_ENTERED = PROC_REF(on_entered))

/obj/effect/decal/cleanable/paradise_zombie_bile/Initialize(mapload, datum/action/cooldown/paradise_zombie_mutation/action)
	// The parent's second argument is a disease list, not this action.
	. = ..(mapload)
	if(. == INITIALIZE_HINT_QDEL || !action?.is_active())
		return INITIALIZE_HINT_QDEL
	action_ref = WEAKREF(action)
	AddElement(/datum/element/connect_loc, loc_connections)
	expiry_timer = addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(qdel), src), 12 SECONDS, TIMER_STOPPABLE)
	for(var/mob/living/victim in loc)
		slow_target(victim)

/obj/effect/decal/cleanable/paradise_zombie_bile/Destroy()
	if(expiry_timer)
		deltimer(expiry_timer)
	expiry_timer = null
	action_ref = null
	return ..()

/obj/effect/decal/cleanable/paradise_zombie_bile/proc/on_entered(datum/source, atom/movable/arrived)
	SIGNAL_HANDLER
	if(isliving(arrived))
		slow_target(arrived)

/obj/effect/decal/cleanable/paradise_zombie_bile/proc/slow_target(mob/living/victim)
	var/datum/action/cooldown/paradise_zombie_mutation/action = action_ref?.resolve()
	if(action?.can_hit(victim))
		// Contact leaves a three-second residue; another caster's refresh must survive this one's cure.
		victim.apply_status_effect(/datum/status_effect/paradise_zombie_mutation_bile_slow)

/datum/status_effect/paradise_zombie_mutation_bile_slow
	id = "paradise_zombie_mutation_bile_slow"
	alert_type = null
	duration = 3 SECONDS
	status_type = STATUS_EFFECT_REFRESH
	on_remove_on_mob_delete = TRUE
	remove_on_fullheal = TRUE
	heal_flag_necessary = HEAL_CC_STATUS

/datum/status_effect/paradise_zombie_mutation_bile_slow/on_apply()
	owner.add_movespeed_modifier(/datum/movespeed_modifier/paradise_zombie_mutation_bile)
	return TRUE

/datum/status_effect/paradise_zombie_mutation_bile_slow/on_remove()
	owner.remove_movespeed_modifier(/datum/movespeed_modifier/paradise_zombie_mutation_bile)

/datum/movespeed_modifier/paradise_zombie_mutation_bile
	multiplicative_slowdown = 1.5

/** An interruptible, announced suicide blast exposes a real targetable organ during its windup. */
/datum/action/cooldown/paradise_zombie_mutation/explode
	name = "Разрыв желчного узла"
	desc = "Две секунды раздувать желчный узел, затем взорваться в радиусе 5 клеток. Попадание по открытому узлу срывает взрыв и ранит вас."
	button_icon_state = "fireball"
	required_form = "exploder"
	cooldown_time = 20 SECONDS
	/// The weak point exists only while a detonation is visibly preparing.
	var/obj/structure/paradise_zombie_mutation_nodule/nodule
	/// Only one windup can exist, even when the action is triggered directly.
	var/priming = FALSE
	/// Rupture invalidates a do_after that is still waiting.
	var/ruptured = FALSE

/// Pacifism blocks this attack at activation and while its delayed effects are resolving.
/datum/action/cooldown/paradise_zombie_mutation/explode/is_active()
	return ..() && !HAS_TRAIT(owner, TRAIT_PACIFISM)

/datum/action/cooldown/paradise_zombie_mutation/explode/Activate(atom/target)
	if(!IsAvailable() || priming || !isturf(owner.loc))
		return FALSE
	var/mob/living/carbon/human/user = owner
	priming = TRUE
	ruptured = FALSE
	nodule = new(get_turf(user), src)
	track_effect(nodule)
	StartCooldown()
	user.visible_message(span_userdanger("Желчный узел [user] раздувается и готовится взорваться!"), span_userdanger("Наш желчный узел раздувается!"))
	user.balloon_alert_to_viewers("готовится взорваться!")
	playsound(user, 'sound/misc/moist_impact.ogg', 60, TRUE)
	var/completed = do_after(user, 2 SECONDS, target = user)
	if(QDELETED(src))
		return FALSE
	priming = FALSE
	var/can_detonate = completed && !ruptured && is_active() && !QDELETED(nodule) && !IS_UNCONSCIOUS_OR_CRIT(user)
	QDEL_NULL(nodule)
	if(!can_detonate)
		return FALSE
	detonate(user)
	return TRUE

/datum/action/cooldown/paradise_zombie_mutation/explode/clear_effects()
	priming = FALSE
	ruptured = TRUE
	nodule = null
	return ..()

/// Destroying the exposed organ consumes the attempted cast and damages the host instead of detonating it.
/datum/action/cooldown/paradise_zombie_mutation/explode/proc/rupture(obj/structure/paradise_zombie_mutation_nodule/weakpoint)
	if(!priming || weakpoint != nodule || !is_active())
		return
	ruptured = TRUE
	nodule = null
	var/mob/living/carbon/human/user = owner
	user.apply_damage(40, BRUTE, BODY_ZONE_CHEST, wound_bonus = CANT_WOUND)
	user.visible_message(span_danger("Желчный узел [user] лопается — взрыв сорван!"))
	log_combat(weakpoint, user, "разорвал мутационный узел")

/// A local blast respects cover and armour without digging station-wide explosion holes.
/datum/action/cooldown/paradise_zombie_mutation/explode/proc/detonate(mob/living/carbon/human/user)
	if(!is_active() || QDELETED(user))
		return
	new /obj/effect/temp_visual/explosion(get_turf(user))
	playsound(user, 'sound/effects/explosion/explosion1.ogg', 80, TRUE)
	for(var/mob/living/victim in view(5, user))
		if(!can_hit(victim))
			continue
		var/blocked_by_cover = FALSE
		for(var/turf/tile as anything in get_line(get_turf(user), get_turf(victim)))
			if(tile != user.loc && tile.is_blocked_turf(exclude_mobs = TRUE))
				blocked_by_cover = TRUE
				break
		if(blocked_by_cover)
			continue
		var/armor = victim.run_armor_check(BODY_ZONE_CHEST, BOMB)
		victim.apply_damage(60 - 6 * get_dist(user, victim), BRUTE, BODY_ZONE_CHEST, blocked = armor, wound_bonus = CANT_WOUND)
		if(QDELETED(victim))
			continue
		victim.Knockdown(1 SECONDS)
		if(ishuman(victim) && armor < 100)
			expose_target(victim)
		log_combat(user, victim, "взорвался (мутация зомби Paradise)")
	// Keep an ordinary corpse: Paradise resurrection and surgery continue to own its future.
	user.adjust_brute_loss(user.maxHealth + 200)
	if(user.stat != DEAD)
		user.death()

/** A click-targetable weak point; ordinary projectile and integrity code provides the counterplay. */
/obj/structure/paradise_zombie_mutation_nodule
	name = "раздутый желчный узел"
	desc = "Нестабильный узел на теле взрывника. Его разрушение сорвёт готовящийся взрыв."
	icon = 'icons/obj/medical/organs/organs.dmi'
	icon_state = "heart-on"
	color = "#BBDD33"
	pixel_y = 12
	layer = ABOVE_MOB_LAYER
	anchored = TRUE
	density = FALSE
	max_integrity = 35
	/// The organ is removed with its owning action; it never retains the caster itself.
	var/datum/weakref/action_ref
	/// Signal cleanup must also work while the action itself is already deleting.
	var/datum/weakref/host_ref

/obj/structure/paradise_zombie_mutation_nodule/Initialize(mapload, datum/action/cooldown/paradise_zombie_mutation/explode/action)
	. = ..()
	if(!action?.is_active())
		return INITIALIZE_HINT_QDEL
	action_ref = WEAKREF(action)
	host_ref = WEAKREF(action.owner)
	RegisterSignal(action.owner, COMSIG_MOVABLE_MOVED, PROC_REF(on_owner_moved))

/obj/structure/paradise_zombie_mutation_nodule/Destroy()
	var/mob/living/host = host_ref?.resolve()
	if(host)
		UnregisterSignal(host, COMSIG_MOVABLE_MOVED)
	host_ref = null
	action_ref = null
	return ..()

/obj/structure/paradise_zombie_mutation_nodule/proc/on_owner_moved(atom/movable/source)
	SIGNAL_HANDLER
	forceMove(get_turf(source))

/obj/structure/paradise_zombie_mutation_nodule/atom_destruction(damage_flag)
	var/datum/action/cooldown/paradise_zombie_mutation/explode/action = action_ref?.resolve()
	action?.rupture(src)
	return ..()
