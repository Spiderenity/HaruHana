extends SceneTree

var failures := 0

func check(value: bool, label: String) -> void:
	print("BUBBLE_MENU ", "PASS " if value else "FAIL ", label)
	if not value:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var creator = load("res://system/tools/bubble_creator/scripts/main.gd").new()
	root.add_child(creator)
	await create_timer(0.5).timeout
	creator._start_new_bubble(true)
	creator.sprite_mode_selector.select(1)
	creator._on_sprite_mode_selected(1)
	creator.tabs.current_tab = 1
	await create_timer(0.5).timeout
	var rows: Control = creator.menu_preview_section
	check(rows.get_child_count() == 2 and rows.get_child(0).get_child_count() == 3 and rows.get_child(1).get_child_count() == 2, "preview has 3 + 2 buttons")
	for row in rows.get_children():
		var first: Control = row.get_child(0)
		var last: Control = row.get_child(row.get_child_count() - 1)
		check(absf((first.position.x + last.position.x + last.size.x) * 0.5 - row.size.x * 0.5) < 2.0, "preview row is centered")
	check(creator.paths.size() == 8 and not creator.paths.has("menu_week"), "editor has three segments and five menu images")
	var target := ProjectSettings.globalize_path("user://five-button-bubble")
	DirAccess.make_dir_recursive_absolute(target)
	check(creator._write_bubble_stage(target) == OK, "advanced bubble exports with five images")
	check(FileAccess.file_exists(target.path_join("menu_settings.png")) and not FileAccess.file_exists(target.path_join("menu_week.png")), "export omits obsolete weekly image")
	creator._on_bubble_file_selected(target.path_join("bubble.json"))
	check(creator._advanced_mode() and creator.menu_preview_images.size() == 5, "five-button bubble reloads in advanced mode")
	creator.queue_free()
	await process_frame
	print("BUBBLE_MENU_FAILURES ", failures)
	quit(1 if failures else 0)
