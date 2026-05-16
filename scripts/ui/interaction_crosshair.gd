extends Control

## Retículo central: anillo hueco más pequeño; punto interior cuando hay objetivo interactuable.

@export var outer_radius_px: float = 14.0 / 2.5
@export var ring_width_px: float = 2.5 / 2.5
@export var inner_dot_radius_px: float = 4.0 / 2.5
@export var idle_color: Color = Color(1.0, 1.0, 1.0, 0.55)
@export var focused_color: Color = Color(0.94, 0.94, 0.97, 0.92)

var focused: bool = false:
	set(value):
		if focused == value:
			return
		focused = value
		queue_redraw()

@onready var prompt_label: Label = $PromptLabel


func _ready() -> void:
	add_to_group("interaction_crosshair")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if prompt_label:
		prompt_label.visible = false
	queue_redraw()


func update_focus(active: bool, prompt: String = "") -> void:
	set_highlight(active)
	set_prompt(prompt if active else "")


func set_highlight(active: bool) -> void:
	focused = active


func set_prompt(text: String) -> void:
	if prompt_label == null:
		return
	prompt_label.text = text
	prompt_label.visible = text.strip_edges().length() > 0


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var steps := 48
	draw_arc(c, outer_radius_px, 0.0, TAU, steps, idle_color if not focused else focused_color, ring_width_px, true)
	if focused:
		draw_circle(c, inner_dot_radius_px, focused_color)
