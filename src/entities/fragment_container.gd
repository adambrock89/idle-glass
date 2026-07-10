class_name FragmentContainer
extends RigidBody2D

@export var break_speed_threshold: float = 200.0

var last_speed: float = 0.0
var hull_polygon_points: PackedVector2Array


func _ready() -> void:
	contact_monitor = true
	max_contacts_reported = 8
	body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	# Track container speed
	last_speed = linear_velocity.length()

	var motion_factor = clamp(last_speed / 4000.0, 0.0, 0.25)
	var light := Vector2(1, -1).normalized()

	for child in get_children():
		if child is MeshInstance2D and child.name.begins_with("BorderMeshInstance_"):
			var mat := child.material as ShaderMaterial
			if mat:
				mat.set_shader_parameter("motion_factor", motion_factor)
				mat.set_shader_parameter("light_dir", light)




func _on_body_entered(_body: Node) -> void:
	if last_speed > break_speed_threshold:
		break_apart()


func finalize_container() -> void:
	generate_convex_hull_collision()
	_update_mass_from_hull()


func break_apart() -> void:
	var fragment_collection := _get_fragment_collection()
	if fragment_collection == null:
		
		return

	var scene_root := get_tree().current_scene
	var break_intensity: float = clampf(last_speed / maxf(break_speed_threshold * 3.0, 1.0), 0.2, 1.0)
	ProceduralSfx.play_break_at(scene_root, global_position, break_intensity)

	var container_linear_velocity := linear_velocity
	var container_angular_velocity := angular_velocity

	var collisions: Array[CollisionPolygon2D] = []
	var borders: Array[MeshInstance2D] = []
	var inners: Array[MeshInstance2D] = []
	_collect_fragment_children(collisions, borders, inners)

	var container_global_pos := global_position

	for inner in inners:
		var key := inner.name.replace("InnerMeshInstance_", "")

		var col = null
		for c in collisions:
			if c.name.ends_with(key):
				col = c
				break

		if col == null:
			
			continue

		var border = null
		for b in borders:
			if b.name.ends_with(key):
				border = b
				break

		_spawn_fragment_from_parts(
			key,
			col,
			inner,
			border,
			container_global_pos,
			fragment_collection,
			container_linear_velocity,
			container_angular_velocity
		)

	queue_free()


func _get_fragment_collection() -> Node:
	return get_tree().current_scene.find_child("FragmentCollection", true, false)


func _collect_fragment_children(
	collisions: Array[CollisionPolygon2D],
	borders: Array[MeshInstance2D],
	inners: Array[MeshInstance2D]
) -> void:
	for child in get_children():
		if child is CollisionPolygon2D:
			collisions.append(child)
		elif child is MeshInstance2D and child.name.begins_with("InnerMeshInstance_"):
			inners.append(child)
		elif child is MeshInstance2D and child.name.begins_with("BorderMeshInstance_"):
			borders.append(child)

func _spawn_fragment_from_parts(
	key,
	col: CollisionPolygon2D,
	inner: MeshInstance2D,
	border: MeshInstance2D,
	container_global_pos: Vector2,
	fragment_collection: Node,
	container_linear_velocity: Vector2,
	container_angular_velocity: float
) -> void:
	var frag := Fragment.new()
	frag.name = "Fragment_%s" % key
	fragment_collection.add_child(frag)

	frag.global_position = col.global_position

	_assign_fragment_mass_from_polygon(frag, col)

	var border_xform := border.global_transform
	var col_xform := col.global_transform
	var inner_xform := inner.global_transform

	remove_child(border)
	remove_child(col)
	remove_child(inner)

	frag.call_deferred("add_child", border)
	frag.call_deferred("add_child", col)
	frag.call_deferred("add_child", inner)

	border.call_deferred("set", "global_transform", border_xform)
	col.call_deferred("set", "global_transform", col_xform)
	inner.call_deferred("set", "global_transform", inner_xform)

	_copy_fragment_metadata_from_inner(frag, inner)

	if border != null:
		frag.set_meta("border_mesh", border)

	_inherit_container_motion(
		frag,
		container_global_pos,
		container_linear_velocity,
		container_angular_velocity
	)

func _assign_fragment_mass_from_polygon(frag: Fragment, col: CollisionPolygon2D) -> void:
	var inner_points := PackedVector2Array()
	for p in col.polygon:
		inner_points.append(p / 1.15)

	var area := Fragment.get_polygon_area(inner_points)
	frag.fragment_mass = area * 0.1
	frag.mass = frag.fragment_mass


func _copy_fragment_metadata_from_inner(frag: Fragment, inner: MeshInstance2D) -> void:
	var cp: ColorProfile = inner.get_meta("color_profile")
	var color_name = inner.get_meta("color_name")
	var base_color: Color = inner.get_meta("base_color")

	frag.color_profile = cp
	frag.color_name = color_name
	frag.base_color = base_color
	frag.visual = inner


func _inherit_container_motion(
	frag: Fragment,
	container_global_pos: Vector2,
	container_linear_velocity: Vector2,
	container_angular_velocity: float
) -> void:
	var offset := frag.global_position - container_global_pos
	var tangential_velocity := Vector2(-offset.y, offset.x) * container_angular_velocity
	frag.linear_velocity = container_linear_velocity + tangential_velocity
	frag.angular_velocity = container_angular_velocity


func generate_convex_hull_collision() -> void:
	var all_points := PackedVector2Array()

	for child in get_children():
		if child is CollisionPolygon2D:
			for p in child.polygon:
				all_points.append(child.to_local(child.to_global(p)))

	if all_points.size() < 3:
		return

	var hull := Geometry2D.convex_hull(all_points)
	hull.reverse()
	hull_polygon_points = hull

	var cs := CollisionShape2D.new()
	var shape := ConvexPolygonShape2D.new()
	shape.points = hull
	cs.shape = shape
	add_child(cs)


func _update_mass_from_hull() -> void:
	if hull_polygon_points.size() >= 3:
		mass = Fragment.get_polygon_area(hull_polygon_points)
	else:
		mass = 1.0
