extends RefCounted
class_name DesktopPreferences

const PATH := "user://settings/desktop_preferences.json"
static var _data: Dictionary = {}
static var _loaded: bool = false

static func key(character_id: String, pack_id: String = "") -> String:
	return (pack_id if not pack_id.is_empty() else CharacterProfiles.get_current_pack()) + "/" + character_id

static func get_entry(character_id: String, pack_id: String = "") -> Dictionary:
	if not _loaded:
		_data = JsonStore.load_dictionary(PATH, {})
		for stale_key: String in _data.keys():
			if stale_key.ends_with("/"):
				_data.erase(stale_key)
		_loaded = true
	var value: Variant = _data.get(key(character_id, pack_id), {})
	return value.duplicate(true) if value is Dictionary else {}

static func update_entry(character_id: String, changes: Dictionary, pack_id: String = "") -> Error:
	if character_id.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	var entry := get_entry(character_id, pack_id)
	entry.merge(changes, true)
	var next := _data.duplicate(true)
	next[key(character_id, pack_id)] = entry
	var error := JsonStore.save_json(PATH, next)
	if error == OK:
		_data = next
	return error

static func font_path(character_id: String, pack_id: String = "") -> String:
	var path := str(get_entry(character_id, pack_id).get("font", ""))
	if not path.is_empty() and FileAccess.file_exists(path):
		return path
	return AppearanceSettings.get_bubble_font_path()

# Screen coordinates may be negative, and displays may be above or below one another.
static func nearest_rect_index(point: Vector2, rects: Array[Rect2i]) -> int:
	var best := 0
	var distance := INF
	for index: int in range(rects.size()):
		var rect := rects[index]
		if rect.has_point(Vector2i(point)):
			return index
		var closest := Vector2(clampf(point.x, rect.position.x, rect.end.x), clampf(point.y, rect.position.y, rect.end.y))
		var candidate := point.distance_squared_to(closest)
		if candidate < distance:
			distance = candidate
			best = index
	return best

static func screen_at(point: Vector2) -> int:
	var rects: Array[Rect2i] = []
	for index: int in range(DisplayServer.get_screen_count()):
		rects.append(Rect2i(DisplayServer.screen_get_position(index), DisplayServer.screen_get_size(index)))
	return nearest_rect_index(point, rects)

static func clamp_window(position: Vector2i, pet: Rect2, usable: Rect2i) -> Vector2i:
	var minimum := usable.position - Vector2i(pet.position.floor())
	var maximum := usable.end - Vector2i(pet.end.ceil())
	return Vector2i(clampi(position.x, minimum.x, maxi(minimum.x, maximum.x)), clampi(position.y, minimum.y, maxi(minimum.y, maximum.y)))
