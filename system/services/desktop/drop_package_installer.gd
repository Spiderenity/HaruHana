extends RefCounted
class_name DropPackageInstaller

const DistributionPathsScript = preload(
	"res://system/app/distribution_paths.gd"
)

const AppearanceSettingsScript = preload(
	"res://system/app/appearance_settings.gd"
)

const MAX_ARCHIVE_FILES: int = 2048
const MAX_FILE_BYTES: int = 32 * 1024 * 1024
const MAX_TOTAL_BYTES: int = 256 * 1024 * 1024

const BLOCKED_EXTENSIONS: Array[String] = [
	"bat",
	"cmd",
	"com",
	"dll",
	"exe",
	"gd",
	"gdextension",
	"lnk",
	"msi",
	"ps1",
	"scr",
	"vbs"
]

static func install_zip(zip_path: String) -> Dictionary:
	zip_path = zip_path.strip_edges()

	if zip_path.get_extension().to_lower() != "zip":
		return _failure("Only ZIP packages can be installed.")

	if not FileAccess.file_exists(zip_path):
		return _failure("The dropped ZIP no longer exists.")

	var reader := ZIPReader.new()
	var open_error: Error = reader.open(zip_path)

	if open_error != OK:
		return _failure("The ZIP could not be opened.")

	var archive: Dictionary = _index_archive(reader)

	if not bool(archive.get("ok", false)):
		reader.close()
		return archive

	var indexed_files: Dictionary = archive.get("files", {})
	var package: Dictionary = _identify_package(
		reader,
		indexed_files,
		zip_path
	)

	if not bool(package.get("ok", false)):
		reader.close()
		return package

	var install_result: Dictionary = _extract_and_validate(
		reader,
		indexed_files,
		package
	)
	reader.close()
	return install_result

static func _index_archive(reader: ZIPReader) -> Dictionary:
	var indexed: Dictionary = {}
	var file_count: int = 0

	for raw_path: String in reader.get_files():
		var is_directory: bool = raw_path.ends_with("/")
		var normalized: String = _normalize_archive_path(raw_path)

		if normalized.is_empty():
			if is_directory:
				continue
			return _failure("The ZIP contains an unsafe path.")

		if is_directory:
			continue

		file_count += 1
		if file_count > MAX_ARCHIVE_FILES:
			return _failure("The ZIP contains too many files.")

		var lookup_key: String = normalized.to_lower()
		if indexed.has(lookup_key):
			return _failure("The ZIP contains duplicate file paths.")

		indexed[lookup_key] = {
			"archive_path": raw_path,
			"normalized_path": normalized
		}

	return {
		"ok": true,
		"files": indexed
	}

static func _identify_package(
	reader: ZIPReader,
	indexed_files: Dictionary,
	zip_path: String
) -> Dictionary:
	var manifest_marker: String = _find_shallowest_marker(
		indexed_files,
		"manifest.json"
	)
	var bubble_marker: String = _find_shallowest_marker(
		indexed_files,
		"bubble.json"
	)

	if not manifest_marker.is_empty():
		return _identify_character_package(
			reader,
			indexed_files,
			manifest_marker
		)

	if not bubble_marker.is_empty():
		return _identify_bubble_package(
			reader,
			indexed_files,
			bubble_marker,
			zip_path
		)

	return _failure(
		"No character manifest.json or bubble.json was found."
	)

static func _identify_character_package(
	reader: ZIPReader,
	indexed_files: Dictionary,
	marker: String
) -> Dictionary:
	var manifest: Dictionary = _read_json_dictionary(
		reader,
		indexed_files,
		marker
	)

	if manifest.is_empty():
		return _failure("The character manifest.json is invalid.")

	var pack_id: String = str(manifest.get("id", "")).strip_edges().to_lower()
	if not _is_safe_directory_name(pack_id):
		return _failure("The character pack ID is missing or unsafe.")

	var characters_value: Variant = manifest.get("characters", [])
	if not (characters_value is Array) or (characters_value as Array).is_empty():
		return _failure("The character manifest contains no characters.")

	var prefix: String = marker.trim_suffix("manifest.json")
	for definition_value: Variant in characters_value as Array:
		if not (definition_value is Dictionary):
			return _failure("A character definition is invalid.")

		var definition: Dictionary = definition_value as Dictionary
		var character_id: String = str(
			definition.get("id", "")
		).strip_edges()
		var profile_file: String = _normalize_relative_path(
			str(definition.get("profile_file", ""))
		)

		if not _is_safe_directory_name(character_id):
			return _failure("A character ID is missing or unsafe.")

		if profile_file.is_empty():
			return _failure(character_id + " has no safe profile file.")

		if not indexed_files.has((prefix + profile_file).to_lower()):
			return _failure(character_id + " is missing its profile file.")

	return {
		"ok": true,
		"type": "character",
		"id": pack_id,
		"prefix": prefix,
		"destination_root": DistributionPathsScript.get_characters_directory()
	}

static func _identify_bubble_package(
	reader: ZIPReader,
	indexed_files: Dictionary,
	marker: String,
	zip_path: String
) -> Dictionary:
	var config: Dictionary = _read_json_dictionary(
		reader,
		indexed_files,
		marker
	)

	if config.is_empty():
		return _failure("The bubble.json file is invalid.")

	var prefix: String = marker.trim_suffix("bubble.json")
	for part_name: String in ["top", "middle", "bottom"]:
		var found_part: bool = false
		for extension: String in ["png", "webp", "jpg", "jpeg"]:
			if indexed_files.has(
				(prefix + part_name + "." + extension).to_lower()
			):
				found_part = true
				break

		if not found_part:
			return _failure("The bubble is missing " + part_name + ".")

	var package_name: String = zip_path.get_file().get_basename()
	if not prefix.is_empty():
		package_name = prefix.trim_suffix("/").get_file()
	package_name = _sanitize_directory_name(package_name)

	if package_name.is_empty():
		return _failure("The bubble package has no usable name.")

	return {
		"ok": true,
		"type": "bubble",
		"id": package_name,
		"prefix": prefix,
		"destination_root": DistributionPathsScript.get_bubbles_directory()
	}

static func _extract_and_validate(
	reader: ZIPReader,
	indexed_files: Dictionary,
	package: Dictionary
) -> Dictionary:
	var package_type: String = str(package.get("type", ""))
	var package_id: String = str(package.get("id", ""))
	var prefix: String = str(package.get("prefix", ""))
	var destination_root: String = str(package.get("destination_root", ""))

	if destination_root.is_empty():
		return _failure("The installation folder is unavailable.")

	var root_error: Error = DirAccess.make_dir_recursive_absolute(destination_root)
	if root_error != OK and root_error != ERR_ALREADY_EXISTS:
		return _failure("The installation folder could not be created.")

	var destination_path: String = destination_root.path_join(package_id)
	if DirAccess.dir_exists_absolute(destination_path):
		return _failure(package_id + " is already installed.")

	var staging_path: String = destination_root.path_join(
		".__drop_install_" + str(Time.get_ticks_usec())
	)
	var staging_error: Error = DirAccess.make_dir_recursive_absolute(staging_path)
	if staging_error != OK and staging_error != ERR_ALREADY_EXISTS:
		return _failure("A temporary installation folder could not be created.")

	var total_bytes: int = 0
	for value: Variant in indexed_files.values():
		if not (value is Dictionary):
			continue

		var entry: Dictionary = value as Dictionary
		var normalized_path: String = str(entry.get("normalized_path", ""))
		if not normalized_path.begins_with(prefix):
			continue

		var relative_path: String = normalized_path.trim_prefix(prefix)
		if relative_path.is_empty():
			continue

		var extension: String = relative_path.get_extension().to_lower()
		if BLOCKED_EXTENSIONS.has(extension):
			_remove_tree(staging_path)
			return _failure("The ZIP contains a blocked file type: ." + extension)

		var archive_path: String = str(entry.get("archive_path", ""))
		var bytes: PackedByteArray = reader.read_file(archive_path)
		if bytes.size() > MAX_FILE_BYTES:
			_remove_tree(staging_path)
			return _failure("A file in the ZIP is too large.")

		total_bytes += bytes.size()
		if total_bytes > MAX_TOTAL_BYTES:
			_remove_tree(staging_path)
			return _failure("The ZIP expands beyond the installation limit.")

		var output_path: String = staging_path.path_join(relative_path)
		var parent_error: Error = DirAccess.make_dir_recursive_absolute(
			output_path.get_base_dir()
		)
		if parent_error != OK and parent_error != ERR_ALREADY_EXISTS:
			_remove_tree(staging_path)
			return _failure("An installation subfolder could not be created.")

		var output := FileAccess.open(output_path, FileAccess.WRITE)
		if output == null:
			_remove_tree(staging_path)
			return _failure("A package file could not be written.")
		output.store_buffer(bytes)

	var move_error: Error = DirAccess.rename_absolute(
		staging_path,
		destination_path
	)
	if move_error != OK:
		_remove_tree(staging_path)
		return _failure("The package could not be moved into place.")

	if package_type == "character":
		var validation: Dictionary = CharacterProfiles.validate_profiles(package_id)
		var valid_value: Variant = validation.get("valid", [])
		var invalid_value: Variant = validation.get("invalid", [])
		if (
			not (valid_value is Array)
			or (valid_value as Array).is_empty()
			or (invalid_value is Array and not (invalid_value as Array).is_empty())
		):
			_remove_tree(destination_path)
			return _failure("The installed character profiles did not validate.")
	elif not AppearanceSettingsScript.is_bubble_skin_valid(destination_path):
		_remove_tree(destination_path)
		return _failure("The installed bubble images did not validate.")

	return {
		"ok": true,
		"type": package_type,
		"id": package_id,
		"path": destination_path
	}

static func _find_shallowest_marker(
	indexed_files: Dictionary,
	filename: String
) -> String:
	var result: String = ""

	for value: Variant in indexed_files.values():
		if not (value is Dictionary):
			continue
		var normalized_path: String = str(
			(value as Dictionary).get("normalized_path", "")
		)
		if normalized_path.get_file().to_lower() != filename:
			continue
		if result.is_empty() or normalized_path.count("/") < result.count("/"):
			result = normalized_path

	return result

static func _read_json_dictionary(
	reader: ZIPReader,
	indexed_files: Dictionary,
	normalized_path: String
) -> Dictionary:
	var value: Variant = indexed_files.get(normalized_path.to_lower(), null)
	if not (value is Dictionary):
		return {}

	var archive_path: String = str(
		(value as Dictionary).get("archive_path", "")
	)
	var bytes: PackedByteArray = reader.read_file(archive_path)
	if bytes.is_empty() or bytes.size() > MAX_FILE_BYTES:
		return {}

	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if parsed is Dictionary:
		return (parsed as Dictionary).duplicate(true)
	return {}

static func _normalize_archive_path(path: String) -> String:
	path = path.replace("\\", "/").strip_edges()
	if path.is_empty() or path.begins_with("/") or path.contains(":"):
		return ""

	var components: PackedStringArray = path.split("/", false)
	var safe_components: PackedStringArray = []
	for component: String in components:
		if component.is_empty() or component == "." or component == "..":
			return ""
		safe_components.append(component)

	return "/".join(safe_components)

static func _normalize_relative_path(path: String) -> String:
	return _normalize_archive_path(path)

static func _is_safe_directory_name(value: String) -> bool:
	value = value.strip_edges()
	if value.is_empty() or value == "." or value == ".." or value.begins_with("."):
		return false
	for blocked: String in ["<", ">", ":", "\"", "/", "\\", "|", "?", "*"]:
		if value.contains(blocked):
			return false
	return true

static func _sanitize_directory_name(value: String) -> String:
	value = value.strip_edges()
	for blocked: String in ["<", ">", ":", "\"", "/", "\\", "|", "?", "*"]:
		value = value.replace(blocked, "_")
	while value.begins_with("."):
		value = value.trim_prefix(".")
	return value.strip_edges().left(80)

static func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return

	directory.list_dir_begin()
	while true:
		var entry: String = directory.get_next()
		if entry.is_empty():
			break
		if entry == "." or entry == "..":
			continue
		var child_path: String = path.path_join(entry)
		if directory.current_is_dir():
			_remove_tree(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	directory.list_dir_end()
	DirAccess.remove_absolute(path)

static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"message": message
	}
