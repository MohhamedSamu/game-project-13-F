class_name JumpscareScreamLibrary
extends RefCounted
## Pool de gritos por intensidad (soft / med / hard) en assets/audio/SFX/screams.

enum Tier {
	SOFT,
	MEDIUM,
	HARD,
}

const SCREAMS_DIR := "res://assets/audio/SFX/screams/"

static var _cache: Dictionary = {}


static func pick_random(tier: Tier) -> AudioStream:
	var clips := get_clips(tier)
	if clips.is_empty():
		return null
	return clips.pick_random() as AudioStream


static func get_clips(tier: Tier) -> Array[AudioStream]:
	var key := int(tier)
	if _cache.has(key):
		return _cache[key]

	var clips: Array[AudioStream] = []
	var prefix := _tier_prefix(tier)

	for file_name in DirAccess.get_files_at(SCREAMS_DIR):
		if not file_name.begins_with(prefix):
			continue
		if not (file_name.ends_with(".mp3") or file_name.ends_with(".ogg") or file_name.ends_with(".wav")):
			continue
		var stream := load(SCREAMS_DIR.path_join(file_name)) as AudioStream
		if stream != null:
			clips.append(stream)

	_cache[key] = clips
	return clips


static func clear_cache() -> void:
	_cache.clear()


static func _tier_prefix(tier: Tier) -> String:
	match tier:
		Tier.SOFT:
			return "soft"
		Tier.MEDIUM:
			return "med"
		Tier.HARD:
			return "hard"
	return ""
