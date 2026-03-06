extends Control

@onready var menu_box: Control = $Panel
@onready var btn_resume: Button = $Panel/btnResume
@onready var btn_options: Button = $Panel/btnOptions
@onready var btn_save: Button = $Panel/btnSave
@onready var btn_main_menu: Button = $Panel/btnMainMenu

@onready var config_module: Control = $ConfigModule

var is_open: bool = false

func _ready() -> void:
	hide()
	config_module.visible = false

	btn_resume.pressed.connect(_resume)
	btn_options.pressed.connect(_open_options)
	btn_main_menu.pressed.connect(_go_main_menu)
	btn_save.pressed.connect(_save_game)

	# back del config_module (tu señal back_pressed)
	if config_module.has_signal("back_pressed"):
		config_module.connect("back_pressed", Callable(self, "_close_options"))

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): # ESC por defecto
		if not is_open:
			open()
		else:
			# Si estás en opciones, vuelve al menú pausa; si no, reanuda
			if config_module.visible:
				_close_options()
			else:
				_resume()

func open() -> void:
	is_open = true
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_box.visible = true
	config_module.visible = false

func _resume() -> void:
	is_open = false
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _open_options() -> void:
	menu_box.visible = false
	config_module.visible = true

func _close_options() -> void:
	config_module.visible = false
	menu_box.visible = true

func _save_game() -> void:
	# placeholder: aquí llamas tu SaveManager
	print("Save game (todo)")

func _go_main_menu() -> void:
	# Salir al menú principal
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
