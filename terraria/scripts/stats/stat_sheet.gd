class_name StatSheet
extends RefCounted

## Rechnet BASE + FLAT, danach * (1 + Summe PERCENT).
## Beispiel Tempo 1.0 + 10% + 20% = 1.30.

signal changed

var _bases: Dictionary = {}
var _modifiers: Array[StatModifier] = []


func set_base(stat: int, value: float) -> void:
	if _bases.get(stat, INF) == value:
		return
	_bases[stat] = value
	changed.emit()


func get_base(stat: int) -> float:
	return float(_bases.get(stat, 0.0))


func apply_defaults() -> void:
	_bases[StatId.MAX_HEALTH] = 100.0
	_bases[StatId.HEALTH_REGEN] = 0.0
	_bases[StatId.MAX_STAMINA] = 100.0
	_bases[StatId.STAMINA_REGEN] = 15.0
	_bases[StatId.MAX_ENERGY] = 100.0
	_bases[StatId.MOVEMENT_SPEED] = 1.0
	_bases[StatId.SPRINT_SPEED] = 1.5
	_bases[StatId.JUMP_POWER] = 1.0
	_bases[StatId.ARMOR] = 0.0
	_bases[StatId.DAMAGE_MULTIPLIER] = 1.0
	_bases[StatId.ATTACK_SPEED] = 1.0
	_bases[StatId.CRIT_CHANCE] = 0.05
	_bases[StatId.CRIT_DAMAGE] = 1.5
	_bases[StatId.ARMOR_PENETRATION] = 0.0
	_bases[StatId.KNOCKBACK_MODIFIER] = 1.0
	_bases[StatId.KNOCKBACK_RESISTANCE] = 0.0
	_bases[StatId.MINING_SPEED] = 1.0
	_bases[StatId.WOODCUTTING_SPEED] = 1.0
	_bases[StatId.HARVEST_AMOUNT] = 1.0
	_bases[StatId.BUILDING_SPEED] = 1.0
	_bases[StatId.REPAIR_SPEED] = 1.0
	_bases[StatId.FIRE_RESISTANCE] = 0.0
	_bases[StatId.COLD_RESISTANCE] = 0.0
	_bases[StatId.POISON_RESISTANCE] = 0.0
	_bases[StatId.BLEEDING_RESISTANCE] = 0.0
	_bases[StatId.DARKNESS_RESISTANCE] = 0.0
	changed.emit()


func add_modifier(mod: StatModifier) -> void:
	if mod == null:
		return
	_modifiers.append(mod)
	changed.emit()


func remove_by_source(source: StringName) -> void:
	var next: Array[StatModifier] = []
	for mod in _modifiers:
		if mod.source != source:
			next.append(mod)
	if next.size() == _modifiers.size():
		return
	_modifiers = next
	changed.emit()


func remove_by_source_kind(kind: StatModifier.SourceKind) -> void:
	var next: Array[StatModifier] = []
	for mod in _modifiers:
		if mod.source_kind != kind:
			next.append(mod)
	if next.size() == _modifiers.size():
		return
	_modifiers = next
	changed.emit()


func clear_modifiers() -> void:
	if _modifiers.is_empty():
		return
	_modifiers.clear()
	changed.emit()


func modifiers() -> Array[StatModifier]:
	return _modifiers


func get_final(stat: int) -> float:
	return _compute_final(stat, [])


func get_final_excluding_source_kinds(stat: int, excluded_kinds: Array) -> float:
	return _compute_final(stat, excluded_kinds)


func _compute_final(stat: int, excluded_kinds: Array) -> float:
	var base := get_base(stat)
	var flat := 0.0
	var percent := 0.0
	for mod in _modifiers:
		if mod == null or int(mod.stat) != stat or mod.is_expired():
			continue
		if not excluded_kinds.is_empty() and excluded_kinds.has(mod.source_kind):
			continue
		if mod.modifier_type == StatModifier.Type.PERCENT:
			percent += mod.value
		else:
			flat += mod.value
	return (base + flat) * (1.0 + percent)


func tick(delta: float) -> bool:
	var removed := false
	var next: Array[StatModifier] = []
	for mod in _modifiers:
		if mod == null:
			removed = true
			continue
		mod.tick(delta)
		if mod.is_expired():
			removed = true
			continue
		next.append(mod)
	if not removed:
		return false
	_modifiers = next
	changed.emit()
	return true


func timed_effects() -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	for mod in _modifiers:
		if mod != null and mod.is_timed() and not mod.is_expired():
			result.append(mod)
	return result


func to_save_dict() -> Dictionary:
	var timed: Array = []
	var upgrades: Array = []
	for mod in _modifiers:
		if mod == null:
			continue
		if mod.source_kind == StatModifier.SourceKind.UPGRADE:
			upgrades.append(mod.to_dict())
		elif mod.is_timed():
			timed.append(mod.to_dict())
	return {"timed": timed, "upgrades": upgrades}


static func modifiers_from_item(item: Resource) -> Array[StatModifier]:
	# Item.defense bleibt die einfache Ruestungsquelle.
	var result: Array[StatModifier] = []
	if item == null:
		return result
	var has_armor := false
	var listed: Variant = item.get("stat_modifiers")
	if listed is Array:
		for entry in listed:
			var mod := entry as StatModifier
			if mod == null:
				continue
			result.append(mod)
			if int(mod.stat) == StatId.ARMOR:
				has_armor = true
	var defense := int(item.get("defense"))
	if defense > 0 and not has_armor:
		var item_id := int(item.get("id"))
		result.append(StatModifier.new(StatId.ARMOR, float(defense), StatModifier.Type.FLAT, StringName("defense:%d" % item_id), StatModifier.SourceKind.EQUIPMENT))
	return result


func load_persistent(data: Dictionary) -> void:
	remove_by_source_kind(StatModifier.SourceKind.UPGRADE)
	remove_by_source_kind(StatModifier.SourceKind.BUFF)
	remove_by_source_kind(StatModifier.SourceKind.DEBUFF)
	remove_by_source_kind(StatModifier.SourceKind.CONSUMABLE)
	for entry in data.get("upgrades", []):
		if entry is Dictionary:
			add_modifier(StatModifier.from_dict(entry))
	for entry in data.get("timed", []):
		if entry is Dictionary:
			add_modifier(StatModifier.from_dict(entry))
