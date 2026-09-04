extends Node
class_name EasterEggDebugTools

const DesktopCharacterProgressScript = preload(
	"res://system/services/desktop/desktop_character_progress.gd"
)

const CharacterProfilesScript = preload(
	"res://system/services/characters/character_profiles.gd"
)

const UserProfileSettingsScript = preload(
	"res://system/app/user_profile_settings.gd"
)

const AppearanceSettingsScript = preload(
	"res://system/app/appearance_settings.gd"
)

const UserNameDialogScript = preload(
	"res://system/ui/user_name_dialog.gd"
)

const DEBUG_INTERACTIVE_PRIORITY: int = 90
const FIRST_BOOT_BUBBLE_SECONDS: float = 5.2
const FIRST_BOOT_STEP_SECONDS: float = 4.4

var app: Node = null

var hourly_request_id: int = 0
var exit_request_id: int = 0
var schedule_request_id: int = 0
var fluster_request_id: int = 0
var focus_session_id: int = 0
var interactive_question_request_id: int = 0

func bind(host: Node) -> void:
	app = host
	var board: CompanionBoardWindow = _board_window()
	if board != null and not board.debug_action_requested.is_connected(handle_action_requested):
		board.debug_action_requested.connect(handle_action_requested)

func handle_action_requested(
	action: String,
	target_slot: int
) -> void:
	action = action.strip_edges().to_lower()

	if action.begins_with("friendship_level_set:"):
		_set_friendship_level(
			target_slot,
			int(action.get_slice(":", 1))
		)
		return
	if action.begins_with("achievement_level_set:"):
		_set_achievement_level(
			target_slot,
			int(action.get_slice(":", 1))
		)
		return
	if action.begins_with("special_boot:"):
		var date_text: String = action.get_slice(":", 1)
		var parts: PackedStringArray = date_text.split("-")
		if parts.size() == 2:
			var startup: StartupFlowController = _app_property("startup_controller") as StartupFlowController
			if startup != null and startup.request_debug_special_boot(int(parts[0]), int(parts[1]), _get_target_character(target_slot)):
				set_output("Special boot test requested for " + date_text + ".")
				return
		set_output("No recognizable special occasion exists on " + date_text + ".")
		return

	match action:
		"ambient_generate":
			_generate_ambient_pool()
		"ambient_play":
			_play_ambient_now()
		"hourly_ai":
			_request_hourly_comment(target_slot)
		"timer_bundle":
			_request_timer_bundle(target_slot)
		"schedule_ai":
			_request_schedule_reminder(target_slot)
		"exit_ai":
			_request_exit_dialogue()
		"first_boot":
			_replay_first_boot(target_slot)
		"fluster_banter":
			_request_fluster_banter(target_slot)
		"force_overlap":
			_force_overlap(target_slot)
		"interactive_question":
			_request_interactive_question(target_slot)
		"progress_show":
			show_progress(target_slot)
		"progress_restore":
			_restore_progress(target_slot)
		"validate_pack":
			_validate_current_pack()

func handle_exit_dialogue_ready(
	request_id: int,
	dialogue: Dictionary
) -> bool:
	if request_id != exit_request_id:
		return false

	exit_request_id = 0
	if not bool(_app_call("_is_exit_dialogue_usable", [dialogue])):
		set_output(
			"Exit-dialogue AI request returned no usable dialogue."
		)
		return true

	_show_generated_dialogue(
		"",
		dialogue,
		"AI exit dialogue"
	)
	return true

func handle_schedule_event_dialogue_ready(
	request_id: int,
	character_id: String,
	dialogue: Dictionary
) -> bool:
	if request_id != schedule_request_id:
		return false

	schedule_request_id = 0
	_show_generated_dialogue(
		character_id,
		dialogue,
		"AI schedule reminder"
	)
	return true

func handle_fluster_banter_ready(
	request_id: int,
	lines: Array
) -> bool:
	if request_id != fluster_request_id:
		return false

	fluster_request_id = 0
	call_deferred(
		"_play_generated_lines",
		lines.duplicate(true),
		"AI fluster peer banter"
	)
	return true

func handle_focus_session_bundle_ready(
	session_id: int,
	character_id: String,
	bundle: Dictionary
) -> bool:
	if session_id != focus_session_id:
		return false

	if bundle.is_empty():
		set_output(
			"AI timer bundle returned no dialogue."
		)
		return true

	set_output(
		_format_timer_bundle(
			character_id,
			bundle
		)
	)
	return true

func handle_hourly_event_dialogue_ready(
	request_id: int,
	character_id: String,
	dialogue: Dictionary
) -> bool:
	if request_id != hourly_request_id:
		return false

	hourly_request_id = 0
	_show_generated_dialogue(
		character_id,
		dialogue,
		"AI hourly comment"
	)
	return true

func handle_interactive_question_ready(
	request_id: int,
	scene: Dictionary
) -> bool:
	if request_id != interactive_question_request_id:
		return false

	interactive_question_request_id = 0
	if scene.is_empty():
		set_output(
			"Interactive-question generation failed. No fallback question was used."
		)
		return true

	set_output(
		"Interactive question generated. Queued for playback."
	)
	_app_call(
		"_enqueue_dialogue_event",
		[
			"interactive_question",
			{
				"scene": scene.duplicate(true),
				"debug_mode": true
			},
			DEBUG_INTERACTIVE_PRIORITY,
			"debug_interactive_question",
			true
		]
	)
	return true

func show_progress(target_slot: int) -> void:
	show_progress_for_character(
		_get_target_character(target_slot)
	)

func show_progress_for_character(
	character_id: String
) -> void:
	var friendship: int = 0
	var friendship_actual: int = 0
	var friendship_level: int = 0
	var friendship_text: String = "Friendship: unavailable"

	if not character_id.is_empty():
		friendship = DesktopCharacterProgressScript.get_friendship(
			character_id
		)
		friendship_actual = DesktopCharacterProgressScript.get_actual_friendship(
			character_id
		)
		friendship_level = DesktopCharacterProgressScript.get_friendship_level(
			character_id
		)
		friendship_text = (
			"Friendship [" + character_id + "]: "
			+ str(friendship)
		)
		if DesktopCharacterProgressScript.has_debug_friendship_override(
			character_id
		):
			friendship_text += (
				" (debug override; actual "
				+ str(friendship_actual)
				+ ")"
			)

	var achievement: int = (
		DesktopCharacterProgressScript.get_achievement_minutes()
	)
	var achievement_actual: int = (
		DesktopCharacterProgressScript.get_actual_achievement_minutes()
	)
	var achievement_level: int = (
		DesktopCharacterProgressScript.get_achievement_level()
	)
	var achievement_text: String = (
		"Achievement: "
		+ str(achievement)
		+ " min this week"
	)
	if DesktopCharacterProgressScript.has_debug_achievement_override():
		achievement_text += (
			" (debug override; actual "
			+ str(achievement_actual)
			+ " min)"
		)

	var text: String = friendship_text + "\n" + achievement_text
	var board: CompanionBoardWindow = _board_window()
	if board == null:
		return
	board.set_debug_progress_levels(
		friendship_level,
		DesktopCharacterProgressScript.get_max_friendship_level(),
		achievement_level,
		DesktopCharacterProgressScript.get_max_achievement_level(),
		text
	)

func set_output(text: String) -> void:
	var board: CompanionBoardWindow = _board_window()
	if board != null:
		board.set_debug_output(text)

func _get_target_character(target_slot: int) -> String:
	var manager: DesktopCharacterManager = _app_property("desktop_character_manager") as DesktopCharacterManager
	if manager == null:
		return ""
	var slots: Array[String] = manager.get_slot_character_ids()
	if target_slot < 0 or target_slot >= slots.size():
		return ""
	var character_id: String = slots[target_slot].strip_edges().to_lower()
	if character_id.is_empty() or manager.get_actor(character_id) == null:
		return ""
	return character_id

func _generate_ambient_pool() -> void:
	var ambient: AmbientDialogue = _app_property("ambient_dialogue") as AmbientDialogue
	if ambient == null:
		set_output("Ambient generation service is unavailable.")
		return
	if ambient.generation_in_progress:
		set_output("Ambient pool generation is already running.")
		return
	ambient.request_generation_pass()
	set_output("Ambient pool generation requested with the configured AI model.")

func _play_ambient_now() -> void:
	if _app_property("ambient_dialogue_playback") == null:
		set_output(
			"Ambient playback service is unavailable."
		)
		return

	_app_call("_cancel_ambient_for_priority_event")
	_app_call("request_ambient_event")
	set_output(
		"Requested an ambient event from the current pool."
	)

func _request_hourly_comment(target_slot: int) -> void:
	var character_id: String = _get_target_character(
		target_slot
	)
	if character_id.is_empty():
		set_output(
			"No active character in that desktop slot."
		)
		return

	var events: CharacterEventDialogue = _app_property("character_event_dialogue") as CharacterEventDialogue
	if events == null:
		set_output(
			"Character event dialogue service is unavailable."
		)
		return

	if hourly_request_id > 0:
		set_output(
			"An hourly debug request is already pending."
		)
		return

	var active_ids: Array[String] = _desktop_character_ids()
	var now: Dictionary = Time.get_datetime_dict_from_system()
	hourly_request_id = events.request_hourly_comment(
		character_id,
		int(now.get("hour", 0)),
		active_ids
	)

	if hourly_request_id <= 0:
		hourly_request_id = 0
		set_output(
			"Could not start the hourly AI request."
		)
		return

	set_output(
		"Hourly AI request started for "
		+ character_id
		+ "."
	)

func _request_timer_bundle(target_slot: int) -> void:
	var character_id: String = _get_target_character(
		target_slot
	)
	if character_id.is_empty():
		set_output(
			"No active character in that desktop slot."
		)
		return

	var reactions: DesktopAIReactions = _app_property("desktop_ai_reactions") as DesktopAIReactions
	if reactions == null:
		set_output(
			"Timer reaction service is unavailable."
		)
		return

	focus_session_id -= 1
	reactions.request_focus_session_bundle(
		focus_session_id,
		character_id,
		"Debug focus session",
		25
	)
	set_output(
		"Timer reaction bundle requested for "
		+ character_id
		+ "."
	)

func _request_schedule_reminder(target_slot: int) -> void:
	var character_id: String = _get_target_character(
		target_slot
	)
	if character_id.is_empty():
		set_output(
			"No active character in that desktop slot."
		)
		return

	var events: CharacterEventDialogue = _app_property("character_event_dialogue") as CharacterEventDialogue
	if events == null:
		set_output(
			"Character event dialogue service is unavailable."
		)
		return

	if schedule_request_id > 0:
		set_output(
			"A schedule reminder debug request is already pending."
		)
		return

	schedule_request_id = events.request_schedule_reminder(
		character_id,
		"Debug schedule",
		10
	)
	if schedule_request_id <= 0:
		schedule_request_id = 0
		set_output(
			"Could not start the schedule reminder AI request."
		)
		return

	set_output(
		"Schedule reminder AI request started for "
		+ character_id
		+ "."
	)

func _request_exit_dialogue() -> void:
	var events: CharacterEventDialogue = _app_property("character_event_dialogue") as CharacterEventDialogue
	if events == null:
		set_output(
			"Character event dialogue service is unavailable."
		)
		return

	var active_ids: Array[String] = _desktop_character_ids()
	if active_ids.is_empty():
		set_output("No active characters.")
		return

	if exit_request_id > 0:
		set_output(
			"An exit dialogue debug request is already pending."
		)
		return

	exit_request_id = events.request_exit_dialogue(active_ids)
	if exit_request_id <= 0:
		exit_request_id = 0
		set_output(
			"Could not start the exit-dialogue AI request."
		)
		return

	set_output(
		"Exit-dialogue AI request started."
	)

func _replay_first_boot(target_slot: int) -> void:
	var character_id: String = _get_target_character(
		target_slot
	)
	if character_id.is_empty():
		set_output(
			"No active character in that desktop slot."
		)
		return

	if (
		bool(_app_property("boot_sequence_busy"))
		or not (_app_property("pending_cast_transition") as Dictionary).is_empty()
		or bool(_app_property("first_boot_sequence_busy"))
	):
		set_output(
			"Another boot or cast sequence is currently busy."
		)
		return

	call_deferred(
		"_replay_first_boot_sequence",
		character_id
	)
	set_output(
		"Replaying first-boot dialogue for "
		+ character_id
		+ " without changing completion state."
	)

func _replay_first_boot_sequence(character_id: String) -> void:
	_app_set("first_boot_sequence_busy", true)
	var timer := _app_property("talk_timer") as Timer
	if timer != null:
		timer.stop()

	await _play_first_boot_sequence(character_id)

	_app_set("first_boot_sequence_busy", false)
	set_output(
		"First-boot replay finished for "
		+ character_id
		+ "."
	)
	_app_call("_try_resume_deferred_events")

func _play_first_boot_sequence(character_id: String) -> void:
	var config: Dictionary = CharacterProfilesScript.get_first_boot_config(
		character_id
	)
	if config.is_empty():
		return

	var lines_value: Variant = config.get("lines", [])
	if not (lines_value is Array):
		return

	var lines: Array = lines_value as Array
	var ask_after: int = int(
		config.get("ask_user_name_after", -1)
	)
	var ask_api_after: int = int(config.get("ask_api_key_after", -1))
	for index: int in range(lines.size()):
		if (
			index == ask_api_after
			and AISettings.get_api_key().is_empty()
		):
			await _request_ai_settings()

		if (
			index == ask_after
			and UserProfileSettingsScript.get_user_name().is_empty()
		):
			await _request_user_name()

		var line_value: Variant = lines[index]
		var line: Dictionary = {}
		if line_value is Dictionary:
			line = (line_value as Dictionary).duplicate(true)
		elif line_value is String:
			line = {
				"text": str(line_value),
				"mood": "neutral"
			}
		else:
			continue

		var user_name: String = UserProfileSettingsScript.get_user_name()
		var output_language: String = (
			CharacterProfilesScript.get_pack_output_language(
				CharacterProfilesScript.get_current_pack()
			)
		)
		var fallback_name: String = (
			"너" if output_language == "ko" else "you"
		)
		line["text"] = str(
			line.get("text", "")
		).replace(
			"{user_name}",
			(
				user_name
				if not user_name.is_empty()
				else fallback_name
			)
		)

		_app_call(
			"_show_pack_event_line",
			[
				character_id,
				line,
				FIRST_BOOT_BUBBLE_SECONDS
			]
		)
		await get_tree().create_timer(
			FIRST_BOOT_STEP_SECONDS
		).timeout

	if (
		ask_after >= lines.size()
		and UserProfileSettingsScript.get_user_name().is_empty()
	):
		await _request_user_name()

	if (
		ask_api_after >= lines.size()
		and AISettings.get_api_key().is_empty()
	):
		await _request_ai_settings()

func _request_ai_settings() -> bool:
	if app == null or not is_instance_valid(app):
		return false
	var dialog := AISettingsDialog.new()
	dialog.theme = AppearanceSettingsScript.build_theme()
	app.add_child(dialog)
	dialog.open_centered()
	var saved: bool = bool(await dialog.finished)
	dialog.queue_free()
	return saved

func _request_user_name() -> String:
	var dialog: UserNameDialog = UserNameDialogScript.new()
	if app == null or not is_instance_valid(app):
		dialog.queue_free()
		return ""
	app.add_child(dialog)
	dialog.open_centered()
	var user_name: String = str(
		await dialog.finished
	).strip_edges()
	return user_name

func _request_fluster_banter(target_slot: int) -> void:
	var character_id: String = _get_target_character(
		target_slot
	)
	if character_id.is_empty():
		set_output(
			"No active character in that desktop slot."
		)
		return

	if not bool(_app_call("_has_play_peer", [character_id])):
		set_output(
			"Fluster peer banter requires two active characters."
		)
		return

	var events: CharacterEventDialogue = _app_property("character_event_dialogue") as CharacterEventDialogue
	if events == null:
		set_output(
			"Character event dialogue service is unavailable."
		)
		return

	if fluster_request_id > 0:
		set_output(
			"A fluster-banter debug request is already pending."
		)
		return

	fluster_request_id = events.request_play_fluster_banter(
		character_id,
		_desktop_character_ids()
	)
	if fluster_request_id <= 0:
		fluster_request_id = 0
		set_output(
			"Could not start the fluster-banter AI request."
		)
		return

	set_output(
		"Fluster peer-banter AI request started for "
		+ character_id
		+ "."
	)

func _force_overlap(target_slot: int) -> void:
	var target_id: String = _get_target_character(
		target_slot
	)
	if target_id.is_empty():
		set_output(
			"No active character in that desktop slot."
		)
		return

	var active_ids: Array[String] = _desktop_character_ids()
	if active_ids.size() < 2:
		set_output(
			"Overlap testing requires two active characters."
		)
		return

	var peer_id: String = ""
	for character_id: String in active_ids:
		if character_id != target_id:
			peer_id = character_id
			break

	if peer_id.is_empty():
		set_output(
			"Could not find another active character."
		)
		return

	var target_actor: DesktopCharacterActor = _app_call(
		"get_desktop_actor", [target_id]
	) as DesktopCharacterActor
	var peer_actor: DesktopCharacterActor = _app_call(
		"get_desktop_actor", [peer_id]
	) as DesktopCharacterActor
	if target_actor == null or peer_actor == null:
		set_output(
			"Selected character cannot be moved for the overlap test."
		)
		return

	var target_rect: Rect2 = _app_call(
		"_get_actor_desktop_pet_rect",
		[target_actor]
	) as Rect2
	var peer_rect: Rect2 = _app_call(
		"_get_actor_desktop_pet_rect",
		[peer_actor]
	) as Rect2
	if (
		target_rect.size == Vector2.ZERO
		or peer_rect.size == Vector2.ZERO
	):
		set_output(
			"Could not read desktop character bounds."
		)
		return

	_app_set("overlap_cooldown_seconds", 0.0)
	_app_call("_reset_overlap_candidate")

	var overlap_left: float = (
		peer_rect.position.x
		+ minf(
			peer_rect.size.x * 0.2,
			target_rect.size.x * 0.2
		)
	)
	target_actor.slide_desktop_pet_to_left(overlap_left, 0.2)

	set_output(
		"Forced "
		+ target_id
		+ " to overlap "
		+ peer_id
		+ ". The normal overlap resolver should react next."
	)

func _request_interactive_question(target_slot: int) -> void:
	var events: CharacterEventDialogue = _app_property("character_event_dialogue") as CharacterEventDialogue
	if events == null:
		set_output(
			"Character event dialogue service is unavailable."
		)
		return

	var queue: DesktopDialogueQueue = _app_property("dialogue_queue") as DesktopDialogueQueue
	if (
		interactive_question_request_id > 0
		or str(_app_call("_active_dialogue_kind")) == "interactive_question"
		or (
			queue != null
			and queue.has_coalesce_key("debug_interactive_question")
		)
	):
		set_output(
			"An interactive-question request or question is already active."
		)
		return

	var active_ids: Array[String] = _desktop_character_ids()
	if active_ids.is_empty():
		set_output(
			"No active desktop characters are available."
		)
		return

	var target_character: String = _get_target_character(
		target_slot
	)
	if target_character.is_empty():
		set_output(
			"No active character in that desktop slot."
		)
		return

	_app_call("_clear_interactive_question_opportunity")
	var progress_context: Variant = _app_call(
		"_build_interactive_progress_context",
		[active_ids]
	)
	var activity_context: Variant = _app_call(
		"_build_interactive_activity_context"
	)
	interactive_question_request_id = events.request_interactive_question(
		active_ids,
		"debug",
		{"preferred_question_speaker": target_character},
		(
			progress_context as Dictionary
				if progress_context is Dictionary
				else {}
		),
		(
			activity_context as Dictionary
				if activity_context is Dictionary
				else {}
		)
	)
	if interactive_question_request_id <= 0:
		interactive_question_request_id = 0
		set_output(
			"Could not start the interactive-question AI request."
		)
		return

	set_output(
		"Interactive-question AI request started."
	)

func _set_friendship_level(
	target_slot: int,
	level: int
) -> void:
	var character_id: String = _get_target_character(
		target_slot
	)
	if character_id.is_empty():
		set_output(
			"No active character in that desktop slot."
		)
		return
	DesktopCharacterProgressScript.set_debug_friendship_level(
		character_id,
		level
	)
	show_progress_for_character(character_id)

func _set_achievement_level(
	target_slot: int,
	level: int
) -> void:
	DesktopCharacterProgressScript.set_debug_achievement_level(
		level
	)
	show_progress(target_slot)

func _restore_progress(target_slot: int) -> void:
	DesktopCharacterProgressScript.clear_debug_overrides()
	show_progress(target_slot)
	set_output(
		"Debug progression overrides cleared. Actual earned progress is active again."
	)

func _validate_current_pack() -> void:
	var report: Dictionary = CharacterProfilesScript.validate_profiles()
	var valid_value: Variant = report.get("valid", [])
	var invalid_value: Variant = report.get("invalid", [])
	var valid: Array = (
		valid_value
		if valid_value is Array
		else []
	)
	var invalid: Array = (
		invalid_value
		if invalid_value is Array
		else []
	)

	var invalid_ids: PackedStringArray = PackedStringArray()
	for value: Variant in invalid:
		invalid_ids.append(str(value))

	var invalid_text: String = (
		", ".join(invalid_ids)
		if not invalid_ids.is_empty()
		else "none"
	)
	set_output(
		"Pack: "
		+ CharacterProfilesScript.get_current_pack()
		+ "\nValid profiles: "
		+ str(valid.size())
		+ "\nInvalid profiles: "
		+ invalid_text
	)

func _show_generated_dialogue(
	character_id: String,
	dialogue: Dictionary,
	label_text: String
) -> void:
	if dialogue.is_empty():
		set_output(
			label_text
			+ " returned no dialogue."
		)
		return

	var speaker: String = str(
		dialogue.get(
			"speaker",
			character_id
		)
	).strip_edges().to_lower()
	var text: String = str(
		dialogue.get(
			"text",
			""
		)
	).strip_edges()
	var mood: String = str(
		dialogue.get(
			"mood",
			"neutral"
		)
	).strip_edges().to_lower()

	if speaker.is_empty():
		speaker = character_id
	if text.is_empty():
		set_output(
			label_text
			+ " returned an empty line."
		)
		return

	_app_call(
		"_show_character_dialogue",
		[speaker, text, mood, 6.0]
	)
	set_output(
		label_text
		+ "\n"
		+ speaker
		+ ": "
		+ text
	)

func _play_generated_lines(
	lines: Array,
	label_text: String
) -> void:
	if lines.is_empty():
		set_output(
			label_text
			+ " returned no lines."
		)
		return

	var shown_lines: Array[String] = []
	for value: Variant in lines:
		if not (value is Dictionary):
			continue

		var line: Dictionary = value as Dictionary
		var speaker: String = str(
			line.get("speaker", "")
		).strip_edges().to_lower()
		var text: String = str(
			line.get("text", "")
		).strip_edges()
		var mood: String = str(
			line.get("mood", "neutral")
		).strip_edges().to_lower()
		if speaker.is_empty() or text.is_empty():
			continue

		_app_call(
			"_show_character_dialogue",
			[speaker, text, mood, 4.5]
		)
		shown_lines.append(
			speaker
			+ ": "
			+ text
		)
		await get_tree().create_timer(3.2).timeout

	set_output(
		label_text
		+ "\n"
		+ "\n".join(shown_lines)
	)

func _format_timer_bundle(
	character_id: String,
	bundle: Dictionary
) -> String:
	var lines: Array[String] = [
		"AI timer bundle for " + character_id + ":"
	]
	for event_key: String in [
		"pause",
		"resume",
		"stop",
		"end"
	]:
		var dialogue_value: Variant = bundle.get(
			event_key,
			{}
		)
		if not (dialogue_value is Dictionary):
			continue

		var text: String = str(
			(dialogue_value as Dictionary).get(
				"text",
				""
			)
		).strip_edges()
		if text.is_empty():
			continue

		lines.append(
			event_key.capitalize()
			+ ": "
			+ text
		)
	return "\n".join(lines)

func _desktop_character_ids() -> Array[String]:
	var value: Variant = _app_call(
		"get_desktop_character_ids"
	)
	if value is Array:
		var result: Array[String] = []
		for item: Variant in value:
			result.append(str(item))
		return result
	return []

func _board_window() -> CompanionBoardWindow:
	return _app_property("board_window") as CompanionBoardWindow

func _app_property(property_name: StringName) -> Variant:
	if app == null or not is_instance_valid(app):
		return null
	return app.get(property_name)

func _app_set(
	property_name: StringName,
	value: Variant
) -> void:
	if app == null or not is_instance_valid(app):
		return
	app.set(property_name, value)

func _app_call(
	method_name: StringName,
	args: Array = []
) -> Variant:
	if app == null or not is_instance_valid(app):
		return null
	if not app.has_method(method_name):
		return null
	return app.callv(method_name, args)
