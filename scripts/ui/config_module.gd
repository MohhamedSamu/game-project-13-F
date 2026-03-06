extends VBoxContainer

signal back_pressed

@onready var btn_back: Button = $VScrollBar/btnBack

func _ready() -> void:
	btn_back.pressed.connect(func(): back_pressed.emit())
