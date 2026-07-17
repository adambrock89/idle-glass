extends StaticBody2D

var visual_node: Node2D
var collision_polygon: CollisionPolygon2D
var is_being_placed := false

func _ready():
	for child in get_children():
		if child is CollisionPolygon2D:
			collision_polygon = child
		elif child is Node2D and not (child is CollisionPolygon2D or child is CollisionShape2D):
			visual_node = child

	input_pickable = true
	set_process_input(true)
	add_to_group("placeable")


func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		var mouse = event.position

		if %Scoreboard.panel_root.get_global_rect().has_point(mouse):
			return

		if %Shop.shop_panel.get_global_rect().has_point(mouse):
			return
		if _mouse_over_self():
			start_placing()


func _mouse_over_self() -> bool:
	var params := PhysicsPointQueryParameters2D.new()
	params.position = get_global_mouse_position()
	params.collide_with_bodies = true
	params.collision_mask = collision_layer

	var space := get_world_2d().direct_space_state
	var results := space.intersect_point(params, 8)

	for hit in results:
		if hit.collider == self:
			return true

	return false


func start_placing():
	if is_being_placed:
		return
	is_being_placed = true
	var ghost := GhostPreview.new()
	ghost.source_node = self
	get_tree().current_scene.add_child(ghost)
