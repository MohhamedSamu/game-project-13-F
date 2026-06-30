extends Node
## Secuencia narrativa de Juan en scene 1 (4ª pared + transición nocturna Sky3D).

const HOURS_PER_REAL_SECOND := 3.0
const SKY_LOOK_BLEND_SEC := 0.55
const SKY_LOOK_MARKER_NAME := &"NightSkyLookTarget"
const DIALOGUE_ANIM := &"breathing_idle"
const SKY_IDLE_ANIM := &"idle"

var _saved_minutes_per_day: float = 15.0
var _saved_dialogue_focus: Node3D = null


func play_fourth_wall_night_transition() -> void:
	var sky := _find_sky3d()
	if sky == null:
		push_warning("Scene1PoliceDirector: no se encontró Sky3D.")
		return

	var pickup := _find_scene1_pickup()
	var police := _find_police_npc(pickup)
	var sky_marker := _find_sky_look_marker(pickup)
	var game_player := GameManager.get_player() as Node

	_saved_dialogue_focus = DialogueController.current_focus_target

	if sky_marker == null:
		push_warning("Scene1PoliceDirector: coloca un Marker3D '%s' en Scene1FlashlightPickup." % SKY_LOOK_MARKER_NAME)

	_set_police_animation(police, SKY_IDLE_ANIM)
	await _look_toward_sky(game_player, sky_marker)
	_force_player_flashlight_near(game_player)
	await _advance_sky_to_midnight(sky)
	await _restore_dialogue_focus(game_player, police)


func _find_sky3d() -> Sky3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("Sky3D", true, false) as Sky3D


func _find_scene1_pickup() -> Node3D:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.find_child("Scene1FlashlightPickup", true, false) as Node3D


func _find_police_npc(pickup: Node3D = null) -> Node3D:
	if pickup == null:
		pickup = _find_scene1_pickup()
	if pickup == null:
		return null
	return pickup.get_node_or_null("PoliceNpc") as Node3D


func _find_sky_look_marker(pickup: Node3D = null) -> Marker3D:
	if pickup == null:
		pickup = _find_scene1_pickup()
	if pickup == null:
		return null
	return pickup.get_node_or_null(String(SKY_LOOK_MARKER_NAME)) as Marker3D


func _look_toward_sky(player: Node, sky_marker: Marker3D) -> void:
	if player != null and sky_marker != null and sky_marker.is_inside_tree():
		if player.has_method("focus_camera_on"):
			player.focus_camera_on(sky_marker)
		elif player.has_method("focus_camera_on_world_point"):
			player.focus_camera_on_world_point(sky_marker.global_position)
	elif player != null and player.has_method("focus_camera_on_world_point"):
		push_warning("Scene1PoliceDirector: sin marker de cielo; usando fallback alto.")
		player.focus_camera_on_world_point(Vector3(0.0, 6.0, 0.0))

	if SKY_LOOK_BLEND_SEC > 0.0:
		await get_tree().create_timer(SKY_LOOK_BLEND_SEC).timeout


func _force_player_flashlight_near(player: Node) -> void:
	if player != null and player.has_method("force_held_flashlight_near"):
		player.force_held_flashlight_near()


func _advance_sky_to_midnight(sky: Sky3D) -> void:
	var tod := sky.tod
	if tod == null:
		tod = sky.get_node_or_null("TimeOfDay") as TimeOfDay
	if tod == null:
		push_warning("Scene1PoliceDirector: Sky3D sin TimeOfDay.")
		return

	_saved_minutes_per_day = tod.minutes_per_day
	tod.minutes_per_day = 24.0 / (HOURS_PER_REAL_SECOND * 60.0)
	sky.game_time_enabled = true

	var hours_remaining := fposmod(24.0 - tod.current_time, 24.0)
	if is_zero_approx(hours_remaining):
		hours_remaining = 24.0
	var max_wait_sec := (hours_remaining / HOURS_PER_REAL_SECOND) + 2.0
	var elapsed := 0.0

	while elapsed < max_wait_sec:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		var hour := tod.current_time
		if hour >= 23.92 or hour < 0.08:
			break

	tod.set_time(0, 0, 0)
	sky.game_time_enabled = false
	tod.minutes_per_day = _saved_minutes_per_day


func _restore_dialogue_focus(player: Node, police: Node3D) -> void:
	if player == null or police == null or not police.is_inside_tree():
		return

	var focus := _resolve_dialogue_focus(police)
	if player.has_method("focus_camera_on"):
		player.focus_camera_on(focus)

	_set_police_animation(police, DIALOGUE_ANIM)


func _resolve_dialogue_focus(police: Node3D) -> Node3D:
	if _saved_dialogue_focus != null and is_instance_valid(_saved_dialogue_focus):
		return _saved_dialogue_focus

	var focus := police.get_node_or_null("DialogueFocusPoint") as Node3D
	if focus != null:
		return focus

	return police


func _set_police_animation(police: Node3D, animation_name: StringName) -> void:
	if police == null:
		return
	if police.has_method("play_animation"):
		police.play_animation(String(animation_name))
