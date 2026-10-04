---
name: feedback-no-visual-testing
description: Don't do visual/interactive testing of the Godot game (screenshots, simulated mouse/window automation) — headless load checks only
metadata:
  type: feedback
---

When verifying changes to the BotHero Godot project, do not launch a windowed game instance, take screenshots, or simulate mouse/keyboard input to visually test the feature. Only use headless checks, e.g.:

```
"e:\Workspace\InerteGames\Godot_v4.7-stable_win64.exe" --path "e:\Workspace\Ludora\BotHero" --headless --quit-after N
```

to confirm the project still parses/runs without script or scene errors. Run `--headless --import` first after adding a `class_name` script so the global class cache updates.

**Why:** Visual/mouse-automation testing (PowerShell window focusing, simulated clicks, screenshots) was fragile and confusing in a prior project — it fought with the user's own Godot editor session open in parallel, and the user explicitly stopped it. They test interactively themselves.

**How to apply:** After implementing a feature (new scripts/scenes, edits to existing ones), run a headless load as the only automated verification, report the result, and hand off interactive/visual verification to the user. Don't launch the Godot executable windowed, don't screenshot, don't simulate input.

Don't write a custom `-s script.gd` SceneTree harness to exercise gameplay logic as a substitute for `--quit-after`: project autoloads don't reliably resolve when the main loop is overridden, and it can leave orphaned `Godot_*.exe` processes that hang the next headless run. If a headless run hangs with zero output, check for stray Godot processes first.

The Godot executable path has moved before — if a headless invocation fails with "not recognized," re-check `.vscode/settings.json`'s `godotTools.editorPath.godot4`.
