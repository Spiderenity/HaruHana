extends SceneTree

var failures := 0

func check(value: bool, label: String) -> void:
	print("TOUCH_REACTION ", "PASS " if value else "FAIL ", label)
	if not value:
		failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var play = load("res://system/services/desktop/desktop_character_play.gd").new()
	play.play_expression_map = {"embarrassed": "embarrassed", "curious": "curious"}
	for mood in ["neutral", "happy", "tired", "smug", "sad", "surprised"]:
		check(play._apply_play_expression_mood({"text": "테스트", "mood": mood})["mood"] == mood, "requested expression survives: " + mood)
	play.zone_expression_maps = {"face": {"curious": "surprised"}}
	check(play._apply_play_expression_mood({"mood": "curious"}, "face")["mood"] == "surprised", "explicit zone mapping retained")
	var lines: Array = []
	for index in range(9):
		lines.append({"text": str(index), "mood": "happy"})
	play.profile = {"pet_lines": lines}
	var counts := {}
	var previous := ""
	var repeated := false
	for index in range(90):
		var text: String = play._pick_pet_dialogue_stage(0, "head")["text"]
		repeated = repeated or text == previous
		previous = text
		counts[text] = counts.get(text, 0) + 1
	check(counts.size() == 9 and counts.values().all(func(count): return count == 10), "short petting uses all nine lines equally")
	check(not repeated, "no immediate repeat across shuffle cycles")
	play.profile["staged_pet_lines"] = true
	check(int(play._pick_pet_dialogue_stage(0, "head")["text"]) < 3, "authored staged reactions retain first band")
	play.free()
	var model = load("res://system/tools/character_creator/scripts/pack_model.gd").new()
	model.new_pack(1, true)
	var surprise: Dictionary = model.get_effective_sprite(0, "surprised")
	check(surprise["source"] in ["neutral", "eyes_open"], "basic preset surprise uses normal face")
	print("TOUCH_REACTION_FAILURES ", failures)
	quit(1 if failures else 0)
