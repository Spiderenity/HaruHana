extends Node
class_name DesktopSpeechTypewriter

signal mood_requested(mood: String)
signal body_requested(body_state: String, hold_seconds: float)
signal reveal_changed(visible_characters: int)
signal finished

const COMMA_PAUSE_SECONDS: float = 0.08
const CLAUSE_PAUSE_SECONDS: float = 0.12
const SENTENCE_PAUSE_SECONDS: float = 0.18
const ELLIPSIS_DOT_PAUSE_SECONDS: float = 0.16
const ELLIPSIS_PAUSE_SECONDS: float = 0.36
const DASH_PAUSE_SECONDS: float = 0.10
const NEWLINE_PAUSE_SECONDS: float = 0.16

var target_label: Label = null
var valid_moods: Array[String] = []
var valid_body_states: Array[String] = []
var clean_text: String = ""
var mood_events: Array[Dictionary] = []
var body_events: Array[Dictionary] = []

var characters_per_second: float = 30.0
var reveal_budget: float = 0.0
var punctuation_pause_remaining: float = 0.0
var visible_characters: int = 0
var next_mood_event_index: int = 0
var next_body_event_index: int = 0
var active: bool = false

func configure(label: Label) -> void:
	target_label = label

func start(
	source_text: String,
	initial_mood: String,
	allowed_moods: Array[String],
	speed_characters_per_second: float,
	allowed_body_states: Array[String] = []
) -> String:
	cancel()

	valid_moods = allowed_moods.duplicate()
	valid_body_states = allowed_body_states.duplicate()
	characters_per_second = maxf(1.0, speed_characters_per_second)

	var parsed: Dictionary = _parse_inline_events(
		source_text,
		initial_mood
	)

	clean_text = str(parsed.get("text", ""))

	var events_value: Variant = parsed.get("events", [])
	if events_value is Array:
		mood_events = (events_value as Array).duplicate(true)

	var body_events_value: Variant = parsed.get("body_events", [])
	if body_events_value is Array:
		body_events = (body_events_value as Array).duplicate(true)

	if target_label != null:
		target_label.text = clean_text
		target_label.visible_characters = 0

	reveal_budget = 0.0
	punctuation_pause_remaining = 0.0
	visible_characters = 0
	next_mood_event_index = 0
	next_body_event_index = 0

	_emit_due_moods(0)
	_emit_due_body_states(0)

	if clean_text.is_empty():
		active = false

		if target_label != null:
			target_label.visible_characters = -1

		finished.emit()
		return clean_text

	active = true
	set_process(true)

	return clean_text

func cancel() -> void:
	active = false
	set_process(false)

	reveal_budget = 0.0
	punctuation_pause_remaining = 0.0
	visible_characters = 0
	next_mood_event_index = 0
	next_body_event_index = 0

	clean_text = ""
	mood_events.clear()
	body_events.clear()

	if target_label != null:
		target_label.visible_characters = -1

func finish_immediately() -> void:
	if not active:
		return

	visible_characters = clean_text.length()
	reveal_budget = 0.0
	punctuation_pause_remaining = 0.0

	if target_label != null:
		target_label.visible_characters = -1

	_emit_due_moods(visible_characters)
	_emit_due_body_states(visible_characters)

	active = false
	set_process(false)

	reveal_changed.emit(visible_characters)
	finished.emit()

func is_active() -> bool:
	return active

func _process(delta: float) -> void:
	if not active:
		return

	if target_label == null:
		finish_immediately()
		return

	var safe_delta: float = maxf(0.0, delta)

	if punctuation_pause_remaining > 0.0:
		punctuation_pause_remaining = maxf(
			0.0,
			punctuation_pause_remaining - safe_delta
		)
		return

	reveal_budget += safe_delta * characters_per_second

	while (
		reveal_budget >= 1.0
		and visible_characters < clean_text.length()
	):
		reveal_budget -= 1.0

		var revealed_index: int = visible_characters
		visible_characters += 1

		target_label.visible_characters = visible_characters

		_emit_due_moods(visible_characters)
		_emit_due_body_states(visible_characters)
		reveal_changed.emit(visible_characters)

		var punctuation_pause: float = _get_pause_after_character(
			revealed_index
		)

		if punctuation_pause > 0.0:
			punctuation_pause_remaining = punctuation_pause

			reveal_budget = minf(reveal_budget, 0.95)
			break

	if visible_characters >= clean_text.length():
		target_label.visible_characters = -1

		active = false
		set_process(false)

		finished.emit()

func _get_pause_after_character(index: int) -> float:
	if index < 0 or index >= clean_text.length():
		return 0.0

	var current: String = clean_text.substr(index, 1)

	if current == "\n":
		return NEWLINE_PAUSE_SECONDS

	if current == ",":
		return COMMA_PAUSE_SECONDS

	if current == ";" or current == ":":
		return CLAUSE_PAUSE_SECONDS

	if current == "—" or current == "–":
		return DASH_PAUSE_SECONDS

	if current == "!" or current == "?":
		return SENTENCE_PAUSE_SECONDS

	if current != ".":
		return 0.0

	var next_is_period: bool = (
		index + 1 < clean_text.length()
		and clean_text.substr(index + 1, 1) == "."
	)

	if next_is_period:
		return ELLIPSIS_DOT_PAUSE_SECONDS

	var previous_is_period: bool = (
		index > 0
		and clean_text.substr(index - 1, 1) == "."
	)

	if previous_is_period:
		return ELLIPSIS_PAUSE_SECONDS

	return SENTENCE_PAUSE_SECONDS

func _emit_due_moods(current_visible_count: int) -> void:
	while next_mood_event_index < mood_events.size():
		var event: Dictionary = mood_events[next_mood_event_index]

		var character_index: int = int(
			event.get("index", 0)
		)

		if character_index > current_visible_count:
			break

		var mood: String = str(
			event.get("mood", "")
		).strip_edges().to_lower()

		if not mood.is_empty():
			mood_requested.emit(mood)

		next_mood_event_index += 1

func _emit_due_body_states(current_visible_count: int) -> void:
	while next_body_event_index < body_events.size():
		var event: Dictionary = body_events[next_body_event_index]
		var character_index: int = int(event.get("index", 0))
		if character_index > current_visible_count:
			break
		var body_state: String = str(event.get("body", "")).strip_edges().to_lower()
		var hold_seconds: float = maxf(0.0, float(event.get("hold_seconds", 0.0)))
		if not body_state.is_empty():
			body_requested.emit(body_state, hold_seconds)
		next_body_event_index += 1

func _normalize_body_indicator(value: String) -> String:
	return value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")

func _parse_body_indicator(candidate: String) -> Dictionary:
	var clean: String = candidate.strip_edges().to_lower()
	var hold_seconds: float = 0.0
	if clean.begins_with("body:"):
		clean = clean.trim_prefix("body:").strip_edges()

	if clean.contains("@"):
		var parts: PackedStringArray = clean.rsplit("@", true, 1)
		if parts.size() == 2 and parts[1].strip_edges().is_valid_float():
			hold_seconds = maxf(0.0, parts[1].strip_edges().to_float())
			clean = parts[0].strip_edges()
	elif candidate.strip_edges().to_lower().begins_with("body:"):
		var last_colon: int = clean.rfind(":")
		if last_colon > 0:
			var maybe_seconds: String = clean.substr(last_colon + 1).strip_edges()
			if maybe_seconds.is_valid_float():
				hold_seconds = maxf(0.0, maybe_seconds.to_float())
				clean = clean.substr(0, last_colon).strip_edges()

	var state: String = _normalize_body_indicator(clean)
	if not valid_body_states.has(state):
		return {}
	return {"body": state, "hold_seconds": hold_seconds}

func _parse_inline_events(
	source_text: String,
	initial_mood: String
) -> Dictionary:
	var output: String = ""
	var events: Array[Dictionary] = []
	var parsed_body_events: Array[Dictionary] = []

	var starting_mood: String = (
		initial_mood.strip_edges().to_lower()
	)

	if valid_moods.has(starting_mood):
		events.append(
			{
				"index": 0,
				"mood": starting_mood
			}
		)

	var index: int = 0
	var source_length: int = source_text.length()

	while index < source_length:
		var current: String = source_text.substr(index, 1)

		if current == "(":
			var close_index: int = source_text.find(
				")",
				index + 1
			)

			if close_index > index:
				var candidate: String = source_text.substr(
					index + 1,
					close_index - index - 1
				).strip_edges().to_lower()

				if valid_moods.has(candidate):
					events.append(
						{
							"index": output.length(),
							"mood": candidate
						}
					)
					index = close_index + 1
					continue

				var body_indicator: Dictionary = _parse_body_indicator(candidate)
				if not body_indicator.is_empty():
					body_indicator["index"] = output.length()
					parsed_body_events.append(body_indicator)
					index = close_index + 1
					continue

		output += current
		index += 1

	return {
		"text": output.strip_edges(),
		"events": events,
		"body_events": parsed_body_events
	}
