extends SceneTree
## Ejecutar: godot --headless --path . -s res://scripts/editor/extract_terror_heads_runner.gd

const Core := preload("res://scripts/editor/extract_terror_heads_core.gd")


func _initialize() -> void:
	print("ExtractTerrorHeadsRunner: extrayendo cabezas desde DAE...")
	var count := Core.extract_all()
	if count != Core.HEADS.size():
		push_error("ExtractTerrorHeadsRunner: solo se guardaron %d/%d escenas." % [count, Core.HEADS.size()])
		quit(1)
		return
	print("ExtractTerrorHeadsRunner: listo (%d escenas)." % count)
	quit()
