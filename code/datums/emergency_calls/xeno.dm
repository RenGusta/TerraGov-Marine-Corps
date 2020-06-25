/datum/emergency_call/xenomorphs
	name = "Xenomorphs"
	probability = 10
	auto_shuttle_launch = TRUE
	spawn_type = null


/datum/emergency_call/xenomorphs/print_backstory(mob/living/carbon/xenomorph/X)
	to_chat(X, "<B>You are Xenomorph from a distant hive.</b>")
	to_chat(X, "<B>You've been cruising in space for years until a new Queen reached out to you and took over the control of your shuttle.</b>")
	to_chat(X, "<B>Help the new Queen take over this sector. For the new Hive!</b>")


/datum/emergency_call/xenomorphs/spawn_items()
	var/turf/drop_spawn	= get_spawn_point(TRUE)
	if(istype(drop_spawn))
		new /obj/effect/alien/weeds/node(drop_spawn) //Drop some weeds for xeno plasma regen.


/datum/emergency_call/xenomorphs/create_member(datum/mind/M)
	. = ..()
	if(!.)
		return

	var/mob/original = M.current
	var/turf/spawn_loc = .

	if(!leader)
		. = new /mob/living/carbon/xenomorph/ravager(spawn_loc)
		leader = .
		M.transfer_to(., TRUE)
		print_backstory(.)
		return

	if(prob(35))
		. = new /mob/living/carbon/xenomorph/drone/elder(spawn_loc)
		M.transfer_to(., TRUE)
		print_backstory(.)
		return

	if(prob(35))
		. = new /mob/living/carbon/xenomorph/spitter/mature(spawn_loc)
		M.transfer_to(., TRUE)
		print_backstory(.)
		return

	. = new /mob/living/carbon/xenomorph/hunter/mature(spawn_loc)
	M.transfer_to(., TRUE)
	print_backstory(.)

	if(original)
		qdel(original)