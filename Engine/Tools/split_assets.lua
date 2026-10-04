-- Splits composite scene mockups into individual per-object source assets,
-- and pulls polished edits back the other way.
--
-- Layout under source_dir (Art/Source):
--   Scene_<Name>.aseprite   - a composite mockup, one layer per object (a
--                             room, its furniture, etc). Staging-only: never
--                             packed into the atlas itself, see
--                             create_atlas.lua.
--   <Name>/*.aseprite       - one file per top-level layer of Scene_<Name>,
--                             named after the layer. This is what actually
--                             gets packed into the atlas. Can be edited by
--                             hand after export ("polishing" a single asset
--                             once the whole scene reads right together).
--   Common/*.aseprite       - standalone assets shared across scenes; not
--                             produced by this script, just picked up by
--                             create_atlas.lua like any other folder here.
--
-- For every Scene_<Name>.aseprite, and for each of its top-level layers L:
--   1. If <Name>/L.aseprite already exists and was modified more recently
--      than the scene file, its content is merged INTO the scene's L layer
--      first (see mergeAssetIntoLayer) - this is how a polish done on the
--      individual asset flows back into the full-scene view. If it's not
--      newer, the scene's own version of L wins, same as before.
--   2. L is (re-)exported to <Name>/L.aseprite: isolated into its own
--      document, cropped to content (only frames with actual content are
--      kept - see frameCountToExport), and its scene-canvas position is
--      stamped into the file (sprite.data) so a future merge knows where it
--      came from - the crop above would otherwise lose that.
--   3. Any tags the file already had are restored on the freshly exported
--      copy. Tags only ever live on the individual asset (never on the
--      scene) - step 2 rebuilds the file from scratch, so without this an
--      animation tag added by hand on the asset would be lost the moment
--      the scene gets re-split.
-- The scene file itself is only re-saved (with the merges from step 1) if at
-- least one layer actually got pulled back into it.
--
-- Run from Godot through split_assets.gd, or by hand:
--   aseprite -b --script-param source_dir=<dir> --script split_assets.lua
local common = dofile(app.fs.joinPath(app.fs.filePath(debug.getinfo(1, "S").source:sub(2)), "library", "common.lua"))

local sourceDir = common.param("source_dir")

-- Renders every frame of the sprite (visible layers only) into RGBA images.
local function renderFrames(sprite)
  local images = {}
  for i = 1, #sprite.frames do
    local image = Image(sprite.width, sprite.height, ColorMode.RGB)
    image:drawSprite(sprite, i)
    images[i] = image
  end
  return images
end

-- How many frames of the layer are worth exporting, judged by what's actually
-- drawn (not by cel counts):
--   * trailing empty frames are dropped;
--   * if every remaining frame is identical (a static object whose cel was
--     just held or copied over several frames), only the first is kept;
--   * otherwise it's an animation and frames 1..last are all kept.
-- Returns 0 if the layer has no content at all.
local function frameCountToExport(images)
  local last = 0
  for i, image in ipairs(images) do
    if not image:shrinkBounds().isEmpty then
      last = i
    end
  end

  for i = 2, last do
    if not images[i]:isEqual(images[1]) then
      return last
    end
  end
  return math.min(last, 1)
end

-- Union of the drawn content of the first frameCount frames, in canvas
-- coordinates. Computed here instead of using app.command.AutocropSprite,
-- which depends on the active frame/sprite state and goes stale after frames
-- are deleted.
local function contentBounds(images, frameCount)
  local bounds
  for i = 1, frameCount do
    local frameBounds = images[i]:shrinkBounds()
    if not frameBounds.isEmpty then
      bounds = bounds and bounds:union(frameBounds) or frameBounds
    end
  end
  return bounds
end

-- Every tag on `tags` (a Sprite.tags list), as plain data that survives past
-- the source sprite being closed.
local function copyTags(tags)
  local result = {}
  for _, tag in ipairs(tags) do
    table.insert(result, {
      name = tag.name,
      fromFrame = tag.fromFrame.frameNumber,
      toFrame = tag.toFrame.frameNumber,
      aniDir = tag.aniDir,
      color = tag.color,
      repeats = tag.repeats,
    })
  end
  return result
end

-- Tags live on the individual asset file only, never on the scene (see the
-- header comment) - exportLayer rebuilds the file from scratch every run, so
-- without this a tag added by hand on the asset would be lost the moment the
-- scene gets re-split. Ranges are clamped to the freshly exported frame
-- count; a tag that no longer fits at all is dropped with a warning.
local function applyPriorTags(sprite, tags, frameCount)
  for _, tag in ipairs(tags) do
    if tag.fromFrame > frameCount then
      print(string.format("Warning: tag '%s' no longer fits (asset now has %d frame(s)) - dropped.", tag.name, frameCount))
    else
      local newTag = sprite:newTag(tag.fromFrame, math.min(tag.toFrame, frameCount))
      newTag.name = tag.name
      newTag.aniDir = tag.aniDir
      newTag.color = tag.color
      newTag.repeats = tag.repeats
    end
  end
end

-- The scene-canvas position an exported asset was cropped from (see
-- exportLayer), read back from the sprite.data metadata it stamped on
-- itself. Returns nil (and warns) if missing - e.g. a file that was created
-- by hand and never actually round-tripped through this script.
local function readOffset(asset, assetPath)
  if not asset.data or asset.data == "" then
    print(string.format("Warning: '%s' has no scene-offset metadata (never exported by this script?) - keeping the scene's own version instead of merging.", assetPath))
    return nil
  end

  local ok, decoded = pcall(json.decode, asset.data)
  if not ok or not decoded or decoded.x == nil or decoded.y == nil then
    print(string.format("Warning: '%s' has unreadable scene-offset metadata - keeping the scene's own version instead of merging.", assetPath))
    return nil
  end

  return Point(decoded.x, decoded.y)
end

local function findChildByName(group, name)
  for _, child in ipairs(group.layers) do
    if child.name == name then
      return child
    end
  end
  return nil
end

-- Copies every cel from `source` onto `target` (a plain layer, or a group
-- with matching sub-layers), shifting positions by offset. target's own
-- existing cels are wiped first. Sub-layers are matched by name: one present
-- in source but missing under target is created; one only under target is
-- left untouched. Assumes sprite already has enough frames for every one of
-- source's cels - see growFrames.
local function replaceCels(sprite, target, source, offset)
  if source.isGroup then
    for _, sourceChild in ipairs(source.layers) do
      local targetChild = findChildByName(target, sourceChild.name)
      if not targetChild then
        targetChild = sprite:newLayer()
        targetChild.name = sourceChild.name
        targetChild.parent = target
      end
      replaceCels(sprite, targetChild, sourceChild, offset)
    end
    return
  end

  for _, cel in ipairs({ table.unpack(target.cels) }) do
    sprite:deleteCel(cel)
  end
  for _, cel in ipairs(source.cels) do
    sprite:newCel(target, cel.frameNumber, cel.image, cel.position + offset)
  end
end

-- The last cel (by frame number) of every leaf layer under `layer`, keyed by
-- layer object. Used by growFrames to know what to repeat onto new frames.
local function collectLastCels(layer, result)
  result = result or {}
  if layer.isGroup then
    for _, child in ipairs(layer.layers) do
      collectLastCels(child, result)
    end
    return result
  end

  local last = nil
  for _, cel in ipairs(layer.cels) do
    if not last or cel.frameNumber > last.frameNumber then
      last = cel
    end
  end
  result[layer] = last
  return result
end

-- Grows sprite to targetCount frames if it's shorter, appending frames at
-- the end. Aseprite's own Sprite:newFrame() is documented as duplicating the
-- current frame, but which frame counts as "current" (and which layers get a
-- copied cel) turned out to be unreliable once a sprite has been reloaded
-- from disk rather than just created - so instead, every leaf layer's own
-- last cel is captured up front and re-stamped onto each new frame
-- explicitly, which is the "layers repeat their last frame" behavior this
-- is meant to give.
local function growFrames(sprite, targetCount)
  local before = #sprite.frames
  if before >= targetCount then
    return
  end

  local lastCels = {}
  for _, layer in ipairs(sprite.layers) do
    collectLastCels(layer, lastCels)
  end

  while #sprite.frames < targetCount do
    sprite:newFrame()
  end

  for layer, cel in pairs(lastCels) do
    for frameNumber = before + 1, targetCount do
      sprite:newCel(layer, frameNumber, cel.image, cel.position)
    end
  end
end

-- If `asset` (already open, loaded from assetPath) should win over the
-- scene's own version of sceneLayer, pulls its cels into it - see the header
-- comment. Tags are deliberately NOT touched here; they never live on the
-- scene, see applyPriorTags. Returns true if it actually merged something.
local function mergeAssetIntoLayer(scene, sceneLayer, asset, assetPath)
  local assetRoot = asset.layers[1]
  if assetRoot.isGroup ~= sceneLayer.isGroup then
    print(string.format(
      "Warning: '%s' is a %s but the scene's '%s' layer is a %s - skipping merge.",
      assetPath, assetRoot.isGroup and "group" or "layer",
      sceneLayer.name, sceneLayer.isGroup and "group" or "layer"))
    return false
  end

  local offset = readOffset(asset, assetPath)
  if not offset then
    return false
  end

  growFrames(scene, #asset.frames)
  replaceCels(scene, sceneLayer, assetRoot, offset)

  print(string.format("Merged '%s' into the scene's '%s' layer (edited more recently).", assetPath, sceneLayer.name))
  return true
end

-- Scene layers are often hidden while composing the mockup; an exported
-- asset must be visible, or rendering/trimming (and create_atlas.lua) see
-- nothing.
local function exportLayer(scenePath, layerName, sceneFolder, priorTags)
  local sprite = Sprite{ fromFile = scenePath }

  for i = #sprite.layers, 1, -1 do
    local layer = sprite.layers[i]
    if layer.name ~= layerName then
      sprite:deleteLayer(layer)
    end
  end

  sprite.layers[1].isVisible = true

  local images = renderFrames(sprite)
  local frameCount = frameCountToExport(images)
  if frameCount == 0 then
    print(string.format("Skipped layer '%s': no content.", layerName))
    sprite:close()
    return
  end

  for i = #sprite.frames, frameCount + 1, -1 do
    sprite:deleteFrame(i)
  end

  -- Crop the canvas to the kept frames' content, and remember where that was
  -- in the scene canvas - see readOffset/mergeAssetIntoLayer.
  local bounds = contentBounds(images, frameCount)
  sprite:crop(bounds)
  sprite.data = json.encode({ x = bounds.x, y = bounds.y })

  applyPriorTags(sprite, priorTags, frameCount)

  local outPath = app.fs.joinPath(sceneFolder, layerName .. ".aseprite")
  sprite:saveAs(outPath)
  sprite:close()

  print(string.format("Exported layer '%s' -> %s", layerName, outPath))
end

local function processScene(scenePath)
  local sceneName = app.fs.fileTitle(scenePath):gsub("^Scene_", "")
  local sceneFolder = app.fs.joinPath(app.fs.filePath(scenePath), sceneName)
  app.fs.makeAllDirectories(sceneFolder)

  local sceneMtime = common.fileModTime(scenePath)
  local scene = Sprite{ fromFile = scenePath }

  local topLayerNames = {}
  local priorTagsByName = {}
  local changed = false

  for _, layer in ipairs(scene.layers) do
    table.insert(topLayerNames, layer.name)

    local assetPath = app.fs.joinPath(sceneFolder, layer.name .. ".aseprite")
    if app.fs.isFile(assetPath) then
      local asset = Sprite{ fromFile = assetPath }
      priorTagsByName[layer.name] = copyTags(asset.tags)

      local assetMtime = common.fileModTime(assetPath)
      if assetMtime and sceneMtime and assetMtime > sceneMtime then
        if mergeAssetIntoLayer(scene, layer, asset, assetPath) then
          changed = true
        end
      end

      asset:close()
    end
  end

  if #topLayerNames == 0 then
    error("Could not read layers from: " .. scenePath)
  end

  if changed then
    scene:saveAs(scenePath)
  end
  scene:close()

  for _, layerName in ipairs(topLayerNames) do
    exportLayer(scenePath, layerName, sceneFolder, priorTagsByName[layerName] or {})
  end

  -- Bump the scene file's mtime past the per-object files just (re)written
  -- above, so next run's merge check isn't fooled by that unconditional
  -- rewrite into thinking they were hand-edited. A no-op resave: identical
  -- content saves out byte-for-byte identical, so this doesn't create
  -- spurious git changes when nothing actually changed.
  local final = Sprite{ fromFile = scenePath }
  final:saveAs(scenePath)
  final:close()
end

local sceneFiles = {}
for _, path in ipairs(common.listFiles(sourceDir, "aseprite")) do
  if common.isSceneFile(path) then
    table.insert(sceneFiles, path)
  end
end

if #sceneFiles == 0 then
  print("No Scene_*.aseprite files found under " .. sourceDir)
  return
end

for _, scenePath in ipairs(sceneFiles) do
  processScene(scenePath)
end

print("Done.")
