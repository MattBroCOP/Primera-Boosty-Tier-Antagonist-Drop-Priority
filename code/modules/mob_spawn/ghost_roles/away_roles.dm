
//roles found on away missions, if you can remember to put them here.

//undead that protect a zlevel

/obj/effect/mob_spawn/ghost_role/human/skeleton
	name = "skeletal remains"
	icon = 'icons/effects/blood.dmi'
	icon_state = "remains"
	mob_name = "skeleton"
	prompt_name = "a skeletal guardian"
	mob_species = /datum/species/skeleton
	you_are_text = "By unknown powers, your skeletal remains have been reanimated!"
	flavour_text = "Walk this mortal plane and terrorize all living adventurers who dare cross your path."
	spawner_job_path = /datum/job/skeleton

/obj/effect/mob_spawn/ghost_role/human/skeleton/special(mob/living/new_spawn, mob/mob_possessor, apply_prefs)
	. = ..()
	to_chat(new_spawn, "<b>You have this horrible lurching feeling deep down that your binding to this world will fail if you abandon this zone... Were you reanimated to protect something?</b>")
	new_spawn.AddComponent(/datum/component/stationstuck, PUNISHMENT_MURDER, "You experience a feeling like a stressed twine being pulled until it snaps. Then, merciful nothing.")

/obj/effect/mob_spawn/ghost_role/human/zombie
	name = "гниющий труп"
	icon = 'icons/effects/blood.dmi'
	icon_state = "remains"
	mob_name = "зомби"
	prompt_name = "страж-нежить"
	mob_species = /datum/species/zombie
	spawner_job_path = /datum/job/zombie
	you_are_text = "Неведомые силы воскресили ваши гниющие останки!"
	flavour_text = "Скитайтесь по миру смертных и наводите ужас на живых искателей приключений, которые осмелятся встать у вас на пути."

/obj/effect/mob_spawn/ghost_role/human/zombie/special(mob/living/new_spawn, mob/mob_possessor, apply_prefs)
	. = ..()
	to_chat(new_spawn, "<b>Глубоко внутри вас возникает ужасное ощущение: связь с этим миром оборвётся, если вы покинете эту зону... Вас оживили, чтобы что-то защищать?</b>")
	new_spawn.AddComponent(/datum/component/stationstuck, PUNISHMENT_MURDER, "Вы ощущаете, как натянутая нить всё сильнее растягивается и наконец лопается. Затем наступает милосердная пустота.")
