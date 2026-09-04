extends Node
class_name AIClient

signal response_received(raw_text: String)
signal request_failed(message: String)

var request_in_progress: bool = false

var _http_request: HTTPRequest = null
var _active_provider: String = ""
var _active_model: String = ""

func _ready() -> void:
	_ensure_http_request()

func _ensure_http_request() -> void:
	if _http_request != null and is_instance_valid(_http_request):
		return

	_http_request = HTTPRequest.new()
	_http_request.timeout = 120.0
	add_child(_http_request)
	_http_request.request_completed.connect(_on_request_completed)

func send_messages(
	api_key: String,
	model_route: String,
	messages: Array,
	request_options: Dictionary = {}
) -> bool:
	if request_in_progress:
		return false

	api_key = api_key.strip_edges()
	model_route = model_route.strip_edges()

	if api_key.is_empty():
		request_failed.emit("API key is empty.")
		return false

	var route: Dictionary = _parse_model_route(model_route)

	if route.is_empty():
		request_failed.emit(
			"AI model route must use provider::model."
		)
		return false

	_active_provider = str(route.get("provider", ""))
	_active_model = str(route.get("model", "")).strip_edges()

	_ensure_http_request()

	var request_info: Dictionary = _build_request(
		_active_provider,
		_active_model,
		api_key,
		messages,
		request_options
	)

	if request_info.is_empty():
		request_failed.emit("Unsupported AI provider: " + _active_provider)
		return false

	var url: String = str(request_info.get("url", ""))
	var headers_value: Variant = request_info.get("headers", PackedStringArray())
	var headers: PackedStringArray = PackedStringArray()

	if headers_value is PackedStringArray:
		headers = headers_value
	elif headers_value is Array:
		for value: Variant in headers_value:
			headers.append(str(value))

	var body_value: Variant = request_info.get("body", {})
	var body_text: String = JSON.stringify(body_value)

	request_in_progress = true
	var error: Error = _http_request.request(
		url,
		headers,
		HTTPClient.METHOD_POST,
		body_text
	)

	if error != OK:
		request_in_progress = false
		request_failed.emit(
			"Could not start AI request. Error: " + str(error)
		)
		return false

	return true

func cancel_current_request() -> void:
	if (
		_http_request != null
		and is_instance_valid(_http_request)
		and request_in_progress
	):
		_http_request.cancel_request()

	request_in_progress = false
	_active_provider = ""
	_active_model = ""

func _parse_model_route(model_route: String) -> Dictionary:
	model_route = model_route.strip_edges()
	var split_at: int = model_route.find("::")

	if split_at <= 0:
		return {}

	var provider: String = (
		model_route.substr(0, split_at).strip_edges().to_lower()
	)
	var model: String = (
		model_route.substr(split_at + 2).strip_edges()
	)

	if provider.is_empty() or model.is_empty():
		return {}

	return {
		"provider": provider,
		"model": model
	}

func _build_request(
	provider: String,
	model: String,
	api_key: String,
	messages: Array,
	request_options: Dictionary
) -> Dictionary:
	match provider:
		"openai":
			return _build_openai_request(model, api_key, messages, request_options)
		"anthropic":
			return _build_anthropic_request(model, api_key, messages)
		"google", "gemini":
			return _build_google_request(model, api_key, messages)
		"deepseek":
			return _build_openai_compatible_request(
				"https://api.deepseek.com/chat/completions",
				model,
				api_key,
				messages,
				{},
				false
			)
		"openrouter":
			return _build_openai_compatible_request(
				"https://openrouter.ai/api/v1/chat/completions",
				model,
				api_key,
				messages,
				request_options,
				true
			)
		_:
			return {}

func _build_openai_request(
	model: String,
	api_key: String,
	messages: Array,
	request_options: Dictionary
) -> Dictionary:
	var input_messages: Array[Dictionary] = []

	for value: Variant in messages:
		if not (value is Dictionary):
			continue

		var message: Dictionary = value
		var role: String = str(message.get("role", "user")).to_lower()
		var content: String = _content_to_text(message.get("content", ""))

		if content.is_empty():
			continue

		if role == "developer":
			role = "system"
		if not ["system", "user", "assistant"].has(role):
			role = "user"

		input_messages.append({
			"role": role,
			"content": content
		})

	var body: Dictionary = {
		"model": model,
		"input": input_messages
	}

	_apply_openai_request_options(
		body,
		request_options
	)

	return {
		"url": "https://api.openai.com/v1/responses",
		"headers": PackedStringArray([
			"Content-Type: application/json",
			"Authorization: Bearer " + api_key
		]),
		"body": body
	}

func _build_openai_compatible_request(
	url: String,
	model: String,
	api_key: String,
	messages: Array,
	request_options: Dictionary,
	allow_plugins: bool
) -> Dictionary:
	var body: Dictionary = {
		"model": model,
		"messages": _normalized_chat_messages(messages),
		"stream": false
	}

	_apply_chat_request_options(
		body,
		request_options,
		allow_plugins
	)

	return {
		"url": url,
		"headers": PackedStringArray([
			"Content-Type: application/json",
			"Authorization: Bearer " + api_key
		]),
		"body": body
	}

func _apply_openai_request_options(
	body: Dictionary,
	request_options: Dictionary
) -> void:
	var response_format_value: Variant = request_options.get(
		"response_format",
		null
	)

	if not (response_format_value is Dictionary):
		return

	var response_format: Dictionary = response_format_value
	var format_type: String = str(
		response_format.get("type", "")
	).strip_edges()

	if format_type == "json_object":
		body["text"] = {
			"format": {
				"type": "json_object"
			}
		}
		return

	if format_type != "json_schema":
		return

	var schema_value: Variant = response_format.get(
		"json_schema",
		null
	)

	if not (schema_value is Dictionary):
		return

	var schema_config: Dictionary = schema_value
	var schema: Variant = schema_config.get("schema", null)
	var schema_name: String = str(
		schema_config.get("name", "")
	).strip_edges()

	if schema_name.is_empty() or not (schema is Dictionary):
		return

	var format: Dictionary = {
		"type": "json_schema",
		"name": schema_name,
		"schema": (schema as Dictionary).duplicate(true),
		"strict": bool(schema_config.get("strict", false))
	}

	var description: String = str(
		schema_config.get("description", "")
	).strip_edges()

	if not description.is_empty():
		format["description"] = description

	body["text"] = {
		"format": format
	}

func _apply_chat_request_options(
	body: Dictionary,
	request_options: Dictionary,
	allow_plugins: bool
) -> void:
	var response_format_value: Variant = request_options.get(
		"response_format",
		null
	)

	if response_format_value is Dictionary:
		body["response_format"] = (
			response_format_value as Dictionary
		).duplicate(true)

	if not allow_plugins:
		return

	var plugins_value: Variant = request_options.get(
		"plugins",
		null
	)

	if plugins_value is Array:
		body["plugins"] = (
			plugins_value as Array
		).duplicate(true)

func _build_anthropic_request(
	model: String,
	api_key: String,
	messages: Array
) -> Dictionary:
	var system_parts: Array[String] = []
	var chat_messages: Array[Dictionary] = []

	for value: Variant in messages:
		if not (value is Dictionary):
			continue

		var message: Dictionary = value
		var role: String = str(message.get("role", "user")).to_lower()
		var content: String = _content_to_text(message.get("content", ""))
		if content.is_empty():
			continue

		if ["system", "developer"].has(role):
			system_parts.append(content)
			continue

		if role != "assistant":
			role = "user"

		chat_messages.append({
			"role": role,
			"content": content
		})

	var body: Dictionary = {
		"model": model,
		"max_tokens": 4096,
		"messages": chat_messages,
		"stream": false
	}

	if not system_parts.is_empty():
		body["system"] = _join_strings(system_parts, "\n\n")

	return {
		"url": "https://api.anthropic.com/v1/messages",
		"headers": PackedStringArray([
			"Content-Type: application/json",
			"x-api-key: " + api_key,
			"anthropic-version: 2023-06-01"
		]),
		"body": body
	}

func _build_google_request(
	model: String,
	api_key: String,
	messages: Array
) -> Dictionary:
	var system_parts: Array[String] = []
	var contents: Array[Dictionary] = []

	for value: Variant in messages:
		if not (value is Dictionary):
			continue

		var message: Dictionary = value
		var role: String = str(message.get("role", "user")).to_lower()
		var content: String = _content_to_text(message.get("content", ""))
		if content.is_empty():
			continue

		if ["system", "developer"].has(role):
			system_parts.append(content)
			continue

		contents.append({
			"role": "model" if role == "assistant" else "user",
			"parts": [{"text": content}]
		})

	var body: Dictionary = {
		"contents": contents
	}

	if not system_parts.is_empty():
		body["systemInstruction"] = {
			"parts": [{
				"text": _join_strings(system_parts, "\n\n")
			}]
		}

	return {
		"url": (
			"https://generativelanguage.googleapis.com/v1beta/models/"
			+ model.uri_encode()
			+ ":generateContent"
		),
		"headers": PackedStringArray([
			"Content-Type: application/json",
			"x-goog-api-key: " + api_key
		]),
		"body": body
	}

func _normalized_chat_messages(messages: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for value: Variant in messages:
		if not (value is Dictionary):
			continue

		var message: Dictionary = value
		var role: String = str(message.get("role", "user")).to_lower()
		if role == "developer":
			role = "system"
		if not ["system", "user", "assistant"].has(role):
			role = "user"

		var content: String = _content_to_text(message.get("content", ""))
		if content.is_empty():
			continue

		result.append({
			"role": role,
			"content": content
		})

	return result

func _content_to_text(content: Variant) -> String:
	if content is String:
		return str(content)

	if content is Array:
		var pieces: Array[String] = []
		for part_value: Variant in content:
			if part_value is Dictionary:
				var part: Dictionary = part_value
				var text: String = str(part.get("text", ""))
				if not text.is_empty():
					pieces.append(text)
			else:
				var plain: String = str(part_value)
				if not plain.is_empty():
					pieces.append(plain)
		return _join_strings(pieces, "\n")

	return str(content)

func _join_strings(parts: Array[String], separator: String) -> String:
	var packed: PackedStringArray = PackedStringArray()
	for part: String in parts:
		packed.append(part)
	return separator.join(packed)

func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	request_in_progress = false

	var raw_text: String = body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(raw_text)

	if result != HTTPRequest.RESULT_SUCCESS:
		request_failed.emit(
			"AI network request failed. Result: " + str(result)
		)
		return

	if response_code < 200 or response_code >= 300:
		request_failed.emit(_extract_error_message(parsed, response_code, raw_text))
		return

	if not (parsed is Dictionary):
		request_failed.emit("AI provider returned an invalid JSON response.")
		return

	var data: Dictionary = parsed
	var answer: String = ""

	match _active_provider:
		"openai":
			answer = _extract_openai_response_text(data)
		"anthropic":
			answer = _extract_anthropic_text(data)
		"google", "gemini":
			answer = _extract_google_text(data)
		"deepseek", "openrouter":
			answer = _extract_chat_completion_text(data)

	answer = answer.strip_edges()
	if answer.is_empty():
		request_failed.emit(
			"The AI provider returned no text for model " + _active_model + "."
		)
		return

	response_received.emit(answer)

func _extract_openai_response_text(data: Dictionary) -> String:
	var output_value: Variant = data.get("output", [])
	if not (output_value is Array):
		return ""

	var pieces: Array[String] = []
	for item_value: Variant in output_value:
		if not (item_value is Dictionary):
			continue
		var item: Dictionary = item_value
		var content_value: Variant = item.get("content", [])
		if not (content_value is Array):
			continue
		for part_value: Variant in content_value:
			if not (part_value is Dictionary):
				continue
			var part: Dictionary = part_value
			if ["output_text", "text"].has(str(part.get("type", ""))):
				var text: String = str(part.get("text", ""))
				if not text.is_empty():
					pieces.append(text)

	return _join_strings(pieces, "\n")

func _extract_chat_completion_text(data: Dictionary) -> String:
	var choices_value: Variant = data.get("choices", [])
	if not (choices_value is Array) or choices_value.is_empty():
		return ""

	var first_value: Variant = choices_value[0]
	if not (first_value is Dictionary):
		return ""

	var message_value: Variant = (first_value as Dictionary).get("message", {})
	if not (message_value is Dictionary):
		return ""

	return _content_to_text((message_value as Dictionary).get("content", ""))

func _extract_anthropic_text(data: Dictionary) -> String:
	var content_value: Variant = data.get("content", [])
	if not (content_value is Array):
		return ""

	var pieces: Array[String] = []
	for block_value: Variant in content_value:
		if not (block_value is Dictionary):
			continue
		var block: Dictionary = block_value
		if str(block.get("type", "")) != "text":
			continue
		var text: String = str(block.get("text", ""))
		if not text.is_empty():
			pieces.append(text)

	return _join_strings(pieces, "\n")

func _extract_google_text(data: Dictionary) -> String:
	var candidates_value: Variant = data.get("candidates", [])
	if not (candidates_value is Array) or candidates_value.is_empty():
		return ""

	var first_value: Variant = candidates_value[0]
	if not (first_value is Dictionary):
		return ""

	var content_value: Variant = (first_value as Dictionary).get("content", {})
	if not (content_value is Dictionary):
		return ""

	var parts_value: Variant = (content_value as Dictionary).get("parts", [])
	if not (parts_value is Array):
		return ""

	var pieces: Array[String] = []
	for part_value: Variant in parts_value:
		if not (part_value is Dictionary):
			continue
		var text: String = str((part_value as Dictionary).get("text", ""))
		if not text.is_empty():
			pieces.append(text)

	return _join_strings(pieces, "\n")

func _extract_error_message(
	parsed: Variant,
	response_code: int,
	raw_text: String
) -> String:
	if parsed is Dictionary:
		var data: Dictionary = parsed
		var error_value: Variant = data.get("error", null)

		if error_value is Dictionary:
			var message: String = str((error_value as Dictionary).get("message", ""))
			if not message.is_empty():
				return "AI request failed (HTTP %d): %s" % [response_code, message]

		if error_value is String and not str(error_value).is_empty():
			return "AI request failed (HTTP %d): %s" % [response_code, str(error_value)]

		var direct_message: String = str(data.get("message", ""))
		if not direct_message.is_empty():
			return "AI request failed (HTTP %d): %s" % [response_code, direct_message]

	var compact: String = raw_text.strip_edges()
	if compact.length() > 320:
		compact = compact.substr(0, 320) + "..."
	if compact.is_empty():
		compact = "No error body returned."

	return "AI request failed (HTTP %d): %s" % [response_code, compact]
