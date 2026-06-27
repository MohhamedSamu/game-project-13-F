class_name LevelIntroParagraph
extends Resource

enum TextStyle {
	DEMO,
	INNER_THOUGHT,
}

@export_multiline var text: String = ""
@export var style: TextStyle = TextStyle.DEMO
