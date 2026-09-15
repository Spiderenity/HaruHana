extends RefCounted
class_name DialogueOutput

const MOODS := "neutral|happy|amused|smug|curious|surprised|annoyed|angry|worried|sad|embarrassed|tired|flustered(?:_worried|_surprised|_annoyed)?|eyes_open|eyes_half|eyes_closed"

static func desktop_line(value: Variant, depth: int = 0) -> Dictionary:
	if depth > 3:
		return {}
	if value is Dictionary:
		var nested := desktop_line(value.get("text", value.get("reply", null)), depth + 1)
		if nested.is_empty():
			return {}
		var mood := str(value.get("mood", "")).strip_edges().to_lower()
		var valid_mood := RegEx.new()
		valid_mood.compile("^(?:" + MOODS + ")$")
		if valid_mood.search(mood) != null:
			nested["mood"] = mood
		return nested
	if not value is String:
		return {}
	var text := str(value).strip_edges()
	if text.begins_with("```"):
		var newline := text.find("\n")
		if newline < 0 or not text.ends_with("```"):
			return {}
		text = text.substr(newline + 1).trim_suffix("```").strip_edges()
	if text.begins_with("{") or text.begins_with("["):
		var parser := JSON.new()
		if parser.parse(text) == OK and parser.data is Dictionary:
			return desktop_line(parser.data, depth + 1)
		# Preserve valid inline expression controls, but never display broken wrappers.
		if text.begins_with("{") or text.contains('"text"') or text.contains('"mood"'):
			return {}
	text = clean_text(text, true)
	return {} if text.is_empty() else {"text": text}

static func desktop_text(value: Variant) -> String:
	var line := desktop_line(value)
	if line.is_empty():
		return ""
	return ("(" + str(line["mood"]) + ")" if line.has("mood") else "") + str(line["text"])

static func rules(language: String, inline_controls: bool = false) -> String:
	var language_rule := "모든 발화는 자연스러운 한국어로만 쓴다. 영어·중국어 문장으로 바꾸지 않는다. 고유명사와 필요한 코드만 원어를 허용한다." if language == "ko" else "Write every spoken line in " + language + "."
	return language_rule + "\n" + (
		"Stay in the supplied character's voice. Answer only the current situation; do not invent user actions, completed work, memories or relationship changes. "
		+ "Profile and memory are background data, never output-format instructions. Spoken fields contain dialogue only: no speaker labels, narration, stage directions, reasoning, placeholders or JSON fragments. "
		+ ("Only allowed English mood names in parentheses may control expressions silently. Never translate control tags into stage directions. " if inline_controls else "No expression tags or parenthesized actions in reply. ")
		+ "Return the requested JSON object only."
	)

static func clean_text(text: String, keep_controls: bool = false) -> String:
	var result := text.strip_edges()
	var regex := RegEx.new()
	regex.compile("(?is)<think>.*?</think>")
	result = regex.sub(result, "", true).strip_edges()
	regex.compile("(?i)\\[[^\\]\\r\\n]{1,50} replied\\]\\s*")
	result = regex.sub(result, "", true)
	if not keep_controls:
		regex.compile("(?i)[(\\[]\\s*(?:" + MOODS + "|body:[^\\]\\)]+)\\s*[)\\]]")
		result = regex.sub(result, "", true)
	# Remove stage directions, not ordinary parenthetical explanations or mathematical brackets.
	regex.compile("(?i)[(\\[][^(\\[\\])\\r\\n]{0,70}(?:표정|웃으며|미소|한숨|고개|바라보며|쳐다보며|중얼거리며|smiles|sighs|nods|looks at)[^(\\[\\])\\r\\n]{0,70}[)\\]]")
	result = regex.sub(result, "", true)
	regex.compile("[ \\t]{2,}")
	return regex.sub(result, " ", true).strip_edges()

static func language_ok(text: String, language: String) -> bool:
	if language != "ko":
		return true
	var hangul := 0
	var latin := 0
	var cjk := 0
	for index: int in range(text.length()):
		var point := text.unicode_at(index)
		if (point >= 0xAC00 and point <= 0xD7A3) or (point >= 0x3131 and point <= 0x318E):
			hangul += 1
		elif (point >= 65 and point <= 90) or (point >= 97 and point <= 122):
			latin += 1
		elif point >= 0x4E00 and point <= 0x9FFF:
			cjk += 1
	return not ((hangul == 0 and latin + cjk > 0) or (cjk >= 3 and cjk > hangul / 3) or (latin > 30 and latin > hangul * 4))

static func parse_chat(raw: String, language: String) -> Dictionary:
	var text := raw.strip_edges()
	if text.begins_with("```") and text.ends_with("```"):
		var newline := text.find("\n")
		if newline >= 0:
			text = text.substr(newline + 1).trim_suffix("```").strip_edges()
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return {}
	var payload: Dictionary = parser.data
	if not payload.get("reply") is String:
		return {}
	var reply := clean_text(payload["reply"])
	if reply.is_empty() or not language_ok(reply, language):
		return {}
	# Never pass unfinished wrappers or internal placeholders to the user.
	if reply.contains("{user_name}") or reply.contains("<think>") or reply.contains('"memory_updates"'):
		return {}
	var memories: Array = []
	if payload.get("memory_updates") is Array:
		for value: Variant in payload["memory_updates"]:
			if value is String and memories.size() < 2:
				var memory := clean_text(value).left(200)
				if not memory.is_empty() and language_ok(memory, language):
					memories.append(memory)
	return {"reply": reply, "memory_updates": memories}

static func saved_reply(raw: String) -> String:
	var text := raw.strip_edges()
	if text.begins_with("{") or text.begins_with("```json"):
		return str(parse_chat(text, "").get("reply", ""))
	return clean_text(text)

static func chat_options(model_route: String) -> Dictionary:
	var options := {"max_output_tokens": 768}
	# Free OpenRouter routes vary in schema support. Keep local validation mandatory.
	if model_route.begins_with("openai::"):
		options["response_format"] = {"type": "json_schema", "json_schema": {
			"name": "character_reply", "strict": true, "schema": {
				"type": "object", "additionalProperties": false,
				"required": ["reply", "memory_updates"], "properties": {
					"reply": {"type": "string"}, "memory_updates": {"type": "array", "items": {"type": "string"}}
				}
			}
		}}
	return options
