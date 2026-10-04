class_name Settings
extends Resource

@export var volume : float
# Empty means "use the OS language".
@export var locale : String = ""

func _init():
	volume = 0.1
