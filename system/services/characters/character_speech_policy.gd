extends RefCounted
class_name CharacterSpeechPolicy

# Restrictions belong to the speaker's profile; characters without a restriction
# retain their own voice. Apply at presentation too, covering older cached lines.
static func apply(text: String, character_id: String, pack_id: String = "") -> String:
	var profile := CharacterProfiles.load_profile(character_id, pack_id)
	return apply_policy(text, profile.get("speech_policy", {}))

static func apply_policy(text: String, policy: Dictionary) -> String:
	if policy.get("profanity_allowed", true) == false:
		var comparison := text.to_lower().replace(" ", "").replace(".", "").replace("·", "")
		comparison = comparison.replace("시발점", "")
		for word: Variant in policy.get("forbidden_words", []):
			if not str(word).is_empty() and comparison.contains(str(word).to_lower()):
				return str(policy.get("fallback", "…"))
	var names: Dictionary = policy.get("spoken_names", {})
	for alias: String in names:
		var pattern := RegEx.new()
		var escaped := alias.replace("-", "\\-")
		var technical_exclusion := "(?!\\s*(?:모니터|디스플레이))" if alias.to_lower() == "crt" else ""
		if pattern.compile("(?i)(?<![A-Za-z0-9_])" + escaped + technical_exclusion + "(가|이|는|은|를|을|와|과|야|아)?(?![A-Za-z0-9_가-힣])") != OK:
			continue
		var matches := pattern.search_all(text)
		matches.reverse()
		for found: RegExMatch in matches:
			var name := str(names[alias])
			var particle := found.get_string(1)
			if not particle.is_empty() and not name.is_empty():
				var last := name.unicode_at(name.length() - 1)
				var consonant := last >= 0xAC00 and last <= 0xD7A3 and (last - 0xAC00) % 28 != 0
				for pair: String in ["이가", "은는", "을를", "과와", "아야"]:
					if pair.contains(particle):
						particle = pair[0] if consonant else pair[1]
						break
			text = text.left(found.get_start()) + name + particle + text.substr(found.get_end())
	return text
