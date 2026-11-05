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
	/// Added to the ordinary zombie's movement delay.
	var/slowdown = 0
	var/claw_multiplier = 1
	var/barrier_damage_bonus = 0
	/// Actions owned by the physical body's mutation controller.
	var/list/ability_types = list()

/datum/paradise_zombie_form/slasher
	id = "slasher"
	name = "Рваный"
	desc = "Основная мутировавшая форма: когти, укусы и вскрытие дверей. Обычная живучесть зомби."
	body_icon = 'modular_bandastation/paradise_zombies/icons/mutations/slasher.dmi'

/datum/paradise_zombie_form/twitcher
	id = "twitcher"
	name = "Бегун"
	desc = "Быстрое передвижение и рывок до 12 клеток. Хрупкое тело и ослабленные когти."
	body_icon = 'modular_bandastation/paradise_zombies/icons/mutations/twitcher.dmi'
	health_bonus = -35
	slowdown = -1.5
	claw_multiplier = 0.85
	ability_types = list(/datum/action/cooldown/paradise_zombie_mutation/dash)

/datum/paradise_zombie_form/hunter
	id = "hunter"
	name = "Ловчий"
	desc = "Прыжок из засады сбивает жертву с ног. После промаха вы уязвимы."
	tier = 2
	body_icon = 'modular_bandastation/paradise_zombies/icons/mutations/hunter.dmi'
	health_bonus = 20
	slowdown = -0.4
	claw_multiplier = 0.9
	ability_types = list(/datum/action/cooldown/paradise_zombie_mutation/dash/pounce)

/datum/paradise_zombie_form/brute
	id = "brute"
	name = "Громила"
	desc = "Живучее тело и тяжёлые когти сокрушают баррикады. Вы медленны и заметны."
	tier = 3
	body_icon = 'modular_bandastation/paradise_zombies/icons/mutations/brute.dmi'
	health_bonus = 150
	slowdown = 1.5
	claw_multiplier = 1.5
	barrier_damage_bonus = 60

/datum/paradise_zombie_form/spitter
	id = "spitter"
	name = "Желчник"
	desc = "Плевки желчью обжигают и замедляют противника, оставляя лужи. Слаб в ближнем бою."
	tier = 2
	body_icon = 'modular_bandastation/paradise_zombies/icons/mutations/spitter.dmi'
	health_bonus = -15
	slowdown = 0.3
	claw_multiplier = 0.4
	ability_types = list(/datum/action/cooldown/paradise_zombie_mutation/bile)

/datum/paradise_zombie_form/exploder
	id = "exploder"
	name = "Нарывник"
	desc = "Взрыв заражённой желчи поражает ближайших противников. Подготовка заметна, а нарост можно прострелить."
	tier = 2
	body_icon = 'modular_bandastation/paradise_zombies/icons/mutations/exploder.dmi'
	health_bonus = 35
	slowdown = 0.5
	claw_multiplier = 0.6
	ability_types = list(/datum/action/cooldown/paradise_zombie_mutation/explode)

/// A source-owned variable modifier lets mutation cleanup restore normal movement exactly.
/datum/movespeed_modifier/paradise_zombie_mutation
	variable = TRUE
