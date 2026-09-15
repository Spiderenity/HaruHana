extends Window
class_name CompanionBoardWindow

signal focus_session_started(
	task_name: String,
	planned_minutes: int
)

signal focus_session_paused(
	task_name: String,
	planned_minutes: int
)

signal focus_session_resumed(
	task_name: String,
	planned_minutes: int
)

signal focus_session_stopped(
	task_name: String,
	planned_minutes: int
)

signal focus_session_completed(
	task_name: String,
	planned_minutes: int
)

signal focus_timer_updated(
	seconds_remaining: int,
	active: bool,
	paused: bool
)

signal focus_session_milestone(
	event_key: String,
	task_name: String,
	planned_minutes: int
)

signal pomodoro_phase_started(
	phase: String,
	task_name: String,
	planned_minutes: int
)

signal pomodoro_phase_finished(
	phase: String,
	task_name: String,
	planned_minutes: int
)

signal pomodoro_break_prompted(
	task_name: String,
	planned_minutes: int
)

signal chat_exchange_completed(
	character_id: String,
	user_message: String,
	character_response: String
)

signal schedules_changed

signal debug_action_requested(
	action: String,
	target_slot: int
)

const BOARD_SIZE := Vector2i(
	980,
	720
)

const MIN_BOARD_SIZE := Vector2i(
	820,
	600
)

const LANGUAGE_REFRESH_INTERVAL_SECONDS: float = 0.5

const TAB_ROOT_RIGHT_MARGIN: int = 0
const TAB_SCROLLBAR_WIDTH: float = 6.0
const TAB_SCROLLBAR_CONTENT_GAP: int = 12

const ChatPanelScript = preload(
	"res://system/ui/panels/chat_panel.gd"
)

const FocusTimerPanelScript = preload(
	"res://system/ui/panels/focus_timer.gd"
)

const CalendarPanelScript = preload(
	"res://system/ui/panels/calendar_panel.gd"
)

const MemoPanelScript = preload(
	"res://system/ui/panels/memo_panel.gd"
)

const SettingsPanelScript = preload(
	"res://system/ui/panels/settings_panel.gd"
)

const DebugPanelScript = preload(
	"res://system/ui/panels/debug_panel.gd"
)

const AppLanguageScript = preload(
	"res://system/app/app_language.gd"
)

const AppearanceSettingsScript = preload(
	"res://system/app/appearance_settings.gd"
)

var chat_panel: CompanionChatPanel = null
var focus_timer_panel: FocusTimerPanel = null
var calendar_panel: CalendarPanel = null
var memo_panel: CompanionMemoPanel = null
var settings_panel: CompanionSettingsPanel = null
var interface_panel: PanelContainer = null
var content_surface_panel: PanelContainer = null
var navigation_separator: ColorRect = null
var board_title_label: Label = null
var board_subtitle_prefix: Label = null
var board_settings_trigger: Label = null

var tabs: TabContainer = null
var index_tab_rail: VBoxContainer = null
var index_tab_buttons: Array[Button] = []
var settings_tab_index: int = -1
var debug_tab_index: int = -1
var debug_unlocked: bool = false
var debug_panel: CompanionDebugPanel = null
var last_non_debug_tab_index: int = 1

var language_refresh_accumulator: float = 0.0
var last_interface_language: String = ""
var appearance_refresh_accumulator: float = 0.0
var last_interface_theme: String = ""
var last_bubble_font_signature: String = ""
var empty_theme_icon: Texture2D = null

func _ready() -> void:
	title = _l("Desktop Pet Board", "데스크탑 펫 보드")

	size = BOARD_SIZE
	min_size = MIN_BOARD_SIZE

	borderless = false
	transparent = false
	transparent_bg = false

	always_on_top = false
	unfocusable = false
	unresizable = false

	transient = false

	close_requested.connect(
		_on_close_requested
	)

	create_interface()
	_apply_appearance(true)
	_apply_interface_language(true)
	set_process(true)

	hide()

func _process(delta: float) -> void:
	if not visible:
		return

	language_refresh_accumulator += maxf(0.0, delta)
	appearance_refresh_accumulator += maxf(0.0, delta)

	var current_language: String = AppLanguageScript.get_language()

	if (
		current_language != last_interface_language
		or language_refresh_accumulator >= LANGUAGE_REFRESH_INTERVAL_SECONDS
	):
		language_refresh_accumulator = 0.0
		_apply_interface_language(false)

	if appearance_refresh_accumulator >= 0.25:
		appearance_refresh_accumulator = 0.0
		_apply_appearance(false)

func _l(english: String, korean: String) -> String:
	return AppLanguageScript.text(english, korean)

func _localized_tab_name(tab_name: String) -> String:
	match tab_name:
		"Chat":
			return _l("Chat", "채팅")
		"Timer":
			return _l("Timer", "타이머")
		"Calendar":
			return _l("Calendar", "캘린더")
		"Memo":
			return _l("Memo", "메모")
		"Settings":
			return _l("Settings", "설정")
		"Debug":
			return _l("Debug", "디버그")
		_:
			return tab_name

func _refresh_tab_titles() -> void:
	if tabs == null:
		return

	for index: int in range(tabs.get_tab_count()):
		var child: Node = tabs.get_child(index)
		var localized_name: String = _localized_tab_name(child.name)
		tabs.set_tab_title(index, localized_name)

		if index < index_tab_buttons.size():
			index_tab_buttons[index].text = localized_name

func _apply_appearance(force: bool) -> void:
	if interface_panel == null:
		return

	var theme_id: String = AppearanceSettingsScript.get_theme_signature()
	var bubble_font_signature: String = _get_current_bubble_font_signature()

	if (
		not force
		and theme_id == last_interface_theme
		and bubble_font_signature == last_bubble_font_signature
	):
		return

	interface_panel.theme = AppearanceSettingsScript.build_theme()
	_apply_board_shell_styles()
	_apply_index_tab_styles()
	_apply_scrollbar_styles_recursive(interface_panel)
	if chat_panel != null and is_instance_valid(chat_panel):
		chat_panel.apply_appearance()
	if focus_timer_panel != null and is_instance_valid(focus_timer_panel):
		focus_timer_panel.apply_appearance()
	if memo_panel != null and is_instance_valid(memo_panel):
		memo_panel.apply_appearance()
	if settings_panel != null and is_instance_valid(settings_panel):
		settings_panel.apply_appearance()
	call_deferred("_apply_calendar_appearance")
	last_interface_theme = theme_id
	last_bubble_font_signature = bubble_font_signature

func create_interface() -> void:
	interface_panel = PanelContainer.new()

	interface_panel.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	add_child(interface_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	interface_panel.add_child(margin)

	var vertical := VBoxContainer.new()
	vertical.add_theme_constant_override("separation", 12)
	margin.add_child(vertical)

	create_header(vertical)
	create_tabs(vertical)

func create_header(
	parent: VBoxContainer
) -> void:
	board_title_label = Label.new()
	board_title_label.text = _l("Desktop Pet Board", "데스크탑 펫 보드")
	board_title_label.add_theme_font_size_override(
		"font_size",
		AppearanceSettingsScript.UI_FONT_LARGE
	)
	parent.add_child(board_title_label)

	var subtitle_row := HBoxContainer.new()
	subtitle_row.add_theme_constant_override("separation", 0)
	parent.add_child(subtitle_row)

	board_subtitle_prefix = Label.new()
	board_subtitle_prefix.text = _l(
		"Chat, focus, schedules, notes and desktop pet ",
		"채팅, 집중, 일정, 메모와 데스크탑 펫 "
	)
	board_subtitle_prefix.add_theme_font_size_override(
		"font_size",
		AppearanceSettingsScript.UI_FONT_SMALL
	)
	board_subtitle_prefix.remove_theme_color_override("font_color")
	subtitle_row.add_child(board_subtitle_prefix)

	board_settings_trigger = Label.new()
	board_settings_trigger.text = _l("settings.", "설정.")
	board_settings_trigger.add_theme_font_size_override(
		"font_size",
		AppearanceSettingsScript.UI_FONT_SMALL
	)
	board_settings_trigger.remove_theme_color_override("font_color")
	board_settings_trigger.mouse_filter = Control.MOUSE_FILTER_STOP
	board_settings_trigger.mouse_default_cursor_shape = Control.CURSOR_ARROW
	board_settings_trigger.gui_input.connect(_on_settings_word_gui_input)
	subtitle_row.add_child(board_settings_trigger)

func _on_settings_word_gui_input(
	event: InputEvent
) -> void:

	if not (
		event is InputEventMouseButton
	):
		return

	var mouse_event: InputEventMouseButton = (
		event as InputEventMouseButton
	)

	if (
		mouse_event.button_index
			!= MOUSE_BUTTON_LEFT
		or not mouse_event.pressed
	):
		return

	_toggle_debug_tab()

	get_viewport().set_input_as_handled()

func create_tabs(
	parent: VBoxContainer
) -> void:
	var tab_shell := HBoxContainer.new()
	tab_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_shell.add_theme_constant_override("separation", 10)
	parent.add_child(tab_shell)

	content_surface_panel = PanelContainer.new()
	content_surface_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_surface_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_shell.add_child(content_surface_panel)

	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 14)
	content_margin.add_theme_constant_override("margin_top", 12)
	content_margin.add_theme_constant_override("margin_right", 0)
	content_margin.add_theme_constant_override("margin_bottom", 12)
	content_surface_panel.add_child(content_margin)

	tabs = TabContainer.new()
	tabs.tabs_visible = false
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_child(tabs)

	create_chat_tab(tabs)
	create_timer_tab(tabs)
	create_calendar_tab(tabs)
	create_memo_tab(tabs)
	create_settings_tab(tabs)

	settings_tab_index = tabs.get_child_count() - 1

	create_debug_tab(tabs)
	debug_tab_index = tabs.get_child_count() - 1
	tabs.set_tab_hidden(debug_tab_index, true)
	tabs.current_tab = 1
	last_non_debug_tab_index = tabs.current_tab

	navigation_separator = ColorRect.new()
	navigation_separator.custom_minimum_size.x = 1.0
	navigation_separator.size_flags_vertical = Control.SIZE_EXPAND_FILL
	navigation_separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tab_shell.add_child(navigation_separator)

	var navigation_margin := MarginContainer.new()
	navigation_margin.custom_minimum_size.x = 126
	navigation_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	navigation_margin.add_theme_constant_override("margin_left", 8)
	navigation_margin.add_theme_constant_override("margin_top", 6)
	navigation_margin.add_theme_constant_override("margin_right", 0)
	navigation_margin.add_theme_constant_override("margin_bottom", 6)
	tab_shell.add_child(navigation_margin)

	index_tab_rail = VBoxContainer.new()
	index_tab_rail.custom_minimum_size.x = 118
	index_tab_rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	index_tab_rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	index_tab_rail.alignment = BoxContainer.ALIGNMENT_CENTER
	index_tab_rail.add_theme_constant_override("separation", 8)
	navigation_margin.add_child(index_tab_rail)

	_build_index_tab_buttons()

	if not tabs.tab_changed.is_connected(_on_tab_changed):
		tabs.tab_changed.connect(_on_tab_changed)

	_apply_board_shell_styles()
	_sync_index_tab_buttons()

func _build_index_tab_buttons() -> void:
	if tabs == null or index_tab_rail == null:
		return

	for child: Node in index_tab_rail.get_children():
		child.queue_free()

	index_tab_buttons.clear()

	for index: int in range(tabs.get_tab_count()):
		var tab_child: Node = tabs.get_child(index)
		var button := Button.new()
		button.text = _localized_tab_name(tab_child.name)
		button.custom_minimum_size = Vector2(120, 40)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_index_tab_pressed.bind(index))
		index_tab_rail.add_child(button)
		index_tab_buttons.append(button)

	if (
		debug_tab_index >= 0
		and debug_tab_index < index_tab_buttons.size()
	):
		index_tab_buttons[debug_tab_index].visible = debug_unlocked

	_apply_index_tab_styles()

func _on_index_tab_pressed(tab_index: int) -> void:
	if tabs == null:
		return

	if tab_index < 0 or tab_index >= tabs.get_tab_count():
		return

	if tabs.is_tab_hidden(tab_index):
		return

	tabs.current_tab = tab_index
	if tab_index == debug_tab_index:
		debug_action_requested.emit("progress_show", 0)
	_sync_index_tab_buttons()

func _on_tab_changed(tab_index: int) -> void:
	if tab_index != debug_tab_index:
		last_non_debug_tab_index = tab_index
	_sync_index_tab_buttons()

func _sync_index_tab_buttons() -> void:
	if tabs == null:
		return

	for index: int in range(index_tab_buttons.size()):
		var button: Button = index_tab_buttons[index]
		button.button_pressed = index == tabs.current_tab

func _apply_index_tab_styles() -> void:
	if index_tab_buttons.is_empty():
		return

	var normal_color := Color(0.0, 0.0, 0.0, 0.0)
	var hover_color := AppearanceSettingsScript.get_ui_color("surface_hover")
	var pressed_color := AppearanceSettingsScript.get_ui_color("selection")
	var text_color := AppearanceSettingsScript.get_ui_color("text")

	for button: Button in index_tab_buttons:
		button.add_theme_stylebox_override(
			"normal", _make_index_tab_style(normal_color)
		)
		button.add_theme_stylebox_override(
			"hover", _make_index_tab_style(hover_color)
		)
		button.add_theme_stylebox_override(
			"pressed", _make_index_tab_style(pressed_color)
		)
		button.add_theme_stylebox_override(
			"hover_pressed", _make_index_tab_style(pressed_color)
		)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.add_theme_color_override("font_color", text_color)
		button.add_theme_color_override("font_hover_color", text_color)
		button.add_theme_color_override("font_pressed_color", text_color)

func _make_index_tab_style(
	background_color: Color
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
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

func _make_board_panel_style(
	background_color: Color,
	border_color: Color,
	radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style

func _apply_board_shell_styles() -> void:
	if content_surface_panel == null:
		return

	var content_color := AppearanceSettingsScript.get_ui_color("surface")
	var border_color := AppearanceSettingsScript.get_ui_color("secondary")

	content_surface_panel.add_theme_stylebox_override(
		"panel",
		_make_board_panel_style(content_color, border_color, 12)
	)

	if navigation_separator != null:
		navigation_separator.color = border_color

func _toggle_debug_tab() -> void:
	if tabs == null:
		return

	debug_unlocked = not debug_unlocked

	tabs.set_tab_hidden(
		debug_tab_index,
		not debug_unlocked
	)

	if (
		debug_tab_index >= 0
		and debug_tab_index < index_tab_buttons.size()
	):
		index_tab_buttons[debug_tab_index].visible = debug_unlocked

	if not debug_unlocked and tabs.current_tab == debug_tab_index:
		tabs.current_tab = clampi(
			last_non_debug_tab_index,
			0,
			tabs.get_tab_count() - 1
		)

	_sync_index_tab_buttons()

func are_debug_tools_unlocked() -> bool:
	return debug_unlocked

func _create_tab_root(
	target_tabs: TabContainer,
	tab_name: String
) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.name = tab_name
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 2)
	margin.add_theme_constant_override("margin_top", 2)
	margin.add_theme_constant_override("margin_right", TAB_ROOT_RIGHT_MARGIN)
	margin.add_theme_constant_override(
		"margin_bottom",
		AppearanceSettingsScript.UI_TAB_MARGIN_BOTTOM
	)
	target_tabs.add_child(margin)

	var tab_index: int = target_tabs.get_tab_count() - 1
	target_tabs.set_tab_title(tab_index, _localized_tab_name(tab_name))
	return margin

func add_direct_tab(
	target_tabs: TabContainer,
	tab_name: String,
	content: Control
) -> void:
	var root: MarginContainer = _create_tab_root(target_tabs, tab_name)

	var content_margin := MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override(
		"margin_right",
		TAB_SCROLLBAR_CONTENT_GAP
	)
	root.add_child(content_margin)

	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_child(content)

func add_scrollable_tab(
	target_tabs: TabContainer,
	tab_name: String,
	content: Control
) -> void:
	var root: MarginContainer = _create_tab_root(target_tabs, tab_name)

	var overlay := Control.new()
	overlay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(overlay)

	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.0
	scroll.anchor_top = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 0.0
	scroll.offset_top = 0.0
	scroll.offset_right = -float(TAB_SCROLLBAR_CONTENT_GAP)
	scroll.offset_bottom = 0.0
	scroll.follow_focus = true
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	overlay.add_child(scroll)

	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	var external_bar := VScrollBar.new()
	external_bar.anchor_left = 1.0
	external_bar.anchor_top = 0.0
	external_bar.anchor_right = 1.0
	external_bar.anchor_bottom = 1.0
	external_bar.offset_left = -(TAB_SCROLLBAR_WIDTH * 0.5)
	external_bar.offset_top = 0.0
	external_bar.offset_right = TAB_SCROLLBAR_WIDTH * 0.5
	external_bar.offset_bottom = 0.0
	external_bar.custom_minimum_size.x = TAB_SCROLLBAR_WIDTH
	external_bar.z_index = 20
	external_bar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_external_scroll_bar(external_bar)
	overlay.add_child(external_bar)

	call_deferred("_setup_external_scroll_bar", scroll, external_bar)

func _setup_external_scroll_bar(
	scroll: ScrollContainer,
	external_bar: VScrollBar
) -> void:
	if scroll == null or external_bar == null:
		return

	var native_bar: VScrollBar = scroll.get_v_scroll_bar()
	if native_bar == null:
		return

	_hide_native_scroll_bar(native_bar)
	_sync_external_scroll_bar(native_bar, external_bar)

	if not native_bar.value_changed.is_connected(
		_on_native_scroll_value_changed.bind(external_bar)
	):
		native_bar.value_changed.connect(
			_on_native_scroll_value_changed.bind(external_bar)
		)

	if not external_bar.value_changed.is_connected(
		_on_external_scroll_value_changed.bind(native_bar)
	):
		external_bar.value_changed.connect(
			_on_external_scroll_value_changed.bind(native_bar)
		)

	var changed_callback: Callable = _sync_external_scroll_bar.bind(native_bar, external_bar)
	if not native_bar.changed.is_connected(changed_callback):
		native_bar.changed.connect(changed_callback)

	scroll.resized.connect(
		Callable(self, "_sync_external_scroll_bar").bind(native_bar, external_bar)
	)

func _hide_native_scroll_bar(bar: VScrollBar) -> void:
	bar.set_meta("_external_scroll_proxy_hidden", true)
	bar.modulate.a = 0.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size.x = 0.0

	var empty := StyleBoxEmpty.new()
	bar.add_theme_stylebox_override("scroll", empty)
	bar.add_theme_stylebox_override("scroll_focus", empty)
	bar.add_theme_stylebox_override("grabber", empty)
	bar.add_theme_stylebox_override("grabber_highlight", empty)
	bar.add_theme_stylebox_override("grabber_pressed", empty)

	var empty_icon: Texture2D = _get_empty_theme_icon()
	for icon_name: String in [
		"increment",
		"increment_highlight",
		"increment_pressed",
		"decrement",
		"decrement_highlight",
		"decrement_pressed"
	]:
		bar.add_theme_icon_override(icon_name, empty_icon)

func _style_external_scroll_bar(bar: VScrollBar) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.0, 0.0, 0.0, 0.0)

	var thumb := StyleBoxFlat.new()
	thumb.bg_color = AppearanceSettingsScript.get_ui_color("scrollbar")
	thumb.corner_radius_top_left = 3
	thumb.corner_radius_top_right = 3
	thumb.corner_radius_bottom_left = 3
	thumb.corner_radius_bottom_right = 3

	var thumb_active: StyleBoxFlat = thumb.duplicate()
	thumb_active.bg_color = AppearanceSettingsScript.get_ui_color("scroll_hover")

	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	bar.add_theme_stylebox_override("grabber", thumb)
	bar.add_theme_stylebox_override("grabber_highlight", thumb_active)
	bar.add_theme_stylebox_override("grabber_pressed", thumb_active)
	bar.add_theme_constant_override("grabber_size", 44)
	bar.add_theme_constant_override("padding_left", 0)
	bar.add_theme_constant_override("padding_right", 0)
	bar.custom_minimum_size.x = TAB_SCROLLBAR_WIDTH

	var empty_icon: Texture2D = _get_empty_theme_icon()
	for icon_name: String in [
		"increment",
		"increment_highlight",
		"increment_pressed",
		"decrement",
		"decrement_highlight",
		"decrement_pressed"
	]:
		bar.add_theme_icon_override(icon_name, empty_icon)

func _sync_external_scroll_bar(
	native_bar: VScrollBar,
	external_bar: VScrollBar
) -> void:
	if (
		native_bar == null
		or external_bar == null
		or not is_instance_valid(native_bar)
		or not is_instance_valid(external_bar)
	):
		return

	external_bar.min_value = native_bar.min_value
	external_bar.max_value = native_bar.max_value
	external_bar.page = native_bar.page
	external_bar.step = native_bar.step
	external_bar.set_value_no_signal(native_bar.value)
	external_bar.visible = native_bar.max_value > native_bar.page + 0.5

func _on_native_scroll_value_changed(
	value: float,
	external_bar: VScrollBar
) -> void:
	if external_bar != null and is_instance_valid(external_bar):
		external_bar.set_value_no_signal(value)

func _on_external_scroll_value_changed(
	value: float,
	native_bar: VScrollBar
) -> void:
	if native_bar != null and is_instance_valid(native_bar):
		native_bar.value = value

func _get_current_bubble_font_signature() -> String:
	var settings: Dictionary = AppearanceSettingsScript.load_settings()
	var font_path: String = str(
		settings.get(
			"bubble_font",
			AppearanceSettingsScript.DEFAULT_BUBBLE_FONT
		)
	)
	var font_size: int = int(
		settings.get(
			"bubble_font_size",
			AppearanceSettingsScript.DEFAULT_BUBBLE_FONT_SIZE
		)
	)
	return font_path + "|" + str(font_size)

func _apply_scrollbar_styles_recursive(node: Node) -> void:
	if node is ScrollContainer:
		_apply_single_bar_scroll_style(node as ScrollContainer)

	for child: Node in node.get_children():
		_apply_scrollbar_styles_recursive(child)

func _apply_single_bar_scroll_style(scroll: ScrollContainer) -> void:
	if scroll == null:
		return

	var vbar: VScrollBar = scroll.get_v_scroll_bar()
	if vbar != null:
		if bool(vbar.get_meta("_external_scroll_proxy_hidden", false)):
			_hide_native_scroll_bar(vbar)
		else:
			_style_scroll_bar(vbar, true)

	var hbar: HScrollBar = scroll.get_h_scroll_bar()
	if hbar != null:
		hbar.visible = false

func _style_scroll_bar(bar: ScrollBar, vertical: bool) -> void:
	if bar == null:
		return

	var clear_style: StyleBoxFlat = StyleBoxFlat.new()
	clear_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	clear_style.border_width_top = 0
	clear_style.border_width_right = 0
	clear_style.border_width_bottom = 0
	clear_style.border_width_left = 0
	clear_style.corner_radius_top_left = 6
	clear_style.corner_radius_top_right = 6
	clear_style.corner_radius_bottom_left = 6
	clear_style.corner_radius_bottom_right = 6

	var grabber_style: StyleBoxFlat = StyleBoxFlat.new()
	grabber_style.bg_color = AppearanceSettingsScript.get_ui_color("scrollbar")
	grabber_style.border_width_top = 0
	grabber_style.border_width_right = 0
	grabber_style.border_width_bottom = 0
	grabber_style.border_width_left = 0
	grabber_style.corner_radius_top_left = 4
	grabber_style.corner_radius_top_right = 4
	grabber_style.corner_radius_bottom_left = 4
	grabber_style.corner_radius_bottom_right = 4

	var grabber_hover: StyleBoxFlat = grabber_style.duplicate()
	grabber_hover.bg_color = AppearanceSettingsScript.get_ui_color("scroll_hover")
	var grabber_pressed: StyleBoxFlat = grabber_style.duplicate()
	grabber_pressed.bg_color = AppearanceSettingsScript.get_ui_color("scroll_hover")

	bar.add_theme_stylebox_override("scroll", clear_style)
	bar.add_theme_stylebox_override("scroll_focus", clear_style)
	bar.add_theme_stylebox_override("grabber", grabber_style)
	bar.add_theme_stylebox_override("grabber_highlight", grabber_hover)
	bar.add_theme_stylebox_override("grabber_pressed", grabber_pressed)
	bar.add_theme_constant_override("grabber_size", 44)

	if vertical:
		bar.add_theme_constant_override("padding_left", 0)
		bar.add_theme_constant_override("padding_right", 0)
		bar.custom_minimum_size.x = TAB_SCROLLBAR_WIDTH
	else:
		bar.custom_minimum_size.y = 14.0

	var empty_icon: Texture2D = _get_empty_theme_icon()
	bar.add_theme_icon_override("increment", empty_icon)
	bar.add_theme_icon_override("increment_highlight", empty_icon)
	bar.add_theme_icon_override("decrement", empty_icon)
	bar.add_theme_icon_override("decrement_highlight", empty_icon)
	bar.add_theme_icon_override("increment_pressed", empty_icon)
	bar.add_theme_icon_override("decrement_pressed", empty_icon)

func _get_empty_theme_icon() -> Texture2D:
	if empty_theme_icon != null:
		return empty_theme_icon

	var image: Image = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	empty_theme_icon = ImageTexture.create_from_image(image)
	return empty_theme_icon

func create_chat_tab(
	target_tabs: TabContainer
) -> void:

	chat_panel = (
		ChatPanelScript.new()
	)

	add_direct_tab(
		target_tabs,
		"Chat",
		chat_panel
	)

	if not chat_panel.desktop_chat_exchange_completed.is_connected(_on_desktop_chat_exchange_completed):
		chat_panel.desktop_chat_exchange_completed.connect(_on_desktop_chat_exchange_completed)

func _on_desktop_chat_exchange_completed(
	character_id: String,
	user_message: String,
	character_response: String
) -> void:
	chat_exchange_completed.emit(
		character_id,
		user_message,
		character_response
	)

func create_timer_tab(
	target_tabs: TabContainer
) -> void:

	focus_timer_panel = (
		FocusTimerPanelScript.new()
	)

	add_scrollable_tab(
		target_tabs,
		"Timer",
		focus_timer_panel
	)

	focus_timer_panel.session_started.connect(
		_on_focus_session_started
	)

	focus_timer_panel.session_paused.connect(
		_on_focus_session_paused
	)

	focus_timer_panel.session_resumed.connect(
		_on_focus_session_resumed
	)

	focus_timer_panel.session_stopped.connect(
		_on_focus_session_stopped
	)

	focus_timer_panel.session_finished.connect(
		_on_focus_session_finished
	)

	focus_timer_panel.session_time_updated.connect(
		_on_focus_timer_updated
	)
	focus_timer_panel.session_milestone.connect(
		_on_focus_session_milestone
	)
	focus_timer_panel.pomodoro_phase_started.connect(
		_on_pomodoro_phase_started
	)
	focus_timer_panel.pomodoro_phase_finished.connect(
		_on_pomodoro_phase_finished
	)
	focus_timer_panel.pomodoro_break_prompted.connect(
		_on_pomodoro_break_prompted
	)
func create_calendar_tab(
	target_tabs: TabContainer
) -> void:

	calendar_panel = (
		CalendarPanelScript.new()
	)

	add_scrollable_tab(
		target_tabs,
		"Calendar",
		calendar_panel
	)

	call_deferred(
		"_apply_calendar_appearance"
	)

	if not calendar_panel.schedules_changed.is_connected(_on_calendar_schedules_changed):
		calendar_panel.schedules_changed.connect(_on_calendar_schedules_changed)

func _on_calendar_schedules_changed() -> void:
	schedules_changed.emit()
	call_deferred(
		"_apply_calendar_appearance"
	)

func _apply_calendar_appearance() -> void:
	if (
		calendar_panel == null
		or not is_instance_valid(calendar_panel)
	):
		return

	calendar_panel.apply_appearance()

func create_memo_tab(
	target_tabs: TabContainer
) -> void:
	memo_panel = MemoPanelScript.new()
	add_direct_tab(target_tabs, "Memo", memo_panel)

func create_settings_tab(
	target_tabs: TabContainer
) -> void:

	settings_panel = (
		SettingsPanelScript.new()
	)

	add_scrollable_tab(
		target_tabs,
		"Settings",
		settings_panel
	)

	var created_tab_index: int = target_tabs.get_child_count() - 1
	target_tabs.set_tab_title(
		created_tab_index,
		AppLanguageScript.text(
			"Settings",
			"설정"
		)
	)

	if not settings_panel.interface_language_changed.is_connected(_on_settings_interface_language_changed):
		settings_panel.interface_language_changed.connect(_on_settings_interface_language_changed)

func _on_settings_interface_language_changed(
	_language: String
) -> void:
	_apply_interface_language(true)

func _apply_interface_language(
	force: bool = false
) -> void:
	var current_language: String = AppLanguageScript.get_language()

	if (
		not force
		and current_language == last_interface_language
	):
		return

	last_interface_language = current_language

	if chat_panel != null and is_instance_valid(chat_panel):
		chat_panel.apply_language()
	if focus_timer_panel != null and is_instance_valid(focus_timer_panel):
		focus_timer_panel.apply_language()
	if calendar_panel != null and is_instance_valid(calendar_panel):
		calendar_panel.apply_language()
	if settings_panel != null and is_instance_valid(settings_panel):
		settings_panel.apply_language()
	if memo_panel != null and is_instance_valid(memo_panel):
		memo_panel.apply_language()

	title = _l(
		"Desktop Pet Board",
		"데스크탑 펫 보드"
	)
	if board_title_label != null:
		board_title_label.text = _l("Desktop Pet Board", "데스크탑 펫 보드")
	if board_subtitle_prefix != null:
		board_subtitle_prefix.text = _l(
			"Chat, focus, schedules, notes and desktop pet ",
			"채팅, 집중, 일정, 메모와 데스크탑 펫 "
		)
	if board_settings_trigger != null:
		board_settings_trigger.text = _l("settings.", "설정.")

	_refresh_tab_titles()

func create_debug_tab(
	target_tabs: TabContainer
) -> void:
	debug_panel = DebugPanelScript.new()
	debug_panel.action_requested.connect(_on_debug_panel_action_requested)
	add_scrollable_tab(target_tabs, "Debug", debug_panel.create_content())

func _on_debug_panel_action_requested(action: String, target_slot: int) -> void:
	debug_action_requested.emit(action, target_slot)

func set_debug_progress_levels(
	friendship_level: int,
	max_friendship_level: int,
	achievement_level: int,
	max_achievement_level: int,
	summary: String
) -> void:
	if debug_panel != null:
		debug_panel.set_progress_levels(
			friendship_level, max_friendship_level,
			achievement_level, max_achievement_level, summary
		)

func set_debug_progress_output(text: String) -> void:
	if debug_panel != null:
		debug_panel.set_progress_output(text)

func set_debug_output(text: String) -> void:
	if debug_panel != null:
		debug_panel.set_output(text)

func _on_focus_session_started(
	task_name: String,
	planned_minutes: int
) -> void:

	focus_session_started.emit(
		task_name,
		planned_minutes
	)

func _on_focus_session_paused(
	task_name: String,
	planned_minutes: int
) -> void:

	focus_session_paused.emit(
		task_name,
		planned_minutes
	)

func _on_focus_session_resumed(
	task_name: String,
	planned_minutes: int
) -> void:

	focus_session_resumed.emit(
		task_name,
		planned_minutes
	)

func _on_focus_session_stopped(
	task_name: String,
	planned_minutes: int
) -> void:

	focus_session_stopped.emit(
		task_name,
		planned_minutes
	)

func _on_focus_session_finished(
	task_name: String,
	planned_minutes: int
) -> void:

	if calendar_panel != null and is_instance_valid(calendar_panel):
		calendar_panel.record_focus_session(planned_minutes)

	focus_session_completed.emit(
		task_name,
		planned_minutes
	)

func _on_focus_timer_updated(
	seconds_remaining: int,
	active: bool,
	paused: bool
) -> void:
	focus_timer_updated.emit(seconds_remaining, active, paused)

func _on_focus_session_milestone(
	event_key: String,
	task_name: String,
	planned_minutes: int
) -> void:
	focus_session_milestone.emit(event_key, task_name, planned_minutes)

func _on_pomodoro_phase_started(
	phase: String,
	task_name: String,
	planned_minutes: int
) -> void:
	pomodoro_phase_started.emit(phase, task_name, planned_minutes)

func _on_pomodoro_phase_finished(
	phase: String,
	task_name: String,
	planned_minutes: int
) -> void:
	pomodoro_phase_finished.emit(phase, task_name, planned_minutes)

func _on_pomodoro_break_prompted(
	task_name: String,
	planned_minutes: int
) -> void:
	pomodoro_break_prompted.emit(task_name, planned_minutes)

func open_tab(
	tab_name: String
) -> bool:

	if tabs == null:
		return false

	var clean_name: String = (
		tab_name.strip_edges()
	)

	for index: int in range(
		tabs.get_tab_count()
	):
		var tab_child: Node = tabs.get_child(index)
		var matches_title: bool = tabs.get_tab_title(index) == clean_name
		var matches_internal_name: bool = str(tab_child.name) == clean_name
		if not matches_title and not matches_internal_name:
			continue

		if tabs.is_tab_hidden(
			index
		):
			return false

		tabs.current_tab = index

		if not visible:
			center_on_screen()
			show()

		else:
			grab_focus()

		return true

	return false

func start_quick_timer(
	minutes: int
) -> bool:
	if focus_timer_panel == null:
		return false
	return focus_timer_panel.start_quick_session(minutes, "")

func toggle_board() -> void:
	if visible:
		hide()
		return

	center_on_screen()
	show()

func center_on_screen() -> void:
	var screen: Rect2i = (
		DisplayServer.screen_get_usable_rect()
	)

	var maximum_initial_size := Vector2i(
		maxi(
			400,
			screen.size.x - 80
		),
		maxi(
			350,
			screen.size.y - 80
		)
	)

	if size.x > maximum_initial_size.x:
		size.x = maximum_initial_size.x

	if size.y > maximum_initial_size.y:
		size.y = maximum_initial_size.y

	position = Vector2i(
		screen.position.x
			+ roundi(
				(
					screen.size.x
					- size.x
				) / 2.0
			),

		screen.position.y
			+ roundi(
				(
					screen.size.y
					- size.y
				) / 2.0
			)
	)

func get_interactive_memo_context(max_characters: int = 600) -> String:
	if memo_panel == null:
		return ""
	return memo_panel.get_context(max_characters)

func save_memo_now() -> void:
	if memo_panel != null:
		memo_panel.save_now()

func _on_close_requested() -> void:
	save_memo_now()

	hide()
