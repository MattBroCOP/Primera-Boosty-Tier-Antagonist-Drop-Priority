/** Paradise's darkness-dependent healing, repeated resurrection and abandoned-body hunger. */
/datum/component/paradise_zombie_regen
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// The corpse's last player, retained when its mind moves into its removed brain.
	var/player_ckey
	/// Retains the original once-per-second NPC decision cadence independently of subsystem frequency.
	var/ai_accumulator = 0
	/// Movement delay when the abandoned body follows prey.
	COOLDOWN_DECLARE(next_step)

/datum/component/paradise_zombie_regen/Initialize()
	if(!ishuman(parent))
		return COMPONENT_INCOMPATIBLE
	var/mob/living/carbon/human/zombie = parent
	player_ckey = zombie.ckey || ckey(zombie.mind?.key) || ckey(zombie.last_mind?.key)
	START_PROCESSING(SSprocessing, src)

/datum/component/paradise_zombie_regen/Destroy(force)
	STOP_PROCESSING(SSprocessing, src)
	return ..()

/datum/component/paradise_zombie_regen/process(seconds_per_tick)
	var/mob/living/carbon/human/zombie = parent
	if(!istype(zombie))
		return PROCESS_KILL
	if(HAS_TRAIT(zombie, TRAIT_SUICIDED))
		return
	var/turf/current_turf = get_turf(zombie)
	if(!current_turf)
		return
	if(zombie.ckey)
		player_ckey = zombie.ckey
	var/healing_factor = max(1, 6 * (1 - current_turf.get_lumcount()))
	if(HAS_TRAIT(zombie, TRAIT_PARADISE_PLAGUE_ZOMBIE))
		healing_factor *= 1.6
	if(zombie.reagents.has_reagent(/datum/reagent/medicine/paradise_zombie_cure/gamma))
		healing_factor /= 3
	if(zombie.stat == DEAD)
		healing_factor *= 2
	for(var/datum/wound/burn/burn in zombie.all_wounds)
		if(burn.severity >= WOUND_SEVERITY_CRITICAL)
			if(SPT_PROB(20, seconds_per_tick))
				burn.remove_wound()
			break
	zombie.heal_overall_damage(healing_factor * seconds_per_tick, healing_factor * seconds_per_tick, required_bodytype = BODYTYPE_ORGANIC)
	zombie.adjust_organ_loss(ORGAN_SLOT_BRAIN, -healing_factor * seconds_per_tick)
	if(zombie.stat == DEAD && zombie.get_brute_loss_for_type(BODYTYPE_ORGANIC) <= 1 && zombie.get_fire_loss_for_type(BODYTYPE_ORGANIC) <= 1 && zombie.timeofdeath + 15 SECONDS <= world.time)
		var/datum/reagent/medicine/paradise_zombie_cure/omega/treatment = zombie.reagents.has_reagent(/datum/reagent/medicine/paradise_zombie_cure/omega)
		if(treatment)
			zombie.reagents.remove_reagent(treatment.type, 2 * treatment.metabolization_rate * zombie.metabolism_efficiency * seconds_per_tick)
			return
		if(zombie_rejuv())
			to_chat(zombie, span_userdanger("Мы... Пробуждаемся..."))
			zombie.notify_revival("Ваше тело зомби снова восстало. Вернитесь в него, чтобы продолжить пир!", source = zombie)

	if(zombie.stat != STABLE || HAS_TRAIT(zombie, TRAIT_HANDS_BLOCKED) || zombie.client || zombie.key)
		return
	if(HAS_TRAIT(zombie, TRAIT_PARADISE_PLAGUE_ZOMBIE))
		return
	if(!player_ckey && !HAS_TRAIT(zombie, TRAIT_PARADISE_NPC_ZOMBIE))
		return
	ai_accumulator += seconds_per_tick
	if(ai_accumulator >= 1)
		ai_accumulator %= 1
		mindless_hunger()

/** Restores existing organs and damage without curing the plague or closing its opened skull. */
/datum/component/paradise_zombie_regen/proc/zombie_rejuv()
	var/mob/living/carbon/human/zombie = parent
	var/list/preserved_openings = list()
	for(var/obj/item/bodypart/limb as anything in zombie.get_bodyparts())
		if(!HAS_TRAIT(limb, TRAIT_PARADISE_ZOMBIE_LIMB))
			continue
		var/opening_states = limb.surgery_state & (SURGERY_SKIN_OPEN|SURGERY_BONE_SAWED)
		if(opening_states)
			preserved_openings[limb] = opening_states
	zombie.fully_heal(HEAL_DAMAGE|HEAL_TEMP|HEAL_BLOOD|HEAL_STATUS|HEAL_CC_STATUS|HEAL_TRAUMAS|HEAL_WOUNDS)
	for(var/obj/item/bodypart/limb as anything in preserved_openings)
		if(!QDELETED(limb) && limb.owner == zombie)
			limb.add_surgical_state(preserved_openings[limb])
	var/static/list/cured_mutations = list(/datum/mutation/mute, /datum/mutation/deaf, /datum/mutation/epilepsy, /datum/mutation/cough, /datum/mutation/nervousness)
	zombie.dna?.remove_mutation_group(cured_mutations)
	zombie.cure_trauma_type(/datum/brain_trauma/severe/paralysis/paraplegic, TRAUMA_RESILIENCE_ABSOLUTE)
	zombie.become_husk(PARADISE_ZOMBIE_TRAIT)
	zombie.bodytemperature = 310
	zombie.set_coretemperature(310)
	zombie.SetAllImmobility(0)
	zombie.SetSleeping(0)
	zombie.set_nutrition(max(zombie.nutrition, NUTRITION_LEVEL_HUNGRY))
	zombie.extinguish_mob()
	zombie.set_fire_stacks(0)
	qdel(zombie.GetComponent(/datum/component/irradiated))
	if(zombie.buckled)
		zombie.buckled.unbuckle_mob(zombie, force = TRUE)
	var/list/missing_organ_types = list(ORGAN_SLOT_HEART = zombie.dna?.species?.mutantheart, ORGAN_SLOT_LUNGS = zombie.dna?.species?.mutantlungs)
	for(var/slot in missing_organ_types)
		var/organ_type = missing_organ_types[slot]
		if(!zombie.get_organ_slot(slot) && ispath(organ_type, /obj/item/organ))
			var/obj/item/organ/replacement = new organ_type()
			replacement.Insert(zombie)
	for(var/obj/item/organ/organ as anything in zombie.organs)
		organ.set_organ_damage(0)
		organ.organ_flags &= ~ORGAN_EMP
	for(var/obj/item/bodypart/limb as anything in zombie.get_bodyparts())
		limb.heal_damage(1000, 1000)
		var/datum/component/paradise_zombie_limb/rot = limb.GetComponent(/datum/component/paradise_zombie_limb)
		rot?.necrotize()
	zombie.set_heartattack(FALSE)
	zombie.restore_blood()
	zombie.update_body_parts()
	if(zombie.stat == DEAD)
		return zombie.revive(force_grab_ghost = FALSE)
	zombie.updatehealth()
	return TRUE

/** Uses the normal item attack path for adjacent prey, otherwise walks toward a visible human. */
/datum/component/paradise_zombie_regen/proc/mindless_hunger()
	var/mob/living/carbon/human/zombie = parent
	var/list/targets = list()
	for(var/mob/living/carbon/human/target in view(6, zombie))
		if(target.stat == STABLE && !HAS_TRAIT(target, TRAIT_PARADISE_ZOMBIE))
			targets |= target
			if(zombie.Adjacent(target))
				break
	var/mob/living/carbon/human/target
	if(length(targets))
		target = pick(targets)
	if(target && zombie.Adjacent(target) && safe_active_hand(zombie))
		if(!zombie.get_active_held_item() && !zombie.get_inactive_held_item() && zombie.usable_hands >= 2 && !HAS_TRAIT(zombie, TRAIT_NO_TWOHANDING))
			var/obj/item/paradise_zombie_claw/claw = new()
			if(!zombie.put_in_hand(claw, zombie.active_hand_index))
				qdel(claw)
		zombie.set_combat_mode(TRUE)
		zombie.ClickOn(target)
		return
	if(!COOLDOWN_FINISHED(src, next_step) || !(zombie.mobility_flags & MOBILITY_MOVE) || zombie.buckled || !isturf(zombie.loc))
		return
	if(!target && prob(90))
		return
	var/target_direction = target ? get_dir(zombie, target) : pick(GLOB.cardinals)
	var/delay = zombie.cached_multiplicative_slowdown
	if(ISDIAGONALDIR(target_direction))
		delay *= sqrt(2)
	COOLDOWN_START(src, next_step, delay)
	zombie.set_glide_size(DELAY_TO_GLIDE_SIZE(delay))
	step(zombie, target_direction)

/** Selects a surviving hand before creating the NPC's claws. */
/datum/component/paradise_zombie_regen/proc/safe_active_hand(mob/living/carbon/human/zombie)
	if(zombie.has_active_hand())
		return TRUE
	for(var/index in 1 to zombie.get_num_hand_slots())
		if(zombie.has_hand_for_held_index(index))
			return zombie.swap_hand(index)
	return FALSE
