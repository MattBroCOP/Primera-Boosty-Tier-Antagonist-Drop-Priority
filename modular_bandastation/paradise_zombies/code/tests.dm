/datum/unit_test/paradise_zombie_research_and_cure/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/disease/paradise_zombie/infection = new
	infection.infect(patient, FALSE)
	patient.reagents.add_reagent(/datum/reagent/medicine/paradise_zombie_cure/beta, 2)
	var/datum/disease/paradise_zombie/sample = infection.Copy()
	TEST_ASSERT_EQUAL(infection.cure_stage, 2, "Drawing a blood sample did not register Beta before the next disease cycle.")
	patient.reagents.clear_reagents()
	TEST_ASSERT_EQUAL(sample.cure_stage, 2, "A blood sample lost the strain's researched cure level.")
	qdel(sample)
	infection.stage = 3
	TEST_ASSERT(infection.has_cure(), "A previously Beta-treated stage three strain should remain treatable.")
	infection.stage = 5
	TEST_ASSERT(!infection.has_cure(), "Beta alone must not cure a stage five strain.")

/datum/unit_test/paradise_zombie_transformation_and_surgery/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/disease/paradise_zombie/infection = new
	infection.infect(patient, FALSE)
	infection.stage = 8
	infection.process_infection_cycle()
	TEST_ASSERT(HAS_TRAIT(patient, TRAIT_PARADISE_ZOMBIE), "Immediate zombification failed to transform the body.")
	var/obj/item/organ/paradise_zombie_tumor/tumor = patient.get_organ_slot(ORGAN_SLOT_ZOMBIE)
	TEST_ASSERT_NOTNULL(tumor, "Transformation did not grow the removable necrotic tumor.")
	allocated |= tumor
	var/mob/living/carbon/human/surgeon = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/hemostat/tool = allocate(/obj/item/hemostat)
	var/datum/surgery_operation/limb/organ_manipulation/operation = allocate(/datum/surgery_operation/limb/organ_manipulation)
	operation.on_success_remove_organ(patient.get_bodypart(BODY_ZONE_HEAD), surgeon, tumor, tool)
	TEST_ASSERT(!QDELETED(tumor) && tumor.loc == get_turf(patient), "Surgery tried to move an already destroyed tumor.")
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_PARADISE_ZOMBIE), "Removing the tumor did not reverse zombification.")
	TEST_ASSERT(!HAS_TRAIT(patient, TRAIT_NOBREATH), "Surgical cure left the body independent of breathing.")
	TEST_ASSERT_NULL(locate(/datum/disease/paradise_zombie) in patient.diseases, "Tumor extraction left the plague in the patient.")
	var/deadline = world.time + 1 SECONDS
	UNTIL(QDELETED(tumor) || world.time >= deadline)
	TEST_ASSERT(QDELETED(tumor), "The extracted tumor did not expire after surgery.")

/// Zombie speech follows the infected body until it is cured.
/datum/unit_test/paradise_zombie_language_and_transfer/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/mob/living/carbon/human/new_body = allocate(/mob/living/carbon/human/consistent)
	patient.mind_initialize()
	var/datum/disease/paradise_zombie/infection = new
	infection.infect(patient, FALSE)
	infection.stage = 8
	infection.process_infection_cycle()
	TEST_ASSERT(patient.can_speak_language(/datum/language/paradise_zombie), "The ordinary human tongue prevented zombie speech.")
	TEST_ASSERT(!patient.can_speak_language(/datum/language/common), "A zombie could still speak its old language.")
	var/datum/mind/mind = patient.mind
	patient.add_to_current_living_antags()
	TEST_ASSERT(patient in GLOB.current_living_antags, "The fixture was not registered as a living antagonist.")
	mind.transfer_to(new_body)
	TEST_ASSERT(!(patient in GLOB.current_living_antags), "Mind transfer left the abandoned body registered as a living antagonist.")
	TEST_ASSERT(!mind.has_antag_datum(/datum/antagonist/paradise_zombie), "The zombie antagonist crossed into an uninfected body.")
	TEST_ASSERT(new_body.can_speak_language(/datum/language/common), "Zombie language restrictions leaked into the new body.")
	TEST_ASSERT(!new_body.has_language(/datum/language/paradise_zombie), "Zombie language leaked into the new body.")
	TEST_ASSERT_EQUAL(patient.get_selected_language(), /datum/language/paradise_zombie, "The mindless zombie reverted to its old language.")
	TEST_ASSERT_NOTNULL(patient.GetComponent(/datum/component/paradise_zombie_combat), "Mind transfer removed the old body's infection-owned combat component.")
	patient.check_breath(null)
	TEST_ASSERT_EQUAL(patient.get_oxy_loss(), 0, "The abandoned infected body started suffocating after its mind left.")
	infection.cure()
	TEST_ASSERT_EQUAL(patient.get_selected_language(), /datum/language/common, "The cured body did not regain its original language.")
	TEST_ASSERT(!patient.has_language(/datum/language/paradise_zombie), "The cured body retained zombie language understanding.")

/// Ordinary ears hear the same groans in chat and in TTS, even with partial language knowledge.
/datum/unit_test/paradise_zombie_speech
	/// The translated speech received by the living listener.
	var/heard_message
	/// The text supplied to the voice synthesis handler for the same listener.
	var/tts_message

/datum/unit_test/paradise_zombie_speech/Run()
	var/mob/living/carbon/human/speaker = allocate(/mob/living/carbon/human/consistent, run_loc_floor_bottom_left)
	speaker.voice = null
	var/mob/living/carbon/human/listener = allocate(/mob/living/carbon/human/consistent/tts_listener, get_step(speaker, EAST))
	listener.mock_client = allocate(/datum/client_interface)
	var/obj/item/taperecorder/recorder = allocate(/obj/item/taperecorder, get_turf(speaker))
	recorder.become_hearing_sensitive()
	var/datum/disease/paradise_zombie/infection = new
	infection.infect(speaker, FALSE)
	infection.stage = 8
	infection.process_infection_cycle()
	listener.grant_partial_language(/datum/language/paradise_zombie, 100)
	RegisterSignal(listener, COMSIG_MOVABLE_HEAR, PROC_REF(on_hear))
	// TTS220's signal define is included after the core unit tests.
	RegisterSignal(speaker, "atom_tts_cast", PROC_REF(on_tts))
	speaker.say("Тайна?", ignore_spam = TRUE)
	TEST_ASSERT(endswith(heard_message, "?") && !findtext(heard_message, "Тайна"), "A living listener received intelligible zombie speech: [heard_message].")
	TEST_ASSERT_EQUAL(tts_message, heard_message, "TTS did not use the same scrambled message as chat.")
	TEST_ASSERT_EQUAL(speaker.translate_language(speaker, /datum/language/paradise_zombie, "Тайна?"), "Тайна?", "A zombie could not understand its own language.")
	TEST_ASSERT(length(recorder.mytape.storedinfo), "The recorder did not capture the speech fixture.")
	var/datum/tape_message/recording = recorder.mytape.storedinfo[1]
	TEST_ASSERT(endswith(recording.text, "?") && !findtext(recording.text, "Тайна"), "The tape recorder stored intelligible zombie speech.")

/datum/unit_test/paradise_zombie_speech/proc/on_hear(datum/source, list/hearing_args)
	SIGNAL_HANDLER
	heard_message = hearing_args[HEARING_RAW_MESSAGE]

/datum/unit_test/paradise_zombie_speech/proc/on_tts(datum/source, mob/listener, message)
	SIGNAL_HANDLER
	tts_message = message

/// Existing Romerol must contract the replacement plague, including its sticky medical discovery.
/datum/unit_test/paradise_zombie_romerol_and_medhud/Run()
	var/mob/living/carbon/human/patient = allocate(/mob/living/carbon/human/consistent)
	var/datum/reagent/romerol/romerol = allocate(/datum/reagent/romerol)
	romerol.expose_mob(patient, INJECT, 2)
	var/datum/disease/paradise_zombie/infection = locate() in patient.diseases
	TEST_ASSERT_NOTNULL(infection, "Romerol did not contract the replacement plague.")
	TEST_ASSERT(!patient.check_virus(), "Medical HUDs detected the early hidden infection.")
	infection.stage = 4
	infection.handle_stage_advance()
	TEST_ASSERT_EQUAL(patient.check_virus(), DISEASE_SEVERITY_BIOHAZARD, "A bite-strength infection stayed hidden until its minute timer elapsed.")
	infection.stage = 2
	TEST_ASSERT_EQUAL(patient.check_virus(), DISEASE_SEVERITY_BIOHAZARD, "A discovered strain became hidden again after partial treatment.")
	infection.cure()
	TEST_ASSERT(!patient.check_virus(), "Curing the plague left a disease marker on medical HUDs.")
