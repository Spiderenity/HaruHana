extends RefCounted
class_name AppearanceSettings

const DistributionPathsScript = preload(
	"res://system/app/distribution_paths.gd"
)

const MAIN_BACKGROUND_HEX: String = "#FCFCFC"
const SURFACE_HEX: String = "#FFFFFF"
const SOFT_GRAY_HEX: String = "#EFEFEF"
const DIVIDER_GRAY_HEX: String = "#E2E2E2"
const DARK_GRAY_HEX: String = "#0D0D0D"
const MUTED_TEXT_HEX: String = "#CACACA"
const SOFT_YELLOW_HEX: String = "#FDF6DC"
const ACCENT_YELLOW_HEX: String = "#F6C543"

const UI_FONT_LARGE: int = 20
const UI_FONT_MEDIUM: int = 16
const UI_FONT_SMALL: int = 13
const UI_CONTROL_HEIGHT: int = 38
const UI_INPUT_HORIZONTAL_PADDING: float = 10.0
const UI_INPUT_VERTICAL_PADDING: float = 7.0

const UI_STACK_GAP: int = 10
const UI_COMPACT_GAP: int = 8
const UI_TAB_MARGIN_BOTTOM: int = 8

const SETTINGS_PATH: String = "user://settings/appearance.json"

const DEFAULT_THEME: String = "lemona"
const DEFAULT_MODE: String = "system"
const DEFAULT_BUBBLE_FONT: String = "res://assets/fonts/NanumGoDigANiGoGoDing.ttf"
const DEFAULT_BUBBLE_FONT_SIZE: int = 28
const DEFAULT_BUBBLE_SKIN: String = "res://assets/bubbles/default"
const DEFAULT_BUBBLE_TEXT_COLOR: String = "#5F5F5F"
const BUBBLE_CONFIG_FILENAME: String = "bubble.json"

const FONT_DIRECTORY: String = "res://assets/fonts"
const USER_FONT_DIRECTORY: String = "user://fonts"
const BUBBLE_DIRECTORY: String = "res://assets/bubbles"

const FONT_EXTENSIONS: Array[String] = [
	"ttf",
	"otf",
	"woff",
	"woff2",
	"pfb",
	"pfm"
]

const BUBBLE_IMAGE_EXTENSIONS: Array[String] = [
	"png",
	"webp"
]

const BUBBLE_PART_NAMES: Array[String] = [
	"top",
	"middle",
	"bottom"
]

const THEME_IDS: Array[String] = [
	"lemona",
	"sakura",
	"ramune",
	"merona",
	"orange",
	"polapo"
]

const MODE_IDS: Array[String] = [
	"system",
	"light",
	"dark"
]

const THEME_COLORS: Dictionary = {
	"lemona": {"accent": "#F6C543", "light_selection": "#FDF6DC", "dark_selection": "#B8802B"},
	"sakura": {"accent": "#F077AF", "light_selection": "#FDEDF4", "dark_selection": "#CF6194"},
	"ramune": {"accent": "#3A83F7", "light_selection": "#E8F3FE", "dark_selection": "#2C67C5"},
	"merona": {"accent": "#53B559", "light_selection": "#DEF3E5", "dark_selection": "#48A04C"},
	"orange": {"accent": "#EE7C37", "light_selection": "#FBE8DB", "dark_selection": "#D25E28"},
	"polapo": {"accent": "#A67DF2", "light_selection": "#EDE5FC", "dark_selection": "#7849D1"}
}

const LEGACY_FONT_PATHS: Dictionary = {
	"ddobag": "res://assets/fonts/NanumDdoBagDdoBag.ttf",
	"donghwa": "res://assets/fonts/NanumDongHwaDdoBag.ttf",
	"square_round": "res://assets/fonts/NanumSquareRoundL.ttf",
	"square_neo": "res://assets/fonts/NanumSquareNeo-Variable.ttf"
}

static var _cached_settings: Dictionary = {}
static var _font_cache: Dictionary = {}
static var _texture_cache: Dictionary = {}

static func _normalize_theme_id(theme_id: String) -> String:
	var normalized: String = theme_id.strip_edges().to_lower()
	if normalized in ["cloud_dancer", "light", "dark"]:
		return "lemona"
	return normalized

static func _normalize_mode_id(mode_id: String) -> String:
	var normalized: String = mode_id.strip_edges().to_lower()
	if not MODE_IDS.has(normalized):
		return DEFAULT_MODE
	return normalized

static func load_settings() -> Dictionary:
	if not _cached_settings.is_empty():
		return _cached_settings.duplicate(true)

	var defaults: Dictionary = _get_default_settings()

	var loaded: Dictionary = JsonStore.load_dictionary(SETTINGS_PATH, defaults)
	var raw_theme_id: String = str(loaded.get("theme", DEFAULT_THEME)).strip_edges().to_lower()
	var theme_id: String = _normalize_theme_id(raw_theme_id)
	var mode_id: String = _normalize_mode_id(str(loaded.get("mode", DEFAULT_MODE)))
	if raw_theme_id == "dark":
		mode_id = "dark"
	elif raw_theme_id in ["light", "cloud_dancer"]:
		mode_id = "light"
	var bubble_font: String = _normalize_font_path(
		str(loaded.get("bubble_font", DEFAULT_BUBBLE_FONT))
	)
	var bubble_font_size: int = clampi(
		int(loaded.get("bubble_font_size", DEFAULT_BUBBLE_FONT_SIZE)),
		12,
		52
	)
	var bubble_skin: String = str(
		loaded.get("bubble_skin", DEFAULT_BUBBLE_SKIN)
	).strip_edges()

	if not THEME_IDS.has(theme_id):
		theme_id = DEFAULT_THEME

	if not _font_path_exists(bubble_font):
		bubble_font = _get_fallback_font_path()

	if not is_bubble_skin_valid(bubble_skin):
		bubble_skin = DEFAULT_BUBBLE_SKIN

	_cached_settings = {
		"theme": theme_id,
		"mode": mode_id,
		"bubble_font": bubble_font,
		"bubble_font_size": bubble_font_size,
		"bubble_skin": bubble_skin
	}

	return _cached_settings.duplicate(true)

static func save_settings(settings: Dictionary) -> Error:
	var current: Dictionary = load_settings()
	var theme_id: String = _normalize_theme_id(str(
		settings.get("theme", current.get("theme", DEFAULT_THEME))
	))
	var mode_id: String = _normalize_mode_id(str(
		settings.get("mode", current.get("mode", DEFAULT_MODE))
	))
	var bubble_font: String = _normalize_font_path(
		str(settings.get("bubble_font", current.get("bubble_font", DEFAULT_BUBBLE_FONT)))
	)
	var bubble_font_size: int = clampi(
		int(settings.get("bubble_font_size", current.get("bubble_font_size", DEFAULT_BUBBLE_FONT_SIZE))),
		12,
		52
	)
	var bubble_skin: String = str(
		settings.get("bubble_skin", current.get("bubble_skin", DEFAULT_BUBBLE_SKIN))
	).strip_edges()

	if not THEME_IDS.has(theme_id):
		theme_id = DEFAULT_THEME

	if not _font_path_exists(bubble_font):
		bubble_font = _get_fallback_font_path()

	if not is_bubble_skin_valid(bubble_skin):
		bubble_skin = DEFAULT_BUBBLE_SKIN

	var data: Dictionary = {
		"theme": theme_id,
		"mode": mode_id,
		"bubble_font": bubble_font,
		"bubble_font_size": bubble_font_size,
		"bubble_skin": bubble_skin
	}
	var save_error: Error = JsonStore.save_json(SETTINGS_PATH, data)
	if save_error != OK:
		return save_error
	_cached_settings = data
	return OK

static func clear_cache() -> void:
	_cached_settings.clear()

static func get_theme_id() -> String:
	return str(load_settings().get("theme", DEFAULT_THEME))

static func get_mode_id() -> String:
	return str(load_settings().get("mode", DEFAULT_MODE))

static func get_effective_mode() -> String:
	var configured: String = get_mode_id()
	if configured != "system":
		return configured
	if DisplayServer.is_dark_mode_supported() and DisplayServer.is_dark_mode():
		return "dark"
	return "light"

static func get_theme_signature() -> String:
	return get_theme_id() + ":" + get_mode_id() + ":" + get_effective_mode()

static func get_ui_color(role: String) -> Color:
	var palette: Dictionary = _get_palette(get_theme_id(), get_effective_mode())
	var normalized_role: String = role.strip_edges().to_lower()
	if normalized_role == "text_muted":
		normalized_role = "muted"
	elif normalized_role == "hover":
		normalized_role = "surface_hover"
	elif normalized_role == "pressed":
		normalized_role = "surface_pressed"
	if palette.has(normalized_role):
		return palette[normalized_role]
	return palette.get("text", Color.html(DARK_GRAY_HEX))

static func get_bubble_font_path() -> String:
	return str(load_settings().get("bubble_font", DEFAULT_BUBBLE_FONT))

static func get_bubble_font_id() -> String:
	return get_bubble_font_path()

static func get_bubble_font_size() -> int:
	return int(load_settings().get("bubble_font_size", DEFAULT_BUBBLE_FONT_SIZE))

static func get_bubble_skin_path() -> String:
	return str(load_settings().get("bubble_skin", DEFAULT_BUBBLE_SKIN))

static func _get_default_settings() -> Dictionary:
	return {
		"theme": DEFAULT_THEME,
		"mode": DEFAULT_MODE,
		"bubble_font": _get_fallback_font_path(),
		"bubble_font_size": DEFAULT_BUBBLE_FONT_SIZE,
		"bubble_skin": DEFAULT_BUBBLE_SKIN
	}

static func _normalize_font_path(value: String) -> String:
	var cleaned: String = value.strip_edges()
	var legacy_key: String = cleaned.to_lower()

	if LEGACY_FONT_PATHS.has(legacy_key):
		return str(LEGACY_FONT_PATHS[legacy_key])

	return cleaned

static func _ensure_directory(path: String) -> Error:
	var absolute_path: String = path
	if path.begins_with("res://") or path.begins_with("user://"):
		absolute_path = ProjectSettings.globalize_path(path)
	var error: Error = DirAccess.make_dir_recursive_absolute(absolute_path)

	if error == ERR_ALREADY_EXISTS:
		return OK

	return error

static func ensure_user_directories() -> void:
	_ensure_directory(USER_FONT_DIRECTORY)
	_ensure_directory(get_user_bubble_directory_path())

static func get_available_fonts() -> Array[Dictionary]:
	ensure_user_directories()

	var paths: Array[String] = []
	_collect_files(FONT_DIRECTORY, FONT_EXTENSIONS, paths)
	_collect_files(USER_FONT_DIRECTORY, FONT_EXTENSIONS, paths)
	paths.sort()

	var result: Array[Dictionary] = []
	var used_labels: Dictionary = {}

	for path: String in paths:
		var label: String = path.get_file().get_basename()

		if used_labels.has(label.to_lower()):
			label += " (User)" if path.begins_with("user://") else " (Built-in)"

		used_labels[label.to_lower()] = true
		result.append({
			"label": label,
			"path": path
		})

	return result

static func get_bubble_font(font_path: String = "") -> Font:
	font_path = _normalize_font_path(font_path)

	if font_path.is_empty():
		font_path = get_bubble_font_path()

	return _load_font(font_path)

static func get_ui_font() -> Font:
	var preferred_path: String = (
		"res://assets/fonts/NanumSquareRoundR.ttf"
		if get_effective_mode() == "dark"
		else "res://assets/fonts/NanumSquareNeo-Variable.ttf"
	)
	var font: Font = _load_font(preferred_path)

	if font == null:
		font = _load_font(
			"res://assets/fonts/NanumSquareRoundR.ttf"
			if get_effective_mode() == "dark"
			else "res://assets/fonts/NanumSquareRoundL.ttf"
		)

	return font

static func get_round_ui_font() -> Font:
	var font: Font = _load_font(
		"res://assets/fonts/NanumSquareRoundL.ttf"
	)

	if font == null:
		font = _load_font(
			"res://assets/fonts/NanumSquareNeo-Variable.ttf"
		)

	return font

static func get_user_font_directory_path() -> String:
	ensure_user_directories()
	return ProjectSettings.globalize_path(USER_FONT_DIRECTORY)

static func _load_font(path: String) -> Font:
	if path.is_empty():
		return null

	if _font_cache.has(path):
		return _font_cache[path]

	var font: Font = null

	if path.begins_with("res://"):
		if ResourceLoader.exists(path):
			var resource: Resource = ResourceLoader.load(path)

			if resource is Font:
				font = resource
	else:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		var dynamic_font: FontFile = FontFile.new()

		if dynamic_font.load_dynamic_font(absolute_path) == OK:
			font = dynamic_font

	if font != null:
		_font_cache[path] = font

	return font

static func _font_path_exists(path: String) -> bool:
	if path.is_empty():
		return false

	if path.begins_with("res://"):
		return ResourceLoader.exists(path) or FileAccess.file_exists(path)

	return FileAccess.file_exists(path)

static func _get_fallback_font_path() -> String:
	if _font_path_exists(DEFAULT_BUBBLE_FONT):
		return DEFAULT_BUBBLE_FONT

	var fonts: Array[Dictionary] = get_available_fonts()

	if fonts.is_empty():
		return ""

	return str(fonts[0].get("path", ""))

static func get_available_bubbles() -> Array[Dictionary]:
	ensure_user_directories()

	var result: Array[Dictionary] = []

	if is_bubble_skin_valid(DEFAULT_BUBBLE_SKIN):
		result.append({
			"label": "",
			"path": DEFAULT_BUBBLE_SKIN,
			"builtin": true
		})

	_collect_bubble_skin_directories(
		BUBBLE_DIRECTORY,
		result
	)
	var external_directory: String = get_user_bubble_directory_path()
	if external_directory != ProjectSettings.globalize_path(BUBBLE_DIRECTORY):
		_collect_bubble_skin_directories(
			external_directory,
			result
		)

	return result

static func is_bubble_skin_valid(skin_path: String) -> bool:
	if skin_path.strip_edges().is_empty():
		return false

	for part_name: String in BUBBLE_PART_NAMES:
		if _find_bubble_part_path(skin_path, part_name).is_empty():
			return false

	var config: Dictionary = _load_bubble_skin_config(skin_path)
	return not str(config.get("text_color", "")).strip_edges().is_empty()

static func get_bubble_skin_config(
	skin_path: String = ""
) -> Dictionary:
	if skin_path.strip_edges().is_empty():
		skin_path = get_bubble_skin_path()

	var config: Dictionary = _load_bubble_skin_config(skin_path)

	if config.is_empty() and skin_path != DEFAULT_BUBBLE_SKIN:
		config = _load_bubble_skin_config(DEFAULT_BUBBLE_SKIN)

	return config

static func get_bubble_skin_text_color(
	skin_path: String = ""
) -> Color:
	var config: Dictionary = get_bubble_skin_config(skin_path)
	var color_text: String = str(
		config.get("text_color", DEFAULT_BUBBLE_TEXT_COLOR)
	).strip_edges()

	return Color.from_string(
		color_text,
		Color.from_string(DEFAULT_BUBBLE_TEXT_COLOR, Color.BLACK)
	)

static func _load_bubble_skin_config(
	skin_path: String
) -> Dictionary:
	if skin_path.strip_edges().is_empty():
		return {}

	var config_path: String = skin_path.path_join(BUBBLE_CONFIG_FILENAME)
	var readable_path: String = _resolve_readable_file_path(config_path)

	if readable_path.is_empty():
		return {}

	var file: FileAccess = FileAccess.open(readable_path, FileAccess.READ)

	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if not (parsed is Dictionary):
		return {}

	return (parsed as Dictionary).duplicate(true)

static func get_bubble_skin_textures(
	skin_path: String = ""
) -> Dictionary:
	if skin_path.strip_edges().is_empty():
		skin_path = get_bubble_skin_path()

	if not is_bubble_skin_valid(skin_path):
		skin_path = DEFAULT_BUBBLE_SKIN

	var result: Dictionary = {}

	for part_name: String in BUBBLE_PART_NAMES:
		var part_path: String = _find_bubble_part_path(
			skin_path,
			part_name
		)

		if part_path.is_empty():
			return {}

		var texture: Texture2D = _load_bubble_texture(part_path)

		if texture == null:
			return {}

		result[part_name] = texture

	return result

static func _collect_bubble_skin_directories(
	root_path: String,
	result: Array[Dictionary]
) -> void:
	var directory: DirAccess = DirAccess.open(root_path)

	if directory == null:
		return

	directory.list_dir_begin()
	var entry: String = directory.get_next()

	while not entry.is_empty():
		if directory.current_is_dir() and not entry.begins_with("."):
			var skin_path: String = root_path.path_join(entry)

			if skin_path != DEFAULT_BUBBLE_SKIN and is_bubble_skin_valid(skin_path):
				result.append({
					"label": entry,
					"path": skin_path,
					"builtin": false
				})

		entry = directory.get_next()

	directory.list_dir_end()

static func _find_bubble_part_path(
	skin_path: String,
	part_name: String
) -> String:
	for extension: String in BUBBLE_IMAGE_EXTENSIONS:
		var candidate: String = skin_path.path_join(
			part_name + "." + extension
		)

		if _bubble_file_exists(candidate):
			return candidate

	return ""

static func get_user_bubble_directory_path() -> String:
	return DistributionPathsScript.get_bubbles_directory()

static func _load_bubble_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]

	if path.begins_with("res://") and ResourceLoader.exists(path):
		var resource: Resource = ResourceLoader.load(path)

		if resource is Texture2D:
			_texture_cache[path] = resource
			return resource as Texture2D

	var readable_path: String = _resolve_readable_file_path(path)

	if readable_path.is_empty():
		return null

	var image: Image = Image.load_from_file(readable_path)

	if image == null or image.is_empty():
		return null

	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_texture_cache[path] = texture
	return texture

static func _bubble_file_exists(path: String) -> bool:
	if path.begins_with("res://") and ResourceLoader.exists(path):
		return true

	return not _resolve_readable_file_path(path).is_empty()

static func _resolve_readable_file_path(path: String) -> String:
	if path.strip_edges().is_empty():
		return ""

	if FileAccess.file_exists(path):
		return path

	if path.begins_with("res://") or path.begins_with("user://"):
		var absolute_path: String = ProjectSettings.globalize_path(path)

		if FileAccess.file_exists(absolute_path):
			return absolute_path

	return ""

static func _collect_files(
	directory_path: String,
	extensions: Array[String],
	result: Array[String]
) -> void:
	var directory: DirAccess = DirAccess.open(directory_path)

	if directory == null:
		return

	directory.list_dir_begin()
	var entry: String = directory.get_next()

	while not entry.is_empty():
		if not directory.current_is_dir():
			var extension: String = entry.get_extension().to_lower()

			if extensions.has(extension):
				result.append(directory_path.path_join(entry))

		entry = directory.get_next()

	directory.list_dir_end()

static func build_theme(theme_id: String = "") -> Theme:
	theme_id = theme_id.strip_edges().to_lower()

	if theme_id.is_empty():
		theme_id = get_theme_id()

	var palette: Dictionary = _get_palette(theme_id, get_effective_mode())
	var result: Theme = Theme.new()
	var ui_font: Font = get_ui_font()

	if ui_font != null:
		result.default_font = ui_font
		for theme_type: String in [
			"Label",
			"Button",
			"OptionButton",
			"CheckBox",
			"LineEdit",
			"TextEdit",
			"PopupMenu",
			"TabBar",
			"TabContainer",
			"Tree",
			"ItemList"
		]:
			result.set_font("font", theme_type, ui_font)

	result.default_font_size = UI_FONT_MEDIUM

	_apply_colors(result, palette)
	_apply_styleboxes(result, palette)
	return result

static func _get_palette(theme_id: String, mode_id: String = "") -> Dictionary:
	var normalized_theme: String = _normalize_theme_id(theme_id)
	if not THEME_IDS.has(normalized_theme):
		normalized_theme = DEFAULT_THEME
	var colors: Dictionary = THEME_COLORS.get(normalized_theme, THEME_COLORS[DEFAULT_THEME])
	var accent: Color = Color.html(str(colors.get("accent", "#F6C543")))
	var effective_mode: String = mode_id.strip_edges().to_lower()
	if effective_mode.is_empty():
		effective_mode = get_effective_mode()

	if effective_mode == "dark":
		return {
			"background": Color.html("#181818"),
			"surface": Color.html("#212121"),
			"surface_alt": Color.html("#414141"),
			"secondary": Color.html("#303030"),
			"surface_hover": Color.html("#181818"),
			"surface_pressed": Color.html("#0D0D0D"),
			"text": Color.html("#FFFFFF"),
			"muted": Color.html("#CDCDCD"),
			"text_faint": Color.html("#AFAFAF"),
			"border": Color.html("#303030"),
			"border_light": Color.html("#303030"),
			"border_heavy": Color.html("#FFFFFF33"),
			"scrollbar": Color.html("#FFFFFF1A"),
			"scroll_hover": Color.html("#FFFFFF33"),
			"accent": accent,
			"selection": Color.html(str(colors.get("dark_selection", "#B8802B")))
		}

	return {
		"background": Color.html("#F9F9F9"),
		"surface": Color.html("#FFFFFF"),
		"surface_alt": Color.html("#F3F3F3"),
		"secondary": Color.html("#E8E8E8"),
		"surface_hover": Color.html("#F9F9F9"),
		"surface_pressed": Color.html("#F3F3F3"),
		"text": Color.html("#0D0D0D"),
		"muted": Color.html("#5D5D5D"),
		"text_faint": Color.html("#8F8F8F"),
		"border": Color.html("#E8E8E8"),
		"border_light": Color.html("#E8E8E8"),
		"border_heavy": Color.html("#00000033"),
		"scrollbar": Color.html("#0000001A"),
		"scroll_hover": Color.html("#00000033"),
		"accent": accent,
		"selection": Color.html(str(colors.get("light_selection", SOFT_YELLOW_HEX)))
	}

static func _apply_colors(
	theme: Theme,
	palette: Dictionary
) -> void:
	var text: Color = palette["text"]
	var muted: Color = palette["muted"]
	var accent: Color = palette["accent"]
	var selection: Color = palette["selection"]

	for theme_type: String in [
		"Label",
		"Button",
		"OptionButton",
		"CheckBox",
		"LineEdit",
		"TextEdit",
		"PopupMenu",
		"TabBar",
		"TabContainer",
		"Tree",
		"ItemList"
	]:
		theme.set_color("font_color", theme_type, text)

	for theme_type: String in [
		"Button",
		"OptionButton",
		"CheckBox",
		"TabBar",
		"TabContainer"
	]:
		theme.set_color("font_hover_color", theme_type, text)
		theme.set_color("font_pressed_color", theme_type, text)
		theme.set_color("font_hover_pressed_color", theme_type, text)
		theme.set_color("font_focus_color", theme_type, text)
		theme.set_color("font_disabled_color", theme_type, muted)

	for theme_type: String in ["LineEdit", "TextEdit"]:
		theme.set_color("font_placeholder_color", theme_type, muted)
		theme.set_color("font_uneditable_color", theme_type, text)
		theme.set_color("font_selected_color", theme_type, text)
		theme.set_color("selection_color", theme_type, selection)
		theme.set_color("caret_color", theme_type, accent)

	theme.set_color("font_hover_color", "PopupMenu", text)
	theme.set_color("font_disabled_color", "PopupMenu", muted)
	theme.set_color("font_accelerator_color", "PopupMenu", muted)
	theme.set_color("font_separator_color", "PopupMenu", muted)
	theme.set_color("font_color", "TooltipLabel", text)

	theme.set_color("font_selected_color", "TabBar", text)
	theme.set_color("font_unselected_color", "TabBar", muted)
	theme.set_color("font_hovered_color", "TabBar", text)
	theme.set_color("font_selected_color", "TabContainer", text)
	theme.set_color("font_unselected_color", "TabContainer", muted)
	theme.set_color("font_hovered_color", "TabContainer", text)

static func _apply_styleboxes(
	theme: Theme,
	palette: Dictionary
) -> void:
	var background: Color = palette["background"]
	var surface: Color = palette["surface"]
	var secondary: Color = palette["secondary"]
	var surface_alt: Color = palette["surface_alt"]
	var surface_hover: Color = palette["surface_hover"]
	var surface_pressed: Color = palette["surface_pressed"]
	var border: Color = palette["border"]
	var text: Color = palette["text"]
	var muted: Color = palette["muted"]
	var accent: Color = palette["accent"]
	var selection: Color = palette["selection"]
	var border_light: Color = secondary
	var border_heavy: Color = accent
	var scrollbar_color: Color = palette.get("scrollbar", secondary)
	var scroll_hover_color: Color = palette.get("scroll_hover", muted)

	theme.set_stylebox(
		"panel",
		"PanelContainer",
		_make_box(background, border, 0, 0.0)
	)
	theme.set_stylebox(
		"panel",
		"TabContainer",
		_make_box(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 0, 0.0)
	)

	var button_normal: StyleBoxFlat = _make_box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 9, 0.0)
	var button_hover: StyleBoxFlat = _make_box(surface_hover, surface_hover, 9, 0.0)
	var button_pressed: StyleBoxFlat = _make_box(surface_pressed, surface_pressed, 9, 0.0)

	theme.set_stylebox("normal", "Button", button_normal)
	theme.set_stylebox("hover", "Button", button_hover)
	theme.set_stylebox("pressed", "Button", button_pressed)
	theme.set_stylebox("hover_pressed", "Button", button_pressed)
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.set_stylebox(
		"disabled",
		"Button",
		_make_box(surface_alt, surface_alt, 9, 0.0)
	)

	var option_normal: StyleBoxFlat = _make_box(surface, border_light, 9, 1.0)
	var option_hover: StyleBoxFlat = _make_box(surface_hover, surface_hover, 9, 0.0)
	option_hover.content_margin_left = 12.0
	var option_pressed: StyleBoxFlat = _make_box(surface_pressed, surface_pressed, 9, 0.0)
	option_pressed.content_margin_left = 12.0
	theme.set_stylebox("normal", "OptionButton", option_normal)
	theme.set_stylebox("hover", "OptionButton", option_hover)
	theme.set_stylebox("pressed", "OptionButton", option_pressed)
	theme.set_stylebox(
		"focus",
		"OptionButton",
		_make_box(Color(0, 0, 0, 0), border_heavy, 9, 1.0)
	)
	theme.set_stylebox(
		"disabled",
		"OptionButton",
		_make_box(surface_alt, surface_alt, 9, 0.0)
	)

	var check_normal := StyleBoxFlat.new()
	check_normal.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	check_normal.content_margin_left = 0.0
	var check_hover: StyleBoxFlat = check_normal.duplicate()
	theme.set_stylebox("normal", "CheckBox", check_normal)
	theme.set_stylebox("hover", "CheckBox", check_hover)
	theme.set_stylebox("pressed", "CheckBox", check_hover)
	theme.set_stylebox("hover_pressed", "CheckBox", check_hover)
	theme.set_stylebox("focus", "CheckBox", StyleBoxEmpty.new())
	theme.set_stylebox("disabled", "CheckBox", check_normal)
	theme.set_icon("unchecked", "CheckBox", _make_checkbox_icon(false, false, secondary, accent))
	theme.set_icon("checked", "CheckBox", _make_checkbox_icon(true, false, secondary, accent))
	theme.set_icon("unchecked_disabled", "CheckBox", _make_checkbox_icon(false, true, secondary, accent))
	theme.set_icon("checked_disabled", "CheckBox", _make_checkbox_icon(true, true, secondary, accent))
	theme.set_constant("h_separation", "CheckBox", 7)

	for theme_type: String in ["LineEdit", "TextEdit"]:
		theme.set_stylebox(
			"normal",
			theme_type,
			_make_box(surface, border_light, 8, 1.0)
		)
		theme.set_stylebox(
			"focus",
			theme_type,
			_make_box(surface, border_heavy, 8, 1.0)
		)
		theme.set_stylebox(
			"read_only",
			theme_type,
			_make_box(surface_alt, surface_alt, 8, 0.0)
		)

	theme.set_stylebox(
		"panel",
		"PopupMenu",
		_make_box(surface, border_light, 8, 1.0)
	)
	theme.set_stylebox(
		"hover",
		"PopupMenu",
		_make_box(surface_hover, surface_hover, 6, 0.0)
	)

	theme.set_stylebox(
		"panel",
		"TooltipPanel",
		_make_box(surface_alt, surface_alt, 7, 0.0)
	)

	for theme_type: String in ["TabBar", "TabContainer"]:
		theme.set_stylebox(
			"tab_unselected",
			theme_type,
			_make_box(surface, border_light, 8, 1.0)
		)
		theme.set_stylebox(
			"tab_hovered",
			theme_type,
			_make_box(surface_hover, surface_hover, 8, 0.0)
		)
		theme.set_stylebox(
			"tab_selected",
			theme_type,
			_make_box(surface_pressed, surface_pressed, 8, 0.0)
		)

	for theme_type: String in ["ItemList", "Tree"]:
		theme.set_stylebox(
			"panel",
			theme_type,
			_make_box(surface, border_light, 10, 1.0)
		)
		theme.set_stylebox(
			"focus",
			theme_type,
			_make_box(Color(0, 0, 0, 0), accent, 10, 1.0)
		)
		theme.set_stylebox(
			"selected",
			theme_type,
			_make_box(selection, selection, 8, 0.0)
		)
		theme.set_stylebox(
			"selected_focus",
			theme_type,
			_make_box(selection, selection, 8, 0.0)
		)

	var slider_track: StyleBoxFlat = StyleBoxFlat.new()
	slider_track.bg_color = surface_pressed
	slider_track.corner_radius_top_left = 4
	slider_track.corner_radius_top_right = 4
	slider_track.corner_radius_bottom_left = 4
	slider_track.corner_radius_bottom_right = 4
	slider_track.content_margin_top = 4.0
	slider_track.content_margin_bottom = 4.0

	var slider_fill: StyleBoxFlat = slider_track.duplicate()
	slider_fill.bg_color = accent

	for slider_type: String in ["HSlider", "VSlider"]:
		theme.set_stylebox("slider", slider_type, slider_track)
		theme.set_stylebox("grabber_area", slider_type, slider_fill)
		theme.set_stylebox("grabber_area_highlight", slider_type, slider_fill)
		theme.set_icon("grabber", slider_type, _make_round_texture(text, 18))
		theme.set_icon(
			"grabber_highlight",
			slider_type,
			_make_round_texture(text, 20)
		)

	var clear_scroll: StyleBoxFlat = StyleBoxFlat.new()
	clear_scroll.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	var scroll_grabber: StyleBoxFlat = StyleBoxFlat.new()
	scroll_grabber.bg_color = scrollbar_color
	scroll_grabber.corner_radius_top_left = 6
	scroll_grabber.corner_radius_top_right = 6
	scroll_grabber.corner_radius_bottom_left = 6
	scroll_grabber.corner_radius_bottom_right = 6
	var scroll_hover: StyleBoxFlat = scroll_grabber.duplicate()
	scroll_hover.bg_color = scroll_hover_color
	var scroll_pressed: StyleBoxFlat = scroll_grabber.duplicate()
	scroll_pressed.bg_color = scroll_hover_color

	for scroll_type: String in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", scroll_type, clear_scroll)
		theme.set_stylebox("scroll_focus", scroll_type, clear_scroll)
		theme.set_stylebox("grabber", scroll_type, scroll_grabber)
		theme.set_stylebox("grabber_highlight", scroll_type, scroll_hover)
		theme.set_stylebox("grabber_pressed", scroll_type, scroll_pressed)

	var separator: StyleBoxLine = StyleBoxLine.new()
	separator.color = border
	separator.thickness = 1
	theme.set_stylebox("separator", "HSeparator", separator)

static func _make_checkbox_icon(
	checked: bool,
	disabled: bool,
	unchecked_color: Color,
	checked_color: Color
) -> Texture2D:
	var size: int = 18
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))

	var fill_color: Color = checked_color if checked else unchecked_color
	if disabled:
		fill_color.a *= 0.55

	var left: int = 2
	var top: int = 2
	var right: int = size - 3
	var bottom: int = size - 3
	var radius: int = 4
	for y: int in range(top, bottom + 1):
		for x: int in range(left, right + 1):
			var nearest_x: int = clampi(x, left + radius, right - radius)
			var nearest_y: int = clampi(y, top + radius, bottom - radius)
			var dx: int = x - nearest_x
			var dy: int = y - nearest_y
			if dx * dx + dy * dy <= radius * radius:
				image.set_pixel(x, y, fill_color)

	if checked:
		var luminance: float = (
			checked_color.r * 0.299
			+ checked_color.g * 0.587
			+ checked_color.b * 0.114
		)
		var mark_color: Color = (
			Color.html("#0D0D0D")
			if luminance >= 0.58
			else Color.WHITE
		)
		if disabled:
			mark_color.a = 0.55
		var points: Array[Vector2i] = [
			Vector2i(5, 9), Vector2i(6, 10), Vector2i(7, 11),
			Vector2i(8, 10), Vector2i(9, 9), Vector2i(10, 8),
			Vector2i(11, 7), Vector2i(12, 6)
		]
		for point: Vector2i in points:
			for y_offset: int in range(2):
				image.set_pixel(point.x, point.y + y_offset, mark_color)

	return ImageTexture.create_from_image(image)

static func _make_round_texture(color: Color, diameter: int) -> Texture2D:
	var size: int = maxi(2, diameter)
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center: float = (float(size) - 1.0) * 0.5
	var radius: float = center
	for y: int in range(size):
		for x: int in range(size):
			var dx: float = float(x) - center
			var dy: float = float(y) - center
			if dx * dx + dy * dy <= radius * radius:
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

static func _make_box(
	background: Color,
	border: Color,
	radius: int,
	border_width: float
) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	var width: int = int(round(border_width))
	box.border_width_left = width
	box.border_width_top = width
	box.border_width_right = width
	box.border_width_bottom = width
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = UI_INPUT_HORIZONTAL_PADDING
	box.content_margin_top = UI_INPUT_VERTICAL_PADDING
	box.content_margin_right = UI_INPUT_HORIZONTAL_PADDING
	box.content_margin_bottom = UI_INPUT_VERTICAL_PADDING
	return box
