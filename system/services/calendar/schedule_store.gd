extends RefCounted
class_name CompanionScheduleStore

const SAVE_DIRECTORY: String = "user://calendar"

const SAVE_PATH: String = (
	SAVE_DIRECTORY
	+ "/schedules.txt"
)
const DEFAULT_SEED_MARKER: String = SAVE_DIRECTORY + "/default_schedules_v1.seed"

const WEEKDAY_NAMES: Array[String] = [
	"Sun",
	"Mon",
	"Tue",
	"Wed",
	"Thu",
	"Fri",
	"Sat"
]

const DEFAULT_HOLIDAY_SCHEDULES: Array[Dictionary] = [
	{"id":"holiday_new_year","title":"신정","repeat":"yearly","month":1,"day":1,"hour":9,"minute":0,"reminder_minutes":-1,"enabled":true,"special_boot_key":"holiday"},
	{"id":"holiday_march_first","title":"삼일절","repeat":"yearly","month":3,"day":1,"hour":9,"minute":0,"reminder_minutes":-1,"enabled":true,"special_boot_key":"holiday"},
	{"id":"holiday_childrens_day","title":"어린이날","repeat":"yearly","month":5,"day":5,"hour":9,"minute":0,"reminder_minutes":-1,"enabled":true,"special_boot_key":"holiday"},
	{"id":"holiday_memorial_day","title":"현충일","repeat":"yearly","month":6,"day":6,"hour":9,"minute":0,"reminder_minutes":-1,"enabled":true,"special_boot_key":"holiday"},
	{"id":"holiday_liberation_day","title":"광복절","repeat":"yearly","month":8,"day":15,"hour":9,"minute":0,"reminder_minutes":-1,"enabled":true,"special_boot_key":"holiday"},
	{"id":"holiday_foundation_day","title":"개천절","repeat":"yearly","month":10,"day":3,"hour":9,"minute":0,"reminder_minutes":-1,"enabled":true,"special_boot_key":"holiday"},
	{"id":"holiday_hangul_day","title":"한글날","repeat":"yearly","month":10,"day":9,"hour":9,"minute":0,"reminder_minutes":-1,"enabled":true,"special_boot_key":"holiday"},
	{"id":"holiday_christmas","title":"크리스마스","repeat":"yearly","month":12,"day":25,"hour":9,"minute":0,"reminder_minutes":-1,"enabled":true,"special_boot_key":"holiday"}
]

static func load_schedules() -> Array[Dictionary]:
	_ensure_save_directory()

	if FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_PATH + ".bak"):
		var loaded: Array[Dictionary] = _load_txt_schedules()
		if not FileAccess.file_exists(DEFAULT_SEED_MARKER):
			loaded = _merge_default_schedules(loaded)
			if _write_txt_schedules(loaded):
				_write_seed_marker()
		return loaded

	var defaults: Array[Dictionary] = _merge_default_schedules([])
	if _write_txt_schedules(defaults):
		_write_seed_marker()
	return defaults

static func save_schedules(
	schedules: Array
) -> bool:

	_ensure_save_directory()

	var normalized: Array[Dictionary] = []

	for value: Variant in schedules:
		if not (
			value is Dictionary
		):
			continue

		var schedule: Dictionary = normalize_schedule(
			value
		)

		if schedule.is_empty():
			continue

		normalized.append(
			schedule
		)

	return _write_txt_schedules(
		normalized
	)

static func _merge_default_schedules(existing: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = existing.duplicate(true)
	var ids: Dictionary = {}
	for schedule: Dictionary in result:
		ids[str(schedule.get("id", ""))] = true
	for default_schedule: Dictionary in DEFAULT_HOLIDAY_SCHEDULES:
		var schedule_id: String = str(default_schedule.get("id", ""))
		if not ids.has(schedule_id):
			result.append(default_schedule.duplicate(true))
	return result

static func _write_seed_marker() -> void:
	_ensure_save_directory()
	var file: FileAccess = FileAccess.open(DEFAULT_SEED_MARKER, FileAccess.WRITE)
	if file != null:
		file.store_string("seeded\n")
		file.close()

static func normalize_schedule(
	value: Dictionary
) -> Dictionary:
	if bool(value.get("_invalid", false)):
		return {}

	var schedule_id: String = str(value.get("id", "")).strip_edges()
	var title: String = str(value.get("title", "")).strip_edges()
	if title.is_empty():
		return {}
	if schedule_id.is_empty():
		schedule_id = make_schedule_id()

	var repeat_mode: String = str(value.get("repeat", "weekly")).strip_edges().to_lower()
	if not repeat_mode in ["once", "weekly", "yearly"]:
		repeat_mode = "weekly"

	var days: Array[int] = []
	if repeat_mode == "weekly":
		var day_values: Variant = value.get("days", [])
		if day_values is Array:
			for day_value: Variant in day_values:
				var weekday: int = int(day_value)
				if weekday >= 0 and weekday <= 6 and not days.has(weekday):
					days.append(weekday)
		days.sort()
		if days.is_empty():
			return {}

	var year: int = clampi(int(value.get("year", Time.get_datetime_dict_from_system().get("year", 1970))), 1970, 9999)
	var month: int = clampi(int(value.get("month", 1)), 1, 12)
	var day: int = clampi(int(value.get("day", 1)), 1, _days_in_month(month))
	var reminder_minutes: int = int(value.get("reminder_minutes", 10))
	if reminder_minutes < -1:
		reminder_minutes = -1
	reminder_minutes = mini(reminder_minutes, 1440)

	return {
		"id": schedule_id,
		"title": title,
		"repeat": repeat_mode,
		"days": days,
		"year": year,
		"month": month,
		"day": day,
		"hour": clampi(int(value.get("hour", 9)), 0, 23),
		"minute": clampi(int(value.get("minute", 0)), 0, 59),
		"reminder_minutes": reminder_minutes,
		"enabled": bool(value.get("enabled", true)),
		"special_boot_key": str(value.get("special_boot_key", "")).strip_edges().to_lower()
	}

static func matches_date(schedule: Dictionary, year: int, month: int, day: int) -> bool:
	if not bool(schedule.get("enabled", true)):
		return false
	var repeat_mode: String = str(schedule.get("repeat", "weekly"))
	if repeat_mode == "once":
		return (
			int(schedule.get("year", 0)) == year
			and int(schedule.get("month", 0)) == month
			and int(schedule.get("day", 0)) == day
		)
	if repeat_mode == "yearly":
		return int(schedule.get("month", 0)) == month and int(schedule.get("day", 0)) == day
	var weekday: int = int(Time.get_datetime_dict_from_unix_time(Time.get_unix_time_from_datetime_dict({"year":year,"month":month,"day":day,"hour":12,"minute":0,"second":0})).get("weekday", -1))
	var days: Variant = schedule.get("days", [])
	return days is Array and (days as Array).has(weekday)

static func get_schedules_for_date(year: int, month: int, day: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for schedule: Dictionary in load_schedules():
		if matches_date(schedule, year, month, day):
			result.append(schedule.duplicate(true))
	return result

static func get_special_boot_occasion(year: int, month: int, day: int) -> Dictionary:
	for schedule: Dictionary in get_schedules_for_date(year, month, day):
		var title: String = str(schedule.get("title", "")).strip_edges()
		var key: String = str(schedule.get("special_boot_key", "")).strip_edges().to_lower()
		if key == "holiday":
			return {"kind":"holiday", "title":title, "source":"schedule"}
		var lower: String = title.to_lower()
		if "생일" in title or "birthday" in lower:
			return {"kind":"birthday", "title":title, "source":"schedule"}
		if "운동" in title or "exercise" in lower or "workout" in lower:
			return {"kind":"exercise", "title":title, "source":"schedule"}
	return {}

static func _days_in_month(month: int) -> int:
	if month == 2:
		return 29
	if month in [4, 6, 9, 11]:
		return 30
	return 31

static func make_schedule_id() -> String:
	return (
		"schedule_"
		+ str(
			int(
				Time.get_unix_time_from_system()
			)
		)
		+ "_"
		+ str(
			randi()
		)
	)

static func _load_txt_schedules() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	var saved_text := AtomicFile.load_text(SAVE_PATH)

	var current: Dictionary = {}

	for raw_line: String in (
		saved_text.split(
			"\n"
		)
	):
		var line: String = (
			raw_line.strip_edges()
		)

		if (
			line.is_empty()
			or line.begins_with(
				"#"
			)
			or line.begins_with(
				";"
			)
		):
			continue

		if (
			line.begins_with(
				"["
			)
			and line.ends_with(
				"]"
			)
		):
			_append_parsed_schedule(
				result,
				current
			)

			current = {
				"id": line.substr(
					1,
					line.length() - 2
				).strip_edges()
			}

			continue

		var separator_index: int = (
			line.find(
				"="
			)
		)

		if separator_index < 0:
			continue

		if current.is_empty():
			continue

		var key: String = (
			line.substr(
				0,
				separator_index
			)
				.strip_edges()
				.to_lower()
		)

		var value: String = (
			line.substr(
				separator_index + 1
			)
				.strip_edges()
		)

		match key:
			"title":
				current["title"] = value

			"days":
				current["days"] = _parse_days(value)
			"repeat":
				current["repeat"] = value.strip_edges().to_lower()
			"year":
				current["year"] = int(value) if value.is_valid_int() else int(Time.get_datetime_dict_from_system().get("year", 1970))
			"month":
				current["month"] = int(value) if value.is_valid_int() else 1
			"day":
				current["day"] = int(value) if value.is_valid_int() else 1
			"enabled":
				current["enabled"] = not value.strip_edges().to_lower() in ["false", "0", "off", "no"]
			"special_boot_key":
				current["special_boot_key"] = value.strip_edges().to_lower()

			"time":
				var parsed_time: Dictionary = _parse_time(
					value
				)

				if parsed_time.is_empty():
					current["_invalid"] = true
				else:
					current["hour"] = int(
						parsed_time["hour"]
					)
					current["minute"] = int(
						parsed_time["minute"]
					)

			"reminder_minutes":
				var reminder: int = _parse_reminder_minutes(
					value
				)

				if reminder < -1:
					current["_invalid"] = true
				else:
					current["reminder_minutes"] = reminder

	_append_parsed_schedule(
		result,
		current
	)

	return result

static func _append_parsed_schedule(
	result: Array[Dictionary],
	raw_schedule: Dictionary
) -> void:

	if raw_schedule.is_empty():
		return

	var normalized: Dictionary = normalize_schedule(
		raw_schedule
	)

	if normalized.is_empty():
		return

	var schedule_id: String = str(
		normalized.get(
			"id",
			""
		)
	)

	for existing: Dictionary in result:
		if str(
			existing.get(
				"id",
				""
			)
		) == schedule_id:
			return

	result.append(
		normalized
	)

static func _write_txt_schedules(
	schedules: Array[Dictionary]
) -> bool:

	_ensure_save_directory()

	var lines: Array[String] = [
		"# Companion schedules",
		"#",
		"# This is a normal text file. You may edit it by hand.",
		"# One-time: repeat = once with year/month/day.",
		"# Weekly: repeat = weekly and days = Sun, Mon, ...",
		"# Yearly: repeat = yearly with month/day. Yearly ignores days.",
		"# Time uses 24-hour HH:MM.",
		"# reminder_minutes = -1 means no reminder.",
		"#",
		"# Example:",
		"# [my_class]",
		"# title = Class",
		"# repeat = weekly",
		"# days = Mon, Wed, Fri",
		"# time = 14:30",
		"# reminder_minutes = 10",
		""
	]

	for schedule: Dictionary in schedules:
		var schedule_id: String = str(
			schedule.get(
				"id",
				""
			)
		).strip_edges()

		if schedule_id.is_empty():
			continue

		lines.append(
			"["
			+ schedule_id
			+ "]"
		)

		lines.append(
			"title = "
			+ _single_line_text(
				str(
					schedule.get(
						"title",
						""
					)
				)
			)
		)

		var repeat_mode: String = str(schedule.get("repeat", "weekly"))
		lines.append("repeat = " + repeat_mode)
		if repeat_mode == "once":
			lines.append("year = " + str(int(schedule.get("year", Time.get_datetime_dict_from_system().get("year", 1970)))))
			lines.append("month = " + str(int(schedule.get("month", 1))))
			lines.append("day = " + str(int(schedule.get("day", 1))))
		elif repeat_mode == "yearly":
			lines.append("month = " + str(int(schedule.get("month", 1))))
			lines.append("day = " + str(int(schedule.get("day", 1))))
		else:
			lines.append("days = " + _format_days(schedule.get("days", [])))

		lines.append(
			"time = %02d:%02d"
			% [
				int(
					schedule.get(
						"hour",
						9
					)
				),
				int(
					schedule.get(
						"minute",
						0
					)
				)
			]
		)

		lines.append(
			"reminder_minutes = "
			+ str(
				int(
					schedule.get(
						"reminder_minutes",
						10
					)
				)
			)
		)

		lines.append("enabled = " + ("true" if bool(schedule.get("enabled", true)) else "false"))
		var special_boot_key: String = str(schedule.get("special_boot_key", "")).strip_edges()
		if not special_boot_key.is_empty():
			lines.append("special_boot_key = " + special_boot_key)

		lines.append("")

	return AtomicFile.save_text(SAVE_PATH, "\n".join(lines)) == OK

static func _parse_days(
	value: String
) -> Array[int]:

	var result: Array[int] = []

	for raw_part: String in value.split(
		","
	):
		var part: String = (
			raw_part
				.strip_edges()
				.to_lower()
		)

		if part.is_empty():
			continue

		var day: int = _weekday_from_text(
			part
		)

		if day < 0:
			continue

		if not result.has(
			day
		):
			result.append(
				day
			)

	result.sort()

	return result

static func _weekday_from_text(
	value: String
) -> int:

	match value:
		"0", "sun", "sunday":
			return 0

		"1", "mon", "monday":
			return 1

		"2", "tue", "tues", "tuesday":
			return 2

		"3", "wed", "wednesday":
			return 3

		"4", "thu", "thur", "thurs", "thursday":
			return 4

		"5", "fri", "friday":
			return 5

		"6", "sat", "saturday":
			return 6

	return -1

static func _parse_time(
	value: String
) -> Dictionary:
	var parts: PackedStringArray = value.strip_edges().split(
		":"
	)

	if parts.size() != 2:
		return {}

	var hour_text: String = parts[0].strip_edges()
	var minute_text: String = parts[1].strip_edges()

	if (
		not hour_text.is_valid_int()
		or not minute_text.is_valid_int()
	):
		return {}

	var hour: int = int(
		hour_text
	)
	var minute: int = int(
		minute_text
	)

	if (
		hour < 0
		or hour > 23
		or minute < 0
		or minute > 59
	):
		return {}

	return {
		"hour": hour,
		"minute": minute
	}

static func _parse_reminder_minutes(
	value: String
) -> int:
	var clean: String = value.strip_edges().to_lower()

	if clean in [
		"none",
		"off",
		"no"
	]:
		return -1

	if not clean.is_valid_int():
		return -2

	var minutes: int = int(
		clean
	)

	if minutes < -1 or minutes > 1440:
		return -2

	return minutes

static func _format_days(
	day_values: Variant
) -> String:

	var names: Array[String] = []

	if day_values is Array:
		for raw_day: Variant in day_values:
			var day: int = int(
				raw_day
			)

			if (
				day < 0
				or day >= WEEKDAY_NAMES.size()
			):
				continue

			names.append(
				WEEKDAY_NAMES[
					day
				]
			)

	return ", ".join(
		names
	)

static func _single_line_text(
	value: String
) -> String:

	return (
		value
			.replace(
				"\r",
				" "
			)
			.replace(
				"\n",
				" "
			)
			.strip_edges()
	)

static func _ensure_save_directory() -> void:
	var user_directory: DirAccess = DirAccess.open(
		"user://"
	)

	if user_directory == null:
		return

	if not user_directory.dir_exists(
		"calendar"
	):
		user_directory.make_dir_recursive(
			"calendar"
		)
