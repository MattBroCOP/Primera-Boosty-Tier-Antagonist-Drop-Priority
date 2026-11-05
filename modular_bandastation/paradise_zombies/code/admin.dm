ADMIN_VERB(paradise_zombie_control, R_ADMIN, "Управление зомби", "Заразить персонажа некротической чумой Paradise, превратить его в зомби, вылечить или удалить заражение.", ADMIN_CATEGORY_FUN)
	VERB_ARG_TYPED(target, VERB_ARG_TYPE_MOB, VERB_ARG_SOURCE_WORLD, /mob/living/carbon/human)
	var/operation = tgui_input_list(user, "Выберите действие для [target.declent_ru(GENITIVE)].", "Управление зомби", list("Заразить", "Превратить в зомби", "Вылечить", "Удалить заражение"))
	if(!operation || QDELETED(target) || !check_rights_for(user, R_ADMIN))
		return
	var/datum/disease/paradise_zombie/infection = locate() in target.diseases
	switch(operation)
		if("Заразить", "Превратить в зомби")
			if(!infection)
				infection = new
				infection.infect(target, FALSE)
			if(operation == "Превратить в зомби")
				infection.stage = 8
				infection.process_infection_cycle()
		if("Вылечить")
			if(infection)
				infection.cure()
		if("Удалить заражение")
			qdel(infection)
	message_admins("[key_name_admin(user)] применяет действие «[operation]» через управление зомби. Цель: [key_name_admin(target)].")
	log_admin("[key_name(user)] применяет действие «[operation]» через управление зомби. Цель: [key_name(target)].")
	BLACKBOX_LOG_ADMIN_VERB("Zombie Control")
