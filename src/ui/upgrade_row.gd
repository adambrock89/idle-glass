extends HBoxContainer

signal purchase_requested(series_id)

var series_id: String
var level_index: int = 0

@onready var name_label: Label = get_node("LeftCol/Name") as Label
@onready var description_label: Label = get_node("LeftCol/Description") as Label
@onready var level_label: Label = get_node("MidCol/Level") as Label
@onready var effect_label: Label = get_node("MidCol/Effect") as Label
@onready var cost_label: Label = get_node("RightCol/Cost") as Label
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
    cost_label.modulate = Color(1, 0.95, 0.72)

    var cost_strs: Array[String] = []
    var costs: Dictionary = level_data.get("cost", {}) as Dictionary
    for raw_color_name in costs.keys():
        var color_name: String = String(raw_color_name)
        var amount: int = int(costs[color_name])
        cost_strs.append("%d %s" % [amount, color_name.capitalize()])
    cost_label.text = "Cost: " + ", ".join(cost_strs)

func _on_Buy_pressed() -> void:
    emit_signal("purchase_requested", series_id)

func _ready() -> void:
    if buy_button != null:
        buy_button.connect("pressed", Callable(self, "_on_Buy_pressed"))
