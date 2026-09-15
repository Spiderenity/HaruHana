extends SceneTree

var failures := 0

func check(value: bool, label: String) -> void:
	print("DROPDOWN_SCROLL ", "PASS " if value else "FAIL ", label)
	if not value:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var board = load("res://system/ui/board_window.gd").new()
	root.add_child(board)
	board.open_tab("Settings")
	await create_timer(0.5).timeout
	var selector: OptionButton = board.settings_panel.theme_selector
	var scroll: Node = selector.get_parent()
	while scroll != null and not scroll is ScrollContainer:
		scroll = scroll.get_parent()
	check(scroll != null, "main settings dropdown has scroll ancestor")
	if scroll != null:
		selector.get_popup().popup()
		await process_frame
		check(selector.get_popup().visible, "main settings dropdown opens")
		scroll.get_v_scroll_bar().value = 30
		await process_frame
		check(not selector.get_popup().visible, "main settings scroll closes dropdown")
	var calendar = board.calendar_panel
	var birthday: Dictionary = calendar.birthday_for_profile("test", {"display_name": "테스트", "birthday": {"month": 9, "day": 15}})
	check(birthday.get("title") == "테스트의 생일", "character birthday uses display name")
	check(calendar.birthday_for_profile("test", {}).is_empty(), "missing birthday is omitted")
	check(calendar.birthday_for_profile("test", {"birthday": {"month": 4, "day": 31}}).is_empty(), "invalid birthday is omitted")
	check(not calendar.birthday_for_profile("test", {"birthday": {"month": 2, "day": 29}}).is_empty(), "leap-day birthday is accepted")
	var saved_schedules: Array = calendar.schedules.duplicate(true)
	calendar.character_birthdays.assign([birthday])
	check(calendar._has_enabled_schedule_on_date(2026, 9, 15) and calendar._has_enabled_schedule_on_date(2027, 9, 15), "birthday marks calendar every year")
	calendar.display_year = 2026
	calendar.display_month = 9
	calendar.selected_day = 15
	calendar.refresh_selected_date_schedules()
	await process_frame
	var found := false
	for label in calendar.selected_date_schedule_box.find_children("*", "Label", true, false):
		if label.text == "테스트의 생일":
			found = true
	check(found, "selected date shows birthday text")
	check(calendar.schedules == saved_schedules, "birthdays do not alter saved schedules")
	calendar._load_character_birthdays()
	check(not calendar.character_birthdays.has(birthday), "refresh removes birthday from former pack")
	board.queue_free()
	await process_frame
	# Dynamically added pages also receive both axis handlers.
	var page := ScrollContainer.new()
	page.size = Vector2(200, 200)
	root.add_child(page)
	var content := Control.new()
	content.custom_minimum_size = Vector2(800, 800)
	page.add_child(content)
	var dropdown := OptionButton.new()
	content.add_child(dropdown)
	for i in range(50):
		dropdown.add_item("Item %d" % i)
	await process_frame
	await process_frame
	dropdown.get_popup().popup()
	await process_frame
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = Vector2(10, 10)
	dropdown.get_popup().push_input(wheel)
	await process_frame
	check(dropdown.get_popup().visible, "dropdown's own wheel keeps list open")
	page.get_h_scroll_bar().value = 20
	await process_frame
	check(not dropdown.get_popup().visible, "dynamic horizontal scrolling closes dropdown")
	dropdown.get_popup().popup()
	await process_frame
	page.get_v_scroll_bar().value = 20
	await process_frame
	check(not dropdown.get_popup().visible, "dynamic vertical scrolling closes dropdown")
	var menu := MenuButton.new()
	content.add_child(menu)
	menu.get_popup().add_item("2026")
	menu.get_popup().popup()
	await process_frame
	check(menu.get_popup().visible, "calendar-style dropdown opens")
	page.get_v_scroll_bar().value = 40
	await process_frame
	check(not menu.get_popup().visible, "calendar-style dropdown closes on scroll")
	page.queue_free()
	await process_frame
	print("DROPDOWN_SCROLL_FAILURES ", failures)
	quit(1 if failures else 0)
