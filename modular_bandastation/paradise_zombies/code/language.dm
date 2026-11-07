/// Paradise's seven-word zombie language, with its original sentence-level scrambling.
/datum/language/paradise_zombie
	name = "Язык зомби"
	desc = "Язык стонов зомби, жаждущих плоти. Мо-о-озги..."
	// Wormspeak already owns Paradise's original 'w' key in this build.
	key = null
	flags = LANGUAGE_TONGUELESS_SPEECH | LANGUAGE_NO_UNIVERSAL_GRANT
	spans = list("zombie")
	syllables = list("Мозги", "Мозги-и-и", "Плоть", "Гр-р-р", "Хн-н-н", "Мо-о-озги", "Мо-озги-и-и")
	always_use_default_namelist = TRUE
	default_priority = 110
	icon_state = "aphasia"

/datum/language/paradise_zombie/scramble_paragraph(input, list/mutual_languages)
	// Listeners without a full language grant only hear groans.
	var/terminator = "..."
	var/last_letter = copytext_char(input, -1)
	if(last_letter in list("?", "!"))
		terminator = last_letter
	return "[pick(syllables)][terminator]"
