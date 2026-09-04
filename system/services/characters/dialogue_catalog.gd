extends RefCounted
class_name DialogueCatalog

const DEFAULT_MOOD: String = "neutral"

const BASE_MOODS: Array[String] = [
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
	"tired"
]

const EXTENDED_MOODS: Array[String] = [
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
	"flustered",
	"flustered_worried",
	"flustered_surprised",
	"flustered_annoyed"
]

static func normalize_mood(mood: String, extended: bool = true) -> String:
	var cleaned: String = mood.strip_edges().to_lower()
	var allowed: Array[String] = EXTENDED_MOODS if extended else BASE_MOODS
	return cleaned if allowed.has(cleaned) else DEFAULT_MOOD
