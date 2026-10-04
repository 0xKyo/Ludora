class_name LanguageSelector
extends OptionButton

# Flag-only dropdown; one entry per supported language.
@export var languages: Array[LanguageData] = []

func _ready() -> void:
	for i in languages.size():
		add_icon_item(languages[i].flag, "", i)
		set_item_tooltip(i, languages[i].display_name)
	select(_index_for(TranslationServer.get_locale()))
	tooltip_text = languages[selected].display_name
	item_selected.connect(_on_item_selected)

func _index_for(locale: String) -> int:
	for i in languages.size():
		if locale == languages[i].locale or locale.begins_with(languages[i].locale + "_"):
			return i
	return 0

func _on_item_selected(index: int) -> void:
	tooltip_text = languages[index].display_name
	File.set_locale(languages[index].locale)
