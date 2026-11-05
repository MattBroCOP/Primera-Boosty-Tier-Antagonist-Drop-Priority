/// Existing map/NPC infection entry points now contract the necrotizing plague.
/proc/try_to_zombie_infect(mob/living/carbon/human/target, mob/living/user, def_zone = BODY_ZONE_CHEST, base_chance = 100)
	if(!ishuman(target) || !prob(base_chance))
		return FALSE
	var/datum/disease/paradise_zombie/infection = locate() in target.diseases
	if(infection)
		return FALSE
	infection = new
	return target.ForceContractDisease(infection, make_copy = FALSE, del_on_fail = TRUE)
