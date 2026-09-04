extends RefCounted
class_name CreatorCatalog

const MOODS: Array[String] = [
	"neutral",
	"happy",
	"amused",
	"smug",
	"curious",
	"surprised",
	"annoyed",
	"angry",
	"worried",
	"sad",
	"embarrassed",
	"tired",
	"flustered_worried",
	"flustered_surprised",
	"flustered_annoyed"
]

const SLOT_LABELS: Dictionary = {
	"body": "Body",
	"neutral": "Neutral",
	"happy": "Happy",
	"amused": "Amused",
	"smug": "Smug",
	"curious": "Curious",
	"surprised": "Surprised",
	"annoyed": "Annoyed",
	"angry": "Angry",
	"worried": "Worried",
	"sad": "Sad",
	"embarrassed": "Embarrassed",
	"tired": "Tired",
	"flustered_worried": "Flustered · Worried",
	"flustered_surprised": "Flustered · Surprised",
	"flustered_annoyed": "Flustered · Annoyed",
	"eyes_open": "Blink · Open",
	"eyes_half": "Blink · Half",
	"eyes_closed": "Blink · Closed"
}

const CHAT_COLOR_PRESETS: Array[Dictionary] = [
	{"label": "Blue", "color": "#3A83F7"},
	{"label": "Green", "color": "#53B559"},
	{"label": "Yellow", "color": "#F6C543"},
	{"label": "Pink", "color": "#F077AF"},
	{"label": "Orange", "color": "#EE7C37"},
	{"label": "Purple", "color": "#A67DF2"}
]

