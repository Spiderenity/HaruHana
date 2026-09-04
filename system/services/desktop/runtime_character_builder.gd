extends RefCounted
class_name RuntimeCharacterBuilder

const CharacterProfilesScript = preload(
	"res://system/services/characters/character_profiles.gd"
)

const DesktopCharacterActorScript = preload(
	"res://system/services/desktop/desktop_character_actor.gd"
)

const PetInteractionScript = preload(
	"res://system/services/desktop/pet_interaction.gd"
)

const DesktopExpressionControllerScript = preload(
	"res://system/services/desktop/desktop_expression_controller.gd"
)
const DialogueCatalogScript = preload(
	"res://system/services/characters/dialogue_catalog.gd"
)

const VALID_MOODS: Array[String] = DialogueCatalogScript.EXTENDED_MOODS

const IMAGE_EXTENSIONS: Array[String] = [
	"png",
	"webp",
]

const ALPHA_THRESHOLD: float = 0.10
const BLANK_PREVIEW_TEXTURE_PATH := "res://assets/placeholders/character_creator/transparent_400x600.png"

static func get_available_skins(
	pack_id: String,
	character_id: String
) -> Array[String]:
	var result: Array[String] = []
	var base_directory: String = _get_character_sprite_root(pack_id, character_id)
	if base_directory.is_empty():
		return result

	if not _find_sprite_file(base_directory, "body").is_empty():
		result.append("default")

	var skins_directory: String = base_directory.path_join("skins")
	var directory := DirAccess.open(skins_directory)
	if directory == null:
		return result

	var discovered: Array[String] = []
	directory.list_dir_begin()
	while true:
		var entry: String = directory.get_next()
		if entry.is_empty():
			break
		if not directory.current_is_dir() or entry.begins_with("."):
			continue
		var skin_id: String = _normalize_skin_id(entry)
		if skin_id.is_empty():
			continue
		var skin_directory: String = skins_directory.path_join(entry)
		if _find_sprite_file(skin_directory, "body").is_empty():
			continue
		discovered.append(skin_id)
	directory.list_dir_end()
	discovered.sort()
	result.append_array(discovered)
	return result

static func get_available_body_states(
	pack_id: String,
	character_id: String,
	skin_id: String = "default"
) -> Array[String]:
	var sprite_directory: String = get_sprite_directory(pack_id, character_id, skin_id)
	if sprite_directory.is_empty():
		return []
	var body_path: String = _find_sprite_file(sprite_directory, "body")
	if body_path.is_empty():
		return []
	var default_texture: Texture2D = _load_texture(body_path)
	if default_texture == null:
		return []
	var variants: Dictionary = _discover_body_variants(sprite_directory, default_texture)
	var result: Array[String] = []
	for key: Variant in variants.keys():
		result.append(str(key))
	result.sort()
	return result

static func get_sprite_directory(
	pack_id: String,
	character_id: String,
	skin_id: String = "default"
) -> String:
	var base_directory: String = _get_character_sprite_root(pack_id, character_id)
	if base_directory.is_empty():
		return ""

	skin_id = _normalize_skin_id(skin_id)
	if skin_id.is_empty():
		return ""

	var directory_path: String = base_directory
	if skin_id != "default":
		directory_path = base_directory.path_join("skins").path_join(skin_id)

	if _find_sprite_file(directory_path, "body").is_empty():
		return ""
	return directory_path

static func _get_character_sprite_root(
	pack_id: String,
	character_id: String
) -> String:
	pack_id = CharacterProfilesScript.normalize_pack_id(pack_id)
	character_id = character_id.strip_edges().to_lower()
	if pack_id.is_empty() or character_id.is_empty():
		return ""
	if not CharacterProfilesScript.get_pack_character_ids(pack_id).has(character_id):
		return ""
	var root_path: String = CharacterProfilesScript.get_pack_root_path(pack_id)
	if root_path.is_empty():
		return ""
	return root_path.path_join("sprites").path_join(character_id)

static func _normalize_skin_id(skin_id: String) -> String:
	skin_id = skin_id.strip_edges().to_lower()
	if skin_id.is_empty():
		return ""
	for character: String in ["/", "\\", ":"]:
		if skin_id.contains(character):
			return ""
	if skin_id == "." or skin_id == "..":
		return ""
	return skin_id

static func can_build(
	pack_id: String,
	character_id: String,
	skin_id: String = "default"
) -> bool:
	return not get_body_path(
		pack_id,
		character_id,
		skin_id
	).is_empty()

static func build_actor(
	pack_id: String,
	character_id: String,
	skin_id: String = "default"
) -> DesktopCharacterActor:
	var sprite_directory: String = get_sprite_directory(
		pack_id,
		character_id,
		skin_id
	)

	if sprite_directory.is_empty():
		return null

	var body_path: String = _find_sprite_file(
		sprite_directory,
		"body"
	)

	if body_path.is_empty():
		return null

	var body_texture: Texture2D = _load_texture(body_path)

	if body_texture == null:
		return null

	var actor: DesktopCharacterActor = DesktopCharacterActorScript.new()

	if actor == null:
		return null

	var content := Node2D.new()
	content.name = "Content"
	actor.add_child(content)

	var body := Sprite2D.new()
	body.name = "Body"
	body.texture = body_texture
	content.add_child(body)

	var body_variants: Dictionary = _discover_body_variants(
		sprite_directory,
		body_texture
	)
	actor.configure_body_variants(body, body_variants)

	var texture_size: Vector2 = body_texture.get_size()
	for variant_value: Variant in body_variants.values():
		if variant_value is Texture2D:
			var variant_size: Vector2 = (variant_value as Texture2D).get_size()
			texture_size.x = maxf(texture_size.x, variant_size.x)
			texture_size.y = maxf(texture_size.y, variant_size.y)
	var canvas_size := Vector2i(
		maxi(1, roundi(texture_size.x)),
		maxi(1, roundi(texture_size.y))
	)

	actor.visual_root = content
	actor.character_canvas_size = canvas_size

	var expression: AnimatedSprite2D = _create_expression_sprite(
		sprite_directory
	)

	if expression != null:
		content.add_child(expression)

	var eyes: AnimatedSprite2D = _create_eyes_sprite(
		sprite_directory
	)
	var blink_timer: Timer = null

	if eyes != null:
		content.add_child(eyes)
		blink_timer = Timer.new()
		blink_timer.name = "BlinkTimer"
		blink_timer.one_shot = true
		eyes.add_child(blink_timer)
		actor.eyes = eyes
		actor.blink_timer = blink_timer

	var hover_area := Area2D.new()
	hover_area.name = "HoverArea"
	content.add_child(hover_area)

	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(
		float(canvas_size.x),
		float(canvas_size.y)
	)
	collision.shape = shape
	hover_area.add_child(collision)

	var bubble_parts: Dictionary = _create_speech_bubble()
	var speech_bubble: PanelContainer = bubble_parts["bubble"]
	var speech_label: Label = bubble_parts["label"]
	content.add_child(speech_bubble)

	var bubble_hide_timer := Timer.new()
	bubble_hide_timer.name = "BubbleHideTimer"
	bubble_hide_timer.one_shot = true
	actor.add_child(bubble_hide_timer)

	var pet_interaction: DesktopPetInteraction = PetInteractionScript.new()
	pet_interaction.name = "PetInteraction"
	pet_interaction.character_actor = actor
	pet_interaction.character_visual = content
	pet_interaction.hover_collision = collision
	pet_interaction.alpha_hit_sprite = body
	actor.add_child(pet_interaction)

	actor.speech_bubble = speech_bubble
	actor.speech_label = speech_label
	actor.bubble_hide_timer = bubble_hide_timer
	actor.pet_interaction = pet_interaction

	if expression != null:
		var expression_controller: DesktopExpressionController = (
			DesktopExpressionControllerScript.new()
		)
		expression_controller.name = "ExpressionController"
		expression_controller.expression_sprite = expression
		if eyes != null:
			expression_controller.neutral_eyes = eyes
		actor.add_child(expression_controller)
		actor.expression_controller = expression_controller

	return actor

static func build_blank_preview_actor() -> DesktopCharacterActor:
	var body_texture: Texture2D = _load_texture(BLANK_PREVIEW_TEXTURE_PATH)
	if body_texture == null:
		return null
	var actor: DesktopCharacterActor = DesktopCharacterActorScript.new()
	var content := Node2D.new()
	content.name = "Content"
	actor.add_child(content)
	var body := Sprite2D.new()
	body.name = "Body"
	body.texture = body_texture
	content.add_child(body)
	actor.configure_body_variants(body, {"default": body_texture})
	var texture_size := body_texture.get_size()
	var canvas_size := Vector2i(maxi(1, roundi(texture_size.x)), maxi(1, roundi(texture_size.y)))
	actor.visual_root = content
	actor.character_canvas_size = canvas_size
	var hover_area := Area2D.new()
	hover_area.name = "HoverArea"
	content.add_child(hover_area)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(canvas_size)
	collision.shape = shape
	hover_area.add_child(collision)
	var bubble_parts: Dictionary = _create_speech_bubble()
	var speech_bubble: PanelContainer = bubble_parts["bubble"]
	var speech_label: Label = bubble_parts["label"]
	content.add_child(speech_bubble)
	var bubble_hide_timer := Timer.new()
	bubble_hide_timer.name = "BubbleHideTimer"
	bubble_hide_timer.one_shot = true
	actor.add_child(bubble_hide_timer)
	var pet_interaction: DesktopPetInteraction = PetInteractionScript.new()
	pet_interaction.name = "PetInteraction"
	pet_interaction.character_actor = actor
	pet_interaction.character_visual = content
	pet_interaction.hover_collision = collision
	pet_interaction.alpha_hit_sprite = body
	actor.add_child(pet_interaction)
	actor.speech_bubble = speech_bubble
	actor.speech_label = speech_label
	actor.bubble_hide_timer = bubble_hide_timer
	actor.pet_interaction = pet_interaction
	return actor

static func get_body_path(
	pack_id: String,
	character_id: String,
	skin_id: String = "default"
) -> String:
	var sprite_directory: String = get_sprite_directory(
		pack_id,
		character_id,
		skin_id
	)

	if sprite_directory.is_empty():
		return ""

	return _find_sprite_file(
		sprite_directory,
		"body"
	)

static func get_alpha_width_hint(
	pack_id: String,
	character_id: String,
	skin_id: String = "default"
) -> float:
	var body_path: String = get_body_path(
		pack_id,
		character_id,
		skin_id
	)

	if body_path.is_empty():
		return 0.0

	var texture: Texture2D = _load_texture(body_path)

	if texture == null:
		return 0.0

	var image: Image = texture.get_image()

	if image == null or image.is_empty():
		return maxf(1.0, texture.get_size().x)

	var minimum_x: int = image.get_width()
	var maximum_x: int = -1

	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			if image.get_pixel(x, y).a <= ALPHA_THRESHOLD:
				continue
			minimum_x = mini(minimum_x, x)
			maximum_x = maxi(maximum_x, x)

	if maximum_x < minimum_x:
		return maxf(1.0, texture.get_size().x)

	return float(maximum_x - minimum_x + 1)

static func _discover_body_variants(
	sprite_directory: String,
	default_texture: Texture2D
) -> Dictionary:
	var result: Dictionary = {"default": default_texture}
	var directory: DirAccess = DirAccess.open(sprite_directory)
	if directory == null:
		return result

	directory.list_dir_begin()
	while true:
		var entry: String = directory.get_next()
		if entry.is_empty():
			break
		if directory.current_is_dir() or entry.begins_with("."):
			continue
		var resource_entry: String = _strip_import_mapping_suffix(entry)
		var extension: String = resource_entry.get_extension().to_lower()
		if not IMAGE_EXTENSIONS.has(extension):
			continue
		var stem: String = resource_entry.get_basename().to_lower()
		if not stem.begins_with("body_"):
			continue
		var state: String = stem.trim_prefix("body_").strip_edges().replace(" ", "_").replace("-", "_")
		if state.is_empty():
			continue
		var texture: Texture2D = _load_texture(
			sprite_directory.path_join(resource_entry)
		)
		if texture != null:
			result[state] = texture
	directory.list_dir_end()
	return result

static func _create_expression_sprite(
	sprite_directory: String
) -> AnimatedSprite2D:
	var frames := SpriteFrames.new()

	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")

	var added: Array[String] = []

	for mood: String in VALID_MOODS:
		var path: String = _find_sprite_file(
			sprite_directory,
			mood
		)

		if path.is_empty():
			continue

		var texture: Texture2D = _load_texture(path)

		if texture == null:
			continue

		var animation_name := StringName(mood)
		frames.add_animation(animation_name)
		frames.add_frame(animation_name, texture)
		frames.set_animation_loop(animation_name, true)
		frames.set_animation_speed(animation_name, 5.0)
		added.append(mood)

	if added.is_empty():
		return null

	var sprite := AnimatedSprite2D.new()
	sprite.name = "Expression"
	sprite.sprite_frames = frames

	var initial: String = (
		"neutral"
		if added.has("neutral")
		else added[0]
	)
	sprite.animation = StringName(initial)
	return sprite

static func _create_eyes_sprite(
	sprite_directory: String
) -> AnimatedSprite2D:
	var open_texture: Texture2D = _load_optional_sprite(
		sprite_directory,
		"eyes_open"
	)
	var half_texture: Texture2D = _load_optional_sprite(
		sprite_directory,
		"eyes_half"
	)
	var closed_texture: Texture2D = _load_optional_sprite(
		sprite_directory,
		"eyes_closed"
	)

	if open_texture == null and closed_texture == null:
		return null

	if open_texture == null:
		open_texture = closed_texture

	if closed_texture == null:
		closed_texture = open_texture

	if half_texture == null:
		half_texture = open_texture

	var frames := SpriteFrames.new()

	if frames.has_animation(&"default"):
		frames.remove_animation(&"default")

	frames.add_animation(&"blink")
	frames.add_frame(&"blink", open_texture)
	frames.add_frame(&"blink", half_texture)
	frames.add_frame(&"blink", closed_texture)
	frames.add_frame(&"blink", half_texture)
	frames.add_frame(&"blink", open_texture)
	frames.set_animation_loop(&"blink", false)
	frames.set_animation_speed(&"blink", 12.0)

	var sprite := AnimatedSprite2D.new()
	sprite.name = "Eyes"
	sprite.sprite_frames = frames
	sprite.animation = &"blink"
	sprite.frame = 0
	return sprite

static func _load_optional_sprite(
	sprite_directory: String,
	stem: String
) -> Texture2D:
	var path: String = _find_sprite_file(
		sprite_directory,
		stem
	)

	if path.is_empty():
		return null

	return _load_texture(path)

static func _create_speech_bubble() -> Dictionary:
	var bubble := PanelContainer.new()
	bubble.name = "SpeechBubble"
	bubble.visible = false
	bubble.custom_minimum_size = Vector2(280.0, 60.0)
	bubble.position = Vector2(-150.0, -300.0)
	bubble.size = Vector2(280.0, 60.0)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.name = "MarginContainer"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	bubble.add_child(margin)

	var label := Label.new()
	label.name = "SpeechLabel"
	label.custom_minimum_size = Vector2(250.0, 0.0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	margin.add_child(label)

	return {
		"bubble": bubble,
		"label": label,
	}

static func _find_sprite_file(
	directory_path: String,
	stem: String
) -> String:
	stem = stem.strip_edges().to_lower()

	if directory_path.is_empty() or stem.is_empty():
		return ""

	for extension: String in IMAGE_EXTENSIONS:
		var candidate: String = directory_path.path_join(
			stem + "." + extension
		)

		if candidate.begins_with("res://"):
			if ResourceLoader.exists(candidate):
				return candidate
		elif FileAccess.file_exists(candidate):
			return candidate

	var directory := DirAccess.open(directory_path)

	if directory == null:
		return ""

	directory.list_dir_begin()

	while true:
		var entry: String = directory.get_next()

		if entry.is_empty():
			break

		if directory.current_is_dir():
			continue

		var resource_entry: String = _strip_import_mapping_suffix(entry)
		var extension: String = resource_entry.get_extension().to_lower()

		if not IMAGE_EXTENSIONS.has(extension):
			continue

		if resource_entry.get_basename().to_lower() != stem:
			continue

		directory.list_dir_end()
		return directory_path.path_join(resource_entry)

	directory.list_dir_end()
	return ""


static func _strip_import_mapping_suffix(entry: String) -> String:
	for suffix: String in [".import", ".remap"]:
		if entry.to_lower().ends_with(suffix):
			return entry.left(entry.length() - suffix.length())

	return entry

static func _load_texture(path: String) -> Texture2D:
	path = path.strip_edges()

	if path.is_empty():
		return null

	if path.begins_with("res://") and ResourceLoader.exists(path):
		var resource: Resource = ResourceLoader.load(path)

		if resource is Texture2D:
			return resource as Texture2D

	var image: Image = Image.load_from_file(path)

	if image == null or image.is_empty():
		return null

	return ImageTexture.create_from_image(image)
