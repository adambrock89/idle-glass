extends Node2D

var stone_shader := preload("res://assets/shaders/stone.gdshader") as Shader

func _ready():
	var platform := %Platform
	if platform:
		platform.connect("hatch_edges", Callable(self, "_on_hatch_edges"))
		platform.start()
		

func generate_level_boundaries(hatch_left_edge: Vector2, hatch_right_edge: Vector2, hatch_top_edge: Vector2) -> void:
	print("generating level")
	var viewport := get_viewport().get_visible_rect()
	var screen_top := viewport.position.y
	var screen_bottom := viewport.position.y + viewport.size.y
	var screen_left := viewport.position.x
	var screen_right := viewport.position.x + viewport.size.x

	# ----------------------------------------
	# LEFT SIDE BOUNDARY
	# ----------------------------------------
	var left_poly := PackedVector2Array([
		Vector2(screen_left + 100.0, screen_top),             # 1. Top of screen, 100px from left
		Vector2(screen_left + 100.0, hatch_top_edge.y),       # 2. Straight down to hatch top Y
		Vector2(hatch_left_edge.x, hatch_top_edge.y),         # 3. Straight right to left hatch edge X
		Vector2(hatch_left_edge.x, screen_bottom),            # 4. Straight down to bottom of screen
		Vector2(screen_left, screen_bottom),                  # 5. Bottom-left of screen
		Vector2(screen_left, screen_top)                      # 6. Top-left of screen
	])

	var left_body = find_child("LeftBoundaryBody", true, false)
	if not left_body:
		left_body = StaticBody2D.new()
		left_body.name = "LeftBoundaryBody"
		add_child(left_body)

	var left_boundary = find_child("LeftBoundary", true, false)
	if not left_boundary:
		left_boundary = CollisionPolygon2D.new()
		left_boundary.name = "LeftBoundary"
		left_body.add_child(left_boundary)
	left_boundary.polygon = left_poly
	
	var left_vis = find_child("LeftBoundaryVisual", true, false)
	if not left_vis:
		left_vis = Polygon2D.new()
		left_vis.name = "LeftBoundaryVisual"
		left_vis.color = Color(0.2, 0.6, 1.0, 0.25)
		left_body.add_child(left_vis)
	left_vis.polygon = left_poly
	left_vis.material = ShaderMaterial.new()
	left_vis.material.shader = stone_shader
	
	# ----------------------------------------
	# RIGHT SIDE BOUNDARY
	# ----------------------------------------
	var right_poly := PackedVector2Array([
		Vector2(screen_right - 100.0, screen_top),            # 1. Top of screen, 100px from right
		Vector2(screen_right - 100.0, hatch_top_edge.y),      # 2. Straight down to hatch top Y
		Vector2(hatch_right_edge.x, hatch_top_edge.y),        # 3. Straight left to right hatch edge X
		Vector2(hatch_right_edge.x, screen_bottom),           # 4. Straight down to bottom of screen
		Vector2(screen_right, screen_bottom),                 # 5. Bottom-right of screen
		Vector2(screen_right, screen_top)                     # 6. Top-right of screen
	])
	
	var right_body = find_child("RightBoundaryBody", true, false)
	if not right_body:
		right_body = StaticBody2D.new()
		right_body.name = "RightBoundaryBody"
		add_child(right_body)
	
	var right_boundary = find_child("RightBoundary", true, false)
	if not right_boundary:
		right_boundary = CollisionPolygon2D.new()
		right_boundary.name = "RightBoundary"
		right_body.add_child(right_boundary)
	right_boundary.polygon = right_poly
	
	var right_vis = find_child("RightBoundaryVisual", true, false)
	if not right_vis:
		right_vis = Polygon2D.new()
		right_vis.name = "RightBoundaryVisual"
		right_vis.color = Color(1.0, 0.4, 0.4, 0.25)
		right_body.add_child(right_vis)
	right_vis.polygon = right_poly
	right_vis.material = ShaderMaterial.new()
	right_vis.material.shader = stone_shader
	
func _on_hatch_edges(left_edge: Vector2, right_edge: Vector2, top_edge: Vector2):
	print("about to generate")
	generate_level_boundaries(left_edge, right_edge, top_edge)

	# Your logic here
