---
name: ui-theme
description: Use whenever creating a new .tscn UI scene, or adding a new top-level Control/Panel/PanelContainer/etc. node directly into an existing scene (e.g. main.tscn), in the BotHero Godot project. Ensures res://Resources/ui.tres is applied so text doesn't render huge/default-styled.
---

# Apply `ui.tres` to every new UI element

Every new UI root node in this project (a new scene's root Control, or a new
top-level panel added straight into `main.tscn`) must have the project theme
applied:

```
theme = ExtResource("<id>_theme")
```

with the matching ext_resource line:

```
[ext_resource type="Theme" uid="uid://c7fc3iqaxbp1g" path="res://Resources/ui.tres" id="<id>_theme"]
```

## Why

`ui.tres` sets the pixel-art font (`PixelifySans`) and `default_font_size =
12`. Without it, new `Control`/`Label`/`Panel` nodes fall back to Godot's
default theme, whose font is much larger relative to this project's 320x180
base viewport — text overflows its container and can cover most of the
screen. This bit `InfoPanel`, `Location`, and `Mission` earlier in
development, each time traced back to a missing `theme =` on the new node's
root.

## How to apply

1. When authoring a new `.tscn` (or a new node block written directly into
   an existing one), add the `Theme` ext_resource shown above if the file
   doesn't already reference it.
2. Set `theme = ExtResource("<id>_theme")` on that element's **root** node
   only — a Theme resource cascades to every descendant automatically, so
   children (`Label`, `Button`, nested containers, etc.) don't need it
   individually unless they intentionally override with `theme_type_variation`
   or a `theme_override_*` property (e.g. `SmallLabel`, per-node font size).
3. Reuse the existing resource (`uid://c7fc3iqaxbp1g`, `res://Resources/ui.tres`)
   — don't create a second theme resource for a new panel.
4. Before considering the element done, grep the new/edited `.tscn` for
   `Resources/ui.tres` to confirm the reference and the root `theme =` line
   are both present. A headless load (see project `CLAUDE.md`) only proves
   the scene parses, not that the theme is wired up — check this by hand.
