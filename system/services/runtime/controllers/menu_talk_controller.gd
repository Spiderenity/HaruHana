extends Node
class_name MenuTalkController

const AppLanguageScript = preload("res://system/app/app_language.gd")
const UserProfileSettingsScript = preload("res://system/app/user_profile_settings.gd")
const DesktopCharacterProgressScript = preload(
	"res://system/services/desktop/desktop_character_progress.gd"
)

const GENERATED_USE_CHANCE: float = 0.25
const PREFETCH_RETRY_MSEC: int = 60000
const RESPONSE_DURATION: float = 3.6

var character_manager: DesktopCharacterManager = null
var character_event_dialogue: CharacterEventDialogue = null
var generated_pools: Dictionary = {}
var pending_requests: Dictionary = {}
var retry_after_msec: Dictionary = {}
var pending_custom_replies: Dictionary = {}

func configure(
	manager: DesktopCharacterManager,
	event_dialogue: CharacterEventDialogue
) -> void:
	character_manager = manager
	character_event_dialogue = event_dialogue

func _l(english: String, korean: String) -> String:
	return AppLanguageScript.text(english, korean)

func invalidate_cache() -> void:
	if character_manager != null:
		for character_id_value: Variant in pending_custom_replies.values():
			character_manager.set_character_response_loading(
				str(character_id_value), "menu", false
			)
	generated_pools.clear()
	pending_requests.clear()
	retry_after_msec.clear()
	pending_custom_replies.clear()

func refresh_cast() -> void:
	if character_manager == null:
		return
	var active_ids: Array[String] = character_manager.get_active_character_ids()
	var valid_prefixes: Array[String] = []
	for character_id: String in active_ids:
		valid_prefixes.append(character_id + "|")
		ensure_prefetch(character_id)
	for key_value: Variant in generated_pools.keys():
		var key: String = str(key_value)
		var keep: bool = false
		for prefix: String in valid_prefixes:
			if key.begins_with(prefix):
				keep = true
				break
		if not keep:
			generated_pools.erase(key)

func ensure_prefetch(character_id: String, menu_key: String = "") -> void:
	if character_event_dialogue == null or character_manager == null:
		return
	character_id = character_id.strip_edges().to_lower()
	if character_id.is_empty():
		return
	if not character_manager.get_active_character_ids().has(character_id):
		return
	var settings: Dictionary = AISettings.load_settings()
	var api_key: String = str(settings.get("api_key", "")).strip_edges()
	var model: String = str(settings.get("model", AISettings.DEFAULT_MODEL)).strip_edges()
	if api_key.is_empty() or model.is_empty():
		return
	var progress: Dictionary = DesktopCharacterProgressScript.get_context(character_id)
	var friendship_level: int = int(progress.get("friendship_level", 0))
	var achievement_level: int = int(progress.get("achievement_level", 0))
	var context_key: String = _context_key(
		character_id,
		friendship_level,
		achievement_level
	)
	_prune_character_contexts(character_id, context_key)
	var requested_keys: Array[String] = []
	if menu_key.is_empty():
		for key: String in CharacterEventDialogue.MENU_RESPONSE_KEYS:
			if not _has_unused_response(context_key, key):
				requested_keys.append(key)
	else:
		menu_key = menu_key.strip_edges().to_lower()
		if _has_unused_response(context_key, menu_key):
			return
		requested_keys.append(menu_key)
	if requested_keys.is_empty():
		return
	var now_msec: int = Time.get_ticks_msec()
	if now_msec < int(retry_after_msec.get(context_key, 0)):
		return
	for pending_value: Variant in pending_requests.values():
		if not (pending_value is Dictionary):
			continue
		var pending: Dictionary = pending_value as Dictionary
		if str(pending.get("context_key", "")) != context_key:
			continue
		var pending_keys_value: Variant = pending.get("menu_keys", [])
		if pending_keys_value is Array:
			for index: int in range(requested_keys.size() - 1, -1, -1):
				if (pending_keys_value as Array).has(requested_keys[index]):
					requested_keys.remove_at(index)
	if requested_keys.is_empty():
		return
	var request_id: int = int(
		character_event_dialogue.request_menu_response_bundle(
			character_id,
			friendship_level,
			achievement_level,
			requested_keys
		)
	)
	if request_id <= 0:
		return
	pending_requests[request_id] = {
		"character_id": character_id,
		"context_key": context_key,
		"menu_keys": requested_keys.duplicate(),
	}

func handle_action(character_id: String, action: String, detail: String) -> void:
	if character_manager == null:
		return
	character_id = character_id.strip_edges().to_lower()
	var actor: DesktopCharacterActor = character_manager.get_actor(character_id)
	if actor == null:
		return
	var clean_action: String = action.strip_edges().to_lower()
	var clean_detail: String = detail.strip_edges().to_lower()
	if clean_action == "custom_unavailable":
		_show_custom_reply(character_id, {})
		return
	if clean_action == "custom":
		_request_custom_reply(character_id, detail, actor)
		return
	if clean_action == "ask" and clean_detail == "controls":
		var controls: Dictionary = _get_controls_reaction(character_id)
		actor.show_speech(
			str(controls.get("text", "")),
			float(controls.get("duration", 8.0)),
			str(controls.get("mood", "neutral"))
		)
		return
	var stock: Dictionary = _get_stock_reaction(character_id, action, detail)
	var reaction: Dictionary = _take_generated_reaction(character_id, action, detail)
	if reaction.is_empty():
		reaction = stock
	actor.show_speech(
		str(reaction.get("text", "")),
		float(reaction.get("duration", RESPONSE_DURATION)),
		str(reaction.get("mood", "neutral"))
	)
	ensure_prefetch(character_id, _menu_key(action, detail))

func _get_controls_reaction(character_id: String) -> Dictionary:
	var text: String = ""
	var mood: String = "neutral"
	match character_id:
		"crt":
			text = _l(
				"Hover over me to reveal ☰, then grab it to move me. Hold Alt or leave the pointer still over me to make me transparent and click-through. Vertical movement can be enabled in Settings.",
				"마우스를 올리면 ☰가 나타나. 그걸 잡으면 나를 옮길 수 있어. Alt를 누르거나 마우스를 내 위에 가만히 두면 투명해지고 클릭이 통과해. 세로 이동은 설정에서 켤 수 있어."
			)
		"chip":
			mood = "happy"
			text = _l(
				"Hover over Chip to reveal ☰, then grab it to move Chip! Hold Alt or leave the pointer still over Chip to become transparent and click-through. Vertical movement can be enabled in Settings!",
				"칩 위에 마우스를 올리면 ☰가 나타나! 그걸 잡으면 칩을 옮길 수 있어. Alt를 누르거나 칩 위에서 마우스를 가만히 두면 투명해지고 클릭이 통과해. 세로 이동은 설정에서 켤 수 있어!"
			)
		_:
			text = _l(
				"Hover over the character to reveal ☰, then grab it to move the character. Hold Alt or leave the pointer still over the character for transparency and click-through. Vertical movement can be enabled in Settings.",
				"캐릭터 위에 마우스를 올리면 ☰가 나타나. 그걸 잡으면 캐릭터를 옮길 수 있어. Alt를 누르거나 캐릭터 위에서 마우스를 가만히 두면 투명해지고 클릭이 통과해. 세로 이동은 설정에서 켤 수 있어."
			)
	return {
		"text": "(" + mood + ")" + text,
		"mood": mood,
		"duration": 8.0,
	}

func _request_custom_reply(
	character_id: String,
	user_text: String,
	actor: DesktopCharacterActor
) -> void:
	user_text = user_text.strip_edges()
	if user_text.is_empty() or character_event_dialogue == null:
		return
	var waiting: Dictionary = _get_custom_waiting_reaction(character_id)
	actor.show_speech(
		str(waiting.get("text", "...")),
		RESPONSE_DURATION,
		str(waiting.get("mood", "curious"))
	)
	var request_id: int = int(
		character_event_dialogue.request_custom_menu_reply(
			character_id,
			user_text
		)
	)
	if request_id <= 0:
		_show_custom_reply(character_id, {})
		return
	pending_custom_replies[request_id] = character_id
	character_manager.set_character_response_loading(character_id, "menu", true)

func _on_custom_menu_reply_ready(
	request_id: int,
	character_id: String,
	dialogue: Dictionary
) -> void:
	if not pending_custom_replies.has(request_id):
		return
	var expected_character_id: String = str(
		pending_custom_replies[request_id]
	)
	pending_custom_replies.erase(request_id)
	if character_manager != null:
		character_manager.set_character_response_loading(
			expected_character_id, "menu", false
		)
	if expected_character_id != character_id:
		return
	_show_custom_reply(character_id, dialogue)

func _show_custom_reply(character_id: String, dialogue: Dictionary) -> void:
	if character_manager == null:
		return
	var actor: DesktopCharacterActor = character_manager.get_actor(character_id)
	if actor == null:
		return
	var reaction: Dictionary = dialogue
	if reaction.is_empty():
		reaction = _get_custom_failure_reaction(character_id)
	actor.show_speech(
		str(reaction.get("text", "")),
		float(reaction.get("duration", RESPONSE_DURATION)),
		str(reaction.get("mood", "neutral"))
	)

func _get_custom_waiting_reaction(character_id: String) -> Dictionary:
	match character_id:
		"crt":
			return {
				"text": _l("Wait. I'm thinking.", "잠깐. 생각 중이야."),
				"mood": "curious",
			}
		"chip":
			return {
				"text": _l("Hmm... Chip will think!", "음... 칩이 생각해 볼게!"),
				"mood": "curious",
			}
		_:
			return {"text": _l("One moment.", "잠깐만."), "mood": "curious"}

func _get_custom_failure_reaction(character_id: String) -> Dictionary:
	match character_id:
		"crt":
			return {
				"text": _l(
					"I need the AI settings first. Check the key in Settings.",
					"AI 설정이 먼저 필요해. 설정에서 키를 확인해 줘."
				),
				"mood": "annoyed",
			}
		"chip":
			return {
				"text": _l(
					"Oh! Chip can't answer yet. Check the AI settings first!",
					"앗! 칩은 아직 대답할 수 없어. AI 설정부터 확인해 줘!"
				),
				"mood": "worried",
			}
		_:
			return {
				"text": _l(
					"Check the AI settings first.",
					"AI 설정을 먼저 확인해 줘."
				),
				"mood": "worried",
			}

func _on_menu_response_bundle_ready(
	request_id: int,
	character_id: String,
	context_key: String,
	responses: Dictionary
) -> void:
	if not pending_requests.has(request_id):
		return
	var pending: Dictionary = pending_requests[request_id] as Dictionary
	pending_requests.erase(request_id)
	if str(pending.get("character_id", "")) != character_id:
		return
	if str(pending.get("context_key", "")) != context_key:
		return
	var progress: Dictionary = DesktopCharacterProgressScript.get_context(character_id)
	var current_key: String = _context_key(
		character_id,
		int(progress.get("friendship_level", 0)),
		int(progress.get("achievement_level", 0))
	)
	if current_key != context_key:
		return
	if responses.is_empty():
		retry_after_msec[context_key] = Time.get_ticks_msec() + PREFETCH_RETRY_MSEC
		return
	retry_after_msec.erase(context_key)
	var pools: Dictionary = {}
	if generated_pools.has(context_key):
		var existing_value: Variant = generated_pools[context_key]
		if existing_value is Dictionary:
			pools = (existing_value as Dictionary).duplicate(true)
	for menu_key_value: Variant in responses.keys():
		var menu_key: String = str(menu_key_value)
		var incoming_value: Variant = responses[menu_key_value]
		if not (incoming_value is Array):
			continue
		var pool: Array = []
		var existing_pool_value: Variant = pools.get(menu_key, [])
		if existing_pool_value is Array:
			pool = (existing_pool_value as Array).duplicate(true)
		for reaction_value: Variant in incoming_value:
			if not (reaction_value is Dictionary):
				continue
			var reaction: Dictionary = (reaction_value as Dictionary).duplicate(true)
			var text: String = str(reaction.get("text", "")).strip_edges()
			if text.is_empty() or _pool_has_text(pool, text):
				continue
			pool.append(reaction)
		pools[menu_key] = pool
	generated_pools[context_key] = pools

func _take_generated_reaction(
	character_id: String,
	action: String,
	detail: String
) -> Dictionary:
	if randf() > GENERATED_USE_CHANCE:
		return {}
	var progress: Dictionary = DesktopCharacterProgressScript.get_context(character_id)
	var context_key: String = _context_key(
		character_id,
		int(progress.get("friendship_level", 0)),
		int(progress.get("achievement_level", 0))
	)
	var pools_value: Variant = generated_pools.get(context_key, {})
	if not (pools_value is Dictionary):
		return {}
	var pools: Dictionary = pools_value as Dictionary
	var menu_key: String = _menu_key(action, detail)
	var pool_value: Variant = pools.get(menu_key, [])
	if not (pool_value is Array):
		return {}
	var pool: Array = pool_value as Array
	if pool.is_empty():
		return {}
	var index: int = randi_range(0, pool.size() - 1)
	var reaction_value: Variant = pool[index]
	pool.remove_at(index)
	pools[menu_key] = pool
	generated_pools[context_key] = pools
	if reaction_value is Dictionary:
		var reaction: Dictionary = (reaction_value as Dictionary).duplicate(true)
		reaction["duration"] = RESPONSE_DURATION
		return reaction
	return {}

func _prune_character_contexts(character_id: String, current_key: String) -> void:
	var prefix: String = character_id.strip_edges().to_lower() + "|"
	for key_value: Variant in generated_pools.keys():
		var key: String = str(key_value)
		if key.begins_with(prefix) and key != current_key:
			generated_pools.erase(key)
	for key_value: Variant in retry_after_msec.keys():
		var key: String = str(key_value)
		if key.begins_with(prefix) and key != current_key:
			retry_after_msec.erase(key)

func _has_unused_response(context_key: String, menu_key: String) -> bool:
	var pools_value: Variant = generated_pools.get(context_key, {})
	if not (pools_value is Dictionary):
		return false
	var pool_value: Variant = (pools_value as Dictionary).get(menu_key, [])
	return pool_value is Array and not (pool_value as Array).is_empty()

func _pool_has_text(pool: Array, text: String) -> bool:
	for value: Variant in pool:
		if value is Dictionary:
			if str((value as Dictionary).get("text", "")).strip_edges() == text:
				return true
	return false

func _context_key(
	character_id: String,
	friendship_level: int,
	achievement_level: int
) -> String:
	return "%s|%s|f%d|a%d" % [
		character_id.strip_edges().to_lower(),
		AppLanguageScript.get_language(),
		friendship_level,
		achievement_level,
	]

func _menu_key(action: String, detail: String) -> String:
	var clean_action: String = action.strip_edges().to_lower()
	var clean_detail: String = detail.strip_edges().to_lower()
	if clean_detail.is_empty():
		return clean_action
	return clean_action + ":" + clean_detail

func _get_stock_reaction(
	character_id: String,
	action: String,
	detail: String
) -> Dictionary:
	var progress: Dictionary = DesktopCharacterProgressScript.get_context(character_id)
	var friendship_level: int = int(progress.get("friendship_level", 0))
	var achievement_level: int = int(progress.get("achievement_level", 0))
	match character_id.strip_edges().to_lower():
		"crt":
			return _get_crt_stock_reaction(
				action,
				detail,
				friendship_level,
				achievement_level
			)
		"chip":
			return _get_chip_stock_reaction(
				action,
				detail,
				friendship_level,
				achievement_level
			)
		_:
			return _get_default_stock_reaction(action)

func _get_crt_stock_reaction(
	action: String,
	detail: String,
	friendship_level: int,
	achievement_level: int
) -> Dictionary:
	var mood: String = "neutral"
	var lines: Array[Dictionary] = []

	match action:
		"hello":
			mood = "happy"
			match friendship_level:
				0:
					lines = _stock_lines([
						["Yeah. Hi.", "응. 안녕."],
						["Hi.", "안녕."],
					])
				1:
					lines = _stock_lines([
						["You're here. Hi.", "왔네. 안녕."],
						["Yeah, hi again.", "응, 또 왔네."],
					])
				2:
					lines = _stock_lines([
						["Hi. You're here again today.", "안녕. 오늘도 왔네."],
						["You're here. I suppose I'm glad to see you.", "왔네. 뭐, 반갑긴 해."],
					])
				_:
					lines = _stock_lines([
						["You're here. Hi.", "왔네. 안녕."],
						["Hi. Right on time.", "안녕. 때맞춰 왔네."],
					])
		"ask":
			match detail:
				"week":
					match achievement_level:
						0:
							mood = "annoyed"
							lines = _stock_lines([
								["Your focus time this week is still under 30 minutes. Planning to get started soon?", "이번 주 집중 시간은 아직 30분도 안 됐네. 슬슬 시작할 생각은 있어?"],
								["You haven't even reached 30 minutes this week. Taking it pretty easy, aren't you.", "이번 주엔 아직 30분도 못 채웠어. 꽤 여유롭네."],
								["You're still under 30 minutes this week. Well, the week's not over yet.", "아직 30분 아래야. 뭐, 이번 주가 끝난 건 아니니까."],
							])
						1:
							mood = "curious"
							lines = _stock_lines([
								["You've passed 30 minutes of focus this week. So you haven't been doing nothing.", "이번 주 집중 시간은 30분 넘겼네. 아주 놀고만 있진 않았어."],
								["You've at least gotten started this week. You're over 30 minutes.", "이번 주는 일단 시작은 했네. 30분은 넘겼어."],
								["You've done more than 30 minutes this week. I wouldn't call it a lot yet, though.", "30분 이상 했어. 아직 많이 했다고 하긴 좀 그렇지만."],
							])
						2:
							mood = "happy"
							lines = _stock_lines([
								["You've passed 90 minutes of focus this week. You've worked pretty hard this week.", "이번 주 집중 시간은 90분 넘겼네. 이번 주는 꽤 열심히 했어."],
								["You've gone past an hour and a half this week. Not bad.", "이번 주에 1시간 반 넘겼어. 제법인데?"],
								["You've focused for at least 90 minutes this week. You're doing pretty well.", "이번 주는 90분 이상 집중했어. 이 정도면 꽤 잘하고 있어."],
							])
						_:
							mood = "smug"
							lines = _stock_lines([
								["You've already passed three hours of focus this week. You worked pretty hard.", "이번 주 집중 시간, 벌써 3시간 넘겼네. 꽤 열심히 했어."],
								["You've gone over 180 minutes this week. Fine, I'll admit it. Good job.", "이번 주는 180분 넘겼어. 인정. 잘했네."],
								["You've done more than three hours this week. I don't really have anything to complain about there.", "이번 주에 3시간 이상 했네. 이 정도면 내가 뭐라고 할 것도 없고."],
							])
				"self":
					mood = "curious"
					match friendship_level:
						0:
							lines = _stock_lines([["Me? CRT. I keep an eye on whether you're focusing. That's enough of an introduction, isn't it?", "나? CRT양.\n네가 집중하는지 보고 있는 쪽이야.\n뭐, 그 정도만 알아도 되잖아."]])
						1:
							lines = _stock_lines([["CRT. I keep an eye on whether you're doing what you need to do, and I say something when I feel like it. Chip lives here too. You'll figure me out soon enough.", "CRT양. 네가 할 일 하는지 보고, 가끔 한마디 하고.\n칩도 같이 지내고 있어.\n보다 보면 어떤 애인지 알게 되겠지."]])
						2:
							mood = "embarrassed"
							lines = _stock_lines([["About me? Don't you know me pretty well by now? I complain when you slack off, and I look after Chip when Chip causes trouble. That's basically me.", "나에 대해? 이제 꽤 알지 않아?\n네가 딴짓하면 뭐라고 하고, 칩이 사고 치면 챙기고.\n...대충 그런 애야."]])
						_:
							mood = "embarrassed"
							lines = _stock_lines([["You want me to introduce myself again? CRT. The one who's here beside you. You know what I mean by now, {user_name}.", "또 자기소개해 달라는 거야?\nCRT양. 네 옆에 있는 애.\n...이제 그 정도면 알아듣잖아, {user_name}."]])
				_:
					lines = _stock_lines([["Go on.", "말해 봐."]])
		"praise":
			mood = "happy"
			match detail:
				"great_job":
					mood = "smug"
					match friendship_level:
						0: lines = _stock_lines([["Of course I did.", "그 정도는 하지."]])
						1: lines = _stock_lines([["This much is nothing.", "뭐, 이 정도쯤이야."]])
						2: lines = _stock_lines([["Yeah. I did pretty well, didn't I?", "응. 꽤 잘했지?"]])
						_: lines = _stock_lines([["I know. Still, hearing you say it isn't bad.", "알아. 그래도 네가 말해 주니까 나쁘진 않네."]])
				"cute":
					mood = "embarrassed" if friendship_level > 0 else "surprised"
					match friendship_level:
						0: lines = _stock_lines([["What? Out of nowhere?", "뭐? 갑자기."]])
						1: lines = _stock_lines([["...Give me some warning before you say things like that.", "...그런 말은 예고하고 해."]])
						2: lines = _stock_lines([["I heard you, so stop staring at me like that.", "알았으니까 그렇게 쳐다보진 마."]])
						_: lines = _stock_lines([["You say things like that without even hesitating now.", "이젠 아무렇지도 않게 그런 말을 하네."]])
				"thanks":
					mood = "happy"
					match friendship_level:
						0: lines = _stock_lines([["It's nothing.", "별걸 다."]])
						1: lines = _stock_lines([["Yeah. That's enough.", "응. 그 정도면 됐어."]])
						2: lines = _stock_lines([["You really don't have to thank me for that.", "굳이 고맙다고까지 할 건 없는데."]])
						_: lines = _stock_lines([["Yeah. If you need something again, tell me.", "응. 다음에도 필요하면 말해."]])
				_:
					lines = _stock_lines([["Thanks.", "고마워."]])
		_:
			lines = _stock_lines([["Go on.", "말해 봐."]])

	return _pick_stock_reaction(lines, mood)

func _get_chip_stock_reaction(
	action: String,
	detail: String,
	friendship_level: int,
	achievement_level: int
) -> Dictionary:
	var mood: String = "neutral"
	var lines: Array[Dictionary] = []

	match action:
		"hello":
			mood = "happy"
			match friendship_level:
				0: lines = _stock_lines([["Hi!", "안녕!"]])
				1: lines = _stock_lines([["Oh, it's {user_name}! Hi!", "어, {user_name}다! 안녕!"]])
				2: lines = _stock_lines([["Hi! You're here again!", "안녕! 또 왔네!"]])
				_: lines = _stock_lines([["{user_name} is here! Hi!", "{user_name} 왔다! 안녕!"]])
		"ask":
			match detail:
				"week":
					mood = "curious"
					match achievement_level:
						0:
							lines = _stock_lines([
								["You haven't reached 30 minutes of focus this week yet. Are you just getting started?", "이번 주 집중 시간은 아직 30분 안 됐어. 이제 시작하는 거야?"],
								["You haven't even done 30 minutes this week yet! You can start now!", "이번 주엔 아직 30분도 안 했네! 지금부터 하면 되겠다!"],
								["You're still under 30 minutes this week. How much will you do this week?", "아직 30분 아래야. 이번 주엔 얼마나 할까?"],
							])
						1:
							mood = "happy"
							lines = _stock_lines([
								["You've passed 30 minutes of focus this week! You started!", "이번 주 집중 시간 30분 넘었어! 시작했네!"],
								["You've focused for at least 30 minutes this week. Oh, you did get some done!", "이번 주에 30분 이상 집중했어. 오, 그래도 했네!"],
								["You're over 30 minutes this week! I wonder how much it'll go up next!", "이번 주 30분 넘겼어! 다음엔 얼마나 늘어날까?"],
							])
						2:
							mood = "happy"
							lines = _stock_lines([
								["You've focused for more than 90 minutes this week! That's quite a lot!", "이번 주에 90분 넘게 집중했어! 꽤 많이 했네!"],
								["Your focus time this week is over an hour and a half. {user_name}, you worked hard!", "이번 주 집중 시간이 1시간 반 넘었어. {user_name}, 열심히 했구나!"],
								["You've done at least 90 minutes this week! You're doing well!", "이번 주는 90분 이상 했어! 잘하고 있네!"],
							])
						_:
							mood = "amused"
							lines = _stock_lines([
								["You've passed three hours of focus this week! Wow, that's a lot!", "이번 주 집중 시간 3시간 넘었어! 우와, 많이 했다!"],
								["You've focused for at least 180 minutes this week! {user_name}, you worked really hard!", "이번 주에 180분 이상 집중했어! {user_name}, 엄청 열심히 했네!"],
								["You're over three hours this week! You really did a lot this week!", "이번 주 3시간 넘겼어! 이번 주 진짜 많이 했구나!"],
							])
				"self":
					mood = "curious"
					match friendship_level:
						0:
							lines = _stock_lines([["Chip is Chip! Chip is square and looks like a chip.", "칩은 칩이야!\n네모나고, 칩처럼 생겼어."]])
						1:
							lines = _stock_lines([["Chip is curious about lots of things. If Chip sees something, Chip goes closer to look! Sometimes CRT catches Chip doing that.", "칩은 궁금한 게 많아.\n뭔가 있으면 가까이 가서 봐!\n그러다 CRT양한테 잡힐 때도 있어."]])
						2:
							mood = "happy"
							lines = _stock_lines([["Chip likes following {user_name}, and Chip likes following CRT too. Watching both of you is fun!", "칩은 {user_name} 따라다니는 것도 좋아하고, CRT양 따라다니는 것도 좋아해.\n둘 다 보고 있으면 재밌어!"]])
						_:
							mood = "happy"
							lines = _stock_lines([["Who is Chip? You know that too, {user_name}! Chip is the chip that stays by {user_name} with CRT.", "칩이 누구냐고?\n{user_name}도 알잖아!\n칩은 {user_name} 옆에서 CRT양이랑 같이 있는 칩이야."]])
				_:
					lines = _stock_lines([["Tell Chip!", "칩한테 말해 봐!"]])
		"praise":
			mood = "happy"
			match detail:
				"great_job":
					match friendship_level:
						0: lines = _stock_lines([["Really? Chip did good?", "진짜? 칩 잘했어?"]])
						1: lines = _stock_lines([["Wow, Chip got praised!", "와, 칭찬받았다!"]])
						2: lines = _stock_lines([["Chip did good! Chip can do it again!", "칩 잘했지! 또 할 수 있어!"]])
						_: lines = _stock_lines([["Oh, {user_name} praised Chip!", "오, 칭찬받았다! {user_name}한테!"]])
				"cute":
					mood = "amused"
					match friendship_level:
						0: lines = _stock_lines([["Chip is cute?", "칩 귀여워?"]])
						1: lines = _stock_lines([["Oh, cute!", "오, 귀엽대!"]])
						2: lines = _stock_lines([["Chip thinks Chip might be a little cute too!", "칩도 좀 귀여운 것 같아!"]])
						_: lines = _stock_lines([["Oh, Chip likes hearing that now!", "오, 이제 칩도 그 말 좋아!"]])
				"thanks":
					match friendship_level:
						0: lines = _stock_lines([["Yeah!", "응!"]])
						1: lines = _stock_lines([["Chip thanks you too!", "칩도 고마워!"]])
						2: lines = _stock_lines([["Yeah! Hearing thanks feels good!", "응! 고맙다고 들으니까 좋다!"]])
						_: lines = _stock_lines([["Chip heard that! You're welcome!", "칩 들었어! 별말을!"]])
				_:
					lines = _stock_lines([["Yeah!", "응!"]])
		_:
			lines = _stock_lines([["Tell Chip!", "칩한테 말해 봐!"]])

	return _pick_stock_reaction(lines, mood)

func _get_default_stock_reaction(action: String) -> Dictionary:
	var mood: String = "neutral"
	var lines: Array[Dictionary] = []
	match action:
		"hello":
			mood = "happy"
			lines = _stock_lines([["Hello.", "안녕."]])
		"ask":
			lines = _stock_lines([["Go on.", "말해 봐."]])
		"praise":
			mood = "happy"
			lines = _stock_lines([["Thanks.", "고마워."]])
		_:
			lines = _stock_lines([["Go on.", "말해 봐."]])
	return _pick_stock_reaction(lines, mood)

func _stock_lines(values: Array) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for value: Variant in values:
		if not (value is Array):
			continue
		var pair: Array = value as Array
		if pair.size() < 2:
			continue
		lines.append({
			"en": str(pair[0]),
			"ko": str(pair[1]),
		})
	return lines

func _pick_stock_reaction(lines: Array[Dictionary], mood: String) -> Dictionary:
	if lines.is_empty():
		return {
			"text": AppLanguageScript.text("Go on.", "말해 봐."),
			"mood": mood,
			"duration": RESPONSE_DURATION,
		}
	var line: Dictionary = lines[randi_range(0, lines.size() - 1)]
	var text: String = AppLanguageScript.text(
		str(line.get("en", "")),
		str(line.get("ko", ""))
	)
	text = _resolve_user_name(text)
	text = "(" + mood + ")" + text
	return {
		"text": text,
		"mood": mood,
		"duration": RESPONSE_DURATION,
	}

func _resolve_user_name(text: String) -> String:
	if not text.contains("{user_name}"):
		return text
	var user_name: String = UserProfileSettingsScript.get_user_name()
	if user_name.is_empty():
		user_name = AppLanguageScript.text("user", "유저")
	return UserProfileSettingsScript.replace_user_name_placeholder(text, user_name)
