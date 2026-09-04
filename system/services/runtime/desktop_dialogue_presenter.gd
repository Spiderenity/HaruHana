extends RefCounted
class_name DesktopDialoguePresenter

var character_manager: DesktopCharacterManager = null

func configure(manager: DesktopCharacterManager) -> void:
	character_manager = manager

func show(
	character_id: String,
	text: String,
	mood: String = "neutral",
	duration: float = 8.0
) -> bool:
	var clean_text: String = text.strip_edges()
	if clean_text.is_empty() or character_manager == null:
		return false

	var actor: DesktopCharacterActor = character_manager.get_actor(character_id)
	if actor == null:
		return false

	actor.show_dialogue(
		{"text": clean_text, "mood": mood.strip_edges().to_lower()},
		duration
	)
	return true

func show_pack_line(
	character_id: String,
	line: Dictionary,
	duration: float
) -> bool:
	if line.is_empty():
		return false
	return show(
		character_id,
		str(line.get("text", "")),
		str(line.get("mood", "neutral")),
		duration
	)
