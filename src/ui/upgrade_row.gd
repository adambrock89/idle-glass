extends PanelContainer

signal purchase_requested(series_id)

const COST_COLOR_ORDER: Array[String] = ["red", "orange", "yellow", "green", "blue", "purple"]
const ROW_FILL_COLOR := Color(0.08, 0.1, 0.12, 0.15)
const ROW_STROKE_COLOR := Color(0.24, 0.26, 0.3, 0.95)
const BUY_ENABLED_COLOR := Color(0.17, 0.19, 0.22, 0.98)
const BUY_HOVER_COLOR := Color(0.2, 0.22, 0.25, 1.0)
const BUY_PRESSED_COLOR := Color(0.15, 0.17, 0.2, 1.0)
const BUY_DISABLED_COLOR := Color(0.12, 0.13, 0.15, 0.98)
const BUY_ENABLED_BORDER_COLOR := Color(0.44, 0.68, 0.5, 0.95)
const BUY_DISABLED_BORDER_COLOR := Color(0.2, 0.22, 0.25, 0.95)

var series_id: String
var level_index: int = 0
var color_profile: ColorProfile = ColorProfile.new()
var tooltip_description_text: String = ""
var tooltip_values_text: String = ""
var is_hovered: bool = false

var hover_tooltip: PanelContainer = null
var hover_tooltip_label: Label = null
var buy_cost_overlay: HBoxContainer = null

var cost_color_map: Dictionary = {
    "red": ColorProfile.ColorName.RED,
    "orange": ColorProfile.ColorName.ORANGE,
    "yellow": ColorProfile.ColorName.YELLOW,
    "green": ColorProfile.ColorName.GREEN,
    "blue": ColorProfile.ColorName.BLUE,
    "purple": ColorProfile.ColorName.PURPLE
}

@onready var buy_button: BaseButton = get_node("Margin/Content/BuyCol/Buy") as BaseButton
@onready var name_label: Label = get_node("Margin/Content/Name") as Label
@onready var level_label: Label = get_node("Margin/Content/MetaCol/Level") as Label
@onready var effect_label: Label = get_node("Margin/Content/MetaCol/Effect") as Label

func set_data(series: Dictionary, level_idx: int) -> void:
    series_id = String(series.get("id", ""))
    level_index = level_idx

    var levels: Array = series.get("levels", []) as Array
    if level_index < 0 or level_index >= levels.size():
        return

    var level_data: Dictionary = levels[level_index] as Dictionary
    var name_text: String = _normalize_display_text(String(series.get("name", "")))
    var description_text: String = _normalize_display_text(String(series.get("description", "")))
    var current_value_text: String = _get_current_value_text(levels, level_index)
    var next_value_text: String = _get_next_value_text(level_data)

    name_label.text = name_text
    level_label.text = "Level %d" % level_index
    effect_label.text = current_value_text
    tooltip_text = ""
    tooltip_description_text = description_text
    tooltip_values_text = "(%s -> %s)" % [current_value_text, next_value_text]
    _update_hover_tooltip_text()

    # Keep text legible on dark shop panel.
    name_label.modulate = Color(1, 1, 1)
    level_label.modulate = Color(0.72, 0.92, 1)
    effect_label.modulate = Color(1, 1, 1)

    var costs: Dictionary = level_data.get("cost", {}) as Dictionary
    _update_button_cost_label(costs)

func set_purchase_state(can_afford: bool) -> void:
    if buy_button == null:
        return
    buy_button.disabled = not can_afford
    buy_button.modulate = Color(1, 1, 1, 1)

func _update_button_cost_label(costs: Dictionary) -> void:
    var ordered_colors: Array[String] = []
    for color_name in COST_COLOR_ORDER:
        if costs.has(color_name):
            ordered_colors.append(color_name)

    for raw_color_name in costs.keys():
        var color_name: String = String(raw_color_name)
        if not ordered_colors.has(color_name):
            ordered_colors.append(color_name)

    if buy_button == null:
        return

    if buy_cost_overlay == null:
        _setup_buy_cost_overlay()

    for child in buy_cost_overlay.get_children():
        child.queue_free()

    if ordered_colors.is_empty():
        buy_button.text = ""
        var free_label := Label.new()
        free_label.text = "Free"
        free_label.modulate = Color(0.84, 0.92, 0.84, 1.0)
        free_label.add_theme_font_size_override("font_size", 14)
        buy_cost_overlay.add_child(free_label)
        return

    buy_button.text = ""
    for color_name in ordered_colors:
        var amount: int = int(costs.get(color_name, 0))
        var cost_chunk := Label.new()
        cost_chunk.text = "\u25CF%d" % amount
        cost_chunk.modulate = _get_cost_color(color_name)
        cost_chunk.add_theme_font_size_override("font_size", 13)
        cost_chunk.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        buy_cost_overlay.add_child(cost_chunk)

func _get_cost_color(color_name: String) -> Color:
    var enum_value: int = int(cost_color_map.get(color_name, ColorProfile.ColorName.RED))
    return color_profile.rgb_values[enum_value]

func _on_Buy_pressed() -> void:
    emit_signal("purchase_requested", series_id)

func _ready() -> void:
    _apply_row_style()
    _apply_button_styles()
    _setup_buy_cost_overlay()
    _setup_hover_tooltip()

    if buy_button != null:
        buy_button.connect("pressed", Callable(self, "_on_Buy_pressed"))

    mouse_entered.connect(_on_row_mouse_entered)
    mouse_exited.connect(_on_row_mouse_exited)

func _process(_delta: float) -> void:
    if is_hovered and hover_tooltip != null and hover_tooltip.visible:
        _position_hover_tooltip()

func _apply_row_style() -> void:
    var row_style := StyleBoxFlat.new()
    row_style.bg_color = ROW_FILL_COLOR
    row_style.border_width_left = 1
    row_style.border_width_top = 1
    row_style.border_width_right = 1
    row_style.border_width_bottom = 1
    row_style.border_color = ROW_STROKE_COLOR
    row_style.corner_radius_top_left = 12
    row_style.corner_radius_top_right = 12
    row_style.corner_radius_bottom_right = 12
    row_style.corner_radius_bottom_left = 12
    add_theme_stylebox_override("panel", row_style)

func _apply_button_styles() -> void:
    if buy_button == null:
        return

    buy_button.add_theme_stylebox_override("normal", _make_button_style(BUY_ENABLED_COLOR, BUY_ENABLED_BORDER_COLOR))
    buy_button.add_theme_stylebox_override("hover", _make_button_style(BUY_HOVER_COLOR, BUY_ENABLED_BORDER_COLOR))
    buy_button.add_theme_stylebox_override("pressed", _make_button_style(BUY_PRESSED_COLOR, BUY_ENABLED_BORDER_COLOR))
    buy_button.add_theme_stylebox_override("focus", _make_button_style(BUY_HOVER_COLOR, BUY_ENABLED_BORDER_COLOR))
    buy_button.add_theme_stylebox_override("disabled", _make_button_style(BUY_DISABLED_COLOR, BUY_DISABLED_BORDER_COLOR))
    buy_button.add_theme_color_override("font_color", Color(0.12, 0.14, 0.16))
    buy_button.add_theme_color_override("font_hover_color", Color(0.1, 0.12, 0.14))
    buy_button.add_theme_color_override("font_pressed_color", Color(0.09, 0.11, 0.13))
    buy_button.add_theme_color_override("font_disabled_color", Color(0.46, 0.49, 0.54))
    buy_button.add_theme_font_size_override("font_size", 15)

func _make_button_style(color: Color, border_color: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_width_left = 1
    style.border_width_top = 1
    style.border_width_right = 1
    style.border_width_bottom = 1
    style.border_color = border_color
    style.corner_radius_top_left = 10
    style.corner_radius_top_right = 10
    style.corner_radius_bottom_right = 10
    style.corner_radius_bottom_left = 10
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 12
    style.content_margin_bottom = 8
    return style

func _setup_buy_cost_overlay() -> void:
    if buy_button == null:
        return
    if buy_cost_overlay != null:
        return

    buy_cost_overlay = HBoxContainer.new()
    buy_cost_overlay.name = "CostOverlay"
    buy_cost_overlay.anchor_left = 0.0
    buy_cost_overlay.anchor_top = 0.0
    buy_cost_overlay.anchor_right = 1.0
    buy_cost_overlay.anchor_bottom = 1.0
    buy_cost_overlay.offset_left = 8.0
    buy_cost_overlay.offset_top = 8.0
    buy_cost_overlay.offset_right = -8.0
    buy_cost_overlay.offset_bottom = -8.0
    buy_cost_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    buy_cost_overlay.alignment = BoxContainer.ALIGNMENT_CENTER
    buy_cost_overlay.add_theme_constant_override("separation", 6)
    buy_button.add_child(buy_cost_overlay)

func _setup_hover_tooltip() -> void:
    hover_tooltip = PanelContainer.new()
    hover_tooltip.visible = false
    hover_tooltip.top_level = true
    hover_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(hover_tooltip)

    var tooltip_style := StyleBoxFlat.new()
    tooltip_style.bg_color = Color(0.07, 0.08, 0.1, 0.96)
    tooltip_style.border_width_left = 1
    tooltip_style.border_width_top = 1
    tooltip_style.border_width_right = 1
    tooltip_style.border_width_bottom = 1
    tooltip_style.border_color = Color(0.28, 0.32, 0.37, 0.98)
    tooltip_style.corner_radius_top_left = 8
    tooltip_style.corner_radius_top_right = 8
    tooltip_style.corner_radius_bottom_right = 8
    tooltip_style.corner_radius_bottom_left = 8
    hover_tooltip.add_theme_stylebox_override("panel", tooltip_style)

    var tooltip_margin := MarginContainer.new()
    tooltip_margin.add_theme_constant_override("margin_left", 10)
    tooltip_margin.add_theme_constant_override("margin_top", 8)
    tooltip_margin.add_theme_constant_override("margin_right", 10)
    tooltip_margin.add_theme_constant_override("margin_bottom", 8)
    hover_tooltip.add_child(tooltip_margin)

    hover_tooltip_label = Label.new()
    hover_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_OFF
    hover_tooltip_label.add_theme_font_size_override("font_size", 13)
    hover_tooltip_label.modulate = Color(0.94, 0.96, 1.0)
    tooltip_margin.add_child(hover_tooltip_label)

func _update_hover_tooltip_text() -> void:
    if hover_tooltip_label != null:
        hover_tooltip_label.text = "%s\n%s" % [tooltip_description_text, tooltip_values_text]

func _on_row_mouse_entered() -> void:
    is_hovered = true
    if hover_tooltip != null:
        _update_hover_tooltip_text()
        hover_tooltip.visible = true
        _position_hover_tooltip()

func _on_row_mouse_exited() -> void:
    is_hovered = false
    if hover_tooltip != null:
        hover_tooltip.visible = false

func _position_hover_tooltip() -> void:
    if hover_tooltip == null:
        return

    var viewport_size: Vector2 = get_viewport_rect().size
    var mouse_pos: Vector2 = get_viewport().get_mouse_position()
    var offset := Vector2(16.0, 2.0)
    hover_tooltip.reset_size()
    var tooltip_size: Vector2 = hover_tooltip.size
    var desired := mouse_pos + offset

    if desired.x + tooltip_size.x > viewport_size.x - 8.0:
        desired.x = viewport_size.x - tooltip_size.x - 8.0
    if desired.y + tooltip_size.y > viewport_size.y - 8.0:
        desired.y = mouse_pos.y - tooltip_size.y - 12.0

    hover_tooltip.position = desired

func _normalize_display_text(text: String) -> String:
    return text.replace("Strength", "Area").replace("strength", "area")

func _get_current_value_text(levels: Array, next_level_index: int) -> String:
    if next_level_index > 0 and next_level_index - 1 < levels.size():
        var current_level_data: Dictionary = levels[next_level_index - 1] as Dictionary
        return _extract_value_text(_normalize_display_text(String(current_level_data.get("effect_text", "-"))))

    if next_level_index < levels.size():
        var next_level_data: Dictionary = levels[next_level_index] as Dictionary
        return _get_base_value_text(next_level_data.get("effect", {}) as Dictionary)

    return "-"

func _get_next_value_text(level_data: Dictionary) -> String:
    return _extract_value_text(_normalize_display_text(String(level_data.get("effect_text", "-"))))

func _get_base_value_text(effect: Dictionary) -> String:
    var effect_type: String = String(effect.get("type", ""))
    var target: String = String(effect.get("target", ""))

    match effect_type:
        "mult":
            if target.begins_with("metal_") and target.ends_with("_value"):
                if target.contains("silver"):
                    return "x10"
                if target.contains("gold"):
                    return "x100"
                if target.contains("crystal"):
                    return "x1000"
                return "x1"
            return "x1"
        "set":
            if target.begins_with("strength_"): 
                return "6.5"
            match target:
                "spawn_speed":
                    return "x1"
                "hatch_speed":
                    return "x1"
                "platform_length":
                    return "200"
                "max_tier":
                    return "1"
                "pull_strength_multiplier":
                    return "x1"
                "grab_radius":
                    return "0"
                "modifier_rainbow_mult":
                    return "x1"
                _:
                    return "0"
        "set_weights":
            return "1 / 0 / 0 / 0"
        "add_percent":
            if target == "modifier_lots_shapes_per_shape":
                return "+0% per extra shape"
            if target == "modifier_all_same_color_mult":
                return "+0 per extra match"
            if target == "modifier_rainbow_mult":
                return "x1"
        "multi":
            return "1"

    return "-"

func _extract_value_text(effect_text: String) -> String:
    var text: String = effect_text.strip_edges()
    for index in range(text.length()):
        var text_char := text.substr(index, 1)
        var code := text.unicode_at(index)
        if code >= 48 and code <= 57:
            return text.substr(index)
        if text_char == "+" or text_char == "(":
            return text.substr(index)
        if text_char.to_lower() == "x" and index + 1 < text.length():
            var next_code := text.unicode_at(index + 1)
            if next_code >= 48 and next_code <= 57:
                return text.substr(index)
    return text
