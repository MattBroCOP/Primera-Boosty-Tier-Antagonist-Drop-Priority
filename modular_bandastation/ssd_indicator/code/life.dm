/mob/living/proc/handle_ssd(seconds_per_tick, times_fired)
	if(player_logged || HAS_TRAIT(src, TRAIT_SSD_SUPPRESSED))
		return
	SetSleeping(7 SECONDS)
