extends RefCounted
class_name BundledAssets

static func restore_missing_defaults() -> void:
	if OS.has_feature("editor"):
		return
	restore_tree("res://characters/crt_chip", DistributionPaths.get_characters_directory().path_join("crt_chip"))
	restore_tree("res://assets/bubbles/default", DistributionPaths.get_bubbles_directory().path_join("default"))

static func restore_tree(source: String, destination: String) -> void:
	var directory := DirAccess.open(source)
	if directory == null:
		return
	if DirAccess.make_dir_recursive_absolute(destination) != OK:
		return
	for folder: String in directory.get_directories():
		if not folder.begins_with("."):
			restore_tree(source.path_join(folder), destination.path_join(folder))
	for entry: String in directory.get_files():
		var filename := entry.trim_suffix(".import").trim_suffix(".remap")
		var extension := filename.get_extension().to_lower()
		if extension not in ["json", "png", "webp"]:
			continue
		var target := destination.path_join(filename)
		if FileAccess.file_exists(target):
			continue
		var path := source.path_join(filename)
		if extension == "json":
			AtomicFile.save_text(target, FileAccess.get_file_as_string(path))
		else:
			var texture := load(path) as Texture2D
			if texture == null:
				continue
			var pixels := texture.get_image()
			if pixels != null:
				if extension == "png":
					pixels.save_png(target)
				else:
					pixels.save_webp(target)
