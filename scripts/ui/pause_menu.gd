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

	# back del config_module (tu señal back_pressed)
	if config_module.has_signal("back_pressed"):
		config_module.connect("back_pressed", Callable(self, "_close_options"))

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.level_intro_active or GameManager.instructions_overlay_active:
		return
	if event.is_action_pressed("ui_cancel"): # ESC por defecto
		get_viewport().set_input_as_handled()
		if not is_open:
			open()
		else:
			# Si estás en opciones, vuelve al menú pausa; si no, reanuda
			if config_module.visible:
				_close_options()
			else:
				_resume()

func _set_crosshair_pause_hidden(is_hidden: bool) -> void:
	var crosshair := get_tree().get_first_node_in_group("interaction_crosshair") as Control
	if crosshair and crosshair.has_method("set_pause_hidden"):
		crosshair.set_pause_hidden(is_hidden)


func open() -> void:
	is_open = true
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_set_crosshair_pause_hidden(true)
	menu_box.visible = true
	config_module.visible = false

func _resume() -> void:
	_play_enter()
	is_open = false
	hide()
	get_tree().paused = false
	_set_crosshair_pause_hidden(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _open_options() -> void:
	_play_enter()
	menu_box.visible = false
	config_module.visible = true

func _close_options() -> void:
	config_module.visible = false
	menu_box.visible = true
	_play_back()

func _go_main_menu() -> void:
	_play_back()
	get_tree().paused = false
	_set_crosshair_pause_hidden(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GameManager.reset_progress_for_new_game()
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")

func _play_enter() -> void:
	if sfx_enter:
		sfx_enter.stop()
		sfx_enter.play()

func _play_back() -> void:
	if sfx_back:
		sfx_back.stop()
		sfx_back.play()
