class_name PlayerStats
extends Node

## Gehoert an: Player/Stats in res://scenes/player/player.tscn
##
## Einzige Quelle der Charakterwerte. Endwerte kommen aus StatSheet
## (Base + Ausrüstung + Buffs). HUD hängt weiter an den Signalen.

signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal energy_changed(current: float, maximum: float)
signal stats_changed
## Fuer diese Phase nur ein Hinweis nach aussen, kein Death-/Respawn-System.
signal depleted

@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
## Dritter Charakterwert. Das Projekt hatte bisher keinen, daher Energy.
@export var max_energy: float = 100.0

var health: float = 100.0
var stamina: float = 100.0
var energy: float = 100.0
var armor_defense: int = 0
var sheet: StatSheet = StatSheet.new()
var playtime_seconds: float = 0.0
var enemies_killed: int = 0
var blocks_mined: int = 0
var items_found: int = 0

func _ready() -> void:
	add_to_group("player_stats")
	sheet.apply_defaults()
	if not sheet.changed.is_connected(_on_sheet_changed):
		sheet.changed.connect(_on_sheet_changed)
	_sync_caps_from_sheet(true)
	call_deferred("_rebuild_from_owner")


func _process(delta: float) -> void:
	playtime_seconds += delta
	if sheet.tick(delta):
		pass
	var regen := sheet.get_final(StatId.HEALTH_REGEN)
	if regen > 0.0 and health < max_health:
		set_health(health + regen * delta)


func _rebuild_from_owner() -> void:
	var inventory := get_parent().get_node_or_null("Inventory") as Inventory if get_parent() != null else null
	rebuild_from_inventory(inventory)


func _on_sheet_changed() -> void:
	_sync_caps_from_sheet(false)
	stats_changed.emit()


func _sync_caps_from_sheet(fill: bool) -> void:
	max_health = maxf(sheet.get_final(StatId.MAX_HEALTH), 1.0)
	max_stamina = maxf(sheet.get_final(StatId.MAX_STAMINA), 1.0)
	max_energy = maxf(sheet.get_final(StatId.MAX_ENERGY), 1.0)
	armor_defense = maxi(int(round(sheet.get_final(StatId.ARMOR))), 0)
	if fill:
		health = max_health
		stamina = max_stamina
		energy = max_energy
	else:
		health = clampf(health, 0.0, max_health)
		stamina = clampf(stamina, 0.0, max_stamina)
		energy = clampf(energy, 0.0, max_energy)
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)
	energy_changed.emit(energy, max_energy)


func rebuild_from_inventory(inventory: Inventory) -> void:
	sheet.remove_by_source_kind(StatModifier.SourceKind.EQUIPMENT)
	sheet.remove_by_source_kind(StatModifier.SourceKind.ACCESSORY)
	if inventory == null:
		_sync_caps_from_sheet(false)
		return
	for key in inventory.equipment.keys():
		var item := inventory.get_equipment_item(str(key))
		if item == null:
			continue
		var kind := StatModifier.SourceKind.ACCESSORY if str(key).begins_with("accessory") else StatModifier.SourceKind.EQUIPMENT
		for mod in StatSheet.modifiers_from_item(item):
			var copy := mod.duplicate_runtime()
			copy.source = StringName("equip:%s" % key)
			copy.source_kind = kind
			copy.duration = -1.0
			copy.remaining = -1.0
			sheet.add_modifier(copy)


func add_timed_modifier(mod: StatModifier) -> void:
	if mod == null:
		return
	var copy := mod.duplicate_runtime()
	if copy.remaining < 0.0:
		copy.remaining = copy.duration
	sheet.add_modifier(copy)


func get_final(stat: int) -> float:
	return sheet.get_final(stat)


func movement_multiplier() -> float:
	return maxf(sheet.get_final(StatId.MOVEMENT_SPEED), 0.05)


func sprint_multiplier() -> float:
	return maxf(sheet.get_final(StatId.SPRINT_SPEED), 1.0)


func jump_multiplier() -> float:
	return maxf(sheet.get_final(StatId.JUMP_POWER), 0.05)


func stamina_regen_rate() -> float:
	return maxf(sheet.get_final(StatId.STAMINA_REGEN), 0.0)


func damage_multiplier() -> float:
	return maxf(sheet.get_final(StatId.DAMAGE_MULTIPLIER), 0.0)


func attack_speed() -> float:
	return maxf(sheet.get_final(StatId.ATTACK_SPEED), 0.05)


func crit_chance() -> float:
	return clampf(sheet.get_final(StatId.CRIT_CHANCE), 0.0, 1.0)


func crit_multiplier() -> float:
	return maxf(sheet.get_final(StatId.CRIT_DAMAGE), 1.0)


func knockback_modifier() -> float:
	return maxf(sheet.get_final(StatId.KNOCKBACK_MODIFIER), 0.0)


func knockback_resistance() -> float:
	return clampf(sheet.get_final(StatId.KNOCKBACK_RESISTANCE), 0.0, 1.0)


func mining_speed() -> float:
	return maxf(sheet.get_final(StatId.MINING_SPEED), 0.05)


func woodcutting_speed() -> float:
	return maxf(sheet.get_final(StatId.WOODCUTTING_SPEED), 0.05)


func harvest_amount() -> float:
	return maxf(sheet.get_final(StatId.HARVEST_AMOUNT), 0.0)


func resistance_for(damage_type: int) -> float:
	match damage_type:
		DamageTypes.Type.FIRE:
			return clampf(sheet.get_final(StatId.FIRE_RESISTANCE), 0.0, 0.9)
		DamageTypes.Type.FROST:
			return clampf(sheet.get_final(StatId.COLD_RESISTANCE), 0.0, 0.9)
		DamageTypes.Type.POISON:
			return clampf(sheet.get_final(StatId.POISON_RESISTANCE), 0.0, 0.9)
		DamageTypes.Type.BLEED:
			return clampf(sheet.get_final(StatId.BLEEDING_RESISTANCE), 0.0, 0.9)
		DamageTypes.Type.DARKNESS:
			return clampf(sheet.get_final(StatId.DARKNESS_RESISTANCE), 0.0, 0.9)
		_:
			return 0.0


func combat_snapshot(item: ItemData = null) -> Dictionary:
	var base_damage := 7
	var weapon_kb := 70.0
	var weapon_range := 1.8
	if item != null:
		base_damage = maxi(item.get_base_damage(), 0)
		weapon_kb = item.get_weapon_knockback() if item.has_method("get_weapon_knockback") else item.knockback
		if item.has_method("get_base_range") and item.get_base_range() > 0.0:
			weapon_range = item.get_base_range()
	var final_damage := maxi(int(round(float(base_damage) * damage_multiplier())), 0)
	return {
		"base_damage": base_damage,
		"damage": final_damage,
		"attack_speed": attack_speed(),
		"crit_chance": crit_chance(),
		"crit_damage": crit_multiplier(),
		"knockback": weapon_kb * knockback_modifier(),
		"range": weapon_range,
		"armor_pen": sheet.get_final(StatId.ARMOR_PENETRATION),
	}


## Die HUD ruft das nach dem Verbinden auf, damit sie sofort 100/100 zeigt und
## nicht erst auf die erste Aenderung warten muss.
func emit_all() -> void:
	health_changed.emit(health, max_health)
	stamina_changed.emit(stamina, max_stamina)
	energy_changed.emit(energy, max_energy)
	stats_changed.emit()


func set_health(value: float) -> void:
	var clamped := clampf(value, 0.0, max_health)
	if is_equal_approx(clamped, health):
		return
	health = clamped
	health_changed.emit(health, max_health)
	if health <= 0.0:
		depleted.emit()


func set_stamina(value: float) -> void:
	var clamped := clampf(value, 0.0, max_stamina)
	if is_equal_approx(clamped, stamina):
		return
	stamina = clamped
	stamina_changed.emit(stamina, max_stamina)


func set_energy(value: float) -> void:
	var clamped := clampf(value, 0.0, max_energy)
	if is_equal_approx(clamped, energy):
		return
	energy = clamped
	energy_changed.emit(energy, max_energy)


func take_damage(amount: float, ignore_armor: bool = false) -> void:
	apply_incoming_damage(amount, ignore_armor)


func apply_incoming_damage(amount: float, ignore_armor: bool = false, damage_type: int = DamageTypes.Type.PHYSICAL) -> Dictionary:
	if _admin_blocks_damage():
		return {
			"incoming": maxf(amount, 0.0),
			"applied": 0.0,
			"reduced": false,
			"blocked": true,
		}
	var incoming := maxf(amount, 0.0)
	var after_armor := incoming if ignore_armor else maxf(incoming - float(armor_defense), 0.0)
	var resist := resistance_for(damage_type)
	var final := after_armor * (1.0 - resist)
	var before := health
	if final > 0.0:
		set_health(health - final)
	var applied := before - health
	return {
		"incoming": incoming,
		"applied": applied,
		"reduced": (not ignore_armor and armor_defense > 0 and after_armor < incoming) or (resist > 0.0 and final < after_armor),
		"blocked": incoming > 0.0 and applied <= 0.0,
	}


func set_armor_defense(value: int) -> void:
	armor_defense = maxi(value, 0)


func heal(amount: float) -> float:
	if amount <= 0.0:
		return 0.0
	var before := health
	set_health(health + amount)
	return health - before


func drain_stamina(amount: float) -> void:
	if _admin_skips_stamina():
		return
	set_stamina(stamina - amount)


func restore_stamina(amount: float) -> void:
	set_stamina(stamina + amount)


func drain_energy(amount: float) -> void:
	if _admin_skips_energy():
		return
	set_energy(energy - amount)


func restore_energy(amount: float) -> void:
	set_energy(energy + amount)


func note_enemy_killed() -> void:
	enemies_killed += 1
	stats_changed.emit()


func note_block_mined() -> void:
	blocks_mined += 1
	stats_changed.emit()


func note_items_found(amount: int) -> void:
	if amount <= 0:
		return
	items_found += amount
	stats_changed.emit()


func to_save_dict() -> Dictionary:
	return {
		"health": health,
		"stamina": stamina,
		"energy": energy,
		"playtime": playtime_seconds,
		"enemies_killed": enemies_killed,
		"blocks_mined": blocks_mined,
		"items_found": items_found,
		"sheet": sheet.to_save_dict(),
	}


func from_save_dict(data: Dictionary) -> void:
	if data.has("sheet") and data["sheet"] is Dictionary:
		sheet.load_persistent(data["sheet"])
	_sync_caps_from_sheet(false)
	if data.has("health"):
		set_health(float(data["health"]))
	if data.has("stamina"):
		set_stamina(float(data["stamina"]))
	if data.has("energy"):
		set_energy(float(data["energy"]))
	playtime_seconds = float(data.get("playtime", playtime_seconds))
	enemies_killed = int(data.get("enemies_killed", enemies_killed))
	blocks_mined = int(data.get("blocks_mined", blocks_mined))
	items_found = int(data.get("items_found", items_found))


func _admin_node() -> Node:
	return get_node_or_null("/root/AdminManager")


func _admin_blocks_damage() -> bool:
	var admin := _admin_node()
	return admin != null and bool(admin.call("should_block_damage"))


func _admin_skips_stamina() -> bool:
	var admin := _admin_node()
	return admin != null and bool(admin.call("should_skip_stamina_drain"))


func _admin_skips_energy() -> bool:
	var admin := _admin_node()
	return admin != null and bool(admin.call("should_skip_energy_drain"))
