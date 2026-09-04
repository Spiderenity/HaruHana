extends RefCounted
class_name ReportSettings

const SETTINGS_PATH: String = "user://settings/reporting.json"
const DEFAULT_REPORT_DIR: String = "user://productivity/reports"

static func get_default_report_directory() -> String:
	return ProjectSettings.globalize_path(
		DEFAULT_REPORT_DIR
	)

static func get_report_directory() -> String:
	var fallback: String = get_default_report_directory()
	var settings: Dictionary = JsonStore.load_dictionary(SETTINGS_PATH, {})
	var directory: String = str(settings.get("reports_directory", "")).strip_edges()
	if directory.is_empty():
		return fallback
	return _normalize_directory(directory)

static func set_report_directory(
	directory: String
) -> bool:
	var clean_directory: String = _normalize_directory(directory)
	if clean_directory.is_empty():
		return false
	var create_error: Error = DirAccess.make_dir_recursive_absolute(clean_directory)
	if create_error != OK and create_error != ERR_ALREADY_EXISTS:
		return false
	return JsonStore.save_json(
		SETTINGS_PATH,
		{"reports_directory": clean_directory}
	) == OK

static func ensure_report_directory() -> bool:
	var directory: String = get_report_directory()
	var error: Error = DirAccess.make_dir_recursive_absolute(
		directory
	)

	return (
		error == OK
		or error == ERR_ALREADY_EXISTS
	)

static func _normalize_directory(
	directory: String
) -> String:
	var clean_directory: String = directory.strip_edges()

	if clean_directory.is_empty():
		return ""

	if (
		clean_directory.begins_with(
			"user://"
		)
		or clean_directory.begins_with(
			"res://"
		)
	):
		return ProjectSettings.globalize_path(
			clean_directory
		)

	return clean_directory
