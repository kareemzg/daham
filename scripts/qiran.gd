class_name Qiran
extends RefCounted
## القِران: which of the twenty-eight mansions the moon is in tonight.
##
## This is not a schedule and not a hash. The moon crosses about 13.18° a night
## and a mansion is 360/28 = 12.857°, so it lodges in a new one every night —
## which is the whole reason the Arabs called them منازل القمر in the first
## place. Twenty lines of arithmetic and no data file.
##
## When the moon lodges in a mansion the player has already lit, that mansion
## is open tonight without lanterns. It is worth most on the night the sky is
## darkest, which is the night a player has none left.

## Degrees of ecliptic each mansion covers.
const SPAN := 360.0 / float(Mansions.COUNT)
## Days from the Unix epoch to J2000, which the formulae below count from.
const J2000 := 10957
## The gap between the tropical zodiac the formulae give and the sidereal one
## the mansions are set against, near enough for 2026. It moves about a degree
## in seventy years, so it is a constant for this game's lifetime.
const AYANAMSA := 24.15


## The moon's ecliptic longitude, low precision — a degree or so, which is a
## twelfth of a mansion and never enough to name the wrong one except within
## minutes of a boundary.
static func moon_longitude(day: int) -> float:
	var d := float(day - J2000)
	var mean := 218.316 + 13.176396 * d
	var anomaly := deg_to_rad(134.963 + 13.064993 * d)
	return fposmod(mean + 6.289 * sin(anomaly), 360.0)


static func sun_longitude(day: int) -> float:
	var d := float(day - J2000)
	var anomaly := deg_to_rad(357.528 + 0.9856003 * d)
	return fposmod(280.46 + 0.9856474 * d + 1.915 * sin(anomaly), 360.0)


## Which mansion the moon lodges in tonight, 1 to 28.
static func mansion_on(day: int) -> int:
	var sidereal := fposmod(moon_longitude(day) - AYANAMSA, 360.0)
	return clampi(int(sidereal / SPAN) + 1, 1, Mansions.COUNT)


## Tonight's.
static func mansion_tonight() -> int:
	return mansion_on(Daily.today())


## How lit the moon's face is, 0 new to 1 full.
static func illumination(day: int) -> float:
	var elongation := fposmod(moon_longitude(day) - sun_longitude(day), 360.0)
	return (1.0 - cos(deg_to_rad(elongation))) * 0.5


## Filling rather than emptying.
static func waxing(day: int) -> bool:
	return fposmod(moon_longitude(day) - sun_longitude(day), 360.0) < 180.0


## Nights from `day` until the moon next lodges in `mansion`, 0 for tonight.
## Returns -1 when it does not inside a lunar month, which cannot happen for a
## real mansion but keeps a wrong number from looping.
static func nights_until(mansion: int, day: int) -> int:
	for ahead in 30:
		if mansion_on(day + ahead) == mansion:
			return ahead
	return -1


## The soonest night the player can actually take: the moon has to lodge in a
## mansion this build ships AND one they have already lit, because the whole
## offer is that a finished mansion opens again.
##
## `reached` is how many mansions the player has finished. Returns
## {"mansion": int, "nights": int}, or an empty dictionary if there is none —
## which is the honest answer for a player who has finished nothing.
static func next_open(day: int, reached: int) -> Dictionary:
	if reached < 1:
		return {}
	for ahead in 30:
		var mansion := mansion_on(day + ahead)
		if mansion <= reached and Mansions.is_shipped(mansion):
			return {"mansion": mansion, "nights": ahead}
	return {}


## Whether tonight's mansion is one the player can enter.
static func open_tonight(day: int, reached: int) -> bool:
	var mansion := mansion_on(day)
	return mansion <= reached and Mansions.is_shipped(mansion)


## Which level of the mansion tonight's visit opens on. It moves with the date
## so two conjunctions on the same mansion are not the same board, and it never
## lands on the tenth or the twentieth: the verse and the rhyme belong to the
## night a mansion was first finished, not to a visit.
static func level_for(day: int, mansion: int) -> String:
	var index := int(posmod(day * 7, Mansions.LEVELS_PER_MANSION)) + 1
	if index == 10 or index == 20:
		index += 1
	return Mansions.level_id(mansion, index)
