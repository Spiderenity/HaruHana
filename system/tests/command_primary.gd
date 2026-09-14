extends SceneTree
var coordinator: RuntimeInstanceCoordinator
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	if not OS.get_user_data_dir().replace("\\", "/").contains("/work/validation/"):
		quit(1)
		return
	coordinator = RuntimeInstanceCoordinator.new()
	root.add_child(coordinator)
	if not coordinator.claim("haruhana"):
		quit(2)
		return
	coordinator.command_received.connect(func(action: String) -> void:
		FileAccess.open("user://command-received.txt", FileAccess.WRITE).store_string(action)
		quit(0)
	)
	FileAccess.open("user://primary-ready.txt", FileAccess.WRITE).store_string("ready")
	await create_timer(20).timeout
	quit(3)
