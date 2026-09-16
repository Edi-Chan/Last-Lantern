class_name FogHud
extends Control

## Gehoert an: HUD/FogHud. Warnung, Status und Damage-Vignette.

@onready var _warning: Label = $WarningLabel
@onready var _status: Label = $StatusLabel
@onready var _vignette: ColorRect = $Vignette

var _fog: FogEvent
var _player: Player
var _flash: float = 0.0
var _status_refresh: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _warning != null:
		_warning.visible = false
		_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _status != null:
		_status.visible = false
		_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _vignette != null:
		_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_vignette.color = Color(0.45, 0.05, 0.08, 0.0)
	call_deferred("_bind")


func _bind() -> void:
	_fog = get_tree().get_first_node_in_group("fog_event") as FogEvent
	_player = get_tree().get_first_node_in_group("player") as Player
	if _fog == null:
		return
	if not _fog.fog_warning_started.is_connected(_on_warning):
		_fog.fog_warning_started.connect(_on_warning)
	if not _fog.state_changed.is_connected(_on_state):
		_fog.state_changed.connect(_on_state)
	if not _fog.fog_damage_applied.is_connected(_on_damage):
		_fog.fog_damage_applied.connect(_on_damage)
	_on_state(_fog.state)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(_flash - delta, 0.0)
	if _vignette != null:
		var danger := 0.0
		if _fog != null and _fog.state == FogEvent.State.FOG_ACTIVE and not _fog.player_is_safe:
			danger = 0.16
		_vignette.color.a = maxf(danger, _flash * 0.28)
	_status_refresh -= delta
	if _status_refresh <= 0.0:
		_status_refresh = 0.25
		_update_status()
	if _warning != null and _warning.visible and _fog != null and _fog.state != FogEvent.State.WARNING:
		_warning.visible = false


func _on_warning(_day: int, _cycle: int) -> void:
	if _warning == null:
		return
	_warning.text = "⚠ DER NEBEL KOMMT ..."
	_warning.visible = true
	var tween := create_tween()
	_warning.modulate.a = 0.0
	tween.tween_property(_warning, "modulate:a", 1.0, 0.35)
	tween.tween_interval(3.6)
	tween.tween_property(_warning, "modulate:a", 0.0, 0.8)
	tween.tween_callback(func() -> void:
		if _fog == null or _fog.state != FogEvent.State.WARNING:
			_warning.visible = false
		else:
			_warning.modulate.a = 1.0
			_warning.visible = true
	)


func _on_state(state: int) -> void:
	if _warning != null and state != FogEvent.State.WARNING:
		_warning.visible = false
	_update_status()


func _on_damage(_amount: float) -> void:
	_flash = 0.35


func _update_status() -> void:
	if _status == null or _fog == null:
		return
	if _fog.state == FogEvent.State.FOG_ACTIVE:
		_status.visible = true
		if _fog.player_is_safe:
			_status.text = "☠ TÖDLICHER NEBEL   GESCHÜTZT"
			_status.modulate = Color(0.95, 0.86, 0.45, 1)
		else:
			_status.text = "☠ TÖDLICHER NEBEL   NEBELGEFAHR"
			_status.modulate = Color(1.0, 0.38, 0.32, 1)
		var left := _fog.fog_time_left()
		if left > 0.0:
			var minutes := int(left) / 60
			var seconds := int(left) % 60
			_status.text += "   %02d:%02d" % [minutes, seconds]
	elif _fog.state == FogEvent.State.WARNING:
		_status.visible = true
		_status.modulate = Color(1.0, 0.72, 0.35, 1)
		_status.text = "⚠ DER NEBEL KOMMT ..."
	else:
		_status.visible = false
