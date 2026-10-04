@tool
extends EditorScript

# Launcher for split_assets.lua, which does all the Aseprite work: splits
# every Scene_*.aseprite composite mockup directly under SOURCE_DIR into
# individual per-object .aseprite files in a same-named subfolder (e.g.
# Scene_LivingRoom.aseprite's layers go to SOURCE_DIR/LivingRoom/), and pulls
# back any of those individual files that were polished more recently than
# the scene itself. See split_assets.lua's header comment for the full
# layout and merge rules.

const AsepriteLua = preload("res://_engine/Tools/library/aseprite_lua.gd")

const SCRIPT := "res://_engine/Tools/split_assets.lua"

const SOURCE_DIR := "res://Art/Source" # can have .gdignore

func _run() -> void:
	var result := AsepriteLua.run(SCRIPT, {
		"source_dir": SOURCE_DIR,
	})

	if not result.ok:
		push_error("split_assets.lua failed:\n" + result.output)
		return

	print(result.output)
	EditorInterface.get_resource_filesystem().scan()
