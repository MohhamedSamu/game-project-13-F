class_name DialogueBeatResolver
extends RefCounted


static func resolve(profile: NpcDialogueProfile, npc_id: String = "") -> NpcDialogueBeat:
	if profile == null:
		return null

	var resolved_npc_id := npc_id if not npc_id.is_empty() else profile.npc_id
	for beat in profile.beats:
		if beat == null:
			continue
		if beat.play_once and GameManager.was_dialogue_beat_played(resolved_npc_id, beat.beat_id):
			continue
		if not _beat_matches(beat):
			continue
		return beat

	return null


static func resolve_title(profile: NpcDialogueProfile, npc_id: String = "") -> String:
	if profile == null:
		return "start"
	var beat := resolve(profile, npc_id)
	if beat != null:
		return beat.dialogue_title
	return profile.fallback_title


static func _beat_matches(beat: NpcDialogueBeat) -> bool:
	if not beat.required_scene_id.is_empty():
		if GameManager.get_level_scene() != beat.required_scene_id:
			return false

	for flag_name in beat.required_flags:
		if not GameManager.get_flag(flag_name):
			return false

	for objective_id in beat.forbidden_objectives:
		if _has_objective_for_beat(beat, objective_id):
			return false

	for objective_id in beat.required_objectives:
		if not _has_objective_for_beat(beat, objective_id):
			return false

	return true


static func _has_objective_for_beat(beat: NpcDialogueBeat, objective_id: String) -> bool:
	if beat.required_objectives_any_scene:
		return GameManager.has_objective_in_level(objective_id)
	if not beat.required_objectives_scene_id.is_empty():
		return GameManager.has_objective(objective_id, beat.required_objectives_scene_id)
	return GameManager.has_objective(objective_id)
