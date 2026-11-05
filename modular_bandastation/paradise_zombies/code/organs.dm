#define PARADISE_ZOMBIE_LIMB_COLOR_PRIORITY 45

/** Stores Paradise's persistent dead-limb state without changing the body's species. */
/datum/component/paradise_zombie_limb
	dupe_mode = COMPONENT_DUPE_UNIQUE
	/// Omega can restore dead tissue while the infection retains its limb marker.
	var/necrotic = FALSE
	/// Necrosis from Lazarus is not plague infection until the disease reaches this limb.
	var/infected = FALSE
	/// Tracks the owner whose transformation signals currently control limb usability.
	var/datum/weakref/owner_ref

/datum/component/paradise_zombie_limb/Initialize(mark_infected = TRUE)
	if(!istype(parent, /obj/item/bodypart))
		return COMPONENT_INCOMPATIBLE
	var/obj/item/bodypart/limb = parent
	if(!(limb.bodytype & BODYTYPE_ORGANIC))
		return COMPONENT_INCOMPATIBLE
	if(mark_infected)
		infect_limb()
	necrotize()

/datum/component/paradise_zombie_limb/RegisterWithParent()
	RegisterSignal(parent, COMSIG_BODYPART_CHANGED_OWNER, PROC_REF(on_owner_changed))
	RegisterSignal(parent, COMSIG_BODYPART_CHECKED_FOR_INJURY, PROC_REF(on_injury_check))
	var/obj/item/bodypart/limb = parent
	bind_owner(limb.owner)

/datum/component/paradise_zombie_limb/UnregisterFromParent()
	UnregisterSignal(parent, list(COMSIG_BODYPART_CHANGED_OWNER, COMSIG_BODYPART_CHECKED_FOR_INJURY))
	bind_owner(null)

/datum/component/paradise_zombie_limb/Destroy(force)
	var/obj/item/bodypart/limb = parent
	if(limb && !QDELETED(limb))
		heal_necrosis()
		REMOVE_TRAIT(limb, TRAIT_PARADISE_ZOMBIE_LIMB, PARADISE_ZOMBIE_TRAIT)
	return ..()

/** Promotes existing dead tissue to infected tissue without replacing its necrosis component. */
/datum/component/paradise_zombie_limb/proc/infect_limb()
	if(infected)
		return FALSE
	infected = TRUE
	ADD_TRAIT(parent, TRAIT_PARADISE_ZOMBIE_LIMB, PARADISE_ZOMBIE_TRAIT)
	return TRUE

/** Makes organic tissue dead and numb; transformed zombies can still use their dead limbs. */
/datum/component/paradise_zombie_limb/proc/necrotize()
	if(necrotic)
		return
	necrotic = TRUE
	var/obj/item/bodypart/limb = parent
	limb.add_color_override("#618C61", PARADISE_ZOMBIE_LIMB_COLOR_PRIORITY)
	if(limb.owner)
		to_chat(limb.owner, span_notice("Вы больше не чувствуете [ru_parse_zone(limb.body_zone, ACCUSATIVE)]..."))
	update_usability()
	limb.owner?.update_body_parts()

/** Restores the current tissue without erasing its infected-limb marker. */
/datum/component/paradise_zombie_limb/proc/heal_necrosis()
	necrotic = FALSE
	var/obj/item/bodypart/limb = parent
	limb.remove_color_override(PARADISE_ZOMBIE_LIMB_COLOR_PRIORITY)
	REMOVE_TRAIT(limb, TRAIT_PARALYSIS, REF(src))
	limb.owner?.update_body_parts()

/** Rebinds owner signals after removal or transplantation of the affected limb. */
/datum/component/paradise_zombie_limb/proc/bind_owner(mob/living/carbon/new_owner)
	var/mob/living/carbon/old_owner = owner_ref?.resolve()
	if(old_owner)
		UnregisterSignal(old_owner, list(SIGNAL_ADDTRAIT(TRAIT_PARADISE_ZOMBIE), SIGNAL_REMOVETRAIT(TRAIT_PARADISE_ZOMBIE)))
	owner_ref = null
	if(new_owner)
		owner_ref = WEAKREF(new_owner)
		RegisterSignals(new_owner, list(SIGNAL_ADDTRAIT(TRAIT_PARADISE_ZOMBIE), SIGNAL_REMOVETRAIT(TRAIT_PARADISE_ZOMBIE)), PROC_REF(on_transformation_changed))
	update_usability()

/datum/component/paradise_zombie_limb/proc/on_owner_changed(obj/item/bodypart/source, mob/living/carbon/new_owner)
	SIGNAL_HANDLER
	bind_owner(new_owner)

/datum/component/paradise_zombie_limb/proc/on_transformation_changed(datum/source)
	SIGNAL_HANDLER
	update_usability()

/** Matches Paradise's is_usable override while keeping other sources of paralysis intact. */
/datum/component/paradise_zombie_limb/proc/update_usability()
	var/obj/item/bodypart/limb = parent
	if(QDELETED(limb))
		return
	if(necrotic && !HAS_TRAIT(limb.owner, TRAIT_PARADISE_ZOMBIE))
		ADD_TRAIT(limb, TRAIT_PARALYSIS, REF(src))
	else
		REMOVE_TRAIT(limb, TRAIT_PARALYSIS, REF(src))

/datum/component/paradise_zombie_limb/proc/on_injury_check(obj/item/bodypart/source, mob/examiner, list/check_list)
	SIGNAL_HANDLER
	if(necrotic)
		check_list += span_warning("Ткань некротизирована и не реагирует на раздражители.")

/** Removable head tumor whose extraction reverses the necrotizing plague. */
/obj/item/organ/paradise_zombie_tumor
	name = "necrotic tumor"
	desc = "Крошечное скопление зловонных грибов, которые питаются мозговой тканью и управляют ею."
	icon = 'icons/obj/service/hydroponics/harvest.dmi'
	icon_state = "chanterelle"
	w_class = WEIGHT_CLASS_TINY
	zone = BODY_ZONE_HEAD
	slot = ORGAN_SLOT_ZOMBIE
	organ_flags = ORGAN_ORGANIC|ORGAN_HAZARDOUS
	visual = FALSE

/obj/item/organ/paradise_zombie_tumor/Remove(mob/living/carbon/organ_owner, special = FALSE, movement_flags)
	. = ..()
	if(organ_owner && !QDELETED(organ_owner))
		for(var/datum/disease/paradise_zombie/infection in organ_owner.diseases?.Copy())
			infection.cure()
		for(var/obj/item/bodypart/limb as anything in organ_owner.get_bodyparts())
			var/datum/component/paradise_zombie_limb/rot = limb.GetComponent(/datum/component/paradise_zombie_limb)
			if(rot?.infected)
				rot.heal_necrosis()
	if(!QDELETED(src))
		qdel(src)

#undef PARADISE_ZOMBIE_LIMB_COLOR_PRIORITY
