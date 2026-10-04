-- Packs every frame of every .aseprite under source_dir into one shared atlas
-- PNG (out_atlas) and writes layout_file with each frame's position, duration
-- and tags - what create_sprites.gd reads, so it never has to touch Aseprite.
--
-- Only rebuilds when the sources actually changed (per `git status`), an asset
-- was added/removed since the last layout, or the atlas doesn't exist yet;
-- pass force=true to rebuild regardless.
--
-- Run from Godot through create_sprites.gd, or by hand:
--   aseprite -b --script-param source_dir=... --script-param out_atlas=...
--     --script-param layout_file=... --script create_atlas.lua
local common = dofile(app.fs.joinPath(app.fs.filePath(debug.getinfo(1, "S").source:sub(2)), "library", "common.lua"))

local sourceDir = common.param("source_dir")
local outAtlas = common.param("out_atlas")
local layoutFile = common.param("layout_file")
local maxWidth = tonumber(app.params["max_width"]) or 1024
local padding = tonumber(app.params["padding"]) or 0
local force = app.params["force"] == "true"

local function assetName(path)
  return app.fs.fileTitle(path)
end

-- True if `git status` reports any pending change (modified, staged or
-- untracked) under sourceDir - our signal that the atlas is stale.
local function gitStatusDirty()
  local pipe = io.popen('git -C "' .. sourceDir .. '" status --porcelain -- .')
  if not pipe then
    print("`git status` couldn't run - rebuilding the atlas to be safe.")
    return true
  end

  local output = pipe:read("a")
  local ok = pipe:close()
  if not ok then
    print("`git status` failed - rebuilding the atlas to be safe.")
    return true
  end

  return output:match("%S") ~= nil
end

-- Catches what git status can't: a .aseprite that's already committed (e.g.
-- pulled from someone else's push) but never went through this builder yet, or
-- one that's been deleted since the last run.
local function assetSetChanged(paths)
  local current = {}
  local currentCount = 0
  for _, path in ipairs(paths) do
    current[assetName(path)] = true
    currentCount = currentCount + 1
  end

  local file = io.open(layoutFile, "r")
  if not file then
    return true
  end
  local ok, layout = pcall(json.decode, file:read("a"))
  file:close()
  -- json.decode returns userdata-backed tables, so check presence, not type().
  if not ok or not layout or not layout.items then
    return true
  end

  local cached = {}
  local cachedCount = 0
  for _, item in ipairs(layout.items) do
    if not cached[item.asset] then
      cached[item.asset] = true
      cachedCount = cachedCount + 1
    end
  end

  if cachedCount ~= currentCount then
    return true
  end
  for name in pairs(current) do
    if not cached[name] then
      return true
    end
  end
  return false
end

-- Frame indices are 0-based in the layout (as create_sprites.gd expects).
local function tagsForFrame(frameIndex, tags)
  local result = {}
  for _, tag in ipairs(tags) do
    if frameIndex >= tag.fromFrame.frameNumber - 1 and frameIndex <= tag.toFrame.frameNumber - 1 then
      table.insert(result, tag.name)
    end
  end
  if #result == 0 then
    table.insert(result, "default")
  end
  return result
end

local function collectFrames(path)
  local sprite = Sprite{ fromFile = path }
  local items = {}

  for i, frame in ipairs(sprite.frames) do
    -- RGB is Aseprite's RGBA mode; drawSprite flattens visible layers and
    -- converts indexed/grayscale sprites for us.
    local image = Image(sprite.width, sprite.height, ColorMode.RGB)
    image:drawSprite(sprite, i)

    table.insert(items, {
      asset = assetName(path),
      frame_index = i - 1,
      image = image,
      w = image.width,
      h = image.height,
      duration_ms = math.floor(frame.duration * 1000 + 0.5),
      tags = tagsForFrame(i - 1, sprite.tags),
      atlas_x = 0,
      atlas_y = 0,
    })
  end

  sprite:close()
  return items
end

-- Assigns atlas_x/atlas_y on each item (left-to-right shelves) and returns the
-- composited atlas image.
local function packAtlas(items)
  local x, y, rowHeight = 0, 0, 0
  local atlasWidth, atlasHeight = 0, 0

  for _, item in ipairs(items) do
    if x + item.w > maxWidth then
      x = 0
      y = y + rowHeight + padding
      rowHeight = 0
    end

    item.atlas_x = x
    item.atlas_y = y

    x = x + item.w + padding
    rowHeight = math.max(rowHeight, item.h)

    atlasWidth = math.max(atlasWidth, x)
    atlasHeight = math.max(atlasHeight, y + rowHeight)
  end

  local atlas = Image(atlasWidth, atlasHeight, ColorMode.RGB)
  for _, item in ipairs(items) do
    atlas:drawImage(item.image, Point(item.atlas_x, item.atlas_y), 255, BlendMode.SRC)
  end
  return atlas
end

local function saveLayout(items, atlas)
  local serializable = {}
  for _, item in ipairs(items) do
    table.insert(serializable, {
      asset = item.asset,
      frame_index = item.frame_index,
      w = item.w,
      h = item.h,
      duration_ms = item.duration_ms,
      tags = item.tags,
      atlas_x = item.atlas_x,
      atlas_y = item.atlas_y,
    })
  end

  local file = assert(io.open(layoutFile, "w"), "Could not write layout cache: " .. layoutFile)
  file:write(json.encode({
    atlas_width = atlas.width,
    atlas_height = atlas.height,
    items = serializable,
  }))
  file:close()
end

-- Scene_*.aseprite composite documents (see split_assets.lua) are staging
-- files, not real assets - only what they get split into (Common/ and each
-- scene's own subfolder) goes into the atlas.
local paths = {}
for _, path in ipairs(common.listFiles(sourceDir, "aseprite")) do
  if not common.isSceneFile(path) then
    table.insert(paths, path)
  end
end

if not force and app.fs.isFile(outAtlas) and not gitStatusDirty() and not assetSetChanged(paths) then
  print("No changes under " .. sourceDir .. " and no assets added/removed - atlas is already up to date.")
  return
end

local items = {}
for _, path in ipairs(paths) do
  for _, item in ipairs(collectFrames(path)) do
    table.insert(items, item)
  end
end

if #items == 0 then
  error("No frames found under " .. sourceDir)
end

local atlas = packAtlas(items)

app.fs.makeAllDirectories(app.fs.filePath(outAtlas))
app.fs.makeAllDirectories(app.fs.filePath(layoutFile))
atlas:saveAs(outAtlas)
saveLayout(items, atlas)

print(string.format("Atlas rebuilt: %s (%dx%d, %d frames).", outAtlas, atlas.width, atlas.height, #items))
