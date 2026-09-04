extends Node
class_name DesktopCharacterPlay

signal play_changed(
	character_id: String,
	play_value: float,
	play_max: float
)

signal interaction_activity(
	character_id: String
)

signal local_reaction_requested(
	character_id: String,
	dialogue: Dictionary
)

signal notable_event_requested(
	character_id: String,
	event_kind: String,
	zone: String,
	play_value: float
)

signal flustered_started(
	character_id: String,
	duration: float,
	mood: String
)

signal flustered_finished(
	character_id: String
)

signal temporary_departure_requested(
	character_id: String,
	duration_seconds: float,
	delay_seconds: float,
	reason: String,
	unavailable_lines: Array
)

const PACK_PROFILE_FILENAME: String = (
	"play_profiles.json"
)

const SAVE_DIRECTORY: String = (
	"user://character_state/play"
)

var character_actor: Node = null
var character_id: String = ""
var pack_id: String = ""

var profile: Dictionary = {}

var play_expression_map: Dictionary = {}
var zone_expression_maps: Dictionary = {}
var fluster_moods: Array[String] = []

var zone_effects: Dictionary = {}

var reluctance_value: float = 0.0
var reluctance_max: float = 100.0
var reluctance_threshold: float = 1000.0
var reluctance_decay_delay_seconds: float = 8.0
var reluctance_decay_per_second: float = 0.30
var refusal_lock_seconds: float = 75.0
var refusal_reset_value: float = 30.0
var refusal_play_multiplier: float = 0.60
var departure_chance: float = 0.0
var departure_seconds: float = 180.0
var departure_delay_seconds: float = 3.2
var interaction_locked_until_unix: int = 0
var last_locked_reaction_msec: int = 0
var locked_reaction_cooldown_seconds: float = 7.0

var play_value: float = 0.0
var play_threshold: float = 35.0
var play_max: float = 100.0

var pet_gain_per_second: float = 0.40
var poke_gain: float = 0.75

var stroke_arm_seconds: float = 1.0
var stroke_chain_reset_seconds: float = 1.5
var poke_reaction_interval: float = 4.0

var pet_reaction_seconds: Array[float] = [
	6.0,
	15.0,
	25.0,
	35.0,
	45.0,
	55.0,
	65.0,
	75.0,
	85.0,
	95.0
]

var fluster_seconds: float = 20.0

var play_decay_delay_seconds: float = 10.0
var play_decay_per_second: float = 0.12
var decay_save_interval_seconds: float = 2.0

var last_pet_stroke_msec: int = 0
var stroke_chain_seconds: float = 0.0
var total_stroke_seconds: float = 0.0
var pet_reaction_index: int = 0
var has_pet_reacted: bool = false

var last_poke_reaction_msec: int = 0
var last_touch_msec: int = 0

var interaction_activity_grace_seconds: float = 2.5

var decay_save_accumulator: float = 0.0

var last_touch_zone: String = ""

var fluster_timer: Timer = null
var flustered: bool = false
var current_fluster_mood: String = "embarrassed"

func _process(
	delta: float
) -> void:

	var safe_delta: float = maxf(
		0.0,
		delta
	)

	var now_msec: int = Time.get_ticks_msec()

	if reluctance_value > 0.0:
		var reluctance_idle_seconds: float = 0.0

		if last_touch_msec > 0:
			reluctance_idle_seconds = (
				float(
					now_msec
					- last_touch_msec
				)
				/ 1000.0
			)

		if (
			last_touch_msec <= 0
			or reluctance_idle_seconds
				>= reluctance_decay_delay_seconds
		):
			var old_reluctance: float = reluctance_value

			reluctance_value = maxf(
				0.0,
				reluctance_value
				- reluctance_decay_per_second
				* safe_delta
			)

			if not is_equal_approx(
				old_reluctance,
				reluctance_value
			):
				decay_save_accumulator += safe_delta

	if flustered:
		return

	if play_value <= 0.0:
		if (
			decay_save_accumulator
				>= decay_save_interval_seconds
		):
			decay_save_accumulator = 0.0
			_save_state()

		return

	if last_touch_msec <= 0:
		last_touch_msec = now_msec
		return

	var idle_seconds: float = (
		float(
			now_msec
			- last_touch_msec
		)
		/ 1000.0
	)

	if idle_seconds < play_decay_delay_seconds:
		if (
			decay_save_accumulator
				>= decay_save_interval_seconds
		):
			decay_save_accumulator = 0.0
			_save_state()

		return

	var old_value: float = play_value

	play_value = maxf(
		0.0,
		play_value
		- play_decay_per_second
		* safe_delta
	)

	if not is_equal_approx(
		old_value,
		play_value
	):
		play_changed.emit(
			character_id,
			play_value,
			play_max
		)

		decay_save_accumulator += safe_delta

	if old_value > 0.0 and play_value <= 0.0:
		total_stroke_seconds = 0.0
		pet_reaction_index = 0
		has_pet_reacted = false
		stroke_chain_seconds = 0.0
		last_pet_stroke_msec = 0

	if (
		play_value <= 0.0
		or decay_save_accumulator
			>= decay_save_interval_seconds
	):
		decay_save_accumulator = 0.0
		_save_state()

func configure(
	actor: Node,
	new_character_id: String
) -> void:

	character_actor = actor

	character_id = (
		new_character_id
			.strip_edges()
			.to_lower()
	)

	pack_id = (
		CharacterProfiles
			.get_current_pack()
			.strip_edges()
			.to_lower()
	)

	_load_profile()
	_load_state()

func reload_profile(
	reset_state: bool = true
) -> void:

	_load_profile()

	if reset_state:
		_reset_runtime_play_state()
	else:
		_load_state()

func debug_trigger_event(
	event_kind: String,
	zone: String = "head"
) -> void:

	event_kind = (
		event_kind
			.strip_edges()
			.to_lower()
	)

	zone = (
		zone
			.strip_edges()
			.to_lower()
	)

	match event_kind:
		"start":
			if play_value <= 0.0:
				_add_play(
					0.01,
					zone
				)
			else:
				_emit_debug_local_line(
					"start",
					zone
				)

		"pet":
			var stage_index: int = clampi(
				pet_reaction_index,
				0,
				maxi(
					0,
					pet_reaction_seconds.size() - 1
				)
			)

			var dialogue: Dictionary = (
				_pick_pet_dialogue_stage(
					stage_index,
					zone
				)
			)

			dialogue = _apply_play_expression_mood(
				dialogue,
				zone
			)

			if not dialogue.is_empty():
				local_reaction_requested.emit(
					character_id,
					dialogue
				)

		"poke":
			_emit_debug_local_line(
				"poke",
				zone
			)

		"fluster":
			if flustered:
				_finish_flustered()

			play_value = play_max
			_begin_flustered()

		"refusal":
			_trigger_refusal_boundary(
				zone
			)

		"reset":
			_reset_runtime_play_state()

func _emit_debug_local_line(
	event_kind: String,
	zone: String
) -> void:

	var dialogue: Dictionary = (
		_pick_local_dialogue(
			event_kind,
			zone
		)
	)

	dialogue = _apply_play_expression_mood(
		dialogue,
		zone
	)

	if not dialogue.is_empty():
		local_reaction_requested.emit(
			character_id,
			dialogue
		)

func _reset_runtime_play_state() -> void:
	if fluster_timer != null:
		fluster_timer.stop()

	flustered = false
	current_fluster_mood = "embarrassed"

	play_value = 0.0
	stroke_chain_seconds = 0.0
	total_stroke_seconds = 0.0
	pet_reaction_index = 0
	has_pet_reacted = false
	last_pet_stroke_msec = 0
	last_poke_reaction_msec = 0
	last_touch_msec = 0
	last_touch_zone = ""
	decay_save_accumulator = 0.0

	reluctance_value = 0.0
	interaction_locked_until_unix = 0
	last_locked_reaction_msec = 0

	play_changed.emit(
		character_id,
		play_value,
		play_max
	)

	_save_state()

func _ready() -> void:
	fluster_timer = Timer.new()
	fluster_timer.name = "FlusterTimer"
	fluster_timer.one_shot = true
	fluster_timer.ignore_time_scale = true

	fluster_timer.timeout.connect(
		_on_fluster_timer_timeout
	)

	add_child(
		fluster_timer
	)

func get_play_value() -> float:
	return play_value

func get_play_max() -> float:
	return play_max

func is_poke_mode() -> bool:
	return (
		not flustered
		and has_pet_reacted
	)

func is_flustered() -> bool:
	return flustered

func is_interaction_active() -> bool:
	if flustered:
		return true

	if last_touch_msec <= 0:
		return false

	var elapsed_seconds: float = (
		float(
			Time.get_ticks_msec()
			- last_touch_msec
		)
		/ 1000.0
	)

	return (
		elapsed_seconds
			<= interaction_activity_grace_seconds
	)

func get_idle_mood() -> String:
	if flustered:
		return current_fluster_mood

	return "neutral"

func _mark_interaction_activity() -> void:
	last_touch_msec = Time.get_ticks_msec()

	interaction_activity.emit(
		character_id
	)

func handle_pet_stroke(
	local_position: Vector2,
	distance: float,
	pet_size: Vector2
) -> void:

	if character_id.is_empty():
		return

	if flustered:
		return

	if _is_interaction_locked():
		_mark_interaction_activity()
		_handle_locked_touch_attempt()
		return

	if distance <= 0.0:
		return

	var now_msec: int = Time.get_ticks_msec()

	last_touch_zone = (
		_get_touch_zone(
			local_position,
			pet_size
		)
	)

	if last_touch_zone.is_empty():
		last_pet_stroke_msec = now_msec
		return

	_mark_interaction_activity()

	if last_pet_stroke_msec <= 0:
		last_pet_stroke_msec = now_msec
		stroke_chain_seconds = 0.0
		return

	var elapsed_seconds: float = (
		float(
			now_msec
			- last_pet_stroke_msec
		)
		/ 1000.0
	)

	last_pet_stroke_msec = now_msec

	if elapsed_seconds <= 0.0:
		return

	if elapsed_seconds > stroke_chain_reset_seconds:
		return

	elapsed_seconds = minf(
		elapsed_seconds,
		0.35
	)

	stroke_chain_seconds += elapsed_seconds

	if stroke_chain_seconds < stroke_arm_seconds:
		return

	total_stroke_seconds += elapsed_seconds

	var zone_effect: Dictionary = (
		_get_zone_effect(
			last_touch_zone
		)
	)

	var pet_play_multiplier: float = maxf(
		0.0,
		float(
			zone_effect.get(
				"pet_play_multiplier",
				1.0
			)
		)
	)

	var reluctance_pet_per_second: float = float(
		zone_effect.get(
			"reluctance_pet_per_second",
			0.0
		)
	)

	if _adjust_reluctance(
		reluctance_pet_per_second
			* elapsed_seconds,
		last_touch_zone
	):
		return

	_add_play(
		elapsed_seconds
		* pet_gain_per_second
		* pet_play_multiplier,
		last_touch_zone
	)

	if flustered:
		return

	if pet_reaction_index >= pet_reaction_seconds.size():
		return

	var next_reaction_seconds: float = (
		pet_reaction_seconds[
			pet_reaction_index
		]
	)

	if total_stroke_seconds < next_reaction_seconds:
		return

	var dialogue: Dictionary = (
		_pick_pet_dialogue_stage(
			pet_reaction_index,
			last_touch_zone
		)
	)

	dialogue = _apply_play_expression_mood(
		dialogue,
		last_touch_zone
	)

	pet_reaction_index += 1

	if not dialogue.is_empty():
		has_pet_reacted = true

	_save_state()

	if not dialogue.is_empty():
		local_reaction_requested.emit(
			character_id,
			dialogue
		)

func handle_poke(
	local_position: Vector2,
	pet_size: Vector2
) -> void:

	if character_id.is_empty():
		return

	if flustered:
		return

	if _is_interaction_locked():
		_mark_interaction_activity()
		_handle_locked_touch_attempt()
		return

	if not is_poke_mode():
		return

	var now_msec: int = Time.get_ticks_msec()

	if (
		last_poke_reaction_msec > 0
		and now_msec - last_poke_reaction_msec
			< int(
				poke_reaction_interval * 1000.0
			)
	):
		return

	var zone: String = (
		_get_touch_zone(
			local_position,
			pet_size
		)
	)

	if zone.is_empty():
		return

	last_poke_reaction_msec = now_msec
	_mark_interaction_activity()
	last_touch_zone = zone

	var zone_effect: Dictionary = (
		_get_zone_effect(
			zone
		)
	)

	var poke_play_multiplier: float = maxf(
		0.0,
		float(
			zone_effect.get(
				"poke_play_multiplier",
				1.0
			)
		)
	)

	var reluctance_poke: float = float(
		zone_effect.get(
			"reluctance_poke",
			0.0
		)
	)

	if _adjust_reluctance(
		reluctance_poke,
		zone
	):
		return

	_add_play(
		poke_gain
		* poke_play_multiplier,
		zone
	)

	if flustered:
		return

	var dialogue: Dictionary = (
		_pick_local_dialogue(
			"poke",
			zone
		)
	)

	dialogue = _apply_play_expression_mood(
		dialogue,
		zone
	)

	if not dialogue.is_empty():
		local_reaction_requested.emit(
			character_id,
			dialogue
		)

func _add_play(
	amount: float,
	zone: String = ""
) -> void:

	if flustered:
		return

	var old_value: float = play_value

	play_value = clampf(
		play_value + maxf(
			0.0,
			amount
		),
		0.0,
		play_max
	)

	play_changed.emit(
		character_id,
		play_value,
		play_max
	)

	if (
		old_value <= 0.0
		and play_value > 0.0
	):
		var start_dialogue: Dictionary = (
			_pick_local_dialogue(
				"start",
				zone
			)
		)

		start_dialogue = (
			_apply_play_expression_mood(
				start_dialogue,
				zone
			)
		)

		if not start_dialogue.is_empty():
			local_reaction_requested.emit(
				character_id,
				start_dialogue
			)

	if play_value >= play_max:
		_begin_flustered()
		return

	_save_state()

func _begin_flustered() -> void:
	flustered = true

	current_fluster_mood = (
		_pick_fluster_mood()
	)

	play_value = 0.0
	total_stroke_seconds = 0.0
	pet_reaction_index = 0
	has_pet_reacted = false
	stroke_chain_seconds = 0.0
	last_pet_stroke_msec = 0

	if character_actor is DesktopCharacterActor:
		(character_actor as DesktopCharacterActor).set_mood(current_fluster_mood)

	var dialogue: Dictionary = (
		_pick_local_dialogue(
			"flustered",
			""
		)
	)

	if not dialogue.is_empty():
		dialogue[
			"mood"
		] = current_fluster_mood

		local_reaction_requested.emit(
			character_id,
			dialogue
		)

	flustered_started.emit(
		character_id,
		fluster_seconds,
		current_fluster_mood
	)

	notable_event_requested.emit(
		character_id,
		"flustered",
		last_touch_zone,
		play_value
	)

	play_changed.emit(
		character_id,
		play_value,
		play_max
	)

	_save_state()

	if fluster_timer != null:
		fluster_timer.start(
			fluster_seconds
		)

func _on_fluster_timer_timeout() -> void:
	_finish_flustered()

func _finish_flustered() -> void:
	flustered = false

	current_fluster_mood = "embarrassed"

	if character_actor is DesktopCharacterActor:
		(character_actor as DesktopCharacterActor).set_mood("neutral")

	_save_state()

	flustered_finished.emit(
		character_id
	)

func _get_effective_play_mood(
	dialogue: Dictionary,
	zone: String = ""
) -> String:

	var requested: String = str(
		dialogue.get(
			"mood",
			"embarrassed"
		)
	).strip_edges().to_lower()

	if requested.begins_with(
		"flustered_"
	):
		return requested

	var selected_map: Dictionary = (
		play_expression_map
	)

	if not zone.is_empty():
		var zone_map_value: Variant = (
			zone_expression_maps.get(
				zone,
				{}
			)
		)

		if zone_map_value is Dictionary:
			var zone_map: Dictionary = (
				zone_map_value
			)

			if not zone_map.is_empty():
				selected_map = zone_map

	var mapped: String = str(
		selected_map.get(
			requested,
			""
		)
	).strip_edges().to_lower()

	if not mapped.is_empty():
		return mapped

	var fallback: String = str(
		selected_map.get(
			"embarrassed",
			""
		)
	).strip_edges().to_lower()

	if not fallback.is_empty():
		return fallback

	return requested

func _apply_play_expression_mood(
	dialogue: Dictionary,
	zone: String = ""
) -> Dictionary:

	if dialogue.is_empty():
		return dialogue

	var effective_mood: String = (
		_get_effective_play_mood(
			dialogue,
			zone
		)
	)

	if effective_mood.is_empty():
		return dialogue

	var updated: Dictionary = dialogue.duplicate(
		true
	)

	updated[
		"mood"
	] = effective_mood

	return updated

func _get_zone_effect(
	zone: String
) -> Dictionary:

	var value: Variant = zone_effects.get(
		zone,
		{}
	)

	if value is Dictionary:
		return (
			value as Dictionary
		)

	return {}

func _is_interaction_locked() -> bool:
	if interaction_locked_until_unix <= 0:
		return false

	var now_unix: int = int(
		Time.get_unix_time_from_system()
	)

	if now_unix >= interaction_locked_until_unix:
		interaction_locked_until_unix = 0
		_save_state()

		return false

	return true

func _handle_locked_touch_attempt() -> void:
	var now_msec: int = Time.get_ticks_msec()

	if (
		last_locked_reaction_msec > 0
		and now_msec - last_locked_reaction_msec
			< int(
				locked_reaction_cooldown_seconds
				* 1000.0
			)
	):
		return

	last_locked_reaction_msec = now_msec

	var dialogue: Dictionary = (
		_pick_local_dialogue(
			"locked",
			last_touch_zone
		)
	)

	dialogue = _apply_play_expression_mood(
		dialogue,
		last_touch_zone
	)

	if not dialogue.is_empty():
		local_reaction_requested.emit(
			character_id,
			dialogue
		)

func _adjust_reluctance(
	amount: float,
	zone: String
) -> bool:

	if is_zero_approx(
		amount
	):
		return false

	var old_value: float = reluctance_value

	reluctance_value = clampf(
		reluctance_value + amount,
		0.0,
		reluctance_max
	)

	if (
		old_value < reluctance_threshold
		and reluctance_value
			>= reluctance_threshold
	):
		_trigger_refusal_boundary(
			zone
		)

		return true

	_save_state()

	return false

func _trigger_refusal_boundary(
	zone: String
) -> void:

	interaction_locked_until_unix = int(
		Time.get_unix_time_from_system()
		+ refusal_lock_seconds
	)

	reluctance_value = clampf(
		refusal_reset_value,
		0.0,
		reluctance_max
	)

	play_value = clampf(
		play_value
		* clampf(
			refusal_play_multiplier,
			0.0,
			1.0
		),
		0.0,
		play_max
	)

	play_changed.emit(
		character_id,
		play_value,
		play_max
	)

	var refusal_dialogue: Dictionary = (
		_pick_local_dialogue(
			"refusal",
			zone
		)
	)

	refusal_dialogue = (
		_apply_play_expression_mood(
			refusal_dialogue,
			zone
		)
	)

	if not refusal_dialogue.is_empty():
		local_reaction_requested.emit(
			character_id,
			refusal_dialogue
		)

	_save_state()

	if (
		departure_chance > 0.0
		and randf() < departure_chance
	):
		var unavailable_value: Variant = profile.get(
			"unavailable_lines",
			[]
		)

		var unavailable_lines: Array = []

		if unavailable_value is Array:
			unavailable_lines = (
				unavailable_value as Array
			).duplicate(
				true
			)

		temporary_departure_requested.emit(
			character_id,
			departure_seconds,
			departure_delay_seconds,
			"touch_boundary",
			unavailable_lines
		)

func _get_touch_zone(
	local_position: Vector2,
	pet_size: Vector2
) -> String:

	if (
		pet_size.x <= 0.0
		or pet_size.y <= 0.0
	):
		return ""

	var nx: float = clampf(
		local_position.x / pet_size.x,
		0.0,
		1.0
	)

	var ny: float = clampf(
		local_position.y / pet_size.y,
		0.0,
		1.0
	)

	var configured_zones: Variant = profile.get(
		"touch_zones",
		[]
	)

	var has_configured_zones: bool = (
		configured_zones is Array
		and not (
			configured_zones as Array
		).is_empty()
	)

	if configured_zones is Array:
		for zone_value: Variant in (
			configured_zones as Array
		):
			if not (
				zone_value is Dictionary
			):
				continue

			var zone_data: Dictionary = (
				zone_value as Dictionary
			)

			var zone_id: String = str(
				zone_data.get(
					"id",
					""
				)
			).strip_edges().to_lower()

			var rect_value: Variant = zone_data.get(
				"rect",
				[]
			)

			if (
				zone_id.is_empty()
				or not (
					rect_value is Array
				)
			):
				continue

			var rect_array: Array = (
				rect_value as Array
			)

			if rect_array.size() < 4:
				continue

			var zone_rect: Rect2 = Rect2(
				float(
					rect_array[0]
				),
				float(
					rect_array[1]
				),
				float(
					rect_array[2]
				),
				float(
					rect_array[3]
				)
			)

			if zone_rect.has_point(
				Vector2(
					nx,
					ny
				)
			):
				return zone_id

	if has_configured_zones:
		return ""

	if ny < 0.12:
		return "head"

	if ny < 0.29:
		return "face"

	if ny < 0.76:
		return "torso"

	return "lower"

func _pick_pet_dialogue_stage(
	stage_index: int,
	zone: String
) -> Dictionary:

	var lines: Array = []

	var zone_lines_value: Variant = profile.get(
		"pet_lines_by_zone",
		{}
	)

	if zone_lines_value is Dictionary:
		var zone_lines: Variant = (
			zone_lines_value as Dictionary
		).get(
			zone,
			[]
		)

		if (
			zone_lines is Array
			and not (
				zone_lines as Array
			).is_empty()
		):
			lines = zone_lines as Array

	if lines.is_empty():
		var pet_value: Variant = profile.get(
			"pet_lines",
			[]
		)

		if pet_value is Array:
			lines = pet_value as Array

	if lines.is_empty():
		return {}

	var stage_count: int = maxi(
		pet_reaction_seconds.size(),
		1
	)
	var stage_position: int = clampi(
		stage_index,
		0,
		stage_count - 1
	)
	var stage_denominator: int = maxi(
		stage_count - 1,
		1
	)
	var band_index: int = mini(
		int(
			floor(
				float(stage_position)
				* 3.0
				/ float(stage_denominator)
			)
		),
		2
	)
	var band_start: int = int(
		floor(
			float(lines.size())
			* float(band_index)
			/ 3.0
		)
	)
	var band_end: int = int(
		floor(
			float(lines.size())
			* float(band_index + 1)
			/ 3.0
		)
	) - 1

	if band_end < band_start:
		band_start = 0
		band_end = lines.size() - 1

	var value: Variant = lines[
		randi_range(
			band_start,
			band_end
		)
	]

	if value is Dictionary:
		return (
			value as Dictionary
		).duplicate(
			true
		)

	if value is String:
		return {
			"text": str(
				value
			),
			"mood": "neutral"
		}

	return {}

func _pick_local_dialogue(
	event_kind: String,
	zone: String
) -> Dictionary:

	var candidates: Array = []

	if event_kind == "start":
		var start_value: Variant = profile.get(
			"play_start_lines",
			[]
		)

		if start_value is Array:
			candidates = start_value

	elif event_kind == "pet":
		var pet_value: Variant = profile.get(
			"pet_lines",
			[]
		)

		if pet_value is Array:
			candidates = pet_value

	elif event_kind == "poke":
		var poke_value: Variant = profile.get(
			"poke_lines",
			{}
		)

		if poke_value is Dictionary:
			var poke_lines: Dictionary = (
				poke_value
			)

			var zone_value: Variant = poke_lines.get(
				zone,
				[]
			)

			if zone_value is Array:
				candidates = zone_value

	elif event_kind == "flustered":
		var fluster_value: Variant = profile.get(
			"fluster_lines",
			[]
		)

		if fluster_value is Array:
			candidates = fluster_value

	elif event_kind == "refusal":
		var refusal_value: Variant = profile.get(
			"refusal_lines",
			[]
		)

		if refusal_value is Array:
			candidates = refusal_value

	elif event_kind == "locked":
		var locked_value: Variant = profile.get(
			"locked_lines",
			[]
		)

		if locked_value is Array:
			candidates = locked_value

	if candidates.is_empty():
		return {}

	var value: Variant = candidates[
		randi_range(
			0,
			candidates.size() - 1
		)
	]

	if value is Dictionary:
		return (
			value as Dictionary
		).duplicate(
			true
		)

	if value is String:
		return {
			"text": str(
				value
			),
			"mood": "neutral"
		}

	return {}

func _pick_fluster_mood() -> String:
	if fluster_moods.is_empty():
		return "embarrassed"

	return fluster_moods[
		randi_range(
			0,
			fluster_moods.size() - 1
		)
	]

func _load_profile() -> void:
	var profiles: Dictionary = (
		_read_profiles()
	)

	var default_value: Variant = profiles.get(
		"default",
		{}
	)

	var merged: Dictionary = {}

	if default_value is Dictionary:
		merged = (
			default_value as Dictionary
		).duplicate(
			true
		)

	var characters_value: Variant = profiles.get(
		"characters",
		{}
	)

	var character_value: Variant = {}

	if characters_value is Dictionary:
		character_value = (
			characters_value as Dictionary
		).get(
			character_id,
			{}
		)

	if character_value is Dictionary:
		for key: Variant in (
			character_value as Dictionary
		).keys():
			merged[
				key
			] = (
				character_value as Dictionary
			)[
				key
			]

	profile = merged

	play_threshold = maxf(
		1.0,
		float(
			profile.get(
				"play_threshold",
				35.0
			)
		)
	)

	play_max = maxf(
		play_threshold + 1.0,
		float(
			profile.get(
				"play_max",
				100.0
			)
		)
	)

	pet_gain_per_second = maxf(
		0.001,
		float(
			profile.get(
				"pet_gain_per_second",
				0.40
			)
		)
	)

	poke_gain = maxf(
		0.0,
		float(
			profile.get(
				"poke_gain",
				0.75
			)
		)
	)

	stroke_arm_seconds = maxf(
		0.0,
		float(
			profile.get(
				"stroke_arm_seconds",
				1.0
			)
		)
	)

	stroke_chain_reset_seconds = maxf(
		0.2,
		float(
			profile.get(
				"stroke_chain_reset_seconds",
				1.5
			)
		)
	)

	poke_reaction_interval = maxf(
		0.5,
		float(
			profile.get(
				"poke_reaction_interval",
				4.0
			)
		)
	)

	pet_reaction_seconds.clear()

	var reaction_seconds_value: Variant = (
		profile.get(
			"pet_reaction_seconds",
			[
				6.0,
				15.0,
				25.0,
				35.0,
				45.0,
				55.0,
				65.0,
				75.0,
				85.0,
				95.0
			]
		)
	)

	if reaction_seconds_value is Array:
		for value: Variant in (
			reaction_seconds_value as Array
		):
			var reaction_second: float = maxf(
				0.0,
				float(
					value
				)
			)

			pet_reaction_seconds.append(
				reaction_second
			)

	if pet_reaction_seconds.is_empty():
		pet_reaction_seconds = [
			6.0,
			15.0,
			25.0,
			35.0,
			45.0,
			55.0,
			65.0,
			75.0,
			85.0,
			95.0
		]

	fluster_seconds = maxf(
		3.0,
		float(
			profile.get(
				"fluster_seconds",
				20.0
			)
		)
	)

	play_decay_delay_seconds = maxf(
		0.0,
		float(
			profile.get(
				"play_decay_delay_seconds",
				10.0
			)
		)
	)

	play_decay_per_second = maxf(
		0.0,
		float(
			profile.get(
				"play_decay_per_second",
				0.12
			)
		)
	)

	decay_save_interval_seconds = maxf(
		0.5,
		float(
			profile.get(
				"decay_save_interval_seconds",
				2.0
			)
		)
	)

	play_expression_map.clear()

	var play_expression_value: Variant = profile.get(
		"play_expression_map",
		{}
	)

	if play_expression_value is Dictionary:
		for key_value: Variant in (
			play_expression_value as Dictionary
		).keys():
			var source_mood: String = str(
				key_value
			).strip_edges().to_lower()

			var target_mood: String = str(
				(
					play_expression_value as Dictionary
				)[
					key_value
				]
			).strip_edges().to_lower()

			if (
				not source_mood.is_empty()
				and not target_mood.is_empty()
			):
				play_expression_map[
					source_mood
				] = target_mood

	zone_expression_maps.clear()

	var zone_expression_value: Variant = profile.get(
		"zone_expression_maps",
		{}
	)

	if zone_expression_value is Dictionary:
		zone_expression_maps = (
			zone_expression_value as Dictionary
		).duplicate(
			true
		)

	zone_effects.clear()

	var zone_effects_value: Variant = profile.get(
		"zone_effects",
		{}
	)

	if zone_effects_value is Dictionary:
		zone_effects = (
			zone_effects_value as Dictionary
		).duplicate(
			true
		)

	reluctance_max = maxf(
		1.0,
		float(
			profile.get(
				"reluctance_max",
				100.0
			)
		)
	)

	reluctance_threshold = maxf(
		0.0,
		float(
			profile.get(
				"reluctance_threshold",
				1000.0
			)
		)
	)

	reluctance_decay_delay_seconds = maxf(
		0.0,
		float(
			profile.get(
				"reluctance_decay_delay_seconds",
				8.0
			)
		)
	)

	reluctance_decay_per_second = maxf(
		0.0,
		float(
			profile.get(
				"reluctance_decay_per_second",
				0.30
			)
		)
	)

	refusal_lock_seconds = maxf(
		0.0,
		float(
			profile.get(
				"refusal_lock_seconds",
				75.0
			)
		)
	)

	refusal_reset_value = clampf(
		float(
			profile.get(
				"refusal_reset_value",
				30.0
			)
		),
		0.0,
		reluctance_max
	)

	refusal_play_multiplier = clampf(
		float(
			profile.get(
				"refusal_play_multiplier",
				0.60
			)
		),
		0.0,
		1.0
	)

	departure_chance = clampf(
		float(
			profile.get(
				"departure_chance",
				0.0
			)
		),
		0.0,
		1.0
	)

	departure_seconds = maxf(
		1.0,
		float(
			profile.get(
				"departure_seconds",
				180.0
			)
		)
	)

	departure_delay_seconds = maxf(
		0.0,
		float(
			profile.get(
				"departure_delay_seconds",
				3.2
			)
		)
	)

	locked_reaction_cooldown_seconds = maxf(
		1.0,
		float(
			profile.get(
				"locked_reaction_cooldown_seconds",
				7.0
			)
		)
	)

	fluster_moods.clear()

	var fluster_moods_value: Variant = profile.get(
		"fluster_moods",
		[
			"embarrassed"
		]
	)

	if fluster_moods_value is Array:
		for mood_value: Variant in (
			fluster_moods_value as Array
		):
			var cleaned_mood: String = str(
				mood_value
			).strip_edges().to_lower()

			if not cleaned_mood.is_empty():
				fluster_moods.append(
					cleaned_mood
				)

func _read_profiles() -> Dictionary:
	if pack_id.is_empty():
		return {}

	return CharacterProfiles.load_pack_localized_json(
		pack_id,
		PACK_PROFILE_FILENAME,
		true
	)

func _get_save_path() -> String:
	var safe_pack_id: String = pack_id

	if safe_pack_id.is_empty():
		safe_pack_id = "unknown"

	return (
		SAVE_DIRECTORY
		+ "/"
		+ safe_pack_id
		+ "/"
		+ character_id
		+ ".json"
	)

func _load_state() -> void:
	if character_id.is_empty():
		return
	var state: Dictionary = JsonStore.load_dictionary(_get_save_path(), {})
	if state.is_empty():
		return
	play_value = clampf(float(state.get("play", 0.0)), 0.0, play_max)
	total_stroke_seconds = maxf(0.0, float(state.get("stroke_seconds", 0.0)))
	pet_reaction_index = clampi(
		int(state.get("pet_reaction_index", 0)),
		0,
		pet_reaction_seconds.size()
	)
	has_pet_reacted = bool(
		state.get("has_pet_reacted", pet_reaction_index > 0)
	)
	reluctance_value = clampf(
		float(state.get("reluctance", 0.0)),
		0.0,
		reluctance_max
	)
	interaction_locked_until_unix = int(
		state.get("interaction_locked_until_unix", 0)
	)
	var flustered_until: int = int(state.get("flustered_until_unix", 0))
	var now_unix: int = int(Time.get_unix_time_from_system())
	last_touch_msec = Time.get_ticks_msec()
	if flustered_until > now_unix:
		flustered = true
		current_fluster_mood = str(
			state.get("fluster_mood", _pick_fluster_mood())
		).strip_edges().to_lower()
		if fluster_timer != null:
			fluster_timer.start(float(flustered_until - now_unix))
		if character_actor != null:
			call_deferred("_restore_fluster_mood")

func _restore_fluster_mood() -> void:
	if not flustered:
		return

	if character_actor == null:
		return

	if character_actor is DesktopCharacterActor:
		(character_actor as DesktopCharacterActor).set_mood(current_fluster_mood)

func _save_state() -> void:
	if character_id.is_empty():
		return
	var flustered_until: int = 0
	if flustered and fluster_timer != null and not fluster_timer.is_stopped():
		flustered_until = int(
			Time.get_unix_time_from_system() + fluster_timer.time_left
		)
	JsonStore.save_json(
		_get_save_path(),
		{
			"play": play_value,
			"stroke_seconds": total_stroke_seconds,
			"pet_reaction_index": pet_reaction_index,
			"has_pet_reacted": has_pet_reacted,
			"reluctance": reluctance_value,
			"interaction_locked_until_unix": interaction_locked_until_unix,
			"flustered_until_unix": flustered_until,
			"fluster_mood": current_fluster_mood,
		}
	)

