extends Node
class_name ExitFlowController

const EXIT_DIALOGUE_DURATION: float = 4.0
const EXIT_QUIT_DELAY_SECONDS: float = 3.8

var board_window: CompanionBoardWindow = null
var character_manager: DesktopCharacterManager = null
var character_event_dialogue: CharacterEventDialogue = null
var debug_tools: EasterEggDebugTools = null
var orchestrator: DesktopDialogueOrchestrator = null
var presenter: DesktopDialoguePresenter = null

var cached_exit_dialogue: Dictionary = {}
var cached_exit_cast_key: String = ""
var exit_prefetch_requests: Dictionary = {}
var quit_sequence_active: bool = false

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

func invalidate_cache() -> void:
	cached_exit_dialogue.clear()
	cached_exit_cast_key = ""
	exit_prefetch_requests.clear()

func request_prefetch() -> void:
	_request_exit_dialogue_prefetch()

func is_quitting() -> bool:
	return quit_sequence_active

func cache_after_cast(dialogue: Dictionary) -> void:
	if _is_exit_dialogue_usable(dialogue):
		cached_exit_dialogue = dialogue.duplicate(true)
	else:
		cached_exit_dialogue = _build_local_exit_dialogue()
	cached_exit_cast_key = _get_exit_cast_key(character_manager.get_active_character_ids())

func get_cast_key(character_ids: Array[String]) -> String:
	return _get_exit_cast_key(character_ids)

func is_dialogue_usable(dialogue: Dictionary) -> bool:
	return _is_exit_dialogue_usable(dialogue)

func build_local_dialogue() -> Dictionary:
	return _build_local_exit_dialogue()

func _get_exit_cast_key(
	character_ids: Array[String]
) -> String:
	var ids: Array[String] = []

	for value: Variant in character_ids:
		var character_id: String = str(
			value
		).strip_edges().to_lower()

		if character_id.is_empty():
			continue

		if not ids.has(
			character_id
		):
			ids.append(
				character_id
			)

	ids.sort()
	return ",".join(
		ids
	)

func _request_exit_dialogue_prefetch() -> void:
	if character_event_dialogue == null:
		return

	var active_ids: Array[String] = character_manager.get_active_character_ids()

	if active_ids.is_empty():
		return

	var cast_key: String = _get_exit_cast_key(
		active_ids
	)

	if (
		cast_key == cached_exit_cast_key
		and _is_exit_dialogue_usable(
			cached_exit_dialogue
		)
	):
		return

	for pending_key: Variant in exit_prefetch_requests.values():
		if str(
			pending_key
		) == cast_key:
			return

	var request_id: int = int(
		character_event_dialogue.request_exit_dialogue(
			active_ids
		)
	)

	if request_id <= 0:
		return

	exit_prefetch_requests[
		request_id
	] = cast_key

func _on_exit_dialogue_ready(
	request_id: int,
	dialogue: Dictionary
) -> void:
	if (
		debug_tools != null
		and debug_tools.handle_exit_dialogue_ready(
			request_id,
			dialogue
		)
	):
		return

	if not exit_prefetch_requests.has(
		request_id
	):
		return

	var requested_cast_key: String = str(
		exit_prefetch_requests[
			request_id
		]
	)

	exit_prefetch_requests.erase(
		request_id
	)

	var current_cast_key: String = _get_exit_cast_key(
		character_manager.get_active_character_ids()
	)

	if requested_cast_key != current_cast_key:
		return

	if not _is_exit_dialogue_usable(
		dialogue
	):
		return

	cached_exit_dialogue = dialogue.duplicate(
		true
	)
	cached_exit_cast_key = current_cast_key

func save_pending_data() -> void:
	board_window.save_memo_now()

func request_system_close() -> void:
	if quit_sequence_active:
		return

	quit_sequence_active = true
	save_pending_data()
	_terminate_process()

func _terminate_process() -> void:
	if OS.get_name() == "Windows":
		var result: Error = OS.kill(OS.get_process_id())
		if result == OK:
			return

	get_tree().quit()

func _on_quit_requested() -> void:
	if quit_sequence_active:
		return

	quit_sequence_active = true
	save_pending_data()
	orchestrator.cancel_active_ambient()

	var exit_dialogue: Dictionary = {}

	if cached_exit_cast_key == _get_exit_cast_key(
		character_manager.get_active_character_ids()
	):
		exit_dialogue = cached_exit_dialogue.duplicate(
			true
		)

	if not _is_exit_dialogue_usable(
		exit_dialogue
	):
		exit_dialogue = (
			_build_local_exit_dialogue()
		)

	if exit_dialogue.is_empty():
		_terminate_process()
		return

	character_manager.restore_from_desktop_minimize()

	var speaker: String = str(
		exit_dialogue.get(
			"speaker",
			""
		)
	).strip_edges().to_lower()

	var exit_text: String = str(
		exit_dialogue.get(
			"text",
			""
		)
	).strip_edges()

	var mood: String = str(
		exit_dialogue.get(
			"mood",
			"neutral"
		)
	).strip_edges().to_lower()

	var shown: bool = (
		presenter.show(
			speaker,
			exit_text,
			mood,
			EXIT_DIALOGUE_DURATION
		)
	)

	if shown:
		await get_tree().create_timer(
			EXIT_QUIT_DELAY_SECONDS
		).timeout

	_terminate_process()

func _is_exit_dialogue_usable(
	dialogue: Dictionary
) -> bool:

	if dialogue.is_empty():
		return false

	var speaker: String = str(
		dialogue.get(
			"speaker",
			""
		)
	).strip_edges().to_lower()

	var exit_text: String = str(
		dialogue.get(
			"text",
			""
		)
	).strip_edges()

	if (
		speaker.is_empty()
		or exit_text.is_empty()
	):
		return false

	return character_manager.get_active_character_ids().has(
		speaker
	)

func _build_local_exit_dialogue() -> Dictionary:
	var active_ids: Array[String] = (
		character_manager.get_active_character_ids()
	)

	if active_ids.is_empty():
		return {}

	var speaker: String = active_ids[
		randi_range(
			0,
			active_ids.size() - 1
		)
	]

	return {
		"speaker": speaker,
		"text": CharacterProfiles.get_default_ui_line(speaker, "exit"),
		"mood": "neutral"
	}
