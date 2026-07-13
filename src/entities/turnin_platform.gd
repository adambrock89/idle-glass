extends Node2D

const PROCEDURAL_SFX_PATH := "res://src/utils/procedural_sfx.gd"
var procedural_sfx_script: Script = load(PROCEDURAL_SFX_PATH) as Script

var platform_length := 200.0
var hatch_height := 5.0
var hatch_offset := 40.0

var animating := false

var top_left_hatch: Node2D
var top_right_hatch: Node2D
var bottom_left_hatch: Node2D
var bottom_right_hatch: Node2D
var bottom_hatch_y: float
var hatch_height_delta: float = 0.0

var base_top_left_global: PackedVector2Array
var base_top_right_global: PackedVector2Array
var base_bottom_left_global: PackedVector2Array
var base_bottom_right_global: PackedVector2Array
var base_top_y: float
var leg_top_y: float = 0.0

var rest_y: float
var button_initialized := false
var button_was_pressed: bool = false
var button_sfx_player: AudioStreamPlayer2D = null
var scoring_zone: Area2D
var pull_zone: Area2D
var hatch_speed_multiplier: float = 1.0


func _ready() -> void:
	button_initialized = false

	var leg: StaticBody2D = %Leg
	leg.position = Vector2.ZERO

	var leg_col: CollisionPolygon2D = leg.get_node("CollisionPolygon2D") as CollisionPolygon2D
	var leg_vis: Polygon2D = leg.get_node("Polygon2D") as Polygon2D
	leg_vis.polygon = leg_col.polygon

	var min_y := INF
	var max_y := -INF
	for point in leg_col.polygon:
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)

	var leg_height := max_y - min_y
	var top_hatch_y := min_y + leg_height * 0.125
	bottom_hatch_y = min_y + leg_height * 0.875 + hatch_height_delta
	leg_top_y = min_y

	var far_leg: StaticBody2D = leg.duplicate() as StaticBody2D
	far_leg.name = "FarLeg"
	add_child(far_leg)

	var far_leg_col: CollisionPolygon2D = far_leg.get_node("CollisionPolygon2D") as CollisionPolygon2D
	var far_leg_vis: Polygon2D = far_leg.get_node("Polygon2D") as Polygon2D
	far_leg_col.polygon = flip_polygon_horiz(leg_col.polygon)
	far_leg_vis.polygon = far_leg_col.polygon

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

	var button := AnimatableBody2D.new()
	button.name = "ButtonShaft"
	button.z_index = 0
	add_child(button)

	var shaft_width := 8.0
	var shaft_height := 1.5
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


	base_top_y = leg_top_y - base_height

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

	top_left_hatch = build_hatch(true, top_hatch_y)
	top_left_hatch.name = "TopLeftHatch"
	top_right_hatch = build_hatch(false, top_hatch_y)
	top_right_hatch.name = "TopRightHatch"
	bottom_left_hatch = build_hatch(true, bottom_hatch_y)
	bottom_left_hatch.name = "BottomLeftHatch"
	bottom_right_hatch = build_hatch(false, bottom_hatch_y)
	bottom_right_hatch.name = "BottomRightHatch"

	button_sfx_player = AudioStreamPlayer2D.new()
	button_sfx_player.name = "ButtonSfxPlayer"
	button_sfx_player.volume_db = -3.0
	button_sfx_player.attenuation = 0.0
	button_sfx_player.max_distance = 100000.0
	add_child(button_sfx_player)

	scoring_zone = create_scoring_zone()
	scoring_zone.monitoring = false
	pull_zone = create_pull_zone(0.0, 0.0)
	update()


func update() -> void:
	var far_leg: Node2D = get_node_or_null("FarLeg") as Node2D
	if far_leg != null:
		far_leg.position = Vector2(platform_length, 0)

	var button_base: StaticBody2D = get_node_or_null("ButtonBase") as StaticBody2D
	if button_base != null:
		button_base.position = Vector2(platform_length - 35.0, leg_top_y)

	var button: AnimatableBody2D = get_node_or_null("ButtonShaft") as AnimatableBody2D
	if button != null:
		button.position = Vector2(platform_length -33.0, base_top_y)
		button.set_meta("rest_x", platform_length -33.0)

	_update_hatch_geometry(top_left_hatch, true)
	_update_hatch_geometry(top_right_hatch, false)
	_update_hatch_geometry(bottom_left_hatch, true)
	_update_hatch_geometry(bottom_right_hatch, false)

	base_top_left_global = store_base(top_left_hatch)
	base_top_right_global = store_base(top_right_hatch)
	base_bottom_left_global = store_base(bottom_left_hatch)
	base_bottom_right_global = store_base(bottom_right_hatch)

	animate_hatch(1.0, top_left_hatch, true, true, base_top_left_global)
	animate_hatch(1.0, top_right_hatch, false, true, base_top_right_global)
	animate_hatch(1.0, bottom_left_hatch, true, false, base_bottom_left_global)
	animate_hatch(1.0, bottom_right_hatch, false, false, base_bottom_right_global)

	if scoring_zone != null:
		scoring_zone.position = Vector2(0, bottom_hatch_y + 40.0)
		var scoring_collision: CollisionPolygon2D = scoring_zone.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
		if scoring_collision != null:
			scoring_collision.polygon = _build_rect_polygon(platform_length, 40.0)
		var scoring_visual: Polygon2D = scoring_zone.get_node_or_null("Polygon2D") as Polygon2D
		if scoring_visual != null:
			scoring_visual.polygon = _build_rect_polygon(platform_length, 40.0)

	if pull_zone != null and scoring_zone != null:
		var top_y: float = top_left_hatch.position.y - 20.0
		var bottom_y: float = scoring_zone.position.y + 40.0
		pull_zone.position = Vector2(0, top_y)
		var pull_collision: CollisionPolygon2D = pull_zone.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
		if pull_collision != null:
			pull_collision.polygon = _build_rect_polygon(platform_length, bottom_y - top_y)


func _update_hatch_geometry(hatch: Node2D, is_left: bool) -> void:
	if hatch == null:
		return

	var collision: CollisionPolygon2D = hatch.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	var visual: Polygon2D = hatch.get_node_or_null("Polygon2D") as Polygon2D
	if collision == null or visual == null:
		return

	if is_left:
		collision.polygon = PackedVector2Array([
			Vector2(hatch_offset, 0),
			Vector2(platform_length * 0.5, 0),
			Vector2(platform_length * 0.5, hatch_height),
			Vector2(hatch_offset, hatch_height)
		])
	else:
		collision.polygon = PackedVector2Array([
			Vector2(platform_length - hatch_offset, 0),
			Vector2(platform_length * 0.5, 0),
			Vector2(platform_length * 0.5, hatch_height),
			Vector2(platform_length - hatch_offset, hatch_height)
		])

	visual.polygon = collision.polygon


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

	var button: AnimatableBody2D = get_node("ButtonShaft") as AnimatableBody2D
	var detector: Area2D = button.get_node("PressDetector") as Area2D
	var press_force := 0.0
	for body in detector.get_overlapping_bodies():
		if body is RigidBody2D:
			press_force += body.mass

	var press_speed := press_force * 0.5 * delta
	rest_y = base_top_y

	var displacement := rest_y - button.position.y
	var spring_strength := 20.0
	var spring_speed := displacement * spring_strength * delta
	var velocity_y := press_speed + spring_speed

	var max_press := 2.0
	var new_y: float = clamp(button.position.y + velocity_y, rest_y, rest_y + max_press)
	var rest_x: float = float(button.get_meta("rest_x"))
	button.position = Vector2(rest_x, new_y)

	var pressed_now: bool = is_button_pressed()
	if pressed_now and not button_was_pressed:
		_play_button_click_down()
	elif not pressed_now and button_was_pressed:
		_play_button_click_up()
	button_was_pressed = pressed_now

	if pressed_now and not animating:
		toggle_all_hatches()

	var active_pull_zone: Area2D = get_node("PullZone") as Area2D
	for body in active_pull_zone.get_overlapping_bodies():
		if body is RigidBody2D:
			body.apply_central_impulse(Vector2(0, 100))


func is_button_pressed() -> bool:
	var button: AnimatableBody2D = get_node("ButtonShaft") as AnimatableBody2D
	return button.position.y > rest_y + 1


func _sfx_call(method_name: String, args: Array) -> Variant:
	if procedural_sfx_script == null:
		return null
	return procedural_sfx_script.callv(method_name, args)


func _play_button_click_down() -> void:
	if button_sfx_player == null:
		return
	button_sfx_player.global_position = (get_node("ButtonShaft") as Node2D).global_position
	button_sfx_player.stream = _sfx_call("get_ui_click_down_stream", []) as AudioStream
	button_sfx_player.play()


func _play_button_click_up() -> void:
	if button_sfx_player == null:
		return
	button_sfx_player.global_position = (get_node("ButtonShaft") as Node2D).global_position
	button_sfx_player.stream = _sfx_call("get_ui_click_up_stream", []) as AudioStream
	button_sfx_player.play()


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
	else:
		col.polygon = PackedVector2Array([
			Vector2(platform_length - hatch_offset, 0),
			Vector2(platform_length * 0.5, 0),
			Vector2(platform_length * 0.5, hatch_height),
			Vector2(platform_length - hatch_offset, hatch_height)
		])
		vis.color = Color8(255, 122, 122, 255)

	hatch.position = Vector2(0, y_offset)
	vis.polygon = col.polygon
	return hatch


func store_base(hatch_node: Node2D) -> PackedVector2Array:
	var col: CollisionPolygon2D = hatch_node.get_node("CollisionPolygon2D") as CollisionPolygon2D
	var arr := PackedVector2Array()
	for point in col.polygon:
		arr.append(col.to_global(point))
	return arr


func _input(event: InputEvent) -> void:
	if animating:
		return

	if event.is_action_pressed("toggle_hatch"):
		toggle_all_hatches()


func tween_hatch(hatch: Node2D, is_left: bool, opening: bool, base: PackedVector2Array, duration := 1.0) -> void:
	var tween := create_tween()
	tween.tween_method(
		func(progress): animate_hatch(progress, hatch, is_left, opening, base),
		0.0, 1.0, duration
	)
	await tween.finished


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


func animate_hatch(progress: float, hatch_node: Node2D, is_left: bool, opening: bool, base: PackedVector2Array) -> void:
	var col: CollisionPolygon2D = hatch_node.get_node("CollisionPolygon2D") as CollisionPolygon2D
	var vis: Polygon2D = hatch_node.get_node("Polygon2D") as Polygon2D

	var new_global := PackedVector2Array()
	var min_x := INF
	var max_x := -INF
	for point in base:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)

	var outer_x := max_x if is_left else min_x
	var inner_x := min_x if is_left else max_x

	for point in base:
		var next_point := point
		if point.x == outer_x:
			next_point.x = lerp(outer_x, inner_x, progress) if opening else lerp(inner_x, outer_x, progress)
		new_global.append(next_point)

	var new_col_local := PackedVector2Array()
	var new_vis_local := PackedVector2Array()
	for point in new_global:
		new_col_local.append(col.to_local(point))
		new_vis_local.append(vis.to_local(point))

	col.polygon = new_col_local
	vis.polygon = new_vis_local


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

	zone.position = Vector2(0, bottom_hatch_y + 40.0)
	add_child(zone)
	zone.monitoring = true
	zone.monitorable = true
	return zone


func update_scoreboard() -> void:
	var scoreboard = get_tree().current_scene.find_child("Scoreboard", true, false)
	var score_zone = get_tree().current_scene.find_child("ScoreZone", true, false)
	if scoreboard and score_zone:
		scoreboard.process_batch(score_zone.processed_fragments)
		score_zone.processed_fragments.clear()
		score_zone.seen_fragments.clear()


func flip_polygon_horiz(points: PackedVector2Array) -> PackedVector2Array:
	var flipped := PackedVector2Array()
	for point in points:
		flipped.append(Vector2(-point.x, point.y))
	return flipped


func tween_hatches_parallel(hatches: Array, is_left_flags: Array, opening_flags: Array, bases: Array, duration := 1.0) -> void:
	var tween := create_tween()
	for index in hatches.size():
		tween.parallel().tween_method(
			func(progress): animate_hatch(progress, hatches[index], is_left_flags[index], opening_flags[index], bases[index]),
			0.0, 1.0, duration
		)
	await tween.finished


func create_pull_zone(top_y: float, bottom_y: float) -> Area2D:
	var zone := Area2D.new()
	zone.name = "PullZone"
	zone.monitoring = true
	zone.monitorable = true

	var col := CollisionPolygon2D.new()
	col.polygon = _build_rect_polygon(platform_length, max(0.0, bottom_y - top_y))
	zone.add_child(col)

	zone.position = Vector2(0, top_y)
	add_child(zone)
	return zone


func set_hatch_speed_multiplier(multiplier: float) -> void:
	hatch_speed_multiplier = max(0.1, multiplier)


func set_platform_length(length_value: float) -> void:
	platform_length = max(120.0, length_value)
	update()




func set_hatch_height_delta(delta_value: float) -> void:
	hatch_height_delta = max(0.0, delta_value)
	var leg: StaticBody2D = %Leg
	var leg_col: CollisionPolygon2D = leg.get_node("CollisionPolygon2D") as CollisionPolygon2D

	var min_y := INF
	var max_y := -INF
	for point in leg_col.polygon:
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)

	var leg_height := max_y - min_y
	bottom_hatch_y = min_y + leg_height * 0.875 + hatch_height_delta
	update()
