
extends Node2D

@export var Red: ColorProfile
@export var Orange: ColorProfile
@export var Yellow: ColorProfile
@export var Green: ColorProfile
@export var Blue: ColorProfile
@export var Purple: ColorProfile

var wait_time := 1.5
var spawn_timer: Timer
var generation_enabled: bool = true

var METAL_TYPES := {
	"copper": 0,
	"silver": 1,
	"gold": 2,
	"crystal": 3
}

var METAL_WEIGHTS := {
	"copper": 0,
	"silver": 1,
	"gold": 0,
	"crystal": 1
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

var held_object: Fragment = null

func _ready():
	Red = ColorProfile.new()
	Red.color_name = ColorProfile.ColorName.RED
	Red.min_strength = 7
	Red.max_strength = 7

	Orange = ColorProfile.new()
	Orange.color_name = ColorProfile.ColorName.ORANGE
	Orange.min_strength = 7
	Orange.max_strength = 7

	Yellow = ColorProfile.new()
	Yellow.color_name = ColorProfile.ColorName.YELLOW
	Yellow.min_strength = 7
	Yellow.max_strength = 7

	Green = ColorProfile.new()
	Green.color_name = ColorProfile.ColorName.GREEN
	Green.min_strength = 7
	Green.max_strength = 7

	Blue = ColorProfile.new()
	Blue.color_name = ColorProfile.ColorName.BLUE
	Blue.min_strength = 7
	Blue.max_strength = 7

	Purple = ColorProfile.new()
	Purple.color_name = ColorProfile.ColorName.PURPLE
	Purple.min_strength = 7
	Purple.max_strength = 7

	spawn_timer = Timer.new()
	add_child(spawn_timer)
	spawn_timer.wait_time = wait_time
	spawn_timer.one_shot = false
	spawn_timer.timeout.connect(func(): build_clusters())

	build_clusters()
	spawn_timer.start()

func _unhandled_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos = get_global_mouse_position()
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
				return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if held_object != null:
			held_object.is_being_held = false
			held_object = null

	if Input.is_action_just_pressed("toggle_generation"):
		_on_toggle_generation_pressed()

func build_clusters() -> void:
	var red_strength = randf_range(Red.min_strength, Red.max_strength)
	var orange_strength = randf_range(Orange.min_strength, Orange.max_strength)
	var yellow_strength = randf_range(Yellow.min_strength, Yellow.max_strength)
	var green_strength = randf_range(Green.min_strength, Green.max_strength)
	var blue_strength = randf_range(Blue.min_strength, Blue.max_strength)
	var purple_strength = randf_range(Purple.min_strength, Purple.max_strength)

	var strengths: Array[float] = [
		red_strength,
		orange_strength,
		yellow_strength,
		green_strength,
		blue_strength,
		purple_strength
	]

	var primary_index = 0
	var tertiary_index = 0
	var polygon_points: PackedVector2Array

	var fragment_container := FragmentContainer.new()
	$FragmentCollection.add_child(fragment_container)
	fragment_container.global_position = %SpawnPoint.global_position

	var angle_offset = 0
	for color in color_list:
		if color in primary_colors:
			polygon_points = get_poly_points(color, 2, strengths[primary_index], null, null, angle_offset)
			build_nodes(fragment_container, polygon_points, color)
			primary_index += 1
		elif color in secondary_colors:
			polygon_points = get_poly_points(
				color,
				2,
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
				2,
				strengths[tertiary_index],
				strengths[(tertiary_index + 1) % strengths.size()],
				null,
				angle_offset
			)
			build_nodes(fragment_container, polygon_points, color)
			tertiary_index += 1

		angle_offset += 30
	fragment_container.finalize_container()

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
				var intersection_ccw := point_a.lerp(point_b, 4.0 / 5.0)

				var point_c := Vector2.UP.rotated(deg_to_rad(starting_angle + 60)) * third_strength_value
				var point_d := Vector2.UP.rotated(deg_to_rad(starting_angle)) * zero_strength
				var intersection_cw := point_c.lerp(point_d, 4.0 / 5.0)

				poly_points = [
					Vector2.UP.rotated(deg_to_rad(starting_angle)) * zero_strength,
					intersection_cw,
					Vector2.UP.rotated(deg_to_rad(starting_angle)) * second_strength_value,
					intersection_ccw
				]
		3:
			zero_strength = 7.0
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

	var base_mesh := Fragment.get_mesh_from_polygon_points(centered_points)
	if base_mesh == null:
		return

	var inner := MeshInstance2D.new()
	inner.name = "InnerMeshInstance_%s" % str(color_name)
	inner.mesh = base_mesh
	inner.z_index = 1
	inner.position = centroid
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

	border_mesh.material = mat
	border_mesh.z_index = 10

	var color_name = inner.get_meta("color_name")
	border_mesh.name = "BorderMeshInstance_%s" % str(color_name)
	frag.add_child(border_mesh)
	return border_mesh

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
				"weight": METAL_WEIGHTS[metal],
				"id": METAL_TYPES[metal]
			})

	var total := 0.0
	for entry in entries:
		total += entry.weight

	var roll := randf() * total
	var cumulative := 0.0

	for entry in entries:
		cumulative += entry.weight
		if roll <= cumulative:
			return entry.id

	return entries[0].id
