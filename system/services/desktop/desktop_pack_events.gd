extends Node
class_name DesktopPackEvents

const EVENTS_FILENAME: String = "desktop_events.json"

func get_events() -> Dictionary:
	var pack_id: String = CharacterProfiles.get_current_pack()

	if pack_id.is_empty():
		return {}

	var interface_language: String = AppLanguage.get_language()
	var root_path: String = CharacterProfiles.get_pack_root_path(pack_id)
	if not root_path.is_empty():
		var interface_events_path: String = root_path.path_join("locales").path_join(
			interface_language
		).path_join(EVENTS_FILENAME)
		if FileAccess.file_exists(interface_events_path):
			var interface_events: Dictionary = JsonStore.load_dictionary(
				interface_events_path,
				{}
			)
			if not interface_events.is_empty():
				return interface_events

	return CharacterProfiles.load_pack_localized_json(
		pack_id,
		EVENTS_FILENAME,
		false
	)

func get_boot_delay_seconds() -> float:
	var boot: Dictionary = _get_section("boot")

	return maxf(
		0.0,
		float(
			boot.get(
				"secondary_delay_seconds",
				4.0
			)
		)
	)

func pick_boot_line(
	character_id: String,
	role: String
) -> Dictionary:

	var boot: Dictionary = _get_section("boot")
	var role_key: String = ""
	match role:
		"primary":
			role_key = "primary_lines"
		"arrival":
			role_key = "arrival_lines"
		_:
			return {}

	var by_character: Variant = boot.get(
		role_key,
		{}
	)

	if not (by_character is Dictionary):
		return {}

	var lines_value: Variant = (
		by_character as Dictionary
	).get(
		character_id,
		[]
	)

	return _pick_line(lines_value)

func pick_boot_peer_line(
	character_id: String
) -> Dictionary:

	var boot: Dictionary = _get_section("boot")
	var by_character: Variant = boot.get(
		"peer_after_arrival_lines",
		{}
	)

	if not (by_character is Dictionary):
		return {}

	return _pick_line(
		(by_character as Dictionary).get(
			character_id,
			[]
		)
	)

func pick_hourly_line(
	character_id: String,
	hour_24: int
) -> Dictionary:

	var hourly: Dictionary = _get_section("hourly")
	var characters_value: Variant = hourly.get(
		"characters",
		{}
	)

	if not (characters_value is Dictionary):
		return {}

	var character_value: Variant = (
		characters_value as Dictionary
	).get(
		character_id,
		{}
	)

	if not (character_value is Dictionary):
		return {}

	var character_lines: Dictionary = (
		character_value as Dictionary
	)

	var period: String = _get_day_period(hour_24)
	var value: Variant = character_lines.get(
		period,
		[]
	)

	var result: Dictionary = _pick_line(value)

	if result.is_empty():
		return result

	var text: String = str(
		result.get(
			"text",
			""
		)
	)

	result["text"] = (
		text
			.replace(
				"{hour}",
				_format_hour(hour_24)
			)
			.replace(
				"{hour24}",
				str(hour_24)
			)
	)

	return result

func _get_section(
	key: String
) -> Dictionary:

	var events: Dictionary = get_events()
	var value: Variant = events.get(
		key,
		{}
	)

	if value is Dictionary:
		return value as Dictionary

	return {}

func _pick_line(
	value: Variant
) -> Dictionary:

	if not (value is Array):
		return {}

	var lines: Array = value

	if lines.is_empty():
		return {}

	var selected: Variant = lines[
		randi_range(
			0,
			lines.size() - 1
		)
	]

	if not (selected is Dictionary):
		return {}

	return (
		selected as Dictionary
	).duplicate(
		true
	)

func _get_day_period(
	hour_24: int
) -> String:

	if hour_24 < 6:
		return "late_night"

	if hour_24 < 12:
		return "morning"

	if hour_24 < 18:
		return "day"

	if hour_24 < 23:
		return "evening"

	return "late_night"

func _format_hour(
	hour_24: int
) -> String:

	var hour_12: int = hour_24 % 12

	if hour_12 == 0:
		hour_12 = 12

	return str(hour_12)
