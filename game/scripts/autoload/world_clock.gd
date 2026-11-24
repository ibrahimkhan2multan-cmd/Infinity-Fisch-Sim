extends Node
## Day/night clock and weather state machine (autoload "Clock").
## Visuals (sky, sun, rain) read from here; fishing reads bite modifiers.

signal weather_changed(weather: String)
signal new_day(day: int)

const DAY_LENGTH := 720.0  ## real seconds per in-game day (12 minutes)
const WEATHERS: Array[String] = ["clear", "cloudy", "rain", "storm", "fog"]

const WEATHER_INFO := {
	"clear": {"name": "Clear", "bite": 1.0, "fog": 0.0006, "dark": 0.0, "wave": 0.5, "rain": 0.0, "clouds": 0.15},
	"cloudy": {"name": "Cloudy", "bite": 1.1, "fog": 0.0010, "dark": 0.25, "wave": 0.7, "rain": 0.0, "clouds": 0.7},
	"rain": {"name": "Rain", "bite": 1.3, "fog": 0.0022, "dark": 0.45, "wave": 1.0, "rain": 1.0, "clouds": 1.0},
	"storm": {"name": "Thunderstorm", "bite": 1.5, "fog": 0.0030, "dark": 0.65, "wave": 1.8, "rain": 2.0, "clouds": 1.0},
	"fog": {"name": "Fog", "bite": 1.15, "fog": 0.0075, "dark": 0.2, "wave": 0.4, "rain": 0.0, "clouds": 0.5},
}
# Transition table: from -> [clear, cloudy, rain, storm, fog] weights
const TRANSITIONS := {
	"clear": [50, 30, 8, 2, 10],
	"cloudy": [25, 30, 25, 8, 12],
	"rain": [10, 35, 30, 15, 10],
	"storm": [5, 25, 55, 10, 5],
	"fog": [35, 30, 10, 2, 23],
}

var hour: float = 8.0
var day: int = 1
var weather: String = "clear"
var weather_left: float = 150.0
var running := false   ## only advances while the game scene is active
var time_scale := 1.0


func _process(delta: float) -> void:
	if not running:
		return
	hour += delta * 24.0 / DAY_LENGTH * time_scale
	if hour >= 24.0:
		hour -= 24.0
		day += 1
		new_day.emit(day)
	weather_left -= delta
	if weather_left <= 0.0:
		_roll_weather()


func _roll_weather() -> void:
	var idx := Util.weighted_index(TRANSITIONS[weather])
	set_weather(WEATHERS[idx])


func set_weather(w: String) -> void:
	weather_left = randf_range(100.0, 260.0)
	if w == weather:
		return
	weather = w
	weather_changed.emit(w)


func info() -> Dictionary:
	return WEATHER_INFO[weather]


func weather_name() -> String:
	return String(WEATHER_INFO[weather]["name"])


func bite_mult() -> float:
	return float(WEATHER_INFO[weather]["bite"])


func is_night() -> bool:
	return FishLogic.is_night(hour)


## 0 at deep night, 1 at full day (smooth through dawn/dusk).
func daylight() -> float:
	return clampf(smoothstep(4.5, 7.5, hour) - smoothstep(17.5, 20.5, hour), 0.0, 1.0)


func skip_to_morning() -> void:
	if hour >= 6.0:
		day += 1
		new_day.emit(day)
	hour = 6.0


func to_dict() -> Dictionary:
	return {"hour": hour, "day": day, "weather": weather, "weather_left": weather_left}


func from_dict(d: Dictionary) -> void:
	hour = float(d.get("hour", 8.0))
	day = int(d.get("day", 1))
	weather = str(d.get("weather", "clear"))
	if not WEATHER_INFO.has(weather):
		weather = "clear"
	weather_left = float(d.get("weather_left", 150.0))
	weather_changed.emit(weather)


func reset() -> void:
	hour = 8.0
	day = 1
	weather = "clear"
	weather_left = 150.0
