class_name CombatTextPresenter
extends Object

## Leitet aus einem DamageEvent die Darstellung ab. Nie umgekehrt (Farbe -> Typ).

enum Style {
	PHYSICAL,
	CRITICAL,
	PLAYER_DAMAGE,
	DARKNESS,
	FIRE,
	FROST,
	HEAL,
	REDUCED,
}


static func style_for(event: DamageEvent) -> int:
	if event == null:
		return Style.PHYSICAL
	if event.is_heal() or event.damage_type == DamageTypes.Type.HEALING:
		return Style.HEAL
	if event.blocked or event.amount <= 0:
		return Style.REDUCED
	if event.critical:
		return Style.CRITICAL
	match event.damage_type:
		DamageTypes.Type.FIRE:
			return Style.FIRE
		DamageTypes.Type.FROST:
			return Style.FROST
		DamageTypes.Type.DARKNESS:
			return Style.DARKNESS
	if event.reduced:
		return Style.REDUCED
	if event.is_player_target:
		return Style.PLAYER_DAMAGE
	return Style.PHYSICAL


static func color_for(event: DamageEvent, config: CombatTextConfig) -> Color:
	var cfg := config if config != null else CombatTextConfig.new()
	match style_for(event):
		Style.CRITICAL:
			return cfg.critical_color
		Style.PLAYER_DAMAGE:
			return cfg.player_damage_color
		Style.DARKNESS:
			return cfg.darkness_color
		Style.FIRE:
			return cfg.fire_color
		Style.FROST:
			return cfg.frost_color
		Style.HEAL:
			return cfg.heal_color
		Style.REDUCED:
			return cfg.reduced_color
		_:
			return cfg.physical_color


static func font_size_for(event: DamageEvent, config: CombatTextConfig) -> int:
	var cfg := config if config != null else CombatTextConfig.new()
	if event != null and event.critical:
		return cfg.critical_font_size
	if event != null and event.is_dot:
		return cfg.dot_font_size
	return cfg.normal_font_size


static func display_text(event: DamageEvent) -> String:
	if event == null:
		return "0"
	if event.is_heal():
		return "+%d" % event.amount
	if event.blocked and event.amount <= 0:
		return "0"
	if event.is_player_target and not event.critical:
		return "-%d" % maxi(event.amount, 0)
	if event.critical:
		return "%d!" % event.amount
	return str(event.amount)
