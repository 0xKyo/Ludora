class_name CommandPalette
extends HBoxContainer

@export var commands: Array[CommandData] = []

func _ready() -> void:
	for command in commands:
		var slot := CommandSlot.new()
		slot.is_source = true
		add_child(slot)
		slot.command = command
