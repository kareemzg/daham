class_name Daily
extends RefCounted
## The daily challenge: one level a day, and seven days in a row light the seven
## stars of بنات نعش.
##
## The rules, all in one place because they are promises the window makes:
## finishing costs no lantern however badly it goes, a day missed puts the run
## back to nothing, and the day's level is the same one for everybody.

const STREAK_LENGTH := 7
const DAY_REWARD := 25
## Paid on top of the day's reward when the seventh star lights.
const WEEK_REWARD := 200


## Days since the Unix epoch, in the player's own day rather than in UTC: the
## challenge turns over at their midnight, not at someone else's.
static func today() -> int:
	var now := Time.get_datetime_dict_from_system()
	return int(
		Time.get_unix_time_from_datetime_dict({
			"year": now["year"], "month": now["month"], "day": now["day"],
			"hour": 0, "minute": 0, "second": 0,
		}) / 86400.0
	)


## Seconds left of the player's day, for the "come back tomorrow" clock.
static func seconds_left_today() -> int:
	var now := Time.get_datetime_dict_from_system()
	return 86400 - (int(now["hour"]) * 3600 + int(now["minute"]) * 60 + int(now["second"]))


## How many stars are alight right now. A run only stands if the last day played
## was today or yesterday; anything older and the sky is dark again.
static func lit(streak: int, last_day: int, day: int) -> int:
	if last_day == day or last_day == day - 1:
		return clampi(streak, 0, STREAK_LENGTH)
	return 0


static func played_today(last_day: int, day: int) -> bool:
	return last_day == day


## What the run becomes after today's challenge is finished. A seventh star
## completes the week, so the next one starts a new one at one.
static func advanced(streak: int, last_day: int, day: int) -> int:
	var standing := lit(streak, last_day, day)
	if standing >= STREAK_LENGTH:
		return 1
	return standing + 1


## The day's level, the same one for everybody on the same date. Multiplying by
## a large odd number and taking the remainder walks the year in big steps, so
## two days running are nowhere near each other.
##
## It walks what this build SHIPS, not the whole year. Walking all 560 while the
## build carries only spring picked a level that is not in the export three days
## out of four: the file was missing, `start_daily()` returned false, and the
## signal it hangs off ignores that, so «العب» simply did nothing and said
## nothing. A dead button reads as a broken game, and nothing in a release build
## would have shown why.
##
## When a season is added the day's level changes for anyone who updates, which
## is unavoidable — the new levels have to become reachable. No save breaks over
## it: a run keeps a day and a count, never a level id, so a streak carries
## across the update untouched.
static func level_for(day: int) -> String:
	var slot: int = posmod(day * 2654435761, Mansions.SHIPPED_LEVELS)
	return Mansions.level_id(slot / Mansions.LEVELS_PER_MANSION + 1,
		slot % Mansions.LEVELS_PER_MANSION + 1)
