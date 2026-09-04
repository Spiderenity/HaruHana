extends Node
class_name DesktopPackValidator

const RuntimeCharacterBuilderScript = preload(
	"res://system/services/desktop/runtime_character_builder.gd"
)

const ALLOWED_MOODS: Array[String] = [
	"neutral",
	"happy",
	"amused",
	"smug",
	"curious",
	"surprised",
	"annoyed",
	"angry",
	"worried",
	"sad",
	"embarrassed",
	"tired",
	"flustered",
	"flustered_worried",
	"flustered_surprised",
	"flustered_annoyed"
]

const PLAY_FILENAMES: Array[String] = [
	"play_profiles_safe.json",
	"play_profiles_alternative.json",
	"play_profiles.json"
]

const EVENTS_FILENAME: String = "desktop_events.json"

func validate_current_pack() -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var notes: Array[String] = []

	var pack_id: String = (
		CharacterProfiles
			.get_current_pack()
			.strip_edges()
			.to_lower()
	)

	if pack_id.is_empty():
		errors.append("No active character pack.")

		return _build_report(
			pack_id,
			errors,
			warnings,
			notes
		)

	var character_ids: Array[String] = CharacterProfiles.get_pack_character_ids(
		pack_id
	)

	if character_ids.is_empty():
		errors.append(
			"The active pack contains no character profiles."
		)

	var known_ids: Array[String] = []

	for value: String in character_ids:
		var character_id: String = value.strip_edges().to_lower()

		if character_id.is_empty():
			errors.append(
				"A profile summary has an empty character ID."
			)
			continue

		known_ids.append(character_id)

		_validate_character_profile(
			character_id,
			errors,
			warnings
		)

	_validate_pack_json_files(
		pack_id,
		known_ids,
		errors,
		warnings,
		notes
	)

	if errors.is_empty():
		notes.append(
			"Pack validation completed without fatal errors."
		)

	return _build_report(
		pack_id,
		errors,
		warnings,
		notes
	)

func _validate_character_profile(
	character_id: String,
	errors: Array[String],
	warnings: Array[String]
) -> void:
	var profile: Dictionary = CharacterProfiles.load_profile(
		character_id
	)

	if profile.is_empty():
		errors.append(
			character_id + ": profile could not be loaded."
		)
		return

	var desktop_value: Variant = profile.get("desktop", {})

	if not (desktop_value is Dictionary):
		errors.append(
			character_id
			+ ": profile.desktop is missing or not a dictionary."
		)
		return

	var desktop: Dictionary = desktop_value as Dictionary
	var skins_value: Variant = desktop.get("skins", {})

	if not (skins_value is Dictionary):
		errors.append(
			character_id
			+ ": desktop.skins is not a dictionary."
		)
		return

	var skins: Dictionary = skins_value as Dictionary

	if skins.is_empty():
		errors.append(
			character_id + ": desktop.skins is empty."
		)
		return

	var pack_id: String = CharacterProfiles.get_current_pack()

	for key: Variant in skins.keys():
		var skin_id: String = str(key).strip_edges()

		if skin_id.is_empty():
			errors.append(
				character_id + ": found an empty skin ID."
			)
			continue

		if RuntimeCharacterBuilderScript.can_build(
			pack_id,
			character_id,
			skin_id
		):
			continue

		var scene_path: String = str(
			skins.get(key, "")
		).strip_edges()

		if scene_path.is_empty() or scene_path == "runtime":
			errors.append(
				character_id
				+ "/"
				+ skin_id
				+ ": no body image is available for the runtime skin."
			)
			continue

		var resource: Resource = ResourceLoader.load(scene_path)

		if not (resource is PackedScene):
			errors.append(
				character_id
				+ "/"
				+ skin_id
				+ ": no body image or loadable legacy scene: "
				+ scene_path
			)

	var default_skin: String = str(
		desktop.get("default_skin", "")
	).strip_edges()

	if (
		not default_skin.is_empty()
		and not skins.has(default_skin)
	):
		warnings.append(
			character_id
				+ ": default_skin does not exist in desktop.skins: "
				+ default_skin
		)

func _validate_pack_json_files(
	pack_id: String,
	known_ids: Array[String],
	errors: Array[String],
	warnings: Array[String],
	notes: Array[String]
) -> void:
	var found_play_file: bool = false

	for filename: String in PLAY_FILENAMES:
		var located: String = _find_pack_file(
			pack_id,
			filename
		)

		if located.is_empty():
			continue

		found_play_file = true

		var data: Dictionary = _read_json(
			located,
			errors
		)

		if data.is_empty():
			continue

		notes.append("Found " + filename + ".")

		_validate_play_profiles(
			filename,
			data,
			known_ids,
			errors,
			warnings
		)

	if not found_play_file:
		warnings.append(
			"No play profile JSON was found."
		)

	var events_path: String = _find_pack_file(
		pack_id,
		EVENTS_FILENAME
	)

	if events_path.is_empty():
		warnings.append(
			"No " + EVENTS_FILENAME + " was found."
		)
		return

	var events: Dictionary = _read_json(
		events_path,
		errors
	)

	if events.is_empty():
		return

	_validate_moods_recursive(
		events,
		EVENTS_FILENAME,
		warnings
	)

func _validate_play_profiles(
	filename: String,
	data: Dictionary,
	known_ids: Array[String],
	errors: Array[String],
	warnings: Array[String]
) -> void:
	var default_value: Variant = data.get("default", {})

	if not (default_value is Dictionary):
		errors.append(
			filename + ": default must be a dictionary."
		)

	var characters_value: Variant = data.get(
		"characters",
		{}
	)

	if not (characters_value is Dictionary):
		errors.append(
			filename + ": characters must be a dictionary."
		)
		return

	for key: Variant in (
		characters_value as Dictionary
	).keys():
		var character_id: String = str(
			key
		).strip_edges().to_lower()

		if character_id.is_empty():
			errors.append(
				filename
					+ ": characters contains an empty ID."
			)
			continue

		if not known_ids.has(character_id):
			warnings.append(
				filename
					+ ": play profile references unknown character "
					+ character_id
					+ "."
			)

		var character_value: Variant = (
			characters_value as Dictionary
		).get(key, {})

		if character_value is Dictionary:
			_validate_touch_zones(
				filename + "/" + character_id,
				character_value as Dictionary,
				errors,
				warnings
			)

	if default_value is Dictionary:
		_validate_touch_zones(
			filename + "/default",
			default_value as Dictionary,
			errors,
			warnings
		)

	_validate_moods_recursive(
		data,
		filename,
		warnings
	)

func _validate_touch_zones(
	label: String,
	profile: Dictionary,
	errors: Array[String],
	warnings: Array[String]
) -> void:
	if not profile.has("touch_zones"):
		return

	var zones_value: Variant = profile.get(
		"touch_zones",
		[]
	)

	if not (zones_value is Array):
		errors.append(
			label + ": touch_zones must be an array."
		)
		return

	var seen: Array[String] = []

	for zone_value: Variant in zones_value as Array:
		if not (zone_value is Dictionary):
			errors.append(
				label
					+ ": touch_zones contains a non-dictionary entry."
			)
			continue

		var zone: Dictionary = zone_value as Dictionary
		var zone_id: String = str(
			zone.get("id", "")
		).strip_edges().to_lower()

		if zone_id.is_empty():
			errors.append(
				label + ": touch zone has an empty id."
			)
			continue

		if seen.has(zone_id):
			errors.append(
				label
					+ ": duplicate touch zone "
					+ zone_id
					+ "."
			)

		seen.append(zone_id)

		var rect_value: Variant = zone.get("rect", [])

		if not (rect_value is Array):
			errors.append(
				label
					+ "/"
					+ zone_id
					+ ": rect must be an array."
			)
			continue

		var rect: Array = rect_value as Array

		if rect.size() != 4:
			errors.append(
				label
					+ "/"
					+ zone_id
					+ ": rect must contain exactly 4 numbers."
			)
			continue

		var x: float = float(rect[0])
		var y: float = float(rect[1])
		var width: float = float(rect[2])
		var height: float = float(rect[3])

		if (
			x < 0.0
			or y < 0.0
			or width <= 0.0
			or height <= 0.0
			or x + width > 1.001
			or y + height > 1.001
		):
			warnings.append(
				label
					+ "/"
					+ zone_id
					+ ": rect extends outside normalized 0–1 bounds."
			)

func _validate_moods_recursive(
	value: Variant,
	path: String,
	warnings: Array[String]
) -> void:
	if value is Dictionary:
		var dictionary: Dictionary = value as Dictionary

		if dictionary.has("mood"):
			var mood: String = str(
				dictionary.get("mood", "")
			).strip_edges().to_lower()

			if (
				not mood.is_empty()
				and not ALLOWED_MOODS.has(mood)
			):
				warnings.append(
					path
						+ ": unknown mood '"
						+ mood
						+ "'."
				)

		for key: Variant in dictionary.keys():
			_validate_moods_recursive(
				dictionary[key],
				path + "/" + str(key),
				warnings
			)

	elif value is Array:
		var array: Array = value as Array

		for index: int in range(array.size()):
			_validate_moods_recursive(
				array[index],
				path
					+ "["
					+ str(index)
					+ "]",
				warnings
			)

func _find_pack_file(
	pack_id: String,
	filename: String
) -> String:
	var root_path: String = CharacterProfiles.get_pack_root_path(pack_id)

	if root_path.is_empty():
		return ""

	var path: String = root_path.path_join(filename)

	if FileAccess.file_exists(path):
		return path

	return ""

func _read_json(
	path: String,
	errors: Array[String]
) -> Dictionary:
	var file: FileAccess = FileAccess.open(
		path,
		FileAccess.READ
	)

	if file == null:
		errors.append(
			"Could not open " + path + "."
		)
		return {}

	var json: JSON = JSON.new()
	var parse_error: Error = json.parse(
		file.get_as_text()
	)

	if parse_error != OK:
		errors.append(
			path
				+ ": JSON parse error on line "
				+ str(json.get_error_line())
				+ ": "
				+ json.get_error_message()
		)
		return {}

	var parsed: Variant = json.data

	if not (parsed is Dictionary):
		errors.append(
			path
				+ ": root JSON value must be a dictionary."
		)
		return {}

	return parsed as Dictionary

func _build_report(
	pack_id: String,
	errors: Array[String],
	warnings: Array[String],
	notes: Array[String]
) -> Dictionary:
	var lines: Array[String] = []

	lines.append(
		"Pack: "
			+ (
				pack_id
				if not pack_id.is_empty()
				else "(none)"
			)
	)

	lines.append(
		"Errors: "
			+ str(errors.size())
			+ " | Warnings: "
			+ str(warnings.size())
	)

	if not errors.is_empty():
		lines.append("")
		lines.append("ERRORS")

		for message: String in errors:
			lines.append("- " + message)

	if not warnings.is_empty():
		lines.append("")
		lines.append("WARNINGS")

		for message: String in warnings:
			lines.append("- " + message)

	if not notes.is_empty():
		lines.append("")
		lines.append("NOTES")

		for message: String in notes:
			lines.append("- " + message)

	return {
		"ok": errors.is_empty(),
		"errors": errors.duplicate(),
		"warnings": warnings.duplicate(),
		"notes": notes.duplicate(),
		"text": "\n".join(lines)
	}
