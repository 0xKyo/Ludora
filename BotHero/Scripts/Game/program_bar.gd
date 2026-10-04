class_name ProgramBar
extends HBoxContainer

# One row, slot_count columns: the commands the hero will execute, left to right.
@export var slot_count: int = 10

var locked: bool = false:
	set(value):
		locked = value
		for slot in _slots:
			slot.locked = value

var _slots: Array[CommandSlot] = []

func _ready() -> void:
	for i in slot_count:
		var slot := CommandSlot.new()
		add_child(slot)
		_slots.append(slot)

# One entry per slot, null where a slot is empty.
func get_program() -> Array[CommandData]:
	var program: Array[CommandData] = []
	for slot in _slots:
		program.append(slot.command)
	return program

func highlight(index: int) -> void:
	clear_highlight()
	_slots[index].set_highlight(true)

func clear_highlight() -> void:
	for slot in _slots:
		slot.set_highlight(false)
