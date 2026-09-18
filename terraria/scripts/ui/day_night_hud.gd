class_name DayNightHud
extends PanelContainer

## Gehoert an: HUD/DayNightHud. Kompakte Tag-/Uhr-/Finsternis-Anzeige, signalbasiert.

@onready var _day_label: Label = $Rows/DayLabel
@onready var _time_label: Label = $Rows/TimeLabel
@onready var _fog_label: Label = $Rows/FogLabel

var _day: DayCycle
var _fog: FogEvent


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	call_deferred("_bind")


func _bind() -> void:
	_day = get_tree().get_first_node_in_group("day_cycle") as DayCycle
	_fog = get_tree().get_first_node_in_group("fog_event") as FogEvent
	if _day != null:
		if not _day.time_changed.is_connected(_on_time_changed):
			_day.time_changed.connect(_on_time_changed)
		if not _day.day_changed.is_connected(_on_day_changed):
			_day.day_changed.connect(_on_day_changed)
	if _fog != null and not _fog.state_changed.is_connected(_on_fog_state):
		_fog.state_changed.connect(_on_fog_state)
	_refresh()


func _on_time_changed(_day_n: int, _time: float, _night: bool) -> void:
	_refresh()


func _on_day_changed(_day_n: int) -> void:
	_refresh()


func _on_fog_state(_state: int) -> void:
	_refresh()


func _refresh() -> void:
	if _day == null:
		return
	if _day_label != null:
		_day_label.text = "Tag %d" % _day.current_day
	if _time_label != null:
		var icon := "☾" if _day.is_night else "☀"
		_time_label.text = "%s %s" % [icon, _day.clock_text()]
	if _fog_label == null:
		return
	if _fog != null and _fog.state == FogEvent.State.FOG_ACTIVE:
		_fog_label.text = "Finsternis aktiv"
		return
	if _fog != null and _fog.state == FogEvent.State.WARNING:
		_fog_label.text = "Finsternis: HEUTE NACHT"
		return
	var settings := _day.settings
	if settings == null:
		_fog_label.text = ""
		return
	var done := _fog.fog_done_today() if _fog != null else false
	var next_day := settings.next_fog_day(_day.current_day, done)
	if next_day == _day.current_day:
		_fog_label.text = "Finsternis: HEUTE NACHT"
	else:
		var left := next_day - _day.current_day
		_fog_label.text = "Finsternis in %d T." % left
