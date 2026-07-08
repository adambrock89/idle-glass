extends CanvasLayer

signal shop_toggled

const SCORE_BALANCE_DIVISOR: float = 95.0
const MASS_VALUE_EXPONENT: float = 2.6
const METAL_ID_TO_NAME: Dictionary = {
	0: "copper",
	1: "silver",
	2: "gold",
	3: "crystal"
}

var color_profile: ColorProfile = ColorProfile.new()

var scoreboard_colors: Dictionary = {
	"red": ColorProfile.ColorName.RED,
	"orange": ColorProfile.ColorName.ORANGE,
	"yellow": ColorProfile.ColorName.YELLOW,
	"green": ColorProfile.ColorName.GREEN,
	"blue": ColorProfile.ColorName.BLUE,
	"purple": ColorProfile.ColorName.PURPLE
}

var scores: Dictionary = {
	"red": 0.0,
	"orange": 0.0,
	"yellow": 0.0,
	"green": 0.0,
	"blue": 0.0,
	"purple": 0.0
}

var value_multiplier: Dictionary = {
	"red": 1.0,
	"orange": 1.0,
	"yellow": 1.0,
	"green": 1.0,
	"blue": 1.0,
	"purple": 1.0
}

var metal_value_multiplier: Dictionary = {
	"copper": 1.0,
	"silver": 10.0,
	"gold": 100.0,
	"crystal": 1000.0
}

var modifier_lots_shapes_per_shape: float = 0.0
var modifier_all_same_color_mult: float = 1.0
var modifier_rainbow_mult: float = 1.0

var entries: Dictionary = {}
var enum_to_string: Dictionary = {}

func _ready():
	for color_name in scoreboard_colors.keys():
		var enum_value: int = int(scoreboard_colors[color_name])
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
		var entry: Control = build_color_entry(color_name)
		root.add_child(entry)
		entries[color_name] = entry

	# Allow clicking the scoreboard to toggle the shop UI
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	root.connect("gui_input", Callable(self, "_on_root_gui_input"))

func _on_root_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("shop_toggled")

func has_cost(costs: Dictionary) -> bool:
	for color_name in costs.keys():
		if not scores.has(color_name):
			return false
		if float(scores[color_name]) < float(costs[color_name]):
			return false
	return true

func spend_cost(costs: Dictionary) -> bool:
	if not has_cost(costs):
		return false
	for color_name in costs.keys():
		scores[color_name] = float(scores[color_name]) - float(costs[color_name])
		_refresh_entry(String(color_name))
	return true

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
	label.text = str(int(round(float(scores[color_name]))))
	label.add_theme_font_size_override("font_size", 22)
	label.modulate = circle.color
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	entry.add_child(label)

	return entry

func update_scores(new_scores: Dictionary) -> void:
	for key in new_scores.keys():
		if scores.has(key):
			scores[key] = float(new_scores[key])
			_refresh_entry(String(key))

func _refresh_entry(color_name: String) -> void:
	var entry: HBoxContainer = entries[color_name] as HBoxContainer
	var label: Label = entry.get_node("Label") as Label
	label.text = str(int(round(float(scores[color_name]))))

func _get_fragment_color_name(fragment: Fragment) -> String:
	if fragment == null:
		return ""
	var enum_value: int = int(fragment.color_name)
	return String(enum_to_string.get(enum_value, ""))

func _get_fragment_metal_name(fragment: Fragment) -> String:
	if fragment == null:
		return "copper"

	var border_mesh: MeshInstance2D = fragment.get_meta("border_mesh", null) as MeshInstance2D
	if border_mesh == null or border_mesh.material == null:
		return "copper"

	var mat: ShaderMaterial = border_mesh.material as ShaderMaterial
	if mat == null:
		return "copper"

	var metal_type: int = int(mat.get_shader_parameter("metal_type"))
	return String(METAL_ID_TO_NAME.get(metal_type, "copper"))

func _compute_fragment_score(fragment: Fragment, batch_multiplier: float) -> float:
	if fragment == null:
		return 0.0

	var color_name: String = _get_fragment_color_name(fragment)
	if color_name == "":
		return 0.0

	var normalized_mass: float = max(float(fragment.fragment_mass) / SCORE_BALANCE_DIVISOR, 0.001)
	var base_value: float = pow(normalized_mass, MASS_VALUE_EXPONENT)
	var color_mult: float = float(value_multiplier.get(color_name, 1.0))
	var metal_name: String = _get_fragment_metal_name(fragment)
	var metal_mult: float = float(metal_value_multiplier.get(metal_name, 1.0))

	return base_value * color_mult * metal_mult * batch_multiplier

func score_shape(fragment: Fragment) -> void:
	if fragment == null:
		return

	var color_name: String = _get_fragment_color_name(fragment)
	if color_name == "":
		return

	var add: float = _compute_fragment_score(fragment, 1.0)
	scores[color_name] = float(scores[color_name]) + add
	_refresh_entry(color_name)
	fragment.queue_free()

func process_batch(fragments: Array) -> void:
	if fragments.is_empty():
		return

	var valid_fragments: Array = []
	var unique_colors: Dictionary = {}

	for frag in fragments:
		if frag is Fragment:
			var color_name: String = _get_fragment_color_name(frag)
			if color_name != "":
				valid_fragments.append(frag)
				unique_colors[color_name] = true

	if valid_fragments.is_empty():
		return

	var count: int = valid_fragments.size()
	var batch_mult: float = 1.0 + max(0, count - 1) * modifier_lots_shapes_per_shape

	if unique_colors.size() == 1:
		batch_mult *= modifier_all_same_color_mult

	if unique_colors.has("red") and unique_colors.has("orange") and unique_colors.has("yellow") and unique_colors.has("green") and unique_colors.has("blue") and unique_colors.has("purple"):
		batch_mult *= modifier_rainbow_mult

	for frag in valid_fragments:
		var fragment: Fragment = frag as Fragment
		var color_name: String = _get_fragment_color_name(fragment)
		var add: float = _compute_fragment_score(fragment, batch_mult)
		scores[color_name] = float(scores[color_name]) + add

	update_ui()

	for frag in valid_fragments:
		var fragment: Fragment = frag as Fragment
		if fragment != null:
			fragment.queue_free()

func apply_modifiers(_fragments: Array, _color_counts: Dictionary, _total_mass: float) -> void:
	return

func _find_game_node(name: String) -> Node:
	var scene := get_tree().get_current_scene()
	if scene != null:
		if scene.name == name:
			return scene
		var node := scene.find_child(name, true, false)
		if node != null:
			return node
	return null

func _apply_set_effect(target: String, value: Variant) -> void:
	var fragment_manager := _find_game_node("Node2D")
	var platform := _find_game_node("Platform")

	match target:
		"spawn_speed":
			if fragment_manager != null and fragment_manager.has_method("set_spawn_speed_multiplier"):
				fragment_manager.call("set_spawn_speed_multiplier", float(value))
		"hatch_speed":
			if platform != null and platform.has_method("set_hatch_speed_multiplier"):
				platform.call("set_hatch_speed_multiplier", float(value))
		"platform_length":
			if platform != null and platform.has_method("set_platform_length"):
				platform.call("set_platform_length", float(value))
		"max_tier":
			if fragment_manager != null and fragment_manager.has_method("set_max_tier"):
				fragment_manager.call("set_max_tier", int(value))
		"tier_random_enabled":
			if fragment_manager != null and fragment_manager.has_method("set_tier_randomization"):
				fragment_manager.call("set_tier_randomization", bool(value))
		"pull_strength_multiplier":
			if fragment_manager != null and fragment_manager.has_method("set_pull_strength_multiplier"):
				fragment_manager.call("set_pull_strength_multiplier", float(value))
		"grab_radius":
			if fragment_manager != null and fragment_manager.has_method("set_grab_radius"):
				fragment_manager.call("set_grab_radius", float(value))
		"modifier_lots_shapes_per_shape":
			modifier_lots_shapes_per_shape = float(value)
		"modifier_all_same_color_mult":
			modifier_all_same_color_mult = float(value)
		"modifier_rainbow_mult":
			modifier_rainbow_mult = float(value)
		_:
			if target.begins_with("strength_") and fragment_manager != null and fragment_manager.has_method("set_color_strength"):
				var color_name: String = target.replace("strength_", "")
				fragment_manager.call("set_color_strength", color_name, float(value))

func apply_effect(effect: Dictionary) -> void:
	if effect == null:
		return

	var t: String = String(effect.get("type", ""))
	var target: String = String(effect.get("target", ""))

	if t == "mult":
		if target.ends_with("_value"):
			var color: String = target.replace("_value", "")
			var mult: float = float(effect.get("multiplier", 1.0))
			if value_multiplier.has(color):
				value_multiplier[color] = mult
		elif target.begins_with("metal_") and target.ends_with("_value"):
			var metal_name: String = target.replace("metal_", "").replace("_value", "")
			var metal_mult: float = float(effect.get("multiplier", 1.0))
			if metal_value_multiplier.has(metal_name):
				metal_value_multiplier[metal_name] = metal_mult
	elif t == "set":
		_apply_set_effect(target, effect.get("value", null))
	elif t == "set_weights":
		var fragment_manager := _find_game_node("Node2D")
		if fragment_manager != null and fragment_manager.has_method("set_metal_weights"):
			fragment_manager.call("set_metal_weights", effect.get("weights", {}) as Dictionary)
	elif t == "multi":
		var effects: Array = effect.get("effects", []) as Array
		for raw_effect in effects:
			if raw_effect is Dictionary:
				apply_effect(raw_effect as Dictionary)
	elif t == "add_percent":
		if target == "modifier_lots_shapes_per_shape":
			modifier_lots_shapes_per_shape += float(effect.get("amount", 0.0))
		elif target == "modifier_all_same_color_mult":
			modifier_all_same_color_mult += float(effect.get("amount", 0.0))
		elif target == "modifier_rainbow_mult":
			modifier_rainbow_mult += float(effect.get("amount", 0.0))

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
