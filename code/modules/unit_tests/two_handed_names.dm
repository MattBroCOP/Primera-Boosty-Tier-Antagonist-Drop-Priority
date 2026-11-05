/// Native wielding localizes both hand tooltips while preserving source keys and player renames.
/datum/unit_test/two_handed_names/Run()
	var/mob/living/carbon/human/consistent/user = allocate(__IMPLIED_TYPE__)
	var/obj/item/fireaxe/axe = allocate(__IMPLIED_TYPE__)
	var/original_name = axe.name
	var/localized_name = axe.declent_ru(NOMINATIVE)
	TEST_ASSERT_EQUAL(localized_name, "пожарный топор", "The generic two-handed fixture did not load its existing name translation.")
	TEST_ASSERT_EQUAL(axe.get_tip_name(), localized_name, "An ordinary item's tooltip did not use its translated name.")
	TEST_ASSERT(user.put_in_hands(axe), "The generic axe fixture could not enter its user's hand.")
	var/datum/component/two_handed/grip = axe.GetComponent(/datum/component/two_handed)
	TEST_ASSERT_NOTNULL(grip, "The generic axe did not retain its native two-handed component.")
	axe.attack_self(user)
	TEST_ASSERT(grip.wielded && HAS_TRAIT(axe, TRAIT_WIELDED), "The native self-interaction did not wield the axe.")
	TEST_ASSERT_EQUAL(axe.get_tip_name(), "[localized_name] (двуручный хват)", "Wielding exposed an untranslated primary-hand tooltip.")
	var/obj/item/offhand/offhand = grip.offhand_item
	TEST_ASSERT_NOTNULL(offhand, "Wielding no longer created its native reserved hand.")
	TEST_ASSERT_EQUAL(user.get_item_for_held_index(grip.offhand_index), offhand, "The renamed offhand did not reserve its native slot.")
	TEST_ASSERT_EQUAL(offhand.get_tip_name(), "[localized_name] — вторая рука", "The reserved hand did not receive the translated item name.")
	TEST_ASSERT(!user.swap_hand(grip.offhand_index, silent = TRUE), "The renamed reserved hand could be activated as an ordinary free hand.")
	axe.attack_self(user)
	TEST_ASSERT(!grip.wielded && QDELETED(offhand), "Unwielding retained its old reserved hand.")
	TEST_ASSERT_EQUAL(axe.name, original_name, "Unwielding replaced the original raw name and its translation source key.")
	TEST_ASSERT_EQUAL(axe.get_tip_name(), localized_name, "Unwielding lost the existing name translation.")
	TEST_ASSERT_EQUAL(length(user.get_held_items()), 1, "Unwielding left a phantom hand reservation.")

	// Renames before wielding retain their exact text instead of reverting to the dictionary name.
	axe.name = "Player's custom axe"
	axe.attack_self(user)
	TEST_ASSERT_EQUAL(axe.get_tip_name(), "Player's custom axe (двуручный хват)", "Wielding overwrote a player's existing custom name.")
	offhand = grip.offhand_item
	TEST_ASSERT_EQUAL(offhand.get_tip_name(), "Player's custom axe — вторая рука", "The reserved hand ignored the player's custom item name.")
	axe.attack_self(user)
	TEST_ASSERT_EQUAL(axe.name, "Player's custom axe", "Unwielding erased a name chosen before the grip began.")
	TEST_ASSERT(QDELETED(offhand), "The custom-named axe leaked its reserved hand.")

	// An external rename during the grip is newer than the component's temporary label.
	axe.attack_self(user)
	TEST_ASSERT(grip.wielded, "The generic axe could not wield again after its first rename.")
	axe.name = "Новое имя во время хвата"
	offhand = grip.offhand_item
	axe.attack_self(user)
	TEST_ASSERT_EQUAL(axe.name, "Новое имя во время хвата", "Unwielding overwrote a newer rename made during the grip.")
	TEST_ASSERT_EQUAL(axe.get_tip_name(), axe.name, "The tooltip fell back to the old dictionary name after a newer rename.")
	TEST_ASSERT(!grip.wielded && QDELETED(offhand) && length(user.get_held_items()) == 1, "Renaming during a grip changed native hand cleanup.")
