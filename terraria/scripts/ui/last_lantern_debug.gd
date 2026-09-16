extends Label

## Gehoert an: HUD/LanternDebugLabel. Kompaktes Debug, 4 Updates/s.

var _refresh_left: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", 8)


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left > 0.0:
		return
	_refresh_left = 0.25
	var day := get_tree().get_first_node_in_group("day_cycle") as DayCycle
	var fog := get_tree().get_first_node_in_group("fog_event") as FogEvent
	var lantern := get_tree().get_first_node_in_group("lantern") as Lantern
	var lines: PackedStringArray = []
	if day != null:
		lines.append("Day %d  Time %s" % [day.current_day, day.clock_text()])
	if fog != null:
		var names: PackedStringArray = ["CLEAR", "WARNING", "FOG_ACTIVE", "FOG_ENDING"]
		var state_name: String = "UNKNOWN"
		if fog.state >= 0 and fog.state < names.size():
			state_name = String(names[fog.state])
		var dps := 0.0
		if fog.settings != null:
			dps = fog.settings.fog_damage_per_second(fog.fog_cycle)
		lines.append("Fog %s  C%d  DPS %.1f" % [state_name, fog.fog_cycle, dps])
		lines.append("Safe %s" % ["YES" if fog.player_is_safe else "NO"])
	if lantern != null:
		lines.append("Lantern L%d  R%d" % [lantern.level, int(lantern.get_safe_radius_tiles())])
	lines.append("%d FPS" % roundi(Engine.get_frames_per_second()))
	text = "\n".join(lines)
