
extends CanvasLayer

var color_profile := ColorProfile.new()

var scoreboard_colors := {
	"red": ColorProfile.ColorName.RED,
	"orange": ColorProfile.ColorName.ORANGE,
	"yellow": ColorProfile.ColorName.YELLOW,
	"green": ColorProfile.ColorName.GREEN,
	"blue": ColorProfile.ColorName.BLUE,
	"purple": ColorProfile.ColorName.PURPLE
}

var scores := {
	"red": 0,
	"orange": 0,
	"yellow": 0,
	"green": 0,
	"blue": 0,
	"purple": 0
}

var entries := {}
var enum_to_string := {}

func _ready():
	for color_name in scoreboard_colors.keys():
		var enum_value = scoreboard_colors[color_name]
		enum_to_string[enum_value] = color_name

	var root := HBoxContainer.new()
	root.name = "ScoreboardRoot"
	root.anchor_left = 0.0
	root.anchor_top = 0.0
	root.anchor_right = 1.0
	root.anchor_bottom = 0.0
	root.offset_left = 20.0
	root.offset_top = 10.0
	root.offset_right = -20.0
	root.custom_minimum_size = Vector2(0, 48)
	root.add_theme_constant_override("separation", 24)
	add_child(root)

	for color_name in scoreboard_colors.keys():
		var entry := build_color_entry(color_name)
		root.add_child(entry)
		entries[color_name] = entry

func build_color_entry(color_name: String) -> Control:
	var entry := HBoxContainer.new()
	entry.name = "ColorEntry_%s" % color_name.capitalize()
	entry.custom_minimum_size = Vector2(120, 48)
	entry.alignment = BoxContainer.ALIGNMENT_CENTER

	var circle := CircleDrawer.new()
	circle.name = "Circle"
	circle.radius = 14.0
	circle.color = color_profile.rgb_values[scoreboard_colors[color_name]]
	entry.add_child(circle)

	var label := Label.new()
	label.name = "Label"
	label.text = str(scores[color_name])
	label.add_theme_font_size_override("font_size", 22)
	label.modulate = circle.color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	entry.add_child(label)

	return entry

func update_scores(new_scores: Dictionary) -> void:
	for key in new_scores.keys():
		if scores.has(key):
			scores[key] = new_scores[key]
			_refresh_entry(key)

func _refresh_entry(color_name: String) -> void:
	var entry: HBoxContainer = entries[color_name]
	var label: Label = entry.get_node("Label")
	label.text = str(scores[color_name])

func score_shape(fragment: Fragment) -> void:
	if fragment == null:
		return

	var enum_value := fragment.color_name
	var color_name = enum_to_string.get(enum_value, null)

	if color_name == null:
		return

	scores[color_name] += fragment.fragment_mass
	_refresh_entry(color_name)
	fragment.queue_free()

func process_batch(fragments: Array) -> void:
	if fragments.is_empty():
		return

	var total_mass := 0.0
	var color_counts := {}

	for frag in fragments:
		var enum_value = frag.color_name
		var color_name = enum_to_string.get(enum_value, null)

		if color_name == null:
			continue

		if not color_counts.has(color_name):
			color_counts[color_name] = 0

		color_counts[color_name] += 1
		total_mass += frag.fragment_mass

	for color_name in color_counts.keys():
		scores[color_name] += color_counts[color_name]

	apply_modifiers(fragments, color_counts, total_mass)
	update_ui()

	for frag in fragments:
		frag.queue_free()

func apply_modifiers(fragments: Array, color_counts: Dictionary, total_mass: float) -> void:
	var fragment_count := fragments.size()

	if color_counts.size() == 1:
		var bonus := fragment_count * 2
		var only_color = color_counts.keys()[0]
		scores[only_color] += bonus

	if color_counts.size() == fragment_count:
		var bonus := fragment_count
		for color_name in scores.keys():
			scores[color_name] += bonus

	var mass_bonus := int(total_mass / 10)
	if mass_bonus > 0:
		for color_name in scores.keys():
			scores[color_name] += mass_bonus

func update_ui():
	for color_name in entries.keys():
		_refresh_entry(color_name)

class CircleDrawer:
	extends Node2D

	var radius: float = 14.0
	var color: Color = Color.WHITE

	func _draw() -> void:
		draw_circle(Vector2(radius, radius), radius, color)

	func _ready() -> void:
		queue_redraw()
