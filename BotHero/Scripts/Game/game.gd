extends Control

@onready var _arena: Arena = %Arena
@onready var _program: ProgramBar = %ProgramBar
@onready var _status: Label = %Status
@onready var _run_button: Button = %RunButton
@onready var _reset_button: Button = %ResetButton

var _running: bool = false
var _stop_requested: bool = false

func _ready() -> void:
	_run_button.pressed.connect(_on_run_pressed)
	_reset_button.pressed.connect(_on_reset_pressed)

func _on_run_pressed() -> void:
	if not _running:
		_run()

# Mid-run this only requests a stop - the current step finishes first.
func _on_reset_pressed() -> void:
	if _running:
		_stop_requested = true
	else:
		_arena.reset()
		_status.text = ""

func _run() -> void:
	_running = true
	_stop_requested = false
	_arena.reset()
	_program.locked = true
	_run_button.disabled = true
	_status.text = "Ejecutando..."

	var reached := false
	var steps := _program.get_program()
	for i in steps.size():
		if _stop_requested:
			break
		_program.highlight(i)
		if steps[i] == null:
			continue
		await _arena.execute(steps[i].action)
		if _arena.is_goal_reached():
			reached = true
			break

	_program.clear_highlight()
	_program.locked = false
	_run_button.disabled = false
	_running = false

	if _stop_requested:
		_arena.reset()
		_status.text = ""
	else:
		_status.text = "¡Meta alcanzada!" if reached else "No llegó a la meta"
