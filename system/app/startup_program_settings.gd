extends RefCounted
class_name StartupProgramSettings

const SETTINGS_PATH: String = "user://settings/startup_program.json"
const RUN_KEY: String = "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run"
const VALUE_NAME: String = "HaruHana"

static func is_supported() -> bool:
	return OS.get_name() == "Windows" and not Engine.is_editor_hint()

static func is_enabled() -> bool:
	var data: Dictionary = JsonStore.load_dictionary(SETTINGS_PATH, {"enabled": false})
	return bool(data.get("enabled", false))

static func set_enabled(enabled: bool) -> Error:
	if not is_supported():
		return ERR_UNAVAILABLE
	var registry_error: Error = _write_registry(enabled)
	if registry_error != OK:
		return registry_error
	return JsonStore.save_json(SETTINGS_PATH, {"enabled": enabled})

static func sync_if_enabled() -> void:
	if not is_supported() or not is_enabled():
		return
	_write_registry(true)

static func _write_registry(enabled: bool) -> Error:
	var output: Array = []
	var args: PackedStringArray
	if enabled:
		var executable: String = OS.get_executable_path()
		if executable.strip_edges().is_empty():
			return ERR_FILE_NOT_FOUND
		var command_value: String = "\"" + executable + "\""
		args = PackedStringArray([
			"add", RUN_KEY, "/v", VALUE_NAME, "/t", "REG_SZ", "/d", command_value, "/f"
		])
	else:
		args = PackedStringArray(["delete", RUN_KEY, "/v", VALUE_NAME, "/f"])
	var exit_code: int = OS.execute("reg.exe", args, output, true, true)
	return OK if exit_code == 0 else FAILED
