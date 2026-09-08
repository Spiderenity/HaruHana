extends VBoxContainer
class_name CalendarPanel

signal schedules_changed

const ScheduleStoreScript = preload(
	"res://system/services/calendar/schedule_store.gd"
)

const AppLanguageScript = preload(
	"res://system/app/app_language.gd"
)

const AppearanceSettingsScript = preload(
	"res://system/app/appearance_settings.gd"
)

const STAR_TEXTURE: Texture2D = preload("res://assets/ui/star.png")
const FOCUS_HISTORY_DIRECTORY: String = "user://calendar"
const FOCUS_HISTORY_PATH: String = "user://calendar/focus_days.json"
const LEGACY_WEEKLY_PATH: String = "user://productivity/current_week.json"
const PRODUCTIVE_FOCUS_MINUTES: int = 30

const CALENDAR_DAY_FONT_SIZE: int = 17

const SPACE_XS: int = 4
const SPACE_SM: int = 8
const SPACE_MD: int = 16
const SPACE_LG: int = 24
const CONTROL_HEIGHT: float = 36.0

const WEEKDAY_NAMES: Array[String] = [
	"Sun",
	"Mon",
	"Tue",
	"Wed",
	"Thu",
	"Fri",
	"Sat"
]

const REMINDER_VALUES: Array[int] = [
	-1,
	0,
	5,
	10,
	15,
	30,
	60
]

const REMINDER_LABELS: Array[String] = [
	"No reminder",
	"At start",
	"5 min before",
	"10 min before",
	"15 min before",
	"30 min before",
	"1 hour before"
]

var schedules: Array[Dictionary] = []

var display_year: int = 1970
var display_month: int = 1
var selected_day: int = 1
var editing_schedule_id: String = ""

var year_menu: MenuButton
var month_menu: MenuButton
var selected_date_label: Label
var toolbar_add_button: Button
var selected_date_schedule_box: VBoxContainer
var editor_container: MarginContainer
var editor_heading_label: Label
var cancel_button: Button
var section_cards: Array[PanelContainer] = []

var day_buttons: Array[Button] = []
var day_number_labels: Array[Label] = []
var day_sticker_icons: Array[TextureRect] = []
var weekday_labels: Array[Label] = []
var weekday_checks: Array[Button] = []
var yearly_check: CheckBox = null

var title_input: LineEdit
var hour_input: SpinBox
var minute_input: SpinBox
var reminder_input: OptionButton

var save_button: Button
var delete_button: Button
var editor_status_label: Label

var productive_dates: Dictionary = {}

func _ready() -> void:
	add_theme_constant_override(
		"separation",
		AppearanceSettingsScript.UI_STACK_GAP
	)

	var now: Dictionary = (
		Time.get_datetime_dict_from_system()
	)

	display_year = int(
		now.get(
			"year",
			1970
		)
	)

	display_month = int(
		now.get(
			"month",
			1
		)
	)

	selected_day = int(
		now.get(
			"day",
			1
		)
	)

	reload_schedules()
	_load_focus_history()
	_discard_legacy_weekly_records()
	create_interface()
	refresh_all()
	apply_language()
	apply_appearance()

func _l(english: String, korean: String) -> String:
	return AppLanguageScript.text(english, korean)

func _bind_localized_text(
	control: Object,
	english: String,
	korean: String,
	property_name: String = "text"
) -> void:
	control.set_meta("_language_en_" + property_name, english)
	control.set_meta("_language_ko_" + property_name, korean)
	control.set(property_name, _l(english, korean))

func _apply_language_to_node(node: Node) -> void:
	for property_name: String in [
		"text",
		"placeholder_text",
		"tooltip_text",
		"suffix"
	]:
		var en_key: String = "_language_en_" + property_name
		var ko_key: String = "_language_ko_" + property_name

		if node.has_meta(en_key) and node.has_meta(ko_key):
			node.set(
				property_name,
				_l(
					str(node.get_meta(en_key)),
					str(node.get_meta(ko_key))
				)
			)

	for child: Node in node.get_children():
		_apply_language_to_node(child)

func apply_language() -> void:
	_apply_language_to_node(self)
	_refresh_weekday_labels()
	_refresh_reminder_labels()
	refresh_all()
	_update_editor_mode_labels()
	apply_appearance()

	if not editing_schedule_id.is_empty():
		_on_schedule_selected(editing_schedule_id)

func _refresh_weekday_labels() -> void:
	var korean_names: Array[String] = [
		"일", "월", "화", "수", "목", "금", "토"
	]

	for index: int in range(weekday_labels.size()):
		var shown_name: String = (
			korean_names[index]
			if AppLanguageScript.get_language() == "ko"
			else WEEKDAY_NAMES[index]
		)
		weekday_labels[index].text = shown_name

		if index < weekday_checks.size():
			weekday_checks[index].text = shown_name

func _refresh_reminder_labels() -> void:
	if reminder_input == null:
		return

	var selected_index: int = reminder_input.selected

	for index: int in range(reminder_input.item_count):
		reminder_input.set_item_text(
			index,
			_reminder_label(index)
		)

	if selected_index >= 0 and selected_index < reminder_input.item_count:
		reminder_input.select(selected_index)

func _reminder_label(index: int) -> String:
	match index:
		0:
			return _l("No reminder", "알림 없음")
		1:
			return _l("At start", "시작할 때")
		2:
			return _l("5 min before", "5분 전")
		3:
			return _l("10 min before", "10분 전")
		4:
			return _l("15 min before", "15분 전")
		5:
			return _l("30 min before", "30분 전")
		6:
			return _l("1 hour before", "1시간 전")
		_:
			return ""

func reload_schedules() -> void:
	schedules = ScheduleStoreScript.load_schedules()

	var migrated: bool = false
	for schedule: Dictionary in schedules:
		if not bool(schedule.get("enabled", true)):
			schedule["enabled"] = true
			migrated = true

	if migrated:
		ScheduleStoreScript.save_schedules(schedules)

func create_interface() -> void:
	var top_region := VBoxContainer.new()
	top_region.custom_minimum_size.y = AppearanceSettingsScript.UI_CARD_TOP_REGION_HEIGHT
	top_region.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_region.add_theme_constant_override(
		"separation", AppearanceSettingsScript.UI_STACK_GAP
	)
	add_child(top_region)

	var heading := Label.new()
	_bind_localized_text(heading, "Calendar", "캘린더")
	heading.add_theme_font_size_override(
		"font_size",
		AppearanceSettingsScript.UI_FONT_LARGE
	)
	top_region.add_child(heading)

	var explanation := Label.new()
	_bind_localized_text(
		explanation,
		"캘린더",
		"Calendar"
	)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_font_size_override(
		"font_size",
		AppearanceSettingsScript.UI_FONT_SMALL
	)
	explanation.remove_theme_color_override("font_color")
	top_region.add_child(explanation)
	top_region.add_child(HSeparator.new())

	var month_block := VBoxContainer.new()
	month_block.add_theme_constant_override("separation", SPACE_SM)
	top_region.add_child(month_block)
	create_month_header(month_block)
	create_calendar_grid(month_block)

	var selected_card: PanelContainer = _create_section_card()
	add_child(selected_card)
	var selected_margin := _make_card_margin(SPACE_MD, 12)
	selected_card.add_child(selected_margin)
	var selected_body := VBoxContainer.new()
	selected_body.add_theme_constant_override("separation", SPACE_SM)
	selected_margin.add_child(selected_body)

	var selected_header := HBoxContainer.new()
	selected_header.add_theme_constant_override("separation", SPACE_SM)
	selected_body.add_child(selected_header)

	selected_date_label = Label.new()
	selected_date_label.add_theme_font_size_override(
		"font_size",
		AppearanceSettingsScript.UI_FONT_MEDIUM
	)
	selected_date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selected_date_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	selected_header.add_child(selected_date_label)

	toolbar_add_button = Button.new()
	_bind_localized_text(toolbar_add_button, "+ New schedule", "+ 새 일정")
	toolbar_add_button.custom_minimum_size = Vector2(100, CONTROL_HEIGHT)
	toolbar_add_button.focus_mode = Control.FOCUS_NONE
	_style_toolbar_add_button(toolbar_add_button)
	toolbar_add_button.pressed.connect(_on_add_schedule_shortcut_pressed)
	selected_header.add_child(toolbar_add_button)

	selected_date_schedule_box = VBoxContainer.new()
	selected_date_schedule_box.add_theme_constant_override(
		"separation",
		SPACE_XS
	)
	selected_body.add_child(selected_date_schedule_box)

	editor_container = MarginContainer.new()
	editor_container.visible = false
	editor_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_container.add_theme_constant_override("margin_left", SPACE_MD)
	editor_container.add_theme_constant_override("margin_top", SPACE_XS)
	editor_container.add_theme_constant_override("margin_right", SPACE_MD)
	editor_container.add_theme_constant_override("margin_bottom", SPACE_SM)
	add_child(editor_container)

	var editor_section := VBoxContainer.new()
	editor_section.add_theme_constant_override("separation", SPACE_SM)
	editor_container.add_child(editor_section)

	editor_heading_label = Label.new()
	editor_heading_label.add_theme_font_size_override(
		"font_size",
		AppearanceSettingsScript.UI_FONT_MEDIUM
	)
	editor_section.add_child(editor_heading_label)

	var editor_description_label := Label.new()
	_bind_localized_text(
		editor_description_label,
		"Set the schedule details. Leave Repeat unchecked for a one-time schedule.",
		"일정의 내용과 시간을 설정하세요. 반복을 선택하지 않으면 한 번만 실행됩니다."
	)
	editor_description_label.add_theme_font_size_override(
		"font_size",
		AppearanceSettingsScript.UI_FONT_SMALL
	)
	editor_description_label.remove_theme_color_override("font_color")
	editor_section.add_child(editor_description_label)

	var editor_gap := Control.new()
	editor_gap.custom_minimum_size.y = SPACE_SM
	editor_section.add_child(editor_gap)
	create_editor(editor_section)
	_update_editor_mode_labels()

func _make_card_margin(horizontal: int, vertical_margin: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_top", vertical_margin)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_bottom", vertical_margin)
	return margin

func _create_section_card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section_cards.append(panel)
	_style_section_card(panel)
	return panel

func _style_section_card(panel: PanelContainer) -> void:
	if panel == null:
		return

	var style := StyleBoxFlat.new()
	style.bg_color = AppearanceSettingsScript.get_ui_color("surface_alt")
	style.border_width_left = 0
	style.border_width_top = 0
	style.border_width_right = 0
	style.border_width_bottom = 0
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	panel.add_theme_stylebox_override("panel", style)

func create_month_header(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size.y = 40.0
	parent.add_child(row)

	var left_slot := HBoxContainer.new()
	left_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_slot.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_child(left_slot)

	var previous_button := Button.new()
	previous_button.text = "<"
	previous_button.custom_minimum_size = Vector2(38, 34)
	_make_calendar_nav_button_flat(previous_button)
	_bind_localized_text(previous_button, "Previous month", "이전 달", "tooltip_text")
	previous_button.pressed.connect(_on_previous_month_pressed)
	left_slot.add_child(previous_button)

	var date_jump_row := HBoxContainer.new()
	date_jump_row.alignment = BoxContainer.ALIGNMENT_CENTER
	date_jump_row.add_theme_constant_override("separation", 2)
	row.add_child(date_jump_row)

	year_menu = MenuButton.new()
	year_menu.focus_mode = Control.FOCUS_NONE
	year_menu.add_theme_font_size_override(
		"font_size", AppearanceSettingsScript.UI_FONT_MEDIUM
	)
	_style_calendar_header_menu(year_menu)
	_bind_localized_text(year_menu, "Jump to year", "연도 이동", "tooltip_text")
	year_menu.get_popup().id_pressed.connect(_on_year_jump_selected)
	date_jump_row.add_child(year_menu)

	month_menu = MenuButton.new()
	month_menu.focus_mode = Control.FOCUS_NONE
	month_menu.add_theme_font_size_override(
		"font_size", AppearanceSettingsScript.UI_FONT_MEDIUM
	)
	_style_calendar_header_menu(month_menu)
	_bind_localized_text(month_menu, "Jump to month", "월 이동", "tooltip_text")
	month_menu.get_popup().id_pressed.connect(_on_month_jump_selected)
	date_jump_row.add_child(month_menu)

	var right_slot := HBoxContainer.new()
	right_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_slot.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(right_slot)

	var next_button := Button.new()
	next_button.text = ">"
	next_button.custom_minimum_size = Vector2(38, 34)
	_make_calendar_nav_button_flat(next_button)
	_bind_localized_text(next_button, "Next month", "다음 달", "tooltip_text")
	next_button.pressed.connect(_on_next_month_pressed)
	right_slot.add_child(next_button)

func _style_calendar_header_menu(menu: MenuButton) -> void:
	menu.flat = true
	menu.custom_minimum_size.y = 34.0
	menu.add_theme_color_override("font_color", AppearanceSettingsScript.get_ui_color("text"))
	menu.add_theme_color_override("font_hover_color", AppearanceSettingsScript.get_ui_color("text"))
	menu.add_theme_color_override("font_pressed_color", AppearanceSettingsScript.get_ui_color("text"))
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		menu.add_theme_stylebox_override(state, StyleBoxEmpty.new())

func _refresh_calendar_jump_menus() -> void:
	if year_menu == null or month_menu == null:
		return

	if AppLanguageScript.get_language() == "ko":
		year_menu.text = "%d년" % display_year
		month_menu.text = "%d월" % display_month
	else:
		year_menu.text = str(display_year)
		month_menu.text = "%02d" % display_month

	var year_popup: PopupMenu = year_menu.get_popup()
	year_popup.clear()
	for year: int in range(display_year - 50, display_year + 51):
		year_popup.add_item(str(year), year)

	var month_popup: PopupMenu = month_menu.get_popup()
	month_popup.clear()
	for month: int in range(1, 13):
		var month_text: String = ("%d월" % month) if AppLanguageScript.get_language() == "ko" else ("%02d" % month)
		month_popup.add_item(month_text, month)

func _on_year_jump_selected(year: int) -> void:
	display_year = year
	selected_day = mini(selected_day, _get_days_in_month(display_year, display_month))
	refresh_calendar()
	refresh_selected_date_schedules()

func _on_month_jump_selected(month: int) -> void:
	display_month = clampi(month, 1, 12)
	selected_day = mini(selected_day, _get_days_in_month(display_year, display_month))
	refresh_calendar()
	refresh_selected_date_schedules()

func _make_calendar_nav_button_flat(button: Button) -> void:
	button.flat = false
	button.focus_mode = Control.FOCUS_NONE

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.content_margin_left = 10.0
	normal.content_margin_right = 10.0
	normal.content_margin_top = 6.0
	normal.content_margin_bottom = 6.0

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = AppearanceSettingsScript.get_ui_color("surface_hover")

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("hover_pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_constant_override("outline_size", 0)

func create_calendar_grid(parent: Control) -> void:
	var grid := GridContainer.new()
	grid.columns = 7
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 2)
	parent.add_child(grid)

	for weekday_name: String in WEEKDAY_NAMES:
		var weekday_label := Label.new()
		weekday_label.text = weekday_name
		weekday_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		weekday_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		weekday_label.custom_minimum_size = Vector2(64, 28)
		weekday_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		weekday_label.add_theme_font_size_override(
			"font_size",
			AppearanceSettingsScript.UI_FONT_SMALL
		)
		grid.add_child(weekday_label)
		weekday_labels.append(weekday_label)

	for index: int in range(42):
		var cell := Control.new()
		cell.custom_minimum_size = Vector2(64, 44)
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(cell)

		var button_center := CenterContainer.new()
		button_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(button_center)

		var button := Button.new()
		button.custom_minimum_size = Vector2(44, 44)
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_calendar_day_pressed.bind(index))
		button_center.add_child(button)
		day_buttons.append(button)

		var star_center := CenterContainer.new()
		star_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		star_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(star_center)

		var sticker := TextureRect.new()
		sticker.texture = STAR_TEXTURE
		sticker.custom_minimum_size = Vector2(44, 44)
		sticker.visible = false
		sticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sticker.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sticker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star_center.add_child(sticker)
		day_sticker_icons.append(sticker)

		var number_center := CenterContainer.new()
		number_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		number_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(number_center)

		var number_label := Label.new()
		number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		number_label.add_theme_font_size_override("font_size", CALENDAR_DAY_FONT_SIZE)
		number_center.add_child(number_label)
		day_number_labels.append(number_label)

func create_editor(parent: Control) -> void:
	var editor_body := VBoxContainer.new()
	editor_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_body.add_theme_constant_override("separation", SPACE_MD)
	parent.add_child(editor_body)

	var title_group := VBoxContainer.new()
	title_group.add_theme_constant_override("separation", SPACE_SM)
	editor_body.add_child(title_group)

	var title_label := Label.new()
	_bind_localized_text(title_label, "Title", "제목")
	title_label.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	title_group.add_child(title_label)

	title_input = LineEdit.new()
	_bind_localized_text(
		title_input,
		"Class, meeting, medication...",
		"수업, 회의, 약 복용...",
		"placeholder_text"
	)
	title_input.max_length = 120
	title_input.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	title_input.custom_minimum_size.y = CONTROL_HEIGHT
	title_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_group.add_child(title_input)

	var repeat_group := VBoxContainer.new()
	repeat_group.add_theme_constant_override("separation", SPACE_SM)
	editor_body.add_child(repeat_group)

	var repeat_label := Label.new()
	_bind_localized_text(repeat_label, "Repeat (optional)", "반복 (선택)")
	repeat_label.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	repeat_group.add_child(repeat_label)

	var days_row := HBoxContainer.new()
	days_row.add_theme_constant_override("separation", SPACE_SM)
	days_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	repeat_group.add_child(days_row)

	for weekday: int in range(7):
		var check := Button.new()
		check.text = WEEKDAY_NAMES[weekday]
		check.toggle_mode = true
		check.focus_mode = Control.FOCUS_NONE
		check.custom_minimum_size = Vector2(44, CONTROL_HEIGHT)
		check.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
		_style_weekday_toggle(check)
		check.toggled.connect(_on_weekday_repeat_toggled.bind(weekday))
		days_row.add_child(check)
		weekday_checks.append(check)

	yearly_check = CheckBox.new()
	_bind_localized_text(yearly_check, "Yearly", "매년")
	yearly_check.focus_mode = Control.FOCUS_NONE
	yearly_check.tooltip_text = _l("Repeat every year on the selected calendar date.", "현재 선택한 날짜에 매년 반복합니다.")
	yearly_check.custom_minimum_size = Vector2(64, CONTROL_HEIGHT)
	yearly_check.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	yearly_check.toggled.connect(_on_yearly_repeat_toggled)
	days_row.add_child(yearly_check)

	var detail_row := HBoxContainer.new()
	detail_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_row.add_theme_constant_override("separation", SPACE_MD)
	editor_body.add_child(detail_row)

	var time_group := VBoxContainer.new()
	time_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_group.add_theme_constant_override("separation", SPACE_SM)
	detail_row.add_child(time_group)

	var time_label := Label.new()
	_bind_localized_text(time_label, "Time", "시간")
	time_label.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	time_group.add_child(time_label)

	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", SPACE_SM)
	time_group.add_child(time_row)

	hour_input = SpinBox.new()
	hour_input.min_value = 0
	hour_input.max_value = 23
	hour_input.step = 1
	hour_input.value = 9
	_bind_localized_text(hour_input, " h", "시", "suffix")
	hour_input.custom_minimum_size = Vector2(112, CONTROL_HEIGHT)
	time_row.add_child(hour_input)

	minute_input = SpinBox.new()
	minute_input.min_value = 0
	minute_input.max_value = 59
	minute_input.step = 1
	minute_input.value = 0
	_bind_localized_text(minute_input, " min", "분", "suffix")
	minute_input.custom_minimum_size = Vector2(112, CONTROL_HEIGHT)
	time_row.add_child(minute_input)

	var reminder_group := VBoxContainer.new()
	reminder_group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reminder_group.add_theme_constant_override("separation", SPACE_SM)
	detail_row.add_child(reminder_group)

	var reminder_label := Label.new()
	_bind_localized_text(reminder_label, "Reminder", "알림")
	reminder_label.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	reminder_group.add_child(reminder_label)

	reminder_input = OptionButton.new()
	reminder_input.custom_minimum_size = Vector2(0, CONTROL_HEIGHT)
	reminder_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for index: int in range(REMINDER_LABELS.size()):
		reminder_input.add_item(_reminder_label(index))
	reminder_input.selected = 3
	reminder_group.add_child(reminder_input)

	var controls := HBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", SPACE_SM)
	editor_body.add_child(controls)

	delete_button = Button.new()
	_bind_localized_text(delete_button, "Delete", "삭제")
	delete_button.custom_minimum_size.y = CONTROL_HEIGHT
	delete_button.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	_style_secondary_action_button(delete_button)
	delete_button.pressed.connect(_on_delete_pressed)
	controls.add_child(delete_button)

	var action_spacer := Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	controls.add_child(action_spacer)

	cancel_button = Button.new()
	_bind_localized_text(cancel_button, "Cancel", "취소")
	cancel_button.custom_minimum_size.y = CONTROL_HEIGHT
	cancel_button.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	_style_secondary_action_button(cancel_button)
	cancel_button.pressed.connect(clear_editor)
	controls.add_child(cancel_button)

	save_button = Button.new()
	_bind_localized_text(save_button, "Add Schedule", "일정 추가")
	save_button.custom_minimum_size.y = CONTROL_HEIGHT
	save_button.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	_style_primary_button(save_button)
	save_button.pressed.connect(_on_save_pressed)
	controls.add_child(save_button)

	editor_status_label = Label.new()
	editor_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor_status_label.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_SMALL)
	editor_status_label.visible = false
	editor_body.add_child(editor_status_label)

func _style_weekday_toggle(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.content_margin_left = 8.0
	normal.content_margin_right = 8.0
	normal.content_margin_top = 6.0
	normal.content_margin_bottom = 6.0

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = AppearanceSettingsScript.get_ui_color("surface_hover")
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = AppearanceSettingsScript.get_ui_color("selection")

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func record_focus_session(planned_minutes: int) -> void:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var date_key: String = "%04d-%02d-%02d" % [
		int(now.get("year", 1970)),
		int(now.get("month", 1)),
		int(now.get("day", 1))
	]
	productive_dates[date_key] = (
		int(productive_dates.get(date_key, 0))
		+ maxi(1, planned_minutes)
	)
	_save_focus_history()
	refresh_calendar()

func _load_focus_history() -> void:
	productive_dates.clear()
	var parsed: Dictionary = JsonStore.load_dictionary(FOCUS_HISTORY_PATH, {})
	for key_value: Variant in (parsed as Dictionary).keys():
		var key: String = str(key_value).strip_edges()
		var minutes: int = int((parsed as Dictionary).get(key_value, 0))
		if not key.is_empty() and minutes > 0:
			productive_dates[key] = minutes

func _save_focus_history() -> void:
	var error := JsonStore.save_json(FOCUS_HISTORY_PATH, productive_dates)
	if error != OK:
		OS.alert("집중 기록을 저장하지 못했습니다. / Could not save focus history.", "HaruHana")

func _discard_legacy_weekly_records() -> void:
	if FileAccess.file_exists(LEGACY_WEEKLY_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_WEEKLY_PATH))

func refresh_all() -> void:
	refresh_calendar()
	refresh_selected_date_schedules()

func apply_appearance() -> void:
	var font: Font = AppearanceSettingsScript.get_bubble_font()
	if font != null:
		for button: Button in day_buttons:
			button.add_theme_font_override("font", font)
			button.add_theme_font_size_override(
				"font_size",
				CALENDAR_DAY_FONT_SIZE
			)

	for panel: PanelContainer in section_cards:
		if is_instance_valid(panel):
			_style_section_card(panel)

	if year_menu != null:
		_style_calendar_header_menu(year_menu)
	if month_menu != null:
		_style_calendar_header_menu(month_menu)
	for check: Button in weekday_checks:
		if is_instance_valid(check):
			_style_weekday_toggle(check)
	if save_button != null:
		_style_primary_button(save_button)
	if toolbar_add_button != null:
		_style_toolbar_add_button(toolbar_add_button)

	refresh_calendar()
	refresh_selected_date_schedules()

func _apply_day_button_appearance(
	button: Button,
	selected: bool,
	_today: bool
) -> void:
	var transparent := Color(0.0, 0.0, 0.0, 0.0)
	var normal_box: StyleBoxFlat = _make_calendar_day_box(transparent)

	button.add_theme_stylebox_override("normal", normal_box)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())

	var hover_color: Color = AppearanceSettingsScript.get_ui_color("selection")
	if not selected:
		button.add_theme_stylebox_override(
			"hover",
			_make_calendar_day_box(hover_color)
		)
		button.add_theme_stylebox_override(
			"pressed",
			_make_calendar_day_box(hover_color)
		)
		return

	var selected_color: Color = AppearanceSettingsScript.get_ui_color("selection")
	var selected_box := _make_calendar_day_box(selected_color)
	button.add_theme_stylebox_override("normal", selected_box)
	button.add_theme_stylebox_override("hover", selected_box)
	button.add_theme_stylebox_override("pressed", selected_box)

func _make_calendar_day_box(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style

func refresh_calendar() -> void:
	_refresh_calendar_jump_menus()

	var days_in_month: int = (
		_get_days_in_month(
			display_year,
			display_month
		)
	)

	selected_day = clampi(
		selected_day,
		1,
		days_in_month
	)

	var first_weekday: int = (
		_get_weekday_for_date(
			display_year,
			display_month,
			1
		)
	)

	var now: Dictionary = Time.get_datetime_dict_from_system()
	var showing_current_month: bool = (
		display_year == int(now.get("year", -1))
		and display_month == int(now.get("month", -1))
	)
	var today_day: int = int(now.get("day", -1))

	for index: int in range(
		day_buttons.size()
	):
		var button: Button = (
			day_buttons[index]
		)
		var number_label: Label = day_number_labels[index]
		var sticker: TextureRect = day_sticker_icons[index]

		var day: int = (
			index
			- first_weekday
			+ 1
		)

		if (
			day < 1
			or day > days_in_month
		):
			number_label.text = ""
			button.text = ""
			button.disabled = true
			sticker.visible = false
			_apply_day_button_appearance(button, false, false)
			button.set_meta(
				"day",
				0
			)
			continue

		button.disabled = false
		button.set_meta(
			"day",
			day
		)


		var has_schedule: bool = _has_enabled_schedule_on_date(
			display_year, display_month, day
		)

		var day_text: String = str(
			day
		)

		if has_schedule:
			day_text += " *"

		var date_key: String = "%04d-%02d-%02d" % [
			display_year, display_month, day
		]
		number_label.text = day_text
		button.text = ""
		var is_selected: bool = day == selected_day
		sticker.visible = (
			int(productive_dates.get(date_key, 0)) >= PRODUCTIVE_FOCUS_MINUTES
			and not is_selected
		)
		_apply_day_button_appearance(
			button,
			is_selected,
			showing_current_month and day == today_day
		)
		_apply_productive_star_appearance(sticker)

func _apply_productive_star_appearance(sticker: TextureRect) -> void:
	if sticker == null:
		return
	sticker.modulate = AppearanceSettingsScript.get_ui_color("selection")

func refresh_selected_date_schedules() -> void:
	_clear_children(selected_date_schedule_box)

	var weekday: int = _get_weekday_for_date(
		display_year,
		display_month,
		selected_day
	)

	if AppLanguageScript.get_language() == "ko":
		var weekdays_ko: Array[String] = ["일", "월", "화", "수", "목", "금", "토"]
		selected_date_label.text = "%d월 %d일 (%s)" % [
			display_month,
			selected_day,
			weekdays_ko[weekday]
		]
	else:
		selected_date_label.text = "%04d-%02d-%02d (%s)" % [
			display_year,
			display_month,
			selected_day,
			WEEKDAY_NAMES[weekday]
		]

	var matching: Array[Dictionary] = []
	for schedule: Dictionary in schedules:
		if ScheduleStoreScript.matches_date(schedule, display_year, display_month, selected_day):
			matching.append(schedule)

	if matching.is_empty():
		var empty_label := Label.new()
		empty_label.text = _l(
			"No schedules for this day.",
			"이 날짜에 등록된 일정이 없습니다."
		)
		empty_label.add_theme_font_size_override(
			"font_size",
			AppearanceSettingsScript.UI_FONT_SMALL
		)
		empty_label.add_theme_color_override(
			"font_color", AppearanceSettingsScript.get_ui_color("muted")
		)
		selected_date_schedule_box.add_child(empty_label)
		return

	for schedule: Dictionary in matching:
		var label_text: String = "%02d:%02d  %s" % [
			int(schedule.get("hour", 0)),
			int(schedule.get("minute", 0)),
			str(schedule.get("title", ""))
		]
		selected_date_schedule_box.add_child(
			_make_schedule_row(schedule, label_text)
		)

func _make_schedule_row(
	schedule: Dictionary,
	_label_text: String = ""
) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = CONTROL_HEIGHT
	row.add_theme_constant_override("separation", SPACE_SM)

	var schedule_id: String = str(schedule.get("id", "")).strip_edges()

	var open_button := Button.new()
	open_button.text = str(schedule.get("title", ""))
	open_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	open_button.custom_minimum_size.y = CONTROL_HEIGHT
	open_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	open_button.focus_mode = Control.FOCUS_NONE
	_style_schedule_row_button(open_button)
	open_button.pressed.connect(_on_schedule_selected.bind(schedule_id))
	row.add_child(open_button)

	var metadata_label := Label.new()
	var recurrence_text: String = ""
	var repeat_mode: String = str(schedule.get("repeat", "weekly"))
	if repeat_mode == "once":
		recurrence_text = _l("once", "1회") + "  ·  "
	elif repeat_mode == "yearly":
		recurrence_text = _l("yearly %02d-%02d" % [int(schedule.get("month", 1)), int(schedule.get("day", 1))], "매년 %d/%d" % [int(schedule.get("month", 1)), int(schedule.get("day", 1))]) + "  ·  "
	metadata_label.text = recurrence_text + "%02d:%02d  ·  %s" % [
		int(schedule.get("hour", 0)),
		int(schedule.get("minute", 0)),
		_format_reminder(int(schedule.get("reminder_minutes", 10)))
	]
	metadata_label.custom_minimum_size.x = 170.0
	metadata_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	metadata_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	metadata_label.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_SMALL)
	var muted := AppearanceSettingsScript.get_ui_color("muted")
	metadata_label.add_theme_color_override("font_color", muted)
	row.add_child(metadata_label)

	var remove_button := Button.new()
	remove_button.text = "×"
	remove_button.tooltip_text = _l("Delete schedule", "일정 삭제")
	remove_button.custom_minimum_size = Vector2(CONTROL_HEIGHT, CONTROL_HEIGHT)
	remove_button.focus_mode = Control.FOCUS_NONE
	remove_button.modulate.a = 0.0
	_style_secondary_action_button(remove_button)
	remove_button.pressed.connect(_delete_schedule_by_id.bind(schedule_id))
	row.add_child(remove_button)

	row.mouse_entered.connect(
		_set_schedule_delete_visibility.bind(remove_button, true)
	)
	row.mouse_exited.connect(
		_set_schedule_delete_visibility.bind(remove_button, false)
	)
	open_button.mouse_entered.connect(
		_set_schedule_delete_visibility.bind(remove_button, true)
	)
	metadata_label.mouse_entered.connect(
		_set_schedule_delete_visibility.bind(remove_button, true)
	)
	remove_button.mouse_entered.connect(
		_set_schedule_delete_visibility.bind(remove_button, true)
	)

	return row

func _style_schedule_row_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	normal.corner_radius_top_left = 7
	normal.corner_radius_top_right = 7
	normal.corner_radius_bottom_left = 7
	normal.corner_radius_bottom_right = 7
	normal.content_margin_left = 8.0
	normal.content_margin_right = 8.0
	normal.content_margin_top = 6.0
	normal.content_margin_bottom = 6.0
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = AppearanceSettingsScript.get_ui_color("secondary")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("hover_pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _style_primary_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = AppearanceSettingsScript.get_ui_color("selection")
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.content_margin_left = 14.0
	normal.content_margin_right = 14.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", normal)
	button.add_theme_stylebox_override("hover_pressed", normal)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var text := AppearanceSettingsScript.get_ui_color("text")
	button.add_theme_color_override("font_color", text)
	button.add_theme_color_override("font_hover_color", text)
	button.add_theme_color_override("font_pressed_color", text)

func _style_toolbar_add_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.content_margin_left = 10.0
	normal.content_margin_right = 10.0
	normal.content_margin_top = 6.0
	normal.content_margin_bottom = 6.0
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = AppearanceSettingsScript.get_ui_color("secondary")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("hover_pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var text := AppearanceSettingsScript.get_ui_color("text")
	button.add_theme_color_override("font_color", text)
	button.add_theme_color_override("font_hover_color", text)
	button.add_theme_color_override("font_pressed_color", text)

func _style_secondary_action_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = AppearanceSettingsScript.get_ui_color("surface_hover")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("hover_pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _on_add_schedule_shortcut_pressed() -> void:
	_reset_editor_fields()
	_show_editor(false)
	if title_input != null:
		title_input.grab_focus()

func _set_schedule_delete_visibility(
	button: Button,
	show_button: bool
) -> void:
	if button == null or not is_instance_valid(button):
		return
	button.modulate.a = 1.0 if show_button else 0.0

func _delete_schedule_by_id(schedule_id: String) -> void:
	schedule_id = schedule_id.strip_edges()
	if schedule_id.is_empty():
		return

	var kept: Array[Dictionary] = []
	for schedule: Dictionary in schedules:
		if str(schedule.get("id", "")) == schedule_id:
			continue
		kept.append(schedule)

	schedules = kept
	if not ScheduleStoreScript.save_schedules(schedules):
		if editor_status_label != null:
			editor_status_label.visible = true
			editor_status_label.text = _l(
				"Failed to delete the schedule.",
				"일정을 삭제하지 못했습니다."
			)
		return

	if editing_schedule_id == schedule_id:
		clear_editor()

	reload_schedules()
	refresh_all()
	if editor_status_label != null:
		editor_status_label.visible = false
		editor_status_label.text = ""
	schedules_changed.emit()

func _reset_editor_fields() -> void:
	editing_schedule_id = ""

	if title_input != null:
		title_input.text = ""

	for check: Button in weekday_checks:
		check.button_pressed = false
	if yearly_check != null:
		yearly_check.set_pressed_no_signal(false)

	if hour_input != null:
		hour_input.value = 9
	if minute_input != null:
		minute_input.value = 0
	if reminder_input != null:
		reminder_input.selected = 3

	if editor_status_label != null:
		editor_status_label.visible = false
		editor_status_label.text = ""

func _update_editor_mode_labels() -> void:
	var is_editing: bool = not editing_schedule_id.is_empty()
	if editor_heading_label != null:
		editor_heading_label.text = _l(
			"Edit schedule" if is_editing else "New schedule",
			"일정 수정" if is_editing else "새 일정"
		)
	if save_button != null:
		save_button.text = _l(
			"Save Changes" if is_editing else "Add Schedule",
			"변경 저장" if is_editing else "일정 추가"
		)
	if delete_button != null:
		delete_button.visible = is_editing
		delete_button.disabled = not is_editing

func _show_editor(is_editing: bool) -> void:
	if not is_editing:
		editing_schedule_id = ""
	_update_editor_mode_labels()
	if editor_container != null:
		editor_container.visible = true

func clear_editor() -> void:
	_reset_editor_fields()
	_update_editor_mode_labels()
	if editor_container != null:
		editor_container.visible = false

func _on_save_pressed() -> void:
	var title: String = (
		title_input.text.strip_edges()
	)

	if title.is_empty():
		editor_status_label.visible = true
		editor_status_label.text = (
			_l("Enter a schedule title.", "일정 제목을 입력하세요.")
		)
		return

	var selected_days: Array[int] = []

	for weekday: int in range(
		weekday_checks.size()
	):
		if weekday_checks[
			weekday
		].button_pressed:
			selected_days.append(
				weekday
			)

	var repeats_yearly: bool = yearly_check != null and yearly_check.button_pressed
	var repeat_mode: String = "yearly" if repeats_yearly else ("weekly" if not selected_days.is_empty() else "once")

	var reminder_index: int = clampi(
		reminder_input.selected,
		0,
		REMINDER_VALUES.size() - 1
	)

	var schedule: Dictionary = {
		"id": editing_schedule_id,
		"title": title,
		"repeat": repeat_mode,
		"days": selected_days if repeat_mode == "weekly" else [],
		"year": display_year,
		"month": display_month,
		"day": selected_day,
		"hour": int(
			hour_input.value
		),
		"minute": int(
			minute_input.value
		),
		"reminder_minutes": (
			REMINDER_VALUES[
				reminder_index
			]
		),
		"enabled": true
	}

	schedule = (
		ScheduleStoreScript.normalize_schedule(
			schedule
		)
	)

	if schedule.is_empty():
		editor_status_label.visible = true
		editor_status_label.text = (
			_l("Could not save this schedule.", "일정을 저장하지 못했습니다.")
		)
		return

	var saved_id: String = str(
		schedule.get(
			"id",
			""
		)
	)

	var replaced: bool = false

	for index: int in range(
		schedules.size()
	):
		if str(
			schedules[index].get(
				"id",
				""
			)
		) != saved_id:
			continue

		schedules[
			index
		] = schedule

		replaced = true
		break

	if not replaced:
		schedules.append(
			schedule
		)

	if not ScheduleStoreScript.save_schedules(
		schedules
	):
		editor_status_label.visible = true
		editor_status_label.text = (
			_l("Failed to write the schedule file.", "일정 파일을 저장하지 못했습니다.")
		)
		return

	editing_schedule_id = saved_id

	editor_status_label.visible = false
	editor_status_label.text = ""

	reload_schedules()
	refresh_all()
	clear_editor()

	schedules_changed.emit()

func _on_delete_pressed() -> void:
	if editing_schedule_id.is_empty():
		return
	_delete_schedule_by_id(editing_schedule_id)

func _on_schedule_selected(
	schedule_id: String
) -> void:

	for schedule: Dictionary in schedules:
		if str(
			schedule.get(
				"id",
				""
			)
		) != schedule_id:
			continue

		editing_schedule_id = schedule_id

		title_input.text = str(
			schedule.get(
				"title",
				""
			)
		)

		var days: Variant = schedule.get("days", [])
		var repeat_mode: String = str(schedule.get("repeat", "weekly"))
		var repeats_yearly: bool = repeat_mode == "yearly"
		if yearly_check != null:
			yearly_check.set_pressed_no_signal(repeats_yearly)
		for weekday: int in range(weekday_checks.size()):
			weekday_checks[weekday].set_pressed_no_signal(
				not repeats_yearly and days is Array and (days as Array).has(weekday)
			)

		hour_input.value = int(
			schedule.get(
				"hour",
				9
			)
		)

		minute_input.value = int(
			schedule.get(
				"minute",
				0
			)
		)

		var reminder_minutes: int = int(
			schedule.get(
				"reminder_minutes",
				10
			)
		)

		var reminder_index: int = (
			REMINDER_VALUES.find(
				reminder_minutes
			)
		)

		if reminder_index < 0:
			reminder_index = 3

		reminder_input.selected = reminder_index

		editor_status_label.visible = false
		editor_status_label.text = ""
		_show_editor(true)

		return

func _on_calendar_day_pressed(
	button_index: int
) -> void:

	if (
		button_index < 0
		or button_index >= day_buttons.size()
	):
		return

	var day: int = int(
		day_buttons[
			button_index
		].get_meta(
			"day",
			0
		)
	)

	if day <= 0:
		return

	selected_day = day

	refresh_calendar()
	refresh_selected_date_schedules()

func _on_previous_month_pressed() -> void:
	_shift_month(
		-1
	)

func _on_next_month_pressed() -> void:
	_shift_month(
		1
	)

func _shift_month(
	delta: int
) -> void:

	display_month += delta

	while display_month < 1:
		display_month += 12
		display_year -= 1

	while display_month > 12:
		display_month -= 12
		display_year += 1

	selected_day = 1

	refresh_calendar()
	refresh_selected_date_schedules()

func _has_enabled_schedule_on_date(year: int, month: int, day: int) -> bool:
	for schedule: Dictionary in schedules:
		if ScheduleStoreScript.matches_date(schedule, year, month, day):
			return true
	return false

func _on_yearly_repeat_toggled(enabled: bool) -> void:
	if not enabled:
		return
	for check: Button in weekday_checks:
		check.set_pressed_no_signal(false)

func _on_weekday_repeat_toggled(enabled: bool, _weekday: int) -> void:
	if enabled and yearly_check != null:
		yearly_check.set_pressed_no_signal(false)

func _format_reminder(
	minutes: int
) -> String:

	if minutes < 0:
		return _l("no reminder", "알림 없음")

	if minutes == 0:
		return _l("at start", "시작할 때")

	if minutes == 60:
		return _l("1 hour before", "1시간 전")

	return (
		str(
			minutes
		)
		+ _l(" min before", "분 전")
	)

func _get_weekday_for_date(
	year: int,
	month: int,
	day: int
) -> int:

	var stamp: int = (
		Time.get_unix_time_from_datetime_dict(
			{
				"year": year,
				"month": month,
				"day": day,
				"hour": 12,
				"minute": 0,
				"second": 0
			}
		)
	)

	var date: Dictionary = (
		Time.get_datetime_dict_from_unix_time(
			stamp
		)
	)

	return int(
		date.get(
			"weekday",
			0
		)
	)

func _get_days_in_month(
	year: int,
	month: int
) -> int:

	match month:
		1, 3, 5, 7, 8, 10, 12:
			return 31

		4, 6, 9, 11:
			return 30

		2:
			if _is_leap_year(
				year
			):
				return 29

			return 28

	return 30

func _is_leap_year(
	year: int
) -> bool:

	if year % 400 == 0:
		return true

	if year % 100 == 0:
		return false

	return year % 4 == 0

func _clear_children(
	parent: Node
) -> void:

	for child: Node in parent.get_children():
		parent.remove_child(
			child
		)

		child.queue_free()
