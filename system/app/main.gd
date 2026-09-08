extends Node2D

const DesktopAIReactionsScript = preload(
	"res://system/services/ai/desktop_ai_reactions.gd"
)
const CharacterEventDialogueScript = preload(
	"res://system/services/ai/character_event_dialogue.gd"
)
const AmbientDialogueScript = preload(
	"res://system/services/ai/ambient_dialogue.gd"
)
const AmbientDialoguePlaybackScript = preload(
	"res://system/services/ai/ambient_dialogue_playback.gd"
)
const DesktopDialogueQueueScript = preload(
	"res://system/services/desktop/desktop_dialogue_queue.gd"
)
const DesktopCharacterSettingsScript = preload(
	"res://system/services/desktop/desktop_character_settings.gd"
)
const ScheduleReminderServiceScript = preload(
	"res://system/services/calendar/schedule_reminder_service.gd"
)
const DesktopPackEventsScript = preload(
	"res://system/services/desktop/desktop_pack_events.gd"
)
const RuntimeInstanceCoordinatorScript = preload(
	"res://system/services/runtime/runtime_instance_coordinator.gd"
)
const EasterEggDebugToolsScript = preload(
	"res://system/services/runtime/easter_egg_debug_tools.gd"
)
const StartupProgramSettingsScript = preload(
	"res://system/app/startup_program_settings.gd"
)
const MenuTalkControllerScript = preload(
	"res://system/services/runtime/controllers/menu_talk_controller.gd"
)

const CHAT_BUBBLE_DURATION: float = 8.0
const DIALOGUE_PRIORITY_CHAT: int = 90

@onready var talk_timer: Timer = $TalkTimer
@onready var board_window: CompanionBoardWindow = $BoardWindow
@onready var system_tray: CompanionTray = $SystemTray
@onready var desktop_character_manager: DesktopCharacterManager = (
	$DesktopCharacters/DesktopCharacterManager
)

var desktop_ai_reactions: DesktopAIReactions = null
var character_event_dialogue: CharacterEventDialogue = null
var ambient_dialogue: AmbientDialogue = null
var ambient_dialogue_playback: AmbientDialoguePlayback = null
var dialogue_queue: DesktopDialogueQueue = null
var schedule_reminder_service: ScheduleReminderService = null
var desktop_pack_events: DesktopPackEvents = null
var desktop_settings_panel: DesktopCharacterSettings = null
var play_interaction_resume_timer: Timer = null

var dialogue_presenter: DesktopDialoguePresenter = null
var dialogue_orchestrator: DesktopDialogueOrchestrator = null

var startup_controller: StartupFlowController = null
var cast_controller: CastTransitionController = null
var exit_controller: ExitFlowController = null
var schedule_controller: ScheduleEventController = null
var focus_controller: FocusEventController = null
var play_controller: PlayEventController = null
var hourly_controller: HourlyEventController = null
var interactive_controller: InteractiveQuestionController = null
var ambient_controller: AmbientEventController = null
var overlap_controller: OverlapResolutionController = null
var menu_talk_controller: MenuTalkController = null

var debug_tools: EasterEggDebugTools = null
var open_character_menu_ids: Dictionary = {}
var runtime_instance_coordinator: RuntimeInstanceCoordinator = null

var boot_sequence_busy: bool:
	get:
		return startup_controller != null and startup_controller.boot_sequence_busy
	set(value):
		if startup_controller != null:
			startup_controller.boot_sequence_busy = value

var pending_cast_transition: Dictionary:
	get:
		return cast_controller.pending_cast_transition if cast_controller != null else {}
	set(value):
		if cast_controller != null:
			cast_controller.pending_cast_transition = value

var first_boot_sequence_busy: bool:
	get:
		return startup_controller != null and startup_controller.first_boot_sequence_busy
	set(value):
		if startup_controller != null:
			startup_controller.first_boot_sequence_busy = value

var overlap_cooldown_seconds: float:
	get:
		return overlap_controller.overlap_cooldown_seconds if overlap_controller != null else 0.0
	set(value):
		if overlap_controller != null:
			overlap_controller.overlap_cooldown_seconds = value

func _ready() -> void:
	StartupProgramSettingsScript.sync_if_enabled()
	runtime_instance_coordinator = RuntimeInstanceCoordinatorScript.new()
	add_child(runtime_instance_coordinator)
	var taskbar_action := _get_taskbar_action()
	if not runtime_instance_coordinator.claim("haruhana"):
		if not taskbar_action.is_empty():
			runtime_instance_coordinator.submit_command("haruhana", taskbar_action)
		get_tree().quit()
		return
	runtime_instance_coordinator.command_received.connect(_on_runtime_command_received)
	runtime_instance_coordinator.bind_character_manager(desktop_character_manager)
	add_to_group(&"desktop_dialogue_hosts")

	create_desktop_ai_reactions()
	create_character_event_dialogue()
	create_ambient_dialogue()
	create_ambient_dialogue_playback()
	create_dialogue_queue()
	create_schedule_reminder_service()
	create_desktop_pack_events()
	create_play_interaction_resume_timer()
	create_runtime_dialogue_services()

	debug_tools = EasterEggDebugToolsScript.new()
	add_child(debug_tools)
	debug_tools.bind(self)

	create_runtime_controllers()
	connect_runtime_signals()
	if not taskbar_action.is_empty():
		call_deferred("_on_runtime_command_received", taskbar_action)

	call_deferred("attach_desktop_settings")
	ambient_controller.refresh_cast()

func _process(delta: float) -> void:
	if overlap_controller != null:
		overlap_controller.update(delta)

func set_character_response_loading(
	character_id: String,
	source: String,
	loading: bool
) -> void:
	desktop_character_manager.set_character_response_loading(
		character_id,
		source,
		loading
	)

func request_update_shutdown() -> void:
	if exit_controller != null:
		exit_controller.request_system_close()
		return
	if OS.get_name() == "Windows":
		var result: Error = OS.kill(OS.get_process_id())
		if result == OK:
			return
	get_tree().quit()

func _get_taskbar_action() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--taskbar-action="):
			return argument.trim_prefix("--taskbar-action=").strip_edges().to_lower()
	return ""

func _on_runtime_command_received(action: String) -> void:
	if system_tray != null:
		system_tray.dispatch_action(action)

func create_desktop_ai_reactions() -> void:
	desktop_ai_reactions = DesktopAIReactionsScript.new()
	add_child(desktop_ai_reactions)

func create_character_event_dialogue() -> void:
	character_event_dialogue = CharacterEventDialogueScript.new()
	add_child(character_event_dialogue)

func create_ambient_dialogue() -> void:
	ambient_dialogue = AmbientDialogueScript.new()
	add_child(ambient_dialogue)

func create_ambient_dialogue_playback() -> void:
	ambient_dialogue_playback = AmbientDialoguePlaybackScript.new()
	ambient_dialogue_playback.ambient_dialogue = ambient_dialogue
	add_child(ambient_dialogue_playback)

func create_dialogue_queue() -> void:
	dialogue_queue = DesktopDialogueQueueScript.new()
	dialogue_queue.name = "DesktopDialogueQueue"
	add_child(dialogue_queue)

func create_schedule_reminder_service() -> void:
	schedule_reminder_service = ScheduleReminderServiceScript.new()
	add_child(schedule_reminder_service)

func create_desktop_pack_events() -> void:
	desktop_pack_events = DesktopPackEventsScript.new()
	add_child(desktop_pack_events)

func create_play_interaction_resume_timer() -> void:
	play_interaction_resume_timer = Timer.new()
	play_interaction_resume_timer.name = "PlayInteractionResumeTimer"
	play_interaction_resume_timer.one_shot = true
	play_interaction_resume_timer.ignore_time_scale = true
	add_child(play_interaction_resume_timer)

func create_runtime_dialogue_services() -> void:
	dialogue_presenter = DesktopDialoguePresenter.new()
	dialogue_presenter.configure(desktop_character_manager)

	dialogue_orchestrator = DesktopDialogueOrchestrator.new()
	dialogue_orchestrator.name = "DesktopDialogueOrchestrator"
	add_child(dialogue_orchestrator)
	dialogue_orchestrator.configure(
		dialogue_queue,
		talk_timer,
		ambient_dialogue_playback
	)
	dialogue_orchestrator.resume_requested.connect(_try_resume_deferred_events)

func create_runtime_controllers() -> void:
	exit_controller = ExitFlowController.new()
	add_child(exit_controller)
	exit_controller.configure(
		board_window,
		desktop_character_manager,
		character_event_dialogue,
		debug_tools,
		dialogue_orchestrator,
		dialogue_presenter
	)

	overlap_controller = OverlapResolutionController.new()
	add_child(overlap_controller)
	overlap_controller.configure(
		desktop_character_manager,
		exit_controller,
		dialogue_orchestrator,
		dialogue_presenter,
		Callable(self, "_is_dialogue_queue_blocked")
	)

	cast_controller = CastTransitionController.new()
	add_child(cast_controller)
	cast_controller.configure(
		desktop_character_manager,
		character_event_dialogue,
		dialogue_orchestrator,
		dialogue_presenter,
		exit_controller
	)

	interactive_controller = InteractiveQuestionController.new()
	add_child(interactive_controller)
	interactive_controller.configure(
		board_window,
		desktop_character_manager,
		character_event_dialogue,
		debug_tools,
		dialogue_orchestrator,
		dialogue_presenter
	)

	focus_controller = FocusEventController.new()
	add_child(focus_controller)
	focus_controller.configure(
		desktop_character_manager,
		desktop_ai_reactions,
		debug_tools,
		dialogue_orchestrator,
		dialogue_presenter
	)
	interactive_controller.bind_focus_controller(focus_controller)

	menu_talk_controller = MenuTalkControllerScript.new()
	add_child(menu_talk_controller)
	menu_talk_controller.configure(
		desktop_character_manager,
		character_event_dialogue
	)

	play_controller = PlayEventController.new()
	add_child(play_controller)
	play_controller.configure(
		desktop_character_manager,
		character_event_dialogue,
		debug_tools,
		dialogue_orchestrator,
		dialogue_presenter,
		play_interaction_resume_timer
	)

	hourly_controller = HourlyEventController.new()
	add_child(hourly_controller)
	hourly_controller.configure(
		desktop_character_manager,
		character_event_dialogue,
		desktop_pack_events,
		debug_tools,
		dialogue_orchestrator,
		dialogue_presenter
	)

	schedule_controller = ScheduleEventController.new()
	add_child(schedule_controller)
	schedule_controller.configure(
		desktop_character_manager,
		character_event_dialogue,
		schedule_reminder_service,
		debug_tools,
		dialogue_orchestrator,
		dialogue_presenter
	)

	ambient_controller = AmbientEventController.new()
	add_child(ambient_controller)
	ambient_controller.configure(
		desktop_character_manager,
		ambient_dialogue,
		ambient_dialogue_playback,
		dialogue_orchestrator,
		dialogue_presenter,
		talk_timer,
		Callable(self, "_is_dialogue_queue_blocked")
	)
	ambient_controller.bind_controllers(interactive_controller, cast_controller)

	startup_controller = StartupFlowController.new()
	add_child(startup_controller)
	startup_controller.configure(
		desktop_character_manager,
		character_event_dialogue,
		ambient_dialogue,
		desktop_pack_events,
		dialogue_orchestrator,
		dialogue_presenter
	)
	startup_controller.bind_controllers(
		cast_controller,
		ambient_controller,
		interactive_controller,
		exit_controller,
		menu_talk_controller
	)

	cast_controller.transition_finished.connect(
		startup_controller.request_pending_first_boots
	)
	focus_controller.interactive_opportunity_requested.connect(
		interactive_controller.arm
	)

	dialogue_orchestrator.register_handler(
		"chat", Callable(self, "_execute_queued_chat")
	)
	dialogue_orchestrator.register_handler(
		"cast_transition", Callable(cast_controller, "_execute_queued_cast_transition")
	)
	dialogue_orchestrator.register_handler(
		"schedule", Callable(schedule_controller, "_execute_queued_schedule_reminder")
	)
	dialogue_orchestrator.register_handler(
		"focus", Callable(focus_controller, "_execute_queued_focus_reaction")
	)
	dialogue_orchestrator.register_handler(
		"play_fluster", Callable(play_controller, "_execute_queued_play_fluster")
	)
	dialogue_orchestrator.register_handler(
		"interactive_question",
		Callable(interactive_controller, "_execute_queued_interactive_question")
	)
	dialogue_orchestrator.register_handler(
		"hourly", Callable(hourly_controller, "_execute_queued_hourly_comment")
	)
	dialogue_orchestrator.register_handler(
		"overlap", Callable(overlap_controller, "_execute_queued_overlap")
	)
	dialogue_orchestrator.register_handler(
		"ambient", Callable(ambient_controller, "_execute_queued_ambient")
	)
	dialogue_orchestrator.register_handler(
		"package_install", Callable(self, "_execute_queued_package_install")
	)

func connect_runtime_signals() -> void:
	get_window().close_requested.connect(exit_controller.request_system_close)
	system_tray.open_board_requested.connect(_on_open_board_requested)
	system_tray.open_board_tab_requested.connect(_on_open_board_tab_requested)
	system_tray.quick_timer_requested.connect(_on_quick_timer_requested)
	system_tray.quit_requested.connect(exit_controller._on_quit_requested)

	desktop_character_manager.character_menu_tab_requested.connect(
		_on_character_menu_tab_requested
	)
	desktop_character_manager.application_close_requested.connect(
		exit_controller.request_system_close
	)
	desktop_character_manager.character_menu_talk_action_requested.connect(
		menu_talk_controller.handle_action
	)
	desktop_character_manager.character_interactive_question_answered.connect(
		interactive_controller._on_character_interactive_question_answered
	)
	desktop_character_manager.character_interactive_question_dismissed.connect(
		interactive_controller._on_character_interactive_question_dismissed
	)
	desktop_character_manager.character_menu_visibility_changed.connect(
		_on_character_menu_visibility_changed
	)
	desktop_character_manager.character_play_event.connect(
		play_controller._on_character_play_event
	)
	desktop_character_manager.character_play_changed.connect(
		play_controller._on_character_play_changed
	)
	desktop_character_manager.character_play_interaction.connect(
		play_controller._on_character_play_interaction
	)
	desktop_character_manager.startup_boot_started.connect(
		startup_controller._on_startup_boot_started
	)
	desktop_character_manager.startup_primary_spawned.connect(
		startup_controller._on_startup_primary_spawned
	)
	desktop_character_manager.startup_secondary_spawned.connect(
		startup_controller._on_startup_secondary_spawned
	)
	desktop_character_manager.startup_boot_completed.connect(
		startup_controller._on_startup_boot_completed
	)
	desktop_character_manager.global_settings_changed.connect(
		_on_global_desktop_settings_changed
	)
	desktop_character_manager.package_install_dialogue_requested.connect(
		_on_package_install_dialogue_requested
	)
	desktop_character_manager.cast_changed.connect(_on_desktop_cast_changed)
	desktop_character_manager.slot_change_requested.connect(
		cast_controller._on_slot_change_requested
	)
	desktop_character_manager.character_unavailable_selected.connect(
		cast_controller._on_character_unavailable_selected
	)

	board_window.focus_session_started.connect(focus_controller._on_focus_session_started)
	board_window.focus_session_paused.connect(focus_controller._on_focus_session_paused)
	board_window.focus_session_resumed.connect(focus_controller._on_focus_session_resumed)
	board_window.focus_session_stopped.connect(focus_controller._on_focus_session_stopped)
	board_window.focus_session_completed.connect(focus_controller._on_focus_session_completed)
	board_window.focus_session_milestone.connect(
		focus_controller._on_focus_session_milestone
	)
	board_window.pomodoro_phase_started.connect(
		focus_controller._on_pomodoro_phase_started
	)
	board_window.pomodoro_phase_finished.connect(
		focus_controller._on_pomodoro_phase_finished
	)
	board_window.pomodoro_break_prompted.connect(
		focus_controller._on_pomodoro_break_prompted
	)
	board_window.focus_timer_updated.connect(
		desktop_character_manager.set_focus_timer_state
	)
	board_window.chat_exchange_completed.connect(_on_chat_exchange_completed)
	board_window.schedules_changed.connect(schedule_controller._on_schedules_changed)

	desktop_ai_reactions.focus_session_bundle_ready.connect(
		focus_controller._on_focus_session_bundle_ready
	)
	character_event_dialogue.boot_scene_ready.connect(
		startup_controller._on_boot_scene_ready
	)
	character_event_dialogue.cast_transition_ready.connect(
		cast_controller._on_cast_transition_dialogue_ready
	)
	character_event_dialogue.exit_dialogue_ready.connect(
		exit_controller._on_exit_dialogue_ready
	)
	character_event_dialogue.menu_response_bundle_ready.connect(
		menu_talk_controller._on_menu_response_bundle_ready
	)
	character_event_dialogue.custom_menu_reply_ready.connect(
		menu_talk_controller._on_custom_menu_reply_ready
	)
	character_event_dialogue.schedule_dialogue_ready.connect(
		schedule_controller._on_schedule_event_dialogue_ready
	)
	character_event_dialogue.hourly_dialogue_ready.connect(
		hourly_controller._on_hourly_event_dialogue_ready
	)
	character_event_dialogue.play_fluster_banter_ready.connect(
		play_controller._on_play_fluster_banter_ready
	)
	character_event_dialogue.interactive_question_ready.connect(
		interactive_controller._on_interactive_question_ready
	)

	schedule_reminder_service.reminder_prefetch_due.connect(
		schedule_controller._on_schedule_reminder_prefetch_due
	)
	schedule_reminder_service.reminder_due.connect(
		schedule_controller._on_schedule_reminder_due
	)
	ambient_dialogue_playback.ambient_event_finished.connect(
		ambient_controller._on_ambient_event_finished
	)
	play_interaction_resume_timer.timeout.connect(
		play_controller._on_play_interaction_resume_timeout
	)
	talk_timer.timeout.connect(ambient_controller._on_talk_timer_timeout)

func attach_desktop_settings() -> void:
	if desktop_settings_panel != null:
		return

	var settings_host: CompanionSettingsPanel = find_settings_panel(board_window)
	if settings_host == null:
		push_error("Could not find Settings panel for desktop character controls.")
		return

	if not settings_host.character_pack_changed.is_connected(_on_character_pack_changed):
		settings_host.character_pack_changed.connect(_on_character_pack_changed)
	if not settings_host.interface_language_changed.is_connected(_on_interface_language_changed):
		settings_host.interface_language_changed.connect(_on_interface_language_changed)

	desktop_settings_panel = DesktopCharacterSettingsScript.new()
	settings_host.add_child(desktop_settings_panel)
	desktop_settings_panel.configure(desktop_character_manager)

func find_settings_panel(root: Node) -> CompanionSettingsPanel:
	if root is CompanionSettingsPanel:
		return root as CompanionSettingsPanel
	for child: Node in root.get_children():
		var result: CompanionSettingsPanel = find_settings_panel(child)
		if result != null:
			return result
	return null

func _on_character_pack_changed(
	_pack_id: String
) -> void:
	desktop_character_manager.reload_desktop_characters()

	if desktop_settings_panel != null:
		desktop_settings_panel.refresh()

	exit_controller.invalidate_cache()
	menu_talk_controller.invalidate_cache()
	ambient_controller.refresh_cast()
	call_deferred("_request_exit_dialogue_prefetch")
	call_deferred("_request_menu_talk_prefetch")

func _on_interface_language_changed(
	_language: String
) -> void:
	system_tray.refresh_language()
	if desktop_settings_panel != null:
		desktop_settings_panel.apply_language()

	exit_controller.invalidate_cache()
	menu_talk_controller.invalidate_cache()
	hourly_controller.invalidate_prefetch()
	focus_controller.clear_cached_reactions()

	if ambient_dialogue != null:
		ambient_dialogue.reload_for_language_change()

	call_deferred("_request_exit_dialogue_prefetch")
	call_deferred("_request_menu_talk_prefetch")

func _on_global_desktop_settings_changed(
	_settings: Dictionary
) -> void:
	ambient_controller.refresh_generation_cadence()
	ambient_controller.schedule_next_talk()

func get_desktop_character_ids() -> Array[String]:
	return desktop_character_manager.get_active_character_ids()

func get_desktop_actor(
	character_id: String
) -> DesktopCharacterActor:
	return desktop_character_manager.get_actor(character_id)

func _on_desktop_cast_changed(
	character_ids: Array[String]
) -> void:
	play_controller.clear_prefetch_cache()
	if not startup_controller.boot_sequence_busy:
		menu_talk_controller.refresh_cast()
	startup_controller.set_pending_first_boot_ids(character_ids)

	if not startup_controller.boot_sequence_busy:
		ambient_controller.refresh_cast()
		startup_controller.request_pending_first_boots()

	if desktop_settings_panel != null:
		desktop_settings_panel.refresh()

func _on_open_board_requested() -> void:
	if board_window.visible:
		board_window.grab_focus()

		return

	board_window.toggle_board()

func _on_open_board_tab_requested(
	tab_name: String
) -> void:
	if not board_window.open_tab(tab_name):
		_on_open_board_requested()

func _on_quick_timer_requested(
	minutes: int
) -> void:
	board_window.start_quick_timer(minutes)
	if not board_window.open_tab("Timer"):
		_on_open_board_requested()

func _is_character_menu_open() -> bool:
	return not open_character_menu_ids.is_empty()

func _on_character_menu_visibility_changed(
	character_id: String,
	is_open: bool
) -> void:
	var clean_id: String = character_id.strip_edges().to_lower()
	if clean_id.is_empty():
		return

	if is_open:
		open_character_menu_ids[clean_id] = true
		menu_talk_controller.ensure_prefetch(clean_id)
		return

	open_character_menu_ids.erase(clean_id)

	if _is_character_menu_open():
		return

	_try_resume_deferred_events()

func _on_character_menu_tab_requested(
	_character_id: String,
	tab_name: String
) -> void:
	if board_window.open_tab(tab_name):
		return
	_on_open_board_requested()
	await get_tree().process_frame
	board_window.open_tab(tab_name)

func show_character_chat_bubble(
	character_id: String,
	text: String
) -> void:
	var clean_text: String = text.strip_edges()
	if clean_text.is_empty():
		return
	dialogue_orchestrator.enqueue(
		"chat",
		{
			"character_id": character_id.strip_edges().to_lower(),
			"text": clean_text,
		},
		DIALOGUE_PRIORITY_CHAT
	)

func _execute_queued_chat(event: Dictionary) -> void:
	var event_id: int = int(event.get("id", 0))
	var payload_value: Variant = event.get("payload", {})
	if not (payload_value is Dictionary):
		dialogue_orchestrator.complete(event_id)
		return
	var payload: Dictionary = payload_value as Dictionary
	var shown: bool = _show_character_dialogue(
		str(payload.get("character_id", "")),
		str(payload.get("text", "")),
		"neutral",
		CHAT_BUBBLE_DURATION
	)
	if shown:
		await get_tree().create_timer(CHAT_BUBBLE_DURATION).timeout
	dialogue_orchestrator.complete(event_id)

func _on_chat_exchange_completed(
	character_id: String,
	user_message: String,
	character_response: String
) -> void:
	interactive_controller.record_chat_activity(
		character_id,
		user_message,
		character_response
	)

func _show_character_dialogue(
	character_id: String,
	text: String,
	mood: String = "neutral",
	duration: float = CHAT_BUBBLE_DURATION
) -> bool:
	return dialogue_presenter.show(character_id, text, mood, duration)

func _cancel_ambient_for_priority_event() -> void:
	dialogue_orchestrator.cancel_active_ambient()

func _try_resume_deferred_events() -> void:
	if dialogue_orchestrator == null or dialogue_orchestrator.is_active():
		return
	if _is_dialogue_queue_blocked():
		return
	if cast_controller.resume_pending_if_needed():
		return

	var event: Dictionary = dialogue_orchestrator.take_next()
	if event.is_empty():
		ambient_controller.schedule_next_talk()
		return
	dialogue_orchestrator.dispatch(event)

func _is_dialogue_queue_blocked() -> bool:
	return (
		exit_controller != null
		and exit_controller.is_quitting()
	) or (
		startup_controller != null
		and startup_controller.is_blocking_dialogue()
	) or (
		play_controller != null
		and play_controller.is_play_mode_active()
	) or (
		desktop_character_manager != null
		and desktop_character_manager.is_desktop_minimized()
	) or _is_character_menu_open()

func _on_package_install_dialogue_requested(
	character_id: String,
	text: String,
	mood: String,
	priority: int
) -> void:
	_enqueue_dialogue_event(
		"package_install",
		{"character_id": character_id, "text": text, "mood": mood},
		priority,
		"package_install",
		true
	)

func _execute_queued_package_install(event: Dictionary) -> void:
	var event_id: int = int(event.get("id", 0))
	var payload_value: Variant = event.get("payload", {})
	if not (payload_value is Dictionary):
		dialogue_orchestrator.complete(event_id)
		return
	var payload: Dictionary = payload_value as Dictionary
	var shown: bool = dialogue_presenter.show(
		str(payload.get("character_id", "")),
		str(payload.get("text", "")),
		str(payload.get("mood", "happy")),
		6.0
	)
	if shown:
		await get_tree().create_timer(6.5).timeout
	dialogue_orchestrator.complete(event_id)

func _enqueue_dialogue_event(
	kind: String,
	payload: Dictionary,
	priority: int,
	coalesce_key: String = "",
	replace_existing: bool = true
) -> int:
	if dialogue_orchestrator == null:
		return 0
	return dialogue_orchestrator.enqueue(
		kind,
		payload,
		priority,
		coalesce_key,
		replace_existing
	)

func _active_dialogue_kind() -> String:
	if dialogue_orchestrator == null:
		return ""
	return dialogue_orchestrator.active_kind()

func refresh_ambient_cast() -> void:
	ambient_controller.refresh_cast()

func get_ambient_character_ids() -> Array[String]:
	return ambient_controller.get_ambient_character_ids()

func schedule_next_talk() -> void:
	ambient_controller.schedule_next_talk()

func request_ambient_event() -> void:
	ambient_controller.request_ambient_event()

func get_fallback_idle_line(character_id: String) -> String:
	return ambient_controller.get_fallback_idle_line(character_id)

func _request_exit_dialogue_prefetch() -> void:
	exit_controller.request_prefetch()

func _request_menu_talk_prefetch() -> void:
	menu_talk_controller.refresh_cast()

func _is_exit_dialogue_usable(dialogue: Dictionary) -> bool:
	return exit_controller.is_dialogue_usable(dialogue)

func _show_pack_event_line(
	character_id: String,
	line: Dictionary,
	duration: float
) -> bool:
	return dialogue_presenter.show_pack_line(character_id, line, duration)

func _has_play_peer(character_id: String) -> bool:
	return play_controller._has_play_peer(character_id)

func _clear_interactive_question_opportunity() -> void:
	interactive_controller.clear_opportunity()

func _build_interactive_progress_context(
	character_ids: Array[String]
) -> Dictionary:
	return interactive_controller._build_interactive_progress_context(character_ids)

func _build_interactive_activity_context() -> Dictionary:
	return interactive_controller._build_interactive_activity_context()

func _reset_overlap_candidate() -> void:
	if overlap_controller != null:
		overlap_controller.reset_candidate()

func _get_actor_desktop_pet_rect(
	actor: DesktopCharacterActor
) -> Rect2:
	if overlap_controller == null:
		return Rect2()
	return overlap_controller.get_actor_rect(actor)
