extends Control

@onready var btn_start: Button = $UI/MainBtns/btnStart
@onready var btn_exit: Button = $UI/MainBtns/btnExit
@onready var btn_options: Button = $UI/MainBtns/btnOptions
@onready var btn_back: Button = $UI/StartPanel/VBoxContainer/btnBack

@onready var start_panel: Control = $UI/StartPanel
@onready var checkpoint_list: VBoxContainer = $UI/StartPanel/VBoxContainer/CheckpointList

@onready var options_panel: Control = $UI/OptionsPanel

@onready var anim: AnimationPlayer = $UI/MenuAnimator

@onready var sfx_enter: AudioStreamPlayer = $EnterStreamPlayer
@onready var sfx_back: AudioStreamPlayer = $BackStreamPlayer
@onready var sfx_audio: AudioStreamPlayer = $AudioChangedStreamPlayer

# 0 = main, 1 = start, 2 = options
var current_panel: int = 0

var checkpoint_data := [
	{"id": "new_game", "title_key": "UI_MAIN_NEW_GAME", "locked": false},
]

func _play_enter() -> void:
	if sfx_enter:
		sfx_enter.stop()
		sfx_enter.play()

func _play_back() -> void:
	if sfx_back:
		sfx_back.stop()
		sfx_back.play()

func _ready() -> void:
	# Estado inicial limpio: siempre partida nueva desde escena 1.
	GameManager.reset_progress_for_new_game()
	current_panel = 0
	start_panel.visible = false
	options_panel.visible = false
	_refresh_localized_texts()
	if not Settings.locale_changed.is_connected(_on_locale_changed):
		Settings.locale_changed.connect(_on_locale_changed)
	var flags := $UI.get_node_or_null("LanguageFlags")
	if flags != null and flags.has_signal("language_change_requested"):
		if not flags.language_change_requested.is_connected(_on_language_changed):
			flags.language_change_requested.connect(_on_language_changed)
	call_deferred("_focus_main_panel")


func _on_locale_changed(_locale: String) -> void:
	_refresh_localized_texts()
	if current_panel == 1:
		_rebuild_checkpoint_list()


func _on_language_changed(_locale: String) -> void:
	_refresh_localized_texts()
	if current_panel == 1:
		_rebuild_checkpoint_list()


func _refresh_localized_texts() -> void:
	btn_start.text = tr("UI_MAIN_START")
	btn_options.text = tr("UI_MAIN_OPTIONS")
	btn_exit.text = tr("UI_MAIN_QUIT")
	btn_back.text = tr("UI_COMMON_BACK")


func _unhandled_input(event: InputEvent) -> void:
	if _try_activate_gamepad_menu_focus(event):
		return
	if event.is_action_pressed("ui_cancel") and current_panel != 0:
		get_viewport().set_input_as_handled()
		if current_panel == 1:
			_on_btn_back_pressed()
		elif current_panel == 2:
			_on_v_box_container_back_pressed()
		return
	if event.is_action_pressed("ui_accept"):
		if not GamepadUINav.should_auto_focus_menu():
			return
		var focused := get_viewport().gui_get_focus_owner() as Control
		if focused is BaseButton and not (focused as BaseButton).disabled:
			get_viewport().set_input_as_handled()
			(focused as BaseButton).pressed.emit()


func _try_activate_gamepad_menu_focus(event: InputEvent) -> bool:
	if GamepadUINav.should_auto_focus_menu():
		return false
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return false
	if event is InputEventJoypadButton and not (event as InputEventJoypadButton).pressed:
		return false
	if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) < 0.35:
		return false
	match current_panel:
		0:
			GamepadUINav.grab_first_focus($UI/MainBtns)
		1:
			GamepadUINav.grab_first_focus(checkpoint_list)
		2:
			_focus_options_panel()
	return false


func _focus_main_panel() -> void:
	GamepadUINav.grab_menu_focus_if_needed($UI/MainBtns)


func _focus_start_panel() -> void:
	GamepadUINav.grab_menu_focus_if_needed(checkpoint_list)


func _focus_options_panel() -> void:
	var config := $UI/OptionsPanel/VBoxContainer
	if config.has_method("grab_menu_focus"):
		config.grab_menu_focus()


func _on_btn_start_pressed() -> void:
	_rebuild_checkpoint_list()
	start_panel.visible = true
	options_panel.visible = false
	current_panel = 1
	anim.play("to_start")
	_play_enter()
	call_deferred("_focus_start_panel")


func _on_btn_options_pressed() -> void:
	options_panel.visible = true
	start_panel.visible = false
	current_panel = 2
	anim.play("to_options")
	_play_enter()
	call_deferred("_focus_options_panel")


func _on_btn_exit_pressed() -> void:
	_play_back()
	get_tree().quit()


func _on_btn_back_pressed() -> void:
	current_panel = 0
	anim.play("to_main")
	_play_back()
	call_deferred("_focus_main_panel")


func _on_menu_animator_animation_finished(anim_name: StringName) -> void:
	if anim_name == "to_main" || anim_name == "from_opt_to_main":
		start_panel.visible = false
		options_panel.visible = false


func _rebuild_checkpoint_list() -> void:
	for c in checkpoint_list.get_children():
		c.queue_free()

	for entry in checkpoint_data:
		var b := Button.new()
		b.text = tr(str(entry.title_key))
		b.disabled = bool(entry.locked)
		b.flat = true

		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
		b.add_theme_color_override("font_focus_color", Color(1.0, 0.85, 0.4))
		b.add_theme_font_size_override("font_size", 34)

		var id := str(entry.id)
		b.pressed.connect(func(): _on_checkpoint_selected(id))

		checkpoint_list.add_child(b)


func _on_checkpoint_selected(id: String) -> void:
	_play_enter()
	get_tree().paused = false
	Engine.time_scale = 1.0
	match id:
		"new_game":
			get_tree().change_scene_to_file("res://scenes/levels/level_2.tscn")
		_:
			print("Checkpoint not mapped:", id)


func _on_v_box_container_back_pressed() -> void:
	current_panel = 0
	anim.play("from_opt_to_main")
	_play_back()
	call_deferred("_focus_main_panel")
