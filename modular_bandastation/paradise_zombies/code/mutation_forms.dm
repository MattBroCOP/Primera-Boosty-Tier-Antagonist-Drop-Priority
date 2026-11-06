GLOBAL_LIST_INIT(paradise_zombie_mutation_forms, list(
	"slasher" = new /datum/paradise_zombie_form/slasher(),
	"twitcher" = new /datum/paradise_zombie_form/twitcher(),
	"hunter" = new /datum/paradise_zombie_form/hunter(),
	"brute" = new /datum/paradise_zombie_form/brute(),
	"spitter" = new /datum/paradise_zombie_form/spitter(),
	"exploder" = new /datum/paradise_zombie_form/exploder(),
))

/// Returns only a registered mutation; client-supplied indices cannot select arbitrary datums.
/proc/get_paradise_zombie_form(form_id)
	if(!istext(form_id))
		return null
	return GLOB.paradise_zombie_mutation_forms[form_id]

/// An infection mutation changes appearance and combat without replacing the character's species.
/datum/paradise_zombie_form
	/// Stable selection and appearance key.
	var/id
	var/name
	var/desc
	/// Epidemic tier required before this form can be chosen.
	var/tier = 1
	/// Original DS13 body DMI; its preview is used only in the selection menu.
	var/body_icon
	/// Added to current maximum health, preserving independent cellular injury.
	var/health_bonus = 0
	/// Scales the form's maximum health once; cleanup subtracts the actual applied delta.
	var/health_multiplier = 1
	/// Added to the ordinary zombie's movement delay.
	var/slowdown = 0
	var/claw_multiplier = 1
	var/barrier_damage_bonus = 0
	/// Actions owned by the physical body's mutation controller.
	var/list/ability_types = list()
	/// Physical-body sound banks; native movement and emotes still decide when to play them.
	var/list/footstep_sounds
	var/list/cry_sounds

/datum/paradise_zombie_form/slasher
	id = "slasher"
	name = "Рваный"
	desc = "Основная мутировавшая форма: когти, укусы, разрушение дверей ударами и язык, притягивающий жертву. Обычная живучесть зомби."
	body_icon = 'modular_bandastation/paradise_zombies/icons/mutations/slasher.dmi'
	ability_types = list(/datum/action/cooldown/paradise_zombie_mutation/tongue)
	footstep_sounds = list('modular_bandastation/paradise_zombies/sound/footsteps/ds13/slasher_1.ogg', 'modular_bandastation/paradise_zombies/sound/footsteps/ds13/slasher_2.ogg')
	cry_sounds = list('modular_bandastation/paradise_zombies/sound/voices/slasher_1.ogg', 'modular_bandastation/paradise_zombies/sound/voices/slasher_2.ogg')

/datum/paradise_zombie_form/twitcher
	id = "twitcher"
	name = "Бегун"
	desc = "Быстрое передвижение, рывок и ударный таран до 12 клеток. Хрупкое тело и ослабленные когти."
	body_icon = 'modular_bandastation/paradise_zombies/icons/mutations/twitcher.dmi'
	health_bonus = -35
	slowdown = -1.5
	claw_multiplier = 0.85
	ability_types = list(/datum/action/cooldown/paradise_zombie_mutation/dash, /datum/action/cooldown/paradise_zombie_mutation/dash/charge)
	footstep_sounds = list('modular_bandastation/paradise_zombies/sound/footsteps/ds13/twitcher_1.ogg', 'modular_bandastation/paradise_zombies/sound/footsteps/ds13/twitcher_2.ogg')
	cry_sounds = list('modular_bandastation/paradise_zombies/sound/mutations/twitcher_shout.ogg')

/datum/paradise_zombie_form/hunter
	id = "hunter"
	name = "Ловчий"
	desc = "Прыжок из засады сбивает жертву с ног; отдельный прыжок позволяет прижать её к земле. После промаха вы уязвимы."
	tier = 2
	body_icon = 'modular_bandastation/paradise_zombies/icons/mutations/hunter.dmi'
	health_bonus = 20
	slowdown = -0.4
	claw_multiplier = 0.9
	ability_types = list(/datum/action/cooldown/paradise_zombie_mutation/dash/pounce, /datum/action/cooldown/paradise_zombie_mutation/dash/pounce/pin)
	footstep_sounds = list('modular_bandastation/paradise_zombies/sound/footsteps/ds13/hunter_1.ogg', 'modular_bandastation/paradise_zombies/sound/footsteps/ds13/hunter_2.ogg')
	cry_sounds = list('modular_bandastation/paradise_zombies/sound/voices/hunter_1.ogg', 'modular_bandastation/paradise_zombies/sound/voices/hunter_2.ogg')

/datum/paradise_zombie_form/brute
	id = "brute"
	name = "Громила"
	desc = "Могучее и живучее тело. Тяжёлые когти сокрушают баррикады, а отдельным действием можно выламывать стены. Вы медленны и заметны."
	tier = 3
	body_icon = 'modular_bandastation/paradise_zombies/icons/mutations/brute.dmi'
	health_bonus = 370
	slowdown = 1.5
	claw_multiplier = 1.5
	barrier_damage_bonus = 60
	ability_types = list(/datum/action/cooldown/paradise_zombie_mutation/tear_wall)
	footstep_sounds = list('modular_bandastation/paradise_zombies/sound/footsteps/alien_footstep_large1.ogg', 'modular_bandastation/paradise_zombies/sound/footsteps/alien_footstep_large2.ogg', 'modular_bandastation/paradise_zombies/sound/footsteps/alien_footstep_large3.ogg')
	cry_sounds = list('modular_bandastation/paradise_zombies/sound/voices/brute_1.ogg', 'modular_bandastation/paradise_zombies/sound/voices/brute_2.ogg')

/datum/paradise_zombie_form/spitter
	id = "spitter"
	name = "Желчник"
	desc = "Желчный плевок замедляет противника; кислотный плевок оставляет опасную область с постоянным уроном. Слаб в ближнем бою."
	tier = 2
	body_icon = 'modular_bandastation/paradise_zombies/icons/mutations/spitter.dmi'
	health_bonus = -15
	slowdown = 0.3
	claw_multiplier = 0.4
	ability_types = list(/datum/action/cooldown/paradise_zombie_mutation/bile, /datum/action/cooldown/paradise_zombie_mutation/bile/acid)
	footstep_sounds = list('modular_bandastation/paradise_zombies/sound/footsteps/ds13/spitter_1.ogg', 'modular_bandastation/paradise_zombies/sound/footsteps/ds13/spitter_2.ogg')
	cry_sounds = list('modular_bandastation/paradise_zombies/sound/voices/spitter_1.ogg', 'modular_bandastation/paradise_zombies/sound/voices/spitter_2.ogg')

/datum/paradise_zombie_form/exploder
	id = "exploder"
	name = "Нарывник"
	desc = "Взрыв заражённой желчи поражает ближайших противников; рвота временно ослепляет цель. Подготовка взрыва заметна, а нарост можно прострелить."
	tier = 2
	body_icon = 'modular_bandastation/paradise_zombies/icons/mutations/exploder.dmi'
	health_bonus = 35
	slowdown = 0.5
	claw_multiplier = 0.6
	ability_types = list(/datum/action/cooldown/paradise_zombie_mutation/explode, /datum/action/cooldown/paradise_zombie_mutation/vomit_bile)
	footstep_sounds = list('modular_bandastation/paradise_zombies/sound/footsteps/ds13/exploder_1.ogg', 'modular_bandastation/paradise_zombies/sound/footsteps/ds13/exploder_2.ogg')
	cry_sounds = list('modular_bandastation/paradise_zombies/sound/voices/exploder_1.ogg', 'modular_bandastation/paradise_zombies/sound/voices/exploder_2.ogg')

/// A source-owned variable modifier lets mutation cleanup restore normal movement exactly.
/datum/movespeed_modifier/paradise_zombie_mutation
	variable = TRUE
