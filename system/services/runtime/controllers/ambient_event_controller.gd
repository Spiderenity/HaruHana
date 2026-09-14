extends Node
class_name AmbientEventController

const FREE_AMBIENT_MINUTES: float = 10.0
const PAID_AMBIENT_MINUTES: float = 30.0
const AMBIENT_JITTER_RATIO: float = 0.20
const MIN_TALK_DELAY: float = 30.0
const MAX_TALK_DELAY: float = 120.0
const DIALOGUE_PRIORITY_INTERACTIVE: int = 50
const DIALOGUE_PRIORITY_AMBIENT: int = 10

const IDLE_REMINDER_AFTER_SECONDS := 180.0
const IDLE_REMINDER_INTERVAL_SECONDS := 600.0
var last_mouse_position := Vector2i.ZERO
var mouse_idle_seconds := 0.0
var activity_sample_seconds := 0.0
var last_idle_reminder_msec: int = -600000

func _ready() -> void:
	last_mouse_position = DisplayServer.mouse_get_position()

func _process(delta: float) -> void:
	if is_focusing() and ambient_dialogue_playback != null and ambient_dialogue_playback.is_busy():
		ambient_dialogue_playback.cancel_current_event()
	activity_sample_seconds += delta
	if activity_sample_seconds < 1.0:
		return
	var position := DisplayServer.mouse_get_position()
	if position != last_mouse_position or DisplayServer.mouse_get_button_state() != 0:
		mouse_idle_seconds = 0.0
	else:
		mouse_idle_seconds += activity_sample_seconds
	last_mouse_position = position
	activity_sample_seconds = 0.0

func is_focusing() -> bool:
	return character_manager != null and character_manager.focus_timer_active and not character_manager.focus_timer_paused

func should_offer_idle_reminder() -> bool:
	return not is_focusing() and mouse_idle_seconds >= IDLE_REMINDER_AFTER_SECONDS and Time.get_ticks_msec() - last_idle_reminder_msec >= int(IDLE_REMINDER_INTERVAL_SECONDS * 1000.0)

var character_manager: DesktopCharacterManager = null
var ambient_dialogue: AmbientDialogue = null
var ambient_dialogue_playback: AmbientDialoguePlayback = null
var orchestrator: DesktopDialogueOrchestrator = null
var presenter: DesktopDialoguePresenter = null
var talk_timer: Timer = null
var interactive_controller: InteractiveQuestionController = null
var cast_controller: CastTransitionController = null
var dialogue_blocked_check: Callable = Callable()

func configure(
	manager: DesktopCharacterManager,
	ambient: AmbientDialogue,
	playback: AmbientDialoguePlayback,
	dialogue_orchestrator: DesktopDialogueOrchestrator,
	dialogue_presenter: DesktopDialoguePresenter,
	ambient_timer: Timer,
	blocked_check: Callable
) -> void:
	character_manager = manager
	ambient_dialogue = ambient
	ambient_dialogue_playback = playback
	orchestrator = dialogue_orchestrator
	presenter = dialogue_presenter
	talk_timer = ambient_timer
	dialogue_blocked_check = blocked_check
	_configure_ambient_generation_cadence()

func bind_controllers(
	interactive_flow: InteractiveQuestionController,
	cast_flow: CastTransitionController
) -> void:
	interactive_controller = interactive_flow
	cast_controller = cast_flow

func _is_blocked() -> bool:
	if not dialogue_blocked_check.is_valid():
		return false
	return bool(dialogue_blocked_check.call())

func refresh_generation_cadence() -> void:
	_configure_ambient_generation_cadence()

func refresh_cast() -> void:
	if ambient_dialogue == null:
		return

	var character_ids: Array[String] = (
		get_ambient_character_ids()
	)

	ambient_dialogue.configure_characters(
		character_ids
	)

func get_ambient_character_ids() -> Array[String]:
	var result: Array[String] = []
	for character_id: String in character_manager.get_active_character_ids():
		var actor: DesktopCharacterActor = character_manager.get_actor(character_id)
		if actor != null and actor.get_ambient_dialogue_enabled():
			result.append(character_id)
	return result

func schedule_next_talk() -> void:
	talk_timer.stop()
	if orchestrator.is_active() or orchestrator.has_pending():
		return
	if _is_blocked():
		return
	if cast_controller.has_pending_transition():
		return
	talk_timer.start(randf_range(MIN_TALK_DELAY, MAX_TALK_DELAY))

func _configure_ambient_generation_cadence() -> void:
	if ambient_dialogue == null:
		return

	ambient_dialogue.configure_generation_cadence(
		_get_ambient_generation_interval_minutes(),
		AMBIENT_JITTER_RATIO
	)

func _get_ambient_generation_interval_minutes() -> float:
	var settings: Dictionary = character_manager.get_global_desktop_settings()

	var mode: String = str(
		settings.get(
			"ambient_cadence_mode",
			"free"
		)
	).strip_edges().to_lower()

	match mode:
		"paid":
			return PAID_AMBIENT_MINUTES
		"custom":
			return clampf(
				float(
					settings.get(
						"custom_ambient_minutes",
						30.0
					)
				),
				1.0,
				120.0
			)
		_:
			return FREE_AMBIENT_MINUTES

func _consume_ambient_slot() -> void:
	talk_timer.stop()
	if is_focusing():
		schedule_next_talk()
		return
	if not should_offer_idle_reminder() and interactive_controller.has_armed_opportunity():
		var scene: Dictionary = interactive_controller.consume_ready_scene()
		if not scene.is_empty():
			orchestrator.enqueue(
				"interactive_question",
				{"scene": scene, "debug_mode": false},
				DIALOGUE_PRIORITY_INTERACTIVE,
				"interactive_question",
				true
			)
			return
	orchestrator.enqueue(
		"ambient",
		{},
		DIALOGUE_PRIORITY_AMBIENT,
		"ambient",
		false
	)

func _on_talk_timer_timeout() -> void:
	_consume_ambient_slot()

func request_ambient_event() -> void:
	orchestrator.enqueue(
		"ambient",
		{},
		DIALOGUE_PRIORITY_AMBIENT,
		"ambient",
		false
	)

func _execute_queued_ambient(event: Dictionary) -> void:
	var event_id: int = int(event.get("id", 0))
	if is_focusing():
		orchestrator.complete(event_id)
		return
	if should_offer_idle_reminder():
		var ids := get_ambient_character_ids()
		if not ids.is_empty():
			ids.shuffle()
			var id := ids[0]
			var line := AppLanguage.text("Thinking things through? When you are ready, try one small step.", "생각 정리 중이야? 준비되면 작은 일 하나부터 이어가 보자.")
			if id == "crt":
				line = AppLanguage.text("Thinking takes time too. Finish that one thing when you are ready.", "생각할 시간도 필요하지. 준비됐으면 하던 일 하나 마저 해 봐.")
			elif id == "chip":
				line = AppLanguage.text("Take your time thinking! We can carry on one thing at a time.", "생각 정리 중이면 천천히 해! 준비되면 하나씩 이어가자.")
			presenter.show(id, line, "neutral", 4.5)
			last_idle_reminder_msec = Time.get_ticks_msec()
			await get_tree().create_timer(4.5).timeout
		orchestrator.complete(event_id)
		return
	if ambient_dialogue_playback != null:
		var started_value: Variant = ambient_dialogue_playback.request_ambient_event()
		if bool(started_value):
			return
	var character_ids: Array[String] = get_ambient_character_ids()
	if character_ids.is_empty():
		orchestrator.complete(event_id)
		return
	await _play_local_ambient_fallback(character_ids.duplicate())
	orchestrator.complete(event_id)

func _on_ambient_event_finished() -> void:
	if orchestrator.active_kind() == "ambient":
		orchestrator.complete(orchestrator.active_id())

func _play_local_ambient_fallback(
	character_ids: Array[String]
) -> void:
	if character_ids.is_empty():
		return
	var ordered_ids: Array[String] = character_ids.duplicate()
	ordered_ids.shuffle()
	for character_id: String in ordered_ids:
		if is_focusing():
			return
		var line: String = get_fallback_idle_line(character_id).strip_edges()
		if line.is_empty():
			continue
		presenter.show(character_id, line, "neutral", 4.5)
		await get_tree().create_timer(4.5).timeout

func get_fallback_idle_line(
	character_id: String
) -> String:
	var line: String = CharacterProfiles.get_fallback_line(
		character_id,
		"idle"
	)
	return line if not line.is_empty() else "..."
