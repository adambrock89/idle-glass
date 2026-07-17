extends Control

@onready var upgrade_row_scene: PackedScene = preload("res://scenes/ui/upgrade_row.tscn")
var scoreboard: CanvasLayer = null

var upgrades_data: Array = []
var current_level: Dictionary = {}

var shop_panel: Control = null
var list_container: VBoxContainer = null
var ui_click_player: AudioStreamPlayer = null
var suppress_score_refresh: bool = false
var scoreboard_open_rect: Rect2
var last_mouse_pos: Vector2 = Vector2.ZERO

var is_open: bool = false

func _ready() -> void:
	# load upgrades
	var file: FileAccess = FileAccess.open("res://data/upgrades.json", FileAccess.READ)
	if file == null:
		push_error("Could not open upgrades.json")
		return
	var txt: String = file.get_as_text()
	var parsed = JSON.parse_string(txt)
	# JSON.parse_string may return a parse-result Dictionary or the direct value depending on engine build.
	if parsed is Dictionary and parsed.has("error"):
		if int(parsed.get("error")) != OK:
			push_error("Failed to parse upgrades.json: %s" % str(parsed.get("error")))
			return
		upgrades_data = parsed.get("result", []) as Array
	else:
		upgrades_data = parsed as Array

	# init current levels
	for raw_series in upgrades_data:
		var series: Dictionary = raw_series as Dictionary
		var sid: String = String(series.get("id", ""))
		current_level[sid] = 0

	# build UI container
	shop_panel = PanelContainer.new()
	shop_panel.name = "ShopPanel"
	shop_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shop_panel.custom_minimum_size = Vector2(0, 0)
	shop_panel.visible = false
	shop_panel.add_theme_stylebox_override("panel", _build_panel_style())
	shop_panel.mouse_filter = Control.MOUSE_FILTER_STOP


	var panel_margin := MarginContainer.new()
	panel_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_margin.add_theme_constant_override("margin_left", 16)
	panel_margin.add_theme_constant_override("margin_top", 16)
	panel_margin.add_theme_constant_override("margin_right", 16)
	panel_margin.add_theme_constant_override("margin_bottom", 16)
	shop_panel.add_child(panel_margin)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel_margin.add_child(scroll)

	list_container = VBoxContainer.new()
	list_container.name = "List"
	list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_container.add_theme_constant_override("separation", 10)
	scroll.add_child(list_container)

	ui_click_player = AudioStreamPlayer.new()
	ui_click_player.stream = ProceduralSfx.get_ui_click_stream()
	ui_click_player.volume_db = -5.0
	add_child(ui_click_player)

	# try to find scoreboard and connect: prefer current scene, fallback to root
	var current_scene: Node = get_tree().get_current_scene()
	if current_scene != null:
		scoreboard = _find_node_by_name(current_scene, "Scoreboard") as CanvasLayer
	if scoreboard == null:
		scoreboard = _find_node_by_name(get_tree().get_root(), "Scoreboard") as CanvasLayer

	if scoreboard != null:
		scoreboard.connect("shop_toggled", Callable(self, "_on_scoreboard_clicked"))
		scoreboard.connect("scores_changed", Callable(self, "_on_scores_changed"))
		if scoreboard.has_method("attach_shop_panel"):
			scoreboard.call("attach_shop_panel", shop_panel)
		if scoreboard.has_method("set_shop_open"):
			scoreboard.call("set_shop_open", false)
	else:
		add_child(shop_panel)

	set_process_unhandled_input(true)
	refresh_list()

func _find_node_by_name(root: Node, target: String) -> Node:
	if root == null:
		return null
	if root.name == target:
		return root
	for child in root.get_children():
		if child is Node:
			var found := _find_node_by_name(child as Node, target)
			if found != null:
				return found
	return null
	
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		last_mouse_pos = event.position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		# While shop is open, block gameplay clicks
		if is_open:
			return

	# Tab toggles shop
	if event is InputEventKey and event.pressed and int(event.unicode) == 9:
		toggle_shop()



func toggle_shop() -> void:
	is_open = !is_open

	if is_open:
		# Capture the scoreboard's original clickable area
		if scoreboard != null and scoreboard.panel_root != null:
			scoreboard_open_rect = scoreboard.panel_root.get_global_rect()
	else:
		# Closing shop normally
		pass

	if shop_panel != null:
		shop_panel.visible = is_open

	if scoreboard != null and scoreboard.has_method("set_shop_open"):
		scoreboard.call("set_shop_open", is_open)

func open_shop() -> void:
	is_open = true

	# Capture the scoreboard's original clickable area BEFORE it expands
	if scoreboard != null and scoreboard.panel_root != null:
		scoreboard_open_rect = scoreboard.panel_root.get_global_rect()

	if shop_panel != null:
		shop_panel.visible = true

	if scoreboard != null and scoreboard.has_method("set_shop_open"):
		scoreboard.call("set_shop_open", true)


func close_shop() -> void:
	is_open = false

	if shop_panel != null:
		shop_panel.visible = false

	if scoreboard != null and scoreboard.has_method("set_shop_open"):
		scoreboard.call("set_shop_open", false)


func _on_scores_changed() -> void:
	if suppress_score_refresh:
		return
	refresh_list()

func _build_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.12, 0.72)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.26, 0.28, 0.32, 0.92)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	return style

func refresh_list() -> void:
	var list := list_container
	for child in list.get_children():
		if child is Node:
			child.queue_free()

	for upgrade_data in upgrades_data:
		var this_upgrade: Dictionary = upgrade_data as Dictionary
		var sid = this_upgrade.get("id")
		var level: int = int(current_level.get(sid, 0))
		this_upgrade.set("level",level)

		var is_max_level: bool = level >= int(this_upgrade.get("max_level", 0))
		var this_target: String = String(this_upgrade.get("id",0))
		
		#Calculate Effects
		var effect_type = this_upgrade.get("effect", {}).get("type", "")
		var this_level_effect: float
		var next_level_effect: float

		if effect_type == "mult":
			this_level_effect = pow(this_upgrade.get("effect",0).get("multiplier",0),level)
			next_level_effect = pow(this_upgrade.get("effect",0).get("multiplier",0),level + 1)

		this_upgrade.set("current_value", this_level_effect)
		this_upgrade.set("next_value", next_level_effect)

		#Calculate Costs
		var cost_multiplier = this_upgrade.get("cost_multiplier",0)
		var costs: Dictionary = this_upgrade.get("cost",{}).duplicate()
		for color in costs.keys():
			costs[color] = costs[color] * pow(cost_multiplier, level)

		# Unlock rules: if cost contains secondary color and player has none, skip
		var locked: bool = false
		for raw_color_name in costs.keys():
			var color_name: String = String(raw_color_name)
			if color_name in ["orange", "green", "purple"]:
				if scoreboard != null and scoreboard.scores.get(color_name, 0) <= 0:
					locked = true
		if locked or is_max_level:
			continue

		var row: Node = upgrade_row_scene.instantiate()
		if row is Node:
			row.visible = true
			list.add_child(row)

			if row.has_method("set_data"):
				row.call("set_data", this_upgrade, costs, level)

			var can_afford: bool = scoreboard != null and scoreboard.has_cost(costs)
			if row.has_method("set_purchase_state"):
				row.call("set_purchase_state", can_afford)

			if row.has_signal("purchase_requested"):
				row.connect("purchase_requested", Callable(self, "_on_purchase_requested"))


func _on_purchase_requested(series_id: String, requested_level: int) -> void:
	var series: Dictionary = {}
	for raw_s in upgrades_data:
		var s: Dictionary = raw_s as Dictionary
		if String(s.get("id", "")) == series_id:
			series = s
			break
	if series.size() == 0:
		return

	var lvl_idx: int = int(current_level.get(series_id, 0))
	var max_level: int = series.get("max_level", 0)
	if lvl_idx >= max_level:
		push_warning("ShopManager: already at max level for=", series_id)
		return

	var costs := series.get("cost", {}).duplicate() as Dictionary
	var cost_multiplier := series.get("cost_multiplier",1.0) as float
	
	for cost in costs:
		var original_cost = costs.get(cost)
		costs.set(cost, costs.get(cost) * pow(cost_multiplier,requested_level-1))

	if scoreboard == null:
		push_warning("No scoreboard found; cannot process purchase")
		return

	var afford: bool = bool(scoreboard.has_cost(costs))

	suppress_score_refresh = true
	var spent: bool = bool(scoreboard.spend_cost(costs))
	if spent:
		if ui_click_player != null:
			ui_click_player.play()
		current_level[series_id] = lvl_idx + 1
		var effect = series.get("effect", null)
		effect.set("level",requested_level)
		effect.set("id",series.get("id"))
		if effect != null and scoreboard != null:
			scoreboard.apply_effect(effect as Dictionary)
		refresh_list()
	else:
		push_error("ShopManager: spend_cost failed for series=", series_id)

	suppress_score_refresh = false
	
func _on_scoreboard_clicked() -> void:
	if not is_open:
		open_shop()
	else:
		# Only close if the mouse is inside the original scoreboard area
		if scoreboard_open_rect.has_point(last_mouse_pos):
			close_shop()

func update_scoreboard_size():
	scoreboard_open_rect = scoreboard.panel_root.get_global_rect()
