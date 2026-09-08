extends RefCounted
class_name ChatThreadStore

const THREAD_FOLDER: String = (
	"user://chats/threads"
)

const MAX_STORED_MESSAGES: int = 200

static func ensure_thread_folder() -> Error:
	var absolute_folder: String = (
		ProjectSettings.globalize_path(
			THREAD_FOLDER
		)
	)

	var error: Error = (
		DirAccess.make_dir_recursive_absolute(
			absolute_folder
		)
	)

	if error == ERR_ALREADY_EXISTS:
		return OK

	return error

static func list_threads(
	pack_id: String
) -> Array:

	var result: Array = []

	var ensure_error: Error = (
		ensure_thread_folder()
	)

	if ensure_error != OK:
		return result

	var directory: DirAccess = DirAccess.open(
		THREAD_FOLDER
	)

	if directory == null:
		return result

	var file_names: Array[String] = []

	directory.list_dir_begin()

	while true:
		var file_name: String = (
			directory.get_next()
		)

		if file_name.is_empty():
			break

		if directory.current_is_dir():
			continue

		if not file_name.ends_with(
			".json"
		):
			continue

		file_names.append(
			file_name
		)

	directory.list_dir_end()

	for file_name: String in file_names:
		var path: String = (
			THREAD_FOLDER.path_join(
				file_name
			)
		)

		var thread: Dictionary = (
			_load_dictionary(
				path
			)
		)

		if thread.is_empty():
			continue

		if str(
			thread.get(
				"pack_id",
				""
			)
		) != pack_id:
			continue

		result.append(
			thread
		)

	_sort_threads(
		result
	)

	return result

static func create_thread(
	pack_id: String,
	character_id: String,
	title: String = "New chat"
) -> Dictionary:

	pack_id = pack_id.strip_edges()

	character_id = (
		character_id
			.strip_edges()
			.to_lower()
	)

	title = title.strip_edges()

	if (
		pack_id.is_empty()
		or character_id.is_empty()
	):
		return {}

	if title.is_empty():
		title = "New chat"

	var ensure_error: Error = (
		ensure_thread_folder()
	)

	if ensure_error != OK:
		return {}

	var thread_id: String = (
		_generate_thread_id()
	)

	var now: int = int(
		Time.get_unix_time_from_system()
	)

	var thread: Dictionary = {
		"id": thread_id,
		"pack_id": pack_id,
		"character_id": character_id,
		"title": title,
		"created_at_unix": now,
		"updated_at_unix": now,
		"messages": [],
	}

	var save_error: Error = (
		_save_thread(
			thread
		)
	)

	if save_error != OK:
		return {}

	return thread

static func load_thread(
	thread_id: String
) -> Dictionary:

	thread_id = thread_id.strip_edges()

	if thread_id.is_empty():
		return {}

	var path: String = (
		THREAD_FOLDER.path_join(
			thread_id + ".json"
		)
	)

	return _load_dictionary(
		path
	)

static func append_message(
	thread_id: String,
	role: String,
	content: String,
	character_id: String = ""
) -> Error:

	role = role.strip_edges()

	content = content.strip_edges()

	if (
		role != "user"
		and role != "assistant"
	):
		return ERR_INVALID_PARAMETER

	if content.is_empty():
		return ERR_INVALID_PARAMETER

	var thread: Dictionary = (
		load_thread(
			thread_id
		)
	)

	if thread.is_empty():
		return ERR_FILE_NOT_FOUND

	var messages_value: Variant = (
		thread.get(
			"messages",
			[]
		)
	)

	var messages: Array = []

	if messages_value is Array:
		messages = messages_value

	var message: Dictionary = {
		"role": role,
		"content": content,
		"created_at_unix": int(
			Time.get_unix_time_from_system()
		),
	}
	character_id = character_id.strip_edges().to_lower()
	if role == "assistant" and not character_id.is_empty():
		message["character_id"] = character_id
	messages.append(message)

	while messages.size() > (
		MAX_STORED_MESSAGES
	):
		messages.pop_front()

	thread["messages"] = messages
	thread["updated_at_unix"] = int(
		Time.get_unix_time_from_system()
	)

	return _save_thread(
		thread
	)

static func set_title(
	thread_id: String,
	title: String
) -> Error:

	title = title.strip_edges()

	if title.is_empty():
		return ERR_INVALID_PARAMETER

	var thread: Dictionary = (
		load_thread(
			thread_id
		)
	)

	if thread.is_empty():
		return ERR_FILE_NOT_FOUND

	thread["title"] = title
	thread["updated_at_unix"] = int(
		Time.get_unix_time_from_system()
	)

	return _save_thread(
		thread
	)

static func delete_thread(
	thread_id: String
) -> Error:

	thread_id = thread_id.strip_edges()

	if thread_id.is_empty():
		return ERR_INVALID_PARAMETER

	var directory: DirAccess = DirAccess.open(
		THREAD_FOLDER
	)

	if directory == null:
		return ERR_CANT_OPEN

	var file_name: String = (
		thread_id + ".json"
	)

	if not FileAccess.file_exists(
		THREAD_FOLDER.path_join(
			file_name
		)
	):
		return ERR_FILE_NOT_FOUND

	# Deleted threads must not be resurrected from their recovery copy.
	for suffix: String in [".bak", ".corrupt", ".tmp"]:
		if directory.file_exists(file_name + suffix):
			var error := directory.remove(file_name + suffix)
			if error != OK:
				return error
	return directory.remove(file_name)

static func get_context_messages(thread_id: String, max_messages: int) -> Array:
	var source: Variant = load_thread(thread_id).get("messages", [])
	if not source is Array or max_messages <= 0:
		return []
	var result: Array = []
	var used := 0
	# Keep recent context within a character budget, independently of the 200-message archive.
	for index: int in range(source.size() - 1, -1, -1):
		var item: Variant = source[index]
		if not item is Dictionary:
			continue
		var role := str(item.get("role", ""))
		if role not in ["user", "assistant"]:
			continue
		var content := str(item.get("content", "")).strip_edges()
		if role == "assistant":
			content = DialogueOutput.saved_reply(content)
		if content.is_empty():
			continue
		# Never silently truncate the newest user message. The UI validates its limit before saving.
		if used + content.length() > 6000 or result.size() >= mini(max_messages, 12):
			break
		if role == "assistant":
			content = JSON.stringify({"speaker": str(item.get("character_id", "")), "reply": content})
		used += content.length()
		result.push_front({"role": role, "content": content})
	return result

static func get_message_count(
	thread_id: String
) -> int:

	var thread: Dictionary = (
		load_thread(
			thread_id
		)
	)

	if thread.is_empty():
		return 0

	var messages_value: Variant = (
		thread.get(
			"messages",
			[]
		)
	)

	if not (
		messages_value is Array
	):
		return 0

	var messages: Array = (
		messages_value
	)

	return messages.size()

static func _save_thread(
	thread: Dictionary
) -> Error:
	var thread_id: String = str(thread.get("id", "")).strip_edges()
	if thread_id.is_empty():
		return ERR_INVALID_DATA
	var ensure_error: Error = ensure_thread_folder()
	if ensure_error != OK:
		return ensure_error
	var path: String = THREAD_FOLDER.path_join(thread_id + ".json")
	return JsonStore.save_json(path, thread)

static func _load_dictionary(
	path: String
) -> Dictionary:
	return JsonStore.load_dictionary(path, {})

static func _generate_thread_id() -> String:
	var now: int = int(
		Time.get_unix_time_from_system()
	)

	var random_part: int = (
		randi() & 0x7fffffff
	)

	return (
		"chat_"
		+ str(now)
		+ "_"
		+ str(random_part)
	)

static func _sort_threads(
	threads: Array
) -> void:

	for index: int in range(
		1,
		threads.size()
	):
		var current_value: Variant = (
			threads[index]
		)

		if not (
			current_value is Dictionary
		):
			continue

		var current: Dictionary = (
			current_value
		)

		var current_updated: int = int(
			current.get(
				"updated_at_unix",
				0
			)
		)

		var position: int = index - 1

		while position >= 0:
			var previous_value: Variant = (
				threads[position]
			)

			if not (
				previous_value is Dictionary
			):
				break

			var previous: Dictionary = (
				previous_value
			)

			var previous_updated: int = int(
				previous.get(
					"updated_at_unix",
					0
				)
			)

			if previous_updated >= current_updated:
				break

			threads[position + 1] = (
				threads[position]
			)

			position -= 1

		threads[position + 1] = current
