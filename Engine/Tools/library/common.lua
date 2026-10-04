-- Helpers shared by the Aseprite Lua tools (create_atlas.lua, split_assets.lua).
-- Loaded with dofile() from the tools one level up, see the top of each tool.
local common = {}

-- Reads a required --script-param, failing loudly if the Godot launcher forgot it.
function common.param(name)
  local value = app.params[name]
  if value == nil or value == "" then
    error("missing --script-param: " .. name)
  end
  return value
end

-- Recursively lists files under dir with the given extension (no dot), sorted
-- so runs are deterministic. Skips dotfiles/dotdirs, like the old GDScript walker.
function common.listFiles(dir, extension)
  local result = {}

  local function walk(current)
    for _, name in ipairs(app.fs.listFiles(current)) do
      if name:sub(1, 1) ~= "." then
        local path = app.fs.joinPath(current, name)
        if app.fs.isDirectory(path) then
          walk(path)
        elseif app.fs.fileExtension(name):lower() == extension then
          table.insert(result, path)
        end
      end
    end
  end

  walk(dir)
  table.sort(result)
  return result
end

-- True for a composite scene document (e.g. "Scene_LivingRoom.aseprite") -
-- the convention split_assets.lua uses to tell those apart from the
-- individual per-object assets it exports and create_atlas.lua packs.
function common.isSceneFile(path)
  return app.fs.fileName(path):match("^Scene_") ~= nil
end

-- A file's last-modified time as an opaque, larger-is-later number (.NET
-- ticks, 100ns units) - only meant for comparing two of these against each
-- other, not as a real timestamp. Whole seconds aren't fine-grained enough:
-- two files touched moments apart by the same script run can otherwise land
-- in the same second and tie. Aseprite's Lua API has no direct stat call, so
-- this shells out to PowerShell - fine given ASEPRITE_EXE is already a
-- Windows-only, hardcoded-per-machine assumption of this whole pipeline.
function common.fileModTime(path)
  local cmd = string.format(
    'powershell -NoProfile -Command "(Get-Item -LiteralPath \'%s\').LastWriteTimeUtc.Ticks"',
    path)
  local pipe = io.popen(cmd)
  if not pipe then
    return nil
  end
  local output = pipe:read("a")
  pipe:close()
  return tonumber(output)
end

return common
