extends RefCounted
class_name CreatorNaming

const INITIALS: Array[String] = [
	"g", "kk", "n", "d", "tt", "r", "m", "b", "pp", "s", "ss", "",
	"j", "jj", "ch", "k", "t", "p", "h"
]
const VOWELS: Array[String] = [
	"a", "ae", "ya", "yae", "eo", "e", "yeo", "ye", "o", "wa", "wae",
	"oe", "yo", "u", "wo", "we", "wi", "yu", "eu", "ui", "i"
]
const FINALS: Array[String] = [
	"", "k", "k", "ks", "n", "nj", "nh", "t", "l", "lk", "lm", "lb",
	"ls", "lt", "lp", "lh", "m", "p", "ps", "t", "t", "ng", "t", "t",
	"k", "t", "p", "h"
]

static func make_id(display_name: String, fallback: String) -> String:
	var romanized: String = ""
	var previous_kind: String = ""
	for index: int in range(display_name.length()):
		var code: int = display_name.unicode_at(index)
		if code >= 0xAC00 and code <= 0xD7A3:
			if previous_kind == "ascii" and not romanized.ends_with("_"):
				romanized += "_"
			var syllable: int = code - 0xAC00
			romanized += INITIALS[floori(float(syllable) / 588.0)]
			romanized += VOWELS[floori(float(syllable % 588) / 28.0)]
			romanized += FINALS[syllable % 28]
			previous_kind = "hangul"
		elif (
			(code >= 48 and code <= 57)
			or (code >= 65 and code <= 90)
			or (code >= 97 and code <= 122)
		):
			if previous_kind == "hangul" and not romanized.ends_with("_"):
				romanized += "_"
			romanized += String.chr(code)
			previous_kind = "ascii"
		else:
			romanized += "_"
			previous_kind = "separator"

	var clean: String = romanized.to_lower()
	var regex: RegEx = RegEx.new()
	regex.compile("[^a-z0-9_]+")
	clean = regex.sub(clean, "_", true)
	while clean.contains("__"):
		clean = clean.replace("__", "_")
	clean = clean.trim_prefix("_").trim_suffix("_")
	return fallback if clean.is_empty() else clean
