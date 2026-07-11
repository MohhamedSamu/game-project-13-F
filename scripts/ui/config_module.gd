extends VBoxContainer

signal back_pressed

@onready var btn_back: Button = $VScrollBar/btnBack
@onready var _scroll_root: Control = $VScrollBar


func _ready() -> void:
	btn_back.pressed.connect(func(): back_pressed.emit())
	process_mode = Node.PROCESS_MODE_ALWAYS


func grab_menu_focus() -> void:
	GamepadUINav.grab_menu_focus_if_needed(_scroll_root)
