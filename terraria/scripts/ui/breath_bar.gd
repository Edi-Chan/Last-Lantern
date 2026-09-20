class_name BreathBar
extends PanelContainer

## Atemanzeige — nur sichtbar bei Kopf unter Wasser.

@onready var _bar: ProgressBar = $Row/BreathBar
@onready var _label: Label = $Row/BreathLabel

var _water: WaterInteraction
var _fade: float = 0.0
var _hide_delay: float = 0.0
var _target_visible: bool = false


func _ready() -> void:
	modulate.a = 0.0
	visible = false
	call_deferred("_bind")


func _bind() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return
	_water = player.get_node_or_null("WaterInteraction") as WaterInteraction
	if _water == null:
		return
	_water.breath_changed.connect(_on_breath_changed)
	_water.head_submerged.connect(_on_head_submerged)
	_water.head_emerged.connect(_on_head_emerged)
	_on_breath_changed(_water.breath, _water.max_breath)


func _process(delta: float) -> void:
	var want := _target_visible
	if want:
		_hide_delay = 0.6
	_fade = move_toward(_fade, 1.0 if want else 0.0, delta * (4.0 if want else 2.5))
	modulate.a = _fade
	visible = _fade > 0.02
	if not want and _fade <= 0.02:
		_hide_delay = maxf(0.0, _hide_delay - delta)


func _on_head_submerged() -> void:
	_target_visible = true


func _on_head_emerged() -> void:
	_target_visible = false


func _on_breath_changed(current: float, maximum: float) -> void:
	if _bar != null:
		_bar.max_value = maximum
		_bar.value = current
	if _label != null:
		_label.text = "LUFT"
	var low := current / maxf(maximum, 1.0) <= 0.25
	if _bar != null:
		if low:
			_bar.modulate = Color(1.0, 0.55, 0.45, 1.0)
		else:
			_bar.modulate = Color(0.65, 0.85, 1.0, 1.0)
