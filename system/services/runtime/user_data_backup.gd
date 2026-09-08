extends RefCounted
class_name UserDataBackup

static func export_zip(destination: String) -> Error:
	var temporary := destination + ".tmp"
	var zip := ZIPPacker.new()
	var error := zip.open(temporary)
	if error != OK:
		return error
	error = _add_directory(zip, "user://", "")
	var close_error := zip.close()
	if error == OK:
		error = close_error
	if error != OK:
		DirAccess.remove_absolute(temporary)
		return error
	# FileDialog asks before replacing an existing export. Retain its previous copy too.
	if FileAccess.file_exists(destination):
		var previous := destination + ".bak"
		if FileAccess.file_exists(previous):
			DirAccess.remove_absolute(previous)
		error = DirAccess.rename_absolute(destination, previous)
		if error != OK:
			return error
	error = DirAccess.rename_absolute(temporary, destination)
	if error != OK and FileAccess.file_exists(destination + ".bak"):
		DirAccess.rename_absolute(destination + ".bak", destination)
	return error

static func _add_directory(zip: ZIPPacker, root: String, relative: String) -> Error:
	for name: String in DirAccess.get_files_at(root):
		var entry := relative.path_join(name) if not relative.is_empty() else name
		if name.ends_with(".tmp") or name.ends_with(".log") or entry.begins_with("settings/ai.json"):
			continue
		var file := FileAccess.open(root.path_join(name), FileAccess.READ)
		if file == null:
			return ERR_FILE_CANT_READ
		var bytes := file.get_buffer(file.get_length())
		file.close()
		var error := zip.start_file(entry)
		if error == OK:
			error = zip.write_file(bytes)
		if error == OK:
			error = zip.close_file()
		if error != OK:
			return error
	for name: String in DirAccess.get_directories_at(root):
		if name.begins_with(".") or name.begins_with("runtime_instance") or name in ["updates", "logs", "shader_cache"]:
			continue
		var directory := DirAccess.open(root)
		if directory == null or directory.is_link(name):
			continue
		var child := relative.path_join(name) if not relative.is_empty() else name
		var error := _add_directory(zip, root.path_join(name), child)
		if error != OK:
			return error
	return OK
