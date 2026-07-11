extends Node3D
## Secuencia de cierre: cámara lenta, silly dance, outro y créditos estilo inner thoughts.

const SILLY_DANCE_ANIM := "silly_dance"
const OUTRO_MUSIC := preload("res://assets/audio/horrorMusic/outro.mp3")
const THANKS_FONT := preload("res://assets/fonts/jackwrite/Jackwrite.ttf")
const INNER_THOUGHT_COLOR := Color(0.796, 0.694, 0.404, 1.0)
const Character09Bake := preload("res://scripts/characters/character_09_bake.gd")
const Character05Bake := preload("res://scripts/characters/character_05_bake.gd")
const OldLadyGhostBake := preload("res://scripts/characters/old_lady_ghost_bake.gd")
const MAIN_MENU_SCENE_PATH := "res://scenes/main/main_menu.tscn"

@export_group("Cámara")
@export_range(1.0, 60.0, 0.5) var camera_travel_duration: float = 30.0
@export var camera_end_position: Vector3 = Vector3(14.226, 2.808, 22.961)

@export_group("Créditos")
@export_range(1.0, 60.0, 0.5) var credits_total_duration: float = 30.0
@export var credits_opening_text: String = "Gracias por jugar"
@export_range(0.5, 20.0, 0.5) var credits_opening_duration: float = 5.0
@export var credits_info_texts: PackedStringArray = PackedStringArray([
	"Proyecto 13F será un juego de terror psicológico inspirado en historias locales",
	"La historia seguirá a un vigilante asignado a la Iglesia Virgen de Fátima, en San Salvador",
	"Durante un turno que no debió aceptar. Esperalo Pronto ...",
])
@export var thanks_continue_text: String = "Gracias por jugar. Da click para volver al menu principal"
@export_range(0.0, 1.5, 0.05) var credit_text_fade_duration: float = 0.45
@export_range(0.0, 2.0, 0.05) var continue_text_fade_duration: float = 0.65

@export_group("Audio")
@export_range(-24.0, 6.0, 0.5) var outro_volume_db: float = -2.0

@onready var _camera: Camera3D = $Camera3D
@onready var _characters_root: Node3D = $Characters

var _thanks_layer: CanvasLayer
var _thanks_label: Label
var _music_player: AudioStreamPlayer
var _thanks_tween: Tween
var _awaiting_menu_input: bool = false


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _camera != null:
		_camera.current = true
	_setup_thanks_overlay()
	_start_outro_music()
	call_deferred("_begin_sequence")


func _begin_sequence() -> void:
	await get_tree().process_frame
	await get_tree().physics_frame
	await _prepare_characters_for_ending()
	_start_character_dances()
	_start_camera_travel()
	await _play_credits_timeline()
	await _show_continue_prompt()
	await _wait_for_menu_input()
	_go_to_main_menu()


func _prepare_characters_for_ending() -> void:
	if _characters_root == null:
		return
	for child in _characters_root.get_children():
		_prepare_character_for_ending(child)
	for _i in 180:
		if _characters_ready_for_dance():
			break
		await get_tree().process_frame


func _prepare_character_for_ending(node: Node) -> void:
	if node == null:
		return
	if node.has_method("set_visible_state"):
		node.call("set_visible_state", true)
	elif node is Node3D:
		(node as Node3D).visible = true
	if node is GasStationNPC:
		node.behavior_enabled = false
		node.auto_idle_on_ready = false
	for animation_player in _find_animation_players(node):
		animation_player.set_deferred("autoplay", "")


func _characters_ready_for_dance() -> bool:
	if _characters_root == null:
		return true
	for child in _characters_root.get_children():
		if not _is_character_ready_for_dance(child):
			return false
	return true


func _is_character_ready_for_dance(node: Node) -> bool:
	var character_09 := node.find_child("Character09", true, false)
	if character_09 != null and character_09.has_method("are_animations_ready"):
		return character_09.are_animations_ready()
	var old_lady_model := node.find_child("OldLadyGhostModel", true, false)
	if old_lady_model != null and old_lady_model.has_method("ensure_animations_ready"):
		old_lady_model.ensure_animations_ready()
		if old_lady_model.has_method("are_animations_ready"):
			return old_lady_model.are_animations_ready()
	return true


func _start_camera_travel() -> void:
	if _camera == null:
		return
	var tween := create_tween()
	tween.tween_property(
		_camera,
		"global_position",
		camera_end_position,
		camera_travel_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _play_credits_timeline() -> void:
	var lines: Array[Dictionary] = []
	lines.append({
		"text": credits_opening_text,
		"duration": credits_opening_duration,
	})
	var info_duration := _get_info_line_duration()
	for info_text in credits_info_texts:
		if String(info_text).strip_edges().is_empty():
			continue
		lines.append({
			"text": String(info_text),
			"duration": info_duration,
		})
	for line in lines:
		await _show_credit_line(String(line["text"]), float(line["duration"]))


func _get_info_line_duration() -> float:
	var info_count := 0
	for info_text in credits_info_texts:
		if not String(info_text).strip_edges().is_empty():
			info_count += 1
	if info_count <= 0:
		return 0.0
	var remaining := maxf(credits_total_duration - credits_opening_duration, 0.0)
	return remaining / float(info_count)


func _show_credit_line(text: String, segment_duration: float) -> void:
	if _thanks_label == null or text.is_empty() or segment_duration <= 0.0:
		return
	var is_first_line := _thanks_label.modulate.a <= 0.01
	_thanks_label.text = text
	if is_first_line:
		await _fade_thanks_label(1.0)
	else:
		_thanks_label.modulate.a = 1.0
	await get_tree().create_timer(segment_duration).timeout


func _show_continue_prompt() -> void:
	if _thanks_label == null:
		return
	if _thanks_label.modulate.a > 0.01:
		await _fade_thanks_label(0.0)
	_thanks_label.text = thanks_continue_text
	await _fade_thanks_label(1.0, continue_text_fade_duration)


func _fade_thanks_label(target_alpha: float, duration: float = -1.0) -> void:
	if _thanks_label == null:
		return
	_kill_thanks_tween()
	var fade_duration := credit_text_fade_duration if duration < 0.0 else duration
	_thanks_tween = create_tween()
	_thanks_tween.tween_property(
		_thanks_label,
		"modulate:a",
		clampf(target_alpha, 0.0, 1.0),
		maxf(fade_duration, 0.05)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _thanks_tween.finished


func _wait_for_menu_input() -> void:
	_awaiting_menu_input = true
	set_process_unhandled_input(true)
	while _awaiting_menu_input:
		await get_tree().process_frame
	_awaiting_menu_input = false
	set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if not _awaiting_menu_input:
		return
	if _is_menu_continue_input(event):
		_awaiting_menu_input = false
		get_viewport().set_input_as_handled()


func _is_menu_continue_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return key_event.pressed and not key_event.echo
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	return false


func _go_to_main_menu() -> void:
	if _music_player != null and is_instance_valid(_music_player):
		_music_player.stop()
	GameManager.reset_progress_for_new_game()
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)


func _start_character_dances() -> void:
	if _characters_root == null:
		return
	for child in _characters_root.get_children():
		_play_silly_dance_on(child)


func _play_silly_dance_on(node: Node) -> void:
	if node == null:
		return
	_ensure_silly_dance_on_node(node)
	if node is GasStationNPC:
		node.play_animation(SILLY_DANCE_ANIM)
		return
	var old_lady_model := node.find_child("OldLadyGhostModel", true, false)
	if old_lady_model != null and old_lady_model.has_method("play_animation"):
		old_lady_model.play_animation(SILLY_DANCE_ANIM)
		return
	if node.has_method("play_animation"):
		node.call("play_animation", SILLY_DANCE_ANIM)
		return
	for animation_player in _find_animation_players(node):
		if not animation_player.has_animation(SILLY_DANCE_ANIM):
			continue
		animation_player.active = true
		animation_player.play(SILLY_DANCE_ANIM)


func _ensure_silly_dance_on_node(node: Node) -> void:
	var character_09 := node.find_child("Character09", true, false)
	if character_09 != null:
		_bake_silly_dance_for_players(character_09, Character09Bake)
		return
	var character_05 := node.find_child("Character05", true, false)
	if character_05 != null:
		_bake_silly_dance_for_players(character_05, Character05Bake)
		return
	var old_lady_model := node.find_child("OldLadyGhostModel", true, false)
	if old_lady_model != null:
		if old_lady_model.has_method("ensure_animations_ready"):
			old_lady_model.ensure_animations_ready()
		_bake_silly_dance_for_players(old_lady_model, OldLadyGhostBake)


func _bake_silly_dance_for_players(root: Node, bake_script: Object) -> void:
	for animation_player in _find_animation_players(root):
		var library := _get_primary_animation_library(animation_player)
		if library == null:
			continue
		bake_script.bake_animation_into_library(library, SILLY_DANCE_ANIM)


func _get_primary_animation_library(animation_player: AnimationPlayer) -> AnimationLibrary:
	for lib_name in animation_player.get_animation_library_list():
		var library := animation_player.get_animation_library(lib_name)
		if library != null:
			return library
	return null


func _find_animation_players(node: Node) -> Array[AnimationPlayer]:
	var players: Array[AnimationPlayer] = []
	_collect_animation_players(node, players)
	return players


func _collect_animation_players(node: Node, out: Array[AnimationPlayer]) -> void:
	if node is AnimationPlayer:
		out.append(node)
	for child in node.get_children():
		_collect_animation_players(child, out)


func _setup_thanks_overlay() -> void:
	_thanks_layer = CanvasLayer.new()
	_thanks_layer.name = "ThanksOverlay"
	_thanks_layer.layer = 96
	add_child(_thanks_layer)

	var anchor := MarginContainer.new()
	anchor.name = "ThanksAnchor"
	anchor.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	anchor.offset_left = -520.0
	anchor.offset_top = -180.0
	anchor.offset_right = 520.0
	anchor.offset_bottom = -28.0
	anchor.grow_horizontal = Control.GROW_DIRECTION_BOTH
	anchor.add_theme_constant_override("margin_left", 24)
	anchor.add_theme_constant_override("margin_right", 24)
	_thanks_layer.add_child(anchor)

	_thanks_label = Label.new()
	_thanks_label.name = "ThanksLabel"
	_thanks_label.text = ""
	_thanks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thanks_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_thanks_label.add_theme_font_override("font", THANKS_FONT)
	_thanks_label.add_theme_font_size_override("font_size", 24)
	_thanks_label.add_theme_color_override("font_color", INNER_THOUGHT_COLOR)
	_thanks_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.65))
	_thanks_label.add_theme_constant_override("outline_size", 2)
	_thanks_label.modulate.a = 0.0
	anchor.add_child(_thanks_label)


func _start_outro_music() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "OutroMusic"
	_music_player.bus = &"Master"
	_music_player.volume_db = outro_volume_db
	var stream := OUTRO_MUSIC.duplicate(true) as AudioStreamMP3
	if stream != null:
		stream.loop = true
		_music_player.stream = stream
	add_child(_music_player)
	_music_player.play()


func _kill_thanks_tween() -> void:
	if _thanks_tween != null and _thanks_tween.is_valid():
		_thanks_tween.kill()
	_thanks_tween = null
