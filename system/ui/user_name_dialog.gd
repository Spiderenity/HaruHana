extends Window
class_name UserNameDialog

signal finished(user_name: String)

const AppLanguageScript = preload("res://system/app/app_language.gd")
const AppearanceSettingsScript = preload("res://system/app/appearance_settings.gd")
const UserProfileSettingsScript = preload("res://system/app/user_profile_settings.gd")

var name_input: LineEdit = null
var result_emitted: bool = false

func _init() -> void:
	transient = true
	exclusive = true

func _ready() -> void:
	title = AppLanguageScript.text("Your name", "이름")
	size = Vector2i(430, 210)
	min_size = Vector2i(380, 190)
	unresizable = true

	close_requested.connect(_finish.bind(""))

	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.theme = AppearanceSettingsScript.build_theme()
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override(
		"separation",
		AppearanceSettingsScript.UI_STACK_GAP
	)
	margin.add_child(content)

	var heading := Label.new()
	heading.text = AppLanguageScript.text("What should I call you?", "뭐라고 부르면 돼?")
	heading.add_theme_font_size_override(
		"font_size",
		AppearanceSettingsScript.UI_FONT_LARGE
	)
	content.add_child(heading)

	var description := Label.new()
	description.text = AppLanguageScript.text(
		"Characters can use this name in dialogue. You can change it later in Settings.",
		"캐릭터가 대화에서 이 이름을 사용할 수 있어. 나중에 설정에서 바꿀 수 있어."
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override(
		"font_size",
		AppearanceSettingsScript.UI_FONT_SMALL
	)
	description.add_theme_color_override(
		"font_color",
		AppearanceSettingsScript.get_ui_color("muted")
	)
	content.add_child(description)

	content.add_child(HSeparator.new())

	name_input = LineEdit.new()
	name_input.placeholder_text = AppLanguageScript.text("Name", "이름")
	name_input.text = UserProfileSettingsScript.get_user_name()
	name_input.custom_minimum_size.y = AppearanceSettingsScript.UI_CONTROL_HEIGHT
	name_input.add_theme_font_size_override(
		"font_size",
		AppearanceSettingsScript.UI_FONT_MEDIUM
	)
	name_input.select_all_on_focus = false
	name_input.text_submitted.connect(_on_text_submitted)
	content.add_child(name_input)

	var buttons := HBoxContainer.new()
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", AppearanceSettingsScript.UI_COMPACT_GAP)
	content.add_child(buttons)

	var later_button := Button.new()
	later_button.text = AppLanguageScript.text("Later", "나중에")
	later_button.custom_minimum_size.y = AppearanceSettingsScript.UI_CONTROL_HEIGHT
	later_button.add_theme_font_size_override(
		"font_size",
		AppearanceSettingsScript.UI_FONT_MEDIUM
	)
	later_button.pressed.connect(_finish.bind(""))
	buttons.add_child(later_button)

	var save_button := Button.new()
	save_button.text = AppLanguageScript.text("Save", "저장")
	save_button.custom_minimum_size.y = AppearanceSettingsScript.UI_CONTROL_HEIGHT
	save_button.add_theme_font_size_override(
		"font_size",
		AppearanceSettingsScript.UI_FONT_MEDIUM
	)
	_style_primary_button(save_button)
	save_button.pressed.connect(_save)
	buttons.add_child(save_button)

func _style_primary_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = AppearanceSettingsScript.get_ui_color("selection")
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.content_margin_left = 14.0
	normal.content_margin_right = 14.0
	normal.content_margin_top = 7.0
	normal.content_margin_bottom = 7.0

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = AppearanceSettingsScript.get_ui_color("selection")

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("hover_pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func open_centered() -> void:
	var screen_index: int = DisplayServer.get_primary_screen()
	var usable_rect: Rect2i = DisplayServer.screen_get_usable_rect(screen_index)
	position = Vector2i(
		usable_rect.position.x + roundi(float(usable_rect.size.x - size.x) / 2.0),
		usable_rect.position.y + roundi(float(usable_rect.size.y - size.y) / 2.0)
	)
	show()
	call_deferred("_focus_name_input")

func _focus_name_input() -> void:
	if name_input == null:
		return

	name_input.grab_focus()
	name_input.deselect()
	name_input.caret_column = name_input.text.length()

func _on_text_submitted(_text: String) -> void:
	_save()

func _save() -> void:
	if name_input == null:
		_finish("")
		return

	var user_name: String = name_input.text.strip_edges()

	if user_name.is_empty():
		name_input.grab_focus()
		return

	var error: Error = UserProfileSettingsScript.set_user_name(user_name)

	if error != OK:
		return

	_finish(user_name)

func _finish(user_name: String) -> void:
	if result_emitted:
		return

	result_emitted = true
	finished.emit(user_name)
	queue_free()
