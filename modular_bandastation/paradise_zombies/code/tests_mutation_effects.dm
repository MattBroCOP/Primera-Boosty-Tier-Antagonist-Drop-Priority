#ifdef UNIT_TESTS

/** Echoes preserve visible DS13 flesh and detached attack artwork without changing the real body. */
/datum/unit_test/paradise_zombie_effect_lifetime/Run()
	var/mob/living/carbon/human/host = allocate(/mob/living/carbon/human/consistent)
	var/datum/component/paradise_zombie_mutation_body/body = host.AddComponent(/datum/component/paradise_zombie_mutation_body, "hunter")
	TEST_ASSERT_NOTNULL(body, "The FX fixture did not obtain its actual DS13 renderer.")
	var/atom/target = allocate(/obj/item, get_step(host, EAST))
	TEST_ASSERT(body.animate_melee(target, 1), "The FX fixture could not create its real detached attack arm.")
	host.alpha = 80
	host.invisibility = INVISIBILITY_OBSERVER
	var/matrix/original_transform = host.transform
	var/old_pixel_x = host.pixel_x
	var/old_pixel_y = host.pixel_y
	var/obj/effect/temp_visual/paradise_zombie_afterimage/echo = allocate(/obj/effect/temp_visual/paradise_zombie_afterimage, get_turf(host), host)
	TEST_ASSERT(!QDELETED(echo), "A visible mutation did not create an afterimage.")
	TEST_ASSERT(echo.alpha <= host.alpha, "A cosmetic echo made the source more opaque.")
	TEST_ASSERT_EQUAL(echo.invisibility, host.invisibility, "An echo revealed an invisible source.")
	TEST_ASSERT_EQUAL(length(echo.vis_contents), 0, "An echo shared live attached visuals with its source.")
	var/swing_found = FALSE
	var/flesh_found = FALSE
	for(var/mutable_appearance/part as anything in echo.overlays)
		if(part.icon == body.body_icon)
			flesh_found = TRUE
		if(part.icon == 'modular_bandastation/paradise_zombies/icons/mutations/hunter_swing.dmi')
			swing_found = TRUE
	TEST_ASSERT(flesh_found && swing_found, "The echo lost DS13 flesh or the detached swinging arm.")
	TEST_ASSERT_EQUAL(host.alpha, 80, "Creating an echo changed the real body's alpha.")
	TEST_ASSERT_EQUAL(host.transform.a, original_transform.a, "Creating an echo changed the real body's scale.")
	TEST_ASSERT_EQUAL(host.transform.e, original_transform.e, "Creating an echo changed the real body's height.")
	TEST_ASSERT_EQUAL(host.pixel_x, old_pixel_x, "Creating an echo moved the real body's horizontal anchor.")
	TEST_ASSERT_EQUAL(host.pixel_y, old_pixel_y, "Creating an echo moved the real body's vertical anchor.")
	var/mutable_appearance/export_appearance = new(echo.appearance)
	// Native fading already stores its destination alpha; icon exports need the visible starting frame.
	export_appearance.alpha = 80
	var/list/dimensions = get_icon_dimensions(body.body_icon)
	var/icon/canvas = icon('icons/blanks/32x32.dmi', "nothing")
	canvas.Scale(dimensions["width"], dimensions["height"])
	export_appearance.icon = canvas
	export_appearance.icon_state = "nothing"
	var/icon/snapshot = getFlatIcon(export_appearance, no_anim = TRUE)
	test_screenshot("hunter_afterimage", snapshot)
	var/obj/effect/temp_visual/paradise_zombie_wave/wave = allocate(/obj/effect/temp_visual/paradise_zombie_wave, get_turf(host))
	var/obj/effect/temp_visual/paradise_zombie_splash/splash = allocate(/obj/effect/temp_visual/paradise_zombie_splash, get_turf(host))
	TEST_ASSERT(!wave.density && !splash.density && !echo.density, "Cosmetic effects blocked the native path.")
	TEST_ASSERT(!wave.mouse_opacity && !splash.mouse_opacity && !echo.mouse_opacity, "Cosmetic effects intercepted clicks.")
	host.alpha = 0
	var/obj/effect/temp_visual/paradise_zombie_afterimage/hidden_echo = allocate(/obj/effect/temp_visual/paradise_zombie_afterimage, get_turf(host), host)
	TEST_ASSERT(QDELETED(hidden_echo), "A completely transparent actor left a visible trail.")
	var/deadline = world.time + 1 SECONDS
	UNTIL((QDELETED(echo) && QDELETED(wave) && QDELETED(splash)) || world.time >= deadline)
	TEST_ASSERT(QDELETED(echo) && QDELETED(wave) && QDELETED(splash), "Short cosmetic effects outlived their native timers.")

/** A real moving mutation produces a detached echo and cures remove all still-owned visuals. */
/datum/unit_test/paradise_zombie_effect_trail_cleanup
	parent_type = /datum/unit_test/paradise_zombie_mutation_ability_test

/datum/unit_test/paradise_zombie_effect_trail_cleanup/Run()
	var/mob/living/carbon/human/host = make_mutant("twitcher")
	TEST_ASSERT(prepare_range(host), "The FX flight fixture did not reserve a real range.")
	var/datum/action/cooldown/paradise_zombie_mutation/dash/action = locate() in host.actions
	TEST_ASSERT_NOTNULL(action, "The FX fixture did not receive its actual dash.")
	TEST_ASSERT(action.Trigger(host, target = locate(host.x + 12, host.y, host.z)), "The real dash refused the FX fixture.")
	var/obj/effect/temp_visual/paradise_zombie_afterimage/echo
	var/deadline = world.time + 3 SECONDS
	while(!echo && world.time < deadline)
		echo = locate() in action.owned_effects
		if(!echo)
			sleep(1)
	TEST_ASSERT_NOTNULL(echo, "The real collision-checked flight never produced a DS13 echo.")
	TEST_ASSERT_NOTEQUAL(echo.loc, host.loc, "The trail followed the caster instead of remaining on the previous turf.")
	var/list/owned = action.owned_effects.Copy()
	var/datum/disease/paradise_zombie/infection = locate() in host.diseases
	infection.cure()
	for(var/datum/effect as anything in owned)
		TEST_ASSERT(QDELETED(effect), "Cure retained a flight or cosmetic trail owned by the old form.")
	TEST_ASSERT(!host.throwing, "Adding a cosmetic trail broke native flight cancellation.")

#endif
