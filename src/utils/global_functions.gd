extends Node

class_name GlobalFunctions

var notations: PackedStringArray = ["","K","M","B","T","q","Q","s","S","O","N","D"]

func format_float_for_notation(raw_float: float) -> String:
	if(raw_float == 0.0):
		return "0"
	var multiple_of_thousands := int(floor(log(raw_float) / log(1000)))
	
	var calculated_value := raw_float / pow(1000, multiple_of_thousands)
	var notation = notations[multiple_of_thousands]
	return "%.2f %s" % [calculated_value,notation]
