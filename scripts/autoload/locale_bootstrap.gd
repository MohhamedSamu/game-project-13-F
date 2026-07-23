extends Node
## Carga CSV de traducción y los registra en TranslationServer antes del resto del juego.

const UI_CSV := "res://translations/ui.csv"
const DIALOGUES_CSV := "res://translations/dialogues.csv"


func _enter_tree() -> void:
	_load_ui_csv(UI_CSV)
	_load_dialogues_csv(DIALOGUES_CSV)


func _load_ui_csv(path: String) -> void:
	var rows := _parse_csv(path)
	if rows.is_empty():
		push_warning("LocaleBootstrap: no se pudo cargar %s" % path)
		return

	var es := Translation.new()
	es.locale = "es"
	var en := Translation.new()
	en.locale = "en"

	for row in rows:
		if row.size() < 3:
			continue
		var key := str(row[0]).strip_edges()
		if key.is_empty() or key == "keys":
			continue
		var es_text := str(row[1])
		var en_text := str(row[2])
		es.add_message(key, es_text)
		en.add_message(key, en_text)
		# También mapear el texto ES literal → EN (prompts/escenas antiguas).
		if not es_text.is_empty() and es_text != key:
			en.add_message(es_text, en_text)

	TranslationServer.add_translation(es)
	TranslationServer.add_translation(en)


func _load_dialogues_csv(path: String) -> void:
	var rows := _parse_csv(path)
	if rows.is_empty():
		push_warning("LocaleBootstrap: no se pudo cargar %s" % path)
		return

	var en := Translation.new()
	en.locale = "en"

	for row in rows:
		if row.size() < 2:
			continue
		var key := str(row[0])
		if key.strip_edges().is_empty() or key.strip_edges() == "keys":
			continue
		var en_text := str(row[1])
		en.add_message(key, en_text)
		en.add_message(key, en_text, "dialogue")

	TranslationServer.add_translation(en)


func _parse_csv(path: String) -> Array:
	var out: Array = []
	if not FileAccess.file_exists(path):
		return out
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var text := f.get_as_text()
	f.close()
	# Normalizar saltos de línea.
	text = text.replace("\r\n", "\n").replace("\r", "\n")
	var i := 0
	var n := text.length()
	while i < n:
		var row: PackedStringArray = PackedStringArray()
		var field := ""
		var in_quotes := false
		while i < n:
			var ch := text[i]
			if in_quotes:
				if ch == "\"":
					if i + 1 < n and text[i + 1] == "\"":
						field += "\""
						i += 2
						continue
					in_quotes = false
					i += 1
					continue
				field += ch
				i += 1
				continue
			if ch == "\"":
				in_quotes = true
				i += 1
				continue
			if ch == ",":
				row.append(field)
				field = ""
				i += 1
				continue
			if ch == "\n":
				row.append(field)
				i += 1
				break
			field += ch
			i += 1
		if i >= n and (not field.is_empty() or not row.is_empty()):
			row.append(field)
		if not row.is_empty():
			out.append(row)
	return out
