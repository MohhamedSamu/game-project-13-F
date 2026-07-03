extends Node3D
## Actor OldLadyGhost: aparición estática detrás de ventana (sin IA, diálogo ni jumpscare).

@export var start_hidden: bool = true
@export var play_animation_on_reveal: bool = true
@export var reveal_animation_name: String = "neck_stretching"
@export var idle_animation_name: String = "old_lady_idle"

@onready var _model_root: Node3D = $Model
@onready var _animation_player: AnimationPlayer = _find_animation_player(_model_root)


func _ready() -> void:
	if start_hidden:
		set_visible_state(false)
	elif _animation_player != null:
		play_idle()


func reveal() -> void:
	set_visible_state(true)
	if play_animation_on_reveal:
		_play_animation(reveal_animation_name)


func hide_ghost() -> void:
	if _animation_player != null:
		_animation_player.stop()
	set_visible_state(false)


func play_idle() -> void:
	_play_animation(idle_animation_name)


func play_neck_stretching() -> void:
	_play_animation("neck_stretching")


func set_visible_state(value: bool) -> void:
	visible = value


func _play_animation(anim_name: String) -> void:
	if _animation_player == null:
		push_warning("OldLadyGhost: AnimationPlayer no encontrado.")
		return
	if anim_name.is_empty():
		return
	if not _animation_player.has_animation(anim_name):
		push_warning("OldLadyGhost: animación '%s' no encontrada." % anim_name)
		return
	_animation_player.play(anim_name)


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node == null:
		return null
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null
