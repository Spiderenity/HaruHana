extends Node

const MAIN_SCENE: PackedScene = preload("res://system/scenes/main.tscn")
const CHARACTER_CREATOR_SCENE: PackedScene = preload(
	"res://system/tools/character_creator/character_creator.tscn"
)
const BUBBLE_CREATOR_SCENE: PackedScene = preload(
	"res://system/tools/bubble_creator/bubble_creator.tscn"
)

func _ready() -> void:
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

	get_tree().change_scene_to_packed.call_deferred(target_scene)
