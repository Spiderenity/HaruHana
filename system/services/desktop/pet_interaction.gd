extends Node
class_name DesktopPetInteraction

const CharacterProfilesScript = preload(
	"res://system/services/characters/character_profiles.gd"
)

const DEFAULT_CHARACTER_LEFT_MARGIN: int = 80

const DEFAULT_SCREEN_BOTTOM_MARGIN: int = 0

const CHARACTER_GAP: int = 48

const HANDLE_SIZE: Vector2i = Vector2i(
	42,
	26
)

const HANDLE_OFFSET: Vector2i = Vector2i(
	0,
	8
)

const CLICK_DRAG_THRESHOLD: int = 8

const ALPHA_HIT_UPPER_REGION_RATIO: float = 0.05

@export var character_actor: Node

@export var character_visual: CanvasItem

@export var hover_collision: CollisionShape2D

@export var alpha_hit_sprite: Sprite2D

@export_range(0.0, 1.0, 0.01) var alpha_hit_threshold: float = 0.10

signal pet_alt_clicked(
	character_id: String
)

signal pet_alt_right_clicked(
	character_id: String
)

signal pet_stroked(
	character_id: String,
	local_position: Vector2,
	distance: float
)

var main_window: Window

var passthrough: Object

var desktop_slot_index: int = 0
var configured_character_id: String = ""
var applied_interaction_rect_context: String = ""
var initial_pair_layout_expected: bool = false
var initial_partner_width_hint: float = -1.0

var alpha_hit_mask: BitMap = null
var alpha_hit_mask_size: Vector2i = Vector2i.ZERO
var alpha_hit_pixel_bounds: Rect2i = Rect2i()
var alpha_hit_upper_center_pixel: Vector2 = Vector2.ZERO
var alpha_hit_attempted: bool = false

var base_opacity: float = 0.82

var handle_window: Window

var handle_button: Button

var dragging: bool = false
var screen_check_seconds: float = 0.0
var screen_layout_signature: String = ""

var automatic_slide_active: bool = false
var automatic_slide_tween: Tween = null

var locked_y: int = 0

var drag_offset_x: int = 0
var drag_offset_y: int = 0

var mouse_down_x: int = 0
var mouse_down_y: int = 0

var drag_distance: int = 0
var vertical_movement_enabled: bool = false
var fade_alpha: float = 0.82
var fade_alpha_initialized: bool = false

const FADE_RESPONSE_SPEED: float = 8.0
const HOVER_IDLE_PASSTHROUGH_SECONDS: float = 0.5
const HOVER_OPACITY_FACTOR: float = 1.20

var interaction_capture_button: Button

var interaction_capture_active: bool = false
var passive_hover_active: bool = false
var hover_idle_elapsed: float = 0.0
var last_hover_mouse_position: Vector2i = Vector2i.ZERO
var hover_pointer_initialized: bool = false

var last_alt_mouse_desktop: Vector2 = Vector2.ZERO
var has_last_alt_mouse: bool = false
var alt_stroke_accumulator: float = 0.0

const ALT_STROKE_EMIT_DISTANCE: float = 3.0
const ALT_STROKE_MAX_SAMPLE_DISTANCE: float = 90.0

func configure_character_id(
	character_id: String
) -> void:
	configured_character_id = (
		character_id
			.strip_edges()
			.to_lower()
	)

	alpha_hit_attempted = false
	alpha_hit_mask = null
	alpha_hit_mask_size = Vector2i.ZERO
	alpha_hit_pixel_bounds = Rect2i()
	alpha_hit_upper_center_pixel = Vector2.ZERO

	if is_node_ready():
		apply_profile_interaction_rect()
		rebuild_alpha_hit_mask()

func apply_profile_interaction_rect() -> void:
	if (
		hover_collision == null
		or hover_collision.shape == null
		or not (hover_collision.shape is RectangleShape2D)
	):
		return

	var character_id: String = configured_character_id

	if character_id.is_empty():
		character_id = get_character_id()

	if character_id.is_empty():
		return

	var profile: Dictionary = (
		CharacterProfilesScript.load_profile(character_id)
	)

	if profile.is_empty():
		return

	applied_interaction_rect_context = (
		CharacterProfilesScript.get_current_pack()
		+ ":"
		+ character_id
	)

	var desktop_value: Variant = profile.get(
		"desktop",
		{}
	)

	if not (desktop_value is Dictionary):
		return

	var desktop: Dictionary = desktop_value as Dictionary
	var rect_value: Variant = desktop.get(
		"interaction_rect",
		{}
	)

	if not (rect_value is Dictionary):
		return

	var rect_config: Dictionary = rect_value as Dictionary

	if rect_config.is_empty():
		return

	if not bool(rect_config.get("enabled", true)):
		return

	var original_shape: RectangleShape2D = (
		hover_collision.shape as RectangleShape2D
	)

	var duplicated_shape_value: Variant = original_shape.duplicate()

	if not (duplicated_shape_value is RectangleShape2D):
		return

	var shape: RectangleShape2D = (
		duplicated_shape_value as RectangleShape2D
	)

	if rect_config.has("size"):
		var configured_size: Vector2 = _read_vector2_config(
			rect_config.get("size"),
			shape.size
		)

		if configured_size.x > 0.0 and configured_size.y > 0.0:
			shape.size = configured_size

	hover_collision.shape = shape

	if rect_config.has("position"):
		hover_collision.position = _read_vector2_config(
			rect_config.get("position"),
			hover_collision.position
		)

func sync_profile_interaction_rect() -> void:
	var current_character_id: String = get_character_id()

	if current_character_id.is_empty():
		return

	var current_context: String = (
		CharacterProfilesScript.get_current_pack()
		+ ":"
		+ current_character_id
	)

	if current_context == applied_interaction_rect_context:
		return

	configured_character_id = current_character_id
	apply_profile_interaction_rect()

func _read_vector2_config(
	value: Variant,
	fallback: Vector2
) -> Vector2:
	if value is Array:
		var values: Array = value as Array

		if values.size() >= 2:
			return Vector2(
				float(values[0]),
				float(values[1])
			)

	if value is Dictionary:
		var values: Dictionary = value as Dictionary

		if values.has("x") and values.has("y"):
			return Vector2(
				float(values.get("x", fallback.x)),
				float(values.get("y", fallback.y))
			)

	return fallback

func configure_visual_behavior(
	new_base_opacity: float
) -> void:

	base_opacity = clampf(
		new_base_opacity,
		0.10,
		1.0
	)

	if is_node_ready():
		update_character_fade()

	else:
		call_deferred(
			"update_character_fade"
		)

func configure_desktop_slot(
	slot_index: int
) -> void:

	desktop_slot_index = maxi(
		0,
		slot_index
	)

	if is_node_ready():
		call_deferred(
			"_refresh_default_layout_after_slot_config"
		)

func configure_initial_pair_layout(
	reserve_pair_layout: bool,
	partner_width_hint: float = -1.0
) -> void:
	initial_pair_layout_expected = reserve_pair_layout
	initial_partner_width_hint = partner_width_hint

func clear_initial_pair_layout() -> void:
	initial_pair_layout_expected = false
	initial_partner_width_hint = -1.0

func _refresh_default_layout_after_slot_config() -> void:
	if main_window == null:
		return

	if not is_instance_valid(
		main_window
	):
		return

	await get_tree().process_frame
	await get_tree().process_frame

	move_to_default_position()

func _ready() -> void:
	main_window = get_window()

	if main_window == null:
		push_error(
			"PetInteraction requires a Window."
		)

		return

	if character_visual == null:
		if character_actor is CanvasItem:
			character_visual = (
				character_actor as CanvasItem
			)

	if character_visual == null:
		push_error(
			"PetInteraction requires "
			+ "Character Visual or "
			+ "Character Actor."
		)

		return

	if hover_collision == null:
		push_error(
			"PetInteraction requires "
			+ "Hover Collision."
		)

		return

	if hover_collision.shape == null:
		push_error(
			"Hover Collision has no shape."
		)

		return

	if not (
		hover_collision.shape
		is RectangleShape2D
	):
		push_error(
			"Hover Collision must use "
			+ "RectangleShape2D."
		)

		return

	apply_profile_interaction_rect()
	rebuild_alpha_hit_mask()

	main_window.mouse_passthrough_polygon = (
		PackedVector2Array()
	)

	set_process(
		false
	)

	call_deferred(
		"finish_window_setup"
	)

	call_deferred(
		"_refresh_default_layout_after_slot_config"
	)

func finish_window_setup() -> void:
	if main_window == null:
		return

	if not is_instance_valid(
		main_window
	):
		return

	apply_profile_interaction_rect()

	call_deferred(
		"_finish_window_setup_after_layout"
	)

func _finish_window_setup_after_layout() -> void:
	if main_window == null:
		return

	if not is_instance_valid(
		main_window
	):
		return

	move_to_default_position()

	locked_y = (
		main_window.position.y
	)

	enable_windows_clickthrough()

	create_handle_window()

	create_interaction_capture()

	set_process(
		true
	)

func get_character_id() -> String:
	if character_actor is DesktopCharacterActor:
		return (character_actor as DesktopCharacterActor).get_character_id().strip_edges().to_lower()
	return ""

func enable_windows_clickthrough() -> void:
	if OS.get_name() != "Windows":
		main_window.mouse_passthrough = true

		return

	if not Engine.has_singleton(
		"MousePassthrough"
	):
		push_error(
			"Windows Mouse Passthrough addon "
			+ "is not loaded."
		)

		return

	passthrough = Engine.get_singleton(
		"MousePassthrough"
	)

	passthrough.call(
		"set_passthrough",
		main_window.get_window_id(),
		true
	)

func is_alt_held_global() -> bool:
	var godot_alt_pressed: bool = (
		Input.is_key_pressed(
			KEY_ALT
		)
	)

	if OS.get_name() != "Windows":
		return godot_alt_pressed

	if (
		passthrough != null
		and passthrough.has_method(
			"is_alt_pressed"
		)
	):
		var value: Variant = passthrough.call(
			"is_alt_pressed"
		)

		if bool(value):
			return true

	return godot_alt_pressed

func update_interaction_mode(delta: float) -> void:
	var mouse_position := DisplayServer.mouse_get_position()
	var mouse_over := is_mouse_over_character()
	var mouse_over_handle := is_mouse_over_handle()
	var pointer_moved := (
		not hover_pointer_initialized
		or mouse_position != last_hover_mouse_position
	)
	hover_pointer_initialized = true
	last_hover_mouse_position = mouse_position

	if passive_hover_active and (mouse_over or mouse_over_handle or dragging):
		hover_idle_elapsed = HOVER_IDLE_PASSTHROUGH_SECONDS
	elif not mouse_over and not mouse_over_handle:
		hover_idle_elapsed = 0.0
		passive_hover_active = false
	elif is_alt_held_global():
		hover_idle_elapsed = HOVER_IDLE_PASSTHROUGH_SECONDS
		passive_hover_active = true
	elif pointer_moved:
		hover_idle_elapsed = 0.0
	else:
		hover_idle_elapsed += maxf(0.0, delta)
		if hover_idle_elapsed >= HOVER_IDLE_PASSTHROUGH_SECONDS:
			passive_hover_active = true
	var should_be_active := (
		mouse_over
		and not passive_hover_active
		and not dragging
	)

	if (
		should_be_active
		== interaction_capture_active
	):
		return

	interaction_capture_active = (
		should_be_active
	)

	if interaction_capture_active:
		enter_interaction_mode()

	else:
		exit_interaction_mode()

func enter_interaction_mode() -> void:
	has_last_alt_mouse = false
	alt_stroke_accumulator = 0.0

	sync_interaction_capture()
	if interaction_capture_button != null:
		interaction_capture_button.show()
	_set_main_window_passthrough(false)

func exit_interaction_mode() -> void:
	has_last_alt_mouse = false
	alt_stroke_accumulator = 0.0

	if interaction_capture_button != null:
		interaction_capture_button.hide()
	_set_main_window_passthrough(true)

func create_interaction_capture() -> void:
	interaction_capture_button = Button.new()
	interaction_capture_button.name = "PetInteractionCapture"
	interaction_capture_button.text = ""
	interaction_capture_button.flat = true
	interaction_capture_button.focus_mode = Control.FOCUS_NONE
	interaction_capture_button.mouse_filter = Control.MOUSE_FILTER_STOP
	interaction_capture_button.z_index = 4096
	interaction_capture_button.button_mask = (
		MOUSE_BUTTON_MASK_LEFT
		| MOUSE_BUTTON_MASK_RIGHT
	)
	interaction_capture_button.mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND
	)
	interaction_capture_button.hide()
	main_window.add_child(interaction_capture_button)
	interaction_capture_button.gui_input.connect(
		_on_interaction_capture_gui_input
	)
	sync_interaction_capture()

func _set_main_window_passthrough(enabled: bool) -> void:
	if main_window == null or not is_instance_valid(main_window):
		return
	if (
		OS.get_name() == "Windows"
		and passthrough != null
		and passthrough.has_method("set_passthrough")
	):
		passthrough.call(
			"set_passthrough",
			main_window.get_window_id(),
			enabled
		)
		return
	main_window.mouse_passthrough = enabled

func sync_interaction_capture() -> void:
	if interaction_capture_button == null:
		return

	var pet_rect: Rect2 = (
		get_pet_rect()
	)

	if pet_rect.size == Vector2.ZERO:
		return

	interaction_capture_button.position = pet_rect.position
	interaction_capture_button.size = pet_rect.size

func _on_interaction_capture_gui_input(event: InputEvent) -> void:
	if not interaction_capture_active:
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed:
		return
	hover_idle_elapsed = 0.0
	if not is_mouse_over_character():
		return

	match mouse_event.button_index:
		MOUSE_BUTTON_LEFT:
			pet_alt_clicked.emit(get_character_id())
		MOUSE_BUTTON_RIGHT:
			pet_alt_right_clicked.emit(get_character_id())
		_:
			return

	interaction_capture_button.accept_event()

func get_alt_local_mouse_position() -> Vector2:
	var pet_rect: Rect2 = (
		get_pet_rect()
	)

	if pet_rect.size == Vector2.ZERO:
		return Vector2.ZERO

	var desktop_mouse: Vector2i = (
		DisplayServer.mouse_get_position()
	)

	var window_local_mouse: Vector2 = Vector2(
		desktop_mouse.x
			- main_window.position.x,

		desktop_mouse.y
			- main_window.position.y
	)

	return (
		window_local_mouse
		- pet_rect.position
	)

func update_interaction_pet_stroke() -> void:
	if not interaction_capture_active:
		has_last_alt_mouse = false
		alt_stroke_accumulator = 0.0
		return

	if not is_mouse_over_character():
		has_last_alt_mouse = false
		alt_stroke_accumulator = 0.0
		return

	var desktop_mouse_i: Vector2i = (
		DisplayServer.mouse_get_position()
	)

	var desktop_mouse: Vector2 = Vector2(
		desktop_mouse_i.x,
		desktop_mouse_i.y
	)

	if not has_last_alt_mouse:
		last_alt_mouse_desktop = desktop_mouse
		has_last_alt_mouse = true
		return

	var sample_distance: float = (
		desktop_mouse.distance_to(
			last_alt_mouse_desktop
		)
	)

	last_alt_mouse_desktop = desktop_mouse

	if (
		sample_distance <= 0.0
		or sample_distance > ALT_STROKE_MAX_SAMPLE_DISTANCE
	):
		return

	alt_stroke_accumulator += sample_distance

	if alt_stroke_accumulator < ALT_STROKE_EMIT_DISTANCE:
		return

	var emitted_distance: float = (
		alt_stroke_accumulator
	)

	alt_stroke_accumulator = 0.0

	pet_stroked.emit(
		get_character_id(),
		get_alt_local_mouse_position(),
		emitted_distance
	)

func rebuild_alpha_hit_mask() -> bool:
	alpha_hit_attempted = true
	alpha_hit_mask = null
	alpha_hit_mask_size = Vector2i.ZERO
	alpha_hit_pixel_bounds = Rect2i()
	alpha_hit_upper_center_pixel = Vector2.ZERO

	var sprite: Sprite2D = _resolve_alpha_hit_sprite()

	if sprite == null or sprite.texture == null:
		return false

	if (
		sprite.region_enabled
		or sprite.hframes != 1
		or sprite.vframes != 1
	):
		return false

	var image: Image = sprite.texture.get_image()

	if image == null or image.is_empty():
		return false

	var mask: BitMap = BitMap.new()

	mask.create_from_image_alpha(
		image,
		clampf(
			alpha_hit_threshold,
			0.0,
			1.0
		)
	)

	var mask_size: Vector2i = mask.get_size()

	if mask_size.x <= 0 or mask_size.y <= 0:
		return false

	var bounds: Rect2i = _calculate_alpha_pixel_bounds(
		mask,
		mask_size
	)

	if bounds.size.x <= 0 or bounds.size.y <= 0:
		return false

	alpha_hit_sprite = sprite
	alpha_hit_mask = mask
	alpha_hit_mask_size = mask_size
	alpha_hit_pixel_bounds = bounds
	alpha_hit_upper_center_pixel = _calculate_alpha_upper_center(
		mask,
		bounds
	)

	return true

func _ensure_alpha_hit_mask() -> bool:
	if (
		alpha_hit_mask != null
		and alpha_hit_mask_size.x > 0
		and alpha_hit_mask_size.y > 0
		and alpha_hit_pixel_bounds.size.x > 0
		and alpha_hit_pixel_bounds.size.y > 0
	):
		return true

	if alpha_hit_attempted:
		return false

	return rebuild_alpha_hit_mask()

func _resolve_alpha_hit_sprite() -> Sprite2D:
	if (
		alpha_hit_sprite != null
		and is_instance_valid(alpha_hit_sprite)
		and alpha_hit_sprite.texture != null
	):
		return alpha_hit_sprite

	if character_visual is Sprite2D:
		var visual_sprite: Sprite2D = (
			character_visual as Sprite2D
		)

		if visual_sprite.texture != null:
			return visual_sprite

	if character_visual is Node:
		var visual_node: Node = (
			character_visual as Node
		)
		var named_body: Sprite2D = _find_named_alpha_sprite(
			visual_node
		)

		if named_body != null:
			return named_body

		return _find_first_textured_sprite(
			visual_node
		)

	return null

func _find_named_alpha_sprite(
	node: Node
) -> Sprite2D:
	for child: Node in node.get_children():
		if child is Sprite2D:
			var sprite: Sprite2D = child as Sprite2D

			if (
				str(sprite.name).to_lower() == "body"
				and sprite.texture != null
			):
				return sprite

	for child: Node in node.get_children():
		var result: Sprite2D = _find_named_alpha_sprite(
			child
		)

		if result != null:
			return result

	return null

func _find_first_textured_sprite(
	node: Node
) -> Sprite2D:
	for child: Node in node.get_children():
		if child is Sprite2D:
			var sprite: Sprite2D = child as Sprite2D

			if sprite.texture != null:
				return sprite

	for child: Node in node.get_children():
		var result: Sprite2D = _find_first_textured_sprite(
			child
		)

		if result != null:
			return result

	return null

func _calculate_alpha_pixel_bounds(
	mask: BitMap,
	mask_size: Vector2i
) -> Rect2i:
	var minimum_x: int = mask_size.x
	var minimum_y: int = mask_size.y
	var maximum_x: int = -1
	var maximum_y: int = -1

	for y: int in range(mask_size.y):
		for x: int in range(mask_size.x):
			if not mask.get_bitv(Vector2i(x, y)):
				continue

			minimum_x = mini(minimum_x, x)
			minimum_y = mini(minimum_y, y)
			maximum_x = maxi(maximum_x, x)
			maximum_y = maxi(maximum_y, y)

	if maximum_x < minimum_x or maximum_y < minimum_y:
		return Rect2i()

	return Rect2i(
		Vector2i(
			minimum_x,
			minimum_y
		),
		Vector2i(
			maximum_x - minimum_x + 1,
			maximum_y - minimum_y + 1
		)
	)

func _calculate_alpha_upper_center(
	mask: BitMap,
	bounds: Rect2i
) -> Vector2:
	var upper_height: int = maxi(
		1,
		roundi(
			float(bounds.size.y)
			* ALPHA_HIT_UPPER_REGION_RATIO
		)
	)
	var upper_end_y: int = mini(
		bounds.end.y,
		bounds.position.y + upper_height
	)
	var total_x: float = 0.0
	var total_y: float = 0.0
	var count: int = 0

	for y: int in range(
		bounds.position.y,
		upper_end_y
	):
		for x: int in range(
			bounds.position.x,
			bounds.end.x
		):
			if not mask.get_bitv(Vector2i(x, y)):
				continue

			total_x += float(x) + 0.5
			total_y += float(y) + 0.5
			count += 1

	if count <= 0:
		return Vector2(
			float(bounds.position.x)
				+ float(bounds.size.x) / 2.0,
			float(bounds.position.y)
				+ float(bounds.size.y) * 0.15
		)

	return Vector2(
		total_x / float(count),
		total_y / float(count)
	)

func _alpha_pixel_to_window_point(
	pixel_position: Vector2
) -> Vector2:
	if (
		alpha_hit_sprite == null
		or alpha_hit_mask_size.x <= 0
		or alpha_hit_mask_size.y <= 0
	):
		return Vector2.ZERO

	var sprite_rect: Rect2 = alpha_hit_sprite.get_rect()
	var u: float = (
		pixel_position.x
		/ float(alpha_hit_mask_size.x)
	)
	var v: float = (
		pixel_position.y
		/ float(alpha_hit_mask_size.y)
	)

	if alpha_hit_sprite.flip_h:
		u = 1.0 - u

	if alpha_hit_sprite.flip_v:
		v = 1.0 - v

	var sprite_local: Vector2 = (
		sprite_rect.position
		+ Vector2(
			u * sprite_rect.size.x,
			v * sprite_rect.size.y
		)
	)

	return alpha_hit_sprite.to_global(
		sprite_local
	)

func _get_alpha_pet_rect() -> Rect2:
	if not _ensure_alpha_hit_mask():
		return Rect2()

	var bounds: Rect2i = alpha_hit_pixel_bounds
	var points: Array[Vector2] = [
		_alpha_pixel_to_window_point(
			Vector2(bounds.position)
		),
		_alpha_pixel_to_window_point(
			Vector2(
				bounds.end.x,
				bounds.position.y
			)
		),
		_alpha_pixel_to_window_point(
			Vector2(
				bounds.position.x,
				bounds.end.y
			)
		),
		_alpha_pixel_to_window_point(
			Vector2(bounds.end)
		)
	]

	var minimum: Vector2 = points[0]
	var maximum: Vector2 = points[0]

	for point: Vector2 in points:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)

	return Rect2(
		minimum,
		maximum - minimum
	)

func _is_window_local_point_on_alpha(
	window_local_point: Vector2
) -> bool:
	if not _ensure_alpha_hit_mask():
		return false

	if alpha_hit_sprite == null:
		return false

	var sprite_rect: Rect2 = alpha_hit_sprite.get_rect()

	if sprite_rect.size.x <= 0.0 or sprite_rect.size.y <= 0.0:
		return false

	var sprite_local: Vector2 = (
		alpha_hit_sprite.to_local(
			window_local_point
		)
	)
	var u: float = (
		sprite_local.x - sprite_rect.position.x
	) / sprite_rect.size.x
	var v: float = (
		sprite_local.y - sprite_rect.position.y
	) / sprite_rect.size.y

	if (
		u < 0.0
		or u >= 1.0
		or v < 0.0
		or v >= 1.0
	):
		return false

	if alpha_hit_sprite.flip_h:
		u = 1.0 - u

	if alpha_hit_sprite.flip_v:
		v = 1.0 - v

	var pixel: Vector2i = Vector2i(
		clampi(
			floori(
				u * float(alpha_hit_mask_size.x)
			),
			0,
			alpha_hit_mask_size.x - 1
		),
		clampi(
			floori(
				v * float(alpha_hit_mask_size.y)
			),
			0,
			alpha_hit_mask_size.y - 1
		)
	)

	return alpha_hit_mask.get_bitv(
		pixel
	)

func get_alpha_handle_anchor() -> Vector2:
	if not _ensure_alpha_hit_mask():
		return Vector2.ZERO

	return _alpha_pixel_to_window_point(
		alpha_hit_upper_center_pixel
	)

func get_sprite_ground_rect() -> Rect2:
	if alpha_hit_sprite == null or alpha_hit_sprite.texture == null:
		if main_window != null and is_instance_valid(main_window):
			return Rect2(Vector2.ZERO, Vector2(main_window.size))
		return Rect2()

	var sprite_rect: Rect2 = alpha_hit_sprite.get_rect()
	if sprite_rect.size == Vector2.ZERO:
		return Rect2()

	var points: Array[Vector2] = [
		alpha_hit_sprite.to_global(sprite_rect.position),
		alpha_hit_sprite.to_global(Vector2(sprite_rect.end.x, sprite_rect.position.y)),
		alpha_hit_sprite.to_global(Vector2(sprite_rect.position.x, sprite_rect.end.y)),
		alpha_hit_sprite.to_global(sprite_rect.end)
	]

	var minimum: Vector2 = points[0]
	var maximum: Vector2 = points[0]
	for point: Vector2 in points:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)

	return Rect2(minimum, maximum - minimum)

func get_effective_desktop_slot_index() -> int:
	if character_actor is DesktopCharacterActor:
		return maxi(0, (character_actor as DesktopCharacterActor).get_desktop_slot_index())
	return desktop_slot_index

func move_to_default_position() -> void:
	if restore_saved_position():
		return
	var usable_screen: Rect2i = (
		get_usable_screen()
	)

	var first_character_left: float = (
		float(
			usable_screen.position.x
		)
		+ float(
			DEFAULT_CHARACTER_LEFT_MARGIN
		)
	)

	if get_active_actor_count() < 2:
		var desired_single_left: float = first_character_left

		if initial_pair_layout_expected:
			var initial_pet_rect: Rect2 = get_pet_rect()

			if (
				initial_pet_rect.size != Vector2.ZERO
				and get_effective_desktop_slot_index() == 0
			):
				var partner_width: float = (
					initial_partner_width_hint
				)

				if partner_width <= 0.0:
					partner_width = initial_pet_rect.size.x

				desired_single_left += (
					partner_width
					+ float(CHARACTER_GAP)
				)

		_set_default_desktop_pet_position(
			desired_single_left
		)
		return

	if _reflow_default_pair_layout():
		return

	var pet_rect: Rect2 = get_pet_rect()

	if pet_rect.size == Vector2.ZERO:
		return

	var effective_slot_index: int = (
		get_effective_desktop_slot_index()
	)

	var desired_pet_left: float = (
		first_character_left
	)

	if effective_slot_index == 0:
		desired_pet_left += (
			pet_rect.size.x
			+ float(
				CHARACTER_GAP
			)
		)

	_set_default_desktop_pet_position(
		desired_pet_left
	)

func _reflow_default_pair_layout() -> bool:
	var pair: Dictionary = _get_default_pair_interactions()
	if not pair.has(0) or not pair.has(1):
		return false

	var slot_zero: DesktopPetInteraction = pair[0] as DesktopPetInteraction
	var slot_one: DesktopPetInteraction = pair[1] as DesktopPetInteraction
	if slot_zero == null or slot_one == null:
		return false

	var slot_one_rect: Rect2 = slot_one.get_pet_rect()
	var slot_zero_rect: Rect2 = slot_zero.get_pet_rect()
	if slot_one_rect.size == Vector2.ZERO or slot_zero_rect.size == Vector2.ZERO:
		return false

	var usable_screen: Rect2i = get_usable_screen()
	var slot_one_left: float = (
		float(usable_screen.position.x)
		+ float(DEFAULT_CHARACTER_LEFT_MARGIN)
	)
	var slot_zero_left: float = (
		slot_one_left + slot_one_rect.size.x + float(CHARACTER_GAP)
	)

	if not slot_one.restore_saved_position():
		slot_one._set_default_desktop_pet_position(slot_one_left)
	if not slot_zero.restore_saved_position():
		slot_zero._set_default_desktop_pet_position(slot_zero_left)
	return true

func _get_default_pair_interactions() -> Dictionary:
	var result: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group(&"desktop_character_actors"):
		if not (node is DesktopCharacterActor):
			continue
		var actor: DesktopCharacterActor = node as DesktopCharacterActor
		var slot_index: int = actor.get_desktop_slot_index()
		if slot_index != 0 and slot_index != 1:
			continue
		if actor.pet_interaction == null:
			continue
		result[slot_index] = actor.pet_interaction
	return result

func _set_default_desktop_pet_position(
	desired_pet_left: float
) -> void:

	if main_window == null:
		return

	if not is_instance_valid(
		main_window
	):
		return

	var pet_rect: Rect2 = (
		get_pet_rect()
	)

	if pet_rect.size == Vector2.ZERO:
		return

	var usable_screen: Rect2i = (
		get_usable_screen()
	)

	var minimum_pet_left: float = float(
		usable_screen.position.x
	)

	var maximum_pet_left: float = (
		float(
			usable_screen.end.x
		)
		- pet_rect.size.x
	)

	var clamped_pet_left: float = clampf(
		desired_pet_left,
		minimum_pet_left,
		maximum_pet_left
	)

	var new_window_x: int = roundi(
		clamped_pet_left
			- pet_rect.position.x
	)

	var ground_rect: Rect2 = get_sprite_ground_rect()
	if ground_rect.size == Vector2.ZERO:
		ground_rect = pet_rect

	var new_window_y: int = (
		usable_screen.end.y
		- roundi(ground_rect.end.y)
		- DEFAULT_SCREEN_BOTTOM_MARGIN
	)

	main_window.position = Vector2i(
		new_window_x,
		new_window_y
	)

	locked_y = new_window_y

func sync_locked_y_to_window_position() -> void:
	if main_window == null:
		return

	if not is_instance_valid(main_window):
		return

	locked_y = main_window.position.y

func configure_vertical_movement(enabled: bool) -> void:
	vertical_movement_enabled = enabled
	if enabled or main_window == null or not is_instance_valid(main_window):
		return
	var current_x: int = main_window.position.x
	var pet_rect: Rect2 = get_pet_rect()
	var ground_rect: Rect2 = get_sprite_ground_rect()
	if ground_rect.size == Vector2.ZERO:
		ground_rect = pet_rect
	var usable_screen: Rect2i = get_usable_screen()
	locked_y = usable_screen.end.y - roundi(ground_rect.end.y) - DEFAULT_SCREEN_BOTTOM_MARGIN
	main_window.position = Vector2i(current_x, locked_y)
	sync_handle_position()
	sync_interaction_capture()

func is_vertical_movement_enabled() -> bool:
	return vertical_movement_enabled

func get_active_actor_count() -> int:
	return (
		get_tree()
			.get_nodes_in_group(
				&"desktop_character_actors"
			)
			.size()
	)

func get_desktop_pet_rect() -> Rect2:
	var pet_rect: Rect2 = (
		get_pet_rect()
	)

	if pet_rect.size == Vector2.ZERO:
		return Rect2()

	return Rect2(
		Vector2(
			float(
				main_window.position.x
			),
			float(
				main_window.position.y
			)
		)
			+ pet_rect.position,

		pet_rect.size
	)

func get_pet_rect() -> Rect2:
	var alpha_rect: Rect2 = _get_alpha_pet_rect()

	if alpha_rect.size != Vector2.ZERO:
		return alpha_rect

	return _get_collision_pet_rect()

func _get_collision_pet_rect() -> Rect2:
	if hover_collision == null:
		return Rect2()

	var shape: RectangleShape2D = (
		hover_collision.shape
		as RectangleShape2D
	)

	if shape == null:
		return Rect2()

	var global_scale: Vector2 = (
		hover_collision.global_scale.abs()
	)
	var scaled_size: Vector2 = Vector2(
		shape.size.x * global_scale.x,
		shape.size.y * global_scale.y
	)
	var half_size: Vector2 = (
		scaled_size / 2.0
	)

	return Rect2(
		hover_collision.global_position
			- half_size,
		scaled_size
	)

func is_mouse_over_character() -> bool:
	var desktop_mouse: Vector2i = (
		DisplayServer.mouse_get_position()
	)
	var local_mouse: Vector2 = Vector2(
		desktop_mouse.x
			- main_window.position.x,
		desktop_mouse.y
			- main_window.position.y
	)

	if _ensure_alpha_hit_mask():
		return _is_window_local_point_on_alpha(
			local_mouse
		)

	var pet_rect: Rect2 = (
		_get_collision_pet_rect()
	)

	if pet_rect.size == Vector2.ZERO:
		return false

	return pet_rect.has_point(
		local_mouse
	)

func has_character_visual_target() -> bool:
	return (
		character_visual != null
		and is_instance_valid(
			character_visual
		)
	)

func set_visual_alpha_direct(
	alpha: float
) -> void:

	if not has_character_visual_target():
		return

	var color: Color = (
		character_visual.modulate
	)

	color.a = clampf(
		alpha,
		0.0,
		1.0
	)

	character_visual.modulate = color

func set_character_alpha(
	alpha: float
) -> void:
	if character_actor is DesktopCharacterActor:
		(character_actor as DesktopCharacterActor).set_character_alpha(alpha)
		return
	if has_character_visual_target():
		set_visual_alpha_direct(alpha)

func update_character_fade(delta: float = 0.016) -> void:
	var hover_alpha := clampf(base_opacity * HOVER_OPACITY_FACTOR, 0.0, 1.0)
	var target_alpha: float = base_opacity
	if passive_hover_active or dragging:
		target_alpha = clampf(base_opacity / HOVER_OPACITY_FACTOR, 0.0, 1.0)
	elif (
		is_mouse_over_character()
		or is_mouse_over_handle()
	):
		target_alpha = hover_alpha
	if not fade_alpha_initialized:
		fade_alpha = base_opacity
		fade_alpha_initialized = true
	var linear_weight: float = clampf(delta * FADE_RESPONSE_SPEED, 0.0, 1.0)
	var curved_weight: float = linear_weight * linear_weight * (3.0 - 2.0 * linear_weight)
	fade_alpha = lerpf(fade_alpha, target_alpha, curved_weight)
	if absf(fade_alpha - target_alpha) < 0.002:
		fade_alpha = target_alpha
	set_character_alpha(fade_alpha)

func create_handle_window() -> void:
	handle_window = Window.new()

	handle_window.name = (
		"PetGrabHandle"
	)

	handle_window.size = (
		HANDLE_SIZE
	)

	handle_window.borderless = true
	handle_window.transparent = true
	handle_window.transparent_bg = true
	handle_window.unresizable = true
	handle_window.unfocusable = true
	handle_window.always_on_top = true
	handle_window.transient = false
	handle_window.visible = false
	if character_actor != null and character_actor.has_method("request_application_close"):
		handle_window.close_requested.connect(
			Callable(character_actor, "request_application_close")
		)

	add_child(
		handle_window
	)

	handle_button = Button.new()

	handle_button.text = "☰"

	handle_button.flat = true

	handle_button.position = (
		Vector2.ZERO
	)

	handle_button.size = Vector2(
		HANDLE_SIZE.x,
		HANDLE_SIZE.y
	)

	handle_button.focus_mode = (
		Control.FOCUS_NONE
	)

	handle_button.mouse_default_cursor_shape = (
		Control.CURSOR_MOVE
	)

	handle_button.add_theme_font_size_override(
		"font_size",
		16
	)

	handle_button.add_theme_color_override(
		"font_color",
		Color.WHITE
	)

	handle_button.add_theme_color_override(
		"font_hover_color",
		Color.WHITE
	)

	handle_button.add_theme_color_override(
		"font_pressed_color",
		Color.WHITE
	)

	handle_button.add_theme_color_override(
		"font_outline_color",
		Color.BLACK
	)

	handle_button.add_theme_constant_override(
		"outline_size",
		4
	)

	handle_window.add_child(
		handle_button
	)

	handle_button.button_down.connect(
		_on_handle_button_down
	)

	sync_handle_position()

func sync_handle_position() -> void:
	if handle_window == null:
		return

	var pet_rect: Rect2 = (
		get_pet_rect()
	)

	if pet_rect.size == Vector2.ZERO:
		return

	var anchor: Vector2 = get_alpha_handle_anchor()

	if anchor == Vector2.ZERO:
		anchor = Vector2(
			pet_rect.position.x
				+ pet_rect.size.x / 2.0,
			pet_rect.position.y
		)

	var local_x: float = (
		anchor.x
		- float(
			HANDLE_SIZE.x
		) / 2.0
		+ float(
			HANDLE_OFFSET.x
		)
	)

	var local_y: float = (
		anchor.y
		- float(
			HANDLE_SIZE.y
		) / 2.0
		+ float(
			HANDLE_OFFSET.y
		)
	)

	handle_window.position = Vector2i(
		main_window.position.x
			+ roundi(
				local_x
			),

		main_window.position.y
			+ roundi(
				local_y
			)
	)

func is_mouse_over_handle() -> bool:
	if handle_window == null:
		return false

	if not handle_window.visible:
		return false

	var mouse_position: Vector2i = (
		DisplayServer.mouse_get_position()
	)

	var handle_rect: Rect2i = Rect2i(
		handle_window.position,
		handle_window.size
	)

	return handle_rect.has_point(
		mouse_position
	)

func update_handle_visibility() -> void:
	if handle_window == null:
		return

	if dragging:
		handle_window.show()

		return

	if (
		passive_hover_active
		and (
			is_mouse_over_character()
		or is_mouse_over_handle()
		)
	):
		handle_window.show()

	else:
		handle_window.hide()

func is_dragging_character() -> bool:
	return dragging

func is_automatic_slide_active() -> bool:
	return automatic_slide_active

func get_default_character_gap() -> float:
	return float(
		CHARACTER_GAP
	)

func slide_pet_to_desktop_left(
	desired_pet_left: float,
	duration: float = 0.4
) -> bool:

	if main_window == null:
		return false

	if not is_instance_valid(
		main_window
	):
		return false

	var pet_rect: Rect2 = (
		get_pet_rect()
	)

	if pet_rect.size == Vector2.ZERO:
		return false

	var usable_screen: Rect2i = (
		get_usable_screen()
	)

	var minimum_pet_left: float = float(
		usable_screen.position.x
	)

	var maximum_pet_left: float = (
		float(
			usable_screen.end.x
		)
		- pet_rect.size.x
	)

	var clamped_pet_left: float = clampf(
		desired_pet_left,
		minimum_pet_left,
		maximum_pet_left
	)

	var target_window_x: int = roundi(
		clamped_pet_left
			- pet_rect.position.x
	)

	_cancel_automatic_slide()

	dragging = false
	automatic_slide_active = true

	var start_window_x: float = float(
		main_window.position.x
	)

	if is_equal_approx(
		start_window_x,
		float(
			target_window_x
		)
	):
		_set_automatic_slide_window_x(
			float(
				target_window_x
			)
		)

		automatic_slide_active = false
		return true

	automatic_slide_tween = (
		create_tween()
	)

	automatic_slide_tween.set_trans(
		Tween.TRANS_QUAD
	)

	automatic_slide_tween.set_ease(
		Tween.EASE_OUT
	)

	automatic_slide_tween.tween_method(
		Callable(
			self,
			"_set_automatic_slide_window_x"
		),
		start_window_x,
		float(
			target_window_x
		),
		maxf(
			0.05,
			duration
		)
	)

	automatic_slide_tween.finished.connect(
		_on_automatic_slide_finished
	)

	return true

func _set_automatic_slide_window_x(
	window_x: float
) -> void:

	if main_window == null:
		return

	if not is_instance_valid(
		main_window
	):
		return

	main_window.position = Vector2i(
		roundi(
			window_x
		),
		main_window.position.y if vertical_movement_enabled else locked_y
	)

	sync_handle_position()
	sync_interaction_capture()

func _on_automatic_slide_finished() -> void:
	automatic_slide_active = false
	automatic_slide_tween = null

	sync_handle_position()
	sync_interaction_capture()

func _cancel_automatic_slide() -> void:
	if automatic_slide_tween != null:
		automatic_slide_tween.kill()

	automatic_slide_tween = null
	automatic_slide_active = false

func _on_handle_button_down() -> void:
	_cancel_automatic_slide()

	dragging = true

	drag_distance = 0

	var mouse_x: int = (
		DisplayServer
			.mouse_get_position()
			.x
	)
	var mouse_y: int = DisplayServer.mouse_get_position().y

	mouse_down_x = mouse_x
	mouse_down_y = mouse_y

	drag_offset_x = (
		mouse_x
		- main_window.position.x
	)
	drag_offset_y = mouse_y - main_window.position.y

func update_dragging() -> void:
	if not dragging:
		return
	if (DisplayServer.mouse_get_button_state() & MOUSE_BUTTON_MASK_LEFT) == 0:
		dragging = false
		save_desktop_position()
		return
	var mouse := DisplayServer.mouse_get_position()
	drag_distance = maxi(absi(mouse.x - mouse_down_x), absi(mouse.y - mouse_down_y))
	var target_screen := DesktopPreferences.screen_at(Vector2(mouse))
	var usable := DisplayServer.screen_get_usable_rect(target_screen)
	var target := Vector2i(mouse.x - drag_offset_x, mouse.y - drag_offset_y)
	if not vertical_movement_enabled:
		var ground := get_sprite_ground_rect()
		if ground.size == Vector2.ZERO:
			ground = get_pet_rect()
		target.y = usable.end.y - roundi(ground.end.y) - DEFAULT_SCREEN_BOTTOM_MARGIN
	main_window.position = DesktopPreferences.clamp_window(target, get_pet_rect(), usable)
	locked_y = main_window.position.y
	sync_handle_position()
	sync_interaction_capture()

func get_current_screen() -> int:
	if main_window == null or not is_instance_valid(main_window):
		return DisplayServer.get_primary_screen()
	if main_window.position.x <= -30000:
		return DisplayServer.get_primary_screen()
	return DesktopPreferences.screen_at(Vector2(main_window.position) + get_pet_rect().get_center())

func get_usable_screen() -> Rect2i:
	return DisplayServer.screen_get_usable_rect(get_current_screen())

func _can_remember_position() -> bool:
	return is_instance_valid(character_actor) and not get_character_id().is_empty() and bool(character_actor.get_meta("remember_desktop_position", false))

func _preferences_pack() -> String:
	return str(character_actor.get_meta("preferences_pack", "")) if is_instance_valid(character_actor) else ""

func has_saved_position() -> bool:
	return _can_remember_position() and DesktopPreferences.get_entry(get_character_id(), _preferences_pack()).get("position", null) is Array

func save_desktop_position() -> void:
	if not _can_remember_position() or main_window == null:
		return
	var usable := get_usable_screen()
	var pet := get_desktop_pet_rect()
	var error := DesktopPreferences.update_entry(get_character_id(), {
		"position": [pet.position.x - usable.position.x, pet.position.y - usable.position.y],
		"screen_origin": [DisplayServer.screen_get_position(get_current_screen()).x, DisplayServer.screen_get_position(get_current_screen()).y]
	}, _preferences_pack())
	if error != OK:
		push_warning("Could not save character position: " + error_string(error))

func restore_saved_position() -> bool:
	if not has_saved_position() or main_window == null or get_pet_rect().size == Vector2.ZERO:
		return false
	var entry := DesktopPreferences.get_entry(get_character_id(), _preferences_pack())
	var position_value: Array = entry.get("position", [])
	var origin: Array = entry.get("screen_origin", [])
	if position_value.size() != 2 or origin.size() != 2:
		return false
	var screen := -1
	for index: int in range(DisplayServer.get_screen_count()):
		if DisplayServer.screen_get_position(index) == Vector2i(int(origin[0]), int(origin[1])):
			screen = index
			break
	if screen < 0:
		reset_desktop_position()
		return true
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var target := Vector2i((Vector2(usable.position) + Vector2(float(position_value[0]), float(position_value[1])) - get_pet_rect().position).round())
	if not vertical_movement_enabled:
		var ground := get_sprite_ground_rect()
		target.y = usable.end.y - roundi((get_pet_rect() if ground.size == Vector2.ZERO else ground).end.y)
	main_window.position = DesktopPreferences.clamp_window(target, get_pet_rect(), usable)
	locked_y = main_window.position.y
	return true

func reset_desktop_position() -> void:
	if main_window == null:
		return
	var screen := DisplayServer.get_primary_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	# Keep a predictable slot gap without moving peers or restoring old positions.
	var left := float(usable.position.x + DEFAULT_CHARACTER_LEFT_MARGIN)
	if get_effective_desktop_slot_index() == 0:
		var pair := _get_default_pair_interactions()
		if pair.has(1):
			left += pair[1].get_pet_rect().size.x + CHARACTER_GAP
		elif initial_pair_layout_expected:
			left += (initial_partner_width_hint if initial_partner_width_hint > 0.0 else get_pet_rect().size.x) + CHARACTER_GAP
	main_window.position = usable.position
	_set_default_desktop_pet_position(left)
	sync_handle_position()
	sync_interaction_capture()
	save_desktop_position()

func move_to_screen(screen: int) -> void:
	if main_window == null or screen < 0 or screen >= DisplayServer.get_screen_count():
		return
	var source := get_usable_screen()
	var target_screen := DisplayServer.screen_get_usable_rect(screen)
	var target := main_window.position + target_screen.position - source.position
	if not vertical_movement_enabled:
		var ground := get_sprite_ground_rect()
		target.y = target_screen.end.y - roundi((get_pet_rect() if ground.size == Vector2.ZERO else ground).end.y)
	main_window.position = DesktopPreferences.clamp_window(target, get_pet_rect(), target_screen)
	locked_y = main_window.position.y
	sync_handle_position()
	sync_interaction_capture()
	save_desktop_position()

func _process(
	delta: float
) -> void:
	screen_check_seconds += delta
	if screen_check_seconds >= 1.0 and _can_remember_position():
		screen_check_seconds = 0.0
		var layout := ""
		for index: int in range(DisplayServer.get_screen_count()):
			layout += str(DisplayServer.screen_get_usable_rect(index))
		if not screen_layout_signature.is_empty() and layout != screen_layout_signature and not dragging:
			if not restore_saved_position():
				reset_desktop_position()
		screen_layout_signature = layout

	sync_profile_interaction_rect()

	update_dragging()

	update_interaction_mode(delta)

	update_interaction_pet_stroke()

	update_character_fade(delta)

	sync_handle_position()

	sync_interaction_capture()

	update_handle_visibility()
