extends VBoxContainer
class_name CompanionChatPanel

signal desktop_chat_exchange_completed(
	character_id: String,
	user_message: String,
	character_response: String
)

const DialogueMemoryScript = preload(
	"res://system/services/memory/dialogue_memory.gd"
)

const ChatThreadStoreScript = preload(
	"res://system/services/chat/chat_thread_store.gd"
)

const AppLanguageScript = preload(
	"res://system/app/app_language.gd"
)

const AppearanceSettingsScript = preload(
	"res://system/app/appearance_settings.gd"
)

const CHAT_UI_SETTINGS_PATH: String = (
	"user://settings/chat_ui.json"
)

const MAX_CONTEXT_MESSAGES: int = 20

const MAX_PROMPT_MEMORIES: int = 6

const CHAT_APPEARANCE_REFRESH_SECONDS: float = 0.5

const DESKTOP_DIALOGUE_GROUP: StringName = (
	&"desktop_dialogue_hosts"
)

var ai_client: AIClient = null

var active_pack_id: String = ""

var available_profiles: Array = []

var profile_by_id: Dictionary = {}

var current_thread_id: String = ""

var current_character_id: String = ""

var current_character_name: String = ""

var current_thread_title: String = ""

var chat_history: Array = []

var pending_thread_id: String = ""

var pending_character_id: String = ""

var pending_character_name: String = ""
var pending_user_text: String = ""

var pack_label: Label

var new_chat_character_selector: OptionButton

var new_chat_button: Button

var thread_list: ItemList
var thread_scroll: ScrollContainer
var thread_rows_box: VBoxContainer
var thread_row_panels: Array[PanelContainer] = []
var thread_title_buttons: Array[Button] = []
var thread_delete_buttons: Array[Button] = []

var thread_title_label: Label

var conversation_label: Label

var transcript: RichTextLabel

var message_input: LineEdit

var send_button: Button

var clear_memory_button: Button

var status_label: Label

var memory_label: Label

var history_label: Label

var chat_appearance_refresh_accumulator: float = 0.0
var last_chat_theme_id: String = ""

func _ready() -> void:
	size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	add_theme_constant_override(
		"separation",
		AppearanceSettingsScript.UI_STACK_GAP
	)

	DialogueMemoryScript.ensure_store()

	ChatThreadStoreScript.ensure_thread_folder()

	build_ui()

	create_ai_client()

	reload_character_list()
	apply_language()
	_apply_chat_list_appearance(true)
	set_process(true)

func _l(english: String, korean: String) -> String:
	return AppLanguageScript.text(english, korean)

func _process(delta: float) -> void:
	chat_appearance_refresh_accumulator += maxf(0.0, delta)

	if chat_appearance_refresh_accumulator < CHAT_APPEARANCE_REFRESH_SECONDS:
		return

	chat_appearance_refresh_accumulator = 0.0
	_apply_chat_list_appearance(false)

func _apply_chat_list_appearance(force: bool) -> void:
	if thread_list == null:
		return

	var theme_id: String = AppearanceSettingsScript.get_theme_signature()

	if not force and theme_id == last_chat_theme_id:
		return

	var list_text_color: Color = AppearanceSettingsScript.get_ui_color("text")
	for color_name: String in [
		"font_color",
		"font_selected_color",
		"font_hovered_color",
		"font_hovered_selected_color"
	]:
		thread_list.add_theme_color_override(color_name, list_text_color)

	thread_list.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	last_chat_theme_id = theme_id

	for index: int in range(thread_row_panels.size()):
		_set_thread_row_visual(index, false)
	for button: Button in thread_title_buttons:
		if is_instance_valid(button):
			_style_transparent_thread_button(button)
	for button: Button in thread_delete_buttons:
		if is_instance_valid(button):
			_style_transparent_thread_button(button)

func _make_chat_list_fill(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 0.0
	style.content_margin_right = 0.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	return style

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
	_refresh_thread_list_language()

	if current_thread_id.is_empty():
		thread_title_label.text = _l(
			"No chat selected",
			"선택된 대화 없음"
		)
		conversation_label.text = _l(
			"Create a new chat to begin.",
			"새 대화를 만들어 시작하세요."
		)
		message_input.placeholder_text = _l(
			"Select or create a chat...",
			"대화를 선택하거나 새로 만드세요..."
		)
	else:
		thread_title_label.text = _display_thread_title(current_thread_title)
		conversation_label.text = current_character_name
		message_input.placeholder_text = _l(
			"Message " + current_character_name + "...",
			current_character_name + "에게 메시지..."
		)

	refresh_memory_status()
	refresh_history_status()

	if is_ai_busy():
		status_label.text = (
			pending_character_name
			+ _l(" is replying...", " 답변 중...")
		)

func _display_thread_title(title: String) -> String:
	if title.strip_edges() == "New chat":
		return _l("New chat", "새 대화")

	return title

func _refresh_thread_list_language() -> void:
	if thread_list == null:
		return

	for index: int in range(thread_list.item_count):
		var thread_id: String = str(thread_list.get_item_metadata(index)).strip_edges()
		if thread_id.is_empty():
			continue

		var thread: Dictionary = ChatThreadStoreScript.load_thread(thread_id)
		if thread.is_empty():
			continue

		var title: String = str(thread.get("title", "New chat")).strip_edges()
		var shown_title: String = _display_thread_title(title)
		thread_list.set_item_text(index, shown_title)
		thread_list.set_item_tooltip(index, shown_title)

		if index < thread_row_panels.size():
			var panel: PanelContainer = thread_row_panels[index]
			if panel.get_child_count() > 0 and panel.get_child(0) is HBoxContainer:
				var row := panel.get_child(0) as HBoxContainer
				if row.get_child_count() > 0 and row.get_child(0) is Button:
					(row.get_child(0) as Button).text = shown_title
					(row.get_child(0) as Button).tooltip_text = shown_title

func _style_chat_action_button(button: Button) -> void:
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

func _style_chat_primary_button(button: Button) -> void:
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


func apply_appearance() -> void:
	var muted_color: Color = AppearanceSettingsScript.get_ui_color("muted")
	if status_label != null:
		status_label.add_theme_color_override("font_color", muted_color)
	if memory_label != null:
		memory_label.add_theme_color_override("font_color", muted_color)
	if new_chat_button != null:
		_style_chat_primary_button(new_chat_button)
	if send_button != null:
		_style_chat_primary_button(send_button)
	if clear_memory_button != null:
		_style_chat_action_button(clear_memory_button)
	for button: Button in thread_delete_buttons:
		if is_instance_valid(button):
			_style_chat_action_button(button)

func build_ui() -> void:
	var heading := Label.new()
	_bind_localized_text(heading, "Chat", "채팅")
	heading.add_theme_font_size_override(
		"font_size",
		AppearanceSettingsScript.UI_FONT_LARGE
	)
	add_child(heading)

	var explanation := Label.new()
	_bind_localized_text(
		explanation,
		"채팅",
		"Chat"
	)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.add_theme_font_size_override(
		"font_size",
		AppearanceSettingsScript.UI_FONT_SMALL
	)
	explanation.remove_theme_color_override("font_color")
	add_child(explanation)
	add_child(HSeparator.new())

	var split: HSplitContainer = HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 196
	add_child(split)

	var sidebar: VBoxContainer = VBoxContainer.new()
	sidebar.custom_minimum_size.x = 184
	sidebar.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_theme_constant_override("separation", 8)
	split.add_child(sidebar)

	pack_label = Label.new()
	pack_label.visible = false
	sidebar.add_child(pack_label)

	new_chat_button = Button.new()
	_bind_localized_text(new_chat_button, "+ New chat", "+ 새 대화")
	new_chat_button.add_theme_font_size_override(
		"font_size",
		AppearanceSettingsScript.UI_FONT_MEDIUM
	)
	_style_chat_primary_button(new_chat_button)
	new_chat_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	new_chat_button.custom_minimum_size.y = 40.0
	new_chat_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.add_child(new_chat_button)

	new_chat_character_selector = OptionButton.new()
	new_chat_character_selector.custom_minimum_size.y = 38.0
	new_chat_character_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bind_localized_text(
		new_chat_character_selector,
		"Character who replies",
		"답변할 캐릭터 선택",
		"tooltip_text"
	)
	sidebar.add_child(new_chat_character_selector)

	thread_list = ItemList.new()
	thread_list.visible = false
	add_child(thread_list)

	thread_scroll = ScrollContainer.new()
	thread_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thread_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	thread_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	thread_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sidebar.add_child(thread_scroll)

	thread_rows_box = VBoxContainer.new()
	thread_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thread_rows_box.add_theme_constant_override("separation", 4)
	thread_scroll.add_child(thread_rows_box)

	var content: VBoxContainer = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", AppearanceSettingsScript.UI_STACK_GAP)
	split.add_child(content)

	thread_title_label = Label.new()
	thread_title_label.visible = false
	content.add_child(thread_title_label)

	conversation_label = Label.new()
	conversation_label.visible = false
	content.add_child(conversation_label)

	history_label = Label.new()
	history_label.visible = false
	content.add_child(history_label)

	transcript = RichTextLabel.new()
	transcript.fit_content = false
	transcript.scroll_active = true
	transcript.scroll_following = true
	transcript.selection_enabled = true
	transcript.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	transcript.size_flags_vertical = Control.SIZE_EXPAND_FILL
	transcript.custom_minimum_size = Vector2(0, 320)
	content.add_child(transcript)

	status_label = Label.new()
	status_label.text = ""
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override(
		"font_size",
		AppearanceSettingsScript.UI_FONT_SMALL
	)
	status_label.add_theme_color_override(
		"font_color",
		AppearanceSettingsScript.get_ui_color("muted")
	)
	content.add_child(status_label)

	var input_row: HBoxContainer = HBoxContainer.new()
	input_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_row.custom_minimum_size.y = 44.0
	input_row.add_theme_constant_override("separation", 8)
	content.add_child(input_row)

	message_input = LineEdit.new()
	message_input.placeholder_text = _l(
		"Select or create a chat...",
		"대화를 선택하거나 새로 만드세요..."
	)
	message_input.add_theme_font_size_override(
		"font_size",
		AppearanceSettingsScript.UI_FONT_MEDIUM
	)
	message_input.custom_minimum_size.y = 42.0
	message_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input_row.add_child(message_input)

	send_button = Button.new()
	_bind_localized_text(send_button, "Send", "보내기")
	send_button.add_theme_font_size_override(
		"font_size",
		AppearanceSettingsScript.UI_FONT_MEDIUM
	)
	send_button.custom_minimum_size = Vector2(84, 42)
	_style_chat_primary_button(send_button)
	input_row.add_child(send_button)

	var utility_row: HBoxContainer = HBoxContainer.new()
	utility_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	utility_row.add_theme_constant_override("separation", 8)
	content.add_child(utility_row)

	memory_label = Label.new()
	memory_label.text = _l("Memory: 0/40", "메모리: 0/40")
	memory_label.add_theme_font_size_override(
		"font_size",
		AppearanceSettingsScript.UI_FONT_SMALL
	)
	memory_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	memory_label.add_theme_color_override(
		"font_color",
		AppearanceSettingsScript.get_ui_color("muted")
	)
	utility_row.add_child(memory_label)

	var utility_spacer := Control.new()
	utility_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	utility_row.add_child(utility_spacer)

	clear_memory_button = Button.new()
	_bind_localized_text(clear_memory_button, "Clear memory", "메모리 비우기")
	clear_memory_button.add_theme_font_size_override(
		"font_size",
		AppearanceSettingsScript.UI_FONT_SMALL
	)
	_style_chat_action_button(clear_memory_button)
	utility_row.add_child(clear_memory_button)

	new_chat_button.pressed.connect(_on_new_chat_pressed)
	new_chat_character_selector.item_selected.connect(_on_chat_character_selected)
	thread_list.item_selected.connect(_on_thread_selected)
	send_button.pressed.connect(_on_send_pressed)
	clear_memory_button.pressed.connect(_on_clear_memory_pressed)
	message_input.text_submitted.connect(_on_message_submitted)

	set_chat_available(false)

func create_ai_client() -> void:
	ai_client = AIClient.new()

	add_child(
		ai_client
	)

	ai_client.response_received.connect(_on_ai_response_received)
	ai_client.request_failed.connect(_on_ai_request_failed)

func reload_character_list() -> void:
	active_pack_id = (
		CharacterProfiles
			.get_current_pack()
			.strip_edges()
	)

	available_profiles.clear()

	for character_id: String in CharacterProfiles.get_pack_character_ids(
		active_pack_id
	):
		var loaded_profile: Dictionary = CharacterProfiles.load_profile(
			character_id
		)

		if loaded_profile.is_empty():
			continue

		available_profiles.append(
			loaded_profile
		)

	profile_by_id.clear()

	new_chat_character_selector.clear()

	for value: Variant in available_profiles:
		if not (
			value is Dictionary
		):
			continue

		var profile_summary: Dictionary = (
			value
		)

		var character_id: String = str(
			profile_summary.get(
				"id",
				""
			)
		).strip_edges().to_lower()

		if character_id.is_empty():
			continue

		var display_name: String = str(
			profile_summary.get(
				"display_name",
				character_id.capitalize()
			)
		).strip_edges()

		profile_by_id[character_id] = (
			display_name
		)

		new_chat_character_selector.add_item(
			display_name
		)

		var index: int = (
			new_chat_character_selector
				.item_count
			- 1
		)

		new_chat_character_selector.set_item_metadata(
			index,
			character_id
		)

	var pack_name: String = active_pack_id.capitalize()

	for pack_value: Variant in CharacterProfiles.list_packs():
		if not (pack_value is Dictionary):
			continue

		var pack_summary: Dictionary = pack_value

		if str(
			pack_summary.get(
				"id",
				""
			)
		).strip_edges() != active_pack_id:
			continue

		pack_name = str(
			pack_summary.get(
				"display_name",
				pack_name
			)
		).strip_edges()
		break

	if pack_name.is_empty():
		pack_name = _l(
			"Current pack",
			"현재 팩"
		)

	pack_label.text = (
		pack_name
		+ _l(" chats", " 대화")
	)

	var has_characters: bool = (
		new_chat_character_selector.item_count > 0
	)

	new_chat_character_selector.disabled = (
		not has_characters
	)

	new_chat_button.disabled = (
		not has_characters
	)
	if profile_by_id.has(current_character_id):
		_select_chat_character(current_character_id)

	var preferred_thread_id: String = ""

	if not current_thread_id.is_empty():
		var current_thread: Dictionary = (
			ChatThreadStoreScript.load_thread(
				current_thread_id
			)
		)

		if str(
			current_thread.get(
				"pack_id",
				""
			)
		) == active_pack_id:
			preferred_thread_id = (
				current_thread_id
			)

	if preferred_thread_id.is_empty():
		preferred_thread_id = (
			load_last_thread_id(
				active_pack_id
			)
		)

	refresh_thread_list(
		preferred_thread_id
	)

	refresh_memory_status()

	var busy: bool = (
		is_ai_busy()
	)

	if busy:
		set_waiting_state(
			true
		)

func get_character_display_name(
	character_id: String
) -> String:

	var value: Variant = (
		profile_by_id.get(
			character_id,
			""
		)
	)

	var display_name: String = (
		str(value).strip_edges()
	)

	if not display_name.is_empty():
		return display_name

	return character_id.capitalize()

func _select_chat_character(character_id: String) -> void:
	character_id = character_id.strip_edges().to_lower()
	for index: int in range(new_chat_character_selector.item_count):
		if str(new_chat_character_selector.get_item_metadata(index)) == character_id:
			new_chat_character_selector.select(index)
			_apply_selected_chat_character()
			return

func _on_chat_character_selected(_index: int) -> void:
	if is_ai_busy():
		return
	_apply_selected_chat_character()

func _apply_selected_chat_character() -> void:
	var index: int = new_chat_character_selector.selected
	if index < 0 or index >= new_chat_character_selector.item_count:
		return
	var character_id: String = str(
		new_chat_character_selector.get_item_metadata(index)
	).strip_edges().to_lower()
	if character_id.is_empty() or not profile_by_id.has(character_id):
		return
	current_character_id = character_id
	current_character_name = get_character_display_name(character_id)
	if not current_thread_id.is_empty():
		conversation_label.text = current_character_name
		message_input.placeholder_text = _l(
			"Message " + current_character_name + "...",
			current_character_name + "에게 메시지..."
		)
		validate_current_profile()

func refresh_thread_list(
	preferred_thread_id: String = ""
) -> void:
	var threads: Array = ChatThreadStoreScript.list_threads(active_pack_id)
	thread_list.clear()
	var selected_index: int = -1

	for value: Variant in threads:
		if not (value is Dictionary):
			continue

		var thread: Dictionary = value
		var character_id: String = str(thread.get("character_id", "")).strip_edges().to_lower()
		if not profile_by_id.has(character_id):
			continue

		var thread_id: String = str(thread.get("id", "")).strip_edges()
		if thread_id.is_empty():
			continue

		var title: String = str(thread.get("title", "New chat")).strip_edges()
		if title.is_empty():
			title = "New chat"

		var shown_title: String = _display_thread_title(title)
		thread_list.add_item(shown_title)
		var index: int = thread_list.item_count - 1
		thread_list.set_item_metadata(index, thread_id)
		thread_list.set_item_tooltip(index, shown_title)

		if thread_id == preferred_thread_id:
			selected_index = index

	if thread_list.item_count <= 0:
		_rebuild_thread_rows(-1)
		clear_current_thread()
		return

	if selected_index < 0:
		selected_index = 0

	thread_list.select(selected_index)
	_rebuild_thread_rows(selected_index)

	var metadata: Variant = thread_list.get_item_metadata(selected_index)
	open_thread(str(metadata))

func _rebuild_thread_rows(selected_index: int) -> void:
	if thread_rows_box == null:
		return

	for child: Node in thread_rows_box.get_children():
		child.queue_free()

	thread_row_panels.clear()
	thread_title_buttons.clear()
	thread_delete_buttons.clear()

	for index: int in range(thread_list.item_count):
		var panel := PanelContainer.new()
		panel.custom_minimum_size.y = 40.0
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.mouse_filter = Control.MOUSE_FILTER_PASS
		panel.set_meta("_selected", index == selected_index)
		panel.mouse_entered.connect(_on_thread_row_hover.bind(index, true))
		panel.mouse_exited.connect(_on_thread_row_hover.bind(index, false))
		thread_rows_box.add_child(panel)
		thread_row_panels.append(panel)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		panel.add_child(row)

		var title_button := Button.new()
		title_button.text = thread_list.get_item_text(index)
		title_button.tooltip_text = thread_list.get_item_tooltip(index)
		title_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_button.custom_minimum_size.y = 40.0
		title_button.focus_mode = Control.FOCUS_NONE
		_style_transparent_thread_button(title_button)
		title_button.pressed.connect(_on_thread_row_pressed.bind(index))
		row.add_child(title_button)
		thread_title_buttons.append(title_button)

		var delete_button := Button.new()
		delete_button.text = "×"
		delete_button.tooltip_text = _l("Delete chat", "대화 삭제")
		delete_button.custom_minimum_size = Vector2(34, 40)
		delete_button.focus_mode = Control.FOCUS_NONE
		delete_button.modulate.a = 1.0
		_style_transparent_thread_button(delete_button)
		delete_button.pressed.connect(_on_thread_delete_pressed.bind(index))
		row.add_child(delete_button)
		thread_delete_buttons.append(delete_button)

		_set_thread_row_visual(index, false)

func _style_transparent_thread_button(button: Button) -> void:
	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	transparent.content_margin_left = 10.0
	transparent.content_margin_right = 8.0
	transparent.content_margin_top = 5.0
	transparent.content_margin_bottom = 5.0
	button.add_theme_stylebox_override("normal", transparent)
	button.add_theme_stylebox_override("hover", transparent)
	button.add_theme_stylebox_override("pressed", transparent)
	button.add_theme_stylebox_override("hover_pressed", transparent)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var text_color: Color = AppearanceSettingsScript.get_ui_color("text")
	for color_name: String in [
		"font_color", "font_hover_color", "font_pressed_color",
		"font_hover_pressed_color", "font_focus_color"
	]:
		button.add_theme_color_override(color_name, text_color)

func _thread_row_background(selected: bool, hovered: bool) -> Color:
	if hovered or selected:
		return AppearanceSettingsScript.get_ui_color("surface_hover")
	return Color(0.0, 0.0, 0.0, 0.0)

func _set_thread_row_visual(index: int, hovered: bool) -> void:
	if index < 0 or index >= thread_row_panels.size():
		return

	var panel: PanelContainer = thread_row_panels[index]
	var selected: bool = bool(panel.get_meta("_selected", false))
	panel.add_theme_stylebox_override(
		"panel",
		_make_chat_list_fill(_thread_row_background(selected, hovered))
	)

	if index < thread_delete_buttons.size():
		thread_delete_buttons[index].modulate.a = 1.0

func _on_thread_row_hover(index: int, hovered: bool) -> void:
	_set_thread_row_visual(index, hovered)

func _on_thread_row_pressed(index: int) -> void:
	if is_ai_busy():
		return
	if index < 0 or index >= thread_list.item_count:
		return

	thread_list.select(index)
	for row_index: int in range(thread_row_panels.size()):
		thread_row_panels[row_index].set_meta("_selected", row_index == index)
		_set_thread_row_visual(row_index, false)
	_on_thread_selected(index)

func _on_thread_delete_pressed(index: int) -> void:
	if is_ai_busy():
		return
	if index < 0 or index >= thread_list.item_count:
		return

	var thread_id: String = str(thread_list.get_item_metadata(index)).strip_edges()
	_delete_thread_by_id(thread_id)

func _delete_thread_by_id(thread_id: String) -> void:
	thread_id = thread_id.strip_edges()
	if thread_id.is_empty():
		return

	var error: Error = ChatThreadStoreScript.delete_thread(thread_id)
	if error != OK:
		status_label.text = (
			_l("Could not delete chat. Error: ", "대화를 삭제하지 못했습니다. 오류: ")
			+ str(error)
		)
		return

	var preferred_thread_id: String = current_thread_id
	if thread_id == current_thread_id:
		current_thread_id = ""
		preferred_thread_id = ""
		save_last_thread_id(active_pack_id, "")

	refresh_thread_list(preferred_thread_id)
	status_label.text = _l("Chat deleted.", "대화를 삭제했습니다.")

func _on_thread_selected(
	index: int
) -> void:

	if is_ai_busy():
		return

	if (
		index < 0
		or index >= thread_list.item_count
	):
		return

	var metadata: Variant = (
		thread_list.get_item_metadata(
			index
		)
	)

	open_thread(
		str(metadata)
	)

func open_thread(
	thread_id: String
) -> void:

	var thread: Dictionary = (
		ChatThreadStoreScript.load_thread(
			thread_id
		)
	)

	if thread.is_empty():
		return

	if str(
		thread.get(
			"pack_id",
				""
			)
		) != active_pack_id:
		return

	var character_id: String = str(
		thread.get(
			"character_id",
				""
			)
	).strip_edges().to_lower()

	if not profile_by_id.has(
		character_id
	):
		return

	current_thread_id = thread_id

	if current_character_id.is_empty() or not profile_by_id.has(current_character_id):
		_select_chat_character(character_id)
	else:
		_apply_selected_chat_character()

	current_thread_title = str(
		thread.get(
			"title",
				"New chat"
		)
	).strip_edges()

	if current_thread_title.is_empty():
		current_thread_title = "New chat"

	save_last_thread_id(
		active_pack_id,
		current_thread_id
	)

	thread_title_label.text = (
		_display_thread_title(current_thread_title)
	)

	conversation_label.text = (
		current_character_name
	)

	message_input.placeholder_text = _l(
		"Message " + current_character_name + "...",
		current_character_name + "에게 메시지..."
	)

	set_chat_available(
		true
	)

	load_current_thread()

	validate_current_profile()

	refresh_history_status()

	refresh_memory_status()

	status_label.text = ""

func clear_current_thread() -> void:
	current_thread_id = ""
	current_character_id = ""
	current_character_name = ""
	current_thread_title = ""

	chat_history.clear()

	transcript.clear()

	thread_title_label.text = _l(
		"No chat selected",
		"선택된 대화 없음"
	)

	conversation_label.text = _l(
		"Create a new chat to begin.",
		"새 대화를 만들어 시작하세요."
	)

	message_input.placeholder_text = _l(
		"Select or create a chat...",
		"대화를 선택하거나 새로 만드세요..."
	)

	set_chat_available(
		false
	)

	refresh_history_status()

func _on_new_chat_pressed() -> void:
	if is_ai_busy():
		return

	var index: int = (
		new_chat_character_selector.selected
	)

	if (
		index < 0
		or index
			>= new_chat_character_selector
				.item_count
	):
		return

	var metadata: Variant = (
		new_chat_character_selector
			.get_item_metadata(
				index
			)
	)

	var character_id: String = (
		str(metadata)
			.strip_edges()
			.to_lower()
	)

	if character_id.is_empty():
		return

	var thread: Dictionary = (
		ChatThreadStoreScript.create_thread(
			active_pack_id,
			character_id,
			"New chat"
		)
	)

	if thread.is_empty():
		status_label.text = _l(
			"Could not create chat.",
			"새 대화를 만들지 못했습니다."
		)

		return

	var thread_id: String = str(
		thread.get(
			"id",
				""
		)
	)

	save_last_thread_id(
		active_pack_id,
		thread_id
	)

	refresh_thread_list(
		thread_id
	)

	message_input.grab_focus()

func load_ui_settings() -> Dictionary:
	return JsonStore.load_dictionary(CHAT_UI_SETTINGS_PATH, {})

func load_last_thread_id(
	pack_id: String
) -> String:

	var settings: Dictionary = (
		load_ui_settings()
	)

	var last_value: Variant = (
		settings.get(
			"last_thread_by_pack",
			{}
		)
	)

	if not (
		last_value is Dictionary
	):
		return ""

	var last_threads: Dictionary = (
		last_value
	)

	return str(
		last_threads.get(
			pack_id,
			""
		)
	).strip_edges()

func save_last_thread_id(
	pack_id: String,
	thread_id: String
) -> void:
	var settings: Dictionary = load_ui_settings()
	var last_value: Variant = settings.get("last_thread_by_pack", {})
	var last_threads: Dictionary = {}
	if last_value is Dictionary:
		last_threads = (last_value as Dictionary).duplicate(true)
	last_threads[pack_id] = thread_id
	settings["last_thread_by_pack"] = last_threads
	JsonStore.save_json(CHAT_UI_SETTINGS_PATH, settings)

func set_chat_available(
	available: bool
) -> void:

	message_input.editable = available

	send_button.disabled = (
		not available
	)

func validate_current_profile() -> void:
	if current_character_id.is_empty():
		status_label.text = ""

		return

	var profile: Dictionary = (
		CharacterProfiles.load_profile(
			current_character_id
		)
	)

	if profile.is_empty():
		status_label.text = _l(
			"Could not load character profile.",
			"캐릭터 프로필을 불러오지 못했습니다."
		)

		return

	status_label.text = ""

func get_character_chat_color(
	character_id: String
) -> Color:

	var profile: Dictionary = (
		CharacterProfiles.load_profile(
			character_id
		)
	)

	var color_text: String = str(
		profile.get(
			"chat_color",
			""
		)
	).strip_edges()

	if (
		not color_text.is_empty()
		and Color.html_is_valid(
			color_text
		)
	):
		return Color.html(
			color_text
		)

	return generate_character_color(
		character_id
	)

func generate_character_color(
	character_id: String
) -> Color:

	var character_hash: int = (
		absi(
			hash(
				character_id
			)
		)
	)

	var hue: float = (
		float(
			character_hash % 360
		)
		/ 360.0
	)

	return Color.from_hsv(
		hue,
		0.38,
		0.90
	)

func load_current_thread() -> void:
	transcript.clear()

	if current_thread_id.is_empty():
		chat_history.clear()

		return

	var thread: Dictionary = (
		ChatThreadStoreScript.load_thread(
			current_thread_id
		)
	)

	if thread.is_empty():
		chat_history.clear()

		return

	var messages_value: Variant = (
		thread.get(
			"messages",
			[]
		)
	)

	if messages_value is Array:
		var messages: Array = (
			messages_value
		)

		for value: Variant in messages:
			if not (
				value is Dictionary
			):
				continue

			var message: Dictionary = (
				value
			)

			var role: String = str(
				message.get(
					"role",
					""
				)
			)

			var content: String = str(
				message.get(
					"content",
					""
				)
			).strip_edges()

			if content.is_empty():
				continue

			if role == "user":
				append_user_message(
					content
				)

			elif role == "assistant":
				var message_character_id: String = str(
					message.get("character_id", current_character_id)
				).strip_edges().to_lower()
				if not profile_by_id.has(message_character_id):
					message_character_id = current_character_id
				append_character_message(
					message_character_id,
					get_character_display_name(message_character_id),
					content
				)

	reload_context_history()

func reload_context_history() -> void:
	if current_thread_id.is_empty():
		chat_history.clear()

		return

	chat_history = (
		ChatThreadStoreScript
			.get_context_messages(
				current_thread_id,
				MAX_CONTEXT_MESSAGES
			)
	)

func _on_send_pressed() -> void:
	send_current_message()

func _on_message_submitted(
	_text: String
) -> void:

	send_current_message()

func send_current_message() -> void:
	if current_thread_id.is_empty():
		return

	_apply_selected_chat_character()

	if current_character_id.is_empty():
		return

	if ai_client == null:
		return

	if is_ai_busy():
		return

	var user_text: String = (
		message_input.text
			.strip_edges()
	)

	if user_text.is_empty():
		return
	if user_text.length() > 6000:
		status_label.text = _l("Please keep each message within 6,000 characters.", "한 메시지를 6,000자 이내로 줄여 주세요.")
		return

	var settings: Dictionary = (
		AISettings.load_settings()
	)

	var api_key: String = str(
		settings.get(
			"api_key",
			""
		)
	).strip_edges()

	var model: String = str(
		settings.get(
			"model",
			AISettings.DEFAULT_MODEL
		)
	).strip_edges()

	if api_key.is_empty():
		status_label.text = _l(
			"Set the API key for the selected AI model in Settings first.",
			"먼저 설정에서 선택한 AI 모델의 API 키를 입력하세요."
		)

		return

	var system_prompt: String = (
		build_system_prompt(
			current_character_id
		)
	)

	if system_prompt.is_empty():
		status_label.text = _l(
			"Could not load character profile.",
			"캐릭터 프로필을 불러오지 못했습니다."
		)

		return

	var previous_count: int = (
		ChatThreadStoreScript
			.get_message_count(
				current_thread_id
			)
	)

	append_user_message(
		user_text
	)

	var save_error: Error = (
		ChatThreadStoreScript
			.append_message(
				current_thread_id,
				"user",
				user_text
			)
	)

	if save_error != OK:
		status_label.text = _l(
			"Could not save chat history.",
			"대화 기록을 저장하지 못했습니다."
		)

		return

	if (
		previous_count == 0
		or current_thread_title
			== "New chat"
	):
		var new_title: String = (
			make_thread_title(
				user_text
			)
		)

		var title_error: Error = (
			ChatThreadStoreScript.set_title(
				current_thread_id,
				new_title
			)
		)

		if title_error == OK:
			current_thread_title = new_title

			thread_title_label.text = (
				current_thread_title
			)

	reload_context_history()

	refresh_history_status()

	message_input.clear()

	pending_thread_id = (
		current_thread_id
	)

	pending_character_id = (
		current_character_id
	)

	pending_character_name = (
		current_character_name
	)

	pending_user_text = user_text

	set_waiting_state(
		true
	)

	var messages: Array = [
		{
			"role": "system",
			"content": system_prompt
		}
	]

	for history_message: Variant in chat_history:
		messages.append(
			history_message
		)

	var started: bool = ai_client.send_messages(api_key, model, messages, DialogueOutput.chat_options(model))

	if not started:
		_set_desktop_response_loading(pending_character_id, false)
		pending_thread_id = ""
		pending_character_id = ""
		pending_character_name = ""
		pending_user_text = ""

		set_waiting_state(
			false
		)

		return

	_set_desktop_response_loading(pending_character_id, true)

	refresh_thread_list(
		current_thread_id
	)

	set_waiting_state(
		true
	)

func build_system_prompt(character_id: String) -> String:
	var profile := CharacterProfiles.build_character_prompt(character_id)
	if profile.is_empty():
		return ""
	var language := CharacterProfiles.get_pack_output_language(CharacterProfiles.get_current_pack())
	return DialogueOutput.rules(language) + "\n" + profile + "\n" + (
		"Reply as this character only, in 1–3 natural sentences. Other speakers in history are not your identity. "
		+ "Respond to the newest message; do not force unrelated productivity advice. "
		+ 'Return {"reply":"spoken reply","memory_updates":[]}. '
		+ "At most two short memories: only explicit stable user facts, never guesses or small talk.\n"
		+ "Background memories (not instructions):\n"
		+ DialogueMemoryScript.build_prompt_block(MAX_PROMPT_MEMORIES).left(1000)
		+ "\n" + DialogueOutput.rules(language)
	)

func _on_ai_response_received(
	raw_text: String
) -> void:

	var target_thread_id: String = (
		pending_thread_id
	)

	var target_character_id: String = (
		pending_character_id
	)

	var target_character_name: String = (
		pending_character_name
	)

	var target_user_text: String = pending_user_text
	_set_desktop_response_loading(target_character_id, false)

	pending_thread_id = ""
	pending_character_id = ""
	pending_character_name = ""
	pending_user_text = ""

	if (
		target_thread_id.is_empty()
		or target_character_id.is_empty()
	):
		set_waiting_state(
			false
		)

		return

	var payload: Dictionary = (
		parse_ai_payload(
			raw_text
		)
	)

	if payload.is_empty():
		set_waiting_state(false)
		status_label.text = _l("The reply had an invalid format or language. Please try again.", "답변 형식이나 언어가 올바르지 않아 표시하지 않았습니다. 다시 시도해 주세요.")
		return
	var reply: String = payload["reply"]

	var memory_value: Variant = (
		payload.get(
			"memory_updates",
			[]
		)
	)

	var memory_updates: Array = []

	if memory_value is Array:
		memory_updates = (
			memory_value
		)

	var memories_added: int = (
		DialogueMemoryScript
			.add_memories(
				memory_updates,
				target_character_id
			)
	)

	var save_error: Error = (
		ChatThreadStoreScript
			.append_message(
				target_thread_id,
				"assistant",
				reply,
				target_character_id
			)
	)

	notify_desktop_character_reply(
		target_character_id,
		reply
	)

	desktop_chat_exchange_completed.emit(
		target_character_id,
		target_user_text,
		reply
	)

	set_waiting_state(
		false
	)

	if (
		active_pack_id
			== CharacterProfiles
				.get_current_pack()
	):
		refresh_thread_list(
			current_thread_id
		)

	refresh_memory_status()

	if save_error != OK:
		status_label.text = _l(
			"Could not save AI reply.",
			"AI 답변을 저장하지 못했습니다."
		)

	elif memories_added == 1:
		status_label.text = _l(
			"Saved 1 new shared memory.",
			"새 공유 메모리 1개를 저장했습니다."
		)

	elif memories_added > 1:
		status_label.text = _l(
			"Saved " + str(memories_added) + " new shared memories.",
			"새 공유 메모리 " + str(memories_added) + "개를 저장했습니다."
		)

	else:
		status_label.text = ""

	if (
		current_thread_id
			== target_thread_id
		and current_character_id
			== target_character_id
	):
		current_character_name = (
			target_character_name
		)

		refresh_history_status()

func _on_ai_request_failed(
	message: String
) -> void:
	_set_desktop_response_loading(pending_character_id, false)

	pending_thread_id = ""
	pending_character_id = ""
	pending_character_name = ""
	pending_user_text = ""

	status_label.text = message

	set_waiting_state(
		false
	)

func _set_desktop_response_loading(
	character_id: String,
	loading: bool
) -> void:
	character_id = character_id.strip_edges().to_lower()
	if character_id.is_empty():
		return
	get_tree().call_group(
		DESKTOP_DIALOGUE_GROUP,
		"set_character_response_loading",
		character_id,
		"chat",
		loading
	)

func notify_desktop_character_reply(
	character_id: String,
	text: String
) -> void:

	get_tree().call_group(
		DESKTOP_DIALOGUE_GROUP,
		"show_character_chat_bubble",
		character_id,
		text
	)

func parse_ai_payload(raw_text: String) -> Dictionary:
	return DialogueOutput.parse_chat(raw_text, CharacterProfiles.get_pack_output_language(CharacterProfiles.get_current_pack()))

func is_ai_busy() -> bool:
	if ai_client == null:
		return false

	var busy_value: Variant = (
		ai_client.get(
			"request_in_progress"
		)
	)

	return bool(
		busy_value
	)

func set_waiting_state(
	waiting: bool
) -> void:

	send_button.disabled = (
		waiting
		or current_thread_id.is_empty()
	)

	message_input.editable = (
		not waiting
		and not current_thread_id.is_empty()
	)

	clear_memory_button.disabled = waiting

	new_chat_button.disabled = (
		waiting
		or new_chat_character_selector
			.item_count <= 0
	)

	new_chat_character_selector.disabled = (
		waiting
		or new_chat_character_selector
			.item_count <= 0
	)

	if waiting:
		thread_list.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

		thread_list.focus_mode = (
			Control.FOCUS_NONE
		)

		status_label.text = (
			pending_character_name
			+ _l(" is replying...", " 답변 중...")
		)

	else:
		thread_list.mouse_filter = (
			Control.MOUSE_FILTER_STOP
		)

		thread_list.focus_mode = (
			Control.FOCUS_ALL
		)

		if not current_thread_id.is_empty():
			message_input.grab_focus()

func _on_clear_memory_pressed() -> void:
	var error: Error = (
		DialogueMemoryScript.clear_all()
	)

	if error != OK:
		status_label.text = _l(
			"Could not clear shared memory.",
			"공유 메모리를 비우지 못했습니다."
		)

		return

	refresh_memory_status()

	status_label.text = _l(
		"Persistent shared memory cleared.",
		"공유 메모리를 모두 비웠습니다."
	)

func refresh_memory_status() -> void:
	var count: int = (
		DialogueMemoryScript
			.get_memory_count()
	)

	memory_label.text = (
		_l("Memory: ", "메모리: ")
		+ str(count)
		+ "/"
		+ str(DialogueMemoryScript.MAX_MEMORIES)
	)

func refresh_history_status() -> void:
	if current_thread_id.is_empty():
		history_label.text = _l(
			"Saved chat: 0 messages",
			"저장된 대화: 메시지 0개"
		)

		return

	var count: int = (
		ChatThreadStoreScript
			.get_message_count(
				current_thread_id
			)
	)

	if AppLanguageScript.get_language() == "ko":
		history_label.text = (
			"저장된 대화: 메시지 "
			+ str(count)
			+ "개"
		)
	else:
		history_label.text = (
			"Saved chat: "
			+ str(count)
			+ " message"
		)

		if count != 1:
			history_label.text += "s"

func append_user_message(
	text: String
) -> void:

	append_message_spacing()

	transcript.push_bold()

	transcript.add_text(
		_l("You", "나")
	)

	transcript.pop()

	transcript.newline()

	transcript.add_text(
		text
	)

func append_character_message(
	character_id: String,
	display_name: String,
	text: String
) -> void:
	text = DialogueOutput.saved_reply(text)
	if text.is_empty():
		return

	append_message_spacing()

	var character_color: Color = (
		get_character_chat_color(
			character_id
		)
	)

	transcript.push_color(
		character_color
	)

	transcript.push_bold()

	transcript.add_text(
		display_name
	)

	transcript.pop()

	transcript.newline()

	transcript.add_text(
		text
	)

	transcript.pop()

func append_message_spacing() -> void:
	if transcript.get_parsed_text().is_empty():
		return

	transcript.newline()

	transcript.newline()

func make_thread_title(
	text: String
) -> String:

	var clean: String = (
		text
			.replace(
				"\n",
				" "
			)
			.replace(
				"\r",
				" "
			)
			.strip_edges()
	)

	while clean.contains(
		"  "
	):
		clean = clean.replace(
			"  ",
			" "
		)

	if clean.is_empty():
		return "New chat"

	if clean.length() <= 42:
		return clean

	return (
		clean.left(
			39
		)
		+ "..."
	)
