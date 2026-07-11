extends Control

@onready var menu_box: Control = $Panel

@onready var btn_resume: Button = $Panel/VBoxContainer/btnResume
@onready var btn_options: Button = $Panel/VBoxContainer/btnOptions
@onready var btn_main_menu: Button = $Panel/VBoxContainer/btnMainMenu

@onready var config_module: Control = $ConfigModule

@onready var sfx_enter: AudioStreamPlayer = $EnterStreamPlayer
@onready var sfx_back: AudioStreamPlayer = $BackStreamPlayer

var is_open: bool = false

func _ready() -> void:
	hide()
	config_module.visible = false

	btn_resume.pressed.connect(_resume)
	btn_options.pressed.connect(_open_options)
	btn_main_menu.pressed.connect(_go_main_menu)

	if config_module.has_signal("back_pressed"):
		config_module.connect("back_pressed", Callable(self, "_close_options"))

	call_deferred("_focus_main_menu")


func _unhandled_input(event: InputEvent) -> void:
	if GameManager.level_intro_active or GameManager.instructions_overlay_active:
		return
	if not is_open:
		if event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			open()
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if config_module.visible:
			_close_options()
		else:
			_resume()
		return
	if event.is_action_pressed("ui_accept"):
		var focused := get_viewport().gui_get_focus_owner() as Control
		if focused is BaseButton and not (focused as BaseButton).disabled:
			get_viewport().set_input_as_handled()
			(focused as BaseButton).pressed.emit()


func open() -> void:
	is_open = true
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_crosshair_pause_hidden(true)
	menu_box.visible = true
	config_module.visible = false
	call_deferred("_focus_main_menu")


func _resume() -> void:
	_play_enter()
	is_open = false
	hide()
	get_tree().paused = false
	_set_crosshair_pause_hidden(false)
	_restore_player_mouse_mode()


func _open_options() -> void:
	_play_enter()
	menu_box.visible = false
	config_module.visible = true
	if config_module.has_method("grab_menu_focus"):
		config_module.grab_menu_focus()


func _close_options() -> void:
	config_module.visible = false
	menu_box.visible = true
	_play_back()
	call_deferred("_focus_main_menu")


func _go_main_menu() -> void:
	_play_back()
	get_tree().paused = false
	_set_crosshair_pause_hidden(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.reset_progress_for_new_game()
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")


func _focus_main_menu() -> void:
	GamepadUINav.grab_first_focus(menu_box)


func _restore_player_mouse_mode() -> void:
	if InputHints.is_gamepad():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_crosshair_pause_hidden(is_hidden: bool) -> void:
	var crosshair := get_tree().get_first_node_in_group("interaction_crosshair") as Control
	if crosshair and crosshair.has_method("set_pause_hidden"):
		crosshair.set_pause_hidden(is_hidden)


func _play_enter() -> void:
	if sfx_enter:
		sfx_enter.stop()
		sfx_enter.play()


func _play_back() -> void:
	if sfx_back:
		sfx_back.stop()
		sfx_back.play()
