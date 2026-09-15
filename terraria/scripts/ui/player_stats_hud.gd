class_name PlayerStatsHUD
extends PanelContainer

## Gehoert an: UI/PlayerStatsPanel in res://scenes/ui/hud.tscn
##
## Reine Anzeige. Die Werte kommen ausschliesslich ueber die Signale von
## PlayerStats, es gibt kein Polling pro Frame.

@onready var _health_bar: ProgressBar = $Rows/HealthRow/HealthBar
@onready var _health_value: Label = $Rows/HealthRow/HealthValue
@onready var _stamina_bar: ProgressBar = $Rows/StaminaRow/StaminaBar
@onready var _stamina_value: Label = $Rows/StaminaRow/StaminaValue
@onready var _energy_bar: ProgressBar = $Rows/EnergyRow/EnergyBar
@onready var _energy_value: Label = $Rows/EnergyRow/EnergyValue

func _ready() -> void:
	_bind_stats()


## Der Player haengt in einer Nachbarszene. Beim ersten Frame kann seine
## _ready noch offen sein, deshalb ein zweiter Versuch im naechsten Frame.
func _bind_stats() -> void:
	var stats := _find_stats()
	if stats == null:
		await get_tree().process_frame
		stats = _find_stats()
	if stats == null:
		push_warning("PlayerStatsHUD: keine PlayerStats in Gruppe 'player_stats' gefunden.")
		return
	stats.health_changed.connect(_on_health_changed)
	stats.stamina_changed.connect(_on_stamina_changed)
	stats.energy_changed.connect(_on_energy_changed)
	# Startwerte sofort anzeigen, nicht erst bei der ersten Aenderung.
	stats.emit_all()


func _find_stats() -> PlayerStats:
	return get_tree().get_first_node_in_group("player_stats") as PlayerStats


func _on_health_changed(current: float, maximum: float) -> void:
	_apply(_health_bar, _health_value, current, maximum)


func _on_stamina_changed(current: float, maximum: float) -> void:
	_apply(_stamina_bar, _stamina_value, current, maximum)


func _on_energy_changed(current: float, maximum: float) -> void:
	_apply(_energy_bar, _energy_value, current, maximum)


## ceili statt roundi: ein Restwert von 0.4 soll als 1 erscheinen, damit die
## Anzeige nur bei echter Null auf 0 springt.
func _apply(bar: ProgressBar, value: Label, current: float, maximum: float) -> void:
	if bar != null:
		bar.max_value = maximum
		bar.value = current
	if value != null:
		value.text = "%d / %d" % [ceili(current), roundi(maximum)]
