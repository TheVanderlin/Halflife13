SUBSYSTEM_DEF(events)
	name = "Events"
	init_order = INIT_ORDER_EVENTS
	runlevels = RUNLEVEL_GAME

	///list of all datum/round_event_control. Used for selecting events based on weight and occurrences.
	var/list/control = list()
	///list of all existing /datum/round_event currently being run.
	var/list/running = list()
	///cache of currently running events, for lag checking.
	var/list/currentrun = list()
	///The next world.time that a naturally occuring random event can be selected.
	var/scheduled = 0
	///The lower bound for how soon another random event can be scheduled.
	var/frequency_lower = 2.5 MINUTES
	///The upper bound for how soon another random event can be scheduled.
	var/frequency_upper = 9 MINUTES
	///Will wizard events be included in the event pool?
	var/wizardmode = FALSE

	//Yog code: we need to switch to Glob.holidays when possible
	var/list/holidays

/datum/controller/subsystem/events/Initialize(time, zlevel)
	for(var/type in typesof(/datum/round_event_control))
		var/datum/round_event_control/E = new type()
		if(!E.typepath)
			continue				//don't want this one! leave it for the garbage collector
		control += E				//add it to the list of all events (controls)
	reschedule()
	// Instantiate our holidays list if it hasn't been already
	if(isnull(GLOB.holidays))
		fill_holidays()
	return SS_INIT_SUCCESS


/datum/controller/subsystem/events/fire(resumed = 0)
	if(!resumed)
		checkEvent() //only check these if we aren't resuming a paused fire
		src.currentrun = running.Copy()

	//cache for sanic speed (lists are references anyways)
	var/list/currentrun = src.currentrun

	while(currentrun.len)
		var/datum/thing = currentrun[currentrun.len]
		currentrun.len--
		if(thing)
			thing.process(wait * 0.1)
		else
			running.Remove(thing)
		if (MC_TICK_CHECK)
			return

//checks if we should select a random event yet, and reschedules if necessary
/datum/controller/subsystem/events/proc/checkEvent()
	if(scheduled <= world.time)
		spawnEvent()
		reschedule()

//decides which world.time we should select another random event at.
/datum/controller/subsystem/events/proc/reschedule()
	scheduled = world.time + rand(frequency_lower, max(frequency_lower,frequency_upper))

//selects a random event based on whether it can occur and it's 'weight'(probability)
/datum/controller/subsystem/events/proc/spawnEvent()
	set waitfor = FALSE	//for the admin prompt
	if(!CONFIG_GET(flag/allow_random_events))
		return

	var/gamemode = SSticker.mode.config_tag
	var/players_amt = get_active_player_count(alive_check = 1, afk_check = 1, human_check = 1)
	// Only alive, non-AFK human players count towards this.

	var/sum_of_weights = 0
	for(var/datum/round_event_control/E in control)
		if(!E.canSpawnEvent(players_amt, gamemode))
			continue
		if(E.weight < 0)						//for round-start events etc.
			var/res = TriggerEvent(E)
			if(res == EVENT_INTERRUPTED)
				continue	//like it never happened
			if(res == EVENT_CANT_RUN)
				return
		sum_of_weights += E.weight

	sum_of_weights = rand(0,sum_of_weights)	//reusing this variable. It now represents the 'weight' we want to select

	for(var/datum/round_event_control/E in control)
		if(!E.canSpawnEvent(players_amt, gamemode))
			continue
		sum_of_weights -= E.weight

		if(sum_of_weights <= 0)				//we've hit our goal
			if(TriggerEvent(E))
				return

/datum/controller/subsystem/events/proc/TriggerEvent(datum/round_event_control/E)
	. = E.preRunEvent()
	if(. == EVENT_CANT_RUN)//we couldn't run this event for some reason, set its max_occurrences to 0
		E.max_occurrences = 00
	else if(. == EVENT_READY)
		E.random = TRUE
		E.runEvent()

//allows a client to trigger an event
//aka Badmin Central
// > Not in modules/admin
// REEEEEEEEE
/client/proc/forceEvent()
	set name = "Trigger Event"
	set category = "Admin.Round Interaction"

	if(!holder ||!check_rights(R_FUN))
		return

	holder.forceEvent()

/datum/admins/proc/forceEvent()
	var/dat 	= ""
	var/normal 	= ""
	var/magic 	= ""
	var/holiday = ""
	for(var/datum/round_event_control/E in SSevents.control)
		dat = "<BR><A href='?src=[REF(src)];[HrefToken()];forceevent=[REF(E)]'>[E]</A>"
		if(E.holidayID)
			holiday	+= dat
		else if(E.wizardevent)
			magic 	+= dat
		else
			normal 	+= dat

	dat = normal + "<BR>" + magic + "<BR>" + holiday

	var/datum/browser/popup = new(usr, "forceevent", "Force Random Event", 300, 750)
	popup.set_content(dat)
	popup.open()


/datum/controller/subsystem/events/proc/toggleWizardmode()
	wizardmode = !wizardmode
	message_admins("Summon Events has been [wizardmode ? "enabled, events will occur every [SSevents.frequency_lower / 600] to [SSevents.frequency_upper / 600] minutes" : "disabled"]!")
	log_game("Summon Events was [wizardmode ? "enabled" : "disabled"]!")


/datum/controller/subsystem/events/proc/resetFrequency()
	frequency_lower = initial(frequency_lower)
	frequency_upper = initial(frequency_upper)



/**
 * HOLIDAYS
 *
 * Uncommenting ALLOW_HOLIDAYS in config.txt will enable holidays
 *
 * It's easy to add stuff. Just add a holiday datum in code/modules/holiday/holidays.dm
 * You can then check if it's a special day in any code in the game by calling check_holidays("Groundhog Day")
 *
 * You can also make holiday random events easily thanks to Pete/Gia's system.
 * simply make a random event normally, then assign it a holidayID string which matches the holiday's name.
 * Anything with a holidayID, which isn't in the holidays list, will never occur.
 *
 * Please, Don't spam stuff up with stupid stuff (key example being april-fools Pooh/ERP/etc),
 * and don't forget: CHECK YOUR CODE!!!! We don't want any zero-day bugs which happen only on holidays and never get found/fixed!
 */
GLOBAL_LIST(holidays)

/**
 * Checks that the passed holiday is located in the global holidays list.
 *
 * Returns a holiday datum, or null if it's not that holiday.
 */
/proc/check_holidays(holiday_to_find)
	if(!CONFIG_GET(flag/allow_holidays))
		return // Holiday stuff was not enabled in the config!

	if(isnull(GLOB.holidays) && !fill_holidays())
		return // Failed to generate holidays, for some reason

	return GLOB.holidays[holiday_to_find]

/**
 * Fills the holidays list if applicable, or leaves it an empty list.
 */
proc/fill_holidays()
	if(!CONFIG_GET(flag/allow_holidays))
		return FALSE // Holiday stuff was not enabled in the config!

	GLOB.holidays = list()
	for(var/holiday_type in subtypesof(/datum/holiday))
		var/datum/holiday/holiday = new holiday_type()
		var/delete_holiday = TRUE
		for(var/timezone in holiday.timezones)
			var/time_in_timezone = world.realtime + timezone HOURS

			var/YYYY = text2num(time2text(time_in_timezone, "YYYY")) // get the current year
			var/MM = text2num(time2text(time_in_timezone, "MM")) // get the current month
			var/DD = text2num(time2text(time_in_timezone, "DD")) // get the current day
			var/DDD = time2text(time_in_timezone, "DDD") // get the current weekday

			if(holiday.shouldCelebrate(DD, MM, YYYY, DDD))
				holiday.celebrate()
				GLOB.holidays[holiday.name] = holiday

				delete_holiday = FALSE
				break
		if(delete_holiday)
			qdel(holiday)

	if(GLOB.holidays.len)
		shuffle_inplace(GLOB.holidays)
		//Yog code, We haven't totally moved away from holidays being in events
		if(!SSevents.holidays)
			SSevents.holidays = list()
		SSevents.holidays = GLOB.holidays
		// regenerate station name because holiday prefixes.
		set_station_name(new_station_name())
		world.update_status()

	return TRUE
