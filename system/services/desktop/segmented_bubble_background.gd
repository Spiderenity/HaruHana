extends Control
class_name SegmentedBubbleBackground

var top_texture: Texture2D = null
var middle_texture: Texture2D = null
var bottom_texture: Texture2D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	resized.connect(queue_redraw)

func configure(textures: Dictionary) -> void:
	top_texture = textures.get("top") as Texture2D
	middle_texture = textures.get("middle") as Texture2D
	bottom_texture = textures.get("bottom") as Texture2D
	queue_redraw()

func get_top_height(target_width: float) -> float:
	return _scaled_height(top_texture, target_width)

func get_bottom_height(target_width: float) -> float:
	return _scaled_height(bottom_texture, target_width)

func get_fixed_height(target_width: float) -> float:
	return (
		get_top_height(target_width)
		+ get_bottom_height(target_width)
	)

func _scaled_height(texture: Texture2D, target_width: float) -> float:
	if texture == null or target_width <= 0.0:
		return 0.0

	var texture_size: Vector2 = texture.get_size()

	if texture_size.x <= 0.0:
		return 0.0

	return texture_size.y * target_width / texture_size.x

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var top_height: float = get_top_height(size.x)
	var bottom_height: float = get_bottom_height(size.x)
	var fixed_height: float = top_height + bottom_height

	if fixed_height > size.y and fixed_height > 0.0:
		var fit_scale: float = size.y / fixed_height
		top_height *= fit_scale
		bottom_height *= fit_scale

	var middle_height: float = maxf(
		0.0,
		size.y - top_height - bottom_height
	)

	if top_texture != null and top_height > 0.0:
		draw_texture_rect(
			top_texture,
			Rect2(0.0, 0.0, size.x, top_height),
			false
		)

	if middle_texture != null and middle_height > 0.0:
		draw_texture_rect(
			middle_texture,
			Rect2(0.0, top_height, size.x, middle_height),
			false
		)

	if bottom_texture != null and bottom_height > 0.0:
		draw_texture_rect(
			bottom_texture,
			Rect2(
				0.0,
				size.y - bottom_height,
				size.x,
				bottom_height
			),
			false
		)
