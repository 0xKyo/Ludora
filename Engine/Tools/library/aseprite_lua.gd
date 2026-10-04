@tool
extends RefCounted

# Bridge to run Aseprite Lua scripts from Godot editor tools. Not an
# EditorScript itself: preload it from one and call run().
#
#   const AsepriteLua = preload("res://_engine/Tools/library/aseprite_lua.gd")
#
#   var result := AsepriteLua.run(
#       "res://_engine/Tools/split_assets.lua",
#       {"source_dir": "res://Art/Scenes", "out_dir": "res://Art/Source"})
#   print(result.output)
#   if not result.ok:
#       push_error("Aseprite script failed")
#
# In Lua the params arrive as app.params["source_dir"]; whatever the script
# prints to stdout comes back in result.output, and error() in the script makes
# result.ok false. res:// paths (script, sprite, param values) are globalized.

const ASEPRITE_EXE := "E:/SteamLibrary/steamapps/common/Aseprite/Aseprite.exe"

# Runs `aseprite -b [sprite_path] --script-param k=v... --script script_path [post_args...]`.
# post_args are extra CLI flags that must run after the script (e.g. --save-as).
# Returns {ok: bool, exit_code: int, output: String} (stdout + stderr merged).
static func run(
	script_path: String,
	params: Dictionary = {},
	sprite_path: String = "",
	post_args: PackedStringArray = PackedStringArray()
) -> Dictionary:
	var args := PackedStringArray(["-b"])

	if not sprite_path.is_empty():
		args.append(ProjectSettings.globalize_path(sprite_path))

	for key in params:
		args.append_array(["--script-param", "%s=%s" % [key, _param_value(params[key])]])

	args.append_array(["--script", ProjectSettings.globalize_path(script_path)])
	args.append_array(post_args)

	var output: Array = []
	var exit_code := OS.execute(ASEPRITE_EXE, args, output, true)

	return {
		"ok": exit_code == 0,
		"exit_code": exit_code,
		"output": "".join(output).strip_edges(),
	}

static func _param_value(value) -> String:
	var text := str(value)
	return ProjectSettings.globalize_path(text) if text.begins_with("res://") else text
