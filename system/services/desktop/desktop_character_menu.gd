extends Node
class_name DesktopCharacterMenu

signal tab_requested(tab_name: String)
signal talk_action_requested(action: String, detail: String)
signal interactive_answer_selected(answer: Dictionary)
signal interactive_question_dismissed(reason: String)
signal normal_menu_visibility_changed(is_open: bool)

const AppLanguageScript = preload("res://system/app/app_language.gd")
const AppearanceSettingsScript = preload("res://system/app/appearance_settings.gd")
const DesktopSpeechTypewriterScript = preload("res://system/services/desktop/desktop_speech_typewriter.gd")
const SegmentedBubbleBackgroundScript = preload("res://system/services/desktop/segmented_bubble_background.gd")
const CharacterProfilesScript = preload("res://system/services/characters/character_profiles.gd")
const UserProfileSettingsScript = preload("res://system/app/user_profile_settings.gd")
const AISettingsScript = preload("res://system/services/ai/ai_settings.gd")

const MENU_WIDTH: int = 276
const MENU_MAX_HEIGHT: int = 360
const MENU_CAP_MARGIN_MAX: int = 48
const MENU_CAP_CONTENT_PADDING: int = 6
const MENU_SIDE_CONTENT_MARGIN: int = 18
const MENU_CONTENT_WIDTH: float = 240.0
const MENU_ICON_SIZE := Vector2(56.0, 48.0)
const MENU_APPEARANCE_REFRESH_SECONDS := 0.5
const MENU_BUTTON_REVEAL_DELAY_SECONDS := 0.18
const MENU_IDLE_TIMEOUT_SECONDS := 20.0
const INTERACTIVE_QUESTION_TIMEOUT_SECONDS := 20.0

const MENU_ICON_FILENAMES: Dictionary = {
	"Chat": "menu_chat.png",
	"Timer": "menu_timer.png",
	"Calendar": "menu_calendar.png",
	"Week": "menu_week.png",
	"Memo": "menu_memo.png",
	"Settings": "menu_settings.png",
}

const TAB_ITEMS: Array[Dictionary] = [
	{"tab": "Chat", "en": "Chat", "ko": "채팅"},
	{"tab": "Timer", "en": "Timer", "ko": "타이머"},
	{"tab": "Calendar", "en": "Calendar", "ko": "캘린더"},
	{"tab": "Week", "en": "Week", "ko": "주간"},
	{"tab": "Memo", "en": "Memo", "ko": "메모"},
	{"tab": "Settings", "en": "Settings", "ko": "설정"},
]

var owner_actor: DesktopCharacterActor = null
var menu_window: Window = null
var menu_panel: PanelContainer = null
var menu_margin: MarginContainer = null
var menu_root: VBoxContainer = null
var intro_label: Label = null
var description_label: Label = null
var content_host: VBoxContainer = null
var divider: ColorRect = null
var typewriter: DesktopSpeechTypewriter = null
var page_reveal_serial: int = 0
var background_host: Control = null
var segmented_background: SegmentedBubbleBackground = null

var current_page: String = "main"
var introduction_text: String = ""
var appearance_refresh_accumulator: float = 0.0
var last_appearance_signature: String = ""
var outside_click_armed: bool = false
var last_left_pressed: bool = false
var last_right_pressed: bool = false
var talk_intro_shown: bool = false
var menu_opening: bool = false
var menu_open_serial: int = 0
var requested_window_size: Vector2i = Vector2i(MENU_WIDTH, 1)
var interactive_question_active: bool = false
var interactive_question_data: Dictionary = {}
var interactive_question_timer: Timer = null
var menu_idle_timer: Timer = null
var normal_menu_active: bool = false
var custom_talk_input: TextEdit = null

func configure(actor: DesktopCharacterActor) -> void:
	owner_actor = actor
	_create_window()
	_create_interactive_question_timer()
	_create_menu_idle_timer()
	set_process(true)

func _exit_tree() -> void:
	_set_normal_menu_active(false)
	if menu_window != null and is_instance_valid(menu_window):
		menu_window.queue_free()
	menu_window = null

func _l(english: String, korean: String) -> String:
	return AppLanguageScript.text(english, korean)

func is_open() -> bool:
	return (
		menu_window != null
		and is_instance_valid(menu_window)
		and menu_window.visible
	)

func toggle_menu() -> void:
	if interactive_question_active:
		return
	if is_open() or menu_opening:
		hide_menu()
		return
	show_menu()

func show_menu() -> void:
	if interactive_question_active:
		return
	if owner_actor == null or not is_instance_valid(owner_actor):
		return
	if menu_window == null or not is_instance_valid(menu_window):
		_create_window()
	if menu_window == null:
		return
	if menu_opening:
		return

	owner_actor.close_peer_character_menus()

	menu_open_serial += 1
	var open_serial: int = menu_open_serial
	menu_opening = true
	menu_window.hide()

	current_page = "main"
	talk_intro_shown = false
	introduction_text = _get_menu_intro()

	_apply_appearance(true)
	_rebuild_main_page(false)

	_prepare_layout_before_show()

	if open_serial != menu_open_serial:
		return
	if owner_actor == null or not is_instance_valid(owner_actor):
		menu_opening = false
		return
	if menu_window == null or not is_instance_valid(menu_window):
		menu_opening = false
		return

	_sync_window_geometry()
	menu_window.show()
	_reconcile_native_window_size()
	menu_window.grab_focus()
	_set_normal_menu_active(true)

	outside_click_armed = false
	last_left_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	last_right_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	menu_opening = false

	await get_tree().process_frame
	if open_serial != menu_open_serial or not is_open():
		return
	_reconcile_native_window_size()
	_position_window()

	_start_intro_typewriter()

func hide_menu(force: bool = false) -> void:
	if interactive_question_active and not force:
		return
	_hide_window()

func is_interactive_question_open() -> bool:
	return interactive_question_active and is_open()

func can_show_interactive_question(question: Dictionary) -> bool:
	if owner_actor == null or not is_instance_valid(owner_actor):
		return false
	if str(question.get("text", "")).strip_edges().is_empty():
		return false
	var answers_value: Variant = question.get("answers", [])
	if not (answers_value is Array) or (answers_value as Array).size() < 2:
		return false
	if menu_window == null or not is_instance_valid(menu_window):
		_create_window()
	return menu_window != null and is_instance_valid(menu_window)

func show_interactive_question(question: Dictionary) -> bool:
	if not can_show_interactive_question(question):
		return false

	_hide_window()
	owner_actor.close_peer_character_menus()

	interactive_question_active = true
	interactive_question_data = question.duplicate(true)
	menu_open_serial += 1
	var open_serial: int = menu_open_serial
	menu_opening = true
	menu_window.hide()
	current_page = "question"
	talk_intro_shown = false
	introduction_text = str(question.get("text", "")).strip_edges()

	_apply_appearance(true)
	_rebuild_interactive_question_page()
	Callable(_finish_interactive_question_open).call_deferred(open_serial)
	return true

func _finish_interactive_question_open(open_serial: int) -> void:
	_prepare_layout_before_show()

	if open_serial != menu_open_serial or not interactive_question_active:
		return
	if owner_actor == null or not is_instance_valid(owner_actor):
		_close_interactive_question("invalid", false)
		return
	if menu_window == null or not is_instance_valid(menu_window):
		interactive_question_active = false
		interactive_question_data.clear()
		menu_opening = false
		return

	_sync_window_geometry()
	menu_window.show()
	_reconcile_native_window_size()
	menu_window.grab_focus()
	outside_click_armed = false
	last_left_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	last_right_pressed = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	menu_opening = false

	await get_tree().process_frame
	if open_serial != menu_open_serial or not is_interactive_question_open():
		return
	_reconcile_native_window_size()
	_position_window()
	_start_page_typewriter(introduction_text)

func _hide_window() -> void:
	menu_open_serial += 1
	menu_opening = false
	page_reveal_serial += 1
	_set_normal_menu_active(false)
	if menu_idle_timer != null:
		menu_idle_timer.stop()
	if interactive_question_timer != null:
		interactive_question_timer.stop()
	if typewriter != null:
		typewriter.cancel()
	if menu_window != null and is_instance_valid(menu_window):
		menu_window.hide()
	current_page = "main"
	outside_click_armed = false

func _create_interactive_question_timer() -> void:
	if interactive_question_timer != null:
		return
	interactive_question_timer = Timer.new()
	interactive_question_timer.name = "InteractiveQuestionTimeout"
	interactive_question_timer.one_shot = true
	interactive_question_timer.ignore_time_scale = true
	interactive_question_timer.timeout.connect(_on_interactive_question_timeout)
	add_child(interactive_question_timer)

func _create_menu_idle_timer() -> void:
	if menu_idle_timer != null:
		return
	menu_idle_timer = Timer.new()
	menu_idle_timer.name = "CharacterMenuIdleTimeout"
	menu_idle_timer.one_shot = true
	menu_idle_timer.ignore_time_scale = true
	menu_idle_timer.timeout.connect(_on_menu_idle_timeout)
	add_child(menu_idle_timer)

func _set_normal_menu_active(active: bool) -> void:
	if normal_menu_active == active:
		return
	normal_menu_active = active
	normal_menu_visibility_changed.emit(active)

func _stop_menu_idle_timeout() -> void:
	if menu_idle_timer != null:
		menu_idle_timer.stop()

func _arm_menu_idle_timeout() -> void:
	if interactive_question_active or not normal_menu_active:
		return
	if menu_idle_timer != null:
		menu_idle_timer.start(MENU_IDLE_TIMEOUT_SECONDS)

func _on_menu_idle_timeout() -> void:
	if interactive_question_active or not normal_menu_active:
		return
	hide_menu()

func _create_window() -> void:
	if owner_actor == null or not is_instance_valid(owner_actor):
		return
	if menu_window != null and is_instance_valid(menu_window):
		return

	var character_window: Window = owner_actor.get_window()
	if character_window == null:
		return
	var window_container: Node = character_window.get_parent()
	if window_container == null:
		return

	menu_window = Window.new()
	menu_window.name = "CharacterMenuWindow"
	menu_window.size = Vector2i(MENU_WIDTH, 1)
	menu_window.borderless = true
	menu_window.transparent = true
	menu_window.transparent_bg = true
	menu_window.unresizable = true
	menu_window.wrap_controls = false
	menu_window.unfocusable = false
	menu_window.always_on_top = true
	menu_window.transient = false
	menu_window.mouse_passthrough = false
	menu_window.visible = false
	menu_window.close_requested.connect(owner_actor.request_application_close)
	window_container.add_child(menu_window)
	menu_window.focus_exited.connect(_on_menu_window_focus_exited)

	background_host = Control.new()
	background_host.name = "BackgroundHost"
	background_host.set_anchors_preset(Control.PRESET_TOP_LEFT)
	background_host.position = Vector2.ZERO
	background_host.size = Vector2(float(MENU_WIDTH), 1.0)
	background_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_host.custom_minimum_size = Vector2.ZERO
	menu_window.add_child(background_host)

	segmented_background = SegmentedBubbleBackgroundScript.new()
	segmented_background.name = "SegmentedBubbleBackground"
	segmented_background.set_anchors_preset(Control.PRESET_TOP_LEFT)
	segmented_background.position = Vector2.ZERO
	segmented_background.size = background_host.size
	segmented_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background_host.add_child(segmented_background)

	menu_panel = PanelContainer.new()
	menu_panel.name = "CharacterMenu"
	menu_panel.position = Vector2.ZERO
	menu_panel.size = Vector2(float(MENU_WIDTH), 1.0)
	menu_panel.custom_minimum_size = Vector2(float(MENU_WIDTH), 0.0)
	menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_window.add_child(menu_panel)
	menu_panel.gui_input.connect(_on_menu_panel_gui_input)

	menu_margin = MarginContainer.new()
	menu_margin.name = "MenuMargin"
	menu_margin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	menu_margin.add_theme_constant_override("margin_left", MENU_SIDE_CONTENT_MARGIN)
	menu_margin.add_theme_constant_override("margin_top", 18)
	menu_margin.add_theme_constant_override("margin_right", MENU_SIDE_CONTENT_MARGIN)
	menu_margin.add_theme_constant_override("margin_bottom", 18)
	menu_panel.add_child(menu_margin)

	menu_root = VBoxContainer.new()
	menu_root.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	menu_root.add_theme_constant_override("separation", 6)
	menu_margin.add_child(menu_root)

	intro_label = Label.new()
	intro_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro_label.custom_minimum_size.y = 30.0
	intro_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(intro_label)

	description_label = Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.custom_minimum_size.y = 16.0
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(description_label)

	divider = ColorRect.new()
	divider.custom_minimum_size.y = 1.0
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_root.add_child(divider)

	content_host = VBoxContainer.new()
	content_host.custom_minimum_size.y = 0.0
	content_host.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content_host.add_theme_constant_override("separation", 6)
	menu_root.add_child(content_host)

	typewriter = DesktopSpeechTypewriterScript.new()
	typewriter.name = "MenuTypewriter"
	add_child(typewriter)
	typewriter.configure(intro_label)
	if not typewriter.finished.is_connected(_on_intro_finished):
		typewriter.finished.connect(_on_intro_finished)

	_apply_appearance(true)

func _get_menu_intro() -> String:
	var character_id: String = _get_character_id()
	var user_name: String = UserProfileSettingsScript.get_user_name()
	if user_name.is_empty():
		user_name = _l("user", "유저")
	var character_line: String = CharacterProfilesScript.get_fallback_line(
		character_id,
		"menu",
		{"{user_name}": user_name}
	)
	if not character_line.is_empty():
		return character_line
	return _l("Need anything?", "뭐 필요한 거 있어?")

func _get_character_id() -> String:
	if owner_actor == null:
		return ""
	return owner_actor.get_character_id().strip_edges().to_lower()

func _get_talk_heading() -> String:
	return _l("What do you want to talk about?", "무슨 얘기를 할까?")

func _default_page_description() -> String:
	match current_page:
		"main":
			return _l("Menu", "메뉴")
		"talk":
			return _l("Talk", "대화")
		"question":
			return _l("Question", "질문")
		"custom_talk":
			return _current_model_display_name()
		_:
			if current_page.begins_with("talk_"):
				return _talk_action_label(current_page.trim_prefix("talk_"))
	return _l("Menu", "메뉴")

func _tab_hover_description(tab_name: String) -> String:
	for item: Dictionary in TAB_ITEMS:
		if str(item.get("tab", "")) == tab_name:
			return _l(
				str(item.get("en", tab_name)),
				str(item.get("ko", tab_name))
			)
	return tab_name

func _talk_hover_description(action_id: String) -> String:
	match action_id:
		"talk": return _l("Talk", "대화")
		"hello": return _l("Hello", "인사")
		"ask": return _l("Ask", "질문")
		"praise": return _l("Praise", "칭찬")
		"free": return _current_model_display_name()
		"back": return _l("Back", "뒤로")
	return _default_page_description()

func _detail_hover_description(label: String) -> String:
	return label

func _set_header_revealed(revealed: bool) -> void:
	if description_label != null:
		description_label.visible = true
		description_label.modulate.a = 1.0 if revealed else 0.0
	if divider != null:
		divider.visible = true
		divider.modulate.a = 1.0 if revealed else 0.0

func _set_content_revealed(revealed: bool) -> void:
	if content_host == null:
		return

	content_host.visible = true
	content_host.modulate.a = 1.0 if revealed else 0.0
	_set_buttons_disabled_recursive(content_host, not revealed)

func _set_buttons_disabled_recursive(node: Node, disabled: bool) -> void:
	for child: Node in node.get_children():
		if child is Button:
			(child as Button).disabled = disabled
		_set_buttons_disabled_recursive(child, disabled)

func _start_intro_typewriter() -> void:
	_start_page_typewriter(introduction_text)

func _start_page_typewriter(text: String) -> void:
	if intro_label == null:
		return

	page_reveal_serial += 1
	_set_header_revealed(false)
	_set_content_revealed(false)

	intro_label.custom_minimum_size.y = 30.0
	intro_label.text = text
	intro_label.visible_characters = -1
	intro_label.custom_minimum_size.y = maxf(
		30.0,
		_measure_label_height(intro_label, MENU_CONTENT_WIDTH)
	)
	intro_label.visible_characters = 0

	_request_window_geometry_refresh()

	if typewriter == null:
		intro_label.visible_characters = -1
		_on_intro_finished()
		return

	var speed: float = 30.0
	if owner_actor != null:
		speed = maxf(1.0, owner_actor.typewriter_characters_per_second)

	var allowed_moods: Array[String] = ["neutral"]
	typewriter.start(text, "neutral", allowed_moods, speed)

func _on_intro_finished() -> void:
	if intro_label != null:
		intro_label.visible_characters = -1

	_set_header_revealed(true)

	var reveal_serial: int = page_reveal_serial
	await get_tree().create_timer(
		MENU_BUTTON_REVEAL_DELAY_SECONDS
	).timeout

	if reveal_serial != page_reveal_serial:
		return
	if not is_open():
		return

	_set_content_revealed(true)
	if interactive_question_active and interactive_question_timer != null:
		interactive_question_timer.start(INTERACTIVE_QUESTION_TIMEOUT_SECONDS)
	else:
		_arm_menu_idle_timeout()

func _clear_content() -> void:
	if content_host == null:
		return
	custom_talk_input = null
	for child: Node in content_host.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false
		content_host.remove_child(child)
		child.queue_free()

func _rebuild_main_page(show_immediately: bool = true) -> void:
	_stop_menu_idle_timeout()
	if show_immediately:
		page_reveal_serial += 1
	current_page = "main"
	_clear_content()
	if intro_label != null:
		intro_label.custom_minimum_size.y = 30.0
		intro_label.text = introduction_text
		if show_immediately:
			intro_label.visible_characters = -1
	if description_label != null:
		description_label.text = _default_page_description()
	_set_header_revealed(show_immediately)

	if _get_character_id() == "crt":
		var grid := GridContainer.new()
		grid.columns = 3
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		content_host.add_child(grid)

		for item: Dictionary in TAB_ITEMS:
			var tab_name: String = str(item.get("tab", ""))
			var label: String = _l(str(item.get("en", tab_name)), str(item.get("ko", tab_name)))
			var button: Button = _make_icon_button(
				tab_name,
				_tab_hover_description(tab_name),
				label
			)
			button.pressed.connect(_on_tab_pressed.bind(tab_name))
			grid.add_child(button)

	var talk_label: String = _l("Talk", "대화")
	var talk_button: Button = _make_wide_button(talk_label, _talk_hover_description("talk"))
	talk_button.pressed.connect(_show_talk_page)
	content_host.add_child(talk_button)

	_set_content_revealed(show_immediately)
	if show_immediately:
		_arm_menu_idle_timeout()
		_request_window_geometry_refresh()

func _rebuild_interactive_question_page() -> void:
	current_page = "question"
	_clear_content()
	intro_label.custom_minimum_size.y = 30.0
	intro_label.text = introduction_text
	intro_label.visible_characters = 0
	if description_label != null:
		description_label.text = _default_page_description()
	_set_header_revealed(false)

	var answers: Array = interactive_question_data.get("answers", []) as Array
	for answer_value: Variant in answers:
		if not (answer_value is Dictionary):
			continue
		var answer: Dictionary = (answer_value as Dictionary).duplicate(true)
		var label: String = str(answer.get("text", "")).strip_edges()
		if label.is_empty():
			continue
		var button := _make_wide_button(label, label)
		button.pressed.connect(_on_interactive_answer_pressed.bind(answer))
		content_host.add_child(button)

	_set_content_revealed(false)

func _show_talk_page(typewrite_heading: bool = true) -> void:
	_stop_menu_idle_timeout()
	var should_typewrite: bool = (
		typewrite_heading
		and not talk_intro_shown
	)

	if should_typewrite:
		talk_intro_shown = true
	else:
		page_reveal_serial += 1

	current_page = "talk"
	_clear_content()

	var talk_heading: String = _get_talk_heading()
	intro_label.custom_minimum_size.y = 30.0
	intro_label.text = talk_heading
	intro_label.visible_characters = -1
	if description_label != null:
		description_label.text = _default_page_description()

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	content_host.add_child(grid)

	var hello_label: String = _l("Say hello", "인사하기")
	var hello := _make_wide_button(hello_label, _talk_hover_description("hello"))
	hello.pressed.connect(_on_hello_pressed)
	grid.add_child(hello)

	for action_info: Dictionary in [
		{"id": "ask", "en": "Ask", "ko": "질문"},
		{"id": "praise", "en": "Praise", "ko": "칭찬"},
		{"id": "free", "en": "Free", "ko": "자유"},
	]:
		var action_id: String = str(action_info.get("id", ""))
		var label: String = _l(
			str(action_info.get("en", action_id)),
			str(action_info.get("ko", action_id))
		)
		var button := _make_wide_button(
			label,
			_talk_hover_description(action_id)
		)
		if action_id == "free":
			button.pressed.connect(_on_free_talk_pressed)
		else:
			button.pressed.connect(
				_show_talk_detail_page.bind(action_id)
			)
		grid.add_child(button)

	var back_label: String = _l("Back", "뒤로")
	var back := _make_wide_button(
		back_label,
		_talk_hover_description("back")
	)
	back.pressed.connect(_rebuild_main_page.bind(true))
	content_host.add_child(back)

	if should_typewrite:
		_start_page_typewriter(talk_heading)
	else:
		_set_header_revealed(true)
		_set_content_revealed(true)
		_request_window_geometry_refresh()
		_arm_menu_idle_timeout()

func _show_talk_detail_page(action_id: String) -> void:
	_stop_menu_idle_timeout()
	page_reveal_serial += 1
	current_page = "talk_" + action_id
	_clear_content()
	var action_label: String = _talk_action_label(action_id)
	intro_label.custom_minimum_size.y = 30.0
	intro_label.text = action_label
	intro_label.visible_characters = -1
	if description_label != null:
		description_label.text = _default_page_description()
	_set_header_revealed(true)

	var options: Array[Dictionary] = _talk_options(action_id)
	for option: Dictionary in options:
		var detail_id: String = str(option.get("id", "other"))
		var label: String = _l(str(option.get("en", "Option")), str(option.get("ko", "선택지")))
		var button := _make_wide_button(label, _detail_hover_description(label))
		button.pressed.connect(_on_talk_option_pressed.bind(action_id, detail_id))
		content_host.add_child(button)

	var back_label: String = _l("Back", "뒤로")
	var back := _make_wide_button(back_label, _talk_hover_description("back"))
	back.pressed.connect(_show_talk_page.bind(false))
	content_host.add_child(back)

	_set_content_revealed(true)
	_request_window_geometry_refresh()
	_arm_menu_idle_timeout()

func _talk_options(action_id: String) -> Array[Dictionary]:
	match action_id:
		"ask":
			return [
				{"id": "week", "en": "About this week", "ko": "이번 주에 대해"},
				{"id": "self", "en": "About you", "ko": "너에 대해"},
				{"id": "controls", "en": "Controls", "ko": "조작 설명"},
			]
		"praise":
			return [
				{"id": "great_job", "en": "Great job", "ko": "잘했어"},
				{"id": "cute", "en": "You're cute", "ko": "귀여워"},
				{"id": "thanks", "en": "Thank you", "ko": "고마워"},
			]
		_:
			return []

func _on_free_talk_pressed() -> void:
	var settings: Dictionary = AISettingsScript.load_settings()
	var api_key: String = str(settings.get("api_key", "")).strip_edges()
	var model: String = str(settings.get("model", "")).strip_edges()
	if api_key.is_empty() or model.is_empty():
		hide_menu()
		talk_action_requested.emit("custom_unavailable", "")
		return
	_show_custom_talk_page()

func _current_model_display_name() -> String:
	var model: String = AISettingsScript.get_model().strip_edges()
	for preset: Dictionary in AISettingsScript.MODEL_PRESETS:
		if str(preset.get("route", "")) == model:
			return str(preset.get("label", model))
	if model.contains("::"):
		return model.get_slice("::", 1)
	return model

func _show_custom_talk_page() -> void:
	_stop_menu_idle_timeout()
	page_reveal_serial += 1
	current_page = "custom_talk"
	_clear_content()
	intro_label.custom_minimum_size.y = 30.0
	intro_label.text = _l("Free", "자유")
	intro_label.visible_characters = -1
	if description_label != null:
		description_label.text = _current_model_display_name()
	_set_header_revealed(true)

	custom_talk_input = TextEdit.new()
	custom_talk_input.name = "CustomTalkInput"
	custom_talk_input.max_length = 2000
	custom_talk_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_talk_input.custom_minimum_size.y = 40.0
	custom_talk_input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	custom_talk_input.scroll_fit_content_height = true
	custom_talk_input.placeholder_text = _l(
		"Type a message...",
		"메시지를 입력해 줘..."
	)
	custom_talk_input.theme = AppearanceSettingsScript.build_theme()
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = AppearanceSettingsScript.get_ui_color("surface_alt")
	input_style.set_corner_radius_all(8)
	input_style.content_margin_left = 10.0
	input_style.content_margin_right = 10.0
	input_style.content_margin_top = 7.0
	input_style.content_margin_bottom = 7.0
	custom_talk_input.add_theme_stylebox_override("normal", input_style)
	var input_focus_style: StyleBoxFlat = input_style.duplicate()
	input_focus_style.bg_color = AppearanceSettingsScript.get_ui_color("surface_pressed")
	custom_talk_input.add_theme_stylebox_override("focus", input_focus_style)
	custom_talk_input.text_changed.connect(_on_custom_talk_text_changed)
	content_host.add_child(custom_talk_input)

	var send_button := _make_wide_button(
		_l("Send", "보내기"),
		_l("Send", "보내기")
	)
	send_button.pressed.connect(_submit_custom_talk)
	content_host.add_child(send_button)

	var back_button := _make_wide_button(
		_l("Back", "뒤로"),
		_talk_hover_description("back")
	)
	back_button.pressed.connect(_show_talk_page.bind(false))
	content_host.add_child(back_button)

	_set_content_revealed(true)
	_request_window_geometry_refresh()
	custom_talk_input.call_deferred("grab_focus")

func _on_custom_talk_text_changed() -> void:
	if custom_talk_input == null:
		return
	var visual_lines: int = 0
	for line_index: int in range(custom_talk_input.get_line_count()):
		visual_lines += 1 + custom_talk_input.get_line_wrap_count(line_index)
	custom_talk_input.custom_minimum_size.y = clampf(
		40.0 + float(maxi(0, visual_lines - 1)) * 20.0,
		40.0,
		120.0
	)
	_request_window_geometry_refresh()

func _submit_custom_talk() -> void:
	if custom_talk_input == null:
		return
	var message: String = custom_talk_input.text.strip_edges()
	if message.is_empty():
		custom_talk_input.grab_focus()
		return
	hide_menu()
	talk_action_requested.emit("custom", message)

func _talk_action_label(action_id: String) -> String:
	match action_id:
		"ask": return _l("Ask", "질문")
		"praise": return _l("Praise", "칭찬")
		"free": return _l("Free", "자유")
		_: return _l("Talk", "대화")

func _make_icon_button(tab_name: String, hover_label: String, fallback_text: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = MENU_ICON_SIZE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(_set_hover_description.bind(hover_label))
	button.mouse_exited.connect(_restore_page_description)

	var texture: Texture2D = _load_menu_icon_texture(tab_name)
	if texture != null:
		button.icon = texture
		button.text = ""
		button.expand_icon = false
		button.set_meta("menu_text_fallback", false)
	else:
		button.text = fallback_text
		button.set_meta("menu_text_fallback", true)

	_style_menu_button(button)
	return button

func _load_menu_icon_texture(tab_name: String) -> Texture2D:
	var filename: String = str(
		MENU_ICON_FILENAMES.get(tab_name, "")
	).strip_edges()
	if filename.is_empty():
		return null

	var settings: Dictionary = AppearanceSettingsScript.load_settings()
	var bubble_skin: String = str(
		settings.get(
			"bubble_skin",
			AppearanceSettingsScript.DEFAULT_BUBBLE_SKIN
		)
	).strip_edges()

	if not AppearanceSettingsScript.is_bubble_skin_valid(bubble_skin):
		bubble_skin = AppearanceSettingsScript.DEFAULT_BUBBLE_SKIN

	var icon_path: String = bubble_skin.path_join(filename)

	if icon_path.begins_with("res://") and ResourceLoader.exists(icon_path):
		var resource: Resource = ResourceLoader.load(icon_path)
		if resource is Texture2D:
			return resource as Texture2D

	var readable_path: String = icon_path
	if icon_path.begins_with("res://") or icon_path.begins_with("user://"):
		readable_path = ProjectSettings.globalize_path(icon_path)

	if not FileAccess.file_exists(readable_path):
		return null

	var image: Image = Image.load_from_file(readable_path)
	if image == null or image.is_empty():
		return null

	return ImageTexture.create_from_image(image)

func _make_wide_button(text: String, hover_label: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 32.0
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_entered.connect(_set_hover_description.bind(hover_label))
	button.mouse_exited.connect(_restore_page_description)
	_style_menu_button(button)
	return button

func _style_menu_button(button: Button) -> void:
	if button == null:
		return
	var settings: Dictionary = AppearanceSettingsScript.load_settings()
	var font_path: String = str(settings.get("bubble_font", AppearanceSettingsScript.DEFAULT_BUBBLE_FONT))
	var bubble_skin: String = str(settings.get("bubble_skin", AppearanceSettingsScript.DEFAULT_BUBBLE_SKIN))
	var text_color: Color = AppearanceSettingsScript.get_bubble_skin_text_color(bubble_skin)
	var font_size: int = clampi(
		int(settings.get("bubble_font_size", AppearanceSettingsScript.DEFAULT_BUBBLE_FONT_SIZE)),
		12,
		52
	)
	var font: Font = AppearanceSettingsScript.get_bubble_font(font_path)
	if font != null:
		button.add_theme_font_override("font", font)
	else:
		button.remove_theme_font_override("font")
	var button_font_size: int = font_size
	if bool(button.get_meta("menu_text_fallback", false)):
		button_font_size = clampi(roundi(float(font_size) * 0.5), 11, 14)
	button.add_theme_font_size_override("font_size", button_font_size)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = text_color
	hover.bg_color.a = 0.10
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("hover_pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _set_hover_description(value: String) -> void:
	if description_label == null:
		return
	if description_label.text == value:
		return
	description_label.text = value
	_request_window_geometry_refresh()

func _restore_page_description() -> void:
	if description_label == null:
		return
	var value := _default_page_description()
	if description_label.text == value:
		return
	description_label.text = value
	_request_window_geometry_refresh()

func _on_tab_pressed(tab_name: String) -> void:
	if _get_character_id() != "crt":
		return
	hide_menu()
	tab_requested.emit(tab_name)

func _on_hello_pressed() -> void:
	hide_menu()
	talk_action_requested.emit("hello", "")

func _on_talk_option_pressed(action: String, detail: String) -> void:
	hide_menu()
	talk_action_requested.emit(action, detail)

func _on_interactive_answer_pressed(answer: Dictionary) -> void:
	if not interactive_question_active:
		return
	var result: Dictionary = answer.duplicate(true)
	_close_interactive_question("answered", false)
	interactive_answer_selected.emit(result)

func _on_interactive_question_timeout() -> void:
	_close_interactive_question("timeout", true)

func _close_interactive_question(reason: String, emit_dismissed: bool) -> void:
	if not interactive_question_active:
		return
	interactive_question_active = false
	interactive_question_data.clear()
	_hide_window()
	if emit_dismissed:
		interactive_question_dismissed.emit(reason)

func _sync_window_geometry() -> void:
	_sync_menu_surface_alpha()
	_refresh_window_height()
	_position_window()

func _sync_menu_surface_alpha() -> void:
	if menu_panel == null or not is_instance_valid(menu_panel):
		return
	var alpha: float = 1.0
	if owner_actor != null:
		alpha = owner_actor.get_menu_alpha()
	var color: Color = menu_panel.modulate
	color.a = clampf(alpha, 0.0, 1.0)
	menu_panel.modulate = color
	if background_host != null and is_instance_valid(background_host):
		var background_color: Color = background_host.modulate
		background_color.a = color.a
		background_host.modulate = background_color

func _refresh_window_height() -> void:
	if menu_window == null or menu_panel == null or menu_margin == null:
		return

	var desired_height: int = ceili(_measure_menu_height())

	var usable_screen: Rect2i = DisplayServer.screen_get_usable_rect()
	var screen_limit: int = maxi(1, usable_screen.size.y - 24)
	desired_height = clampi(
		desired_height,
		1,
		mini(MENU_MAX_HEIGHT, screen_limit)
	)

	_apply_exact_window_size(Vector2i(MENU_WIDTH, desired_height))

func _measure_menu_height() -> float:
	if menu_margin == null or menu_root == null:
		return 1.0

	var top_margin: float = float(menu_margin.get_theme_constant("margin_top"))
	var bottom_margin: float = float(menu_margin.get_theme_constant("margin_bottom"))
	return top_margin + _measure_vbox_height(menu_root, MENU_CONTENT_WIDTH) + bottom_margin

func _measure_control_height(control: Control, available_width: float) -> float:
	if control == null or not control.visible:
		return 0.0

	if control is Label:
		return _measure_label_height(control as Label, available_width)
	if control is GridContainer:
		return _measure_grid_height(control as GridContainer, available_width)
	if control is VBoxContainer:
		return _measure_vbox_height(control as VBoxContainer, available_width)

	if control.custom_minimum_size.y > 0.0:
		return control.custom_minimum_size.y
	return control.get_minimum_size().y

func _measure_label_height(label: Label, available_width: float) -> float:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	if font == null or label.text.is_empty():
		return label.custom_minimum_size.y

	var measured: Vector2 = font.get_multiline_string_size(
		label.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		maxf(1.0, available_width),
		font_size
	)
	return maxf(label.custom_minimum_size.y, ceilf(measured.y))

func _measure_vbox_height(box: VBoxContainer, available_width: float) -> float:
	var total: float = 0.0
	var visible_count: int = 0
	for child: Node in box.get_children():
		if not (child is Control):
			continue
		var control := child as Control
		if not control.visible:
			continue
		total += _measure_control_height(control, available_width)
		visible_count += 1
	if visible_count > 1:
		total += float(box.get_theme_constant("separation")) * float(visible_count - 1)
	return maxf(box.custom_minimum_size.y, total)

func _measure_grid_height(grid: GridContainer, available_width: float) -> float:
	var controls: Array[Control] = []
	for child: Node in grid.get_children():
		if child is Control and (child as Control).visible:
			controls.append(child as Control)
	if controls.is_empty():
		return grid.custom_minimum_size.y

	var columns: int = maxi(1, grid.columns)
	var h_separation: float = float(grid.get_theme_constant("h_separation"))
	var v_separation: float = float(grid.get_theme_constant("v_separation"))
	var cell_width: float = maxf(
		1.0,
		(available_width - h_separation * float(columns - 1)) / float(columns)
	)
	var rows: int = ceili(float(controls.size()) / float(columns))
	var total: float = 0.0
	for row: int in range(rows):
		var row_height: float = 0.0
		for column: int in range(columns):
			var index: int = row * columns + column
			if index >= controls.size():
				break
			row_height = maxf(
				row_height,
				_measure_control_height(controls[index], cell_width)
			)
		total += row_height
	if rows > 1:
		total += v_separation * float(rows - 1)
	return maxf(grid.custom_minimum_size.y, total)

func _apply_exact_window_size(target_size: Vector2i) -> void:
	if menu_window == null or menu_panel == null:
		return

	requested_window_size = Vector2i(
		maxi(1, target_size.x),
		maxi(1, target_size.y)
	)

	menu_window.min_size = Vector2i.ZERO
	menu_window.max_size = Vector2i.ZERO
	menu_window.size = requested_window_size
	menu_window.min_size = requested_window_size
	menu_window.max_size = requested_window_size

	var exact_size := Vector2(requested_window_size)
	menu_panel.size = exact_size

	if background_host != null and is_instance_valid(background_host):
		background_host.position = Vector2.ZERO
		background_host.size = exact_size
	if segmented_background != null and is_instance_valid(segmented_background):
		segmented_background.position = Vector2.ZERO
		segmented_background.size = exact_size
		segmented_background.queue_redraw()

func _prepare_layout_before_show() -> void:
	if menu_panel != null:
		menu_panel.size.x = float(MENU_WIDTH)
	if menu_margin != null:
		menu_margin.size.x = float(MENU_WIDTH)
	if menu_root != null:
		menu_root.size.x = MENU_CONTENT_WIDTH
	if intro_label != null:
		intro_label.size.x = MENU_CONTENT_WIDTH
	if description_label != null:
		description_label.size.x = MENU_CONTENT_WIDTH
	if content_host != null:
		content_host.size.x = MENU_CONTENT_WIDTH

func _request_window_geometry_refresh() -> void:
	if menu_window == null or not is_instance_valid(menu_window):
		return
	_sync_window_geometry()

func _queue_menu_layout() -> void:
	if menu_panel != null:
		menu_panel.queue_sort()
	if menu_margin != null:
		menu_margin.queue_sort()
	if menu_root != null:
		menu_root.queue_sort()
	if content_host != null:
		content_host.queue_sort()

func _reconcile_native_window_size() -> void:
	if menu_window == null or not is_instance_valid(menu_window):
		return
	if not menu_window.visible:
		return

	var window_id: int = menu_window.get_window_id()
	if window_id < 0:
		return

	var native_size: Vector2i = DisplayServer.window_get_size(window_id)
	if native_size == requested_window_size:
		return

	_apply_exact_window_size(requested_window_size)

func _position_window() -> void:
	if menu_window == null or owner_actor == null:
		return
	var requested_size := Vector2(requested_window_size)
	var rect: Rect2 = owner_actor.get_interaction_menu_rect(requested_size)
	menu_window.position = Vector2i(roundi(rect.position.x), roundi(rect.position.y))
	menu_panel.size = Vector2(requested_window_size)

func _apply_appearance(force: bool = false) -> void:
	if menu_panel == null or intro_label == null:
		return
	var settings: Dictionary = AppearanceSettingsScript.load_settings()
	var font_path: String = str(settings.get("bubble_font", AppearanceSettingsScript.DEFAULT_BUBBLE_FONT))
	var font_size: int = clampi(int(settings.get("bubble_font_size", AppearanceSettingsScript.DEFAULT_BUBBLE_FONT_SIZE)), 12, 52)
	var bubble_skin: String = str(settings.get("bubble_skin", AppearanceSettingsScript.DEFAULT_BUBBLE_SKIN))
	var text_color: Color = AppearanceSettingsScript.get_bubble_skin_text_color(bubble_skin)
	var bubble_alpha: float = 1.0
	if owner_actor != null:
		bubble_alpha = clampf(owner_actor.get_speech_bubble_alpha(), 0.0, 1.0)
	var signature := (
		font_path
		+ "|" + str(font_size)
		+ "|" + bubble_skin
		+ "|" + text_color.to_html(true)
		+ "|" + str(snappedf(bubble_alpha, 0.001))
	)
	if not force and signature == last_appearance_signature:
		return

	var menu_color: Color = menu_panel.modulate
	menu_color.a = bubble_alpha
	menu_panel.modulate = menu_color
	if background_host != null and is_instance_valid(background_host):
		var background_color: Color = background_host.modulate
		background_color.a = bubble_alpha
		background_host.modulate = background_color

	var font: Font = AppearanceSettingsScript.get_bubble_font(font_path)
	if font != null:
		intro_label.add_theme_font_override("font", font)
		if description_label != null:
			description_label.add_theme_font_override("font", font)
	else:
		intro_label.remove_theme_font_override("font")
		if description_label != null:
			description_label.remove_theme_font_override("font")
	intro_label.add_theme_font_size_override("font_size", font_size)
	intro_label.add_theme_color_override("font_color", text_color)
	if description_label != null:
		var panel_font_ratio: float = (
			float(AppearanceSettingsScript.UI_FONT_SMALL)
			/ float(AppearanceSettingsScript.UI_FONT_MEDIUM)
		)
		var description_font_size: int = maxi(
			1,
			roundi(float(font_size) * panel_font_ratio)
		)
		description_label.add_theme_font_size_override(
			"font_size",
			description_font_size
		)
		var description_color: Color = text_color
		description_color.a *= 0.62
		description_label.add_theme_color_override("font_color", description_color)

	if divider != null:
		divider.color = text_color

	var textures: Dictionary = AppearanceSettingsScript.get_bubble_skin_textures(bubble_skin)
	if segmented_background != null and not textures.is_empty():
		segmented_background.configure(textures)
		segmented_background.show()
		menu_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_apply_segmented_margins()
	_restyle_buttons_recursive(menu_panel)
	last_appearance_signature = signature
	_request_window_geometry_refresh()

func _restyle_buttons_recursive(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Button:
			_style_menu_button(child as Button)
		_restyle_buttons_recursive(child)

func _apply_segmented_margins() -> void:
	if segmented_background == null or menu_margin == null:
		return
	var width := float(MENU_WIDTH)
	var top_height := segmented_background.get_top_height(width)
	var bottom_height := segmented_background.get_bottom_height(width)
	menu_margin.add_theme_constant_override("margin_left", MENU_SIDE_CONTENT_MARGIN)
	menu_margin.add_theme_constant_override(
		"margin_top",
		clampi(
			maxi(14, ceili(top_height) + MENU_CAP_CONTENT_PADDING),
			14,
			MENU_CAP_MARGIN_MAX
		)
	)
	menu_margin.add_theme_constant_override("margin_right", MENU_SIDE_CONTENT_MARGIN)
	menu_margin.add_theme_constant_override(
		"margin_bottom",
		clampi(
			maxi(14, ceili(bottom_height) + MENU_CAP_CONTENT_PADDING),
			14,
			MENU_CAP_MARGIN_MAX
		)
	)

func _on_menu_window_focus_exited() -> void:
	if interactive_question_active:
		return
	if is_open():
		hide_menu()

func _on_menu_panel_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if not mouse_event.pressed:
		return

	var top_height: float = 0.0
	if segmented_background != null and is_instance_valid(segmented_background):
		top_height = segmented_background.get_top_height(float(menu_panel.size.x))

	if mouse_event.position.y <= top_height:
		if interactive_question_active:
			_close_interactive_question("top", true)
		else:
			hide_menu()
		menu_panel.accept_event()

func _update_click_off_close() -> void:
	if not is_open() or interactive_question_active:
		return

	var left_pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var right_pressed: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

	if not outside_click_armed:
		if not left_pressed and not right_pressed:
			outside_click_armed = true
	else:
		var new_press: bool = (
			(left_pressed and not last_left_pressed)
			or (right_pressed and not last_right_pressed)
		)

		if new_press and menu_window != null:
			var desktop_mouse_i: Vector2i = DisplayServer.mouse_get_position()
			var desktop_mouse := Vector2(
				float(desktop_mouse_i.x),
				float(desktop_mouse_i.y)
			)
			var menu_rect := Rect2(
				Vector2(menu_window.position),
				Vector2(menu_window.size)
			)

			if not menu_rect.has_point(desktop_mouse):
				hide_menu()

	last_left_pressed = left_pressed
	last_right_pressed = right_pressed

func _process(delta: float) -> void:
	if not is_open():
		return
	_sync_menu_surface_alpha()
	_update_click_off_close()
	if not is_open():
		return
	_position_window()
	appearance_refresh_accumulator += maxf(0.0, delta)
	if appearance_refresh_accumulator >= MENU_APPEARANCE_REFRESH_SECONDS:
		appearance_refresh_accumulator = 0.0
		_apply_appearance(false)
