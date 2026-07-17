extends CanvasLayer

signal shop_toggled
signal scores_changed

const AREA_SCORE_REFERENCE_MASS: float = 72.0
const AREA_SCORE_REFERENCE_VALUE: float = 1.0
const AREA_SCORE_TARGET_MASS: float = 181.0
const AREA_SCORE_TARGET_VALUE: float = 3.0
const AREA_SCORE_EXPONENT: float = 1.5
const PANEL_WIDTH: float = 484.0
const PANEL_SIDE_MARGIN: float = 12.0
const PANEL_TOP_MARGIN: float = 12.0
const METAL_ID_TO_NAME: Dictionary = {
	0: "copper",
	1: "silver",
	2: "gold",
	3: "crystal"
}
const SCORE_COLOR_ORDER: Array[String] = ["red", "yellow", "blue", "orange", "green", "purple"]
const TIER_TWO_COLORS: Array[String] = ["orange", "green", "purple"]

var global_functions: GlobalFunctions = GlobalFunctions.new()
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
	"red": 1000000.0,
	"orange": 200.0,
	"yellow": 200000.0,
	"green": 200.0,
	"blue": 200.0,
	"purple": 200000.0
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
var modifier_all_same_color_mult: float = 0.0
var modifier_rainbow_mult: float = 1.0

var entries: Dictionary = {}
var enum_to_string: Dictionary = {}
var panel_root: PanelContainer = null
var shop_host: VBoxContainer = null
var arrow_hint_label: Label = null
var shop_separation: Control = null
var tier_two_unlocked: bool = false

func _ready():
	for color_name in scoreboard_colors.keys():
		var enum_value: int = int(scoreboard_colors[color_name])
		enum_to_string[enum_value] = color_name

	panel_root = PanelContainer.new()
	panel_root.name = "ScoreboardRoot"
	panel_root.anchor_left = 1.0
	panel_root.anchor_top = 0.0
	panel_root.anchor_right = 1.0
	panel_root.anchor_bottom = 0.0
	panel_root.offset_left = -(PANEL_WIDTH + PANEL_SIDE_MARGIN)
	panel_root.offset_top = PANEL_TOP_MARGIN
	panel_root.offset_right = -PANEL_SIDE_MARGIN
	panel_root.offset_bottom = PANEL_TOP_MARGIN
	panel_root.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	panel_root.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_root.add_theme_stylebox_override("panel", _build_panel_style())
	add_child(panel_root)

	var margin := MarginContainer.new()
	margin.anchor_left = 0.0
	margin.anchor_top = 0.0
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel_root.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(stack)

	var grid_center := CenterContainer.new()
	grid_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(grid_center)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid_center.add_child(grid)

	for color_name in SCORE_COLOR_ORDER:
		var entry: Control = build_color_entry(color_name)
		grid.add_child(entry)
		entries[color_name] = entry
		_refresh_entry(color_name)

	_update_tier_two_entry_visibility()

	arrow_hint_label = Label.new()
	arrow_hint_label.text = "▼"
	arrow_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	arrow_hint_label.modulate = Color(0.78, 0.84, 0.9, 0.9)
	arrow_hint_label.add_theme_font_size_override("font_size", 20)
	arrow_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(arrow_hint_label)

	shop_separation = Control.new()
	shop_separation.custom_minimum_size = Vector2(0, 4)
	shop_separation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(shop_separation)

	shop_host = VBoxContainer.new()
	shop_host.visible = false
	shop_host.add_theme_constant_override("separation", 0)
	shop_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(shop_host)

	panel_root.connect("gui_input", Callable(self, "_on_root_gui_input"))

func _on_root_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("shop_toggled")

func set_shop_open(is_open: bool) -> void:
	if panel_root != null:
		if is_open:
			panel_root.anchor_bottom = 1.0
			panel_root.offset_bottom = -PANEL_SIDE_MARGIN
		else:
			panel_root.anchor_bottom = 0.0
			panel_root.offset_bottom = PANEL_TOP_MARGIN

	if arrow_hint_label != null:
		if(is_open):
			arrow_hint_label.text = "▲"
		else:
			arrow_hint_label.text = "▼"
		
	if shop_separation != null:
		shop_separation.visible = is_open
	if shop_host != null:
		shop_host.visible = is_open

func attach_shop_panel(panel: Control) -> void:
	if panel == null or shop_host == null:
		return
	if panel.get_parent() != null:
		panel.get_parent().remove_child(panel)
	shop_host.add_child(panel)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 380)
	panel.visible = shop_host.visible

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
	emit_signal("scores_changed")
	return true

func build_color_entry(color_name: String) -> Control:
	var entry := HBoxContainer.new()
	entry.name = "ColorEntry_%s" % color_name.capitalize()
	entry.custom_minimum_size = Vector2(102, 34)
	entry.alignment = BoxContainer.ALIGNMENT_BEGIN
	entry.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_theme_constant_override("separation", 8)

	var circle := Panel.new()
	circle.name = "Circle"
	circle.custom_minimum_size = Vector2(16, 16)
	circle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	circle.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var circle_style := StyleBoxFlat.new()
	circle_style.bg_color = color_profile.rgb_values[scoreboard_colors[color_name]]
	circle_style.corner_radius_top_left = 8
	circle_style.corner_radius_top_right = 8
	circle_style.corner_radius_bottom_right = 8
	circle_style.corner_radius_bottom_left = 8
	circle.add_theme_stylebox_override("panel", circle_style)
	entry.add_child(circle)

	var label := Label.new()
	label.name = "Label"
	label.text = "" #Defined on update
	label.add_theme_font_size_override("font_size", 19)
	label.modulate = color_profile.rgb_values[scoreboard_colors[color_name]]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_child(label)

	return entry

func _build_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.12, 0.72)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.26, 0.28, 0.32, 0.92)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	return style

func update_scores(new_scores: Dictionary) -> void:
	for key in new_scores.keys():
		if scores.has(key):
			scores[key] = float(new_scores[key])
			_refresh_entry(String(key))
	emit_signal("scores_changed")

func _refresh_entry(color_name: String) -> void:
	var entry: HBoxContainer = entries[color_name] as HBoxContainer
	var label: Label = entry.get_node("Label") as Label
	label.text = global_functions.format_float_for_notation(scores[color_name])

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

	var mass_value: float = max(float(fragment.fragment_mass), 0.001)
	var base_value: float = AREA_SCORE_REFERENCE_VALUE * pow(mass_value / AREA_SCORE_REFERENCE_MASS, AREA_SCORE_EXPONENT)
	var color_mult: float = float(value_multiplier.get(color_name, 1.0))
	var metal_name: String = _get_fragment_metal_name(fragment)
	var metal_mult: float = float(metal_value_multiplier.get(metal_name, 1.0))

	return base_value * color_mult * metal_mult * batch_multiplier

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
	if unique_colors.size() == 1 and count > 1:
		var same_color_batch_bonus: float = 1.0 + float(count - 1) * modifier_all_same_color_mult
		batch_mult += same_color_batch_bonus
	if unique_colors.has("red") and unique_colors.has("orange") and unique_colors.has("yellow") and unique_colors.has("green") and unique_colors.has("blue") and unique_colors.has("purple"):
		batch_mult *= modifier_rainbow_mult
	for frag in valid_fragments:
		var fragment: Fragment = frag as Fragment
		var color_name: String = _get_fragment_color_name(fragment)
		var add: float = _compute_fragment_score(fragment, batch_mult)

		scores[color_name] = float(scores[color_name]) + add

	update_ui()
	emit_signal("scores_changed")

	for frag in valid_fragments:
		var fragment: Fragment = frag as Fragment
		if fragment != null:
			fragment.queue_free()

func apply_modifiers(_fragments: Array, _color_counts: Dictionary, _total_mass: float) -> void:
	return

func _find_game_node(node_name: String) -> Node:
	var scene := get_tree().get_current_scene()
	if scene != null:
		if scene.name == node_name:
			return scene
		var node := scene.find_child(node_name, true, false)
		if node != null:
			return node
	return null

func _apply_set_effect(target: String, value: Variant) -> void:
	var fragment_manager := %FragmentCollection
	var platform := %Platform

	match target:
		"spawn_speed":
			if fragment_manager != null and fragment_manager.has_method("set_spawn_speed_multiplier"):	
				fragment_manager.call("set_spawn_speed_multiplier", float(value))
		"hatch_speed":
			if platform != null and platform.has_method("set_hatch_speed_multiplier"):	
				platform.call("set_hatch_speed_multiplier", float(value))
		"hatch_height_delta":
			if platform != null and platform.has_method("set_hatch_height_delta"):	
				platform.call("set_hatch_height_delta", float(value))
		"platform_length":
			if platform != null and platform.has_method("set_platform_length"):	
				platform.call("set_platform_length", float(value))
		"max_tier":
			if fragment_manager != null and fragment_manager.has_method("set_max_tier"):	
				fragment_manager.call("set_max_tier", int(value))
			tier_two_unlocked = tier_two_unlocked or int(value) >= 2
			_update_tier_two_entry_visibility()
		"tier_random_enabled":
			if fragment_manager != null and fragment_manager.has_method("set_tier_randomization"):	
				fragment_manager.call("set_tier_randomization", bool(value))
		"pull_strength_multiplier":
			if fragment_manager != null and fragment_manager.has_method("set_pull_strength_multiplier"):	
				fragment_manager.call("set_pull_strength_multiplier", float(value))
		"grab_radius":
			if fragment_manager != null and fragment_manager.has_method("set_grab_radius"):	
				fragment_manager.call("set_grab_radius", float(value))
		"tier_two_probability":
			if fragment_manager != null and fragment_manager.has_method("set_tier_two_probability"):	
				fragment_manager.call("set_tier_two_probability", float(value))
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
	if t == "mult": #WORKING HERE
		var base_mult: float = float(effect.get("multiplier", 1.0))
		var level: int = int(effect.get("level",0.0))
		var mult = pow(base_mult, level)
		if target.ends_with("_value"):
			var color: String = target.replace("_value", "")
			if value_multiplier.has(color):
				value_multiplier[color] = mult

		elif target.ends_with("_size"):
			var size_multiplier = %FragmentCollection.get("size_multiplier")
			var color: String = target.replace("_size", "")
			
			if size_multiplier.has(color):
				size_multiplier[color] = mult 
				#Tell fragment_manager
		
		elif target == "spawn_speed":
			%FragmentCollection.set_spawn_speed_multiplier(mult)
		elif target == "hatch_speed":
			%Platform.hatch_speed_multiplier = mult
		elif target == "hatch_width":
			%Platform.set_hatch_width_multiplier(mult)
			
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

func _update_tier_two_entry_visibility() -> void:
	for color_name in TIER_TWO_COLORS:
		if entries.has(color_name):
			var entry: Control = entries[color_name] as Control
			if entry != null:
				entry.visible = tier_two_unlocked

class CircleDrawer:
	extends Node2D

	var radius: float = 14.0
	var color: Color = Color.WHITE

	func _draw() -> void:
		draw_circle(Vector2(radius, radius), radius, color)

	func _ready() -> void:
		queue_redraw()
