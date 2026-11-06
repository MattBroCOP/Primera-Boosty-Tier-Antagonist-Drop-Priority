#ifdef UNIT_TESTS

/// Build actual screen buttons so inherited resource/state mistakes and extra frames cannot hide in previews.
/datum/unit_test/paradise_zombie_action_icons/Run()
	var/list/expected = list(
		/datum/action/cooldown/paradise_zombie_claws = "claws",
		/datum/action/cooldown/paradise_zombie_claws/plague = "claws",
		/datum/action/cooldown/paradise_zombie_mutation/tongue = "tongue",
		/datum/action/cooldown/paradise_zombie_mutation/dash = "dash",
		/datum/action/cooldown/paradise_zombie_mutation/dash/charge = "charge",
		/datum/action/cooldown/paradise_zombie_mutation/dash/pounce = "pounce",
		/datum/action/cooldown/paradise_zombie_mutation/dash/pounce/pin = "pin",
		/datum/action/cooldown/paradise_zombie_mutation/tear_wall = "tear_wall",
		/datum/action/cooldown/paradise_zombie_mutation/bile = "bile",
		/datum/action/cooldown/paradise_zombie_mutation/bile/acid = "acid",
		/datum/action/cooldown/paradise_zombie_mutation/explode = "explode",
		/datum/action/cooldown/paradise_zombie_mutation/vomit_bile = "vomit",
	)
	TEST_ASSERT_EQUAL(length(icon_states('modular_bandastation/paradise_zombies/icons/abilities.dmi')), 11, "The shared resource lost a frame or acquired an unintended state.")
	for(var/action_type in expected)
		var/datum/action/action = allocate(action_type)
		TEST_ASSERT_EQUAL(action.button_icon, 'modular_bandastation/paradise_zombies/icons/abilities.dmi', "[action_type] retained its old resource.")
		TEST_ASSERT_EQUAL(action.button_icon_state, expected[action_type], "[action_type] selects another skill's artwork.")
		TEST_ASSERT_NULL(action.background_icon_state, "[action_type] adds another background behind its framed icon.")
		TEST_ASSERT(icon_exists(action.button_icon, action.button_icon_state), "[action_type] selects a missing icon state.")
		var/atom/movable/screen/movable/action_button/button = allocate(/atom/movable/screen/movable/action_button)
		button.linked_action = action
		action.build_button_icon(button, UPDATE_BUTTON_BACKGROUND|UPDATE_BUTTON_ICON|UPDATE_BUTTON_OVERLAY, force = TRUE)
		TEST_ASSERT_EQUAL(button.icon_state, expected[action_type], "The native renderer changed the requested button state.")
		TEST_ASSERT_EQUAL(length(button.underlays), 0, "The native renderer added a duplicate frame.")
		var/icon/rendered = getFlatIcon(button, no_anim = TRUE)
		TEST_ASSERT_EQUAL(rendered.Width(), 32, "[action_type] does not render at native button width.")
		TEST_ASSERT_EQUAL(rendered.Height(), 32, "[action_type] does not render at native button height.")
		fcopy(rendered, "data/zombie-button-[action.button_icon_state].png")

#endif
