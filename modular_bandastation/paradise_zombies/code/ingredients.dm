/** Existing collection tools provide the original natural research ingredients. */
/obj/effect/decal/cleanable/vomit
	decal_reagent = /datum/reagent/paradise_vomit
	reagent_amount = 5

/obj/structure/toilet
	reagent_id = /datum/reagent/water/paradise_toilet

/obj/item/food/badrecipe/grind_results()
	. = ..()
	if(isnull(.))
		. = list()
	.[/datum/reagent/paradise_questionmark] = 30

/** Temperature-regulating plasma compound used in Beta research. */
/datum/reagent/medicine/paradise_teporone
	name = "Тепорон"
	description = "Это экспериментальное соединение на основе плазмы, похоже, регулирует температуру тела."
	color = "#D782E6"
	taste_description = "тепла и стабильности"
	metabolization_rate = 0.2
	chemical_flags = REAGENT_REVERSE_METABOLISM
	overdose_threshold = 50
	addiction_types = list(/datum/addiction/opioids = 10)

/datum/reagent/medicine/paradise_teporone/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()
	if(affected_mob.bodytemperature > 310)
		affected_mob.bodytemperature = max(310, affected_mob.bodytemperature - 20 * TEMPERATURE_DAMAGE_COEFFICIENT * seconds_per_tick)
	else if(affected_mob.bodytemperature < 311)
		affected_mob.bodytemperature = min(310, affected_mob.bodytemperature + 20 * TEMPERATURE_DAMAGE_COEFFICIENT * seconds_per_tick)

/** Activated charcoal, retaining the donor's indiscriminate reagent purge. */
/datum/reagent/medicine/paradise_charcoal
	name = "Активированный уголь"
	description = "Активированный уголь медленно поглощает токсины в организме."
	taste_description = "пыли"
	metabolization_rate = 0.2
	chemical_flags = REAGENT_REVERSE_METABOLISM

/datum/reagent/medicine/paradise_charcoal/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()
	if(affected_mob.adjust_tox_loss(-0.75 * seconds_per_tick, updating_health = FALSE))
		. |= UPDATE_MOB_HEALTH
	if(SPT_PROB(50, seconds_per_tick / 2))
		for(var/datum/reagent/reagent as anything in holder.reagent_list.Copy())
			if(reagent != src)
				holder.remove_reagent(reagent.type, 1)

/** Repairs every internal organ, and rejuvenates detached organic organs. */
/datum/reagent/medicine/paradise_mitocholide
	name = "Митохолид"
	description = "Стимулирует митохондрии, способствуя восстановлению внутренних органов. Не помогает при внутреннем кровотечении."
	color = "#8523be"
	taste_description = "заботы"
	metabolization_rate = 0.2
	chemical_flags = REAGENT_REVERSE_METABOLISM

/datum/reagent/medicine/paradise_mitocholide/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()
	if(!ishuman(affected_mob))
		return
	var/healing = holder.has_reagent(/datum/reagent/drug/pumpup) ? 0.05 : 0.2
	for(var/obj/item/organ/organ as anything in affected_mob.organs)
		if(organ.apply_organ_damage(-healing * seconds_per_tick))
			. |= UPDATE_MOB_HEALTH

/datum/reagent/medicine/paradise_mitocholide/expose_obj(obj/exposed_obj, reac_volume, methods = TOUCH, show_message = TRUE)
	. = ..()
	if(isorgan(exposed_obj))
		var/obj/item/organ/organ = exposed_obj
		if(!IS_ROBOTIC_ORGAN(organ))
			organ.set_organ_damage(0)

/** Vomit collected from the floor for Gamma research. */
/datum/reagent/paradise_vomit
	name = "Рвотная масса"
	description = "Похоже, кто-то изверг свой обед. А потом собрал его. Фу."
	color = "#FFFF00"
	taste_description = "блевотины"
	metabolization_rate = 0.2

/datum/reagent/paradise_vomit/expose_turf(turf/exposed_turf, reac_volume)
	. = ..()
	if(reac_volume >= 5 && !isspaceturf(exposed_turf))
		exposed_turf.spawn_unique_cleanable(/obj/effect/decal/cleanable/vomit)

/** Contaminated toilet water is the precursor to Jenkem. */
/datum/reagent/water/paradise_toilet
	parent_type = /datum/reagent
	name = "Вода из унитаза"
	description = "Грязная вода из мерзкого унитаза. Абсолютная гадость."
	color = "#757547"
	taste_description = "унитазных нечистот... или чего похуже"
	metabolization_rate = 0.2

/datum/reagent/water/paradise_toilet/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()
	if(SPT_PROB(30, seconds_per_tick / 2))
		affected_mob.paradise_fakevomit(green = prob(50))
	if(affected_mob.adjust_tox_loss(0.5 * seconds_per_tick, updating_health = FALSE))
		. |= UPDATE_MOB_HEALTH

/** A fermented drug brewed from toilet water. */
/datum/reagent/drug/paradise_jenkem
	name = "Дженкем"
	description = "Тюремный наркотик, получаемый брожением фекалий в моче. Невероятная мерзость."
	color = "#644600"
	taste_description = "унитазных нечистот... или чего похуже"
	metabolization_rate = 0.2
	addiction_types = list(/datum/addiction/hallucinogens = 5)

/datum/reagent/drug/paradise_jenkem/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()
	affected_mob.set_dizzy_if_lower(10 SECONDS)
	if(SPT_PROB(10, seconds_per_tick / 2))
		affected_mob.emote(pick("twitch", "drool", "moan"))
		if(affected_mob.adjust_tox_loss(1, updating_health = FALSE))
			. |= UPDATE_MOB_HEALTH

/** A plain soda from the donor; its two-second nutrition and metabolism rates are unchanged. */
/datum/reagent/consumable/paradise_ginger_ale
	name = "Имбирный эль"
	description = "Пряная газировка."
	color = "#996B2B"
	taste_description = "сладкого газированного имбиря"
	creation_purity = 1
	metabolization_rate = 0.2

/** The soft-drink vendor supplies the original otherwise uncraftable cure ingredient. */
/obj/item/reagent_containers/cup/soda_cans/paradise_ginger_ale
	name = "Ginger Ale"
	desc = "Пряная газировка."
	icon_state = "sol_dry"
	inhand_icon_state = "sodawater"
	list_reagents = list(/datum/reagent/consumable/paradise_ginger_ale = 30)
	drink_type = SUGAR

/** The mysterious substance obtained by grinding burned food. */
/datum/reagent/paradise_questionmark
	name = "????"
	description = "Мерзкая неопознаваемая субстанция."
	color = "#63DE63"
	taste_description = "горелой еды"
	metabolization_rate = 0.2

/datum/reagent/paradise_questionmark/expose_mob(mob/living/exposed_mob, methods = TOUCH, reac_volume, show_message = TRUE, touch_protection = 0)
	. = ..()
	if(!(methods & INGEST) || !ishuman(exposed_mob))
		return
	var/mob/living/carbon/human/human = exposed_mob
	if(!HAS_TRAIT(human, TRAIT_AGEUSIA))
		to_chat(human, span_danger("Фу! Есть это было ужасной идеей!"))
		if(!(locate(/datum/disease/paradise_food_poisoning) in human.diseases))
			human.paradise_fakevomit(no_text = TRUE)
	if(HAS_TRAIT(human, TRAIT_NOHUNGER))
		return
	var/datum/disease/paradise_food_poisoning/poisoning = new()
	human.ForceContractDisease(poisoning, make_copy = FALSE, del_on_fail = TRUE)

/** A non-contagious infection retained for the burned-food ingredient. */
/datum/disease/paradise_food_poisoning
	parent_type = /datum/disease/paradise_plague_dependency
	name = "Пищевое отравление"
	desc = "Тошнота, недомогание и рвота."
	agent = "Сальмонелла"
	max_stages = 3
	stage_prob = 5
	spread_text = "Не передаётся"
	spread_flags = DISEASE_SPREAD_NON_CONTAGIOUS
	cure_text = "Сон"
	cures = list(/datum/reagent/consumable/nutriment/soup/chicken_noodle_soup, /datum/reagent/consumable/paradise_ginger_ale)
	cure_chance = 10
	viable_mobtypes = list(/mob/living/carbon/human)
	severity = DISEASE_SEVERITY_MINOR
	disease_flags = CURABLE

/datum/disease/paradise_food_poisoning/on_plague_cycle()
	if((affected_mob.IsSleeping() && prob(33)) || (stage > 1 && prob(1) && prob(10)))
		to_chat(affected_mob, span_notice("Вам становится лучше."))
		cure()
		return FALSE
	switch(stage)
		if(1)
			if(prob(5))
				to_chat(affected_mob, span_danger("В желудке странное ощущение."))
			if(prob(5))
				to_chat(affected_mob, span_danger("Вас мутит."))
		if(2)
			if(affected_mob.IsSleeping() && prob(40))
				cure()
				return FALSE
			if(prob(10))
				affected_mob.emote("groan")
			if(prob(5))
				to_chat(affected_mob, span_danger("У вас ноет желудок."))
			if(prob(5))
				to_chat(affected_mob, span_danger("Вас тошнит."))
		if(3)
			if(affected_mob.IsSleeping() && prob(25))
				cure()
				return FALSE
			if(prob(10))
				affected_mob.emote("moan")
			if(prob(10))
				affected_mob.emote("groan")
			if(prob(1))
				to_chat(affected_mob, span_danger("У вас болит желудок."))
			if(prob(1))
				to_chat(affected_mob, span_danger("Вы чувствуете недомогание."))
			if(prob(5))
				if(affected_mob.nutrition > 10)
					affected_mob.visible_message(span_danger("[affected_mob] обильно блюёт на пол!"))
					affected_mob.paradise_fakevomit(no_text = TRUE)
					affected_mob.adjust_nutrition(-rand(3, 5))
				else
					to_chat(affected_mob, span_danger("Желудок болезненно скручивает!"))
					affected_mob.Stun(rand(4 SECONDS, 8 SECONDS))
					affected_mob.Knockdown(rand(4 SECONDS, 8 SECONDS))

/datum/disease/paradise_food_poisoning/get_recovery_failure_chance()
	return 100

/** Original non-toxic-to-humans herbicide, also an Omega ingredient. */
/datum/reagent/paradise_glyphosate
	name = "Глифосат"
	description = "Гербицид широкого действия, крайне эффективно уничтожающий любые растения."
	color = "#d3cf50"
	taste_description = "горечи"
	metabolization_rate = 0.2
	/// The donor's Atrazine subtype is poisonous where Glyphosate is not.
	var/lethality = 0

/datum/reagent/paradise_glyphosate/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()
	if(affected_mob.adjust_tox_loss(lethality * seconds_per_tick / 2, updating_health = FALSE))
		. |= UPDATE_MOB_HEALTH

/datum/reagent/paradise_glyphosate/expose_obj(obj/exposed_obj, reac_volume, methods = TOUCH, show_message = TRUE)
	. = ..()
	if(istype(exposed_obj, /obj/structure/alien/weeds))
		exposed_obj.take_damage(rand(15, 35), BRUTE, 0)
	else if(istype(exposed_obj, /obj/structure/glowshroom) || istype(exposed_obj, /obj/structure/spacevine))
		qdel(exposed_obj)

/datum/reagent/paradise_glyphosate/expose_mob(mob/living/exposed_mob, methods = TOUCH, reac_volume, show_message = TRUE, touch_protection = 0)
	. = ..()
	if(exposed_mob.mob_biotypes & MOB_PLANT)
		exposed_mob.adjust_tox_loss(min(round(0.4 * reac_volume, 0.1), 10))
	if(ishuman(exposed_mob))
		var/mob/living/carbon/human/human = exposed_mob
		if(!human.wear_mask)
			human.adjust_tox_loss(lethality)

/datum/reagent/paradise_glyphosate/on_hydroponics_apply(obj/machinery/hydroponics/tray, mob/user)
	tray.adjust_plant_health(-round(volume * 10))
	tray.adjust_weedlevel(-rand(4, 8))

/** Toxic herbicide precursor used in the Sarin recipe. */
/datum/reagent/paradise_glyphosate/atrazine
	name = "Атразин"
	description = "Гербицидное соединение для уничтожения нежелательных растений."
	color = "#773E73"
	lethality = 2

/** Synthetic stimulant used in the Gamma ingredient pool. */
/datum/reagent/drug/paradise_surge
	name = "Сёрдж"
	description = "Сверхпроводящий гель, перегружающий процессоры. По сообщениям, у синтетиков вызывает эффект, похожий на действие опиатов."
	color = "#6DD16D"
	taste_description = "тепла, растекающегося по корпусу"
	metabolization_rate = 0.2
	overdose_threshold = 20
	addiction_types = list(/datum/addiction/stimulants = 5)
	affected_biotype = MOB_ROBOTIC
	affected_bodytype = BODYTYPE_ROBOTIC
	affected_organ_flags = ORGAN_ROBOTIC

/datum/reagent/drug/paradise_surge/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()
	if(!(affected_mob.mob_biotypes & MOB_ROBOTIC))
		return
	var/recent_consumption = affected_mob.paradise_synthetic_drug_dose(type, metabolization_rate * seconds_per_tick * affected_mob.metabolism_efficiency, 0.1)
	affected_mob.set_drugginess(30 SECONDS)
	affected_mob.AdjustAllImmobility(-2 SECONDS * seconds_per_tick)
	if(affected_mob.adjust_stamina_loss(-20 * seconds_per_tick, updating_stamina = FALSE, required_biotype = affected_biotype))
		. |= UPDATE_MOB_HEALTH
	if(SPT_PROB(5, seconds_per_tick / 2))
		to_chat(affected_mob, span_notice(prob(10) ? "0100011101001111010101000101010001000001010001110100111101000110010000010101001101010100!" : pick("Вы чувствуете спокойствие.", "Вы чувствуете собранность.", "Вам хочется расслабиться.")))
	if(SPT_PROB(2.5 * 0.1 * recent_consumption, seconds_per_tick / 2))
		to_chat(affected_mob, span_notice("Ваши схемы перегреваются!"))
		affected_mob.bodytemperature += 30 * 0.2 * recent_consumption
		affected_mob.set_confusion_if_lower(1 SECONDS * 0.2 * recent_consumption)

/datum/reagent/drug/paradise_surge/on_mob_delete(mob/living/affected_mob)
	. = ..()
	if(iscarbon(affected_mob))
		var/mob/living/carbon/carbon = affected_mob
		carbon.paradise_synthetic_drug_ended(type)

/datum/reagent/drug/paradise_surge/overdose_process(mob/living/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()
	if(!(affected_mob.mob_biotypes & MOB_ROBOTIC))
		return
	affected_mob.Knockdown(10 SECONDS)
	affected_mob.set_jitter_if_lower(40 SECONDS)
	affected_mob.set_stutter_if_lower(10 SECONDS)
	if(SPT_PROB(10, seconds_per_tick / 2))
		to_chat(affected_mob, span_danger("Вас пронзает мощный электрический разряд!"))
		do_sparks(5, TRUE, affected_mob)
		affected_mob.adjust_fire_loss(rand(1, 5), required_bodytype = affected_bodytype)
		affected_mob.adjust_brute_loss(rand(1, 5), required_bodytype = affected_bodytype)

/** Synthetic lubricant: the donor's stimulant, distinct from TG superlube. */
/datum/reagent/lube/paradise_ultra
	name = "Ультрасмазка"
	description = "Усовершенствованная смазка, стимулирующая синтетиков благодаря уменьшению внутреннего трения и усилению охлаждения."
	color = "#1BB1FF"
	taste_description = "смазанных сервоприводов"
	metabolization_rate = 0.3
	overdose_threshold = 20
	addiction_types = list(/datum/addiction/stimulants = 5)
	affected_biotype = MOB_ROBOTIC
	affected_bodytype = BODYTYPE_ROBOTIC
	affected_organ_flags = ORGAN_ROBOTIC
	/// Whether this holder received our additive physiology changes.
	var/stimulant_applied = FALSE

/datum/reagent/lube/paradise_ultra/on_mob_add(mob/living/affected_mob, amount)
	. = ..()
	if(ishuman(affected_mob) && (affected_mob.mob_biotypes & MOB_ROBOTIC))
		var/mob/living/carbon/human/human = affected_mob
		MODIFY_PHYSIOLOGY(human, PHYS_COEFF_STUN, 1.5)
		human.add_movespeed_modifier(/datum/movespeed_modifier/reagent/paradise_ultralube)
		stimulant_applied = TRUE

/datum/reagent/lube/paradise_ultra/on_mob_delete(mob/living/affected_mob)
	. = ..()
	if(iscarbon(affected_mob))
		var/mob/living/carbon/carbon = affected_mob
		carbon.paradise_synthetic_drug_ended(type)
	if(stimulant_applied && ishuman(affected_mob))
		var/mob/living/carbon/human/human = affected_mob
		MODIFY_PHYSIOLOGY(human, PHYS_COEFF_STUN, 1 / 1.5)
		human.remove_movespeed_modifier(/datum/movespeed_modifier/reagent/paradise_ultralube)
		stimulant_applied = FALSE

/datum/reagent/lube/paradise_ultra/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()
	if(!(affected_mob.mob_biotypes & MOB_ROBOTIC))
		return
	var/recent_consumption = affected_mob.paradise_synthetic_drug_dose(type, metabolization_rate * seconds_per_tick * affected_mob.metabolism_efficiency, 0.05)
	affected_mob.adjust_jitter(5 SECONDS * seconds_per_tick)
	affected_mob.adjust_stamina_loss(-20 * seconds_per_tick, required_biotype = affected_biotype)
	affected_mob.SetSleeping(0)
	affected_mob.set_drowsiness(0)
	if(SPT_PROB(6 * 0.1 * recent_consumption, seconds_per_tick / 2))
		affected_mob.adjust_organ_loss(ORGAN_SLOT_BRAIN, 10, required_organ_flag = affected_organ_flags)
	if(SPT_PROB(5, seconds_per_tick / 2))
		to_chat(affected_mob, span_notice(prob(10) ? "0100011101001111010101000101010001000001010001110100111101000110010000010101001101010100!" : pick("Вы чувствуете, как жужжат ваши сервоприводы!", "Вам хочется двигаться быстрее.", "Кажется, вас только что разогнали!")))
	if(SPT_PROB(5, seconds_per_tick / 2))
		affected_mob.emote(pick("twitch", "shiver"))

/datum/reagent/lube/paradise_ultra/overdose_process(mob/living/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()
	if(!(affected_mob.mob_biotypes & MOB_ROBOTIC))
		return
	if(SPT_PROB(20, seconds_per_tick / 2))
		affected_mob.emote("ping")
	if(SPT_PROB(33, seconds_per_tick / 2))
		affected_mob.visible_message(span_danger("[affected_mob] беспорядочно размахивает руками!"))
		affected_mob.dropItemToGround(affected_mob.get_active_held_item())
	affected_mob.adjust_fire_loss(2.5 * seconds_per_tick, required_bodytype = affected_bodytype)
	affected_mob.adjust_organ_loss(ORGAN_SLOT_BRAIN, 1.5 * seconds_per_tick, required_organ_flag = affected_organ_flags)

/** Separate source so ending Ultra-Lube does not remove another stimulant. */
/datum/movespeed_modifier/reagent/paradise_ultralube
	multiplicative_slowdown = -1

/** A progressive neurotoxin retained as an Omega candidate. */
/datum/reagent/toxin/paradise_sarin
	name = "Зарин"
	description = "Чрезвычайно смертоносный нейротоксин."
	taste_description = "горечи"
	color = "#C7C7C7"
	metabolization_rate = 0.05
	penetrates_skin = TOUCH|VAPOR
	overdose_threshold = 25
	taste_mult = 0
	toxpwr = 0
	/// Progress is measured in seconds rather than variable-rate metabolism ticks.
	var/exposure_seconds = 0

/datum/reagent/toxin/paradise_sarin/on_mob_life(mob/living/carbon/affected_mob, seconds_per_tick, metabolization_ratio)
	. = ..()
	exposure_seconds += seconds_per_tick
	switch(exposure_seconds)
		if(0 to 30)
			affected_mob.adjust_jitter(20 SECONDS * seconds_per_tick)
			if(SPT_PROB(20, seconds_per_tick / 2))
				affected_mob.emote(pick("twitch", "quiver"))
		if(30 to 60)
			if(SPT_PROB(25, seconds_per_tick / 2))
				affected_mob.emote(pick("twitch", "twitch", "drool", "quiver", "tremble"))
			affected_mob.adjust_eye_blur(5 SECONDS * seconds_per_tick)
			affected_mob.set_stutter_if_lower(10 SECONDS)
			if(SPT_PROB(10, seconds_per_tick / 2))
				affected_mob.set_confusion_if_lower(30 SECONDS)
			if(SPT_PROB(15, seconds_per_tick / 2))
				affected_mob.Stun(2 SECONDS)
				affected_mob.emote("scream")
		if(60 to 120)
			affected_mob.adjust_eye_blur(5 SECONDS * seconds_per_tick)
			affected_mob.set_stutter_if_lower(10 SECONDS)
			if(SPT_PROB(10, seconds_per_tick / 2))
				affected_mob.Stun(2 SECONDS)
				affected_mob.emote(pick("twitch", "twitch", "drool", "shake", "tremble"))
			if(SPT_PROB(5, seconds_per_tick / 2))
				affected_mob.emote("faint")
			if(SPT_PROB(5, seconds_per_tick / 2))
				affected_mob.Knockdown(6 SECONDS)
				affected_mob.visible_message(span_warning("[affected_mob] бьётся в припадке!"))
				affected_mob.set_jitter(2000 SECONDS)
			if(SPT_PROB(5, seconds_per_tick / 2))
				to_chat(affected_mob, span_warning("Вы не можете дышать!"))
				affected_mob.emote(pick("gasp", "choke", "cough"))
				affected_mob.losebreath += 2
		if(120 to INFINITY)
			if(SPT_PROB(15, seconds_per_tick / 2))
				affected_mob.emote(pick("gasp", "choke", "cough", "twitch", "shake", "tremble", "quiver", "drool", "twitch", "faint"))
			affected_mob.losebreath = max(affected_mob.losebreath, 10)
			affected_mob.adjust_tox_loss(0.5 * seconds_per_tick)
			affected_mob.adjust_organ_loss(ORGAN_SLOT_BRAIN, 0.5 * seconds_per_tick)
			affected_mob.Knockdown(8 SECONDS)
	if(SPT_PROB(8, seconds_per_tick / 2))
		affected_mob.paradise_fakevomit()
	affected_mob.adjust_tox_loss(0.5 * seconds_per_tick)
	affected_mob.adjust_organ_loss(ORGAN_SLOT_BRAIN, 0.5 * seconds_per_tick)
	affected_mob.adjust_fire_loss(0.5 * seconds_per_tick)

/mob/living/carbon
	/// Primitive dose/decay records preserve synthetic drug exposure between doses.
	var/list/paradise_synthetic_drug_doses

/** Preserves the donor's accumulated-dose drawback curve without permanent processing. */
/mob/living/carbon/proc/paradise_synthetic_drug_dose(reagent_type, consumed, decay_per_second)
	LAZYINITLIST(paradise_synthetic_drug_doses)
	var/list/record = paradise_synthetic_drug_doses[reagent_type]
	if(isnull(record))
		record = list("amount" = 0, "time" = world.time, "present" = FALSE)
		paradise_synthetic_drug_doses[reagent_type] = record
	if(!record["present"])
		record["amount"] = max(0, record["amount"] - ((world.time - record["time"]) / (1 SECONDS)) * decay_per_second)
	var/recent_consumption = record["amount"]
	record["amount"] += consumed
	record["time"] = world.time
	record["present"] = TRUE
	return recent_consumption

/** Begins passive dose decay only once the reagent leaves the bloodstream. */
/mob/living/carbon/proc/paradise_synthetic_drug_ended(reagent_type)
	var/list/record = paradise_synthetic_drug_doses?[reagent_type]
	if(record)
		record["time"] = world.time
		record["present"] = FALSE
