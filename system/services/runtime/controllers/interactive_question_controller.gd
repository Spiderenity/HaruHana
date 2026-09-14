extends Node
class_name InteractiveQuestionController

const INTERACTIVE_QUESTION_CHANCE: float = 0.40
const INTERACTIVE_SCENE_BUBBLE_DURATION: float = 4.5
const INTERACTIVE_SCENE_STEP_SECONDS: float = 4.7

var board_window: CompanionBoardWindow = null
var character_manager: DesktopCharacterManager = null
var character_event_dialogue: CharacterEventDialogue = null
var debug_tools: EasterEggDebugTools = null
var orchestrator: DesktopDialogueOrchestrator = null
var presenter: DesktopDialoguePresenter = null
var focus_controller: FocusEventController = null

var interactive_question_slot_armed: bool = false
var interactive_question_request_id: int = 0
var interactive_question_scene: Dictionary = {}
var recent_chat_activity: Dictionary = {}

func configure(
	board: CompanionBoardWindow,
	manager: DesktopCharacterManager,
	event_dialogue: CharacterEventDialogue,
	debug: EasterEggDebugTools,
	dialogue_orchestrator: DesktopDialogueOrchestrator,
	dialogue_presenter: DesktopDialoguePresenter
) -> void:
	board_window = board
	character_manager = manager
	character_event_dialogue = event_dialogue
	debug_tools = debug
	orchestrator = dialogue_orchestrator
	presenter = dialogue_presenter

func bind_focus_controller(focus_flow: FocusEventController) -> void:
	focus_controller = focus_flow

func record_chat_activity(
	character_id: String,
	user_message: String,
	character_response: String
) -> void:
	var clean_user_message: String = user_message.strip_edges()
	var clean_character_response: String = character_response.strip_edges()
	if clean_user_message.is_empty() and clean_character_response.is_empty():
		return
	recent_chat_activity = {
		"character_id": character_id.strip_edges().to_lower(),
		"user_message": clean_user_message.left(500),
		"character_response": clean_character_response.left(500),
	}

func has_armed_opportunity() -> bool:
	return interactive_question_slot_armed

func consume_ready_scene() -> Dictionary:
	if not interactive_question_slot_armed:
		return {}
	var scene: Dictionary = interactive_question_scene.duplicate(true)
	clear_opportunity()
	return scene

func arm(
	source_event: String,
	source_context: Dictionary
) -> void:
	if interactive_question_slot_armed or orchestrator.active_kind() == "interactive_question":
		return
	if orchestrator.has_coalesce_key("interactive_question"):
		return
	if character_event_dialogue == null:
		return
	if randf() >= INTERACTIVE_QUESTION_CHANCE:
		return

	var active_ids: Array[String] = character_manager.get_active_character_ids()
	if active_ids.is_empty():
		return

	interactive_question_slot_armed = true
	interactive_question_scene.clear()
	interactive_question_request_id = int(
		character_event_dialogue.request_interactive_question(
			active_ids,
			source_event,
			source_context,
			_build_interactive_progress_context(active_ids),
			_build_interactive_activity_context()
		)
	)

	if interactive_question_request_id <= 0:
		interactive_question_request_id = 0

func _build_interactive_progress_context(
	character_ids: Array[String]
) -> Dictionary:
	var characters: Dictionary = {}
	for character_id: String in character_ids:
		characters[character_id] = DesktopCharacterProgress.get_context(character_id)
	return {
		"characters": characters,
		"weekly_achievement_minutes": DesktopCharacterProgress.get_achievement_minutes(),
		"weekly_achievement_level": DesktopCharacterProgress.get_achievement_level(),
	}

func _build_interactive_activity_context() -> Dictionary:
	var context: Dictionary = {}
	var active_focus_session: Dictionary = focus_controller.get_active_session()
	var last_focus_activity: Dictionary = focus_controller.get_last_activity()

	if not active_focus_session.is_empty():
		context["focus"] = {
			"task_name": str(active_focus_session.get("task_name", "")),
			"planned_minutes": int(active_focus_session.get("planned_minutes", 0)),
			"status": "active",
		}
	elif not last_focus_activity.is_empty():
		context["focus"] = last_focus_activity.duplicate(true)

	var memo_text: String = board_window.get_interactive_memo_context(600).strip_edges()
	if not memo_text.is_empty():
		context["memo"] = memo_text

	if not recent_chat_activity.is_empty():
		context["recent_chat"] = recent_chat_activity.duplicate(true)

	return context

func _on_interactive_question_ready(
	request_id: int,
	scene: Dictionary
) -> void:
	if (
		debug_tools != null
		and debug_tools.handle_interactive_question_ready(
			request_id,
			scene
		)
	):
		return

	if request_id != interactive_question_request_id or not interactive_question_slot_armed:
		return
	interactive_question_request_id = 0
	interactive_question_scene = scene.duplicate(true)

func clear_opportunity() -> void:
	interactive_question_slot_armed = false
	interactive_question_request_id = 0
	interactive_question_scene.clear()

func _play_interactive_question_scene(
	scene: Dictionary,
	debug_mode: bool,
	event_id: int
) -> void:
	var question_value: Variant = scene.get("question", {})
	if not (question_value is Dictionary):
		if debug_mode and debug_tools != null:
			debug_tools.set_output(
				"Interactive question data was invalid."
			)
		orchestrator.complete(event_id)
		return

	var question: Dictionary = (question_value as Dictionary).duplicate(true)
	var asker: String = str(question.get("speaker", "")).strip_edges().to_lower()
	var actor: DesktopCharacterActor = character_manager.get_actor(asker)
	if actor == null:
		if debug_mode and debug_tools != null:
			debug_tools.set_output(
				"The generated question's asking character is not available."
			)
		orchestrator.complete(event_id)
		return

	var lines_value: Variant = scene.get("lines", [])
	if lines_value is Array:
		for value: Variant in (lines_value as Array):
			if not (value is Dictionary):
				continue
			var line: Dictionary = value as Dictionary
			var speaker: String = str(line.get("speaker", "")).strip_edges().to_lower()
			var text_line: String = str(line.get("text", "")).strip_edges()
			var mood: String = str(line.get("mood", "neutral")).strip_edges().to_lower()
			if speaker.is_empty() or text_line.is_empty():
				continue
			if presenter.show(
				speaker,
				text_line,
				mood,
				INTERACTIVE_SCENE_BUBBLE_DURATION
			):
				await get_tree().create_timer(INTERACTIVE_SCENE_STEP_SECONDS).timeout

	actor = character_manager.get_actor(asker)
	if actor == null:
		orchestrator.complete(event_id)
		return
	var opened: bool = actor.open_interactive_question(question)
	if not opened:
		if debug_mode and debug_tools != null:
			debug_tools.set_output(
				"The question window could not be opened."
			)
		orchestrator.complete(event_id)
		return
	if debug_mode and debug_tools != null:
		debug_tools.set_output(
			"Interactive question is open. Answer it, click its top cap, or let it time out."
		)

func _on_character_interactive_question_answered(
	character_id: String,
	answer: Dictionary
) -> void:
	if orchestrator.active_kind() != "interactive_question":
		return
	var event_id: int = orchestrator.active_id()
	var gain: int = clampi(int(answer.get("friendship_gain", 0)), 0, 1)
	if gain > 0:
		DesktopCharacterProgress.add_friendship(character_id, 1)
	if debug_tools != null:
		debug_tools.show_progress_for_character(
			character_id
		)

	var reaction_value: Variant = answer.get("reaction", {})
	var reaction_shown: bool = false
	if reaction_value is Dictionary:
		var reaction: Dictionary = reaction_value as Dictionary
		var text_line: String = str(reaction.get("text", "")).strip_edges()
		if not text_line.is_empty():
			reaction_shown = presenter.show(
				character_id,
				text_line,
				str(reaction.get("mood", "neutral")),
				INTERACTIVE_SCENE_BUBBLE_DURATION
			)
	if reaction_shown:
		await get_tree().create_timer(INTERACTIVE_SCENE_STEP_SECONDS).timeout
	orchestrator.complete(event_id)

func _on_character_interactive_question_dismissed(
	_character_id: String,
	_reason: String
) -> void:
	if orchestrator.active_kind() != "interactive_question":
		return
	orchestrator.complete(orchestrator.active_id())

func _execute_queued_interactive_question(event: Dictionary) -> void:
	var event_id: int = int(event.get("id", 0))
	if character_manager != null and character_manager.focus_timer_active and not character_manager.focus_timer_paused:
		orchestrator.complete(event_id)
		return
	var payload_value: Variant = event.get("payload", {})
	if not (payload_value is Dictionary):
		orchestrator.complete(event_id)
		return
	var payload: Dictionary = payload_value as Dictionary
	var scene_value: Variant = payload.get("scene", {})
	if not (scene_value is Dictionary):
		orchestrator.complete(event_id)
		return
	await _play_interactive_question_scene(
		(scene_value as Dictionary).duplicate(true),
		bool(payload.get("debug_mode", false)),
		event_id
	)
