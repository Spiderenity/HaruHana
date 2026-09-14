extends VBoxContainer
class_name DesktopCharacterSettings

const SLOT_COUNT: int = 2
const LABEL_COLUMN_WIDTH: float = 120.0

const AppLanguageScript = preload(
	"res://system/app/app_language.gd"
)

const AppearanceSettingsScript = preload(
	"res://system/app/appearance_settings.gd"
)

var manager: DesktopCharacterManager = null

var character_selectors: Array[OptionButton] = []

var skin_selectors: Array[OptionButton] = []
var font_selectors: Array[OptionButton] = []
var monitor_selectors: Array[OptionButton] = []
var monitor_refresh_seconds: float = 0.0

var ambient_checks: Array[CheckBox] = []

var timer_checks: Array[CheckBox] = []

var slot_character_ids: Array = []

var slot_skin_ids: Array = []

var opacity_slider: HSlider = null
var scale_slider: HSlider = null
var bubble_scale_slider: HSlider = null
var bubble_opacity_slider: HSlider = null
var vertical_movement_check: CheckBox = null
var bubble_drag_check: CheckBox = null
var previous_character_opacity_percent: float = 82.0
var previous_character_scale_percent: float = 75.0

var refreshing: bool = false
var transition_in_progress: bool = false
var last_language: String = ""
var last_debug_tooltips_enabled: bool = false

func configure(
	desktop_manager: DesktopCharacterManager
) -> void:

	manager = desktop_manager

	_connect_manager_signals()

	if not is_node_ready():
		return

	refresh()

func _ready() -> void:
	add_theme_constant_override("separation", AppearanceSettingsScript.UI_STACK_GAP)
	build_ui()
	_apply_layout_spacing(self)
	apply_language()
	refresh()
	set_process(true)

func _apply_layout_spacing(node: Node) -> void:
	if node is HBoxContainer:
		var row: HBoxContainer = node as HBoxContainer
		row.add_theme_constant_override("separation", 12)
		row.custom_minimum_size.y = maxf(row.custom_minimum_size.y, 38.0)
	elif node is HSeparator:
		(node as HSeparator).custom_minimum_size.y = 1.0
	elif node is VBoxContainer and node != self:
		(node as VBoxContainer).add_theme_constant_override("separation", AppearanceSettingsScript.UI_STACK_GAP)

	for child: Node in node.get_children():
		_apply_layout_spacing(child)

func _process(_delta: float) -> void:
	monitor_refresh_seconds += _delta
	if monitor_refresh_seconds >= 1.0 and not transition_in_progress and manager != null:
		monitor_refresh_seconds = 0.0
		for slot: int in range(monitor_selectors.size()):
			_refresh_monitor_selector(slot)
	var language: String = AppLanguageScript.get_language()
	var debug_tooltips: bool = _debug_tooltips_enabled()
	var language_changed: bool = language != last_language
	var debug_changed: bool = debug_tooltips != last_debug_tooltips_enabled
	if not language_changed and not debug_changed:
		return

	last_debug_tooltips_enabled = debug_tooltips
	apply_language()
	if debug_changed and manager != null:
		refresh()

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
	last_language = AppLanguageScript.get_language()
	_apply_language_to_node(self)

func _localized_setting_label(english: String) -> String:
	match english:
		"Default opacity":
			return "기본 불투명도"
		"Speech bubble opacity":
			return "말풍선 불투명도"
		"Character size":
			return "캐릭터 크기"
		"Speech bubble size":
			return "말풍선 크기"
		_:
			return english

func _debug_tooltips_enabled() -> bool:
	var cursor: Node = self
	while cursor != null:
		if cursor is CompanionBoardWindow:
			return (cursor as CompanionBoardWindow).are_debug_tools_unlocked()
		cursor = cursor.get_parent()
	return false

func _localized_diagnostic_reason(reason: String, character_id: String) -> String:
	match reason:
		"Ready (runtime sprites).":
			return _l("Ready (runtime sprites).", "준비됨 (런타임 스프라이트).")
		"Character ID is empty.":
			return _l("Character ID is empty.", "캐릭터 ID가 비어 있습니다.")
		"No usable sprite set was found.":
			return _l("No usable sprite set was found.", "사용 가능한 스프라이트 세트를 찾지 못했습니다.")
		"Desktop skin unavailable.":
			return _l("Desktop skin unavailable.", "데스크탑용 스킨을 사용할 수 없습니다.")

	if reason.begins_with("Profile could not be loaded for "):
		return _l(
			reason,
			"프로필을 불러오지 못했습니다: " + character_id
		)
	return reason

func build_ui() -> void:
	var top_spacer := Control.new()
	top_spacer.custom_minimum_size.y = 12.0
	add_child(top_spacer)

	var display_title := Label.new()
	_bind_localized_text(display_title, "Display Settings", "표시 설정")
	display_title.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	add_child(display_title)
	add_child(HSeparator.new())

	opacity_slider = _add_number_slider(
		"Default opacity",
		25.0,
		100.0,
		1.0,
		82.0,
		"%"
	)

	bubble_opacity_slider = _add_number_slider(
		"Speech bubble opacity",
		25.0,
		100.0,
		1.0,
		100.0,
		"%"
	)

	scale_slider = _add_number_slider(
		"Character size",
		50.0,
		150.0,
		1.0,
		100.0,
		"%"
	)

	bubble_scale_slider = _add_number_slider(
		"Speech bubble size",
		50.0,
		150.0,
		1.0,
		100.0,
		"%"
	)

	vertical_movement_check = CheckBox.new()
	_bind_localized_text(
		vertical_movement_check,
		"Allow vertical character movement",
		"캐릭터 세로 이동 허용"
	)
	add_child(vertical_movement_check)

	bubble_drag_check = CheckBox.new()
	_bind_localized_text(
		bubble_drag_check,
		"Allow speech bubble dragging",
		"말풍선 드래그 허용"
	)
	add_child(bubble_drag_check)

	var reset_bubbles_button: Button = Button.new()
	_bind_localized_text(
		reset_bubbles_button,
		"Reset speech bubble positions",
		"말풍선 위치 초기화"
	)
	reset_bubbles_button.pressed.connect(_on_reset_bubble_positions_pressed)
	var reset_row := HBoxContainer.new()
	reset_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_bubbles_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(reset_row)
	reset_row.add_child(reset_bubbles_button)
	var reset_characters := Button.new()
	reset_characters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bind_localized_text(reset_characters, "Reset character positions", "캐릭터 위치 초기화")
	reset_characters.pressed.connect(func() -> void:
		if manager != null:
			manager.reset_character_positions()
	)
	reset_row.add_child(reset_characters)

	opacity_slider.value_changed.connect(_on_character_opacity_changed)
	bubble_opacity_slider.value_changed.connect(_on_global_setting_changed)
	scale_slider.value_changed.connect(_on_character_size_changed)
	bubble_scale_slider.value_changed.connect(_on_global_setting_changed)
	vertical_movement_check.toggled.connect(_on_global_toggle_changed)
	bubble_drag_check.toggled.connect(_on_global_toggle_changed)

	var section_spacer := Control.new()
	section_spacer.custom_minimum_size.y = 12.0
	add_child(section_spacer)

	var pet_title := Label.new()
	_bind_localized_text(pet_title, "Pet Settings", "펫 설정")
	pet_title.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	add_child(pet_title)
	add_child(HSeparator.new())

	for slot_index: int in range(SLOT_COUNT):
		build_slot(slot_index)

func _add_number_slider(
	label_text: String,
	minimum: float,
	maximum: float,
	step_value: float,
	default_value: float,
	suffix: String = ""
) -> HSlider:
	var row: HBoxContainer = HBoxContainer.new()
	add_child(row)

	var label: Label = Label.new()
	_bind_localized_text(
		label,
		label_text,
		_localized_setting_label(label_text)
	)
	label.custom_minimum_size.x = LABEL_COLUMN_WIDTH
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)

	var slider: HSlider = HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step_value
	slider.value = default_value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var value_label: Label = Label.new()
	value_label.custom_minimum_size.x = 52.0
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(value_label)
	_update_slider_value_label(
		default_value,
		value_label,
		step_value,
		suffix
	)
	slider.value_changed.connect(
		_update_slider_value_label.bind(
			value_label,
			step_value,
			suffix
		)
	)

	return slider

func _update_slider_value_label(
	value: float,
	label: Label,
	step_value: float,
	suffix: String
) -> void:
	if label == null:
		return
	var value_text: String
	if step_value >= 1.0:
		value_text = str(int(round(value)))
	elif step_value >= 0.1:
		value_text = "%.1f" % value
	else:
		value_text = "%.2f" % value
	label.text = value_text + suffix

func refresh_global_settings() -> void:
	if manager == null:
		return

	var global_settings: Dictionary = manager.get_global_desktop_settings()

	opacity_slider.value = (
		float(global_settings.get("base_opacity", 0.82))
		* 100.0
	)
	previous_character_opacity_percent = opacity_slider.value
	bubble_opacity_slider.value = float(
		global_settings.get("bubble_opacity", 1.0)
	) * 100.0
	scale_slider.value = (
		float(global_settings.get("character_scale", 0.75))
		* 100.0
	)
	previous_character_scale_percent = scale_slider.value
	bubble_scale_slider.value = float(
		global_settings.get("bubble_scale", 1.0)
	) * 100.0
	vertical_movement_check.button_pressed = bool(
		global_settings.get("vertical_movement_enabled", false)
	)
	bubble_drag_check.button_pressed = bool(
		global_settings.get("bubble_drag_enabled", true)
	)

func _on_global_setting_changed(
	_value: float
) -> void:
	_apply_global_settings()

func _on_character_opacity_changed(value: float) -> void:
	if refreshing:
		previous_character_opacity_percent = value
		return
	var delta := value - previous_character_opacity_percent
	previous_character_opacity_percent = value
	var adjusted_bubble_opacity := clampf(
		bubble_opacity_slider.value + delta,
		bubble_opacity_slider.min_value,
		bubble_opacity_slider.max_value
	)
	if not is_equal_approx(bubble_opacity_slider.value, adjusted_bubble_opacity):
		bubble_opacity_slider.value = adjusted_bubble_opacity
		return
	_apply_global_settings()

func _on_character_size_changed(value: float) -> void:
	if refreshing:
		previous_character_scale_percent = value
		return
	var delta := value - previous_character_scale_percent
	previous_character_scale_percent = value
	var adjusted_bubble_scale := clampf(
		bubble_scale_slider.value + delta,
		bubble_scale_slider.min_value,
		bubble_scale_slider.max_value
	)
	if not is_equal_approx(bubble_scale_slider.value, adjusted_bubble_scale):
		bubble_scale_slider.value = adjusted_bubble_scale
		return
	_apply_global_settings()

func _on_global_toggle_changed(_enabled: bool) -> void:
	_apply_global_settings()

func _on_reset_bubble_positions_pressed() -> void:
	if manager == null:
		return
	var result: Error = manager.reset_speech_bubble_offsets()
	if result != OK:
		push_error("Could not reset speech bubble positions. Error: " + str(result))

func _apply_global_settings() -> void:
	if refreshing or manager == null:
		return

	var current_settings: Dictionary = manager.get_global_desktop_settings().duplicate(true)
	current_settings["base_opacity"] = opacity_slider.value / 100.0
	current_settings["bubble_opacity"] = bubble_opacity_slider.value / 100.0
	current_settings["character_scale"] = scale_slider.value / 100.0
	current_settings["bubble_scale"] = bubble_scale_slider.value / 100.0
	current_settings["vertical_movement_enabled"] = vertical_movement_check.button_pressed
	current_settings["bubble_drag_enabled"] = bubble_drag_check.button_pressed

	var result: Error = manager.apply_global_desktop_settings(current_settings)
	if result != OK:
		push_error("Could not save desktop settings. Error: " + str(result))

func build_slot(
	slot_index: int
) -> void:

	if slot_index > 0:
		add_child(
			HSeparator.new()
		)

	var character_row: HBoxContainer = (
		HBoxContainer.new()
	)

	add_child(
		character_row
	)

	var character_label: Label = Label.new()

	_bind_localized_text(
		character_label,
		"Character " + str(slot_index + 1),
		"캐릭터" + str(slot_index + 1)
	)

	character_label.custom_minimum_size.x = LABEL_COLUMN_WIDTH
	character_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	character_row.add_child(
		character_label
	)

	var character_selector: OptionButton = (
		OptionButton.new()
	)

	character_selector.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	character_row.add_child(
		character_selector
	)

	character_selectors.append(
		character_selector
	)

	slot_character_ids.append(
		[]
	)

	var skin_row: HBoxContainer = (
		HBoxContainer.new()
	)

	add_child(
		skin_row
	)

	var skin_label: Label = Label.new()

	_bind_localized_text(skin_label, "Skin", "스킨")

	skin_label.custom_minimum_size.x = LABEL_COLUMN_WIDTH
	skin_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	skin_row.add_child(
		skin_label
	)

	var skin_selector: OptionButton = (
		OptionButton.new()
	)

	skin_selector.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	skin_row.add_child(
		skin_selector
	)

	skin_selectors.append(
		skin_selector
	)

	slot_skin_ids.append(
		[]
	)

	var font_selector := _add_extra_selector("Bubble font", "말풍선 폰트")
	font_selectors.append(font_selector)
	font_selector.item_selected.connect(_on_font_selected.bind(slot_index))
	var monitor_selector := _add_extra_selector("Monitor", "모니터")
	monitor_selectors.append(monitor_selector)
	monitor_selector.item_selected.connect(_on_monitor_selected.bind(slot_index))

	var behavior_row := HBoxContainer.new()
	behavior_row.add_theme_constant_override("separation", 12)
	add_child(behavior_row)

	var behavior_label := Label.new()
	_bind_localized_text(behavior_label, "Reactions", "반응")
	behavior_label.custom_minimum_size.x = LABEL_COLUMN_WIDTH
	behavior_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	behavior_row.add_child(behavior_label)

	var ambient_check: CheckBox = CheckBox.new()
	_bind_localized_text(ambient_check, "Ambient dialogue", "상시 대화")
	behavior_row.add_child(ambient_check)
	ambient_checks.append(ambient_check)

	var timer_check: CheckBox = CheckBox.new()
	_bind_localized_text(timer_check, "Timer reactions", "타이머 반응")
	behavior_row.add_child(timer_check)
	timer_checks.append(timer_check)

	character_selector.item_selected.connect(
		_on_character_selected.bind(
			slot_index
		)
	)

	skin_selector.item_selected.connect(
		_on_skin_selected.bind(
			slot_index
		)
	)

	ambient_check.toggled.connect(
		_on_behavior_toggled.bind(
			slot_index
		)
	)

	timer_check.toggled.connect(
		_on_behavior_toggled.bind(
			slot_index
		)
	)

func _add_extra_selector(english: String, korean: String) -> OptionButton:
	var row := HBoxContainer.new()
	add_child(row)
	var label := Label.new()
	_bind_localized_text(label, english, korean)
	label.custom_minimum_size.x = LABEL_COLUMN_WIDTH
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.fit_to_longest_item = false
	row.add_child(selector)
	return selector

func _refresh_font_selector(slot: int) -> void:
	var selector := font_selectors[slot]
	selector.clear()
	selector.add_item(_l("Use common setting", "공통 설정 사용"))
	selector.set_item_metadata(0, "")
	var id := get_selected_character_id(slot)
	var saved := str(DesktopPreferences.get_entry(id).get("font", ""))
	for font: Dictionary in AppearanceSettingsScript.get_available_fonts():
		selector.add_item(str(font.get("label", "")))
		var index := selector.item_count - 1
		selector.set_item_metadata(index, str(font.get("path", "")))
		if str(font.get("path", "")) == saved:
			selector.select(index)
	selector.disabled = id.is_empty() or transition_in_progress

func _refresh_monitor_selector(slot: int) -> void:
	var selector := monitor_selectors[slot]
	if selector.get_popup().visible:
		return
	selector.clear()
	for index: int in range(DisplayServer.get_screen_count()):
		var size := DisplayServer.screen_get_size(index)
		var suffix := _l(" (Primary)", " (주 모니터)") if index == DisplayServer.get_primary_screen() else ""
		selector.add_item(_l("Monitor ", "모니터 ") + str(index + 1) + suffix + " · %d × %d" % [size.x, size.y])
	var actor := manager.get_actor(get_selected_character_id(slot)) if manager != null else null
	selector.disabled = actor == null or transition_in_progress
	if actor != null and actor.pet_interaction != null:
		selector.select(actor.pet_interaction.get_current_screen())

func _on_font_selected(index: int, slot: int) -> void:
	if refreshing or transition_in_progress:
		return
	var id := get_selected_character_id(slot)
	if id.is_empty():
		return
	var error := DesktopPreferences.update_entry(id, {"font": str(font_selectors[slot].get_item_metadata(index))})
	if error != OK:
		push_warning("Could not save character font: " + error_string(error))
		_refresh_font_selector(slot)

func _on_monitor_selected(index: int, slot: int) -> void:
	if refreshing or transition_in_progress or manager == null:
		return
	var actor := manager.get_actor(get_selected_character_id(slot))
	if actor != null and actor.pet_interaction != null:
		actor.pet_interaction.move_to_screen(index)

func refresh() -> void:
	if not is_node_ready():
		return

	if manager == null:
		set_all_available(
			false
		)

		return

	refreshing = true

	refresh_global_settings()

	var configured_slots: Array[String] = (
		get_configured_slots()
	)

	for slot_index: int in range(
		SLOT_COUNT
	):
		refresh_character_selector(
			slot_index,
			configured_slots[slot_index]
		)

		refresh_skin_selector(
			slot_index
		)

		load_preferences_for_slot(
			slot_index
		)
		_refresh_font_selector(slot_index)
		_refresh_monitor_selector(slot_index)

	refreshing = false

	update_slot_enabled_states()

	if transition_in_progress:
		set_all_available(
			false
		)

func get_configured_slots() -> Array[String]:
	var result: Array[String] = ["", ""]
	if manager == null:
		return result

	var source: Array[String] = manager.get_slot_character_ids()
	for index: int in range(mini(source.size(), SLOT_COUNT)):
		result[index] = source[index].strip_edges().to_lower()
	return result

func refresh_character_selector(
	slot_index: int,
	selected_character_id: String
) -> void:

	var selector: OptionButton = (
		character_selectors[
			slot_index
		]
	)

	var ids: Array = (
		slot_character_ids[
			slot_index
		]
	)

	selector.clear()

	ids.clear()

	selector.add_item(
		_l("None", "없음")
	)

	ids.append(
		""
	)

	var pack_id: String = CharacterProfiles.get_current_pack()
	var character_ids: Array[String] = (
		CharacterProfiles.get_pack_character_ids(pack_id)
	)

	for character_id: String in character_ids:
		var summary: Dictionary = CharacterProfiles.load_profile(character_id)

		if summary.is_empty():
			summary = CharacterProfiles.get_character_definition(
				pack_id,
				character_id
			)

		if not manager.is_character_allowed_in_slot(character_id, slot_index):
			continue

		var display_name: String = str(
			summary.get(
				"display_name",
				character_id.capitalize()
			)
		).strip_edges()

		var diagnostic: Dictionary = manager.get_desktop_character_diagnostic(character_id)

		var usable: bool = bool(
			diagnostic.get(
				"usable",
				false
			)
		)

		var reason: String = str(
			diagnostic.get(
				"reason",
				"Desktop skin unavailable."
			)
		).strip_edges()

		if usable:
			selector.add_item(
				display_name
			)

		else:
			selector.add_item(
				display_name
				+ _l(" — desktop unavailable", " — 데스크탑 사용 불가")
			)

		ids.append(
			character_id
		)

		var item_index: int = (
			selector.item_count - 1
		)

		if _debug_tooltips_enabled():
			selector.set_item_tooltip(
				item_index,
				_localized_diagnostic_reason(reason, character_id)
			)
		else:
			selector.set_item_tooltip(item_index, "")

		if not usable:
			selector.set_item_disabled(
				item_index,
				true
			)

	if ids.is_empty():
		selector.disabled = true
		return

	var selected_index: int = 0

	for index: int in range(
		ids.size()
	):
		if str(
			ids[index]
		) == selected_character_id:
			selected_index = index
			break

	selector.select(
		selected_index
	)

	selector.disabled = false

func refresh_skin_selector(
	slot_index: int
) -> void:

	var selector: OptionButton = (
		skin_selectors[
			slot_index
		]
	)

	var ids: Array = (
		slot_skin_ids[
			slot_index
		]
	)

	selector.clear()

	ids.clear()

	var character_id: String = (
		get_selected_character_id(
			slot_index
		)
	)

	if character_id.is_empty():
		selector.disabled = true
		return

	var available_skins: Array[String] = manager.get_available_skins(character_id)

	for skin_value: Variant in available_skins:
		var skin_id: String = (
			str(
				skin_value
			)
				.strip_edges()
		)

		if skin_id.is_empty():
			continue

		ids.append(
			skin_id
		)

		selector.add_item(
			format_skin_name(
				skin_id
			)
		)

	selector.disabled = (
		ids.is_empty()
	)

func load_preferences_for_slot(
	slot_index: int
) -> void:

	var character_id: String = (
		get_selected_character_id(
			slot_index
		)
	)

	if character_id.is_empty():
		ambient_checks[
			slot_index
		].button_pressed = true

		timer_checks[
			slot_index
		].button_pressed = true

		return

	var preferences: Dictionary = manager.get_character_preferences(character_id)

	var selected_skin: String = str(
		preferences.get(
			"skin",
			""
		)
	).strip_edges()

	var ids: Array = (
		slot_skin_ids[
			slot_index
		]
	)

	for index: int in range(
		ids.size()
	):
		if str(
			ids[index]
		) == selected_skin:
			skin_selectors[
				slot_index
			].select(
				index
			)

			break

	ambient_checks[
		slot_index
	].button_pressed = bool(
		preferences.get(
			"ambient_dialogue",
			true
		)
	)

	timer_checks[
		slot_index
	].button_pressed = bool(
		preferences.get(
			"timer_reactions",
			true
		)
	)

func _on_character_selected(
	_selected_index: int,
	slot_index: int
) -> void:

	if refreshing:
		return

	var character_id: String = (
		get_selected_character_id(
			slot_index
		)
	)

	if is_duplicate_selection(
		slot_index,
		character_id
	):
		call_deferred(
			"refresh"
		)

		return

	refreshing = true

	refresh_skin_selector(
		slot_index
	)

	load_preferences_for_slot(
		slot_index
	)

	refreshing = false

	update_slot_enabled_states()

	apply_slot(
		slot_index
	)

func _on_skin_selected(
	_selected_index: int,
	slot_index: int
) -> void:

	if refreshing:
		return

	apply_slot(
		slot_index
	)

func _on_behavior_toggled(
	_enabled: bool,
	slot_index: int
) -> void:

	if refreshing:
		return

	apply_slot(
		slot_index
	)

func is_duplicate_selection(
	slot_index: int,
	character_id: String
) -> bool:

	if character_id.is_empty():
		return false

	for other_slot: int in range(
		SLOT_COUNT
	):
		if other_slot == slot_index:
			continue

		if (
			get_selected_character_id(
				other_slot
			)
			== character_id
		):
			return true

	return false

func get_selected_character_id(
	slot_index: int
) -> String:

	if (
		slot_index < 0
		or slot_index
			>= character_selectors.size()
	):
		return ""

	var selector: OptionButton = (
		character_selectors[
			slot_index
		]
	)

	var ids: Array = (
		slot_character_ids[
			slot_index
		]
	)

	var index: int = (
		selector.selected
	)

	if (
		index < 0
		or index >= ids.size()
	):
		return ""

	return (
		str(
			ids[index]
		)
			.strip_edges()
			.to_lower()
	)

func get_selected_skin_id(
	slot_index: int
) -> String:

	if (
		slot_index < 0
		or slot_index
			>= skin_selectors.size()
	):
		return ""

	var selector: OptionButton = (
		skin_selectors[
			slot_index
		]
	)

	var ids: Array = (
		slot_skin_ids[
			slot_index
		]
	)

	var index: int = (
		selector.selected
	)

	if (
		index < 0
		or index >= ids.size()
	):
		return ""

	return str(
		ids[index]
	).strip_edges()

func apply_slot(
	slot_index: int
) -> void:
	if manager == null or transition_in_progress:
		return

	var character_id: String = get_selected_character_id(slot_index)
	if character_id.is_empty():
		var none_error: Error = manager.apply_slot_settings(
			slot_index, "", "", true, true
		)
		if none_error != OK:
			push_error("Could not disable desktop slot. Error: " + str(none_error))
		return

	if is_duplicate_selection(slot_index, character_id):
		return

	var skin_id: String = get_selected_skin_id(slot_index)
	if skin_id.is_empty():
		return

	var error_code: Error = manager.apply_slot_settings(
		slot_index,
		character_id,
		skin_id,
		ambient_checks[slot_index].button_pressed,
		timer_checks[slot_index].button_pressed
	)
	if error_code != OK:
		push_error("Could not save desktop settings. Error: " + str(error_code))

func update_slot_enabled_states() -> void:
	for slot: int in range(font_selectors.size()):
		_refresh_font_selector(slot)
		_refresh_monitor_selector(slot)
	for slot_index: int in range(
		SLOT_COUNT
	):
		var character_id: String = (
			get_selected_character_id(
				slot_index
			)
		)

		var enabled: bool = (
			not character_id.is_empty()
		)

		skin_selectors[
			slot_index
		].disabled = (
			not enabled
			or slot_skin_ids[
				slot_index
			].is_empty()
		)

		ambient_checks[
			slot_index
		].disabled = (
			not enabled
		)

		timer_checks[
			slot_index
		].disabled = (
			not enabled
		)

func set_all_available(
	available: bool
) -> void:

	for selector: OptionButton in font_selectors + monitor_selectors:
		selector.disabled = not available
	for selector: OptionButton in character_selectors:
		selector.disabled = (
			not available
		)

	for selector: OptionButton in skin_selectors:
		selector.disabled = (
			not available
		)

	for check: CheckBox in ambient_checks:
		check.disabled = (
			not available
		)

	for check: CheckBox in timer_checks:
		check.disabled = (
			not available
		)

func _connect_manager_signals() -> void:
	if manager == null:
		return

	if not manager.slot_change_started.is_connected(_on_slot_change_started):
		manager.slot_change_started.connect(_on_slot_change_started)
	if not manager.slot_change_completed.is_connected(_on_slot_change_completed):
		manager.slot_change_completed.connect(_on_slot_change_completed)

func _on_slot_change_started(
	_slot_index: int,
	_old_character_id: String,
	_new_character_id: String
) -> void:
	transition_in_progress = true
	set_all_available(
		false
	)

func _on_slot_change_completed(
	_slot_index: int,
	_old_character_id: String,
	_new_character_id: String,
	error_code: int
) -> void:

	transition_in_progress = false

	refresh()

	if error_code != OK:
		push_error(
			"Character change failed. Error: "
			+ str(
				error_code
			)
		)

func format_skin_name(
	skin_id: String
) -> String:

	return (
		skin_id
			.replace(
				"_",
				" "
			)
			.capitalize()
	)
