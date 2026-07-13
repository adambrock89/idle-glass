extends CanvasLayer

@onready var upgrade_row_scene: PackedScene = preload("res://scenes/ui/upgrade_row.tscn")
var scoreboard: CanvasLayer = null

var upgrades_data: Array = []
var current_level: Dictionary = {}

var shop_panel: Control = null
var list_container: VBoxContainer = null
var ui_click_player: AudioStreamPlayer = null
var suppress_score_refresh: bool = false

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
		scoreboard.connect("shop_toggled", Callable(self, "toggle_shop"))
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

func _unhandled_input(event: InputEvent) -> void:
	# Tab doesn't have a stable Key enum across builds; check unicode 9 (tab)
	if event is InputEventKey and event.pressed and int(event.unicode) == 9:
		toggle_shop()

func toggle_shop() -> void:
	is_open = !is_open
	if shop_panel != null:
		shop_panel.visible = is_open
	if scoreboard != null and scoreboard.has_method("set_shop_open"):
		scoreboard.call("set_shop_open", is_open)

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

	for raw_series in upgrades_data:
		var series: Dictionary = raw_series as Dictionary
		var sid: String = String(series.get("id", ""))
		var levels: Array = series.get("levels", []) as Array
		var lvl_idx: int = int(current_level.get(sid, 0))
		if lvl_idx >= levels.size():
			continue

		var level_data: Dictionary = levels[lvl_idx] as Dictionary

		if bool(series.get("requires_tier_two", false)) and (scoreboard == null or not bool(scoreboard.tier_two_unlocked)):
			continue

		# Unlock rules: if cost contains secondary color and player has none, skip
		var costs: Dictionary = level_data.get("cost", {}) as Dictionary
		var locked: bool = false
		for raw_color_name in costs.keys():
			var color_name: String = String(raw_color_name)
			if color_name in ["orange", "green", "purple"]:
				if scoreboard != null and scoreboard.scores.get(color_name, 0) <= 0:
					locked = true
		if locked:
			continue

		var row: Node = upgrade_row_scene.instantiate()
		if row is Node:
			row.visible = true
			list.add_child(row)

			if row.has_method("set_data"):
				row.call("set_data", series, lvl_idx)

			var can_afford: bool = scoreboard != null and scoreboard.has_cost(costs)
			if row.has_method("set_purchase_state"):
				row.call("set_purchase_state", can_afford)

			if row.has_signal("purchase_requested"):
				row.connect("purchase_requested", Callable(self, "_on_purchase_requested"))


func _on_purchase_requested(series_id: String) -> void:
	var series: Dictionary = {}
	for raw_s in upgrades_data:
		var s: Dictionary = raw_s as Dictionary
		if String(s.get("id", "")) == series_id:
			series = s
			break
	if series.size() == 0:
		return

	var lvl_idx: int = int(current_level.get(series_id, 0))
	var levels: Array = series.get("levels", []) as Array
	if lvl_idx >= levels.size():
		print("ShopManager: already at max level for=", series_id)
		return

	var level_data: Dictionary = levels[lvl_idx] as Dictionary
	var costs: Dictionary = level_data.get("cost", {}) as Dictionary

	if scoreboard == null:
		push_warning("No scoreboard found; cannot process purchase")
		return

	var afford: bool = bool(scoreboard.has_cost(costs))
	if not afford:
		print("ShopManager: cannot afford purchase for series=", series_id)
		return

	suppress_score_refresh = true
	var spent: bool = bool(scoreboard.spend_cost(costs))
	if spent:
		if ui_click_player != null:
			ui_click_player.play()
		current_level[series_id] = lvl_idx + 1
		var effect = level_data.get("effect", null)
		if effect != null and scoreboard != null:
			scoreboard.apply_effect(effect as Dictionary)
		refresh_list()
	else:
		print("ShopManager: spend_cost failed for series=", series_id)

	suppress_score_refresh = false
