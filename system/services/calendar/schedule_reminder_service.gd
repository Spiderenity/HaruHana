extends Node
class_name ScheduleReminderService

signal reminder_prefetch_due(
	schedule: Dictionary
)

signal reminder_due(
	schedule: Dictionary
)

const ScheduleStoreScript = preload(
	"res://system/services/calendar/schedule_store.gd"
)

const REMINDER_STATE_PATH: String = (
	"user://calendar/reminder_state.json"
)

const POLL_SECONDS: float = 10.0
const CATCH_UP_SECONDS: int = 300
const PREFETCH_LEAD_SECONDS: int = 300

var schedules: Array[Dictionary] = []
var reminder_state: Dictionary = {}
var prefetch_state: Dictionary = {}
var poll_timer: Timer = null

func _ready() -> void:
	reload_schedules()
	load_reminder_state()

	poll_timer = Timer.new()
	poll_timer.name = "ScheduleReminderPoll"
	poll_timer.wait_time = POLL_SECONDS
	poll_timer.one_shot = false
	poll_timer.ignore_time_scale = true

	poll_timer.timeout.connect(
		check_now
	)

	add_child(
		poll_timer
	)

	poll_timer.start()

	call_deferred(
		"check_now"
	)

func reload_schedules() -> void:
	schedules = (
		ScheduleStoreScript.load_schedules()
	)

	_remove_deleted_schedule_state()

func check_now() -> void:
	reload_schedules()

	if schedules.is_empty():
		return

	var now: Dictionary = (
		Time.get_datetime_dict_from_system()
	)

	var now_stamp: int = (
		_local_datetime_stamp(
			now
		)
	)

	if now_stamp <= 0:
		return

	var state_changed: bool = false

	for schedule_value: Variant in schedules:
		if not (
			schedule_value is Dictionary
		):
			continue

		var schedule: Dictionary = (
			schedule_value
		)

		if not bool(
			schedule.get(
				"enabled",
				true
			)
		):
			continue

		var reminder_minutes: int = int(
			schedule.get(
				"reminder_minutes",
				10
			)
		)

		if reminder_minutes < 0:
			continue

		_emit_prefetch_if_due(
			schedule,
			now,
			now_stamp
		)

		var due: Dictionary = (
			_find_due_occurrence(
				schedule,
				now,
				now_stamp
			)
		)

		if due.is_empty():
			continue

		var schedule_id: String = str(
			schedule.get(
				"id",
				""
			)
		)

		if schedule_id.is_empty():
			continue

		var trigger_stamp: int = int(
			due.get(
				"trigger_stamp",
				0
			)
		)

		var previous_trigger: int = int(
			reminder_state.get(
				schedule_id,
				0
			)
		)

		if previous_trigger == trigger_stamp:
			continue

		reminder_state[
			schedule_id
		] = trigger_stamp

		state_changed = true

		var payload: Dictionary = (
			schedule.duplicate(
				true
			)
		)

		payload[
			"_occurrence_stamp"
		] = int(
			due.get(
				"occurrence_stamp",
				0
			)
		)

		payload[
			"_trigger_stamp"
		] = trigger_stamp

		payload[
			"_minutes_until_start"
		] = int(
			round(
				float(
					int(
						due.get(
							"occurrence_stamp",
							0
						)
					)
					- now_stamp
				) / 60.0
			)
		)

		reminder_due.emit(
			payload
		)

	if state_changed:
		save_reminder_state()

func _emit_prefetch_if_due(
	schedule: Dictionary,
	now: Dictionary,
	now_stamp: int
) -> void:

	var due: Dictionary = (
		_find_prefetch_occurrence(
			schedule,
			now,
			now_stamp
		)
	)

	if due.is_empty():
		return

	var schedule_id: String = str(
		schedule.get(
			"id",
			""
		)
	)

	if schedule_id.is_empty():
		return

	var trigger_stamp: int = int(
		due.get(
			"trigger_stamp",
			0
		)
	)

	if trigger_stamp <= 0:
		return

	if int(
		prefetch_state.get(
			schedule_id,
			0
		)
	) == trigger_stamp:
		return

	prefetch_state[
		schedule_id
	] = trigger_stamp

	var payload: Dictionary = (
		schedule.duplicate(
			true
		)
	)

	payload[
		"_occurrence_stamp"
	] = int(
		due.get(
			"occurrence_stamp",
			0
		)
	)

	payload[
		"_trigger_stamp"
	] = trigger_stamp

	payload[
		"_minutes_until_start"
	] = int(
		schedule.get(
			"reminder_minutes",
			0
		)
	)

	reminder_prefetch_due.emit(
		payload
	)

func _find_prefetch_occurrence(
	schedule: Dictionary,
	now: Dictionary,
	now_stamp: int
) -> Dictionary:

	var reminder_minutes: int = int(
		schedule.get(
			"reminder_minutes",
			10
		)
	)

	var hour: int = int(
		schedule.get(
			"hour",
			9
		)
	)

	var minute: int = int(
		schedule.get(
			"minute",
			0
		)
	)

	var current_midnight: int = (
		Time.get_unix_time_from_datetime_dict(
			{
				"year": int(
					now.get(
						"year",
						1970
					)
				),
				"month": int(
					now.get(
						"month",
						1
					)
				),
				"day": int(
					now.get(
						"day",
						1
					)
				),
				"hour": 0,
				"minute": 0,
				"second": 0
			}
		)
	)

	var best_trigger: int = -1
	var best_occurrence: int = -1

	for day_offset: int in range(
		-1,
		8
	):
		var candidate_midnight: int = (
			current_midnight
			+ day_offset * 86400
		)

		var candidate_date: Dictionary = (
			Time.get_datetime_dict_from_unix_time(
				candidate_midnight
			)
		)

		if not ScheduleStoreScript.matches_date(
			schedule,
			int(candidate_date.get("year", 1970)),
			int(candidate_date.get("month", 1)),
			int(candidate_date.get("day", 1))
		):
			continue

		var occurrence_stamp: int = (
			candidate_midnight
			+ hour * 3600
			+ minute * 60
		)

		var trigger_stamp: int = (
			occurrence_stamp
			- reminder_minutes * 60
		)

		var seconds_until_trigger: int = (
			trigger_stamp
			- now_stamp
		)

		if (
			seconds_until_trigger < 0
			or seconds_until_trigger > PREFETCH_LEAD_SECONDS
		):
			continue

		if (
			best_trigger < 0
			or trigger_stamp < best_trigger
		):
			best_trigger = trigger_stamp
			best_occurrence = occurrence_stamp

	if best_trigger < 0:
		return {}

	return {
		"trigger_stamp": best_trigger,
		"occurrence_stamp": best_occurrence
	}

func _find_due_occurrence(
	schedule: Dictionary,
	now: Dictionary,
	now_stamp: int
) -> Dictionary:

	var reminder_minutes: int = int(
		schedule.get(
			"reminder_minutes",
			10
		)
	)

	var hour: int = int(
		schedule.get(
			"hour",
			9
		)
	)

	var minute: int = int(
		schedule.get(
			"minute",
			0
		)
	)

	var current_midnight: int = (
		Time.get_unix_time_from_datetime_dict(
			{
				"year": int(
					now.get(
						"year",
						1970
					)
				),
				"month": int(
					now.get(
						"month",
						1
					)
				),
				"day": int(
					now.get(
						"day",
						1
					)
				),
				"hour": 0,
				"minute": 0,
				"second": 0
			}
		)
	)

	var best_trigger: int = -1
	var best_occurrence: int = -1

	for day_offset: int in range(
		-7,
		8
	):
		var candidate_midnight: int = (
			current_midnight
			+ day_offset * 86400
		)

		var candidate_date: Dictionary = (
			Time.get_datetime_dict_from_unix_time(
				candidate_midnight
			)
		)

		if not ScheduleStoreScript.matches_date(
			schedule,
			int(candidate_date.get("year", 1970)),
			int(candidate_date.get("month", 1)),
			int(candidate_date.get("day", 1))
		):
			continue

		var occurrence_stamp: int = (
			candidate_midnight
			+ hour * 3600
			+ minute * 60
		)

		var trigger_stamp: int = (
			occurrence_stamp
			- reminder_minutes * 60
		)

		var seconds_after_trigger: int = (
			now_stamp
			- trigger_stamp
		)

		if (
			seconds_after_trigger < 0
			or seconds_after_trigger > CATCH_UP_SECONDS
		):
			continue

		if trigger_stamp > best_trigger:
			best_trigger = trigger_stamp
			best_occurrence = occurrence_stamp

	if best_trigger < 0:
		return {}

	return {
		"trigger_stamp": best_trigger,
		"occurrence_stamp": best_occurrence
	}

func _local_datetime_stamp(
	datetime: Dictionary
) -> int:

	return Time.get_unix_time_from_datetime_dict(
		{
			"year": int(
				datetime.get(
					"year",
					1970
				)
			),
			"month": int(
				datetime.get(
					"month",
					1
				)
			),
			"day": int(
				datetime.get(
					"day",
					1
				)
			),
			"hour": int(
				datetime.get(
					"hour",
					0
				)
			),
			"minute": int(
				datetime.get(
					"minute",
					0
				)
			),
			"second": int(
				datetime.get(
					"second",
					0
				)
			)
		}
	)

func load_reminder_state() -> void:
	reminder_state.clear()
	var parsed: Dictionary = JsonStore.load_dictionary(REMINDER_STATE_PATH, {})
	for key: Variant in parsed.keys():
		reminder_state[str(key)] = int(parsed[key])

func save_reminder_state() -> void:
	JsonStore.save_json(REMINDER_STATE_PATH, reminder_state)

func _remove_deleted_schedule_state() -> void:
	if reminder_state.is_empty():
		return

	var existing_ids: Array[String] = []

	for schedule: Dictionary in schedules:
		var schedule_id: String = str(
			schedule.get(
				"id",
				""
			)
		)

		if not schedule_id.is_empty():
			existing_ids.append(
				schedule_id
			)

	var changed: bool = false

	for key: Variant in reminder_state.keys():
		var schedule_id: String = str(
			key
		)

		if existing_ids.has(
			schedule_id
		):
			continue

		reminder_state.erase(
			schedule_id
		)

		changed = true

	for key: Variant in prefetch_state.keys():
		var schedule_id: String = str(
			key
		)

		if existing_ids.has(
			schedule_id
		):
			continue

		prefetch_state.erase(
			schedule_id
		)

	if changed:
		save_reminder_state()
