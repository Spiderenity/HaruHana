extends RefCounted
class_name AtomicFile

# Keep the previous successful save. Temporary data is never exposed as the primary.
static func save_text(path: String, text: String, keep_backup: bool = true) -> Error:
	return save_bytes(path, text.to_utf8_buffer(), keep_backup)

static func save_bytes(path: String, bytes: PackedByteArray, keep_backup: bool = true) -> Error:
	var absolute := ProjectSettings.globalize_path(path)
	var error := DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if error != OK and error != ERR_ALREADY_EXISTS:
		return error
	var temporary := absolute + ".tmp"
	var backup := absolute + ".bak"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK or FileAccess.get_file_as_bytes(temporary) != bytes:
		DirAccess.remove_absolute(temporary)
		return ERR_FILE_CANT_WRITE
	var had_original := FileAccess.file_exists(absolute)
	if had_original:
		if FileAccess.file_exists(backup):
			error = DirAccess.remove_absolute(backup)
			if error != OK:
				return error
		error = DirAccess.rename_absolute(absolute, backup)
		if error != OK:
			return error
	error = DirAccess.rename_absolute(temporary, absolute)
	if error != OK:
		if had_original:
			DirAccess.rename_absolute(backup, absolute)
		return error
	if not keep_backup and FileAccess.file_exists(backup):
		DirAccess.remove_absolute(backup)
	return OK

static func load_text(path: String) -> String:
	if FileAccess.file_exists(path):
		return FileAccess.get_file_as_string(path)
	return FileAccess.get_file_as_string(path + ".bak") if FileAccess.file_exists(path + ".bak") else ""
