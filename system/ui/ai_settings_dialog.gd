extends Window
class_name AISettingsDialog

signal finished(saved: bool)

const AppLanguageScript = preload("res://system/app/app_language.gd")
const AppearanceSettingsScript = preload("res://system/app/appearance_settings.gd")


var model_selector: OptionButton
var custom_model_row: HBoxContainer
var custom_model_input: LineEdit
var api_key_input: LineEdit
var status_label: Label
var title_label: Label
var note_label: Label
var model_label: Label
var custom_label: Label
var key_label: Label
var cancel_button: Button
var save_button: Button
var background_panel: PanelContainer
var _finished_emitted: bool = false

func _ready() -> void:
	theme = AppearanceSettingsScript.build_theme()
	title = _l("AI Settings", "AI 설정")
	size = Vector2i(560, 330)
	min_size = Vector2i(480, 300)
	transient = true
	close_requested.connect(_cancel)
	_build_ui()
	load_fields()

func _l(english: String, korean: String) -> String:
	return AppLanguageScript.text(english, korean)

func _build_ui() -> void:
	background_panel = PanelContainer.new()
	background_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_panel.theme = theme
	add_child(background_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	background_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)

	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 20)
	box.add_child(title_label)

	note_label = Label.new()
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note_label)

	var model_row := HBoxContainer.new()
	model_row.add_theme_constant_override("separation", 10)
	box.add_child(model_row)
	model_label = Label.new()
	model_label.custom_minimum_size.x = 150
	model_row.add_child(model_label)
	model_selector = OptionButton.new()
	model_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for preset: Dictionary in AISettings.MODEL_PRESETS:
		model_selector.add_item(str(preset.get("label", "")))
		model_selector.set_item_metadata(model_selector.item_count - 1, str(preset.get("route", "")))
	model_selector.add_item("")
	model_selector.set_item_metadata(model_selector.item_count - 1, "__custom_openrouter__")
	model_selector.item_selected.connect(_on_model_selected)
	model_row.add_child(model_selector)

	custom_model_row = HBoxContainer.new()
	custom_model_row.add_theme_constant_override("separation", 10)
	box.add_child(custom_model_row)
	custom_label = Label.new()
	custom_label.custom_minimum_size.x = 150
	custom_model_row.add_child(custom_label)
	custom_model_input = LineEdit.new()
	custom_model_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_model_input.placeholder_text = "openrouter/free"
	custom_model_row.add_child(custom_model_input)

	var key_row := HBoxContainer.new()
	key_row.add_theme_constant_override("separation", 10)
	box.add_child(key_row)
	key_label = Label.new()
	key_label.custom_minimum_size.x = 150
	key_row.add_child(key_label)
	api_key_input = LineEdit.new()
	api_key_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	api_key_input.secret = true
	key_row.add_child(api_key_input)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(status_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	cancel_button = Button.new()
	cancel_button.pressed.connect(_cancel)
	buttons.add_child(cancel_button)
	save_button = Button.new()
	save_button.pressed.connect(_save)
	buttons.add_child(save_button)

	apply_language()

func apply_language() -> void:
	title = _l("AI Settings", "AI 설정")
	if title_label == null:
		return
	title_label.text = _l("AI Settings", "AI 설정")
	note_label.text = _l(
		"Choose a provider and enter its API key. These settings are shared by HaruHana and the creator tools.",
		"AI 제공자를 선택하고 API 키를 입력하세요. 이 설정은 HaruHana와 크리에이터 도구가 함께 사용합니다."
	)
	model_label.text = _l("Model", "모델")
	custom_label.text = _l("OpenRouter model ID", "OpenRouter 모델 ID")
	key_label.text = _l("API key", "API 키")
	cancel_button.text = _l("Cancel", "취소")
	save_button.text = _l("Save AI settings", "AI 설정 저장")
	if model_selector != null and model_selector.item_count > 0:
		model_selector.set_item_text(
			model_selector.item_count - 1,
			_l("Custom OpenRouter model...", "OpenRouter 모델 직접 입력...")
		)

func open_centered() -> void:
	_finished_emitted = false
	theme = AppearanceSettingsScript.build_theme()
	if background_panel != null:
		background_panel.theme = theme
	load_fields()
	apply_language()
	popup_centered()

func load_fields() -> void:
	if model_selector == null or api_key_input == null or custom_model_input == null:
		return
	var settings := AISettings.load_settings()
	api_key_input.text = str(settings.get("api_key", ""))
	_select_route(str(settings.get("model", AISettings.DEFAULT_MODEL)))
	status_label.text = ""

func _select_route(route_value: String) -> void:
	var route := route_value.strip_edges()
	if route.is_empty():
		route = AISettings.DEFAULT_MODEL
	for index in range(model_selector.item_count):
		if str(model_selector.get_item_metadata(index)) == route:
			model_selector.select(index)
			custom_model_input.text = ""
			_update_selection()
			return
	if route.begins_with("openrouter::"):
		var custom_index := model_selector.item_count - 1
		model_selector.select(custom_index)
		custom_model_input.text = route.trim_prefix("openrouter::")
	else:
		model_selector.select(0)
		custom_model_input.text = ""
	_update_selection()

func _on_model_selected(_index: int) -> void:
	_update_selection()

func _update_selection() -> void:
	if model_selector == null or model_selector.item_count == 0:
		return
	var route := str(model_selector.get_item_metadata(model_selector.selected))
	custom_model_row.visible = route == "__custom_openrouter__"
	var selected_route := _selected_route()
	var provider := selected_route.get_slice("::", 0).to_lower()
	match provider:
		"anthropic": api_key_input.placeholder_text = "sk-ant-..."
		"google": api_key_input.placeholder_text = "AIza..."
		"openrouter": api_key_input.placeholder_text = "sk-or-v1-..."
		_: api_key_input.placeholder_text = "sk-..."

func _selected_route() -> String:
	if model_selector == null or model_selector.item_count == 0:
		return AISettings.DEFAULT_MODEL
	var route := str(model_selector.get_item_metadata(model_selector.selected)).strip_edges()
	if route == "__custom_openrouter__":
		var model_id := custom_model_input.text.strip_edges()
		if model_id.is_empty():
			model_id = "openrouter/free"
		return "openrouter::" + model_id
	if route.is_empty():
		return AISettings.DEFAULT_MODEL
	return route

func _save() -> void:
	var error := AISettings.save_settings(api_key_input.text, _selected_route())
	if error != OK:
		status_label.text = _l("Could not save AI settings.", "AI 설정을 저장하지 못했습니다.")
		return
	_finish(true)

func _cancel() -> void:
	_finish(false)

func _finish(saved: bool) -> void:
	if _finished_emitted:
		return
	_finished_emitted = true
	hide()
	finished.emit(saved)
