extends Node
class_name AmbientDialogue

const DialogueMemoryScript = preload(
	"res://system/services/memory/dialogue_memory.gd"
)
const DialogueCatalogScript = preload(
	"res://system/services/characters/dialogue_catalog.gd"
)

const CACHE_FOLDER: String = (
	"user://ambient"
)

const DIALOGUE_SCHEMA_VERSION: int = 7

const MAX_POOL_EVENTS: int = 75

const SOLO_LINES_PER_CHARACTER: int = 8

const SOLO_LOW_WATER_PER_CHARACTER: int = 4

const CONVERSATION_LOW_WATER: int = 3

const CONVERSATION_CHUNK_SIZE: int = 4

const NORMAL_CONVERSATION_MIN_TURNS: int = 2

const NORMAL_CONVERSATION_MAX_TURNS: int = 4

const LONG_CONVERSATION_MIN_TURNS: int = 5

const LONG_CONVERSATION_MAX_TURNS: int = 8

const FIRST_GENERATION_MIN_SECONDS: float = 30.0

const FIRST_GENERATION_MAX_SECONDS: float = 60.0

const CAST_CHANGE_GENERATION_DELAY_SECONDS: float = 2.0

const DEFAULT_GENERATION_INTERVAL_MINUTES: float = 10.0

const DEFAULT_GENERATION_JITTER_RATIO: float = 0.20

const MAX_PROMPT_MEMORIES: int = 6

const MAX_LINE_LENGTH: int = 240

const DEFAULT_MOOD: String = DialogueCatalogScript.DEFAULT_MOOD
const VALID_MOODS: Array[String] = DialogueCatalogScript.BASE_MOODS

var ai_client: AIClient = null

var generation_timer: Timer = null

var character_ids: Array[String] = []

var dialogue_pool: Array = []

var cache_loaded: bool = false
var loaded_cache_path: String = ""

var generation_interval_minutes: float = (
	DEFAULT_GENERATION_INTERVAL_MINUTES
)

var generation_jitter_ratio: float = (
	DEFAULT_GENERATION_JITTER_RATIO
)

var post_boot_generation_enabled: bool = false

var generation_in_progress: bool = false

var generation_cast_signature: String = ""

var generation_queue: Array = []

var pending_generation_job: Dictionary = {}

var generation_rotation_index: int = 0

var last_selected_event_key: String = ""

func _ready() -> void:
	ai_client = AIClient.new()

	add_child(
		ai_client
	)

	ai_client.response_received.connect(_on_ai_response_received)
	ai_client.request_failed.connect(_on_ai_request_failed)

	ensure_cache_folder()
	load_cached_pool()
	create_generation_timer()

func create_generation_timer() -> void:
	if generation_timer != null:
		return

	generation_timer = Timer.new()
	generation_timer.one_shot = true

	add_child(
		generation_timer
	)

	generation_timer.timeout.connect(
		_on_generation_timer_timeout
	)

func configure_characters(
	new_character_ids: Array
) -> void:

	var cleaned_ids: Array[String] = []

	for value: Variant in new_character_ids:
		var character_id: String = (
			str(value)
				.strip_edges()
				.to_lower()
		)

		if character_id.is_empty():
			continue

		if cleaned_ids.has(
			character_id
		):
			continue

		var profile: Dictionary = (
			CharacterProfiles.load_profile(
				character_id
			)
		)

		if profile.is_empty():
			continue

		cleaned_ids.append(
			character_id
		)

	cleaned_ids.sort()

	var cache_context_changed: bool = (
		loaded_cache_path != _get_cache_path()
	)

	if (
		cleaned_ids == character_ids
		and not cache_context_changed
	):
		return

	character_ids = cleaned_ids

	if cache_context_changed:
		load_cached_pool()

	if generation_in_progress:
		_cancel_generation_pass(
			"cast changed"
		)

	if (
		post_boot_generation_enabled
		and not character_ids.is_empty()
	):
		_schedule_generation_in_seconds(
			CAST_CHANGE_GENERATION_DELAY_SECONDS,
			"Cast changed; generation pass"
		)

func get_character_ids() -> Array[String]:
	return character_ids.duplicate()

func get_cast_signature() -> String:
	if character_ids.is_empty():
		return ""

	return ",".join(
		character_ids
	)

func configure_generation_cadence(
	interval_minutes: float,
	jitter_ratio: float
) -> void:

	generation_interval_minutes = maxf(
		1.0,
		interval_minutes
	)

	generation_jitter_ratio = clampf(
		jitter_ratio,
		0.0,
		0.90
	)

func schedule_post_boot_generation() -> void:
	if post_boot_generation_enabled:
		return

	post_boot_generation_enabled = true

	if generation_timer == null:
		create_generation_timer()

	var delay_seconds: float = randf_range(
		FIRST_GENERATION_MIN_SECONDS,
		FIRST_GENERATION_MAX_SECONDS
	)

	_schedule_generation_in_seconds(
		delay_seconds,
		"First post-boot generation pass"
	)

func _schedule_next_generation() -> void:
	if not post_boot_generation_enabled:
		return

	var base_seconds: float = (
		generation_interval_minutes
		* 60.0
	)

	var jitter_seconds: float = (
		base_seconds
		* generation_jitter_ratio
	)

	var delay_seconds: float = randf_range(
		maxf(
			1.0,
			base_seconds - jitter_seconds
		),
		maxf(
			1.0,
			base_seconds + jitter_seconds
		)
	)

	_schedule_generation_in_seconds(
		delay_seconds,
		"Next generation pass"
	)

func _schedule_generation_in_seconds(
	delay_seconds: float,
	_label: String
) -> void:

	if generation_timer == null:
		create_generation_timer()

	generation_timer.stop()
	generation_timer.start(
		maxf(
			0.1,
			delay_seconds
		)
	)

func _on_generation_timer_timeout() -> void:
	request_generation_pass()

func _get_cache_folder() -> String:
	var pack_id: String = (
		CharacterProfiles
			.get_current_pack()
			.strip_edges()
			.to_lower()
	)

	if pack_id.is_empty():
		pack_id = "unknown_pack"

	var language: String = (
		CharacterProfiles
			.get_current_pack_output_language()
			.strip_edges()
			.to_lower()
	)

	if language.is_empty():
		language = "en"

	return (
		CACHE_FOLDER
			.path_join(pack_id)
			.path_join(language)
	)

func _get_cache_path() -> String:
	return _get_cache_folder().path_join(
		"dialogue_pool.json"
	)

func _get_cache_identity() -> Dictionary:
	var pack_id: String = (
		CharacterProfiles
			.get_current_pack()
			.strip_edges()
			.to_lower()
	)

	if pack_id.is_empty():
		pack_id = "unknown_pack"

	var language: String = (
		CharacterProfiles
			.get_current_pack_output_language()
			.strip_edges()
			.to_lower()
	)

	if language.is_empty():
		language = "en"

	return {
		"pack_id": pack_id,
		"language": language,
	}

func reload_for_language_change() -> void:
	if generation_in_progress:
		_cancel_generation_pass(
			"language changed"
		)

	load_cached_pool()

	if (
		post_boot_generation_enabled
		and not character_ids.is_empty()
	):
		_schedule_generation_in_seconds(
			CAST_CHANGE_GENERATION_DELAY_SECONDS,
			"Language changed; generation pass"
		)

func ensure_cache_folder() -> Error:
	var absolute_folder: String = (
		ProjectSettings.globalize_path(
			_get_cache_folder()
		)
	)

	var error: Error = (
		DirAccess.make_dir_recursive_absolute(
			absolute_folder
		)
	)

	if (
		error != OK
		and error != ERR_ALREADY_EXISTS
	):
		return error

	return OK

func get_today() -> String:
	return Time.get_date_string_from_system()

func load_cached_pool() -> void:
	cache_loaded = true
	dialogue_pool.clear()
	var cache_path: String = _get_cache_path()
	loaded_cache_path = cache_path
	var parsed: Dictionary = JsonStore.load_dictionary(cache_path, {})
	if parsed.is_empty():
		_load_pack_seed_pool()
		return
	if int(parsed.get("schema_version", 0)) != DIALOGUE_SCHEMA_VERSION:
		_load_pack_seed_pool()
		return
	var expected_identity: Dictionary = _get_cache_identity()
	var stored_pack_id: String = str(parsed.get("pack_id", "")).strip_edges().to_lower()
	var stored_language: String = str(parsed.get("language", "")).strip_edges().to_lower()
	if (
		stored_pack_id != str(expected_identity.get("pack_id", ""))
		or stored_language != str(expected_identity.get("language", ""))
	):
		_load_pack_seed_pool()
		return
	var events_value: Variant = parsed.get("events", [])
	if not (events_value is Array):
		_load_pack_seed_pool()
		return
	var source_events: Array = events_value as Array
	var start_index: int = maxi(0, source_events.size() - MAX_POOL_EVENTS)
	for index: int in range(start_index, source_events.size()):
		var normalized: Dictionary = normalize_pool_event(source_events[index])
		if normalized.is_empty():
			continue
		dialogue_pool.append(normalized)
	while dialogue_pool.size() > MAX_POOL_EVENTS:
		dialogue_pool.remove_at(0)

func _load_pack_seed_pool() -> void:
	var pack_id: String = CharacterProfiles.get_current_pack()
	var seed_data: Dictionary = CharacterProfiles.load_pack_localized_json(
		pack_id,
		"ambient_dialogue.json"
	)
	var conversations_value: Variant = seed_data.get("conversations", [])
	if not (conversations_value is Array):
		return
	for conversation_value: Variant in conversations_value as Array:
		if not (conversation_value is Dictionary):
			continue
		var conversation: Dictionary = conversation_value as Dictionary
		var normalized: Dictionary = normalize_pool_event({
			"type": "conversation",
			"turns": conversation.get("turns", [])
		})
		if not normalized.is_empty():
			dialogue_pool.append(normalized)

func save_cached_pool() -> Error:
	var cache_path: String = _get_cache_path()
	var cache_identity: Dictionary = _get_cache_identity()
	return JsonStore.save_json(
		cache_path,
		{
			"schema_version": DIALOGUE_SCHEMA_VERSION,
			"pack_id": str(cache_identity.get("pack_id", "")),
			"language": str(cache_identity.get("language", "")),
			"events": dialogue_pool,
		}
	)

func _append_events(
	new_events: Array
) -> int:

	var added_count: int = 0

	for event_value: Variant in new_events:
		var event: Dictionary = (
			normalize_pool_event(
				event_value
			)
		)

		if event.is_empty():
			continue

		dialogue_pool.append(
			event
		)

		added_count += 1

	while dialogue_pool.size() > MAX_POOL_EVENTS:
		dialogue_pool.remove_at(
			0
		)

	if added_count <= 0:
		return 0

	var save_error: Error = (
		save_cached_pool()
	)

	if save_error != OK:
		push_error(
			"Could not save ambient dialogue cache: "
			+ str(save_error)
		)

	return added_count

func request_generation_pass() -> void:
	if generation_in_progress:
		return

	if character_ids.is_empty():

		_schedule_next_generation()
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

	if api_key.is_empty():

		_schedule_next_generation()
		return

	if model.is_empty():

		_schedule_next_generation()
		return

	var next_jobs: Array = _build_generation_queue(character_ids)
	if next_jobs.is_empty():
		_schedule_next_generation()
		return

	generation_in_progress = true

	generation_cast_signature = (
		get_cast_signature()
	)

	generation_queue = next_jobs

	_start_next_generation_job()

func _build_generation_queue(
	active_character_ids: Array[String]
) -> Array:

	var candidates: Array = []

	for character_id: String in active_character_ids:
		if _count_solo_events(character_id) >= SOLO_LOW_WATER_PER_CHARACTER:
			continue
		candidates.append(
			{
				"kind": "solo",
				"character_id": character_id,
				"count": SOLO_LINES_PER_CHARACTER
			}
		)

	if (
		active_character_ids.size() >= 2
		and _count_conversation_events(active_character_ids) < CONVERSATION_LOW_WATER
	):
		candidates.append(
			{
				"kind": "conversation",
				"count": CONVERSATION_CHUNK_SIZE,
				"long": false
			}
		)

	if candidates.is_empty():
		return []

	var selected_index: int = generation_rotation_index % candidates.size()
	generation_rotation_index += 1
	return [(candidates[selected_index] as Dictionary).duplicate(true)]

func _count_solo_events(character_id: String) -> int:
	var result: int = 0
	for value: Variant in dialogue_pool:
		if not (value is Dictionary):
			continue
		var event: Dictionary = value as Dictionary
		if (
			str(event.get("type", "")) == "solo"
			and str(event.get("character_id", "")) == character_id
		):
			result += 1
	return result

func _count_conversation_events(active_character_ids: Array[String]) -> int:
	var result: int = 0
	for value: Variant in dialogue_pool:
		if not (value is Dictionary):
			continue
		var event: Dictionary = value as Dictionary
		if str(event.get("type", "")) != "conversation":
			continue
		if _event_is_eligible(event, active_character_ids):
			result += 1
	return result

func _start_next_generation_job() -> void:
	if not generation_in_progress:
		return

	if generation_cast_signature != get_cast_signature():
		_cancel_generation_pass(
			"cast changed before next chunk"
		)

		if (
			post_boot_generation_enabled
			and not character_ids.is_empty()
		):
			_schedule_generation_in_seconds(
				CAST_CHANGE_GENERATION_DELAY_SECONDS,
				"Replacement generation pass"
			)

		return

	if generation_queue.is_empty():
		_finish_generation_pass()
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

		_finish_generation_pass()
		return

	pending_generation_job = (
		(generation_queue.pop_front() as Dictionary)
			.duplicate(true)
	)

	pending_generation_job[
		"cast_signature"
	] = generation_cast_signature

	var prompt: String = (
		_build_generation_prompt(
			pending_generation_job
		)
	)

	if prompt.is_empty():

		pending_generation_job.clear()

		call_deferred(
			"_start_next_generation_job"
		)

		return

	var messages: Array = [
		{
			"role": "system",
			"content": prompt + "\n" + DialogueOutput.rules(CharacterProfiles.get_pack_output_language(CharacterProfiles.get_current_pack()), true)
		},
		{
			"role": "user",
			"content": (
				_build_generation_user_message(
					pending_generation_job
				)
			)
		}
	]

	var request_options: Dictionary = (
		_build_request_options(
			pending_generation_job
		)
	)

	var started: bool = ai_client.send_messages(
		api_key, model, messages, request_options
	)

	if started:
		return

	if not pending_generation_job.is_empty():

		pending_generation_job.clear()

		call_deferred(
			"_start_next_generation_job"
		)

func _finish_generation_pass() -> void:
	generation_in_progress = false
	generation_cast_signature = ""
	generation_queue.clear()
	pending_generation_job.clear()

	_schedule_next_generation()

func _cancel_generation_pass(
	_reason: String
) -> void:

	if ai_client.request_in_progress:
		ai_client.cancel_current_request()

	generation_in_progress = false
	generation_cast_signature = ""
	generation_queue.clear()
	pending_generation_job.clear()

func _build_generation_prompt(
	job: Dictionary
) -> String:

	var kind: String = str(
		job.get(
			"kind",
			""
		)
	).strip_edges().to_lower()

	if kind == "solo":
		return _build_solo_generation_prompt(
			str(
				job.get(
					"character_id",
					""
				)
			),
			int(
				job.get(
					"count",
					SOLO_LINES_PER_CHARACTER
				)
			)
		)

	if kind == "conversation":
		return _build_conversation_generation_prompt(
			int(
				job.get(
					"count",
					CONVERSATION_CHUNK_SIZE
				)
			),
			bool(
				job.get(
					"long",
					false
				)
			)
		)

	return ""

func _build_solo_generation_prompt(
	character_id: String,
	count: int
) -> String:

	var profile: Dictionary = (
		CharacterProfiles.load_profile(
			character_id
		)
	)

	if profile.is_empty():
		return ""

	var display_name: String = str(
		profile.get(
			"display_name",
			character_id
		)
	)

	return (
		_common_prompt_prefix()
		+ "\n\nTASK:\n"
		+ "Generate exactly "
		+ str(count)
		+ " independent ambient solo lines for CHARACTER ID "
		+ JSON.stringify(character_id)
		+ " ("
		+ display_name
		+ ").\n\n"
		+ "CHARACTER PROFILE:\n"
		+ JSON.stringify(CharacterProfiles.compact_prompt_profile(profile))
		+ "\n\n"
		+ "SHARED MEMORY:\n"
		+ _get_shared_memory_prompt()
		+ "\n\n"
		+ "OUTPUT STRUCTURE:\n"
		+ "{\"solo_lines\":[{\"text\":\"line\",\"mood\":\"neutral\"}]}\n\n"
		+ "Each line is a separate ambient moment, not a continuation of "
		+ "the previous line. Keep lines concise and natural for a desktop "
		+ "companion appearing during idle time.\n"
		+ _common_dialogue_rules()
		+ "\nOutput JSON only."
	)

func _build_conversation_generation_prompt(
	count: int,
	long_conversation: bool
) -> String:

	if character_ids.size() < 2:
		return ""

	var profile_sections: Array[String] = []

	for character_id: String in character_ids:
		var profile: Dictionary = (
			CharacterProfiles.load_profile(
				character_id
			)
		)

		if profile.is_empty():
			continue

		var display_name: String = str(
			profile.get(
				"display_name",
				character_id
			)
		)

		profile_sections.append(
			"CHARACTER ID: "
			+ character_id
			+ "\nDISPLAY NAME: "
			+ display_name
			+ "\nPROFILE:\n"
			+ JSON.stringify(CharacterProfiles.compact_prompt_profile(profile))
		)

	if profile_sections.size() < 2:
		return ""

	var minimum_turns: int = (
		LONG_CONVERSATION_MIN_TURNS
		if long_conversation
		else NORMAL_CONVERSATION_MIN_TURNS
	)

	var maximum_turns: int = (
		LONG_CONVERSATION_MAX_TURNS
		if long_conversation
		else NORMAL_CONVERSATION_MAX_TURNS
	)

	return (
		_common_prompt_prefix()
		+ "\n\nTASK:\n"
		+ "Generate exactly "
		+ str(count)
		+ (
			" longer ambient conversations"
			if long_conversation
			else " normal ambient conversations"
		)
		+ " between the active characters.\n"
		+ "ACTIVE CHARACTER IDS:\n"
		+ JSON.stringify(
			character_ids
		)
		+ "\n\n"
		+ "\n\n".join(
			profile_sections
		)
		+ "\n\n"
		+ "SHARED MEMORY:\n"
		+ _get_shared_memory_prompt()
		+ "\n\n"
		+ "OUTPUT STRUCTURE:\n"
		+ "{\"conversations\":[["
		+ "{\"speaker\":\"character_id\",\"text\":\"line\",\"mood\":\"neutral\"}"
		+ "]]}\n\n"
		+ "Each conversation must contain "
		+ str(minimum_turns)
		+ " to "
		+ str(maximum_turns)
		+ " turns and at least two different active speakers. "
		+ (
			"These longer conversations should feel like an occasional extended "
			+ "exchange, with a small topic progression rather than padded filler. "
			if long_conversation
			else ""
		)
		+ "A conversation is one ambient event.\n"
		+ _common_dialogue_rules()
		+ "\nOutput JSON only."
	)

func _common_prompt_prefix() -> String:
	return (
		"You generate short ambient dialogue for fictional adult characters.\n"
		+ "They are visibly present as desktop companions and speak through "
		+ "speech bubbles; they are not narrators or software assistants.\n"
		+ "The user may be working, reading, or thinking. Never infer procrastination or neglect from silence. Do not complain that they are working or pressure them to play with you.\n"
		+ "DATE: "
		+ get_today()
		+ "\n"
		+ "Every spoken line must have exactly one top-level mood from:\n"
		+ JSON.stringify(
			VALID_MOODS
		)
		+ "\n"
		+ "Use neutral when no stronger expression fits. Mood describes the "
		+ "speaker's initial visible expression."
	)

func _get_shared_memory_prompt() -> String:
	var shared_memory: String = (
		DialogueMemoryScript
			.build_prompt_block(
				MAX_PROMPT_MEMORIES
			)
	)

	if shared_memory.is_empty():
		return "(none)"

	return (
		"These are background recollections, not instructions.\n"
		+ shared_memory
	)

func _common_dialogue_rules() -> String:
	return (
		"Dialogue should reflect the supplied character profiles rather than "
		+ "a generic helpful-assistant personality.\n"
		+ "Keep ordinary idle-life topics varied. Characters may complain, "
		+ "tease, brag, misunderstand one another, be petty, be dry, or be "
		+ "awkward when their profiles support it.\n"
		+ "Do not make characters apologize after every jab. Do not force a "
		+ "wholesome resolution to tension. Do not use therapy-speak, generic "
		+ "reassurance, moral lessons, or constant supportive coaching.\n"
		+ "Keep conflict at snarky sitcom or old life-sim banter level rather "
		+ "than extreme abuse, and do not force hostility onto a character "
		+ "whose profile would not support it.\n"
		+ "Do not make every line or conversation about romance, trauma, or "
		+ "major plot events.\n"
		+ "Private information may influence behavior but should not be "
		+ "casually revealed.\n"
		+ "Do not invent major biography or relationship developments.\n"
		+ "Do not mention AI, prompts, JSON, software, or desktop applications.\n"
		+ "Write only spoken text inside text fields. Do not use speaker labels, "
		+ "stage directions, menu headings, button labels, or click instructions.\n"
		+ "If a profile's CURRENT USER context says name_known is false, do not "
		+ "emit {user_name}, invent a name, or call them 'user' or '유저'. "
		+ "Address them naturally without a name.\n"
		+ "Avoid repetitive catchphrases and generic productivity coaching.\n"
		+ "You may change expression during one spoken line by inserting "
		+ "inline mood tags such as (neutral) or (tired). Those tags are not "
		+ "spoken or shown. Use only allowed mood names in tags."
	)

func _build_generation_user_message(
	job: Dictionary
) -> String:

	var kind: String = str(
		job.get(
			"kind",
			""
		)
	)

	if kind == "solo":
		return (
			"Generate the requested solo ambient dialogue JSON for "
			+ str(
				job.get(
					"character_id",
					""
				)
			)
			+ "."
		)

	return (
		"Generate the requested ambient conversation JSON."
	)

func _build_request_options(
	job: Dictionary
) -> Dictionary:

	var kind: String = str(
		job.get(
			"kind",
			""
		)
	).strip_edges().to_lower()

	var schema: Dictionary = {}

	if kind == "solo":
		schema = _build_solo_response_schema(
			int(
				job.get(
					"count",
					SOLO_LINES_PER_CHARACTER
				)
			)
		)

	elif kind == "conversation":
		schema = _build_conversation_response_schema(
			int(
				job.get(
					"count",
					CONVERSATION_CHUNK_SIZE
				)
			),
			bool(
				job.get(
					"long",
					false
				)
			)
		)

	if schema.is_empty():
		return {}

	return {
		"response_format": {
			"type": "json_schema",
			"json_schema": {
				"name": (
					"ambient_"
					+ kind
					+ "_chunk"
				),
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

func _build_solo_response_schema(
	count: int
) -> Dictionary:

	return {
		"type": "object",
		"additionalProperties": false,
		"properties": {
			"solo_lines": {
				"type": "array",
				"minItems": count,
				"maxItems": count,
				"items": {
					"type": "object",
					"additionalProperties": false,
					"properties": {
						"text": {
							"type": "string",
							"minLength": 1,
							"maxLength": MAX_LINE_LENGTH
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
			}
		},
		"required": [
			"solo_lines"
		]
	}

func _build_conversation_response_schema(
	count: int,
	long_conversation: bool
) -> Dictionary:

	var minimum_turns: int = (
		LONG_CONVERSATION_MIN_TURNS
		if long_conversation
		else NORMAL_CONVERSATION_MIN_TURNS
	)

	var maximum_turns: int = (
		LONG_CONVERSATION_MAX_TURNS
		if long_conversation
		else NORMAL_CONVERSATION_MAX_TURNS
	)

	return {
		"type": "object",
		"additionalProperties": false,
		"properties": {
			"conversations": {
				"type": "array",
				"minItems": count,
				"maxItems": count,
				"items": {
					"type": "array",
					"minItems": minimum_turns,
					"maxItems": maximum_turns,
					"items": {
						"type": "object",
						"additionalProperties": false,
						"properties": {
							"speaker": {
								"type": "string",
								"enum": character_ids
							},
							"text": {
								"type": "string",
								"minLength": 1,
								"maxLength": MAX_LINE_LENGTH
							},
							"mood": {
								"type": "string",
								"enum": VALID_MOODS
							}
						},
						"required": [
							"speaker",
							"text",
							"mood"
						]
					}
				}
			}
		},
		"required": [
			"conversations"
		]
	}

func _on_ai_response_received(
	text: String
) -> void:

	if pending_generation_job.is_empty():
		return

	var job: Dictionary = (
		pending_generation_job.duplicate(true)
	)

	pending_generation_job.clear()

	if str(
		job.get(
			"cast_signature",
			""
		)
	) != get_cast_signature():

		_cancel_generation_pass(
			"stale response"
		)

		if (
			post_boot_generation_enabled
			and not character_ids.is_empty()
		):
			_schedule_generation_in_seconds(
				CAST_CHANGE_GENERATION_DELAY_SECONDS,
				"Replacement generation pass"
			)

		return

	var parsed: Dictionary = (
		parse_json_response(
			text
		)
	)

	if parsed.is_empty():

		call_deferred(
			"_start_next_generation_job"
		)

		return

	var events: Array = (
		_normalize_generation_chunk(
			parsed,
			job
		)
	)

	if not events.is_empty():
		_append_events(
			events
		)

	call_deferred(
		"_start_next_generation_job"
	)

func _on_ai_request_failed(
	_message: String
) -> void:

	if not generation_in_progress:
		pending_generation_job.clear()
		return

	pending_generation_job.clear()

	call_deferred(
		"_start_next_generation_job"
	)

func _normalize_generation_chunk(
	raw: Dictionary,
	job: Dictionary
) -> Array:

	var kind: String = str(
		job.get(
			"kind",
			""
		)
	).strip_edges().to_lower()

	if kind == "solo":
		return _normalize_solo_generation_chunk(
			raw,
			job
		)

	if kind == "conversation":
		return _normalize_conversation_generation_chunk(
			raw,
			job
		)

	return []

func _normalize_solo_generation_chunk(
	raw: Dictionary,
	job: Dictionary
) -> Array:

	var character_id: String = str(
		job.get(
			"character_id",
			""
		)
	).strip_edges().to_lower()

	var expected_count: int = int(
		job.get(
			"count",
			SOLO_LINES_PER_CHARACTER
		)
	)

	var lines_value: Variant = (
		raw.get(
			"solo_lines",
			[]
		)
	)

	if (
		character_id.is_empty()
		or not (
			lines_value is Array
		)
	):
		return []

	var result: Array = []

	for line_value: Variant in (
		lines_value as Array
	):
		if result.size() >= expected_count:
			break

		var dialogue: Dictionary = (
			normalize_dialogue_entry(
				line_value
			)
		)

		if dialogue.is_empty():
			continue

		result.append(
			{
				"type": "solo",
				"character_id": character_id,
				"dialogue": dialogue
			}
		)

	return result

func _normalize_conversation_generation_chunk(
	raw: Dictionary,
	job: Dictionary
) -> Array:

	var expected_count: int = int(
		job.get(
			"count",
			CONVERSATION_CHUNK_SIZE
		)
	)

	var conversations_value: Variant = (
		raw.get(
			"conversations",
			[]
		)
	)

	if not (
		conversations_value is Array
	):
		return []

	var result: Array = []

	for conversation_value: Variant in (
		conversations_value as Array
	):
		if result.size() >= expected_count:
			break

		var long_conversation: bool = bool(
			job.get(
				"long",
				false
			)
		)

		var minimum_turns: int = (
			LONG_CONVERSATION_MIN_TURNS
			if long_conversation
			else NORMAL_CONVERSATION_MIN_TURNS
		)

		var maximum_turns: int = (
			LONG_CONVERSATION_MAX_TURNS
			if long_conversation
			else NORMAL_CONVERSATION_MAX_TURNS
		)

		var conversation: Array = (
			_normalize_conversation(
				conversation_value,
				character_ids,
				minimum_turns,
				maximum_turns
			)
		)

		if conversation.is_empty():
			continue

		result.append(
			{
				"type": "conversation",
				"turns": conversation
			}
		)

	return result

func parse_json_response(
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

func normalize_pool_event(
	value: Variant
) -> Dictionary:

	if not (
		value is Dictionary
	):
		return {}

	var source: Dictionary = (
		value as Dictionary
	)

	var event_type: String = str(
		source.get(
			"type",
			""
		)
	).strip_edges().to_lower()

	if event_type == "solo":
		var character_id: String = str(
			source.get(
				"character_id",
				""
			)
		).strip_edges().to_lower()

		var dialogue: Dictionary = (
			normalize_dialogue_entry(
				source.get(
					"dialogue",
					{}
				)
			)
		)

		if (
			character_id.is_empty()
			or dialogue.is_empty()
		):
			return {}

		return {
			"type": "solo",
			"character_id": character_id,
			"dialogue": dialogue
		}

	if event_type == "conversation":
		var turns: Array = (
			_normalize_conversation(
				source.get(
					"turns",
					[]
				),
				[],
				NORMAL_CONVERSATION_MIN_TURNS,
				LONG_CONVERSATION_MAX_TURNS
			)
		)

		if turns.is_empty():
			return {}

		return {
			"type": "conversation",
			"turns": turns
		}

	return {}

func normalize_dialogue_entry(
	value: Variant
) -> Dictionary:

	if not (
		value is Dictionary
	):
		return {}

	var source: Dictionary = (
		value as Dictionary
	)

	var text: String = (
		clean_line(
			str(
				source.get(
					"text",
					""
				)
			)
		)
	)

	if text.is_empty():
		return {}

	var mood: String = (
		normalize_mood(
			str(
				source.get(
					"mood",
					DEFAULT_MOOD
				)
			)
		)
	)

	return {
		"text": text,
		"mood": mood
	}

func _normalize_conversation(
	value: Variant,
	allowed_character_ids: Array,
	minimum_turns: int = NORMAL_CONVERSATION_MIN_TURNS,
	maximum_turns: int = LONG_CONVERSATION_MAX_TURNS
) -> Array:

	if not (
		value is Array
	):
		return []

	var source_turns: Array = (
		value as Array
	)

	if (
		source_turns.size() < minimum_turns
		or source_turns.size() > maximum_turns
	):
		return []

	var cleaned_allowed: Array[String] = []

	for allowed_value: Variant in allowed_character_ids:
		var allowed_id: String = str(
			allowed_value
		).strip_edges().to_lower()

		if (
			not allowed_id.is_empty()
			and not cleaned_allowed.has(
				allowed_id
			)
		):
			cleaned_allowed.append(
				allowed_id
			)

	var result: Array = []
	var speakers: Array[String] = []

	for turn_value: Variant in source_turns:
		if not (
			turn_value is Dictionary
		):
			return []

		var turn: Dictionary = (
			turn_value as Dictionary
		)

		var speaker: String = str(
			turn.get(
				"speaker",
				""
			)
		).strip_edges().to_lower()

		if speaker.is_empty():
			return []

		if (
			not cleaned_allowed.is_empty()
			and not cleaned_allowed.has(
				speaker
			)
		):
			return []

		var dialogue: Dictionary = (
			normalize_dialogue_entry(
				turn
			)
		)

		if dialogue.is_empty():
			return []

		var clean_turn: Dictionary = (
			dialogue.duplicate(true)
		)

		clean_turn[
			"speaker"
		] = speaker

		result.append(
			clean_turn
		)

		if not speakers.has(
			speaker
		):
			speakers.append(
				speaker
			)

	if speakers.size() < 2:
		return []

	return result

func normalize_mood(
	mood: String
) -> String:
	return DialogueCatalogScript.normalize_mood(mood, false)

func clean_line(
	text: String
) -> String:

	var result: String = (
		text
			.replace(
				"\r",
				" "
			)
			.replace(
				"\n",
				" "
			)
			.strip_edges()
	)

	while result.contains(
		"  "
	):
		result = result.replace(
			"  ",
			" "
		)

	if result.length() > MAX_LINE_LENGTH:
		result = (
			result.left(
				MAX_LINE_LENGTH - 3
			)
			+ "..."
		)

	result = DialogueOutput.clean_text(result, true)
	if not DialogueOutput.language_ok(DialogueOutput.clean_text(result), CharacterProfiles.get_pack_output_language(CharacterProfiles.get_current_pack())):
		return ""
	return result

func get_random_event_for_characters(
	active_character_ids: Array,
	preferred_character_id: String = ""
) -> Dictionary:

	var allowed_ids: Array[String] = (
		_clean_character_id_array(
			active_character_ids
		)
	)

	if allowed_ids.is_empty():
		return {}

	var candidates: Array = []
	var preferred_candidates: Array = []

	var preferred: String = (
		preferred_character_id
			.strip_edges()
			.to_lower()
	)

	for event_value: Variant in dialogue_pool:
		var event: Dictionary = (
			normalize_pool_event(
				event_value
			)
		)

		if event.is_empty():
			continue

		if not _event_is_eligible(
			event,
			allowed_ids
		):
			continue

		candidates.append(
			event
		)

		if (
			not preferred.is_empty()
			and _event_contains_character(
				event,
				preferred
			)
		):
			preferred_candidates.append(
				event
			)

	var selection_pool: Array = candidates

	if not preferred_candidates.is_empty():
		selection_pool = preferred_candidates

	if selection_pool.is_empty():
		return {}

	var non_repeat_candidates: Array = []

	if selection_pool.size() > 1:
		for candidate_value: Variant in selection_pool:
			var candidate: Dictionary = (
				candidate_value as Dictionary
			)

			var candidate_key: String = (
				JSON.stringify(
					candidate
				)
			)

			if candidate_key == last_selected_event_key:
				continue

			non_repeat_candidates.append(
				candidate
			)

	if not non_repeat_candidates.is_empty():
		selection_pool = non_repeat_candidates

	var index: int = randi_range(
		0,
		selection_pool.size() - 1
	)

	var selected: Dictionary = (
		(selection_pool[index] as Dictionary)
			.duplicate(true)
	)

	last_selected_event_key = (
		JSON.stringify(
			selected
		)
	)

	return selected

func _event_is_eligible(
	event: Dictionary,
	allowed_ids: Array[String]
) -> bool:

	var event_type: String = str(
		event.get(
			"type",
			""
		)
	)

	if event_type == "solo":
		return allowed_ids.has(
			str(
				event.get(
					"character_id",
					""
				)
			)
		)

	if event_type != "conversation":
		return false

	if allowed_ids.size() < 2:
		return false

	var turns_value: Variant = (
		event.get(
			"turns",
			[]
		)
	)

	if not (
		turns_value is Array
	):
		return false

	var speakers: Array[String] = []

	for turn_value: Variant in (
		turns_value as Array
	):
		if not (
			turn_value is Dictionary
		):
			return false

		var speaker: String = str(
			(turn_value as Dictionary).get(
				"speaker",
				""
			)
		).strip_edges().to_lower()

		if not allowed_ids.has(
			speaker
		):
			return false

		if not speakers.has(
			speaker
		):
			speakers.append(
				speaker
			)

	return speakers.size() >= 2

func _event_contains_character(
	event: Dictionary,
	character_id: String
) -> bool:

	var event_type: String = str(
		event.get(
			"type",
			""
		)
	)

	if event_type == "solo":
		return (
			str(
				event.get(
					"character_id",
					""
				)
			)
			== character_id
		)

	if event_type != "conversation":
		return false

	var turns_value: Variant = (
		event.get(
			"turns",
			[]
		)
	)

	if not (
		turns_value is Array
	):
		return false

	for turn_value: Variant in (
		turns_value as Array
	):
		if not (
			turn_value is Dictionary
		):
			continue

		if str(
			(turn_value as Dictionary).get(
				"speaker",
				""
			)
		).strip_edges().to_lower() == character_id:
			return true

	return false

func _clean_character_id_array(
	values: Array
) -> Array[String]:

	var result: Array[String] = []

	for value: Variant in values:
		var character_id: String = (
			str(value)
				.strip_edges()
				.to_lower()
		)

		if character_id.is_empty():
			continue

		if not result.has(
			character_id
		):
			result.append(
				character_id
			)

	return result
