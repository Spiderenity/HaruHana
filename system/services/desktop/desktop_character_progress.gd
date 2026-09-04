extends RefCounted
class_name DesktopCharacterProgress

const SAVE_PATH: String = "user://desktop_character_progress.json"
const DATA_VERSION: int = 2
const FRIENDSHIP_LEVEL_THRESHOLDS: Array[int] = [5, 15, 35]
const ACHIEVEMENT_LEVEL_THRESHOLDS: Array[int] = [30, 90, 180]

static func get_friendship(character_id: String) -> int:
	var override_level: int = get_debug_friendship_level(character_id)
	if override_level >= 0:
		return _value_for_level(override_level, FRIENDSHIP_LEVEL_THRESHOLDS)
	return get_actual_friendship(character_id)

static func get_actual_friendship(character_id: String) -> int:
	var state: Dictionary = _load_state()
	var friendship: Dictionary = state.get("friendship", {}) as Dictionary
	return maxi(0, int(friendship.get(_normalize_character_id(character_id), 0)))

static func set_friendship(character_id: String, value: int) -> int:
	var clean_id: String = _normalize_character_id(character_id)
	if clean_id.is_empty():
		return 0

	var state: Dictionary = _load_state()
	var friendship: Dictionary = state.get("friendship", {}) as Dictionary
	var clean_value: int = maxi(0, value)
	friendship[clean_id] = clean_value
	state["friendship"] = friendship
	_save_state(state)
	return clean_value

static func add_friendship(character_id: String, amount: int = 1) -> int:
	if amount <= 0:
		return get_actual_friendship(character_id)
	return set_friendship(
		character_id,
		get_actual_friendship(character_id) + amount
	)

static func reset_friendship(character_id: String) -> int:
	return set_friendship(character_id, 0)

static func get_friendship_level(character_id: String) -> int:
	var override_level: int = get_debug_friendship_level(character_id)
	if override_level >= 0:
		return override_level
	return _level_for_value(
		get_actual_friendship(character_id),
		FRIENDSHIP_LEVEL_THRESHOLDS
	)

static func get_actual_friendship_level(character_id: String) -> int:
	return _level_for_value(
		get_actual_friendship(character_id),
		FRIENDSHIP_LEVEL_THRESHOLDS
	)

static func set_friendship_level(character_id: String, level: int) -> int:
	return set_friendship(
		character_id,
		_value_for_level(level, FRIENDSHIP_LEVEL_THRESHOLDS)
	)

static func get_max_friendship_level() -> int:
	return FRIENDSHIP_LEVEL_THRESHOLDS.size()

static func get_achievement_minutes() -> int:
	var override_level: int = get_debug_achievement_level()
	if override_level >= 0:
		return _value_for_level(override_level, ACHIEVEMENT_LEVEL_THRESHOLDS)
	return get_actual_achievement_minutes()

static func get_actual_achievement_minutes() -> int:
	var state: Dictionary = _load_state()
	var achievement: Dictionary = state.get("achievement", {}) as Dictionary
	return maxi(0, int(achievement.get("minutes", 0)))

static func set_achievement_minutes(minutes: int) -> int:
	var state: Dictionary = _load_state()
	var achievement: Dictionary = state.get("achievement", {}) as Dictionary
	var clean_minutes: int = maxi(0, minutes)
	achievement["week_key"] = _current_week_key()
	achievement["minutes"] = clean_minutes
	state["achievement"] = achievement
	_save_state(state)
	return clean_minutes

static func add_achievement_minutes(minutes: int) -> int:
	if minutes <= 0:
		return get_actual_achievement_minutes()
	return set_achievement_minutes(
		get_actual_achievement_minutes() + minutes
	)

static func reset_achievement() -> int:
	return set_achievement_minutes(0)

static func get_achievement_level() -> int:
	var override_level: int = get_debug_achievement_level()
	if override_level >= 0:
		return override_level
	return _level_for_value(
		get_actual_achievement_minutes(),
		ACHIEVEMENT_LEVEL_THRESHOLDS
	)

static func get_actual_achievement_level() -> int:
	return _level_for_value(
		get_actual_achievement_minutes(),
		ACHIEVEMENT_LEVEL_THRESHOLDS
	)

static func set_achievement_level(level: int) -> int:
	return set_achievement_minutes(
		_value_for_level(level, ACHIEVEMENT_LEVEL_THRESHOLDS)
	)

static func get_max_achievement_level() -> int:
	return ACHIEVEMENT_LEVEL_THRESHOLDS.size()

static func set_debug_friendship_level(
	character_id: String,
	level: int
) -> int:
	var clean_id: String = _normalize_character_id(character_id)
	if clean_id.is_empty():
		return -1

	var state: Dictionary = _load_state()
	var overrides: Dictionary = state.get("debug_overrides", {}) as Dictionary
	var friendship_levels: Dictionary = overrides.get(
		"friendship_levels",
		{}
	) as Dictionary
	var clean_level: int = clampi(
		level,
		0,
		get_max_friendship_level()
	)
	friendship_levels[clean_id] = clean_level
	overrides["friendship_levels"] = friendship_levels
	state["debug_overrides"] = overrides
	_save_state(state)
	return clean_level

static func set_debug_achievement_level(level: int) -> int:
	var state: Dictionary = _load_state()
	var overrides: Dictionary = state.get("debug_overrides", {}) as Dictionary
	var clean_level: int = clampi(
		level,
		0,
		get_max_achievement_level()
	)
	overrides["achievement_level"] = clean_level
	state["debug_overrides"] = overrides
	_save_state(state)
	return clean_level

static func get_debug_friendship_level(character_id: String) -> int:
	var clean_id: String = _normalize_character_id(character_id)
	if clean_id.is_empty():
		return -1
	var state: Dictionary = _load_state()
	var overrides: Dictionary = state.get("debug_overrides", {}) as Dictionary
	var friendship_levels: Dictionary = overrides.get(
		"friendship_levels",
		{}
	) as Dictionary
	if not friendship_levels.has(clean_id):
		return -1
	return clampi(
		int(friendship_levels.get(clean_id, -1)),
		0,
		get_max_friendship_level()
	)

static func get_debug_achievement_level() -> int:
	var state: Dictionary = _load_state()
	var overrides: Dictionary = state.get("debug_overrides", {}) as Dictionary
	var level: int = int(overrides.get("achievement_level", -1))
	if level < 0:
		return -1
	return clampi(level, 0, get_max_achievement_level())

static func has_debug_friendship_override(character_id: String) -> bool:
	return get_debug_friendship_level(character_id) >= 0

static func has_debug_achievement_override() -> bool:
	return get_debug_achievement_level() >= 0

static func clear_debug_overrides() -> void:
	var state: Dictionary = _load_state()
	state["debug_overrides"] = _default_debug_overrides()
	_save_state(state)

static func get_context(character_id: String) -> Dictionary:
	var state: Dictionary = _load_state()
	var clean_id: String = _normalize_character_id(character_id)
	var friendship: Dictionary = state.get("friendship", {}) as Dictionary
	var achievement: Dictionary = state.get("achievement", {}) as Dictionary
	var actual_friendship: int = maxi(
		0,
		int(friendship.get(clean_id, 0))
	)
	var actual_achievement: int = maxi(
		0,
		int(achievement.get("minutes", 0))
	)
	var friendship_override: int = _get_debug_friendship_level_from_state(
		state,
		clean_id
	)
	var achievement_override: int = _get_debug_achievement_level_from_state(
		state
	)
	var friendship_value: int = actual_friendship
	var friendship_level: int = _level_for_value(
		actual_friendship,
		FRIENDSHIP_LEVEL_THRESHOLDS
	)
	if friendship_override >= 0:
		friendship_level = friendship_override
		friendship_value = _value_for_level(
		friendship_override,
		FRIENDSHIP_LEVEL_THRESHOLDS
		)
	var achievement_value: int = actual_achievement
	var achievement_level: int = _level_for_value(
		actual_achievement,
		ACHIEVEMENT_LEVEL_THRESHOLDS
	)
	if achievement_override >= 0:
		achievement_level = achievement_override
		achievement_value = _value_for_level(
		achievement_override,
		ACHIEVEMENT_LEVEL_THRESHOLDS
		)
	return {
		"character_id": clean_id,
		"friendship": friendship_value,
		"friendship_level": friendship_level,
		"friendship_actual": actual_friendship,
		"friendship_actual_level": _level_for_value(
			actual_friendship,
			FRIENDSHIP_LEVEL_THRESHOLDS
		),
		"friendship_debug_override": friendship_override,
		"achievement": achievement_value,
		"achievement_level": achievement_level,
		"achievement_actual": actual_achievement,
		"achievement_actual_level": _level_for_value(
			actual_achievement,
			ACHIEVEMENT_LEVEL_THRESHOLDS
		),
		"achievement_debug_override": achievement_override,
		"achievement_week": str(
			achievement.get("week_key", _current_week_key())
		),
	}

static func _load_state() -> Dictionary:
	var state: Dictionary = _sanitize_state(
		JsonStore.load_dictionary(SAVE_PATH, _default_state())
	)
	var achievement: Dictionary = state.get("achievement", {}) as Dictionary
	var current_week: String = _current_week_key()
	if str(achievement.get("week_key", "")) != current_week:
		achievement["week_key"] = current_week
		achievement["minutes"] = 0
		state["achievement"] = achievement
		_save_state(state)
	return state

static func _save_state(state: Dictionary) -> void:
	JsonStore.save_json(SAVE_PATH, state)

static func _default_state() -> Dictionary:
	return {
		"version": DATA_VERSION,
		"friendship": {},
		"achievement": {
			"week_key": _current_week_key(),
			"minutes": 0,
		},
		"debug_overrides": _default_debug_overrides(),
	}

static func _default_debug_overrides() -> Dictionary:
	return {
		"friendship_levels": {},
		"achievement_level": -1,
	}

static func _sanitize_state(raw: Dictionary) -> Dictionary:
	var state: Dictionary = _default_state()
	var friendship_out: Dictionary = {}
	var friendship_raw: Variant = raw.get("friendship", {})

	if friendship_raw is Dictionary:
		for key: Variant in (friendship_raw as Dictionary).keys():
			var clean_id: String = _normalize_character_id(str(key))
			if clean_id.is_empty():
				continue
			friendship_out[clean_id] = maxi(
				0,
				int((friendship_raw as Dictionary).get(key, 0))
			)

	var achievement_out: Dictionary = state.get("achievement", {}) as Dictionary
	var achievement_raw: Variant = raw.get("achievement", {})
	if achievement_raw is Dictionary:
		achievement_out["week_key"] = str(
			(achievement_raw as Dictionary).get("week_key", "")
		)
		achievement_out["minutes"] = maxi(
			0,
			int((achievement_raw as Dictionary).get("minutes", 0))
		)

	var overrides_out: Dictionary = _default_debug_overrides()
	var overrides_raw: Variant = raw.get("debug_overrides", {})
	if overrides_raw is Dictionary:
		var friendship_levels_out: Dictionary = {}
		var levels_raw: Variant = (overrides_raw as Dictionary).get(
			"friendship_levels",
			{}
		)
		if levels_raw is Dictionary:
			for key: Variant in (levels_raw as Dictionary).keys():
				var clean_id: String = _normalize_character_id(str(key))
				if clean_id.is_empty():
					continue
				friendship_levels_out[clean_id] = clampi(
					int((levels_raw as Dictionary).get(key, 0)),
					0,
					get_max_friendship_level()
				)
		overrides_out["friendship_levels"] = friendship_levels_out
		var achievement_level: int = int(
			(overrides_raw as Dictionary).get("achievement_level", -1)
		)
		overrides_out["achievement_level"] = (
			clampi(achievement_level, 0, get_max_achievement_level())
			if achievement_level >= 0
			else -1
		)

	state["version"] = DATA_VERSION
	state["friendship"] = friendship_out
	state["achievement"] = achievement_out
	state["debug_overrides"] = overrides_out
	return state

static func _get_debug_friendship_level_from_state(
	state: Dictionary,
	character_id: String
) -> int:
	if character_id.is_empty():
		return -1
	var overrides: Dictionary = state.get("debug_overrides", {}) as Dictionary
	var friendship_levels: Dictionary = overrides.get(
		"friendship_levels",
		{}
	) as Dictionary
	if not friendship_levels.has(character_id):
		return -1
	return clampi(
		int(friendship_levels.get(character_id, -1)),
		0,
		get_max_friendship_level()
	)

static func _get_debug_achievement_level_from_state(
	state: Dictionary
) -> int:
	var overrides: Dictionary = state.get("debug_overrides", {}) as Dictionary
	var level: int = int(overrides.get("achievement_level", -1))
	if level < 0:
		return -1
	return clampi(level, 0, get_max_achievement_level())

static func _normalize_character_id(character_id: String) -> String:
	return character_id.strip_edges().to_lower()

static func _level_for_value(value: int, thresholds: Array[int]) -> int:
	var level: int = 0
	for threshold: int in thresholds:
		if value < threshold:
			break
		level += 1
	return level

static func _value_for_level(level: int, thresholds: Array[int]) -> int:
	var clean_level: int = clampi(level, 0, thresholds.size())
	if clean_level <= 0:
		return 0
	return thresholds[clean_level - 1]

static func _current_week_key() -> String:
	var date: Dictionary = Time.get_date_dict_from_system(false)
	var weekday: int = int(date.get("weekday", Time.WEEKDAY_MONDAY))
	var days_since_monday: int = (
		weekday - Time.WEEKDAY_MONDAY + 7
	) % 7
	var timestamp: int = Time.get_unix_time_from_datetime_dict({
		"year": int(date.get("year", 1970)),
		"month": int(date.get("month", 1)),
		"day": int(date.get("day", 1)),
		"hour": 12,
	})
	timestamp -= days_since_monday * 86400
	return Time.get_date_string_from_unix_time(timestamp)
