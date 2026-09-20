extends Control

## Zeigt Fortschritt, bevor die bestehende World-Szene geladen wird.

const TIPS := [
	"Sammle Ressourcen, bevor die Nacht kommt.",
	"Eine gute Mauer ist besser als Hoffnung.",
	"Bereite dich auf Tag 7 vor.",
	"Die Laterne haelt die Finsternis fern.",
	"Ohne Werkzeug musst du erst finden, dann formen.",
]

@onready var _title: Label = $Center/Column/TitleLabel
@onready var _tip: Label = $Center/Column/TipLabel
@onready var _bar: ProgressBar = $Center/Column/Bar
@onready var _fill_label: Label = $Center/Column/PercentLabel

var _elapsed: float = 0.0
var _started_world: bool = false


func _ready() -> void:
	add_to_group("start_flow_ui")
	theme = AdminTheme.make_theme()
	if _title != null:
		_title.text = "WELT WIRD ERSTELLT..."
	if _tip != null:
		_tip.text = TIPS[randi() % TIPS.size()]
	if _bar != null:
		_bar.min_value = 0.0
		_bar.max_value = 1.0
		_bar.value = 0.08
		_bar.show_percentage = false
	_fade_in()


func _process(delta: float) -> void:
	_elapsed += delta
	var t := clampf(_elapsed / 1.15, 0.0, 1.0)
	if _bar != null:
		_bar.value = t
	if _fill_label != null:
		_fill_label.text = "%d%%" % int(t * 100.0)
	if not _started_world and _elapsed >= 0.85:
		_started_world = true
		var flow := get_node_or_null("/root/GameFlow")
		if flow != null and flow.has_method("enter_world"):
			flow.call("enter_world")


func _fade_in() -> void:
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.16)
