extends RefCounted
class_name PackageSave

# Stage beside the destination so directory renames stay on the same filesystem.
static func begin(target: String) -> String:
	var absolute := ProjectSettings.globalize_path(target)
	var backup := absolute.get_base_dir().path_join("." + absolute.get_file() + ".previous")
	if not DirAccess.dir_exists_absolute(absolute) and DirAccess.dir_exists_absolute(backup):
		if DirAccess.rename_absolute(backup, absolute) != OK:
			return ""
	var stage := absolute.get_base_dir().path_join("." + absolute.get_file() + ".saving-" + str(OS.get_process_id()))
	if DirAccess.dir_exists_absolute(stage):
		return "" # Preserve an interrupted save for recovery rather than overwrite it.
	if DirAccess.make_dir_recursive_absolute(stage) != OK:
		return ""
	if DirAccess.dir_exists_absolute(absolute) and _copy_tree(absolute, stage) != OK:
		_remove_tree(stage)
		return ""
	return stage

static func commit(stage: String, target: String) -> Error:
	var absolute := ProjectSettings.globalize_path(target)
	if stage != absolute.get_base_dir().path_join("." + absolute.get_file() + ".saving-" + str(OS.get_process_id())):
		return ERR_INVALID_PARAMETER
	var backup := absolute.get_base_dir().path_join("." + absolute.get_file() + ".previous")
	# Retain only the previous successful package; don't expose backup packs in discovery.
	if DirAccess.dir_exists_absolute(backup):
		var cleanup := _remove_tree(backup)
		if cleanup != OK:
			return cleanup
	var had_original := DirAccess.dir_exists_absolute(absolute)
	if had_original:
		var move := DirAccess.rename_absolute(absolute, backup)
		if move != OK:
			return move
	var result := DirAccess.rename_absolute(stage, absolute)
	if result != OK and had_original:
		DirAccess.rename_absolute(backup, absolute)
	return result

static func discard(stage: String) -> void:
	if stage.ends_with(".saving-" + str(OS.get_process_id())):
		_remove_tree(stage)

static func _copy_tree(source: String, target: String) -> Error:
	var directory := DirAccess.open(source)
	if directory == null:
		return ERR_CANT_OPEN
	for name: String in DirAccess.get_files_at(source):
		if directory.is_link(name):
			return ERR_INVALID_DATA
		if name.ends_with(".tmp") or name.ends_with(".bak") or name.ends_with(".import"):
			continue
		var error := DirAccess.copy_absolute(source.path_join(name), target.path_join(name))
		if error != OK:
			return error
	for name: String in DirAccess.get_directories_at(source):
		if directory.is_link(name):
			return ERR_INVALID_DATA
		var child := target.path_join(name)
		var error := DirAccess.make_dir_recursive_absolute(child)
		if error != OK:
			return error
		error = _copy_tree(source.path_join(name), child)
		if error != OK:
			return error
	return OK

static func _remove_tree(path: String) -> Error:
	var directory := DirAccess.open(path)
	if directory == null:
		return ERR_CANT_OPEN
	for name: String in directory.get_files():
		var error := directory.remove(name)
		if error != OK:
			return error
	for name: String in directory.get_directories():
		if directory.is_link(name):
			return ERR_INVALID_DATA
		var error := _remove_tree(path.path_join(name))
		if error != OK:
			return error
	return DirAccess.remove_absolute(path)
