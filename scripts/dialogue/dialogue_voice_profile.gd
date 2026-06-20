class_name DialogueVoiceProfile
extends Resource

@export var enabled: bool = true
@export var clips: Array[AudioStream] = []
@export var volume_db: float = -12.0
@export var pitch_min: float = 0.9
@export var pitch_max: float = 1.1
@export var characters_per_blip: int = 2
@export var min_time_between_blips: float = 0.035
@export var skip_spaces: bool = true
@export var skip_punctuation: bool = true

const PUNCTUATION: Array[String] = [
	".", ",", ";", ":", "!", "?", "¿", "¡", "-", "—", "\n"
]


func is_valid() -> bool:
	return enabled and not clips.is_empty()


func should_skip_character(character: String) -> bool:
	if skip_spaces and character.strip_edges() == "":
		return true
	if skip_punctuation and character in PUNCTUATION:
		return true
	return false
