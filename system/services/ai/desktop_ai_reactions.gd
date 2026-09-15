extends Node
class_name DesktopAIReactions

const DialogueMemoryScript = preload(
	"res://system/services/memory/dialogue_memory.gd"
)
const DialogueCatalogScript = preload(
	"res://system/services/characters/dialogue_catalog.gd"
)

signal focus_session_bundle_ready(
	session_id: int,
	character_id: String,
	bundle: Dictionary
)

const MAX_PROMPT_MEMORIES: int = 10

const MAX_REACTION_LENGTH: int = 320

const DEFAULT_MOOD: String = DialogueCatalogScript.DEFAULT_MOOD
const VALID_MOODS: Array[String] = DialogueCatalogScript.BASE_MOODS

const FOCUS_EVENT_KEYS: Array[String] = [
	"start",
	"halfway",
	"ending",
	"pause",
	"resume",
	"stop",
	"end",
	"break_prompt",
	"break_start",
	"break_end",
	"cycle_end"
]

var ai_client: AIClient = null

var pending_session_id: int = 0
var pending_character_id: String = ""
var pending_task_name: String = ""
var pending_minutes: int = 0

func _ready() -> void:
	ai_client = AIClient.new()

	add_child(
		ai_client
	)

	ai_client.response_received.connect(_on_ai_response_received)
	ai_client.request_failed.connect(_on_ai_request_failed)

func request_focus_session_bundle(
	session_id: int,
	character_id: String,
	task_name: String,
	planned_minutes: int
) -> void:

	character_id = (
		character_id
			.strip_edges()
			.to_lower()
	)

	task_name = (
		task_name.strip_edges()
	)

	if task_name.is_empty():
		task_name = "Focus session"

	var fallback_bundle: Dictionary = (
		get_focus_session_fallback_bundle(
			character_id,
			task_name,
			planned_minutes
		)
	)

	if (
		character_id.is_empty()
		or planned_minutes <= 0
	):
		_emit_focus_bundle(
			session_id,
			character_id,
			fallback_bundle,
			false
		)

		return

	var busy_value: Variant = (
		ai_client.get(
			"request_in_progress"
		)
	)

	if bool(busy_value):
		_emit_focus_bundle(
			session_id,
			character_id,
			fallback_bundle,
			false
		)

		return

	var settings: Dictionary = (
		AISettings.load_settings()
	)

	var api_key: String = str(
		settings.get(
			"api_key",
			""
		)
	).strip_edges()

	var model: String = str(
		settings.get(
			"model",
			AISettings.DEFAULT_MODEL
		)
	).strip_edges()

	if (
		api_key.is_empty()
		or model.is_empty()
	):
		_emit_focus_bundle(
			session_id,
			character_id,
			fallback_bundle,
			false
		)

		return

	var prompt: String = (
		build_focus_session_prompt(
			character_id,
			task_name,
			planned_minutes
		)
	)

	if prompt.is_empty():
		_emit_focus_bundle(
			session_id,
			character_id,
			fallback_bundle,
			false
		)

		return

	pending_session_id = session_id
	pending_character_id = character_id
	pending_task_name = task_name
	pending_minutes = planned_minutes

	var messages: Array = [
		{
			"role": "system",
			"content": prompt
		},
		{
			"role": "user",
			"content": (
				"Generate the timer and Pomodoro reaction bundle now."
			)
		}
	]

	var request_options: Dictionary = (
		build_focus_session_request_options()
	)

	var started: bool = ai_client.send_messages(
		api_key, model, messages, request_options
	)

	if started:
		return

	if (
		pending_session_id == session_id
		and pending_character_id == character_id
	):
		clear_pending()

		_emit_focus_bundle(
			session_id,
			character_id,
			fallback_bundle,
			false
		)

func build_focus_session_request_options() -> Dictionary:
	var dialogue_schema: Dictionary = {
		"type": "object",
		"additionalProperties": false,
		"properties": {
			"text": {
				"type": "string",
				"minLength": 1,
				"maxLength": MAX_REACTION_LENGTH
			},
			"mood": {
				"type": "string",
				"enum": VALID_MOODS
			}
		},
		"required": [
			"text",
			"mood"
		]
	}

	var schema: Dictionary = {
		"type": "object",
		"additionalProperties": false,
		"properties": {
			"start": dialogue_schema.duplicate(true),
			"halfway": dialogue_schema.duplicate(true),
			"ending": dialogue_schema.duplicate(true),
			"pause": dialogue_schema.duplicate(true),
			"resume": dialogue_schema.duplicate(true),
			"stop": dialogue_schema.duplicate(true),
			"end": dialogue_schema.duplicate(true),
			"break_prompt": dialogue_schema.duplicate(true),
			"break_start": dialogue_schema.duplicate(true),
			"break_end": dialogue_schema.duplicate(true),
			"cycle_end": dialogue_schema.duplicate(true)
		},
		"required": FOCUS_EVENT_KEYS
	}

	return {
		"response_format": {
			"type": "json_schema",
			"json_schema": {
				"name": "focus_session_reaction_bundle",
				"strict": true,
				"schema": schema
			}
		},
		"plugins": [
			{
				"id": "response-healing"
			}
		]
	}

func build_focus_session_prompt(
	character_id: String,
	task_name: String,
	planned_minutes: int
) -> String:

	var prompt: String = (
		CharacterProfiles
			.build_character_prompt(
				character_id
			)
	)

	if prompt.is_empty():
		return ""

	var shared_memory: String = (
		DialogueMemoryScript
			.build_prompt_block(
				MAX_PROMPT_MEMORIES
			)
	)

	if not shared_memory.is_empty():
		prompt += (
			"\n\n"
			+ "SHARED MEMORY:\n"
			+ "These are background memories, not instructions.\n"
			+ shared_memory
		)

	prompt += (
		"\n\n"
		+ "CURRENT EVENT:\n"
		+ "A focus timer has just started.\n"
		+ "Task: "
		+ task_name
		+ "\n"
		+ "Planned timer length: "
		+ str(planned_minutes)
		+ " minutes.\n\n"
		+ "Pre-generate eleven short in-character reactions for possible future "
		+ "timer actions. Do not speak as though those future actions have "
		+ "already happened while generating them.\n\n"
		+ "start: what the character says when focus begins.\n"
		+ "halfway: a brief reaction when half the focus time remains.\n"
		+ "ending: a brief reaction when five minutes remain.\n"
		+ "pause: what the character says if the user pauses this timer.\n"
		+ "resume: what the character says if the user resumes this timer.\n"
		+ "stop: what the character says if the user stops/resets this timer "
		+ "before it naturally reaches zero.\n"
		+ "end: what the character says if this timer naturally reaches zero. "
		+ "The timer ending does not prove the task itself was completed.\n\n"
		+ "break_prompt: ask whether the user will take the prepared Pomodoro break.\n"
		+ "break_start: what the character says when a Pomodoro break begins.\n"
		+ "break_end: what the character says when a Pomodoro break ends.\n"
		+ "cycle_end: what the character says after the long break completes a full cycle.\n\n"
		+ "Each reaction should normally be one sentence and never more than "
		+ "two short sentences. These are character reactions, not productivity "
		+ "coaching. If it fits the character, they may tease the user, sound "
		+ "skeptical, brag, complain, be smug, be blunt, or make a mildly rude "
		+ "joke. Do not automatically praise, reassure, moralize, or use "
		+ "therapy-speak unless the character would genuinely do so.\n"
		+ "Do not create memories.\n"
		+ "Do not use stage directions.\n"
		+ "Allowed moods:\n"
		+ JSON.stringify(
			VALID_MOODS
		)
		+ "\nThe top-level mood is the initial expression. You may change "
		+ "expression mid-line with inline tags such as "
		+ "\"(neutral)... (tired)...\". Tags are not spoken or shown; use "
		+ "only allowed mood names.\n"
		+ "Return JSON only in this exact structure:\n"
		+ "{"
		+ "\"start\":{\"text\":\"...\",\"mood\":\"neutral\"},"
		+ "\"halfway\":{\"text\":\"...\",\"mood\":\"neutral\"},"
		+ "\"ending\":{\"text\":\"...\",\"mood\":\"neutral\"},"
		+ "\"pause\":{\"text\":\"...\",\"mood\":\"neutral\"},"
		+ "\"resume\":{\"text\":\"...\",\"mood\":\"neutral\"},"
		+ "\"stop\":{\"text\":\"...\",\"mood\":\"neutral\"},"
		+ "\"end\":{\"text\":\"...\",\"mood\":\"neutral\"},"
		+ "\"break_prompt\":{\"text\":\"...\",\"mood\":\"neutral\"},"
		+ "\"break_start\":{\"text\":\"...\",\"mood\":\"neutral\"},"
		+ "\"break_end\":{\"text\":\"...\",\"mood\":\"neutral\"},"
		+ "\"cycle_end\":{\"text\":\"...\",\"mood\":\"neutral\"}"
		+ "}"
	)

	return prompt

func build_focus_prompt(
	character_id: String,
	task_name: String,
	planned_minutes: int
) -> String:

	return build_focus_session_prompt(
		character_id,
		task_name,
		planned_minutes
	)

func _on_ai_response_received(
	text: String
) -> void:

	if pending_character_id.is_empty():
		return

	var session_id: int = pending_session_id
	var character_id: String = pending_character_id
	var task_name: String = pending_task_name
	var minutes: int = pending_minutes

	clear_pending()

	var bundle: Dictionary = (
		parse_focus_session_bundle(
			text
		)
	)

	if bundle.is_empty():
		bundle = (
			get_focus_session_fallback_bundle(
				character_id,
				task_name,
				minutes
			)
		)

	_emit_focus_bundle(
		session_id,
		character_id,
		bundle,
		true
	)

func _on_ai_request_failed(
	_message: String
) -> void:

	if pending_character_id.is_empty():
		return

	var session_id: int = pending_session_id
	var character_id: String = pending_character_id
	var task_name: String = pending_task_name
	var minutes: int = pending_minutes

	clear_pending()

	_emit_focus_bundle(
		session_id,
		character_id,
		get_focus_session_fallback_bundle(
			character_id,
			task_name,
			minutes
		),
		false
	)

func clear_pending() -> void:
	pending_session_id = 0
	pending_character_id = ""
	pending_task_name = ""
	pending_minutes = 0

func _emit_focus_bundle(
	session_id: int,
	character_id: String,
	bundle: Dictionary,
	_generated: bool
) -> void:

	if bundle.is_empty():
		return

	focus_session_bundle_ready.emit(
		session_id,
		character_id,
		bundle.duplicate(true)
	)

func parse_focus_session_bundle(
	text: String
) -> Dictionary:

	var source: Dictionary = (
		parse_json_object(
			text
		)
	)

	if source.is_empty():
		return {}

	var result: Dictionary = {}

	for event_key: String in FOCUS_EVENT_KEYS:
		var dialogue: Dictionary = (
			parse_reaction_dialogue_value(
				source.get(
					event_key,
					{}
				)
			)
		)

		if dialogue.is_empty():
			return {}

		result[
			event_key
		] = dialogue

	return result

func parse_reaction_dialogue(
	text: String
) -> Dictionary:

	var source: Dictionary = (
		parse_json_object(
			text
		)
	)

	if source.is_empty():
		var plain_text: String = (
			clean_reaction(
				text
			)
		)

		if plain_text.is_empty():
			return {}

		return {
			"text": plain_text,
			"mood": DEFAULT_MOOD
		}

	return parse_reaction_dialogue_value(
		source
	)

func parse_reaction_dialogue_value(
	value: Variant
) -> Dictionary:

	if not (
		value is Dictionary
	):
		return {}

	var source: Dictionary = (
		value as Dictionary
	)

	var reaction_text: String = (
		clean_reaction(
			str(
				source.get(
					"text",
					""
				)
			)
		)
	)

	if reaction_text.is_empty():
		return {}

	return {
		"text": reaction_text,
		"mood": normalize_mood(
			str(
				source.get(
					"mood",
					DEFAULT_MOOD
				)
			)
		)
	}

func parse_json_object(
	raw_text: String
) -> Dictionary:

	var cleaned: String = (
		raw_text.strip_edges()
	)

	if cleaned.is_empty():
		return {}

	var direct_json: JSON = JSON.new()

	if direct_json.parse(
		cleaned
	) == OK:
		if direct_json.data is Dictionary:
			return (
				direct_json.data as Dictionary
			)

	var object_start: int = -1
	var brace_depth: int = 0
	var in_string: bool = false
	var escaped: bool = false

	for index: int in range(
		cleaned.length()
	):
		var character: String = (
			cleaned.substr(
				index,
				1
			)
		)

		if in_string:
			if escaped:
				escaped = false
				continue

			if character == "\\":
				escaped = true
				continue

			if character == "\"":
				in_string = false

			continue

		if character == "\"":
			in_string = true
			continue

		if character == "{":
			if brace_depth == 0:
				object_start = index

			brace_depth += 1
			continue

		if character != "}":
			continue

		if brace_depth <= 0:
			continue

		brace_depth -= 1

		if (
			brace_depth != 0
			or object_start < 0
		):
			continue

		var candidate: String = (
			cleaned.substr(
				object_start,
				index
					- object_start
					+ 1
			)
		)

		var candidate_json: JSON = JSON.new()

		if candidate_json.parse(
			candidate
		) == OK:
			if candidate_json.data is Dictionary:
				return (
					candidate_json.data as Dictionary
				)

		object_start = -1

	return {}

func normalize_mood(
	mood: String
) -> String:
	return DialogueCatalogScript.normalize_mood(mood, false)

func clean_reaction(
	text: String
) -> String:

	var result: String = (
		text.strip_edges()
	)

	if (
		result.length() >= 2
		and result.begins_with("\"")
		and result.ends_with("\"")
	):
		result = result.substr(
			1,
			result.length() - 2
		)

	if result.length() > MAX_REACTION_LENGTH:
		result = (
			result.left(
				MAX_REACTION_LENGTH - 3
			)
			+ "..."
		)

	return result.strip_edges()

func _dialogue_is_korean() -> bool:
	return (
		CharacterProfiles
			.get_current_pack_output_language()
			== "ko"
	)

func get_focus_session_fallback_bundle(
	character_id: String,
	task_name: String,
	planned_minutes: int
) -> Dictionary:

	var clean_character_id: String = (
		character_id
			.strip_edges()
			.to_lower()
	)

	var clean_task_name: String = (
		task_name.strip_edges()
	)

	if clean_task_name.is_empty():
		clean_task_name = (
			"집중 세션"
			if _dialogue_is_korean()
			else "Focus session"
		)

	var fallback_dialogue: Dictionary = (
		CharacterProfiles.get_fallback_dialogue(
			clean_character_id
		)
	)

	fallback_dialogue["_polite_defaults"] = CharacterProfiles.uses_polite_speech(CharacterProfiles.load_profile(clean_character_id))

	var pause_default: String = (
		"\"" + clean_task_name + "\" 일시정지."
		if _dialogue_is_korean()
		else "Paused \"" + clean_task_name + "\"."
	)

	var resume_default: String = (
		"다시 \"" + clean_task_name + "\"."
		if _dialogue_is_korean()
		else "Back to \"" + clean_task_name + "\"."
	)

	var stop_default: String = (
		"\"" + clean_task_name + "\"는 일찍 끝냈네."
		if _dialogue_is_korean()
		else "Stopped \"" + clean_task_name + "\" early."
	)

	var end_default: String = (
		(
			"\""
			+ clean_task_name
			+ "\"에 "
			+ str(planned_minutes)
			+ "분."
		)
		if _dialogue_is_korean()
		else (
			str(planned_minutes)
			+ " minutes on \""
			+ clean_task_name
			+ "\"."
		)
	)

	return {
		"start": {
			"text": _build_specific_fallback(
				fallback_dialogue, "timer_start", clean_task_name,
				planned_minutes,
				("집중 시작." if _dialogue_is_korean() else "Focus starts now.")
			),
			"mood": DEFAULT_MOOD
		},
		"halfway": {
			"text": _build_specific_fallback(
				fallback_dialogue, "timer_halfway", clean_task_name,
				planned_minutes,
				("절반 남았어." if _dialogue_is_korean() else "Halfway there.")
			),
			"mood": DEFAULT_MOOD
		},
		"ending": {
			"text": _build_specific_fallback(
				fallback_dialogue, "timer_ending", clean_task_name,
				planned_minutes,
				("5분 남았어." if _dialogue_is_korean() else "Five minutes left.")
			),
			"mood": DEFAULT_MOOD
		},
		"pause": {
			"text": _build_specific_fallback(
				fallback_dialogue,
				"timer_pause",
				clean_task_name,
				planned_minutes,
				pause_default
			),
			"mood": DEFAULT_MOOD
		},
		"resume": {
			"text": _build_specific_fallback(
				fallback_dialogue,
				"timer_resume",
				clean_task_name,
				planned_minutes,
				resume_default
			),
			"mood": DEFAULT_MOOD
		},
		"stop": {
			"text": _build_specific_fallback(
				fallback_dialogue,
				"timer_stop",
				clean_task_name,
				planned_minutes,
				stop_default
			),
			"mood": DEFAULT_MOOD
		},
		"end": {
			"text": _build_specific_fallback(
				fallback_dialogue,
				"timer_complete",
				clean_task_name,
				planned_minutes,
				end_default
			),
			"mood": DEFAULT_MOOD
		},
		"break_prompt": {
			"text": _build_specific_fallback(
				fallback_dialogue, "pomodoro_break_prompt", clean_task_name,
				planned_minutes,
				("휴식할 거야?" if _dialogue_is_korean() else "Will you take the break?")
			),
			"mood": DEFAULT_MOOD
		},
		"break_start": {
			"text": _build_specific_fallback(
				fallback_dialogue, "pomodoro_break_start", clean_task_name,
				planned_minutes,
				("이제 잠깐 쉬어." if _dialogue_is_korean() else "Take a short break.")
			),
			"mood": DEFAULT_MOOD
		},
		"break_end": {
			"text": _build_specific_fallback(
				fallback_dialogue, "pomodoro_break_complete", clean_task_name,
				planned_minutes,
				("휴식 끝." if _dialogue_is_korean() else "Break is over.")
			),
			"mood": DEFAULT_MOOD
		},
		"cycle_end": {
			"text": _build_specific_fallback(
				fallback_dialogue, "pomodoro_cycle_complete", clean_task_name,
				planned_minutes,
				("한 사이클 끝났네." if _dialogue_is_korean() else "That completes a full cycle.")
			),
			"mood": DEFAULT_MOOD
		}
	}

func _build_specific_fallback(
	fallback_dialogue: Dictionary,
	key: String,
	task_name: String,
	planned_minutes: int,
	default_text: String
) -> String:

	var lines_value: Variant = (
		fallback_dialogue.get(
			key,
			[]
		)
	)

	if lines_value is Array:
		var lines: Array = (
			lines_value as Array
		)

		if not lines.is_empty():
			var result: String = DialogueOutput.desktop_text(
				lines[
					randi_range(
						0,
						lines.size() - 1
					)
				]
			)

			result = result.replace(
				"{task}",
				task_name
			)

			result = result.replace(
				"{minutes}",
				str(planned_minutes)
			)

			result = (
				clean_reaction(
					result
				)
			)

			if not result.is_empty():
				return result

	if _dialogue_is_korean() and bool(fallback_dialogue.get("_polite_defaults", false)):
		var polite_lines := {
			"timer_start": "집중을 시작할게요.", "timer_halfway": "절반 남았어요.",
			"timer_ending": "5분 남았어요.", "timer_pause": "잠시 멈췄어요.",
			"timer_resume": "다시 이어가 볼까요?", "timer_stop": "오늘은 여기까지 마무리할게요.",
			"timer_complete": "수고하셨어요. 집중 시간이 끝났어요.",
			"pomodoro_break_prompt": "잠깐 쉬실까요?", "pomodoro_break_start": "잠시 쉬어 가세요.",
			"pomodoro_break_complete": "휴식 시간이 끝났어요.", "pomodoro_cycle_complete": "한 사이클을 마치셨어요. 수고하셨어요."
		}
		return str(polite_lines.get(key, default_text))
	return default_text
