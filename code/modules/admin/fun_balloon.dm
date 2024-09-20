/obj/effect/fun_balloon
	name = "fun balloon"
	desc = "This is going to be a laugh riot."
	icon = 'icons/obj/toy.dmi'
	icon_state = "syndballoon"
	anchored = TRUE
	var/popped = FALSE

/obj/effect/fun_balloon/Initialize(mapload)
	. = ..()
	SSobj.processing |= src

/obj/effect/fun_balloon/Destroy()
	SSobj.processing -= src
	. = ..()

/obj/effect/fun_balloon/process()
	if(!popped && check() && !QDELETED(src))
		popped = TRUE
		effect()
		pop()

/obj/effect/fun_balloon/proc/check()
	return FALSE

/obj/effect/fun_balloon/proc/effect()
	return

/obj/effect/fun_balloon/proc/pop()
	visible_message("[src] pops!")
	playsound(get_turf(src), 'sound/items/party_horn.ogg', 50, 1, -1)
	qdel(src)

//ATTACK GHOST IGNORING PARENT RETURN VALUE
/obj/effect/fun_balloon/attack_ghost(mob/user)
	if(!user.client || !user.client.holder || popped)
		return
	var/confirmation = tgui_alert(usr, "Pop [src]?","Fun Balloon",list("Yes","No"))
	if(confirmation == "Yes" && !popped)
		popped = TRUE
		effect()
		pop()

/obj/effect/fun_balloon/sentience
	name = "sentience fun balloon"
	desc = "When this pops, things are gonna get more aware around here."
	var/effect_range = 4
	var/group_name = "a zombie"

/obj/effect/fun_balloon/sentience/effect()
	var/list/bodies = list()
	for(var/mob/living/M in range(effect_range, get_turf(src)))
		bodies += M

	var/question = "Would you like to be [group_name]?"
	var/list/candidates = pollCandidatesForMobs(question, ROLE_PAI, null, FALSE, 100, bodies)
	while(LAZYLEN(candidates) && LAZYLEN(bodies))
		var/mob/dead/observer/C = pick_n_take(candidates)
		var/mob/living/body = pick_n_take(bodies)

		to_chat(body, "Your mob has been taken over by a ghost!")
		message_admins("[key_name_admin(C)] has taken control of ([key_name_admin(body)])")
		body.ghostize(0)
		body.key = C.key
		new /obj/effect/temp_visual/gravpush(get_turf(body))

/obj/effect/fun_balloon/sentience/emergency_shuttle
	name = "shuttle sentience fun balloon"
	var/trigger_time = 60

/obj/effect/fun_balloon/sentience/emergency_shuttle/check()
	. = FALSE
	if(SSshuttle.emergency && (SSshuttle.emergency.timeLeft() <= trigger_time) && (SSshuttle.emergency.mode == SHUTTLE_CALL))
		. = TRUE

/obj/effect/fun_balloon/scatter
	name = "scatter fun balloon"
	desc = "When this pops, you're not going to be around here anymore."
	var/effect_range = 5

/obj/effect/fun_balloon/scatter/effect()
	for(var/mob/living/M in range(effect_range, get_turf(src)))
		var/turf/T = find_safe_turf()
		new /obj/effect/temp_visual/gravpush(get_turf(M))
		M.forceMove(T)
		to_chat(M, span_notice("Pop!"))

/obj/effect/station_crash
	name = "station crash"
	desc = "With no survivors!"
	icon = 'icons/obj/toy.dmi'
	icon_state = "syndballoon"
	anchored = TRUE

/obj/effect/station_crash/Initialize(mapload)
	..()
	for(var/S in SSshuttle.stationary_docking_ports)
		var/obj/docking_port/stationary/SM = S
		if(SM.shuttle_id == "emergency_home")
			var/new_dir = turn(SM.dir, 180)
			SM.forceMove(get_ranged_target_turf(SM, new_dir, rand(3,15)))
			break
	return INITIALIZE_HINT_QDEL


//Arena

/obj/effect/forcefield/arena_shuttle
	name = "portal"
	initial_duration = 0
	var/list/warp_points = list()

/obj/effect/forcefield/arena_shuttle/Bumped(atom/movable/AM)
	if(!isliving(AM))
		return

	if(!warp_points.len)
		for(var/obj/effect/landmark/shuttle_arena_safe/S in GLOB.landmarks_list)
			warp_points |= S

	var/mob/living/L = AM
	if(L.pulling && istype(L.pulling, /obj/item/bodypart/head))
		to_chat(L, "Your offering is accepted. You may pass.")
		qdel(L.pulling)
		var/turf/LA = get_turf(pick(warp_points))
		L.forceMove(LA)
		L.remove_status_effect(/datum/status_effect/hallucination)
		to_chat(L, "<span class='reallybig redtext'>The battle is won. Your bloodlust subsides.</span>")
		for(var/obj/item/melee/chainsaw/doomslayer/chainsaw in L)
			qdel(chainsaw)
	else
		to_chat(L, "You are not yet worthy of passing. Drag a severed head to the barrier to be allowed entry to the hall of champions.")

/obj/effect/landmark/shuttle_arena_safe
	name = "hall of champions"
	desc = "For the winners."

/obj/effect/landmark/shuttle_arena_entrance
	name = "the arena"
	desc = "A lava filled battlefield."


/obj/effect/forcefield/arena_shuttle_entrance
	name = "portal"
	initial_duration = 0
	var/list/warp_points = list()

/obj/effect/forcefield/arena_shuttle_entrance/Bumped(atom/movable/AM)
	if(!isliving(AM))
		return

	if(!warp_points.len)
		for(var/obj/effect/landmark/shuttle_arena_entrance/S in GLOB.landmarks_list)
			warp_points |= S

	var/obj/effect/landmark/LA = pick(warp_points)
	var/mob/living/M = AM
	M.forceMove(get_turf(LA))
	to_chat(M, "<span class='reallybig redtext'>You're trapped in a deadly arena! To escape, you'll need to drag a severed head to the escape portals.</span>")
	spawn()
		var/obj/effect/mine/pickup/bloodbath/B = new (M)
		B.mineEffect(M)


/area/shuttle_arena
	name = "The Arena"
	has_gravity = STANDARD_GRAVITY
	requires_power = FALSE
	hidden = TRUE
	mood_bonus = 25
	mood_message = span_nicegreen("NO TIME TO THINK, JUST RIP AND TEAR!!/n")
