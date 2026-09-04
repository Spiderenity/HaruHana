extends Node
class_name OverlapResolutionController

const CHARACTER_OVERLAP_GRACE_SECONDS: float = 0.55
const CHARACTER_OVERLAP_COOLDOWN_SECONDS: float = 5.0
const CHARACTER_OVERLAP_MOVE_DELAY_SECONDS: float = 0.35
const CHARACTER_OVERLAP_SLIDE_SECONDS: float = 0.4
const CHARACTER_OVERLAP_BUBBLE_SECONDS: float = 3.5
const DIALOGUE_PRIORITY_OVERLAP: int = 95

var character_manager: DesktopCharacterManager = null
var exit_controller: ExitFlowController = null
var orchestrator: DesktopDialogueOrchestrator = null
var presenter: DesktopDialoguePresenter = null
var dialogue_blocked_check: Callable = Callable()

var overlap_candidate_key: String = ""
var overlap_candidate_seconds: float = 0.0
var overlap_cooldown_seconds: float = 0.0

func configure(
	manager: DesktopCharacterManager,
	exit_flow: ExitFlowController,
	dialogue_orchestrator: DesktopDialogueOrchestrator,
	dialogue_presenter: DesktopDialoguePresenter,
	blocked_check: Callable
) -> void:
	character_manager = manager
	exit_controller = exit_flow
	orchestrator = dialogue_orchestrator
	presenter = dialogue_presenter
	dialogue_blocked_check = blocked_check

func _is_blocked() -> bool:
	if not dialogue_blocked_check.is_valid():
		return false
	return bool(dialogue_blocked_check.call())

func reset_candidate() -> void:
	_reset_overlap_candidate()

func get_actor_rect(actor: DesktopCharacterActor) -> Rect2:
	return _get_actor_desktop_pet_rect(actor)

func update(
	delta: float
) -> void:
	overlap_cooldown_seconds = maxf(0.0, overlap_cooldown_seconds - delta)
	if exit_controller.is_quitting() or overlap_cooldown_seconds > 0.0:
		_reset_overlap_candidate()
		return
	if not _can_start_overlap_resolution():
		_reset_overlap_candidate()
		return
	var pair: Dictionary = _find_overlapping_character_pair()
	if pair.is_empty():
		_reset_overlap_candidate()
		return
	var pair_key: String = str(pair.get("key", ""))
	if pair_key != overlap_candidate_key:
		overlap_candidate_key = pair_key
		overlap_candidate_seconds = 0.0
	overlap_candidate_seconds += delta
	if overlap_candidate_seconds < CHARACTER_OVERLAP_GRACE_SECONDS:
		return
	_reset_overlap_candidate()
	var coalesce_key: String = "overlap:" + pair_key
	if orchestrator.has_coalesce_key(coalesce_key):
		return
	orchestrator.enqueue(
		"overlap",
		{"pair": pair.duplicate(true)},
		DIALOGUE_PRIORITY_OVERLAP,
		coalesce_key,
		false
	)

func _reset_overlap_candidate() -> void:
	overlap_candidate_key = ""
	overlap_candidate_seconds = 0.0

func _can_start_overlap_resolution() -> bool:
	return not _is_blocked()

func _find_overlapping_character_pair() -> Dictionary:
	var active_ids: Array[String] = character_manager.get_active_character_ids()

	for first_index: int in range(active_ids.size()):
		var first_id: String = active_ids[first_index]
		var first_actor: DesktopCharacterActor = character_manager.get_actor(first_id)
		if first_actor == null or first_actor.is_desktop_position_busy():
			continue
		var first_rect: Rect2 = first_actor.get_desktop_pet_rect()
		if first_rect.size == Vector2.ZERO:
			continue

		for second_index: int in range(first_index + 1, active_ids.size()):
			var second_id: String = active_ids[second_index]
			var second_actor: DesktopCharacterActor = character_manager.get_actor(second_id)
			if second_actor == null or second_actor.is_desktop_position_busy():
				continue
			var second_rect: Rect2 = second_actor.get_desktop_pet_rect()
			if second_rect.size == Vector2.ZERO:
				continue
			if not first_rect.intersects(second_rect):
				continue

			return {
				"key": first_id + ":" + second_id,
				"first_id": first_id,
				"second_id": second_id,
			}

	return {}

func _resolve_character_overlap(
	pair: Dictionary,
	event_id: int
) -> void:
	var first_id: String = str(pair.get("first_id", "")).strip_edges().to_lower()
	var second_id: String = str(pair.get("second_id", "")).strip_edges().to_lower()
	var first_actor: DesktopCharacterActor = character_manager.get_actor(first_id)
	var second_actor: DesktopCharacterActor = character_manager.get_actor(second_id)
	if first_actor == null or second_actor == null:
		_finish_overlap_resolution(event_id)
		return

	var first_rect: Rect2 = _get_actor_desktop_pet_rect(first_actor)
	var second_rect: Rect2 = _get_actor_desktop_pet_rect(second_actor)
	var gap: float = maxf(
		_get_actor_default_gap(first_actor),
		_get_actor_default_gap(second_actor)
	)
	if (
		first_rect.size == Vector2.ZERO
		or second_rect.size == Vector2.ZERO
		or not first_rect.intersects(second_rect)
	):
		_finish_overlap_resolution(event_id)
		return
	var first_slot: int = _get_desktop_character_slot_index(first_id)
	var second_slot: int = _get_desktop_character_slot_index(second_id)
	var first_is_anchor: bool = false
	if first_slot >= 0 and second_slot >= 0 and first_slot != second_slot:
		first_is_anchor = first_slot > second_slot
	else:
		first_is_anchor = (
			first_rect.position.x + first_rect.size.x / 2.0
			<= second_rect.position.x + second_rect.size.x / 2.0
		)

	var anchor_id: String = first_id if first_is_anchor else second_id
	var moving_id: String = second_id if first_is_anchor else first_id
	var anchor_actor: DesktopCharacterActor = first_actor if first_is_anchor else second_actor
	var moving_actor: DesktopCharacterActor = second_actor if first_is_anchor else first_actor
	var anchor_rect: Rect2 = first_rect if first_is_anchor else second_rect
	var moving_rect: Rect2 = second_rect if first_is_anchor else first_rect
	var moving_target_left: float = anchor_rect.end.x + gap
	var speaker_id: String = ""
	var mover_id: String = ""
	var mover_actor: DesktopCharacterActor = null
	var desired_left: float = 0.0

	if _desktop_pet_left_fits_screen(moving_rect.size.x, moving_target_left):
		speaker_id = anchor_id
		mover_id = moving_id
		mover_actor = moving_actor
		desired_left = moving_target_left
	else:
		speaker_id = moving_id
		mover_id = anchor_id
		mover_actor = anchor_actor
		desired_left = moving_rect.position.x - gap - anchor_rect.size.x

	if mover_actor == null:
		_finish_overlap_resolution(event_id)
		return

	presenter.show(
		speaker_id,
		_get_overlap_stock_line(speaker_id, mover_id),
		"annoyed",
		CHARACTER_OVERLAP_BUBBLE_SECONDS
	)
	await get_tree().create_timer(CHARACTER_OVERLAP_MOVE_DELAY_SECONDS).timeout
	mover_actor.slide_desktop_pet_to_left(
		desired_left,
		CHARACTER_OVERLAP_SLIDE_SECONDS
	)
	await get_tree().create_timer(CHARACTER_OVERLAP_SLIDE_SECONDS + 0.05).timeout
	_finish_overlap_resolution(event_id)

func _finish_overlap_resolution(event_id: int) -> void:
	overlap_cooldown_seconds = CHARACTER_OVERLAP_COOLDOWN_SECONDS
	orchestrator.complete(event_id)

func _execute_queued_overlap(event: Dictionary) -> void:
	var event_id: int = int(event.get("id", 0))
	var payload_value: Variant = event.get("payload", {})
	if not (payload_value is Dictionary):
		orchestrator.complete(event_id)
		return
	var pair_value: Variant = (payload_value as Dictionary).get("pair", {})
	if not (pair_value is Dictionary):
		orchestrator.complete(event_id)
		return
	await _resolve_character_overlap((pair_value as Dictionary).duplicate(true), event_id)

func _get_desktop_character_slot_index(
	character_id: String
) -> int:
	var target_id: String = character_id.strip_edges().to_lower()
	if target_id.is_empty():
		return -1

	var actor: DesktopCharacterActor = character_manager.get_actor(target_id)
	if actor != null and actor.get_desktop_slot_index() >= 0:
		return actor.get_desktop_slot_index()

	var slots: Array[String] = character_manager.get_slot_character_ids()
	for slot_index: int in range(slots.size()):
		if slots[slot_index].strip_edges().to_lower() == target_id:
			return slot_index
	return -1

func _get_actor_desktop_pet_rect(
	actor: DesktopCharacterActor
) -> Rect2:
	if actor == null:
		return Rect2()
	return actor.get_desktop_pet_rect()

func _get_actor_default_gap(
	actor: DesktopCharacterActor
) -> float:
	if actor == null:
		return 48.0
	return maxf(0.0, actor.get_default_desktop_character_gap())

func _desktop_pet_left_fits_screen(
	pet_width: float,
	desired_left: float
) -> bool:

	var usable_screen: Rect2i = (
		DisplayServer
			.screen_get_usable_rect()
	)

	return (
		desired_left
			>= float(
				usable_screen.position.x
			)
		and desired_left + pet_width
			<= float(
				usable_screen.end.x
			)
	)

func _get_overlap_stock_line(
	_speaker_id: String,
	_mover_id: String
) -> String:

	var lines: Array[String] = [
		"Move over.",
		"You're crowding me. Scoot.",
		"Give me some room.",
		"You're standing too close. Shift over.",
		"Personal space. Move."
	]

	if (
		CharacterProfiles
			.get_current_pack_output_language()
		== "ko"
	):
		lines = [
			"좀 비켜.",
			"너무 붙었잖아. 조금만 옮겨.",
			"자리 좀 줘.",
			"가까워. 옆으로 가.",
			"조금 떨어져 있어."
		]

	return lines[
		randi_range(
			0,
			lines.size() - 1
		)
	]
