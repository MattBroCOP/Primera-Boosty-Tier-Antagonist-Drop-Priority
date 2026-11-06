#ifdef UNIT_TESTS

/// Observe the native payloads by reference, including listeners which run after our callback.
/datum/unit_test/paradise_zombie_audio_test
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test
	abstract_type = /datum/unit_test/paradise_zombie_audio_test
	var/list/observed_steps = list()
	var/list/observed_cries = list()
	var/emotes_used = 0
	var/datum/emote/last_emote

/datum/unit_test/paradise_zombie_audio_test/proc/on_step_sound(mob/living/carbon/human/source, list/step_sound)
	SIGNAL_HANDLER
	observed_steps += list(step_sound)

/datum/unit_test/paradise_zombie_audio_test/proc/on_cry_sound(mob/living/source, key, list/sounds)
	SIGNAL_HANDLER
	observed_cries[key] = sounds

/datum/unit_test/paradise_zombie_audio_test/proc/on_emote(mob/living/source, datum/emote/emote)
	SIGNAL_HANDLER
	emotes_used++
	last_emote = emote

/datum/unit_test/paradise_zombie_audio_test/proc/prepare_audio_floor(mob/living/carbon/human/host)
	if(!prepare_range(host, offset = 8))
		return FALSE
	for(var/turf/open/tile as anything in range_reservation.reserved_turfs)
		tile.footstep = FOOTSTEP_FLOOR
		tile.barefootstep = FOOTSTEP_HARD_BAREFOOT
		tile.clawfootstep = FOOTSTEP_HARD_CLAW
		tile.heavyfootstep = FOOTSTEP_GENERIC_HEAVY
	return TRUE

/datum/unit_test/paradise_zombie_audio_test/proc/check_steps(mob/living/carbon/human/host, list/expected, context)
	observed_steps.Cut()
	RegisterSignal(host, COMSIG_HUMAN_FOOTSTEP_SOUND, PROC_REF(on_step_sound))
	host.set_move_intent(MOVE_INTENT_RUN)
	TEST_ASSERT(host.Move(get_step(host, EAST), EAST) && host.Move(get_step(host, WEST), WEST), "[context]: the real running moves failed.")
	TEST_ASSERT_EQUAL(length(observed_steps), 1, "[context]: two native moves did not produce exactly one footfall.")
	var/list/payload = observed_steps[1]
	TEST_ASSERT(payload[1] in expected, "[context]: the final footstep file did not belong to the expected body profile.")
	UnregisterSignal(host, COMSIG_HUMAN_FOOTSTEP_SOUND)
	return TRUE

/datum/unit_test/paradise_zombie_audio_test/proc/check_cries(mob/living/carbon/human/host, list/expected, context, intentional = TRUE, check_silent_death = TRUE)
	host.physique = MALE
	observed_cries.Cut()
	emotes_used = 0
	last_emote = null
	var/list/keys = list("scream", "deathgasp", "gasp", "moan")
	RegisterSignal(host, COMSIG_MOB_EMOTE, PROC_REF(on_emote))
	for(var/key in keys)
		RegisterSignal(host, COMSIG_MOB_EMOTE_SOUND(key), PROC_REF(on_cry_sound))
	TEST_ASSERT(host.emote("scream", intentional = intentional), "[context]: the actual scream command failed.")
	TEST_ASSERT_EQUAL(emotes_used, 1, "[context]: the native scream did not dispatch exactly once.")
	TEST_ASSERT_EQUAL(last_emote.type, /datum/emote/living/scream, "[context]: a non-native scream datum handled the command.")
	var/list/payload = observed_cries["scream"]
	var/monster_override = FALSE
	for(var/candidate in payload)
		if((candidate in expected) && payload[candidate] == EMOTE_SOUND_STATUS_EFFECT + 1)
			monster_override = TRUE
	TEST_ASSERT(monster_override, "[context]: the actual scream lookup omitted the body-owned voice override.")
	var/datum/emote/deathgasp = GLOB.emote_list["deathgasp"][1]
	var/original_death_sound = host.death_sound
	if(check_silent_death)
		TEST_ASSERT_NULL(original_death_sound, "[context]: the ordinary human fixture unexpectedly has an audible death sound.")
		TEST_ASSERT_NULL(deathgasp.get_sound(host), "[context]: a previously silent deathgasp acquired a sound after a recent scream.")
		TEST_ASSERT(host.emote("deathgasp"), "[context]: the silent native deathgasp could not follow a recent scream.")
		TEST_ASSERT_EQUAL(emotes_used, 2, "[context]: the silent deathgasp did not dispatch after the recent scream.")
	// An already audible species death is replaced; ordinary silent death must stay silent.
	host.death_sound = 'sound/mobs/humanoids/human/scream/malescream_1.ogg'
	for(var/key in keys + "screech")
		var/datum/emote/emote = GLOB.emote_list[key][1]
		TEST_ASSERT(emote.get_sound(host) in expected, "[context]: [key] retained a human or unrelated voice.")
	var/datum/emote/scream = GLOB.emote_list["scream"][1]
	for(var/sample in 1 to 1000)
		TEST_ASSERT(scream.get_sound(host) in expected, "[context]: the male human's rare scream escaped the monster override.")
	host.death_sound = original_death_sound
	UnregisterSignal(host, COMSIG_MOB_EMOTE)
	for(var/key in keys)
		UnregisterSignal(host, COMSIG_MOB_EMOTE_SOUND(key))
	return TRUE

/** Every profile is exercised through native Move and emote, without bypassing population limits. */
/datum/unit_test/paradise_zombie_audio_profiles
	parent_type = /datum/unit_test/paradise_zombie_audio_test

/datum/unit_test/paradise_zombie_audio_profiles/Run()
	var/mob/living/carbon/human/host = make_zombie(run_loc_floor_bottom_left)
	TEST_ASSERT(prepare_audio_floor(host), "The audio profile fixture could not reserve its floor.")
	var/turf/stage = get_turf(host)
	for(var/support in 1 to 7)
		make_zombie(run_loc_floor_top_right)
	GLOB.paradise_zombie_mutation_progression.first_infection_at = world.time - 20 MINUTES
	var/list/seen_steps = list()
	var/list/seen_cries = list()
	for(var/profile in list("ordinary", "slasher", "twitcher", "hunter", "brute", "spitter", "exploder"))
		if(profile != "ordinary")
			host = make_zombie(stage)
			var/datum/component/paradise_zombie_mutation/controller = host.GetComponent(/datum/component/paradise_zombie_mutation)
			TEST_ASSERT(controller.apply_form(profile), "The real mutation controller rejected audio profile [profile].")
		var/datum/paradise_zombie_form/form = get_paradise_zombie_form(profile)
		var/list/steps = form?.footstep_sounds || /datum/component/paradise_zombie_regen::ordinary_footsteps
		var/list/cries = form?.cry_sounds || /datum/component/paradise_zombie_regen::ordinary_cries
		TEST_ASSERT(length(steps) && length(cries), "[profile] has an empty audio bank.")
		TEST_ASSERT_EQUAL(length(steps & seen_steps), 0, "[profile] shares another zombie type's footstep bank.")
		TEST_ASSERT_EQUAL(length(cries & seen_cries), 0, "[profile] shares another zombie type's voice bank.")
		seen_steps |= steps
		seen_cries |= cries
		TEST_ASSERT(check_steps(host, steps, profile), "[profile] failed its real footfalls.")
		TEST_ASSERT(check_cries(host, cries, profile), "[profile] failed its real voice dispatch.")
		qdel(host)

/** Immature and cured bodies retain real organs, mask and foreign sound-status listeners. */
/datum/unit_test/paradise_zombie_audio_maturity_and_cure
	parent_type = /datum/unit_test/paradise_zombie_audio_test

/datum/unit_test/paradise_zombie_audio_maturity_and_cure/Run()
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	host.mind_initialize()
	TEST_ASSERT(prepare_audio_floor(host), "The maturity audio fixture could not reserve its floor.")
	var/obj/item/organ/tongue/old_tongue = host.get_organ_slot(ORGAN_SLOT_TONGUE)
	old_tongue.Remove(host)
	qdel(old_tongue)
	var/obj/item/organ/tongue/alien/tongue = allocate(/obj/item/organ/tongue/alien)
	tongue.Insert(host)
	var/obj/item/clothing/mask/gas/sechailer/mask = allocate(/obj/item/clothing/mask/gas/sechailer)
	TEST_ASSERT(host.equip_to_slot_if_possible(mask, ITEM_SLOT_MASK, disable_warning = TRUE), "The real hailer mask could not be equipped.")
	var/datum/status_effect/replace_sound/foreign_sound = host.apply_status_effect(/datum/status_effect/replace_sound, 1 MINUTES, list("gasp" = 'sound/misc/moist_impact.ogg'))
	TEST_ASSERT_NOTNULL(foreign_sound, "The foreign native sound-replacement status was rejected.")
	var/datum/emote/deathgasp = GLOB.emote_list["deathgasp"][1]
	var/datum/emote/gasp = GLOB.emote_list["gasp"][1]
	var/datum/disease/paradise_zombie/infection = new
	TEST_ASSERT(host.ForceContractDisease(infection, make_copy = FALSE, del_on_fail = TRUE), "The early audio fixture could not contract the real plague.")
	// Exercise the component's maturity boundary while the ordinary infection is still at its first stage.
	host.LoadComponent(/datum/component/paradise_zombie_regen)
	TEST_ASSERT(!HAS_TRAIT(host, TRAIT_PARADISE_ZOMBIE), "The first-stage fixture unexpectedly matured.")
	TEST_ASSERT(check_steps(host, GLOB.barefootstep[FOOTSTEP_HARD_BAREFOOT][1], "immature"), "An immature infection changed native footsteps.")
	TEST_ASSERT_EQUAL(deathgasp.get_sound(host), 'sound/items/sec_hailer/sec_death.ogg', "An immature infection replaced its real mask voice.")
	TEST_ASSERT_EQUAL(gasp.get_sound(host), 'sound/misc/moist_impact.ogg', "An immature infection replaced a foreign sound status.")
	host.death_sound = 'sound/mobs/humanoids/human/scream/malescream_1.ogg'
	infection.stage = 8
	infection.process_infection_cycle()
	TEST_ASSERT(check_steps(host, /datum/component/paradise_zombie_regen::ordinary_footsteps, "mature"), "Actual maturation did not replace footsteps.")
	TEST_ASSERT(check_cries(host, /datum/component/paradise_zombie_regen::ordinary_cries, "mature with foreign listeners", check_silent_death = FALSE), "Actual maturation did not override the foreign voice listeners.")
	infection.cure()
	TEST_ASSERT_NULL(host.GetComponent(/datum/component/paradise_zombie_regen), "Cure retained its audio-owning regeneration component.")
	TEST_ASSERT(check_steps(host, GLOB.barefootstep[FOOTSTEP_HARD_BAREFOOT][1], "cured"), "Cure retained a monster footstep.")
	TEST_ASSERT_EQUAL(host.wear_mask, mask, "Cure replaced the real voice mask.")
	TEST_ASSERT_EQUAL(host.get_organ_slot(ORGAN_SLOT_TONGUE), tongue, "Cure replaced the original voice organ.")
	TEST_ASSERT(!QDELETED(foreign_sound), "Cure removed another source's sound status.")
	TEST_ASSERT_EQUAL(deathgasp.get_sound(host), 'sound/items/sec_hailer/sec_death.ogg', "Cure did not restore the mask's native voice listener.")
	TEST_ASSERT_EQUAL(gasp.get_sound(host), 'sound/misc/moist_impact.ogg', "Cure did not restore the foreign sound status.")
	TEST_ASSERT(host.dropItemToGround(mask), "The cured fixture could not remove its hailer.")
	TEST_ASSERT_EQUAL(deathgasp.get_sound(host), 'sound/mobs/non-humanoids/hiss/hiss6.ogg', "Cure or mask removal erased the transplanted tongue's listener.")
	qdel(foreign_sound)
	var/list/human_gasps = gasp.sounds_by_mobtype[/mob/living/carbon/human]
	TEST_ASSERT(gasp.get_sound(host) in human_gasps[MALE], "Removing the foreign status did not restore the cured body's actual human sound bank.")

/** A body's voice stays behind during mind transfer, and non-player variants use the ordinary bank. */
/datum/unit_test/paradise_zombie_audio_body_variants
	parent_type = /datum/unit_test/paradise_zombie_audio_test

/datum/unit_test/paradise_zombie_audio_body_variants/Run()
	var/mob/living/carbon/human/host = make_mutant("hunter")
	TEST_ASSERT(prepare_audio_floor(host), "The physical audio fixture could not reserve its floor.")
	var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent, get_step(host, NORTH))
	host.mind.transfer_to(recipient)
	var/datum/paradise_zombie_form/form = get_paradise_zombie_form("hunter")
	TEST_ASSERT(check_steps(host, form.footstep_sounds, "abandoned Hunter"), "The monster's footfalls followed its transferred mind.")
	TEST_ASSERT(check_cries(host, form.cry_sounds, "abandoned Hunter"), "The monster's voice followed its transferred mind.")
	TEST_ASSERT(check_steps(recipient, GLOB.barefootstep[FOOTSTEP_HARD_BAREFOOT][1], "clean recipient"), "The clean recipient inherited monster footsteps.")
	TEST_ASSERT(recipient.emote("scream", intentional = TRUE), "The clean recipient lost its native scream.")
	var/datum/emote/scream = GLOB.emote_list["scream"][1]
	TEST_ASSERT(!(scream.get_sound(recipient) in form.cry_sounds), "The clean recipient inherited its mind's former monster voice.")
	var/mob/living/carbon/human/npc = allocate(/mob/living/basic/zombie/rotten/assistant, get_step(recipient, NORTH))
	TEST_ASSERT(HAS_TRAIT(npc, TRAIT_PARADISE_NPC_ZOMBIE), "The mapped NPC fixture lost its native variant.")
	TEST_ASSERT_NULL(npc.GetComponent(/datum/component/paradise_zombie_mutation), "The mapped NPC unexpectedly acquired a player mutation controller.")
	// Unlike /consistent, an ordinary mapped body takes a second to stand after its legs recover.
	var/standing_deadline = world.time + 3 SECONDS
	while(npc.body_position != STANDING_UP && world.time < standing_deadline)
		sleep(world.tick_lag)
	TEST_ASSERT(npc.body_position == STANDING_UP && (npc.mobility_flags & MOBILITY_MOVE) && npc.has_gravity(), "The mapped NPC did not finish its native stand-up before the running test.")
	TEST_ASSERT(check_steps(npc, /datum/component/paradise_zombie_regen::ordinary_footsteps, "mapped NPC"), "The controller-free mapped NPC retained human footsteps.")
	TEST_ASSERT(check_cries(npc, /datum/component/paradise_zombie_regen::ordinary_cries, "mapped NPC pain", intentional = FALSE, check_silent_death = FALSE), "The native NPC pain-emote route retained a human voice.")
	var/mob/living/carbon/human/servant = allocate(/mob/living/carbon/human/consistent, get_step(npc, NORTH))
	ADD_TRAIT(servant, TRAIT_PARADISE_PLAGUE_ZOMBIE, PARADISE_ZOMBIE_TRAIT)
	var/datum/disease/paradise_zombie/wizard/plague = new /datum/disease/paradise_zombie/wizard(/datum/disease/anxiety/paradise_plague, TRUE)
	TEST_ASSERT(servant.ForceContractDisease(plague, make_copy = FALSE, del_on_fail = TRUE), "The magic audio fixture could not contract its real wizard plague.")
	plague.process_infection_cycle()
	TEST_ASSERT_NULL(servant.GetComponent(/datum/component/paradise_zombie_mutation), "The wizard servant unexpectedly acquired an ordinary mutation controller.")
	TEST_ASSERT(check_steps(servant, /datum/component/paradise_zombie_regen::ordinary_footsteps, "wizard plague"), "The wizard plague retained human footsteps.")
	TEST_ASSERT(check_cries(servant, /datum/component/paradise_zombie_regen::ordinary_cries, "wizard plague"), "The wizard plague retained a human voice.")

#endif
