extends RefCounted
class_name CreatorPackModel

const PLACEHOLDER_PATH := "res://assets/placeholders/character_creator/transparent_400x600.png"
const PRESET_CRT_ROOT := "res://characters/crt_chip/sprites/crt"
const PRESET_CHIP_ROOT := "res://characters/crt_chip/sprites/chip"

const EMOTION_SLOTS: Array[String] = [
	"neutral", "happy", "amused", "smug", "curious", "surprised",
	"annoyed", "angry", "worried", "sad", "embarrassed", "tired",
	"flustered_worried", "flustered_surprised", "flustered_annoyed"
]
const BLINK_SLOTS: Array[String] = ["eyes_open", "eyes_half", "eyes_closed"]
const ALL_SPRITE_SLOTS: Array[String] = [
	"body", "neutral", "happy", "amused", "smug", "curious", "surprised",
	"annoyed", "angry", "worried", "sad", "embarrassed", "tired",
	"flustered_worried", "flustered_surprised", "flustered_annoyed",
	"eyes_open", "eyes_half", "eyes_closed"
]

const NATURAL_PRIMARY: Array[String] = [
	"body", "eyes_open", "eyes_half", "eyes_closed", "angry",
	"happy", "sad", "surprised", "embarrassed"
]

const PRESET_SLOT_ALIASES: Dictionary = {
	"neutral": "eyes_open",
	"annoyed": "angry",
	"tired": "sad",
	"flustered_surprised": "surprised",
	"flustered_annoyed": "angry"
}

var source_root: String = ""
var raw_manifest: Dictionary = {}
var pack_id: String = "character_1_character_2"
var display_name: String = "Character 1 & Character 2"
var description: String = ""
var default_language: String = "ko"
var supported_languages: Array[String] = ["ko"]
var characters: Array[Dictionary] = []
var parked_second_character: Dictionary = {}
var desktop_events: Dictionary = {}
var play_profiles: Dictionary = {}
var conversations: Array[Dictionary] = []
var secondary_locales: Dictionary = {}
var dirty: bool = false

func new_pack(character_count: int, use_preset_sprites: bool = true) -> void:
	source_root = ""
	raw_manifest = {}
	description = ""
	default_language = "ko"
	supported_languages = ["ko"]
	characters.clear()
	parked_second_character.clear()
	desktop_events = _default_desktop_events()
	play_profiles = _default_play_profiles()
	conversations.clear()
	secondary_locales.clear()

	var count: int = clampi(character_count, 1, 2)
	for index: int in range(count):
		var character_id: String = "character_%d" % (index + 1)
		var character_name: String = "Character %d" % (index + 1)
		var preset_root: String = ""
		if use_preset_sprites:
			preset_root = PRESET_CRT_ROOT if index == 0 else PRESET_CHIP_ROOT
		var default_chat_color: String = "#F6C543" if index == 0 else "#3A83F7"
		characters.append(_make_blank_character(
			character_id,
			character_name,
			preset_root,
			default_chat_color,
			index == 0
		))

	if count == 1:
		pack_id = "character_1"
		display_name = "Character 1"
	else:
		pack_id = "character_1_character_2"
		display_name = "Character 1 & Character 2"

	_sync_relationship_skeletons()
	dirty = false

func set_character_count(character_count: int) -> void:
	var count: int = clampi(character_count, 1, 2)
	if count == characters.size():
		return
	if count == 1 and characters.size() == 2:
		parked_second_character = characters.pop_back().duplicate(true)
	elif count == 2 and characters.size() == 1:
		if parked_second_character.is_empty():
			parked_second_character = _make_blank_character(
				"character_2",
				"Character 2",
				PRESET_CHIP_ROOT,
				"#3A83F7",
				false
			)
		characters.append(parked_second_character.duplicate(true))
	_sync_relationship_skeletons()
	dirty = true

func load_existing(manifest_path: String, preferred_language: String = "") -> Dictionary:
	var manifest_value: Variant = _read_json(manifest_path)
	if not (manifest_value is Dictionary):
		return {"ok": false, "message": "manifest.json을 읽을 수 없습니다."}

	var manifest: Dictionary = (manifest_value as Dictionary).duplicate(true)
	var entries_value: Variant = manifest.get("characters", [])
	if not (entries_value is Array):
		return {"ok": false, "message": "manifest.json의 characters가 배열이 아닙니다."}

	var entries: Array = entries_value as Array
	if entries.is_empty() or entries.size() > 2:
		return {"ok": false, "message": "현재 Creator는 1~2 캐릭터 팩만 지원합니다."}

	source_root = manifest_path.get_base_dir()
	raw_manifest = manifest
	pack_id = str(manifest.get("id", source_root.get_file())).strip_edges()
	display_name = str(manifest.get("display_name", pack_id)).strip_edges()
	description = str(manifest.get("description", ""))
	default_language = str(manifest.get("default_language", "ko")).strip_edges()
	if default_language.is_empty():
		default_language = "ko"

	supported_languages.clear()
	var languages_value: Variant = manifest.get("supported_languages", [default_language])
	if languages_value is Array:
		for value: Variant in languages_value:
			var language := str(value).strip_edges()
			if not language.is_empty() and not supported_languages.has(language):
				supported_languages.append(language)
	if supported_languages.is_empty():
		supported_languages.append(default_language)
	var preferred: String = preferred_language.strip_edges().to_lower()
	if supported_languages.has(preferred):
		default_language = preferred

	characters.clear()
	parked_second_character.clear()
	var locale_root := source_root.path_join("locales").path_join(default_language)
	for entry_index: int in range(entries.size()):
		var entry_value: Variant = entries[entry_index]
		if not (entry_value is Dictionary):
			continue
		var entry: Dictionary = entry_value as Dictionary
		var character_id := str(entry.get("id", "")).strip_edges().to_lower()
		if character_id.is_empty():
			continue
		var profile_path := locale_root.path_join(str(entry.get("profile_file", "%s/profile.json" % character_id)))
		var dialogue_path := locale_root.path_join(str(entry.get("dialogue_file", "%s/%s.json" % [character_id, character_id])))
		var profile_value: Variant = _read_json(profile_path)
		var dialogue_value: Variant = _read_json(dialogue_path)
		var profile: Dictionary = _default_profile(character_id, character_id)
		if profile_value is Dictionary:
			profile = (profile_value as Dictionary).duplicate(true)
		var dialogue: Dictionary = _default_dialogue()
		if dialogue_value is Dictionary:
			dialogue = (dialogue_value as Dictionary).duplicate(true)
		var sprites: Dictionary = _load_sprite_paths(source_root.path_join("sprites").path_join(character_id))
		var sprite_origins: Dictionary = {}
		for sprite_slot_value: Variant in sprites.keys():
			var sprite_slot: String = str(sprite_slot_value)
			var sprite_path: String = str(sprites.get(sprite_slot, ""))
			sprite_origins[sprite_slot] = _detect_loaded_sprite_origin(
				entry_index,
				sprite_slot,
				sprite_path
			)
		characters.append({
			"id": character_id,
			"profile": profile.duplicate(true),
			"dialogue": dialogue.duplicate(true),
			"sprite_mode": _infer_sprite_mode(sprites),
			"sprites": sprites,
			"sprite_origins": sprite_origins,
			"editor_mode": "advanced",
			"custom_chat_color": str(profile.get("chat_color", "#3A83F7")),
		})

	var desktop_value: Variant = _read_json(locale_root.path_join("desktop_events.json"))
	desktop_events = _default_desktop_events()
	if desktop_value is Dictionary:
		desktop_events = (desktop_value as Dictionary).duplicate(true)
	var play_value: Variant = _read_json(locale_root.path_join("play_profiles.json"))
	play_profiles = _default_play_profiles()
	if play_value is Dictionary:
		play_profiles = (play_value as Dictionary).duplicate(true)
	conversations.clear()
	var ambient_value: Variant = _read_json(locale_root.path_join("ambient_dialogue.json"))
	if ambient_value is Dictionary:
		var conversations_value: Variant = (ambient_value as Dictionary).get("conversations", [])
		if conversations_value is Array:
			for conversation_value: Variant in conversations_value as Array:
				if conversation_value is Dictionary:
					conversations.append((conversation_value as Dictionary).duplicate(true))
	secondary_locales.clear()
	for language: String in supported_languages:
		if language == default_language:
			continue
		var translated_root: String = source_root.path_join("locales").path_join(language)
		var translated_characters: Dictionary = {}
		var locale_complete: bool = true
		for entry_value: Variant in entries:
			if not (entry_value is Dictionary):
				locale_complete = false
				break
			var entry: Dictionary = entry_value as Dictionary
			var character_id: String = str(entry.get("id", "")).strip_edges().to_lower()
			var profile_value: Variant = _read_json(translated_root.path_join(str(entry.get("profile_file", "%s/profile.json" % character_id))))
			var dialogue_value: Variant = _read_json(translated_root.path_join(str(entry.get("dialogue_file", "%s/%s.json" % [character_id, character_id]))))
			if not (profile_value is Dictionary) or not (dialogue_value is Dictionary):
				locale_complete = false
				break
			translated_characters[character_id] = {
				"profile": (profile_value as Dictionary).duplicate(true),
				"dialogue": (dialogue_value as Dictionary).duplicate(true)
			}
		var translated_desktop: Variant = _read_json(translated_root.path_join("desktop_events.json"))
		var translated_play: Variant = _read_json(translated_root.path_join("play_profiles.json"))
		var translated_ambient: Variant = _read_json(translated_root.path_join("ambient_dialogue.json"))
		var translated_conversations: Variant = (
			(translated_ambient as Dictionary).get("conversations", [])
			if translated_ambient is Dictionary
			else []
		)
		if (
			not locale_complete
			or not (translated_desktop is Dictionary)
			or not (translated_play is Dictionary)
			or not (translated_ambient is Dictionary)
			or not (translated_conversations is Array)
		):
			continue
		secondary_locales[language] = {
			"characters": translated_characters,
			"desktop_events": (translated_desktop as Dictionary).duplicate(true),
			"play_profiles": (translated_play as Dictionary).duplicate(true),
			"conversations": (translated_conversations as Array).duplicate(true)
		}
	_ensure_pack_structures()
	dirty = false
	return {"ok": true, "message": "팩을 불러왔습니다."}

func get_character_count() -> int:
	return characters.size()

func get_character(index: int) -> Dictionary:
	if index < 0 or index >= characters.size():
		return {}
	return characters[index]

func set_character_id(index: int, new_id: String) -> bool:
	if index < 0 or index >= characters.size():
		return false
	var clean := _clean_id(new_id)
	if clean.is_empty():
		return false
	for other_index: int in range(characters.size()):
		if other_index == index:
			continue
		if str(characters[other_index].get("id", "")) == clean:
			return false
	var old_id := str(characters[index].get("id", ""))
	if clean == old_id:
		return true
	characters[index]["id"] = clean
	var profile: Dictionary = characters[index].get("profile", {})
	profile["id"] = clean
	characters[index]["profile"] = profile
	_rename_pack_character_keys(old_id, clean)
	for other_index: int in range(characters.size()):
		if other_index == index:
			continue
		var other_profile: Dictionary = characters[other_index].get("profile", {})
		var relationships: Dictionary = other_profile.get("relationships", {})
		if relationships.has(old_id):
			relationships[clean] = relationships[old_id]
			relationships.erase(old_id)
		other_profile["relationships"] = relationships
		characters[other_index]["profile"] = other_profile
	_sync_relationship_skeletons()
	dirty = true
	return true

func set_sprite_mode(index: int, mode: String) -> void:
	if index < 0 or index >= characters.size():
		return
	var clean := mode.strip_edges().to_lower()
	if not ["simple", "natural", "expressive"].has(clean):
		clean = "natural"
	characters[index]["sprite_mode"] = clean
	dirty = true

func set_sprite(index: int, slot: String, path: String) -> void:
	if index < 0 or index >= characters.size():
		return
	if not ALL_SPRITE_SLOTS.has(slot):
		return
	var sprites: Dictionary = characters[index].get("sprites", {})
	var origins: Dictionary = characters[index].get("sprite_origins", {})
	sprites[slot] = path
	origins[slot] = "uploaded"
	characters[index]["sprites"] = sprites
	characters[index]["sprite_origins"] = origins
	dirty = true

func clear_sprite(index: int, slot: String) -> void:
	if index < 0 or index >= characters.size():
		return
	var sprites: Dictionary = characters[index].get("sprites", {})
	var origins: Dictionary = characters[index].get("sprite_origins", {})
	sprites.erase(slot)
	origins.erase(slot)
	characters[index]["sprites"] = sprites
	characters[index]["sprite_origins"] = origins
	dirty = true

func get_sprite_path(index: int, slot: String) -> String:
	if index < 0 or index >= characters.size():
		return ""
	var sprites: Dictionary = characters[index].get("sprites", {})
	return str(sprites.get(slot, ""))

func get_sprite_origin(index: int, slot: String) -> String:
	if index < 0 or index >= characters.size():
		return ""
	var origins: Dictionary = characters[index].get("sprite_origins", {})
	return str(origins.get(slot, ""))

func get_required_sprite_slots(index: int) -> Array[String]:
	if index < 0 or index >= characters.size():
		return []
	var mode: String = str(characters[index].get("sprite_mode", "natural"))
	match mode:
		"simple":
			return ["body", "eyes_open"]
		"expressive":
			return ALL_SPRITE_SLOTS.duplicate()
		_:
			return NATURAL_PRIMARY.duplicate()

func get_sprite_save_warnings() -> Array[Dictionary]:
	var warnings: Array[Dictionary] = []
	for character_index: int in range(characters.size()):
		var character_id: String = str(characters[character_index].get("id", "character_%d" % (character_index + 1)))
		for slot: String in get_required_sprite_slots(character_index):
			var path: String = get_sprite_path(character_index, slot)
			var origin: String = get_sprite_origin(character_index, slot)
			if origin == "default" or not _is_usable_sprite_path(path):
				warnings.append({"character": character_id, "slot": slot, "kind": "missing"})
	return warnings

func get_effective_sprite(index: int, slot: String) -> Dictionary:
	var direct: String = get_sprite_path(index, slot)
	var uses_preset_alias: bool = (
		PRESET_SLOT_ALIASES.has(slot)
		and get_sprite_origin(index, slot) == "default"
	)
	if (
		_is_direct_slot_allowed(index, slot)
		and not uses_preset_alias
		and _is_usable_sprite_path(direct)
	):
		return {"path": direct, "source": slot, "fallback": false}
	for candidate: String in _fallback_chain(slot):
		if not _is_direct_slot_allowed(index, candidate):
			continue
		var candidate_path: String = get_sprite_path(index, candidate)
		if _is_usable_sprite_path(candidate_path):
			return {"path": candidate_path, "source": candidate, "fallback": true}
	if slot != "body" and slot != "neutral" and _is_direct_slot_allowed(index, "neutral"):
		var neutral_path: String = get_sprite_path(index, "neutral")
		if _is_usable_sprite_path(neutral_path):
			return {"path": neutral_path, "source": "neutral", "fallback": true}
	if slot != "body" and slot != "eyes_open" and _is_direct_slot_allowed(index, "eyes_open"):
		var eyes_open_path: String = get_sprite_path(index, "eyes_open")
		if _is_usable_sprite_path(eyes_open_path):
			return {"path": eyes_open_path, "source": "eyes_open", "fallback": true}
	return {"path": PLACEHOLDER_PATH, "source": "placeholder", "fallback": true}

func get_export_sprite(index: int, slot: String) -> Dictionary:
	var direct: String = get_sprite_path(index, slot)
	if (
		_is_direct_slot_allowed(index, slot)
		and get_sprite_origin(index, slot) != "default"
		and _is_usable_sprite_path(direct)
	):
		return {"path": direct, "source": slot, "fallback": false}
	for candidate: String in _fallback_chain(slot):
		if not _is_direct_slot_allowed(index, candidate):
			continue
		if get_sprite_origin(index, candidate) == "default":
			continue
		var candidate_path: String = get_sprite_path(index, candidate)
		if _is_usable_sprite_path(candidate_path):
			return {"path": candidate_path, "source": candidate, "fallback": true}
	if slot != "body" and slot != "eyes_open" and _is_direct_slot_allowed(index, "eyes_open"):
		var eyes_open_path: String = get_sprite_path(index, "eyes_open")
		if (
			get_sprite_origin(index, "eyes_open") != "default"
			and _is_usable_sprite_path(eyes_open_path)
		):
			return {"path": eyes_open_path, "source": "eyes_open", "fallback": true}
	return {"path": PLACEHOLDER_PATH, "source": "placeholder", "fallback": true}

func _is_direct_slot_allowed(index: int, slot: String) -> bool:
	if index < 0 or index >= characters.size():
		return false
	var mode := str(characters[index].get("sprite_mode", "natural"))
	match mode:
		"simple":
			return ["body", "eyes_open"].has(slot)
		"natural":
			return NATURAL_PRIMARY.has(slot)
		_:
			return ALL_SPRITE_SLOTS.has(slot)

func validate_sprite_file(path: String) -> Dictionary:
	if path.get_extension().to_lower() != "png":
		return {"ok": false, "message": "PNG 파일만 사용할 수 있습니다."}
	var image := Image.new()
	var error := image.load(path)
	if error != OK:
		return {"ok": false, "message": "PNG 이미지를 읽을 수 없습니다."}
	if image.get_width() != 400 or image.get_height() != 600:
		return {
			"ok": false,
			"message": "이미지는 정확히 400×600이어야 합니다. 현재 %d×%d입니다." % [image.get_width(), image.get_height()]
		}
	var has_transparent_pixel := false
	for y: int in range(0, image.get_height(), 2):
		for x: int in range(0, image.get_width(), 2):
			if image.get_pixel(x, y).a < 0.999:
				has_transparent_pixel = true
				break
		if has_transparent_pixel:
			break
	if not has_transparent_pixel:
		return {"ok": false, "message": "투명 배경이 있는 RGBA PNG가 필요합니다."}
	return {"ok": true, "message": "400×600 투명 PNG"}

func get_line_groups(character_index: int) -> Array[Dictionary]:
	if character_index < 0 or character_index >= characters.size():
		return []
	var character_id := str(characters[character_index].get("id", ""))
	return [
		{"id": "first_boot", "label": "첫 부팅", "scope": "dialogue", "path": ["first_boot", "lines"]},
		{"id": "idle", "label": "대기", "scope": "dialogue", "path": ["fallback_dialogue", "idle"]},
		{"id": "timer_complete", "label": "타이머 완료", "scope": "dialogue", "path": ["fallback_dialogue", "timer_complete"]},
		{"id": "timer_pause", "label": "타이머 일시정지", "scope": "dialogue", "path": ["fallback_dialogue", "timer_pause"]},
		{"id": "timer_resume", "label": "타이머 재개", "scope": "dialogue", "path": ["fallback_dialogue", "timer_resume"]},
		{"id": "timer_stop", "label": "타이머 중단", "scope": "dialogue", "path": ["fallback_dialogue", "timer_stop"]},
		{"id": "desktop_leave", "label": "데스크톱 떠남", "scope": "dialogue", "path": ["fallback_dialogue", "desktop_leave"]},
		{"id": "desktop_arrive", "label": "데스크톱 도착", "scope": "dialogue", "path": ["fallback_dialogue", "desktop_arrive"]},
		{"id": "boot_primary", "label": "부팅 기본", "scope": "desktop", "path": ["boot", "primary_lines", character_id]},
		{"id": "boot_arrival", "label": "합류", "scope": "desktop", "path": ["boot", "arrival_lines", character_id]},
		{"id": "boot_peer", "label": "동료 합류 후", "scope": "desktop", "path": ["boot", "peer_after_arrival_lines", character_id]},
		{"id": "hourly_morning", "label": "정시 · 아침", "scope": "desktop", "path": ["hourly", "characters", character_id, "morning"]},
		{"id": "hourly_day", "label": "정시 · 낮", "scope": "desktop", "path": ["hourly", "characters", character_id, "day"]},
		{"id": "hourly_evening", "label": "정시 · 저녁", "scope": "desktop", "path": ["hourly", "characters", character_id, "evening"]},
		{"id": "hourly_late", "label": "정시 · 심야", "scope": "desktop", "path": ["hourly", "characters", character_id, "late_night"]},
		{"id": "pet", "label": "터치", "scope": "play", "path": ["characters", character_id, "pet_lines"]},
		{"id": "poke_head", "label": "찌르기 · head", "scope": "play", "path": ["characters", character_id, "poke_lines", "head"]},
		{"id": "fluster", "label": "과부하 / 당황", "scope": "play", "path": ["characters", character_id, "fluster_lines"]},
	]

func get_line_group(character_index: int, group_id: String) -> Array[Dictionary]:
	for group: Dictionary in get_line_groups(character_index):
		if str(group.get("id", "")) != group_id:
			continue
		var value: Variant = _get_group_value(character_index, group)
		return _normalize_line_array(value)
	return []

func set_line_group(character_index: int, group_id: String, lines: Array[Dictionary]) -> void:
	for group: Dictionary in get_line_groups(character_index):
		if str(group.get("id", "")) != group_id:
			continue
		_set_group_value(character_index, group, lines.duplicate(true))
		dirty = true
		return

func apply_generated_groups(character_index: int, groups: Dictionary) -> int:
	var applied := 0
	for group: Dictionary in get_line_groups(character_index):
		var group_id := str(group.get("id", ""))
		if not groups.has(group_id):
			continue
		if not get_line_group(character_index, group_id).is_empty():
			continue
		var lines := _normalize_line_array(groups[group_id])
		if lines.is_empty():
			continue
		_set_group_value(character_index, group, lines)
		applied += 1
	if applied > 0:
		dirty = true
	return applied

func apply_generated_conversations(generated: Array) -> int:
	if not conversations.is_empty():
		return 0
	var normalized: Array[Dictionary] = []
	var character_ids: Array[String] = []
	for character: Dictionary in characters:
		character_ids.append(str(character.get("id", "")))
	for conversation_value: Variant in generated:
		if not (conversation_value is Dictionary):
			continue
		var conversation: Dictionary = conversation_value as Dictionary
		var turns_value: Variant = conversation.get("turns", [])
		if not (turns_value is Array):
			continue
		var turns: Array[Dictionary] = []
		var speakers: Array[String] = []
		for turn_value: Variant in turns_value as Array:
			if not (turn_value is Dictionary):
				turns.clear()
				break
			var turn: Dictionary = turn_value as Dictionary
			var speaker: String = str(turn.get("speaker", "")).strip_edges().to_lower()
			var text: String = str(turn.get("text", "")).strip_edges()
			if not character_ids.has(speaker) or text.is_empty():
				turns.clear()
				break
			if not speakers.has(speaker):
				speakers.append(speaker)
			turns.append({
				"speaker": speaker,
				"text": text,
				"mood": str(turn.get("mood", "neutral")).strip_edges().to_lower()
			})
		if turns.size() < 2 or turns.size() > 5 or speakers.size() < 2:
			continue
		normalized.append({"turns": turns})
	if normalized.is_empty():
		return 0
	conversations = normalized
	dirty = true
	return conversations.size()

func set_secondary_locale(language: String, locale_data: Dictionary) -> void:
	var clean: String = language.strip_edges().to_lower()
	if clean.is_empty() or locale_data.is_empty():
		return
	secondary_locales[clean] = locale_data.duplicate(true)
	dirty = true

func export_to(parent_directory: String) -> Dictionary:
	var clean_pack_id := _clean_id(pack_id)
	if clean_pack_id.is_empty():
		return {"ok": false, "message": "Pack ID가 비어 있습니다."}
	if characters.is_empty():
		return {"ok": false, "message": "캐릭터가 없습니다."}

	pack_id = clean_pack_id
	var target_root := parent_directory.path_join(pack_id)
	var locale_root := target_root.path_join("locales").path_join(default_language)
	_make_dir_recursive(locale_root)
	_make_dir_recursive(target_root.path_join("sprites"))

	var manifest := raw_manifest.duplicate(true)
	manifest["id"] = pack_id
	manifest["display_name"] = display_name
	manifest["description"] = description
	manifest["default_language"] = default_language
	manifest["supported_languages"] = supported_languages.duplicate()
	var entries: Array = []

	_ensure_pack_structures()
	for character_index: int in range(characters.size()):
		var character: Dictionary = characters[character_index]
		var character_id := _clean_id(str(character.get("id", "")))
		if character_id.is_empty():
			return {"ok": false, "message": "캐릭터 %d의 ID가 비어 있습니다." % (character_index + 1)}
		var profile: Dictionary = (character.get("profile", {}) as Dictionary).duplicate(true)
		profile["id"] = character_id
		var character_locale := locale_root.path_join(character_id)
		_make_dir_recursive(character_locale)
		if not _write_json(character_locale.path_join("profile.json"), profile):
			return {"ok": false, "message": "프로필 파일을 저장하지 못했습니다: %s" % character_id}
		if not _write_json(character_locale.path_join("%s.json" % character_id), character.get("dialogue", {})):
			return {"ok": false, "message": "대사 파일을 저장하지 못했습니다: %s" % character_id}
		entries.append({
			"id": character_id,
			"profile_file": "%s/profile.json" % character_id,
			"dialogue_file": "%s/%s.json" % [character_id, character_id],
		})

		var sprite_root := target_root.path_join("sprites").path_join(character_id)
		_make_dir_recursive(sprite_root)
		for slot: String in ALL_SPRITE_SLOTS:
			var effective := get_export_sprite(character_index, slot)
			var source_path := str(effective.get("path", PLACEHOLDER_PATH))
			var destination_path: String = sprite_root.path_join("%s.png" % slot)
			if source_path == PLACEHOLDER_PATH:
				_remove_file(destination_path)
			elif not _copy_file(source_path, destination_path):
				return {"ok": false, "message": "스프라이트 파일을 저장하지 못했습니다: %s/%s" % [character_id, slot]}

	manifest["characters"] = entries
	if not _write_json(target_root.path_join("manifest.json"), manifest):
		return {"ok": false, "message": "manifest.json을 저장하지 못했습니다."}
	if not _write_json(locale_root.path_join("desktop_events.json"), desktop_events):
		return {"ok": false, "message": "desktop_events.json을 저장하지 못했습니다."}
	if not _write_json(locale_root.path_join("play_profiles.json"), play_profiles):
		return {"ok": false, "message": "play_profiles.json을 저장하지 못했습니다."}
	if not _write_json(locale_root.path_join("ambient_dialogue.json"), {"conversations": conversations}):
		return {"ok": false, "message": "ambient_dialogue.json을 저장하지 못했습니다."}
	if not _export_secondary_locales(target_root):
		return {"ok": false, "message": "추가 로캘 파일을 저장하지 못했습니다."}
	dirty = false
	return {"ok": true, "message": "내보냈습니다: %s" % target_root, "path": target_root}

func _export_secondary_locales(target_root: String) -> bool:
	for language_value: Variant in secondary_locales.keys():
		var language: String = str(language_value)
		if language == default_language or not supported_languages.has(language):
			continue
		var locale_data: Dictionary = secondary_locales.get(language, {})
		var translated_root: String = target_root.path_join("locales").path_join(language)
		var translated_characters: Dictionary = locale_data.get("characters", {})
		for character: Dictionary in characters:
			var character_id: String = str(character.get("id", ""))
			var character_data: Dictionary = translated_characters.get(character_id, {})
			var character_root: String = translated_root.path_join(character_id)
			if not _write_json(character_root.path_join("profile.json"), character_data.get("profile", character.get("profile", {}))):
				return false
			if not _write_json(character_root.path_join("%s.json" % character_id), character_data.get("dialogue", character.get("dialogue", {}))):
				return false
		if not _write_json(translated_root.path_join("desktop_events.json"), locale_data.get("desktop_events", desktop_events)):
			return false
		if not _write_json(translated_root.path_join("play_profiles.json"), locale_data.get("play_profiles", play_profiles)):
			return false
		if not _write_json(translated_root.path_join("ambient_dialogue.json"), {
			"conversations": locale_data.get("conversations", conversations)
		}):
			return false
	return true

func save_over_existing() -> Dictionary:
	if source_root.is_empty():
		return {"ok": false, "message": "기존 팩으로 불러온 프로젝트가 아닙니다. 내보내기를 사용하세요."}
	return export_to(source_root.get_base_dir())

func _make_blank_character(
	character_id: String,
	name: String,
	preset_root: String,
	chat_color: String,
	default_on_desktop: bool
) -> Dictionary:
	var sprites: Dictionary = {}
	var sprite_origins: Dictionary = {}
	for slot: String in ALL_SPRITE_SLOTS:
		var path: String = preset_root.path_join("%s.png" % slot)
		if _file_exists(path):
			sprites[slot] = path
			sprite_origins[slot] = "default"
	for alias_value: Variant in PRESET_SLOT_ALIASES.keys():
		var alias_slot: String = str(alias_value)
		var source_slot: String = str(PRESET_SLOT_ALIASES[alias_value])
		if sprites.has(source_slot):
			sprites[alias_slot] = sprites[source_slot]
			sprite_origins[alias_slot] = "default"
	var profile: Dictionary = _default_profile(character_id, name)
	profile["chat_color"] = chat_color
	profile["desktop"] = {"default_on_desktop": default_on_desktop}
	return {
		"id": character_id,
		"profile": profile,
		"dialogue": _default_dialogue(),
		"sprite_mode": "natural",
		"sprites": sprites,
		"sprite_origins": sprite_origins,
		"editor_mode": "simple",
		"custom_chat_color": "#7F8E79",
	}

func _default_profile(character_id: String, name: String) -> Dictionary:
	return {
		"id": character_id,
		"display_name": name,
		"birthday": {},
		"chat_color": "#3A83F7",
		"desktop": {"default_on_desktop": true},
		"identity": {"role": "", "setting_note": ""},
		"appearance": {"summary": ""},
		"core_personality": [],
		"voice": {"casual": "", "avoid": []},
		"behavior_patterns": [],
		"mundane_details": [],
		"relationships": {},
		"private_internal": [],
		"user_entity": {"role": "", "description": ""},
		"ai_behavior_rules": [],
		"lore": [],
	}

func get_editor_mode(index: int) -> String:
	if index < 0 or index >= characters.size():
		return "advanced"
	return str(characters[index].get("editor_mode", "advanced"))

func set_editor_mode(index: int, mode: String) -> void:
	if index < 0 or index >= characters.size():
		return
	var clean: String = mode.strip_edges().to_lower()
	if not ["simple", "advanced"].has(clean):
		clean = "advanced"
	characters[index]["editor_mode"] = clean

func get_custom_chat_color(index: int) -> String:
	if index < 0 or index >= characters.size():
		return "#7F8E79"
	return str(characters[index].get("custom_chat_color", "#7F8E79"))

func set_custom_chat_color(index: int, color_value: String) -> void:
	if index < 0 or index >= characters.size():
		return
	characters[index]["custom_chat_color"] = color_value.strip_edges()

func get_missing_advanced_profile_fields(index: int) -> Array[String]:
	var missing: Array[String] = []
	if index < 0 or index >= characters.size():
		return missing
	var profile: Dictionary = characters[index].get("profile", {})
	var identity: Dictionary = profile.get("identity", {})
	var voice: Dictionary = profile.get("voice", {})
	if str(identity.get("setting_note", "")).strip_edges().is_empty(): missing.append("setting_note")
	if _array_is_empty(voice.get("avoid", [])): missing.append("voice_avoid")
	if _array_is_empty(profile.get("behavior_patterns", [])): missing.append("behavior_patterns")
	if _array_is_empty(profile.get("mundane_details", [])): missing.append("mundane_details")
	if _array_is_empty(profile.get("private_internal", [])): missing.append("private_internal")
	if _array_is_empty(profile.get("ai_behavior_rules", [])): missing.append("ai_behavior_rules")
	if _array_is_empty(profile.get("lore", [])): missing.append("lore")
	return missing

func apply_generated_profile_fields(index: int, generated: Dictionary) -> int:
	if index < 0 or index >= characters.size():
		return 0
	var profile: Dictionary = characters[index].get("profile", {})
	var applied: int = 0
	var identity: Dictionary = profile.get("identity", {})
	if str(identity.get("setting_note", "")).strip_edges().is_empty():
		var setting_note: String = str(generated.get("setting_note", "")).strip_edges()
		if not setting_note.is_empty():
			identity["setting_note"] = setting_note
			applied += 1
	profile["identity"] = identity

	var voice: Dictionary = profile.get("voice", {})
	if _array_is_empty(voice.get("avoid", [])):
		var avoid: Array[String] = _variant_to_string_array(generated.get("voice_avoid", []))
		if not avoid.is_empty():
			voice["avoid"] = avoid
			applied += 1
	profile["voice"] = voice

	for key: String in ["behavior_patterns", "mundane_details", "private_internal", "ai_behavior_rules", "lore"]:
		if _array_is_empty(profile.get(key, [])):
			var values: Array[String] = _variant_to_string_array(generated.get(key, []))
			if not values.is_empty():
				profile[key] = values
				applied += 1

	characters[index]["profile"] = profile
	if applied > 0:
		dirty = true
	return applied

func _array_is_empty(value: Variant) -> bool:
	return not (value is Array) or (value as Array).is_empty()

func _variant_to_string_array(value: Variant) -> Array[String]:
	var output: Array[String] = []
	if value is Array:
		for item: Variant in value as Array:
			var text: String = str(item).strip_edges()
			if not text.is_empty(): output.append(text)
	elif value is String:
		var text: String = str(value).strip_edges()
		if not text.is_empty(): output.append(text)
	return output

func _default_dialogue() -> Dictionary:
	return {
		"first_boot": {"lines": []},
		"fallback_dialogue": {
			"idle": [], "timer_complete": [], "timer_pause": [], "timer_resume": [],
			"timer_stop": [], "desktop_leave": [], "desktop_arrive": []
		}
	}

func _default_desktop_events() -> Dictionary:
	return {
		"boot": {
			"secondary_delay_seconds": 4.0,
			"primary_lines": {}, "arrival_lines": {}, "peer_after_arrival_lines": {}
		},
		"hourly": {"characters": {}}
	}

func _default_play_profiles() -> Dictionary:
	return {
		"default": {
			"fluster_moods": ["embarrassed", "surprised"],
			"play_expression_map": {
				"embarrassed": "embarrassed", "curious": "curious", "surprised": "surprised"
			}
		},
		"characters": {}
	}

func _ensure_pack_structures() -> void:
	if not desktop_events.has("boot") or not (desktop_events["boot"] is Dictionary):
		desktop_events["boot"] = {}
	var boot: Dictionary = desktop_events["boot"]
	for key: String in ["primary_lines", "arrival_lines", "peer_after_arrival_lines"]:
		if not boot.has(key) or not (boot[key] is Dictionary):
			boot[key] = {}
	if not boot.has("secondary_delay_seconds"):
		boot["secondary_delay_seconds"] = 4.0
	desktop_events["boot"] = boot
	if not desktop_events.has("hourly") or not (desktop_events["hourly"] is Dictionary):
		desktop_events["hourly"] = {"characters": {}}
	var hourly: Dictionary = desktop_events["hourly"]
	if not hourly.has("characters") or not (hourly["characters"] is Dictionary):
		hourly["characters"] = {}
	desktop_events["hourly"] = hourly
	if not play_profiles.has("characters") or not (play_profiles["characters"] is Dictionary):
		play_profiles["characters"] = {}
	for character: Dictionary in characters:
		var character_id := str(character.get("id", ""))
		for key: String in ["primary_lines", "arrival_lines", "peer_after_arrival_lines"]:
			var map: Dictionary = boot[key]
			if not map.has(character_id):
				map[character_id] = []
			boot[key] = map
		var hourly_characters: Dictionary = hourly["characters"]
		if not hourly_characters.has(character_id) or not (hourly_characters[character_id] is Dictionary):
			hourly_characters[character_id] = {"morning": [], "day": [], "evening": [], "late_night": []}
		else:
			var periods: Dictionary = hourly_characters[character_id]
			for period: String in ["morning", "day", "evening", "late_night"]:
				if not periods.has(period):
					periods[period] = []
			hourly_characters[character_id] = periods
		hourly["characters"] = hourly_characters
		var play_characters: Dictionary = play_profiles["characters"]
		if not play_characters.has(character_id) or not (play_characters[character_id] is Dictionary):
			play_characters[character_id] = {
				"touch_zones": [{"id": "head", "rect": [0.0, 0.0, 1.0, 0.5]}],
				"pet_lines": [], "poke_lines": {"head": []}, "fluster_lines": []
			}
		play_profiles["characters"] = play_characters
	desktop_events["boot"] = boot
	desktop_events["hourly"] = hourly

func _sync_relationship_skeletons() -> void:
	for index: int in range(characters.size()):
		var profile: Dictionary = characters[index].get("profile", {})
		var relationships: Dictionary = profile.get("relationships", {})
		var valid_ids: Array[String] = []
		for other_index: int in range(characters.size()):
			if other_index == index:
				continue
			var other_id := str(characters[other_index].get("id", ""))
			valid_ids.append(other_id)
			if not relationships.has(other_id):
				relationships[other_id] = {"summary": ""}
		for key: Variant in relationships.keys():
			if not valid_ids.has(str(key)):
				relationships.erase(key)
		profile["relationships"] = relationships
		characters[index]["profile"] = profile

func _rename_pack_character_keys(old_id: String, new_id: String) -> void:
	_ensure_pack_structures()
	var boot: Dictionary = desktop_events.get("boot", {})
	for key: String in ["primary_lines", "arrival_lines", "peer_after_arrival_lines"]:
		var map: Dictionary = boot.get(key, {})
		if map.has(old_id):
			map[new_id] = map[old_id]
			map.erase(old_id)
		boot[key] = map
	desktop_events["boot"] = boot
	var hourly: Dictionary = desktop_events.get("hourly", {})
	var hourly_chars: Dictionary = hourly.get("characters", {})
	if hourly_chars.has(old_id):
		hourly_chars[new_id] = hourly_chars[old_id]
		hourly_chars.erase(old_id)
	hourly["characters"] = hourly_chars
	desktop_events["hourly"] = hourly
	var play_chars: Dictionary = play_profiles.get("characters", {})
	if play_chars.has(old_id):
		play_chars[new_id] = play_chars[old_id]
		play_chars.erase(old_id)
	play_profiles["characters"] = play_chars

func _get_group_value(character_index: int, group: Dictionary) -> Variant:
	var scope := str(group.get("scope", ""))
	var path: Array = group.get("path", [])
	match scope:
		"dialogue":
			return _dict_get_path(characters[character_index].get("dialogue", {}), path)
		"desktop":
			return _dict_get_path(desktop_events, path)
		"play":
			return _dict_get_path(play_profiles, path)
	return []

func _set_group_value(character_index: int, group: Dictionary, value: Variant) -> void:
	var scope := str(group.get("scope", ""))
	var path: Array = group.get("path", [])
	match scope:
		"dialogue":
			var dictionary: Dictionary = characters[character_index].get("dialogue", {})
			_dict_set_path(dictionary, path, value)
			characters[character_index]["dialogue"] = dictionary
		"desktop":
			_dict_set_path(desktop_events, path, value)
		"play":
			_dict_set_path(play_profiles, path, value)

func _dict_get_path(dictionary: Dictionary, path: Array) -> Variant:
	var current: Variant = dictionary
	for key_value: Variant in path:
		if not (current is Dictionary):
			return []
		var current_dict: Dictionary = current as Dictionary
		var key := str(key_value)
		if not current_dict.has(key):
			return []
		current = current_dict[key]
	return current

func _dict_set_path(dictionary: Dictionary, path: Array, value: Variant) -> void:
	if path.is_empty():
		return
	var current: Dictionary = dictionary
	for index: int in range(path.size() - 1):
		var key := str(path[index])
		var child: Dictionary = {}
		if current.has(key) and current[key] is Dictionary:
			child = current[key]
		current[key] = child
		current = child
	current[str(path[path.size() - 1])] = value

func _normalize_line_array(value: Variant) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	if not (value is Array):
		return output
	for item: Variant in value as Array:
		if item is Dictionary:
			var text := str((item as Dictionary).get("text", "")).strip_edges()
			if text.is_empty():
				continue
			output.append({"text": text, "mood": str((item as Dictionary).get("mood", "neutral")).strip_edges().to_lower()})
		else:
			var text := str(item).strip_edges()
			if not text.is_empty():
				output.append({"text": text, "mood": "neutral"})
	return output

func _load_sprite_paths(sprite_root: String) -> Dictionary:
	var sprites: Dictionary = {}
	for slot: String in ALL_SPRITE_SLOTS:
		var path := sprite_root.path_join("%s.png" % slot)
		if _file_exists(path):
			sprites[slot] = path
	return sprites

func _infer_sprite_mode(sprites: Dictionary) -> String:
	var expressive_count := 0
	for slot: String in ALL_SPRITE_SLOTS:
		if sprites.has(slot):
			expressive_count += 1
	if expressive_count >= 14:
		return "expressive"
	var natural_count := 0
	for slot: String in NATURAL_PRIMARY:
		if sprites.has(slot):
			natural_count += 1
	if natural_count >= 5:
		return "natural"
	return "simple"

func _detect_loaded_sprite_origin(
	character_index: int,
	slot: String,
	path: String
) -> String:
	if not _file_exists(path):
		return ""
	var preset_root: String = PRESET_CRT_ROOT if character_index == 0 else PRESET_CHIP_ROOT
	var preset_path: String = preset_root.path_join("%s.png" % slot)
	if _same_sprite_content(path, preset_path):
		return "default"
	return "existing"

func _same_sprite_content(first_path: String, second_path: String) -> bool:
	if not _file_exists(first_path) or not _file_exists(second_path):
		return false
	var first_hash: String = FileAccess.get_sha256(first_path)
	var second_hash: String = FileAccess.get_sha256(second_path)
	if not first_hash.is_empty() and first_hash == second_hash:
		return true
	var first_image: Image = _load_sprite_image(first_path)
	var second_image: Image = _load_sprite_image(second_path)
	if first_image == null or second_image == null:
		return false
	return (
		first_image.get_size() == second_image.get_size()
		and first_image.get_format() == second_image.get_format()
		and first_image.get_data() == second_image.get_data()
	)

func _is_usable_sprite_path(path: String) -> bool:
	if path.is_empty() or not _file_exists(path):
		return false
	var image: Image = _load_sprite_image(path)
	if image == null:
		return false
	return image.get_width() > 0 and image.get_height() > 0

func _load_sprite_image(path: String) -> Image:
	if path.begins_with("res://"):
		var resource: Resource = ResourceLoader.load(path)
		if resource is Texture2D:
			return (resource as Texture2D).get_image()
	var image: Image = Image.new()
	if image.load(path) != OK:
		return null
	return image

func _fallback_chain(slot: String) -> Array[String]:
	match slot:
		"body": return []
		"neutral": return ["eyes_open"]
		"eyes_open": return []
		"eyes_half": return ["eyes_open"]
		"eyes_closed": return ["eyes_open"]
		"happy": return ["neutral"]
		"amused": return ["happy", "neutral"]
		"smug": return ["happy", "neutral"]
		"curious": return ["neutral"]
		"surprised": return ["neutral"]
		"annoyed": return ["angry", "neutral"]
		"angry": return ["neutral"]
		"worried": return ["sad", "neutral"]
		"sad": return ["neutral"]
		"embarrassed": return ["neutral"]
		"tired": return ["sad", "neutral"]
		"flustered_worried": return ["worried", "sad", "neutral"]
		"flustered_surprised": return ["surprised", "neutral"]
		"flustered_annoyed": return ["angry", "neutral"]
		_: return ["neutral"]

func _clean_id(value: String) -> String:
	var clean := value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	var regex := RegEx.new()
	regex.compile("[^a-z0-9_]+")
	clean = regex.sub(clean, "", true)
	while clean.begins_with("_"):
		clean = clean.substr(1)
	while clean.ends_with("_"):
		clean = clean.left(clean.length() - 1)
	return clean

func _read_json(path: String) -> Variant:
	if not _file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data

func _write_json(path: String, value: Variant) -> bool:
	_make_dir_recursive(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(value, "  ", false))
	file.close()
	return true

func _copy_file(source_path: String, destination_path: String) -> bool:
	if source_path.begins_with("res://"):
		var resource := ResourceLoader.load(source_path)
		if resource is Texture2D:
			var image := (resource as Texture2D).get_image()
			if image != null:
				return image.save_png(destination_path) == OK
		if source_path != PLACEHOLDER_PATH:
			return _copy_file(PLACEHOLDER_PATH, destination_path)
		return false
	var source := FileAccess.open(source_path, FileAccess.READ)
	if source == null:
		return _copy_file(PLACEHOLDER_PATH, destination_path)
	var bytes := source.get_buffer(source.get_length())
	source.close()
	var destination := FileAccess.open(destination_path, FileAccess.WRITE)
	if destination == null:
		return false
	destination.store_buffer(bytes)
	destination.close()
	return true

func _make_dir_recursive(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path)

func _remove_file(path: String) -> void:
	var absolute_path: String = ProjectSettings.globalize_path(path) if path.begins_with("res://") or path.begins_with("user://") else path
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)

func _file_exists(path: String) -> bool:
	if path.begins_with("res://"):
		return ResourceLoader.exists(path)
	return FileAccess.file_exists(path)
