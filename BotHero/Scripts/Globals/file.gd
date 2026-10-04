class_name SaveFile
extends Node

const SETTINGS_PATH : String = "user://settings.tres"

var settings : Settings

func _ready():
	if ResourceLoader.exists(SETTINGS_PATH):
		settings = ResourceLoader.load(SETTINGS_PATH)
	else:
		settings = Settings.new()
		ResourceSaver.save(settings, SETTINGS_PATH)

func save_settings():
	ResourceSaver.save(settings, SETTINGS_PATH)
