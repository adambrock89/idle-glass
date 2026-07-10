extends HBoxContainer

signal purchase_requested(series_id)

const COST_COLOR_ORDER: Array[String] = ["red", "orange", "yellow", "green", "blue", "purple"]

var series_id: String
var level_index: int = 0
var color_profile: ColorProfile = ColorProfile.new()

var cost_color_map: Dictionary = {
    "red": ColorProfile.ColorName.RED,
    "orange": ColorProfile.ColorName.ORANGE,
    "yellow": ColorProfile.ColorName.YELLOW,
    "green": ColorProfile.ColorName.GREEN,
    "blue": ColorProfile.ColorName.BLUE,
    "purple": ColorProfile.ColorName.PURPLE
}

@onready var name_label: Label = get_node("LeftCol/Name") as Label
@onready var description_label: Label = get_node("LeftCol/Description") as Label
@onready var level_label: Label = get_node("MidCol/Level") as Label
@onready var effect_label: Label = get_node("MidCol/Effect") as Label
@onready var cost_row: HBoxContainer = get_node("RightCol/CostRow") as HBoxContainer
@onready var buy_button: BaseButton = get_node("RightCol/Buy") as BaseButton

func set_data(series: Dictionary, level_idx: int) -> void:
    series_id = String(series.get("id", ""))
    level_index = level_idx

    var levels: Array = series.get("levels", []) as Array
    if level_index < 0 or level_index >= levels.size():
        return

    var level_data: Dictionary = levels[level_index] as Dictionary

    name_label.text = String(series.get("name", ""))
    description_label.text = String(series.get("description", ""))
    level_label.text = "Level %s" % str(level_data.get("level", level_idx + 1))
    effect_label.text = String(level_data.get("effect_text", ""))

    # Keep text legible on dark shop panel.
    name_label.modulate = Color(1, 1, 1)
    description_label.modulate = Color(0.86, 0.88, 0.92)
    level_label.modulate = Color(0.72, 0.92, 1)
    effect_label.modulate = Color(1, 1, 1)

    _render_costs(level_data.get("cost", {}) as Dictionary)

func _render_costs(costs: Dictionary) -> void:
    for child in cost_row.get_children():
        child.queue_free()

    var ordered_colors: Array[String] = []
    for color_name in COST_COLOR_ORDER:
        if costs.has(color_name):
            ordered_colors.append(color_name)

    for raw_color_name in costs.keys():
        var color_name: String = String(raw_color_name)
        if not ordered_colors.has(color_name):
            ordered_colors.append(color_name)

    if ordered_colors.is_empty():
        var free_label := Label.new()
        free_label.text = "Free"
        free_label.modulate = Color(0.8, 0.9, 0.8)
        cost_row.add_child(free_label)
        return

    for color_name in ordered_colors:
        var amount: int = int(costs.get(color_name, 0))
        var cost_chunk := Label.new()
        cost_chunk.text = "\u25CF%d" % amount
        cost_chunk.modulate = _get_cost_color(color_name)
        cost_chunk.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        cost_chunk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        cost_row.add_child(cost_chunk)

func _get_cost_color(color_name: String) -> Color:
    var enum_value: int = int(cost_color_map.get(color_name, ColorProfile.ColorName.RED))
    return color_profile.rgb_values[enum_value]

func _on_Buy_pressed() -> void:
    emit_signal("purchase_requested", series_id)

func _ready() -> void:
    if buy_button != null:
        buy_button.connect("pressed", Callable(self, "_on_Buy_pressed"))
