extends RefCounted
class_name CompanionMemoStore

const JsonStoreScript = preload(
	"res://system/services/runtime/json_store.gd"
)

const STORE_PATH: String = "user://memos/memos.json"
const LEGACY_PATH: String = "user://companion_memo.txt"
const SCHEMA_VERSION: int = 1

static func load_memos() -> Array[Dictionary]:
	var data: Dictionary = JsonStoreScript.load_dictionary(STORE_PATH, {})
	var result: Array[Dictionary] = []
	var values: Variant = data.get("memos", [])
	if values is Array:
		for value: Variant in values:
			if value is Dictionary:
				var memo: Dictionary = _normalize_memo(value as Dictionary)
				if not memo.is_empty():
					result.append(memo)
	if result.is_empty():
		var migrated: Dictionary = _load_legacy_memo()
		if not migrated.is_empty():
			result.append(migrated)
	if result.is_empty():
		result.append(create_memo("", ""))
	return result

static func save_memos(memos: Array[Dictionary]) -> Error:
	var normalized: Array[Dictionary] = []
	for memo: Dictionary in memos:
		var clean: Dictionary = _normalize_memo(memo)
		if not clean.is_empty():
			normalized.append(clean)
	return JsonStoreScript.save_json(
		STORE_PATH,
		{"schema_version": SCHEMA_VERSION, "memos": normalized}
	)

static func create_memo(title: String, body: String) -> Dictionary:
	var now: int = int(Time.get_unix_time_from_system())
	return {
		"id": "%d_%d" % [Time.get_ticks_usec(), randi()],
		"title": title.strip_edges().left(120),
		"body": body,
		"created_at": now,
		"updated_at": now,
		"pinned": false,
	}

static func _normalize_memo(source: Dictionary) -> Dictionary:
	var memo_id: String = str(source.get("id", "")).strip_edges()
	if memo_id.is_empty():
		return {}
	return {
		"id": memo_id,
		"title": str(source.get("title", "")).strip_edges().left(120),
		"body": str(source.get("body", "")),
		"created_at": int(source.get("created_at", 0)),
		"updated_at": int(source.get("updated_at", 0)),
		"pinned": bool(source.get("pinned", false)),
	}

static func _load_legacy_memo() -> Dictionary:
	if not FileAccess.file_exists(LEGACY_PATH):
		return {}
	var file: FileAccess = FileAccess.open(LEGACY_PATH, FileAccess.READ)
	if file == null:
		return {}
	var body: String = file.get_as_text()
	file.close()
	if body.strip_edges().is_empty():
		return {}
	return create_memo("이전 메모", body)
