class_name StatId
extends Object

## Zentrale Stat-IDs. Anzeige und Berechnung haengen an diesen Werten,
## nicht an verstreuten Player-Variablen.

enum {
	MAX_HEALTH,
	HEALTH_REGEN,
	MAX_STAMINA,
	STAMINA_REGEN,
	MAX_ENERGY,
	MOVEMENT_SPEED,
	SPRINT_SPEED,
	JUMP_POWER,
	ARMOR,
	DAMAGE_MULTIPLIER,
	ATTACK_SPEED,
	CRIT_CHANCE,
	CRIT_DAMAGE,
	ARMOR_PENETRATION,
	KNOCKBACK_MODIFIER,
	KNOCKBACK_RESISTANCE,
	MINING_SPEED,
	WOODCUTTING_SPEED,
	HARVEST_AMOUNT,
	BUILDING_SPEED,
	REPAIR_SPEED,
	FIRE_RESISTANCE,
	COLD_RESISTANCE,
	POISON_RESISTANCE,
	BLEEDING_RESISTANCE,
	DARKNESS_RESISTANCE,
}


static func display_name(stat: int) -> String:
	match stat:
		MAX_HEALTH:
			return "Max. Leben"
		HEALTH_REGEN:
			return "Leben-Regeneration"
		MAX_STAMINA:
			return "Max. Ausdauer"
		STAMINA_REGEN:
			return "Ausdauer-Regeneration"
		MAX_ENERGY:
			return "Max. Energie"
		MOVEMENT_SPEED:
			return "Bewegungstempo"
		SPRINT_SPEED:
			return "Sprinttempo"
		JUMP_POWER:
			return "Sprungkraft"
		ARMOR:
			return "Rüstung"
		DAMAGE_MULTIPLIER:
			return "Schaden"
		ATTACK_SPEED:
			return "Angriffstempo"
		CRIT_CHANCE:
			return "Krit. Chance"
		CRIT_DAMAGE:
			return "Krit. Schaden"
		ARMOR_PENETRATION:
			return "Rüstungsdurchdringung"
		KNOCKBACK_MODIFIER:
			return "Rückstoß"
		KNOCKBACK_RESISTANCE:
			return "Rückstoß-Resistenz"
		MINING_SPEED:
			return "Abbaugeschwindigkeit"
		WOODCUTTING_SPEED:
			return "Holzfäll-Geschwindigkeit"
		HARVEST_AMOUNT:
			return "Erntemenge"
		BUILDING_SPEED:
			return "Baugeschwindigkeit"
		REPAIR_SPEED:
			return "Reparaturgeschwindigkeit"
		FIRE_RESISTANCE:
			return "Feuer"
		COLD_RESISTANCE:
			return "Kälte"
		POISON_RESISTANCE:
			return "Gift"
		BLEEDING_RESISTANCE:
			return "Bluten"
		DARKNESS_RESISTANCE:
			return "Finsternis"
		_:
			return "Unbekannt"


static func all_ids() -> Array[int]:
	return [
		MAX_HEALTH, HEALTH_REGEN, MAX_STAMINA, STAMINA_REGEN, MAX_ENERGY,
		MOVEMENT_SPEED, SPRINT_SPEED, JUMP_POWER,
		ARMOR, DAMAGE_MULTIPLIER, ATTACK_SPEED, CRIT_CHANCE, CRIT_DAMAGE,
		ARMOR_PENETRATION, KNOCKBACK_MODIFIER, KNOCKBACK_RESISTANCE,
		MINING_SPEED, WOODCUTTING_SPEED, HARVEST_AMOUNT, BUILDING_SPEED, REPAIR_SPEED,
		FIRE_RESISTANCE, COLD_RESISTANCE, POISON_RESISTANCE, BLEEDING_RESISTANCE, DARKNESS_RESISTANCE,
	]
