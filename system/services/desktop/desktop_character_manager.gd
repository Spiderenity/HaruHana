extends Node
class_name DesktopCharacterManager

signal cast_changed(
	character_ids: Array[String]
)

signal startup_boot_started

signal startup_primary_spawned(
	character_id: String,
	has_secondary: bool
)

signal startup_secondary_spawned(
	character_id: String,
	primary_character_id: String
)

signal startup_boot_completed

signal global_settings_changed(
	settings: Dictionary
)

signal package_install_dialogue_requested(
	character_id: String,
	text: String,
	mood: String,
	priority: int
)

signal application_close_requested

signal character_menu_tab_requested(
	character_id: String,
	tab_name: String
)

signal character_menu_talk_action_requested(
	character_id: String,
	action: String,
	detail: String
)

signal character_interactive_question_answered(
	character_id: String,
	answer: Dictionary
)

signal character_interactive_question_dismissed(
	character_id: String,
	reason: String
)

signal character_menu_visibility_changed(
	character_id: String,
	is_open: bool
)

signal character_play_changed(
	character_id: String,
	play_value: float,
	play_max: float
)

signal character_play_interaction(
	character_id: String
)

signal character_play_event(
	character_id: String,
	event_kind: String,
	zone: String,
	play_value: float
)

signal character_unavailable_selected(
	character_id: String,
	remaining_seconds: float,
	lines: Array
)

signal slot_change_requested(
	slot_index: int,
	old_character_id: String,
	new_character_id: String
)

signal slot_change_started(
	slot_index: int,
	old_character_id: String,
	new_character_id: String
)

signal slot_change_completed(
	slot_index: int,
	old_character_id: String,
	new_character_id: String,
	error_code: int
)

const SETTINGS_PATH: String = (
	"user://settings/desktop_characters.json"
)

const MAX_DESKTOP_CHARACTERS: int = 2

const TEMPORARY_ABSENCE_FILENAME: String = (
	"temporary_absences.json"
)

const RuntimeCharacterBuilderScript = preload(
	"res://system/services/desktop/runtime_character_builder.gd"
)

const DropPackageInstallerScript = preload(
	"res://system/services/desktop/drop_package_installer.gd"
)

const AppLanguageScript = preload(
	"res://system/app/app_language.gd"
)

const DEFAULT_STARTUP_SECONDARY_DELAY_SECONDS: float = 4.0
const DEFAULT_INTERACTION_WIDTH: float = 200.0
const DEFAULT_CHARACTER_SCALE: float = 0.75

const STARTUP_WINDOW_SETTLE_FRAMES: int = 2
const OFFSCREEN_WINDOW_POSITION: Vector2i = Vector2i(-32000, -32000)

const STARTUP_BOOT_PREPARE_TIMEOUT_SECONDS: float = 47.0

var spawned_actors: Dictionary = {}

var spawned_windows: Dictionary = {}

var current_character_ids: Array[String] = []

var pending_slot_changes: Dictionary = {}

var absence_check_accumulator: float = 0.0
var last_loaded_pack_id: String = ""

var startup_boot_prepare_released: bool = false
var host_window_clickthrough_on_ready: bool = true
var startup_boot_on_ready: bool = true
var preview_visible_character_limit: int = MAX_DESKTOP_CHARACTERS
var manual_preview_mode: bool = false
var external_occupied_rects: Array[Rect2] = []
var desktop_minimized: bool = false
var focus_timer_seconds_remaining: int = 0
var focus_timer_active: bool = false
var focus_timer_paused: bool = false
var response_loading_sources: Dictionary = {}

func _ready() -> void:
	_connect_host_window_focus_recovery()

	if host_window_clickthrough_on_ready:
		enable_host_window_clickthrough()

	if manual_preview_mode:
		set_process(false)
		return

	last_loaded_pack_id = (
		CharacterProfiles
			.get_current_pack()
			.strip_edges()
			.to_lower()
	)

	call_deferred(
		"reload_desktop_characters",
		startup_boot_on_ready
	)

func _connect_host_window_focus_recovery() -> void:
	var host_window: Window = get_window()

	if host_window == null:
		return

	var focus_callable: Callable = Callable(
		self,
		"_on_host_window_focus_entered"
	)

	if not host_window.focus_entered.is_connected(
		focus_callable
	):
		host_window.focus_entered.connect(
			focus_callable
		)

func _on_host_window_focus_entered() -> void:
	call_deferred("_handle_host_window_focus_restore")

func _handle_host_window_focus_restore() -> void:
	var host_window: Window = get_window()
	if host_window != null and host_window.mode != Window.MODE_MINIMIZED:
		_set_desktop_minimized(false)
	_restore_character_window_order()

func _restore_character_window_order() -> void:
	for actor_value: Variant in spawned_actors.values():
		if not (actor_value is DesktopCharacterActor):
			continue

		var actor: DesktopCharacterActor = (
			actor_value as DesktopCharacterActor
		)

		if not is_instance_valid(actor):
			continue

		actor.restore_desktop_window_order()

func set_focus_timer_state(
	seconds_remaining: int,
	active: bool,
	paused: bool
) -> void:
	focus_timer_seconds_remaining = maxi(0, seconds_remaining)
	focus_timer_active = active
	focus_timer_paused = paused
	_apply_focus_timer_state_to_actors()

func set_character_response_loading(
	character_id: String,
	source: String,
	loading: bool
) -> void:
	character_id = character_id.strip_edges().to_lower()
	source = source.strip_edges().to_lower()
	if character_id.is_empty() or source.is_empty():
		return
	var character_sources: Dictionary = response_loading_sources.get(character_id, {})
	if loading:
		character_sources[source] = true
		response_loading_sources[character_id] = character_sources
	else:
		character_sources.erase(source)
		if character_sources.is_empty():
			response_loading_sources.erase(character_id)
		else:
			response_loading_sources[character_id] = character_sources
	var actor: DesktopCharacterActor = get_actor(character_id)
	if actor != null:
		actor.set_response_loading(source, loading)

func _apply_focus_timer_state_to_actors() -> void:
	var primary_actor: DesktopCharacterActor = null
	for actor_value: Variant in spawned_actors.values():
		if not (actor_value is DesktopCharacterActor):
			continue
		var actor: DesktopCharacterActor = actor_value as DesktopCharacterActor
		if not is_instance_valid(actor):
			continue
		if (
			primary_actor == null
			or actor.get_desktop_slot_index()
				< primary_actor.get_desktop_slot_index()
		):
			primary_actor = actor

	for actor_value: Variant in spawned_actors.values():
		if not (actor_value is DesktopCharacterActor):
			continue
		var actor: DesktopCharacterActor = actor_value as DesktopCharacterActor
		if not is_instance_valid(actor):
			continue
		actor.set_focus_timer_state(
			focus_timer_seconds_remaining,
			focus_timer_active and actor == primary_actor,
			focus_timer_paused
		)

func _process(
	delta: float
) -> void:
	_sync_host_minimize_state()
	_poll_native_file_drops()

	absence_check_accumulator += maxf(
		0.0,
		delta
	)

	if absence_check_accumulator < 1.0:
		return

	absence_check_accumulator = 0.0

	if _restore_temporary_absences(
		false
	):
		reload_desktop_characters()

func _get_mouse_passthrough_singleton() -> Object:
	if OS.get_name() != "Windows":
		return null

	if not Engine.has_singleton("MousePassthrough"):
		return null

	return Engine.get_singleton("MousePassthrough")

func _register_character_drop_target(character_window: Window) -> void:
	if manual_preview_mode or character_window == null:
		return

	var passthrough: Object = _get_mouse_passthrough_singleton()
	if passthrough == null or not passthrough.has_method("set_file_drop_target"):
		return

	passthrough.call(
		"set_passthrough",
		character_window.get_window_id(),
		true
	)
	passthrough.call(
		"set_file_drop_target",
		character_window.get_window_id(),
		true
	)

func _unregister_character_drop_target(character_window: Window) -> void:
	if character_window == null:
		return

	var passthrough: Object = _get_mouse_passthrough_singleton()
	if passthrough == null or not passthrough.has_method("set_file_drop_target"):
		return

	passthrough.call(
		"set_file_drop_target",
		character_window.get_window_id(),
		false
	)

func _poll_native_file_drops() -> void:
	if manual_preview_mode:
		return

	var passthrough: Object = _get_mouse_passthrough_singleton()
	if passthrough == null or not passthrough.has_method("poll_dropped_files"):
		return

	var events_value: Variant = passthrough.call("poll_dropped_files")
	if not (events_value is Array):
		return

	for event_value: Variant in events_value as Array:
		if not (event_value is Dictionary):
			continue
		var event: Dictionary = event_value as Dictionary
		var window_id: int = int(event.get("window_id", -1))
		var files_value: Variant = event.get("files", PackedStringArray())
		if not (files_value is PackedStringArray):
			continue

		for file_path: String in files_value as PackedStringArray:
			_install_dropped_package(window_id, file_path)

func _sync_host_minimize_state() -> void:
	if manual_preview_mode:
		return
	var host_window: Window = get_window()
	if host_window == null:
		return
	_set_desktop_minimized(host_window.mode == Window.MODE_MINIMIZED)

func _set_desktop_minimized(minimized: bool) -> void:
	if desktop_minimized == minimized:
		return
	desktop_minimized = minimized
	for actor_value: Variant in spawned_actors.values():
		if actor_value is DesktopCharacterActor and is_instance_valid(actor_value):
			(actor_value as DesktopCharacterActor).set_desktop_minimized(minimized)

func is_desktop_minimized() -> bool:
	return desktop_minimized

func restore_from_desktop_minimize() -> void:
	var host_window: Window = get_window()
	if host_window != null and host_window.mode == Window.MODE_MINIMIZED:
		host_window.mode = Window.MODE_WINDOWED
	_set_desktop_minimized(false)
	call_deferred("_restore_character_window_order")

func _install_dropped_package(window_id: int, file_path: String) -> void:
	var actor: DesktopCharacterActor = _get_actor_for_window_id(window_id)
	var result: Dictionary = DropPackageInstallerScript.install_zip(file_path)

	if actor == null:
		return

	if not bool(result.get("ok", false)):
		actor.show_speech(
			"설치할 수 없어: " + str(result.get("message", "Invalid package.")),
			6.0,
			"worried"
		)
		return

	var package_type: String = str(result.get("type", ""))
	var announcement: String = AppLanguageScript.text(
		"A new character was added.",
		"새 캐릭터가 추가됐어."
	) if package_type == "character" else AppLanguageScript.text(
		"A new speech bubble was added.",
		"새 말풍선이 추가됐어."
	)
	package_install_dialogue_requested.emit(actor.character_id, announcement, "happy", 30)

func _get_actor_for_window_id(window_id: int) -> DesktopCharacterActor:
	for character_id_value: Variant in spawned_windows:
		var character_id: String = str(character_id_value)
		var window_value: Variant = spawned_windows.get(character_id, null)
		if not (window_value is Window):
			continue
		var character_window: Window = window_value as Window
		if character_window.get_window_id() == window_id:
			return get_actor(character_id)
	return null

func enable_host_window_clickthrough() -> void:
	var host_window: Window = get_window()

	if host_window == null:
		return

	host_window.mouse_passthrough_polygon = (
		PackedVector2Array()
	)

	host_window.mouse_passthrough = true
	# The root hosts taskbar actions only; every visible surface has its own window.
	# Keep its native bounds away from desktop icons even if passthrough is reset.
	host_window.min_size = Vector2i.ONE
	host_window.max_size = Vector2i.ONE
	host_window.size = Vector2i.ONE
	host_window.position = OFFSCREEN_WINDOW_POSITION


func _wait_for_startup_window_settle() -> void:
	for _frame_index: int in range(
		STARTUP_WINDOW_SETTLE_FRAMES
	):
		await get_tree().process_frame

func release_startup_boot_preparation() -> void:
	startup_boot_prepare_released = true

func _wait_for_startup_boot_preparation() -> void:
	var started_msec: int = Time.get_ticks_msec()
	var timeout_msec: int = int(
		STARTUP_BOOT_PREPARE_TIMEOUT_SECONDS
		* 1000.0
	)

	while not startup_boot_prepare_released:
		if (
			Time.get_ticks_msec()
			- started_msec
			>= timeout_msec
		):
			push_warning(
				"DesktopCharacterManager: startup boot preparation "
				+ "did not release within "
				+ str(STARTUP_BOOT_PREPARE_TIMEOUT_SECONDS)
				+ " seconds; continuing with local fallback."
			)

			break

		await get_tree().process_frame

	startup_boot_prepare_released = false

func reload_desktop_characters(
	startup_boot: bool = false
) -> void:
	var current_pack_id: String = (
		CharacterProfiles
			.get_current_pack()
			.strip_edges()
			.to_lower()
	)

	if (
		not last_loaded_pack_id.is_empty()
		and not current_pack_id.is_empty()
		and current_pack_id != last_loaded_pack_id
	):
		_restore_temporary_absences(
			true
		)

	last_loaded_pack_id = current_pack_id

	clear_spawned_characters()

	var settings: Dictionary = (
		load_settings()
	)

	var pack_settings: Dictionary = (
		get_current_pack_settings(
			settings
		)
	)

	var slots: Array[String] = []

	if pack_settings.has(
		"slots"
	):
		slots = (
			get_requested_slots(
				pack_settings
			)
		)
	else:
		slots = (
			_build_default_slots(
				pack_settings
			)
		)

	var had_requested_character := slots.any(func(id: String) -> bool: return not id.is_empty())
	for slot_index: int in range(
		MAX_DESKTOP_CHARACTERS
	):
		var requested_character_id: String = (
			slots[slot_index]
		)

		if requested_character_id.is_empty():
			continue

		if not is_character_allowed_in_slot(
			requested_character_id,
			slot_index
		):
			slots[slot_index] = ""

			continue

		if not is_character_usable(
			requested_character_id,
			pack_settings
		):
			slots[slot_index] = ""

	if (
		not slots[0].is_empty()
		and slots[0] == slots[1]
	):
		slots[1] = ""

	if had_requested_character and slots.all(func(id: String) -> bool: return id.is_empty()) and CharacterProfiles.get_current_pack() == CharacterProfiles.DEFAULT_PACK_ID:
		slots[0] = "crt"

	pack_settings["slots"] = (
		slots.duplicate()
	)

	store_current_pack_settings(
		settings,
		pack_settings
	)

	save_settings(
		settings
	)

	var nonempty_slots: Array[int] = []

	for slot_index: int in range(
		MAX_DESKTOP_CHARACTERS
	):
		if not slots[
			slot_index
		].is_empty():
			nonempty_slots.append(
				slot_index
			)

	if (
		startup_boot
		and not nonempty_slots.is_empty()
	):
		startup_boot_prepare_released = false
		startup_boot_started.emit()

		var primary_slot: int = nonempty_slots[0]
		var primary_id: String = slots[
			primary_slot
		]

		var primary_partner_width_hint: float = -1.0

		if nonempty_slots.size() >= 2:
			var future_secondary_slot: int = nonempty_slots[1]
			var future_secondary_id: String = slots[
				future_secondary_slot
			]
			primary_partner_width_hint = (
				_estimate_character_pet_width(
					future_secondary_id,
					pack_settings
				)
			)

		var primary_actor: Node = (
			spawn_character(
				primary_id,
				primary_slot,
				pack_settings,
				nonempty_slots.size() >= 2,
				primary_partner_width_hint
			)
		)

		if primary_actor != null:
			current_character_ids.append(
				primary_id
			)

		cast_changed.emit(
			current_character_ids.duplicate()
		)

		await _wait_for_startup_window_settle()

		await _wait_for_startup_boot_preparation()

		startup_primary_spawned.emit(
			primary_id,
			nonempty_slots.size() >= 2
		)

		if nonempty_slots.size() >= 2:
			await get_tree().create_timer(
				DEFAULT_STARTUP_SECONDARY_DELAY_SECONDS
			).timeout

			var secondary_slot: int = nonempty_slots[1]
			var secondary_id: String = slots[
				secondary_slot
			]

			var primary_width_hint: float = (
				_estimate_character_pet_width(
					primary_id,
					pack_settings
				)
			)

			var secondary_actor: Node = (
				spawn_character(
					secondary_id,
					secondary_slot,
					pack_settings,
					true,
					primary_width_hint
				)
			)

			if secondary_actor != null:
				current_character_ids.append(
					secondary_id
				)

			cast_changed.emit(
				current_character_ids.duplicate()
			)

			await _wait_for_startup_window_settle()

			startup_secondary_spawned.emit(
				secondary_id,
				primary_id
			)

			_clear_initial_pair_layout_reservations()

		startup_boot_completed.emit()
		return

	for slot_index: int in range(
		MAX_DESKTOP_CHARACTERS
	):
		var spawned_character_id: String = (
			slots[slot_index]
		)

		if spawned_character_id.is_empty():
			continue

		var reserve_pair_layout: bool = (
			nonempty_slots.size() >= 2
		)
		var partner_width_hint: float = -1.0

		if reserve_pair_layout:
			var partner_slot: int = (
				1
				if slot_index == 0
				else 0
			)
			var partner_id: String = slots[partner_slot]

			if not partner_id.is_empty():
				partner_width_hint = (
					_estimate_character_pet_width(
						partner_id,
						pack_settings
					)
				)

		var actor: Node = (
			spawn_character(
				spawned_character_id,
				slot_index,
				pack_settings,
				reserve_pair_layout,
				partner_width_hint
			)
		)

		if actor == null:
			continue

		current_character_ids.append(
			spawned_character_id
		)

	_clear_initial_pair_layout_reservations()

	cast_changed.emit(
		current_character_ids.duplicate()
	)

func get_active_character_ids() -> Array[String]:
	return current_character_ids.duplicate()

func set_external_occupied_rects(rects: Array[Rect2]) -> void:
	external_occupied_rects = rects.duplicate()
	call_deferred("_refresh_spawned_default_layout")

func get_spawned_character_rects() -> Array[Rect2]:
	var result: Array[Rect2] = []
	for character_id: String in current_character_ids:
		var actor: DesktopCharacterActor = get_actor(character_id)
		var window_value: Variant = spawned_windows.get(character_id, null)
		if actor == null or not (window_value is Window):
			continue
		if not (window_value as Window).visible:
			continue
		var rect: Rect2 = actor.get_desktop_pet_rect()
		if rect.size != Vector2.ZERO:
			result.append(rect)
	return result

func get_preferred_preview_specs(limit: int = MAX_DESKTOP_CHARACTERS) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var pack_ids: Array[String] = []
	if CharacterProfiles.pack_exists(CharacterProfiles.DEFAULT_PACK_ID):
		pack_ids.append(CharacterProfiles.DEFAULT_PACK_ID)
	var current_pack := CharacterProfiles.get_current_pack()
	if not current_pack.is_empty() and not pack_ids.has(current_pack):
		pack_ids.append(current_pack)
	for pack_id: String in pack_ids:
		var character_ids: Array[String] = CharacterProfiles.get_pack_character_ids(pack_id)
		if pack_id == CharacterProfiles.DEFAULT_PACK_ID:
			var ordered: Array[String] = []
			for preferred_id: String in ["crt", "chip"]:
				if character_ids.has(preferred_id):
					ordered.append(preferred_id)
			for character_id: String in character_ids:
				if not ordered.has(character_id):
					ordered.append(character_id)
			character_ids = ordered
		for character_id: String in character_ids:
			if result.size() >= limit:
				break
			if CharacterProfiles.load_profile(character_id, pack_id).is_empty():
				continue
			if not RuntimeCharacterBuilderScript.can_build(pack_id, character_id, "default"):
				continue
			result.append({"character_id": character_id, "pack_id": pack_id, "blank": false})
		if not result.is_empty():
			break
	while result.size() < limit:
		result.append({
			"character_id": "preview_blank_%d" % (result.size() + 1),
			"pack_id": "",
			"blank": true,
		})
	return result

func spawn_preview_cast(specs: Array[Dictionary]) -> Array[DesktopCharacterActor]:
	clear_spawned_characters()
	var actors: Array[DesktopCharacterActor] = []
	for index: int in range(mini(specs.size(), MAX_DESKTOP_CHARACTERS)):
		var spec: Dictionary = specs[index]
		var character_id := str(spec.get("character_id", "preview_blank_%d" % (index + 1)))
		var actor: DesktopCharacterActor = null
		if not bool(spec.get("blank", false)):
			actor = spawn_character(
				character_id,
				index,
				{},
				specs.size() > 1,
				400.0,
				str(spec.get("pack_id", ""))
			)
		if actor == null:
			actor = _spawn_blank_preview_character(character_id, index, specs.size() > 1)
		if actor == null:
			continue
		actor.set_character_menu_enabled(false)
		actors.append(actor)
		current_character_ids.append(character_id)
	_clear_initial_pair_layout_reservations()
	cast_changed.emit(current_character_ids.duplicate())
	call_deferred("_refresh_spawned_default_layout")
	return actors

func set_preview_visible_character_limit(limit: int) -> void:
	preview_visible_character_limit = clampi(limit, 1, MAX_DESKTOP_CHARACTERS)
	for index: int in range(current_character_ids.size()):
		var character_id: String = current_character_ids[index]
		var window_value: Variant = spawned_windows.get(character_id, null)
		if not (window_value is Window):
			continue
		var character_window: Window = window_value as Window
		if index < preview_visible_character_limit:
			character_window.show()
		else:
			character_window.hide()

func get_slot_character_ids() -> Array[String]:
	var settings: Dictionary = (
		load_settings()
	)

	var pack_settings: Dictionary = (
		get_current_pack_settings(
			settings
		)
	)

	return get_requested_slots(
		pack_settings
	)

func get_actor(
	character_id: String
) -> DesktopCharacterActor:
	character_id = character_id.strip_edges().to_lower()
	var actor_value: Variant = spawned_actors.get(character_id, null)
	if actor_value is DesktopCharacterActor:
		return actor_value as DesktopCharacterActor
	return null

func get_character_preferences(
	character_id: String
) -> Dictionary:
	character_id = character_id.strip_edges().to_lower()
	if CharacterProfiles.load_profile(character_id).is_empty():
		return {}

	var settings: Dictionary = load_settings()
	var pack_settings: Dictionary = get_current_pack_settings(settings)
	var behavior: Dictionary = get_behavior_settings(
		character_id,
		pack_settings
	)

	return {
		"skin": _get_saved_skin_id(character_id, pack_settings),
		"ambient_dialogue": bool(
			behavior.get("ambient_dialogue", true)
		),
		"timer_reactions": bool(
			behavior.get("timer_reactions", true)
		),
	}

func apply_slot_settings(
	slot_index: int,
	character_id: String,
	skin_id: String,
	ambient_enabled: bool,
	timer_enabled: bool
) -> Error:

	if (
		slot_index < 0
		or slot_index
			>= MAX_DESKTOP_CHARACTERS
	):
		return ERR_INVALID_PARAMETER

	character_id = (
		character_id
			.strip_edges()
			.to_lower()
	)

	skin_id = skin_id.strip_edges()

	if not character_id.is_empty():
		var absence: Dictionary = (
			_get_active_temporary_absence(
				character_id
			)
		)

		if not absence.is_empty():
			var remaining_seconds: float = maxf(
				0.0,
				float(
					int(
						absence.get(
							"until_unix",
							0
						)
					)
					- int(
						Time.get_unix_time_from_system()
					)
				)
			)

			var lines_value: Variant = absence.get(
				"unavailable_lines",
				[]
			)

			var lines: Array = []

			if lines_value is Array:
				lines = (
					lines_value as Array
				).duplicate(
					true
				)

			character_unavailable_selected.emit(
				character_id,
				remaining_seconds,
				lines
			)

			return ERR_BUSY

	var settings: Dictionary = (
		load_settings()
	)

	var pack_settings: Dictionary = (
		get_current_pack_settings(
			settings
		)
	)

	var slots: Array[String] = (
		get_requested_slots(
			pack_settings
		)
	)

	var old_character_id: String = (
		slots[
			slot_index
		]
	)

	if character_id == old_character_id:
		return _save_slot_settings_now(
			slot_index,
			character_id,
			skin_id,
			ambient_enabled,
			timer_enabled
		)

	if not pending_slot_changes.is_empty():
		return ERR_BUSY

	if not character_id.is_empty():
		for other_slot: int in range(
			MAX_DESKTOP_CHARACTERS
		):
			if other_slot == slot_index:
				continue

			if slots[other_slot] == character_id:
				return ERR_INVALID_PARAMETER

		if not is_character_allowed_in_slot(
			character_id,
			slot_index
		):
			return ERR_INVALID_PARAMETER

		var profile: Dictionary = (
			CharacterProfiles.load_profile(
				character_id
			)
		)

		if profile.is_empty():
			return ERR_FILE_NOT_FOUND

		var available_skins: Array[String] = (
			get_available_skins(
				character_id
			)
		)

		if not available_skins.has(
			skin_id
		):
			return ERR_DOES_NOT_EXIST

	var pending: Dictionary = {
		"slot_index": slot_index,
		"old_character_id": old_character_id,
		"new_character_id": character_id,
		"skin_id": skin_id,
		"ambient_enabled": ambient_enabled,
		"timer_enabled": timer_enabled
	}

	pending_slot_changes[
		slot_index
	] = pending

	slot_change_started.emit(
		slot_index,
		old_character_id,
		character_id
	)

	slot_change_requested.emit(
		slot_index,
		old_character_id,
		character_id
	)

	return OK

func commit_pending_slot_change(
	slot_index: int
) -> Error:

	var pending_value: Variant = (
		pending_slot_changes.get(
			slot_index,
			null
		)
	)

	if not (
		pending_value is Dictionary
	):
		return ERR_DOES_NOT_EXIST

	var pending: Dictionary = (
		pending_value
	)

	if bool(
		pending.get(
			"committed",
			false
		)
	):
		return ERR_BUSY

	var new_character_id: String = str(
		pending.get(
			"new_character_id",
			""
		)
	)

	var skin_id: String = str(
		pending.get(
			"skin_id",
			""
		)
	)

	var ambient_enabled: bool = bool(
		pending.get(
			"ambient_enabled",
			true
		)
	)

	var timer_enabled: bool = bool(
		pending.get(
			"timer_enabled",
			true
		)
	)

	var save_error: Error = (
		_save_slot_settings_now(
			slot_index,
			new_character_id,
			skin_id,
			ambient_enabled,
			timer_enabled
		)
	)

	if save_error != OK:
		finish_pending_slot_change(
			slot_index,
			int(
				save_error
			)
		)

		return save_error

	pending[
		"committed"
	] = true

	pending_slot_changes[
		slot_index
	] = pending

	return OK

func finish_pending_slot_change(
	slot_index: int,
	error_code: int = OK
) -> void:

	var pending_value: Variant = (
		pending_slot_changes.get(
			slot_index,
			null
		)
	)

	if not (
		pending_value is Dictionary
	):
		return

	var pending: Dictionary = (
		pending_value
	)

	var old_character_id: String = str(
		pending.get(
			"old_character_id",
			""
		)
	)

	var new_character_id: String = str(
		pending.get(
			"new_character_id",
			""
		)
	)

	pending_slot_changes.erase(
		slot_index
	)

	slot_change_completed.emit(
		slot_index,
		old_character_id,
		new_character_id,
		error_code
	)

func _save_slot_settings_now(
	slot_index: int,
	character_id: String,
	skin_id: String,
	ambient_enabled: bool,
	timer_enabled: bool
) -> Error:

	if (
		slot_index < 0
		or slot_index
			>= MAX_DESKTOP_CHARACTERS
	):
		return ERR_INVALID_PARAMETER

	character_id = (
		character_id
			.strip_edges()
			.to_lower()
	)

	skin_id = skin_id.strip_edges()

	var settings: Dictionary = (
		load_settings()
	)

	var pack_settings: Dictionary = (
		get_current_pack_settings(
			settings
		)
	)

	var slots: Array[String] = (
		get_requested_slots(
			pack_settings
		)
	)

	if not character_id.is_empty():
		for other_slot: int in range(
			MAX_DESKTOP_CHARACTERS
		):
			if other_slot == slot_index:
				continue

			if slots[other_slot] == character_id:
				return ERR_INVALID_PARAMETER

		if not is_character_allowed_in_slot(
			character_id,
			slot_index
		):
			return ERR_INVALID_PARAMETER

		var profile: Dictionary = (
			CharacterProfiles.load_profile(
				character_id
			)
		)

		if profile.is_empty():
			return ERR_FILE_NOT_FOUND

		var available_skins: Array[String] = (
			get_available_skins(
				character_id
			)
		)

		if not available_skins.has(
			skin_id
		):
			return ERR_DOES_NOT_EXIST

	slots[
		slot_index
	] = character_id

	pack_settings["slots"] = (
		slots.duplicate()
	)

	if not character_id.is_empty():
		var skins_value: Variant = (
			pack_settings.get(
				"skins",
				{}
			)
		)

		var skins: Dictionary = {}

		if skins_value is Dictionary:
			skins = skins_value

		skins[
			character_id
		] = skin_id

		pack_settings[
			"skins"
		] = skins

		var behavior_value: Variant = (
			pack_settings.get(
				"behavior",
				{}
			)
		)

		var behavior: Dictionary = {}

		if behavior_value is Dictionary:
			behavior = behavior_value

		behavior[
			character_id
		] = {
			"ambient_dialogue": ambient_enabled,
			"timer_reactions": timer_enabled
		}

		pack_settings[
			"behavior"
		] = behavior

	store_current_pack_settings(
		settings,
		pack_settings
	)

	var save_error: Error = (
		save_settings(
			settings
		)
	)

	if save_error != OK:
		return save_error

	reload_desktop_characters()

	return OK

func get_available_skins(
	character_id: String
) -> Array[String]:
	character_id = character_id.strip_edges().to_lower()
	if CharacterProfiles.load_profile(character_id).is_empty():
		return []

	return RuntimeCharacterBuilderScript.get_available_skins(
		CharacterProfiles.get_current_pack(),
		character_id
	)

func is_character_allowed_in_slot(
	character_id: String,
	slot_index: int
) -> bool:

	if (
		slot_index < 0
		or slot_index
			>= MAX_DESKTOP_CHARACTERS
	):
		return false

	character_id = (
		character_id
			.strip_edges()
			.to_lower()
	)

	if character_id.is_empty():
		return false

	var profile: Dictionary = (
		CharacterProfiles.load_profile(
			character_id
		)
	)

	if profile.is_empty():
		return false

	var desktop: Dictionary = (
		get_desktop_config(
			profile
		)
	)

	if desktop.is_empty():
		return false

	var default_on_desktop: bool = bool(
		desktop.get(
			"default_on_desktop",
			false
		)
	)

	if slot_index == 0:
		return default_on_desktop

	return not default_on_desktop

func get_desktop_character_diagnostic(
	character_id: String
) -> Dictionary:
	character_id = character_id.strip_edges().to_lower()
	if character_id.is_empty():
		return {
			"usable": false,
			"reason": "Character ID is empty.",
		}

	if CharacterProfiles.load_profile(character_id).is_empty():
		return {
			"usable": false,
			"reason": "Profile could not be loaded for " + character_id + ".",
		}

	var skins: Array[String] = get_available_skins(character_id)
	if skins.is_empty():
		return {
			"usable": false,
			"reason": "No usable sprite set was found.",
		}

	return {
		"usable": true,
		"reason": "Ready (runtime sprites).",
		"skin_id": skins[0],
	}

func make_empty_slots() -> Array[String]:
	var result: Array[String] = []

	for _index: int in range(
		MAX_DESKTOP_CHARACTERS
	):
		result.append(
			""
		)

	return result

func _build_default_slots(
	pack_settings: Dictionary
) -> Array[String]:
	var result: Array[String] = make_empty_slots()
	var pack_id: String = (
		CharacterProfiles
			.get_current_pack()
			.strip_edges()
			.to_lower()
	)

	if pack_id.is_empty():
		return result

	var character_ids: Array[String] = (
		CharacterProfiles.get_pack_character_ids(
			pack_id
		)
	)

	for slot_index: int in range(
		MAX_DESKTOP_CHARACTERS
	):
		for character_id: String in character_ids:
			if result.has(
				character_id
			):
				continue

			if not is_character_allowed_in_slot(
				character_id,
				slot_index
			):
				continue

			if not is_character_usable(
				character_id,
				pack_settings
			):
				continue

			result[
				slot_index
			] = character_id
			break

	return result

func get_requested_slots(
	pack_settings: Dictionary
) -> Array[String]:
	var result: Array[String] = make_empty_slots()
	var slots_value: Variant = pack_settings.get("slots", [])

	if not (slots_value is Array):
		return result

	var source_slots: Array = slots_value
	for index: int in range(
		mini(source_slots.size(), MAX_DESKTOP_CHARACTERS)
	):
		result[index] = str(
			source_slots[index]
		).strip_edges().to_lower()

	return result

func is_character_usable(
	character_id: String,
	pack_settings: Dictionary
) -> bool:
	if CharacterProfiles.load_profile(character_id).is_empty():
		return false

	var skin_id: String = _get_saved_skin_id(
		character_id,
		pack_settings
	)
	if skin_id.is_empty():
		return false

	return RuntimeCharacterBuilderScript.can_build(
		CharacterProfiles.get_current_pack(),
		character_id,
		skin_id
	)

func _estimate_character_pet_width(
	character_id: String,
	pack_settings: Dictionary
) -> float:
	var width: float = DEFAULT_INTERACTION_WIDTH
	if CharacterProfiles.load_profile(character_id).is_empty():
		return width

	var skin_id: String = _get_saved_skin_id(
		character_id,
		pack_settings
	)
	var runtime_width: float = RuntimeCharacterBuilderScript.get_alpha_width_hint(
		CharacterProfiles.get_current_pack(),
		character_id,
		skin_id
	)

	if runtime_width > 0.0:
		width = runtime_width

	var global_settings: Dictionary = (
		get_global_desktop_settings()
	)
	var character_scale: float = clampf(
		float(
			global_settings.get(
				"character_scale",
				DEFAULT_CHARACTER_SCALE
			)
		),
		0.50,
		1.50
	)

	return width * character_scale

func _set_initial_pair_layout(
	actor: DesktopCharacterActor,
	reserve_pair_layout: bool,
	partner_width_hint: float
) -> void:
	if actor == null or actor.pet_interaction == null:
		return
	actor.pet_interaction.configure_initial_pair_layout(
		reserve_pair_layout,
		partner_width_hint
	)

func _clear_initial_pair_layout_reservations() -> void:
	for actor_value: Variant in spawned_actors.values():
		if not (actor_value is DesktopCharacterActor):
			continue
		var actor: DesktopCharacterActor = actor_value as DesktopCharacterActor
		if not is_instance_valid(actor) or actor.pet_interaction == null:
			continue
		actor.pet_interaction.clear_initial_pair_layout()

func spawn_character(
	character_id: String,
	slot_index: int,
	pack_settings: Dictionary,
	reserve_pair_layout: bool = false,
	partner_width_hint: float = -1.0,
	pack_id_override: String = ""
) -> DesktopCharacterActor:
	var profile: Dictionary = CharacterProfiles.load_profile(character_id, pack_id_override)
	if profile.is_empty():
		return null

	var pack_id: String = pack_id_override.strip_edges().to_lower()
	if pack_id.is_empty():
		pack_id = CharacterProfiles.get_current_pack()
	var skin_id: String = _get_saved_skin_id(character_id, pack_settings)

	if not RuntimeCharacterBuilderScript.can_build(pack_id, character_id, skin_id):
		push_error("Character has no usable runtime sprites: " + character_id)
		return null

	var actor: DesktopCharacterActor = RuntimeCharacterBuilderScript.build_actor(
		pack_id, character_id, skin_id
	)
	if actor == null:
		push_error("Runtime character build failed: " + character_id)
		return null

	actor.set_meta("preferences_pack", pack_id)
	actor.set_meta("progress_rewards_enabled", not manual_preview_mode)
	actor.set_meta("remember_desktop_position", host_window_clickthrough_on_ready)
	actor.configure_character_id(character_id)
	actor.configure_desktop_slot(slot_index)
	_set_initial_pair_layout(actor, reserve_pair_layout, partner_width_hint)

	var behavior: Dictionary = get_behavior_settings(character_id, pack_settings)
	var global_settings: Dictionary = get_global_desktop_settings()
	actor.configure_display(
		float(global_settings.get("base_opacity", 0.82)),
		float(global_settings.get("character_scale", DEFAULT_CHARACTER_SCALE)),
		float(global_settings.get("bubble_scale", 1.0)),
		float(global_settings.get("bubble_opacity", 1.0))
	)
	actor.configure_behavior(
		bool(behavior.get("ambient_dialogue", true)),
		bool(behavior.get("timer_reactions", true))
	)

	actor.name = "DesktopCharacter_" + character_id
	var character_window: Window = create_character_window(
		character_id, actor.get_character_window_size()
	)
	if character_window == null:
		actor.queue_free()
		return null

	character_window.add_child(actor)
	if actor.pet_interaction != null:
		actor.pet_interaction.move_to_default_position()
	actor.configure_desktop_interaction(
		bool(global_settings.get("vertical_movement_enabled", false)),
		bool(global_settings.get("bubble_drag_enabled", true)),
		get_speech_bubble_offset(character_id, pack_id)
	)
	_show_character_window_when_ready(character_window)
	_register_character_drop_target(character_window)

	actor.menu_tab_requested.connect(_on_actor_menu_tab_requested)
	actor.menu_talk_action_requested.connect(_on_actor_menu_talk_action_requested)
	actor.interactive_question_answered.connect(_on_actor_interactive_question_answered)
	actor.interactive_question_dismissed.connect(_on_actor_interactive_question_dismissed)
	actor.menu_visibility_changed.connect(_on_actor_menu_visibility_changed)
	actor.play_changed.connect(_on_actor_play_changed)
	actor.play_interaction_activity.connect(_on_actor_play_interaction_activity)
	actor.play_event_requested.connect(_on_actor_play_event_requested)
	actor.temporary_departure_requested.connect(_on_actor_temporary_departure_requested)
	actor.speech_bubble_offset_changed.connect(_on_actor_speech_bubble_offset_changed)
	actor.application_close_requested.connect(_on_character_window_close_requested)

	spawned_actors[character_id] = actor
	spawned_windows[character_id] = character_window
	_apply_focus_timer_state_to_actors()
	var loading_sources: Dictionary = response_loading_sources.get(character_id, {})
	for source_value: Variant in loading_sources.keys():
		actor.set_response_loading(str(source_value), true)
	call_deferred("_refresh_spawned_default_layout")
	return actor

func _spawn_blank_preview_character(
	character_id: String,
	slot_index: int,
	reserve_pair_layout: bool
) -> DesktopCharacterActor:
	var actor: DesktopCharacterActor = RuntimeCharacterBuilderScript.build_blank_preview_actor()
	if actor == null:
		return null
	actor.configure_character_id(character_id)
	actor.configure_desktop_slot(slot_index)
	_set_initial_pair_layout(actor, reserve_pair_layout, 400.0)
	var global_settings: Dictionary = get_global_desktop_settings()
	actor.configure_display(
		float(global_settings.get("base_opacity", 0.82)),
		float(global_settings.get("character_scale", DEFAULT_CHARACTER_SCALE)),
		float(global_settings.get("bubble_scale", 1.0)),
		float(global_settings.get("bubble_opacity", 1.0))
	)
	actor.configure_behavior(false, false)
	actor.name = "DesktopCharacter_" + character_id
	var character_window: Window = create_character_window(
		character_id, actor.get_character_window_size()
	)
	if character_window == null:
		actor.queue_free()
		return null
	character_window.add_child(actor)
	if actor.pet_interaction != null:
		actor.pet_interaction.move_to_default_position()
	_show_character_window_when_ready(character_window)
	_register_character_drop_target(character_window)
	spawned_actors[character_id] = actor
	spawned_windows[character_id] = character_window
	return actor

func _refresh_spawned_default_layout() -> void:
	await get_tree().process_frame
	while _character_window_is_priming():
		await get_tree().process_frame

	for actor_value: Variant in spawned_actors.values():
		if not (actor_value is DesktopCharacterActor):
			continue
		var actor: DesktopCharacterActor = actor_value as DesktopCharacterActor
		if not is_instance_valid(actor) or actor.pet_interaction == null:
			continue
		actor.pet_interaction.move_to_default_position()
		break

	await get_tree().process_frame
	_place_spawned_cast_in_leftmost_available_space()

func _character_window_is_priming() -> bool:
	for window_value: Variant in spawned_windows.values():
		if window_value is Window and (window_value as Window).has_meta(&"priming"):
			if bool((window_value as Window).get_meta(&"priming")):
				return true
	return false

func _place_spawned_cast_in_leftmost_available_space() -> void:
	for actor_value: Variant in spawned_actors.values():
		if is_instance_valid(actor_value) and actor_value.pet_interaction != null and actor_value.pet_interaction.has_saved_position():
			return
	if external_occupied_rects.is_empty():
		return
	var actor_rects: Array[Rect2] = get_spawned_character_rects()
	if actor_rects.is_empty():
		return
	var group_rect: Rect2 = actor_rects[0]
	var gap := 48.0
	for index: int in range(actor_rects.size()):
		if index > 0:
			group_rect = group_rect.merge(actor_rects[index])
		var actor: DesktopCharacterActor = get_actor(current_character_ids[index])
		if actor != null:
			gap = maxf(gap, actor.get_default_desktop_character_gap())
	var usable := Rect2(DisplayServer.screen_get_usable_rect())
	var candidate_left := maxf(usable.position.x, group_rect.position.x)
	var relevant: Array[Rect2] = []
	for rect: Rect2 in external_occupied_rects:
		if rect.size == Vector2.ZERO:
			continue
		if rect.end.y <= group_rect.position.y or rect.position.y >= group_rect.end.y:
			continue
		relevant.append(rect)
	relevant.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	var searching := true
	while searching:
		searching = false
		var candidate := Rect2(candidate_left, group_rect.position.y, group_rect.size.x, group_rect.size.y)
		for obstacle: Rect2 in relevant:
			var padded := Rect2(
				obstacle.position.x - gap,
				obstacle.position.y,
				obstacle.size.x + gap * 2.0,
				obstacle.size.y
			)
			if candidate.intersects(padded):
				candidate_left = obstacle.end.x + gap
				searching = true
				break
	if candidate_left + group_rect.size.x > usable.end.x:
		return
	var shift := candidate_left - group_rect.position.x
	if is_zero_approx(shift):
		return
	for index: int in range(actor_rects.size()):
		var actor: DesktopCharacterActor = get_actor(current_character_ids[index])
		if actor != null:
			actor.slide_desktop_pet_to_left(actor_rects[index].position.x + shift, 0.05)

func create_character_window(
	character_id: String,
	window_size: Vector2i = Vector2i(400, 600)
) -> Window:

	var window_container: Node = (
		get_parent()
	)

	if window_container == null:
		return null

	var host_window: Window = (
		get_window()
	)

	if host_window == null:
		return null

	var character_window: Window = (
		Window.new()
	)

	character_window.name = (
		"CharacterWindow_"
		+ character_id
	)

	character_window.size = Vector2i(
		maxi(1, window_size.x),
		maxi(1, window_size.y)
	)

	character_window.borderless = true
	character_window.transparent = true
	character_window.transparent_bg = true
	character_window.unresizable = true
	character_window.unfocusable = true
	character_window.always_on_top = true
	character_window.transient = false
	character_window.mouse_passthrough = OS.get_name() != "Windows"
	character_window.visible = false

	window_container.add_child(
		character_window
	)
	character_window.close_requested.connect(
		_on_character_window_close_requested
	)

	return character_window

func _show_character_window_when_ready(character_window: Window) -> void:
	var target_position := character_window.position
	character_window.set_meta(&"priming", true)
	character_window.position = OFFSCREEN_WINDOW_POSITION
	character_window.show()
	for _frame: int in range(STARTUP_WINDOW_SETTLE_FRAMES):
		await get_tree().process_frame
	if not is_instance_valid(character_window):
		return
	character_window.position = target_position
	character_window.set_meta(&"priming", false)

func _on_character_window_close_requested() -> void:
	application_close_requested.emit()

func clear_spawned_characters() -> void:
	for value: Variant in spawned_windows.values():
		if not (
			value is Window
		):
			continue

		var character_window: Window = value

		if not is_instance_valid(
			character_window
		):
			continue

		_unregister_character_drop_target(character_window)
		character_window.hide()

		var parent: Node = (
			character_window.get_parent()
		)

		if parent != null:
			parent.remove_child(
				character_window
			)

		character_window.queue_free()

	spawned_windows.clear()
	spawned_actors.clear()
	current_character_ids.clear()

func _on_actor_menu_tab_requested(
	character_id: String,
	tab_name: String
) -> void:
	character_menu_tab_requested.emit(character_id, tab_name)

func _on_actor_menu_talk_action_requested(
	character_id: String,
	action: String,
	detail: String
) -> void:
	character_menu_talk_action_requested.emit(character_id, action, detail)

func _on_actor_interactive_question_answered(
	character_id: String,
	answer: Dictionary
) -> void:
	character_interactive_question_answered.emit(
		character_id,
		answer.duplicate(true)
	)

func _on_actor_interactive_question_dismissed(
	character_id: String,
	reason: String
) -> void:
	character_interactive_question_dismissed.emit(character_id, reason)

func _on_actor_menu_visibility_changed(
	character_id: String,
	is_open: bool
) -> void:
	character_menu_visibility_changed.emit(character_id, is_open)

func _on_actor_play_changed(
	character_id: String,
	play_value: float,
	play_max: float
) -> void:

	character_play_changed.emit(
		character_id,
		play_value,
		play_max
	)

func _on_actor_play_interaction_activity(
	character_id: String
) -> void:

	character_play_interaction.emit(
		character_id
	)

func _on_actor_play_event_requested(
	character_id: String,
	event_kind: String,
	zone: String,
	play_value: float
) -> void:

	character_play_event.emit(
		character_id,
		event_kind,
		zone,
		play_value
	)

func _on_actor_temporary_departure_requested(
	character_id: String,
	duration_seconds: float,
	delay_seconds: float,
	reason: String,
	unavailable_lines: Array
) -> void:

	if delay_seconds > 0.0:
		await get_tree().create_timer(
			delay_seconds
		).timeout

	_temporarily_remove_character(
		character_id,
		duration_seconds,
		reason,
		unavailable_lines
	)

func _temporarily_remove_character(
	character_id: String,
	duration_seconds: float,
	reason: String,
	unavailable_lines: Array
) -> void:

	character_id = (
		character_id
			.strip_edges()
			.to_lower()
	)

	if character_id.is_empty():
		return

	var slots: Array[String] = (
		get_slot_character_ids()
	)

	var slot_index: int = slots.find(
		character_id
	)

	if slot_index < 0:
		return

	var preferences: Dictionary = (
		get_character_preferences(
			character_id
		)
	)

	if preferences.is_empty():
		return

	var absences: Dictionary = (
		_load_temporary_absences()
	)

	absences[
		character_id
	] = {
		"until_unix": int(
			Time.get_unix_time_from_system()
			+ maxf(
				1.0,
				duration_seconds
			)
		),
		"slot_index": slot_index,
		"skin": str(
			preferences.get(
				"skin",
				""
			)
		),
		"ambient_dialogue": bool(
			preferences.get(
				"ambient_dialogue",
				true
			)
		),
		"timer_reactions": bool(
			preferences.get(
				"timer_reactions",
				true
			)
		),
		"reason": reason,
		"unavailable_lines": unavailable_lines.duplicate(
			true
		)
	}

	_save_temporary_absences(
		absences
	)

	var clear_error: Error = (
		_save_slot_settings_now(
			slot_index,
			"",
			"",
			true,
			true
		)
	)

	if clear_error == OK:
		reload_desktop_characters()

func get_behavior_settings(
	character_id: String,
	pack_settings: Dictionary
) -> Dictionary:

	var result: Dictionary = {
		"ambient_dialogue": true,
		"timer_reactions": true,
	}

	var behavior_value: Variant = (
		pack_settings.get(
			"behavior",
			{}
		)
	)

	if not (
		behavior_value is Dictionary
	):
		return result

	var all_behavior: Dictionary = (
		behavior_value
	)

	var character_value: Variant = (
		all_behavior.get(
			character_id,
			{}
		)
	)

	if not (
		character_value is Dictionary
	):
		return result

	var character_behavior: Dictionary = (
		character_value
	)

	result["ambient_dialogue"] = bool(
		character_behavior.get(
			"ambient_dialogue",
			true
		)
	)

	result["timer_reactions"] = bool(
		character_behavior.get(
			"timer_reactions",
			true
		)
	)

	return result

func get_desktop_config(
	profile: Dictionary
) -> Dictionary:

	var value: Variant = (
		profile.get(
			"desktop",
			{}
		)
	)

	if value is Dictionary:
		return value

	return {}

func _get_saved_skin_id(
	character_id: String,
	pack_settings: Dictionary
) -> String:
	var available: Array[String] = get_available_skins(character_id)
	if available.is_empty():
		return ""

	var skins_value: Variant = pack_settings.get("skins", {})
	if skins_value is Dictionary and (skins_value as Dictionary).has(character_id):
		var saved: String = str(
			(skins_value as Dictionary).get(character_id, "")
		).strip_edges().to_lower()
		return saved if available.has(saved) else ""

	return "default" if available.has("default") else ""

func _get_temporary_absence_path() -> String:
	var pack_id: String = (
		CharacterProfiles
			.get_current_pack()
			.strip_edges()
			.to_lower()
	)

	return (
		"user://character_state/play/"
		+ (
			pack_id
			if not pack_id.is_empty()
			else "unknown"
		)
		+ "/"
		+ TEMPORARY_ABSENCE_FILENAME
	)

func _load_temporary_absences() -> Dictionary:
	return JsonStore.load_dictionary(_get_temporary_absence_path(), {})

func _save_temporary_absences(
	absences: Dictionary
) -> void:
	var path: String = _get_temporary_absence_path()
	if absences.is_empty():
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		return
	JsonStore.save_json(path, absences)

func _get_active_temporary_absence(
	character_id: String
) -> Dictionary:

	var absences: Dictionary = (
		_load_temporary_absences()
	)

	var value: Variant = absences.get(
		character_id,
		{}
	)

	if not (
		value is Dictionary
	):
		return {}

	var absence: Dictionary = (
		value
	)

	var until_unix: int = int(
		absence.get(
			"until_unix",
			0
		)
	)

	if until_unix <= int(
		Time.get_unix_time_from_system()
	):
		return {}

	return absence.duplicate(
		true
	)

func _restore_temporary_absences(
	force_restore: bool
) -> bool:

	var absences: Dictionary = (
		_load_temporary_absences()
	)

	if absences.is_empty():
		return false

	var now_unix: int = int(
		Time.get_unix_time_from_system()
	)

	var slots: Array[String] = (
		get_slot_character_ids()
	)

	var restored_any: bool = false
	var changed: bool = false

	for key: Variant in absences.keys():
		var character_id: String = str(
			key
		).strip_edges().to_lower()

		var value: Variant = absences[
			key
		]

		if not (
			value is Dictionary
		):
			absences.erase(
				key
			)

			changed = true
			continue

		var absence: Dictionary = (
			value
		)

		var until_unix: int = int(
			absence.get(
				"until_unix",
				0
			)
		)

		if (
			not force_restore
			and until_unix > now_unix
		):
			continue

		var slot_index: int = int(
			absence.get(
				"slot_index",
				-1
			)
		)

		if (
			slot_index >= 0
			and slot_index < slots.size()
			and slots[
				slot_index
			].is_empty()
		):
			var restore_error: Error = (
				_save_slot_settings_now(
					slot_index,
					character_id,
					str(
						absence.get(
							"skin",
							""
						)
					),
					bool(
						absence.get(
							"ambient_dialogue",
							true
						)
					),
					bool(
						absence.get(
							"timer_reactions",
							true
						)
					)
				)
			)

			if restore_error == OK:
				restored_any = true

				slots[
					slot_index
				] = character_id

				if force_restore:
					_clear_character_interaction_lock(
						character_id
					)

		absences.erase(
			key
		)

		changed = true

	if changed:
		_save_temporary_absences(
			absences
		)

	return restored_any

func _clear_character_interaction_lock(
	character_id: String
) -> void:
	character_id = character_id.strip_edges().to_lower()
	if character_id.is_empty():
		return
	var pack_id: String = CharacterProfiles.get_current_pack().strip_edges().to_lower()
	var path: String = (
		"user://character_state/play/"
		+ (pack_id if not pack_id.is_empty() else "unknown")
		+ "/"
		+ character_id
		+ ".json"
	)
	var state: Dictionary = JsonStore.load_dictionary(path, {})
	if state.is_empty():
		return
	state["interaction_locked_until_unix"] = 0
	state["reluctance"] = 0.0
	JsonStore.save_json(path, state)

func get_global_desktop_settings() -> Dictionary:
	var defaults: Dictionary = {
		"base_opacity": 0.82,
		"bubble_opacity": 1.0,
		"character_scale": DEFAULT_CHARACTER_SCALE,
		"bubble_scale": 1.0,
		"vertical_movement_enabled": false,
		"bubble_drag_enabled": true,
		"ambient_cadence_mode": "free",
		"custom_ambient_minutes": 30.0,
	}

	var settings: Dictionary = load_settings()
	var global_value: Variant = settings.get(
		"global",
		{}
	)

	if not (global_value is Dictionary):
		return defaults

	var result: Dictionary = defaults.duplicate(
		true
	)

	for key: Variant in defaults.keys():
		if not (global_value as Dictionary).has(key):
			continue

		result[
			key
		] = (
			global_value as Dictionary
		)[
			key
		]

	if (
		not (global_value as Dictionary).has("bubble_opacity")
		and (global_value as Dictionary).has("bubble_opacity_multiplier")
	):
		result["bubble_opacity"] = clampf(
			float(result.get("base_opacity", 0.82))
			* float((global_value as Dictionary).get("bubble_opacity_multiplier", 1.0)),
			0.25,
			1.0
		)

	return result

func apply_global_desktop_settings(
	values: Dictionary
) -> Error:

	var current: Dictionary = (
		get_global_desktop_settings()
	)

	for key: Variant in values.keys():
		if not current.has(key):
			continue

		current[
			key
		] = values[
			key
		]

	current["base_opacity"] = clampf(
		float(
			current.get(
				"base_opacity",
				0.82
			)
		),
		0.10,
		1.0
	)

	current["bubble_opacity"] = clampf(
		float(
			current.get(
				"bubble_opacity",
				1.0
			)
		),
		0.25,
		1.0
	)

	current["character_scale"] = clampf(
		float(
			current.get(
				"character_scale",
				DEFAULT_CHARACTER_SCALE
			)
		),
		0.50,
		1.50
	)
	current["bubble_scale"] = clampf(
		float(current.get("bubble_scale", 1.0)),
		0.50,
		1.50
	)
	current["vertical_movement_enabled"] = bool(
		current.get("vertical_movement_enabled", false)
	)
	current["bubble_drag_enabled"] = bool(
		current.get("bubble_drag_enabled", true)
	)

	var cadence_mode: String = str(
		current.get(
			"ambient_cadence_mode",
			"free"
		)
	).strip_edges().to_lower()

	if not [
		"free",
		"paid",
		"custom"
	].has(
		cadence_mode
	):
		cadence_mode = "free"

	current["ambient_cadence_mode"] = cadence_mode

	current["custom_ambient_minutes"] = clampf(
		float(
			current.get(
				"custom_ambient_minutes",
				30.0
			)
		),
		1.0,
		120.0
	)

	var settings: Dictionary = load_settings()

	settings[
		"global"
	] = current.duplicate(
		true
	)

	var save_error: Error = save_settings(
		settings
	)

	if save_error != OK:
		return save_error

	for actor_value: Variant in spawned_actors.values():
		if not (actor_value is DesktopCharacterActor):
			continue

		var actor: DesktopCharacterActor = actor_value as DesktopCharacterActor
		actor.configure_display(
			float(current.get("base_opacity", 0.82)),
			float(current.get("character_scale", DEFAULT_CHARACTER_SCALE)),
			float(current.get("bubble_scale", 1.0)),
			float(current.get("bubble_opacity", 1.0))
		)
		actor.configure_desktop_interaction(
			bool(current.get("vertical_movement_enabled", false)),
			bool(current.get("bubble_drag_enabled", true)),
			get_speech_bubble_offset(actor.character_id)
		)

	global_settings_changed.emit(
		current.duplicate(
			true
		)
	)

	return OK

func get_current_pack_settings(
	settings: Dictionary
) -> Dictionary:
	var pack_id: String = CharacterProfiles.get_current_pack()

	if pack_id.is_empty():
		return {}

	var packs_value: Variant = settings.get(
		"packs",
		{}
	)

	if not (packs_value is Dictionary):
		return {}

	var pack_value: Variant = (packs_value as Dictionary).get(
		pack_id,
		{}
	)

	if pack_value is Dictionary:
		return pack_value as Dictionary

	return {}

func store_current_pack_settings(
	settings: Dictionary,
	pack_settings: Dictionary
) -> void:

	var pack_id: String = (
		CharacterProfiles.get_current_pack()
	)

	if pack_id.is_empty():
		return

	var packs_value: Variant = (
		settings.get(
			"packs",
			{}
		)
	)

	var packs: Dictionary = {}

	if packs_value is Dictionary:
		packs = packs_value

	packs[pack_id] = pack_settings

	settings["packs"] = packs

func _speech_bubble_offset_key(character_id: String, pack_id: String = "") -> String:
	var normalized_pack: String = pack_id.strip_edges().to_lower()
	if normalized_pack.is_empty():
		normalized_pack = CharacterProfiles.get_current_pack().strip_edges().to_lower()
	return normalized_pack + ":" + character_id.strip_edges().to_lower()

func get_speech_bubble_offset(character_id: String, pack_id: String = "") -> Vector2:
	var settings: Dictionary = load_settings()
	var offsets_value: Variant = settings.get("speech_bubble_offsets", {})
	if not (offsets_value is Dictionary):
		return Vector2.ZERO
	var value: Variant = (offsets_value as Dictionary).get(
		_speech_bubble_offset_key(character_id, pack_id),
		{}
	)
	if not (value is Dictionary):
		return Vector2.ZERO
	return Vector2(float(value.get("x", 0.0)), float(value.get("y", 0.0)))

func _on_actor_speech_bubble_offset_changed(character_id: String, offset: Vector2) -> void:
	var settings: Dictionary = load_settings()
	var offsets: Dictionary = {}
	var offsets_value: Variant = settings.get("speech_bubble_offsets", {})
	if offsets_value is Dictionary:
		offsets = (offsets_value as Dictionary).duplicate(true)
	offsets[_speech_bubble_offset_key(character_id)] = {"x": offset.x, "y": offset.y}
	settings["speech_bubble_offsets"] = offsets
	save_settings(settings)

func reset_character_positions() -> void:
	for actor_value: Variant in spawned_actors.values():
		if actor_value is DesktopCharacterActor and is_instance_valid(actor_value) and actor_value.pet_interaction != null:
			actor_value.pet_interaction.reset_desktop_position()

func reset_speech_bubble_offsets() -> Error:
	var settings: Dictionary = load_settings()
	settings["speech_bubble_offsets"] = {}
	var result: Error = save_settings(settings)
	if result != OK:
		return result
	var global_settings: Dictionary = get_global_desktop_settings()
	for actor_value: Variant in spawned_actors.values():
		if actor_value is DesktopCharacterActor and is_instance_valid(actor_value):
			var actor: DesktopCharacterActor = actor_value as DesktopCharacterActor
			actor.configure_desktop_interaction(
				bool(global_settings.get("vertical_movement_enabled", false)),
				bool(global_settings.get("bubble_drag_enabled", true)),
				Vector2.ZERO
			)
	return OK

func load_settings() -> Dictionary:
	return JsonStore.load_dictionary(
		SETTINGS_PATH,
		{"packs": {}}
	)

func save_settings(
	settings: Dictionary
) -> Error:
	return JsonStore.save_json(SETTINGS_PATH, settings)
