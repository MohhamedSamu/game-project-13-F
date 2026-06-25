extends CanvasLayer
## A basic dialogue balloon for use with Dialogue Manager.


## The dialogue resource
@export var dialogue_resource: DialogueResource

## Start from a given title when using balloon as a [Node] in a scene.
@export var start_from_title: String = ""

## If running as a [Node] in a scene then auto start the dialogue.
@export var auto_start: bool = false

## If all other input is blocked as long as dialogue is shown.
@export var will_block_other_input: bool = true

## The action to use for advancing the dialogue (Enter / Space por defecto).
@export var next_action: StringName = &"ui_accept"

## Misma tecla que interactuar en el mundo (E).
@export var interact_action: StringName = &"interact"

## Navegar opciones de respuesta (W).
@export var menu_up_action: StringName = &"up"

## Navegar opciones de respuesta (S).
@export var menu_down_action: StringName = &"down"

## The action to use to skip typing the dialogue
@export var skip_action: StringName = &"ui_cancel"

## A sound player for voice lines (if they exist).
@onready var audio_stream_player: AudioStreamPlayer = %AudioStreamPlayer

## Temporary game states
var temporary_game_states: Array = []

## See if we are waiting for the player
var is_waiting_for_input: bool = false

## See if we are running a long mutation and should hide the balloon
var will_hide_balloon: bool = false

## A dictionary to store any ephemeral variables
var locals: Dictionary = {}

var _locale: String = TranslationServer.get_locale()

## The current line
var dialogue_line: DialogueLine:
	set(value):
		if value:
			dialogue_line = value
			apply_dialogue_line()
		else:
			# The dialogue has finished so close the balloon
			_stop_voice_blip_player()
			if owner == null:
				queue_free()
			else:
				hide()
	get:
		return dialogue_line

## A cooldown timer for delaying the balloon hide when encountering a mutation.
var mutation_cooldown: Timer = Timer.new()

## The base balloon anchor
@onready var balloon: Control = %Balloon

## Fuente del título del menú (Jackwrite). Asignar en Inspector si cambia.
@export var dialogue_font: Font = preload("res://assets/fonts/jackwrite/Jackwrite.ttf")

@export_group("Dialogue Option Audio")
@export var option_hover_sound: AudioStream = preload("res://assets/audio/menu/back.ogg")
@export var option_select_sound: AudioStream = preload("res://assets/audio/menu/enter.ogg")
@export var option_hover_volume_db: float = 0.0
@export var option_select_volume_db: float = 0.0
@export var option_hover_pitch_scale: float = 1.0
@export var option_select_pitch_scale: float = 1.0

@export_group("Voice Blips")
@export var enable_voice_blips: bool = true
@export var default_voice_profile: DialogueVoiceProfile
@export var adult_male_neutral_profile: DialogueVoiceProfile = preload("res://resources/dialogue_voices/adult_male_neutral.tres")
@export var adult_male_nervous_profile: DialogueVoiceProfile = preload("res://resources/dialogue_voices/adult_male_nervous.tres")
@export var adult_male_angry_profile: DialogueVoiceProfile = preload("res://resources/dialogue_voices/adult_male_angry.tres")
@export var muted_character_names: PackedStringArray = ["PLAYER", "Player", "player"]

@export_group("Dialogue Typing")
## Segundos entre cada carácter revelado. Más alto = typewriter más lento (addon: 0.02).
@export_range(0.01, 0.2, 0.005) var typing_seconds_per_step: float = 0.05
## Pausa extra tras . ? ! mientras se escribe.
@export_range(0.1, 1.0, 0.05) var typing_seconds_per_pause: float = 0.35

## Bloque inferior (20% márgenes laterales, sin panel visible).
@onready var dialogue_anchor: MarginContainer = %DialogueAnchor

## The label showing the name of the currently speaking character
@onready var character_label: RichTextLabel = %CharacterLabel

## The label showing the currently spoken dialogue
@onready var dialogue_label: DialogueLabel = %DialogueLabel

## The menu of responses
@onready var responses_menu: DialogueResponsesMenu = %ResponsesMenu

## Indicador legacy (oculto; se usa ContinueDots).
@onready var progress: Polygon2D = %Progress

@onready var continue_dots: Label = %ContinueDots

const ANCHOR_TOP_NO_RESPONSES: float = 0.73
const ANCHOR_TOP_WITH_RESPONSES: float = 0.62
const ANCHOR_BOTTOM: float = 0.96

var option_hover_audio: AudioStreamPlayer
var option_select_audio: AudioStreamPlayer
var last_hovered_response_index: int = -1
var _skip_next_response_hover_sound: bool = false

var voice_blip_player: AudioStreamPlayer
var current_voice_profile: DialogueVoiceProfile
var last_voice_blip_time: float = 0.0
var revealed_character_count: int = 0
var _voice_blips_active: bool = false


func _ready() -> void:
	balloon.hide()
	progress.hide()
	continue_dots.hide()
	_apply_dialogue_fonts()
	_apply_dialogue_typing_speed()
	Engine.get_singleton("DialogueManager").mutated.connect(_on_mutated)

	# If the responses menu doesn't have a next action set, use this one
	if responses_menu.next_action.is_empty():
		responses_menu.next_action = next_action

	mutation_cooldown.timeout.connect(_on_mutation_cooldown_timeout)
	add_child(mutation_cooldown)

	dialogue_label.spoke.connect(_on_dialogue_label_spoke)
	dialogue_label.skipped_typing.connect(_on_dialogue_label_skipped_typing)

	if auto_start:
		if not is_instance_valid(dialogue_resource):
			assert(false, DMConstants.get_error_message(DMConstants.ERR_MISSING_RESOURCE_FOR_AUTOSTART))
		start()


func _process(_delta: float) -> void:
	if not is_instance_valid(dialogue_line):
		return
	progress.visible = false
	var show_continue: bool = (
		not dialogue_label.is_typing
		and dialogue_line.responses.size() == 0
		and not dialogue_line.has_tag("voice")
		and is_waiting_for_input
	)
	continue_dots.visible = show_continue


func _unhandled_input(event: InputEvent) -> void:
	if not will_block_other_input or not balloon.visible:
		return

	if _handle_dialogue_keyboard(event):
		get_viewport().set_input_as_handled()
		return

	# Bloquear el resto de input de juego (WASD, etc.) sin interferir con clics en la UI.
	if not (event is InputEventMouseButton or event is InputEventMouseMotion):
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	## Detect a change of locale and update the current dialogue line to show the new language
	if what == NOTIFICATION_TRANSLATION_CHANGED and _locale != TranslationServer.get_locale() and is_instance_valid(dialogue_label):
		_locale = TranslationServer.get_locale()
		var visible_ratio: float = dialogue_label.visible_ratio
		dialogue_line = await dialogue_resource.get_next_dialogue_line(dialogue_line.id)
		if visible_ratio < 1:
			dialogue_label.skip_typing()


func _advance_actions_pressed(event: InputEvent) -> bool:
	return event.is_action_pressed(next_action) or event.is_action_pressed(interact_action)


func _handle_dialogue_keyboard(event: InputEvent) -> bool:
	if not is_instance_valid(dialogue_line):
		return false

	if responses_menu.visible:
		if event.is_action_pressed(menu_up_action):
			_navigate_responses(-1)
			return true
		if event.is_action_pressed(menu_down_action):
			_navigate_responses(1)
			return true
		if _advance_actions_pressed(event):
			_select_focused_response()
			return true
		return false

	if dialogue_label.is_typing:
		if _advance_actions_pressed(event) or event.is_action_pressed(skip_action):
			dialogue_label.skip_typing()
			return true
		return false

	if is_waiting_for_input and dialogue_line.responses.size() == 0:
		if _advance_actions_pressed(event):
			next(dialogue_line.next_id)
			return true

	return false


func _navigate_responses(direction: int) -> void:
	var items: Array = responses_menu.get_menu_items()
	if items.is_empty():
		return

	var focused: Control = get_viewport().gui_get_focus_owner() as Control
	var index := items.find(focused)
	if index < 0:
		items[0].grab_focus()
		return

	index = wrapi(index + direction, 0, items.size())
	if index == last_hovered_response_index:
		return
	(items[index] as Control).grab_focus()


func _select_focused_response() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner() as Control
	if focused == null or focused not in responses_menu.get_menu_items():
		return
	if focused.has_meta("response"):
		_confirm_response(focused.get_meta("response"))


func _confirm_response(response: DialogueResponse) -> void:
	if response == null:
		return
	_play_option_select_sound()
	next(response.next_id)


func _get_response_index(response_control: Control) -> int:
	return responses_menu.get_menu_items().find(response_control)


## Start some dialogue
func start(with_dialogue_resource: DialogueResource = null, title: String = "", extra_game_states: Array = []) -> void:
	temporary_game_states = [self] + extra_game_states
	is_waiting_for_input = false
	if is_instance_valid(with_dialogue_resource):
		dialogue_resource = with_dialogue_resource
	if not title.is_empty():
		start_from_title = title
	dialogue_line = await dialogue_resource.get_next_dialogue_line(start_from_title, temporary_game_states)
	show()


## Apply any changes to the balloon given a new [DialogueLine].
func apply_dialogue_line() -> void:
	mutation_cooldown.stop()

	progress.hide()
	is_waiting_for_input = false
	balloon.focus_mode = Control.FOCUS_ALL
	balloon.grab_focus()

	var has_character: bool = not dialogue_line.character.is_empty()
	var character_row: Node = character_label.get_parent()
	if character_row is CanvasItem:
		(character_row as CanvasItem).visible = has_character
	character_label.visible = has_character
	character_label.text = tr(dialogue_line.character, "dialogue").to_upper()

	dialogue_label.hide()
	dialogue_label.dialogue_line = dialogue_line

	responses_menu.hide()
	responses_menu.responses = dialogue_line.responses
	_set_dialogue_anchor_for_responses(dialogue_line.responses.size() > 0)

	# Show our balloon
	balloon.show()
	will_hide_balloon = false
	_fade_in_dialogue_panel()

	dialogue_label.show()
	if not dialogue_line.text.is_empty():
		_reset_voice_blips_for_line(dialogue_line.character)
		dialogue_label.type_out()
		await dialogue_label.finished_typing
		_stop_voice_blip_player()

	# Wait for next line
	if dialogue_line.has_tag("voice"):
		audio_stream_player.stream = load(dialogue_line.get_tag_value("voice"))
		audio_stream_player.play()
		await audio_stream_player.finished
		next(dialogue_line.next_id)
	elif dialogue_line.responses.size() > 0:
		balloon.focus_mode = Control.FOCUS_NONE
		last_hovered_response_index = -1
		_skip_next_response_hover_sound = true
		responses_menu.show()
		_update_response_labels()
	elif dialogue_line.time != "":
		var time: float = dialogue_line.text.length() * 0.02 if dialogue_line.time == "auto" else dialogue_line.time.to_float()
		await get_tree().create_timer(time).timeout
		next(dialogue_line.next_id)
	else:
		is_waiting_for_input = true
		balloon.focus_mode = Control.FOCUS_ALL
		balloon.grab_focus()


## Go to the next line
func next(next_id: String) -> void:
	dialogue_line = await dialogue_resource.get_next_dialogue_line(next_id, temporary_game_states)


#region Signals


func _on_mutation_cooldown_timeout() -> void:
	if will_hide_balloon:
		will_hide_balloon = false
		_stop_voice_blip_player()
		balloon.hide()


func _on_mutated(mutation: Dictionary) -> void:
	if not mutation.is_inline:
		is_waiting_for_input = false
		will_hide_balloon = true
		_stop_voice_blip_player()
		mutation_cooldown.start(0.1)


func _on_balloon_gui_input(event: InputEvent) -> void:
	# See if we need to skip typing of the dialogue
	if dialogue_label.is_typing:
		var mouse_was_clicked: bool = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed()
		var skip_button_was_pressed: bool = event.is_action_pressed(skip_action)
		if mouse_was_clicked or skip_button_was_pressed or _advance_actions_pressed(event):
			get_viewport().set_input_as_handled()
			dialogue_label.skip_typing()
			return

	if not is_waiting_for_input:
		return
	if dialogue_line.responses.size() > 0:
		return

	# When there are no response options the balloon itself is the clickable thing
	get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
		next(dialogue_line.next_id)
	elif _advance_actions_pressed(event) and get_viewport().gui_get_focus_owner() == balloon:
		next(dialogue_line.next_id)


func _on_responses_menu_response_selected(response: DialogueResponse) -> void:
	_confirm_response(response)


func _on_responses_menu_response_focused(response_control: Control) -> void:
	_update_response_labels()
	if not responses_menu.visible:
		return

	var index := _get_response_index(response_control)
	if index < 0:
		return

	if _skip_next_response_hover_sound:
		_skip_next_response_hover_sound = false
		last_hovered_response_index = index
		return

	if index == last_hovered_response_index:
		return

	last_hovered_response_index = index
	_play_option_hover_sound()


func _apply_dialogue_fonts() -> void:
	if dialogue_font == null:
		return
	character_label.add_theme_font_override(&"normal_font", dialogue_font)
	dialogue_label.add_theme_font_override(&"normal_font", dialogue_font)
	continue_dots.add_theme_font_override(&"font", dialogue_font)


func _apply_dialogue_typing_speed() -> void:
	dialogue_label.seconds_per_step = typing_seconds_per_step
	dialogue_label.seconds_per_pause_step = typing_seconds_per_pause


func _set_dialogue_anchor_for_responses(has_responses: bool) -> void:
	if dialogue_anchor == null:
		return
	dialogue_anchor.anchor_top = ANCHOR_TOP_WITH_RESPONSES if has_responses else ANCHOR_TOP_NO_RESPONSES
	dialogue_anchor.anchor_bottom = ANCHOR_BOTTOM
	dialogue_anchor.set_meta(&"rest_offset_top", dialogue_anchor.offset_top)


func _update_response_labels() -> void:
	var focused: Control = get_viewport().gui_get_focus_owner() as Control
	for item: Control in responses_menu.get_menu_items():
		if not item.has_meta("response"):
			continue
		var response: DialogueResponse = item.get_meta("response")
		var label_text: String = response.text.to_upper()
		if item == focused:
			item.text = "> " + label_text
		else:
			item.text = "  " + label_text


func _fade_in_dialogue_panel() -> void:
	if dialogue_anchor == null:
		return
	var rest_offset_top: float = dialogue_anchor.get_meta(&"rest_offset_top", dialogue_anchor.offset_top)
	dialogue_anchor.set_meta(&"rest_offset_top", rest_offset_top)
	dialogue_anchor.modulate = Color(1, 1, 1, 0)
	dialogue_anchor.offset_top = rest_offset_top + 8
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(dialogue_anchor, "modulate:a", 1.0, 0.16)
	tween.tween_property(dialogue_anchor, "offset_top", rest_offset_top, 0.16).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _ensure_option_audio_players() -> void:
	if option_hover_audio == null:
		option_hover_audio = AudioStreamPlayer.new()
		option_hover_audio.name = "OptionHoverAudio"
		option_hover_audio.bus = "SFX"
		add_child(option_hover_audio)

	if option_select_audio == null:
		option_select_audio = AudioStreamPlayer.new()
		option_select_audio.name = "OptionSelectAudio"
		option_select_audio.bus = "SFX"
		add_child(option_select_audio)

	option_hover_audio.stream = option_hover_sound
	option_hover_audio.volume_db = option_hover_volume_db
	option_hover_audio.pitch_scale = option_hover_pitch_scale

	option_select_audio.stream = option_select_sound
	option_select_audio.volume_db = option_select_volume_db
	option_select_audio.pitch_scale = option_select_pitch_scale


func _play_option_hover_sound() -> void:
	if option_hover_sound == null:
		return
	_ensure_option_audio_players()
	option_hover_audio.stop()
	option_hover_audio.play()


func _play_option_select_sound() -> void:
	if option_select_sound == null:
		return
	_ensure_option_audio_players()
	option_select_audio.stop()
	option_select_audio.play()


func _get_voice_profile_for_character(character_name: String) -> DialogueVoiceProfile:
	if not enable_voice_blips:
		return null

	var upper_name := character_name.strip_edges().to_upper()
	if upper_name.is_empty():
		return null

	for muted_name in muted_character_names:
		if upper_name == String(muted_name).to_upper():
			return null

	if upper_name == "PLAYER":
		return null

	if upper_name == "NATHAN":
		return adult_male_neutral_profile

	if upper_name == "OLD MAN":
		return adult_male_neutral_profile

	return default_voice_profile


func _reset_voice_blips_for_line(character_name: String) -> void:
	_stop_voice_blip_player()
	revealed_character_count = 0
	last_voice_blip_time = 0.0

	if is_instance_valid(dialogue_line) and dialogue_line.has_tag("voice"):
		current_voice_profile = null
		_voice_blips_active = false
		return

	current_voice_profile = _get_voice_profile_for_character(character_name)
	_voice_blips_active = current_voice_profile != null and current_voice_profile.is_valid()


func _on_dialogue_label_spoke(letter: String, _letter_index: int, _speed: float) -> void:
	_maybe_play_voice_blip(letter)


func _on_dialogue_label_skipped_typing() -> void:
	_stop_voice_blip_player()


func _maybe_play_voice_blip(character: String) -> void:
	if not _voice_blips_active or current_voice_profile == null:
		return

	if current_voice_profile.should_skip_character(character):
		return

	revealed_character_count += 1

	if current_voice_profile.characters_per_blip > 1:
		if revealed_character_count % current_voice_profile.characters_per_blip != 0:
			return

	var now := Time.get_ticks_msec() / 1000.0
	if now - last_voice_blip_time < current_voice_profile.min_time_between_blips:
		return

	last_voice_blip_time = now
	_play_voice_blip(current_voice_profile)


func _ensure_voice_blip_player() -> void:
	if voice_blip_player != null:
		return

	voice_blip_player = AudioStreamPlayer.new()
	voice_blip_player.name = "VoiceBlipPlayer"
	voice_blip_player.bus = "SFX"
	add_child(voice_blip_player)


func _play_voice_blip(profile: DialogueVoiceProfile) -> void:
	if profile == null or profile.clips.is_empty():
		return

	_ensure_voice_blip_player()

	var clip: AudioStream = profile.clips.pick_random()
	if clip == null:
		return

	voice_blip_player.stop()
	voice_blip_player.stream = clip
	voice_blip_player.volume_db = profile.volume_db
	voice_blip_player.pitch_scale = randf_range(profile.pitch_min, profile.pitch_max)
	voice_blip_player.play()


func _stop_voice_blip_player() -> void:
	_voice_blips_active = false
	if voice_blip_player != null:
		voice_blip_player.stop()


#endregion
