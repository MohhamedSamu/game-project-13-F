extends CharacterBody3D
## NPC payaso: solo física. Diálogos y enfoque en componentes hijos.

const SPEED := 5.0


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
