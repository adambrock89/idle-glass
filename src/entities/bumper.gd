extends CollisionShape2D

func _onready():
	var mat := PhysicsMaterial.new()
	mat.bounce = 50.0
	mat.friction = 0.0
