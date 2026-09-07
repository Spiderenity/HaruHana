extends RefCounted
class_name DistributionPaths


static func get_characters_directory() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://characters")

	return OS.get_executable_path().get_base_dir().path_join("characters")


static func get_bubbles_directory() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://assets/bubbles")

	return OS.get_executable_path().get_base_dir().path_join("bubbles")


static func get_fonts_directory() -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://fonts")

	return OS.get_executable_path().get_base_dir().path_join("fonts")
