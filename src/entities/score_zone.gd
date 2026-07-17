extends Area2D

var seen_fragments := {}
var processed_fragments := []

func _ready():
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body is Fragment and not seen_fragments.has(body):
		seen_fragments[body] = true
		processed_fragments.append(body)

func _score_fragment(fragment):
	var scoreboard = get_tree().current_scene.find_child("Scoreboard", true, false)
	if scoreboard == null:
		print("ERROR: Scoreboard not found")
		return

	scoreboard.score_shape(fragment)
