extends Node
class_name ScheduleEventController

const DIALOGUE_PRIORITY_SCHEDULE: int = 80

var character_manager: DesktopCharacterManager = null
var character_event_dialogue: CharacterEventDialogue = null
var schedule_reminder_service: ScheduleReminderService = null
var debug_tools: EasterEggDebugTools = null
var orchestrator: DesktopDialogueOrchestrator = null
var presenter: DesktopDialoguePresenter = null

var last_schedule_character_id: String = ""
var schedule_prefetch_requests: Dictionary = {}
var schedule_prefetched_dialogue: Dictionary = {}

func configure(
	manager: DesktopCharacterManager,
	event_dialogue: CharacterEventDialogue,
	reminder_service: ScheduleReminderService,
	debug: EasterEggDebugTools,
	dialogue_orchestrator: DesktopDialogueOrchestrator,
	dialogue_presenter: DesktopDialoguePresenter
) -> void:
	character_manager = manager
	character_event_dialogue = event_dialogue
	schedule_reminder_service = reminder_service
	debug_tools = debug
	orchestrator = dialogue_orchestrator
	presenter = dialogue_presenter

func _on_schedules_changed() -> void:
	schedule_prefetch_requests.clear()
	schedule_prefetched_dialogue.clear()

	if schedule_reminder_service == null:
		return

	schedule_reminder_service.reload_schedules()

func _get_schedule_occurrence_key(
	schedule: Dictionary
) -> String:

	var schedule_id: String = str(
		schedule.get(
			"id",
			""
		)
	).strip_edges()

	var trigger_stamp: int = int(
		schedule.get(
			"_trigger_stamp",
			0
		)
	)

	if schedule_id.is_empty():
		schedule_id = str(
			schedule.get(
				"title",
				"schedule"
			)
		).strip_edges()

	return (
		schedule_id
		+ ":"
		+ str(trigger_stamp)
	)

func _on_schedule_reminder_prefetch_due(
	schedule: Dictionary
) -> void:

	if character_event_dialogue == null:
		return

	var cache_key: String = (
		_get_schedule_occurrence_key(
			schedule
		)
	)

	if cache_key.is_empty():
		return

	if schedule_prefetched_dialogue.has(
		cache_key
	):
		return

	for pending_value: Variant in schedule_prefetch_requests.values():
		if not (
			pending_value is Dictionary
		):
			continue

		if str(
			(pending_value as Dictionary).get(
				"cache_key",
				""
			)
		) == cache_key:
			return

	var character_id: String = (
		_choose_schedule_reminder_character()
	)

	if character_id.is_empty():
		return

	var title: String = str(
		schedule.get(
			"title",
			"your schedule"
		)
	).strip_edges()

	var minutes_until: int = int(
		schedule.get(
			"_minutes_until_start",
			schedule.get(
				"reminder_minutes",
				0
			)
		)
	)

	var request_id: int = int(
		character_event_dialogue.request_schedule_reminder(
			character_id,
			title,
			minutes_until
		)
	)

	if request_id <= 0:
		return

	schedule_prefetch_requests[
		request_id
	] = {
		"cache_key": cache_key,
		"character_id": character_id,
		"schedule": schedule.duplicate(
			true
		)
	}

func _on_schedule_reminder_due(
	schedule: Dictionary
) -> void:
	character_manager.restore_from_desktop_minimize()
	orchestrator.enqueue(
		"schedule",
		{"schedule": schedule.duplicate(true)},
		DIALOGUE_PRIORITY_SCHEDULE
	)

func _on_schedule_event_dialogue_ready(
	request_id: int,
	character_id: String,
	dialogue: Dictionary
) -> void:
	if (
		debug_tools != null
		and debug_tools.handle_schedule_event_dialogue_ready(
			request_id,
			character_id,
			dialogue
		)
	):
		return

	if not schedule_prefetch_requests.has(request_id):
		return
	var prefetch_value: Variant = schedule_prefetch_requests[request_id]
	schedule_prefetch_requests.erase(request_id)
	if not (prefetch_value is Dictionary):
		return
	var prefetch: Dictionary = prefetch_value as Dictionary
	var cache_key: String = str(prefetch.get("cache_key", ""))
	if cache_key.is_empty() or dialogue.is_empty():
		return
	schedule_prefetched_dialogue[cache_key] = {
		"character_id": character_id,
		"dialogue": dialogue.duplicate(true),
	}

func _deliver_schedule_reminder_fallback(
	character_id: String,
	schedule: Dictionary
) -> bool:
	var text: String = _build_schedule_reminder_text(schedule)
	var shown: bool = presenter.show(
		character_id,
		text,
		"neutral",
		7.5
	)
	if shown:
		last_schedule_character_id = character_id
	return shown

func _execute_queued_schedule_reminder(event: Dictionary) -> void:
	var event_id: int = int(event.get("id", 0))
	var payload_value: Variant = event.get("payload", {})
	if not (payload_value is Dictionary):
		orchestrator.complete(event_id)
		return
	var schedule_value: Variant = (payload_value as Dictionary).get("schedule", {})
	if not (schedule_value is Dictionary):
		orchestrator.complete(event_id)
		return
	var schedule: Dictionary = (schedule_value as Dictionary).duplicate(true)
	var cache_key: String = _get_schedule_occurrence_key(schedule)
	var cached_value: Variant = schedule_prefetched_dialogue.get(cache_key, {})
	if schedule_prefetched_dialogue.has(cache_key):
		schedule_prefetched_dialogue.erase(cache_key)
	var cached: Dictionary = {}
	if cached_value is Dictionary:
		cached = (cached_value as Dictionary).duplicate(true)

	var character_id: String = str(cached.get("character_id", "")).strip_edges().to_lower()
	if character_id.is_empty() or character_manager.get_actor(character_id) == null:
		character_id = _choose_schedule_reminder_character()
	if character_id.is_empty():
		orchestrator.complete(event_id)
		return

	var dialogue_value: Variant = cached.get("dialogue", {})
	var dialogue: Dictionary = {}
	if dialogue_value is Dictionary:
		dialogue = (dialogue_value as Dictionary).duplicate(true)
	var text: String = str(dialogue.get("text", "")).strip_edges()
	var mood: String = str(dialogue.get("mood", "neutral")).strip_edges().to_lower()
	var shown: bool = false
	if text.is_empty():
		shown = _deliver_schedule_reminder_fallback(character_id, schedule)
	else:
		shown = presenter.show(character_id, text, mood, 7.5)
		if shown:
			last_schedule_character_id = character_id

	if shown:
		await get_tree().create_timer(8.0).timeout
	orchestrator.complete(event_id)

func _choose_schedule_reminder_character() -> String:
	var candidates: Array[String] = (
		character_manager.get_active_character_ids()
	)

	if candidates.is_empty():
		return ""

	if candidates.size() == 1:
		return candidates[0]

	var alternatives: Array[String] = []

	for character_id: String in candidates:
		if character_id == last_schedule_character_id:
			continue

		alternatives.append(
			character_id
		)

	if alternatives.is_empty():
		alternatives = candidates

	return alternatives[
		randi_range(
			0,
			alternatives.size() - 1
		)
	]

func _build_schedule_reminder_text(
	schedule: Dictionary
) -> String:

	var title: String = str(
		schedule.get(
			"title",
			"your schedule"
		)
	).strip_edges()

	if title.is_empty():
		title = "your schedule"

	var minutes_until: int = int(
		schedule.get(
			"_minutes_until_start",
			schedule.get(
				"reminder_minutes",
				0
			)
		)
	)

	if minutes_until > 1:
		var options: Array[String] = [
			"%s starts in %d minutes." % [
				title,
				minutes_until
			],
			"Just a reminder: %s starts in %d minutes." % [
				title,
				minutes_until
			],
			"You have %s in %d minutes." % [
				title,
				minutes_until
			]
		]

		return options[
			randi_range(
				0,
				options.size() - 1
			)
		]

	if minutes_until == 1:
		return (
			title
			+ " starts in 1 minute."
		)

	if minutes_until == 0:
		var now_options: Array[String] = [
			"It's time for %s." % title,
			"%s is starting now." % title
		]

		return now_options[
			randi_range(
				0,
				now_options.size() - 1
			)
		]

	return (
		"%s started %d minutes ago."
		% [
			title,
			absi(
				minutes_until
			)
		]
	)
