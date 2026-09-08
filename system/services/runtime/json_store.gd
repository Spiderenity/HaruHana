extends RefCounted
class_name JsonStore

const TEMP_SUFFIX: String = ".tmp"
const BACKUP_SUFFIX: String = ".bak"

static func load_json(path: String, fallback: Variant = null) -> Variant:
	var primary: Variant = _read_json_file(path)
	if primary != null:
		return primary

	var backup_path: String = path + BACKUP_SUFFIX
	var backup: Variant = _read_json_file(backup_path)
	if backup != null:
		_restore_backup(path, backup_path)
		return backup

	return _duplicate_fallback(fallback)

static func load_dictionary(path: String, fallback: Dictionary = {}) -> Dictionary:
	var value: Variant = load_json(path, fallback)
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return fallback.duplicate(true)

static func save_json(
	path: String, value: Variant, indent: String = "\t",
	trailing_newline: bool = false, keep_backup: bool = true
) -> Error:
	var text := JSON.stringify(value, indent)
	if trailing_newline:
		text += "\n"
	# A corrupt primary must not replace the last valid backup.
	if FileAccess.file_exists(path) and _read_json_file(path) == null:
		var quarantine_error := DirAccess.rename_absolute(_absolute(path), _absolute(path + ".corrupt"))
		if quarantine_error != OK:
			return quarantine_error
	return AtomicFile.save_text(path, text, keep_backup)

static func _read_json_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null

	var text: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data

static func _ensure_parent_directory(path: String) -> Error:
	var directory: String = path.get_base_dir()
	if directory.is_empty():
		return OK

	var error: Error = DirAccess.make_dir_recursive_absolute(_absolute(directory))
	if error == ERR_ALREADY_EXISTS:
		return OK
	return error

static func _restore_backup(path: String, backup_path: String) -> void:
	if FileAccess.file_exists(path) or not FileAccess.file_exists(backup_path):
		return
	DirAccess.rename_absolute(_absolute(backup_path), _absolute(path))

static func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(_absolute(path))

static func _absolute(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path

static func _duplicate_fallback(fallback: Variant) -> Variant:
	if fallback is Dictionary:
		return (fallback as Dictionary).duplicate(true)
	if fallback is Array:
		return (fallback as Array).duplicate(true)
	return fallback
