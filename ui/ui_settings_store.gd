extends RefCounted

## Small persistent store for presentation-only UI preferences. This is
## intentionally separate from ProgressStore: changing card density must
## never touch level completion or unlock state.

const CardMetrics = preload("res://ui/card_metrics.gd")

const DEFAULT_PATH := "user://ui_settings.cfg"
const VERSION := 1

var path: String = DEFAULT_PATH
var card_size_mode: String = CardMetrics.DEFAULT

func _init(p_path: String = DEFAULT_PATH) -> void:
	path = p_path
	load_settings()

func load_settings() -> void:
	card_size_mode = CardMetrics.DEFAULT
	if path.is_empty():
		return
	var config := ConfigFile.new()
	if config.load(path) != OK:
		return
	card_size_mode = CardMetrics.normalize(str(config.get_value("ui", "card_size", CardMetrics.DEFAULT)))

func save() -> void:
	if path.is_empty():
		return
	var config := ConfigFile.new()
	config.set_value("version", "version", VERSION)
	config.set_value("ui", "card_size", card_size_mode)
	config.save(path)

func set_card_size_mode(mode: String) -> void:
	var normalized := CardMetrics.normalize(mode)
	if normalized == card_size_mode:
		return
	card_size_mode = normalized
	save()
