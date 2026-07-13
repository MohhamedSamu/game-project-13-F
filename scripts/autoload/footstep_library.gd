extends Node
## Biblioteca de pasos por superficie (Concrete, Dirt, Grass, Gravel).
## Preload explícito: DirAccess falla en builds exportadas (PCK).

const _CONCRETE: Array[AudioStream] = [
	preload("res://assets/audio/SFX/footsteps/Concrete/Footstep Concrete 1.ogg"),
	preload("res://assets/audio/SFX/footsteps/Concrete/Footstep Concrete 2.ogg"),
	preload("res://assets/audio/SFX/footsteps/Concrete/Footstep Concrete 3.ogg"),
	preload("res://assets/audio/SFX/footsteps/Concrete/Footstep Concrete 4.ogg"),
	preload("res://assets/audio/SFX/footsteps/Concrete/Footstep Concrete 5.ogg"),
]

const _DIRT: Array[AudioStream] = [
	preload("res://assets/audio/SFX/footsteps/Dirt/Footstep Dirt 1.ogg"),
	preload("res://assets/audio/SFX/footsteps/Dirt/Footstep Dirt 2.ogg"),
	preload("res://assets/audio/SFX/footsteps/Dirt/Footstep Dirt 3.ogg"),
	preload("res://assets/audio/SFX/footsteps/Dirt/Footstep Dirt 4.ogg"),
	preload("res://assets/audio/SFX/footsteps/Dirt/Footstep Dirt 5.ogg"),
]

const _GRASS: Array[AudioStream] = [
	preload("res://assets/audio/SFX/footsteps/Grass/Footstep Grass 1.ogg"),
	preload("res://assets/audio/SFX/footsteps/Grass/Footstep Grass 2.ogg"),
	preload("res://assets/audio/SFX/footsteps/Grass/Footstep Grass 3.ogg"),
	preload("res://assets/audio/SFX/footsteps/Grass/Footstep Grass 4.ogg"),
	preload("res://assets/audio/SFX/footsteps/Grass/Footstep Grass 5.ogg"),
	preload("res://assets/audio/SFX/footsteps/Grass/Footstep Grass 6.ogg"),
]

const _GRAVEL: Array[AudioStream] = [
	preload("res://assets/audio/SFX/footsteps/Gravel/Footstep Gravel 1.ogg"),
	preload("res://assets/audio/SFX/footsteps/Gravel/Footstep Gravel 2.ogg"),
	preload("res://assets/audio/SFX/footsteps/Gravel/Footstep Gravel 3.ogg"),
	preload("res://assets/audio/SFX/footsteps/Gravel/Footstep Gravel 4.ogg"),
	preload("res://assets/audio/SFX/footsteps/Gravel/Footstep Gravel 5.ogg"),
]

const _SURFACE_CLIPS: Dictionary = {
	"Concrete": _CONCRETE,
	"Dirt": _DIRT,
	"Grass": _GRASS,
	"Gravel": _GRAVEL,
}


func get_surface_library() -> Dictionary:
	var out: Dictionary = {}
	for surface_name in _SURFACE_CLIPS.keys():
		out[surface_name] = (_SURFACE_CLIPS[surface_name] as Array).duplicate()
	return out


func get_streams_for_surface(surface_name: String) -> Array[AudioStream]:
	if _SURFACE_CLIPS.has(surface_name):
		return (_SURFACE_CLIPS[surface_name] as Array).duplicate() as Array[AudioStream]
	for key in _SURFACE_CLIPS.keys():
		if String(key).nocasecmp_to(surface_name) == 0:
			return (_SURFACE_CLIPS[key] as Array).duplicate() as Array[AudioStream]
	return []
