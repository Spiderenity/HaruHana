extends SceneTree

var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# All mutable paths are inside the isolated APPDATA supplied by test.ps1.
	check(OS.get_user_data_dir().replace("\\", "/").contains("/work/validation/"), "isolated user data")
	if failures > 0:
		quit(1)
		return
	var beta := '{"reply":"(무심한 표정으로) 안녕. 뭐해?""."memorv_updates":[]}'
	check(DialogueOutput.parse_chat(beta, "ko").is_empty(), "exact malformed beta reply rejected")
	check(DialogueOutput.parse_chat('{"reply":"(무심한 표정으로) 안녕. 뭐해?","memory_updates":[]}', "ko").get("reply") == "안녕. 뭐해?", "Korean stage direction removed")
	check(DialogueOutput.clean_text("[crt replied] (neutral) 안녕. (annoyed) 왜?") == "안녕. 왜?", "silent tags and speaker metadata removed")
	check(DialogueOutput.clean_text("쉬어. (5분 정도) 배열[0]도 확인해.") == "쉬어. (5분 정도) 배열[0]도 확인해.", "ordinary parentheses and brackets preserved")
	check(DialogueOutput.clean_text("(neutral) 안녕.", true) == "(neutral) 안녕.", "desktop mood controls preserved")
	for reply: String in ["Hello there, how are you today?", "你好，今天过得怎么样？"]:
		check(DialogueOutput.parse_chat(JSON.stringify({"reply": reply}), "ko").is_empty(), "wrong language rejected")
	check(DialogueOutput.language_ok("Godot에서 JSON 파일을 확인해 봐.", "ko"), "Korean with technical names allowed")
	check(DialogueOutput.parse_chat('{"reply": {"text":"안녕"}}', "ko").is_empty(), "non-string reply rejected")
	check(DialogueOutput.parse_chat('```json\n{"reply":"안녕.","memory_updates":[]}\n```', "ko").get("reply") == "안녕.", "fenced JSON accepted")

	var save_path := "user://tests/state.json"
	check(JsonStore.save_json(save_path, {"value": 1}) == OK, "first save")
	check(JsonStore.save_json(save_path, {"value": 2}) == OK, "second save")
	check(JsonStore.load_dictionary(save_path + ".bak").get("value") == 1, "previous successful save retained")
	var corrupt := FileAccess.open(save_path, FileAccess.WRITE)
	corrupt.store_string('{"broken":')
	corrupt.close()
	check(JsonStore.load_dictionary(save_path).get("value") == 1, "corrupt save loads backup")
	check(JsonStore.save_json(save_path, {"value": 3}) == OK, "save after corruption")
	check(JsonStore.load_dictionary(save_path).get("value") == 3, "recovered primary")
	check(JsonStore.load_dictionary(save_path + ".bak").get("value") == 1, "corrupt primary never replaces valid backup")
	var blocked := "user://tests/blocked"
	AtomicFile.save_text(blocked, "file")
	check(JsonStore.save_json(blocked + "/child.json", {}) != OK, "failed save reported")

	check(CompanionScheduleStore.save_schedules([{"id":"test", "title":"작업", "repeat":"weekly", "days":[1], "hour":9, "minute":0}]), "calendar save")
	check(CompanionScheduleStore.save_schedules([{"id":"test2", "title":"새 작업", "repeat":"weekly", "days":[2], "hour":10, "minute":0}]), "calendar second save")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CompanionScheduleStore.SAVE_PATH))
	check(CompanionScheduleStore.load_schedules().any(func(item: Dictionary) -> bool: return item.get("id") == "test"), "calendar recovers missing primary")

	var target := ProjectSettings.globalize_path("user://tests/pack")
	DirAccess.make_dir_recursive_absolute(target)
	AtomicFile.save_text(target.path_join("manifest.json"), "old")
	var stage := PackageSave.begin(target)
	check(not stage.is_empty(), "package staging")
	AtomicFile.save_text(stage.path_join("manifest.json"), "new", false)
	check(FileAccess.get_file_as_string(target.path_join("manifest.json")) == "old", "staging does not alter old package")
	check(PackageSave.commit(stage, target) == OK, "package commit")
	check(FileAccess.get_file_as_string(target.path_join("manifest.json")) == "new", "new package installed")
	check(FileAccess.get_file_as_string(target.get_base_dir().path_join(".pack.previous/manifest.json")) == "old", "previous package retained")

	var thread := ChatThreadStore.create_thread("crt_chip", "crt", "Regression")
	for index: int in range(18):
		ChatThreadStore.append_message(thread["id"], "user" if index % 2 == 0 else "assistant", "안녕. ".repeat(100), "chip")
	ChatThreadStore.append_message(thread["id"], "user", "마지막 질문")
	var context := ChatThreadStore.get_context_messages(thread["id"], 40)
	check(context.size() <= 12, "bounded recent context")
	check(context.back()["content"] == "마지막 질문", "newest message retained")
	check(not JSON.stringify(context).contains("replied]"), "no bracketed speaker cues in context")
	check(DialogueOutput.saved_reply(beta).is_empty(), "malformed legacy replies excluded")
	check(DialogueOutput.saved_reply('(무심한 표정으로) 안녕.') == "안녕.", "legacy stage directions hidden")
	check(ChatThreadStore.delete_thread(thread["id"]) == OK, "thread deletion")
	check(ChatThreadStore.load_thread(thread["id"]).is_empty(), "deleted thread cannot recover from backup")
	var panel = load("res://system/ui/panels/chat_panel.gd").new()
	var prompt: String = panel.build_system_prompt("crt")
	print("METRIC chat_system_prompt_chars=" + str(prompt.length()))
	check(prompt.length() < 4500, "compact chat system prompt")
	check(prompt.contains("한국어"), "explicit Korean output rule")
	check(not prompt.contains("인라인 표정 태그를"), "authoring tag instructions omitted from chat")
	panel.free()
	var client := AIClient.new()
	var options := DialogueOutput.chat_options("openai::gpt-5.1")
	var request := client._build_request("openai", "gpt-5.1", "dummy", [{"role":"user", "content":"안녕"}], options)
	check(request["body"]["text"]["format"]["type"] == "json_schema", "OpenAI chat schema")
	check(not DialogueOutput.chat_options("openrouter::openrouter/free").has("response_format"), "free route keeps schema compatibility")
	client.free()
	var coordinator := RuntimeInstanceCoordinator.new()
	check(coordinator._entry_has_fresh_lease({"pid":OS.get_process_id(), "updated":0}), "sleep/stale heartbeat does not invalidate live process")
	check(not coordinator._entry_has_fresh_lease({"pid":0, "updated":Time.get_unix_time_from_system()}), "missing process not live")
	coordinator.free()
	AtomicFile.save_text("user://settings/ai.json", "SECRET_TEST_ONLY")
	var backup := ProjectSettings.globalize_path("user://../regression-backup.zip")
	check(UserDataBackup.export_zip(backup) == OK, "user data export")
	var zip := ZIPReader.new()
	check(zip.open(backup) == OK, "backup opens")
	check(not zip.get_files().has("settings/ai.json"), "backup excludes credentials")
	check(zip.get_files().has("tests/state.json"), "backup includes saved data")
	zip.close()
	var monitors: Array[Rect2i] = [Rect2i(0, 0, 1920, 1080), Rect2i(-1280, 0, 1280, 1024), Rect2i(0, -900, 1600, 900)]
	check(DesktopPreferences.nearest_rect_index(Vector2(-300, 500), monitors) == 1, "drag enters monitor with negative coordinates")
	check(DesktopPreferences.nearest_rect_index(Vector2(400, -300), monitors) == 2, "drag enters vertically stacked monitor")
	check(DesktopPreferences.nearest_rect_index(Vector2(-100, -300), monitors) == 2, "display gap chooses nearest monitor")
	var pet_bounds := Rect2(20, 40, 120, 200)
	check(DesktopPreferences.clamp_window(Vector2i(-2000, 1000), pet_bounds, monitors[1]) == Vector2i(-1300, 784), "character kept visible on secondary usable area")
	check(DesktopPreferences.clamp_window(Vector2i(0, 0), Rect2(0, 0, 3000, 2000), monitors[0]) == Vector2i.ZERO, "oversized character avoids inverted clamp bounds")
	check(DesktopPreferences.update_entry("crt", {"font":"res://assets/fonts/NanumSquareRoundR.ttf", "position":[10, 20]}, "test") == OK, "character preferences save")
	check(DesktopPreferences.update_entry("chip", {"font":"res://assets/fonts/NanumSquareRoundL.ttf"}, "test") == OK, "second character preferences save")
	check(DesktopPreferences.font_path("crt", "test") != DesktopPreferences.font_path("chip", "test"), "characters resolve independent fonts")
	DesktopPreferences.update_entry("crt", {"font":""}, "test")
	check(DesktopPreferences.font_path("crt", "test") == AppearanceSettings.get_bubble_font_path(), "common font inheritance")
	check(DesktopPreferences.get_entry("crt", "test")["position"] == [10, 20], "font changes preserve placement")
	DesktopPreferences._loaded = false
	var restored_position: Array = DesktopPreferences.get_entry("crt", "test")["position"]
	check(Vector2i(int(restored_position[0]), int(restored_position[1])) == Vector2i(10, 20), "placement persists after reload")
	check(DesktopPreferences.get_entry("crt", "different_pack").is_empty(), "same character id in different packs stays separate")
	DesktopPreferences.update_entry("chip", {"font":"missing.ttf"}, "test")
	check(DesktopPreferences.font_path("chip", "test") == AppearanceSettings.get_bubble_font_path(), "removed custom font falls back")
	var desktop_manager := DesktopCharacterManager.new()
	var ambient_controller := AmbientEventController.new()
	ambient_controller.character_manager = desktop_manager
	ambient_controller.mouse_idle_seconds = 200.0
	check(ambient_controller.should_offer_idle_reminder(), "prolonged idle can offer gentle reminder")
	desktop_manager.focus_timer_active = true
	check(ambient_controller.is_focusing() and not ambient_controller.should_offer_idle_reminder(), "focus takes priority over mouse inactivity")
	desktop_manager.focus_timer_paused = true
	check(not ambient_controller.is_focusing(), "paused timer permits ambient dialogue")
	ambient_controller.last_idle_reminder_msec = Time.get_ticks_msec()
	check(not ambient_controller.should_offer_idle_reminder(), "idle reminders have ten minute cooldown")
	ambient_controller.mouse_idle_seconds = 0.0
	ambient_controller.last_idle_reminder_msec = -600000
	check(not ambient_controller.should_offer_idle_reminder(), "active mouse receives ordinary dialogue")
	ambient_controller.free()
	desktop_manager.free()
	var crt_policy: Dictionary = CharacterProfiles.load_profile("crt").get("speech_policy", {})
	check(crt_policy.get("profanity_allowed", true) == false, "CRT profile forbids profanity")
	check(CharacterSpeechPolicy.apply_policy("씨발. Chip은 뭐 해?", crt_policy) == crt_policy["fallback"], "CRT profanity blocked at presentation")
	check(CharacterSpeechPolicy.apply_policy("씨.발", crt_policy) == crt_policy["fallback"], "punctuated profanity blocked")
	check(CharacterSpeechPolicy.apply_policy("시발점부터 보자.", crt_policy) == "시발점부터 보자.", "ordinary word not mistaken for profanity")
	check(CharacterSpeechPolicy.apply_policy("씨발", {}) == "씨발", "other characters receive no global profanity restriction")
	check(CharacterSpeechPolicy.apply_policy("Chip은 CRT가 좋아?", crt_policy) == "칩은 CRT양이 좋아?", "spoken names and particles normalized")
	check(CharacterSpeechPolicy.apply_policy("CRT양과 칩, CRT 모니터.", crt_policy) == "CRT양과 칩, CRT 모니터.", "correct names stay unchanged")
	check(CharacterProfiles.build_character_prompt("crt").contains("욕설"), "critical profile rules survive compact prompt")
	check(DesktopPreferences.update_entry("", {"position":[0,0]}) == ERR_INVALID_PARAMETER, "empty character id cannot overwrite shared placement")
	var available_bubbles := AppearanceSettings.get_available_bubbles()
	check(available_bubbles.filter(func(item: Dictionary) -> bool: return str(item.get("path", "")).get_file() == "default").size() == 1, "default bubble listed once")
	var restored_assets := ProjectSettings.globalize_path("user://tests/restored-default")
	BundledAssets.restore_tree("res://assets/bubbles/default", restored_assets)
	check(AppearanceSettings.is_bubble_skin_valid(restored_assets), "missing bubble files restored")
	AtomicFile.save_text(restored_assets.path_join("bubble.json"), "custom file")
	BundledAssets.restore_tree("res://assets/bubbles/default", restored_assets)
	check(FileAccess.get_file_as_string(restored_assets.path_join("bubble.json")) == "custom file", "asset recovery preserves existing customization")
	print("REGRESSION: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
