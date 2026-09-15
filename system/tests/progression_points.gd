extends SceneTree

var failures := 0

func check(value: bool, label: String) -> void:
	print("PROGRESSION ", "PASS " if value else "FAIL ", label)
	if not value:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var progress = DesktopCharacterProgress
	JsonStore.save_json(progress.SAVE_PATH, {"version": 2, "friendship": {"test": 15}, "achievement": {"minutes": 90, "week_key": progress._current_week_key()}})
	check(progress.get_actual_friendship("test") == 15, "existing friendship is not converted")
	check(progress.get_actual_achievement_points() == 0 and progress.get_weekly_focus_minutes() == 90, "existing focus time is not converted to points")
	progress.set_achievement_points(9000)
	check(progress.get_actual_friendship("test") == 15 and progress.get_actual_achievement_points() == 9000, "saved points load without conversion")
	var state: Dictionary = progress._load_state()
	state["achievement"]["week_key"] = "2000-01-01"
	progress._save_state(state)
	check(progress.get_weekly_focus_minutes() == 0 and progress.get_actual_achievement_points() == 9000, "new week preserves accumulated points")
	progress._save_state(progress._default_state())
	var now := 1800000000
	check(progress.reward_activity("test", "attendance", now) == {"friendship": 100, "achievement": 150}, "attendance rewards")
	check(progress.reward_activity("test", "attendance", now + 60)["friendship"] == 0, "restart cannot duplicate attendance")
	check(progress.reward_activity("second", "attendance", now)["achievement"] == 0 and progress.get_actual_friendship("second") == 100, "two pets do not double global attendance achievement")
	check(progress.reward_activity("test", "chat", now)["friendship"] == 60, "chat reward")
	check(progress.reward_activity("test", "chat", now + 1)["friendship"] == 0, "chat interval")
	for index in range(20):
		progress.reward_activity("test", "chat", now + 20 * (index + 1))
	check(progress.get_actual_friendship("test") == 700, "chat daily cap")
	for index in range(20):
		progress.reward_activity("test", "pet", now + 30 * index)
	check(progress.get_actual_friendship("test") == 900, "pet daily cap")
	progress.reward_activity("test", "question", now)
	check(progress.get_actual_friendship("test") == 1000, "compatible answer gives 100 points")
	progress.reward_focus_completion("test", 25)
	check(progress.get_actual_friendship("test") == 1200 and progress.get_actual_achievement_points() == 2750, "25 minute completion rewards friendship and achievement")
	check(progress.get_weekly_focus_minutes() == 25, "actual focus minutes remain separate")
	progress.reward_focus_completion("test", 0)
	check(progress.get_actual_achievement_points() == 2750, "zero duration gives no points")
	check(progress.reward_activity("test", "attendance", now + 86400)["friendship"] == 100, "next day allows attendance")
	check(progress.reward_activity("test", "chat", now + 86400)["friendship"] == 60, "next day resets daily caps")
	progress.set_debug_achievement_level(3)
	check(progress.get_achievement_points() == 18000 and progress.get_actual_achievement_points() == 2900, "debug level does not alter earned points")
	check(progress.get_context("test")["weekly_focus_minutes"] == 25, "dialogue gets actual weekly minutes")
	print("PROGRESSION_FAILURES ", failures)
	quit(1 if failures else 0)
