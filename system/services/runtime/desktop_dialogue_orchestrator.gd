extends Node
class_name DesktopDialogueOrchestrator

signal resume_requested

var dialogue_queue: DesktopDialogueQueue = null
var talk_timer: Timer = null
var ambient_playback: AmbientDialoguePlayback = null
var handlers: Dictionary = {}

func configure(
	queue: DesktopDialogueQueue,
	ambient_timer: Timer,
	playback: AmbientDialoguePlayback
) -> void:
	dialogue_queue = queue
	talk_timer = ambient_timer
	ambient_playback = playback

func register_handler(kind: String, handler: Callable) -> void:
	var clean_kind: String = kind.strip_edges().to_lower()
	if clean_kind.is_empty() or not handler.is_valid():
		return
	handlers[clean_kind] = handler

func enqueue(
	kind: String,
	payload: Dictionary,
	priority: int,
	coalesce_key: String = "",
	replace_existing: bool = true
) -> int:
	if dialogue_queue == null:
		return 0
	stop_talk_timer()
	var event_id: int = dialogue_queue.enqueue(
		kind,
		payload,
		priority,
		coalesce_key,
		replace_existing
	)
	request_resume()
	return event_id

func complete(event_id: int) -> void:
	if dialogue_queue == null:
		return
	dialogue_queue.complete(event_id)
	request_resume()

func request_resume() -> void:
	call_deferred("_emit_resume_requested")

func _emit_resume_requested() -> void:
	resume_requested.emit()

func take_next() -> Dictionary:
	if dialogue_queue == null:
		return {}
	return dialogue_queue.take_next()

func dispatch(event: Dictionary) -> void:
	var kind: String = str(event.get("kind", "")).strip_edges().to_lower()
	var handler_value: Variant = handlers.get(kind, Callable())
	if handler_value is Callable:
		var handler: Callable = handler_value
		if handler.is_valid():
			handler.call(event)
			return
	complete(int(event.get("id", 0)))

func is_active() -> bool:
	return dialogue_queue != null and dialogue_queue.is_active()

func has_pending() -> bool:
	return dialogue_queue != null and dialogue_queue.has_pending()

func has_coalesce_key(key: String) -> bool:
	return dialogue_queue != null and dialogue_queue.has_coalesce_key(key)

func active_id() -> int:
	if dialogue_queue == null:
		return 0
	return dialogue_queue.get_active_id()

func active_kind() -> String:
	if dialogue_queue == null:
		return ""
	return dialogue_queue.get_active_kind()

func is_talk_timer_stopped() -> bool:
	return talk_timer == null or talk_timer.is_stopped()

func stop_talk_timer() -> void:
	if talk_timer != null:
		talk_timer.stop()

func cancel_active_ambient() -> void:
	if active_kind() != "ambient":
		return
	if ambient_playback != null:
		ambient_playback.cancel_current_event()
