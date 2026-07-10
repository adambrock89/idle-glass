extends Node

var MODERN_FONT_NAMES: PackedStringArray = PackedStringArray(["Segoe UI", "Inter", "Noto Sans", "Roboto", "Arial"])
const APPLIED_META_KEY := &"global_font_applied"

var modern_font: SystemFont

func _ready() -> void:
	modern_font = SystemFont.new()
	modern_font.font_names = MODERN_FONT_NAMES
	call_deferred("_apply_to_tree")
	get_tree().node_added.connect(_on_node_added)

func _apply_to_tree() -> void:
	var current_scene := get_tree().current_scene
	if current_scene != null:
		_apply_to_node(current_scene)

func _on_node_added(node: Node) -> void:
	_apply_to_node(node)

func _apply_to_node(node: Node) -> void:
	if node is Control:
		_apply_to_control(node as Control)

	for child in node.get_children():
		if child is Node:
			_apply_to_node(child)

func _apply_to_control(control: Control) -> void:
	if control.has_meta(APPLIED_META_KEY):
		return

	control.add_theme_font_override("font", modern_font)
	control.set_meta(APPLIED_META_KEY, true)
