/// Keep existing buildup/species regressions deterministic while new tests cover every outcome.
/datum/component/cyberpsychosis/test_outcome
	/// Force one branch without changing the probabilities of the production component.
	var/test_outcome = "berserk"

/datum/component/cyberpsychosis/test_outcome/trigger_overload(outcome, forced = FALSE)
	return ..(test_outcome, forced)

/// All branches are reached through real installed burden and the production increment callback.
/datum/unit_test/cyberpsychosis_outcomes/Run()
	for(var/outcome in list("berserk", "possession", "explosion"))
		var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
		qdel(host.GetComponent(/datum/component/cyberpsychosis))
		var/datum/component/cyberpsychosis/test_outcome/load = host.AddComponent(/datum/component/cyberpsychosis/test_outcome)
		load.test_outcome = outcome
		for(var/index in 1 to 8)
			var/obj/item/implant/tracking/tracker = allocate(/obj/item/implant/tracking)
			tracker.allow_multiple = TRUE
			tracker.implant(host, silent = TRUE, force = TRUE)
		TEST_ASSERT_EQUAL(load.load, 16, "Fixture did not physically install sixteen points of burden.")
		load.buildup = 99
		load.stop_timer()
		load.advance_buildup()
		var/datum/status_effect/forced_combat/cyberpsychosis/episode = host.has_status_effect(/datum/status_effect/forced_combat/cyberpsychosis)
		if(outcome == "explosion")
			TEST_ASSERT_NULL(episode, "Explosion also started a berserk episode.")
			TEST_ASSERT(host.get_brute_loss() + host.get_fire_loss() > 0, "Explosion did not injure its unarmored host.")
			TEST_ASSERT_EQUAL(load.buildup, 0, "Explosion retained the old accumulation.")
			TEST_ASSERT_NOTNULL(load.buildup_timer, "Living overloaded survivor did not start a fresh interval.")
		else
			TEST_ASSERT_NOTNULL(episode, "[outcome] did not start an episode at 100.")
			TEST_ASSERT_EQUAL(episode.duration, 40 SECONDS, "Outcome changed the common episode duration.")
			TEST_ASSERT_EQUAL(istype(episode, /datum/status_effect/forced_combat/cyberpsychosis/possession), outcome == "possession", "Wrong episode type selected.")
			TEST_ASSERT_EQUAL(episode.uses_automatic_combat(), outcome == "berserk", "Lottery body attacked automatically.")
			TEST_ASSERT_NULL(load.buildup_timer, "Accumulation continued during an episode.")
			qdel(episode)
		qdel(host)

/// Forced admin outcomes bypass only burden/protection, not death or an already active episode.
/datum/unit_test/cyberpsychosis_admin/Run()
	TEST_ASSERT_EQUAL(GLOB.smites["Киберпсихоз"], /datum/smite/cyberpsychosis, "Cyberpsychosis was not registered in Smite.")
	var/datum/smite/cyberpsychosis/smite = allocate(/datum/smite/cyberpsychosis)
	for(var/protected in list(FALSE, TRUE))
		for(var/outcome in list("berserk", "possession", "explosion"))
			var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
			var/datum/component/cyberpsychosis/load = host.GetComponent(/datum/component/cyberpsychosis)
			if(protected)
				for(var/index in 1 to 8)
					var/obj/item/implant/tracking/tracker = allocate(/obj/item/implant/tracking)
					tracker.allow_multiple = TRUE
					tracker.implant(host, silent = TRUE, force = TRUE)
				var/obj/item/implant/cyberpsychopath/chip = allocate(/obj/item/implant/cyberpsychopath)
				chip.implant(host, silent = TRUE, force = TRUE)
				TEST_ASSERT(load.buildup_blocked && load.load > load.safe_load, "Protected fixture did not have overloaded hardware and Cyberpsychopath.")
			TEST_ASSERT(!smite.effect(null, host), "A caller without admin rights used Smite.")
			TEST_ASSERT(!load.trigger_overload(outcome), "Natural overload ignored safe burden or Cyberpsychopath.")
			TEST_ASSERT_NULL(host.has_status_effect(/datum/status_effect/forced_combat/cyberpsychosis), "Rejected invocation created an episode.")
			TEST_ASSERT_EQUAL(host.get_brute_loss() + host.get_fire_loss(), 0, "Rejected invocation damaged the host.")
			var/previous_load = load.load
			TEST_ASSERT(load.trigger_overload(outcome, forced = TRUE), "Forced [outcome] was blocked by burden/protection.")
			TEST_ASSERT_EQUAL(load.load, previous_load, "Admin invocation changed installed burden.")
			var/datum/status_effect/forced_combat/cyberpsychosis/episode = host.has_status_effect(/datum/status_effect/forced_combat/cyberpsychosis)
			if(outcome == "explosion")
				TEST_ASSERT_NULL(episode, "Admin explosion also started an episode.")
				TEST_ASSERT(host.stat != DEAD && host.get_brute_loss() + host.get_fire_loss() > 0, "Admin explosion did not hurt its healthy survivor.")
			else
				TEST_ASSERT_NOTNULL(episode, "Forced [outcome] failed to start.")
				TEST_ASSERT_EQUAL(episode.duration, 40 SECONDS, "Admin invocation changed the episode duration.")
				TEST_ASSERT_EQUAL(istype(episode, /datum/status_effect/forced_combat/cyberpsychosis/possession), outcome == "possession", "Wrong admin outcome applied.")
				TEST_ASSERT(!load.trigger_overload("explosion", forced = TRUE), "Admin invocation stacked over an existing episode.")
				TEST_ASSERT_EQUAL(host.get_brute_loss() + host.get_fire_loss(), 0, "Stacked invocation damaged the host.")
				qdel(episode)
			host.death()
			TEST_ASSERT(!load.trigger_overload("berserk", forced = TRUE), "Admin invocation started an episode on a corpse.")
			qdel(host)

/// Only the epicenter takes blast damage; even an unarmored host can survive the light blast.
/datum/unit_test/cyberpsychosis_explosion/Run()
	var/turf/epicenter = get_step(run_loc_floor_bottom_left, NORTHEAST)
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent, epicenter)
	var/mob/living/carbon/human/same_tile = allocate(/mob/living/carbon/human/consistent, epicenter)
	var/mob/living/carbon/human/neighbor = allocate(/mob/living/carbon/human/consistent, get_step(epicenter, EAST))
	var/datum/component/cyberpsychosis/load = host.GetComponent(/datum/component/cyberpsychosis)
	load.load = 16
	load.buildup = 100
	load.trigger_overload("explosion")
	sleep(1 SECONDS)
	TEST_ASSERT_EQUAL(host.get_brute_loss(), 50, "Unarmored host did not receive fifty brute damage.")
	TEST_ASSERT_EQUAL(host.get_fire_loss(), 50, "Unarmored host did not receive fifty burn damage.")
	TEST_ASSERT(same_tile.get_brute_loss() + same_tile.get_fire_loss() > 0, "Another mob on the epicenter was not hurt.")
	TEST_ASSERT_EQUAL(neighbor.get_brute_loss() + neighbor.get_fire_loss(), 0, "Explosion damaged the adjacent tile.")
	TEST_ASSERT(host.stat != DEAD && !QDELETED(host), "Healthy unarmored host could not survive the light blast.")

/// Empty/disabled ghost roles still wait ten real seconds, then use the remaining episode time.
/datum/unit_test/cyberpsychosis_lottery/Run()
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	var/datum/status_effect/forced_combat/cyberpsychosis/possession/episode = host.apply_status_effect(/datum/status_effect/forced_combat/cyberpsychosis/possession)
	TEST_ASSERT(episode.poll_pending && !episode.uses_automatic_combat(), "Lottery did not start in a passive waiting state.")
	TEST_ASSERT_EQUAL(episode.poll_ends_at, world.time + 10 SECONDS, "Lottery deadline is not ten seconds from onset.")
	TEST_ASSERT(!episode.finish_poll(null), "An early result ended the lottery.")
	sleep(11 SECONDS)
	TEST_ASSERT(!QDELETED(episode) && !episode.poll_pending && episode.uses_automatic_combat(), "No-candidate lottery did not fall back to berserk.")
	TEST_ASSERT(episode.duration < 31 SECONDS && episode.duration > 25 SECONDS, "Fallback reset or consumed the entire forty-second episode.")
	qdel(episode)
	TEST_ASSERT(!episode.finish_poll(null), "An expired lottery accepted a late result.")

/// Death and an EMP interruption invalidate outstanding polls without creating another seat.
/datum/unit_test/cyberpsychosis_lottery_interruptions/Run()
	for(var/by_death in list(FALSE, TRUE))
		var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
		var/datum/status_effect/forced_combat/cyberpsychosis/possession/episode = host.apply_status_effect(/datum/status_effect/forced_combat/cyberpsychosis/possession)
		var/mob/living/cyberpsychosis_backseat/seat = episode.backseat
		if(by_death)
			host.death()
			TEST_ASSERT(QDELETED(episode) && QDELETED(seat), "Death leaked the waiting episode/seat.")
		else
			TEST_ASSERT(episode.begin_emp_overload(), "EMP failed to interrupt the lottery.")
			TEST_ASSERT(episode.emp_overloaded && !episode.poll_pending && episode.uses_automatic_combat(), "EMP lottery stayed pending or controllable.")
			TEST_ASSERT_EQUAL(episode.backseat, seat, "EMP replaced the owner seat.")
			TEST_ASSERT_EQUAL(episode.duration, 40 SECONDS, "EMP interruption did not use its normal duration.")
			TEST_ASSERT(!episode.finish_poll(null), "EMP-locked episode accepted a late poll.")
			qdel(episode)

/// Mock clients exercise the real lease, key guards and cleanup without impersonating connected players.
/datum/unit_test/cyberpsychosis_possession_control/Run()
	for(var/ending in list("expiry", "death", "emp", "disconnect", "offline_key", "deleted_body", "brain_removed", "changed_mind"))
		var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
		host.mind_initialize()
		var/datum/mind/character = host.mind
		character.key = "@cyberpsychosis_owner"
		var/mob/dead/observer/volunteer = allocate(/mob/dead/observer)
		volunteer.key = "@cyberpsychosis_volunteer"
		var/datum/client_interface/mock = allocate(/datum/client_interface)
		volunteer.mock_client = mock
		mock.mob = volunteer
		var/datum/status_effect/forced_combat/cyberpsychosis/possession/episode = host.apply_status_effect(/datum/status_effect/forced_combat/cyberpsychosis/possession)
		var/mob/living/cyberpsychosis_backseat/seat = episode.backseat
		seat.mind = character
		seat.key = character.key
		episode.process(10)
		episode.poll_ends_at = world.time
		TEST_ASSERT(episode.finish_poll(volunteer), "[ending]: volunteer was not given control after the lottery.")
		var/datum/cyberpsychosis_possession/lease = episode.control_lease
		var/ghost_sound_channel = lease.sound_channel
		TEST_ASSERT(ghost_sound_channel && ghost_sound_channel != episode.sound_channel, "Volunteer did not get an independent sound channel.")
		TEST_ASSERT_EQUAL(SSsounds.using_channels[num2text(ghost_sound_channel)], lease, "Volunteer sound channel is not owned by its lease.")
		// Fake keys have no BYOND client to move these mock pointers automatically.
		volunteer.key = null
		volunteer.mock_client = null
		host.mock_client = mock
		mock.mob = host
		host.mind_initialize()
		TEST_ASSERT_EQUAL(host.mind, character, "[ending]: possession replaced the character's mind.")
		TEST_ASSERT_EQUAL(character.current, host, "[ending]: possession transferred character ownership.")
		TEST_ASSERT_EQUAL(character.key, "@cyberpsychosis_owner", "[ending]: Login stole the character's registered key.")
		TEST_ASSERT(!episode.uses_automatic_combat(), "[ending]: automatic combat fought the volunteer.")
		switch(ending)
			if("expiry")
				episode.process(30)
			if("death")
				host.death()
			if("emp")
				TEST_ASSERT(episode.begin_emp_overload(), "EMP did not revoke volunteer control.")
				TEST_ASSERT(QDELETED(lease), "EMP retained its volunteer lease.")
				TEST_ASSERT(episode.uses_automatic_combat(), "EMP failed to restore berserk attacks.")
				TEST_ASSERT_EQUAL(seat.key, "@cyberpsychosis_owner", "EMP returned the real owner before the locked episode ended.")
				episode.process(40)
			if("disconnect")
				host.mock_client = null
				episode.tick(0.5)
				TEST_ASSERT(QDELETED(lease) && episode.uses_automatic_combat(), "Disconnect did not fall back to berserk.")
				qdel(episode)
			if("offline_key")
				host.key = null
				host.mock_client = null
				lease.controller_client = null
				episode.tick(0.5)
				TEST_ASSERT(QDELETED(lease) && episode.uses_automatic_combat(), "Offline key did not fall back to berserk.")
				qdel(episode)
			if("deleted_body")
				qdel(host)
			if("brain_removed")
				var/obj/item/organ/brain/brain = host.get_organ_slot(ORGAN_SLOT_BRAIN)
				character.active = TRUE
				brain.Remove(host)
				allocated += brain
				TEST_ASSERT(QDELETED(episode) && QDELETED(lease), "Brain removal leaked the control episode/lease.")
				TEST_ASSERT_EQUAL(volunteer.key, "@cyberpsychosis_volunteer", "Brain removal stranded the volunteer in the old body.")
				TEST_ASSERT_EQUAL(brain.brainmob.mind, character, "Brain removal lost the original character.")
				TEST_ASSERT_EQUAL(character.key, "@cyberpsychosis_owner", "Brain removal changed the original registered player.")
				TEST_ASSERT(SSsounds.using_channels[num2text(ghost_sound_channel)] != lease, "Brain removal leaked the volunteer sound channel.")
				continue
			if("changed_mind")
				var/datum/mind/replacement = allocate(/datum/mind)
				replacement.set_current(host)
				character.set_current(null)
				host.mind = replacement
				qdel(episode)
				TEST_ASSERT_EQUAL(host.key, "@cyberpsychosis_volunteer", "Cleanup took a client after an unrelated mind change.")
				TEST_ASSERT(SSsounds.using_channels[num2text(ghost_sound_channel)] != lease, "Mind change leaked the volunteer sound channel.")
				continue
		TEST_ASSERT(QDELETED(episode) && QDELETED(seat), "[ending]: expiry/death leaked the effect or owner seat.")
		TEST_ASSERT(QDELETED(lease), "[ending]: cleanup leaked the volunteer lease.")
		TEST_ASSERT_NULL(lease.sound_channel, "[ending]: cleanup retained the volunteer's playback channel.")
		TEST_ASSERT(SSsounds.using_channels[num2text(ghost_sound_channel)] != lease, "[ending]: cleanup did not release the volunteer sound channel.")
		TEST_ASSERT_EQUAL(volunteer.key, "@cyberpsychosis_volunteer", "[ending]: volunteer did not return to their original observer.")
		if(!QDELETED(host))
			TEST_ASSERT_EQUAL(host.key, "@cyberpsychosis_owner", "[ending]: original owner did not regain the body.")
			TEST_ASSERT_EQUAL(host.mind, character, "[ending]: original character was lost on return.")
			TEST_ASSERT_EQUAL(character.key, "@cyberpsychosis_owner", "[ending]: cleanup lost the original registered key.")
			host.mock_client = null
		qdel(host)

/// The observer and the volunteer share the body's track selection and looping settings.
/datum/unit_test/cyberpsychosis_audio/Run()
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	var/datum/status_effect/forced_combat/cyberpsychosis/episode = host.apply_status_effect(/datum/status_effect/forced_combat/cyberpsychosis)
	for(var/gender in list(MALE, FEMALE))
		host.gender = gender
		var/expected_track = gender == FEMALE ? "modular_bandastation/cyberpsychosis/sound/edgerunner-fury-female.ogg" : "modular_bandastation/cyberpsychosis/sound/edgerunner-fury-male.ogg"
		var/sound/owner_audio = episode.get_ambience_sound()
		var/sound/ghost_audio = episode.get_ambience_sound(123)
		TEST_ASSERT_EQUAL("[ghost_audio.file]", expected_track, "Volunteer did not get the body's gender-specific track.")
		TEST_ASSERT_EQUAL("[owner_audio.file]", "[ghost_audio.file]", "The two listeners got different tracks.")
		TEST_ASSERT_EQUAL(owner_audio.channel, episode.sound_channel, "Owner track lost its original channel.")
		TEST_ASSERT_EQUAL(ghost_audio.channel, 123, "Volunteer track ignored its private channel.")
		TEST_ASSERT(ghost_audio.repeat && owner_audio.repeat, "Ambience is not looping for both recipients.")
		TEST_ASSERT_EQUAL(ghost_audio.volume, owner_audio.volume, "Ambience volume differs between recipients.")
	qdel(episode)
