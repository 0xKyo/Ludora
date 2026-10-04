@tool
extends EditorScript

# Aseprite sources -> sprite resources, in one run.
#
# 1. create_atlas.lua (Aseprite, batch mode) packs every frame under SOURCE_DIR
#    into OUT_ATLAS and writes LAYOUT_FILE (each frame's position/duration/
#    tags). It skips the work when the sources didn't change - that's the slow
#    part of the pipeline.
# 2. If the atlas PNG changed, it's reimported synchronously so the resources
#    below can reference it right away (no waiting on the import progress bar).
# 3. One .tres per asset is written to OUT_SPRITES_DIR: a plain AtlasTexture
#    for single-frame (static) assets, or a SpriteFrames (one animation per
#    Aseprite tag) for multi-frame ones. Always regenerated unconditionally,
#    since a repacked atlas can shift every asset's position, not just the
#    changed one.
#
# To split scene mockups into per-layer sources first, run split_assets.gd.

const AsepriteLua = preload("res://_engine/Tools/library/aseprite_lua.gd")

const ATLAS_SCRIPT := "res://_engine/Tools/create_atlas.lua"

const SOURCE_DIR := "res://Art/Source" # can have .gdignore
const OUT_ATLAS := "res://Assets/atlas.png" # should NOT have .gdignore
const LAYOUT_FILE := "res://Art/generated/atlas_layout.json"
const OUT_SPRITES_DIR := "res://Resources/Sprites" # should NOT have .gdignore

const MAX_WIDTH := 1024
const PADDING := 0

func _run() -> void:
	var atlas_time_before := FileAccess.get_modified_time(OUT_ATLAS)

	var result := AsepriteLua.run(ATLAS_SCRIPT, {
		"source_dir": SOURCE_DIR,
		"out_atlas": OUT_ATLAS,
		"layout_file": LAYOUT_FILE,
		"max_width": MAX_WIDTH,
		"padding": PADDING,
	})

	if not result.ok:
		push_error("create_atlas.lua failed:\n" + result.output)
		return

	print(result.output)

	if FileAccess.get_modified_time(OUT_ATLAS) != atlas_time_before:
		_reimport_atlas()

	var layout := _load_layout()
	if layout.is_empty():
		return

	var atlas_texture := ResourceLoader.load(OUT_ATLAS, "Texture2D", ResourceLoader.CACHE_MODE_REPLACE) as Texture2D
	if atlas_texture == null:
		push_error("Could not load %s." % OUT_ATLAS)
		return

	if atlas_texture.get_width() != int(layout["atlas_width"]) or atlas_texture.get_height() != int(layout["atlas_height"]):
		push_error("%s's imported size doesn't match %s." % [OUT_ATLAS, LAYOUT_FILE])
		return

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_SPRITES_DIR))
	_create_sprite_resources(layout["items"], atlas_texture)
	print("Done.")

func _reimport_atlas() -> void:
	var filesystem := EditorInterface.get_resource_filesystem()
	filesystem.update_file(OUT_ATLAS)
	filesystem.reimport_files(PackedStringArray([OUT_ATLAS]))

func _load_layout() -> Dictionary:
	var path := ProjectSettings.globalize_path(LAYOUT_FILE)
	if not FileAccess.file_exists(path):
		push_error("No layout data at %s." % LAYOUT_FILE)
		return {}

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))

	if not (parsed is Dictionary) or not parsed.has("items"):
		push_error("Invalid layout cache: " + LAYOUT_FILE)
		return {}

	return parsed

func _create_sprite_resources(items: Array, atlas_texture: Texture2D) -> void:
	var by_asset := {}

	for item in items:
		var asset: String = item["asset"]

		if not by_asset.has(asset):
			by_asset[asset] = []

		by_asset[asset].append(item)

	for asset in by_asset.keys():
		var asset_items: Array = by_asset[asset]
		var out_path := OUT_SPRITES_DIR.path_join(asset + ".tres")

		# Static asset (single frame): plain AtlasTexture, not a SpriteFrames -
		# for entities with a Sprite2D instead of AnimatedSprite2D.
		if asset_items.size() <= 1:
			_save_resource(_make_atlas_frame(asset_items[0], atlas_texture), out_path)
			continue

		var sprite_frames := SpriteFrames.new()
		sprite_frames.remove_animation("default")

		var animations := {}

		for item in asset_items:
			for tag in item["tags"]:
				if not animations.has(tag):
					animations[tag] = []
				animations[tag].append(item)

		for anim_name in animations.keys():
			sprite_frames.add_animation(anim_name)
			sprite_frames.set_animation_speed(anim_name, 1.0)
			sprite_frames.set_animation_loop(anim_name, true)

			var anim_items: Array = animations[anim_name]
			anim_items.sort_custom(func(a, b): return a["frame_index"] < b["frame_index"])

			for item in anim_items:
				var duration_seconds := float(item["duration_ms"]) / 1000.0
				sprite_frames.add_frame(anim_name, _make_atlas_frame(item, atlas_texture), duration_seconds)

		_save_resource(sprite_frames, out_path)

func _make_atlas_frame(item: Dictionary, atlas_texture: Texture2D) -> AtlasTexture:
	var atlas_frame := AtlasTexture.new()
	atlas_frame.atlas = atlas_texture
	atlas_frame.region = Rect2(item["atlas_x"], item["atlas_y"], item["w"], item["h"])
	return atlas_frame

func _save_resource(resource: Resource, out_path: String) -> void:
	# Without this, if Godot already has an old resource cached at out_path
	# (e.g. it's open in the editor), save() can collide with that stale
	# identity and the file on disk never actually gets overwritten.
	resource.take_over_path(out_path)

	if ResourceSaver.save(resource, out_path) != OK:
		push_error("Failed to save %s" % out_path)
	else:
		print("Created %s: %s" % [resource.get_class(), out_path])
