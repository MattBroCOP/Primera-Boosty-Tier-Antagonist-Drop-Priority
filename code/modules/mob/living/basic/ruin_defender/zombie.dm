/** A mapped corpse uses the same body, infection and resurrection as infected crewmembers. */
/mob/living/carbon/human/paradise_zombie_npc
	name = "Бредущий труп"
	real_name = "Бредущий труп"
	desc = "Когда в аду больше не останется места, мёртвые выйдут в открытый космос."
	faction = list(FACTION_HOSTILE)
	/// Clothes previously rendered by the basic zombie, now worn by its real human body.
	var/outfit = /datum/outfit/corpse_doctor
	/// The sound variants retained by the mapped corpses.
	var/list/zombie_damaged_sounds

/mob/living/carbon/human/paradise_zombie_npc/Initialize(mapload)
	. = ..()
	real_name = name
	equipOutfit(outfit)
	add_blood_DNA_to_items(get_blood_dna_list(), ITEM_SLOT_OCLOTHING)
	mind_initialize()
	ADD_TRAIT(src, TRAIT_PARADISE_NPC_ZOMBIE, INNATE_TRAIT)
	// Space-ruin corpses were noninfectious; admins can remove this existing plague trait.
	ADD_TRAIT(src, TRAIT_PARADISE_NON_INFECTIOUS_ZOMBIE, INNATE_TRAIT)
	var/datum/disease/paradise_zombie/infection = new()
	infection.infect(src, FALSE)
	infection.stage = 8
	infection.process_infection_cycle()
	RegisterSignal(src, COMSIG_MOB_AFTER_APPLY_DAMAGE, PROC_REF(on_zombie_damage))

/mob/living/carbon/human/paradise_zombie_npc/proc/on_zombie_damage(datum/source, damage, damage_type)
	SIGNAL_HANDLER
	if(HAS_TRAIT(src, TRAIT_PARADISE_ZOMBIE) && damage > 0 && (damage_type in list(BRUTE, BURN)) && length(zombie_damaged_sounds))
		playsound(src, pick(zombie_damaged_sounds), 75, TRUE)

/** Preserve map and admin spawn paths without creating an intermediate basic mob or replacing player references. */
/mob/living/basic/zombie
	parent_type = /mob/living/carbon/human/paradise_zombie_npc

/mob/living/basic/zombie/rotten
	name = "Гниющий труп"
	desc = "Эта нежить находится на поздней стадии разложения."

/mob/living/basic/zombie/rotten/assistant
	outfit = /datum/outfit/corpse_assistant

/datum/outfit/corpse_doctor
	name = "Труп врача"
	suit = /obj/item/clothing/suit/toggle/labcoat
	uniform = /obj/item/clothing/under/rank/medical/doctor
	shoes = /obj/item/clothing/shoes/sneakers/white
	back = /obj/item/storage/backpack/medic

/datum/outfit/corpse_assistant
	name = "Труп ассистента"
	mask = /obj/item/clothing/mask/gas
	uniform = /obj/item/clothing/under/color/grey
	shoes = /obj/item/clothing/shoes/sneakers/black
	back = /obj/item/storage/backpack
