@tool
class_name WeaponData
extends Resource

## Unveraenderliche Kampfwerte einer Waffe. Der Typ liegt auf ItemData.WeaponKind.
## Weitere Arten koennen spaeter ans ItemData-Enum angehaengt werden.

@export var tier: int = 1
@export var base_damage: int = 0
@export var attack_speed: float = 1.0
@export var base_range: float = 2.5
@export var knockback: float = 110.0
@export var base_max_durability: int = 100
## -1 = keine Munition. Pfeile nutzen vorhandene Item-IDs.
@export var ammo_item_id: int = -1
@export var projectile_speed: float = 0.0
## Extra-Schaden durch Munition. 0 = nur Waffenschaden, falls Munition 0 Schaden hat.
@export var projectile_damage_bonus: int = 0
## Zeit bis der Bogen voll aufgezogen ist. 0 = 0.55 s.
@export var draw_time: float = 0.55
## Linksklick-Schnellschuss, relativ zu Bogen+Pfeil. Volle Reichweite, weniger Schaden.
@export var quick_shot_damage_mult: float = 0.5
## Schaden bei minimaler Rechtsklick-Ladung, relativ zu Bogen+Pfeil.
@export var charge_damage_min: float = 0.85
## Schaden bei voller Rechtsklick-Ladung, relativ zu Bogen+Pfeil.
@export var charge_damage_max: float = 1.55
## Pfeilschwerkraft in px/s². 0 = kein Bogen.
@export var projectile_gravity: float = 820.0
## 1.0 = kein Bonus. Zentraler Finsternis-Multiplikator, nicht in Gegner-Scripts.
@export var darkness_damage_multiplier: float = 1.0
## 0 = 1 / attack_speed. Kampf-Laterne nutzt einen klaren Cooldown.
@export var cooldown: float = 0.0
## Vorbereitet fuer Energie/Brennstoff. 0 = in Version 1 ungenutzt.
@export var energy_cost: float = 0.0
@export var special: String = ""


func get_attack_cooldown() -> float:
	if cooldown > 0.0:
		return cooldown
	if attack_speed <= 0.0:
		return 0.35
	return 1.0 / attack_speed


func uses_ammo() -> bool:
	return ammo_item_id >= 0


func uses_projectile() -> bool:
	return ammo_item_id >= 0 or projectile_speed > 0.0


func get_draw_time() -> float:
	return draw_time if draw_time > 0.0 else 0.55


func get_flight_distance(tile_size: float = 16.0) -> float:
	return maxf(base_range, 0.5) * tile_size


func get_projectile_gravity() -> float:
	return projectile_gravity if projectile_gravity > 0.0 else 0.0


func scale_charge_damage(damage: int, charge: float) -> int:
	var t := clampf(charge, 0.0, 1.0)
	var min_m := charge_damage_min if charge_damage_min > 0.0 else 0.85
	var max_m := charge_damage_max if charge_damage_max > 0.0 else 1.55
	return maxi(int(round(float(damage) * lerpf(min_m, max_m, t))), 1)


func scale_quick_damage(damage: int) -> int:
	var mult := quick_shot_damage_mult if quick_shot_damage_mult > 0.0 else 0.5
	return maxi(int(round(float(damage) * mult)), 1)


func get_quick_shot_cooldown() -> float:
	return maxf(0.2, get_attack_cooldown() * 0.28)
