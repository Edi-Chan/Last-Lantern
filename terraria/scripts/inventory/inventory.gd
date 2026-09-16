class_name Inventory
extends Node

## Gehoert an: Player/Inventory in res://scenes/player/player.tscn
## Slots 0-9 sind die Hotbar, Slots 10-39 das Inventar. Eine Datenquelle.

signal inventory_changed
signal selected_slot_changed(index: int)
signal equipment_changed

const SLOT_COUNT := 40
const HOTBAR_COUNT := 10
const START_PICKAXE_ID := 22
const TEST_HELMET_ID := 4
const TEST_CHEST_ID := 5
const TEST_LEGS_ID := 21
const START_STONE_ID := 2
const DEV_WOOD_ID := 9
const DEV_WOOD_AMOUNT := 100
const DEV_SUPPORT_BEAM_ID := 60
const DEV_SUPPORT_BEAM_AMOUNT := 20
const START_TOOL_IDS := [22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32]
## Default-Hotbar nur fuer neues Spiel / Testcharakter. Reihenfolge entspricht der Toolbar 1-0.
## Sichel vor Angel, wie im bestehenden Werkzeugset vorgesehen. Scanner bleibt im Beutel.
const DEFAULT_HOTBAR_TOOL_IDS := [START_PICKAXE_ID, 23, 24, 25, 26, 28, 27, 29, 30, 31]

## Welcher ItemData.EquipmentSlot in welchen Equipment-Key passt.
const EQUIPMENT_TYPES := {
	"head": ItemData.EquipmentSlot.HEAD,
	"chest": ItemData.EquipmentSlot.CHEST,
	"legs": ItemData.EquipmentSlot.LEGS,
	"accessory_1": ItemData.EquipmentSlot.ACCESSORY,
	"accessory_2": ItemData.EquipmentSlot.ACCESSORY,
}

@export var item_catalog: ItemCatalog

var slots: Array[Dictionary] = []
var selected_hotbar_index: int = 0
var equipment: Dictionary = {}

func _ready() -> void:
	slots.resize(SLOT_COUNT)
	for i in SLOT_COUNT:
		slots[i] = _empty_slot()
	equipment = {
		"head": _empty_slot(),
		"chest": _empty_slot(),
		"legs": _empty_slot(),
		"accessory_1": _empty_slot(),
		"accessory_2": _empty_slot(),
	}
	add_to_group("player_inventory")
	_give_demo_armor_once()
	_give_demo_tools_once()
	_give_demo_stone_once()
	_give_lantern_upgrade_materials_once()
	_give_dev_structural_loadout_once()


func _empty_slot() -> Dictionary:
	return {
		"item_id": -1,
		"amount": 0,
		"favorite": false,
		"durability": -1,
		"upgrades": _empty_upgrades(),
	}


func _empty_upgrades() -> Dictionary:
	return {
		"damage_bonus": 0,
		"tool_power_bonus": 0,
		"speed_bonus": 0.0,
		"durability_bonus": 0,
		"range_bonus": 0.0,
	}


func set_selected_hotbar_index(index: int) -> void:
	var wrapped := wrapi(index, 0, HOTBAR_COUNT)
	if wrapped == selected_hotbar_index:
		return
	selected_hotbar_index = wrapped
	selected_slot_changed.emit(selected_hotbar_index)


func get_selected_item() -> ItemData:
	return get_item_in_slot(selected_hotbar_index)


func get_selected_instance() -> ItemInstanceData:
	return get_instance(selected_hotbar_index)


func get_item_in_slot(index: int) -> ItemData:
	var data := get_slot(index)
	var item_id := int(data["item_id"])
	var amount := int(data["amount"])
	if item_id < 0 or amount <= 0:
		return null
	return _get_item(item_id)


func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= slots.size():
		return _empty_slot()
	return slots[index]


## Erster freier Inventarslot ausserhalb der Hotbar, oder -1 wenn voll.
func find_first_empty_bag_slot() -> int:
	for i in range(HOTBAR_COUNT, SLOT_COUNT):
		if int(slots[i]["item_id"]) < 0 or int(slots[i]["amount"]) <= 0:
			return i
	return -1


## View-Drops ohne konkreten Slot landen im ersten freien Beutel-Slot.
func resolve_drop_ref(ref: Variant) -> Variant:
	if ref is int and int(ref) < 0:
		return find_first_empty_bag_slot()
	return ref


func consume_from_slot(index: int, amount: int = 1) -> bool:
	if index < 0 or index >= slots.size() or amount <= 0:
		return false
	var slot := slots[index]
	if int(slot["item_id"]) < 0 or int(slot["amount"]) < amount:
		return false
	slot["amount"] = int(slot["amount"]) - amount
	if int(slot["amount"]) <= 0:
		_clear(slot)
	inventory_changed.emit()
	return true


func add_item(item_id: int, amount: int = 1) -> bool:
	if item_id < 0 or amount <= 0:
		return false
	var item := _get_item(item_id)
	var max_stack := item.max_stack if item != null else 999
	var remaining := amount
	for slot in slots:
		if int(slot["item_id"]) != item_id:
			continue
		var space: int = max_stack - int(slot["amount"])
		if space <= 0:
			continue
		var added: int = mini(space, remaining)
		slot["amount"] = int(slot["amount"]) + added
		remaining -= added
		if remaining <= 0:
			inventory_changed.emit()
			return true
	for slot in slots:
		if int(slot["item_id"]) != -1:
			continue
		var added: int = mini(max_stack, remaining)
		slot["item_id"] = item_id
		slot["amount"] = added
		_init_instance(slot, item)
		remaining -= added
		if remaining <= 0:
			inventory_changed.emit()
			return true
	return false


func get_total_amount(item_id: int) -> int:
	var total := 0
	for slot in slots:
		if int(slot["item_id"]) == item_id:
			total += int(slot["amount"])
	for key in equipment.keys():
		var data: Dictionary = equipment[key]
		if int(data["item_id"]) == item_id:
			total += int(data["amount"])
	return total


func get_bag_amount(item_id: int) -> int:
	var total := 0
	for slot in slots:
		if int(slot["item_id"]) == item_id:
			total += int(slot["amount"])
	return total


func can_consume_items(costs: Array) -> bool:
	for cost in costs:
		if get_bag_amount(int(cost["item_id"])) < int(cost["amount"]):
			return false
	return true


func try_consume_items(costs: Array) -> bool:
	if not can_consume_items(costs):
		return false
	for cost in costs:
		var remaining := int(cost["amount"])
		var item_id := int(cost["item_id"])
		for slot in slots:
			if remaining <= 0:
				break
			if int(slot["item_id"]) != item_id:
				continue
			var take := mini(int(slot["amount"]), remaining)
			slot["amount"] = int(slot["amount"]) - take
			remaining -= take
			if int(slot["amount"]) <= 0:
				_clear(slot)
	inventory_changed.emit()
	return true


func get_total_defense() -> int:
	var total := 0
	for key in ["head", "chest", "legs"]:
		var item := get_equipment_item(key)
		if item != null:
			total += item.defense
	return total


func get_equipment_item(key: String) -> ItemData:
	if not equipment.has(key):
		return null
	var data: Dictionary = equipment[key]
	var item_id := int(data["item_id"])
	if item_id < 0 or int(data["amount"]) <= 0:
		return null
	return _get_item(item_id)


## --- Verschieben per Drag & Drop --------------------------------------------
##
## Eine Slot-Referenz ist entweder ein int (Inventarslot 0-39) oder ein String
## (Equipment-Key). Die Hotbar braucht keinen Sonderfall, weil sie dieselben
## Slots 0-9 benutzt wie das Inventar.

func get_ref_item(ref: Variant) -> ItemData:
	var stack := _stack_of(ref)
	if stack.is_empty() or int(stack["amount"]) <= 0:
		return null
	return _get_item(int(stack["item_id"]))


func get_ref_amount(ref: Variant) -> int:
	var stack := _stack_of(ref)
	return 0 if stack.is_empty() else int(stack["amount"])


func has_open_storage() -> bool:
	return false


func find_equipment_key(item: ItemData) -> String:
	if item == null:
		return ""
	match item.equipment_slot:
		ItemData.EquipmentSlot.HEAD:
			return "head"
		ItemData.EquipmentSlot.CHEST:
			return "chest"
		ItemData.EquipmentSlot.LEGS:
			return "legs"
		ItemData.EquipmentSlot.ACCESSORY:
			if int(equipment["accessory_1"]["amount"]) <= 0:
				return "accessory_1"
			if int(equipment["accessory_2"]["amount"]) <= 0:
				return "accessory_2"
			return "accessory_1"
		_:
			return ""


## Equipment-Slots nehmen nur den passenden Itemtyp an, Inventarslots alles.
func accepts(ref: Variant, item: ItemData) -> bool:
	if item == null:
		return true
	if ref is int:
		if int(ref) < 0:
			return find_first_empty_bag_slot() >= 0
		return true
	var key := str(ref)
	if not EQUIPMENT_TYPES.has(key):
		return false
	return item.equipment_slot == EQUIPMENT_TYPES[key]


## Leeres Ziel -> verschieben, gleiches Item -> stapeln, sonst tauschen.
## Gibt true zurueck, wenn sich etwas geaendert hat.
func transfer(from_ref: Variant, to_ref: Variant) -> bool:
	to_ref = resolve_drop_ref(to_ref)
	if to_ref is int and int(to_ref) < 0:
		return false
	if _same_ref(from_ref, to_ref):
		return false
	var source := _stack_of(from_ref)
	var target := _stack_of(to_ref)
	if source.is_empty() or target.is_empty():
		return false
	var source_item := _get_item(int(source["item_id"]))
	if source_item == null or int(source["amount"]) <= 0:
		return false
	if not accepts(to_ref, source_item):
		return false
	var target_item := _get_item(int(target["item_id"])) if int(target["amount"]) > 0 else null
	# Ein Tausch muss in beide Richtungen erlaubt sein.
	if target_item != null and not accepts(from_ref, target_item):
		return false

	if target_item == null:
		_write(target, int(source["item_id"]), int(source["amount"]), _snapshot_instance(source))
		_clear(source)
	elif int(target["item_id"]) == int(source["item_id"]) and source_item.max_stack > 1:
		var space: int = source_item.max_stack - int(target["amount"])
		if space <= 0:
			return false
		var moved: int = mini(space, int(source["amount"]))
		target["amount"] = int(target["amount"]) + moved
		source["amount"] = int(source["amount"]) - moved
		if bool(source.get("favorite", false)):
			target["favorite"] = true
		if int(source["amount"]) <= 0:
			_clear(source)
	else:
		var carry_id := int(target["item_id"])
		var carry_amount := int(target["amount"])
		var source_inst := _snapshot_instance(source)
		var target_inst := _snapshot_instance(target)
		_write(target, int(source["item_id"]), int(source["amount"]), source_inst)
		_write(source, carry_id, carry_amount, target_inst)

	_emit_for(from_ref, to_ref)
	return true


## Liefert das echte Dictionary, damit Aenderungen direkt im Inventar landen.
func _stack_of(ref: Variant) -> Dictionary:
	if ref is int:
		var index := int(ref)
		if index < 0 or index >= slots.size():
			return {}
		return slots[index]
	var key := str(ref)
	return equipment[key] if equipment.has(key) else {}


func _same_ref(a: Variant, b: Variant) -> bool:
	if a is int and b is int:
		return int(a) == int(b)
	if not (a is int) and not (b is int):
		return str(a) == str(b)
	return false


func _write(stack: Dictionary, item_id: int, amount: int, instance: Dictionary = {}) -> void:
	stack["item_id"] = item_id
	stack["amount"] = amount
	_apply_instance(stack, instance)


func _clear(stack: Dictionary) -> void:
	stack["item_id"] = -1
	stack["amount"] = 0
	stack["favorite"] = false
	stack["durability"] = -1
	stack["upgrades"] = _empty_upgrades()


func _init_instance(stack: Dictionary, item: ItemData) -> void:
	var inst := ItemInstanceData.from_item(item)
	_apply_instance(stack, inst.to_slot_fields())


func _snapshot_instance(stack: Dictionary) -> Dictionary:
	return {
		"favorite": bool(stack.get("favorite", false)),
		"durability": int(stack.get("durability", -1)),
		"upgrades": (stack.get("upgrades", _empty_upgrades()) as Dictionary).duplicate(true),
	}


func _apply_instance(stack: Dictionary, instance: Dictionary) -> void:
	stack["favorite"] = bool(instance.get("favorite", false))
	stack["durability"] = int(instance.get("durability", -1))
	var upgrades: Dictionary = instance.get("upgrades", _empty_upgrades()) as Dictionary
	stack["upgrades"] = (upgrades as Dictionary).duplicate(true)


func is_favorite(ref: Variant) -> bool:
	var stack := _stack_of(ref)
	return not stack.is_empty() and bool(stack.get("favorite", false))


func set_favorite(ref: Variant, favorite: bool) -> bool:
	var stack := _stack_of(ref)
	if stack.is_empty() or int(stack["amount"]) <= 0:
		return false
	stack["favorite"] = favorite
	_emit_for(ref, ref)
	return true


func get_instance(ref: Variant) -> ItemInstanceData:
	var stack := _stack_of(ref)
	if stack.is_empty():
		return ItemInstanceData.new()
	return ItemInstanceData.from_slot(stack)


func find_best_hotbar_tool_for(block: BlockData, preferred_kind: int = 0) -> int:
	if block == null:
		return -1
	var best_slot := -1
	var best_kind_match := -1
	var best_power := -1
	var best_durability := -1
	for i in HOTBAR_COUNT:
		var item := get_item_in_slot(i)
		if item == null:
			continue
		if int(item.tool_kind) == int(ItemData.ToolKind.NONE):
			continue
		var inst := get_instance(i)
		if inst != null and inst.durability == 0:
			continue
		if block.evaluate_break(item, inst) != BlockData.BreakCheck.CAN_BREAK:
			continue
		var kind_match := 1 if preferred_kind != 0 and int(item.tool_kind) == preferred_kind else 0
		var power := inst.effective_tool_power(item) if inst != null else item.get_base_tool_power()
		var durability := inst.durability if inst != null else -1
		var better := false
		if kind_match > best_kind_match:
			better = true
		elif kind_match == best_kind_match and power > best_power:
			better = true
		elif kind_match == best_kind_match and power == best_power and durability > best_durability:
			better = true
		if better:
			best_slot = i
			best_kind_match = kind_match
			best_power = power
			best_durability = durability
	return best_slot


func find_first_empty_hotbar_slot() -> int:
	for i in HOTBAR_COUNT:
		if int(slots[i]["item_id"]) < 0 or int(slots[i]["amount"]) <= 0:
			return i
	return -1


func find_first_empty_slot() -> int:
	var bag := find_first_empty_bag_slot()
	if bag >= 0:
		return bag
	return find_first_empty_hotbar_slot()


func move_to_hotbar(from_ref: Variant) -> bool:
	if from_ref is int and int(from_ref) >= 0 and int(from_ref) < HOTBAR_COUNT:
		return false
	var empty := find_first_empty_hotbar_slot()
	if empty < 0:
		return false
	return transfer(from_ref, empty)


func split_stack(from_ref: Variant, amount: int) -> bool:
	var source := _stack_of(from_ref)
	if source.is_empty():
		return false
	var total := int(source["amount"])
	if total < 2 or amount < 1 or amount >= total:
		return false
	var empty := find_first_empty_slot()
	if empty < 0:
		return false
	var item := _get_item(int(source["item_id"]))
	if item == null:
		return false
	var target := slots[empty]
	target["item_id"] = int(source["item_id"])
	target["amount"] = amount
	_init_instance(target, item)
	target["favorite"] = false
	source["amount"] = total - amount
	_emit_for(from_ref, empty)
	return true


func take_stack(ref: Variant) -> Dictionary:
	var source := _stack_of(ref)
	if source.is_empty() or int(source["amount"]) <= 0:
		return {}
	if bool(source.get("favorite", false)):
		return {}
	var snapshot := {
		"item_id": int(source["item_id"]),
		"amount": int(source["amount"]),
		"instance": _snapshot_instance(source),
	}
	_clear(source)
	_emit_for(ref, ref)
	return snapshot


func _emit_for(from_ref: Variant, to_ref: Variant) -> void:
	if from_ref is int or to_ref is int:
		inventory_changed.emit()
	if not (from_ref is int) or not (to_ref is int):
		equipment_changed.emit()


func _get_item(item_id: int) -> ItemData:
	if item_catalog == null:
		return null
	return item_catalog.get_item(item_id)


func _give_demo_armor_once() -> void:
	for item_id in [TEST_HELMET_ID, TEST_CHEST_ID, TEST_LEGS_ID]:
		if get_total_amount(item_id) > 0:
			continue
		_add_item_to_bag(item_id, 1)


func _give_demo_tools_once() -> void:
	_apply_default_hotbar_loadout()
	for item_id in START_TOOL_IDS:
		if get_total_amount(item_id) > 0:
			continue
		_add_item_to_bag(item_id, 1)
	inventory_changed.emit()


## Fuellt nur LEERE Hotbar-Slots. Belegte Slots (Savegame/manuelles Layout) bleiben.
## Vorhandene Instanzen werden aus dem Beutel verschoben, nie dupliziert.
func _apply_default_hotbar_loadout() -> void:
	for i in DEFAULT_HOTBAR_TOOL_IDS.size():
		if i >= HOTBAR_COUNT:
			break
		var item_id := int(DEFAULT_HOTBAR_TOOL_IDS[i])
		var slot := slots[i]
		if int(slot["item_id"]) >= 0 and int(slot["amount"]) > 0:
			continue
		if _hotbar_contains(item_id):
			continue
		var bag_slot := _find_bag_slot_with_item(item_id)
		if bag_slot >= 0:
			transfer(bag_slot, i)
			continue
		_put_item_in_empty_slot(i, item_id)


func _hotbar_contains(item_id: int) -> bool:
	for i in HOTBAR_COUNT:
		if int(slots[i]["item_id"]) == item_id and int(slots[i]["amount"]) > 0:
			return true
	return false


func _find_bag_slot_with_item(item_id: int) -> int:
	for i in range(HOTBAR_COUNT, SLOT_COUNT):
		if int(slots[i]["item_id"]) == item_id and int(slots[i]["amount"]) > 0:
			return i
	return -1


func _put_item_in_empty_slot(index: int, item_id: int) -> void:
	if index < 0 or index >= slots.size() or item_id < 0:
		return
	var slot := slots[index]
	if int(slot["item_id"]) >= 0 and int(slot["amount"]) > 0:
		return
	var item := _get_item(item_id)
	slot["item_id"] = item_id
	slot["amount"] = 1
	_init_instance(slot, item)


func _give_demo_stone_once() -> void:
	if get_total_amount(START_STONE_ID) > 0:
		return
	_add_item_to_bag(START_STONE_ID, 20)


## Kein Crafting-System vorhanden: 100 Wood + 20 Holzstuetzen, nur wenn der Bestand darunter liegt.
func _give_dev_structural_loadout_once() -> void:
	_ensure_total_at_least(DEV_WOOD_ID, DEV_WOOD_AMOUNT)
	_ensure_total_at_least(DEV_SUPPORT_BEAM_ID, DEV_SUPPORT_BEAM_AMOUNT)


func _ensure_total_at_least(item_id: int, amount: int) -> void:
	var have := get_total_amount(item_id)
	if have >= amount:
		return
	_add_item_to_bag(item_id, amount - have)


func _give_lantern_upgrade_materials_once() -> void:
	## Testvorrat fuer Laternen-Upgrades. Nur Beutel, keine neuen Itemtypen.
	var packs := [
		[9, 80],
		[2, 80],
		[11, 50],
		[12, 40],
		[13, 40],
	]
	for pack in packs:
		var item_id := int(pack[0])
		var amount := int(pack[1])
		if get_bag_amount(item_id) >= amount:
			continue
		_add_item_to_bag(item_id, amount - get_bag_amount(item_id))


## Demo-Ruestung landet im Beutel, nicht in der Hotbar, damit Search/Filter greifen.
func _add_item_to_bag(item_id: int, amount: int = 1) -> bool:
	if item_id < 0 or amount <= 0:
		return false
	var item := _get_item(item_id)
	var max_stack := item.max_stack if item != null else 999
	var remaining := amount
	for i in range(HOTBAR_COUNT, SLOT_COUNT):
		var slot := slots[i]
		if int(slot["item_id"]) != item_id:
			continue
		var space: int = max_stack - int(slot["amount"])
		if space <= 0:
			continue
		var added: int = mini(space, remaining)
		slot["amount"] = int(slot["amount"]) + added
		remaining -= added
		if remaining <= 0:
			inventory_changed.emit()
			return true
	for i in range(HOTBAR_COUNT, SLOT_COUNT):
		var slot := slots[i]
		if int(slot["item_id"]) != -1:
			continue
		var added: int = mini(max_stack, remaining)
		slot["item_id"] = item_id
		slot["amount"] = added
		_init_instance(slot, item)
		remaining -= added
		if remaining <= 0:
			inventory_changed.emit()
			return true
	return false
