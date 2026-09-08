extends VBoxContainer
class_name CompanionMemoPanel

const MemoStoreScript = preload(
	"res://system/services/memo/memo_store.gd"
)
const AppLanguageScript = preload(
	"res://system/app/app_language.gd"
)
const AppearanceSettingsScript = preload(
	"res://system/app/appearance_settings.gd"
)

const AUTOSAVE_SECONDS: float = 0.6
const PIN_ASSET_PATH: String = "res://assets/ui/pin.svg"
const PIN_SVG: String = """<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><path fill="#ffffff" d="M5 1h6v1l-1 1v4l2 2v1H9v5H7v-5H4V9l2-2V3L5 2V1z"/></svg>"""

var memos: Array[Dictionary] = []
var current_index: int = -1
var applying_memo: bool = false
var title_label: Label = null
var subtitle_label: Label = null
var date_label: Label = null
var memo_list: ItemList = null
var memo_scroll: ScrollContainer = null
var memo_rows_box: VBoxContainer = null
var memo_row_panels: Array[PanelContainer] = []
var memo_title_buttons: Array[Button] = []
var memo_delete_buttons: Array[Button] = []
var pin_texture: Texture2D = null
var title_input: LineEdit = null
var body_edit: TextEdit = null
var new_button: Button = null
var delete_button: Button = null
var pin_button: Button = null
var save_timer: Timer = null
var delete_dialog: ConfirmationDialog = null

func _ready() -> void:
	add_theme_constant_override("separation", AppearanceSettingsScript.UI_STACK_GAP)
	_build_interface()
	memos = MemoStoreScript.load_memos()
	_refresh_list()
	_select_memo(0)
	apply_language()
	apply_appearance()

func _l(english: String, korean: String) -> String:
	return AppLanguageScript.text(english, korean)

func _build_interface() -> void:
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_LARGE)
	add_child(title_label)
	subtitle_label = Label.new()
	subtitle_label.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_SMALL)
	subtitle_label.remove_theme_color_override("font_color")
	add_child(subtitle_label)
	add_child(HSeparator.new())

	var split := HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 196
	add_child(split)

	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 184.0
	sidebar.add_theme_constant_override("separation", AppearanceSettingsScript.UI_COMPACT_GAP)
	split.add_child(sidebar)

	new_button = Button.new()
	new_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	new_button.custom_minimum_size.y = 40.0
	new_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_button.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_MEDIUM)
	new_button.pressed.connect(_on_new_pressed)
	sidebar.add_child(new_button)

	memo_list = ItemList.new()
	memo_list.visible = false
	memo_list.select_mode = ItemList.SELECT_SINGLE
	memo_list.item_selected.connect(_on_memo_selected)
	sidebar.add_child(memo_list)
	memo_scroll = ScrollContainer.new()
	memo_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	memo_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	memo_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	memo_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sidebar.add_child(memo_scroll)
	memo_rows_box = VBoxContainer.new()
	memo_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	memo_rows_box.add_theme_constant_override("separation", 4)
	memo_scroll.add_child(memo_rows_box)

	var editor := VBoxContainer.new()
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.add_theme_constant_override("separation", AppearanceSettingsScript.UI_COMPACT_GAP)
	split.add_child(editor)

	var title_row := HBoxContainer.new()
	title_input = LineEdit.new()
	title_input.max_length = 120
	title_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_input.text_changed.connect(_on_title_changed)
	title_row.add_child(title_input)
	pin_button = Button.new()
	pin_button.toggle_mode = true
	pin_button.toggled.connect(_on_pin_toggled)
	title_row.add_child(pin_button)
	editor.add_child(title_row)

	body_edit = TextEdit.new()
	body_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	body_edit.text_changed.connect(_on_body_changed)
	editor.add_child(body_edit)

	var utility_row := HBoxContainer.new()
	utility_row.add_theme_constant_override("separation", AppearanceSettingsScript.UI_COMPACT_GAP)
	editor.add_child(utility_row)
	date_label = Label.new()
	date_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	date_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	date_label.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_SMALL)
	utility_row.add_child(date_label)
	delete_button = Button.new()
	delete_button.add_theme_font_size_override("font_size", AppearanceSettingsScript.UI_FONT_SMALL)
	delete_button.pressed.connect(_on_delete_pressed)
	utility_row.add_child(delete_button)

	save_timer = Timer.new()
	save_timer.one_shot = true
	save_timer.wait_time = AUTOSAVE_SECONDS
	save_timer.timeout.connect(save_now)
	add_child(save_timer)

	delete_dialog = ConfirmationDialog.new()
	delete_dialog.confirmed.connect(_delete_current_memo)
	add_child(delete_dialog)

func apply_language() -> void:
	if title_label != null:
		title_label.text = _l("Memo", "메모")
	if subtitle_label != null:
		subtitle_label.text = _l("메모", "Memo")
	if new_button != null:
		new_button.text = _l("+ New memo", "+ 새 메모")
	if delete_button != null:
		delete_button.text = _l("Delete", "삭제")
	if pin_button != null:
		pin_button.text = _l("Pin to top", "맨 위 고정")
	if title_input != null:
		title_input.placeholder_text = _l("Memo title", "메모 제목")
	if body_edit != null:
		body_edit.placeholder_text = _l(
			"Write anything you want to keep here...",
			"기억해두고 싶은 걸 편하게 적어두세요..."
		)
	if delete_dialog != null:
		delete_dialog.title = _l("Delete memo", "메모 삭제")
		delete_dialog.dialog_text = _l(
			"Delete the selected memo?",
			"선택한 메모를 삭제할까요?"
		)
	if not memos.is_empty():
		_refresh_list()
	_refresh_date_label()

func apply_appearance() -> void:
	add_theme_constant_override("separation", AppearanceSettingsScript.UI_STACK_GAP)
	if new_button != null:
		_style_primary_button(new_button)
	if delete_button != null:
		_style_action_button(delete_button)
	if pin_button != null:
		_style_action_button(pin_button)
	if date_label != null:
		date_label.add_theme_color_override(
			"font_color", AppearanceSettingsScript.get_ui_color("muted")
		)
	if memo_list != null:
		memo_list.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	if not memos.is_empty():
		_rebuild_memo_rows()
	for button: Button in memo_title_buttons:
		if is_instance_valid(button):
			_style_row_button(button)
	for button: Button in memo_delete_buttons:
		if is_instance_valid(button):
			_style_row_button(button)

func _style_action_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.content_margin_left = 10.0
	normal.content_margin_right = 10.0
	normal.content_margin_top = 7.0
	normal.content_margin_bottom = 7.0
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = AppearanceSettingsScript.get_ui_color("surface_hover")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("hover_pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _style_primary_button(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = AppearanceSettingsScript.get_ui_color("selection")
	normal.corner_radius_top_left = 8
	normal.corner_radius_top_right = 8
	normal.corner_radius_bottom_left = 8
	normal.corner_radius_bottom_right = 8
	normal.content_margin_left = 12.0
	normal.content_margin_right = 12.0
	normal.content_margin_top = 8.0
	normal.content_margin_bottom = 8.0
	var hover: StyleBoxFlat = normal.duplicate()
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.add_theme_stylebox_override("hover_pressed", hover)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _style_row_button(button: Button) -> void:
	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	transparent.content_margin_left = 8.0
	transparent.content_margin_right = 8.0
	transparent.content_margin_top = 5.0
	transparent.content_margin_bottom = 5.0
	for style_name: String in ["normal", "hover", "pressed", "hover_pressed"]:
		button.add_theme_stylebox_override(style_name, transparent)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var text_color: Color = AppearanceSettingsScript.get_ui_color("text")
	for color_name: String in [
		"font_color", "font_hover_color", "font_pressed_color",
		"font_hover_pressed_color", "font_focus_color"
	]:
		button.add_theme_color_override(color_name, text_color)

func _make_row_fill(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style

func get_context(max_characters: int = 600) -> String:
	if body_edit == null:
		return ""
	var text: String = body_edit.text.strip_edges()
	if text.is_empty():
		return ""
	return text.left(maxi(1, max_characters)).strip_edges()

func save_now() -> void:
	if save_timer != null:
		save_timer.stop()
	_commit_current_fields()
	MemoStoreScript.save_memos(memos)

func _display_title(memo: Dictionary) -> String:
	var title: String = str(memo.get("title", "")).strip_edges()
	if title.is_empty():
		title = _l("Untitled memo", "제목 없는 메모")
	return title

func _refresh_list() -> void:
	if memo_list == null:
		return
	memo_list.clear()
	for memo: Dictionary in memos:
		memo_list.add_item(_display_title(memo))
	if current_index >= 0 and current_index < memo_list.item_count:
		memo_list.select(current_index)
	_rebuild_memo_rows()

func _rebuild_memo_rows() -> void:
	if memo_rows_box == null:
		return
	for child: Node in memo_rows_box.get_children():
		child.queue_free()
	memo_row_panels.clear()
	memo_title_buttons.clear()
	memo_delete_buttons.clear()
	for index: int in range(memos.size()):
		var memo: Dictionary = memos[index]
		var panel := PanelContainer.new()
		panel.custom_minimum_size.y = 40.0
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.set_meta("_selected", index == current_index)
		panel.mouse_entered.connect(_on_memo_row_hover.bind(index, true))
		panel.mouse_exited.connect(_on_memo_row_hover.bind(index, false))
		memo_rows_box.add_child(panel)
		memo_row_panels.append(panel)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		panel.add_child(row)
		if bool(memo.get("pinned", false)):
			var pin_icon := TextureRect.new()
			pin_icon.texture = _get_pin_texture()
			pin_icon.custom_minimum_size = Vector2(28, 16)
			pin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			pin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			pin_icon.modulate = AppearanceSettingsScript.get_ui_color("accent")
			pin_icon.tooltip_text = _l("Pinned to top", "맨 위에 고정됨")
			row.add_child(pin_icon)
		var title_button := Button.new()
		title_button.text = _display_title(memo)
		title_button.tooltip_text = title_button.text
		title_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_button.custom_minimum_size.y = 40.0
		title_button.focus_mode = Control.FOCUS_NONE
		_style_row_button(title_button)
		title_button.pressed.connect(_on_memo_row_pressed.bind(index))
		row.add_child(title_button)
		memo_title_buttons.append(title_button)
		var row_delete := Button.new()
		row_delete.text = "×"
		row_delete.tooltip_text = _l("Delete memo", "메모 삭제")
		row_delete.custom_minimum_size = Vector2(34, 40)
		row_delete.focus_mode = Control.FOCUS_NONE
		_style_row_button(row_delete)
		row_delete.pressed.connect(_on_memo_row_delete_pressed.bind(index))
		row.add_child(row_delete)
		memo_delete_buttons.append(row_delete)
		_set_memo_row_visual(index, false)

func _get_pin_texture() -> Texture2D:
	if pin_texture != null:
		return pin_texture
	if FileAccess.file_exists(PIN_ASSET_PATH + ".import"):
		var asset: Resource = load(PIN_ASSET_PATH)
		if asset is Texture2D:
			pin_texture = asset as Texture2D
			return pin_texture
	var image := Image.new()
	if image.load_svg_from_string(PIN_SVG) != OK:
		return null
	pin_texture = ImageTexture.create_from_image(image)
	return pin_texture

func _set_memo_row_visual(index: int, hovered: bool) -> void:
	if index < 0 or index >= memo_row_panels.size():
		return
	var panel: PanelContainer = memo_row_panels[index]
	var selected: bool = bool(panel.get_meta("_selected", false))
	var color := Color(0.0, 0.0, 0.0, 0.0)
	if hovered or selected:
		color = AppearanceSettingsScript.get_ui_color("surface_hover")
	panel.add_theme_stylebox_override("panel", _make_row_fill(color))

func _on_memo_row_hover(index: int, hovered: bool) -> void:
	_set_memo_row_visual(index, hovered)

func _on_memo_row_pressed(index: int) -> void:
	_select_memo(index)

func _on_memo_row_delete_pressed(index: int) -> void:
	_select_memo(index)
	_on_delete_pressed()

func _select_memo(index: int) -> void:
	if index < 0 or index >= memos.size():
		return
	if current_index >= 0:
		_commit_current_fields()
	current_index = index
	var memo: Dictionary = memos[index]
	applying_memo = true
	title_input.text = str(memo.get("title", ""))
	body_edit.text = str(memo.get("body", ""))
	pin_button.set_pressed_no_signal(bool(memo.get("pinned", false)))
	applying_memo = false
	memo_list.select(index)
	for row_index: int in range(memo_row_panels.size()):
		memo_row_panels[row_index].set_meta("_selected", row_index == index)
		_set_memo_row_visual(row_index, false)
	_refresh_date_label()
	body_edit.grab_focus()

func _commit_current_fields() -> void:
	if current_index < 0 or current_index >= memos.size():
		return
	var memo: Dictionary = memos[current_index]
	var new_title: String = title_input.text.strip_edges().left(120)
	var new_body: String = body_edit.text
	var new_pinned: bool = pin_button.button_pressed
	var changed := (
		str(memo.get("title", "")) != new_title
		or str(memo.get("body", "")) != new_body
		or bool(memo.get("pinned", false)) != new_pinned
	)
	memo["title"] = new_title
	memo["body"] = new_body
	memo["pinned"] = new_pinned
	if changed:
		memo["updated_at"] = int(Time.get_unix_time_from_system())
	memos[current_index] = memo

func _schedule_save() -> void:
	if applying_memo:
		return
	_commit_current_fields()
	if current_index >= 0 and current_index < memos.size():
		var shown_title: String = _display_title(memos[current_index])
		if memo_list != null and current_index < memo_list.item_count:
			memo_list.set_item_text(current_index, shown_title)
		if current_index < memo_title_buttons.size():
			memo_title_buttons[current_index].text = shown_title
			memo_title_buttons[current_index].tooltip_text = shown_title
	if save_timer != null:
		save_timer.start(AUTOSAVE_SECONDS)
	_refresh_date_label()

func _on_memo_selected(index: int) -> void:
	_select_memo(index)

func _on_title_changed(_text: String) -> void:
	_schedule_save()

func _on_body_changed() -> void:
	_schedule_save()

func _on_pin_toggled(_pressed: bool) -> void:
	if applying_memo or current_index < 0 or current_index >= memos.size():
		return
	_commit_current_fields()
	var selected_id: String = str(memos[current_index].get("id", ""))
	var pinned: Array[Dictionary] = []
	var unpinned: Array[Dictionary] = []
	for memo: Dictionary in memos:
		if bool(memo.get("pinned", false)):
			pinned.append(memo)
		else:
			unpinned.append(memo)
	memos = pinned + unpinned
	current_index = -1
	_refresh_list()
	for index: int in range(memos.size()):
		if str(memos[index].get("id", "")) == selected_id:
			_select_memo(index)
			break
	if save_timer != null:
		save_timer.start(AUTOSAVE_SECONDS)

func _on_new_pressed() -> void:
	save_now()
	var memo: Dictionary = MemoStoreScript.create_memo("", "")
	memos.push_front(memo)
	var new_id: String = str(memo.get("id", ""))
	var pinned: Array[Dictionary] = []
	var unpinned: Array[Dictionary] = []
	for value: Dictionary in memos:
		if bool(value.get("pinned", false)):
			pinned.append(value)
		else:
			unpinned.append(value)
	memos = pinned + unpinned
	current_index = -1
	_refresh_list()
	for index: int in range(memos.size()):
		if str(memos[index].get("id", "")) == new_id:
			_select_memo(index)
			break
	save_now()
	title_input.grab_focus()

func _on_delete_pressed() -> void:
	if delete_dialog != null and current_index >= 0:
		delete_dialog.popup_centered()

func _delete_current_memo() -> void:
	if current_index < 0 or current_index >= memos.size():
		return
	memos.remove_at(current_index)
	if memos.is_empty():
		memos.append(MemoStoreScript.create_memo("", ""))
	current_index = -1
	_refresh_list()
	_select_memo(0)
	save_now()

func _refresh_date_label() -> void:
	if date_label == null or current_index < 0 or current_index >= memos.size():
		return
	var timestamp: int = int(memos[current_index].get("updated_at", 0))
	if timestamp <= 0:
		date_label.text = ""
		return
	var date: Dictionary = Time.get_datetime_dict_from_unix_time(timestamp)
	date_label.text = "%04d-%02d-%02d %02d:%02d" % [
		int(date.get("year", 0)), int(date.get("month", 0)),
		int(date.get("day", 0)), int(date.get("hour", 0)),
		int(date.get("minute", 0))
	]
