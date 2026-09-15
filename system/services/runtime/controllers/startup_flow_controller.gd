extends Node
class_name StartupFlowController

const ScheduleStoreScript = preload("res://system/services/calendar/schedule_store.gd")
const JsonStoreScript = preload("res://system/services/runtime/json_store.gd")
const AppearanceSettingsScript = preload("res://system/app/appearance_settings.gd")
const SPECIAL_BOOT_STATE_PATH: String = "user://runtime/special_boot_state.json"

const FIRST_BOOT_BUBBLE_SECONDS: float = 5.2
const FIRST_BOOT_STEP_SECONDS: float = 4.4

var character_manager: DesktopCharacterManager = null
var character_event_dialogue: CharacterEventDialogue = null
var ambient_dialogue: AmbientDialogue = null
var desktop_pack_events: DesktopPackEvents = null
var orchestrator: DesktopDialogueOrchestrator = null
var presenter: DesktopDialoguePresenter = null

var cast_controller: CastTransitionController = null
var ambient_controller: AmbientEventController = null
var interactive_controller: InteractiveQuestionController = null
var exit_controller: ExitFlowController = null
var menu_talk_controller: MenuTalkController = null

var boot_sequence_busy: bool = false
var boot_primary_character_id: String = ""
var boot_ai_request_id: int = 0
var debug_special_boot_request_id: int = 0
var boot_ai_scene_lines: Array = []
var boot_special_occasion: Dictionary = {}
var first_boot_sequence_busy: bool = false
var pending_first_boot_ids: Array[String] = []

func configure(
	manager: DesktopCharacterManager,
	event_dialogue: CharacterEventDialogue,
	ambient: AmbientDialogue,
	pack_events: DesktopPackEvents,
	dialogue_orchestrator: DesktopDialogueOrchestrator,
	dialogue_presenter: DesktopDialoguePresenter
) -> void:
	character_manager = manager
	character_event_dialogue = event_dialogue
	ambient_dialogue = ambient
	desktop_pack_events = pack_events
	orchestrator = dialogue_orchestrator
	presenter = dialogue_presenter

func bind_controllers(
	cast_flow: CastTransitionController,
	ambient_flow: AmbientEventController,
	interactive_flow: InteractiveQuestionController,
	exit_flow: ExitFlowController,
	menu_talk_flow: MenuTalkController
) -> void:
	cast_controller = cast_flow
	ambient_controller = ambient_flow
	interactive_controller = interactive_flow
	exit_controller = exit_flow
	menu_talk_controller = menu_talk_flow

func set_pending_first_boot_ids(character_ids: Array[String]) -> void:
	pending_first_boot_ids = character_ids.duplicate()

func has_pending_first_boots() -> bool:
	return not pending_first_boot_ids.is_empty()

func is_blocking_dialogue() -> bool:
	return boot_sequence_busy or first_boot_sequence_busy or has_pending_first_boots()

func request_pending_first_boots() -> void:
	call_deferred("_try_run_pending_first_boots")

func _on_startup_boot_started() -> void:
	boot_sequence_busy = true
	boot_primary_character_id = ""
	boot_ai_request_id = 0
	boot_ai_scene_lines.clear()
	boot_special_occasion.clear()
	orchestrator.stop_talk_timer()

	var planned_ids: Array[String] = []
	for value: String in character_manager.get_slot_character_ids():
		var character_id: String = value.strip_edges().to_lower()
		if character_id.is_empty():
			continue
		planned_ids.append(character_id)
		DesktopCharacterProgress.reward_activity(character_id, "attendance")
		if planned_ids.size() >= 2:
			break

	if _has_uncompleted_first_boot(planned_ids):
		_release_startup_boot_preparation()
		return

	if planned_ids.is_empty() or character_event_dialogue == null:

		_release_startup_boot_preparation()
		return

	var now: Dictionary = (
		Time.get_datetime_dict_from_system()
	)

	boot_special_occasion = _get_special_boot_occasion(planned_ids, now, false)

	var request_value: Variant = character_event_dialogue.request_boot_scene(
		planned_ids,
		int(now.get("hour", 0)),
		boot_special_occasion
	)

	boot_ai_request_id = int(
		request_value
	)

	if boot_ai_request_id <= 0:

		_release_startup_boot_preparation()
		return

	boot_primary_character_id = planned_ids[0]
	character_manager.set_character_response_loading(
		boot_primary_character_id, "boot", true
	)

func _get_special_boot_occasion(
	character_ids: Array[String],
	date: Dictionary,
	ignore_daily_limit: bool
) -> Dictionary:
	var year: int = int(date.get("year", 1970))
	var month: int = int(date.get("month", 1))
	var day: int = int(date.get("day", 1))
	var date_key: String = "%04d-%02d-%02d" % [year, month, day]
	if not ignore_daily_limit:
		var state: Dictionary = JsonStoreScript.load_dictionary(SPECIAL_BOOT_STATE_PATH, {})
		if str(state.get("last_date", "")) == date_key:
			return {}

	for character_id: String in character_ids:
		var profile: Dictionary = CharacterProfiles.load_profile(character_id)
		var birthday_value: Variant = profile.get("birthday", {})
		if birthday_value is Dictionary:
			var birthday: Dictionary = birthday_value as Dictionary
			if int(birthday.get("month", 0)) == month and int(birthday.get("day", 0)) == day:
				return {
					"kind": "character_birthday",
					"title": str(profile.get("display_name", character_id)) + "의 생일",
					"character_id": character_id,
					"date": date_key
				}

	var schedule_occasion: Dictionary = ScheduleStoreScript.get_special_boot_occasion(year, month, day)
	if not schedule_occasion.is_empty():
		schedule_occasion["date"] = date_key
	return schedule_occasion

func _mark_special_boot_used(date: Dictionary) -> void:
	var date_key: String = "%04d-%02d-%02d" % [
		int(date.get("year", 1970)), int(date.get("month", 1)), int(date.get("day", 1))
	]
	JsonStoreScript.save_json(SPECIAL_BOOT_STATE_PATH, {"last_date": date_key})

func request_debug_special_boot(month: int, day: int, target_character_id: String = "") -> bool:
	if character_event_dialogue == null or character_manager == null:
		return false
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var date: Dictionary = {
		"year": int(now.get("year", 1970)),
		"month": clampi(month, 1, 12),
		"day": clampi(day, 1, 31),
		"hour": int(now.get("hour", 0))
	}
	var ids: Array[String] = character_manager.get_active_character_ids()
	if not target_character_id.is_empty() and ids.has(target_character_id):
		ids.erase(target_character_id)
		ids.push_front(target_character_id)
	if ids.is_empty():
		return false
	var occasion: Dictionary = _get_special_boot_occasion(ids, date, true)
	if occasion.is_empty():
		return false
	var request_id: int = character_event_dialogue.request_boot_scene(ids, int(now.get("hour", 0)), occasion)
	if request_id <= 0:
		return false
	debug_special_boot_request_id = request_id
	character_manager.set_character_response_loading(ids[0], "debug_boot", true)
	return true

func _on_boot_scene_ready(
	request_id: int,
	lines: Array
) -> void:

	if request_id == debug_special_boot_request_id:
		debug_special_boot_request_id = 0
		if character_manager != null:
			for character_id: String in character_manager.get_active_character_ids():
				character_manager.set_character_response_loading(
					character_id, "debug_boot", false
				)
		call_deferred("_play_debug_special_boot_lines", lines.duplicate(true))
		return

	if request_id != boot_ai_request_id:
		return

	boot_ai_request_id = 0
	if character_manager != null and not boot_primary_character_id.is_empty():
		character_manager.set_character_response_loading(
			boot_primary_character_id, "boot", false
		)
	boot_ai_scene_lines = lines.duplicate(
		true
	)
	if not boot_special_occasion.is_empty() and not boot_ai_scene_lines.is_empty():
		var now: Dictionary = Time.get_datetime_dict_from_system()
		_mark_special_boot_used(now)
	boot_special_occasion.clear()

	_release_startup_boot_preparation()

func _play_debug_special_boot_lines(lines: Array) -> void:
	for value: Variant in lines:
		if not (value is Dictionary):
			continue
		var line: Dictionary = value as Dictionary
		var speaker: String = str(line.get("speaker", "")).strip_edges().to_lower()
		var text: String = str(line.get("text", "")).strip_edges()
		if speaker.is_empty() or text.is_empty():
			continue
		if presenter.show(speaker, text, str(line.get("mood", "neutral")), FIRST_BOOT_BUBBLE_SECONDS):
			await get_tree().create_timer(FIRST_BOOT_STEP_SECONDS).timeout

func _release_startup_boot_preparation() -> void:
	character_manager.release_startup_boot_preparation()

func _get_ai_boot_line(
	phase: String,
	speaker: String = ""
) -> Dictionary:

	phase = (
		phase.strip_edges()
			.to_lower()
	)

	speaker = (
		speaker.strip_edges()
			.to_lower()
	)

	for value: Variant in boot_ai_scene_lines:
		if not (
			value is Dictionary
		):
			continue

		var line: Dictionary = value

		var line_phase: String = str(
			line.get(
				"phase",
				""
			)
		).strip_edges().to_lower()

		var line_speaker: String = str(
			line.get(
				"speaker",
				""
			)
		).strip_edges().to_lower()

		if line_phase != phase:
			continue

		if (
			not speaker.is_empty()
			and line_speaker != speaker
		):
			continue

		return line.duplicate(
			true
		)

	return {}

func _on_startup_primary_spawned(
	character_id: String,
	has_secondary: bool
) -> void:

	boot_sequence_busy = true
	boot_primary_character_id = character_id
	orchestrator.stop_talk_timer()

	var line: Dictionary = {}
	var pack_id: String = CharacterProfiles.get_current_pack()
	var first_boot_pending: bool = not CharacterFirstBootState.has_completed(
		pack_id,
		character_id
	)

	if not first_boot_pending and not boot_ai_scene_lines.is_empty():
		line = _get_ai_boot_line(
			"primary",
			character_id
		)

	if (
		not first_boot_pending
		and line.is_empty()
		and desktop_pack_events != null
	):
		line = desktop_pack_events.pick_boot_line(
			character_id,
			"primary"
		)

	_show_pack_event_line(
		character_id,
		line,
		4.0
	)

	if not has_secondary:
		await get_tree().create_timer(
			4.5
		).timeout

		boot_sequence_busy = false
		orchestrator.request_resume()

func _on_startup_secondary_spawned(
	character_id: String,
	primary_character_id: String
) -> void:

	var arrival: Dictionary = {}
	var peer_line: Dictionary = {}
	var pack_id: String = CharacterProfiles.get_current_pack()
	var secondary_first_boot_pending: bool = not CharacterFirstBootState.has_completed(
		pack_id,
		character_id
	)
	var primary_first_boot_pending: bool = not CharacterFirstBootState.has_completed(
		pack_id,
		primary_character_id
	)

	if (
		not secondary_first_boot_pending
		and not primary_first_boot_pending
		and not boot_ai_scene_lines.is_empty()
	):
		arrival = _get_ai_boot_line(
			"arrival",
			character_id
		)

		peer_line = _get_ai_boot_line(
			"peer",
			primary_character_id
		)

	if (
		not secondary_first_boot_pending
		and arrival.is_empty()
		and desktop_pack_events != null
	):
		arrival = desktop_pack_events.pick_boot_line(
			character_id,
			"arrival"
		)

	if (
		not primary_first_boot_pending
		and boot_ai_scene_lines.is_empty()
		and desktop_pack_events != null
	):
		peer_line = desktop_pack_events.pick_boot_peer_line(
			primary_character_id
		)

	_show_pack_event_line(
		character_id,
		arrival,
		4.0
	)

	if not peer_line.is_empty():
		await get_tree().create_timer(
			2.7
		).timeout

		_show_pack_event_line(
			primary_character_id,
			peer_line,
			4.0
		)

func _on_startup_boot_completed() -> void:
	var active_ids: Array[String] = character_manager.get_active_character_ids()
	var wait_seconds: float = 0.6 if _has_uncompleted_first_boot(active_ids) else 7.0
	await get_tree().create_timer(wait_seconds).timeout

	active_ids = character_manager.get_active_character_ids()
	pending_first_boot_ids.clear()

	boot_ai_request_id = 0
	boot_ai_scene_lines.clear()

	await _run_first_boot_sequences(active_ids)

	boot_sequence_busy = false
	if has_pending_first_boots():
		request_pending_first_boots()

	ambient_controller.refresh_cast()
	interactive_controller.arm("boot", {})

	if ambient_dialogue != null:
		ambient_dialogue.schedule_post_boot_generation()

	exit_controller.request_prefetch()
	menu_talk_controller.refresh_cast()
	orchestrator.request_resume()

func _has_uncompleted_first_boot(character_ids: Array[String]) -> bool:
	var pack_id: String = CharacterProfiles.get_current_pack()

	for character_id: String in character_ids:
		character_id = character_id.strip_edges().to_lower()

		if character_id.is_empty():
			continue

		if not CharacterFirstBootState.has_completed(pack_id, character_id):
			return true

	return false

func _try_run_pending_first_boots() -> void:
	if pending_first_boot_ids.is_empty():
		return

	if boot_sequence_busy or cast_controller.has_pending_transition() or first_boot_sequence_busy:
		return

	var ids: Array[String] = pending_first_boot_ids.duplicate()
	pending_first_boot_ids.clear()
	await _run_first_boot_sequences(ids)

func _run_first_boot_sequences(character_ids: Array[String]) -> void:
	if first_boot_sequence_busy:
		return

	first_boot_sequence_busy = true
	orchestrator.stop_talk_timer()

	var pack_id: String = CharacterProfiles.get_current_pack()
	var sequences: Array[Dictionary] = []

	for raw_character_id: String in character_ids:
		var character_id: String = raw_character_id.strip_edges().to_lower()

		if character_id.is_empty():
			continue
		if CharacterFirstBootState.has_completed(pack_id, character_id):
			continue
		if character_manager.get_actor(character_id) == null:
			continue

		var config: Dictionary = CharacterProfiles.get_first_boot_config(character_id)
		var lines_value: Variant = config.get("lines", [])
		if config.is_empty() or not (lines_value is Array):
			CharacterFirstBootState.mark_completed(pack_id, character_id)
			continue

		sequences.append({
			"character_id": character_id,
			"lines": (lines_value as Array).duplicate(true),
			"ask_user_name_after": int(config.get("ask_user_name_after", -1)),
			"ask_api_key_after": int(config.get("ask_api_key_after", -1)),
			"index": 0,
			"finished": false,
		})

	while _has_active_first_boot_sequence(sequences):
		for sequence: Dictionary in sequences:
			if bool(sequence.get("finished", false)):
				continue
			await _play_next_first_boot_line(sequence)

	for sequence: Dictionary in sequences:
		var character_id: String = str(sequence.get("character_id", ""))
		if not character_id.is_empty():
			CharacterFirstBootState.mark_completed(pack_id, character_id)

	first_boot_sequence_busy = false

	if not boot_sequence_busy and not cast_controller.has_pending_transition():
		ambient_controller.refresh_cast()
		orchestrator.request_resume()

func _has_active_first_boot_sequence(sequences: Array[Dictionary]) -> bool:
	for sequence: Dictionary in sequences:
		if not bool(sequence.get("finished", false)):
			return true
	return false

func _play_next_first_boot_line(sequence: Dictionary) -> void:
	var character_id: String = str(sequence.get("character_id", ""))
	var lines: Array = sequence.get("lines", []) as Array
	var index: int = int(sequence.get("index", 0))
	var ask_after: int = int(sequence.get("ask_user_name_after", -1))
	var ask_api_after: int = int(sequence.get("ask_api_key_after", -1))

	if index >= lines.size():
		await _finish_first_boot_prompts(sequence)
		sequence["finished"] = true
		return

	if index == ask_api_after and AISettings.get_api_key().is_empty():
		await _request_ai_settings()

	if index == ask_after and UserProfileSettings.get_user_name().is_empty():
		await _request_user_name()

	var line_value: Variant = lines[index]
	sequence["index"] = index + 1

	var line: Dictionary = {}
	if line_value is Dictionary:
		line = (line_value as Dictionary).duplicate(true)
	elif line_value is String:
		line = {
			"text": str(line_value),
			"mood": "neutral"
		}
	else:
		return

	var user_name: String = UserProfileSettings.get_user_name()
	var output_language: String = CharacterProfiles.get_pack_output_language(
		CharacterProfiles.get_current_pack()
	)
	var fallback_name: String = "너" if output_language == "ko" else "you"
	var text_value: String = str(line.get("text", ""))
	line["text"] = UserProfileSettings.replace_user_name_placeholder(
		text_value,
		user_name if not user_name.is_empty() else fallback_name
	)

	_show_pack_event_line(
		character_id,
		line,
		FIRST_BOOT_BUBBLE_SECONDS
	)

	await get_tree().create_timer(FIRST_BOOT_STEP_SECONDS).timeout

	if int(sequence.get("index", 0)) >= lines.size():
		await _finish_first_boot_prompts(sequence)
		sequence["finished"] = true

func _finish_first_boot_prompts(sequence: Dictionary) -> void:
	var lines: Array = sequence.get("lines", []) as Array
	var ask_after: int = int(sequence.get("ask_user_name_after", -1))
	var ask_api_after: int = int(sequence.get("ask_api_key_after", -1))

	if ask_after >= lines.size() and UserProfileSettings.get_user_name().is_empty():
		await _request_user_name()

	if ask_api_after >= lines.size() and AISettings.get_api_key().is_empty():
		await _request_ai_settings()

func _play_first_boot_sequence(character_id: String) -> void:
	var config: Dictionary = CharacterProfiles.get_first_boot_config(character_id)
	if config.is_empty():
		return

	var lines_value: Variant = config.get("lines", [])
	if not (lines_value is Array):
		return

	var sequence: Dictionary = {
		"character_id": character_id,
		"lines": (lines_value as Array).duplicate(true),
		"ask_user_name_after": int(config.get("ask_user_name_after", -1)),
		"ask_api_key_after": int(config.get("ask_api_key_after", -1)),
		"index": 0,
		"finished": false,
	}
	while not bool(sequence.get("finished", false)):
		await _play_next_first_boot_line(sequence)

func _request_ai_settings() -> bool:
	var dialog := AISettingsDialog.new()
	dialog.theme = AppearanceSettingsScript.build_theme()
	add_child(dialog)
	dialog.open_centered()
	var saved: bool = bool(await dialog.finished)
	dialog.queue_free()
	return saved

func _request_user_name() -> String:
	var dialog: UserNameDialog = UserNameDialog.new()
	add_child(dialog)
	dialog.open_centered()
	var user_name: String = str(await dialog.finished).strip_edges()
	return user_name

func _show_pack_event_line(
	character_id: String,
	line: Dictionary,
	duration: float
) -> bool:

	if line.is_empty():
		return false

	var text: String = str(
		line.get(
			"text",
			""
		)
	).strip_edges()

	var mood: String = str(
		line.get(
			"mood",
			"neutral"
		)
	).strip_edges().to_lower()

	return presenter.show(
		character_id,
		text,
		mood,
		duration
	)
