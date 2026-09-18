class_name CombatResolver
extends RefCounted

## Zentrale Treffer- und Schadensaufloesung fuer Werkzeuge und Waffen.

## Finsternis-Boni stehen auf WeaponData, nicht in Zombie- oder Player-Scripts.

static func is_darkness_target(target: Node) -> bool:
	if target == null:
		return false
	var flag: Variant = target.get("darkness_active")
	if typeof(flag) != TYPE_NIL:
		return bool(flag)
	if target.has_method("is_darkness_form"):
		return bool(target.call("is_darkness_form"))
	return false


static func resolve_damage(base_damage: int, weapon: Resource, target: Node) -> int:
	var dmg := maxi(base_damage, 0)
	if weapon == null or dmg <= 0:
		return dmg
	var mult := float(weapon.get("darkness_damage_multiplier"))
	if is_darkness_target(target) and mult > 0.0 and not is_equal_approx(mult, 1.0):
		return maxi(int(round(float(dmg) * mult)), 0)
	return dmg


static func combined_ranged_damage(weapon: Resource, ammo: ItemData) -> int:
	var bow := 0
	if weapon != null:
		bow = int(weapon.get("base_damage"))
	var arrow := 0
	if ammo != null:
		arrow = ammo.get_base_damage()
	elif weapon != null:
		arrow = int(weapon.get("projectile_damage_bonus"))
	return maxi(bow + arrow, 0)


static func charged_ranged_damage(weapon: Resource, ammo: ItemData, charge: float) -> int:
	var base := combined_ranged_damage(weapon, ammo)
	if weapon != null and weapon.has_method("scale_charge_damage"):
		return int(weapon.call("scale_charge_damage", base, charge))
	var t := clampf(charge, 0.0, 1.0)
	return maxi(int(round(float(base) * lerpf(0.85, 1.55, t))), 1)


static func quick_ranged_damage(weapon: Resource, ammo: ItemData) -> int:
	var base := combined_ranged_damage(weapon, ammo)
	if weapon != null and weapon.has_method("scale_quick_damage"):
		return int(weapon.call("scale_quick_damage", base))
	return maxi(int(round(float(base) * 0.5)), 1)


static func apply_hit(target: Node, amount: int, knockback_force: float, source: Node2D) -> bool:
	if target == null or amount <= 0:
		return false
	if not target.has_method("take_damage"):
		return false
	target.take_damage(amount, source)
	if knockback_force > 0.0 and target.has_method("apply_knockback") and source != null:
		var away: Vector2 = target.global_position - source.global_position
		if away == Vector2.ZERO:
			away = Vector2.RIGHT
		target.apply_knockback(away.normalized() * knockback_force)
	return true


static func find_damageable(node: Node) -> Node:
	var current := node
	for _i in 4:
		if current == null:
			break
		if current.has_method("get_hurtbox_owner"):
			current = current.get_hurtbox_owner()
			continue
		if current.has_method("take_damage"):
			return current
		current = current.get_parent()
	return null
