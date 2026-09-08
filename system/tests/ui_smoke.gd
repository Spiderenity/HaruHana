extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/work/validation/"):
		quit(1)
		return
	var board := CompanionBoardWindow.new()
	root.add_child(board)
	for mode: String in ["light", "dark"]:
		AppearanceSettings.save_settings({"mode": mode})
		board._apply_appearance(true)
		for tab: String in ["Chat", "Timer", "Calendar", "Settings"]:
			if not board.open_tab(tab):
				printerr("UI_FAIL missing tab " + tab)
				quit(1)
				return
			await create_timer(0.4).timeout
			await RenderingServer.frame_post_draw
			var path := ProjectSettings.globalize_path("res://../work/validation/ui-" + mode + "-" + tab + ".png")
			board.get_texture().get_image().save_png(path)
			print("UI_CAPTURE " + mode + " " + tab + " " + str(board.size))
	board.queue_free()
	await process_frame
	quit()
