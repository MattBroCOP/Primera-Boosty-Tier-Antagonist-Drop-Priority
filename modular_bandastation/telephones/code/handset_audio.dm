#define PHONE_AUDIO_MAX_AGE (2 SECONDS)
#define PHONE_AUDIO_MAX_VOLUME 50

/// Receives the already selected clip after it reaches the holder's sound output.
/obj/item/telephone/proc/on_sound_heard(mob/living/source, turf/sound_origin, sound/heard_sound, audible_description)
	SIGNAL_HANDLER
	if(source != holder || loc != holder || !raised || HAS_TRAIT(src, TRAIT_WIELDED) || !isfile(heard_sound.file))
		return
	var/turf/microphone_turf = get_turf(src)
	if(!microphone_turf || !sound_origin || microphone_turf.z != sound_origin.z || get_dist(microphone_turf, sound_origin) > PHONE_MIC_RANGE)
		return
	if(!get_call_receiver())
		return
	// The native sound object is reused for later listeners, so take its playback values now.
	INVOKE_ASYNC(src, PROC_REF(relay_heard_sound), heard_sound.file, audible_description, min(heard_sound.volume, PHONE_AUDIO_MAX_VOLUME), heard_sound.frequency, heard_sound.pitch, heard_sound.offset, attached_to.call_sequence, world.time + PHONE_AUDIO_MAX_AGE)

/// Rejects stale clips when filtering finishes after the call was replaced.
/obj/item/telephone/proc/relay_heard_sound(clip, audible_description, volume, frequency, pitch, offset, call_sequence, deadline)
	var/filtered = filter_heard_sound(clip)
	if(QDELETED(src) || !isfile(filtered) || world.time > deadline || attached_to?.call_sequence != call_sequence)
		return
	var/obj/item/telephone/receiver = get_call_receiver()
	if(!receiver)
		return

	var/mob/living/primary_listener
	if(receiver.raised && receiver.attached_to.can_use_handset(receiver.holder))
		primary_listener = receiver.holder
	var/list/listeners = get_hearers_in_view(1, receiver)
	if(primary_listener)
		listeners |= primary_listener
	var/message = span_notice("Вы слышите [html_encode(audible_description)], исходящий из динамика трубки.")
	var/sound/replayed_sound = sound(filtered)
	replayed_sound.frequency = frequency
	replayed_sound.pitch = pitch
	replayed_sound.offset = offset
	for(var/mob/living/listener in listeners)
		var/listener_volume = listener == primary_listener ? volume : volume * 0.2
		if(listener_volume >= 0.1 && listener.show_message(message, MSG_AUDIBLE))
			listener.playsound_local(null, null, listener_volume, sound_to_use = replayed_sound)

/// Shares one conversion per resource across all calls, independently of the TTS provider.
/obj/item/telephone/proc/filter_heard_sound(clip)
	var/static/list/filtered_clips = list()
	var/clip_key = "[clip]"
	if(!clip_key)
		return null
	if(clip_key in filtered_clips)
		var/deadline = world.time + PHONE_AUDIO_MAX_AGE
		UNTIL(filtered_clips[clip_key] != TRUE || world.time >= deadline)
		return filtered_clips[clip_key]

	filtered_clips[clip_key] = TRUE
	// Export the compiled resource before passing only generated paths to the shell.
	var/file_key = md5(clip_key)
	var/input_path = "data/telephone-audio/[file_key].source"
	var/output_path = "data/telephone-audio/[file_key].ogg"
	var/converted = fcopy(clip, input_path) && apply_sound_effects(list(GET_SINGLETON(/datum/singleton/sound_effect/radio)), input_path, output_path)
	fdel(input_path)
	if(!converted)
		fdel(output_path)
	filtered_clips[clip_key] = converted ? file(output_path) : FALSE
	return filtered_clips[clip_key]

#undef PHONE_AUDIO_MAX_AGE
#undef PHONE_AUDIO_MAX_VOLUME
