class_name JumpscareScreamLibrary
extends RefCounted
## Pool de gritos por intensidad (soft / med / hard) en assets/audio/SFX/screams.
## Preload explícito: DirAccess.get_files_at() falla en builds exportadas (PCK).

enum Tier {
	SOFT,
	MEDIUM,
	HARD,
}

const _SOFT_CLIPS: Array[AudioStream] = [
	preload("res://assets/audio/SFX/screams/soft1.mp3"),
	preload("res://assets/audio/SFX/screams/soft2.mp3"),
	preload("res://assets/audio/SFX/screams/soft3.mp3"),
	preload("res://assets/audio/SFX/screams/soft4.mp3"),
]

const _MEDIUM_CLIPS: Array[AudioStream] = [
	preload("res://assets/audio/SFX/screams/med1.mp3"),
	preload("res://assets/audio/SFX/screams/med2.mp3"),
	preload("res://assets/audio/SFX/screams/med3.mp3"),
	preload("res://assets/audio/SFX/screams/med4.mp3"),
]

const _HARD_CLIPS: Array[AudioStream] = [
	preload("res://assets/audio/SFX/screams/hard1.mp3"),
	preload("res://assets/audio/SFX/screams/hard2.mp3"),
	preload("res://assets/audio/SFX/screams/hard3.mp3"),
	preload("res://assets/audio/SFX/screams/hard4.mp3"),
	preload("res://assets/audio/SFX/screams/hard5.mp3"),
	preload("res://assets/audio/SFX/screams/hard6.mp3"),
	preload("res://assets/audio/SFX/screams/hard7.mp3"),
]

const _TIER_CLIPS := {
	Tier.SOFT: _SOFT_CLIPS,
	Tier.MEDIUM: _MEDIUM_CLIPS,
	Tier.HARD: _HARD_CLIPS,
}


static func pick_random(tier: Tier) -> AudioStream:
	var clips := get_clips(tier)
	if clips.is_empty():
		return null
	return clips.pick_random() as AudioStream


static func get_clips(tier: Tier) -> Array[AudioStream]:
	if not _TIER_CLIPS.has(tier):
		return []
	return (_TIER_CLIPS[tier] as Array).duplicate() as Array[AudioStream]


static func clear_cache() -> void:
	pass
