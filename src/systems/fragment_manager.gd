extends Node2D

@export var Red: ColorProfile
@export var Orange: ColorProfile
@export var Yellow: ColorProfile
@export var Green: ColorProfile
@export var Blue: ColorProfile
@export var Purple: ColorProfile

var base_wait_time: float = 5.0
var spawn_speed_multiplier: float = 1.0
var spawn_timer: Timer
var generation_enabled: bool = true
var max_tier: int = 1
var randomize_tier: bool = false
var tier_two_probability: float = 0.2

var base_pull_strength: float = 5.0
var pull_strength_multiplier: float = 1.0
var grab_radius: float = 0.0
var unlocked_grab_radii: Array[float] = [0.0]
var active_grab_radius_index: int = 0

var METAL_TYPES := {
	"copper": 0,
	"silver": 1,
	"gold": 2,
	"crystal": 3
}

var METAL_WEIGHTS := {
	"copper": 1.0,
	"silver": 0.0,
	"gold": 0.0,
	"crystal": 0.0
}

var color_list := ColorProfile.ColorName.values()
var primary_colors: Array[ColorProfile.ColorName] = [
	ColorProfile.ColorName.RED,
	ColorProfile.ColorName.YELLOW,
	ColorProfile.ColorName.BLUE
]
var secondary_colors: Array[ColorProfile.ColorName] = [
	ColorProfile.ColorName.ORANGE,
	ColorProfile.ColorName.GREEN,
	ColorProfile.ColorName.PURPLE
]
var tertiary_colors: Array[ColorProfile.ColorName] = [
	ColorProfile.ColorName.RED_ORANGE,
	ColorProfile.ColorName.ORANGE_YELLOW,
	ColorProfile.ColorName.YELLOW_GREEN,
	ColorProfile.ColorName.GREEN_BLUE,
	ColorProfile.ColorName.BLUE_PURPLE,
	ColorProfile.ColorName.PURPLE_RED
]

const BASE_COLOR_STRENGTH: float = 6.5
const STRENGTH_VISIBILITY_MULTIPLIER: float = 0.75

var color_strength: Dictionary = {
	"red": BASE_COLOR_STRENGTH,
	"orange": BASE_COLOR_STRENGTH,
	"yellow": BASE_COLOR_STRENGTH,
	"green": BASE_COLOR_STRENGTH,
	"blue": BASE_COLOR_STRENGTH,
	"purple": BASE_COLOR_STRENGTH
}

var held_object: Fragment = null
var held_fragments: Array[Fragment] = []
var grab_indicator: GrabRadiusIndicator = null

func _ready():
	ProceduralSfx.prime_cache(ColorProfile.ColorName.size())

	Red = ColorProfile.new()
	Red.color_name = ColorProfile.ColorName.RED

	Orange = ColorProfile.new()
	Orange.color_name = ColorProfile.ColorName.ORANGE

	Yellow = ColorProfile.new()
	Yellow.color_name = ColorProfile.ColorName.YELLOW

	Green = ColorProfile.new()
	Green.color_name = ColorProfile.ColorName.GREEN

	Blue = ColorProfile.new()
	Blue.color_name = ColorProfile.ColorName.BLUE

	Purple = ColorProfile.new()
	Purple.color_name = ColorProfile.ColorName.PURPLE

	_sync_color_profile_strengths()

	spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(func(): build_clusters())
	_update_spawn_timer_wait_time()

	grab_indicator = GrabRadiusIndicator.new()
	grab_indicator.visible = false
	add_child(grab_indicator)

	build_clusters()
	spawn_timer.start()

func _process(_delta: float) -> void:
	if grab_indicator != null:
		grab_indicator.global_position = get_global_mouse_position()
		grab_indicator.visible = grab_radius > 0.0

func _sync_color_profile_strengths() -> void:
	Red.min_strength = float(color_strength["red"])
	Red.max_strength = float(color_strength["red"])

	Orange.min_strength = float(color_strength["orange"])
	Orange.max_strength = float(color_strength["orange"])

	Yellow.min_strength = float(color_strength["yellow"])
	Yellow.max_strength = float(color_strength["yellow"])

	Green.min_strength = float(color_strength["green"])
	Green.max_strength = float(color_strength["green"])

	Blue.min_strength = float(color_strength["blue"])
	Blue.max_strength = float(color_strength["blue"])

	Purple.min_strength = float(color_strength["purple"])
	Purple.max_strength = float(color_strength["purple"])

func _update_spawn_timer_wait_time() -> void:
	var effective: float = base_wait_time / max(spawn_speed_multiplier, 0.1)
	if spawn_timer != null:
		spawn_timer.wait_time = max(0.1, effective)

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_adjust_grab_radius_selection(1)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_adjust_grab_radius_selection(-1)
			return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_begin_grab(get_global_mouse_position())

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_end_grab()

	if Input.is_action_just_pressed("toggle_generation"):
		_on_toggle_generation_pressed()

func _begin_grab(mouse_pos: Vector2) -> void:
	_end_grab()

	if grab_radius > 0.0:
		var fragment_collection := get_tree().current_scene.find_child("FragmentCollection", true, false)
		if fragment_collection != null:
			for child in fragment_collection.get_children():
				if child is Fragment:
					var frag: Fragment = child as Fragment
					if frag.global_position.distance_to(mouse_pos) <= grab_radius:
						frag.is_being_held = true
						frag.pull_strength = base_pull_strength * pull_strength_multiplier
						held_fragments.append(frag)
		return

	var space_state = get_world_2d().direct_space_state

	var query := PhysicsPointQueryParameters2D.new()
	query.position = mouse_pos
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.collision_mask = 0xFFFFFFFF

	var results = space_state.intersect_point(query)

	for result in results:
		if result.collider is Fragment:
			held_object = result.collider
			held_object.is_being_held = true
			held_object.pull_strength = base_pull_strength * pull_strength_multiplier
			return

func _end_grab() -> void:
	if held_object != null:
		held_object.is_being_held = false
		held_object = null

	for frag in held_fragments:
		if frag != null:
			frag.is_being_held = false
	held_fragments.clear()

func build_clusters() -> void:
	var red_strength: float = _scaled_color_strength(float(color_strength["red"]))
	var orange_strength: float = _scaled_color_strength(float(color_strength["orange"]))
	var yellow_strength: float = _scaled_color_strength(float(color_strength["yellow"]))
	var green_strength: float = _scaled_color_strength(float(color_strength["green"]))
	var blue_strength: float = _scaled_color_strength(float(color_strength["blue"]))
	var purple_strength: float = _scaled_color_strength(float(color_strength["purple"]))

	var strengths: Array[float] = [
		red_strength,
		orange_strength,
		yellow_strength,
		green_strength,
		blue_strength,
		purple_strength
	]

	var primary_index := 0
	var tertiary_index := 0
	var polygon_points: PackedVector2Array

	var fragment_container := FragmentContainer.new()
	$FragmentCollection.add_child(fragment_container)
	fragment_container.global_position = %SpawnPoint.global_position

	var angle_offset := 0
	var tier: int = max_tier
	if randomize_tier and max_tier > 1:
		tier = _roll_random_tier()

	for color in color_list:
		if color in primary_colors:
			polygon_points = get_poly_points(color, tier, strengths[primary_index], null, null, angle_offset)
			build_nodes(fragment_container, polygon_points, color)
			primary_index += 1
		elif color in secondary_colors:
			polygon_points = get_poly_points(
				color,
				tier,
				strengths[(primary_index - 1) % strengths.size()],
				strengths[primary_index],
				strengths[(primary_index + 1) % strengths.size()],
				angle_offset
			)
			build_nodes(fragment_container, polygon_points, color)
			primary_index += 1
		else:
			polygon_points = get_poly_points(
				color,
				tier,
				strengths[tertiary_index],
				strengths[(tertiary_index + 1) % strengths.size()],
				null,
				angle_offset
			)
			build_nodes(fragment_container, polygon_points, color)
			tertiary_index += 1

		angle_offset += 30
	fragment_container.finalize_container()

func _scaled_color_strength(value: float) -> float:
	var clamped_value: float = max(0.1, value)
	if clamped_value <= BASE_COLOR_STRENGTH:
		return clamped_value
	return BASE_COLOR_STRENGTH + (clamped_value - BASE_COLOR_STRENGTH) * STRENGTH_VISIBILITY_MULTIPLIER

func _coerce_strength(value: Variant, default: float = 0.0) -> float:
	if value == null:
		return default
	if value is int:
		return float(value)
	if value is float:
		return value
	return float(value)

func get_poly_points(color: ColorProfile.ColorName, tier: int, first_strength: Variant, second_strength: Variant, third_strength: Variant, starting_angle: float) -> PackedVector2Array:
	var poly_points: PackedVector2Array = []
	var zero_strength := 3.0
	var first_strength_value := _coerce_strength(first_strength)
	var second_strength_value := _coerce_strength(second_strength)
	var third_strength_value := _coerce_strength(third_strength)

	match tier:
		1:
			if color in primary_colors:
				poly_points = [
					Vector2.ZERO,
					Vector2.UP.rotated(deg_to_rad(starting_angle + 60)) * zero_strength,
					Vector2.UP.rotated(deg_to_rad(starting_angle)) * first_strength_value,
					Vector2.UP.rotated(deg_to_rad(starting_angle - 60)) * zero_strength
				]
		2:
			if color in primary_colors:
				poly_points = [
					Vector2.ZERO,
					Vector2.UP.rotated(deg_to_rad(starting_angle + 60)) * zero_strength,
					Vector2.UP.rotated(deg_to_rad(starting_angle)) * first_strength_value,
					Vector2.UP.rotated(deg_to_rad(starting_angle - 60)) * zero_strength
				]
			elif color in secondary_colors:
				var point_a := Vector2.UP.rotated(deg_to_rad(starting_angle - 60)) * first_strength_value
				var point_b := Vector2.UP.rotated(deg_to_rad(starting_angle)) * zero_strength
				var intersection_ccw := point_a.lerp(point_b, 3.5 / 5.0)

				var point_c := Vector2.UP.rotated(deg_to_rad(starting_angle + 60)) * third_strength_value
				var point_d := Vector2.UP.rotated(deg_to_rad(starting_angle)) * zero_strength
				var intersection_cw := point_c.lerp(point_d, 3.5 / 5.0)

				poly_points = [
					Vector2.UP.rotated(deg_to_rad(starting_angle)) * zero_strength,
					intersection_cw,
					Vector2.UP.rotated(deg_to_rad(starting_angle)) * second_strength_value,
					intersection_ccw
				]
		3:
			zero_strength = 6.5
			if color in primary_colors:
				poly_points = [
					Vector2.UP.rotated(deg_to_rad(starting_angle + 30)) * zero_strength,
					Vector2.UP.rotated(deg_to_rad(starting_angle)) * first_strength_value,
					Vector2.UP.rotated(deg_to_rad(starting_angle - 30)) * zero_strength,
					Vector2.UP.rotated(deg_to_rad(starting_angle)) * first_strength_value / 3.0
				]
			elif color in secondary_colors:
				poly_points = [
					Vector2.UP.rotated(deg_to_rad(starting_angle + 30)) * zero_strength,
					Vector2.UP.rotated(deg_to_rad(starting_angle)) * second_strength_value,
					Vector2.UP.rotated(deg_to_rad(starting_angle - 30)) * zero_strength,
					Vector2.UP.rotated(deg_to_rad(starting_angle)) * second_strength_value / 3.0
				]
			else:
				poly_points = [
					Vector2.UP.rotated(deg_to_rad(starting_angle + 30)) * second_strength_value / 3.0,
					Vector2.UP.rotated(deg_to_rad(starting_angle)) * zero_strength,
					Vector2.UP.rotated(deg_to_rad(starting_angle - 30)) * first_strength_value / 3.0,
					Vector2.ZERO
				]

	var scaled_points := PackedVector2Array()
	for point in poly_points:
		scaled_points.append(point * 10.0)

	return scaled_points

func build_nodes(parent_container: FragmentContainer, points: PackedVector2Array, color_name):
	if points.size() < 3:
		return

	var centroid := Vector2.ZERO
	for point in points:
		centroid += point
	centroid /= points.size()

	var centered_points := PackedVector2Array()
	for point in points:
		centered_points.append(point - centroid)

	var container_center := parent_container.global_position
	var border_scale := 1.15
	var push_offset := compute_push_out_offset(centroid, container_center, border_scale)
	centroid += push_offset

	var inner := Polygon2D.new()
	inner.name = "InnerPolygon_%s" % str(color_name)
	inner.polygon = centered_points
	inner.position = centroid
	inner.z_index = 1
	parent_container.add_child(inner)

	var cp := ColorProfile.new()
	cp.color_name = color_name

	inner.set_meta("color_profile", cp)
	inner.set_meta("color_name", color_name)
	inner.set_meta("base_color", cp.get_color_code())

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/glass_fragment.gdshader")
	mat.set_shader_parameter("tint_color", cp.get_color_code())
	mat.set_shader_parameter("object_rotation", inner.rotation)

	inner.material = mat


	var collision := CollisionPolygon2D.new()
	collision.name = "CollisionPolygon2D_%s" % str(color_name)

	var outer_points := PackedVector2Array()
	for point in centered_points:
		outer_points.append(point * 1.15)

	collision.polygon = outer_points
	collision.position = centroid
	parent_container.add_child(collision)

	create_border(centered_points, inner)

func compute_push_out_offset(fragment_centroid: Vector2, container_center: Vector2, border_scale: float) -> Vector2:
	var outward_dir := (fragment_centroid - container_center).normalized()
	var dist := (fragment_centroid - container_center).length()
	var border_growth := border_scale - 1.0
	var push_distance := dist * border_growth
	return outward_dir * push_distance

func set_generation_enabled(enabled: bool) -> void:
	if spawn_timer == null:
		return

	if enabled:
		spawn_timer.start()
	else:
		spawn_timer.stop()

func _on_toggle_generation_pressed():
	var enabled := !generation_enabled
	generation_enabled = enabled
	set_generation_enabled(enabled)

func create_border(centered_points: PackedVector2Array, inner: Node2D) -> MeshInstance2D:
	var thickness := 8.0

	var global_pts := PackedVector2Array()
	for point in centered_points:
		global_pts.append(inner.to_global(point))

	var frag := inner.get_parent()
	var local_pts := PackedVector2Array()
	for point in global_pts:
		local_pts.append(frag.to_local(point))

	var border_mesh := create_border_mesh_from_polygon(local_pts, thickness)
	if border_mesh == null:
		push_warning("Border mesh generation failed.")
		return null

	border_mesh.position = Vector2.ZERO
	border_mesh.rotation = 0.0
	border_mesh.scale = Vector2.ONE

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/solder.gdshader")
	mat.set("shader_parameter/metal_type", get_random_metal_type())
	mat.set("shader_parameter/bevel_mode", 0)
	mat.set("shader_parameter/motion_factor", 0.0)
	mat.set("shader_parameter/global_rotation", global_transform.get_rotation())
	
	var angle_offset = get_angle_offset_by_color(inner.get_meta("color_name"))
	mat.set("shader_parameter/uv_angle_offset", angle_offset)
	

	border_mesh.material = mat
	border_mesh.z_index = 10

	var color_name = inner.get_meta("color_name")
	border_mesh.name = "BorderMeshInstance_%s" % str(color_name)
	frag.add_child(border_mesh)
	return border_mesh
	
func get_angle_offset_by_color(color_name) -> float:
	if color_name == ColorProfile.ColorName.RED:
		return PI
	elif color_name == ColorProfile.ColorName.YELLOW:
		return PI/3
	elif color_name == ColorProfile.ColorName.BLUE:
		return PI * 5/3
		
	return 0

func create_border_mesh_from_polygon(points: PackedVector2Array, thickness: float) -> MeshInstance2D:
	var mesh := ArrayMesh.new()

	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var count := points.size()
	if count < 3:
		return null

	var inner := PackedVector2Array()
	var outer := PackedVector2Array()
	var max_bevel := thickness * 1.2

	for i in range(count):
		var p_prev := points[(i - 1 + count) % count]
		var p := points[i]
		var p_next := points[(i + 1) % count]

		var v1 := (p - p_prev).normalized()
		var v2 := (p_next - p).normalized()
		var bisector := (v1 + v2).normalized()
		var angle := acos(clamp(v1.dot(v2), -1.0, 1.0))
		var half_angle := angle * 0.5
		var raw_scale = thickness / max(sin(half_angle), 0.001)
		var final_scale = min(raw_scale, max_bevel)
		var outward := Vector2(-bisector.y, bisector.x)

		inner.append(p - outward * final_scale * 0.5)
		outer.append(p + outward * final_scale * 0.5)

	for i in range(count):
		var i0 := i
		var i1 := (i + 1) % count

		var inner0 := inner[i0]
		var inner1 := inner[i1]
		var outer0 := outer[i0]
		var outer1 := outer[i1]

		var base := vertices.size()

		vertices.append(inner0)
		vertices.append(outer0)
		vertices.append(inner1)
		vertices.append(outer1)

		var u0 := float(i) / float(count)
		var u1 := float(i + 1) / float(count)

		uvs.append(Vector2(u0, 0.0))
		uvs.append(Vector2(u0, 1.0))
		uvs.append(Vector2(u1, 0.0))
		uvs.append(Vector2(u1, 1.0))

		indices.append(base + 0)
		indices.append(base + 1)
		indices.append(base + 2)
		indices.append(base + 2)
		indices.append(base + 1)
		indices.append(base + 3)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mi := MeshInstance2D.new()
	mi.mesh = mesh
	return mi

func get_random_metal_type() -> int:
	var entries := []
	for metal in METAL_WEIGHTS.keys():
		if METAL_TYPES.has(metal):
			entries.append({
				"name": metal,
				"weight": max(0.0, float(METAL_WEIGHTS[metal])),
				"id": METAL_TYPES[metal]
			})

	var total := 0.0
	for entry in entries:
		total += entry.weight

	if total <= 0.0:
		return METAL_TYPES["copper"]

	var roll := randf() * total
	var cumulative := 0.0

	for entry in entries:
		cumulative += entry.weight
		if roll <= cumulative:
			return entry.id

	return METAL_TYPES["copper"]

func set_color_strength(color_name: String, value: float) -> void:
	if not color_strength.has(color_name):
		return
	color_strength[color_name] = max(0.1, value)
	_sync_color_profile_strengths()

func set_spawn_speed_multiplier(multiplier: float) -> void:
	spawn_speed_multiplier = max(0.1, multiplier)
	_update_spawn_timer_wait_time()

func set_max_tier(tier: int) -> void:
	max_tier = clamp(tier, 1, 3)

func set_tier_randomization(enabled: bool) -> void:
	randomize_tier = enabled

func set_pull_strength_multiplier(multiplier: float) -> void:
	pull_strength_multiplier = max(0.1, multiplier)

func set_grab_radius(radius: float) -> void:
	var clamped_radius: float = max(0.0, radius)
	var already_unlocked := false
	for unlocked in unlocked_grab_radii:
		if is_equal_approx(unlocked, clamped_radius):
			already_unlocked = true
			break
	if not already_unlocked:
		unlocked_grab_radii.append(clamped_radius)

	active_grab_radius_index = unlocked_grab_radii.size() - 1
	_apply_active_grab_radius()

func set_tier_two_probability(probability: float) -> void:
	tier_two_probability = clamp(probability, 0.0, 1.0)

func _roll_random_tier() -> int:
	if max_tier <= 1:
		return 1

	if randf() <= tier_two_probability:
		return 2

	if max_tier == 2:
		return 1

	var fallback_tiers: Array[int] = [1, 3]
	return fallback_tiers[randi() % fallback_tiers.size()]

func _adjust_grab_radius_selection(direction: int) -> void:
	if unlocked_grab_radii.size() <= 1:
		return

	active_grab_radius_index = clamp(active_grab_radius_index + direction, 0, unlocked_grab_radii.size() - 1)
	_apply_active_grab_radius()

func _apply_active_grab_radius() -> void:
	if unlocked_grab_radii.is_empty():
		unlocked_grab_radii = [0.0]
		active_grab_radius_index = 0

	grab_radius = max(0.0, unlocked_grab_radii[active_grab_radius_index])
	if grab_indicator != null:
		grab_indicator.radius = grab_radius
		grab_indicator.queue_redraw()

func set_metal_weights(weights: Dictionary) -> void:
	for key in weights.keys():
		var metal_name: String = String(key)
		if METAL_WEIGHTS.has(metal_name):
			METAL_WEIGHTS[metal_name] = max(0.0, float(weights[key]))

class GrabRadiusIndicator:
	extends Node2D

	var radius: float = 0.0

	func _draw() -> void:
		if radius <= 0.0:
			return
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.55, 0.12, 0.14))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, Color(1.0, 0.72, 0.2, 0.9), 2.0)
