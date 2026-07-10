extends CanvasLayer

const SHOP_TOP_PADDING: float = 56.0

@onready var upgrade_row_scene: PackedScene = preload("res://scenes/ui/upgrade_row.tscn")
var scoreboard: CanvasLayer = null

var upgrades_data: Array = []
var current_level: Dictionary = {}

var shop_panel: Panel = null
var list_container: VBoxContainer = null

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
    shop_panel = Panel.new()
    shop_panel.name = "ShopPanel"
    shop_panel.anchor_right = 1.0
    shop_panel.anchor_left = 0.68
    shop_panel.anchor_top = 0.0
    shop_panel.anchor_bottom = 1.0
    shop_panel.offset_top = SHOP_TOP_PADDING
    # no explicit margin needed when anchors are used; set a sensible minimum width and start hidden
    shop_panel.custom_minimum_size = Vector2(200, 0)
    shop_panel.visible = false
    add_child(shop_panel)

    var scroll: ScrollContainer = ScrollContainer.new()
    scroll.name = "Scroll"
    scroll.anchor_left = 0.0
    scroll.anchor_top = 0.0
    scroll.anchor_right = 1.0
    scroll.anchor_bottom = 1.0
    shop_panel.add_child(scroll)

    list_container = VBoxContainer.new()
    list_container.name = "List"
    list_container.anchor_left = 0.0
    list_container.anchor_top = 0.0
    list_container.anchor_right = 1.0
    list_container.anchor_bottom = 1.0
    list_container.add_theme_constant_override("separation", 6)
    scroll.add_child(list_container)

    # try to find scoreboard and connect: prefer current scene, fallback to root
    var current_scene: Node = get_tree().get_current_scene()
    if current_scene != null:
        scoreboard = _find_node_by_name(current_scene, "Scoreboard") as CanvasLayer
    if scoreboard == null:
        scoreboard = _find_node_by_name(get_tree().get_root(), "Scoreboard") as CanvasLayer

    if scoreboard != null:
        scoreboard.connect("shop_toggled", Callable(self, "toggle_shop"))

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

func refresh_list() -> void:
    var list := list_container
    var added_count: int = 0
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

            # Direct button hookup: keep a single purchase path to avoid double-triggering.
            var buy_button: BaseButton = row.find_child("Buy", true, false) as BaseButton
            if buy_button != null:
                buy_button.pressed.connect(Callable(self, "_on_purchase_requested").bind(sid))
                buy_button.disabled = false

            added_count += 1


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

    var spent: bool = bool(scoreboard.spend_cost(costs))
    if spent:
        current_level[series_id] = lvl_idx + 1
        var effect = level_data.get("effect", null)
        if effect != null and scoreboard != null:
            scoreboard.apply_effect(effect as Dictionary)
        refresh_list()
    else:
        print("ShopManager: spend_cost failed for series=", series_id)
