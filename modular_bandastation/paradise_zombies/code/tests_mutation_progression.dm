#ifdef UNIT_TESTS

/** Uses actual infected bodies and minds while isolating each test's outbreak clock and reservations. */
/datum/unit_test/paradise_zombie_mutation_progression
	parent_type = /datum/unit_test/paradise_zombie_mutation_test
	abstract_type = /datum/unit_test/paradise_zombie_mutation_progression

/datum/unit_test/paradise_zombie_mutation_progression/proc/make_progression_zombie(datum/paradise_zombie_mutation_progression/progression)
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	host.mind_initialize()
	var/datum/disease/paradise_zombie/infection = new()
	infection.infect(host, FALSE)
	progression.note_infection(host)
	infection.stage = 8
	infection.process_infection_cycle()
	progression.register_zombie(host)
	return host

/** Both elapsed time and the current transformed population must reach the unlock threshold. */
/datum/unit_test/paradise_zombie_mutation_progression/population/Run()
	var/datum/paradise_zombie_mutation_progression/progression = allocate(/datum/paradise_zombie_mutation_progression)
	var/mob/living/carbon/human/incubating = allocate(/mob/living/carbon/human/consistent)
	incubating.mind_initialize()
	var/datum/disease/paradise_zombie/early_infection = new()
	early_infection.infect(incubating, FALSE)
	TEST_ASSERT(progression.note_infection(incubating), "An ordinary incubation did not start the outbreak clock.")
	TEST_ASSERT(!progression.register_zombie(incubating), "An incubating human counted as a transformed zombie.")
	TEST_ASSERT(!progression.can_choose(incubating, "slasher"), "An ordinary infected human could select a new body before transforming.")
	var/mob/living/carbon/human/first = make_progression_zombie(progression)
	progression.first_infection_at = world.time - 2 MINUTES + 1
	TEST_ASSERT(!progression.can_choose(first, "slasher"), "Mutation became available before two minutes of ordinary infection.")
	progression.first_infection_at = world.time - 2 MINUTES
	TEST_ASSERT(progression.can_choose(first, "slasher"), "The first tier did not unlock at its elapsed-time boundary.")
	progression.first_infection_at = world.time - 20 MINUTES
	TEST_ASSERT(!progression.can_choose(first, "hunter"), "Elapsed time alone unlocked a form requiring a larger outbreak.")
	for(var/index in 1 to 3)
		make_progression_zombie(progression)
	progression.first_infection_at = world.time - 10 MINUTES + 1
	TEST_ASSERT(!progression.can_choose(first, "hunter"), "Four transformed minds bypassed the ten-minute threshold.")
	progression.first_infection_at = world.time - 10 MINUTES
	TEST_ASSERT(progression.can_choose(first, "hunter"), "Four transformed minds and ten minutes did not unlock tier two.")
	for(var/index in 1 to 4)
		make_progression_zombie(progression)
	progression.first_infection_at = world.time - 20 MINUTES
	TEST_ASSERT(progression.can_choose(first, "brute"), "Eight transformed minds and twenty minutes did not unlock the strongest form.")
	progression.register_zombie(first)
	progression.register_zombie(first)
	var/list/progress = progression.get_progress()
	TEST_ASSERT_EQUAL(progress["zombies"], 8, "Registering the same body twice inflated epidemic progression.")
	first.death()
	progress = progression.get_progress()
	TEST_ASSERT_EQUAL(progress["zombies"], 8, "A corpse which can resurrect disappeared from the current transformed population.")
	var/datum/disease/paradise_zombie/infection = locate() in first.diseases
	infection.cure()
	progress = progression.get_progress()
	TEST_ASSERT_EQUAL(progress["zombies"], 7, "A cured body continued advancing the epidemic.")
	TEST_ASSERT_EQUAL(progress["tier"], 2, "The strongest tier remained available after the current population fell below its threshold.")
	var/mob/living/carbon/human/plague = make_progression_zombie(progression)
	ADD_TRAIT(plague, TRAIT_PARADISE_PLAGUE_ZOMBIE, REF(src))
	progress = progression.get_progress()
	TEST_ASSERT_EQUAL(progress["zombies"], 7, "A wizard's plague body inflated the ordinary outbreak.")
	TEST_ASSERT(!progression.can_choose(plague, "slasher"), "A nonstandard plague zombie could select an ordinary mutation.")

/** Every special form shares a population cap, with a stricter subset for Brutes. */
/datum/unit_test/paradise_zombie_mutation_progression/shared_slots/Run()
	var/datum/paradise_zombie_mutation_progression/progression = allocate(/datum/paradise_zombie_mutation_progression)
	var/list/hosts = list()
	for(var/index in 1 to 8)
		hosts += make_progression_zombie(progression)
	progression.first_infection_at = world.time - 20 MINUTES
	var/mob/living/carbon/human/brute = hosts[1]
	var/mob/living/carbon/human/twitcher = hosts[2]
	var/mob/living/carbon/human/slasher = hosts[3]
	var/mob/living/carbon/human/candidate = hosts[4]
	TEST_ASSERT(progression.claim(brute, "brute") && progression.commit_choice(brute, "brute"), "An available Brute slot could not be claimed and committed.")
	TEST_ASSERT(!progression.claim(twitcher, "brute"), "A second Brute bypassed its stricter population subset.")
	TEST_ASSERT(progression.claim(twitcher, "twitcher") && progression.commit_choice(twitcher, "twitcher"), "The unoccupied shared special slot could not hold a tier-one mutation.")
	TEST_ASSERT(!progression.claim(candidate, "hunter"), "A different form bypassed the cap shared by all special mutations.")
	TEST_ASSERT(progression.claim(slasher, "slasher") && progression.commit_choice(slasher, "slasher"), "The ordinary Slasher incorrectly consumed a rare slot.")
	var/list/progress = progression.get_progress()
	TEST_ASSERT_EQUAL(progress["special_claimed"], 2, "A Slasher or a failed claim consumed a shared special slot.")
	TEST_ASSERT_EQUAL(progress["brute_claimed"], 1, "The rejected second Brute consumed its subset reservation.")
	var/datum/disease/paradise_zombie/infection = locate() in twitcher.diseases
	infection.cure()
	progress = progression.get_progress()
	TEST_ASSERT_EQUAL(progress["special_claimed"], 1, "Curing an infected body did not free its special reservation.")
	qdel(brute)
	progress = progression.get_progress()
	TEST_ASSERT_EQUAL(progress["special_claimed"], 0, "A deleted physical body retained a rare slot through a weak reference.")
	TEST_ASSERT_EQUAL(progress["brute_claimed"], 0, "Deleting a Brute failed to release its subset slot.")
	TEST_ASSERT(progression.can_choose(candidate, "hunter"), "Freed slots did not become available for a still-eligible form.")

/** Parking a special corpse by moving its mind cannot create extra rare bodies. */
/datum/unit_test/paradise_zombie_mutation_progression/parked_body/Run()
	var/datum/paradise_zombie_mutation_progression/progression = allocate(/datum/paradise_zombie_mutation_progression)
	var/mob/living/carbon/human/original = make_progression_zombie(progression)
	var/mob/living/carbon/human/recipient = make_progression_zombie(progression)
	make_progression_zombie(progression)
	make_progression_zombie(progression)
	progression.first_infection_at = world.time - 20 MINUTES
	TEST_ASSERT(progression.claim(original, "twitcher") && progression.commit_choice(original, "twitcher"), "The parking fixture could not take its initial special slot.")
	original.death()
	TEST_ASSERT(!progression.can_choose(recipient, "twitcher"), "Ordinary death released a special body which could rise again.")
	var/datum/mind/choosing_mind = original.mind
	choosing_mind.transfer_to(recipient)
	var/list/progress = progression.get_progress()
	TEST_ASSERT_EQUAL(progress["special_claimed"], 1, "Moving a mind freed the still-infected body's physical reservation.")
	TEST_ASSERT(!progression.claim(recipient, "twitcher"), "The same mind claimed a second special body while its original corpse remained parked.")
	var/datum/disease/paradise_zombie/infection = locate() in original.diseases
	infection.cure()
	TEST_ASSERT(progression.claim(recipient, "twitcher") && progression.commit_choice(recipient, "twitcher"), "The original fixed choice could not be reused after its old infected body was cured.")
	progression.release_body(recipient)
	TEST_ASSERT(!progression.claim(recipient, "slasher"), "Releasing a body reservation allowed its mind to change an already committed choice.")
	qdel(recipient)
	TEST_ASSERT(!(recipient in GLOB.current_living_antags), "A deleted infected body remained in the living antagonist list after its mind transferred.")

/** Failed application does not fix a choice, and a changed mind cannot commit someone else's reservation. */
/datum/unit_test/paradise_zombie_mutation_progression/commit_identity/Run()
	var/datum/paradise_zombie_mutation_progression/progression = allocate(/datum/paradise_zombie_mutation_progression)
	var/mob/living/carbon/human/host = make_progression_zombie(progression)
	progression.first_infection_at = world.time - 2 MINUTES
	TEST_ASSERT(!progression.claim(host, "not_a_mutation"), "A forged form ID was accepted as a mutation.")
	TEST_ASSERT(progression.claim(host, "twitcher"), "The initial pending reservation failed.")
	progression.release_body(host)
	TEST_ASSERT(progression.claim(host, "slasher"), "A rolled-back application permanently fixed the mind's choice.")
	progression.release_body(host)
	TEST_ASSERT(progression.claim(host, "twitcher"), "Rollback removed the mature body's population registration.")
	var/datum/mind/original_mind = host.mind
	var/mob/living/carbon/human/other_body = allocate(/mob/living/carbon/human/consistent)
	original_mind.transfer_to(other_body)
	host.mind_initialize()
	TEST_ASSERT(!progression.commit_choice(host, "twitcher"), "A replacement mind committed a reservation made by another character.")
	progression.release_body(host)
	original_mind.transfer_to(host)
	TEST_ASSERT(progression.claim(host, "slasher") && progression.commit_choice(host, "slasher"), "A failed identity check consumed the original mind's uncommitted choice.")
	progression.release_body(host)
	TEST_ASSERT(!progression.can_choose(host, "twitcher"), "A successfully committed choice was not retained by its mind.")

/** Map-spawned NPCs do not age the outbreak; an ordinary mature body can start it when a mind arrives. */
/datum/unit_test/paradise_zombie_mutation_progression/npc_clock/Run()
	var/datum/paradise_zombie_mutation_progression/progression = allocate(/datum/paradise_zombie_mutation_progression)
	var/mob/living/carbon/human/npc = allocate(/mob/living/carbon/human/consistent)
	npc.mind_initialize()
	ADD_TRAIT(npc, TRAIT_PARADISE_NPC_ZOMBIE, REF(src))
	var/datum/disease/paradise_zombie/npc_infection = new()
	npc_infection.infect(npc, FALSE)
	TEST_ASSERT(!progression.note_infection(npc), "A prepared NPC started the player outbreak clock.")
	npc_infection.stage = 8
	npc_infection.process_infection_cycle()
	TEST_ASSERT(progression.register_zombie(npc), "The NPC clock exclusion incorrectly removed an ordinary infected body from registration.")
	TEST_ASSERT(isnull(progression.first_infection_at), "Registering an NPC started the player outbreak clock.")
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	var/datum/disease/paradise_zombie/infection = new()
	infection.infect(host, FALSE)
	infection.stage = 8
	infection.process_infection_cycle()
	TEST_ASSERT(progression.register_zombie(host), "A mature mindless body could not be registered.")
	TEST_ASSERT(isnull(progression.first_infection_at), "Registering a mindless mature body fabricated a player outbreak.")
	host.mind_initialize()
	TEST_ASSERT(progression.register_zombie(host), "A mature body could not be registered after gaining a mind.")
	TEST_ASSERT_EQUAL(progression.first_infection_at, world.time, "A current ordinary mind did not start the missing outbreak clock on registration.")
	progression.first_infection_at = 0
	progression.note_infection(host)
	TEST_ASSERT_EQUAL(progression.first_infection_at, 0, "A valid outbreak timestamp at world.time zero was reset as though it were uninitialized.")

/** A real mapped zombie corpse must not age the global outbreak before any ordinary mind is infected. */
/datum/unit_test/paradise_zombie_mutation_progression/mapped_corpse_clock/Run()
	var/obj/effect/mob_spawn/corpse/human/zombie/spawner = allocate(/obj/effect/mob_spawn/corpse/human/zombie, run_loc_floor_bottom_left, TRUE)
	var/mob/living/carbon/human/corpse = spawner.create()
	TEST_ASSERT_NOTNULL(corpse, "The real map spawner did not create its zombie corpse.")
	allocated |= corpse
	TEST_ASSERT_NULL(corpse.mind, "The unoccupied map corpse unexpectedly acquired a mind.")
	TEST_ASSERT(HAS_TRAIT(corpse, TRAIT_PARADISE_ZOMBIE), "The mapped corpse did not run its real species-driven infection.")
	TEST_ASSERT(isnull(GLOB.paradise_zombie_mutation_progression.first_infection_at), "An unoccupied mapped zombie corpse started the global outbreak clock.")
	var/mob/living/carbon/human/crewmember = allocate(/mob/living/carbon/human/consistent)
	crewmember.mind_initialize()
	var/datum/disease/paradise_zombie/infection = new()
	TEST_ASSERT(crewmember.ForceContractDisease(infection, make_copy = FALSE, del_on_fail = TRUE), "The ordinary crewmember could not contract the first real outbreak infection.")
	var/started_at = GLOB.paradise_zombie_mutation_progression.first_infection_at
	TEST_ASSERT_EQUAL(started_at, world.time, "The first infected ordinary mind did not start the global outbreak clock.")
	var/obj/item/organ/brain/brain = crewmember.get_organ_slot(ORGAN_SLOT_BRAIN)
	brain.Remove(crewmember)
	allocated |= brain
	TEST_ASSERT_EQUAL(GLOB.paradise_zombie_mutation_progression.first_infection_at, started_at, "Extracting an infected crewmember's brain reset the existing outbreak clock.")

#endif
