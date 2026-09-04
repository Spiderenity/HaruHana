extends Node
class_name PlayEventController

const PLAY_INTERACTION_GRACE_SECONDS: float = 2.5
const PLAY_FLUSTER_PEER_DELAY_SECONDS: float = 1.0
const PLAY_FLUSTER_PREFETCH_WAIT_SECONDS: float = 2.0
const PLAY_FLUSTER_BANTER_BUBBLE_SECONDS: float = 4.5
const DIALOGUE_PRIORITY_PLAY: int = 60

var character_manager: DesktopCharacterManager = null
var character_event_dialogue: CharacterEventDialogue = null
var debug_tools: EasterEggDebugTools = null
var orchestrator: DesktopDialogueOrchestrator = null
var presenter: DesktopDialoguePresenter = null
var play_interaction_resume_timer: Timer = null

var play_fluster_prefetch_requests: Dictionary = {}
var play_fluster_prefetched: Dictionary = {}

func configure(
	manager: DesktopCharacterManager,
	event_dialogue: CharacterEventDialogue,
	debug: EasterEggDebugTools,
	dialogue_orchestrator: DesktopDialogueOrchestrator,
	dialogue_presenter: DesktopDialoguePresenter,
	resume_timer: Timer
) -> void:
	character_manager = manager
	character_event_dialogue = event_dialogue
	debug_tools = debug
	orchestrator = dialogue_orchestrator
	presenter = dialogue_presenter
	play_interaction_resume_timer = resume_timer

func clear_prefetch_cache() -> void:
	play_fluster_prefetch_requests.clear()
	play_fluster_prefetched.clear()

func is_play_mode_active() -> bool:
	for character_id: String in character_manager.get_active_character_ids():
		var actor: DesktopCharacterActor = character_manager.get_actor(character_id)
		if actor == null:
			continue
		if actor.is_play_flustered() or actor.is_play_interaction_active():
			return true
	return false

func _on_character_play_changed(
	_character_id: String,
	_play_value: float,
	_play_max: float
) -> void:

	if (
		not is_play_mode_active()
		and orchestrator.is_talk_timer_stopped()
	):
		orchestrator.request_resume()

func _on_character_play_interaction(
	character_id: String
) -> void:

	orchestrator.cancel_active_ambient()

	_ensure_play_fluster_banter_prefetched(
		character_id
	)

	if play_interaction_resume_timer != null:
		play_interaction_resume_timer.start(
			PLAY_INTERACTION_GRACE_SECONDS
		)

func _on_play_interaction_resume_timeout() -> void:
	if is_play_mode_active():
		if play_interaction_resume_timer != null:
			play_interaction_resume_timer.start(
				PLAY_INTERACTION_GRACE_SECONDS
			)

		return

	orchestrator.request_resume()

func _get_play_fluster_cache_key(
	target_character_id: String
) -> String:

	var active_ids: Array[String] = (
		character_manager.get_active_character_ids()
	)

	active_ids.sort()

	return (
		target_character_id.strip_edges().to_lower()
		+ "|"
		+ ",".join(
			active_ids
		)
	)

func _has_play_peer(
	target_character_id: String
) -> bool:

	var target_id: String = (
		target_character_id
			.strip_edges()
			.to_lower()
	)

	for active_id: String in character_manager.get_active_character_ids():
		if active_id != target_id:
			return true

	return false

func _ensure_play_fluster_banter_prefetched(
	character_id: String
) -> void:

	if character_event_dialogue == null:
		return

	if not _has_play_peer(
		character_id
	):
		return

	var cache_key: String = (
		_get_play_fluster_cache_key(
			character_id
		)
	)

	if play_fluster_prefetched.has(
		cache_key
	):
		return

	for pending_value: Variant in play_fluster_prefetch_requests.values():
		if str(
			pending_value
		) == cache_key:
			return

	var request_id: int = int(
		character_event_dialogue.request_play_fluster_banter(
			character_id,
			character_manager.get_active_character_ids()
		)
	)

	if request_id <= 0:
		return

	play_fluster_prefetch_requests[
		request_id
	] = cache_key

func _on_play_fluster_banter_ready(
	request_id: int,
	_target_character_id: String,
	lines: Array
) -> void:

	if (
		debug_tools != null
		and debug_tools.handle_fluster_banter_ready(
			request_id,
			lines
		)
	):
		return

	if not play_fluster_prefetch_requests.has(
		request_id
	):
		return

	var cache_key: String = str(
		play_fluster_prefetch_requests[
			request_id
		]
	)

	play_fluster_prefetch_requests.erase(
		request_id
	)

	if lines.is_empty():
		return

	play_fluster_prefetched[
		cache_key
	] = lines.duplicate(
		true
	)

func _is_play_fluster_prefetch_pending(
	cache_key: String
) -> bool:
	for pending_value: Variant in play_fluster_prefetch_requests.values():
		if str(
			pending_value
		) == cache_key:
			return true

	return false

func _on_character_play_event(
	character_id: String,
	event_kind: String,
	_zone: String,
	_play_value: float
) -> void:
	if event_kind != "flustered":
		return
	var cache_key: String = _get_play_fluster_cache_key(character_id)
	call_deferred(
		"_resolve_play_fluster_banter",
		character_id,
		cache_key
	)

func _resolve_play_fluster_banter(
	character_id: String,
	cache_key: String
) -> void:
	var waited_seconds: float = 0.0
	while (
		not play_fluster_prefetched.has(cache_key)
		and _is_play_fluster_prefetch_pending(cache_key)
		and waited_seconds < PLAY_FLUSTER_PREFETCH_WAIT_SECONDS
	):
		await get_tree().create_timer(0.1).timeout
		waited_seconds += 0.1

	var lines: Array = []
	if play_fluster_prefetched.has(cache_key):
		var cached_value: Variant = play_fluster_prefetched[cache_key]
		play_fluster_prefetched.erase(cache_key)
		if cached_value is Array:
			lines = (cached_value as Array).duplicate(true)
	if lines.is_empty() and character_event_dialogue != null:
		var fallback_value: Variant = character_event_dialogue.get_play_fluster_banter_fallback(
			character_id,
			character_manager.get_active_character_ids()
		)
		if fallback_value is Array:
			lines = (fallback_value as Array).duplicate(true)
	if lines.is_empty():
		return
	orchestrator.enqueue(
		"play_fluster",
		{"character_id": character_id, "lines": lines},
		DIALOGUE_PRIORITY_PLAY,
		"play_fluster:" + character_id,
		true
	)

func _execute_queued_play_fluster(event: Dictionary) -> void:
	var event_id: int = int(event.get("id", 0))
	var payload_value: Variant = event.get("payload", {})
	if not (payload_value is Dictionary):
		orchestrator.complete(event_id)
		return
	var lines_value: Variant = (payload_value as Dictionary).get("lines", [])
	if not (lines_value is Array):
		orchestrator.complete(event_id)
		return
	await get_tree().create_timer(PLAY_FLUSTER_PEER_DELAY_SECONDS).timeout
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
			PLAY_FLUSTER_BANTER_BUBBLE_SECONDS
		):
			await get_tree().create_timer(PLAY_FLUSTER_BANTER_BUBBLE_SECONDS).timeout
			break
	orchestrator.complete(event_id)
