extends RefCounted
class_name CompanionDebugPanel

signal action_requested(action: String, target_slot: int)

const AppLanguageScript = preload("res://system/app/app_language.gd")
const AppearanceSettingsScript = preload("res://system/app/appearance_settings.gd")

var target_selector: OptionButton = null
var friendship_level_selector: OptionButton = null
var achievement_level_selector: OptionButton = null
var progress_output: Label = null
var progress_syncing: bool = false
var output: Label = null
var special_month_selector: OptionButton = null
var special_day_selector: OptionButton = null

func _l(english: String, korean: String) -> String:
	return AppLanguageScript.text(english, korean)

func create_content() -> VBoxContainer:
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", AppearanceSettingsScript.UI_STACK_GAP)

	var title_label := Label.new()
	title_label.text = _l("Debug", "디버그")
	title_label.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_LARGE)
	content.add_child(title_label)

	var description := Label.new()
	description.text = _l(
		"Trigger runtime paths that are difficult to test through normal use.",
		"일반 사용으로 확인하기 어려운 런타임 동작을 직접 실행합니다."
	)
	_style_secondary_label(description)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(description)
	content.add_child(HSeparator.new())

	_add_section_header(content, _l("Target", "대상"), _l(
		"Character-specific tests use the selected desktop slot.",
		"캐릭터별 테스트는 선택한 데스크탑 슬롯을 사용합니다."
	))
	var target_row := HBoxContainer.new()
	target_row.add_theme_constant_override("separation", 12)
	target_row.custom_minimum_size.y = float(AppearanceSettingsScript.UI_CONTROL_HEIGHT)
	content.add_child(target_row)
	var target_label := Label.new()
	target_label.text = _l("Character", "캐릭터")
	target_label.custom_minimum_size.x = 120.0
	target_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	target_row.add_child(target_label)
	target_selector = OptionButton.new()
	target_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	target_selector.custom_minimum_size.y = float(AppearanceSettingsScript.UI_CONTROL_HEIGHT)
	target_selector.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	target_selector.add_item(_l("Desktop slot 1", "데스크탑 슬롯 1"))
	target_selector.add_item(_l("Desktop slot 2", "데스크탑 슬롯 2"))
	target_selector.item_selected.connect(_on_target_selected)
	target_row.add_child(target_selector)

	_add_section_header(content, _l("Ambient dialogue", "앰비언트 대화"), _l(
		"Test generation and playback without waiting for the normal timer.",
		"일반 타이머를 기다리지 않고 생성과 재생을 테스트합니다."
	))
	var ambient_grid := _create_button_grid()
	content.add_child(ambient_grid)
	_add_button(ambient_grid, _l("Generate ambient pool", "앰비언트 풀 생성"), "ambient_generate")
	_add_button(ambient_grid, _l("Play ambient now", "앰비언트 즉시 재생"), "ambient_play")

	_add_section_header(content, _l("Generated events", "생성 이벤트"), _l(
		"Exercise AI paths that normally depend on time, schedules, or quitting.",
		"시간, 일정, 종료 상황을 기다려야 하는 AI 경로를 테스트합니다."
	))
	var event_grid := _create_button_grid()
	content.add_child(event_grid)
	_add_button(event_grid, _l("AI hourly comment", "AI 정시 코멘트"), "hourly_ai")
	_add_button(event_grid, _l("AI timer bundle", "AI 타이머 반응 묶음"), "timer_bundle")
	_add_button(event_grid, _l("AI schedule reminder", "AI 일정 알림"), "schedule_ai")
	_add_button(event_grid, _l("AI exit dialogue", "AI 종료 대화"), "exit_ai")

	_add_section_header(content, _l("Special boot", "특별 부팅"), _l(
		"Test the once-per-day occasion line for a chosen month and day.",
		"선택한 월/일의 하루 한 번 특별 부팅 대사를 테스트합니다."
	))
	var date_row := HBoxContainer.new()
	date_row.add_theme_constant_override("separation", 8)
	content.add_child(date_row)
	special_month_selector = OptionButton.new()
	special_month_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for month: int in range(1, 13):
		special_month_selector.add_item(_l("Month %d" % month, "%d월" % month), month)
	special_month_selector.select(maxi(0, int(Time.get_datetime_dict_from_system().get("month", 1)) - 1))
	special_month_selector.item_selected.connect(_refresh_special_day_options)
	date_row.add_child(special_month_selector)
	special_day_selector = OptionButton.new()
	special_day_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date_row.add_child(special_day_selector)
	_refresh_special_day_options(0)
	var today_day: int = int(Time.get_datetime_dict_from_system().get("day", 1))
	if special_day_selector.item_count >= today_day:
		special_day_selector.select(today_day - 1)
	var special_button_grid := _create_button_grid()
	special_button_grid.columns = 1
	content.add_child(special_button_grid)
	_add_button(special_button_grid, _l("Play special boot line", "특별 부팅 대사 재생"), "special_boot")

	_add_section_header(content, _l("Character state", "캐릭터 상태"), _l(
		"Replay rare state-dependent behavior without changing saved completion state.",
		"저장된 완료 상태를 바꾸지 않고 드문 상태 의존 동작을 재현합니다."
	))
	var character_grid := _create_button_grid()
	content.add_child(character_grid)
	_add_button(character_grid, _l("Replay first boot", "첫 부팅 대화 재생"), "first_boot")
	_add_button(character_grid, _l("Fluster peer banter", "당황 동료 대화"), "fluster_banter")
	_add_button(character_grid, _l("Force overlap", "겹침 강제 발생"), "force_overlap")

	_add_section_header(content, _l("Interactive friendship", "상호작용 친밀도"), _l(
		"Generate a question immediately or temporarily override progression tiers for testing.",
		"질문을 즉시 생성하거나 테스트 중에만 진행도 단계를 덮어씁니다."
	))
	var question_grid := _create_button_grid()
	content.add_child(question_grid)
	_add_button(question_grid, _l("Generate question now", "질문 즉시 생성"), "interactive_question")
	_add_button(question_grid, _l("Use actual progress", "원래대로"), "progress_restore")

	var friendship_row := HBoxContainer.new()
	friendship_row.add_theme_constant_override("separation", 12)
	content.add_child(friendship_row)
	var friendship_label := Label.new()
	friendship_label.text = _l("Friendship", "친밀도")
	friendship_label.custom_minimum_size.x = 120.0
	friendship_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	friendship_row.add_child(friendship_label)
	friendship_level_selector = OptionButton.new()
	friendship_level_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	friendship_level_selector.custom_minimum_size.y = float(AppearanceSettingsScript.UI_CONTROL_HEIGHT)
	friendship_level_selector.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	friendship_level_selector.item_selected.connect(_on_friendship_level_selected)
	friendship_row.add_child(friendship_level_selector)

	var achievement_row := HBoxContainer.new()
	achievement_row.add_theme_constant_override("separation", 12)
	content.add_child(achievement_row)
	var achievement_label := Label.new()
	achievement_label.text = _l("Achievement", "성취도")
	achievement_label.custom_minimum_size.x = 120.0
	achievement_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	achievement_row.add_child(achievement_label)
	achievement_level_selector = OptionButton.new()
	achievement_level_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	achievement_level_selector.custom_minimum_size.y = float(AppearanceSettingsScript.UI_CONTROL_HEIGHT)
	achievement_level_selector.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	achievement_level_selector.item_selected.connect(_on_achievement_level_selected)
	achievement_row.add_child(achievement_level_selector)

	progress_output = Label.new()
	progress_output.text = _l(
		"Dropdown changes are debug overrides. Use Actual Progress returns to earned values.",
		"드롭다운 변경은 디버그 덮어쓰기입니다. 원래대로를 누르면 실제 누적값으로 돌아갑니다."
	)
	_style_secondary_label(progress_output)
	progress_output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(progress_output)

	_add_section_header(content, _l("Diagnostics", "진단"), _l(
		"Check content and configuration without modifying the pack.",
		"팩을 수정하지 않고 콘텐츠와 설정 상태를 검사합니다."
	))
	var diagnostic_grid := _create_button_grid()
	diagnostic_grid.columns = 1
	content.add_child(diagnostic_grid)
	_add_button(diagnostic_grid, _l("Validate current pack", "현재 팩 검사"), "validate_pack")

	_add_section_header(content, _l("Output", "출력"), _l(
		"Generated text and test status appear below.",
		"생성된 텍스트와 테스트 상태가 아래에 표시됩니다."
	))
	output = Label.new()
	output.text = _l("No debug action has been run yet.", "아직 실행한 디버그 동작이 없습니다.")
	_style_secondary_label(output)
	output.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	output.custom_minimum_size.y = 72.0
	content.add_child(output)
	return content

func _add_section_header(parent: VBoxContainer, title_text: String, description_text: String) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12.0
	parent.add_child(spacer)
	var heading := Label.new()
	heading.text = title_text
	heading.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	parent.add_child(heading)
	var description := Label.new()
	description.text = description_text
	_style_secondary_label(description)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(description)
	parent.add_child(HSeparator.new())

func _style_secondary_label(label: Label) -> void:
	label.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_SMALL)
	label.add_theme_color_override("font_color", AppearanceSettingsScript.get_ui_color("muted"))

func _create_button_grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", AppearanceSettingsScript.UI_STACK_GAP)
	return grid

func _add_button(parent: GridContainer, label_text: String, action: String) -> void:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size.y = float(AppearanceSettingsScript.UI_CONTROL_HEIGHT)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(_on_button_pressed.bind(action))
	parent.add_child(button)

func _target_slot() -> int:
	return target_selector.selected if target_selector != null else 0

func _on_button_pressed(action: String) -> void:
	if action == "special_boot":
		var month: int = special_month_selector.get_selected_id() if special_month_selector != null else 1
		var day: int = special_day_selector.get_selected_id() if special_day_selector != null else 1
		action = "special_boot:%02d-%02d" % [month, day]
	action_requested.emit(action, _target_slot())

func _on_target_selected(_index: int) -> void:
	action_requested.emit("progress_show", _target_slot())

func _on_friendship_level_selected(index: int) -> void:
	if not progress_syncing:
		action_requested.emit("friendship_level_set:" + str(index), _target_slot())

func _on_achievement_level_selected(index: int) -> void:
	if not progress_syncing:
		action_requested.emit("achievement_level_set:" + str(index), _target_slot())

func _sync_level_selector(selector: OptionButton, selected_level: int, max_level: int) -> void:
	if selector == null:
		return
	selector.clear()
	for level: int in range(maxi(0, max_level) + 1):
		selector.add_item(_l("Level " + str(level), "레벨 " + str(level)))
	selector.select(clampi(selected_level, 0, maxi(0, max_level)))

func set_progress_levels(friendship_level: int, max_friendship_level: int, achievement_level: int, max_achievement_level: int, summary: String) -> void:
	progress_syncing = true
	_sync_level_selector(friendship_level_selector, friendship_level, max_friendship_level)
	_sync_level_selector(achievement_level_selector, achievement_level, max_achievement_level)
	progress_syncing = false
	set_progress_output(summary)

func set_progress_output(text: String) -> void:
	if progress_output != null:
		progress_output.text = text

func set_output(text: String) -> void:
	if output != null:
		output.text = text

func _refresh_special_day_options(_index: int) -> void:
	if special_month_selector == null or special_day_selector == null:
		return
	var month: int = special_month_selector.get_selected_id()
	var max_day: int = 31
	if month in [4, 6, 9, 11]:
		max_day = 30
	elif month == 2:
		max_day = 29
	var previous: int = maxi(1, special_day_selector.get_selected_id())
	special_day_selector.clear()
	for day: int in range(1, max_day + 1):
		special_day_selector.add_item(_l("Day %d" % day, "%d일" % day), day)
	special_day_selector.select(clampi(previous, 1, max_day) - 1)
