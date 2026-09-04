extends RefCounted
class_name CreatorTheme

const AppearanceSettingsScript = preload("res://system/app/appearance_settings.gd")

const FONT_LARGE: int = AppearanceSettingsScript.UI_FONT_LARGE
const FONT_MEDIUM: int = AppearanceSettingsScript.UI_FONT_MEDIUM
const FONT_SMALL: int = AppearanceSettingsScript.UI_FONT_SMALL
const CONTROL_HEIGHT: int = AppearanceSettingsScript.UI_CONTROL_HEIGHT

static func build() -> Theme:
	return AppearanceSettingsScript.build_theme()

static func background() -> Color:
	return AppearanceSettingsScript.get_ui_color("background")

static func surface() -> Color:
	return AppearanceSettingsScript.get_ui_color("surface")

static func border() -> Color:
	return AppearanceSettingsScript.get_ui_color("secondary")

static func muted() -> Color:
	return AppearanceSettingsScript.get_ui_color("muted")

static func accent() -> Color:
	return AppearanceSettingsScript.get_ui_color("accent")

static func soft_accent() -> Color:
	return AppearanceSettingsScript.get_ui_color("selection")

static func hover() -> Color:
	return AppearanceSettingsScript.get_ui_color("surface_hover")

static func danger() -> Color:
	return Color("#B74747")

static func success() -> Color:
	return Color("#4D7A5C")

static func box(background_color: Color, border_color: Color, radius: int = 10, width: float = 1.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(int(width))
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = AppearanceSettingsScript.UI_INPUT_HORIZONTAL_PADDING
	style.content_margin_right = AppearanceSettingsScript.UI_INPUT_HORIZONTAL_PADDING
	style.content_margin_top = AppearanceSettingsScript.UI_INPUT_VERTICAL_PADDING
	style.content_margin_bottom = AppearanceSettingsScript.UI_INPUT_VERTICAL_PADDING
	return style

static func card() -> StyleBoxFlat:
	return box(surface(), border(), 12, 1.0)

static func accent_card() -> StyleBoxFlat:
	return box(soft_accent(), accent(), 12, 1.0)

static func board_panel() -> StyleBoxFlat:
	return _board_box(surface(), border(), 12)

static func subpanel() -> StyleBoxFlat:
	return _board_box(surface(), border(), 10)

static func row_panel() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = border()
	style.border_width_bottom = 1
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 6.0
	return style

static func nav_style(state: String) -> StyleBoxFlat:
	var background_color: Color = Color(0.0, 0.0, 0.0, 0.0)
	if state == "hover":
		background_color = AppearanceSettingsScript.get_ui_color("surface_hover")
	elif state == "pressed":
		background_color = AppearanceSettingsScript.get_ui_color("selection")
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	style.set_content_margin(SIDE_LEFT, 16.0)
	style.set_content_margin(SIDE_RIGHT, 12.0)
	style.set_content_margin(SIDE_TOP, 9.0)
	style.set_content_margin(SIDE_BOTTOM, 9.0)
	return style

static func nav_text_color() -> Color:
	return AppearanceSettingsScript.get_ui_color("text")

static func _board_box(background_color: Color, border_color: Color, radius: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
