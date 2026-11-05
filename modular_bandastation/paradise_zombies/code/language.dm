/// Paradise's seven-word zombie language, with its original sentence-level scrambling.
/datum/language/paradise_zombie
	name = "Язык зомби"
	desc = "Язык стонов зомби, жаждущих плоти. Мо-о-озги..."
	// Wormspeak already owns Paradise's original 'w' key in this build.
	key = null
	flags = LANGUAGE_TONGUELESS_SPEECH
	spans = list("zombie")
	syllables = list("Мозги", "Мозги-и-и", "Плоть", "Гр-р-р", "Хн-н-н", "Мо-о-озги", "Мо-озги-и-и")
	always_use_default_namelist = TRUE
	default_priority = 110
	icon_state = "aphasia"

/datum/language/paradise_zombie/scramble_paragraph(input, list/mutual_languages)
	if(mutual_languages?[type] >= 100)
		return input
	var/terminator = "..."
	if(!length(input))
		return "[pick(syllables)][terminator]"
	var/last_letter = copytext(input, length(input))
	if(last_letter in list("?", "!"))
		terminator = last_letter
	if(prob(90))
		return "[pick(syllables)][terminator]"
	return "[copytext_char(input, 1, min(7, length(input)))][terminator]"
