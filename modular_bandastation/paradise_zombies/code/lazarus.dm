/** Paradise Lazarus replaces TG Strange Reagent while preserving its callers. */
/datum/reagent/medicine/strange_reagent
	name = "Реагент Лазаря"
	description = "Биолюминесцентная зелёная жидкость, которая, кажется, движется сама по себе."
	color = "#A0E85E"
	metabolization_rate = 0.1
	taste_description = "жизни"
	chemical_flags = REAGENT_CAN_BE_SYNTHESIZED|REAGENT_REVERSE_METABOLISM
	/// Retained for the existing administrative instant subtype.
	var/instant = FALSE

/datum/reagent/medicine/strange_reagent/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()
	if(SPT_PROB(10, seconds_per_tick / 2))
		affected_mob.adjust_brute_loss(2)
		affected_mob.adjust_tox_loss(2)

/datum/reagent/medicine/strange_reagent/expose_mob(mob/living/exposed_mob, methods = TOUCH, reac_volume, show_message = TRUE, touch_protection = 0)
	. = ..()
	if(reac_volume < 1 || exposed_mob.stat != DEAD || !pre_rez_check(exposed_mob) || exposed_mob.reagents?.is_reagent_immune())
		return
	if((methods & TOUCH) && exposed_mob.compare_sentience_type(SENTIENCE_ORGANIC))
		if(exposed_mob.revive(HEAL_ALL))
			exposed_mob.AddComponent(/datum/component/paradise_lazarus_no_loot)
			if(istype(exposed_mob, /mob/living/simple_animal))
				var/mob/living/simple_animal/animal = exposed_mob
				animal.loot.Cut()
			exposed_mob.visible_message(span_warning("[capitalize(exposed_mob.declent_ru(NOMINATIVE))], похоже, восстаёт из мёртвых!"))
		return
	if(!iscarbon(exposed_mob) || (!(methods & INGEST) && (!(methods & TOUCH) || !prob(25))))
		return
	var/mob/living/carbon/carbon = exposed_mob
	if(HAS_TRAIT(carbon, TRAIT_SUICIDED))
		carbon.visible_message(span_warning("[carbon] слегка дёргается, но, похоже, не желает возвращаться к жизни!"))
		return
	if(HAS_TRAIT(carbon, TRAIT_HUSK) || HAS_TRAIT(carbon, TRAIT_BADDNA))
		carbon.visible_message(span_warning("[carbon] слегка дёргается, но больше ни на что не реагирует!"))
		return
	var/datum/status_effect/paradise_cloning_damage/cloning_damage = carbon.has_status_effect(/datum/status_effect/paradise_cloning_damage)
	if(carbon.get_brute_loss() + carbon.get_fire_loss() + cloning_damage?.amount >= 150)
		if(carbon.mind?.has_antag_datum(/datum/antagonist/changeling) || HAS_TRAIT(carbon, TRAIT_PARADISE_ZOMBIE) || !carbon.get_ghost())
			carbon.visible_message(span_warning("[carbon] слегка дёргается, но ничего не происходит."))
			return
		carbon.gib()
		return
	if(carbon.paradise_lazarus_pending)
		return
	carbon.paradise_lazarus_pending = TRUE
	carbon.visible_message(span_notice("[carbon] начинает дёргаться под действием реагента Лазаря!"))
	carbon.do_jitter_animation(30 SECONDS)
	carbon.notify_revival("Реагент Лазаря пытается оживить ваше тело. Вернитесь в него, чтобы воскреснуть!")
	if(instant)
		carbon.paradise_lazarus_revival()
	else
		addtimer(CALLBACK(carbon, TYPE_PROC_REF(/mob/living/carbon, paradise_lazarus_revival)), 5 SECONDS, TIMER_UNIQUE)

/mob/living/carbon
	/// Guards simultaneous exposures scheduling multiple Lazarus revivals.
	var/paradise_lazarus_pending = FALSE

/** Resolves a Lazarus exposure after the original five-second return window. */
/mob/living/carbon/proc/paradise_lazarus_revival()
	paradise_lazarus_pending = FALSE
	var/datum/status_effect/paradise_cloning_damage/cloning_damage = has_status_effect(/datum/status_effect/paradise_cloning_damage)
	if(stat != DEAD || get_ghost() || HAS_TRAIT(src, TRAIT_SUICIDED) || HAS_TRAIT(src, TRAIT_HUSK) || get_brute_loss() + get_fire_loss() + cloning_damage?.amount >= 150)
		visible_message(span_warning("[src] перестаёт дёргаться: реагент Лазаря теряет силу."))
		return
	set_oxy_loss(0, updating_health = FALSE)
	adjust_brute_loss(rand(0, 15), updating_health = FALSE)
	adjust_tox_loss(rand(0, 15), updating_health = FALSE)
	adjust_fire_loss(rand(0, 15), updating_health = FALSE)
	apply_status_effect(/datum/status_effect/paradise_cloning_damage, 50)
	do_jitter_animation(20 SECONDS)
	var/decay_level = 0
	var/datum/component/paradise_corpse_decay/decay = GetComponent(/datum/component/paradise_corpse_decay)
	if(decay)
		decay.update_decay()
		decay_level = decay.decay_level
	set_heartattack(FALSE)
	if(revive())
		if(ishuman(src))
			var/mob/living/carbon/human/human = src
			human.paradise_lazarus_decay_effects(decay_level)
		visible_message(span_notice("[src] с шумом вдыхает, возвращаясь к жизни!"))
		log_combat(src, src, "ожил благодаря реагенту Лазаря")
		SSblackbox.record_feedback("tally", "players_revived", 1, "lazarus_reagent")

/** Tracks only the donor's whole-body decay level needed by Lazarus, independently of TG's rot aura. */
/datum/component/paradise_corpse_decay
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// Original decay level, retained while embalming fluid or NODECAY prevents further updates.
	var/decay_level = 0

/datum/component/paradise_corpse_decay/Initialize()
	if(!ishuman(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/paradise_corpse_decay/RegisterWithParent()
	RegisterSignal(parent, COMSIG_LIVING_DEATH, PROC_REF(on_death))
	RegisterSignal(parent, COMSIG_LIVING_REVIVE, PROC_REF(on_revive))
	var/mob/living/carbon/human/human = parent
	if(human.stat == DEAD)
		START_PROCESSING(SSprocessing, src)

/datum/component/paradise_corpse_decay/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_LIVING_DEATH, COMSIG_LIVING_REVIVE))
	STOP_PROCESSING(SSprocessing, src)

/datum/component/paradise_corpse_decay/Destroy(force)
	STOP_PROCESSING(SSprocessing, src)
	return ..()

/datum/component/paradise_corpse_decay/proc/on_death(datum/source, gibbed)
	SIGNAL_HANDLER
	START_PROCESSING(SSprocessing, src)

/datum/component/paradise_corpse_decay/proc/on_revive(datum/source)
	SIGNAL_HANDLER
	var/mob/living/carbon/human/human = parent
	if(human.stat == DEAD)
		return
	reset_decay()
	STOP_PROCESSING(SSprocessing, src)

/datum/component/paradise_corpse_decay/process(seconds_per_tick)
	var/mob/living/carbon/human/human = parent
	if(human.stat != DEAD)
		return PROCESS_KILL
	update_decay()

/** Cold does not halt these original whole-body stages; preservation retains the already reached level. */
/datum/component/paradise_corpse_decay/proc/update_decay()
	var/mob/living/carbon/human/human = parent
	if(human.stat != DEAD || HAS_TRAIT(human, TRAIT_NODECAY) || human.reagents?.has_reagent(/datum/reagent/toxin/formaldehyde))
		return
	var/decay_age = world.time - human.timeofdeath
	if(decay_age > 8 MINUTES)
		decay_level = 1
	if(decay_age > 16 MINUTES)
		decay_level = 2
	if(decay_age > 24 MINUTES)
		decay_level = 3
	if(decay_age > 45 MINUTES)
		decay_level = 4

/datum/component/paradise_corpse_decay/proc/reset_decay()
	decay_level = 0

/** Every nonvital organic tissue receives its own original 15-percent-per-decay-level roll. */
/mob/living/carbon/human/proc/paradise_lazarus_decay_effects(decay_level)
	var/datum/component/paradise_corpse_decay/decay = GetComponent(/datum/component/paradise_corpse_decay)
	if(!decay)
		return
	if(isnull(decay_level))
		decay.update_decay()
		decay_level = decay.decay_level
	var/necrosis_probability = 15 * decay_level
	decay.reset_decay()
	for(var/obj/item/tissue as anything in (get_bodyparts() | organs))
		if(prob(necrosis_probability))
			paradise_lazarus_necrotize(tissue)
	update_body_parts()

/** TG represents necrotic internal tissue through organ failure and external tissue through the shared limb state. */
/mob/living/carbon/human/proc/paradise_lazarus_necrotize(obj/item/tissue)
	if(istype(tissue, /obj/item/bodypart))
		var/obj/item/bodypart/limb = tissue
		if(!(limb.bodytype & BODYTYPE_ORGANIC) || (limb.body_zone in list(BODY_ZONE_HEAD, BODY_ZONE_CHEST)))
			return FALSE
		var/datum/component/paradise_zombie_limb/necrosis = limb.GetComponent(/datum/component/paradise_zombie_limb)
		if(!necrosis)
			necrosis = limb.AddComponent(/datum/component/paradise_zombie_limb, FALSE)
		necrosis.necrotize()
		return TRUE
	if(isorgan(tissue))
		var/obj/item/organ/organ = tissue
		if(!(organ.organ_flags & ORGAN_ORGANIC) || (organ.organ_flags & ORGAN_VITAL))
			return FALSE
		organ.set_organ_damage(organ.maxHealth)
		return TRUE
	return FALSE

/** Blocks a resurrected animal's repeated loot drops. */
/datum/component/paradise_lazarus_no_loot
	dupe_mode = COMPONENT_DUPE_UNIQUE

/datum/component/paradise_lazarus_no_loot/Initialize()
	if(!isliving(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/paradise_lazarus_no_loot/RegisterWithParent()
	RegisterSignal(parent, COMSIG_LIVING_DROP_LOOT, PROC_REF(block_loot))

/datum/component/paradise_lazarus_no_loot/UnregisterFromParent()
	UnregisterSignal(parent, COMSIG_LIVING_DROP_LOOT)

/datum/component/paradise_lazarus_no_loot/proc/block_loot(datum/source)
	SIGNAL_HANDLER
	return COMPONENT_NO_LOOT_DROP

/** The removed cloning-damage channel, represented by an independent health penalty. */
/datum/status_effect/paradise_cloning_damage
	id = "paradise_cloning_damage"
	status_type = STATUS_EFFECT_REFRESH
	alert_type = null
	tick_interval = 2 SECONDS
	remove_on_fullheal = TRUE
	/// Cellular damage; ordinary brute and toxin medicine cannot heal this amount.
	var/amount = 0

/datum/status_effect/paradise_cloning_damage/on_apply(initial_amount = 0)
	if(initial_amount <= 0)
		return FALSE
	change_amount(initial_amount)
	RegisterSignal(owner, COMSIG_LIVING_HEALTHSCAN, PROC_REF(on_healthscan))
	return TRUE

/datum/status_effect/paradise_cloning_damage/refresh(effect, additional_amount = 0)
	change_amount(additional_amount)

/** Adjusts cellular damage and restores only its own contribution when healed. */
/datum/status_effect/paradise_cloning_damage/proc/change_amount(delta)
	var/old_amount = amount
	amount = max(0, amount + delta)
	owner.setMaxHealth(owner.maxHealth + old_amount - amount)
	owner.updatehealth()
	if(amount <= 0)
		qdel(src)

/datum/status_effect/paradise_cloning_damage/on_remove()
	UnregisterSignal(owner, COMSIG_LIVING_HEALTHSCAN)
	owner.setMaxHealth(owner.maxHealth + amount)
	owner.updatehealth()
	amount = 0
	return ..()

/datum/status_effect/paradise_cloning_damage/tick(seconds_between_ticks)
	if(owner.stat == DEAD || !owner.reagents)
		return
	var/datum/reagents/chemicals = owner.reagents
	if(chemicals.has_reagent(/datum/reagent/medicine/rezadone, needs_metabolizing = TRUE))
		change_amount(-amount)
		return
	var/healing_per_second = 0
	var/datum/reagent/medicine/cryoxadone/cryoxadone = chemicals.has_reagent(/datum/reagent/medicine/cryoxadone, needs_metabolizing = TRUE)
	if(owner.bodytemperature < 215 && (cryoxadone?.data?["paradise_application_method"] & (TOUCH|VAPOR)))
		healing_per_second += 2
	if(chemicals.has_reagent(/datum/reagent/medicine/syndicate_nanites, needs_metabolizing = TRUE))
		healing_per_second += 1.5
	var/datum/reagent/medicine/earthsblood/earthsblood = chemicals.has_reagent(/datum/reagent/medicine/earthsblood, needs_metabolizing = TRUE)
	if(earthsblood)
		healing_per_second += earthsblood.current_cycle <= 25 ? 0.05 : 0.5
	if(healing_per_second)
		change_amount(-healing_per_second * seconds_between_ticks)

/datum/status_effect/paradise_cloning_damage/proc/on_healthscan(datum/source, list/render_list, scanpower, mob/user, mode, tochat)
	SIGNAL_HANDLER
	render_list += "<span class='alert ml-1'>Клеточные повреждения: [round(amount, 0.1)]. Требуется резадон или криогенное лечение.</span><br>"

/** Records topical/cryo administration separately from swallowed or injected doses. */
/datum/reagent/medicine/cryoxadone/expose_mob(mob/living/exposed_mob, methods = TOUCH, reac_volume, show_message = TRUE, touch_protection = 0)
	LAZYSET(data, "paradise_application_method", methods)
	return ..()
