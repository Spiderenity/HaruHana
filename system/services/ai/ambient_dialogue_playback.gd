extends Node
class_name AmbientDialoguePlayback

signal ambient_event_started

signal ambient_event_finished

signal turn_started(
	character_id: String,
	text: String,
	mood: String
)

const DESKTOP_ACTOR_GROUP: StringName = (
	&"desktop_character_actors"
)

const DialogueCatalogScript = preload(
	"res://system/services/characters/dialogue_catalog.gd"
)
const DEFAULT_MOOD: String = DialogueCatalogScript.DEFAULT_MOOD

@export var ambient_dialogue: AmbientDialogue

@export var minimum_turn_seconds: float = 2.4

@export var maximum_turn_seconds: float = 5.5

@export var base_turn_seconds: float = 2.1

@export var seconds_per_character: float = 0.025

@export var bubble_overlap_seconds: float = 1.2

var busy: bool = false
var event_token: int = 0

func request_ambient_event(
	preferred_character_id: String = ""
) -> bool:

	if busy:
		return false

	if _any_actor_play_active():
		return false

	if ambient_dialogue == null:
		return false

	var actors: Array[DesktopCharacterActor] = _get_eligible_actors()

	if actors.is_empty():
		return false

	var active_ids: Array[String] = []

	for actor: DesktopCharacterActor in actors:
		var actor_character_id: String = (
			_get_actor_character_id(
				actor
			)
		)

		if not actor_character_id.is_empty():
			active_ids.append(
				actor_character_id
			)

	var event: Dictionary = ambient_dialogue.get_random_event_for_characters(
		active_ids,
		preferred_character_id
	)

	if event.is_empty():
		return false

	var event_type: String = str(
		event.get(
			"type",
			""
		)
	).strip_edges().to_lower()

	if event_type == "conversation":
		var conversation_value: Variant = (
			event.get(
				"turns",
				[]
			)
		)

		if not (
			conversation_value is Array
		):
			return false

		var conversation: Array = (
			conversation_value as Array
		)

		if conversation.is_empty():
			return false

		busy = true
		event_token += 1

		var conversation_token: int = event_token

		ambient_event_started.emit()

		call_deferred(
			"_play_conversation",
			conversation.duplicate(true),
			conversation_token
		)

		return true

	if event_type != "solo":
		return false

	var character_id: String = str(
		event.get(
			"character_id",
			""
		)
	).strip_edges().to_lower()

	var dialogue_value: Variant = (
		event.get(
			"dialogue",
			{}
		)
	)

	if (
		character_id.is_empty()
		or not (
			dialogue_value is Dictionary
		)
	):
		return false

	var actor: DesktopCharacterActor = _find_actor(character_id)

	if (
		actor == null
		or not _actor_ambient_enabled(
			actor
		)
	):
		return false

	var dialogue: Dictionary = (
		dialogue_value as Dictionary
	)

	if dialogue.is_empty():
		return false

	busy = true
	event_token += 1

	var solo_token: int = event_token

	ambient_event_started.emit()

	call_deferred(
		"_play_solo",
		character_id,
		dialogue.duplicate(true),
		solo_token
	)

	return true
func is_busy() -> bool:
	return busy

func cancel_current_event() -> void:
	if not busy:
		return

	event_token += 1
	busy = false

	for actor: DesktopCharacterActor in _get_all_actors():
		actor.hide_speech()

	ambient_event_finished.emit()

func _play_solo(
	character_id: String,
	dialogue: Dictionary,
	token: int
) -> void:

	if (
		token != event_token
		or _any_actor_play_active()
	):
		if token == event_token:
			_finish_event()

		return

	var actor: DesktopCharacterActor = _find_actor(character_id)

	if actor == null:
		_finish_event()

		return

	var text: String = str(
		dialogue.get(
			"text",
			""
		)
	).strip_edges()

	var mood: String = str(
		dialogue.get(
			"mood",
			DEFAULT_MOOD
		)
	).strip_edges().to_lower()

	if text.is_empty():
		_finish_event()

		return

	var duration: float = (
		_get_turn_seconds(
			text
		)
		+ bubble_overlap_seconds
	)

	_show_actor_dialogue(
		actor,
		{
			"text": text,
			"mood": mood
		},
		duration
	)

	turn_started.emit(
		character_id,
		text,
		mood
	)

	await get_tree().create_timer(
		duration
	).timeout

	if token != event_token:
		return

	_finish_event()

func _play_conversation(
	conversation: Array,
	token: int
) -> void:

	var played_turn: bool = false

	for turn_value: Variant in conversation:
		if (
			token != event_token
			or _any_actor_play_active()
		):
			if token == event_token:
				_finish_event()

			return

		if not (
			turn_value is Dictionary
		):
			continue

		var turn: Dictionary = (
			turn_value
		)

		var character_id: String = str(
			turn.get(
				"speaker",
				""
			)
		).strip_edges().to_lower()

		var text: String = str(
			turn.get(
				"text",
				""
			)
		).strip_edges()

		var mood: String = str(
			turn.get(
				"mood",
				DEFAULT_MOOD
			)
		).strip_edges().to_lower()

		if (
			character_id.is_empty()
			or text.is_empty()
		):
			continue

		var actor: DesktopCharacterActor = _find_actor(character_id)

		if actor == null:
			continue

		if not _actor_ambient_enabled(
			actor
		):
			continue

		var turn_seconds: float = (
			_get_turn_seconds(
				text
			)
		)

		var bubble_duration: float = (
			turn_seconds
			+ bubble_overlap_seconds
		)

		_show_actor_dialogue(
			actor,
			{
				"text": text,
				"mood": mood
			},
			bubble_duration
		)

		turn_started.emit(
			character_id,
			text,
			mood
		)

		played_turn = true

		await get_tree().create_timer(
			turn_seconds
		).timeout

		if token != event_token:
			return

	if played_turn:
		await get_tree().create_timer(
			maxf(
				0.0,
				bubble_overlap_seconds
			)
		).timeout

	if token != event_token:
		return

	_finish_event()

func _show_actor_dialogue(
	actor: DesktopCharacterActor,
	dialogue: Dictionary,
	duration: float
) -> void:
	actor.show_dialogue(dialogue, duration)

func _finish_event() -> void:
	busy = false

	ambient_event_finished.emit()

func _get_all_actors() -> Array[DesktopCharacterActor]:
	var result: Array[DesktopCharacterActor] = []
	for node: Node in get_tree().get_nodes_in_group(DESKTOP_ACTOR_GROUP):
		if is_instance_valid(node) and node is DesktopCharacterActor:
			result.append(node as DesktopCharacterActor)
	return result

func _actor_play_active(actor: DesktopCharacterActor) -> bool:
	return actor.is_play_flustered() or actor.is_play_interaction_active()

func _any_actor_play_active() -> bool:
	for actor: DesktopCharacterActor in _get_all_actors():
		if _actor_play_active(actor):
			return true
	return false

func _get_eligible_actors() -> Array[DesktopCharacterActor]:
	var result: Array[DesktopCharacterActor] = []
	for actor: DesktopCharacterActor in _get_all_actors():
		if not actor.get_ambient_dialogue_enabled():
			continue
		var character_id: String = actor.get_character_id().strip_edges().to_lower()
		if character_id.is_empty() or not _ambient_cast_has(character_id):
			continue
		result.append(actor)
	return result

func _find_actor(character_id: String) -> DesktopCharacterActor:
	var target: String = character_id.strip_edges().to_lower()
	for actor: DesktopCharacterActor in _get_all_actors():
		if actor.get_character_id().strip_edges().to_lower() == target:
			return actor
	return null

func _get_actor_character_id(actor: DesktopCharacterActor) -> String:
	if actor == null:
		return ""
	return actor.get_character_id().strip_edges().to_lower()

func _actor_ambient_enabled(actor: DesktopCharacterActor) -> bool:
	return actor != null and actor.get_ambient_dialogue_enabled()

func _ambient_cast_has(character_id: String) -> bool:
	if ambient_dialogue == null:
		return false
	return ambient_dialogue.get_character_ids().has(character_id)

func _get_turn_seconds(
	text: String
) -> float:

	return clampf(
		base_turn_seconds
			+ float(text.length())
			* seconds_per_character,
		minimum_turn_seconds,
		maximum_turn_seconds
	)
