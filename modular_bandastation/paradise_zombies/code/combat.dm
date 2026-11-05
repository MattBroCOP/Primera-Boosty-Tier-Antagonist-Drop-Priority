/**
 * Transfers an owned strain through a Paradise blood exposure, retaining its original carbon resistance rolls.
 * Clothing is bypassed; species immunity, acquired resistance and disease viability still apply.
 * The supplied disease is either installed without copying or deleted on failure.
 */
/proc/paradise_zombie_blood_infect(mob/living/carbon/human/target, datum/disease/infection)
	if(QDELETED(infection))
		return FALSE
	if(QDELETED(target) || infection.spreading_modifier <= 0 || !target.CanContractDisease(infection))
		qdel(infection)
		return FALSE
	if((target.satiety > 0 && prob(target.satiety / 10)) || prob(15 / infection.spreading_modifier))
		qdel(infection)
		return FALSE
	return target.ForceContractDisease(infection, make_copy = FALSE, del_on_fail = TRUE)

/// Gives Paradise zombies their grab bites, brain eating and resistance to traumatic amputation.
/datum/component/paradise_zombie_combat
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// Prevent overlapping brain-eating actions from bypassing the one-second delay.
	var/eating = FALSE

/datum/component/paradise_zombie_combat/Initialize()
	if(!ishuman(parent))
		return COMPONENT_INCOMPATIBLE

/datum/component/paradise_zombie_combat/RegisterWithParent()
	RegisterSignal(parent, COMSIG_LIVING_UNARMED_ATTACK, PROC_REF(on_unarmed_attack))
	RegisterSignal(parent, COMSIG_CARBON_PRE_DISMEMBER, PROC_REF(on_dismember))
	RegisterSignal(parent, COMSIG_MOB_SAY, PROC_REF(on_say))

/datum/component/paradise_zombie_combat/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_LIVING_UNARMED_ATTACK, COMSIG_CARBON_PRE_DISMEMBER, COMSIG_MOB_SAY))

/datum/component/paradise_zombie_combat/proc/on_say(mob/living/source, list/speech_args)
	SIGNAL_HANDLER
	if(speech_args[SPEECH_LANGUAGE] != /datum/language/paradise_zombie)
		return
	var/list/message_mods = speech_args[SPEECH_MODS]
	message_mods[SAY_MOD_VERB] = endswith(speech_args[SPEECH_MESSAGE], "!") ? "кричит" : "стонет"

/datum/component/paradise_zombie_combat/proc/on_dismember(mob/living/carbon/human/source, obj/item/bodypart/limb)
	SIGNAL_HANDLER
	if(!HAS_TRAIT(source, TRAIT_PARADISE_ZOMBIE))
		return NONE
	limb.force_wound_upwards(/datum/wound/blunt/bone/severe, wound_source = "травма при попытке отсечения конечности зомби")
	return COMPONENT_CANCEL_DISMEMBER

/datum/component/paradise_zombie_combat/proc/on_unarmed_attack(mob/living/carbon/human/source, atom/target, proximity, list/modifiers)
	SIGNAL_HANDLER
	if(!HAS_TRAIT(source, TRAIT_PARADISE_ZOMBIE) || !proximity || !source.combat_mode || HAS_TRAIT(source, TRAIT_PACIFISM) || LAZYACCESS(modifiers, RIGHT_CLICK) || !ishuman(target))
		return NONE
	var/mob/living/carbon/human/victim = target
	if(source.pulling == victim)
		if(source.grab_state < GRAB_AGGRESSIVE)
			to_chat(source, span_warning("Нам нужно крепче схватить [victim], чтобы укусить!"))
			return COMPONENT_CANCEL_ATTACK_CHAIN
		bite(source, victim)
		return COMPONENT_CANCEL_ATTACK_CHAIN
	if(HAS_TRAIT(victim, TRAIT_PARADISE_ZOMBIE))
		to_chat(source, span_warning("Мы не чувствуем запаха свежих мозгов у [victim]."))
		return NONE
	var/obj/item/organ/brain/brain = victim.get_organ_slot(ORGAN_SLOT_BRAIN)
	var/obj/item/bodypart/brain_holder = brain ? victim.get_bodypart(check_zone(brain.zone)) : null
	if(!brain_holder || (victim.mob_biotypes & MOB_ROBOTIC))
		to_chat(source, span_warning("Мы не чувствуем запаха мозгов у [victim]."))
		return NONE
	if(source.zone_selected != brain_holder.body_zone || !LIMB_HAS_SURGERY_STATE(brain_holder, SURGERY_SKIN_OPEN|SURGERY_BONE_SAWED))
		return NONE
	if(victim.getarmor(brain_holder.body_zone, MELEE) > 0)
		to_chat(source, span_warning("Мозги [victim] защищены бронёй."))
		return NONE
	if(victim.get_organ_loss(ORGAN_SLOT_BRAIN) >= 120)
		to_chat(source, span_warning("Мозгов больше не осталось..."))
		return COMPONENT_CANCEL_ATTACK_CHAIN
	if(!eating)
		eating = TRUE
		INVOKE_ASYNC(src, PROC_REF(eat_brain), source, victim, brain, brain_holder)
	return COMPONENT_CANCEL_ATTACK_CHAIN

/// A firm grab lets a bite bypass clothing and antibiotics, as in Paradise.
/datum/component/paradise_zombie_combat/proc/bite(mob/living/carbon/human/user, mob/living/carbon/human/target)
	if(target.mob_biotypes & MOB_ROBOTIC)
		to_chat(user, span_warning("Мы не чувствуем запаха мозгов у [target]."))
		return FALSE
	if(HAS_TRAIT(target, TRAIT_PIERCEIMMUNE))
		to_chat(user, span_warning("Наш укус не может пробить [target]!"))
		return FALSE
	if(target.check_block(user, 20, "укус", attack_type = UNARMED_ATTACK))
		return FALSE
	user.visible_message(span_danger("[user] яростно кусает [target]!"))
	playsound(user, 'sound/items/weapons/bite.ogg', 20, TRUE)
	playsound(user, 'sound/misc/moist_impact.ogg', 50, TRUE)
	user.do_attack_animation(target, ATTACK_EFFECT_BITE)
	target.apply_damage(20, BRUTE, user.zone_selected)
	if(!HAS_TRAIT(user, TRAIT_PARADISE_NON_INFECTIOUS_ZOMBIE))
		var/datum/disease/paradise_zombie/infection = locate() in target.diseases
		if(!infection && target.ForceContractDisease(new /datum/disease/paradise_zombie, make_copy = FALSE, del_on_fail = TRUE))
			target.set_dizzy_if_lower(10 SECONDS)
			target.set_confusion_if_lower(10 SECONDS)
			infection = locate() in target.diseases
		if(infection)
			infection.stage = max(rand(3, 4), infection.stage)
	log_combat(user, target, "укусил (зомби Paradise)")
	user.stop_pulling()
	return TRUE

/// The infection is delivered before eating; interrupted feeding still exposes an open brain.
/datum/component/paradise_zombie_combat/proc/eat_brain(mob/living/carbon/human/user, mob/living/carbon/human/target, obj/item/organ/brain/brain, obj/item/bodypart/brain_holder)
	if(target.check_block(user, 0, "поедание мозга", attack_type = UNARMED_ATTACK))
		eating = FALSE
		return
	target.visible_message(span_danger("[user] вонзает пальцы в голову [target], поедая мозги!"), span_userdanger("ОН ПОЕДАЕТ ВАШ МОЗГ!"))
	if(!HAS_TRAIT(user, TRAIT_PARADISE_NON_INFECTIOUS_ZOMBIE))
		var/datum/disease/paradise_zombie/infection = locate() in target.diseases
		if(!infection)
			paradise_zombie_blood_infect(target, new /datum/disease/paradise_zombie)
			infection = locate() in target.diseases
		if(infection)
			infection.stage = max(5, infection.stage)
	var/completed = do_after(user, 1 SECONDS, target = target)
	if(QDELETED(src))
		return
	eating = FALSE
	if(!completed)
		return
	if(QDELETED(user) || QDELETED(target) || QDELETED(brain_holder) || QDELETED(brain) || !user.Adjacent(target) || !user.combat_mode || !user.can_unarmed_attack())
		return
	if(user.get_active_held_item() || !HAS_TRAIT(user, TRAIT_PARADISE_ZOMBIE) || target.get_organ_slot(ORGAN_SLOT_BRAIN) != brain || brain_holder.owner != target)
		return
	if(HAS_TRAIT(target, TRAIT_PARADISE_ZOMBIE) || (target.mob_biotypes & MOB_ROBOTIC))
		return
	if(user.zone_selected != brain_holder.body_zone || !LIMB_HAS_SURGERY_STATE(brain_holder, SURGERY_SKIN_OPEN|SURGERY_BONE_SAWED) || target.getarmor(brain_holder.body_zone, MELEE) > 0 || target.get_organ_loss(ORGAN_SLOT_BRAIN) >= 120)
		return
	playsound(user, 'sound/items/eatfood.ogg', 20, TRUE)
	playsound(user, 'sound/misc/moist_impact.ogg', 50, TRUE)
	user.do_attack_animation(target, ATTACK_EFFECT_BITE)
	target.adjust_organ_loss(ORGAN_SLOT_BRAIN, 5)
	if(!IS_UNCONSCIOUS_OR_CRIT(target) && prob(33))
		target.emote("scream")
	if(user.nutrition < NUTRITION_LEVEL_FULL - 10)
		user.set_nutrition(user.nutrition + 10)
	user.heal_overall_damage(2, 2)
	log_combat(user, target, "съел мозг (зомби Paradise)")

/// A single, two-handed pair of claws; clicking again retracts it.
/datum/action/cooldown/paradise_zombie_claws
	name = "Когти зомби"
	desc = "Выпустить или убрать когти. Они заражают ранения в голову и грудь и вскрывают повреждённые черепа."
	button_icon = 'modular_bandastation/vampire/icons/mob/actions/actions.dmi'
	button_icon_state = "vampire_claws"
	check_flags = AB_CHECK_CONSCIOUS|AB_CHECK_HANDS_BLOCKED
	cooldown_time = 0
	/// Claws created by this action, also cleaned up on body transfer.
	var/list/our_claws = list()
	/// Minimum stage transmitted by a successful scratch.
	var/infection_stage = 1
	/// Disease type carried by the plague variant.
	var/disease

/datum/action/cooldown/paradise_zombie_claws/Destroy()
	QDEL_LIST(our_claws)
	return ..()

/datum/action/cooldown/paradise_zombie_claws/Remove(mob/removed_from)
	QDEL_LIST(our_claws)
	return ..()

/datum/action/cooldown/paradise_zombie_claws/IsAvailable(feedback = FALSE)
	return ..() && ishuman(owner)

/datum/action/cooldown/paradise_zombie_claws/Activate(atom/target)
	if(!IsAvailable())
		return FALSE
	var/mob/living/carbon/human/user = owner
	var/obj/item/paradise_zombie_claw/held = user.get_active_held_item()
	if(istype(held))
		qdel(held)
		return TRUE
	if(held || user.get_inactive_held_item() || user.usable_hands < 2 || HAS_TRAIT(user, TRAIT_NO_TWOHANDING) || user.is_holding_item_of_type(/obj/item/paradise_zombie_claw))
		return FALSE
	var/obj/item/paradise_zombie_claw/claws
	if(HAS_TRAIT(user, TRAIT_PARADISE_PLAGUE_ZOMBIE))
		claws = new /obj/item/paradise_zombie_claw/plague(user.loc, src, disease)
	else
		claws = new(user.loc, src)
		claws.infection_stage = infection_stage
	if(!user.put_in_hands(claws))
		qdel(claws)
		to_chat(user, span_warning("У нас нет когтей..."))
		return FALSE
	our_claws += claws
	return TRUE

/// The wizard's claws spread its selected disease instead of the zombie virus.
/datum/action/cooldown/paradise_zombie_claws/plague
	name = "Чумные когти"
	desc = "Выпустить или убрать когти, распространяющие выбранную хозяином болезнь."

/// Paradise's 21-force claws retain their antibiotic, armour and robotic-limb infection rules.
/obj/item/paradise_zombie_claw
	name = "claws"
	desc = "Когти, выступающие из гниющих рук. Подходят для вскрытия черепов."
	icon = 'modular_bandastation/vampire/icons/effects/vampire_effects.dmi'
	icon_state = "vamp_claws"
	inhand_icon_state = "vamp_claws"
	lefthand_file = 'modular_bandastation/paradise_zombies/icons/claws_lefthand.dmi'
	righthand_file = 'modular_bandastation/paradise_zombies/icons/claws_righthand.dmi'
	w_class = WEIGHT_CLASS_BULKY
	item_flags = ABSTRACT|DROPDEL
	gender = PLURAL
	force = 21
	armour_penetration = 0
	sharpness = SHARP_EDGED
	hitsound = 'modular_bandastation/vampire/sound/weapons/bladeslice.ogg'
	attack_verb_continuous = list("slashes", "slices", "tears", "rips", "mauls", "cuts", "savages", "claws")
	attack_verb_simple = list("slash", "slice", "tear", "rip", "maul", "cut", "savage", "claw")
	/// Action owning this disposable weapon.
	var/datum/action/cooldown/paradise_zombie_claws/parent_action
	/// Beta medicine dulls normal claws to this force.
	var/force_weak = 10
	/// Minimum transmitted zombie-virus stage.
	var/infection_stage = 1
	/// Disease type carried by a plague zombie.
	var/claw_disease
	/// Serializes the three-second skull-opening action.
	var/opening_skull = FALSE

/obj/item/paradise_zombie_claw/Initialize(mapload, datum/action/cooldown/paradise_zombie_claws/new_parent_action, disease)
	. = ..()
	AddComponent(/datum/component/two_handed, require_twohands = TRUE)
	ADD_TRAIT(src, TRAIT_NODROP, PARADISE_ZOMBIE_TRAIT)
	parent_action = new_parent_action
	claw_disease = disease
	if(parent_action?.owner)
		RegisterSignal(parent_action.owner, COMSIG_MOB_DROPPING_ITEM, PROC_REF(retract_on_drop))

/obj/item/paradise_zombie_claw/Destroy()
	if(parent_action)
		if(parent_action.owner)
			UnregisterSignal(parent_action.owner, COMSIG_MOB_DROPPING_ITEM)
		parent_action.our_claws -= src
		parent_action = null
	return ..()

/obj/item/paradise_zombie_claw/proc/retract_on_drop(mob/user)
	SIGNAL_HANDLER
	if(user.get_active_held_item() == src)
		qdel(src)

/obj/item/paradise_zombie_claw/attack_self(mob/user, modifiers)
	. = ..()
	if(!.)
		qdel(src)

/obj/item/paradise_zombie_claw/pre_attack(atom/target, mob/living/user, list/modifiers, list/attack_modifiers)
	if(!HAS_TRAIT(user, TRAIT_PARADISE_PLAGUE_ZOMBIE))
		force = user.reagents?.has_reagent(/datum/reagent/medicine/paradise_zombie_cure/beta) ? force_weak : initial(force)
	return ..()

/// Paradise scales positive armour by 120% before subtracting flat plague penetration.
/obj/item/paradise_zombie_claw/get_melee_armor_block(mob/living/target, target_zone, target_zone_text)
	var/armor = target.getarmor(target_zone, MELEE)
	if(armor == INFINITY)
		to_chat(target, span_notice("Ваша броня защитила вашу [target_zone_text]!"))
		return armor
	if(armor <= 0)
		return armor
	armor = clamp(armor * 1.2 - armour_penetration, 0, 100)
	if(armor)
		to_chat(target, span_warning("Ваша броня смягчила удар, нанесённый в вашу [target_zone_text]!"))
	else
		to_chat(target, span_userdanger("Ваша броня была пробита!"))
	return armor

/obj/item/paradise_zombie_claw/afterattack(atom/target, mob/user, list/modifiers, list/attack_modifiers)
	. = ..()
	if(!ishuman(target) || !user.Adjacent(target))
		return
	var/mob/living/carbon/human/victim = target
	if(victim.mob_biotypes & MOB_ROBOTIC)
		return
	if(HAS_TRAIT(user, TRAIT_PARADISE_PLAGUE_ZOMBIE))
		try_virus_infect(victim, user)
		return
	try_infect(victim, user)
	var/obj/item/organ/brain/brain = victim.get_organ_slot(ORGAN_SLOT_BRAIN)
	var/obj/item/bodypart/brain_holder = brain ? victim.get_bodypart(check_zone(brain.zone)) : null
	if(!brain_holder || LIMB_HAS_SURGERY_STATE(brain_holder, SURGERY_SKIN_OPEN|SURGERY_BONE_SAWED) || brain_holder.body_zone != user.zone_selected)
		return
	if(brain_holder.get_damage() <= brain_holder.max_damage - 5)
		return
	if(victim.getarmor(brain_holder.body_zone, MELEE) > 0)
		to_chat(user, span_warning("Мозги [victim] защищены бронёй."))
		return
	if(!opening_skull)
		opening_skull = TRUE
		INVOKE_ASYNC(src, PROC_REF(open_skull), user, victim, brain, brain_holder)

/// Scratches need exposed organic head/chest tissue; Alpha and spaceacillin prevent transmission.
/obj/item/paradise_zombie_claw/proc/try_infect(mob/living/carbon/human/target, mob/living/user)
	if(HAS_TRAIT(user, TRAIT_PARADISE_NON_INFECTIOUS_ZOMBIE))
		return FALSE
	if(!(user.zone_selected in list(BODY_ZONE_HEAD, BODY_ZONE_CHEST)))
		to_chat(user, span_warning("Наша инфекция распространяется только через голову или грудь."))
		return FALSE
	if(HAS_TRAIT(target, TRAIT_PIERCEIMMUNE))
		return FALSE
	if(target.reagents.has_reagent(/datum/reagent/medicine/paradise_zombie_cure/alpha) || target.reagents.has_reagent(/datum/reagent/medicine/spaceacillin))
		return FALSE
	var/obj/item/bodypart/affecting = target.get_bodypart(user.zone_selected)
	if(!affecting || IS_ROBOTIC_LIMB(affecting))
		return FALSE
	if(prob(3 * target.getarmor(user.zone_selected, MELEE)) || prob(50))
		return FALSE
	var/datum/disease/paradise_zombie/infection = locate() in target.diseases
	if(!infection)
		paradise_zombie_blood_infect(target, new /datum/disease/paradise_zombie)
		infection = locate() in target.diseases
	if(!infection)
		return FALSE
	playsound(user, 'sound/misc/moist_impact.ogg', 50, TRUE)
	add_infection_bleeding(target, affecting)
	infection.stage = max(infection.stage, infection_stage)
	return TRUE

/// Preserve the original minimum five bleeding rate using TG's treatable slash wound.
/obj/item/paradise_zombie_claw/proc/add_infection_bleeding(mob/living/carbon/human/target, obj/item/bodypart/affecting)
	var/desired_rate = max(5, target.get_bleed_rate() + 1)
	var/datum/wound/slash/flesh/bleeding
	for(var/datum/wound/slash/flesh/existing_wound in affecting.wounds)
		bleeding = existing_wound
		break
	if(!bleeding)
		bleeding = affecting.force_wound_upwards(/datum/wound/slash/flesh/moderate, wound_source = src)
	if(!QDELETED(bleeding) && bleeding.limb == affecting && bleeding.victim == target)
		bleeding.set_blood_flow(bleeding.blood_flow + max(0, desired_rate - target.get_bleed_rate()))

/// Ripping a skull takes three uninterrupted seconds and remains tied to the held claws and original brain.
/obj/item/paradise_zombie_claw/proc/open_skull(mob/living/user, mob/living/carbon/human/target, obj/item/organ/brain/brain, obj/item/bodypart/brain_holder)
	user.visible_message(span_danger("[user] вонзает когти в череп [target]!"))
	to_chat(target, span_userdanger("Когти [user] впиваются в ваш череп!"))
	playsound(user, 'modular_bandastation/paradise_zombies/sound/armblade.ogg', 50, TRUE)
	var/completed = do_after(user, 3 SECONDS, target = target)
	if(QDELETED(src))
		return
	opening_skull = FALSE
	if(!completed)
		return
	if(QDELETED(user) || QDELETED(target) || QDELETED(brain_holder) || QDELETED(brain) || user.get_active_held_item() != src || !user.Adjacent(target))
		return
	if(brain_holder.owner != target || target.get_organ_slot(ORGAN_SLOT_BRAIN) != brain || user.zone_selected != brain_holder.body_zone)
		return
	if(brain_holder.get_damage() <= brain_holder.max_damage - 5 || target.getarmor(brain_holder.body_zone, MELEE) > 0 || LIMB_HAS_SURGERY_STATE(brain_holder, SURGERY_SKIN_OPEN|SURGERY_BONE_SAWED))
		return
	playsound(user, 'sound/misc/moist_impact.ogg', 50, TRUE)
	if(!IS_ROBOTIC_LIMB(brain_holder))
		brain_holder.force_wound_upwards(/datum/wound/cranial_fissure, wound_source = src)
	// Paradise opens the brain holder even when its anatomy cannot receive a bone fracture.
	brain_holder.add_surgical_state(SURGERY_SKIN_OPEN|SURGERY_BONE_SAWED)
	user.visible_message(span_danger("[user] с хрустом раскалывает череп [target]!"))
	to_chat(target, span_userdanger("Ваш череп с хрустом раскрывается!"))
	log_combat(user, target, "вскрыл череп (зомби Paradise)")

/// Plague claws trade normal claw damage for fifteen points of armour penetration.
/obj/item/paradise_zombie_claw/plague
	name = "plague claws"
	desc = "Из гниющих рук выступают острые когти, сочащиеся зловонной жижей."
	force = 13
	armour_penetration = 15

/// Infect an uninfected target, or advance the selected plague with forty-percent probability.
/obj/item/paradise_zombie_claw/proc/try_virus_infect(mob/living/carbon/human/target, mob/living/user)
	if(!ispath(claw_disease, /datum/disease))
		return FALSE
	var/datum/disease/infection = locate(claw_disease) in target.diseases
	if(!infection)
		paradise_zombie_blood_infect(target, new claw_disease)
	else if(prob(40) && infection.stage < infection.max_stages)
		infection.stage++
	var/obj/item/bodypart/affecting = target.get_bodypart(check_zone(user.zone_selected))
	if(affecting)
		add_infection_bleeding(target, affecting)
	return TRUE

/// The plague zombie's original five-tile leap with a sixty-second cooldown.
/datum/action/cooldown/paradise_zombie_leap
	name = "Яростный прыжок"
	desc = "Временно снять ограничения мышц и прыгнуть к выбранной цели."
	button_icon = 'icons/mob/actions/actions_spells.dmi'
	button_icon_state = "mutate"
	check_flags = AB_CHECK_CONSCIOUS|AB_CHECK_INCAPACITATED
	cooldown_time = 60 SECONDS
	click_to_activate = TRUE

/datum/action/cooldown/paradise_zombie_leap/IsAvailable(feedback = FALSE)
	var/mob/living/user = owner
	return ..() && ishuman(user) && HAS_TRAIT(user, TRAIT_PARADISE_PLAGUE_ZOMBIE) && user.body_position == STANDING_UP && !user.buckled && !user.throwing && isturf(user.loc)

/datum/action/cooldown/paradise_zombie_leap/Activate(atom/target)
	if(!IsAvailable() || !get_turf(target) || target == owner)
		return FALSE
	var/mob/living/user = owner
	playsound(user, 'modular_bandastation/paradise_zombies/sound/zombie_leap.ogg', 80, FALSE)
	if(!user.throw_at(target, 5, 1, user, spin = FALSE, gentle = TRUE, throw_type_path = /datum/thrownthing/paradise_zombie_leap))
		return FALSE
	StartCooldown()
	return TRUE

/// The charging state belongs to this throw, so interruption cannot leak it into a later throw.
/datum/thrownthing/paradise_zombie_leap
	/// Bump and landing can report the same collision twice.
	var/list/struck_atoms = list()

/datum/thrownthing/paradise_zombie_leap/New(thrownthing, target, init_dir, maxrange, speed, thrower, diagonals_first, force, gentle, callback, target_zone)
	. = ..()
	RegisterSignal(thrownthing, COMSIG_MOVABLE_PRE_IMPACT, PROC_REF(on_impact))

/datum/thrownthing/paradise_zombie_leap/Destroy()
	if(thrownthing)
		UnregisterSignal(thrownthing, COMSIG_MOVABLE_PRE_IMPACT)
	return ..()

/datum/thrownthing/paradise_zombie_leap/proc/on_impact(mob/living/carbon/human/source, atom/target, datum/thrownthing/throwingdatum)
	SIGNAL_HANDLER
	if(throwingdatum != src)
		return NONE
	if(!(REF(target) in struck_atoms))
		struck_atoms += REF(target)
		INVOKE_ASYNC(src, PROC_REF(hit_target), source, target)
	return COMPONENT_MOVABLE_IMPACT_NEVERMIND

/// Paradise plague charges attack with the held weapon, knock down for one second, and smash obstacles.
/datum/thrownthing/paradise_zombie_leap/proc/hit_target(mob/living/carbon/human/user, atom/target)
	if(QDELETED(user) || QDELETED(target))
		return
	var/hit_something = isobj(target) || isliving(target) || iswallturf(target)
	if(ismovable(target))
		var/atom/movable/movable_target = target
		if(!movable_target.anchored || ismecha(movable_target))
			hit_something = TRUE
	if(hit_something)
		playsound(get_turf(user), 'sound/effects/meteorimpact.ogg', 100, TRUE)
		user.visible_message(span_danger("[user] врезается в [target]!"), span_userdanger("Вы врезаетесь в [target]!"))
		log_combat(user, target, "протаранил (прыжок чумного зомби)")
	if(isobj(target))
		if(target.uses_integrity)
			target.take_damage(150, BRUTE)
	if(isliving(target))
		var/mob/living/victim = target
		shake_camera(victim, 4, 3)
		var/obj/item/held_item = user.get_active_held_item()
		if(held_item)
			held_item.attack(victim, user)
		victim.Knockdown(1 SECONDS)
	if(iswallturf(target))
		var/turf/closed/wall/wall = target
		wall.dismantle_wall(devastated = TRUE)
