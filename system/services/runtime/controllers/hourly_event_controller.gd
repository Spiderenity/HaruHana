extends Node
class_name HourlyEventController

const HOURLY_PREFETCH_START_MINUTE: int = 50
const HOURLY_RETRY_BACKOFF_SECONDS: int = 120
const DIALOGUE_PRIORITY_HOURLY: int = 40

var character_manager: DesktopCharacterManager = null
var character_event_dialogue: CharacterEventDialogue = null
var desktop_pack_events: DesktopPackEvents = null
var debug_tools: EasterEggDebugTools = null
var orchestrator: DesktopDialogueOrchestrator = null
var presenter: DesktopDialoguePresenter = null

var hourly_timer: Timer = null
var hourly_prefetch_request_id: int = 0
var hourly_prefetch_key: String = ""
var hourly_prefetched_dialogue: Dictionary = {}
var last_hourly_key: String = ""
var hourly_retry_key: String = ""
var hourly_retry_not_before_unix: int = 0

func configure(
	manager: DesktopCharacterManager,
	event_dialogue: CharacterEventDialogue,
	pack_events: DesktopPackEvents,
	debug: EasterEggDebugTools,
	dialogue_orchestrator: DesktopDialogueOrchestrator,
	dialogue_presenter: DesktopDialoguePresenter
) -> void:
	character_manager = manager
	character_event_dialogue = event_dialogue
	desktop_pack_events = pack_events
	debug_tools = debug
	orchestrator = dialogue_orchestrator
	presenter = dialogue_presenter
	_create_timer()

func invalidate_prefetch() -> void:
	hourly_prefetched_dialogue.clear()
	hourly_prefetch_key = ""
	hourly_prefetch_request_id = 0
	hourly_retry_key = ""
	hourly_retry_not_before_unix = 0

func _create_timer() -> void:
	if hourly_timer != null:
		return
	hourly_timer = Timer.new()
	hourly_timer.name = "HourlyCommentTimer"
	hourly_timer.wait_time = 15.0
	hourly_timer.one_shot = false
	hourly_timer.ignore_time_scale = true
	hourly_timer.timeout.connect(_check_hourly_comment)
	add_child(hourly_timer)
	hourly_timer.start()

func _hourly_key_from_datetime(
	datetime: Dictionary
) -> String:

	return (
		str(
			datetime.get(
				"year",
				0
			)
		)
		+ "-"
		+ str(
			datetime.get(
				"month",
				0
			)
		)
		+ "-"
		+ str(
			datetime.get(
				"day",
				0
			)
		)
		+ "-"
		+ str(
			datetime.get(
				"hour",
				0
			)
		)
	)

func _maybe_prefetch_hourly_comment(
	now: Dictionary
) -> void:
	var minute: int = int(
		now.get(
			"minute",
			0
		)
	)

	if minute < HOURLY_PREFETCH_START_MINUTE:
		return

	var now_stamp: int = (
		Time.get_unix_time_from_datetime_dict(
			{
				"year": int(
					now.get(
						"year",
						1970
					)
				),
				"month": int(
					now.get(
						"month",
						1
					)
				),
				"day": int(
					now.get(
						"day",
						1
					)
				),
				"hour": int(
					now.get(
						"hour",
						0
					)
				),
				"minute": minute,
				"second": int(
					now.get(
						"second",
						0
					)
				)
			}
		)
	)

	var next_hour_stamp: int = (
		now_stamp
		- minute * 60
		- int(
			now.get(
				"second",
				0
			)
		)
		+ 3600
	)

	var next_hour_datetime: Dictionary = (
		Time.get_datetime_dict_from_unix_time(
			next_hour_stamp
		)
	)

	var next_key: String = (
		_hourly_key_from_datetime(
			next_hour_datetime
		)
	)

	if hourly_retry_key != next_key:
		hourly_retry_key = next_key
		hourly_retry_not_before_unix = 0
	if int(Time.get_unix_time_from_system()) < hourly_retry_not_before_unix:
		return

	if (
		not hourly_prefetched_dialogue.is_empty()
		and str(
			hourly_prefetched_dialogue.get(
				"key",
				""
			)
		) == next_key
	):
		return

	if (
		hourly_prefetch_request_id > 0
		and hourly_prefetch_key == next_key
	):
		return

	var candidates: Array[String] = (
		character_manager.get_active_character_ids()
	)

	if candidates.is_empty():
		return

	var character_id: String = candidates[
		randi_range(
			0,
			candidates.size() - 1
		)
	]

	var request_id: int = int(
		character_event_dialogue.request_hourly_comment(
			character_id,
			int(
				next_hour_datetime.get(
					"hour",
					0
				)
			),
			candidates
		)
	)

	if request_id <= 0:
		hourly_retry_key = next_key
		hourly_retry_not_before_unix = int(Time.get_unix_time_from_system()) + HOURLY_RETRY_BACKOFF_SECONDS
		return

	hourly_prefetch_request_id = request_id
	hourly_prefetch_key = next_key

func _on_hourly_event_dialogue_ready(
	request_id: int,
	character_id: String,
	dialogue: Dictionary
) -> void:
	if (
		debug_tools != null
		and debug_tools.handle_hourly_event_dialogue_ready(
			request_id,
			character_id,
			dialogue
		)
	):
		return

	if request_id != hourly_prefetch_request_id:
		return

	var cache_key: String = hourly_prefetch_key

	hourly_prefetch_request_id = 0

	if dialogue.is_empty():
		hourly_prefetch_key = ""
		hourly_retry_key = cache_key
		hourly_retry_not_before_unix = int(Time.get_unix_time_from_system()) + HOURLY_RETRY_BACKOFF_SECONDS
		return

	hourly_retry_key = ""
	hourly_retry_not_before_unix = 0
	hourly_prefetched_dialogue = {
		"key": cache_key,
		"character_id": character_id,
		"dialogue": dialogue.duplicate(
			true
		)
	}

func _check_hourly_comment() -> void:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	_maybe_prefetch_hourly_comment(now)
	var minute: int = int(now.get("minute", 0))
	if minute > 3:
		return
	var hour: int = int(now.get("hour", 0))
	var key: String = _hourly_key_from_datetime(now)
	if key == last_hourly_key:
		return
	last_hourly_key = key
	orchestrator.enqueue(
		"hourly",
		{"hour": hour, "key": key},
		DIALOGUE_PRIORITY_HOURLY,
		"hourly",
		true
	)

func _execute_queued_hourly_comment(event: Dictionary) -> void:
	var event_id: int = int(event.get("id", 0))
	var payload_value: Variant = event.get("payload", {})
	if not (payload_value is Dictionary):
		orchestrator.complete(event_id)
		return
	var payload: Dictionary = payload_value as Dictionary
	var hour: int = int(payload.get("hour", 0))
	var key: String = str(payload.get("key", ""))
	var candidates: Array[String] = character_manager.get_active_character_ids()
	if candidates.is_empty():
		orchestrator.complete(event_id)
		return

	var character_id: String = ""
	var line: Dictionary = {}
	if (
		not hourly_prefetched_dialogue.is_empty()
		and str(hourly_prefetched_dialogue.get("key", "")) == key
	):
		var cached_character_id: String = str(
			hourly_prefetched_dialogue.get("character_id", "")
		).strip_edges().to_lower()
		var cached_dialogue_value: Variant = hourly_prefetched_dialogue.get("dialogue", {})
		if candidates.has(cached_character_id) and cached_dialogue_value is Dictionary:
			character_id = cached_character_id
			line = (cached_dialogue_value as Dictionary).duplicate(true)
	hourly_prefetched_dialogue.clear()
	hourly_prefetch_key = ""

	if character_id.is_empty():
		character_id = candidates[randi_range(0, candidates.size() - 1)]
	if line.is_empty():
		line = desktop_pack_events.pick_hourly_line( character_id, hour)
	if line.is_empty():
		push_error(
			"Character pack "
			+ CharacterProfiles.get_current_pack()
			+ " is missing an hourly fallback line for "
			+ character_id
			+ " at hour "
			+ str(hour)
			+ "."
		)
		orchestrator.complete(event_id)
		return

	presenter.show_pack_line(character_id, line, 6.0)
	await get_tree().create_timer(6.5).timeout
	orchestrator.complete(event_id)
