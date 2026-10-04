class_name CommandData
extends Resource

enum Action { FORWARD, BACK, JUMP, ATTACK }

@export var action: Action = Action.FORWARD
@export var display_name: String = ""
# One or two characters drawn on the block - no art for commands yet.
@export var symbol: String = ""
@export var color: Color = Color.WHITE
