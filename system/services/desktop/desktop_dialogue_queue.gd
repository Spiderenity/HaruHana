extends Node
class_name DesktopDialogueQueue

signal changed(pending_count: int, active_kind: String)

var pending: Array[Dictionary] = []
var active: Dictionary = {}
var next_id: int = 1
var next_sequence: int = 1

func enqueue(
	kind: String,
	payload: Dictionary,
	priority: int,
	coalesce_key: String = "",
	replace_existing: bool = true
) -> int:
	var clean_kind: String = kind.strip_edges().to_lower()
	if clean_kind.is_empty():
		return 0

	var clean_key: String = coalesce_key.strip_edges().to_lower()
	if not clean_key.is_empty():
		var existing_index: int = _find_pending_coalesce_index(clean_key)
		if existing_index >= 0:
			var existing: Dictionary = pending[existing_index]
			if replace_existing:
				existing["kind"] = clean_kind
				existing["payload"] = payload.duplicate(true)
				existing["priority"] = priority
				pending[existing_index] = existing
				_emit_changed()
			return int(existing.get("id", 0))

	var event_id: int = next_id
	next_id += 1
	var event: Dictionary = {
		"id": event_id,
		"sequence": next_sequence,
		"kind": clean_kind,
		"payload": payload.duplicate(true),
		"priority": priority,
		"coalesce_key": clean_key,
	}
	next_sequence += 1
	pending.append(event)
	_emit_changed()
	return event_id

func take_next() -> Dictionary:
	if not active.is_empty() or pending.is_empty():
		return {}

	var best_index: int = 0
	for index: int in range(1, pending.size()):
		if _comes_before(pending[index], pending[best_index]):
			best_index = index

	active = pending[best_index].duplicate(true)
	pending.remove_at(best_index)
	_emit_changed()
	return active.duplicate(true)

func complete(event_id: int = 0) -> bool:
	if active.is_empty():
		return false
	if event_id > 0 and int(active.get("id", 0)) != event_id:
		return false
	active.clear()
	_emit_changed()
	return true

func clear_pending() -> void:
	pending.clear()
	_emit_changed()

func clear_all() -> void:
	pending.clear()
	active.clear()
	_emit_changed()

func is_active() -> bool:
	return not active.is_empty()

func get_active() -> Dictionary:
	return active.duplicate(true)

func get_active_id() -> int:
	return int(active.get("id", 0))

func get_active_kind() -> String:
	return str(active.get("kind", ""))

func has_pending() -> bool:
	return not pending.is_empty()

func has_coalesce_key(coalesce_key: String) -> bool:
	var clean_key: String = coalesce_key.strip_edges().to_lower()
	if clean_key.is_empty():
		return false
	if str(active.get("coalesce_key", "")) == clean_key:
		return true
	return _find_pending_coalesce_index(clean_key) >= 0

func pending_count() -> int:
	return pending.size()

func _find_pending_coalesce_index(coalesce_key: String) -> int:
	for index: int in range(pending.size()):
		if str(pending[index].get("coalesce_key", "")) == coalesce_key:
			return index
	return -1

func _comes_before(first: Dictionary, second: Dictionary) -> bool:
	var first_priority: int = int(first.get("priority", 0))
	var second_priority: int = int(second.get("priority", 0))
	if first_priority != second_priority:
		return first_priority > second_priority
	return int(first.get("sequence", 0)) < int(second.get("sequence", 0))

func _emit_changed() -> void:
	changed.emit(pending.size(), get_active_kind())
