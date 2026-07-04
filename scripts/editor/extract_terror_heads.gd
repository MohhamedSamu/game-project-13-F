@tool
extends EditorScript
## Herramienta de editor: re-extrae cabezas desde el DAE importado por Godot.
## Ejecutar: File > Run (con este script abierto).
## Alternativa CLI: godot --headless --path . -s res://scripts/editor/extract_terror_heads_runner.gd

const Core := preload("res://scripts/editor/extract_terror_heads_core.gd")


func _run() -> void:
	print("ExtractTerrorHeads: extrayendo cabezas desde DAE...")
	var count := Core.extract_all()
	if count != Core.HEADS.size():
		push_error("ExtractTerrorHeads: solo se guardaron %d/%d escenas." % [count, Core.HEADS.size()])
		return
	print("ExtractTerrorHeads: terminado (%d escenas en %s)." % [count, Core.OUT_DIR])
