/// Paradise's original bee infestation, isolated from TG's different recovery model.
/datum/disease/beesease/paradise_plague
	parent_type = /datum/disease/paradise_plague_dependency
	name = "Пчелезнь"
	form = "Инфекция"
	max_stages = 4
	cure_text = "Сахар"
	cures = list(/datum/reagent/consumable/sugar)
	agent = "Инфекция Apidae"
	viable_mobtypes = list(/mob/living/carbon/human)
	desc = "Без лечения больной начнёт откашливать пчёл."
	severity = DISEASE_SEVERITY_BIOHAZARD

/datum/disease/beesease/paradise_plague/on_plague_cycle()
	switch(stage)
		if(2)
			if(prob(2))
				to_chat(affected_mob, span_notice("Вы чувствуете вкус мёда во рту."))
		if(3)
			if(prob(10))
				to_chat(affected_mob, span_notice("У вас урчит в животе."))
			if(prob(2))
				to_chat(affected_mob, span_danger("В желудке болезненно покалывает."))
				if(prob(20))
					affected_mob.adjust_tox_loss(2)
		if(4)
			if(prob(10))
				affected_mob.visible_message(span_danger("[affected_mob] жужжит."), span_userdanger("В животе неистово жужжит!"))
			if(prob(5))
				to_chat(affected_mob, span_danger("Вы чувствуете, как что-то шевелится у вас в горле."))
			if(prob(1))
				affected_mob.visible_message(span_danger("[affected_mob] откашливает рой пчёл!"), span_userdanger("Вы откашливаете рой пчёл!"))
				new /mob/living/basic/bee(affected_mob.loc)

/// ICE9 cold retains its original cooling, frost damage, and lack of spontaneous recovery.
/datum/disease/cold9/paradise_plague
	parent_type = /datum/disease/paradise_plague_dependency
	name = "Ледяная простуда"
	max_stages = 3
	cure_text = "Космоциллин"
	cures = list(/datum/reagent/medicine/spaceacillin)
	agent = "Риновирус ICE9"
	desc = "Без лечения больной замедляется, словно частично замерзает."
	severity = DISEASE_SEVERITY_HARMFUL

/datum/disease/cold9/paradise_plague/on_plague_cycle()
	if(stage < 2)
		return
	var/stage_factor = stage - 1
	affected_mob.bodytemperature -= 7.5 * stage_factor
	if(prob(2 * stage_factor))
		affected_mob.emote("sneeze")
	if(prob(2 * stage_factor))
		affected_mob.emote("cough")
	if(prob(3 * stage_factor))
		to_chat(affected_mob, span_danger("У вас болит горло."))
	if(prob(5 * stage_factor))
		to_chat(affected_mob, span_danger("Ваши движения скованы."))
		affected_mob.adjust_fire_loss(1)

/// The original Spanish Inquisition flu heats its victim and burns at both symptomatic stages.
/datum/disease/fluspanish/paradise_plague
	parent_type = /datum/disease/paradise_plague_dependency
	name = "Грипп испанской инквизиции"
	max_stages = 3
	cure_text = "Космоциллин"
	cures = list(/datum/reagent/medicine/spaceacillin)
	cure_chance = 10
	agent = "Вирион гриппа 1nqu1s1t10n"
	spreading_modifier = 0.75
	desc = "Без лечения больной сгорит заживо за свою ересь."
	severity = DISEASE_SEVERITY_HARMFUL

/datum/disease/fluspanish/paradise_plague/on_plague_cycle()
	if(stage < 2)
		return
	var/stage_factor = stage - 1
	affected_mob.bodytemperature += 10 * stage_factor
	if(prob(3 * stage_factor))
		affected_mob.emote("sneeze")
	if(prob(3 * stage_factor))
		affected_mob.emote("cough")
	if(prob(2.5 * stage_factor))
		to_chat(affected_mob, span_danger("Ваша кожа словно горит!"))
		affected_mob.adjust_fire_loss(5)

/// Retrovirus keeps its strain-specific rest/mutadone cure and original two DNA-scrambling outcomes.
/datum/disease/dna_retrovirus/paradise_plague
	parent_type = /datum/disease/paradise_plague_dependency
	name = "Ретровирус"
	max_stages = 4
	cure_text = "Отдых или инъекция мутадона"
	cure_chance = 6
	spreading_modifier = 0.4
	stage_prob = 2
	desc = "Изменяющий ДНК ретровирус, который постоянно перемешивает структурные и уникальные ферменты носителя."
	severity = DISEASE_SEVERITY_BIOHAZARD
	/// Sixty percent of new strains are cured by lying down rather than mutadone.
	var/restcure = FALSE

/datum/disease/dna_retrovirus/paradise_plague/New()
	. = ..()
	agent = "Вирус класса [pick("A", "B", "C", "D", "E", "F")][pick("A", "B", "C", "D", "E", "F")]-[rand(50, 300)]"
	if(prob(40))
		cures = list(/datum/reagent/medicine/mutadone)
	else
		restcure = TRUE

/datum/disease/dna_retrovirus/paradise_plague/Copy()
	var/datum/disease/dna_retrovirus/paradise_plague/copied = ..()
	copied.restcure = restcure
	return copied

/datum/disease/dna_retrovirus/paradise_plague/on_plague_cycle()
	var/rest_chance
	switch(stage)
		if(1)
			rest_chance = 30
		if(2, 3)
			rest_chance = 20
		if(4)
			rest_chance = 5
	if(restcure && affected_mob.body_position == LYING_DOWN && prob(rest_chance))
		to_chat(affected_mob, span_notice("Вам становится лучше."))
		cure()
		return
	switch(stage)
		if(1)
			if(prob(8))
				to_chat(affected_mob, span_danger("У вас болит голова."))
			if(prob(9))
				to_chat(affected_mob, "Вы чувствуете покалывание в груди.")
			if(prob(9))
				to_chat(affected_mob, span_danger("Вы чувствуете злость."))
		if(2)
			if(prob(8))
				to_chat(affected_mob, span_danger("Кажется, кожа на вас обвисла."))
			if(prob(10))
				to_chat(affected_mob, "Вы чувствуете себя очень странно.")
			if(prob(4))
				to_chat(affected_mob, span_danger("Вы чувствуете пронзительную боль в голове!"))
				affected_mob.Paralyze(4 SECONDS)
			if(prob(4))
				to_chat(affected_mob, span_danger("У вас крутит живот."))
		if(3)
			if(prob(10))
				to_chat(affected_mob, span_danger("Всё ваше тело вибрирует."))
			if(prob(35))
				scramble_host()
		if(4)
			if(prob(60))
				scramble_host()

/// Paradise's UI/SE map to TG identity/mutation blocks; feature DNA is not a third outcome.
/datum/disease/dna_retrovirus/paradise_plague/proc/scramble_host()
	if(!affected_mob.has_dna())
		return
	var/scramble_identity = prob(50)
	scramble_dna(affected_mob, ui = scramble_identity, se = !scramble_identity, probability = rand(15, 45))

/// Fungal tuberculosis uses the donor's salbutamol cure and stage-specific symptoms.
/datum/disease/tuberculosis/paradise_plague
	parent_type = /datum/disease/paradise_plague_dependency
	form = "Болезнь"
	name = "Грибковый туберкулёз"
	max_stages = 5
	cure_text = "Космоциллин и сальбутамол"
	cures = list(/datum/reagent/medicine/spaceacillin, /datum/reagent/medicine/salbutamol)
	agent = "Грибковая туберкулёзная палочка Cosmosis"
	cure_chance = 5
	desc = "Редкий высокозаразный вирулентный вирус. Вызывает жар, кровавую рвоту, повреждение лёгких, потерю веса и утомляемость."
	required_organ = ORGAN_SLOT_LUNGS
	severity = DISEASE_SEVERITY_HARMFUL

/datum/disease/tuberculosis/paradise_plague/on_plague_cycle()
	switch(stage)
		if(2)
			if(prob(2))
				affected_mob.emote("cough")
				to_chat(affected_mob, span_danger("У вас болит грудь."))
			if(prob(2))
				to_chat(affected_mob, span_danger("В животе неистово урчит!"))
			if(prob(5))
				to_chat(affected_mob, span_danger("Вас прошибает холодный пот."))
		if(4)
			if(prob(2))
				to_chat(affected_mob, span_userdanger("У вас всё четверится."))
				affected_mob.set_dizzy_if_lower(10 SECONDS)
			if(prob(2))
				to_chat(affected_mob, span_danger("Вы чувствуете острую боль в нижней части груди!"))
				affected_mob.adjust_oxy_loss(5)
				affected_mob.emote("gasp")
			if(prob(10))
				to_chat(affected_mob, span_danger("Вы чувствуете, как воздух с болью выходит из лёгких."))
				affected_mob.adjust_oxy_loss(25)
				affected_mob.emote("gasp")
		if(5)
			if(prob(2))
				to_chat(affected_mob, span_userdanger("[pick("Вы чувствуете, как замедляется ваше сердце...", "Вы расслабляетесь, и ваше сердцебиение замедляется.")]"))
				affected_mob.adjust_stamina_loss(70)
			if(prob(10))
				affected_mob.adjust_stamina_loss(100)
				affected_mob.visible_message(span_warning("[affected_mob] теряет сознание!"), span_userdanger("Вы перестаёте сопротивляться и обретаете покой..."))
				affected_mob.AdjustSleeping(10 SECONDS)
			if(prob(2))
				to_chat(affected_mob, span_userdanger("Разум расслабляется, а мысли уплывают!"))
				affected_mob.adjust_confusion_up_to(16 SECONDS, 200 SECONDS)
			if(prob(10))
				affected_mob.paradise_vomit(20)
			if(prob(3))
				to_chat(affected_mob, span_warning("<i>[pick("В животе тихо урчит...", "Желудок сводит судорогой, а затем он обмякает; мышцы мертвы и безжизненны.", "Вы готовы съесть даже мелок.")]</i>"))
				// The donor counted two-second life ticks; TG stores deciseconds.
				affected_mob.overeatduration = max(affected_mob.overeatduration - 200 SECONDS, 0)
				affected_mob.adjust_nutrition(-100)
			if(prob(15))
				to_chat(affected_mob, span_danger("[pick("Вам неприятно жарко...", "Вам хочется расстегнуть комбинезон.", "Вам хочется снять с себя часть одежды...")]"))
				affected_mob.bodytemperature += 40

/// The original anxiety has longer confusion attacks and short-lived butterflies.
/datum/disease/anxiety/paradise_plague
	parent_type = /datum/disease/paradise_plague_dependency
	name = "Тяжёлая тревожность"
	form = "Инфекция"
	max_stages = 4
	cure_text = "Этанол"
	cures = list(/datum/reagent/consumable/ethanol)
	agent = "Избыток лепидоптицидов"
	viable_mobtypes = list(/mob/living/carbon/human)
	desc = "Без лечения больной начнёт откашливать бабочек."
	severity = DISEASE_SEVERITY_MINOR

/datum/disease/anxiety/paradise_plague/on_plague_cycle()
	switch(stage)
		if(2)
			if(prob(5))
				to_chat(affected_mob, span_notice("Вы чувствуете тревогу."))
		if(3)
			if(prob(10))
				to_chat(affected_mob, span_notice("Вы чувствуете трепет в животе."))
			if(prob(5))
				to_chat(affected_mob, span_notice("Вас охватывает паника."))
			if(prob(2))
				to_chat(affected_mob, span_danger("Паника полностью захватывает вас!"))
				affected_mob.adjust_confusion(rand(4 SECONDS, 6 SECONDS))
		if(4)
			if(prob(10))
				to_chat(affected_mob, span_danger("Вы чувствуете бабочек в животе."))
			if(prob(5))
				affected_mob.visible_message(span_danger("[affected_mob] мечется в панике, спотыкаясь."), span_userdanger("У вас паническая атака!"))
				affected_mob.adjust_confusion(rand(12 SECONDS, 16 SECONDS))
				affected_mob.adjust_jitter(rand(12 SECONDS, 16 SECONDS))
			if(prob(2))
				affected_mob.visible_message(span_danger("[affected_mob] откашливает бабочек!"), span_userdanger("Вы откашливаете бабочек!"))
				spawn_butterflies()

/// Spawn the donor's pair, each with its own five-to-twenty-five-second decomposition timer.
/datum/disease/anxiety/paradise_plague/proc/spawn_butterflies()
	var/list/butterflies = list()
	for(var/count in 1 to 2)
		butterflies += new /mob/living/basic/butterfly/paradise_plague(affected_mob.loc)
	return butterflies

/// These butterflies disappear instead of accumulating permanently on the server.
/mob/living/basic/butterfly/paradise_plague
	gold_core_spawnable = NO_SPAWN
	/// Cancel the pending lifetime callback when the butterfly is deleted early.
	var/decompose_timer

/mob/living/basic/butterfly/paradise_plague/Initialize(mapload)
	. = ..()
	decompose_timer = addtimer(CALLBACK(src, PROC_REF(decompose)), rand(5, 25) SECONDS, TIMER_STOPPABLE)

/mob/living/basic/butterfly/paradise_plague/Destroy()
	if(decompose_timer)
		deltimer(decompose_timer)
	return ..()

/// Remove the insect and its corpse just as the donor's melt did.
/mob/living/basic/butterfly/paradise_plague/proc/decompose()
	visible_message(span_notice("[capitalize(declent_ru(NOMINATIVE))] разлагается, слишком долго пробыв вне родной среды!"), span_userdanger("Вы разлагаетесь, слишком долго пробыв вне родной среды!"))
	qdel(src)

/// Wizarditis produces sayings, disposable clothes and rare teleports; it grants no TG spell arsenal.
/datum/disease/wizarditis/paradise_plague
	parent_type = /datum/disease/paradise_plague_dependency
	name = "Волшебнит"
	desc = "У больных наблюдаются признаки деменции, выкрикивание непонятных фраз и растущее ощущение внутренней силы."
	max_stages = 4
	cure_text = "Коктейль «The Manly Dorf»"
	cures = list(/datum/reagent/consumable/ethanol/manly_dorf)
	cure_chance = 100
	agent = "Rincewindus Vulgaris"
	spreading_modifier = 0.75
	severity = DISEASE_SEVERITY_MINOR
	/// TG uses indexed hand slots rather than Paradise's left/right equipment slot flags.
	var/list/magic_fashion = list()

/datum/disease/wizarditis/paradise_plague/New()
	. = ..()
	magic_fashion = list(
		"left_hand" = /obj/item/staff,
		"right_hand" = /obj/item/staff,
		"[ITEM_SLOT_HEAD]" = /obj/item/clothing/head/wizard,
		"[ITEM_SLOT_OCLOTHING]" = /obj/item/clothing/suit/wizrobe,
		"[ITEM_SLOT_FEET]" = /obj/item/clothing/shoes/sandal,
	)

/datum/disease/wizarditis/paradise_plague/on_plague_cycle()
	switch(stage)
		if(2, 3)
			if(prob(2))
				affected_mob.say(pick("ТЫ!!! НЕ ПРОЙ-ДЁШЬ!!!", "Экспеллиармус!", "Мерлинова борода!", "Почувствуй силу тёмной стороны!"))
			if(prob(8))
				to_chat(affected_mob, span_danger(pick("Вы чувствуете, что вам не хватает маны.", "Вы чувствуете, что ветры магии стихли.", "Кажется, это место даёт вам +1 к интеллекту.", "Вам хочется призвать фамильяра.")))
		if(4)
			if(prob(1))
				affected_mob.say(pick("FORTI GY AMA!", "GITTAH WEIGH!", "TOKI WO TOMARE!", "TARCOL MINTI ZHERI!", "ONI SOMA!", "EI NATH!", "BIRUZ BENNAR!", "NWOLC EGNEVER!"))
			if(prob(3))
				to_chat(affected_mob, span_danger(pick("Вы чувствуете, как внутри нарастает прилив необузданной силы.", "Кажется, это место даёт вам +2 к интеллекту и +1 к мудрости.", "Вам хочется телепортироваться.", "Вы чувствуете магию, бурлящую в ваших венах.", "Вам хочется призвать фамильяра.")))
			if(prob(3))
				spawn_wizard_clothes()
			if(prob(0.033))
				teleport()

/// Replace one eligible slot with one DROPDEL magical item, preserving irremovable equipment.
/datum/disease/wizarditis/paradise_plague/proc/spawn_wizard_clothes()
	var/mob/living/carbon/human/host = affected_mob
	if(!istype(host))
		return FALSE
	var/list/eligible_slots = list()
	for(var/slot in magic_fashion)
		var/hand_index = slot == "left_hand" ? LEFT_HANDS : (slot == "right_hand" ? RIGHT_HANDS : 0)
		var/equipment_slot = hand_index ? ITEM_SLOT_HANDS : text2num(slot)
		var/obj/item/current = hand_index ? host.get_item_for_held_index(hand_index) : host.get_item_by_slot(equipment_slot)
		if((locate(magic_fashion[slot]) in host) || !host.canUnEquip(current))
			continue
		if(hand_index && !host.has_hand_for_held_index(hand_index))
			continue
		if(equipment_slot == ITEM_SLOT_HEAD && (!host.get_bodypart(BODY_ZONE_HEAD) || isplasmaman(host)))
			continue
		if(equipment_slot == ITEM_SLOT_OCLOTHING && !host.get_bodypart(BODY_ZONE_CHEST))
			continue
		if(equipment_slot == ITEM_SLOT_FEET && !host.num_legs)
			continue
		eligible_slots += slot
	if(!length(eligible_slots))
		return FALSE
	var/chosen_slot = pick(eligible_slots)
	var/hand_index = chosen_slot == "left_hand" ? LEFT_HANDS : (chosen_slot == "right_hand" ? RIGHT_HANDS : 0)
	var/equipment_slot = hand_index ? ITEM_SLOT_HANDS : text2num(chosen_slot)
	var/obj/item/current = hand_index ? host.get_item_for_held_index(hand_index) : host.get_item_by_slot(equipment_slot)
	if(current && !host.dropItemToGround(current))
		return FALSE
	var/item_type = magic_fashion[chosen_slot]
	var/obj/item/attire = new item_type()
	attire.item_flags |= DROPDEL
	if(hand_index)
		if(!host.put_in_hand(attire, hand_index, forced = TRUE))
			qdel(attire)
			return FALSE
	else if(!host.equip_to_slot_or_del(attire, equipment_slot))
		return FALSE
	return TRUE

/// The original rare teleport chooses a clear non-space area within an eighty-tile area search.
/datum/disease/wizarditis/paradise_plague/proc/teleport()
	if(!check_teleport_valid(affected_mob, get_turf(affected_mob), TELEPORT_CHANNEL_MAGIC))
		return FALSE
	var/list/possible_areas = get_areas_in_range(80, affected_mob)
	for(var/area/space/space_area in possible_areas.Copy())
		possible_areas -= space_area
	if(!length(possible_areas))
		return FALSE
	var/area/chosen_area = pick(possible_areas)
	var/list/teleport_turfs = list()
	for(var/turf/destination as anything in get_area_turfs(chosen_area.type))
		if(isspaceturf(destination) || destination.density)
			continue
		var/clear = TRUE
		for(var/obj/obstacle in destination)
			if(obstacle.density)
				clear = FALSE
				break
		if(clear)
			teleport_turfs += destination
	if(!length(teleport_turfs))
		return FALSE
	affected_mob.say("SCYAR NILA [uppertext(chosen_area.name)]!")
	return do_teleport(affected_mob, pick(teleport_turfs), no_effects = TRUE, channel = TELEPORT_CHANNEL_MAGIC)
