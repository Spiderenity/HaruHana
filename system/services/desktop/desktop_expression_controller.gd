extends Node
class_name DesktopExpressionController

const DEFAULT_MOOD: StringName = &"neutral"

@export var expression_sprite: AnimatedSprite2D
@export var neutral_eyes: CanvasItem

func _ready() -> void:
	set_mood(
		String(DEFAULT_MOOD)
	)

func set_mood(
	mood: String
) -> void:

	var requested: StringName = StringName(
		mood
			.strip_edges()
			.to_lower()
	)

	if requested.is_empty():
		requested = DEFAULT_MOOD

	var selected: StringName = DEFAULT_MOOD

	if (
		requested != DEFAULT_MOOD
		and expression_sprite != null
		and expression_sprite.sprite_frames != null
		and expression_sprite.sprite_frames.has_animation(
			requested
		)
	):
		selected = requested

	var use_neutral: bool = (
		selected == DEFAULT_MOOD
	)

	if neutral_eyes != null:
		neutral_eyes.visible = use_neutral

	if expression_sprite == null:
		return

	if use_neutral:
		expression_sprite.visible = false

		if expression_sprite.is_playing():
			expression_sprite.stop()

		return

	expression_sprite.visible = true
	expression_sprite.play(
		selected
	)

func set_expression(
	mood: String
) -> void:
	set_mood(
		mood
	)
