extends Control

const ThemeKit = preload("res://system/tools/character_creator/scripts/creator_theme.gd")
const CreatorNamingScript = preload("res://system/tools/character_creator/scripts/creator_naming.gd")
const BubbleBackgroundScript = preload("res://system/services/desktop/segmented_bubble_background.gd")
const DesktopManagerScript = preload("res://system/services/desktop/desktop_character_manager.gd")
const AppearanceSettingsScript = preload("res://system/app/appearance_settings.gd")
const AppLanguageScript = preload("res://system/app/app_language.gd")
const ThemedColorPickerScript = preload("res://system/tools/shared/themed_color_picker.gd")
const RuntimeInstanceCoordinatorScript = preload("res://system/services/runtime/runtime_instance_coordinator.gd")
const DEFAULT := "res://assets/bubbles/default"
const CHARACTERS := "res://characters/crt_chip/sprites"
const PARTS: Array[String] = ["top", "middle", "bottom"]
const MENU_PARTS: Array[String] = [
	"menu_chat",
	"menu_timer",
	"menu_calendar",
	"menu_memo",
	"menu_settings",
]
const MENU_LABELS: Dictionary = {
	"menu_chat": "Chat",
	"menu_timer": "Timer",
	"menu_calendar": "Calendar",
	"menu_memo": "Memo",
	"menu_settings": "Settings",
}
const COLOR_PRESETS: Array[Dictionary] = [
	{"label":"Blue", "color":"#2C67C5"}, {"label":"Green", "color":"#48A04C"},
	{"label":"Yellow", "color":"#B8802B"}, {"label":"Pink", "color":"#CF6194"},
	{"label":"Orange", "color":"#D25E28"}, {"label":"Purple", "color":"#7849D1"}
]
const KO: Dictionary = {
	"Bubble Creator":"말풍선 크리에이터", "Bubble":"말풍선", "Sprites":"스프라이트", "Save":"저장",
	"Name the bubble, choose text color, enter custom text, and test it.":"말풍선 이름과 글자 색상을 정하고 사용자 문구를 시험합니다.",
	"Upload 280 px-wide PNG segments; height may vary.":"너비 280px PNG 조각을 업로드하세요. 높이는 자유입니다.",
	"Upload and preview bubble assets.":"말풍선 에셋을 업로드하고 미리 봅니다.",
	"PNG only · bubble segments exactly 280 px wide · Advanced menu buttons exactly 56×48":"PNG만 가능 · 말풍선 조각은 너비 280px · 고급 메뉴 버튼은 정확히 56×48",
	"Review missing items and save to assets/bubbles.":"누락 항목을 확인하고 assets/bubbles에 저장합니다.",
	"Bubble name":"말풍선 이름", "Text color":"글자 색상", "Custom test text":"시험 문구",
	"Test bubble":"말풍선 시험", "Upload":"업로드", "Clear":"삭제", "Default":"기본", "Uploaded":"업로드됨",
	"Test":"테스트",
	"Top":"위", "Middle":"가운데", "Bottom":"아래", "Save bubble":"말풍선 저장",
	"Missing":"누락", "Ready to save":"저장 준비 완료", "Custom":"사용자 지정",
	"Blue":"블루", "Green":"그린", "Yellow":"옐로", "Pink":"핑크", "Orange":"오렌지", "Purple":"퍼플",
	"Design segmented speech bubbles for CRT, Chip, and every desktop character.":"CRT, Chip과 모든 데스크톱 캐릭터용 분할 말풍선을 디자인합니다.",
	"Not set":"설정 안 됨", "Bubble package":"말풍선 패키지", "Name":"이름", "Folder":"폴더",
	"Could not load that PNG.":"PNG를 불러올 수 없습니다.", "Width must be exactly 280 px.":"너비는 정확히 280px여야 합니다.",
	"Ready. Alt-click CRT or Chip, or press Test bubble.":"준비되었습니다. CRT 또는 Chip을 Alt+클릭하거나 말풍선 시험을 누르세요.",
	"Preview characters are displayed at the desktop's bottom-left.":"미리보기 캐릭터가 데스크톱 왼쪽 아래에 표시됩니다.",
	"Preview":"미리보기", "BUBBLE":"BUBBLE · 말풍선", "Bubble files":"말풍선 파일",
	"Hello world":"hello world", "Menu":"메뉴",
	"All required bubble images are uploaded.":"필수 말풍선 이미지가 모두 업로드되었습니다.",
	"Upload every required bubble image before saving.":"저장하기 전에 모든 필수 말풍선 이미지를 업로드하세요.",
	"Ready":"준비됨",
	"Start editing":"편집 시작",
	"Choose how to start this Bubble Creator session.":"말풍선 크리에이터 작업을 어떻게 시작할지 선택하세요.",
	"Start from scratch":"처음부터 시작하기",
	"Start new":"새로 만들기",
	"Use preset":"프리셋 사용하기",
	"Open":"열기",
	"Open existing bubble":"기존 말풍선 열기",
	"Choose a bubble.json from assets/bubbles":"assets/bubbles에서 bubble.json을 선택하세요",
	"Sprite mode":"스프라이트 모드",
	"Advanced":"고급",
	"MENU · Menu buttons":"MENU · 메뉴 버튼",
	"Menu buttons":"메뉴 버튼",
	"All required menu button images are uploaded.":"필수 메뉴 버튼 이미지가 모두 업로드되었습니다.",
	"Advanced mode requires all five menu button images.":"고급 모드에서는 메뉴 버튼 이미지 5개가 모두 필요합니다.",
	"56×48 PNG":"56×48 PNG",
	"Chat":"채팅",
	"Timer":"타이머",
	"Calendar":"캘린더",
	"Memo":"메모",
	"Settings":"설정",
	"Could not open that bubble package.":"말풍선 패키지를 열 수 없습니다.",
	"Imported bubble package":"말풍선 패키지를 불러왔습니다",
	"Menu button images must be exactly 56×48 px.":"메뉴 버튼 이미지는 정확히 56×48px여야 합니다."
}

var tabs: TabContainer
var nav: Array[Button] = []
var name_edit: LineEdit
var color_selector: OptionButton
var color_picker: LineEdit
var sample_edit: TextEdit
var status: Label
var summary: VBoxContainer
var save_button: Button
var stage: Control
var bubble: Control
var bubble_bg: Control
var bubble_label: Label
var dialog: FileDialog
var pending := ""
var paths: Dictionary = {}
var thumbnails: Dictionary = {}
var path_labels: Dictionary = {}
var textures: Dictionary = {}
var creator_window: Window
var desktop_manager: DesktopCharacterManager
var runtime_instance_coordinator: RuntimeInstanceCoordinator
var preview_actors: Array[DesktopCharacterActor] = []
var last_language := ""
var last_theme := ""
var color_icon_cache: Dictionary = {}
var sprite_mode_selector: OptionButton
var advanced_sprite_section: VBoxContainer
var menu_preview_section: Control
var menu_preview_images: Dictionary = {}
var preview_title_label: Label
var preview_menu_label: Label
var preview_divider: ColorRect
var preview_talk_button: Button
var preview_overlay: MarginContainer
var preview_frame: CenterContainer
var startup_window: Window
var startup_default_button: Button
var startup_selection_made: bool = false
var imported_bubble_id: String = ""
var imported_bubble_root: String = ""
var open_bubble_dialog: FileDialog

func _ready() -> void:
	runtime_instance_coordinator = RuntimeInstanceCoordinatorScript.new()
	add_child(runtime_instance_coordinator)
	if not runtime_instance_coordinator.claim("bubble_creator"):
		get_tree().quit()
		return
	creator_window = get_window()
	_prepare_window()
	creator_window.close_requested.connect(_close)
	theme = ThemeKit.build()
	for part: String in PARTS + MENU_PARTS:
		paths[part] = DEFAULT.path_join(part + ".png")
	_build()
	_refresh()
	_start_desktop_preview()
	_build_startup_window()
	startup_window.popup_centered()
	if startup_default_button != null:
		startup_default_button.call_deferred("grab_focus")
	set_process(true)

func _process(_delta: float) -> void:
	var language_code := AppLanguageScript.get_language()
	if language_code != last_language:
		_apply_language(self)
		creator_window.title = _l("Bubble Creator")
		if startup_window != null:
			startup_window.title = _l("Start editing")
		if open_bubble_dialog != null:
			open_bubble_dialog.title = _l("Choose a bubble.json from assets/bubbles")
		_refresh_sprite_mode_labels()
		_refresh_color_labels()
		last_language = language_code
	var theme_id := AppearanceSettingsScript.get_theme_signature()
	if theme_id != last_theme:
		theme = ThemeKit.build()
		_apply_theme(self)
		last_theme = theme_id

func _l(english: String) -> String:
	return AppLanguageScript.text(english, str(KO.get(english, english)))

func _apply_language(node: Node) -> void:
	if node is Label or node is Button or node is LineEdit or node is TextEdit:
		if node.has_meta("opposite_language_title"):
			var title_key := str(node.get_meta("opposite_language_title"))
			node.set("text", _opposite_language_title(title_key))
		else:
			var current := str(node.get("text"))
			for english: String in KO:
				if current == english or current == str(KO[english]):
					node.set("text", _l(english))
					break
	for child: Node in node.get_children():
		_apply_language(child)
	if node == self:
		_summary()

func _opposite_language_title(english: String) -> String:
	if AppLanguageScript.get_language() == "ko":
		return english
	return str(KO.get(english, english))

func _apply_theme(node: Node) -> void:
	if node is ColorRect:
		(node as ColorRect).color = ThemeKit.border() if (node as ColorRect).custom_minimum_size.x == 1.0 else ThemeKit.background()
	elif node is PanelContainer:
		var style := ThemeKit.row_panel() if node.has_meta("bubble_row") else ThemeKit.board_panel()
		(node as PanelContainer).add_theme_stylebox_override("panel", style)
	for child: Node in node.get_children():
		_apply_theme(child)
	for button: Button in nav:
		for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
			button.add_theme_stylebox_override(state, ThemeKit.nav_style("pressed" if "pressed" in state else state))

func _prepare_window() -> void:
	creator_window.title = "Bubble Creator"
	creator_window.mode = Window.MODE_WINDOWED
	creator_window.borderless = false
	creator_window.transparent = false
	creator_window.transparent_bg = false
	creator_window.always_on_top = false
	creator_window.unfocusable = false
	creator_window.unresizable = false
	creator_window.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	creator_window.content_scale_factor = 1.0
	creator_window.min_size = Vector2i(820, 600)
	creator_window.size = Vector2i(980, 720)

func _close() -> void:
	if desktop_manager != null and is_instance_valid(desktop_manager):
		desktop_manager.clear_spawned_characters()
	get_tree().quit()

func _build() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = ThemeKit.background()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)
	root.add_child(_heading("Bubble Creator", "Design segmented speech bubbles for CRT, Chip, and every desktop character."))
	var work := HBoxContainer.new()
	work.size_flags_vertical = Control.SIZE_EXPAND_FILL
	work.add_theme_constant_override("separation", 10)
	root.add_child(work)
	var editor := PanelContainer.new()
	editor.custom_minimum_size.x = 650
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.add_theme_stylebox_override("panel", ThemeKit.board_panel())
	work.add_child(editor)
	var editor_margin := MarginContainer.new()
	editor_margin.add_theme_constant_override("margin_left", 14)
	editor_margin.add_theme_constant_override("margin_top", 12)
	editor_margin.add_theme_constant_override("margin_right", 12)
	editor_margin.add_theme_constant_override("margin_bottom", 12)
	editor.add_child(editor_margin)
	tabs = TabContainer.new()
	tabs.tabs_visible = false
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.tab_changed.connect(_tab_changed)
	editor_margin.add_child(tabs)
	for page: Control in [_bubble_page(), _sprites_page(), _save_page()]:
		tabs.add_child(page)
	work.add_child(_separator())
	work.add_child(_navigation())
	status = Label.new()
	status.add_theme_font_size_override("font_size", ThemeKit.FONT_SMALL)
	status.add_theme_color_override("font_color", ThemeKit.muted())
	root.add_child(status)
	_dialog()
	_build_open_bubble_dialog()

func _start_desktop_preview() -> void:
	desktop_manager = DesktopManagerScript.new()
	desktop_manager.name = "BubbleCreatorDesktopPreview"
	desktop_manager.host_window_clickthrough_on_ready = false
	desktop_manager.startup_boot_on_ready = false
	desktop_manager.manual_preview_mode = true
	add_child(desktop_manager)
	runtime_instance_coordinator.bind_character_manager(desktop_manager)
	var specs: Array[Dictionary] = desktop_manager.get_preferred_preview_specs(2)
	preview_actors = desktop_manager.spawn_preview_cast(specs)
	for actor: DesktopCharacterActor in preview_actors:
		if actor.pet_interaction != null and not actor.pet_interaction.pet_alt_clicked.is_connected(_on_desktop_alt_clicked):
			actor.pet_interaction.pet_alt_clicked.connect(_on_desktop_alt_clicked)
	_sync_desktop_bubbles()
	status.text = _l("Preview characters are displayed at the desktop's bottom-left.")

func _on_desktop_alt_clicked(_character_id: String) -> void:
	_test()

func _sync_desktop_bubbles() -> void:
	for actor: DesktopCharacterActor in preview_actors:
		if is_instance_valid(actor):
			actor.configure_preview_bubble(_bubble_textures(), _selected_color())

func _bubble_page() -> Control:
	var root := _page("Bubble", "Name the bubble, choose text color, enter custom text, and test it.")
	var name_row := _row("Bubble name")
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "soft_cloud"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(_value: String) -> void: _summary())
	name_row.add_child(name_edit)
	root.add_child(name_row)
	var color_row := _row("Text color")
	var color_controls := HBoxContainer.new()
	color_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_controls.add_theme_constant_override("separation", 6)
	color_row.add_child(color_controls)
	color_selector = OptionButton.new()
	color_selector.custom_minimum_size = Vector2(190, ThemeKit.CONTROL_HEIGHT)
	for preset: Dictionary in COLOR_PRESETS:
		color_selector.add_item(_l(str(preset["label"])))
		color_selector.set_item_metadata(color_selector.item_count - 1, str(preset["color"]))
	color_selector.add_item(_l("Custom"))
	color_selector.set_item_metadata(color_selector.item_count - 1, "__custom__")
	color_selector.select(0)
	color_selector.item_selected.connect(_on_color_preset)
	color_controls.add_child(color_selector)
	color_picker = ThemedColorPickerScript.new()
	color_picker.text = "#2C67C5"
	color_picker.custom_minimum_size.y = ThemeKit.CONTROL_HEIGHT
	color_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	color_picker.visible = false
	color_picker.text_changed.connect(_color_changed)
	color_controls.add_child(color_picker)
	_refresh_color_labels()
	root.add_child(color_row)
	var text_row := _row("Custom test text")
	root.add_child(text_row)
	sample_edit = TextEdit.new()
	sample_edit.text = "Hello world"
	sample_edit.custom_minimum_size.y = 150
	sample_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(sample_edit)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var test := _button("Test", _test)
	test.custom_minimum_size = Vector2(180, 40)
	actions.add_child(test)
	root.add_child(actions)
	return root

func _sprites_page() -> Control:
	var root := _page("Sprites", "Upload and preview bubble assets.")
	var mode_row := _row("Sprite mode")
	root.add_child(mode_row)
	sprite_mode_selector = OptionButton.new()
	sprite_mode_selector.custom_minimum_size.y = ThemeKit.CONTROL_HEIGHT
	sprite_mode_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for label: String in ["Default", "Advanced"]:
		sprite_mode_selector.add_item(_l(label))
	sprite_mode_selector.item_selected.connect(_on_sprite_mode_selected)
	mode_row.add_child(sprite_mode_selector)

	var requirement := Label.new()
	requirement.text = _l("PNG only · bubble segments exactly 280 px wide · Advanced menu buttons exactly 56×48")
	requirement.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	requirement.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	requirement.add_theme_font_size_override("font_size", ThemeKit.FONT_SMALL)
	requirement.add_theme_color_override("font_color", ThemeKit.muted())
	root.add_child(requirement)

	var content_margin := MarginContainer.new()
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_top", 4)
	content_margin.add_theme_constant_override("margin_bottom", 10)
	root.add_child(content_margin)
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	content_margin.add_child(content)
	content.add_child(_sprite_preview())
	content.add_child(_separator())
	var rows_scroll := ScrollContainer.new()
	rows_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(rows_scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 5)
	rows_scroll.add_child(rows)
	var section := Label.new()
	section.text = _l("BUBBLE")
	section.add_theme_font_size_override("font_size", ThemeKit.FONT_SMALL)
	section.add_theme_color_override("font_color", ThemeKit.muted())
	rows.add_child(section)
	for part: String in PARTS:
		rows.add_child(_sprite_row(part))

	advanced_sprite_section = VBoxContainer.new()
	advanced_sprite_section.add_theme_constant_override("separation", 5)
	rows.add_child(advanced_sprite_section)
	var menu_section := Label.new()
	menu_section.text = _l("MENU · Menu buttons")
	menu_section.add_theme_font_size_override("font_size", ThemeKit.FONT_SMALL)
	menu_section.add_theme_color_override("font_color", ThemeKit.muted())
	advanced_sprite_section.add_child(menu_section)
	for part: String in MENU_PARTS:
		advanced_sprite_section.add_child(_sprite_row(part, true))
	var bottom_space := Control.new()
	bottom_space.custom_minimum_size.y = 12
	advanced_sprite_section.add_child(bottom_space)
	return root

func _sprite_preview() -> Control:
	var preview_box := VBoxContainer.new()
	preview_box.custom_minimum_size.x = 300
	preview_box.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	preview_box.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	preview_box.add_theme_constant_override("separation", 8)
	var heading := Label.new()
	heading.text = _l("Preview")
	heading.add_theme_font_size_override("font_size", ThemeKit.FONT_MEDIUM)
	preview_box.add_child(heading)

	preview_frame = CenterContainer.new()
	preview_frame.custom_minimum_size = Vector2(300, 300)
	preview_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	preview_box.add_child(preview_frame)

	bubble = Control.new()
	bubble.custom_minimum_size = Vector2(276, 279)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_frame.add_child(bubble)

	bubble_bg = BubbleBackgroundScript.new()
	bubble_bg.position = Vector2.ZERO
	bubble_bg.size = bubble.custom_minimum_size
	bubble_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(bubble_bg)

	preview_overlay = MarginContainer.new()
	preview_overlay.position = Vector2.ZERO
	preview_overlay.size = bubble.custom_minimum_size
	preview_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(preview_overlay)

	var preview_content := VBoxContainer.new()
	preview_content.add_theme_constant_override("separation", 6)
	preview_overlay.add_child(preview_content)

	preview_title_label = Label.new()
	preview_title_label.text = _l("Hello world")
	preview_title_label.custom_minimum_size.y = 30.0
	preview_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	preview_content.add_child(preview_title_label)

	preview_menu_label = Label.new()
	preview_menu_label.text = _l("Menu")
	preview_menu_label.custom_minimum_size.y = 16.0
	preview_menu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	preview_content.add_child(preview_menu_label)

	preview_divider = ColorRect.new()
	preview_divider.custom_minimum_size.y = 1.0
	preview_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_content.add_child(preview_divider)

	var menu_content := VBoxContainer.new()
	menu_content.add_theme_constant_override("separation", 6)
	preview_content.add_child(menu_content)

	menu_preview_section = VBoxContainer.new()
	menu_preview_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_preview_section.add_theme_constant_override("separation", 8)
	menu_content.add_child(menu_preview_section)

	var row: HBoxContainer
	for index in range(MENU_PARTS.size()):
		if index % 3 == 0:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 8)
			menu_preview_section.add_child(row)
		var part: String = MENU_PARTS[index]
		var button := Button.new()
		button.custom_minimum_size = Vector2(56, 48)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.expand_icon = false
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.text = _l(str(MENU_LABELS.get(part, part)))
		button.set_meta("menu_text_fallback", true)
		_style_preview_menu_button(button)
		row.add_child(button)
		menu_preview_images[part] = button

	preview_talk_button = Button.new()
	preview_talk_button.text = _l("Chat")
	preview_talk_button.custom_minimum_size.y = 32.0
	preview_talk_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_talk_button.focus_mode = Control.FOCUS_NONE
	preview_talk_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_preview_menu_button(preview_talk_button)
	menu_content.add_child(preview_talk_button)

	_apply_preview_menu_style()
	return preview_box

func _style_preview_menu_button(button: Button) -> void:
	if button == null:
		return
	var settings: Dictionary = AppearanceSettingsScript.load_settings()
	var font_path: String = str(settings.get("bubble_font", AppearanceSettingsScript.DEFAULT_BUBBLE_FONT))
	var font_size: int = clampi(int(settings.get("bubble_font_size", AppearanceSettingsScript.DEFAULT_BUBBLE_FONT_SIZE)), 12, 52)
	var font: Font = AppearanceSettingsScript.get_bubble_font(font_path)
	if font != null:
		button.add_theme_font_override("font", font)
	var button_font_size: int = font_size
	if bool(button.get_meta("menu_text_fallback", false)):
		button_font_size = clampi(roundi(float(font_size) * 0.5), 11, 14)
	button.add_theme_font_size_override("font_size", button_font_size)
	var text_color: Color = _selected_color()
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		button.add_theme_color_override(color_name, text_color)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	for corner: String in ["top_left", "top_right", "bottom_left", "bottom_right"]:
		normal.set("corner_radius_" + corner, 8)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = text_color
	hover.bg_color.a = 0.10
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("hover_pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _apply_preview_menu_style() -> void:
	if bubble == null or bubble_bg == null or preview_overlay == null:
		return
	var settings: Dictionary = AppearanceSettingsScript.load_settings()
	var font_path: String = str(settings.get("bubble_font", AppearanceSettingsScript.DEFAULT_BUBBLE_FONT))
	var font_size: int = clampi(int(settings.get("bubble_font_size", AppearanceSettingsScript.DEFAULT_BUBBLE_FONT_SIZE)), 12, 52)
	var font: Font = AppearanceSettingsScript.get_bubble_font(font_path)
	var text_color: Color = _selected_color()

	if preview_title_label != null:
		if font != null:
			preview_title_label.add_theme_font_override("font", font)
		preview_title_label.add_theme_font_size_override("font_size", font_size)
		preview_title_label.add_theme_color_override("font_color", text_color)
	if preview_menu_label != null:
		if font != null:
			preview_menu_label.add_theme_font_override("font", font)
		var ratio: float = float(AppearanceSettingsScript.UI_FONT_SMALL) / float(AppearanceSettingsScript.UI_FONT_MEDIUM)
		preview_menu_label.add_theme_font_size_override("font_size", maxi(1, roundi(float(font_size) * ratio)))
		var secondary_color := text_color
		secondary_color.a *= 0.62
		preview_menu_label.add_theme_color_override("font_color", secondary_color)
	if preview_divider != null:
		preview_divider.color = text_color

	for value: Variant in menu_preview_images.values():
		_style_preview_menu_button(value as Button)
	_style_preview_menu_button(preview_talk_button)

	var width: float = 276.0
	var top_height: float = bubble_bg.get_top_height(width)
	var bottom_height: float = bubble_bg.get_bottom_height(width)
	var top_margin: int = clampi(maxi(14, ceili(top_height) + 6), 14, 48)
	var bottom_margin: int = clampi(maxi(14, ceili(bottom_height) + 6), 14, 48)
	preview_overlay.add_theme_constant_override("margin_left", 18)
	preview_overlay.add_theme_constant_override("margin_top", top_margin)
	preview_overlay.add_theme_constant_override("margin_right", 18)
	preview_overlay.add_theme_constant_override("margin_bottom", bottom_margin)

	var content_height: int = 30 + 16 + 1 + 18 + 104 + 6 + 32
	var preview_height: int = top_margin + content_height + bottom_margin
	bubble.custom_minimum_size = Vector2(width, float(preview_height))
	bubble.size = bubble.custom_minimum_size
	bubble_bg.size = bubble.custom_minimum_size
	preview_overlay.size = bubble.custom_minimum_size
	if preview_frame != null:
		preview_frame.custom_minimum_size = Vector2(300, float(preview_height + 20))

func _sprite_row(part: String, is_menu_button: bool = false) -> Control:
	var panel := PanelContainer.new()
	panel.set_meta("bubble_row", true)
	panel.add_theme_stylebox_override("panel", ThemeKit.row_panel())
	var margin := MarginContainer.new()
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = 104
	row.add_theme_constant_override("separation", 12)
	margin.add_child(row)
	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(64, 64 if is_menu_button else 96)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(image)
	thumbnails[part] = image
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(detail)
	var title := Label.new()
	title.text = _l(str(MENU_LABELS.get(part, part.capitalize()))) if is_menu_button else _l(part.capitalize())
	title.add_theme_font_size_override("font_size", ThemeKit.FONT_MEDIUM)
	detail.add_child(title)
	var path_label := Label.new()
	path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	path_label.add_theme_font_size_override("font_size", ThemeKit.FONT_SMALL)
	path_label.add_theme_color_override("font_color", ThemeKit.muted())
	detail.add_child(path_label)
	path_labels[part] = path_label
	var actions := HBoxContainer.new()
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.add_theme_constant_override("separation", 4)
	row.add_child(actions)
	var upload := _button("Upload", func() -> void: _choose(part))
	upload.custom_minimum_size.x = 70
	actions.add_child(upload)
	var clear := _button("Clear", func() -> void: _reset(part))
	clear.custom_minimum_size.x = 58
	actions.add_child(clear)
	return panel

func _save_page() -> Control:
	var root := _page("Save", "Review missing items and save to assets/bubbles.")
	summary = VBoxContainer.new()
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary.add_theme_constant_override("separation", 8)
	root.add_child(summary)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button = _button("Save bubble", _save)
	save_button.custom_minimum_size = Vector2(180, 40)
	actions.add_child(save_button)
	root.add_child(actions)
	return root

func _page(title: String, _subtitle: String) -> VBoxContainer:
	var root := VBoxContainer.new()
	root.name = title
	root.add_theme_constant_override("separation", 12)
	root.add_child(_heading(title, ""))
	root.add_child(HSeparator.new())
	return root

func _heading(title_text: String, subtitle_text: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", ThemeKit.FONT_LARGE)
	box.add_child(title)
	var subtitle := Label.new()
	if subtitle_text.is_empty():
		subtitle.set_meta("opposite_language_title", title_text)
		subtitle.text = _opposite_language_title(title_text)
	else:
		subtitle.text = subtitle_text
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", ThemeKit.FONT_SMALL)
	subtitle.add_theme_color_override("font_color", ThemeKit.muted())
	box.add_child(subtitle)
	return box

func _navigation() -> Control:
	var navigation_margin := MarginContainer.new()
	navigation_margin.custom_minimum_size.x = 126
	navigation_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	navigation_margin.add_theme_constant_override("margin_left", 8)
	navigation_margin.add_theme_constant_override("margin_top", 6)
	navigation_margin.add_theme_constant_override("margin_right", 0)
	navigation_margin.add_theme_constant_override("margin_bottom", 6)
	var rail := VBoxContainer.new()
	rail.custom_minimum_size.x = 118
	rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rail.alignment = BoxContainer.ALIGNMENT_CENTER
	rail.add_theme_constant_override("separation", 8)
	navigation_margin.add_child(rail)
	for index: int in range(3):
		var button := Button.new()
		button.text = ["Bubble", "Sprites", "Save"][index]
		button.custom_minimum_size = Vector2(120, 40)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void: tabs.current_tab = index)
		for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
			button.add_theme_stylebox_override(state, ThemeKit.nav_style("pressed" if "pressed" in state else state))
		rail.add_child(button)
		nav.append(button)
	return navigation_margin

func _row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size.y = ThemeKit.CONTROL_HEIGHT
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 120
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	return row

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = ThemeKit.CONTROL_HEIGHT
	button.pressed.connect(callback)
	return button

func _separator() -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size.x = 1
	line.size_flags_vertical = Control.SIZE_EXPAND_FILL
	line.color = ThemeKit.border()
	return line

func _dialog() -> void:
	dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.filters = PackedStringArray(["*.png ; PNG"])
	dialog.file_selected.connect(_selected)
	add_child(dialog)

func _build_open_bubble_dialog() -> void:
	open_bubble_dialog = FileDialog.new()
	open_bubble_dialog.title = _l("Choose a bubble.json from assets/bubbles")
	open_bubble_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	open_bubble_dialog.access = FileDialog.ACCESS_FILESYSTEM
	open_bubble_dialog.use_native_dialog = true
	open_bubble_dialog.current_dir = AppearanceSettingsScript.get_user_bubble_directory_path()
	open_bubble_dialog.filters = PackedStringArray(["bubble.json ; Bubble package"])
	open_bubble_dialog.file_selected.connect(_on_bubble_file_selected)
	open_bubble_dialog.canceled.connect(_on_bubble_open_canceled)
	add_child(open_bubble_dialog)

func _build_startup_window() -> void:
	startup_window = Window.new()
	startup_window.title = _l("Start editing")
	startup_window.theme = ThemeKit.build()
	startup_window.size = Vector2i(540, 300)
	startup_window.min_size = Vector2i(480, 280)
	startup_window.transient = true
	startup_window.exclusive = true
	startup_window.close_requested.connect(_on_startup_window_closed)
	add_child(startup_window)

	var background := ColorRect.new()
	background.color = ThemeKit.background()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	startup_window.add_child(background)
	var outer := MarginContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		outer.add_theme_constant_override("margin_" + side, 18)
	startup_window.add_child(outer)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeKit.board_panel())
	outer.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	var title := Label.new()
	title.text = _l("Start editing")
	title.add_theme_font_size_override("font_size", ThemeKit.FONT_LARGE)
	box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = _l("Choose how to start this Bubble Creator session.")
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", ThemeKit.FONT_SMALL)
	subtitle.add_theme_color_override("font_color", ThemeKit.muted())
	box.add_child(subtitle)
	var buttons := VBoxContainer.new()
	buttons.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	for definition: Dictionary in [
		{"label": "Start new", "callback": _on_startup_new},
		{"label": "Use preset", "callback": _on_startup_preset},
		{"label": "Open", "callback": _on_startup_open},
	]:
		var callback: Callable = definition.get("callback", Callable())
		var button := _button(_l(str(definition["label"])), callback)
		button.custom_minimum_size = Vector2(300, 38)
		buttons.add_child(button)
		if startup_default_button == null:
			startup_default_button = button

func _on_startup_window_closed() -> void:
	_on_startup_new()

func _on_startup_new() -> void:
	_start_new_bubble(false)

func _on_startup_preset() -> void:
	_start_new_bubble(true)

func _start_new_bubble(use_preset: bool) -> void:
	startup_selection_made = true
	imported_bubble_id = ""
	imported_bubble_root = ""
	startup_window.hide()
	for part: String in PARTS + MENU_PARTS:
		paths[part] = DEFAULT.path_join(part + ".png") if use_preset else ""
	name_edit.text = ""
	_set_color_hex("#2C67C5")
	sprite_mode_selector.select(0)
	_sync_sprite_mode_visibility()
	_refresh()
	status.text = _l("Ready. Alt-click CRT or Chip, or press Test bubble.")

func _on_startup_open() -> void:
	startup_window.hide()
	open_bubble_dialog.popup_centered_ratio(0.75)

func _on_bubble_open_canceled() -> void:
	if not startup_selection_made and startup_window != null:
		startup_window.popup_centered()

func _on_bubble_file_selected(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		status.text = _l("Could not open that bubble package.")
		_on_bubble_open_canceled()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		status.text = _l("Could not open that bubble package.")
		_on_bubble_open_canceled()
		return
	startup_selection_made = true
	var folder := path.get_base_dir()
	name_edit.text = folder.get_file()
	imported_bubble_id = _slug(name_edit.text)
	imported_bubble_root = folder
	_set_color_hex(str((parsed as Dictionary).get("text_color", "#2C67C5")))
	var has_menu_asset := false
	for part: String in PARTS + MENU_PARTS:
		var candidate := folder.path_join(part + ".png")
		if FileAccess.file_exists(candidate):
			paths[part] = candidate
			if MENU_PARTS.has(part):
				has_menu_asset = true
		else:
			paths[part] = DEFAULT.path_join(part + ".png")
	sprite_mode_selector.select(1 if has_menu_asset else 0)
	_sync_sprite_mode_visibility()
	_refresh()
	status.text = _l("Imported bubble package") + ": " + folder.get_file()

func _advanced_mode() -> bool:
	return sprite_mode_selector != null and sprite_mode_selector.selected == 1

func _on_sprite_mode_selected(_index: int) -> void:
	_sync_sprite_mode_visibility()
	_summary()

func _sync_sprite_mode_visibility() -> void:
	var advanced := _advanced_mode()
	if advanced_sprite_section != null:
		advanced_sprite_section.visible = advanced
	if menu_preview_section != null:
		menu_preview_section.visible = true

func _refresh_sprite_mode_labels() -> void:
	if sprite_mode_selector == null:
		return
	for index: int in range(mini(sprite_mode_selector.item_count, 2)):
		sprite_mode_selector.set_item_text(index, _l(["Default", "Advanced"][index]))

func _bubble_textures() -> Dictionary:
	var result: Dictionary = {}
	for part: String in PARTS:
		result[part] = textures.get(part)
	return result

func _set_color_hex(value: String) -> void:
	var normalized := value.strip_edges().to_upper()
	if not Color.html_is_valid(normalized):
		normalized = "#2C67C5"
	var preset_index := -1
	for index: int in range(COLOR_PRESETS.size()):
		if str(COLOR_PRESETS[index]["color"]).to_upper() == normalized:
			preset_index = index
			break
	if preset_index >= 0:
		color_selector.select(preset_index)
		color_picker.visible = false
		color_picker.text = str(COLOR_PRESETS[preset_index]["color"])
	else:
		color_selector.select(COLOR_PRESETS.size())
		color_picker.visible = true
		color_picker.text = normalized
	_color_changed(color_picker.text)

func _test() -> void:
	var value := sample_edit.text.strip_edges() if sample_edit else ""
	var sample := value if not value.is_empty() else "Hello world"
	if bubble_label != null:
		bubble_label.text = sample
		bubble.visible = true
	_sync_desktop_bubbles()
	for actor: DesktopCharacterActor in preview_actors:
		if is_instance_valid(actor):
			actor.show_speech(sample, 8.0, "neutral")
	status.text = "Previewing on CRT and Chip: “%s”" % sample.replace("\n", " ")

func _color_changed(_value: String) -> void:
	var color := _selected_color()
	if bubble_label != null:
		bubble_label.add_theme_color_override("font_color", color)
	_refresh_color_icons()
	_sync_desktop_bubbles()
	_summary()

func _on_color_preset(_index: int) -> void:
	color_picker.visible = color_selector.selected == COLOR_PRESETS.size()
	if not color_picker.visible:
		color_picker.text = str(color_selector.get_item_metadata(color_selector.selected))
	_color_changed(color_picker.text)

func _selected_color() -> Color:
	return Color.html(_hex()) if Color.html_is_valid(_hex()) else Color("173E76")

func _refresh_color_labels() -> void:
	if color_selector == null:
		return
	for index: int in range(COLOR_PRESETS.size()):
		color_selector.set_item_text(index, _l(str(COLOR_PRESETS[index]["label"])))
	color_selector.set_item_text(COLOR_PRESETS.size(), _l("Custom"))
	_refresh_color_icons()

func _refresh_color_icons() -> void:
	if color_selector == null:
		return
	var popup := color_selector.get_popup()
	for index: int in range(color_selector.item_count):
		popup.set_item_as_radio_checkable(index, false)
		popup.set_item_as_checkable(index, false)
		var value := color_picker.text if index == COLOR_PRESETS.size() and color_picker != null else str(color_selector.get_item_metadata(index))
		color_selector.set_item_icon(index, _color_icon(value))

func _color_icon(value: String) -> Texture2D:
	var normalized := value.strip_edges().to_upper()
	var swatch := Color.html(normalized) if Color.html_is_valid(normalized) else ThemeKit.nav_text_color()
	if color_icon_cache.has(normalized):
		return color_icon_cache[normalized] as Texture2D
	var image := Image.create(18, 18, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y: int in range(18):
		for x: int in range(18):
			var alpha := clampf(7.75 - Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(Vector2(9, 9)), 0.0, 1.0)
			if alpha > 0.0:
				var pixel := swatch
				pixel.a *= alpha
				image.set_pixel(x, y, pixel)
	var texture := ImageTexture.create_from_image(image)
	color_icon_cache[normalized] = texture
	return texture

func _choose(part: String) -> void:
	pending = part
	dialog.popup_centered_ratio(0.72)

func _reset(part: String) -> void:
	paths[part] = DEFAULT.path_join(part + ".png")
	_refresh_part(part)
	_preview_skin()
	_summary()

func _selected(path: String) -> void:
	var image := Image.new()
	if pending.is_empty() or image.load(path) != OK or image.is_empty():
		status.text = _l("Could not load that PNG.")
		return
	if MENU_PARTS.has(pending):
		if image.get_width() != 56 or image.get_height() != 48:
			status.text = _l("Menu button images must be exactly 56×48 px.")
			return
	elif image.get_width() != 280:
		status.text = _l("Width must be exactly 280 px.")
		return
	paths[pending] = path
	_refresh_part(pending)
	_preview_skin()
	_summary()
	status.text = "%s segment loaded." % pending.capitalize()
	pending = ""

func _refresh() -> void:
	for part: String in PARTS + MENU_PARTS:
		_refresh_part(part)
	_sync_sprite_mode_visibility()
	_preview_skin()
	_color_changed(color_picker.text)
	tabs.current_tab = 0
	_tab_changed(0)
	status.text = _l("Ready. Alt-click CRT or Chip, or press Test bubble.")

func _refresh_part(part: String) -> void:
	var path := str(paths[part])
	var texture: Texture2D
	if path.begins_with("res://"):
		texture = load(path)
	else:
		var image := Image.new()
		if image.load(path) == OK:
			texture = ImageTexture.create_from_image(image)
	textures[part] = texture
	if thumbnails.has(part):
		(thumbnails[part] as TextureRect).texture = texture
	if menu_preview_images.has(part):
		var preview_button := menu_preview_images[part] as Button
		var has_visible_icon := _texture_has_visible_pixels(texture)
		preview_button.icon = texture if has_visible_icon else null
		preview_button.text = "" if has_visible_icon else _l(str(MENU_LABELS.get(part, part)))
	var is_default := path == DEFAULT.path_join(part + ".png")
	(path_labels[part] as Label).text = _l("Default" if is_default else "Uploaded")
	(path_labels[part] as Label).add_theme_color_override("font_color", ThemeKit.accent() if is_default else ThemeKit.success())

func _texture_has_visible_pixels(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var image := texture.get_image()
	if image == null or image.is_empty():
		return false
	return image.get_used_rect().has_area()

func _preview_skin() -> void:
	if bubble_bg != null:
		var bubble_textures: Dictionary = {}
		for part: String in PARTS:
			bubble_textures[part] = textures.get(part)
		bubble_bg.configure(bubble_textures)
	_apply_preview_menu_style()
	_sync_desktop_bubbles()

func _tab_changed(_index: int) -> void:
	for index: int in range(nav.size()):
		nav[index].button_pressed = index == tabs.current_tab
	_summary()

func _slug(value: String) -> String:
	return CreatorNamingScript.make_id(value.strip_edges(), "")

func _exists(path: String) -> bool:
	if path.begins_with("res://"):
		return ResourceLoader.exists(path)
	return FileAccess.file_exists(path)

func _name_is_valid(id: String) -> bool:
	if id.is_empty():
		return false
	if id != "default":
		return true
	return not imported_bubble_id.is_empty() and id == imported_bubble_id

func _summary() -> void:
	if summary == null:
		return
	for child: Node in summary.get_children():
		summary.remove_child(child)
		child.queue_free()
	var id := _slug(name_edit.text)
	var name_valid := _name_is_valid(id)
	var missing: Array[String] = []
	var details: Array[String] = []
	if not name_valid:
		missing.append(_l("Bubble name"))
	details.append("%s · %s" % [_l("Bubble name"), _l("Ready") if name_valid else _l("Missing")])
	for part: String in PARTS:
		var uploaded := _part_is_uploaded(part)
		if not uploaded:
			missing.append(_l(part.capitalize()) + ".png")
		details.append("%s · %s" % [_l(part.capitalize()), _l("Uploaded") if uploaded else _l("Missing")])
	_add_checklist_section(
		_l("Bubble files"),
		_l("All required bubble images are uploaded.") if missing.is_empty() else _l("Upload every required bubble image before saving."),
		details,
		missing.is_empty()
	)
	if _advanced_mode():
		var menu_missing: Array[String] = []
		var menu_details: Array[String] = []
		for part: String in MENU_PARTS:
			var uploaded := _part_is_uploaded(part)
			if not uploaded:
				menu_missing.append(str(MENU_LABELS.get(part, part)) + ".png")
			menu_details.append("%s · %s" % [_l(str(MENU_LABELS.get(part, part))), _l("Uploaded") if uploaded else _l("Missing")])
		_add_checklist_section(
			_l("Menu buttons"),
			_l("All required menu button images are uploaded.") if menu_missing.is_empty() else _l("Advanced mode requires all five menu button images."),
			menu_details,
			menu_missing.is_empty()
		)
	if save_button:
		save_button.disabled = not name_valid or not _valid()

func _add_checklist_section(title_text: String, status_text: String, details: Array[String], ok: bool) -> void:
	var panel := PanelContainer.new()
	panel.set_meta("bubble_row", true)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", ThemeKit.row_panel())
	summary.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)
	var title := Label.new()
	title.text = ("✓ " if ok else "! ") + title_text
	title.add_theme_font_size_override("font_size", ThemeKit.FONT_MEDIUM)
	title.add_theme_color_override("font_color", ThemeKit.success() if ok else ThemeKit.danger())
	box.add_child(title)
	var state := Label.new()
	state.text = status_text
	state.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(state)
	for detail: String in details:
		var label := Label.new()
		label.text = "• " + detail
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", ThemeKit.FONT_SMALL)
		label.add_theme_color_override("font_color", ThemeKit.muted())
		box.add_child(label)

func _part_is_uploaded(part: String) -> bool:
	var path := str(paths.get(part, ""))
	if path.is_empty() or not _exists(path):
		return false
	if not imported_bubble_root.is_empty() and path.get_base_dir() == imported_bubble_root:
		return true
	return path != DEFAULT.path_join(part + ".png")

func _valid() -> bool:
	for part: String in PARTS:
		if not _part_is_uploaded(part):
			return false
	if _advanced_mode():
		for part: String in MENU_PARTS:
			if not _part_is_uploaded(part):
				return false
	return true

func _hex() -> String:
	if color_selector != null and color_selector.selected >= 0 and color_selector.selected < COLOR_PRESETS.size():
		return str(color_selector.get_item_metadata(color_selector.selected)).to_upper()
	var value := color_picker.text.strip_edges().to_upper() if color_picker != null else "#2C67C5"
	return value if Color.html_is_valid(value) else "#2C67C5"

func _save() -> void:
	var id := _slug(name_edit.text)
	if not _name_is_valid(id) or not _valid():
		status.text = "Enter a valid name and provide all required PNGs."
		return
	var target := AppearanceSettingsScript.get_user_bubble_directory_path().path_join(id)
	var stage := PackageSave.begin(target)
	if stage.is_empty():
		status.text = _l("Could not prepare save. Existing files are unchanged.")
		return
	var error := _write_bubble_stage(stage)
	if error != OK:
		PackageSave.discard(stage)
		status.text = _l("Could not save bubble. Existing files are unchanged.")
		return
	error = PackageSave.commit(stage, target)
	status.text = ("Saved bubble skin to " + target) if error == OK else "Could not replace bubble files."

func _write_bubble_stage(target: String) -> Error:
	var save_parts: Array[String] = PARTS.duplicate()
	if _advanced_mode():
		save_parts.append_array(MENU_PARTS)
	for part: String in save_parts:
		var bytes := _get_png_bytes(str(paths[part]))
		if bytes.is_empty():
			return ERR_FILE_CANT_READ
		var error := AtomicFile.save_bytes(target.path_join(part + ".png"), bytes, false)
		if error != OK:
			return error
	if not _advanced_mode():
		for part: String in MENU_PARTS:
			var path := target.path_join(part + ".png")
			if FileAccess.file_exists(path):
				var error := DirAccess.remove_absolute(path)
				if error != OK:
					return error
	return JsonStore.save_json(target.path_join("bubble.json"), {"text_color": _hex()}, "  ", true, false)


func _get_png_bytes(path: String) -> PackedByteArray:
	if path.begins_with("res://"):
		var texture: Resource = ResourceLoader.load(path)
		if texture is Texture2D:
			var image: Image = (texture as Texture2D).get_image()
			if image != null and not image.is_empty():
				return image.save_png_to_buffer()
		return PackedByteArray()

	return FileAccess.get_file_as_bytes(path)
