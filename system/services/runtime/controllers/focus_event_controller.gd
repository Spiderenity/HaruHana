extends Node
class_name FocusEventController

signal interactive_opportunity_requested(source_event: String, source_context: Dictionary)

const FOCUS_REACTION_BUBBLE_DURATION: float = 5.0
const FOCUS_REACTION_STEP_SECONDS: float = 5.5
const DIALOGUE_PRIORITY_FOCUS: int = 70

var character_manager: DesktopCharacterManager = null
var desktop_ai_reactions: DesktopAIReactions = null
var debug_tools: EasterEggDebugTools = null
var orchestrator: DesktopDialogueOrchestrator = null
var presenter: DesktopDialoguePresenter = null

var focus_session_serial: int = 0
var active_focus_session: Dictionary = {}
var last_focus_activity: Dictionary = {}
var active_focus_reaction_bundle: Dictionary = {}
var retained_pomodoro_character_id: String = ""
var retained_pomodoro_task_name: String = ""
var retained_pomodoro_reaction_bundle: Dictionary = {}

func configure(
	manager: DesktopCharacterManager,
	ai_reactions: DesktopAIReactions,
	debug: EasterEggDebugTools,
	dialogue_orchestrator: DesktopDialogueOrchestrator,
	dialogue_presenter: DesktopDialoguePresenter
) -> void:
	character_manager = manager
	desktop_ai_reactions = ai_reactions
	debug_tools = debug
	orchestrator = dialogue_orchestrator
	presenter = dialogue_presenter

func clear_cached_reactions() -> void:
	active_focus_reaction_bundle.clear()

func get_active_session() -> Dictionary:
	return active_focus_session.duplicate(true)

func get_last_activity() -> Dictionary:
	return last_focus_activity.duplicate(true)

func _on_focus_session_started(
	task_name: String,
	planned_minutes: int
) -> void:

	focus_session_serial += 1

	var clean_task_name: String = (
		task_name.strip_edges()
	)

	if clean_task_name.is_empty():
		clean_task_name = "Focus session"

	active_focus_session = {
		"session_id": focus_session_serial,
		"task_name": clean_task_name,
		"planned_minutes": planned_minutes,
		"character_id": ""
	}
	_record_focus_activity(clean_task_name, planned_minutes, "active")

	active_focus_reaction_bundle.clear()

	var candidates: Array[String] = (
		_get_timer_reaction_candidates()
	)

	if candidates.is_empty():
		return

	var character_id: String = (
		candidates[
			randi_range(
				0,
				candidates.size() - 1
			)
		]
	)

	active_focus_session[
		"character_id"
	] = character_id

	if desktop_ai_reactions == null:
		return

	active_focus_reaction_bundle = desktop_ai_reactions.get_focus_session_fallback_bundle(
		character_id,
		clean_task_name,
		planned_minutes
	).duplicate(true)

	desktop_ai_reactions.request_focus_session_bundle(
		focus_session_serial,
		character_id,
		clean_task_name,
		planned_minutes
	)
	_queue_focus_timer_reaction("start")

func _on_focus_session_bundle_ready(
	session_id: int,
	character_id: String,
	bundle: Dictionary
) -> void:

	if (
		debug_tools != null
		and debug_tools.handle_focus_session_bundle_ready(
			session_id,
			character_id,
			bundle
		)
	):
		return

	if active_focus_session.is_empty():
		return

	if int(
		active_focus_session.get(
			"session_id",
			0
		)
	) != session_id:
		return

	if str(
		active_focus_session.get(
			"character_id",
			""
		)
	) != character_id:
		return

	if bundle.is_empty():
		return

	active_focus_reaction_bundle = (
		bundle.duplicate(true)
	)

func _record_focus_activity(
	task_name: String,
	planned_minutes: int,
	status: String
) -> void:
	var clean_task_name: String = task_name.strip_edges()
	if clean_task_name.is_empty():
		clean_task_name = str(active_focus_session.get("task_name", "Focus session"))
	last_focus_activity = {
		"task_name": clean_task_name,
		"planned_minutes": maxi(0, planned_minutes),
		"status": status.strip_edges().to_lower(),
	}

func _on_focus_session_paused(
	task_name: String,
	planned_minutes: int
) -> void:

	_record_focus_activity(task_name, planned_minutes, "paused")
	_queue_focus_timer_reaction(
		"pause"
	)

func _on_focus_session_resumed(
	task_name: String,
	planned_minutes: int
) -> void:

	_record_focus_activity(task_name, planned_minutes, "active")
	_queue_focus_timer_reaction(
		"resume"
	)

func _on_focus_session_stopped(
	task_name: String,
	planned_minutes: int
) -> void:

	_record_focus_activity(task_name, planned_minutes, "stopped")
	_queue_focus_timer_reaction(
		"stop"
	)
	retained_pomodoro_character_id = ""
	retained_pomodoro_task_name = ""
	retained_pomodoro_reaction_bundle.clear()

	_clear_active_focus_session()

func _on_focus_session_completed(
	task_name: String,
	planned_minutes: int
) -> void:
	character_manager.restore_from_desktop_minimize()

	_queue_focus_timer_reaction(
		"end"
	)
	retained_pomodoro_character_id = str(
		active_focus_session.get("character_id", "")
	)
	retained_pomodoro_task_name = str(
		active_focus_session.get("task_name", task_name)
	)
	retained_pomodoro_reaction_bundle = active_focus_reaction_bundle.duplicate(true)

	_record_focus_activity(task_name, planned_minutes, "completed")
	if not active_focus_session.is_empty():
		var rewarded_character := retained_pomodoro_character_id
		if rewarded_character.is_empty():
			for character_id in character_manager.get_slot_character_ids():
				if not character_id.is_empty():
					rewarded_character = character_id
					break
		DesktopCharacterProgress.reward_focus_completion(rewarded_character, planned_minutes)
	_clear_active_focus_session()

func _on_focus_session_milestone(
	event_key: String,
	_task_name: String,
	_planned_minutes: int
) -> void:
	_queue_focus_timer_reaction(event_key)

func _on_pomodoro_phase_started(
	_phase: String,
	task_name: String,
	planned_minutes: int
) -> void:
	_queue_retained_pomodoro_reaction("break_start", task_name, planned_minutes)

func _on_pomodoro_break_prompted(
	task_name: String,
	planned_minutes: int
) -> void:
	_queue_retained_pomodoro_reaction("break_prompt", task_name, planned_minutes)

func _on_pomodoro_phase_finished(
	phase: String,
	task_name: String,
	planned_minutes: int
) -> void:
	_queue_retained_pomodoro_reaction("break_end", task_name, planned_minutes)
	if phase == "long_break":
		_queue_retained_pomodoro_reaction("cycle_end", task_name, planned_minutes)
		retained_pomodoro_character_id = ""
		retained_pomodoro_task_name = ""
		retained_pomodoro_reaction_bundle.clear()

func _get_timer_reaction_candidates() -> Array[String]:
	var candidates: Array[String] = []
	for character_id: String in character_manager.get_active_character_ids():
		var actor: DesktopCharacterActor = character_manager.get_actor(character_id)
		if actor != null and actor.get_timer_reactions_enabled():
			candidates.append(character_id)
	return candidates

func _queue_focus_timer_reaction(
	event_key: String
) -> void:
	if active_focus_session.is_empty():
		return
	var character_id: String = str(
		active_focus_session.get("character_id", "")
	).strip_edges().to_lower()
	if character_id.is_empty():
		return
	_queue_reaction_from_bundle(
		character_id,
		active_focus_reaction_bundle,
		event_key,
		str(active_focus_session.get("task_name", "")),
		int(active_focus_session.get("planned_minutes", 0))
	)

func _queue_retained_pomodoro_reaction(
	event_key: String,
	task_name: String,
	planned_minutes: int
) -> void:
	if retained_pomodoro_character_id.is_empty():
		return
	_queue_reaction_from_bundle(
		retained_pomodoro_character_id,
		retained_pomodoro_reaction_bundle,
		event_key,
		task_name if not task_name.is_empty() else retained_pomodoro_task_name,
		planned_minutes
	)

func _queue_reaction_from_bundle(
	character_id: String,
	bundle: Dictionary,
	event_key: String,
	task_name: String,
	planned_minutes: int
) -> void:
	var dialogue_value: Variant = bundle.get(event_key, {})
	if not (dialogue_value is Dictionary):
		return
	var dialogue: Dictionary = (dialogue_value as Dictionary).duplicate(true)
	if str(dialogue.get("text", "")).strip_edges().is_empty():
		return
	orchestrator.enqueue(
		"focus",
		{
			"character_id": character_id,
			"dialogue": dialogue,
			"event": event_key,
			"task_name": task_name,
			"planned_minutes": planned_minutes,
		},
		DIALOGUE_PRIORITY_FOCUS
	)

func _execute_queued_focus_reaction(event: Dictionary) -> void:
	var event_id: int = int(event.get("id", 0))
	var payload_value: Variant = event.get("payload", {})
	if not (payload_value is Dictionary):
		orchestrator.complete(event_id)
		return
	var payload: Dictionary = payload_value as Dictionary
	var character_id: String = str(payload.get("character_id", "")).strip_edges().to_lower()
	var dialogue_value: Variant = payload.get("dialogue", {})
	if character_id.is_empty() or not (dialogue_value is Dictionary):
		orchestrator.complete(event_id)
		return
	var dialogue: Dictionary = dialogue_value as Dictionary
	var text: String = str(dialogue.get("text", "")).strip_edges()
	var mood: String = str(dialogue.get("mood", "neutral")).strip_edges().to_lower()
	var shown: bool = false
	if not text.is_empty():
		shown = presenter.show(
			character_id,
			text,
			mood,
			FOCUS_REACTION_BUBBLE_DURATION
		)
	if shown:
		await get_tree().create_timer(FOCUS_REACTION_STEP_SECONDS).timeout
	if str(payload.get("event", "")) == "end":
		interactive_opportunity_requested.emit(
			"timer_end",
			{
				"task_name": str(payload.get("task_name", "")),
				"planned_minutes": int(payload.get("planned_minutes", 0)),
			}
		)
	orchestrator.complete(event_id)

func _clear_active_focus_session() -> void:
	active_focus_session.clear()
	active_focus_reaction_bundle.clear()
