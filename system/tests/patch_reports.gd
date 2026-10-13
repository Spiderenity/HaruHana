extends SceneTree

var failures := 0
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	print("PATCH ", "PASS " if value else "FAIL ", label)
	if not value:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/work/validation/"):
		quit(1)
		return
	var model: CreatorPackModel = load("res://system/tools/character_creator/scripts/pack_model.gd").new()
	model.new_pack(2, true)
	for character: Dictionary in model.characters:
		for slot: String in character.sprite_origins:
			character.sprite_origins[slot] = "custom"
	model.pack_id = "patch_regression_fixture"
	model.characters[0]["profile"]["desktop"] = {"default_on_desktop": false}
	model.characters[1]["profile"]["desktop"] = {"default_on_desktop": true}
	model.characters[0]["profile"]["default_lines"] = {"exit": "내일 또 만나자.", "menu": "무슨 일이야?"}
	check(model.get_line_group(0, "exit")[0].text == "내일 또 만나자.", "legacy farewell is editable")
	model.set_line_group(0, "exit", [{"text": "다음에 만나자.", "mood": "happy"}])
	model.set_line_group(0, "idle", [{"text": "내가 직접 적은 대기 대사야.", "mood": "neutral"}])
	model.set_line_group(0, "boot_primary", [{"text": "내가 직접 적은 시작 인사야.", "mood": "happy"}])
	check(model.characters[0].profile.default_lines.exit == "다음에 만나자.", "greeting editor updates legacy field")
	var exported: Dictionary = model.export_to(ProjectSettings.globalize_path("res://characters"))
	check(bool(exported.get("ok", false)), "fixture exports")
	if not exported.get("ok", false):
		quit(1)
		return
	CharacterProfiles.set_current_pack(model.pack_id)
	var manager := DesktopCharacterManager.new()
	manager.manual_preview_mode = true
	root.add_child(manager)
	check(manager._build_default_slots({}) == ["character_2", "character_1"], "second character can be primary")
	check(manager.is_character_allowed_in_slot("character_1", 0) and manager.is_character_allowed_in_slot("character_2", 1), "saved slots remain valid after role change")
	manager.save_settings({"packs": {model.pack_id: {"slots": ["", ""]}}})
	manager.reload_desktop_characters(false)
	await create_timer(0.5).timeout
	check(manager.get_slot_character_ids() == ["character_2", "character_1"], "old empty slots recover without deleting user data")
	manager.clear_spawned_characters()
	var ambient := AmbientDialogue.new()
	ambient.dialogue_pool = [{"type": "solo", "character_id": "character_1", "dialogue": {"text": "예전 AI 대사", "mood": "neutral"}}]
	check(DialogueOutput.clean_text(ambient.get_random_event_for_characters(["character_1"]).get("dialogue", {}).get("text")) == "내가 직접 적은 대기 대사야.", "authored idle overrides stale AI cache")
	ambient.free()
	var client := AIClient.new()
	var rejected: Array[String] = []
	var replies: Array[String] = []
	client.request_failed.connect(func(message: String) -> void: rejected.append(message))
	client.response_received.connect(func(message: String) -> void: replies.append(message))
	client._on_request_completed(HTTPRequest.RESULT_SUCCESS, 429, PackedStringArray(), '{"error":{"message":"quota exhausted"}}'.to_utf8_buffer())
	check(rejected.size() == 1 and replies.is_empty(), "provider quota error cannot become generated dialogue")
	client.free()
	var events := CharacterEventDialogue.new()
	check(DialogueOutput.clean_text(events._build_fallback_cast_exit_dialogue({"active_character_ids": ["character_1"]}).get("text")) == "다음에 만나자.", "API failure uses authored farewell")
	events.free()
	var startup := StartupFlowController.new()
	var pack_events := DesktopPackEvents.new()
	startup.desktop_pack_events = pack_events
	startup.boot_ai_scene_lines = [{"phase": "primary", "speaker": "character_1", "text": "예전 AI 인사"}]
	check(startup._get_ai_boot_line("primary", "character_1").get("text") == "내가 직접 적은 시작 인사야.", "authored startup overrides AI")
	startup.free()
	pack_events.free()
	var bubble_path := ProjectSettings.globalize_path("user://missing-icons")
	BundledAssets.restore_tree("res://assets/bubbles/default", bubble_path)
	DirAccess.remove_absolute(bubble_path.path_join("menu_chat.png"))
	var appearance := AppearanceSettings.load_settings()
	appearance["bubble_skin"] = bubble_path
	AppearanceSettings.save_settings(appearance)
	var menu := DesktopCharacterMenu.new()
	check(menu._load_menu_icon_texture("Chat") != null, "missing custom icon falls back to bundled icon")
	menu.free()
	var dialog := AISettingsDialog.new()
	root.add_child(dialog)
	dialog._select_route("google::gemini-test-older")
	check(dialog._selected_route() == "google::gemini-test-older", "custom Gemini model survives selection")
	dialog.queue_free()
	var creator = load("res://system/tools/character_creator/character_creator.tscn").instantiate()
	root.add_child(creator)
	await create_timer(0.5).timeout
	creator._start_new_pack(2, true)
	creator._on_profile_mode_selected("advanced")
	creator.manifest_profile_controls["farewell"].text = "수정한 작별 인사야."
	check(creator._commit_current_edits(), "profile greeting edit commits")
	check(creator.model.get_line_group(0, "exit")[0].text == "수정한 작별 인사야.", "profile greeting stays in sync with dialogue editor")
	await create_timer(0.3).timeout
	if DisplayServer.get_screen_count() > 0:
		var preview_manager: DesktopCharacterManager = creator.desktop_character_manager
		preview_manager._layout_preview_cast()
		var preview_rects: Array[Rect2] = preview_manager.get_spawned_character_rects()
		check(preview_rects.size() == 2 and not preview_rects[0].intersects(preview_rects[1]), "preview characters do not overlap")
		for actor_id: String in preview_manager.get_active_character_ids():
			check(not preview_manager.get_actor(actor_id).get_meta("remember_desktop_position", true), "preview does not save live positions")
		preview_manager._layout_preview_cast()
		check(preview_manager.get_spawned_character_rects() == preview_rects, "repeated preview refresh does not drift")
	creator._on_dialogue_scope_selected(2)
	creator._on_add_line()
	check(creator.model.conversations.size() == 1, "conversation can be added")
	creator._edit_conversation_text("첫 대사", 0, 0)
	creator._edit_conversation_text("답장", 0, 1)
	creator._edit_conversation_mood(1, 0, 0)
	check(creator.model.conversations[0].turns[0].text == "첫 대사", "conversation edits update model")
	creator._add_conversation_turn(0)
	creator._delete_conversation_turn(0, 2)
	var roundtrip: Dictionary = creator.model.export_to(ProjectSettings.globalize_path("user://roundtrip"))
	var restored = load("res://system/tools/character_creator/scripts/pack_model.gd").new()
	check(bool(restored.load_existing(str(roundtrip.path).path_join("manifest.json")).get("ok", false)), "edited conversation reloads")
	check(restored.conversations[0].turns[0].text == "첫 대사", "conversation text survives export")
	creator._clear_dialogue(true)
	check(creator.model.conversations.is_empty(), "clear all removes conversations")
	var all_empty := true
	for index: int in range(creator.model.characters.size()):
		for group: Dictionary in creator.model.get_line_groups(index):
			all_empty = all_empty and creator.model.get_line_group(index, str(group.id)).is_empty()
	check(all_empty, "clear all includes greetings and both characters")
	creator._on_bulk_generate()
	await process_frame
	check(not creator.bulk_generation_active, "bulk generation waits for group selection")
	var choices: Array[CheckBox] = []
	for window: Node in creator.get_children():
		if window is ConfirmationDialog:
			for content: Node in window.get_children():
				if content is ScrollContainer and content.get_child_count() > 0:
					for choice: Node in content.get_child(0).get_children():
						if choice is CheckBox:
							choices.append(choice)
	check(choices.size() > 1, "generation dialog lists groups")
	if choices.size() > 1:
		choices[0].button_pressed = false
		check(creator.generation_groups.get("first_boot", true) == false and creator.generation_groups.get("idle", true), "group selection changes only the chosen group")
	creator.queue_free()
	manager.queue_free()
	await process_frame
	print("PATCH_REPORTS: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
