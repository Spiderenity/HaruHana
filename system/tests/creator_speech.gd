extends SceneTree

var failures := 0

func check(value: bool, label: String) -> void:
	print("CREATOR_SPEECH ", "PASS " if value else "FAIL ", label)
	if not value:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://system/tools/character_creator/character_creator.tscn").instantiate()
	root.add_child(scene)
	await create_timer(1.0).timeout
	scene._start_new_pack(1, true)
	scene._on_profile_mode_selected("simple")
	check(not scene.manifest_profile_controls["menu_greeting"].get_parent().visible and not scene.manifest_profile_controls["farewell"].get_parent().visible, "greetings hidden in simple mode")
	scene._on_profile_mode_selected("advanced")
	check(scene.manifest_profile_controls["menu_greeting"].get_parent().visible and scene.manifest_profile_controls["farewell"].get_parent().visible, "greetings shown in advanced mode")
	var selector: OptionButton = scene.manifest_profile_controls["voice_register"]
	check(selector.get_item_text(0) in ["자동", "Auto"], "auto label has no explanation")
	await process_frame
	var scroll: Node = selector.get_parent()
	while scroll != null and not scroll is ScrollContainer:
		scroll = scroll.get_parent()
	check(scroll != null, "speech selector belongs to scroll page")
	if scroll != null:
		selector.get_popup().popup()
		await process_frame
		check(selector.get_popup().visible, "dropdown opens")
		var bar: VScrollBar = scroll.get_v_scroll_bar()
		bar.value = 30 if bar.value == 0 else 0
		await process_frame
		check(not selector.get_popup().visible, "page scrolling closes dropdown")
	scene.manifest_profile_controls["voice_register"].select(2)
	scene.manifest_profile_controls["menu_greeting"].text = "무엇을 도와드릴까요?"
	scene.manifest_profile_controls["farewell"].text = "다음에 뵙겠습니다."
	check(scene._commit_manifest_form(), "creator form saves")
	var destination := ProjectSettings.globalize_path("user://creator-roundtrip")
	DirAccess.make_dir_recursive_absolute(destination)
	var exported: Dictionary = scene.model.export_to(destination)
	check(bool(exported.get("ok", false)), "single character pack exports")
	if exported.get("ok", false):
		var restored = load("res://system/tools/character_creator/scripts/pack_model.gd").new()
		var loaded: Dictionary = restored.load_existing(str(exported["path"]).path_join("manifest.json"))
		check(bool(loaded.get("ok", false)), "pack reloads")
		if loaded.get("ok", false):
			var profile: Dictionary = restored.characters[0]["profile"]
			check(profile["voice"]["register"] == "polite", "polite choice survives export")
			check(profile["default_lines"]["menu"] == "무엇을 도와드릴까요?", "menu greeting survives export")
			check(profile["default_lines"]["exit"] == "다음에 뵙겠습니다.", "farewell survives export")
	scene._refresh_manifest_form()
	check(scene.manifest_profile_controls["voice_register"].selected == 2, "form restores speech choice")
	print("CREATOR_SPEECH_FAILURES ", failures)
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)
