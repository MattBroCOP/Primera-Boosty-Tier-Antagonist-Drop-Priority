/// One rule covers command execution, aliases, panel availability and forced emotes.
/proc/paradise_zombie_can_emote(mob/user, datum/emote/emote, intentional)
	if(!HAS_TRAIT(user, TRAIT_PARADISE_ZOMBIE))
		return TRUE
	return istype(emote, /datum/emote/living/scream) || istype(emote, /datum/emote/living/carbon/human/screech) || emote.key == "help" || (!intentional && emote.key == "deathgasp")

/// Retain saved preferences and restore only verbs removed from this physical body.
/datum/component/paradise_zombie_regen/proc/refresh_emotes(restore = FALSE)
	if(QDELETED(parent))
		return
	var/mob/living/carbon/human/host = parent
	if(!restore && HAS_TRAIT(host, TRAIT_PARADISE_ZOMBIE))
		var/list/to_remove = list()
		for(var/procpath/verb_path as anything in host.verbs)
			if(verb_path.category == "Эмоции" && verb_path != /mob/living/carbon/human/verb/emote_scream)
				to_remove += verb_path
		if(length(to_remove))
			LAZYOR(removed_emote_verbs, to_remove)
			remove_verb(host, to_remove)
	else if(length(removed_emote_verbs))
		add_verb(host, removed_emote_verbs)
		removed_emote_verbs = null
	host.update_emote_panels()
