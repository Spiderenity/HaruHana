extends VBoxContainer
class_name CompanionSettingsPanel

signal character_pack_changed(
	pack_id: String
)

signal interface_language_changed(
	language: String
)

const AppLanguageScript = preload(
	"res://system/app/app_language.gd"
)

const AppearanceSettingsScript = preload(
	"res://system/app/appearance_settings.gd"
)

const UserProfileSettingsScript = preload(
	"res://system/app/user_profile_settings.gd"
)
const StartupProgramSettingsScript = preload(
	"res://system/app/startup_program_settings.gd"
)
const UpdateServiceScript = preload(
	"res://system/services/update/update_service.gd"
)

const SETTINGS_LABEL_WIDTH: float = 120.0


var language_selector: OptionButton
var applying_language: bool = false

var user_name_input: LineEdit

var theme_selector: OptionButton
var theme_color_icon_cache: Dictionary = {}
var appearance_mode_selector: OptionButton
var bubble_font_selector: OptionButton
var bubble_font_size_slider: HSlider
var bubble_font_size_value_label: Label
var bubble_style_selector: OptionButton
var appearance_status_label: Label
var applying_appearance: bool = false
var startup_program_check: CheckBox
var startup_program_status: Label
var applying_startup_program: bool = false

var update_service: HaruHanaUpdateService = null
var update_current_version_value: Label
var update_check_button: Button
var update_install_button: Button
var update_status_label: Label
var update_progress_bar: ProgressBar
var update_status_code: String = "idle"
var update_status_detail: String = ""
var update_available_version: String = ""

var api_key_input: LineEdit
var model_selector: OptionButton
var custom_model_input: LineEdit

var generation_cadence_selector: OptionButton
var generation_interval_label: Label
var generation_interval_spin: SpinBox
var desktop_settings_manager: DesktopCharacterManager = null
var refreshing_generation_settings: bool = false

var pack_selector: OptionButton
var set_pack_button: Button

func _ready() -> void:
	update_service = UpdateServiceScript.new()
	add_child(update_service)
	_connect_update_service()

	size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	add_theme_constant_override("separation", AppearanceSettingsScript.UI_STACK_GAP)

	build_ui()
	_apply_settings_spacing(self)

	load_ai_fields()

	refresh_pack_list()

	call_deferred("_connect_desktop_settings_manager")

	var previous_update_error: String = update_service.consume_last_update_error()
	if not previous_update_error.is_empty():
		_set_update_status("previous_error", previous_update_error)

func build_ui() -> void:
	var title := Label.new()
	_bind_localized_text(title, "Settings", "설정")
	title.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_LARGE)
	add_child(title)

	add_child(HSeparator.new())

	build_language_section()
	build_user_section()
	build_appearance_section()
	build_startup_program_section()
	build_update_section()
	build_ai_section()
	build_pack_section()

func _add_section_header(
	english_title: String,
	korean_title: String
) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 12.0
	add_child(spacer)

	var heading := Label.new()
	_bind_localized_text(heading, english_title, korean_title)
	heading.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	add_child(heading)

	add_child(HSeparator.new())

func _apply_settings_spacing(node: Node) -> void:
	if node is HBoxContainer:
		var row: HBoxContainer = node as HBoxContainer
		row.add_theme_constant_override("separation", 12)
		row.custom_minimum_size.y = maxf(
			row.custom_minimum_size.y,
			float(AppearanceSettingsScript.UI_CONTROL_HEIGHT)
		)
	elif node is VBoxContainer and node != self:
		(node as VBoxContainer).add_theme_constant_override(
			"separation",
			AppearanceSettingsScript.UI_STACK_GAP
		)

	if node is LineEdit or node is OptionButton or node is SpinBox:
		var control := node as Control
		control.custom_minimum_size.y = maxf(
			control.custom_minimum_size.y,
			float(AppearanceSettingsScript.UI_CONTROL_HEIGHT)
		)
		control.add_theme_font_size_override(
			"font_size",
			AppearanceSettingsScript.UI_FONT_MEDIUM
		)

	for child: Node in node.get_children():
		_apply_settings_spacing(child)

func _style_secondary_label(label: Label) -> void:
	label.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_SMALL)
	label.remove_theme_color_override("font_color")

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
	for property_name: String in ["text", "placeholder_text", "title"]:
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

func apply_appearance() -> void:
	_update_generation_interval_editable()

func apply_language() -> void:
	applying_language = true
	_apply_language_to_node(self)

	if language_selector != null:
		var current_language: String = AppLanguageScript.get_language()

		for index: int in range(language_selector.item_count):
			if str(language_selector.get_item_metadata(index)) == current_language:
				language_selector.select(index)
				break

	_refresh_model_selector_labels()
	_refresh_appearance_selector_labels()
	_refresh_generation_cadence_labels()
	_refresh_update_status_text()
	applying_language = false

func build_language_section() -> void:
	_add_section_header(
		"Language",
		"언어"
	)

	var row: HBoxContainer = HBoxContainer.new()
	add_child(row)

	var label: Label = Label.new()
	_bind_localized_text(label, "Interface language", "인터페이스 언어")
	label.custom_minimum_size.x = SETTINGS_LABEL_WIDTH
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)

	language_selector = OptionButton.new()
	language_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_selector.add_item("English")
	language_selector.set_item_metadata(0, "en")
	language_selector.add_item("한국어")
	language_selector.set_item_metadata(1, "ko")
	row.add_child(language_selector)

	language_selector.item_selected.connect(_on_language_selected)
	apply_language()

func _on_language_selected(index: int) -> void:
	if language_selector == null or applying_language:
		return

	var language: String = str(
		language_selector.get_item_metadata(index)
	).strip_edges().to_lower()

	var error: Error = AppLanguageScript.set_language(language)

	if error != OK:
		push_error(
			"Could not save language setting. Error: "
			+ str(
				error
			)
		)
		return

	apply_language()
	interface_language_changed.emit(language)

func build_user_section() -> void:
	_add_section_header(
		"You",
		"사용자"
	)

	var row: HBoxContainer = HBoxContainer.new()
	add_child(row)

	var label: Label = Label.new()
	_bind_localized_text(label, "Your name", "이름")
	label.custom_minimum_size.x = SETTINGS_LABEL_WIDTH
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)

	user_name_input = LineEdit.new()
	user_name_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bind_localized_text(user_name_input, "Name desktop pets can call you", "데스크탑 펫이 부를 이름", "placeholder_text")
	row.add_child(user_name_input)

	var save_button: Button = Button.new()
	_bind_localized_text(save_button, "Save", "저장")
	save_button.pressed.connect(_on_save_user_name_pressed)
	row.add_child(save_button)

	user_name_input.text = UserProfileSettingsScript.get_user_name()
	user_name_input.text_submitted.connect(_on_user_name_submitted)

func _on_user_name_submitted(_value: String) -> void:
	_on_save_user_name_pressed()

func _on_save_user_name_pressed() -> void:
	if user_name_input == null:
		return

	var error: Error = UserProfileSettingsScript.set_user_name(user_name_input.text)

	if error != OK:
		push_error(
			"Could not save user name. Error: "
			+ str(
				error
			)
		)
		return

	user_name_input.text = UserProfileSettingsScript.get_user_name()

func build_appearance_section() -> void:
	AppearanceSettingsScript.ensure_user_directories()

	_add_section_header(
		"Appearance",
		"화면 스타일"
	)

	var theme_row: HBoxContainer = HBoxContainer.new()
	add_child(theme_row)

	var theme_label: Label = Label.new()
	_bind_localized_text(theme_label, "Theme", "테마")
	theme_label.custom_minimum_size.x = SETTINGS_LABEL_WIDTH
	theme_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	theme_row.add_child(theme_label)

	theme_selector = OptionButton.new()
	theme_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for theme_id: String in AppearanceSettingsScript.THEME_IDS:
		theme_selector.add_item("")
		theme_selector.set_item_metadata(theme_selector.item_count - 1, theme_id)
	theme_row.add_child(theme_selector)

	var mode_row: HBoxContainer = HBoxContainer.new()
	add_child(mode_row)

	var mode_label: Label = Label.new()
	_bind_localized_text(mode_label, "Mode", "밝기")
	mode_label.custom_minimum_size.x = SETTINGS_LABEL_WIDTH
	mode_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mode_row.add_child(mode_label)

	appearance_mode_selector = OptionButton.new()
	appearance_mode_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for mode_id: String in AppearanceSettingsScript.MODE_IDS:
		appearance_mode_selector.add_item("")
		appearance_mode_selector.set_item_metadata(appearance_mode_selector.item_count - 1, mode_id)
	mode_row.add_child(appearance_mode_selector)

	var font_row: HBoxContainer = HBoxContainer.new()
	add_child(font_row)

	var font_label: Label = Label.new()
	_bind_localized_text(font_label, "Speech bubble font", "말풍선 글꼴")
	font_label.custom_minimum_size.x = SETTINGS_LABEL_WIDTH
	font_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	font_row.add_child(font_label)

	bubble_font_selector = OptionButton.new()
	bubble_font_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	font_row.add_child(bubble_font_selector)

	var font_size_row: HBoxContainer = HBoxContainer.new()
	add_child(font_size_row)

	var font_size_label: Label = Label.new()
	_bind_localized_text(font_size_label, "Bubble text size", "말풍선 글자 크기")
	font_size_label.custom_minimum_size.x = SETTINGS_LABEL_WIDTH
	font_size_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	font_size_row.add_child(font_size_label)

	bubble_font_size_slider = HSlider.new()
	bubble_font_size_slider.min_value = 12
	bubble_font_size_slider.max_value = 52
	bubble_font_size_slider.step = 1
	bubble_font_size_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	font_size_row.add_child(bubble_font_size_slider)

	bubble_font_size_value_label = Label.new()
	bubble_font_size_value_label.custom_minimum_size.x = 54
	font_size_row.add_child(bubble_font_size_value_label)

	var bubble_style_row: HBoxContainer = HBoxContainer.new()
	add_child(bubble_style_row)

	var bubble_style_label: Label = Label.new()
	_bind_localized_text(bubble_style_label, "Speech bubble", "말풍선")
	bubble_style_label.custom_minimum_size.x = SETTINGS_LABEL_WIDTH
	bubble_style_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bubble_style_row.add_child(bubble_style_label)

	bubble_style_selector = OptionButton.new()
	bubble_style_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble_style_row.add_child(bubble_style_selector)

	appearance_status_label = Label.new()
	_style_secondary_label(appearance_status_label)
	appearance_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bind_localized_text(
		appearance_status_label,
		"",
		""
	)
	add_child(appearance_status_label)

	theme_selector.item_selected.connect(_on_theme_selected)
	appearance_mode_selector.item_selected.connect(_on_appearance_mode_selected)
	bubble_font_selector.item_selected.connect(_on_bubble_font_selected)
	bubble_font_size_slider.value_changed.connect(_on_bubble_font_size_changed)
	bubble_style_selector.item_selected.connect(_on_bubble_style_selected)

	_load_appearance_fields()
	_refresh_appearance_selector_labels()

func _load_appearance_fields() -> void:
	applying_appearance = true
	var settings: Dictionary = AppearanceSettingsScript.load_settings()

	_select_option_by_metadata(
		theme_selector,
		str(settings.get("theme", AppearanceSettingsScript.DEFAULT_THEME))
	)
	_select_option_by_metadata(
		appearance_mode_selector,
		str(settings.get("mode", AppearanceSettingsScript.DEFAULT_MODE))
	)
	_refresh_font_selector(
		str(settings.get("bubble_font", AppearanceSettingsScript.DEFAULT_BUBBLE_FONT))
	)
	_refresh_bubble_style_selector(
		str(settings.get("bubble_skin", AppearanceSettingsScript.DEFAULT_BUBBLE_SKIN))
	)

	bubble_font_size_slider.value = float(
		settings.get(
			"bubble_font_size",
			AppearanceSettingsScript.DEFAULT_BUBBLE_FONT_SIZE
		)
	)
	_update_font_size_value_label()
	applying_appearance = false

func _refresh_font_selector(desired_path: String = "") -> void:
	if bubble_font_selector == null:
		return

	if desired_path.is_empty() and bubble_font_selector.item_count > 0:
		desired_path = str(
			bubble_font_selector.get_item_metadata(
				bubble_font_selector.selected
			)
		)

	if desired_path.is_empty():
		desired_path = AppearanceSettingsScript.get_bubble_font_path()

	bubble_font_selector.clear()
	var fonts: Array[Dictionary] = AppearanceSettingsScript.get_available_fonts()

	for font_info: Dictionary in fonts:
		var index: int = bubble_font_selector.item_count
		bubble_font_selector.add_item(str(font_info.get("label", "Font")))
		bubble_font_selector.set_item_metadata(index, str(font_info.get("path", "")))

	if bubble_font_selector.item_count == 0:
		bubble_font_selector.add_item(
			AppearanceSettingsScript.DEFAULT_BUBBLE_FONT.get_file().get_basename()
		)
		bubble_font_selector.set_item_metadata(
			0,
			AppearanceSettingsScript.DEFAULT_BUBBLE_FONT
		)

	if not _select_option_by_metadata(bubble_font_selector, desired_path):
		bubble_font_selector.select(0)

func _refresh_bubble_style_selector(desired_path: String = "") -> void:
	if bubble_style_selector == null:
		return

	if desired_path.is_empty() and bubble_style_selector.item_count > 0:
		desired_path = str(
			bubble_style_selector.get_item_metadata(
				bubble_style_selector.selected
			)
		)

	bubble_style_selector.clear()
	var bubbles: Array[Dictionary] = AppearanceSettingsScript.get_available_bubbles()

	for bubble_info: Dictionary in bubbles:
		var index: int = bubble_style_selector.item_count
		var path: String = str(bubble_info.get("path", ""))
		var label: String = str(bubble_info.get("label", ""))

		if bool(bubble_info.get("builtin", false)):
			label = _l("Default bubble", "기본 말풍선")

		bubble_style_selector.add_item(label)
		bubble_style_selector.set_item_metadata(index, path)

	if not _select_option_by_metadata(bubble_style_selector, desired_path):
		bubble_style_selector.select(0)

func _refresh_theme_color_icons() -> void:
	if theme_selector == null:
		return
	var popup: PopupMenu = theme_selector.get_popup()
	for index: int in range(theme_selector.item_count):
		popup.set_item_as_radio_checkable(index, false)
		popup.set_item_as_checkable(index, false)
		var theme_id: String = str(theme_selector.get_item_metadata(index))
		var colors: Dictionary = AppearanceSettingsScript.THEME_COLORS.get(theme_id, {})
		theme_selector.set_item_icon(index, _theme_color_circle_icon(str(colors.get("accent", "#F6C543"))))

func _theme_color_circle_icon(color_value: String) -> Texture2D:
	var normalized: String = color_value.strip_edges().to_upper()
	if theme_color_icon_cache.has(normalized):
		return theme_color_icon_cache[normalized] as Texture2D
	var swatch: Color = Color.html(normalized) if Color.html_is_valid(normalized) else Color.WHITE
	var image: Image = Image.create(18, 18, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y: int in range(18):
		for x: int in range(18):
			var alpha: float = clampf(7.75 - Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(Vector2(9.0, 9.0)), 0.0, 1.0)
			if alpha > 0.0:
				var pixel: Color = swatch
				pixel.a *= alpha
				image.set_pixel(x, y, pixel)
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	theme_color_icon_cache[normalized] = texture
	return texture

func _select_option_by_metadata(
	selector: OptionButton,
	value: String
) -> bool:
	if selector == null:
		return false

	for index: int in range(selector.item_count):
		if str(selector.get_item_metadata(index)) == value:
			selector.select(index)
			return true

	return false

func _refresh_appearance_selector_labels() -> void:
	if theme_selector != null and theme_selector.item_count >= 6:
		var theme_labels: Array = [
			["Lemona", "레모나"],
			["Pink", "핑크"],
			["Blue", "블루"],
			["Green", "그린"],
			["Orange", "오렌지"],
			["Purple", "퍼플"]
		]
		for index: int in range(theme_labels.size()):
			theme_selector.set_item_text(index, _l(str(theme_labels[index][0]), str(theme_labels[index][1])))
		_refresh_theme_color_icons()

	if appearance_mode_selector != null and appearance_mode_selector.item_count >= 3:
		appearance_mode_selector.set_item_text(0, _l("System", "시스템"))
		appearance_mode_selector.set_item_text(1, _l("Light", "라이트"))
		appearance_mode_selector.set_item_text(2, _l("Dark", "다크"))

	if (
		bubble_style_selector != null
		and bubble_style_selector.item_count > 0
		and str(bubble_style_selector.get_item_metadata(0))
			== AppearanceSettingsScript.DEFAULT_BUBBLE_SKIN
	):
		bubble_style_selector.set_item_text(
			0,
			_l("Default bubble", "기본 말풍선")
		)

func _on_theme_selected(_index: int) -> void:
	_save_appearance_settings()

func _on_appearance_mode_selected(_index: int) -> void:
	_save_appearance_settings()

func _on_bubble_font_selected(_index: int) -> void:
	_save_appearance_settings()

func _on_bubble_font_size_changed(_value: float) -> void:
	_update_font_size_value_label()
	_save_appearance_settings()

func _on_bubble_style_selected(_index: int) -> void:
	_save_appearance_settings()

func _update_font_size_value_label() -> void:
	if bubble_font_size_value_label == null or bubble_font_size_slider == null:
		return

	bubble_font_size_value_label.text = str(roundi(bubble_font_size_slider.value)) + " px"

func _save_appearance_settings() -> void:
	if (
		theme_selector == null
		or appearance_mode_selector == null
		or bubble_font_selector == null
		or bubble_font_size_slider == null
		or bubble_style_selector == null
		or applying_appearance
	):
		return

	var theme_id: String = str(
		theme_selector.get_item_metadata(theme_selector.selected)
	)
	var mode_id: String = str(
		appearance_mode_selector.get_item_metadata(appearance_mode_selector.selected)
	)
	var bubble_font_path: String = str(
		bubble_font_selector.get_item_metadata(bubble_font_selector.selected)
	)
	var bubble_skin_path: String = str(
		bubble_style_selector.get_item_metadata(bubble_style_selector.selected)
	)
	var error: Error = AppearanceSettingsScript.save_settings({
		"theme": theme_id,
		"mode": mode_id,
		"bubble_font": bubble_font_path,
		"bubble_font_size": roundi(bubble_font_size_slider.value),
		"bubble_skin": bubble_skin_path
	})

	if error == OK:
		appearance_status_label.text = ""
	else:
		appearance_status_label.text = (
			_l(
				"Could not save appearance settings. Error: ",
				"화면 스타일을 저장하지 못했습니다. 오류: "
			)
			+ str(error)
		)

func build_startup_program_section() -> void:
	_add_section_header(
		"Startup",
		"시작 프로그램"
	)

	startup_program_check = CheckBox.new()
	_bind_localized_text(startup_program_check, "Start HaruHana with Windows", "시작 프로그램으로 설정")
	startup_program_check.button_pressed = StartupProgramSettingsScript.is_enabled()
	startup_program_check.disabled = not StartupProgramSettingsScript.is_supported()
	if startup_program_check.disabled:
		startup_program_check.tooltip_text = _l(
			"Available in the exported Windows build.",
			"내보낸 Windows 빌드에서 사용할 수 있습니다."
		)
	startup_program_check.toggled.connect(_on_startup_program_toggled)
	add_child(startup_program_check)

	startup_program_status = Label.new()
	_style_secondary_label(startup_program_status)
	startup_program_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(startup_program_status)

func _on_startup_program_toggled(enabled: bool) -> void:
	if applying_startup_program or startup_program_check == null:
		return
	var error: Error = StartupProgramSettingsScript.set_enabled(enabled)
	if error == OK:
		startup_program_status.text = ""
		return
	applying_startup_program = true
	startup_program_check.button_pressed = not enabled
	applying_startup_program = false
	startup_program_status.text = _l(
		"Could not change the Windows startup setting.",
		"Windows 시작 프로그램 설정을 변경하지 못했습니다."
	)

func build_update_section() -> void:
	_add_section_header(
		"Updates",
		"업데이트"
	)

	var version_row := HBoxContainer.new()
	add_child(version_row)

	var version_label := Label.new()
	_bind_localized_text(version_label, "Current version", "현재 버전")
	version_label.custom_minimum_size.x = SETTINGS_LABEL_WIDTH
	version_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	version_row.add_child(version_label)

	update_current_version_value = Label.new()
	update_current_version_value.text = "v" + update_service.get_current_version()
	update_current_version_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	update_current_version_value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	version_row.add_child(update_current_version_value)

	var button_row := HBoxContainer.new()
	button_row.alignment = BoxContainer.ALIGNMENT_END
	add_child(button_row)

	update_check_button = Button.new()
	_bind_localized_text(update_check_button, "Check for updates", "업데이트 확인")
	update_check_button.pressed.connect(_on_update_check_pressed)
	button_row.add_child(update_check_button)

	update_install_button = Button.new()
	_bind_localized_text(update_install_button, "Update now", "지금 업데이트")
	update_install_button.disabled = true
	update_install_button.pressed.connect(_on_update_install_pressed)
	button_row.add_child(update_install_button)

	update_progress_bar = ProgressBar.new()
	update_progress_bar.visible = false
	update_progress_bar.min_value = 0.0
	update_progress_bar.max_value = 100.0
	update_progress_bar.value = 0.0
	update_progress_bar.show_percentage = true
	update_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(update_progress_bar)

	update_status_label = Label.new()
	_style_secondary_label(update_status_label)
	update_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(update_status_label)

	if OS.get_name() != "Windows" or OS.has_feature("editor"):
		update_check_button.disabled = true
		update_install_button.disabled = true
		_set_update_status("windows_export_required")

func _connect_update_service() -> void:
	update_service.check_started.connect(_on_update_check_started)
	update_service.update_available.connect(_on_update_available)
	update_service.up_to_date.connect(_on_update_up_to_date)
	update_service.check_failed.connect(_on_update_check_failed)
	update_service.download_started.connect(_on_update_download_started)
	update_service.download_progress.connect(_on_update_download_progress)
	update_service.download_ready.connect(_on_update_download_ready)
	update_service.download_failed.connect(_on_update_download_failed)
	update_service.installer_preparing.connect(_on_update_installer_preparing)
	update_service.installer_ready.connect(_on_update_installer_ready)
	update_service.installer_failed.connect(_on_update_installer_failed)

func _on_update_check_pressed() -> void:
	update_available_version = ""
	update_install_button.disabled = true
	update_progress_bar.visible = false
	update_progress_bar.value = 0.0
	update_service.check_for_updates()

func _on_update_check_started() -> void:
	update_check_button.disabled = true
	update_install_button.disabled = true
	_set_update_status("checking")

func _on_update_available(version: String) -> void:
	update_available_version = version
	update_check_button.disabled = false
	update_install_button.disabled = false
	_set_update_status("available", version)

func _on_update_up_to_date(version: String) -> void:
	update_available_version = ""
	update_check_button.disabled = false
	update_install_button.disabled = true
	_set_update_status("up_to_date", version)

func _on_update_check_failed(message: String) -> void:
	update_check_button.disabled = false
	update_install_button.disabled = true
	_set_update_status("error", message)

func _on_update_install_pressed() -> void:
	update_check_button.disabled = true
	update_install_button.disabled = true
	update_service.download_update()

func _on_update_download_started() -> void:
	update_progress_bar.visible = true
	update_progress_bar.value = 0.0
	_set_update_status("downloading", update_available_version)

func _on_update_download_progress(downloaded: int, total: int) -> void:
	if total > 0:
		update_progress_bar.max_value = float(total)
		update_progress_bar.value = float(downloaded)
	else:
		update_progress_bar.max_value = 100.0
		update_progress_bar.value = 0.0

func _on_update_download_ready() -> void:
	update_progress_bar.visible = false
	var launch_result: Dictionary = update_service.launch_updater()
	if not bool(launch_result.get("ok", false)):
		update_check_button.disabled = false
		update_install_button.disabled = false
		_set_update_status("error", str(launch_result.get("error", "updater_launch_failed")))

func _on_update_installer_preparing() -> void:
	update_check_button.disabled = true
	update_install_button.disabled = true
	_set_update_status("preparing", update_available_version)

func _on_update_installer_ready() -> void:
	_set_update_status("restarting", update_available_version)
	if _request_update_shutdown():
		return
	update_check_button.disabled = false
	update_install_button.disabled = false
	_set_update_status("error", "shutdown_host_missing")

func _on_update_installer_failed(message: String) -> void:
	update_check_button.disabled = false
	update_install_button.disabled = false
	_set_update_status("error", message)

func _on_update_download_failed(message: String) -> void:
	update_progress_bar.visible = false
	update_check_button.disabled = false
	update_install_button.disabled = update_available_version.is_empty()
	_set_update_status("error", message)

func _request_update_shutdown() -> bool:
	for host: Node in get_tree().get_nodes_in_group(&"desktop_dialogue_hosts"):
		if host.has_method("request_update_shutdown"):
			host.call("request_update_shutdown")
			return true
	return false

func _set_update_status(code: String, detail: String = "") -> void:
	update_status_code = code
	update_status_detail = detail
	_refresh_update_status_text()

func _refresh_update_status_text() -> void:
	if update_status_label == null:
		return
	match update_status_code:
		"idle":
			update_status_label.text = ""
		"windows_export_required":
			update_status_label.text = _l(
				"Update checking is available in the exported Windows build.",
				"업데이트 확인은 내보낸 Windows 빌드에서 사용할 수 있습니다."
			)
		"checking":
			update_status_label.text = _l("Checking for updates...", "업데이트를 확인하는 중...")
		"available":
			update_status_label.text = _l(
				"Version v%s is available.",
				"v%s 버전을 사용할 수 있습니다."
			) % update_status_detail
		"up_to_date":
			update_status_label.text = _l(
				"You're up to date. Latest release: v%s.",
				"최신 버전입니다. 최신 릴리스: v%s."
			) % update_status_detail
		"downloading":
			update_status_label.text = _l(
				"Downloading v%s...",
				"v%s 버전을 다운로드하는 중..."
			) % update_status_detail
		"preparing":
			update_status_label.text = _l(
				"Preparing v%s for installation...",
				"v%s 버전 설치를 준비하는 중..."
			) % update_status_detail
		"restarting":
			update_status_label.text = _l(
				"Update downloaded. Restarting to install...",
				"업데이트를 다운로드했습니다. 설치를 위해 다시 시작하는 중..."
			)
		"previous_error":
			update_status_label.text = _l(
				"The previous update failed: ",
				"이전 업데이트에 실패했습니다: "
			) + update_status_detail
		"error":
			update_status_label.text = _update_error_text(update_status_detail)
		_:
			update_status_label.text = ""

func _update_error_text(code: String) -> String:
	match code:
		"release_missing":
			return _l(
				"No published GitHub release was found for Spiderenity/HaruHana.",
				"Spiderenity/HaruHana에 게시된 GitHub 릴리스를 찾지 못했습니다."
			)
		"asset_missing":
			return _l(
				"The latest release does not contain HaruHana-Windows-x86_64.zip.",
				"최신 릴리스에 HaruHana-Windows-x86_64.zip이 없습니다."
			)
		"updater_missing":
			return _l(
				"HaruHanaUpdater.exe is missing next to 하루하나.exe.",
				"하루하나.exe와 같은 폴더에 HaruHanaUpdater.exe가 없습니다."
			)
		"install_not_writable":
			return _l(
				"HaruHana's folder is not writable. Move it to a user-writable folder and try again.",
				"하루하나 폴더에 쓸 수 없습니다. 사용자가 쓸 수 있는 폴더로 옮긴 뒤 다시 시도하세요."
			)
		"size_mismatch", "digest_mismatch":
			return _l(
				"The downloaded update failed integrity verification.",
				"다운로드한 업데이트의 무결성 확인에 실패했습니다."
			)
		"invalid_digest", "unsupported_digest", "hash_failed":
			return _l(
				"The update checksum could not be verified.",
				"업데이트 체크섬을 확인하지 못했습니다."
			)
		"windows_export_required":
			return _l(
				"Updates can only be installed from the exported Windows build.",
				"업데이트는 내보낸 Windows 빌드에서만 설치할 수 있습니다."
			)
		"shutdown_host_missing":
			return _l(
				"The updater started, but HaruHana could not begin its update shutdown.",
				"업데이터를 시작했지만 하루하나가 업데이트 종료를 시작하지 못했습니다."
			)
		"updater_launch_failed", "finalizer_launch_failed":
			return _l(
				"HaruHanaUpdater.exe could not prepare the Windows update process.",
				"HaruHanaUpdater.exe가 Windows 업데이트 작업을 준비하지 못했습니다."
			)
		"updater_exited_early", "updater_prepare_timeout", "status_read_failed", "status_invalid":
			return _l(
				"The updater stopped before installation was ready.",
				"설치 준비가 완료되기 전에 업데이터가 중지되었습니다."
			)
		"package_missing":
			return _l(
				"The downloaded update package could not be found.",
				"다운로드한 업데이트 파일을 찾지 못했습니다."
			)
		"package_open_failed", "package_layout_invalid", "unsafe_package_path":
			return _l(
				"The update ZIP is invalid or does not have the required files at its root.",
				"업데이트 ZIP이 올바르지 않거나 필요한 파일이 ZIP 최상위에 없습니다."
			)
		"staging_directory_failed", "staging_write_failed", "finalizer_write_failed":
			return _l(
				"The updater could not prepare files for installation.",
				"업데이터가 설치할 파일을 준비하지 못했습니다."
			)
		"install_directory_missing", "update_install_failed", "restart_failed", "process_exit_timeout":
			return _l(
				"The update could not replace the installed files or restart HaruHana.",
				"업데이트가 설치된 파일을 교체하거나 하루하나를 다시 시작하지 못했습니다."
			)
		"directory_failed", "package_read_failed":
			return _l(
				"The update package could not be saved or read.",
				"업데이트 파일을 저장하거나 읽지 못했습니다."
			)
		"request_start_failed", "network_failed":
			return _l(
				"Could not connect to GitHub to check or download the update.",
				"GitHub에 연결하여 업데이트를 확인하거나 다운로드하지 못했습니다."
			)
		"invalid_response", "invalid_version":
			return _l(
				"GitHub returned an invalid release response.",
				"GitHub에서 올바르지 않은 릴리스 응답을 받았습니다."
			)
		_:
			if code.begins_with("http_"):
				return _l("GitHub request failed: ", "GitHub 요청 실패: ") + code.trim_prefix("http_")
			return _l("Update failed: ", "업데이트 실패: ") + code

func build_ai_section() -> void:
	_add_section_header(
		"AI",
		"AI"
	)

	var model_row := HBoxContainer.new()
	add_child(model_row)

	var model_label := Label.new()
	_bind_localized_text(model_label, "Model", "모델")
	model_label.custom_minimum_size.x = SETTINGS_LABEL_WIDTH
	model_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	model_row.add_child(model_label)

	model_selector = OptionButton.new()
	model_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_populate_model_selector()
	model_selector.item_selected.connect(_on_model_selected)
	model_row.add_child(model_selector)

	var custom_row := HBoxContainer.new()
	custom_row.name = "CustomAIModelRow"
	custom_row.visible = false
	add_child(custom_row)

	var custom_label := Label.new()
	_bind_localized_text(custom_label, "OpenRouter model ID", "OpenRouter 모델 ID")
	custom_label.custom_minimum_size.x = SETTINGS_LABEL_WIDTH
	custom_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_row.add_child(custom_label)

	custom_model_input = LineEdit.new()
	_bind_localized_text(
		custom_model_input,
		"provider/model",
		"provider/model",
		"placeholder_text"
	)
	custom_model_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_row.add_child(custom_model_input)

	var key_row := HBoxContainer.new()
	add_child(key_row)

	var key_label := Label.new()
	_bind_localized_text(key_label, "API key", "API 키")
	key_label.custom_minimum_size.x = SETTINGS_LABEL_WIDTH
	key_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	key_row.add_child(key_label)

	api_key_input = LineEdit.new()
	api_key_input.secret = true
	api_key_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_row.add_child(api_key_input)

	var cadence_row := HBoxContainer.new()
	add_child(cadence_row)

	var cadence_label := Label.new()
	_bind_localized_text(cadence_label, "Generation cadence", "생성 간격")
	cadence_label.custom_minimum_size.x = SETTINGS_LABEL_WIDTH
	cadence_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cadence_row.add_child(cadence_label)

	generation_cadence_selector = OptionButton.new()
	generation_cadence_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generation_cadence_selector.add_item("")
	generation_cadence_selector.add_item("")
	generation_cadence_selector.add_item("")
	generation_cadence_selector.item_selected.connect(_on_generation_cadence_selected)
	cadence_row.add_child(generation_cadence_selector)
	_refresh_generation_cadence_labels()

	var interval_row := HBoxContainer.new()
	add_child(interval_row)

	generation_interval_label = Label.new()
	_bind_localized_text(
		generation_interval_label,
		"Base interval (minutes)",
		"기본 간격(분)"
	)
	generation_interval_label.custom_minimum_size.x = SETTINGS_LABEL_WIDTH
	generation_interval_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	interval_row.add_child(generation_interval_label)

	generation_interval_spin = SpinBox.new()
	generation_interval_spin.min_value = 1.0
	generation_interval_spin.max_value = 120.0
	generation_interval_spin.step = 1.0
	generation_interval_spin.value = 30.0
	generation_interval_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	generation_interval_spin.value_changed.connect(_on_generation_interval_changed)
	interval_row.add_child(generation_interval_spin)
	_update_generation_interval_editable()

	var save_row := HBoxContainer.new()
	save_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_row.alignment = BoxContainer.ALIGNMENT_END
	add_child(save_row)

	var save_button := Button.new()
	_bind_localized_text(save_button, "Save AI settings", "AI 설정 저장")
	save_button.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	save_button.pressed.connect(_on_save_ai_pressed)
	save_row.add_child(save_button)

	_update_ai_input_for_selection()

func load_ai_fields() -> void:
	var settings: Dictionary = AISettings.load_settings()
	api_key_input.text = str(settings.get("api_key", ""))
	_select_saved_model(
		str(settings.get("model", AISettings.DEFAULT_MODEL))
	)
	_update_ai_input_for_selection()

func _populate_model_selector() -> void:
	if model_selector == null:
		return

	model_selector.clear()

	for preset: Dictionary in AISettings.MODEL_PRESETS:
		model_selector.add_item(str(preset.get("label", "")))
		model_selector.set_item_metadata(
			model_selector.item_count - 1,
			str(preset.get("route", ""))
		)

	model_selector.add_item(_l("Custom OpenRouter model...", "OpenRouter 모델 직접 입력..."))
	model_selector.set_item_metadata(
		model_selector.item_count - 1,
		"__custom_openrouter__"
	)

func _refresh_model_selector_labels() -> void:
	if model_selector == null or model_selector.item_count == 0:
		return

	model_selector.set_item_text(
		model_selector.item_count - 1,
		_l("Custom OpenRouter model...", "OpenRouter 모델 직접 입력...")
	)

func _select_saved_model(model: String) -> void:
	if model_selector == null:
		return

	var route: String = model.strip_edges()

	if route.is_empty():
		route = str(AISettings.DEFAULT_MODEL).strip_edges()

	for index: int in range(model_selector.item_count):
		if str(model_selector.get_item_metadata(index)) == route:
			model_selector.select(index)
			_update_ai_input_for_selection()
			return

	if route.begins_with("openrouter::"):
		var custom_index: int = model_selector.item_count - 1
		model_selector.select(custom_index)
		custom_model_input.text = route.trim_prefix("openrouter::")
	else:
		model_selector.select(0)
		custom_model_input.text = ""

	_update_ai_input_for_selection()

func _on_model_selected(_index: int) -> void:
	_update_ai_input_for_selection()

func _get_selected_ai_route() -> String:
	if model_selector == null or model_selector.item_count == 0:
		return "openrouter::openrouter/free"

	var route: String = str(
		model_selector.get_item_metadata(model_selector.selected)
	).strip_edges()

	if route == "__custom_openrouter__":
		var custom_id: String = custom_model_input.text.strip_edges()
		if custom_id.is_empty():
			custom_id = "openrouter/free"
		return "openrouter::" + custom_id

	if route.is_empty():
		return "openrouter::openrouter/free"

	return route

func _get_selected_ai_provider() -> String:
	var route: String = _get_selected_ai_route()
	var split_at: int = route.find("::")
	if split_at <= 0:
		return ""
	return route.substr(0, split_at).to_lower()

func _update_ai_input_for_selection() -> void:
	if model_selector == null or api_key_input == null or custom_model_input == null:
		return

	var is_custom: bool = (
		str(model_selector.get_item_metadata(model_selector.selected))
		== "__custom_openrouter__"
	)
	var custom_row: Node = get_node_or_null("CustomAIModelRow")
	if custom_row is Control:
		(custom_row as Control).visible = is_custom

	match _get_selected_ai_provider():
		"anthropic":
			api_key_input.placeholder_text = "sk-ant-..."
		"google":
			api_key_input.placeholder_text = "AIza..."
		"openrouter":
			api_key_input.placeholder_text = "sk-or-v1-..."
		_:
			api_key_input.placeholder_text = "sk-..."

func _on_save_ai_pressed() -> void:
	var error: Error = AISettings.save_settings(
		api_key_input.text,
		_get_selected_ai_route()
	)

	if error != OK:
		push_error(
			"Could not save AI settings. Error: "
			+ str(
				error
			)
		)

func _refresh_generation_cadence_labels() -> void:
	if generation_cadence_selector == null or generation_cadence_selector.item_count < 3:
		return

	var selected_index: int = generation_cadence_selector.selected
	generation_cadence_selector.set_item_text(
		0,
		_l("Free — 10 min base (8–12)", "무료 — 기본 10분 (8~12분)")
	)
	generation_cadence_selector.set_item_text(
		1,
		_l("Paid — 30 min base (24–36)", "유료 — 기본 30분 (24~36분)")
	)
	generation_cadence_selector.set_item_text(2, _l("Custom", "사용자 지정"))
	generation_cadence_selector.select(clampi(selected_index, 0, 2))

func _connect_desktop_settings_manager() -> void:
	desktop_settings_manager = _find_desktop_settings_manager(get_tree().current_scene)
	_load_generation_settings()

func _find_desktop_settings_manager(node: Node) -> DesktopCharacterManager:
	if node == null:
		return null

	if node is DesktopCharacterManager:
		return node as DesktopCharacterManager

	for child: Node in node.get_children():
		var result: DesktopCharacterManager = _find_desktop_settings_manager(child)
		if result != null:
			return result

	return null

func _load_generation_settings() -> void:
	if generation_cadence_selector == null or generation_interval_spin == null:
		return

	if desktop_settings_manager == null or not is_instance_valid(desktop_settings_manager):
		generation_cadence_selector.disabled = true
		_update_generation_interval_editable()
		return

	var settings: Dictionary = desktop_settings_manager.get_global_desktop_settings()
	refreshing_generation_settings = true

	match str(settings.get("ambient_cadence_mode", "free")):
		"paid":
			generation_cadence_selector.select(1)
		"custom":
			generation_cadence_selector.select(2)
		_:
			generation_cadence_selector.select(0)

	generation_interval_spin.value = float(settings.get("custom_ambient_minutes", 30.0))
	generation_cadence_selector.disabled = false
	refreshing_generation_settings = false
	_update_generation_interval_editable()

func _on_generation_cadence_selected(_index: int) -> void:
	_update_generation_interval_editable()
	_apply_generation_settings()

func _on_generation_interval_changed(_value: float) -> void:
	_apply_generation_settings()

func _update_generation_interval_editable() -> void:
	if generation_cadence_selector == null or generation_interval_spin == null:
		return

	var editable: bool = (
		not generation_cadence_selector.disabled
		and generation_cadence_selector.selected == 2
	)
	var disabled_text: Color = AppearanceSettingsScript.get_ui_color("text_faint")
	var text_color: Color = AppearanceSettingsScript.get_ui_color("text")
	var line_edit: LineEdit = generation_interval_spin.get_line_edit()

	generation_interval_spin.editable = editable
	line_edit.editable = editable
	line_edit.add_theme_color_override(
		"font_uneditable_color",
		disabled_text
	)
	line_edit.add_theme_color_override(
		"font_color",
		text_color
	)

	if generation_interval_label != null:
		generation_interval_label.add_theme_color_override(
			"font_color",
			text_color if editable else disabled_text
		)

func _apply_generation_settings() -> void:
	if refreshing_generation_settings:
		return
	if desktop_settings_manager == null or not is_instance_valid(desktop_settings_manager):
		return
	var settings: Dictionary = desktop_settings_manager.get_global_desktop_settings().duplicate(true)
	var cadence_mode: String = "free"
	match generation_cadence_selector.selected:
		1:
			cadence_mode = "paid"
		2:
			cadence_mode = "custom"

	settings["ambient_cadence_mode"] = cadence_mode
	settings["custom_ambient_minutes"] = generation_interval_spin.value
	desktop_settings_manager.apply_global_desktop_settings(settings)

func build_pack_section() -> void:
	_add_section_header(
		"Character Pack",
		"캐릭터 팩"
	)

	pack_selector = OptionButton.new()

	pack_selector.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	add_child(
		pack_selector
	)

	var set_pack_row := HBoxContainer.new()
	set_pack_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_pack_row.alignment = BoxContainer.ALIGNMENT_END
	add_child(set_pack_row)

	set_pack_button = Button.new()
	_bind_localized_text(set_pack_button, "Set Current Pack", "현재 팩으로 설정")
	set_pack_button.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	set_pack_button.pressed.connect(_on_set_pack_pressed)
	set_pack_row.add_child(set_pack_button)

func refresh_pack_list() -> void:
	pack_selector.clear()

	var packs: Array = (
		CharacterProfiles.list_packs()
	)

	if packs.is_empty():
		set_pack_button.disabled = true
		return

	set_pack_button.disabled = false

	var selected_index: int = 0

	var current_pack: String = (
		CharacterProfiles.get_current_pack()
	)

	for item_value: Variant in packs:
		if not (
			item_value is Dictionary
		):
			continue

		var item: Dictionary = (
			item_value
		)

		var pack_id: String = str(
			item.get(
				"id",
				""
			)
		).strip_edges()

		var display_name: String = str(
			item.get(
				"display_name",
				pack_id.capitalize()
			)
		).strip_edges()

		pack_selector.add_item(
			display_name
		)

		var index: int = (
			pack_selector.item_count - 1
		)

		pack_selector.set_item_metadata(
			index,
			item
		)

		if pack_id == current_pack:
			selected_index = index

	pack_selector.select(
		selected_index
	)

func _get_selected_pack() -> Dictionary:
	if pack_selector.item_count <= 0:
		return {}

	var index: int = (
		pack_selector.selected
	)

	if index < 0:
		return {}

	var metadata: Variant = (
		pack_selector.get_item_metadata(
			index
		)
	)

	if not (
		metadata is Dictionary
	):
		return {}

	return metadata

func _on_set_pack_pressed() -> void:
	var info: Dictionary = (
		_get_selected_pack()
	)

	if info.is_empty():
		return

	var pack_id: String = str(
		info.get(
			"id",
			""
		)
	).strip_edges()

	if pack_id.is_empty():
		return

	var error: Error = (
		CharacterProfiles.set_current_pack(
			pack_id
		)
	)

	if error != OK:
		push_error(
			"Could not set current pack. Error: "
			+ str(
				error
			)
		)
		return

	refresh_pack_list()

	_notify_chat_profiles_changed()

	character_pack_changed.emit(
		pack_id
	)

func _notify_chat_profiles_changed() -> void:
	var root: Node = (
		get_tree().current_scene
	)

	if root == null:
		return

	_notify_chat_recursive(
		root
	)

func _notify_chat_recursive(
	node: Node
) -> void:

	if node is CompanionChatPanel:
		(node as CompanionChatPanel).reload_character_list()

	for child: Node in node.get_children():
		_notify_chat_recursive(
			child
		)

