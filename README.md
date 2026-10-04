# Ludora

Ludora is an educational games platform. This repository contains all the games built for the Ludora project, along with the engine code they share.

## Repository layout

| Folder | Description |
| --- | --- |
| `BotHero/` | A programming-puzzle game built with Godot. |
| `Engine/` | Shared tools, assets and shaders used by every game (fonts, CRT shader, sprite and atlas tooling). |

New games are added as sibling folders next to `BotHero/`.

## Requirements

- [Godot](https://godotengine.org/) 4.x
- [Aseprite](https://www.aseprite.org/), only to regenerate art assets
- Windows: Developer Mode enabled (or an administrator console) to create the symlink below

## Getting started

Each game links to the shared `Engine/` folder through an `_engine` symlink, which is not committed. After cloning, run the setup script inside the game you want to open:

```bat
BotHero\setup_project.bat
```

Then open the game's folder (for example `BotHero/`) in the Godot editor.

## License

Proprietary. All rights reserved. See [LICENSE](LICENSE).
