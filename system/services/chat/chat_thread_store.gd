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
	content: String
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

	messages.append({
		"role": role,
		"content": content,
		"created_at_unix": int(
			Time.get_unix_time_from_system()
		),
	})

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

	return directory.remove(
		file_name
	)

static func get_context_messages(
	thread_id: String,
	max_messages: int
) -> Array:

	var result: Array = []

	if max_messages <= 0:
		return result

	var thread: Dictionary = (
		load_thread(
			thread_id
		)
	)

	if thread.is_empty():
		return result

	var messages_value: Variant = (
		thread.get(
			"messages",
			[]
		)
	)

	if not (
		messages_value is Array
	):
		return result

	var messages: Array = (
		messages_value
	)

	var start_index: int = maxi(
		0,
		messages.size() - max_messages
	)

	for index: int in range(
		start_index,
		messages.size()
	):
		var value: Variant = (
			messages[index]
		)

		if not (
			value is Dictionary
		):
			continue

		var message: Dictionary = value

		var role: String = str(
			message.get(
				"role",
				""
			)
		)

		var content: String = str(
			message.get(
				"content",
				""
			)
		).strip_edges()

		if (
			role != "user"
			and role != "assistant"
		):
			continue

		if content.is_empty():
			continue

		result.append({
			"role": role,
			"content": content,
		})

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
