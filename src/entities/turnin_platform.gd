extends Node2D

var platform_length := 200.0
var hatch_height := 5.0
var hatch_offset := 40.0

var animating := false

var top_left_hatch : Node2D
var top_right_hatch : Node2D
var bottom_left_hatch : Node2D
var bottom_right_hatch : Node2D
var bottom_hatch_y : float

var base_top_left_global : PackedVector2Array
var base_top_right_global : PackedVector2Array
var base_bottom_left_global : PackedVector2Array
var base_bottom_right_global : PackedVector2Array
var base_top_y: float

var rest_y : float
var button_initialized := false
var scoring_zone


func _ready():
	button_initialized = false

	var leg := %Leg
	leg.position = Vector2(0, 0)

	var leg_col := leg.get_node("CollisionPolygon2D")
	var leg_vis := leg.get_node("Polygon2D")
	leg_vis.polygon = leg_col.polygon

	var min_y := INF
	var max_y := -INF
	for p in leg_col.polygon:
		min_y = min(min_y, p.y)
		max_y = max(max_y, p.y)

	var leg_height := max_y - min_y

	var top_hatch_y := min_y + leg_height * 0.125
	bottom_hatch_y = min_y + leg_height * 0.875

	var far_leg := leg.duplicate()
	add_child(far_leg)

	var far_leg_col := far_leg.get_node("CollisionPolygon2D")
	var far_leg_vis := far_leg.get_node("Polygon2D")

	far_leg_col.polygon = flip_polygon_horiz(leg_col.polygon)
	far_leg_vis.polygon = far_leg_col.polygon

	far_leg.position = Vector2(platform_length, 0)

	var button_base := StaticBody2D.new()
	button_base.name = "ButtonBase"
	button_base.z_index = 1
	add_child(button_base)

	var bb_col := CollisionPolygon2D.new()
	var bb_vis := Polygon2D.new()
	button_base.add_child(bb_col)
	button_base.add_child(bb_vis)

	var base_width := 12.0
	var base_height := 1.5
	var leg_top_y := min_y

	# Bottom anchored at (0, 0), top at -base_height
	bb_col.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(base_width, 0),
		Vector2(base_width, -base_height),
		Vector2(0, -base_height)
	])

	bb_vis.polygon = bb_col.polygon
	bb_vis.color = Color8(200, 200, 200)

	# Base bottom flush with leg top
	button_base.position = Vector2(platform_length + 10, leg_top_y)

	var button := AnimatableBody2D.new()
	button.name = "ButtonShaft"
	button.z_index = 0
	add_child(button)

	var b_col := CollisionPolygon2D.new()
	var b_vis := Polygon2D.new()
	button.add_child(b_col)
	button.add_child(b_vis)

	var shaft_width := 8.0
	var shaft_height := 1.5

	# Bottom anchored at (0, 0), top at -shaft_height
	b_col.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(shaft_width, 0),
		Vector2(shaft_width, -shaft_height),
		Vector2(0, -shaft_height)
	])

	b_vis.polygon = b_col.polygon
	b_vis.color = Color8(150, 150, 150)

	# Shaft bottom flush with base top
	base_top_y = leg_top_y - base_height
	button.position = Vector2(platform_length + 12, base_top_y)
	button.set_meta("rest_x", platform_length + 12)


	var detector := Area2D.new()
	detector.name = "PressDetector"
	button.add_child(detector)

	# Use CollisionPolygon2D instead of RectangleShape2D
	var det_poly := CollisionPolygon2D.new()
	detector.add_child(det_poly)

	# EXACT same polygon as the debug polygon
	det_poly.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(shaft_width, 0),
		Vector2(shaft_width, -4),
		Vector2(0, -4)
	])

	# No centering offset needed — polygon is already aligned
	detector.position = Vector2(0, 0)

	detector.monitoring = true
	detector.monitorable = true

	top_left_hatch = build_hatch(true, top_hatch_y)
	top_right_hatch = build_hatch(false, top_hatch_y)

	bottom_left_hatch = build_hatch(true, bottom_hatch_y)
	bottom_right_hatch = build_hatch(false, bottom_hatch_y)

	base_top_left_global = store_base(top_left_hatch)
	base_top_right_global = store_base(top_right_hatch)
	base_bottom_left_global = store_base(bottom_left_hatch)
	base_bottom_right_global = store_base(bottom_right_hatch)

	animate_hatch(1.0, top_left_hatch, true, true, base_top_left_global)
	animate_hatch(1.0, top_right_hatch, false, true, base_top_right_global)
	
	scoring_zone = create_scoring_zone()
	scoring_zone.monitoring = false
	
	var top_y := top_left_hatch.global_position.y - 20 # extra 20 for physics "bridges"
	var bottom_y = scoring_zone.global_position.y + 40  # scoring zone height

	create_pull_zone(
		to_local(Vector2(0, top_y)).y,
		to_local(Vector2(0, bottom_y)).y
	)



func _physics_process(delta):
	if not button_initialized:
		button_initialized = true
		return

	var button := get_node("ButtonShaft")
	var detector := button.get_node("PressDetector")

	var bodies = detector.get_overlapping_bodies()

	var press_force := 0.0
	for b in bodies:
		if b is RigidBody2D:
			press_force += b.mass

	var press_speed = press_force * 0.5 * delta

	rest_y = base_top_y

	var displacement = rest_y - button.position.y
	var spring_strength := 20.0
	var spring_speed = displacement * spring_strength * delta

	var velocity_y = press_speed + spring_speed

	var max_press := 2.0
	var new_y = clamp(button.position.y + velocity_y, rest_y, rest_y + max_press)

	var rest_x = button.get_meta("rest_x")
	button.position = Vector2(rest_x, new_y)

	var pressed_now := is_button_pressed()

	if pressed_now and not animating:
		toggle_all_hatches()
		
	var pull_zone := get_node("PullZone")
	var pull_zone_bodies = pull_zone.get_overlapping_bodies()

	for b in pull_zone_bodies:
		if b is RigidBody2D:
			b.apply_central_impulse(Vector2(0, 100))  # small downward tug




func is_button_pressed() -> bool:
	var button := get_node("ButtonShaft")
	return button.position.y > rest_y + 1


func build_hatch(is_left: bool, y_offset: float) -> Node2D:
	var hatch := StaticBody2D.new()
	add_child(hatch)

	var col := CollisionPolygon2D.new()
	var vis := Polygon2D.new()
	col.name = "CollisionPolygon2D"
	vis.name = "Polygon2D"
	hatch.add_child(col)
	hatch.add_child(vis)

	if is_left:
		col.polygon = PackedVector2Array([
			Vector2(hatch_offset, 0),
			Vector2(platform_length * 0.5, 0),
			Vector2(platform_length * 0.5, hatch_height),
			Vector2(hatch_offset, hatch_height)
		])
		vis.color = Color.WHITE
		hatch.position = Vector2(0, y_offset)
	else:
		col.polygon = PackedVector2Array([
			Vector2(platform_length - hatch_offset, 0),
			Vector2(platform_length * 0.5, 0),
			Vector2(platform_length * 0.5, hatch_height),
			Vector2(platform_length - hatch_offset, hatch_height)
		])
		vis.color = Color8(255, 122, 122, 255)
		hatch.position = Vector2(0, y_offset)  # ← IMPORTANT: same origin as left hatch


	vis.polygon = col.polygon
	return hatch


func store_base(hatch_node: Node2D) -> PackedVector2Array:
	var col := hatch_node.get_node("CollisionPolygon2D")
	var arr := PackedVector2Array()
	for p in col.polygon:
		arr.append(col.to_global(p))
	return arr


func _input(event):
	if animating:
		return

	if event.is_action_pressed("toggle_hatch"):
		toggle_all_hatches()


func tween_hatch(hatch: Node2D, is_left: bool, opening: bool, base: PackedVector2Array, duration := 1.0) -> void:
	var t := create_tween()
	t.tween_method(
		func(progress): animate_hatch(progress, hatch, is_left, opening, base),
		0.0, 1.0, duration
	)
	await t.finished

# Hatch Animation Function
func toggle_all_hatches() -> void:
	if animating:
		return
	animating = true

	# STEP 1: Close top pair
	await tween_hatches_parallel(
		[top_left_hatch, top_right_hatch],
		[true, false],
		[false, false],
		[base_top_left_global, base_top_right_global],
		.5
	)

	# STEP 2: Open bottom pair
	await tween_hatches_parallel(
		[bottom_left_hatch, bottom_right_hatch],
		[true, false],
		[true, true],
		[base_bottom_left_global, base_bottom_right_global],
		.5
	)

	scoring_zone.monitoring = true

	# STEP 3: Wait
	await get_tree().create_timer(2.0).timeout

	# STEP 4: Close bottom pair
	await tween_hatches_parallel(
		[bottom_left_hatch, bottom_right_hatch],
		[true, false],
		[false, false],
		[base_bottom_left_global, base_bottom_right_global],
		.5
	)

	scoring_zone.monitoring = false

	update_scoreboard()

	# STEP 5: Open top pair
	await tween_hatches_parallel(
		[top_left_hatch, top_right_hatch],
		[true, false],
		[true, true],
		[base_top_left_global, base_top_right_global],
		.5
	)

	await get_tree().create_timer(2.0).timeout
	animating = false



func animate_hatch(progress: float, hatch_node: Node2D, is_left: bool, opening: bool, base: PackedVector2Array):
	var col := hatch_node.get_node("CollisionPolygon2D")
	var vis := hatch_node.get_node("Polygon2D")

	var new_global := PackedVector2Array()

	var min_x := INF
	var max_x := -INF
	for p in base:
		min_x = min(min_x, p.x)
		max_x = max(max_x, p.x)

	var outer_x := max_x if is_left else min_x
	var inner_x := min_x if is_left else max_x

	for p in base:
		var np := p
		if p.x == outer_x:
			np.x = lerp(outer_x, inner_x, progress) if opening else lerp(inner_x, outer_x, progress)
		new_global.append(np)

	var new_col_local := PackedVector2Array()
	var new_vis_local := PackedVector2Array()

	for p in new_global:
		new_col_local.append(col.to_local(p))
		new_vis_local.append(vis.to_local(p))

	col.polygon = new_col_local
	vis.polygon = new_vis_local


func create_scoring_zone() -> Area2D:
	# Create node
	var zone := Area2D.new()
	zone.name = "ScoreZone"

	# Attach script BEFORE adding to scene
	zone.set_script(load("res://score_zone.gd"))

	# --- Collision Shape Setup ---
	var colpoly := CollisionPolygon2D.new()
	colpoly.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(platform_length, 0),
		Vector2(platform_length, 40),
		Vector2(0, 40)
	])
	zone.add_child(colpoly)

	# --- Debug Polygon ---
	var debug_poly := Polygon2D.new()
	debug_poly.color = Color(1, 0, 0, 0.3)
	debug_poly.z_index = 999
	debug_poly.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(platform_length, 0),
		Vector2(platform_length, 40),
		Vector2(0, 40)
	])
	zone.add_child(debug_poly)

	# --- Positioning ---
		# Get hatch global Y
	var hatch_global_y := bottom_left_hatch.global_position.y

	# Convert to TurnInPlatform local space
	var hatch_local_y := to_local(Vector2(0, hatch_global_y)).y

	# Place scoring zone directly under hatch
	zone.position = Vector2(0, hatch_local_y + 40)

	# Add to scene *after* children exist
	add_child(zone)

	# --- Ensure monitoring stays ON ---
	zone.monitoring = true
	zone.monitorable = true

	return zone

	
func update_scoreboard():
	var scoreboard = get_tree().current_scene.find_child("Scoreboard", true, false)
	var score_zone = get_tree().current_scene.find_child("ScoreZone", true, false)

	if scoreboard and score_zone:
		scoreboard.process_batch(score_zone.processed_fragments)
		score_zone.processed_fragments.clear()
		score_zone.seen_fragments.clear()

func flip_polygon_horiz(points: PackedVector2Array) -> PackedVector2Array:
	var flipped := PackedVector2Array()
	for p in points:
		flipped.append(Vector2(-p.x, p.y))
	return flipped

func tween_hatches_parallel(hatches: Array, is_left_flags: Array, opening_flags: Array, bases: Array, duration := 1.0) -> void:
	var t := create_tween()
	for i in hatches.size():
		t.parallel().tween_method(
			func(progress): animate_hatch(progress, hatches[i], is_left_flags[i], opening_flags[i], bases[i]),
			0.0, 1.0, duration
		)
	await t.finished

func create_pull_zone(top_y: float, bottom_y: float) -> Area2D:
	var zone := Area2D.new()
	zone.name = "PullZone"
	zone.monitoring = true
	zone.monitorable = true

	var height := bottom_y - top_y
	var width := platform_length

	var col := CollisionPolygon2D.new()
	col.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(width, 0),
		Vector2(width, height),
		Vector2(0, height)
	])
	zone.add_child(col)

	zone.position = Vector2(0, top_y)

	add_child(zone)
	return zone
