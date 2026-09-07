extends Node2D
class_name DesktopCharacterActor

signal menu_tab_requested(
	character_id: String,
	tab_name: String
)

signal menu_talk_action_requested(
	character_id: String,
	action: String,
	detail: String
)

signal interactive_question_answered(
	character_id: String,
	answer: Dictionary
)

signal interactive_question_dismissed(
	character_id: String,
	reason: String
)

signal menu_visibility_changed(
	character_id: String,
	is_open: bool
)

signal play_event_requested(
	character_id: String,
	event_kind: String,
	zone: String,
	play_value: float
)

signal play_changed(
	character_id: String,
	play_value: float,
	play_max: float
)

signal play_interaction_activity(
	character_id: String
)

signal flustered_started(
	character_id: String,
	duration: float,
	mood: String
)

signal temporary_departure_requested(
	character_id: String,
	duration_seconds: float,
	delay_seconds: float,
	reason: String,
	unavailable_lines: Array
)

signal speech_bubble_offset_changed(
	character_id: String,
	offset: Vector2
)

signal application_close_requested

const DESKTOP_ACTOR_GROUP: StringName = (
	&"desktop_character_actors"
)

const DesktopCharacterPlayScript = preload(
	"res://system/services/desktop/desktop_character_play.gd"
)

const DesktopSpeechTypewriterScript = preload(
	"res://system/services/desktop/desktop_speech_typewriter.gd"
)

const AppearanceSettingsScript = preload(
	"res://system/app/appearance_settings.gd"
)

const SegmentedBubbleBackgroundScript = preload(
	"res://system/services/desktop/segmented_bubble_background.gd"
)

const DesktopCharacterMenuScript = preload(
	"res://system/services/desktop/desktop_character_menu.gd"
)

const DesktopCharacterProgressScript = preload(
	"res://system/services/desktop/desktop_character_progress.gd"
)

const AppLanguageScript = preload(
	"res://system/app/app_language.gd"
)

const DialogueCatalogScript = preload(
	"res://system/services/characters/dialogue_catalog.gd"
)

const DEFAULT_MOOD: String = DialogueCatalogScript.DEFAULT_MOOD
const VALID_MOODS: Array[String] = DialogueCatalogScript.EXTENDED_MOODS
const OFFSCREEN_WINDOW_POSITION: Vector2i = Vector2i(-32000, -32000)

@export var character_id: String = ""

@export var visual_root: CanvasItem

@export var body_sprite: Sprite2D

@export var expression_controller: DesktopExpressionController

@export var eyes: AnimatedSprite2D

@export var blink_timer: Timer

@export var speech_bubble: Control

@export var speech_label: Label

@export var bubble_hide_timer: Timer

@export var pet_interaction: DesktopPetInteraction

@export var blink_animation: StringName = &"blink"

@export var timer_reactions_enabled: bool = true

@export var ambient_dialogue_enabled: bool = true

@export var speech_bubble_opacity: float = 1.0

@export var minimum_blink_delay: float = 2.5

@export var maximum_blink_delay: float = 6.0

@export var typewriter_characters_per_second: float = 30.0

@export var speech_bubble_gap: float = 18.0

@export var speech_bubble_screen_margin: float = 12.0

@export var speech_bubble_inward_offset: float = 34.0

@export var speech_bubble_pair_gap: float = 10.0

@export var character_canvas_size: Vector2i = Vector2i(400, 600)

@export var center_visual_in_window: bool = true

var desktop_slot_index: int = 0

var current_mood: String = DEFAULT_MOOD

var play_controller: DesktopCharacterPlay = null

var speech_typewriter: DesktopSpeechTypewriter = null
var speech_hold_duration: float = 5.0

var desktop_base_opacity: float = 0.82
var desktop_character_scale: float = 1.0
var desktop_speech_bubble_scale: float = 1.0
var current_character_alpha: float = 0.82

var speech_bubble_height_locked: bool = false
var speech_bubble_highest_desktop_y: float = 0.0
var appearance_refresh_accumulator: float = 0.0
var last_bubble_appearance_signature: String = ""
var last_bubble_load_warning_skin: String = ""
var preview_bubble_override_enabled: bool = false
var preview_bubble_textures: Dictionary = {}
var preview_bubble_text_color: Color = Color.WHITE
var segmented_bubble_background: SegmentedBubbleBackground = null
var speech_bubble_window: Window = null
var speech_bubble_top_close_window: Window = null
var speech_bubble_top_close_surface: Control = null
var focus_timer_window: Window = null
var focus_timer_panel: PanelContainer = null
var focus_status_box: HBoxContainer = null
var focus_timer_label: Label = null
var response_loading_label: Label = null
var focus_timer_window_id: int = -1
var focus_timer_seconds_remaining: int = 0
var focus_timer_active: bool = false
var focus_timer_paused: bool = false
var response_loading_sources: Dictionary = {}
var response_loading_frame: int = 0
var response_loading_elapsed: float = 0.0
var last_focus_timer_appearance_signature: String = ""
var speech_bubble_drag_enabled: bool = false
var speech_bubble_dragging: bool = false
var speech_bubble_drag_moved: bool = false
var speech_bubble_drag_origin: Vector2i = Vector2i.ZERO
var speech_bubble_offset_origin: Vector2 = Vector2.ZERO
var speech_bubble_offset: Vector2 = Vector2.ZERO
var desktop_minimized: bool = false
var character_window_id: int = -1
var speech_bubble_window_id: int = -1
var speech_bubble_top_close_window_id: int = -1
var speech_bubble_windows_primed: bool = false

var body_variants: Dictionary = {}
var current_body_state: String = "default"
var body_hold_timer: Timer = null
var body_hold_restore_state: String = "default"
var body_restore_on_speech_hide: bool = false
var body_dialogue_restore_state: String = "default"

var character_menu: DesktopCharacterMenu = null
var character_menu_enabled: bool = true

func _ready() -> void:
	add_to_group(
		DESKTOP_ACTOR_GROUP
	)

	if visual_root == null:
		visual_root = self

	_configure_character_window_topmost()
	character_window_id = get_window().get_window_id()

	_apply_visual_scale()
	_center_visual_root_in_window()
	_create_speech_bubble_window()
	_create_focus_timer_window()

	if speech_bubble != null:
		speech_bubble.hide()

		speech_bubble.mouse_filter = (
			Control.MOUSE_FILTER_IGNORE
		)

		speech_bubble.mouse_default_cursor_shape = (
			Control.CURSOR_ARROW
		)

		var bubble_input_callable: Callable = Callable(
			self,
			"_on_speech_bubble_gui_input"
		)

		if not speech_bubble.gui_input.is_connected(
			bubble_input_callable
		):
			speech_bubble.gui_input.connect(
				bubble_input_callable
			)

	if blink_timer != null:
		var blink_callable: Callable = Callable(
			self,
			"_on_blink_timer_timeout"
		)

		if not blink_timer.timeout.is_connected(
			blink_callable
		):
			blink_timer.timeout.connect(
				blink_callable
			)

		schedule_next_blink()

	if bubble_hide_timer != null:
		var hide_callable: Callable = Callable(
			self,
			"_on_bubble_hide_timer_timeout"
		)

		if not bubble_hide_timer.timeout.is_connected(
			hide_callable
		):
			bubble_hide_timer.timeout.connect(
				hide_callable
			)

	if pet_interaction != null:
		var alt_callable: Callable = _on_pet_alt_clicked
		if not pet_interaction.pet_alt_clicked.is_connected(alt_callable):
			pet_interaction.pet_alt_clicked.connect(alt_callable)

		var menu_callable: Callable = _on_pet_alt_right_clicked
		if not pet_interaction.pet_alt_right_clicked.is_connected(menu_callable):
			pet_interaction.pet_alt_right_clicked.connect(menu_callable)

	_create_body_hold_timer()
	create_character_menu()
	create_play_controller()

	create_speech_typewriter()
	_apply_bubble_appearance(true)

	call_deferred(
		"set_mood",
		_get_idle_mood()
	)

	call_deferred(
		"_apply_display_settings"
	)

func _configure_character_window_topmost() -> void:
	var character_window: Window = get_window()

	if character_window == null:
		return

	character_window.always_on_top = true

	var focus_callable: Callable = Callable(
		self,
		"_on_character_window_focus_entered"
	)

	if not character_window.focus_entered.is_connected(
		focus_callable
	):
		character_window.focus_entered.connect(
			focus_callable
		)

func _on_character_window_focus_entered() -> void:
	restore_desktop_window_order()

func restore_desktop_window_order() -> void:
	_raise_desktop_window(get_window(), character_window_id)
	_raise_desktop_window(speech_bubble_window, speech_bubble_window_id)
	_raise_desktop_window(speech_bubble_top_close_window, speech_bubble_top_close_window_id)
	_raise_desktop_window(focus_timer_window, focus_timer_window_id)

func _raise_desktop_window(window: Window, cached_window_id: int = -1) -> void:
	if window == null or not is_instance_valid(window) or not window.visible:
		return

	if OS.get_name() == "Windows":
		var native_passthrough: Object = (
			Engine.get_singleton("MousePassthrough")
		)

		if (
			native_passthrough != null
			and native_passthrough.has_method("raise_window_topmost")
		):
			native_passthrough.call(
				"raise_window_topmost",
				cached_window_id if cached_window_id >= 0 else window.get_window_id()
			)
			return

	window.always_on_top = true

	DisplayServer.window_move_to_foreground(
		window.get_window_id()
	)

func _exit_tree() -> void:
	if focus_timer_window != null and is_instance_valid(focus_timer_window):
		focus_timer_window.queue_free()

	if (
		speech_bubble_top_close_window != null
		and is_instance_valid(speech_bubble_top_close_window)
	):
		speech_bubble_top_close_window.queue_free()

	if (
		speech_bubble_window != null
		and is_instance_valid(speech_bubble_window)
	):
		speech_bubble_window.queue_free()

func _create_focus_timer_window() -> void:
	if focus_timer_window != null and is_instance_valid(focus_timer_window):
		return
	var character_window: Window = get_window()
	if character_window == null or character_window.get_parent() == null:
		return

	focus_timer_window = Window.new()
	focus_timer_window.name = "FocusTimerWindow_" + character_id
	focus_timer_window.size = Vector2i(104, 36)
	focus_timer_window.borderless = true
	focus_timer_window.transparent = true
	focus_timer_window.transparent_bg = true
	focus_timer_window.unresizable = true
	focus_timer_window.unfocusable = true
	focus_timer_window.always_on_top = true
	focus_timer_window.transient = false
	focus_timer_window.mouse_passthrough = true
	focus_timer_window.visible = false
	focus_timer_window.close_requested.connect(request_application_close)
	character_window.get_parent().add_child(focus_timer_window)
	focus_timer_window_id = focus_timer_window.get_window_id()

	focus_timer_panel = PanelContainer.new()
	focus_timer_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_timer_window.add_child(focus_timer_panel)

	focus_status_box = HBoxContainer.new()
	focus_status_box.alignment = BoxContainer.ALIGNMENT_CENTER
	focus_status_box.add_theme_constant_override("separation", 6)
	focus_timer_panel.add_child(focus_status_box)

	response_loading_label = Label.new()
	response_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	response_loading_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	response_loading_label.add_theme_font_size_override("font_size", 18)
	response_loading_label.text = "◜"
	response_loading_label.visible = false
	focus_status_box.add_child(response_loading_label)

	focus_timer_label = Label.new()
	focus_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	focus_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	focus_timer_label.add_theme_font_size_override("font_size", 16)
	focus_status_box.add_child(focus_timer_label)
	_apply_focus_timer_appearance(true)
	_update_focus_timer_window()

func set_focus_timer_state(
	seconds_remaining: int,
	active: bool,
	paused: bool
) -> void:
	focus_timer_seconds_remaining = maxi(0, seconds_remaining)
	focus_timer_active = active
	focus_timer_paused = paused
	_update_focus_timer_window()

func set_response_loading(source: String, loading: bool) -> void:
	source = source.strip_edges().to_lower()
	if source.is_empty():
		return
	if loading:
		response_loading_sources[source] = true
	else:
		response_loading_sources.erase(source)
	if response_loading_sources.is_empty():
		response_loading_elapsed = 0.0
		response_loading_frame = 0
	_update_focus_timer_window()

func _update_focus_timer_window() -> void:
	if focus_timer_window == null or not is_instance_valid(focus_timer_window):
		return
	var minutes: int = focus_timer_seconds_remaining / 60
	var seconds: int = focus_timer_seconds_remaining % 60
	if focus_timer_label != null:
		focus_timer_label.text = "%02d:%02d" % [minutes, seconds]
		focus_timer_label.visible = focus_timer_active
	var response_loading: bool = not response_loading_sources.is_empty()
	if response_loading_label != null:
		response_loading_label.visible = response_loading
	_update_focus_status_window_size(response_loading)
	_apply_focus_timer_appearance(false)
	if focus_timer_panel != null:
		var timer_color: Color = focus_timer_panel.modulate
		timer_color.a = get_speech_bubble_alpha()
		focus_timer_panel.modulate = timer_color
	if (focus_timer_active or response_loading) and not desktop_minimized:
		_sync_focus_timer_position()
		if not focus_timer_window.visible:
			focus_timer_window.show()
	else:
		focus_timer_window.hide()

func _update_focus_status_window_size(response_loading: bool) -> void:
	if focus_timer_window == null:
		return
	var width: int = 104
	if response_loading and focus_timer_active:
		width = 132
	elif response_loading:
		width = 40
	focus_timer_window.size = Vector2i(width, 36)

func _apply_focus_timer_appearance(force: bool) -> void:
	if focus_timer_panel == null or focus_timer_label == null:
		return
	var signature: String = (
		AppearanceSettingsScript.get_theme_signature()
		+ ("|paused" if focus_timer_paused else "|active")
	)
	if not force and signature == last_focus_timer_appearance_signature:
		return
	var background_role: String = "secondary" if focus_timer_paused else "selection"
	var style := StyleBoxFlat.new()
	style.bg_color = AppearanceSettingsScript.get_ui_color(background_role)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	focus_timer_panel.add_theme_stylebox_override("panel", style)
	focus_timer_label.add_theme_color_override(
		"font_color",
		AppearanceSettingsScript.get_ui_color(
			"muted" if focus_timer_paused else "text"
		)
	)
	if response_loading_label != null:
		response_loading_label.add_theme_color_override(
			"font_color",
			AppearanceSettingsScript.get_ui_color("text")
		)
	var ui_font: Font = AppearanceSettingsScript.get_ui_font()
	if ui_font != null:
		focus_timer_label.add_theme_font_override("font", ui_font)
		if response_loading_label != null:
			response_loading_label.add_theme_font_override("font", ui_font)
	else:
		focus_timer_label.remove_theme_font_override("font")
		if response_loading_label != null:
			response_loading_label.remove_theme_font_override("font")
	last_focus_timer_appearance_signature = signature

func _sync_focus_timer_position() -> void:
	if focus_timer_window == null or pet_interaction == null:
		return
	var pet_rect: Rect2 = pet_interaction.get_desktop_pet_rect()
	if pet_rect.size == Vector2.ZERO:
		return
	var screen: Rect2i = DisplayServer.screen_get_usable_rect()
	var target_x: int = roundi(pet_rect.get_center().x - float(focus_timer_window.size.x) / 2.0)
	var target_y: int = roundi(pet_rect.position.y - float(focus_timer_window.size.y) - 8.0)
	focus_timer_window.position = Vector2i(
		clampi(target_x, screen.position.x, screen.end.x - focus_timer_window.size.x),
		clampi(target_y, screen.position.y, screen.end.y - focus_timer_window.size.y)
	)

func _create_speech_bubble_window() -> void:
	if speech_bubble == null:
		return

	if (
		speech_bubble_window != null
		and is_instance_valid(speech_bubble_window)
	):
		return

	var character_window: Window = get_window()

	if character_window == null:
		return

	var window_container: Node = character_window.get_parent()

	if window_container == null:
		return

	speech_bubble_window = Window.new()
	speech_bubble_window.name = "SpeechBubbleWindow_" + character_id
	speech_bubble_window.borderless = true
	speech_bubble_window.transparent = true
	speech_bubble_window.transparent_bg = true
	speech_bubble_window.unresizable = true
	speech_bubble_window.unfocusable = true
	speech_bubble_window.always_on_top = true
	speech_bubble_window.transient = false
	speech_bubble_window.mouse_passthrough = true
	speech_bubble_window.visible = false
	speech_bubble_window.close_requested.connect(request_application_close)

	window_container.add_child(speech_bubble_window)
	speech_bubble_window_id = speech_bubble_window.get_window_id()
	speech_bubble.reparent(speech_bubble_window, false)
	speech_bubble.position = Vector2.ZERO
	speech_bubble.scale = Vector2.ONE

	_create_speech_bubble_top_close_window(window_container)
	_prime_speech_bubble_windows()

func _prime_speech_bubble_windows() -> void:
	speech_bubble_windows_primed = false
	for window: Window in [speech_bubble_window, speech_bubble_top_close_window]:
		if window == null or not is_instance_valid(window):
			continue
		window.position = OFFSCREEN_WINDOW_POSITION
		window.show()
	if speech_bubble_top_close_window != null:
		speech_bubble_top_close_window.mouse_passthrough = true
	await get_tree().process_frame
	await get_tree().process_frame
	speech_bubble_windows_primed = true
	if speech_bubble == null or not speech_bubble.visible:
		_move_speech_bubble_windows_offscreen()
	else:
		_update_speech_bubble_position()

func _move_speech_bubble_windows_offscreen() -> void:
	if speech_bubble_window != null and is_instance_valid(speech_bubble_window):
		speech_bubble_window.position = OFFSCREEN_WINDOW_POSITION
	if (
		speech_bubble_top_close_window != null
		and is_instance_valid(speech_bubble_top_close_window)
	):
		speech_bubble_top_close_window.mouse_passthrough = true
		speech_bubble_top_close_window.position = OFFSCREEN_WINDOW_POSITION

func _create_speech_bubble_top_close_window(
	window_container: Node
) -> void:
	if (
		speech_bubble_top_close_window != null
		and is_instance_valid(speech_bubble_top_close_window)
	):
		return

	speech_bubble_top_close_window = Window.new()
	speech_bubble_top_close_window.name = (
		"SpeechBubbleTopCloseWindow_" + character_id
	)
	speech_bubble_top_close_window.borderless = true
	speech_bubble_top_close_window.transparent = true
	speech_bubble_top_close_window.transparent_bg = true
	speech_bubble_top_close_window.unresizable = true
	speech_bubble_top_close_window.unfocusable = true
	speech_bubble_top_close_window.always_on_top = true
	speech_bubble_top_close_window.transient = false
	speech_bubble_top_close_window.mouse_passthrough = false
	speech_bubble_top_close_window.visible = false
	speech_bubble_top_close_window.close_requested.connect(request_application_close)

	window_container.add_child(speech_bubble_top_close_window)
	speech_bubble_top_close_window_id = speech_bubble_top_close_window.get_window_id()

	speech_bubble_top_close_surface = Control.new()
	speech_bubble_top_close_surface.name = "TopCloseSurface"
	speech_bubble_top_close_surface.mouse_filter = (
		Control.MOUSE_FILTER_STOP
	)
	speech_bubble_top_close_surface.mouse_default_cursor_shape = (
		Control.CURSOR_ARROW
	)
	speech_bubble_top_close_window.add_child(
		speech_bubble_top_close_surface
	)
	speech_bubble_top_close_surface.gui_input.connect(
		_on_speech_bubble_top_close_gui_input
	)

func _apply_visual_scale() -> void:
	if visual_root is Node2D:
		(visual_root as Node2D).scale = Vector2(
			desktop_character_scale,
			desktop_character_scale
		)
	elif visual_root is Control:
		(visual_root as Control).scale = Vector2(
			desktop_character_scale,
			desktop_character_scale
		)

func _center_visual_root_in_window() -> void:
	if not center_visual_in_window:
		return

	var window: Window = get_window()

	if window == null:
		return

	var center: Vector2 = Vector2(window.size) / 2.0

	if visual_root is Node2D:
		(visual_root as Node2D).position = center
	elif visual_root is Control:
		(visual_root as Control).position = center

func configure_character_id(
	new_character_id: String
) -> void:

	character_id = (
		new_character_id
			.strip_edges()
			.to_lower()
	)

func configure_desktop_slot(
	slot_index: int
) -> void:

	desktop_slot_index = maxi(
		0,
		slot_index
	)

	if pet_interaction != null:
		pet_interaction.configure_desktop_slot(desktop_slot_index)

func get_character_window_size() -> Vector2i:
	return Vector2i(
		maxi(1, roundi(float(character_canvas_size.x) * desktop_character_scale)),
		maxi(1, roundi(float(character_canvas_size.y) * desktop_character_scale))
	)
func configure_display(
	base_opacity: float,
	character_scale: float,
	bubble_scale: float = 1.0,
	bubble_opacity: float = 1.0
) -> void:
	desktop_base_opacity = clampf(
		base_opacity,
		0.10,
		1.0
	)
	desktop_character_scale = clampf(
		character_scale,
		0.50,
		1.50
	)
	desktop_speech_bubble_scale = clampf(bubble_scale, 0.50, 1.50)
	speech_bubble_opacity = clampf(
		bubble_opacity,
		0.25,
		1.0
	)

	if is_node_ready():
		_apply_display_settings()
	else:
		call_deferred(
			"_apply_display_settings"
		)

func configure_desktop_interaction(
	vertical_movement_enabled: bool,
	bubble_drag_enabled: bool,
	bubble_offset: Vector2
) -> void:
	speech_bubble_drag_enabled = bubble_drag_enabled
	speech_bubble_offset = bubble_offset
	if pet_interaction != null:
		pet_interaction.configure_vertical_movement(vertical_movement_enabled)
	_update_speech_bubble_input_mode()
	_reset_speech_bubble_height_lock()

func set_desktop_minimized(minimized: bool) -> void:
	desktop_minimized = minimized
	var character_window: Window = get_window()
	if minimized:
		if character_window != null and not _set_native_window_visible(character_window, false, character_window_id):
			character_window.hide()
		if speech_bubble_window != null and is_instance_valid(speech_bubble_window) and not _set_native_window_visible(speech_bubble_window, false, speech_bubble_window_id):
			speech_bubble_window.hide()
		if speech_bubble_top_close_window != null and is_instance_valid(speech_bubble_top_close_window) and not _set_native_window_visible(speech_bubble_top_close_window, false, speech_bubble_top_close_window_id):
			speech_bubble_top_close_window.hide()
		if focus_timer_window != null and is_instance_valid(focus_timer_window):
			focus_timer_window.hide()
		return
	if character_window != null:
		if not _set_native_window_visible(character_window, true, character_window_id):
			character_window.show()
	if speech_bubble != null and speech_bubble.visible:
		_update_speech_bubble_position()
		_set_native_window_visible(speech_bubble_window, true, speech_bubble_window_id)
		if speech_bubble_top_close_window != null and speech_bubble_top_close_window.visible:
			_set_native_window_visible(speech_bubble_top_close_window, true, speech_bubble_top_close_window_id)
	_update_focus_timer_window()
	restore_desktop_window_order()

func _set_native_window_visible(window: Window, should_be_visible: bool, cached_window_id: int = -1) -> bool:
	if window == null or not is_instance_valid(window) or OS.get_name() != "Windows":
		return false
	var native_passthrough: Object = Engine.get_singleton("MousePassthrough")
	if native_passthrough == null or not native_passthrough.has_method("set_window_visible"):
		return false
	return bool(native_passthrough.call(
		"set_window_visible",
		cached_window_id if cached_window_id >= 0 else window.get_window_id(),
		should_be_visible
	))

func configure_behavior(
	ambient_enabled: bool,
	timer_enabled: bool
) -> void:
	ambient_dialogue_enabled = ambient_enabled
	timer_reactions_enabled = timer_enabled

func _apply_display_settings() -> void:
	if visual_root == null:
		visual_root = self

	var window: Window = get_window()
	var old_desktop_pet_rect: Rect2 = Rect2()

	if window != null and pet_interaction != null:
		old_desktop_pet_rect = pet_interaction.get_desktop_pet_rect()

	_apply_visual_scale()

	if window != null:
		window.size = get_character_window_size()
		_center_visual_root_in_window()

		var target_x: int = window.position.x
		if old_desktop_pet_rect.size != Vector2.ZERO and pet_interaction != null:
			var new_pet_rect: Rect2 = pet_interaction.get_pet_rect()
			if new_pet_rect.size != Vector2.ZERO:
				target_x = roundi(
					old_desktop_pet_rect.get_center().x
					- new_pet_rect.get_center().x
				)

		var target_y: int = window.position.y
		if (
			pet_interaction == null
			or not pet_interaction.is_vertical_movement_enabled()
		):
			var ground_end_y: float = float(window.size.y)
			if pet_interaction != null:
				var ground_rect: Rect2 = pet_interaction.get_sprite_ground_rect()
				if ground_rect.size != Vector2.ZERO:
					ground_end_y = ground_rect.end.y

			var usable_screen: Rect2i = DisplayServer.screen_get_usable_rect()
			target_y = usable_screen.end.y - roundi(ground_end_y)

		window.position = Vector2i(target_x, target_y)

		if pet_interaction != null:
			pet_interaction.sync_locked_y_to_window_position()

	if pet_interaction != null:
		pet_interaction.configure_visual_behavior(desktop_base_opacity)

	set_character_alpha(desktop_base_opacity)
	call_deferred("_update_speech_bubble_position")

func get_character_id() -> String:
	return character_id

func request_application_close() -> void:
	application_close_requested.emit()

func get_menu_alpha() -> float:
	return get_speech_bubble_alpha()

func get_desktop_slot_index() -> int:
	return desktop_slot_index

func get_timer_reactions_enabled() -> bool:
	return timer_reactions_enabled

func get_ambient_dialogue_enabled() -> bool:
	return ambient_dialogue_enabled

func get_speech_bubble_size() -> Vector2:
	if speech_bubble == null:
		return Vector2.ZERO

	var result: Vector2 = (
		speech_bubble.size
	)

	var minimum_size: Vector2 = (
		speech_bubble.get_combined_minimum_size()
	)

	result.x = maxf(
		result.x,
		minimum_size.x
	)

	result.y = maxf(
		result.y,
		minimum_size.y
	)

	return result * desktop_speech_bubble_scale

func create_play_controller() -> void:
	if play_controller != null:
		return

	play_controller = (
		DesktopCharacterPlayScript.new()
	)

	play_controller.name = "CharacterPlay"

	add_child(
		play_controller
	)

	play_controller.configure(
		self,
		character_id
	)

	play_controller.connect(
		"play_changed",
		Callable(
			self,
			"_on_play_changed"
		)
	)

	play_controller.connect(
		"interaction_activity",
		Callable(
			self,
			"_on_play_interaction_activity"
		)
	)

	play_controller.connect(
		"local_reaction_requested",
		Callable(
			self,
			"_on_play_local_reaction_requested"
		)
	)

	play_controller.connect(
		"notable_event_requested",
		Callable(
			self,
			"_on_play_notable_event_requested"
		)
	)

	play_controller.connect(
		"flustered_started",
		Callable(
			self,
			"_on_play_flustered_started"
		)
	)

	play_controller.connect(
		"temporary_departure_requested",
		Callable(
			self,
			"_on_play_temporary_departure_requested"
		)
	)

	if pet_interaction != null:
		var stroke_callable: Callable = _on_pet_stroked
		if not pet_interaction.pet_stroked.is_connected(stroke_callable):
			pet_interaction.pet_stroked.connect(stroke_callable)

func _on_pet_stroked(
	_interaction_character_id: String,
	local_position: Vector2,
	distance: float
) -> void:

	if play_controller == null:
		return

	var pet_size: Vector2 = (
		_get_local_pet_rect().size
	)

	play_controller.handle_pet_stroke(
		local_position,
		distance,
		pet_size
	)

func _on_pet_alt_clicked(
	_interaction_character_id: String
) -> void:
	if speech_bubble != null and speech_bubble.visible:
		return
	if play_controller == null:
		return

	var local_position: Vector2 = Vector2.ZERO
	if pet_interaction != null:
		local_position = pet_interaction.get_alt_local_mouse_position()
	var pet_size: Vector2 = _get_local_pet_rect().size
	if bool(play_controller.is_poke_mode()):
		play_controller.handle_poke(local_position, pet_size)
	else:
		play_controller.handle_click_dialogue(local_position, pet_size, true)

func _on_pet_alt_right_clicked(
	_interaction_character_id: String
) -> void:
	if play_controller != null and bool(play_controller.is_flustered()):
		return
	var menu_is_open: bool = character_menu != null and character_menu.is_open()
	if not menu_is_open:
		hide_speech()
	toggle_character_menu()

func _on_play_changed(
	_interaction_character_id: String,
	play_value: float,
	play_max: float
) -> void:

	play_changed.emit(
		character_id,
		play_value,
		play_max
	)

func _on_play_interaction_activity(
	_interaction_character_id: String
) -> void:

	play_interaction_activity.emit(
		character_id
	)

func _on_play_local_reaction_requested(
	_interaction_character_id: String,
	dialogue: Dictionary
) -> void:

	show_dialogue(
		dialogue,
		4.2
	)

func _on_play_notable_event_requested(
	_interaction_character_id: String,
	event_kind: String,
	zone: String,
	play_value: float
) -> void:

	play_event_requested.emit(
		character_id,
		event_kind,
		zone,
		play_value
	)

func _on_play_flustered_started(
	_interaction_character_id: String,
	duration: float,
	mood: String
) -> void:

	flustered_started.emit(
		character_id,
		duration,
		mood
	)

func _on_play_temporary_departure_requested(
	_interaction_character_id: String,
	duration_seconds: float,
	delay_seconds: float,
	reason: String,
	unavailable_lines: Array
) -> void:

	temporary_departure_requested.emit(
		character_id,
		duration_seconds,
		delay_seconds,
		reason,
		unavailable_lines.duplicate(
			true
		)
	)
func is_play_interaction_active() -> bool:
	return play_controller != null and play_controller.is_interaction_active()

func get_play_value() -> float:
	if play_controller == null:
		return 0.0

	return float(
		play_controller.get_play_value()
	)

func is_play_flustered() -> bool:
	if play_controller == null:
		return false

	return bool(
		play_controller.is_flustered()
	)

func _get_idle_mood() -> String:
	if play_controller == null:
		return DEFAULT_MOOD
	return play_controller.get_idle_mood()

func set_character_alpha(
	alpha: float
) -> void:

	var safe_alpha: float = clampf(
		alpha,
		0.0,
		1.0
	)

	current_character_alpha = safe_alpha
	_set_speech_bubble_alpha(safe_alpha)

	var root: Node = visual_root

	if root == null:
		root = self

	if root is CanvasItem:
		var root_color: Color = (
			(root as CanvasItem).modulate
		)

		root_color.a = 1.0

		(root as CanvasItem).modulate = (
			root_color
		)

	var changed_count: int = (
		_apply_character_art_alpha_recursive(
			root,
			safe_alpha
		)
	)

	if changed_count > 0:
		return

	if root is CanvasItem:
		var fallback_color: Color = (
			(root as CanvasItem).modulate
		)

		fallback_color.a = safe_alpha

		(root as CanvasItem).modulate = (
			fallback_color
		)

func get_speech_bubble_alpha() -> float:
	var fade_ratio: float = current_character_alpha / maxf(desktop_base_opacity, 0.01)
	return clampf(speech_bubble_opacity * fade_ratio, 0.0, 1.0)

func _set_speech_bubble_alpha(alpha: float) -> void:
	if speech_bubble == null:
		return

	current_character_alpha = clampf(alpha, 0.0, 1.0)
	var bubble_color: Color = speech_bubble.modulate
	bubble_color.a = get_speech_bubble_alpha()
	speech_bubble.modulate = bubble_color
	if focus_timer_panel != null:
		var timer_color: Color = focus_timer_panel.modulate
		timer_color.a = get_speech_bubble_alpha()
		focus_timer_panel.modulate = timer_color

func _apply_character_art_alpha_recursive(
	node: Node,
	alpha: float
) -> int:

	if node == null:
		return 0

	if (
		speech_bubble != null
		and node == speech_bubble
	):
		return 0

	var changed: int = 0

	if (
		node is Sprite2D
		or node is AnimatedSprite2D
		or node is Polygon2D
		or node is Line2D
		or node is TextureRect
		or node is NinePatchRect
	):
		var item: CanvasItem = (
			node as CanvasItem
		)

		var color: Color = item.self_modulate

		color.a = alpha

		item.self_modulate = color

		changed += 1

	for child: Node in node.get_children():
		changed += _apply_character_art_alpha_recursive(
			child,
			alpha
		)

	return changed

func create_character_menu() -> void:
	if not character_menu_enabled:
		return
	if character_menu != null and is_instance_valid(character_menu):
		return
	character_menu = DesktopCharacterMenuScript.new()
	character_menu.name = "CharacterMenuController"
	add_child(character_menu)
	character_menu.configure(self)
	character_menu.tab_requested.connect(_on_menu_tab_requested)
	character_menu.talk_action_requested.connect(_on_menu_talk_action_requested)
	character_menu.interactive_answer_selected.connect(_on_interactive_answer_selected)
	character_menu.interactive_question_dismissed.connect(_on_interactive_question_dismissed)
	character_menu.normal_menu_visibility_changed.connect(_on_menu_visibility_changed)

func toggle_character_menu() -> void:
	if not character_menu_enabled:
		return
	for node: Node in get_tree().get_nodes_in_group(DESKTOP_ACTOR_GROUP):
		if node is DesktopCharacterActor:
			var actor: DesktopCharacterActor = node as DesktopCharacterActor
			if actor.is_interactive_question_open():
				return
	if character_menu == null:
		create_character_menu()
	if character_menu != null:
		character_menu.toggle_menu()

func hide_character_menu() -> void:
	if character_menu != null and is_instance_valid(character_menu):
		character_menu.hide_menu()

func open_interactive_question(question: Dictionary) -> bool:
	if not character_menu_enabled:
		return false
	if character_menu == null:
		create_character_menu()
	if character_menu == null or not is_instance_valid(character_menu):
		return false
	if not character_menu.can_show_interactive_question(question):
		return false
	return character_menu.show_interactive_question(question)

func set_character_menu_enabled(enabled: bool) -> void:
	character_menu_enabled = enabled
	if enabled:
		return
	if character_menu != null and is_instance_valid(character_menu):
		character_menu.queue_free()
	character_menu = null

func is_interactive_question_open() -> bool:
	if character_menu == null or not is_instance_valid(character_menu):
		return false
	return character_menu.is_interactive_question_open()

func close_peer_character_menus() -> void:
	for node: Node in get_tree().get_nodes_in_group(DESKTOP_ACTOR_GROUP):
		if node == self or not (node is DesktopCharacterActor):
			continue
		(node as DesktopCharacterActor).hide_character_menu()

func _on_menu_tab_requested(tab_name: String) -> void:
	menu_tab_requested.emit(character_id, tab_name)

func _on_menu_talk_action_requested(action: String, detail: String) -> void:
	menu_talk_action_requested.emit(character_id, action, detail)

func _on_interactive_answer_selected(answer: Dictionary) -> void:
	interactive_question_answered.emit(character_id, answer.duplicate(true))

func _on_interactive_question_dismissed(reason: String) -> void:
	interactive_question_dismissed.emit(character_id, reason)

func _on_menu_visibility_changed(is_open: bool) -> void:
	menu_visibility_changed.emit(character_id, is_open)

func _get_menu_talk_reaction(action: String, detail: String) -> Dictionary:
	var progress: Dictionary = DesktopCharacterProgressScript.get_context(character_id)
	var friendship_level: int = int(progress.get("friendship_level", 0))
	var achievement_level: int = int(progress.get("achievement_level", 0))
	var text: String = ""
	var mood: String = "neutral"

	match action:
		"hello":
			mood = "happy"
			if friendship_level >= 3:
				text = AppLanguageScript.text("There you are.", "왔네.")
			elif friendship_level >= 1:
				text = AppLanguageScript.text("Hey. Good to see you.", "왔구나. 반가워.")
			else:
				text = AppLanguageScript.text("Hello.", "안녕.")
		"ask":
			match detail:
				"week":
					if achievement_level >= 3:
						text = AppLanguageScript.text(
							"You've already focused for more than three hours this week. You worked pretty hard.",
							"이번 주 집중 시간, 벌써 3시간 넘겼네. 꽤 열심히 했어."
						)
					elif achievement_level >= 2:
						text = AppLanguageScript.text(
							"You've passed 90 minutes of focus this week. You worked pretty hard this week.",
							"이번 주 집중 시간은 90분 넘겼네. 이번 주는 꽤 열심히 했어."
						)
					elif achievement_level >= 1:
						text = AppLanguageScript.text(
							"You've passed 30 minutes of focus this week. So you haven't been doing nothing.",
							"이번 주 집중 시간은 30분 넘겼네. 아주 놀고만 있진 않았어."
						)
					else:
						text = AppLanguageScript.text(
							"Your focus time this week is still under 30 minutes. Planning to get started soon?",
							"이번 주 집중 시간은 아직 30분도 안 됐네. 슬슬 시작할 생각은 있어?"
						)
				"self":
					if friendship_level >= 3:
						text = AppLanguageScript.text(
							"You know me well enough by now. Ask something specific.",
							"이제 나를 꽤 알잖아. 궁금한 걸 제대로 물어봐."
						)
					elif friendship_level >= 1:
						text = AppLanguageScript.text("Still curious about me?", "아직도 내가 궁금해?")
					else:
						text = AppLanguageScript.text("What do you want to know?", "뭐가 궁금한데?")
				_:
					text = AppLanguageScript.text("Go on.", "말해 봐.")
		"praise":
			mood = "happy"
			match detail:
				"great_job":
					if achievement_level >= 2:
						text = AppLanguageScript.text(
							"You too. You've been busy enough yourself.",
							"너도. 이번 주는 너도 꽤 바빴잖아."
						)
					else:
						text = AppLanguageScript.text("I know.", "알아.")
				"cute":
					if friendship_level >= 3:
						mood = "smug"
						text = AppLanguageScript.text(
							"You say that like it's established fact.",
							"이제 완전히 사실인 것처럼 말하네."
						)
					elif friendship_level >= 1:
						mood = "embarrassed"
						text = AppLanguageScript.text("Again with that?", "또 그 말이야?")
					else:
						mood = "surprised"
						text = AppLanguageScript.text("That's sudden.", "갑자기?")
				"thanks":
					if friendship_level >= 2:
						text = AppLanguageScript.text(
							"You don't have to make a thing of it.",
							"그걸 굳이 크게 말할 것까지야."
						)
					else:
						text = AppLanguageScript.text("You're welcome.", "별말을.")
				_:
					text = AppLanguageScript.text("Thanks.", "고마워.")
		"scold":
			mood = "annoyed"
			if friendship_level >= 3:
				text = AppLanguageScript.text(
					"You're getting awfully comfortable with me.",
					"나한테 아주 편해졌네."
				)
			elif friendship_level >= 1:
				text = AppLanguageScript.text("That's a little harsh.", "좀 너무한데.")
			else:
				text = AppLanguageScript.text("Excuse me?", "뭐라고?")
		_:
			text = AppLanguageScript.text("Go on.", "말해 봐.")

	return {
		"text": text,
		"mood": mood,
		"duration": 3.6,
	}

func get_interaction_menu_rect(menu_size: Vector2) -> Rect2:
	var own_rect: Rect2 = get_desktop_pet_rect()
	if own_rect.size == Vector2.ZERO:
		return Rect2(Vector2(DisplayServer.mouse_get_position()), menu_size)

	var preferred_right: bool = _should_place_bubble_on_right(own_rect)
	for side_right: bool in [preferred_right, not preferred_right]:
		var candidate: Rect2 = _make_side_menu_rect(own_rect, menu_size, side_right)
		if _menu_rect_is_screen_safe(candidate) and not _menu_rect_hits_character_except(candidate, self):
			return candidate

	var peers: Array[DesktopCharacterActor] = _get_peer_actors_nearest_first(own_rect)
	for peer: DesktopCharacterActor in peers:
		var peer_rect: Rect2 = peer.get_desktop_pet_rect()
		var peer_center_x: float = peer_rect.position.x + peer_rect.size.x / 2.0
		var own_center_x: float = own_rect.position.x + own_rect.size.x / 2.0
		var outward_right: bool = peer_center_x >= own_center_x
		for side_right: bool in [outward_right, not outward_right]:
			var candidate: Rect2 = _make_side_menu_rect(peer_rect, menu_size, side_right)
			if _menu_rect_is_screen_safe(candidate) and not _menu_rect_hits_character_except(candidate, peer):
				return candidate

	return _clamp_bubble_rect_to_screen(_make_side_menu_rect(own_rect, menu_size, preferred_right))

func _make_side_menu_rect(anchor: Rect2, menu_size: Vector2, right: bool) -> Rect2:
	var gap: float = 10.0
	var x: float = anchor.end.x + gap if right else anchor.position.x - menu_size.x - gap
	var y: float = anchor.position.y + anchor.size.y * 0.48 - menu_size.y * 0.5
	var rect := Rect2(Vector2(x, y), menu_size)
	var usable: Rect2i = DisplayServer.screen_get_usable_rect()
	var min_y: float = float(usable.position.y) + speech_bubble_screen_margin
	var max_y: float = float(usable.end.y) - speech_bubble_screen_margin - menu_size.y
	if max_y >= min_y:
		rect.position.y = clampf(rect.position.y, min_y, max_y)
	return rect

func _menu_rect_is_screen_safe(rect: Rect2) -> bool:
	var usable: Rect2i = DisplayServer.screen_get_usable_rect()
	var margin: float = speech_bubble_screen_margin
	return (
		rect.position.x >= float(usable.position.x) + margin
		and rect.end.x <= float(usable.end.x) - margin
		and rect.position.y >= float(usable.position.y) + margin
		and rect.end.y <= float(usable.end.y) - margin
	)

func _menu_rect_hits_character_except(
	rect: Rect2,
	ignored_actor: DesktopCharacterActor
) -> bool:
	for node: Node in get_tree().get_nodes_in_group(DESKTOP_ACTOR_GROUP):
		if node == ignored_actor or not (node is DesktopCharacterActor):
			continue
		var peer_rect: Rect2 = (node as DesktopCharacterActor).get_desktop_pet_rect()
		if rect.intersects(peer_rect):
			return true
	return false

func _get_peer_actors_nearest_first(own_rect: Rect2) -> Array[DesktopCharacterActor]:
	var pairs: Array[Dictionary] = []
	var own_center: Vector2 = own_rect.get_center()
	for node: Node in get_tree().get_nodes_in_group(DESKTOP_ACTOR_GROUP):
		if node == self or not (node is DesktopCharacterActor):
			continue
		var peer: DesktopCharacterActor = node as DesktopCharacterActor
		var peer_rect: Rect2 = peer.get_desktop_pet_rect()
		pairs.append({
			"actor": peer,
			"distance": own_center.distance_to(peer_rect.get_center()),
		})
	pairs.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return float(a["distance"]) < float(b["distance"])
	)
	var result: Array[DesktopCharacterActor] = []
	for pair: Dictionary in pairs:
		var actor_value: Variant = pair.get("actor", null)
		if actor_value is DesktopCharacterActor:
			result.append(actor_value as DesktopCharacterActor)
	return result

func configure_body_variants(sprite: Sprite2D, variants: Dictionary) -> void:
	body_sprite = sprite
	body_variants = variants.duplicate()
	if body_sprite != null and not body_variants.has("default") and body_sprite.texture != null:
		body_variants["default"] = body_sprite.texture
	current_body_state = "default"

func _create_body_hold_timer() -> void:
	if body_hold_timer != null:
		return
	body_hold_timer = Timer.new()
	body_hold_timer.name = "BodyStateTimer"
	body_hold_timer.one_shot = true
	body_hold_timer.ignore_time_scale = true
	body_hold_timer.timeout.connect(_on_body_hold_timeout)
	add_child(body_hold_timer)

func get_body_states() -> Array[String]:
	var result: Array[String] = []
	for key: Variant in body_variants.keys():
		result.append(str(key))
	result.sort()
	return result

func has_body_state(state: String) -> bool:
	return body_variants.has(_normalize_body_state(state))

func set_body_state(state: String) -> bool:
	body_restore_on_speech_hide = false
	if body_hold_timer != null:
		body_hold_timer.stop()
	return _apply_body_state(state)

func show_body_state_during_speech(state: String) -> bool:
	var cleaned: String = _normalize_body_state(state)
	if not body_variants.has(cleaned):
		return false
	if not body_restore_on_speech_hide:
		body_dialogue_restore_state = current_body_state
	body_restore_on_speech_hide = true
	if body_hold_timer != null:
		body_hold_timer.stop()
	return _apply_body_state(cleaned)

func keep_body_state_for(state: String, duration_seconds: float) -> bool:
	var cleaned: String = _normalize_body_state(state)
	if not body_variants.has(cleaned):
		return false
	body_restore_on_speech_hide = false
	body_hold_restore_state = current_body_state
	if not _apply_body_state(cleaned):
		return false
	_create_body_hold_timer()
	body_hold_timer.stop()
	body_hold_timer.start(maxf(0.05, duration_seconds))
	return true

func reset_body_state() -> void:
	body_restore_on_speech_hide = false
	if body_hold_timer != null:
		body_hold_timer.stop()
	_apply_body_state("default")

func _normalize_body_state(state: String) -> String:
	var cleaned: String = state.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	if cleaned.begins_with("body_"):
		cleaned = cleaned.trim_prefix("body_")
	if cleaned.is_empty():
		return "default"
	return cleaned

func _apply_body_state(state: String) -> bool:
	var cleaned: String = _normalize_body_state(state)
	if body_sprite == null or not body_variants.has(cleaned):
		return false
	var texture_value: Variant = body_variants[cleaned]
	if not (texture_value is Texture2D):
		return false
	body_sprite.texture = texture_value as Texture2D
	current_body_state = cleaned
	if pet_interaction != null:
		pet_interaction.call_deferred("rebuild_alpha_hit_mask")
	return true

func _on_body_hold_timeout() -> void:
	_apply_body_state(body_hold_restore_state)

func _restore_dialogue_body_state() -> void:
	if not body_restore_on_speech_hide:
		return
	body_restore_on_speech_hide = false
	_apply_body_state(body_dialogue_restore_state)

func normalize_mood(
	mood: String
) -> String:
	return DialogueCatalogScript.normalize_mood(mood)

func set_mood(
	mood: String
) -> void:

	var cleaned: String = (
		normalize_mood(
			mood
		)
	)

	current_mood = cleaned

	var controller: Node = (
		_get_expression_controller()
	)

	if controller != null:
		if controller.has_method(
			"set_mood"
		):
			controller.call(
				"set_mood",
				cleaned
			)

func _get_expression_controller() -> Node:
	if expression_controller != null:
		return expression_controller

	var sibling_controller: Node = get_node_or_null(
		"ExpressionController"
	)

	if sibling_controller != null:
		if sibling_controller.has_method(
			"set_mood"
		):
			return sibling_controller

	if visual_root is Node:
		var visual_node: Node = (
			visual_root as Node
		)

		if visual_node.has_method(
			"set_mood"
		):
			return visual_node

		var child_controller: Node = visual_node.get_node_or_null(
			"ExpressionController"
		)

		if child_controller != null:
			if child_controller.has_method(
				"set_mood"
			):
				return child_controller

	return null

func create_speech_typewriter() -> void:
	if speech_typewriter != null:
		return

	speech_typewriter = (
		DesktopSpeechTypewriterScript.new()
	)

	speech_typewriter.name = "SpeechTypewriter"

	add_child(
		speech_typewriter
	)

	speech_typewriter.configure(
		speech_label
	)

	speech_typewriter.mood_requested.connect(_on_typewriter_mood_requested)
	speech_typewriter.body_requested.connect(_on_typewriter_body_requested)
	speech_typewriter.finished.connect(_on_typewriter_finished)

func _on_typewriter_mood_requested(
	mood: String
) -> void:

	set_mood(
		mood
	)

func _on_typewriter_body_requested(
	body_state: String,
	hold_seconds: float
) -> void:
	if hold_seconds > 0.0:
		keep_body_state_for(body_state, hold_seconds)
	else:
		show_body_state_during_speech(body_state)

func _on_typewriter_finished() -> void:
	_update_speech_bubble_input_mode()

	if (
		speech_bubble == null
		or not speech_bubble.visible
	):
		return

	if bubble_hide_timer == null:
		return

	bubble_hide_timer.stop()
	bubble_hide_timer.start(speech_hold_duration)

func _on_speech_bubble_gui_input(
	event: InputEvent
) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed and speech_typewriter != null and bool(speech_typewriter.is_active()):
		speech_typewriter.finish_immediately()
		speech_bubble.accept_event()

func _update_speech_bubble_input_mode() -> void:
	if speech_bubble == null:
		return
	var typewriter_active: bool = speech_typewriter != null and bool(speech_typewriter.is_active())
	var accepts_input: bool = typewriter_active
	speech_bubble.mouse_filter = Control.MOUSE_FILTER_STOP if accepts_input else Control.MOUSE_FILTER_IGNORE
	speech_bubble.mouse_default_cursor_shape = Control.CURSOR_ARROW
	if speech_bubble_window != null and is_instance_valid(speech_bubble_window):
		speech_bubble_window.mouse_passthrough = not accepts_input
	if speech_bubble_top_close_surface != null:
		speech_bubble_top_close_surface.mouse_default_cursor_shape = (
			Control.CURSOR_MOVE
			if speech_bubble_drag_enabled
			else Control.CURSOR_ARROW
		)

func _on_speech_bubble_top_close_gui_input(
	event: InputEvent
) -> void:
	if not (event is InputEventMouseButton):
		return

	var mouse_event: InputEventMouseButton = (
		event as InputEventMouseButton
	)

	if (
		mouse_event.button_index != MOUSE_BUTTON_LEFT
	):
		return

	if (
		speech_bubble == null
		or not speech_bubble.visible
	):
		return

	if speech_bubble_drag_enabled:
		if mouse_event.pressed:
			speech_bubble_dragging = true
			speech_bubble_drag_moved = false
			speech_bubble_drag_origin = DisplayServer.mouse_get_position()
			speech_bubble_offset_origin = speech_bubble_offset
		else:
			_finish_speech_bubble_drag()
	else:
		if not mouse_event.pressed:
			return
		hide_speech()

	if speech_bubble_top_close_surface != null:
		speech_bubble_top_close_surface.accept_event()

func _update_speech_bubble_drag() -> void:
	if not speech_bubble_dragging:
		return
	var left_pressed: bool = (
		DisplayServer.mouse_get_button_state()
		& MOUSE_BUTTON_MASK_LEFT
	) != 0
	if not left_pressed:
		_finish_speech_bubble_drag()
		return
	var mouse_position: Vector2i = DisplayServer.mouse_get_position()
	var delta: Vector2 = Vector2(mouse_position - speech_bubble_drag_origin)
	if delta.length() >= 3.0:
		speech_bubble_drag_moved = true
	speech_bubble_offset = speech_bubble_offset_origin + delta
	_update_speech_bubble_position()

func _finish_speech_bubble_drag() -> void:
	if not speech_bubble_dragging:
		return
	speech_bubble_dragging = false
	if speech_bubble_drag_moved:
		speech_bubble_offset_changed.emit(character_id, speech_bubble_offset)
	else:
		hide_speech()

func schedule_next_blink() -> void:
	if blink_timer == null:
		return

	blink_timer.stop()

	blink_timer.start(
		randf_range(
			minimum_blink_delay,
			maximum_blink_delay
		)
	)

func _on_blink_timer_timeout() -> void:
	if eyes != null:
		if not blink_animation.is_empty():
			eyes.play(
				blink_animation
			)

	schedule_next_blink()

func show_dialogue(
	dialogue: Dictionary,
	duration: float = 5.0
) -> void:

	var text: String = str(
		dialogue.get(
			"text",
			""
		)
	).strip_edges()

	if text.is_empty():
		return

	var initial_mood: String = str(
		dialogue.get(
			"mood",
			DEFAULT_MOOD
		)
	)

	var body_state: String = str(dialogue.get("body", dialogue.get("body_state", ""))).strip_edges()
	if not body_state.is_empty():
		var body_hold_seconds: float = float(dialogue.get("body_hold_seconds", dialogue.get("body_duration", 0.0)))
		if body_hold_seconds > 0.0:
			keep_body_state_for(body_state, body_hold_seconds)
		else:
			show_body_state_during_speech(body_state)

	show_speech(
		text,
		duration,
		initial_mood
	)

func configure_preview_bubble(textures: Dictionary, text_color: Color) -> void:
	preview_bubble_override_enabled = true
	preview_bubble_textures = textures.duplicate()
	preview_bubble_text_color = text_color
	last_bubble_appearance_signature = ""
	_apply_bubble_appearance(true)
	_set_speech_bubble_alpha(current_character_alpha)

func show_speech(
	text: String,
	duration: float = 5.0,
	initial_mood: String = DEFAULT_MOOD
) -> void:
	if speech_bubble == null:
		return

	if speech_label == null:
		return

	if speech_bubble_window == null:
		_create_speech_bubble_window()

	if speech_bubble_window == null:
		return

	var source_text: String = text.strip_edges()

	if source_text.is_empty():
		return

	speech_hold_duration = maxf(0.1, duration)

	if bubble_hide_timer != null:
		bubble_hide_timer.stop()

	if not speech_bubble.visible:
		_reset_speech_bubble_height_lock()

	speech_bubble.show()
	_set_speech_bubble_alpha(current_character_alpha)

	if speech_typewriter != null:
		_update_speech_bubble_input_mode()

		var allowed_moods: Array[String] = VALID_MOODS.duplicate()
		var allowed_body_states: Array[String] = get_body_states()

		var visible_text: String = str(
			speech_typewriter.start(
				source_text,
				normalize_mood(initial_mood),
				allowed_moods,
				typewriter_characters_per_second,
				allowed_body_states
			)
		)

		if visible_text.is_empty():
			hide_speech()
			return
	else:
		speech_label.text = source_text
		speech_label.visible_characters = -1
		set_mood(initial_mood)

	call_deferred("_refresh_speech_bubble_layout")

	if speech_typewriter == null:
		_on_typewriter_finished()

func hide_speech() -> void:
	speech_bubble_dragging = false
	if speech_typewriter != null:
		speech_typewriter.cancel()

	if speech_bubble != null:
		speech_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		speech_bubble.hide()

	if (
		speech_bubble_window != null
		and is_instance_valid(speech_bubble_window)
	):
		speech_bubble_window.mouse_passthrough = true

	if (
		speech_bubble_top_close_window != null
		and is_instance_valid(speech_bubble_top_close_window)
	):
		speech_bubble_top_close_window.mouse_passthrough = true

	_move_speech_bubble_windows_offscreen()

	_reset_speech_bubble_height_lock()

	if bubble_hide_timer != null:
		bubble_hide_timer.stop()

	_restore_dialogue_body_state()
	set_mood(_get_idle_mood())

func _on_bubble_hide_timer_timeout() -> void:
	hide_speech()

func _refresh_speech_bubble_layout() -> void:
	if speech_bubble == null:
		return

	if speech_label == null:
		return

	_apply_segmented_bubble_content_margins()

	if not speech_bubble.visible:
		return

	var line_count: int = maxi(
		1,
		speech_label.get_line_count()
	)

	var line_height: int = maxi(
		1,
		speech_label.get_line_height()
	)

	var line_spacing: int = speech_label.get_theme_constant(
		"line_spacing"
	)

	var text_height: float = (
		float(
			line_count * line_height
		)
		+ float(
			maxi(
				0,
				line_count - 1
			) * line_spacing
		)
	)

	var vertical_padding: float = 0.0

	var label_parent: Node = speech_label.get_parent()

	if label_parent is MarginContainer:
		var margin_parent: MarginContainer = (
			label_parent as MarginContainer
		)

		vertical_padding = float(
			margin_parent.get_theme_constant(
				"margin_top"
			)
			+ margin_parent.get_theme_constant(
				"margin_bottom"
			)
		)

	var minimum_size: Vector2 = (
		speech_bubble.custom_minimum_size
	)

	var target_width: float = maxf(
		minimum_size.x,
		speech_bubble.size.x
	)

	var target_height: float = maxf(
		minimum_size.y,
		text_height + vertical_padding
	)

	speech_bubble.size = Vector2(
		target_width,
		target_height
	)

	speech_bubble.queue_sort()

	call_deferred(
		"_update_speech_bubble_position"
	)

func _update_speech_bubble_position() -> void:
	if speech_bubble == null:
		return
	if not speech_bubble_windows_primed:
		return

	if not speech_bubble.visible:
		return

	if (
		speech_bubble_window == null
		or not is_instance_valid(speech_bubble_window)
	):
		return

	var own_pet_rect: Rect2 = get_desktop_pet_rect()

	if own_pet_rect.size == Vector2.ZERO:
		return

	var bubble_size: Vector2 = get_speech_bubble_size()

	if bubble_size == Vector2.ZERO:
		return

	var place_on_right: bool = _should_place_bubble_on_right(own_pet_rect)
	place_on_right = _choose_screen_safe_bubble_side(
		own_pet_rect,
		bubble_size,
		place_on_right
	)

	var target_rect: Rect2 = _make_bubble_desktop_rect(
		own_pet_rect,
		bubble_size,
		place_on_right
	)

	if _bubble_rect_hits_other_character(target_rect):
		var alternate_rect: Rect2 = _make_bubble_desktop_rect(
			own_pet_rect,
			bubble_size,
			not place_on_right
		)

		if not _bubble_rect_hits_other_character(alternate_rect):
			place_on_right = not place_on_right
			target_rect = alternate_rect

	target_rect = _clamp_bubble_rect_to_screen(target_rect)
	target_rect = _resolve_other_bubble_overlap(target_rect, own_pet_rect)

	if not speech_bubble_height_locked:
		speech_bubble_highest_desktop_y = target_rect.position.y
		speech_bubble_height_locked = true
	else:
		speech_bubble_highest_desktop_y = minf(
			speech_bubble_highest_desktop_y,
			target_rect.position.y
		)
		target_rect.position.y = speech_bubble_highest_desktop_y

	target_rect.position += speech_bubble_offset
	target_rect = _clamp_bubble_rect_to_screen(target_rect)

	var native_size: Vector2i = Vector2i(
		maxi(1, ceili(target_rect.size.x)),
		maxi(1, ceili(target_rect.size.y))
	)
	var unscaled_size := Vector2(native_size) / desktop_speech_bubble_scale

	speech_bubble_window.size = native_size
	speech_bubble_window.position = Vector2i(
		roundi(target_rect.position.x),
		roundi(target_rect.position.y)
	)
	speech_bubble.position = Vector2.ZERO
	speech_bubble.scale = Vector2.ONE * desktop_speech_bubble_scale
	speech_bubble.size = unscaled_size

	if (
		segmented_bubble_background != null
		and is_instance_valid(segmented_bubble_background)
	):
		segmented_bubble_background.position = Vector2.ZERO
		segmented_bubble_background.size = unscaled_size

	if not desktop_minimized and not speech_bubble_window.visible:
		speech_bubble_window.show()

	_update_speech_bubble_top_close_window(
		native_size,
		speech_bubble_window.position
	)

func _update_speech_bubble_top_close_window(
	bubble_size: Vector2i,
	bubble_position: Vector2i
) -> void:
	if (
		speech_bubble_top_close_window == null
		or not is_instance_valid(speech_bubble_top_close_window)
		or speech_bubble_top_close_surface == null
		or not is_instance_valid(speech_bubble_top_close_surface)
	):
		return

	if (
		segmented_bubble_background == null
		or not is_instance_valid(segmented_bubble_background)
	):
		speech_bubble_top_close_window.mouse_passthrough = true
		speech_bubble_top_close_window.position = OFFSCREEN_WINDOW_POSITION
		return

	var top_height: int = clampi(
		ceili(
			float(
				segmented_bubble_background.get_top_height(
					float(bubble_size.x) / desktop_speech_bubble_scale
				)
			) * desktop_speech_bubble_scale
		),
		0,
		bubble_size.y
	)

	if top_height <= 0:
		speech_bubble_top_close_window.mouse_passthrough = true
		speech_bubble_top_close_window.position = OFFSCREEN_WINDOW_POSITION
		return

	speech_bubble_top_close_window.size = Vector2i(
		bubble_size.x,
		top_height
	)
	speech_bubble_top_close_window.position = bubble_position
	speech_bubble_top_close_window.mouse_passthrough = false
	speech_bubble_top_close_surface.position = Vector2.ZERO
	speech_bubble_top_close_surface.size = Vector2(
		float(bubble_size.x),
		float(top_height)
	)

	if not speech_bubble_top_close_window.visible:
		speech_bubble_top_close_window.show()

func _choose_screen_safe_bubble_side(
	own_pet_rect: Rect2,
	bubble_size: Vector2,
	preferred_right: bool
) -> bool:

	var preferred_rect: Rect2 = (
		_make_bubble_desktop_rect(
			own_pet_rect,
			bubble_size,
			preferred_right
		)
	)

	var alternate_rect: Rect2 = (
		_make_bubble_desktop_rect(
			own_pet_rect,
			bubble_size,
			not preferred_right
		)
	)

	var preferred_overflow: float = (
		_get_horizontal_screen_overflow(
			preferred_rect
		)
	)

	var alternate_overflow: float = (
		_get_horizontal_screen_overflow(
			alternate_rect
		)
	)

	if alternate_overflow < preferred_overflow:
		return not preferred_right

	return preferred_right

func _get_horizontal_screen_overflow(
	rect: Rect2
) -> float:

	var usable_screen: Rect2i = (
		DisplayServer
			.screen_get_usable_rect()
	)

	var left_edge: float = (
		float(
			usable_screen.position.x
		)
		+ speech_bubble_screen_margin
	)

	var right_edge: float = (
		float(
			usable_screen.end.x
		)
		- speech_bubble_screen_margin
	)

	var overflow: float = 0.0

	if rect.position.x < left_edge:
		overflow += (
			left_edge
				- rect.position.x
		)

	if rect.end.x > right_edge:
		overflow += (
			rect.end.x
				- right_edge
		)

	return overflow

func _should_place_bubble_on_right(
	own_pet_rect: Rect2
) -> bool:

	var own_center_x: float = (
		own_pet_rect.position.x
		+ own_pet_rect.size.x / 2.0
	)

	var other_centers: Array[float] = []

	for node: Node in get_tree().get_nodes_in_group(DESKTOP_ACTOR_GROUP):
		if node == self or not (node is DesktopCharacterActor):
			continue
		var peer: DesktopCharacterActor = node as DesktopCharacterActor
		var peer_rect: Rect2 = peer.get_desktop_pet_rect()

		if peer_rect.size == Vector2.ZERO:
			continue

		other_centers.append(
			peer_rect.position.x
				+ peer_rect.size.x / 2.0
		)

	if not other_centers.is_empty():
		var nearest_center_x: float = (
			other_centers[0]
		)

		var nearest_distance: float = absf(
			own_center_x
			- nearest_center_x
		)

		for center_x: float in other_centers:
			var distance: float = absf(
				own_center_x
				- center_x
			)

			if distance < nearest_distance:
				nearest_distance = distance
				nearest_center_x = center_x

		if is_equal_approx(
			own_center_x,
			nearest_center_x
		):
			return desktop_slot_index == 0

		return own_center_x < nearest_center_x

	var usable_screen: Rect2i = (
		DisplayServer
			.screen_get_usable_rect()
	)

	var screen_center_x: float = (
		float(usable_screen.position.x)
		+ float(usable_screen.size.x) / 2.0
	)

	return own_center_x < screen_center_x

func _make_bubble_desktop_rect(
	own_pet_rect: Rect2,
	bubble_size: Vector2,
	place_on_right: bool
) -> Rect2:

	var target_x: float = (
		own_pet_rect.position.x
		+ own_pet_rect.size.x / 2.0
		- bubble_size.x / 2.0
	)

	if place_on_right:
		target_x += speech_bubble_inward_offset

	else:
		target_x -= speech_bubble_inward_offset

	var target_y: float = (
		own_pet_rect.position.y
		- bubble_size.y
		- speech_bubble_gap
	)

	return Rect2(
		Vector2(
			target_x,
			target_y
		),
		bubble_size
	)

func _clamp_bubble_rect_to_screen(
	rect: Rect2
) -> Rect2:
	var usable_screen: Rect2i = DisplayServer.screen_get_usable_rect()
	var minimum_x: float = float(usable_screen.position.x) + speech_bubble_screen_margin
	var maximum_x: float = (
		float(usable_screen.end.x)
		- speech_bubble_screen_margin
		- rect.size.x
	)
	var minimum_y: float = float(usable_screen.position.y) + speech_bubble_screen_margin
	var maximum_y: float = (
		float(usable_screen.end.y)
		- speech_bubble_screen_margin
		- rect.size.y
	)
	var clamped_position: Vector2 = rect.position

	if maximum_x >= minimum_x:
		clamped_position.x = clampf(clamped_position.x, minimum_x, maximum_x)

	if maximum_y >= minimum_y:
		clamped_position.y = clampf(clamped_position.y, minimum_y, maximum_y)

	return Rect2(clamped_position, rect.size)

func _bubble_rect_hits_other_character(
	bubble_rect: Rect2
) -> bool:

	for node: Node in get_tree().get_nodes_in_group(DESKTOP_ACTOR_GROUP):
		if node == self or not (node is DesktopCharacterActor):
			continue
		var peer: DesktopCharacterActor = node as DesktopCharacterActor
		var peer_rect: Rect2 = peer.get_desktop_pet_rect()

		if peer_rect.size == Vector2.ZERO:
			continue

		if bubble_rect.intersects(
			peer_rect
		):
			return true

	return false

func _resolve_other_bubble_overlap(
	target_rect: Rect2,
	own_pet_rect: Rect2
) -> Rect2:

	if not _bubble_rect_hits_other_bubble(
		target_rect
	):
		return target_rect

	var own_center_x: float = (
		own_pet_rect.position.x
		+ own_pet_rect.size.x / 2.0
	)

	var resolved_rect: Rect2 = target_rect
	var found_upper_row_peer: bool = false

	for node: Node in get_tree().get_nodes_in_group(DESKTOP_ACTOR_GROUP):
		if node == self or not (node is DesktopCharacterActor):
			continue
		var peer: DesktopCharacterActor = node as DesktopCharacterActor
		var peer_bubble_rect: Rect2 = peer.get_desktop_speech_bubble_rect()

		if peer_bubble_rect.size == Vector2.ZERO:
			continue

		if not resolved_rect.intersects(
			peer_bubble_rect
		):
			continue

		var peer_pet_rect: Rect2 = peer.get_desktop_pet_rect()

		if peer_pet_rect.size == Vector2.ZERO:
			continue

		var peer_center_x: float = (
			peer_pet_rect.position.x
			+ peer_pet_rect.size.x / 2.0
		)

		var own_is_left: bool = false

		if is_equal_approx(
			own_center_x,
			peer_center_x
		):
			own_is_left = desktop_slot_index > peer.get_desktop_slot_index()

		else:
			own_is_left = (
				own_center_x < peer_center_x
			)

		if not own_is_left:
			continue

		found_upper_row_peer = true

		resolved_rect.position.y = minf(
			resolved_rect.position.y,
			peer_bubble_rect.position.y
				- resolved_rect.size.y
				- speech_bubble_pair_gap
		)

	if not found_upper_row_peer:
		return target_rect

	resolved_rect = (
		_clamp_bubble_rect_to_screen(
			resolved_rect
		)
	)

	return resolved_rect

func _bubble_rect_hits_other_bubble(
	bubble_rect: Rect2
) -> bool:

	for node: Node in get_tree().get_nodes_in_group(DESKTOP_ACTOR_GROUP):
		if node == self or not (node is DesktopCharacterActor):
			continue
		var peer_rect: Rect2 = (node as DesktopCharacterActor).get_desktop_speech_bubble_rect()

		if peer_rect.size == Vector2.ZERO:
			continue

		if bubble_rect.intersects(
			peer_rect
		):
			return true

	return false

func get_desktop_speech_bubble_rect() -> Rect2:
	if speech_bubble == null:
		return Rect2()

	if not speech_bubble.visible:
		return Rect2()

	if (
		speech_bubble_window == null
		or not is_instance_valid(speech_bubble_window)
		or not speech_bubble_window.visible
	):
		return Rect2()

	var bubble_size: Vector2 = get_speech_bubble_size()

	if bubble_size == Vector2.ZERO:
		return Rect2()

	return Rect2(Vector2(speech_bubble_window.position), bubble_size)

func get_desktop_pet_rect() -> Rect2:
	if pet_interaction == null:
		return Rect2()
	return pet_interaction.get_desktop_pet_rect()

func is_desktop_position_busy() -> bool:
	if pet_interaction == null:
		return false
	return (
		pet_interaction.is_dragging_character()
		or pet_interaction.is_automatic_slide_active()
	)

func get_default_desktop_character_gap() -> float:
	if pet_interaction == null:
		return 48.0
	return maxf(0.0, pet_interaction.get_default_character_gap())

func slide_desktop_pet_to_left(
	desired_pet_left: float,
	duration: float = 0.4
) -> bool:

	if pet_interaction == null:
		return false

	return bool(
		pet_interaction.slide_pet_to_desktop_left(
			desired_pet_left,
			duration
		)
	)

func _get_local_pet_rect() -> Rect2:
	if pet_interaction == null:
		return Rect2()
	return pet_interaction.get_pet_rect()

func _reset_speech_bubble_height_lock() -> void:
	speech_bubble_height_locked = false
	speech_bubble_highest_desktop_y = 0.0

func _apply_bubble_appearance(force: bool) -> void:
	if speech_label == null or speech_bubble == null:
		return

	var settings: Dictionary = AppearanceSettingsScript.load_settings()
	var font_path: String = str(
		settings.get(
			"bubble_font",
			AppearanceSettingsScript.DEFAULT_BUBBLE_FONT
		)
	)
	var font_size: int = clampi(
		int(
			settings.get(
				"bubble_font_size",
				AppearanceSettingsScript.DEFAULT_BUBBLE_FONT_SIZE
			)
		),
		12,
		52
	)
	var bubble_skin: String = str(
		settings.get(
			"bubble_skin",
			AppearanceSettingsScript.DEFAULT_BUBBLE_SKIN
		)
	)
	var bubble_text_color: Color = (
		AppearanceSettingsScript.get_bubble_skin_text_color(
			bubble_skin
		)
	)
	if preview_bubble_override_enabled:
		bubble_text_color = preview_bubble_text_color
	var signature: String = (
		font_path
		+ "|"
		+ str(font_size)
		+ "|"
		+ bubble_skin
		+ "|"
		+ bubble_text_color.to_html(true)
	)

	if not force and signature == last_bubble_appearance_signature:
		return

	var font: Font = AppearanceSettingsScript.get_bubble_font(font_path)

	if font == null:
		speech_label.remove_theme_font_override("font")
	else:
		speech_label.add_theme_font_override("font", font)

	speech_label.add_theme_font_size_override(
		"font_size",
		font_size
	)
	speech_label.add_theme_color_override(
		"font_color",
		bubble_text_color
	)

	var textures: Dictionary = (
		AppearanceSettingsScript.get_bubble_skin_textures(
			bubble_skin
		)
	)
	if preview_bubble_override_enabled:
		textures = preview_bubble_textures.duplicate()

	if textures.is_empty():
		_clear_segmented_bubble_background()
		last_bubble_appearance_signature = ""

		if last_bubble_load_warning_skin != bubble_skin:
			last_bubble_load_warning_skin = bubble_skin
			push_warning(
				"Speech bubble skin could not be loaded: "
				+ bubble_skin
			)
	else:
		last_bubble_load_warning_skin = ""
		var background: SegmentedBubbleBackground = _ensure_segmented_bubble_background()

		if background != null:
			background.configure(textures)
			background.show()

		var empty_style: StyleBoxEmpty = StyleBoxEmpty.new()
		speech_bubble.add_theme_stylebox_override(
			"panel",
			empty_style
		)

		_apply_segmented_bubble_content_margins()

		last_bubble_appearance_signature = signature

	if speech_bubble.visible:
		call_deferred("_refresh_speech_bubble_layout")

func _ensure_segmented_bubble_background() -> SegmentedBubbleBackground:
	if (
		segmented_bubble_background != null
		and is_instance_valid(segmented_bubble_background)
	):
		return segmented_bubble_background

	if speech_bubble == null:
		return null

	segmented_bubble_background = SegmentedBubbleBackgroundScript.new()
	segmented_bubble_background.name = "SegmentedBubbleBackground"
	segmented_bubble_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	segmented_bubble_background.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	segmented_bubble_background.size_flags_vertical = Control.SIZE_EXPAND_FILL
	speech_bubble.add_child(segmented_bubble_background)
	speech_bubble.move_child(segmented_bubble_background, 0)
	segmented_bubble_background.show()
	return segmented_bubble_background

func _clear_segmented_bubble_background() -> void:
	if (
		segmented_bubble_background != null
		and is_instance_valid(segmented_bubble_background)
	):
		segmented_bubble_background.queue_free()

	segmented_bubble_background = null
	speech_bubble.remove_theme_stylebox_override("panel")
	_set_bubble_content_margins(14, 14, 14, 14)

func _apply_segmented_bubble_content_margins() -> void:
	if (
		segmented_bubble_background == null
		or not is_instance_valid(segmented_bubble_background)
	):
		return

	var target_width: float = maxf(
		1.0,
		maxf(
			speech_bubble.size.x,
			speech_bubble.custom_minimum_size.x
		)
	)
	var top_height: float = float(
		segmented_bubble_background.get_top_height(
			target_width
		)
	)
	var bottom_height: float = float(
		segmented_bubble_background.get_bottom_height(
			target_width
		)
	)

	_set_bubble_content_margins(
		18,
		maxi(14, ceili(top_height) + 8),
		18,
		maxi(14, ceili(bottom_height) + 8)
	)

func _set_bubble_content_margins(
	left: int,
	top: int,
	right: int,
	bottom: int
) -> void:
	if speech_label == null:
		return

	var label_parent: Node = speech_label.get_parent()

	if not (label_parent is MarginContainer):
		return

	var margin_parent: MarginContainer = label_parent as MarginContainer
	margin_parent.add_theme_constant_override("margin_left", left)
	margin_parent.add_theme_constant_override("margin_top", top)
	margin_parent.add_theme_constant_override("margin_right", right)
	margin_parent.add_theme_constant_override("margin_bottom", bottom)

func _process(
	delta: float
) -> void:
	_update_speech_bubble_drag()
	if not response_loading_sources.is_empty():
		response_loading_elapsed += maxf(0.0, delta)
		if response_loading_elapsed >= 0.12:
			response_loading_elapsed = fmod(response_loading_elapsed, 0.12)
			response_loading_frame = (response_loading_frame + 1) % 4
			if response_loading_label != null:
				response_loading_label.text = ["◜", "◝", "◞", "◟"][response_loading_frame]
	appearance_refresh_accumulator += maxf(0.0, delta)

	if appearance_refresh_accumulator >= 0.5:
		appearance_refresh_accumulator = 0.0
		_apply_bubble_appearance(false)
		_apply_focus_timer_appearance(false)

	if (
		speech_bubble != null
		and speech_bubble.visible
		and not desktop_minimized
	):
		_update_speech_bubble_position()
	if (focus_timer_active or not response_loading_sources.is_empty()) and not desktop_minimized:
		_sync_focus_timer_position()
