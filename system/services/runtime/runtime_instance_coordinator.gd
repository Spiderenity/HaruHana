extends Node
class_name RuntimeInstanceCoordinator

signal command_received(action: String)

const INSTANCE_KINDS: Array[String] = [
	"haruhana",
	"character_creator",
	"bubble_creator",
]
const STATE_DIRECTORY := "user://settings/runtime_instances"
const LOCK_DIRECTORY := "user://settings/runtime_instance_locks"
const COMMAND_DIRECTORY := "user://settings/runtime_instance_commands"
const PUBLISH_INTERVAL_SECONDS := 2.0
const COMMAND_POLL_SECONDS := 0.2
const PLACEMENT_HANDSHAKE_SECONDS := 1.25
const INSTANCE_LEASE_SECONDS := 5.0

var instance_kind := ""
var process_id := 0
var character_manager: DesktopCharacterManager = null
var publish_accumulator := 0.0
var command_accumulator := 0.0
var last_published_rects: Array = []
var has_published := false
var claimed := false
var started_at := 0.0
var placement_generation := 0

func claim(kind: String) -> bool:
	instance_kind = kind.strip_edges().to_lower()
	process_id = OS.get_process_id()
	started_at = Time.get_unix_time_from_system()
	if not INSTANCE_KINDS.has(instance_kind) or process_id <= 0:
		return false
	if not _acquire_instance_lock():
		return false
	claimed = true
	set_process(true)
	publish_now()
	return true

func bind_character_manager(manager: DesktopCharacterManager) -> void:
	character_manager = manager
	if character_manager == null:
		return
	character_manager.set_external_occupied_rects(get_other_character_rects())
	if not character_manager.cast_changed.is_connected(_on_cast_changed):
		character_manager.cast_changed.connect(_on_cast_changed)
	call_deferred("publish_now")
	call_deferred("settle_character_placement")

func get_other_character_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for kind: String in INSTANCE_KINDS:
		if kind == instance_kind:
			continue
		var entry := _load_live_state(kind)
		if entry.is_empty() or not _state_started_before_this_instance(entry):
			continue
		var rect_values: Variant = entry.get("rects", [])
		if not (rect_values is Array):
			continue
		for rect_value: Variant in rect_values as Array:
			if not (rect_value is Dictionary):
				continue
			var data := rect_value as Dictionary
			var rect := Rect2(
				float(data.get("x", 0.0)),
				float(data.get("y", 0.0)),
				float(data.get("width", 0.0)),
				float(data.get("height", 0.0))
			)
			if rect.size.x > 0.0 and rect.size.y > 0.0:
				result.append(rect)
	return result

func _process(delta: float) -> void:
	if not claimed:
		return
	command_accumulator += maxf(0.0, delta)
	if command_accumulator >= COMMAND_POLL_SECONDS:
		command_accumulator = 0.0
		_poll_commands()
	publish_accumulator += maxf(0.0, delta)
	if publish_accumulator < PUBLISH_INTERVAL_SECONDS:
		return
	publish_accumulator = 0.0
	publish_now()

func submit_command(kind: String, action: String) -> bool:
	var normalized_kind := kind.strip_edges().to_lower()
	var normalized_action := action.strip_edges().to_lower()
	if not INSTANCE_KINDS.has(normalized_kind) or normalized_action.is_empty():
		return false
	var directory_path := COMMAND_DIRECTORY.path_join(normalized_kind)
	var absolute_directory := ProjectSettings.globalize_path(directory_path)
	var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return false
	var filename := "%d_%d.json" % [Time.get_ticks_usec(), OS.get_process_id()]
	return _write_json(directory_path.path_join(filename), {
		"action": normalized_action,
		"created": Time.get_unix_time_from_system(),
	}) == OK

func _poll_commands() -> void:
	var directory_path := COMMAND_DIRECTORY.path_join(instance_kind)
	var absolute_directory := ProjectSettings.globalize_path(directory_path)
	if not DirAccess.dir_exists_absolute(absolute_directory):
		return
	for filename: String in DirAccess.get_files_at(absolute_directory):
		if filename.get_extension().to_lower() != "json":
			continue
		var path := directory_path.path_join(filename)
		var command := _read_json(path)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		var action := str(command.get("action", "")).strip_edges().to_lower()
		if not action.is_empty():
			command_received.emit(action)

func _on_cast_changed(_character_ids: Array[String]) -> void:
	call_deferred("publish_now")
	call_deferred("settle_character_placement")

func settle_character_placement() -> void:
	if not claimed or character_manager == null or not is_instance_valid(character_manager):
		return
	placement_generation += 1
	var generation := placement_generation
	await get_tree().process_frame
	var occupied := get_other_character_rects()
	if occupied.is_empty() and _has_earlier_live_instance():
		var deadline := Time.get_ticks_msec() + roundi(PLACEMENT_HANDSHAKE_SECONDS * 1000.0)
		while occupied.is_empty() and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
			if generation != placement_generation:
				return
			occupied = get_other_character_rects()
	if generation != placement_generation or occupied.is_empty():
		return
	character_manager.set_external_occupied_rects(occupied)

func _has_earlier_live_instance() -> bool:
	for kind: String in INSTANCE_KINDS:
		if kind == instance_kind:
			continue
		var entry := _load_live_state(kind)
		if not entry.is_empty() and _state_started_before_this_instance(entry):
			return true
		var owner_state := _read_json(_lock_owner_path(kind))
		var owner_pid := int(owner_state.get("pid", 0))
		if owner_pid > 0 and _entry_has_fresh_lease(owner_state) and _state_started_before_this_instance(owner_state):
			return true
	return false

func _state_started_before_this_instance(state: Dictionary) -> bool:
	var other_started := float(state.get("started", state.get("updated", 0.0)))
	var other_pid := int(state.get("pid", 0))
	if other_started < started_at:
		return true
	if is_equal_approx(other_started, started_at):
		return other_pid < process_id
	return false

func publish_now() -> void:
	if not claimed:
		return
	var rects: Array = []
	if character_manager != null and is_instance_valid(character_manager):
		for rect: Rect2 in character_manager.get_spawned_character_rects():
			rects.append({
				"x": rect.position.x,
				"y": rect.position.y,
				"width": rect.size.x,
				"height": rect.size.y,
			})
	if has_published and rects == last_published_rects:
		return
	has_published = true
	last_published_rects = rects.duplicate(true)
	_write_json(_state_path(instance_kind), {
		"kind": instance_kind,
		"pid": process_id,
		"started": started_at,
		"updated": Time.get_unix_time_from_system(),
		"rects": rects,
	})

func _exit_tree() -> void:
	if not claimed:
		return
	var state := _read_json(_state_path(instance_kind))
	if int(state.get("pid", 0)) == process_id:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_state_path(instance_kind)))
	_release_instance_lock()
	claimed = false

func _acquire_instance_lock() -> bool:
	var lock_parent := ProjectSettings.globalize_path(LOCK_DIRECTORY)
	var directory_error := DirAccess.make_dir_recursive_absolute(lock_parent)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return false
	var lock_path := ProjectSettings.globalize_path(_lock_path(instance_kind))
	for attempt: int in range(3):
		var lock_error := DirAccess.make_dir_absolute(lock_path)
		if lock_error == OK:
			if _write_json(_lock_owner_path(instance_kind), {
				"kind": instance_kind,
				"pid": process_id,
				"started": started_at,
				"created": Time.get_unix_time_from_system(),
				"updated": Time.get_unix_time_from_system(),
			}) == OK:
				return true
			DirAccess.remove_absolute(lock_path)
			return false
		if lock_error != ERR_ALREADY_EXISTS:
			return false
		var owner_state := _read_json(_lock_owner_path(instance_kind))
		var owner_pid := int(owner_state.get("pid", 0))
		if owner_pid > 0 and _entry_has_fresh_lease(owner_state):
			return false
		if owner_pid <= 0:
			OS.delay_msec(35)
			continue
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_lock_owner_path(instance_kind)))
		DirAccess.remove_absolute(lock_path)
	return false

func _release_instance_lock() -> void:
	var owner_state := _read_json(_lock_owner_path(instance_kind))
	if int(owner_state.get("pid", 0)) != process_id:
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_lock_owner_path(instance_kind)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(_lock_path(instance_kind)))

func _load_live_state(kind: String) -> Dictionary:
	var state := _read_json(_state_path(kind))
	var pid := int(state.get("pid", 0))
	if pid > 0 and _entry_has_fresh_lease(state):
		return state
	if not state.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_state_path(kind)))
	return {}

func _entry_has_fresh_lease(entry: Dictionary) -> bool:
	return is_instance_process_running(int(entry.get("pid", 0)))

static func is_instance_process_running(pid: int) -> bool:
	if pid <= 0:
		return false
	if pid == OS.get_process_id() or OS.is_process_running(pid):
		return true
	if OS.get_name() != "Windows":
		return OS.is_process_running(pid)
	# Godot on Windows only tracks children created by this process.
	# Query the OS for independently launched instances; never treat query failure as death.
	var output: Array = []
	var tasklist := OS.get_environment("SystemRoot").path_join("System32/tasklist.exe")
	var result := OS.execute(tasklist, PackedStringArray(["/FI", "PID eq %d" % pid, "/FO", "CSV", "/NH"]), output, false, false)
	if result != 0:
		push_warning("Could not verify running instance; keeping its lock.")
		return true
	for chunk: Variant in output:
		for line: String in str(chunk).split("\n"):
			var fields := line.split(",")
			if fields.size() >= 2 and fields[1].strip_edges().trim_prefix('"').trim_suffix('"') == str(pid):
				return true
	return false

func _read_json(path: String) -> Dictionary:
	return JsonStore.load_dictionary(path, {})

func _write_json(path: String, value: Dictionary) -> Error:
	return JsonStore.save_json(path, value, "	", true, false)

func _state_path(kind: String) -> String:
	return STATE_DIRECTORY.path_join(kind + ".json")

func _lock_path(kind: String) -> String:
	return LOCK_DIRECTORY.path_join(kind)

func _lock_owner_path(kind: String) -> String:
	return _lock_path(kind).path_join("owner.json")
