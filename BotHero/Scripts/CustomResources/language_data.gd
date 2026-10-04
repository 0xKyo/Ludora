class_name LanguageData
extends Resource

# Matches the Localization/<locale>.csv column and Godot's locale code.
@export var locale: String = ""
# Shown in the language's own tongue, so it's deliberately not a translation key.
@export var display_name: String = ""
@export var flag: Texture2D
