class_name PickupTextSystem
extends CanvasLayer

## Kurze Pickup-Zeilen in Bildschirmkoordinaten, Zoom-entkoppelt wie CombatText.

const GROUP := &"pickup_text"
const MAX_LINES := 10
const STACK_Y := -13.0
const PLAYER_OFFSET := Vector2(0, -82)

var _pool: Array[PickupTextItem] = []
var _active: Array[PickupTextItem] = []
var _spawn_seq: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	layer = 18
	follow_viewport_enabled = false
	_build_pool()
	set_process(true)


func _build_pool() -> void:
	for i in MAX_LINES:
		var item := PickupTextItem.new()
		item.name = "PickupText_%d" % i
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(item)
		_pool.append(item)


static func instance(from: Node = null) -> PickupTextSystem:
	var tree: SceneTree = null
	if from != null:
		tree = from.get_tree()
	elif Engine.get_main_loop() is SceneTree:
		tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP) as PickupTextSystem


static func present(from: Node, item_id: int, amount: int, item: ItemData = null) -> void:
	if item_id < 0 or amount <= 0:
		return
	var sys := instance(from)
	if sys == null:
		return
	sys._present(from, item_id, amount, item)


static func anchor_of(from: Node) -> Vector2:
	if from == null or not is_instance_valid(from):
		return Vector2.ZERO
	var node: Node = from
	if from is Inventory:
		node = from.get_parent()
	if node is Player:
		return (node as Node2D).global_position + PLAYER_OFFSET
	if node is Node2D:
		return (node as Node2D).global_position + Vector2(0, -48)
	return Vector2.ZERO


func _present(from: Node, item_id: int, amount: int, item: ItemData) -> void:
	var origin := anchor_of(from)
	for existing in _active:
		if existing != null and existing.active and existing.item_id == item_id:
			existing.add_amount(amount, item)
			existing.world_pos = origin
			return
	var line := _acquire()
	if line == null:
		return
	line.spawn_order = _spawn_seq
	_spawn_seq += 1
	var stacked := origin + Vector2(0.0, STACK_Y * float(_active.size()))
	line.activate(item_id, amount, item, stacked)
	if line not in _active:
		_active.append(line)


func _acquire() -> PickupTextItem:
	for item in _pool:
		if item != null and not item.active:
			return item
	if _active.is_empty():
		return _pool[0] if not _pool.is_empty() else null
	var oldest: PickupTextItem = _active[0]
	for item in _active:
		if item.spawn_order < oldest.spawn_order:
			oldest = item
	oldest.deactivate()
	_active.erase(oldest)
	return oldest


func _process(delta: float) -> void:
	var ui := 1.0
	if SettingsManager != null and SettingsManager.has_method("get_ui_scale"):
		ui = maxf(SettingsManager.get_ui_scale(), 0.001)
	var xform := get_viewport().get_canvas_transform()
	var i := 0
	while i < _active.size():
		var item: PickupTextItem = _active[i]
		if item == null or not item.tick(delta, xform, ui):
			_active.remove_at(i)
			continue
		i += 1
