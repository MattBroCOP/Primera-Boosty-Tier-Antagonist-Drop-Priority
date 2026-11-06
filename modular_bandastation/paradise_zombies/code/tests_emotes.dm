#ifdef UNIT_TESTS

/// Real commands, catalog, saved favorites and body verbs share the same restriction.
/datum/unit_test/paradise_zombie_emote_restrictions
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test
	var/emotes_performed = 0
	var/last_message_override
	var/last_params

/datum/unit_test/paradise_zombie_emote_restrictions/proc/on_emote(mob/source, datum/emote/emote, act, type_override, message, intentional, message_override)
	SIGNAL_HANDLER
	emotes_performed++
	last_message_override = message_override

/datum/unit_test/paradise_zombie_emote_restrictions/proc/on_pre_emote(mob/source, key, params, type_override, intentional, datum/emote/emote)
	SIGNAL_HANDLER
	last_params = params

/datum/unit_test/paradise_zombie_emote_restrictions/Run()
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	host.mind_initialize()
	var/list/original_verbs = host.verbs.Copy()
	TEST_ASSERT(/mob/living/carbon/human/verb/emote_laugh in original_verbs, "The healthy fixture lacks its actual laughter verb.")
	TEST_ASSERT_NOTNULL(get_available_emote(host, "laugh"), "Healthy humans lost laughter before infection.")
	var/datum/disease/paradise_zombie/infection = new
	TEST_ASSERT(host.ForceContractDisease(infection, make_copy = FALSE, del_on_fail = TRUE), "The emote fixture could not contract the plague.")
	TEST_ASSERT_NOTNULL(get_available_emote(host, "laugh"), "An early infection restricted human emotes.")
	infection.stage = 8
	infection.process_infection_cycle()
	TEST_ASSERT(HAS_TRAIT(host, TRAIT_PARADISE_ZOMBIE), "The emote fixture never matured.")
	RegisterSignal(host, COMSIG_MOB_EMOTE, PROC_REF(on_emote))
	RegisterSignal(host, COMSIG_MOB_PRE_EMOTED, PROC_REF(on_pre_emote))
	for(var/key in list("laugh", "laughs", "clap", "flip", "dance", "moan", "gasp", "me"))
		TEST_ASSERT_NULL(get_available_emote(host, key), "The zombie panel still offers [key].")
		TEST_ASSERT(!host.emote(key, message = "test", intentional = TRUE, force_silence = TRUE), "A zombie executed forbidden [key].")
		TEST_ASSERT(!host.emote(key, message = "test", intentional = TRUE, forced = TRUE, force_silence = TRUE), "Forced execution bypassed the zombie restriction for [key].")
	TEST_ASSERT_EQUAL(emotes_performed, 0, "A denied emote reached its native effect dispatch.")
	var/datum/emote_panel/panel = allocate(/datum/emote_panel)
	var/list/data = panel.ui_static_data(host)
	var/list/keys = list()
	for(var/list/entry as anything in data["emotes"])
		keys += entry["key"]
	TEST_ASSERT_EQUAL(length(keys), 3, "The zombie catalog contains non-screaming emotes or lacks a scream variant.")
	for(var/key in list("scream", "screech", "roar"))
		TEST_ASSERT(key in keys, "The zombie catalog lost [key].")
	// Use the actual serialized preference values; module-local defines load after core unit tests.
	var/list/favorites = list("cry" = list("type" = 1, "key" = "scream"), "laugh" = list("type" = 1, "key" = "laugh"), "custom" = list("type" = 3, "message" = "waves"))
	var/saved_favorites = json_encode(favorites)
	var/list/available_favorites = get_available_emote_panel_entries(host, favorites)
	TEST_ASSERT_EQUAL(length(available_favorites), 1, "The zombie sidebar retains non-screaming favorites.")
	TEST_ASSERT("cry" in available_favorites, "The zombie sidebar lost its saved scream.")
	TEST_ASSERT_EQUAL(json_encode(favorites), saved_favorites, "Filtering mutated saved preferences.")
	for(var/procpath/verb_path as anything in host.verbs)
		if(verb_path.category == "Эмоции")
			TEST_ASSERT_EQUAL(verb_path, /mob/living/carbon/human/verb/emote_scream, "A forbidden emote remains in the verb menu.")
	TEST_ASSERT(host.emote("scream fake dance", intentional = TRUE, message_override = "waves"), "The zombie lost its actual scream command.")
	TEST_ASSERT_NULL(last_params, "Scream parameters bypassed the ban on custom emotes.")
	TEST_ASSERT_NULL(last_message_override, "A custom scream text bypassed the zombie policy.")
	TEST_ASSERT(host.emote("deathgasp"), "The restriction suppressed the native automatic death message.")
	TEST_ASSERT(!host.emote("moan", force_silence = TRUE), "Automatic non-screaming emotes escaped the policy.")
	TEST_ASSERT(prepare_range(host, offset = 8), "The emote fixture could not prepare a native body-transfer range.")
	for(var/support in 1 to 7)
		make_zombie(run_loc_floor_top_right)
	GLOB.paradise_zombie_mutation_progression.first_infection_at = world.time - 20 MINUTES
	var/datum/component/paradise_zombie_mutation/controller = host.GetComponent(/datum/component/paradise_zombie_mutation)
	TEST_ASSERT(controller.apply_form("hunter"), "The real controller could not prepare the evolved emote fixture.")
	TEST_ASSERT_NULL(get_available_emote(host, "laugh"), "Evolution restored forbidden emotions.")
	var/mob/living/carbon/human/recipient = allocate(/mob/living/carbon/human/consistent, get_step(host, NORTH))
	host.mind.transfer_to(recipient)
	TEST_ASSERT_NOTNULL(get_available_emote(recipient, "laugh"), "A healthy recipient inherited zombie emotions.")
	TEST_ASSERT_NULL(get_available_emote(host, "laugh"), "The abandoned zombie lost its body-owned emotion restriction.")
	infection.cure()
	TEST_ASSERT_NOTNULL(get_available_emote(host, "laugh"), "Cure failed to restore human emotions.")
	TEST_ASSERT_EQUAL(length(original_verbs - host.verbs), 0, "Cure failed to restore previously available verbs.")
	available_favorites = get_available_emote_panel_entries(host, favorites)
	TEST_ASSERT_EQUAL(length(available_favorites), 3, "Cure failed to restore hidden favorites.")
	TEST_ASSERT_EQUAL(json_encode(favorites), saved_favorites, "Cure changed saved emote preferences.")

#endif
