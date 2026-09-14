extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var manager := DesktopCharacterManager.new()
	manager.manual_preview_mode = true
	root.add_child(manager)
	await process_frame
	await process_frame
	print("HOST_BOUNDS ", root.size, " ", root.position)
	var valid := root.size == Vector2i.ONE and root.max_size == Vector2i.ONE and root.mouse_passthrough and root.position == manager.OFFSCREEN_WINDOW_POSITION
	manager.queue_free()
	await process_frame
	quit(0 if valid else 1)
