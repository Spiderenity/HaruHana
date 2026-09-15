extends SceneTree

var failures := 0
var quit_actions := 0

func check(value: bool, label: String) -> void:
	print("DESKTOP_FEATURE ", "PASS " if value else "FAIL ", label)
	if not value:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var manager := DesktopCharacterManager.new()
	manager.manual_preview_mode = true
	root.add_child(manager)
	manager.reload_desktop_characters(false)
	await create_timer(2.0).timeout
	var crt := manager.get_actor("crt")
	var chip := manager.get_actor("chip")
	check(crt != null and chip != null, "both characters load")
	if crt == null or chip == null:
		quit(1)
		return
	print("DESKTOP_SCREEN_COUNT ", DisplayServer.get_screen_count())
	var settings := DesktopCharacterSettings.new()
	settings.configure(manager)
	root.add_child(settings)
	await process_frame
	check(settings.font_selectors.size() == 2 and settings.monitor_selectors.size() == 2, "per-character controls load")
	DesktopPreferences.update_entry("crt", {"font":"res://assets/fonts/NanumSquareRoundR.ttf"})
	DesktopPreferences.update_entry("chip", {"font":"res://assets/fonts/NanumSquareRoundL.ttf"})
	crt._apply_bubble_appearance(true)
	chip._apply_bubble_appearance(true)
	check(crt.speech_label.get_theme_font("font") != chip.speech_label.get_theme_font("font"), "separate fonts reach rendered labels")
	var interaction := chip.pet_interaction
	interaction.move_to_screen(DisplayServer.get_primary_screen())
	interaction.main_window.position.x += 50
	interaction.save_desktop_position()
	var expected := interaction.main_window.position
	interaction.main_window.position.x += 100
	check(interaction.restore_saved_position() and interaction.main_window.position == expected, "position restored on real window")
	var menu := crt.character_menu
	menu._rebuild_main_page(true)
	var row := menu.content_host.get_child(menu.content_host.get_child_count() - 1) as HBoxContainer
	check(row != null and row.get_child_count() == 2, "talk and quit share bottom row")
	if row != null:
		check(row.get_child(0).text in ["대화", "Talk"] and row.get_child(1).text in ["종료", "Quit"], "quit sits to the right of talk")
		manager.character_menu_talk_action_requested.connect(func(_id: String, action: String, _detail: String) -> void:
			if action == "quit":
				quit_actions += 1
		)
		row.get_child(1).pressed.emit()
		check(quit_actions == 1, "quit reaches main routing signal once")
	var usable := crt.get_desktop_usable_rect()
	check(Rect2(usable).encloses(crt.get_interaction_menu_rect(Vector2(276, 250))), "menu stays inside character monitor")
	crt.pet_interaction.main_window.position.x += 100
	crt.pet_interaction.save_desktop_position()
	var crt_position := crt.pet_interaction.main_window.position
	if DisplayServer.get_screen_count() > 1:
		chip.pet_interaction.move_to_screen((DisplayServer.get_primary_screen() + 1) % DisplayServer.get_screen_count())
	var chip_position := chip.pet_interaction.main_window.position
	check(DesktopPreferences.get_entry("crt").has("position") and DesktopPreferences.get_entry("chip").has("position"), "positions saved under separate character ids")
	DesktopPreferences._loaded = false
	manager.reload_desktop_characters(false)
	await create_timer(2.0).timeout
	var restored_crt := manager.get_actor("crt")
	var restored_chip := manager.get_actor("chip")
	check(restored_crt.pet_interaction.main_window.position.distance_to(crt_position) <= 1.0 and restored_chip.pet_interaction.main_window.position.distance_to(chip_position) <= 1.0, "cast recreation restores independent positions")
	DesktopPreferences.update_entry("chip", {"screen_origin":[-99999,-99999]})
	restored_chip.pet_interaction.restore_saved_position()
	check(restored_chip.pet_interaction.get_current_screen() == DisplayServer.get_primary_screen(), "disabled monitor returns character to primary")
	var default_left := restored_chip.pet_interaction.get_desktop_pet_rect().position.x
	check(absf(default_left - float(DisplayServer.screen_get_usable_rect(DisplayServer.get_primary_screen()).position.x + 80)) <= 1.0, "disabled monitor uses default left position")
	manager.reset_character_positions()
	check(DesktopPreferences.get_entry("crt").has("font"), "position reset preserves character font")
	DesktopPreferences.update_entry("crt", {"screen_origin":[-99999,-99999]})
	DesktopPreferences.update_entry("chip", {"screen_origin":[-99999,-99999]})
	manager.reload_desktop_characters(false)
	await create_timer(2.0).timeout
	var reset_crt := manager.get_actor("crt").get_desktop_pet_rect()
	var reset_chip := manager.get_actor("chip").get_desktop_pet_rect()
	check(reset_crt.position.x >= reset_chip.end.x, "cold start without saved monitor reserves room for both characters")
	var primary := manager.get_actor("crt")
	var secondary := manager.get_actor("chip")
	primary.configure_character_id("custom_primary")
	check(primary.character_menu._can_open_board(), "custom primary can open board")
	check(not secondary.character_menu._can_open_board(), "secondary has no board icons when primary is present")
	primary.configure_character_id("crt")
	manager.clear_spawned_characters()
	await process_frame
	var solo := manager.spawn_character("chip", 1, manager.get_current_pack_settings(manager.load_settings())) as DesktopCharacterActor
	await create_timer(1.0).timeout
	solo.configure_character_id("custom_solo")
	var solo_menu := solo.character_menu
	solo_menu._rebuild_main_page(true)
	var menu_rows := solo_menu.content_host.get_child(0)
	check(solo_menu._can_open_board() and menu_rows is VBoxContainer and menu_rows.get_child_count() == 2 and menu_rows.get_child(0).get_child_count() == 3 and menu_rows.get_child(1).get_child_count() == 2, "solo character gets five board icons in centered 3 + 2 rows")
	var tab_requests: Array[String] = []
	solo_menu.tab_requested.connect(func(tab: String) -> void: tab_requests.append(tab))
	solo_menu._on_tab_pressed("Timer")
	check(tab_requests == ["Timer"], "solo custom timer icon routes to board")
	solo.show_speech('{"mood":"neutral","text":"타이머 시작할게요~♪"}', 5.0)
	check(solo.speech_label.text == "타이머 시작할게요~♪", "visible speech label contains no serialized code")
	settings.queue_free()
	manager.queue_free()
	await process_frame
	await process_frame
	print("DESKTOP_FEATURE_FAILURES ", failures)
	quit(0 if failures == 0 else 1)
