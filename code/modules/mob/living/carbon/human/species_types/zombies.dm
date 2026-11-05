/// Retains mapped zombie species/spawns while using the same plague as infected crew.
/datum/species/zombie
	name = "Зомби"
	id = SPECIES_ZOMBIE
	changesource_flags = MIRROR_BADMIN | WABBAJACK | MIRROR_PRIDE | MIRROR_MAGIC | ERT_SPAWN

/datum/species/zombie/on_species_gain(mob/living/carbon/human/human_who_gained_species, datum/species/old_species, pref_load, regenerate_icons, replace_missing)
	. = ..()
	if(istype(human_who_gained_species, /mob/living/carbon/human/dummy))
		human_who_gained_species.become_husk(PARADISE_ZOMBIE_TRAIT)
		human_who_gained_species.AddComponent(/datum/component/paradise_zombie_appearance)
		return
	var/datum/disease/paradise_zombie/infection = locate() in human_who_gained_species.diseases
	if(!infection)
		infection = new
		infection.infect(human_who_gained_species, FALSE)
	infection.stage = 8
	infection.process_infection_cycle()

/datum/species/zombie/on_species_loss(mob/living/carbon/human/human_who_lost_species, datum/species/new_species, pref_load, regenerate_icons, replace_missing)
	. = ..()
	if(istype(human_who_lost_species, /mob/living/carbon/human/dummy))
		qdel(human_who_lost_species.GetComponent(/datum/component/paradise_zombie_appearance))
		human_who_lost_species.cure_husk(PARADISE_ZOMBIE_TRAIT)

/datum/species/zombie/get_species_description()
	return "Жертва некротической чумы, жаждущая мозгов и способная восставать после смерти."

/datum/species/zombie/get_species_lore()
	return list("Некротическая чума передаётся через заражённую кровь и слюну. Исследование противочумных препаратов или удаление некротической опухоли позволяет обратить заражение.")
