class_name ColorProfile
extends Resource

enum ColorName {RED,RED_ORANGE,ORANGE,ORANGE_YELLOW,YELLOW,YELLOW_GREEN,GREEN,GREEN_BLUE,BLUE,BLUE_PURPLE,PURPLE, PURPLE_RED}

var rgb_values: Array[Color] = [
	Color8(198,88,88), #RED
	Color8(184,100,88), #RED-ORANGE
	Color8(170,112,88), #ORANGE
	Color8(184,154,106), #ORANGE-YELLOW
	Color8(198,196,124), #YELLOW
	Color8(156,187,115), #YELLOW-GREEN
	Color8(112,178,106), #GREEN
	Color8(101,158,138), #GREEN-BLUE
	Color8(90,138,170), #BLUE
	Color8(101,114,170), #BLUE-PURPLE
	Color8(112,88,170), #PURPLE
	Color8(156,88,129), #PURPLE-BLUE
]

@export var color_name: ColorName
@export var min_strength: float
@export var max_strength: float

func get_color_code() -> Color:
	return rgb_values[color_name]
