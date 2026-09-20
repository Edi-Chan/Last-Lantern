class_name LavaInteraction
extends Node

## Lava-Kontakt, getickter Schaden, Nachbrennen und zähe Bewegung.
## Nutzt dieselbe Submersion-Abtastung wie Wasser, aber eigene Parameter.

signal lava_entered
signal lava_exited
signal burning_started
signal burning_stopped

@export var head_offset_y: float = -38.0
@export var body_offset_y: float = -21.0

var in_lava: bool = false
var swimming: bool = false
var burning: bool = false
var burn_left: float = 0.0

var _player: Player
var _liquid: LiquidSystem
var _settings: LiquidSettings
var _lava_node: Lava
var _was_in_lava: bool = false
var _contact_timer: float = 0.0
var _burn_timer: float = 0.0
var _visuals: CanvasItem
var _visual_base: Color = Color.WHITE


func _ready() -> void:
	_player = get_parent() as Player
	if _player != null:
		_visuals = _player.get_node_or_null("Visuals") as CanvasItem
		if _visuals != null:
			_visual_base = _visuals.modulate
	call_deferred("_bind")


func _bind() -> void:
	_liquid = get_tree().get_first_node_in_group(LiquidSystem.GROUP) as LiquidSystem
	if _liquid != null:
		_settings = _liquid.settings
		_lava_node = _liquid.get_node_or_null("Lava") as Lava


func update_before_physics() -> void:
	_update_lava_state()


func _physics_process(delta: float) -> void:
	if _player == null or _settings == null:
		return
	_update_contact_damage(delta)
	_update_burning(delta)


func get_movement_multipliers() -> Dictionary:
	if not in_lava:
		return {"speed": 1.0, "gravity": 1.0, "max_fall": 1.0, "sprint_allowed": true}
	return {
		"speed": _settings.lava_move_multiplier,
		"gravity": _settings.lava_gravity_multiplier,
		"max_fall": _settings.lava_max_fall_multiplier,
		"sprint_allowed": false,
	}


func can_swim_up() -> bool:
	return in_lava and swimming


func apply_swim_forces(delta: float) -> void:
	if _player == null or _settings == null or not can_swim_up():
		return
	_player.velocity.x = move_toward(_player.velocity.x, 0.0, _settings.lava_drag_horizontal * delta * 60.0)
	var wants_rise := _player.world_input_enabled and Input.is_action_pressed("jump")
	if wants_rise:
		_player.velocity.y -= _settings.lava_swim_force * _settings.lava_vertical_multiplier * delta
		_player.velocity.y = maxf(_player.velocity.y, -_settings.lava_swim_max_up_speed)
		return
	if _player.velocity.y < _settings.lava_sink_speed:
		_player.velocity.y = move_toward(_player.velocity.y, _settings.lava_sink_speed, 70.0 * delta)
	else:
		_player.velocity.y = move_toward(_player.velocity.y, _settings.lava_sink_speed, 35.0 * delta)


func apply_lava_gravity_multiplier(base_gravity: float, delta: float) -> float:
	if not in_lava:
		return base_gravity * delta
	return base_gravity * _settings.lava_gravity_multiplier * delta


func _update_lava_state() -> void:
	if _player == null or _liquid == null or _settings == null:
		return
	var sample := _liquid.sample_submersion(_player.global_position, head_offset_y, body_offset_y, LiquidTypes.Type.LAVA)
	in_lava = bool(sample.get("in_lava", false))
	swimming = bool(sample.get("swimming", false))
	if in_lava and not _was_in_lava:
		lava_entered.emit()
		_on_enter()
	if not in_lava and _was_in_lava:
		lava_exited.emit()
		_on_exit()
	_was_in_lava = in_lava
	_apply_burn_visual()


func _on_enter() -> void:
	_contact_timer = 0.0
	_start_burning(_settings.burn_duration)
	_apply_fire_damage(_settings.lava_contact_damage, false)
	if _lava_node != null:
		_lava_node.play_burn(_player.global_position)


func _on_exit() -> void:
	_start_burning(_settings.burn_duration)


func _update_contact_damage(delta: float) -> void:
	if not in_lava:
		return
	_contact_timer -= delta
	if _contact_timer > 0.0:
		return
	_contact_timer = _settings.lava_damage_interval
	_apply_fire_damage(_settings.lava_contact_damage, true)
	_start_burning(_settings.burn_duration)


func _update_burning(delta: float) -> void:
	if not burning:
		return
	if in_lava:
		burn_left = maxf(burn_left, _settings.burn_duration)
		return
	burn_left = maxf(0.0, burn_left - delta)
	_burn_timer -= delta
	if _burn_timer <= 0.0 and burn_left > 0.0:
		_burn_timer = _settings.burn_tick_rate
		_apply_fire_damage(_settings.burn_damage, true)
	if burn_left <= 0.0:
		burning = false
		burning_stopped.emit()
		_apply_burn_visual()


func _start_burning(duration: float) -> void:
	var was_burning := burning
	burning = true
	burn_left = maxf(burn_left, duration)
	_burn_timer = _settings.burn_tick_rate
	if not was_burning:
		burning_started.emit()
	_apply_burn_visual()


func _apply_fire_damage(amount: float, is_dot: bool) -> void:
	if _player == null or _player.stats == null or amount <= 0.0:
		return
	var event := DamageEvent.new()
	event.incoming_amount = int(round(amount))
	event.amount = event.incoming_amount
	event.damage_type = DamageTypes.Type.FIRE
	event.element = DamageTypes.Type.FIRE
	event.source_node = self
	event.target_node = _player
	event.is_dot = is_dot
	event.ignore_armor = false
	_player.apply_damage_event(event)
	if _player.has_method("play_hit"):
		_player.play_hit(0, false)


func _apply_burn_visual() -> void:
	if _visuals == null:
		return
	if burning or in_lava:
		_visuals.modulate = Color(1.35, 0.62, 0.32)
	else:
		_visuals.modulate = _visual_base
