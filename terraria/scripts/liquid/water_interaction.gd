class_name WaterInteraction
extends Node

## Player-Wassererkennung, Schwimmen, Atem und Ertrinken.

signal water_entered
signal water_exited
signal head_submerged
signal head_emerged
signal breath_changed(current: float, maximum: float)
signal drowning_started
signal drowning_stopped

enum DepthState { DRY, FEET, WAIST, SWIMMING, HEAD_UNDER }

@export var head_offset_y: float = -38.0
@export var body_offset_y: float = -21.0

var depth_state: int = DepthState.DRY
var in_water: bool = false
var swimming: bool = false
var head_underwater: bool = false
var breath: float = 100.0
var max_breath: float = 100.0

var _player: Player
var _liquid: LiquidSystem
var _settings: LiquidSettings
var _was_in_water: bool = false
var _was_head_under: bool = false
var _drowning: bool = false
var _drown_timer: float = 0.0
var _bubble_timer: float = 0.0
var _renderer: LiquidRenderer
var _underwater_overlay: ColorRect


func _ready() -> void:
	_player = get_parent() as Player
	call_deferred("_bind")


func _bind() -> void:
	_liquid = get_tree().get_first_node_in_group(LiquidSystem.GROUP) as LiquidSystem
	if _liquid != null:
		_settings = _liquid.settings
		_renderer = _liquid.get_node_or_null("LiquidRenderer") as LiquidRenderer
	if _settings != null:
		max_breath = _settings.max_breath
		breath = max_breath


func _physics_process(delta: float) -> void:
	if _player == null or _liquid == null or _settings == null:
		return
	_update_water_state()
	_update_breath(delta)
	_update_drowning(delta)
	_update_bubbles(delta)


func get_movement_multipliers() -> Dictionary:
	if not in_water:
		return {"speed": 1.0, "gravity": 1.0, "max_fall": 1.0, "sprint_allowed": true}
	if swimming:
		return {
			"speed": _settings.deep_water_speed_multiplier,
			"gravity": _settings.water_gravity_multiplier,
			"max_fall": _settings.water_max_fall_multiplier,
			"sprint_allowed": false,
		}
	return {
		"speed": _settings.shallow_water_speed_multiplier,
		"gravity": 1.0,
		"max_fall": 1.0,
		"sprint_allowed": true,
	}


func apply_swim_forces(delta: float) -> void:
	if _player == null or not swimming:
		return
	var drag_h := _settings.water_drag_horizontal
	var drag_v := _settings.water_drag_vertical
	_player.velocity.x = move_toward(_player.velocity.x, 0.0, drag_h * delta * 60.0)
	_player.velocity.y = move_toward(_player.velocity.y, 0.0, drag_v * delta * 60.0)
	if _player.world_input_enabled and Input.is_action_pressed("jump"):
		_player.velocity.y -= _settings.swim_force * delta
		_player.velocity.y = maxf(_player.velocity.y, -_settings.swim_max_up_speed)
		if _player.stats != null and _settings.swim_stamina_cost > 0.0:
			_player.stats.drain_stamina(_settings.swim_stamina_cost * delta)


func apply_water_gravity_multiplier(base_gravity: float, delta: float) -> float:
	if not in_water:
		return base_gravity
	var mult := get_movement_multipliers()
	var g := base_gravity * float(mult["gravity"])
	if swimming and not Input.is_action_pressed("jump"):
		g *= 0.85
	return g * delta


func force_breath(value: float) -> void:
	breath = clampf(value, 0.0, max_breath)
	breath_changed.emit(breath, max_breath)


func _update_water_state() -> void:
	var sample := _liquid.sample_submersion(_player.global_position, head_offset_y, body_offset_y)
	in_water = bool(sample["in_water"])
	swimming = bool(sample["swimming"])
	head_underwater = bool(sample["head_submerged"])
	if in_water and not _was_in_water:
		water_entered.emit()
		_on_water_enter()
	if not in_water and _was_in_water:
		water_exited.emit()
		_on_water_exit()
	if head_underwater and not _was_head_under:
		head_submerged.emit()
	if not head_underwater and _was_head_under:
		head_emerged.emit()
	_was_in_water = in_water
	_was_head_under = head_underwater
	if not in_water:
		depth_state = DepthState.DRY
	elif swimming:
		depth_state = DepthState.SWIMMING if not head_underwater else DepthState.HEAD_UNDER
	elif bool(sample["waist_in_water"]):
		depth_state = DepthState.WAIST
	else:
		depth_state = DepthState.FEET


func _update_breath(delta: float) -> void:
	if _liquid.is_debug_infinite_breath():
		breath = max_breath
		breath_changed.emit(breath, max_breath)
		return
	if head_underwater:
		breath = maxf(0.0, breath - _settings.breath_drain_rate * delta)
	else:
		breath = minf(max_breath, breath + _settings.breath_regen_rate * delta)
	breath_changed.emit(breath, max_breath)


func _update_drowning(delta: float) -> void:
	if head_underwater and breath <= 0.0:
		if not _drowning:
			_drowning = true
			drowning_started.emit()
		_drown_timer -= delta
		if _drown_timer <= 0.0:
			_drown_timer = _settings.drowning_damage_interval
			_apply_drown_damage()
	elif _drowning:
		_drowning = false
		drowning_stopped.emit()


func _apply_drown_damage() -> void:
	if _player == null or _player.stats == null:
		return
	var event := DamageEvent.new()
	event.incoming_amount = int(round(_settings.drowning_damage))
	event.amount = event.incoming_amount
	event.damage_type = DamageTypes.Type.DROWNING
	event.element = DamageTypes.Type.DROWNING
	event.source_node = self
	event.target_node = _player
	event.is_dot = true
	event.ignore_armor = false
	_player.apply_damage_event(event)


func _on_water_enter() -> void:
	if _renderer != null:
		var speed := absf(_player.velocity.y)
		_renderer.spawn_splash(_player.global_position, clampf(speed / 300.0, 0.4, 1.6))


func _on_water_exit() -> void:
	if _renderer != null:
		_renderer.spawn_splash(_player.global_position, 0.35)


func _update_bubbles(delta: float) -> void:
	if not head_underwater or _renderer == null:
		return
	_bubble_timer -= delta
	if _bubble_timer <= 0.0:
		_bubble_timer = randf_range(0.8, 2.2)
		_renderer.spawn_bubbles(_player.global_position + Vector2(randf_range(-4, 4), head_offset_y + 4))
