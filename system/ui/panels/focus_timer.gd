extends VBoxContainer
class_name FocusTimerPanel

const AppLanguageScript = preload(
	"res://system/app/app_language.gd"
)

const AppearanceSettingsScript = preload(
	"res://system/app/appearance_settings.gd"
)

signal session_started(
	task_name: String,
	planned_minutes: int
)

signal session_paused(
	task_name: String,
	planned_minutes: int
)

signal session_resumed(
	task_name: String,
	planned_minutes: int
)

signal session_stopped(
	task_name: String,
	planned_minutes: int
)

signal session_finished(
	task_name: String,
	planned_minutes: int
)

signal session_time_updated(
	seconds_remaining: int,
	active: bool,
	paused: bool
)

const DEFAULT_MINUTES := 25.0
const DEFAULT_TASK_NAME := "Focus session"
const LOCKED_CONTROL_TINT := Color(0.62, 0.62, 0.62, 1.0)

var configured_seconds: float = (
	DEFAULT_MINUTES * 60.0
)

var active_task_name: String = ""

var countdown: Timer

var task_input: LineEdit
var duration_input: SpinBox

var time_label: LineEdit
var status_label: Label

var start_pause_button: Button
var reset_button: Button

var preset_buttons: Array[Button] = []
var last_finished_task_name: String = ""
var last_emitted_seconds: int = -1
var last_emitted_active: bool = false
var last_emitted_paused: bool = false

func _ready() -> void:
	add_theme_constant_override(
		"separation",
		AppearanceSettingsScript.UI_STACK_GAP
	)

	create_timer()
	create_interface()

	update_display(
		configured_seconds
	)

	apply_language()

func _l(english: String, korean: String) -> String:
	return AppLanguageScript.text(english, korean)

func _default_task_name() -> String:
	return _l(DEFAULT_TASK_NAME, "집중 세션")

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
	_refresh_language_state()

func _refresh_language_state() -> void:
	if countdown == null or start_pause_button == null or status_label == null:
		return

	if not countdown.is_stopped():
		if countdown.paused:
			start_pause_button.text = _l("Resume", "계속")
			status_label.text = _l("Paused", "일시정지")
		else:
			start_pause_button.text = _l("Pause", "일시정지")
			if active_task_name.is_empty():
				status_label.text = _l("Focusing", "집중 중")
			else:
				status_label.text = (
					_l("Focusing: ", "집중 중: ")
					+ active_task_name
				)
		return

	start_pause_button.text = _l("Start", "시작")

	if not last_finished_task_name.is_empty():
		status_label.text = (
			_l("Finished: ", "완료: ")
			+ last_finished_task_name
		)
	else:
		status_label.text = _l("Ready", "대기")
	status_label.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)

func create_timer() -> void:
	countdown = Timer.new()

	countdown.name = "Countdown"
	countdown.one_shot = true
	countdown.ignore_time_scale = true

	countdown.timeout.connect(
		_on_countdown_finished
	)

	add_child(countdown)

func create_interface() -> void:
	var heading := Label.new()
	_bind_localized_text(heading, "Focus Timer", "집중 타이머")
	heading.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_LARGE)
	add_child(heading)

	var explanation := Label.new()
	_bind_localized_text(
		explanation,
		"Name a task, pick a duration, and start.",
		"작업 이름을 적고 시간을 고른 뒤 시작하세요."
	)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_SMALL)
	explanation.remove_theme_color_override("font_color")
	add_child(explanation)

	add_child(HSeparator.new())

	var body_shell := HBoxContainer.new()
	body_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_shell.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(body_shell)

	var body := VBoxContainer.new()
	body.custom_minimum_size.x = 500.0
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", AppearanceSettingsScript.UI_STACK_GAP)
	body_shell.add_child(body)

	var task_row := HBoxContainer.new()
	task_row.add_theme_constant_override("separation", 10)
	body.add_child(task_row)

	var task_label := Label.new()
	_bind_localized_text(task_label, "Task:", "작업:")
	task_label.custom_minimum_size = Vector2(70, 0)
	task_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	task_label.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	task_row.add_child(task_label)

	task_input = LineEdit.new()
	_bind_localized_text(
		task_input,
		"What are you working on?",
		"무엇에 집중할까요?",
		"placeholder_text"
	)
	task_input.max_length = 120
	task_input.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	task_input.custom_minimum_size.y = 38.0
	task_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_row.add_child(task_input)

	var presets := HBoxContainer.new()
	presets.alignment = BoxContainer.ALIGNMENT_CENTER
	presets.add_theme_constant_override("separation", 18)
	body.add_child(presets)
	create_preset_button(presets, 1)
	create_preset_button(presets, 5)
	create_preset_button(presets, 25)
	create_preset_button(presets, 45)

	duration_input = SpinBox.new()
	duration_input.min_value = 1
	duration_input.max_value = 180
	duration_input.step = 1
	duration_input.value = DEFAULT_MINUTES
	duration_input.visible = false
	duration_input.value_changed.connect(_on_duration_changed)
	body.add_child(duration_input)

	var timer_center := CenterContainer.new()
	timer_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timer_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	timer_center.custom_minimum_size.y = 300.0
	body.add_child(timer_center)

	var timer_core := VBoxContainer.new()
	timer_core.custom_minimum_size.x = 320.0
	timer_core.add_theme_constant_override("separation", AppearanceSettingsScript.UI_STACK_GAP)
	timer_center.add_child(timer_core)

	time_label = LineEdit.new()
	time_label.text = "25:00"
	time_label.alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_label.custom_minimum_size.y = 86.0
	time_label.max_length = 6
	time_label.select_all_on_focus = true
	time_label.add_theme_font_size_override("font_size", 56)
	time_label.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	time_label.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	time_label.add_theme_stylebox_override("read_only", StyleBoxEmpty.new())
	time_label.text_submitted.connect(_on_time_text_submitted)
	time_label.focus_exited.connect(_commit_time_text)
	timer_core.add_child(time_label)

	status_label = Label.new()
	status_label.text = _l("Ready", "대기")
	status_label.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timer_core.add_child(status_label)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 22)
	timer_core.add_child(controls)

	reset_button = Button.new()
	_bind_localized_text(reset_button, "Reset", "초기화")
	reset_button.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	reset_button.custom_minimum_size = Vector2(120, 42)
	_style_timer_button(reset_button)
	reset_button.pressed.connect(_on_reset_pressed)
	controls.add_child(reset_button)

	start_pause_button = Button.new()
	_bind_localized_text(start_pause_button, "Start", "시작")
	start_pause_button.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	start_pause_button.custom_minimum_size = Vector2(120, 42)
	_style_timer_primary_button(start_pause_button)
	start_pause_button.pressed.connect(_on_start_pause_pressed)
	controls.add_child(start_pause_button)

func _style_timer_button(button: Button) -> void:
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
	button.add_theme_stylebox_override("disabled", normal.duplicate())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _style_timer_primary_button(button: Button) -> void:
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
	var hover: StyleBoxFlat = normal.duplicate()
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("hover_pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func apply_appearance() -> void:
	if start_pause_button != null:
		_style_timer_primary_button(start_pause_button)
	if reset_button != null:
		_style_timer_button(reset_button)
	for button: Button in preset_buttons:
		if is_instance_valid(button):
			_style_timer_button(button)

func create_preset_button(
	parent: HBoxContainer,
	minutes: int
) -> void:

	var button := Button.new()

	_bind_localized_text(button, "%d min" % minutes, "%d분" % minutes)
	button.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	_style_timer_button(button)

	button.pressed.connect(
		_set_preset.bind(minutes)
	)

	parent.add_child(button)

	preset_buttons.append(button)

func _set_preset(
	minutes: int
) -> void:

	if not countdown.is_stopped():
		return

	duration_input.set_value_no_signal(minutes)
	configured_seconds = float(minutes) * 60.0
	update_display(configured_seconds)

func get_entered_task_name() -> String:
	var clean_name: String = (
		task_input.text.strip_edges()
	)

	if clean_name.is_empty():
		return _default_task_name()

	return clean_name

func set_configuration_editable(
	editable: bool
) -> void:
	var tint := Color.WHITE if editable else LOCKED_CONTROL_TINT

	task_input.editable = editable
	task_input.modulate = tint
	if not editable:
		task_input.add_theme_stylebox_override(
			"read_only",
			task_input.get_theme_stylebox("normal").duplicate()
		)
	duration_input.editable = editable
	if time_label != null:
		time_label.editable = editable
		time_label.modulate = tint

	for button: Button in preset_buttons:
		button.disabled = not editable
		button.modulate = tint

func start_quick_session(
	minutes: int,
	task_name: String = ""
) -> bool:

	if countdown == null:
		return false

	if not countdown.is_stopped():
		return false

	var clamped_minutes: int = clampi(
		minutes,
		int(duration_input.min_value),
		int(duration_input.max_value)
	)

	duration_input.set_value_no_signal(clamped_minutes)
	configured_seconds = float(clamped_minutes) * 60.0
	update_display(configured_seconds)

	var clean_task_name: String = (
		task_name.strip_edges()
	)

	task_input.text = clean_task_name

	start_new_session()

	return true

func is_session_active() -> bool:
	if countdown == null:
		return false

	return not countdown.is_stopped()

func _on_start_pause_pressed() -> void:
	if countdown.is_stopped():
		start_new_session()
		return

	var planned_minutes: int = roundi(
		configured_seconds / 60.0
	)

	var task_name: String = active_task_name

	if task_name.is_empty():
		task_name = _default_task_name()

	if countdown.paused:
		countdown.paused = false

		start_pause_button.text = _l("Pause", "일시정지")
		status_label.text = _l("Focusing", "집중 중")

		session_resumed.emit(
			task_name,
			planned_minutes
		)

		return

	countdown.paused = true

	start_pause_button.text = _l("Resume", "계속")
	status_label.text = _l("Paused", "일시정지")

	session_paused.emit(
		task_name,
		planned_minutes
	)

func start_new_session() -> void:
	last_finished_task_name = ""
	_commit_time_text()

	active_task_name = (
		get_entered_task_name()
	)

	set_configuration_editable(false)

	countdown.paused = false

	countdown.start(
		configured_seconds
	)

	start_pause_button.text = _l("Pause", "일시정지")

	status_label.text = (
		_l("Focusing: ", "집중 중: ")
		+ active_task_name
	)

	update_display(
		configured_seconds
	)

	session_started.emit(
		active_task_name,
		roundi(
			configured_seconds / 60.0
		)
	)

func _on_reset_pressed() -> void:
	var was_running: bool = (
		not countdown.is_stopped()
	)

	var stopped_task: String = active_task_name

	if stopped_task.is_empty():
		stopped_task = _default_task_name()

	var planned_minutes: int = roundi(
		configured_seconds / 60.0
	)

	countdown.stop()
	countdown.paused = false

	active_task_name = ""
	last_finished_task_name = ""

	set_configuration_editable(true)

	start_pause_button.text = _l("Start", "시작")
	status_label.text = _l("Ready", "대기")

	update_display(
		configured_seconds
	)

	if was_running:
		session_stopped.emit(
			stopped_task,
			planned_minutes
		)

func _on_time_text_submitted(_value: String) -> void:
	_commit_time_text()
	if time_label != null:
		time_label.release_focus()

func _commit_time_text() -> void:
	if time_label == null:
		return

	if countdown != null and not countdown.is_stopped():
		update_display(countdown.time_left)
		return

	var parsed_seconds: float = _parse_time_text(time_label.text)
	if parsed_seconds < 0.0:
		update_display(configured_seconds)
		return

	configured_seconds = parsed_seconds
	if duration_input != null:
		duration_input.set_value_no_signal(configured_seconds / 60.0)
	update_display(configured_seconds)

func _parse_time_text(value: String) -> float:
	var clean: String = value.strip_edges()
	if clean.is_empty():
		return -1.0

	if clean.is_valid_int():
		return clampf(float(clean.to_int()) * 60.0, 60.0, 10800.0)

	var parts: PackedStringArray = clean.split(":", false)
	if parts.size() != 2:
		return -1.0
	if not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return -1.0

	var minutes: int = parts[0].to_int()
	var seconds: int = parts[1].to_int()
	if minutes < 0 or seconds < 0 or seconds > 59:
		return -1.0

	return clampf(float(minutes * 60 + seconds), 60.0, 10800.0)

func _on_duration_changed(
	new_minutes: float
) -> void:

	if not countdown.is_stopped():
		return

	configured_seconds = (
		new_minutes * 60.0
	)

	update_display(
		configured_seconds
	)

func _on_countdown_finished() -> void:
	countdown.paused = false

	var planned_minutes: int = roundi(
		configured_seconds / 60.0
	)

	var finished_task: String = (
		active_task_name
	)

	if finished_task.is_empty():
		finished_task = _default_task_name()

	start_pause_button.text = _l("Start", "시작")

	last_finished_task_name = finished_task

	status_label.text = (
		_l("Finished: ", "완료: ")
		+ finished_task
	)

	set_configuration_editable(true)

	update_display(0.0)

	session_finished.emit(
		finished_task,
		planned_minutes
	)

	active_task_name = ""

func update_display(
	seconds_remaining: float
) -> void:

	var total_seconds: int = maxi(
		0,
		ceili(seconds_remaining)
	)

	var minutes: int = int(
		float(total_seconds) / 60.0
	)

	var seconds: int = (
		total_seconds % 60
	)

	time_label.text = "%02d:%02d" % [
		minutes,
		seconds
	]

	var active: bool = countdown != null and not countdown.is_stopped()
	var paused: bool = active and countdown.paused
	if (
		total_seconds != last_emitted_seconds
		or active != last_emitted_active
		or paused != last_emitted_paused
	):
		last_emitted_seconds = total_seconds
		last_emitted_active = active
		last_emitted_paused = paused
		session_time_updated.emit(total_seconds, active, paused)

func _process(
	_delta: float
) -> void:

	if countdown == null:
		return

	if countdown.is_stopped():
		return

	update_display(
		countdown.time_left
	)
