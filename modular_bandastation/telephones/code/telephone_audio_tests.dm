/// Stands in for FFmpeg while keeping the real microphone signal and call lifecycle.
/obj/item/telephone/audio_test
	abstract_type = /obj/item/telephone/audio_test
	var/last_captured_clip
	var/pause_filter = FALSE
	var/filter_waiting = FALSE

/obj/item/telephone/audio_test/filter_heard_sound(clip)
	last_captured_clip = clip
	if(pause_filter)
		filter_waiting = TRUE
		UNTIL(!pause_filter || QDELETED(src))
		if(QDELETED(src))
			return null
		filter_waiting = FALSE
	return 'sound/machines/ping.ogg'

/// Observes the message and audio boundaries without a network client.
/mob/living/carbon/human/consistent/telephone_audio_listener
	var/telephone_descriptions = 0
	var/list/telephone_clips = list()

/mob/living/carbon/human/consistent/telephone_audio_listener/show_message(msg, type, alt_msg, alt_type, avoid_highlighting = FALSE)
	if(type != MSG_AUDIBLE || !findtext(msg, "проверочный звон"))
		return ..()
	telephone_descriptions++
	return TRUE

/mob/living/carbon/human/consistent/telephone_audio_listener/playsound_local(turf/turf_source, soundin, vol as num, vary, frequency, falloff_exponent = SOUND_FALLOFF_EXPONENT, channel = 0, pressure_affected = TRUE, sound/sound_to_use, max_distance, falloff_distance = SOUND_DEFAULT_FALLOFF_DISTANCE, distance_multiplier = 1, use_reverb = TRUE, wait = FALSE, datum/preference/numeric/volume/volume_preference = null, min_volume = 5, audible_description)
	if(sound_to_use?.file != 'sound/machines/ping.ogg')
		return ..()
	telephone_clips += list(list("volume" = vol, "frequency" = sound_to_use.frequency, "pitch" = sound_to_use.pitch, "described" = telephone_descriptions > length(telephone_clips)))
	return TRUE

/// Only nearby sound reaches the open microphone, and the earpiece controls its audience and volume.
/datum/unit_test/telephone/environment_audio/Run()
	qdel(calling_phone.handset)
	var/obj/item/telephone/audio_test/sender = allocate(/obj/item/telephone/audio_test, calling_phone, calling_phone)
	calling_phone.handset = sender
	var/turf/caller_turf = get_turf(calling_user)
	var/turf/receiver_turf = locate(run_loc_floor_top_right.x, caller_turf.y, caller_turf.z)
	receiving_phone.forceMove(receiver_turf)
	var/mob/living/carbon/human/consistent/telephone_audio_listener/primary_listener = allocate(__IMPLIED_TYPE__, receiver_turf)
	var/mob/living/carbon/human/consistent/telephone_audio_listener/nearby = allocate(__IMPLIED_TYPE__, get_step(receiver_turf, NORTH))
	var/mob/living/carbon/human/consistent/telephone_audio_listener/distant = allocate(__IMPLIED_TYPE__, get_step(nearby, NORTH))
	TEST_ASSERT(calling_user.put_in_active_hand(sender), "The caller must hold the real microphone.")
	TEST_ASSERT(calling_phone.start_call(calling_user, receiving_phone.phone_id), "The audio fixture must start a real call.")
	TEST_ASSERT(primary_listener.put_in_hands(receiving_phone.handset), "The listener must lift the receiver.")
	TEST_ASSERT(receiving_phone.answer_call(), "The two handsets must connect before sampling sound.")

	var/turf/near_source = locate(caller_turf.x, caller_turf.y + 2, caller_turf.z)
	var/turf/far_source = get_step(near_source, NORTH)
	var/sound/heard_sound = sound('sound/machines/click.ogg', volume = 80)
	heard_sound.frequency = 42000
	heard_sound.pitch = 1.1
	var/description = "проверочный звон"
	SEND_SIGNAL(calling_user, COMSIG_MOB_HEARD_SOUND, far_source, heard_sound, description)
	TEST_ASSERT_NULL(sender.last_captured_clip, "A sound three tiles away must not reach the microphone.")
	sender.attack_self_secondary(calling_user)
	TEST_ASSERT(HAS_TRAIT(sender, TRAIT_WIELDED), "Covering must use the real second hand.")
	SEND_SIGNAL(calling_user, COMSIG_MOB_HEARD_SOUND, near_source, heard_sound, description)
	TEST_ASSERT_NULL(sender.last_captured_clip, "A covered microphone must not capture nearby sounds.")
	sender.attack_self_secondary(calling_user)
	SEND_SIGNAL(calling_user, COMSIG_MOB_HEARD_SOUND, near_source, heard_sound, description)
	TEST_ASSERT_EQUAL(sender.last_captured_clip, heard_sound.file, "The microphone must filter the clip the caller actually heard.")
	TEST_ASSERT_EQUAL(length(primary_listener.telephone_clips), 1, "The raised receiver's holder must hear the sound exactly once.")
	TEST_ASSERT_EQUAL(length(nearby.telephone_clips), 1, "An adjacent bystander must hear the earpiece.")
	TEST_ASSERT_EQUAL(length(distant.telephone_clips), 0, "A bystander two tiles away must not hear the earpiece.")
	var/list/primary_clip = primary_listener.telephone_clips[1]
	var/list/nearby_clip = nearby.telephone_clips[1]
	TEST_ASSERT(primary_clip["described"] && nearby_clip["described"], "Each listener must receive the audible description before playback.")
	TEST_ASSERT_EQUAL(primary_clip["frequency"], heard_sound.frequency, "Playback must preserve the chosen frequency.")
	TEST_ASSERT_EQUAL(primary_clip["pitch"], heard_sound.pitch, "Playback must preserve the chosen pitch.")
	TEST_ASSERT_EQUAL(primary_clip["volume"], 50, "A loud sound must be capped for the holder.")
	TEST_ASSERT_EQUAL(nearby_clip["volume"], 10, "Earpiece leakage must play at one fifth of the holder's volume.")

	TEST_ASSERT(primary_listener.dropItemToGround(receiving_phone.handset), "The receiver must be able to remain connected on the floor.")
	SEND_SIGNAL(calling_user, COMSIG_MOB_HEARD_SOUND, near_source, heard_sound, description)
	TEST_ASSERT_EQUAL(length(primary_listener.telephone_clips), 2, "The former holder must still hear the nearby floor receiver.")
	TEST_ASSERT_EQUAL(length(nearby.telephone_clips), 2, "The adjacent bystander must still hear the floor receiver.")
	TEST_ASSERT_EQUAL(length(distant.telephone_clips), 0, "Putting the receiver down must not extend the sound's audience.")
	var/list/floor_clip = primary_listener.telephone_clips[2]
	TEST_ASSERT_EQUAL(floor_clip["volume"], 10, "A floor receiver must no longer have a full-volume listener.")

	// Finish before the audio age limit so the old clip can only be rejected because its call changed.
	var/deadline = world.time + 1 SECONDS
	sender.pause_filter = TRUE
	SEND_SIGNAL(calling_user, COMSIG_MOB_HEARD_SOUND, near_source, heard_sound, description)
	TEST_ASSERT(sender.filter_waiting, "The old call must have an audio conversion in progress.")
	receiving_phone.recall_phone()
	TEST_ASSERT(calling_phone.start_call(calling_user, receiving_phone.phone_id), "The same pair must be able to start a new call.")
	TEST_ASSERT(primary_listener.put_in_hands(receiving_phone.handset), "The recipient must lift the receiver again.")
	TEST_ASSERT(receiving_phone.answer_call(), "The new call must connect before the old clip is ready.")
	sender.pause_filter = FALSE
	UNTIL(!sender.filter_waiting || world.time >= deadline)
	TEST_ASSERT(!sender.filter_waiting && world.time <= deadline, "The filter must finish before the old clip expires.")
	TEST_ASSERT_EQUAL(length(primary_listener.telephone_clips), 2, "Audio captured during an earlier call must not play in the new call.")
