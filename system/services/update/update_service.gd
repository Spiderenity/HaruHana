extends Node
class_name HaruHanaUpdateService

signal check_started
signal update_available(version: String)
signal up_to_date(version: String)
signal check_failed(message: String)
signal download_started
signal download_progress(downloaded: int, total: int)
signal download_ready
signal download_failed(message: String)
signal installer_preparing
signal installer_ready
signal installer_failed(message: String)

const RELEASE_API: String = "https://api.github.com/repos/Spiderenity/HaruHana/releases?per_page=30"
const RELEASE_ASSET_NAME: String = "HaruHana-Windows-x86_64.zip"
const UPDATER_EXE_NAME: String = "HaruHanaUpdater.exe"
const UPDATE_DIRECTORY: String = "user://updates"
const UPDATE_ZIP_PATH: String = "user://updates/HaruHana-Windows-x86_64.zip"
const UPDATE_ERROR_PATH: String = "user://updates/update_error.txt"
const UPDATER_STATUS_PATH: String = "user://updates/updater_status.json"
const API_HEADERS = [
	"Accept: application/vnd.github+json",
	"X-GitHub-Api-Version: 2026-03-10",
	"User-Agent: HaruHana-Updater"
]

var latest_version: String = ""
var latest_asset_url: String = ""
var latest_asset_digest: String = ""
var latest_asset_size: int = 0
var check_request: HTTPRequest = null
var download_request: HTTPRequest = null
var last_progress_downloaded: int = -1
var last_progress_total: int = -2
var installer_pid: int = 0
var installer_started_msec: int = 0

func _ready() -> void:
	set_process(false)

func get_current_version() -> String:
	return _normalize_version(
		str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	)

func check_for_updates() -> void:
	if check_request != null or download_request != null or installer_pid > 0:
		return

	latest_version = ""
	latest_asset_url = ""
	latest_asset_digest = ""
	latest_asset_size = 0
	check_started.emit()

	check_request = HTTPRequest.new()
	check_request.timeout = 15.0
	check_request.use_threads = true
	add_child(check_request)
	check_request.request_completed.connect(_on_check_completed)
	var error: Error = check_request.request(RELEASE_API, PackedStringArray(API_HEADERS))
	if error != OK:
		_release_check_request()
		check_failed.emit("request_start_failed")

func download_update() -> void:
	if download_request != null or installer_pid > 0 or latest_asset_url.is_empty():
		return

	var directory_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(UPDATE_DIRECTORY)
	)
	if directory_error != OK:
		download_failed.emit("directory_failed")
		return

	var absolute_zip: String = ProjectSettings.globalize_path(UPDATE_ZIP_PATH)
	if FileAccess.file_exists(absolute_zip):
		DirAccess.remove_absolute(absolute_zip)

	download_request = HTTPRequest.new()
	download_request.timeout = 120.0
	download_request.use_threads = true
	download_request.download_file = UPDATE_ZIP_PATH
	add_child(download_request)
	download_request.request_completed.connect(_on_download_completed)
	last_progress_downloaded = -1
	last_progress_total = -2
	set_process(true)
	download_started.emit()

	var error: Error = download_request.request(
		latest_asset_url,
		PackedStringArray(["User-Agent: HaruHana-Updater"])
	)
	if error != OK:
		_release_download_request()
		download_failed.emit("request_start_failed")

func launch_updater() -> Dictionary:
	if OS.get_name() != "Windows" or OS.has_feature("editor"):
		return {"ok": false, "error": "windows_export_required"}

	for kind: String in ["character_creator", "bubble_creator"]:
		var state := JsonStore.load_dictionary("user://settings/runtime_instances/" + kind + ".json", {})
		var pid := int(state.get("pid", 0))
		if pid > 0 and OS.is_process_running(pid):
			return {"ok": false, "error": "close_creators_required"}
	var install_directory: String = OS.get_executable_path().get_base_dir()
	var updater_path: String = install_directory.path_join(UPDATER_EXE_NAME)
	var package_path: String = ProjectSettings.globalize_path(UPDATE_ZIP_PATH)
	var status_path: String = ProjectSettings.globalize_path(UPDATER_STATUS_PATH)
	if not FileAccess.file_exists(updater_path):
		return {"ok": false, "error": "updater_missing"}
	if not FileAccess.file_exists(package_path):
		return {"ok": false, "error": "package_missing"}
	if not _install_directory_is_writable(install_directory):
		return {"ok": false, "error": "install_not_writable"}
	if FileAccess.file_exists(status_path):
		DirAccess.remove_absolute(status_path)

	var arguments: PackedStringArray = PackedStringArray([
		"--apply-update",
		"--wait-pid=" + str(OS.get_process_id()),
		"--package=" + package_path,
		"--install-dir=" + install_directory,
		"--restart=" + OS.get_executable_path(),
		"--status-file=" + status_path
	])
	installer_pid = OS.create_process(updater_path, arguments)
	if installer_pid <= 0:
		installer_pid = 0
		return {"ok": false, "error": "updater_launch_failed"}
	installer_started_msec = Time.get_ticks_msec()
	_update_process_state()
	installer_preparing.emit()
	return {"ok": true, "pid": installer_pid}

func consume_last_update_error() -> String:
	var absolute_path: String = ProjectSettings.globalize_path(UPDATE_ERROR_PATH)
	if not FileAccess.file_exists(absolute_path):
		return ""
	var file: FileAccess = FileAccess.open(absolute_path, FileAccess.READ)
	if file == null:
		return ""
	var message: String = file.get_as_text().strip_edges()
	file.close()
	DirAccess.remove_absolute(absolute_path)
	return message

func _process(_delta: float) -> void:
	if download_request != null:
		var downloaded: int = download_request.get_downloaded_bytes()
		var total: int = download_request.get_body_size()
		if downloaded != last_progress_downloaded or total != last_progress_total:
			last_progress_downloaded = downloaded
			last_progress_total = total
			download_progress.emit(downloaded, total)

	if installer_pid > 0:
		_poll_installer_status()

	_update_process_state()

func _on_check_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_release_check_request()
	if result != HTTPRequest.RESULT_SUCCESS:
		check_failed.emit("network_failed")
		return
	if response_code == 404:
		check_failed.emit("release_missing")
		return
	if response_code != 200:
		check_failed.emit("http_" + str(response_code))
		return

	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if typeof(parsed) != TYPE_ARRAY:
		check_failed.emit("invalid_response")
		return

	var release: Dictionary = _find_latest_release(parsed as Array)
	if release.is_empty():
		check_failed.emit("release_missing")
		return
	var version: String = _normalize_version(str(release.get("tag_name", "")))
	if version.is_empty():
		check_failed.emit("invalid_version")
		return

	var asset: Dictionary = _find_release_asset(release.get("assets", []))
	if asset.is_empty():
		check_failed.emit("asset_missing")
		return

	latest_version = version
	latest_asset_url = str(asset.get("browser_download_url", "")).strip_edges()
	var digest_value: Variant = asset.get("digest", null)
	latest_asset_digest = (
		str(digest_value).strip_edges().to_lower()
		if digest_value is String
		else ""
	)
	latest_asset_size = int(asset.get("size", 0))
	if latest_asset_url.is_empty():
		check_failed.emit("asset_missing")
		return
	if not _is_valid_sha256_digest(latest_asset_digest):
		check_failed.emit("invalid_digest")
		return

	if _is_newer_version(latest_version, get_current_version()):
		update_available.emit(latest_version)
	else:
		up_to_date.emit(latest_version)

func _on_download_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray
) -> void:
	_release_download_request()
	if result != HTTPRequest.RESULT_SUCCESS:
		download_failed.emit("network_failed")
		return
	if response_code < 200 or response_code >= 300:
		download_failed.emit("http_" + str(response_code))
		return

	var absolute_zip: String = ProjectSettings.globalize_path(UPDATE_ZIP_PATH)
	if not FileAccess.file_exists(absolute_zip):
		download_failed.emit("package_missing")
		return
	if latest_asset_size > 0:
		var actual_size: int = FileAccess.get_size(absolute_zip)
		if actual_size != latest_asset_size:
			DirAccess.remove_absolute(absolute_zip)
			download_failed.emit("size_mismatch")
			return
	if not latest_asset_digest.is_empty():
		var digest_error: String = _verify_digest(absolute_zip, latest_asset_digest)
		if not digest_error.is_empty():
			DirAccess.remove_absolute(absolute_zip)
			download_failed.emit(digest_error)
			return
	download_ready.emit()

func _find_release_asset(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_ARRAY:
		return {}
	for item: Variant in value:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var asset: Dictionary = item as Dictionary
		if str(asset.get("name", "")) == RELEASE_ASSET_NAME:
			return asset
	return {}

func _find_latest_release(releases: Array) -> Dictionary:
	var latest: Dictionary = {}
	var latest_version: String = ""
	for item: Variant in releases:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var release: Dictionary = item as Dictionary
		if bool(release.get("draft", false)):
			continue
		var version: String = _normalize_version(str(release.get("tag_name", "")))
		if _parse_version(version).is_empty():
			continue
		if latest.is_empty() or _compare_versions(version, latest_version) > 0:
			latest = release
			latest_version = version
	return latest

func _verify_digest(path: String, expected: String) -> String:
	var normalized_expected: String = expected.strip_edges().to_lower()
	if not normalized_expected.begins_with("sha256:"):
		return "unsupported_digest"
	normalized_expected = normalized_expected.trim_prefix("sha256:")
	var actual: String = FileAccess.get_sha256(path).strip_edges().to_lower()
	if actual.is_empty():
		return "hash_failed"
	if actual != normalized_expected:
		return "digest_mismatch"
	return ""

func _is_valid_sha256_digest(value: String) -> bool:
	var normalized: String = value.strip_edges().to_lower()
	if not normalized.begins_with("sha256:") or normalized.length() != 71:
		return false
	for character: String in normalized.trim_prefix("sha256:"):
		if character not in "0123456789abcdef":
			return false
	return true

func _install_directory_is_writable(directory: String) -> bool:
	var test_path: String = directory.path_join(".haruhana_update_write_test")
	var test_file: FileAccess = FileAccess.open(test_path, FileAccess.WRITE)
	if test_file == null:
		return false
	test_file.store_8(0)
	test_file.close()
	return DirAccess.remove_absolute(test_path) == OK

func _normalize_version(version: String) -> String:
	var normalized: String = version.strip_edges()
	if normalized.begins_with("v") or normalized.begins_with("V"):
		normalized = normalized.substr(1)
	var separator: int = normalized.find("+")
	if separator >= 0:
		normalized = normalized.substr(0, separator)
	return normalized

func _is_newer_version(candidate: String, current: String) -> bool:
	return _compare_versions(candidate, current) > 0

func _compare_versions(first: String, second: String) -> int:
	var first_version: Dictionary = _parse_version(first)
	var second_version: Dictionary = _parse_version(second)
	if first_version.is_empty() or second_version.is_empty():
		return 0

	var first_core: PackedInt32Array = first_version["core"]
	var second_core: PackedInt32Array = second_version["core"]
	for index: int in range(3):
		if first_core[index] != second_core[index]:
			return 1 if first_core[index] > second_core[index] else -1

	var first_pre: PackedStringArray = first_version["prerelease"]
	var second_pre: PackedStringArray = second_version["prerelease"]
	if first_pre.is_empty() and second_pre.is_empty():
		return 0
	if first_pre.is_empty():
		return 1
	if second_pre.is_empty():
		return -1

	var shared_count: int = mini(first_pre.size(), second_pre.size())
	for index: int in range(shared_count):
		var first_identifier: String = first_pre[index]
		var second_identifier: String = second_pre[index]
		if first_identifier == second_identifier:
			continue
		var first_numeric: bool = first_identifier.is_valid_int()
		var second_numeric: bool = second_identifier.is_valid_int()
		if first_numeric and second_numeric:
			return 1 if int(first_identifier) > int(second_identifier) else -1
		if first_numeric != second_numeric:
			return -1 if first_numeric else 1
		return 1 if first_identifier > second_identifier else -1
	if first_pre.size() == second_pre.size():
		return 0
	return 1 if first_pre.size() > second_pre.size() else -1

func _parse_version(version: String) -> Dictionary:
	var normalized: String = _normalize_version(version)
	if normalized.is_empty():
		return {}
	var dash_index: int = normalized.find("-")
	var core_text: String = normalized
	var prerelease_text: String = ""
	if dash_index >= 0:
		core_text = normalized.substr(0, dash_index)
		prerelease_text = normalized.substr(dash_index + 1)
		if prerelease_text.is_empty():
			return {}

	var core_parts: PackedStringArray = core_text.split(".")
	if core_parts.size() != 3:
		return {}
	var core: PackedInt32Array = PackedInt32Array()
	for part: String in core_parts:
		if not part.is_valid_int() or int(part) < 0:
			return {}
		core.append(int(part))

	var prerelease: PackedStringArray = PackedStringArray()
	if not prerelease_text.is_empty():
		prerelease = prerelease_text.split(".")
		for identifier: String in prerelease:
			if not _is_valid_prerelease_identifier(identifier):
				return {}
	return {"core": core, "prerelease": prerelease}

func _is_valid_prerelease_identifier(identifier: String) -> bool:
	if identifier.is_empty():
		return false
	for character: String in identifier:
		if character not in "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-":
			return false
	return true

func _release_check_request() -> void:
	if check_request == null:
		return
	check_request.queue_free()
	check_request = null

func _release_download_request() -> void:
	if download_request == null:
		return
	download_request.queue_free()
	download_request = null
	_update_process_state()

func _poll_installer_status() -> void:
	var status_path: String = ProjectSettings.globalize_path(UPDATER_STATUS_PATH)
	if FileAccess.file_exists(status_path):
		var file: FileAccess = FileAccess.open(status_path, FileAccess.READ)
		if file == null:
			_finish_installer_wait("status_read_failed")
			return
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		file.close()
		DirAccess.remove_absolute(status_path)
		if typeof(parsed) != TYPE_DICTIONARY:
			_finish_installer_wait("status_invalid")
			return
		var status: Dictionary = parsed as Dictionary
		if bool(status.get("ok", false)):
			installer_pid = 0
			installer_started_msec = 0
			installer_ready.emit()
			return
		_finish_installer_wait(str(status.get("error", "updater_prepare_failed")))
		return

	if not OS.is_process_running(installer_pid):
		_finish_installer_wait("updater_exited_early")
		return

	if Time.get_ticks_msec() - installer_started_msec > 120000:
		OS.kill(installer_pid)
		_finish_installer_wait("updater_prepare_timeout")

func _finish_installer_wait(error: String) -> void:
	installer_pid = 0
	installer_started_msec = 0
	installer_failed.emit(error)
	_update_process_state()

func _update_process_state() -> void:
	set_process(download_request != null or installer_pid > 0)
