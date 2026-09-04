extends LineEdit
class_name ThemedCreatorColorPicker

const ThemeKit = preload("res://system/tools/character_creator/scripts/creator_theme.gd")
const AppLanguageScript = preload("res://system/app/app_language.gd")
const AppearanceSettingsScript = preload("res://system/app/appearance_settings.gd")

var picker_window: Window
var picker: ColorPicker
var done_button: Button
var popup_background: ColorRect
var popup_panel: PanelContainer
var last_language := ""
var last_theme := ""

func _ready() -> void:
	editable = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(_on_input)
	_build_popup()
	_refresh_swatch()
	text_changed.connect(func(_value: String) -> void: _refresh_swatch())

func _build_popup() -> void:
	picker_window = Window.new()
	picker_window.title = "Color Picker"
	picker_window.size = Vector2i(540, 680)
	picker_window.min_size = Vector2i(480, 600)
	picker_window.mode = Window.MODE_WINDOWED
	picker_window.borderless = false
	picker_window.unresizable = false
	picker_window.unfocusable = false
	picker_window.always_on_top = false
	picker_window.transient = true
	picker_window.transparent = false
	picker_window.transparent_bg = false
	picker_window.visible = false
	picker_window.theme = ThemeKit.build()
	picker_window.close_requested.connect(picker_window.hide)
	add_child(picker_window)
	picker_window.hide()
	popup_background = ColorRect.new()
	popup_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_background.color = ThemeKit.background()
	picker_window.add_child(popup_background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	picker_window.add_child(margin)
	popup_panel = PanelContainer.new()
	popup_panel.add_theme_stylebox_override("panel", ThemeKit.board_panel())
	margin.add_child(popup_panel)
	var inner := MarginContainer.new()
	for side: String in ["left", "top", "right", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 14)
	popup_panel.add_child(inner)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	inner.add_child(box)
	var picker_scroll := ScrollContainer.new()
	picker_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picker_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(picker_scroll)
	picker = ColorPicker.new()
	picker.picker_shape = ColorPicker.SHAPE_HSV_WHEEL
	picker.color_mode = ColorPicker.MODE_HSV
	picker.presets_visible = false
	picker.custom_minimum_size = Vector2(440, 650)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picker.color_changed.connect(_picked)
	picker_scroll.add_child(picker)
	done_button = Button.new()
	done_button.custom_minimum_size = Vector2(120, 40)
	done_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	done_button.pressed.connect(picker_window.hide)
	box.add_child(done_button)
	set_process(true)

func _process(_delta: float) -> void:
	var language_code := AppLanguageScript.get_language()
	if language_code != last_language:
		picker_window.title = AppLanguageScript.text("Color Picker", "색상 선택")
		done_button.text = AppLanguageScript.text("Done", "완료")
		last_language = language_code
	var theme_id := AppearanceSettingsScript.get_theme_signature()
	if theme_id != last_theme:
		picker_window.theme = ThemeKit.build()
		popup_background.color = ThemeKit.background()
		popup_panel.add_theme_stylebox_override("panel", ThemeKit.board_panel())
		last_theme = theme_id

func _on_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and (event as InputEventMouseButton).pressed
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	):
		picker.color = Color.html(text) if Color.html_is_valid(text) else Color.WHITE
		picker_window.popup_centered()
		accept_event()

func _picked(value: Color) -> void:
	text = "#" + value.to_html(false).to_upper()
	text_changed.emit(text)

func _refresh_swatch() -> void:
	var value := Color.html(text) if Color.html_is_valid(text) else ThemeKit.nav_text_color()
	add_theme_color_override("font_color", value)
	add_theme_color_override("font_uneditable_color", value)
