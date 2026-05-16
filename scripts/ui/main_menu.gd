extends Control

@onready var btn_start: Button = $UI/MainBtns/btnStart
@onready var btn_exit: Button = $UI/MainBtns/btnExit
@onready var btn_options: Button = $UI/MainBtns/btnOptions

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
	{"id":"new_game", "title":"Partida nueva", "locked":false},
	{"id":"lvl1", "title":"Nivel 1", "locked":false},
	{"id":"lvl2", "title":"Nivel 2", "locked":false},
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
	# Estado inicial limpio
	current_panel = 0
	start_panel.visible = false
	options_panel.visible = false
	_rebuild_checkpoint_list()

# ---------- Main buttons ----------
func _on_btn_start_pressed() -> void:
	_rebuild_checkpoint_list()
	start_panel.visible = true
	options_panel.visible = false
	current_panel = 1
	anim.play("to_start")
	_play_enter()

func _on_btn_options_pressed() -> void:
	options_panel.visible = true
	start_panel.visible = false
	current_panel = 2
	anim.play("to_options")
	_play_enter()

func _on_btn_exit_pressed() -> void:
	_play_back()
	get_tree().quit()

# ---------- Back buttons ----------
func _on_btn_back_pressed() -> void:
	# Back desde Start
	current_panel = 0
	anim.play("to_main")
	_play_back()

# ---------- Animation finished ----------
func _on_menu_animator_animation_finished(anim_name: StringName) -> void:
	# Cuando regresas al main, apaga submenús
	if anim_name == "to_main" || anim_name == "from_opt_to_main":
		start_panel.visible = false
		options_panel.visible = false

# ---------- Dynamic list ----------
func _rebuild_checkpoint_list() -> void:
	for c in checkpoint_list.get_children():
		c.queue_free()

	for entry in checkpoint_data:
		var b := Button.new()
		b.text = str(entry.title)
		b.disabled = bool(entry.locked)
		b.flat = true

		b.add_theme_color_override("font_color", Color.WHITE)
		b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
		b.add_theme_font_size_override("font_size", 34)

		var id := str(entry.id)
		b.pressed.connect(func(): _on_checkpoint_selected(id))

		checkpoint_list.add_child(b)

func _on_checkpoint_selected(id: String) -> void:
	_play_enter()
	get_tree().paused = false
	
	Engine.time_scale = 1.0
	
	match id:
		"new_game", "lvl1":
			get_tree().change_scene_to_file("res://scenes/levels/level_1.tscn")
		"lvl2":
			get_tree().change_scene_to_file("res://scenes/levels/level_2.tscn")
		_:
			print("Checkpoint not mapped:", id)


func _on_v_box_container_back_pressed() -> void:
		# Back desde Options
	current_panel = 0
	anim.play("from_opt_to_main")
	_play_back()
