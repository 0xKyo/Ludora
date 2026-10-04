---
name: project-placeholder-assets
description: Which pre-made placeholder texture to use per size when no real art exists yet for an icon/sprite
metadata:
  type: project
---

Three placeholder textures exist for whenever something needs a texture but no real art has been made yet:

- `res://Resources/Sprites/PlaceHolder8.tres` — for 8x8 assets
- `res://Resources/Sprites/Placeholder16.tres` — for 16x16 assets (note: lowercase "h" in the filename, unlike the other two)
- `res://Resources/Sprites/PlaceHolder32.tres` — for 32x32 assets

**Why:** Stated directly by the user so new content doesn't get built with a borrowed/mismatched texture or a plain default Godot icon.

**How to apply:** When creating a new asset that needs a texture and no real art exists for it yet, pick the placeholder matching the target size instead of leaving it blank, reusing an unrelated texture, or inventing a new placeholder file.
