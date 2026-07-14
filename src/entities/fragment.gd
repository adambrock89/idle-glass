class_name Fragment
extends RigidBody2D

var fragment_mass: float = 0.0
var fragment_value: float = 0.0

var color_profile: ColorProfile
var color_name: ColorProfile.ColorName
var base_color: Color

var visual: Polygon2D
var is_being_held: bool = false

var border_mesh: MeshInstance2D
var inner_poly: Polygon2D

@export var pull_strength: float = 5
@export var max_velocity: float = 2500.0
@export var surface_friction: float = 0.2
@export var surface_bounce: float = 0.2
@export var impact_sound_threshold: float = 140.0
@export var impact_cooldown_seconds: float = 0.08
@export var max_sound_speed: float = 900.0

var impact_player: AudioStreamPlayer2D
var impact_cooldown_remaining: float = 0.0

func _ready():
	_cache_meshes()
	_configure_physics_material()
	_configure_audio()
	collision_layer = 1
	collision_mask = 1
	contact_monitor = true
	max_contacts_reported = 4
	input_pickable = false
	can_sleep = false
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if impact_cooldown_remaining > 0.0:
		impact_cooldown_remaining = max(0.0, impact_cooldown_remaining - delta)

	_sync_meshes()
	_update_shader_parameters()

func _configure_audio() -> void:
	impact_player = AudioStreamPlayer2D.new()
	impact_player.max_polyphony = 1
	impact_player.volume_db = -10.0
	add_child(impact_player)

func _configure_physics_material() -> void:
	var mat := PhysicsMaterial.new()
	mat.friction = clamp(surface_friction, 0.0, 1.0)
	mat.bounce = clamp(surface_bounce, 0.0, 1.0)
	mat.rough = false
	physics_material_override = mat

func _sync_meshes() -> void:
	for child in get_children():
		if child is Polygon2D and child.name.begins_with("InnerPolygon_"):
			inner_poly = child
		elif child is MeshInstance2D and child.name.begins_with("BorderMeshInstance_"):
			border_mesh = child

func _update_shader_parameters() -> void:
	var speed: float = linear_velocity.length()
	var motion_factor: float = clampf(speed / 4000.0, 0.0, 0.25)
	var screen_light_dir := Vector2(1, 1).normalized()

	if border_mesh and border_mesh.material is ShaderMaterial:
		var bmat := border_mesh.material as ShaderMaterial
		bmat.set_shader_parameter("motion_factor", motion_factor)
		bmat.set_shader_parameter("light_dir", screen_light_dir.rotated(-border_mesh.global_rotation))

	if inner_poly and inner_poly.material is ShaderMaterial:
		var mat := inner_poly.material as ShaderMaterial
		
		var poly_screen := []
		for p in inner_poly.polygon:
			poly_screen.append(inner_poly.to_global(p))
			
		mat.set_shader_parameter("poly", poly_screen)
		mat.set_shader_parameter("poly_count", poly_screen.size())
		mat.set_shader_parameter("viewport_size", get_viewport_rect().size)
		mat.set_shader_parameter("pane_rotation", inner_poly.global_rotation)

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
			inner_poly = child

func _on_body_entered(_body: Node) -> void:
	if impact_player == null or impact_cooldown_remaining > 0.0:
		return

	var impact_speed := linear_velocity.length()
	if impact_speed < impact_sound_threshold:
		return

	var capped_speed: float = minf(impact_speed, max_sound_speed)
	var intensity: float = clampf(inverse_lerp(impact_sound_threshold, max_sound_speed, capped_speed), 0.18, 1.0)
	impact_cooldown_remaining = impact_cooldown_seconds
	impact_player.stop()
	impact_player.volume_db = lerpf(-16.0, -7.0, intensity)
	impact_player.pitch_scale = lerpf(0.98, 1.03, intensity)
	impact_player.stream = ProceduralSfx.get_fragment_impact_stream(int(color_name), intensity)
	impact_player.play()
