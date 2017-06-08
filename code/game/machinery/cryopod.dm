/*
 * Cryogenic refrigeration unit. Basically a despawner.
 * Stealing a lot of concepts/code from sleepers due to massive laziness.
 * The despawn tick will only fire if it's been more than time_till_despawned ticks
 * since time_entered, which is world.time when the occupant moves in.
 * ~ Zuhayr
 */

//Used for logging people entering cryosleep and important items they are carrying.
var/global/list/frozen_crew = list()
var/global/list/frozen_items = list()

//Main cryopod console.

/obj/machinery/computer/cryopod
	name = "cryogenic oversight console"
	desc = "An interface between crew and the cryogenic storage oversight systems."
	icon = 'icons/obj/Cryogenic2.dmi'
	icon_state = "cellconsole"
	circuit = "/obj/item/weapon/circuitboard/cryopodcontrol"
	var/mode = null

/obj/machinery/computer/cryopod/attack_paw()
	src.attack_hand()

/obj/machinery/computer/cryopod/attack_ai()
	src.attack_hand()

/obj/machinery/computer/cryopod/attack_hand(mob/user = usr)
	if(stat & (NOPOWER|BROKEN))
		return

	user.set_machine(src)
	src.add_fingerprint(usr)

	var/dat

	if (!( ticker ))
		return

	dat += "<hr/><br/><b>Cryogenic Oversight Control</b><br/>"
	dat += "<i>Welcome, [user.real_name].</i><br/><br/><hr/>"
	dat += "<a href='?src=\ref[src];log=1'>View storage log</a>.<br>"
	dat += "<a href='?src=\ref[src];view=1'>View objects</a>.<br>"
	dat += "<a href='?src=\ref[src];item=1'>Recover object</a>.<br>"
	dat += "<a href='?src=\ref[src];allitems=1'>Recover all objects</a>.<br>"

	user << browse(dat, "window=cryopod_console")
	onclose(user, "cryopod_console")

/obj/machinery/computer/cryopod/Topic(href, href_list)

	if(..())
		return

	var/mob/user = usr

	src.add_fingerprint(user)

	if(href_list["log"])

		var/dat = "<b>Recently stored crewmembers</b><br/><hr/><br/>"
		for(var/person in frozen_crew)
			dat += "[person]<br/>"
		dat += "<hr/>"

		user << browse(dat, "window=cryolog")

	if(href_list["view"])

		var/dat = "<b>Recently stored objects</b><br/><hr/><br/>"
		for(var/obj/item/I in frozen_items)
			dat += "[I.name]<br/>"
		dat += "<hr/>"

		user << browse(dat, "window=cryoitems")

	else if(href_list["item"])

		if(frozen_items.len == 0)
			user << "\blue There is nothing to recover from storage."
			return

		var/obj/item/I = input(usr, "Please choose which object to retrieve.","Object recovery",null) as null|anything in frozen_items
		if(!I)
			return

		if(!(I in frozen_items))
			user << "\blue \The [I] is no longer in storage."
			return

		visible_message("\blue The console beeps happily as it disgorges \the [I].", 3)

		I.loc = get_turf(src)
		frozen_items -= I

	else if(href_list["allitems"])

		if(frozen_items.len == 0)
			user << "\blue There is nothing to recover from storage."
			return

		visible_message("\blue The console beeps happily as it disgorges the desired objects.", 3)

		for(var/obj/item/I in frozen_items)
			I.loc = get_turf(src)
			frozen_items -= I

	src.updateUsrDialog()
	return

/obj/item/weapon/circuitboard/cryopodcontrol
	name = "Circuit board (Cryogenic Oversight Console)"
	build_path = "/obj/machinery/computer/cryopod"
	origin_tech = "programming=3"

//Decorative structures to go alongside cryopods.
/obj/structure/cryofeed

	name = "\improper cryogenic feed"
	desc = "A bewildering tangle of machinery and pipes."
	icon = 'icons/obj/Cryogenic2.dmi'
	icon_state = "cryo_rear"
	anchored = 1

	var/orient_right = null //Flips the sprite.

/obj/structure/cryofeed/right
	orient_right = 1
	icon_state = "cryo_rear-r"

/obj/structure/cryofeed/New()

	if(orient_right)
		icon_state = "cryo_rear-r"
	else
		icon_state = "cryo_rear"
	..()

//Cryopods themselves.
/obj/machinery/cryopod
	name = "\improper cryogenic freezer"
	desc = "A man-sized pod for entering suspended animation."
	icon = 'icons/obj/Cryogenic2.dmi'
	icon_state = "body_scanner_0"
	density = 1
	anchored = 1

	var/mob/living/occupant = null       // Person waiting to be despawned.
	var/orient_right = null       // Flips the sprite.
	var/time_till_despawn = 9000 // 15 minutes-ish safe period before being despawned.
	var/time_entered = 0          // Used to keep track of the safe period.
	var/obj/item/device/radio/intercom/announce //

/obj/machinery/cryopod/right
	orient_right = 1
	icon_state = "body_scanner_0-r"

/obj/machinery/cryopod/New()

	announce = new /obj/item/device/radio/intercom(src)

	if(orient_right)
		icon_state = "body_scanner_0-r"
	else
		icon_state = "body_scanner_0"
	..()

//Lifted from Unity stasis.dm and refactored. ~Zuhayr
/obj/machinery/cryopod/process()
	if(occupant)
		//Allow a ten minute gap between entering the pod and actually despawning.
		if(world.time - time_entered < time_till_despawn)
			return

		if(!occupant.client && occupant.stat<2) //Occupant is living and has no client.

			//Drop all items into the pod.
			for(var/obj/item/W in occupant)
				occupant.drop_inv_item_to_loc(W, src)

			//Delete all items not on the preservation list.
			var/list/items = src.contents
			items -= occupant // Don't delete the occupant
			items -= announce // or the autosay radio.

			for(var/obj/item/W in items)
				if(istype(W, /obj/item/weapon/card/id)) continue //don't keep id, to avoid abuse
				if(W.flags_inventory & CANTSTRIP) // we don't keep donor items
					if(istype(W, /obj/item/clothing/suit/storage))
						var/obj/item/clothing/suit/storage/SS = W
						for(var/obj/item/I in SS.pockets) //but we keep stuff inside them
							SS.pockets.remove_from_storage(I, loc)
							frozen_items += I
							I.loc = null
					if(istype(W, /obj/item/weapon/storage))
						var/obj/item/weapon/storage/S = W
						for(var/obj/item/I in S)
							S.remove_from_storage(I, loc)
							frozen_items += I
							I.loc = null
					continue
				frozen_items += W
				W.loc = null

			//Update any existing objectives involving this mob.
			for(var/datum/objective/O in all_objectives)
				// We don't want revs to get objectives that aren't for heads of staff. Letting
				// them win or lose based on cryo is silly so we remove the objective.
				if(istype(O,/datum/objective/mutiny) && O.target == occupant.mind)
					cdel(O)
				else if(O.target && istype(O.target,/datum/mind))
					if(O.target == occupant.mind)
						if(O.owner && O.owner.current)
							O.owner.current << "\red You get the feeling your target is no longer within your reach. Time for Plan [pick(list("A","B","C","D","X","Y","Z"))]..."
						O.target = null
						spawn(1) //This should ideally fire after the occupant is deleted.
							if(!O) return
							O.find_target()
							if(!(O.target))
								all_objectives -= O
								O.owner.objectives -= O
								cdel(O)

			if(occupant.mind && occupant.mind.assigned_squad)
				var/datum/squad/S = occupant.mind.assigned_squad
				if(!isnull(S) && istype(S))
					if(occupant.mind.assigned_role == "Squad Engineer") S.num_engineers--
					if(occupant.mind.assigned_role == "Squad Medic") S.num_medics--
					if(occupant.mind.assigned_role == "Squad Specialist") S.num_specialists--
					if(occupant.mind.assigned_role == "Squad Smartgunner") S.num_smartgun--
					if(occupant.mind.assigned_role == "Squad Leader")
						S.squad_leader = null
						S.num_leaders--
					S.count--
					occupant.mind.assigned_squad = null

			//Handle job slot/tater cleanup.
			if(occupant.mind)
				RoleAuthority.free_role(RoleAuthority.roles_for_mode[occupant.mind.assigned_role])

				if(occupant.mind.objectives.len)
					cdel(occupant.mind.objectives)
					occupant.mind.objectives = null
					occupant.mind.special_role = null

			//Delete them from datacore.
			if(PDA_Manifest.len)
				PDA_Manifest.Cut()
			for(var/datum/data/record/R in data_core.medical)
				if ((R.fields["name"] == occupant.real_name))
					data_core.medical -= R
					cdel(R)
			for(var/datum/data/record/T in data_core.security)
				if ((T.fields["name"] == occupant.real_name))
					data_core.security -= T
					cdel(T)
			for(var/datum/data/record/G in data_core.general)
				if ((G.fields["name"] == occupant.real_name))
					data_core.general -= G
					cdel(G)

			if(orient_right)
				icon_state = "body_scanner_0-r"
			else
				icon_state = "body_scanner_0"


			occupant.ghostize(0) //We want to make sure they are not kicked to lobby.
			//TODO: Check objectives/mode, update new targets if this mob is the target, spawn new antags?

			//Make an announcement and log the person entering storage.
			frozen_crew += "[occupant.real_name]"

			announce.autosay("[occupant.real_name] has entered long-term storage.", "Cryogenic Oversight")
			visible_message("\blue The crypod hums and hisses as it moves [occupant.real_name] into storage.", 3)

			// Delete the mob.

			cdel(occupant)
			occupant = null


	return


/obj/machinery/cryopod/attackby(obj/item/weapon/W, mob/user)

	if(istype(W, /obj/item/weapon/grab))
		var/obj/item/weapon/grab/G = W
		if(occupant)
			user << "<span class='warning'>The cryo pod is in use.</span>"
			return

		if(!ismob(G.grabbed_thing))
			return

		var/willing = null //We don't want to allow people to be forced into despawning.
		var/mob/M = G.grabbed_thing

		if(M.client)
			if(alert(M,"Would you like to enter cryosleep?",,"Yes","No") == "Yes")
				if(!M || !G || !G.grabbed_thing) return
				willing = 1
		else
			willing = 1

		if(willing)

			visible_message("<span class='notice'>[user] starts putting [M] into the cryo pod.</span>", 3)

			if(!do_after(user, 20, TRUE, 5, BUSY_ICON_CLOCK)) return
			if(!M || !G || !G.grabbed_thing) return
			M.forceMove(src)
			if(orient_right)
				icon_state = "body_scanner_1-r"
			else
				icon_state = "body_scanner_1"

			M << "<span class='notice'>You feel cool air surround you. You go numb as your senses turn inward.</span>"
			M << "\blue <b>If you ghost, log out or close your client now, your character will shortly be permanently removed from the round.</b>"
			occupant = M
			time_entered = world.time

			// Book keeping!
			var/turf/location = get_turf(src)
			log_admin("[key_name_admin(M)] has entered a stasis pod. (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[location.x];Y=[location.y];Z=[location.z]'>JMP</a>)")
			message_admins("\blue [key_name_admin(M)] has entered a stasis pod.")

			//Despawning occurs when process() is called with an occupant without a client.
			src.add_fingerprint(M)

/obj/machinery/cryopod/verb/eject()

	set name = "Eject Pod"
	set category = "Object"
	set src in oview(1)
	if(usr.stat != 0)
		return

	if(orient_right)
		icon_state = "body_scanner_0-r"
	else
		icon_state = "body_scanner_0"

	//Eject any items that aren't meant to be in the pod.
	var/list/items = src.contents
	if(occupant) items -= occupant
	if(announce) items -= announce

	for(var/obj/item/W in items)
		W.loc = get_turf(src)

	src.go_out()
	add_fingerprint(usr)
	return

/obj/machinery/cryopod/verb/move_inside()
	set name = "Enter Pod"
	set category = "Object"
	set src in oview(1)

	if(usr.stat != 0 || !(ishuman(usr) || ismonkey(usr)))
		return

	if(src.occupant)
		usr << "\blue <B>The cryo pod is in use.</B>"
		return

	visible_message("[usr] starts climbing into the cryo pod.", 3)

	if(do_after(usr, 20, FALSE, TRUE, 5, BUSY_ICON_CLOCK))

		if(!usr || !usr.client)
			return

		if(src.occupant)
			usr << "\blue <B>The cryo pod is in use.</B>"
			return

		usr.forceMove(src)
		occupant = usr

		if(orient_right)
			icon_state = "body_scanner_1-r"
		else
			icon_state = "body_scanner_1"

		usr << "\blue You feel cool air surround you. You go numb as your senses turn inward."
		usr << "\blue <b>If you ghost, log out or close your client now, your character will shortly be permanently removed from the round.</b>"
		time_entered = world.time

		src.add_fingerprint(usr)

	return

/obj/machinery/cryopod/proc/go_out()

	if(!occupant)
		return

	occupant.forceMove(get_turf(src))
	occupant = null

	if(orient_right)
		icon_state = "body_scanner_0-r"
	else
		icon_state = "body_scanner_0"
