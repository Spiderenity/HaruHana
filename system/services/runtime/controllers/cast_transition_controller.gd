extends Node
class_name CastTransitionController

signal transition_finished

const CAST_TRANSITION_BUBBLE_DURATION: float = 4.5
const CAST_TRANSITION_STEP_SECONDS: float = 3.2
const DIALOGUE_PRIORITY_CAST: int = 100

var character_manager: DesktopCharacterManager = null
var character_event_dialogue: CharacterEventDialogue = null
var orchestrator: DesktopDialogueOrchestrator = null
var presenter: DesktopDialoguePresenter = null
var exit_controller: ExitFlowController = null

var pending_cast_transition: Dictionary = {}

func configure(
	manager: DesktopCharacterManager,
	event_dialogue: CharacterEventDialogue,
	dialogue_orchestrator: DesktopDialogueOrchestrator,
	dialogue_presenter: DesktopDialoguePresenter,
	exit_flow: ExitFlowController
) -> void:
	character_manager = manager
	character_event_dialogue = event_dialogue
	orchestrator = dialogue_orchestrator
	presenter = dialogue_presenter
	exit_controller = exit_flow

func has_pending_transition() -> bool:
	return not pending_cast_transition.is_empty()

func resume_pending_if_needed() -> bool:
	if pending_cast_transition.is_empty():
		return false
	var queued_id: int = int(pending_cast_transition.get("queue_event_id", 0))
	var request_id: int = int(pending_cast_transition.get("request_id", 0))
	if queued_id <= 0 and request_id > 0:
		return true
	if queued_id <= 0 and request_id <= 0:
		_try_start_cast_transition_request()
		return true
	return false

func _on_character_unavailable_selected(
	_character_id: String,
	_remaining_seconds: float,
	lines: Array
) -> void:

	for value: Variant in lines:
		if not (
			value is Dictionary
		):
			continue

		var line: Dictionary = (
			value
		)

		var speaker: String = str(
			line.get(
				"speaker",
				""
			)
		).strip_edges().to_lower()

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

		if (
			speaker.is_empty()
			or text.is_empty()
		):
			continue

		if presenter.show(
			speaker,
			text,
			mood,
			4.5
		):
			return

func _on_slot_change_requested(
	slot_index: int,
	old_character_id: String,
	new_character_id: String
) -> void:

	pending_cast_transition = {
		"slot_index": slot_index,
		"old_character_id": old_character_id,
		"new_character_id": new_character_id,
		"request_id": 0,
		"queue_event_id": 0,
		"exit_dialogue": {}
	}

	orchestrator.stop_talk_timer()

	_try_start_cast_transition_request()

func _try_start_cast_transition_request() -> void:
	if pending_cast_transition.is_empty():
		return
	if int(pending_cast_transition.get("request_id", 0)) > 0:
		return
	if int(pending_cast_transition.get("queue_event_id", 0)) > 0:
		return

	if character_event_dialogue == null:
		_queue_cast_transition(_build_local_cast_transition_fallback())
		return

	var request_id: int = int(
		character_event_dialogue.request_cast_transition(
			int(pending_cast_transition.get("slot_index", 0)),
			str(pending_cast_transition.get("old_character_id", "")),
			str(pending_cast_transition.get("new_character_id", "")),
			character_manager.get_active_character_ids()
		)
	)
	if request_id <= 0:
		_queue_cast_transition(_build_local_cast_transition_fallback())
		return
	pending_cast_transition["request_id"] = request_id

func _on_cast_transition_dialogue_ready(
	request_id: int,
	lines: Array,
	exit_dialogue: Dictionary
) -> void:
	if pending_cast_transition.is_empty():
		return
	if request_id != int(pending_cast_transition.get("request_id", 0)):
		return
	pending_cast_transition["request_id"] = 0
	pending_cast_transition["exit_dialogue"] = exit_dialogue.duplicate(true)
	_queue_cast_transition(lines)

func _queue_cast_transition(lines: Array) -> void:
	if pending_cast_transition.is_empty():
		return
	var event_id: int = orchestrator.enqueue(
		"cast_transition",
		{"lines": lines.duplicate(true)},
		DIALOGUE_PRIORITY_CAST,
		"cast_transition",
		true
	)
	pending_cast_transition["queue_event_id"] = event_id

func _execute_queued_cast_transition(event: Dictionary) -> void:
	var event_id: int = int(event.get("id", 0))
	var payload_value: Variant = event.get("payload", {})
	if not (payload_value is Dictionary):
		orchestrator.complete(event_id)
		return
	var lines_value: Variant = (payload_value as Dictionary).get("lines", [])
	if not (lines_value is Array):
		orchestrator.complete(event_id)
		return
	await _play_cast_transition_sequence((lines_value as Array).duplicate(true), event_id)

func _play_cast_transition_sequence(
	lines: Array,
	event_id: int
) -> void:
	if pending_cast_transition.is_empty():
		orchestrator.complete(event_id)
		return

	for line_value: Variant in lines:
		if not (line_value is Dictionary):
			continue
		var before_line: Dictionary = line_value
		if str(before_line.get("phase", "")) != "before":
			continue
		await _play_cast_transition_line(before_line)

	var slot_index: int = int(pending_cast_transition.get("slot_index", 0))
	var commit_error: int = int(
		character_manager.commit_pending_slot_change(
			slot_index
		)
	)
	if commit_error != OK:
		pending_cast_transition.clear()
		orchestrator.complete(event_id)
		return

	await get_tree().create_timer(0.2).timeout

	for line_value: Variant in lines:
		if not (line_value is Dictionary):
			continue
		var after_line: Dictionary = line_value
		if str(after_line.get("phase", "")) != "after":
			continue
		await _play_cast_transition_line(after_line)

	character_manager.finish_pending_slot_change(slot_index, OK)

	var exit_value: Variant = pending_cast_transition.get("exit_dialogue", {})
	if exit_value is Dictionary:
		exit_controller.cache_after_cast(exit_value as Dictionary)
	else:
		exit_controller.cache_after_cast({})
	pending_cast_transition.clear()
	transition_finished.emit()
	orchestrator.complete(event_id)

func _play_cast_transition_line(
	line: Dictionary
) -> void:

	var speaker: String = str(
		line.get(
			"speaker",
			""
		)
	).strip_edges().to_lower()

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

	if (
		speaker.is_empty()
		or text.is_empty()
	):
		return

	var shown: bool = (
		presenter.show(
			speaker,
			text,
			mood,
			CAST_TRANSITION_BUBBLE_DURATION
		)
	)

	if not shown:
		return

	await get_tree().create_timer(
		CAST_TRANSITION_STEP_SECONDS
	).timeout

func _build_local_cast_transition_fallback() -> Array:
	var lines: Array = []

	var old_character_id: String = str(
		pending_cast_transition.get(
			"old_character_id",
			""
		)
	)

	var new_character_id: String = str(
		pending_cast_transition.get(
			"new_character_id",
			""
		)
	)

	if not old_character_id.is_empty():
		lines.append(
			{
				"phase": "before",
				"speaker": old_character_id,
				"text": (
					"I'm heading out. Try not to "
					+ "make a disaster of the place."
				),
				"mood": "annoyed"
			}
		)

	if not new_character_id.is_empty():
		lines.append(
			{
				"phase": "after",
				"speaker": new_character_id,
				"text": (
					"I'm here. You can stop staring now."
				),
				"mood": "curious"
			}
		)

	return lines
