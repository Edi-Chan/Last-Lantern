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
@onready var _admin_row: HBoxContainer = get_node_or_null("Rows/AdminRow")
@onready var _admin_button: Button = get_node_or_null("Rows/AdminRow/AdminButton")
@onready var _admin_dot: Label = get_node_or_null("Rows/AdminRow/AdminDot")

func _ready() -> void:
	_bind_stats()
	_wire_admin_button()


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


func _wire_admin_button() -> void:
	z_index = 90
	var show := OS.is_debug_build() or OS.has_feature("editor")
	var admin := get_node_or_null("/root/AdminManager")
	if admin != null and admin.has_method("is_available"):
		show = bool(admin.call("is_available")) or OS.has_feature("editor")
	if _admin_row != null:
		_admin_row.visible = show
	if _admin_button == null:
		return
	_admin_button.visible = show
	_admin_button.focus_mode = Control.FOCUS_NONE
	_admin_button.tooltip_text = "Admin-Menü"
	if show and not _admin_button.pressed.is_connected(_on_admin_pressed):
		_admin_button.pressed.connect(_on_admin_pressed)
	if admin != null and admin.has_signal("modifiers_changed"):
		if not admin.is_connected("modifiers_changed", _on_admin_modifiers):
			admin.connect("modifiers_changed", _on_admin_modifiers)
	_on_admin_modifiers()


func _on_admin_pressed() -> void:
	var admin := get_node_or_null("/root/AdminManager")
	if admin != null:
		admin.call("toggle_menu")


func _on_admin_modifiers() -> void:
	if _admin_dot == null:
		return
	var admin := get_node_or_null("/root/AdminManager")
	_admin_dot.visible = admin != null and bool(admin.call("has_active_modifiers"))
