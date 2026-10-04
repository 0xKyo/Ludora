class_name CommandSlot
extends PanelContainer

const SLOT_SIZE := Vector2(20, 20)

# Source slots (the palette) are infinite and drag-only; program slots hold
# one command and accept drops.
@export var is_source: bool = false

var command: CommandData:
	set(value):
		command = value
		_refresh()

# Set while the program is running, so it can't be edited mid-execution.
var locked: bool = false

var _label: Label
var _highlighted: bool = false

func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	_refresh()

func set_highlight(on: bool) -> void:
	_highlighted = on
	_refresh()

func _refresh() -> void:
	if _label == null:
		return
	var style := StyleBoxFlat.new()
	style.bg_color = command.color if command else Color(0.12, 0.12, 0.16)
	style.set_border_width_all(1)
	style.border_color = Color.WHITE if _highlighted else style.bg_color.lightened(0.4)
	add_theme_stylebox_override("panel", style)
	_label.text = command.symbol if command else ""
	tooltip_text = command.display_name if command else ""

# Dragging a program slot's command out of it clears the slot, so dropping it
# anywhere that isn't another slot deletes it.
func _get_drag_data(_at_position: Vector2) -> Variant:
	if locked or command == null:
		return null

	var dragged := command
	var preview := CommandSlot.new()
	preview.command = dragged
	preview.modulate.a = 0.8
	set_drag_preview(preview)

	if not is_source:
		command = null
	return {"command": dragged}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return not is_source and not locked and data is Dictionary and data.get("command") is CommandData

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	command = data["command"]
