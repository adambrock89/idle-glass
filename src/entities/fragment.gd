class_name Fragment
extends RigidBody2D

var fragment_mass: float = 0.0
var fragment_value: float = 0.0

var color_profile: ColorProfile
var color_name: ColorProfile.ColorName
var base_color: Color

var visual: MeshInstance2D
var is_being_held: bool = false

var border_mesh: MeshInstance2D
var inner_mesh: MeshInstance2D

@export var pull_strength: float = 5
@export var max_velocity: float = 2500.0
@export var surface_friction: float = 0.2
@export var surface_bounce: float = 0.2

func _ready():
	_cache_meshes()
	_configure_physics_material()
	collision_layer = 1
	collision_mask = 1
	contact_monitor = true
	max_contacts_reported = 4
	input_pickable = false
	can_sleep = false

func _configure_physics_material() -> void:
	var mat := PhysicsMaterial.new()
	mat.friction = clamp(surface_friction, 0.0, 1.0)
	mat.bounce = clamp(surface_bounce, 0.0, 1.0)
	mat.rough = false
	physics_material_override = mat


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if is_being_held:
		linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
		angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
		linear_damp = 0.1
		angular_damp = 0.1

		var target_pos: Vector2 = get_global_mouse_position()
		var distance_vector: Vector2 = target_pos - global_position

		var target_velocity: Vector2 = distance_vector * pull_strength
		target_velocity = target_velocity.limit_length(max_velocity)

		state.linear_velocity = state.linear_velocity.lerp(target_velocity, 0.15)
		state.angular_velocity = 0.0
	else:
		linear_damp_mode = RigidBody2D.DAMP_MODE_COMBINE
		angular_damp_mode = RigidBody2D.DAMP_MODE_COMBINE
		linear_damp = 0.1
		angular_damp = 0.1
	
	var speed := linear_velocity.length()
	var motion_factor = clamp(speed / 4000.0, 0.0, 0.25)
	
	for child in get_children():
		if child is MeshInstance2D and child.name.begins_with("InnerMeshInstance_"):
			inner_mesh = child
		elif child is MeshInstance2D and child.name.begins_with("BorderMeshInstance_"):
			border_mesh = child
	if border_mesh and border_mesh.material is ShaderMaterial:
		var bmat := border_mesh.material as ShaderMaterial
		bmat.set_shader_parameter("motion_factor", motion_factor)
		bmat.set_shader_parameter("light_dir", Vector2(1, -1).normalized())
		
	if inner_mesh and inner_mesh.material is ShaderMaterial:
		var mat := inner_mesh.material as ShaderMaterial
		var canvas_xform := get_viewport().get_canvas_transform()
		var screen_pos := canvas_xform * inner_mesh.global_position
		var vp_size: Vector2 = get_viewport().size
		var screen_uv := screen_pos / vp_size
		mat.set_shader_parameter("object_screen_pos", screen_uv)


func get_color_profile() -> ColorProfile:
	return color_profile

func get_fragment_mass() -> float:
	return fragment_mass

func get_value() -> float:
	return fragment_value

static func get_polygon_area(points: PackedVector2Array) -> float:
	var area := 0.0
	var count := points.size()
	for i in range(count):
		var p1 = points[i]
		var p2 = points[(i + 1) % count]
		area += p1.x * p2.y - p2.x * p1.y
	return abs(area) * 0.5

static func get_mesh_from_polygon_points(points: PackedVector2Array) -> ArrayMesh:
	if points.size() < 3:
		return null

	# --- 1. Triangulate polygon ---
	var indices := Geometry2D.triangulate_polygon(points)
	if indices.is_empty():
		push_warning("Triangulation failed.")
		return null

	# --- 2. Compute bounding box for UV mapping ---
	var uv_min := Vector2(INF, INF)
	var uv_max := Vector2(-INF, -INF)

	for p in points:
		uv_min.x = min(uv_min.x, p.x)
		uv_min.y = min(uv_min.y, p.y)
		uv_max.x = max(uv_max.x, p.x)
		uv_max.y = max(uv_max.y, p.y)

	var size := uv_max - uv_min
	if size.x == 0 or size.y == 0:
		size = Vector2(1, 1)  # Avoid division by zero

	# --- 3. Generate UVs ---
	var uvs := PackedVector2Array()
	for p in points:
		var uv := (p - uv_min) / size
		uvs.append(uv)

	# --- 4. Build mesh arrays ---
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)

	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	# --- 4b. Normals ---
	var normals := PackedVector3Array()
	for i in points.size():
		normals.append(Vector3(0, 0, 1))
	arrays[Mesh.ARRAY_NORMAL] = normals


	# --- 5. Commit mesh ---
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return mesh

func _cache_meshes():
	for child in get_children():
		if child is MeshInstance2D and child.name.begins_with("BorderMeshInstance_"):
			border_mesh = child
		elif child is MeshInstance2D and child.name.begins_with("InnerMeshInstance_"):
			inner_mesh = child
