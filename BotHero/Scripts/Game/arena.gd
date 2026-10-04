class_name Arena
extends Control

# Side-view playfield: the hero walks along the bottom row, the rows above
# are headroom for jumps. Nothing here is draggable - it only plays back
# commands handed to execute().

signal goal_reached

const CELL := 16
const STEP_TIME := 0.3
const JUMP_DISTANCE := 2

@export var grid_size := Vector2i(12, 5)
@export var hero_start_x: int = 0
@export var goal_x: int = 9
@export var wall_xs: Array[int] = [3]
@export var enemy_xs: Array[int] = [6]

var hero_x: int = 0

var _hero: ColorRect
var _walls: Dictionary = {}    # x -> ColorRect
var _enemies: Dictionary = {}  # x -> ColorRect, hidden once killed

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(grid_size * CELL)

	_make_block(goal_x, Color(0.95, 0.8, 0.2))
	for x in wall_xs:
		_walls[x] = _make_block(x, Color(0.5, 0.5, 0.55))
	for x in enemy_xs:
		_enemies[x] = _make_block(x, Color(0.85, 0.25, 0.25))
	_hero = _make_block(hero_start_x, Color(0.3, 0.8, 0.5))
	reset()

func _draw() -> void:
	for y in grid_size.y:
		for x in grid_size.x:
			var shade := 0.16 if (x + y) % 2 == 0 else 0.19
			var color := Color(shade, shade, shade + 0.04)
			if y == grid_size.y - 1:
				color = color.lightened(0.1)
			draw_rect(Rect2(x * CELL, y * CELL, CELL, CELL), color)

func reset() -> void:
	hero_x = hero_start_x
	_hero.position = _cell_pos(hero_x)
	for enemy in _enemies.values():
		enemy.visible = true

func is_goal_reached() -> bool:
	return hero_x == goal_x

func execute(action: CommandData.Action) -> void:
	match action:
		CommandData.Action.FORWARD:
			await _walk(1)
		CommandData.Action.BACK:
			await _walk(-1)
		CommandData.Action.JUMP:
			await _jump()
		CommandData.Action.ATTACK:
			await _attack()
	if is_goal_reached():
		goal_reached.emit()

func _walk(dir: int) -> void:
	var target := hero_x + dir
	if _is_blocked(target):
		await _bump(dir)
		return
	hero_x = target
	var tween := create_tween()
	tween.tween_property(_hero, "position", _cell_pos(hero_x), STEP_TIME)
	await tween.finished

# Leaps over whatever is in between; if the landing cell is taken it hops in place.
func _jump() -> void:
	var target := hero_x + JUMP_DISTANCE
	var start := _hero.position
	if not _is_blocked(target):
		hero_x = target
	var end := _cell_pos(hero_x)
	var tween := create_tween()
	tween.tween_method(func(t: float): _hero.position = start.lerp(end, t) - Vector2(0, sin(t * PI) * CELL), 0.0, 1.0, STEP_TIME)
	await tween.finished

func _attack() -> void:
	var target := hero_x + 1
	var start_x := _hero.position.x
	var tween := create_tween()
	tween.tween_property(_hero, "position:x", start_x + 4, STEP_TIME * 0.4)
	if _is_enemy_at(target):
		tween.tween_callback(func(): _enemies[target].visible = false)
	tween.tween_property(_hero, "position:x", start_x, STEP_TIME * 0.6)
	await tween.finished

func _bump(dir: int) -> void:
	var start_x := _hero.position.x
	var tween := create_tween()
	tween.tween_property(_hero, "position:x", start_x + dir * 4, STEP_TIME * 0.5)
	tween.tween_property(_hero, "position:x", start_x, STEP_TIME * 0.5)
	await tween.finished

func _is_enemy_at(x: int) -> bool:
	return _enemies.has(x) and _enemies[x].visible

func _is_blocked(x: int) -> bool:
	return x < 0 or x >= grid_size.x or _walls.has(x) or _is_enemy_at(x)

func _cell_pos(x: int) -> Vector2:
	return Vector2(x * CELL + 1, (grid_size.y - 1) * CELL + 1)

func _make_block(x: int, color: Color) -> ColorRect:
	var block := ColorRect.new()
	block.color = color
	block.size = Vector2(CELL - 2, CELL - 2)
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.position = _cell_pos(x)
	add_child(block)
	return block
