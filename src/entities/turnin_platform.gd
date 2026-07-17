extends Node2D

signal hatch_edges(left_edge: Vector2, right_edge: Vector2, top_edge: Vector2)

const PROCEDURAL_SFX_PATH := "res://src/utils/procedural_sfx.gd"
var procedural_sfx_script: Script = load(PROCEDURAL_SFX_PATH) as Script

var platform_length := 120.0
var hatch_height := 5.0

var animating := false

var top_left_hatch: Node2D
var top_right_hatch: Node2D
var bottom_left_hatch: Node2D
var bottom_right_hatch: Node2D

var hatch_height_delta: float = 60.0

var base_top_left_global: PackedVector2Array
var base_top_right_global: PackedVector2Array
var base_bottom_left_global: PackedVector2Array
var base_bottom_right_global: PackedVector2Array

var base_top_y: float

var rest_y: float
var button_initialized := false
var button_was_pressed: bool = false
var scoring_zone: Area2D
var hatch_speed_multiplier: float = 1.0


func start() -> void:
	build_button()
	build_hatches()

	scoring_zone = create_scoring_zone()
	scoring_zone.monitoring = false

	configure_layout()
	rebuild()


func configure_layout() -> void:
	var viewport := get_viewport()
	var rect := viewport.get_visible_rect()
	var camera := viewport.get_camera_2d()

	if camera == null:
		return

	var world_bottom_y := camera.global_position.y + rect.size.y * 0.5
	var world_center_x := camera.global_position.x

	var scale_y := global_transform.get_scale().y
	var parent_y := world_bottom_y - (hatch_height_delta + hatch_height) * scale_y
	global_position = Vector2(world_center_x, parent_y)



func build_button():
	button_initialized = false

	# BUTTON BASE
	var button_base := StaticBody2D.new()
	button_base.name = "ButtonBase"
	button_base.z_index = 1
	add_child(button_base)

	var base_width := 12.0
	var base_height := 1.5
	var button_base_col := CollisionPolygon2D.new()
	var button_base_vis := Polygon2D.new()
	button_base.add_child(button_base_col)
	button_base.add_child(button_base_vis)
	button_base_col.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(base_width, 0),
		Vector2(base_width, -base_height),
		Vector2(0, -base_height)
	])
	button_base_vis.polygon = button_base_col.polygon
	button_base_vis.color = Color8(200, 200, 200)

	# BUTTON SHAFT
	var button := AnimatableBody2D.new()
	button.name = "ButtonShaft"
	button.z_index = 0
	add_child(button)

	var shaft_width := 8.0
	var shaft_height := base_height + 1.5
	var button_col := CollisionPolygon2D.new()
	var button_vis := Polygon2D.new()
	button.add_child(button_col)
	button.add_child(button_vis)
	button_col.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(shaft_width, 0),
		Vector2(shaft_width, -shaft_height),
		Vector2(0, -shaft_height)
	])
	button_vis.polygon = button_col.polygon
	button_vis.color = Color8(150, 150, 150)

	# PRESS DETECTOR
	var detector := Area2D.new()
	detector.name = "PressDetector"
	button.add_child(detector)

	var detector_poly := CollisionPolygon2D.new()
	detector.add_child(detector_poly)
	detector_poly.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(shaft_width, 0),
		Vector2(shaft_width, -4),
		Vector2(0, -4)
	])
	detector.position = Vector2.ZERO
	detector.monitoring = true
	detector.monitorable = true


func _build_hatch_polygon(is_left: bool) -> PackedVector2Array:
	var half := platform_length * 0.5
	if is_left:
		return PackedVector2Array([
			Vector2(-half, 0),
			Vector2(0, 0),
			Vector2(0, hatch_height),
			Vector2(-half, hatch_height)
		])
	else:
		return PackedVector2Array([
			Vector2(0, 0),
			Vector2(half, 0),
			Vector2(half, hatch_height),
			Vector2(0, hatch_height)
		])


func build_hatches():
	top_left_hatch = build_hatch(true, 0.0)
	top_left_hatch.name = "TopLeftHatch"

	top_right_hatch = build_hatch(false, 0.0)
	top_right_hatch.name = "TopRightHatch"

	bottom_left_hatch = build_hatch(true, hatch_height_delta)
	bottom_left_hatch.name = "BottomLeftHatch"

	bottom_right_hatch = build_hatch(false, hatch_height_delta)
	bottom_right_hatch.name = "BottomRightHatch"


func build_hatch(is_left: bool, y_offset: float) -> Node2D:
	var hatch := StaticBody2D.new()
	add_child(hatch)

	var col := CollisionPolygon2D.new()
	col.name = "CollisionPolygon2D"
	var vis := Polygon2D.new()
	vis.name = "Polygon2D"

	hatch.add_child(col)
	hatch.add_child(vis)

	col.polygon = _build_hatch_polygon(is_left)
	vis.polygon = col.polygon

	if is_left:
		vis.color = Color.WHITE
	else:
		vis.color = Color8(255, 122, 122, 255)

	hatch.position = Vector2(0, y_offset)
	return hatch


func reset_hatch_geometry(hatch: Node2D, is_left: bool):
	var col := hatch.get_node("CollisionPolygon2D") as CollisionPolygon2D
	col.polygon = _build_hatch_polygon(is_left)


func rebuild() -> void:
	# --- TOP HATCHES ALWAYS AT Y = 0 ---
	top_left_hatch.position = Vector2(0, 0)
	top_right_hatch.position = Vector2(0, 0)
	base_top_y = top_left_hatch.position.y

	# --- BOTTOM HATCHES EXTEND DOWNWARD ---
	bottom_left_hatch.position = Vector2(0, hatch_height_delta)
	bottom_right_hatch.position = Vector2(0, hatch_height_delta)

	# BUTTON POSITION (anchored to top hatch)
	var button_offset := 15
	var button_base: StaticBody2D = get_node_or_null("ButtonBase") as StaticBody2D
	if button_base != null:
		button_base.position = Vector2(platform_length / 2 + button_offset, 0)

	var button: AnimatableBody2D = get_node_or_null("ButtonShaft") as AnimatableBody2D
	if button != null:
		button.position = Vector2(platform_length / 2 + button_offset + 2, base_top_y)
		button.set_meta("rest_x", platform_length / 2 + button_offset + 2)

	reset_hatch_geometry(top_left_hatch, true)
	reset_hatch_geometry(top_right_hatch, false)
	reset_hatch_geometry(bottom_left_hatch, true)
	reset_hatch_geometry(bottom_right_hatch, false)

	# STORE BASE GEOMETRY
	base_top_left_global = store_base(top_left_hatch)
	base_top_right_global = store_base(top_right_hatch)
	base_bottom_left_global = store_base(bottom_left_hatch)
	base_bottom_right_global = store_base(bottom_right_hatch)

	# FORCE REST STATE
	animate_hatch(1.0, top_left_hatch, true, true, base_top_left_global)
	animate_hatch(1.0, top_right_hatch, false, true, base_top_right_global)
	animate_hatch(1.0, bottom_left_hatch, true, false, base_bottom_left_global)
	animate_hatch(1.0, bottom_right_hatch, false, false, base_bottom_right_global)

	# SCORING ZONE
	if scoring_zone != null:
		scoring_zone.position = Vector2(-platform_length * 0.5, hatch_height_delta)
		var scoring_collision: CollisionPolygon2D = scoring_zone.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
		if scoring_collision != null:
			scoring_collision.polygon = _build_rect_polygon(platform_length, 40.0)

	# HATCH SIGNAL FOR LEVEL GENERATION
	send_hatch_edges()


func store_base(hatch_node: Node2D) -> PackedVector2Array:
	var col := hatch_node.get_node("CollisionPolygon2D") as CollisionPolygon2D
	var arr := PackedVector2Array()
	for point in col.polygon:
		arr.append(point)
	return arr


func animate_hatch(progress: float, hatch_node: Node2D, is_left: bool, opening: bool, base: PackedVector2Array) -> void:
	var col := hatch_node.get_node("CollisionPolygon2D") as CollisionPolygon2D
	var vis := hatch_node.get_node("Polygon2D") as Polygon2D

	var new_local := PackedVector2Array()

	var half := platform_length * 0.5
	var inner_x := 0.0
	var outer_x := -half if is_left else half

	for point in base:
		var next_point := point
		if is_equal_approx(point.x, inner_x):
			next_point.x = lerp(inner_x, outer_x, progress) if opening else lerp(outer_x, inner_x, progress)
		new_local.append(next_point)

	col.polygon = new_local
	vis.polygon = new_local


func create_scoring_zone() -> Area2D:
	var zone := Area2D.new()
	zone.name = "ScoreZone"
	zone.set_script(load("res://src/entities/score_zone.gd"))

	var colpoly := CollisionPolygon2D.new()
	colpoly.polygon = _build_rect_polygon(platform_length, 40.0)
	zone.add_child(colpoly)

	var debug_poly := Polygon2D.new()
	debug_poly.color = Color(1, 0, 0, 0.3)
	debug_poly.z_index = 999
	debug_poly.polygon = _build_rect_polygon(platform_length, 40.0)
	zone.add_child(debug_poly)

	zone.position = Vector2(0, hatch_height_delta + 40.0)
	add_child(zone)
	zone.monitoring = true
	zone.monitorable = true
	return zone


func _build_rect_polygon(width: float, height: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, 0),
		Vector2(width, 0),
		Vector2(width, height),
		Vector2(0, height)
	])


func _physics_process(delta: float) -> void:
	if not button_initialized:
		button_initialized = true
		return

	var button := get_node_or_null("ButtonShaft")
	if button == null:
		return

	var rest_x_meta = button.get_meta("rest_x")
	if button and rest_x_meta:
		var detector: Area2D = button.get_node("PressDetector") as Area2D
		var press_force := 0.0
		for body in detector.get_overlapping_bodies():
			if body is RigidBody2D:
				press_force += body.mass

		var press_speed := press_force * 0.5 * delta
		rest_y = base_top_y

		var displacement = rest_y - button.position.y
		var spring_strength := 20.0
		var spring_speed = displacement * spring_strength * delta
		var velocity_y = press_speed + spring_speed

		var max_press := 2.0
		var new_y: float = clamp(button.position.y + velocity_y, rest_y, rest_y + max_press)
		var rest_x: float = rest_x_meta
		button.position = Vector2(rest_x, new_y)

		var pressed_now: bool = is_button_pressed()
		button_was_pressed = pressed_now

		if pressed_now and not animating:
			toggle_all_hatches()


func _input(event: InputEvent) -> void:
	if animating:
		return

	if event.is_action_pressed("toggle_hatch"):
		toggle_all_hatches()


func is_button_pressed() -> bool:
	var button: AnimatableBody2D = get_node("ButtonShaft") as AnimatableBody2D
	return button.position.y > rest_y + 1


func toggle_all_hatches() -> void:
	if animating:
		return
	animating = true

	_play_hatch_group_sfx([top_left_hatch, top_right_hatch], false)
	await tween_hatches_parallel(
		[top_left_hatch, top_right_hatch],
		[true, false],
		[false, false],
		[base_top_left_global, base_top_right_global],
		0.5
	)

	_play_hatch_group_sfx([bottom_left_hatch, bottom_right_hatch], true)
	await tween_hatches_parallel(
		[bottom_left_hatch, bottom_right_hatch],
		[true, false],
		[true, true],
		[base_bottom_left_global, base_bottom_right_global],
		0.5
	)

	scoring_zone.monitoring = true
	await get_tree().create_timer(2.0 / max(hatch_speed_multiplier, 0.1)).timeout

	_play_hatch_group_sfx([bottom_left_hatch, bottom_right_hatch], false)
	await tween_hatches_parallel(
		[bottom_left_hatch, bottom_right_hatch],
		[true, false],
		[false, false],
		[base_bottom_left_global, base_bottom_right_global],
		0.5
	)

	scoring_zone.monitoring = false
	update_scoreboard()

	_play_hatch_group_sfx([top_left_hatch, top_right_hatch], true)
	await tween_hatches_parallel(
		[top_left_hatch, top_right_hatch],
		[true, false],
		[true, true],
		[base_top_left_global, base_top_right_global],
		0.5
	)

	await get_tree().create_timer(2.0 / max(hatch_speed_multiplier, 0.1)).timeout
	animating = false


func _play_hatch_group_sfx(hatches: Array, opening: bool) -> void:
	for hatch in hatches:
		if hatch is Node2D:
			_sfx_call("play_hatch_motion_at", [self, (hatch as Node2D).global_position, opening])


func tween_hatches_parallel(hatches: Array, is_left_flags: Array, opening_flags: Array, bases: Array, duration := 1.0) -> void:
	var tween := create_tween()
	for index in hatches.size():
		tween.parallel().tween_method(
			func(progress): animate_hatch(progress, hatches[index], is_left_flags[index], opening_flags[index], bases[index]),
			0.0, 1.0, duration
		)
	await tween.finished


func update_scoreboard() -> void:
	var scoreboard = get_tree().current_scene.find_child("Scoreboard", true, false)
	var score_zone = get_tree().current_scene.find_child("ScoreZone", true, false)
	if scoreboard and score_zone:
		scoreboard.process_batch(score_zone.processed_fragments)
		score_zone.processed_fragments.clear()
		score_zone.seen_fragments.clear()


func _sfx_call(method_name: String, args: Array) -> Variant:
	if procedural_sfx_script == null:
		return null
	return procedural_sfx_script.callv(method_name, args)


func set_hatch_height_delta(val: float):
	hatch_height_delta = val
	rebuild()


func set_platform_length(val: float):
	platform_length = val
	rebuild()


func send_hatch_edges():
	if top_left_hatch == null or top_right_hatch == null:
		return

	var left_col := top_left_hatch.get_node("CollisionPolygon2D") as CollisionPolygon2D
	var left_edge_local := left_col.polygon[0]
	var left_edge_global := left_col.to_global(left_edge_local)

	var right_col := top_right_hatch.get_node("CollisionPolygon2D") as CollisionPolygon2D
	var right_edge_local := right_col.polygon[1]
	var right_edge_global := right_col.to_global(right_edge_local)

	var top_edge_local := Vector2(0, 0)
	var top_edge_global := left_col.to_global(top_edge_local)

	emit_signal("hatch_edges", left_edge_global, right_edge_global, top_edge_global)
