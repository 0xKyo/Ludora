# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

"BotHero" is a Godot 4.7 (GDScript) programming-puzzle game. The screen is split in two: a top **Arena** (a grid where the hero plays out the action; nothing in it is draggable) and a bottom **programming area** where the player drags commands (forward, back, jump, attack) into a single-row program, then hits Run and the hero executes them left to right. Rendering uses the GL Compatibility renderer at a pixel-art base resolution of 320x180 (integer-scaled to 1280x720).

There is no CLI build/test pipeline — this is a Godot editor project. Open it in the Godot editor (`Godot_v4.7-stable_win64.exe`, referenced in `.vscode/settings.json`) or load it headlessly with `--path . --headless --quit-after N`. Run `--headless --import` first after adding a `class_name` script so the global class cache updates. There are no automated tests.

## Architecture

Main scene is `Scenes/game.tscn`; all gameplay code lives in `Scripts/Game/`.

- `Game` (`game.gd`, root of `game.tscn`) — the runner. On Run it resets the arena, locks the program, then walks the program slot by slot: highlight the slot, `await arena.execute(action)`, stop early if the goal is reached. Reset mid-run only sets a stop flag (the current step finishes first); tweens are never killed because an awaited killed tween never resumes.
- `Arena` (`arena.gd`) — side-view playfield. Hero walks the bottom row; upper rows are headroom for jumps. Level layout is exported (`grid_size`, `goal_x`, `wall_xs`, `enemy_xs`); visuals are placeholder `ColorRect`s plus a `_draw` checkerboard. `execute(CommandData.Action)` implements the rules: forward/back move one cell (bump if blocked), jump leaps 2 cells over anything in between (hops in place if the landing cell is taken), attack kills the enemy in the next cell.
- `CommandData` (`command_data.gd`) — Resource describing one command (action enum, name, symbol, color). Commands live in `Resources/Commands/*.tres`; adding one is a new `.tres` plus a case in `Arena.execute()`.
- `CommandSlot` (`command_slot.gd`) — one drag/drop cell. With `is_source = true` (the palette) it's an infinite drag-only source; otherwise it's a program slot holding one command. Dragging a command out of a program slot clears it, so dropping it anywhere but another slot deletes it. Drag data is `{"command": CommandData}`.
- `ProgramBar` (`program_bar.gd`) — the 1xN row of program slots (`slot_count`); `get_program()` returns one entry per slot, `null` for empty ones. `locked` freezes editing while running.
- `CommandPalette` (`command_palette.gd`) — builds one source slot per entry in its `commands` export.

**Autoloads** (`project.godot`): `File` (`Scripts/Globals/file.gd`, class `SaveFile`) loads/creates `user://settings.tres` (`Settings` resource); `Music` (`Scripts/Globals/music.gd`) is a crossfading `AudioStreamPlayer` using `File.settings.volume`.

## UI

New UI scenes must apply `res://Resources/ui.tres` as their theme (see the `ui-theme` skill), otherwise text renders huge. Icons with no real art yet should use `Resources/Sprites/PlaceHolder8/16/32.tres`.

## Asset pipeline

Source art lives in `Art/Source/*.aseprite`; `generate_assets.cmd` shells out to Aseprite (`-b --save-as`) to export each to a flat PNG in `Art/Generated/`. `_engine` is a symlink to the shared engine (`../Engine`, created by `setup_project.bat`); fonts for `ui.tres` come from `_engine/assets/fonts/PixelifySans`. Both assume Aseprite is installed locally; there's no CI asset build.

## Verification

Verify with headless loads only (no windowed game, screenshots or simulated input). Do not write custom `-s` SceneTree harnesses: autoloads do not reliably resolve when the main loop is overridden, and orphaned `Godot_*.exe` processes can hang the next headless run, so check for stray processes if a run hangs with no output.
