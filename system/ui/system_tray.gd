extends StatusIndicator
class_name CompanionTray

const AppLanguageScript = preload(
	"res://system/app/app_language.gd"
)

signal open_board_requested

signal open_board_tab_requested(
	tab_name: String
)

signal quick_timer_requested(
	minutes: int
)

signal quit_requested

var tray_menu: RID
var tray_menu_created: bool = false

func _l(english: String, korean: String) -> String:
	return AppLanguageScript.text(english, korean)

func refresh_language() -> void:
	tooltip = _l("Companion", "컴패니언")

	if tray_menu_created:
		NativeMenu.free_menu(tray_menu)
		tray_menu_created = false

	if NativeMenu.has_feature(NativeMenu.FEATURE_POPUP_MENU):
		create_tray_menu()

func _ready() -> void:
	tooltip = _l("Companion", "컴패니언")

	if not DisplayServer.has_feature(
		DisplayServer.FEATURE_STATUS_INDICATOR
	):
		visible = false
		return

	ensure_icon()

	pressed.connect(
		_on_tray_pressed
	)

	if NativeMenu.has_feature(
		NativeMenu.FEATURE_POPUP_MENU
	):
		create_tray_menu()

	configure_taskbar_menu()

	visible = true

func ensure_icon() -> void:
	if icon != null:
		return

	if ResourceLoader.exists(
		"res://assets/icon/icon.svg"
	):
		var loaded_icon: Resource = load(
			"res://assets/icon/icon.svg"
		)

		if loaded_icon is Texture2D:
			icon = loaded_icon as Texture2D

	if icon == null:
		push_warning(
			"SystemTray has no icon. "
			+ "Assign a Texture2D to its Icon property."
		)

func create_tray_menu() -> void:
	tray_menu = NativeMenu.create_menu()

	tray_menu_created = true

	NativeMenu.add_item(
		tray_menu,
		_l("Chat", "채팅"),
		_on_menu_item,
		Callable(),
		"open_chat"
	)

	NativeMenu.add_item(
		tray_menu,
		_l("Calendar", "캘린더"),
		_on_menu_item,
		Callable(),
		"open_calendar"
	)

	NativeMenu.add_item(
		tray_menu,
		_l("Timer", "타이머"),
		_on_menu_item,
		Callable(),
		"open_timer"
	)

	NativeMenu.add_item(
		tray_menu,
		_l("Week", "주간"),
		_on_menu_item,
		Callable(),
		"open_week"
	)

	NativeMenu.add_item(
		tray_menu,
		_l("Memo", "메모"),
		_on_menu_item,
		Callable(),
		"open_memo"
	)

	NativeMenu.add_item(
		tray_menu,
		_l("Settings", "설정"),
		_on_menu_item,
		Callable(),
		"open_settings"
	)

	NativeMenu.add_separator(
		tray_menu
	)

	NativeMenu.add_item(
		tray_menu,
		_l("Start 15 min timer", "15분 타이머 시작"),
		_on_menu_item,
		Callable(),
		"timer_15"
	)

	NativeMenu.add_separator(
		tray_menu
	)

	NativeMenu.add_item(
		tray_menu,
		_l("Quit", "종료"),
		_on_menu_item,
		Callable(),
		"quit"
	)

func _on_tray_pressed(
	mouse_button: int,
	mouse_position: Vector2i
) -> void:

	if mouse_button == MOUSE_BUTTON_LEFT:
		open_board_requested.emit()
		return

	if mouse_button == MOUSE_BUTTON_RIGHT:
		if tray_menu_created:
			NativeMenu.popup(
				tray_menu,
				mouse_position
			)

		else:
			open_board_requested.emit()

func configure_taskbar_menu() -> void:
	if OS.get_name() != "Windows" or not Engine.has_singleton("MousePassthrough"):
		return
	var native_bridge: Object = Engine.get_singleton("MousePassthrough")
	if not native_bridge.has_method("set_taskbar_tasks"):
		return
	var tasks: Array = [
		{"title": _l("Chat", "채팅"), "action": "open_chat"},
		{"title": _l("Calendar", "캘린더"), "action": "open_calendar"},
		{"title": _l("Timer", "타이머"), "action": "open_timer"},
		{"title": _l("Week", "주간"), "action": "open_week"},
		{"title": _l("Memo", "메모"), "action": "open_memo"},
		{"title": _l("Settings", "설정"), "action": "open_settings"},
		{"title": _l("Start 15 min timer", "15분 타이머 시작"), "action": "timer_15"},
		{"title": _l("Quit", "종료"), "action": "quit"},
	]
	var host_window := get_window()
	if host_window == null:
		return
	var configured: bool = native_bridge.set_taskbar_tasks(
		host_window.get_window_id(),
		OS.get_executable_path(),
		tasks
	)
	if not configured:
		push_warning("Windows taskbar commands could not be registered.")

func _on_menu_item(
	action: Variant
) -> void:
	dispatch_action(str(action))

func dispatch_action(command: String) -> void:
	match command.strip_edges().to_lower():
		"open_board":
			open_board_requested.emit()

		"open_chat":
			open_board_tab_requested.emit(
				"Chat"
			)

		"open_calendar":
			open_board_tab_requested.emit(
				"Calendar"
			)

		"open_timer":
			open_board_tab_requested.emit(
				"Timer"
			)

		"open_week":
			open_board_tab_requested.emit(
				"Week"
			)

		"open_memo":
			open_board_tab_requested.emit(
				"Memo"
			)

		"open_settings":
			open_board_tab_requested.emit(
				"Settings"
			)

		"timer_15":
			quick_timer_requested.emit(
				15
			)

		"quit":
			quit_requested.emit()

func _exit_tree() -> void:
	if tray_menu_created:
		NativeMenu.free_menu(
			tray_menu
		)

		tray_menu_created = false
