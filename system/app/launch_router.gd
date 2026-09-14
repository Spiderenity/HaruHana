extends Node

const MAIN_SCENE: PackedScene = preload("res://system/scenes/main.tscn")
const CHARACTER_CREATOR_SCENE: PackedScene = preload(
	"res://system/tools/character_creator/character_creator.tscn"
)
const BUBBLE_CREATOR_SCENE: PackedScene = preload(
	"res://system/tools/bubble_creator/bubble_creator.tscn"
)

func _ready() -> void:
	# The scene root is still adding its children during _ready(). Register the
	# coordinator only after that finishes, so main can reuse the same owner.
	call_deferred("_route_launch")

func _route_launch() -> void:
	var executable_name: String = (
		OS.get_executable_path().get_file().get_basename().to_lower()
	)
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var target_scene: PackedScene = MAIN_SCENE

	if (
		arguments.has("--character-creator")
		or executable_name.contains("character_creator")
		or executable_name.contains("캐릭터")
	):
		target_scene = CHARACTER_CREATOR_SCENE
	elif (
		arguments.has("--bubble-creator")
		or executable_name.contains("bubble_creator")
		or executable_name.contains("말풍선")
	):
		target_scene = BUBBLE_CREATOR_SCENE

	if target_scene == MAIN_SCENE:
		# Acquire ownership before instantiating children that create desktop windows.
		var coordinator := RuntimeInstanceCoordinator.new()
		coordinator.name = "HaruHanaInstanceCoordinator"
		get_tree().root.add_child(coordinator)
		var action := ""
		for argument: String in arguments:
			if argument.begins_with("--taskbar-action="):
				action = argument.trim_prefix("--taskbar-action=").strip_edges().to_lower()
		if not coordinator.claim("haruhana"):
			if not action.is_empty():
				coordinator.submit_command("haruhana", action)
			get_tree().quit()
			return
		# A stale Quit shortcut must never start a new companion session.
		if action == "quit":
			coordinator.free()
			get_tree().quit()
			return

	BundledAssets.restore_missing_defaults()
	get_tree().change_scene_to_packed.call_deferred(target_scene)
