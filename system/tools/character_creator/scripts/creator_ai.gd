extends Node
class_name CreatorAI

const AppLanguageScript = preload("res://system/app/app_language.gd")

signal generation_finished(groups: Dictionary)
signal generation_failed(message: String)
signal profile_generation_finished(fields: Dictionary)
signal profile_generation_failed(message: String)
signal conversation_generation_finished(conversations: Array)
signal conversation_generation_failed(message: String)
signal locale_generation_finished(language: String, locale_data: Dictionary)
signal locale_generation_failed(language: String, message: String)

var ai_client: AIClient = null
var request_kind: String = ""
var request_in_progress: bool = false
var request_language: String = ""

func _ready() -> void:
	ai_client = AIClient.new()
	add_child(ai_client)
	ai_client.response_received.connect(_on_ai_response_received)
	ai_client.request_failed.connect(_on_ai_request_failed)

func load_settings() -> Dictionary:
	return AISettings.load_settings()

func save_settings(api_key: String, model: String) -> Error:
	return AISettings.save_settings(api_key, model)

func cancel_generation() -> void:
	if ai_client != null:
		ai_client.cancel_current_request()
	request_in_progress = false
	request_kind = ""
	request_language = ""

func generate_defaults(model: CreatorPackModel, character_index: int) -> void:
	if not _can_start_request(character_index, model, "lines"):
		return
	request_kind = "lines"
	var prompt: String = _build_line_prompt(model, character_index)
	_start_request(prompt, "Generate the editable default line groups now. Return JSON only.")

func generate_profile_defaults(model: CreatorPackModel, character_index: int) -> void:
	if not _can_start_request(character_index, model, "profile"):
		return
	request_kind = "profile"
	var prompt: String = _build_profile_prompt(model, character_index)
	_start_request(prompt, "Generate only the missing advanced profile fields. Return JSON only.")

func generate_conversations(model: CreatorPackModel) -> void:
	if not _can_start_pack_request("conversation"):
		return
	request_kind = "conversation"
	_start_request(
		_build_conversation_prompt(model),
		"Generate the editable character conversations now. Return JSON only."
	)

func generate_locale(model: CreatorPackModel, language: String) -> void:
	request_language = language.strip_edges().to_lower()
	if not _can_start_pack_request("locale"):
		request_language = ""
		return
	request_kind = "locale"
	_start_request(
		_build_locale_prompt(model, request_language),
		"Generate the complete translated locale now. Return JSON only."
	)

func _can_start_pack_request(attempted_kind: String) -> bool:
	if request_in_progress:
		_emit_failure_for_kind(attempted_kind, "An AI request is already in progress.", "이미 AI 요청이 진행 중입니다.")
		return false
	var settings: Dictionary = AISettings.load_settings()
	var api_key: String = str(settings.get("api_key", "")).strip_edges()
	var model_route: String = str(settings.get("model", AISettings.DEFAULT_MODEL)).strip_edges()
	if api_key.is_empty() or model_route.is_empty():
		_emit_failure_for_kind(attempted_kind, "Set the API key and model in AI Settings first.", "먼저 AI 설정에서 API 키와 모델을 설정하세요.")
		return false
	return true

func _can_start_request(character_index: int, model: CreatorPackModel, attempted_kind: String) -> bool:
	if request_in_progress:
		_emit_failure_for_kind(attempted_kind, "An AI request is already in progress.", "이미 AI 요청이 진행 중입니다.")
		return false
	if character_index < 0 or character_index >= model.characters.size():
		_emit_failure_for_kind(attempted_kind, "Select a character first.", "캐릭터를 먼저 선택하세요.")
		return false
	var settings: Dictionary = AISettings.load_settings()
	var api_key: String = str(settings.get("api_key", "")).strip_edges()
	var model_route: String = str(settings.get("model", AISettings.DEFAULT_MODEL)).strip_edges()
	if api_key.is_empty() or model_route.is_empty():
		_emit_failure_for_kind(
			attempted_kind,
			"Set the API key and model in AI Settings first.",
			"먼저 AI 설정에서 API 키와 모델을 설정하세요."
		)
		return false
	return true

func _start_request(system_prompt: String, user_prompt: String) -> void:
	var settings: Dictionary = AISettings.load_settings()
	var api_key: String = str(settings.get("api_key", "")).strip_edges()
	var model_route: String = str(settings.get("model", AISettings.DEFAULT_MODEL)).strip_edges()
	var messages: Array = [
		{"role": "system", "content": system_prompt},
		{"role": "user", "content": user_prompt}
	]
	request_in_progress = true
	var started: bool = ai_client.send_messages(api_key, model_route, messages)
	if not started:
		request_in_progress = false
		var failed_kind: String = request_kind
		request_kind = ""
		_emit_failure_for_kind(
			failed_kind,
			"AIClient could not start the request.",
			"AI 요청을 시작할 수 없습니다."
		)

func _build_line_prompt(model: CreatorPackModel, character_index: int) -> String:
	var character: Dictionary = model.characters[character_index]
	var profile: Dictionary = (character.get("profile", {}) as Dictionary).duplicate(true)
	profile.erase("birthday")
	var character_id: String = str(character.get("id", ""))
	var group_ids: Array[String] = []
	for group: Dictionary in model.get_line_groups(character_index):
		var group_id: String = str(group.get("id", ""))
		if model.get_line_group(character_index, group_id).is_empty():
			group_ids.append(group_id)
	var context: Dictionary = {
		"pack": {
			"id": model.pack_id,
			"display_name": model.display_name,
			"description": model.description,
			"language": model.default_language,
		},
		"character_id": character_id,
		"profile": profile,
	}
	return """You write default fallback dialogue for a desktop companion character pack.
Use the supplied manifest/profile as the authority for personality, relationship, voice, lore, and behavioral limits.
Keep lines compact and natural. Do not turn the character into a generic motivational assistant.
Do not claim the user completed work unless the event itself confirms completion.
The runtime displays each text value as spoken bubble dialogue. Do not write speaker names, stage directions, menu headings, button labels, or instructions to click controls.
Preserve useful runtime placeholders such as {task}, {minutes}, and {hour} where relevant. Use {user_name} only as an optional form of address, never as required sentence grammar; the runtime may remove it when no preferred name exists. Never print "user" or "유저" as the person's name.
The mood field is the initial expression. Inline tags such as (happy) or (tired) are silent expression controls and may be placed only where the expression genuinely changes. Every tag must use an allowed mood.
These groups are event fallbacks. Menu conversations and interactive answer choices are generated separately at runtime, so do not put menus, navigation questions, or answer options in these groups.

Return ONE JSON object with this exact outer shape:
{"groups": {"group_id": [{"text": "...", "mood": "neutral"}]}}

Allowed mood values:
neutral, happy, amused, smug, curious, surprised, annoyed, angry, worried, sad, embarrassed, tired, flustered_worried, flustered_surprised, flustered_annoyed

Required group IDs:
%s

Recommended amounts:
- first_boot: 5-7 lines. First-boot dialogue is authored per character, but when multiple new characters boot together the runtime alternates one line per character in round-robin order. Write each line so it still reads naturally with another character speaking between this character's lines; do not assume this character speaks all of its first_boot lines consecutively.
- idle: 5 lines
- timer groups: 3 lines each. timer_complete reacts only after a timer naturally reaches zero; timer_pause, timer_resume, and timer_stop react only to those exact user actions.
- desktop_leave / desktop_arrive: 2 lines each, reacting to a character leaving or returning rather than the user leaving the computer.
- boot_primary: 2 lines for the first character shown at startup.
- boot_arrival / boot_peer: 1-2 lines for a later character arriving and an already-present peer reacting.
- hourly groups: 1-2 lines each, suited to their time period without mechanically announcing the clock.
- pet: 6-10 lines for a friendly touch or stroke.
- poke_head: 3 lines for a direct head poke.
- fluster: 2 lines for overload or accumulated teasing/touch, not ordinary anger.

Character context JSON:
%s
""" % [", ".join(group_ids), JSON.stringify(context, "  ")]

func _build_profile_prompt(model: CreatorPackModel, character_index: int) -> String:
	var character: Dictionary = model.characters[character_index]
	var profile: Dictionary = (character.get("profile", {}) as Dictionary).duplicate(true)
	profile.erase("birthday")
	var missing: Array[String] = model.get_missing_advanced_profile_fields(character_index)
	var context: Dictionary = {
		"pack": {
			"id": model.pack_id,
			"display_name": model.display_name,
			"description": model.description,
			"language": model.default_language,
		},
		"character_id": str(character.get("id", "")),
		"profile": profile,
		"missing_fields": missing,
	}
	return """You complete advanced profile fields for a desktop companion character.
The user intentionally chose a simplified editor. Preserve every existing field exactly and generate only fields listed in missing_fields.
Do not overwrite or reinterpret existing user-written content. Keep the character specific, internally consistent, and suitable for later dialogue generation.
Avoid generic motivational-assistant behavior unless the user's existing profile explicitly asks for it.

Return ONE JSON object using only these keys when they are requested:
{
  "setting_note": "...",
  "voice_avoid": ["..."],
  "behavior_patterns": ["..."],
  "mundane_details": ["..."],
  "private_internal": ["..."],
  "ai_behavior_rules": ["..."],
  "lore": ["..."]
}

Character context JSON:
%s
""" % JSON.stringify(context, "  ")

func _build_conversation_prompt(model: CreatorPackModel) -> String:
	var cast: Array[Dictionary] = []
	for character: Dictionary in model.characters:
		var profile: Dictionary = (character.get("profile", {}) as Dictionary).duplicate(true)
		profile.erase("birthday")
		cast.append({
			"id": character.get("id", ""),
			"profile": profile
		})
	return """You write ambient conversations between desktop companion characters.
Use their profiles, voices, relationship fields, and behavioral limits. Generate 8 conversations with 2-5 turns each. Every conversation must use at least two speakers. Keep ordinary topics varied and avoid generic assistant talk.
Each turn appears as spoken bubble text. Do not include speaker labels, stage directions, menus, buttons, or instructions to click anything. Turns must respond to one another naturally and must use only the supplied character IDs.
The mood field is the speaker's initial expression. Inline mood tags are silent expression changes; use them only at genuine emotional turns and only with an allowed mood.
If the user name is unavailable in the supplied profile, do not emit {user_name}, invent a name, or address the person as "user" or "유저".

Return ONE JSON object:
{"conversations":[{"turns":[{"speaker":"character_id","text":"...","mood":"neutral"}]}]}

Allowed moods:
neutral, happy, amused, smug, curious, surprised, annoyed, angry, worried, sad, embarrassed, tired, flustered_worried, flustered_surprised, flustered_annoyed

Pack context:
%s
""" % JSON.stringify({
		"pack_id": model.pack_id,
		"language": model.default_language,
		"characters": cast
	}, "  ")

func _build_locale_prompt(model: CreatorPackModel, target_language: String) -> String:
	var characters_data: Dictionary = {}
	for character: Dictionary in model.characters:
		characters_data[str(character.get("id", ""))] = {
			"profile": character.get("profile", {}),
			"dialogue": character.get("dialogue", {})
		}
	var source: Dictionary = {
		"characters": characters_data,
		"desktop_events": model.desktop_events,
		"play_profiles": model.play_profiles,
		"conversations": model.conversations
	}
	return """Translate a complete desktop companion character locale from %s to %s.
Preserve every JSON key, character ID, mood value, placeholder, number, and array/object structure. Translate only human-readable prose. Do not summarize or omit content.
Preserve inline mood tags such as (happy) exactly as control tags while translating the surrounding spoken text. Preserve {user_name} as a placeholder rather than translating or expanding it.

Return ONE JSON object with this exact outer shape:
{"characters":{"character_id":{"profile":{},"dialogue":{}}},"desktop_events":{},"play_profiles":{},"conversations":[]}

Source locale JSON:
%s
""" % [model.default_language, target_language, JSON.stringify(source, "  ")]

func _on_ai_response_received(raw_text: String) -> void:
	request_in_progress = false
	var kind: String = request_kind
	var language: String = request_language
	request_kind = ""
	request_language = ""
	var parsed: Dictionary = _parse_json_object(raw_text)
	if parsed.is_empty():
		if kind == "profile":
			profile_generation_failed.emit(_language_text(
				"The generated profile was not valid JSON.",
				"생성된 프로필을 JSON으로 해석할 수 없습니다."
			))
		elif kind == "conversation":
			conversation_generation_failed.emit(_language_text("The generated conversations were not valid JSON.", "생성된 대화를 JSON으로 해석할 수 없습니다."))
		elif kind == "locale":
			locale_generation_failed.emit(language, _language_text("The generated locale was not valid JSON.", "생성된 로캘을 JSON으로 해석할 수 없습니다."))
		else:
			generation_failed.emit(_language_text(
				"The generated default lines were not valid JSON.",
				"생성된 기본 대사를 JSON으로 해석할 수 없습니다."
			))
		return
	if kind == "profile":
		profile_generation_finished.emit(parsed.duplicate(true))
		return
	if kind == "conversation":
		var conversations_value: Variant = parsed.get("conversations", [])
		if not (conversations_value is Array):
			conversation_generation_failed.emit(_language_text("The generation result did not contain conversations.", "생성 결과에 대화가 없습니다."))
			return
		conversation_generation_finished.emit((conversations_value as Array).duplicate(true))
		return
	if kind == "locale":
		locale_generation_finished.emit(language, parsed.duplicate(true))
		return
	var groups_value: Variant = parsed.get("groups", {})
	if not (groups_value is Dictionary):
		generation_failed.emit(_language_text(
			"The generation result did not contain groups.",
			"생성 결과에 groups가 없습니다."
		))
		return
	generation_finished.emit((groups_value as Dictionary).duplicate(true))

func _on_ai_request_failed(message: String) -> void:
	request_in_progress = false
	var kind: String = request_kind
	var language: String = request_language
	request_kind = ""
	request_language = ""
	if kind == "profile":
		profile_generation_failed.emit(message)
	elif kind == "conversation":
		conversation_generation_failed.emit(message)
	elif kind == "locale":
		locale_generation_failed.emit(language, message)
	else:
		generation_failed.emit(message)

func _emit_failure_for_kind(kind: String, english: String, korean: String) -> void:
	var message: String = _language_text(english, korean)
	if kind == "profile":
		profile_generation_failed.emit(message)
	elif kind == "conversation":
		conversation_generation_failed.emit(message)
	elif kind == "locale":
		locale_generation_failed.emit(request_language, message)
	else:
		generation_failed.emit(message)

func _parse_json_object(text: String) -> Dictionary:
	var clean: String = _strip_json_fence(text)
	var json: JSON = JSON.new()
	if json.parse(clean) != OK or not (json.data is Dictionary):
		var first_brace: int = clean.find("{")
		var last_brace: int = clean.rfind("}")
		if first_brace < 0 or last_brace <= first_brace:
			return {}
		var candidate: String = clean.substr(first_brace, last_brace - first_brace + 1)
		json = JSON.new()
		if json.parse(candidate) != OK or not (json.data is Dictionary):
			return {}
	return (json.data as Dictionary).duplicate(true)

func _strip_json_fence(text: String) -> String:
	var clean: String = text.strip_edges()
	if clean.begins_with("```"):
		var first_newline: int = clean.find("\n")
		if first_newline >= 0:
			clean = clean.substr(first_newline + 1)
		if clean.ends_with("```"):
			clean = clean.left(clean.length() - 3)
	return clean.strip_edges()

func _language_text(english: String, korean: String) -> String:
	return AppLanguageScript.text(english, korean)
