class_name CombatTextSystem
extends CanvasLayer

## Gepoolte Kampfzahlen in Bildschirmkoordinaten, Zoom-entkoppelt wie EnemyHealthBarManager.

const GROUP := &"combat_text"
const CONFIG_PATH := "res://resources/combat/combat_text_config.tres"

var config: CombatTextConfig

var _pool: Array[CombatTextItem] = []
var _active: Array[CombatTextItem] = []
var _stack: Dictionary = {}
var _spawn_seq: int = 0
var _now: float = 0.0
var _aggregator := CombatTextAggregator.new()


func _ready() -> void:
	add_to_group(GROUP)
	layer = 19
	follow_viewport_enabled = false
	if config == null:
		var settings := load("res://resources/systems/last_lantern_settings.tres") as LastLanternSettings
		if settings != null and settings.combat_text != null:
			config = settings.combat_text
	if config == null:
		config = load(CONFIG_PATH) as CombatTextConfig
	if config == null:
		config = CombatTextConfig.new()
	_aggregator.window = config.dot_aggregate_window
	_build_pool()
	set_process(true)


func _build_pool() -> void:
	var count := maxi(config.max_combat_text, 1)
	for i in count:
		var item := CombatTextItem.new()
		item.name = "CombatText_%d" % i
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(item)
		_pool.append(item)


static func instance(from: Node = null) -> CombatTextSystem:
	var tree: SceneTree = null
	if from != null:
		tree = from.get_tree()
	elif Engine.get_main_loop() is SceneTree:
		tree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(GROUP) as CombatTextSystem


static func present(event: DamageEvent) -> void:
	var sys := instance(event.target_node if event != null else null)
	if sys == null:
		return
	sys._present(event)


static func anchor_of(target: Node) -> Vector2:
	if target == null or not is_instance_valid(target):
		return Vector2.ZERO
	if target.has_method("get_combat_text_origin"):
		return target.call("get_combat_text_origin")
	if target.has_method("get_health_bar_world_position"):
		return target.call("get_health_bar_world_position") + Vector2(0, -14)
	if target is Node2D:
		var node := target as Node2D
		if target is Player:
			return node.global_position + Vector2(0, -58)
		return node.global_position + Vector2(0, -48)
	return Vector2.ZERO


func _present(event: DamageEvent) -> void:
	if event == null:
		return
	if event.world_position == Vector2.ZERO:
		event.world_position = anchor_of(event.target_node)
	for due_event in _aggregator.ingest(event, _now):
		_spawn(due_event)


func _spawn(event: DamageEvent) -> void:
	if event == null:
		return
	var item := _acquire()
	if item == null:
		return
	var origin := _offset_origin(event)
	item.spawn_order = _spawn_seq
	_spawn_seq += 1
	item.activate(
		CombatTextPresenter.display_text(event),
		CombatTextPresenter.color_for(event, config),
		CombatTextPresenter.font_size_for(event, config),
		origin,
		config,
		event.critical
	)
	if item not in _active:
		_active.append(item)


func _offset_origin(event: DamageEvent) -> Vector2:
	var origin := event.world_position
	var jitter := config.random_x_offset
	origin.x += randf_range(-jitter, jitter)
	var id := event.target_id()
	var used: Array = _stack.get(id, [])
	for p in used:
		if origin.distance_to(p) < 12.0:
			origin.x += config.stack_x
			origin.y += config.stack_y
	used.append(origin)
	if used.size() > 6:
		used.pop_front()
	_stack[id] = used
	return origin


func _acquire() -> CombatTextItem:
	for item in _pool:
		if item != null and not item.active:
			return item
	if _active.is_empty():
		return _pool[0] if not _pool.is_empty() else null
	var oldest: CombatTextItem = _active[0]
	for item in _active:
		if item.spawn_order < oldest.spawn_order:
			oldest = item
	oldest.deactivate()
	_active.erase(oldest)
	return oldest


func _process(delta: float) -> void:
	_now += delta
	for due_event in _aggregator.flush_due(_now):
		_spawn(due_event)
	var ui := 1.0
	if SettingsManager != null and SettingsManager.has_method("get_ui_scale"):
		ui = maxf(SettingsManager.get_ui_scale(), 0.001)
	var xform := get_viewport().get_canvas_transform()
	var i := 0
	while i < _active.size():
		var item: CombatTextItem = _active[i]
		if item == null or not item.tick(delta, xform, ui):
			_active.remove_at(i)
			continue
		i += 1


func debug_emit(origin: Vector2, amount: int, damage_type: int, critical: bool = false, player_target: bool = false, reduced: bool = false) -> void:
	var event := DamageEvent.new()
	event.amount = amount
	event.incoming_amount = amount
	event.damage_type = damage_type
	event.element = damage_type
	event.critical = critical
	event.is_player_target = player_target
	event.reduced = reduced
	event.blocked = amount <= 0
	event.world_position = origin
	_present(event)
