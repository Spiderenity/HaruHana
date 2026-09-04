extends VBoxContainer
class_name WeeklyProductivityPanel

signal productivity_status_changed(date_key: String, status: int)

const ReportSettingsScript = preload(
	"res://system/services/report/report_settings.gd"
)

const AppLanguageScript = preload(
	"res://system/app/app_language.gd"
)

const STATUS_UNMARKED := 0
const STATUS_PRODUCTIVE := 1
const STATUS_NOT_PRODUCTIVE := 2

const SECONDS_PER_DAY := 86400

const DAY_NAMES: Array[String] = [
	"Monday",
	"Tuesday",
	"Wednesday",
	"Thursday",
	"Friday",
	"Saturday",
	"Sunday",
]

const DAY_NAMES_KO: Array[String] = [
	"월요일",
	"화요일",
	"수요일",
	"목요일",
	"금요일",
	"토요일",
	"일요일",
]

const DATA_DIR := "user://productivity"

const SAVE_PATH := (
	"user://productivity/current_week.json"
)

var current_week_start: String = ""

var day_statuses: Array[int] = [
	0, 0, 0, 0, 0, 0, 0
]

var focus_minutes: Array[int] = [
	0, 0, 0, 0, 0, 0, 0
]

var session_counts: Array[int] = [
	0, 0, 0, 0, 0, 0, 0
]

var focus_sessions: Array = [
	[],
	[],
	[],
	[],
	[],
	[],
	[]
]

var last_seen_date: String = ""
var startup_message: String = ""

var week_range_label: Label
var summary_label: Label
var save_status_label: Label
var day_rows_container: VBoxContainer
var calendar_timer: Timer

func _ready() -> void:
	add_theme_constant_override(
		"separation",
		10
	)

	ensure_storage_directory()
	prepare_week_state()
	create_interface()
	create_calendar_timer()
	refresh_interface()
	apply_language()

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
	for property_name: String in ["text", "placeholder_text", "tooltip_text"]:
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

	if save_status_label != null:
		save_status_label.text = ""
	startup_message = ""

	if day_rows_container != null:
		rebuild_day_rows()

	if summary_label != null:
		update_summary()

func _day_name(day_index: int) -> String:
	if AppLanguageScript.get_language() == "ko":
		return DAY_NAMES_KO[day_index]

	return DAY_NAMES[day_index]

func ensure_storage_directory() -> void:
	var absolute_directory: String = (
		ProjectSettings.globalize_path(
			DATA_DIR
		)
	)

	if not DirAccess.dir_exists_absolute(
		absolute_directory
	):
		DirAccess.make_dir_recursive_absolute(
			absolute_directory
		)

func prepare_week_state() -> void:
	last_seen_date = (
		Time.get_date_string_from_system(false)
	)

	load_saved_week()

	var actual_week_start: String = (
		get_current_week_start_string()
	)

	if current_week_start.is_empty():
		current_week_start = actual_week_start

		reset_week_data()
		save_current_week()

		startup_message = _l("Current week created.", "이번 주 기록을 만들었습니다.")
		return

	if current_week_start != actual_week_start:
		export_week_report(
			current_week_start,
			day_statuses,
			focus_minutes,
			session_counts,
			focus_sessions
		)

		current_week_start = actual_week_start

		reset_week_data()
		save_current_week()

		startup_message = _l(
			"New week started. Previous week exported.",
			"새 주가 시작되어 지난주 기록을 내보냈습니다."
		)

		return

	startup_message = ""

func load_saved_week() -> void:
	var data: Dictionary = JsonStore.load_dictionary(SAVE_PATH, {})
	if data.is_empty():
		return
	current_week_start = str(data.get("week_start", ""))
	load_status_array(data.get("days", []))
	load_nonnegative_int_array(data.get("focus_minutes", []), focus_minutes)
	load_nonnegative_int_array(data.get("session_counts", []), session_counts)
	load_focus_sessions(data.get("focus_sessions", []))

func load_status_array(
	value: Variant
) -> void:

	if value is not Array:
		return

	var loaded: Array = value

	var amount: int = mini(
		day_statuses.size(),
		loaded.size()
	)

	for index: int in range(amount):
		day_statuses[index] = clampi(
			int(loaded[index]),
			STATUS_UNMARKED,
			STATUS_NOT_PRODUCTIVE
		)

func load_nonnegative_int_array(
	value: Variant,
	target: Array[int]
) -> void:

	if value is not Array:
		return

	var loaded: Array = value

	var amount: int = mini(
		target.size(),
		loaded.size()
	)

	for index: int in range(amount):
		target[index] = maxi(
			0,
			int(loaded[index])
		)

func load_focus_sessions(
	value: Variant
) -> void:

	if value is not Array:
		return

	var loaded_days: Array = value

	var amount: int = mini(
		focus_sessions.size(),
		loaded_days.size()
	)

	for day_index: int in range(amount):
		if loaded_days[day_index] is not Array:
			continue

		var loaded_sessions: Array = (
			loaded_days[day_index]
		)

		var clean_sessions: Array = []

		for entry: Variant in loaded_sessions:
			if entry is not Dictionary:
				continue

			var entry_data: Dictionary = entry

			var task_name: String = str(
				entry_data.get(
					"task",
					"Focus session"
				)
			).strip_edges()

			if task_name.is_empty():
				task_name = "Focus session"

			var minutes: int = maxi(
				0,
				int(
					entry_data.get(
						"minutes",
						0
					)
				)
			)

			clean_sessions.append(
				{
					"task": task_name,
					"minutes": minutes,
				}
			)

		focus_sessions[day_index] = (
			clean_sessions
		)

func save_current_week() -> void:
	var data: Dictionary = {
		"week_start": current_week_start,
		"days": day_statuses,
		"focus_minutes": focus_minutes,
		"session_counts": session_counts,
		"focus_sessions": focus_sessions,
	}
	var save_error: Error = JsonStore.save_json(SAVE_PATH, data)
	if save_error != OK:
		push_error("Could not save weekly productivity data: %s" % error_string(save_error))

func get_current_week_start_string() -> String:
	var today: Dictionary = (
		Time.get_date_dict_from_system(false)
	)

	var weekday: int = int(
		today["weekday"]
	)

	var days_since_monday: int

	if weekday == Time.WEEKDAY_SUNDAY:
		days_since_monday = 6
	else:
		days_since_monday = (
			weekday
			- Time.WEEKDAY_MONDAY
		)

	var today_unix: int = (
		Time.get_unix_time_from_datetime_dict(
			{
				"year": int(today["year"]),
				"month": int(today["month"]),
				"day": int(today["day"]),
				"hour": 0,
				"minute": 0,
				"second": 0,
			}
		)
	)

	var monday_unix: int = (
		today_unix
		- days_since_monday * SECONDS_PER_DAY
	)

	return Time.get_date_string_from_unix_time(
		monday_unix
	)

func get_week_date(
	day_index: int
) -> String:

	var week_start_unix: int = (
		Time.get_unix_time_from_datetime_string(
			current_week_start
		)
	)

	return Time.get_date_string_from_unix_time(
		week_start_unix
		+ day_index * SECONDS_PER_DAY
	)

func reset_week_data() -> void:
	for index: int in range(7):
		day_statuses[index] = STATUS_UNMARKED
		focus_minutes[index] = 0
		session_counts[index] = 0
		focus_sessions[index] = []

func record_focus_session(
	task_name: String,
	minutes: int
) -> void:

	if minutes <= 0:
		return

	check_calendar_state()

	var clean_task_name: String = (
		task_name.strip_edges()
	)

	if clean_task_name.is_empty():
		clean_task_name = _l("Focus session", "집중 세션")

	var today: String = (
		Time.get_date_string_from_system(false)
	)

	for day_index: int in range(
		DAY_NAMES.size()
	):
		if get_week_date(day_index) != today:
			continue

		focus_minutes[day_index] += minutes
		session_counts[day_index] += 1

		focus_sessions[day_index].append(
			{
				"task": clean_task_name,
				"minutes": minutes,
			}
		)

		save_current_week()
		return

func create_interface() -> void:
	var heading := Label.new()

	_bind_localized_text(heading, "This Week", "이번 주")

	heading.add_theme_font_size_override(
		"font_size",
		20
	)

	add_child(heading)

	var explanation := Label.new()

	_bind_localized_text(
		explanation,
		"Mark how each day went. The active week resets every Monday.",
		"하루의 상태를 표시하세요. 기록은 매주 월요일 새로 시작됩니다."
	)

	explanation.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	add_child(explanation)

	week_range_label = Label.new()

	week_range_label.add_theme_font_size_override(
		"font_size",
		16
	)

	add_child(week_range_label)

	add_child(
		HSeparator.new()
	)

	day_rows_container = VBoxContainer.new()

	day_rows_container.add_theme_constant_override(
		"separation",
		8
	)

	add_child(day_rows_container)

	add_child(
		HSeparator.new()
	)

	summary_label = Label.new()

	add_child(summary_label)

	save_status_label = Label.new()

	save_status_label.autowrap_mode = (
		TextServer.AUTOWRAP_WORD_SMART
	)

	add_child(save_status_label)

func refresh_interface() -> void:
	update_week_range()
	rebuild_day_rows()
	update_summary()

	if not startup_message.is_empty():
		save_status_label.text = startup_message
		startup_message = ""

func update_week_range() -> void:
	if current_week_start.is_empty():
		week_range_label.text = ""
		return

	week_range_label.text = (
		"%s  —  %s"
		% [
			current_week_start,
			get_week_date(6),
		]
	)

func rebuild_day_rows() -> void:
	for child: Node in (
		day_rows_container.get_children()
	):
		child.queue_free()

	var today: String = (
		Time.get_date_string_from_system(false)
	)

	for day_index: int in range(
		DAY_NAMES.size()
	):
		var date_string: String = (
			get_week_date(day_index)
		)

		var row := HBoxContainer.new()

		row.add_theme_constant_override(
			"separation",
			12
		)

		day_rows_container.add_child(row)

		var day_label := Label.new()

		day_label.custom_minimum_size = Vector2(
			150,
			0
		)

		if date_string == today:
			day_label.text = (
				_day_name(day_index)
				+ _l("  (Today)", "  (오늘)")
			)
		else:
			day_label.text = (
				_day_name(day_index)
			)

		row.add_child(day_label)

		var date_label := Label.new()

		date_label.text = date_string

		date_label.custom_minimum_size = Vector2(
			120,
			0
		)

		row.add_child(date_label)

		var selector := OptionButton.new()

		selector.size_flags_horizontal = (
			Control.SIZE_EXPAND_FILL
		)

		selector.add_item(_l("Unmarked", "미표시"))
		selector.add_item(_l("Productive", "생산적"))
		selector.add_item(_l("Not productive", "비생산적"))

		selector.select(
			day_statuses[day_index]
		)

		var is_future: bool = (
			date_string > today
		)

		selector.disabled = is_future

		if is_future:
			selector.tooltip_text = _l(
				"Future days can be marked when they arrive.",
				"미래 날짜는 해당 날짜가 된 뒤 표시할 수 있습니다."
			)

		selector.item_selected.connect(
			_on_status_selected.bind(
				day_index
			)
		)

		row.add_child(selector)

func _on_status_selected(
	selected_index: int,
	day_index: int
) -> void:

	var date_string: String = (
		get_week_date(day_index)
	)

	var today: String = (
		Time.get_date_string_from_system(false)
	)

	if date_string > today:
		return

	day_statuses[day_index] = clampi(
		selected_index,
		STATUS_UNMARKED,
		STATUS_NOT_PRODUCTIVE
	)

	save_current_week()
	update_summary()
	productivity_status_changed.emit(date_string, day_statuses[day_index])

	save_status_label.text = _l("Saved.", "저장됨.")

func get_productive_date_keys() -> Array[String]:
	var result: Array[String] = []
	for day_index: int in range(day_statuses.size()):
		if day_statuses[day_index] == STATUS_PRODUCTIVE:
			result.append(get_week_date(day_index))
	return result

func update_summary() -> void:
	var productive_count: int = 0
	var not_productive_count: int = 0
	var unmarked_count: int = 0

	for status: int in day_statuses:
		match status:
			STATUS_PRODUCTIVE:
				productive_count += 1

			STATUS_NOT_PRODUCTIVE:
				not_productive_count += 1

			_:
				unmarked_count += 1

	summary_label.text = (
		_l(
			"Productive: %d    Not productive: %d    Unmarked: %d",
			"생산적: %d    비생산적: %d    미표시: %d"
		)
		% [
			productive_count,
			not_productive_count,
			unmarked_count,
		]
	)

func status_to_text(
	status: int
) -> String:

	match status:
		STATUS_PRODUCTIVE:
			return "Productive"

		STATUS_NOT_PRODUCTIVE:
			return "Not productive"

		_:
			return "Unmarked"

func export_current_week_snapshot() -> String:
	return export_week_report(
		current_week_start,
		day_statuses,
		focus_minutes,
		session_counts,
		focus_sessions
	)

func export_week_report(
	week_start: String,
	statuses: Array[int],
	minutes_data: Array[int],
	sessions_data: Array[int],
	session_logs: Array
) -> String:

	if week_start.is_empty():
		return ""

	if not ReportSettingsScript.ensure_report_directory():
		return ""

	var reports_directory: String = (
		ReportSettingsScript.get_report_directory()
	)

	var week_start_unix: int = (
		Time.get_unix_time_from_datetime_string(
			week_start
		)
	)

	var week_end: String = (
		Time.get_date_string_from_unix_time(
			week_start_unix
			+ 6 * SECONDS_PER_DAY
		)
	)

	var lines := PackedStringArray()

	lines.append(
		"Weekly Productivity Report"
	)

	lines.append(
		"Week: %s to %s"
		% [
			week_start,
			week_end,
		]
	)

	lines.append("")

	var productive_count: int = 0
	var not_productive_count: int = 0
	var unmarked_count: int = 0

	var total_focus_minutes: int = 0
	var total_sessions: int = 0

	for day_index: int in range(
		DAY_NAMES.size()
	):
		var day_date: String = (
			Time.get_date_string_from_unix_time(
				week_start_unix
				+ day_index * SECONDS_PER_DAY
			)
		)

		var status: int = STATUS_UNMARKED
		var minutes: int = 0
		var sessions: int = 0

		if day_index < statuses.size():
			status = statuses[day_index]

		if day_index < minutes_data.size():
			minutes = minutes_data[day_index]

		if day_index < sessions_data.size():
			sessions = sessions_data[day_index]

		lines.append(
			"%s %s"
			% [
				DAY_NAMES[day_index],
				day_date,
			]
		)

		lines.append(
			"  Status: %s"
			% status_to_text(status)
		)

		lines.append(
			"  Focus: %d minutes"
			% minutes
		)

		lines.append(
			"  Sessions: %d"
			% sessions
		)

		if (
			day_index < session_logs.size()
			and session_logs[day_index] is Array
		):
			var day_sessions: Array = (
				session_logs[day_index]
			)

			if not day_sessions.is_empty():
				lines.append(
					"  Session log:"
				)

				for entry: Variant in day_sessions:
					if entry is not Dictionary:
						continue

					var entry_data: Dictionary = entry

					var task: String = str(
						entry_data.get(
							"task",
							"Focus session"
						)
					)

					var session_minutes: int = int(
						entry_data.get(
							"minutes",
							0
						)
					)

					lines.append(
						"    - %d min: %s"
						% [
							session_minutes,
							task,
						]
					)

		match status:
			STATUS_PRODUCTIVE:
				productive_count += 1

			STATUS_NOT_PRODUCTIVE:
				not_productive_count += 1

			_:
				unmarked_count += 1

		total_focus_minutes += minutes
		total_sessions += sessions

	lines.append("")
	lines.append("Summary")

	lines.append(
		"Productive days: %d"
		% productive_count
	)

	lines.append(
		"Not productive days: %d"
		% not_productive_count
	)

	lines.append(
		"Unmarked days: %d"
		% unmarked_count
	)

	lines.append(
		"Focus minutes: %d"
		% total_focus_minutes
	)

	lines.append(
		"Completed sessions: %d"
		% total_sessions
	)

	var report_path: String = (
		reports_directory.path_join(
			"week_"
			+ week_start
			+ ".txt"
		)
	)

	var file: FileAccess = FileAccess.open(
		report_path,
		FileAccess.WRITE
	)

	if file == null:
		return ""

	file.store_string(
		"\n".join(lines)
	)

	return report_path

func create_calendar_timer() -> void:
	calendar_timer = Timer.new()

	calendar_timer.name = "CalendarCheck"
	calendar_timer.wait_time = 60.0
	calendar_timer.one_shot = false
	calendar_timer.autostart = true

	calendar_timer.timeout.connect(
		check_calendar_state
	)

	add_child(calendar_timer)

func check_calendar_state() -> void:
	var today: String = (
		Time.get_date_string_from_system(false)
	)

	var actual_week_start: String = (
		get_current_week_start_string()
	)

	if actual_week_start != current_week_start:
		export_week_report(
			current_week_start,
			day_statuses,
			focus_minutes,
			session_counts,
			focus_sessions
		)

		current_week_start = actual_week_start

		reset_week_data()
		save_current_week()

		last_seen_date = today

		refresh_interface()

		save_status_label.text = _l(
			"New week started. Previous week exported.",
			"새 주가 시작되어 지난주 기록을 내보냈습니다."
		)

		return

	if today != last_seen_date:
		last_seen_date = today

		rebuild_day_rows()
		update_summary()

		save_status_label.text = _l(
			"New day detected.",
			"새 날짜를 감지했습니다."
		)
