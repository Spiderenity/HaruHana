extends RefCounted
class_name DialogueMemory

const MEMORY_PATH := (
	"user://memory/dialogue_memory.json"
)

const MEMORY_FOLDER := (
	"user://memory"
)

const MAX_MEMORIES := 40

const MAX_MEMORY_LENGTH := 240

static func ensure_store() -> Error:
	var absolute_folder: String = (
		ProjectSettings.globalize_path(
			MEMORY_FOLDER
		)
	)

	var folder_error: Error = (
		DirAccess.make_dir_recursive_absolute(
			absolute_folder
		)
	)

	if (
		folder_error != OK
		and folder_error
			!= ERR_ALREADY_EXISTS
	):
		return folder_error

	if not FileAccess.file_exists(
		MEMORY_PATH
	):
		return _save_memories(
			[]
		)

	return OK

static func load_memories() -> Array:
	var ensure_error: Error = ensure_store()
	if ensure_error != OK:
		push_error("Could not initialize dialogue memory store.")
		return []
	var data: Dictionary = JsonStore.load_dictionary(MEMORY_PATH, {})
	var memories: Variant = data.get("memories", [])
	if not (memories is Array):
		return []
	return (memories as Array).duplicate(true)

static func add_memories(
	new_entries: Array,
	source_character: String
) -> int:

	if new_entries.is_empty():
		return 0

	var memories: Array = (
		load_memories()
	)

	var existing_texts: Dictionary = {}

	for item: Variant in memories:
		if not (
			item is Dictionary
		):
			continue

		var existing_text := str(
			item.get(
				"text",
				""
			)
		)

		existing_texts[
			existing_text.to_lower()
		] = true

	var added: int = 0

	for entry: Variant in new_entries:
		if added >= 2:
			break

		var text: String = (
			_extract_memory_text(
				entry
			)
		)

		text = _clean_memory_text(
			text
		)

		if text.is_empty():
			continue

		var duplicate_key := (
			text.to_lower()
		)

		if existing_texts.has(
			duplicate_key
		):
			continue

		var timestamp: int = int(
			Time.get_unix_time_from_system()
		)

		var memory := {
			"id": (
				str(timestamp)
				+ "-"
				+ str(randi())
			),

			"text": text,

			"source_character": (
				source_character
			),

			"created_at_unix": timestamp,
		}

		memories.append(
			memory
		)

		existing_texts[
			duplicate_key
		] = true

		added += 1

	while (
		memories.size()
		> MAX_MEMORIES
	):
		memories.pop_front()

	var save_error: Error = (
		_save_memories(
			memories
		)
	)

	if save_error != OK:
		push_error(
			"Could not save dialogue memory."
		)

		return 0

	return added

static func clear_all() -> Error:
	return _save_memories(
		[]
	)

static func get_memory_count() -> int:
	return load_memories().size()

static func build_prompt_block(
	max_items: int = 20
) -> String:

	var memories: Array = (
		load_memories()
	)

	if memories.is_empty():
		return ""

	max_items = maxi(
		1,
		max_items
	)

	var start_index: int = maxi(
		0,
		memories.size()
			- max_items
	)

	var lines: Array[String] = []

	for index: int in range(
		start_index,
		memories.size()
	):
		var memory: Variant = (
			memories[index]
		)

		if not (
			memory is Dictionary
		):
			continue

		var text := str(
			memory.get(
				"text",
				""
			)
		).strip_edges()

		if text.is_empty():
			continue

		var source := str(
			memory.get(
				"source_character",
				""
			)
		).strip_edges()

		if source.is_empty():
			lines.append(
				"- " + text
			)

		else:
			lines.append(
				"- [Remembered via "
				+ source.capitalize()
				+ "] "
				+ text
			)

	return "\n".join(
		lines
	)

static func get_memory_file_display_path() -> String:
	return ProjectSettings.globalize_path(
		MEMORY_PATH
	)

static func _save_memories(
	memories: Array
) -> Error:
	return JsonStore.save_json(
		MEMORY_PATH,
		{
			"schema_version": 1,
			"memories": memories,
		}
	)

static func _extract_memory_text(
	entry: Variant
) -> String:

	if entry is String:
		return entry

	if entry is Dictionary:
		return str(
			entry.get(
				"text",
				""
			)
		)

	return ""

static func _clean_memory_text(
	text: String
) -> String:

	text = text.replace(
		"\n",
		" "
	)

	text = text.replace(
		"\r",
		" "
	)

	text = text.strip_edges()

	while text.contains(
		"  "
	):
		text = text.replace(
			"  ",
			" "
		)

	if (
		text.length()
		> MAX_MEMORY_LENGTH
	):
		text = (
			text.left(
				MAX_MEMORY_LENGTH - 3
			)
			+ "..."
		)

	return text
