class_name AnimalBase
extends CharacterBody2D

## Gemeinsame Wildlife-Basis. Nutzt Hurtbox, DamageEvent, LiquidSystem und FogEvent.
## Keine Drops. Kein komplexes Pathfinding.

signal died
signal health_changed(current: float, maximum: float)
signal damage_received(amount: int)

enum State {
	IDLE,
	WANDER,
	FLEE,
	CHASE,
	ATTACK,
	HURT,
	DEAD,
	CURL,
	EAT,
}

enum Lod {
	NEAR,
	MEDIUM,
	FAR,
}

const TILE := 16.0
const WORLD_MASK := 1
const PLATFORM_MASK_BIT := 6
const ANIM_IDLE := &"idle"
const ANIM_WALK := &"walk"
const ANIM_RUN := &"run"
const ANIM_ATTACK := &"attack"
const ANIM_HURT := &"hurt"
const ANIM_DEATH := &"death"
const ANIM_FLY := &"fly"
const ANIM_SWIM := &"swim"
const ANIM_EAT := &"eat"
const ANIM_CURL := &"curl"
const ANIM_JUMP := &"jump"
const ATTACK_DAMAGE_FRAMES := [1]

@export var data: AnimalData

var max_health: int = 10
var current_health: int = 10
var frozen: bool = false
var darkness_active: bool = false
var debug_spawned: bool = false

var _state: int = State.IDLE
var _lod: int = Lod.NEAR
var _facing: float = 1.0
var _player: Player
var _fog: FogEvent
var _day: DayCycle
var _liquid: LiquidSystem
var _hurt_left: float = 0.0
var _attack_cd: float = 0.0
var _think_left: float = 0.0
var _state_left: float = 1.0
var _wander_dir: float = 1.0
var _hop_cd: float = 0.0
var _idle_sound_left: float = 3.0
var _lava_hurt_timer: float = 0.0
var _death_left: float = 0.0
var _flying: bool = false
var _in_water: bool = false
var _on_screen: bool = true
var _sleeping: bool = false
var _despawn_after_flee: bool = false
var _charge_left: float = 0.0
var _glow_t: float = 0.0
var _light_target: Vector2 = Vector2.INF
var _home: Vector2 = Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _flash_tween: Tween
var _strike_on: bool = false
var _debug_label: Label

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _hitbox: EnemyHitbox = get_node_or_null("AttackHitbox") as EnemyHitbox
@onready var _body_shape: CollisionShape2D = $CollisionShape2D
@onready var _ground_check: RayCast2D = $GroundCheck
@onready var _wall_check: RayCast2D = $WallCheck
@onready var _edge_check: RayCast2D = $EdgeCheck
@onready var _screen: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var _audio: Node = $Audio
@onready var _health_anchor: Marker2D = get_node_or_null("HealthBarAnchor") as Marker2D


func _ready() -> void:
	_rng.randomize()
	add_to_group("animals")
	add_to_group("wildlife")
	if data == null:
		push_warning("AnimalBase ohne AnimalData: %s" % name)
		return
	darkness_active = data.darkness_form
	max_health = data.max_health
	current_health = max_health
	_home = global_position
	_idle_sound_left = _rng.randf_range(2.0, 8.0)
	_flying = data.locomotion == AnimalData.Locomotion.FLYING and not data.perch_then_fly
	_apply_body_setup()
	_setup_areas()
	_bind_signals()
	if data.show_health_bar:
		add_to_group("enemy_health")
		call_deferred("_register_health_bar")
	_set_state(State.IDLE)
	_play_anim(_locomotion_anim(), true)
	health_changed.emit(float(current_health), float(max_health))


func _apply_body_setup() -> void:
	set_collision_layer_value(1, false)
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(3, false)
	set_collision_mask_value(PLATFORM_MASK_BIT, true)
	z_index = data.z_index_value
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 8.0
	floor_constant_speed = true
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING if _uses_air_motion() else CharacterBody2D.MOTION_MODE_GROUNDED
	if _sprite != null:
		_sprite.position = data.sprite_offset
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _body_shape != null:
		var rect := RectangleShape2D.new()
		rect.size = data.collider_size
		_body_shape.shape = rect
		_body_shape.position = Vector2(0.0, -data.collider_size.y * 0.5)
	if _health_anchor != null:
		_health_anchor.position = data.health_bar_offset


func _setup_areas() -> void:
	if _hurtbox != null:
		_hurtbox.collision_layer = 4
		_hurtbox.collision_mask = 0
		_hurtbox.monitoring = false
		_hurtbox.monitorable = true
		var hurt_shape := _hurtbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if hurt_shape != null:
			var rect := RectangleShape2D.new()
			rect.size = data.hurtbox_size
			hurt_shape.shape = rect
			hurt_shape.position = Vector2(0.0, -data.hurtbox_size.y * 0.5)
	if _hitbox != null:
		_hitbox.collision_layer = 0
		_hitbox.collision_mask = 2
	if _screen != null:
		if not _screen.screen_entered.is_connected(_on_screen_entered):
			_screen.screen_entered.connect(_on_screen_entered)
		if not _screen.screen_exited.is_connected(_on_screen_exited):
			_screen.screen_exited.connect(_on_screen_exited)
	_update_sensors()


func _bind_signals() -> void:
	if _sprite != null:
		if not _sprite.animation_finished.is_connected(_on_anim_finished):
			_sprite.animation_finished.connect(_on_anim_finished)
		if not _sprite.frame_changed.is_connected(_on_frame_changed):
			_sprite.frame_changed.connect(_on_frame_changed)
	_refresh_refs()
	if _fog != null:
		if not _fog.fog_started.is_connected(_on_fog_started):
			_fog.fog_started.connect(_on_fog_started)
		if not _fog.fog_ended.is_connected(_on_fog_ended):
			_fog.fog_ended.connect(_on_fog_ended)


func _physics_process(delta: float) -> void:
	if data == null or _state == State.DEAD:
		if _state == State.DEAD:
			_tick_dead(delta)
		return
	if _sleeping:
		return
	if frozen:
		velocity.x = 0.0
		if not _uses_air_motion():
			_apply_gravity(delta)
		move_and_slide()
		return
	_hurt_left = maxf(_hurt_left - delta, 0.0)
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_hop_cd = maxf(_hop_cd - delta, 0.0)
	_charge_left = maxf(_charge_left - delta, 0.0)
	_sample_water()
	_apply_motion_mode()
	if not _uses_air_motion():
		_apply_gravity(delta)
	_tick_lava(delta)
	_think_left -= delta
	if _think_left <= 0.0:
		_think()
		_think_left = _think_interval()
	_tick_state(delta)
	_update_sensors()
	move_and_slide()
	_update_facing_visual()
	_update_animation()
	_tick_audio(delta)
	_tick_glow(delta)
	_update_debug_label()


func is_dead() -> bool:
	return _state == State.DEAD


func is_sleeping() -> bool:
	return _sleeping


func is_on_screen() -> bool:
	return _on_screen


func animal_id() -> StringName:
	return data.id if data != null else &""


func population_kind() -> int:
	return data.population if data != null else AnimalData.Population.SURFACE


func current_lod() -> int:
	return _lod


func debug_ai_text() -> String:
	var biome := "-"
	var world := get_tree().get_first_node_in_group("world_generator") as WorldGenerator
	if world != null:
		biome = String(world.get_surface_biome(int(floor(global_position.x / TILE))))
	var dist := _distance_to_player()
	var dist_s := "-"
	if dist != INF:
		dist_s = "%.0f" % dist
	return "%s\nState: %s\nTarget: %s\nDistance: %s\nBiome: %s" % [
		data.display_name if data != null else String(name),
		_state_name(),
		"Player" if _player_alive() else "-",
		dist_s,
		biome,
	]


func set_lod(lod: int) -> void:
	_lod = lod


func is_critter() -> bool:
	return data != null and data.is_critter()


func sleep_ai() -> void:
	if _state == State.DEAD or _sleeping:
		return
	_sleeping = true
	velocity = Vector2.ZERO
	set_physics_process(false)


func wake_ai() -> void:
	if not _sleeping:
		return
	_sleeping = false
	set_physics_process(true)
	_think_left = 0.05


func force_flee_despawn() -> void:
	if _state == State.DEAD or debug_spawned:
		return
	_despawn_after_flee = true
	_begin_flee()


func take_damage(amount: int, _source = null) -> void:
	var event := DamageEvent.outgoing_hit(maxi(int(round(float(amount))), 0), _source, self, null)
	apply_damage_event(event)


func apply_damage_event(event: DamageEvent) -> void:
	if _state == State.DEAD or event == null:
		return
	var dmg := maxi(int(event.amount), 0)
	if dmg <= 0:
		return
	current_health = maxi(current_health - dmg, 0)
	event.amount = dmg
	event.incoming_amount = maxi(event.incoming_amount, dmg)
	event.target_node = self
	event.killed = current_health <= 0
	if event.world_position == Vector2.ZERO:
		event.world_position = get_combat_text_origin()
	_flash_hit()
	_play_sfx("Hurt")
	health_changed.emit(float(current_health), float(max_health))
	damage_received.emit(dmg)
	if data != null and data.show_health_bar:
		var mgr := get_tree().get_first_node_in_group(EnemyHealthBarManager.GROUP)
		if mgr != null and mgr.has_method("notify_hit"):
			mgr.call("notify_hit", self)
	CombatTextSystem.present(event)
	if current_health <= 0:
		_die()
		return
	if data != null and data.charge_on_hit:
		_begin_chase()
		_charge_left = 0.55
		return
	_hurt_left = data.hurt_lock_time if data != null else 0.14
	_set_strike(false)
	_set_state(State.HURT)
	_play_anim(ANIM_HURT, true)


func apply_knockback(impulse: Vector2) -> void:
	if _state == State.DEAD:
		return
	velocity += impulse


func get_display_name() -> String:
	if data != null and not String(data.display_name).is_empty():
		return data.display_name
	return String(name)


func get_health_current() -> float:
	return float(current_health)


func get_health_max() -> float:
	return float(max_health)


func get_health_bar_rank() -> int:
	return EnemyData.Rank.NORMAL


func get_health_bar_world_position() -> Vector2:
	if _health_anchor != null:
		return _health_anchor.global_position
	return global_position + data.health_bar_offset


func get_combat_text_origin() -> Vector2:
	return get_health_bar_world_position() + Vector2(0, -8)


func is_darkness_form() -> bool:
	return darkness_active


func remove_silent() -> void:
	queue_free()


func _register_health_bar() -> void:
	var mgr := get_tree().get_first_node_in_group(EnemyHealthBarManager.GROUP)
	if mgr != null and mgr.has_method("register_enemy"):
		mgr.call("register_enemy", self)


func _think() -> void:
	if _state in [State.HURT, State.DEAD, State.ATTACK]:
		return
	if data.attracted_to_light:
		_refresh_light_target()
	if data.flee_on_darkness and _world_is_darkness() and not data.darkness_form and not debug_spawned:
		_despawn_after_flee = true
		_begin_flee()
		return
	if _player_threatens():
		match data.temperament:
			AnimalData.Temperament.FLEE, AnimalData.Temperament.AMBIENT:
				_begin_flee()
				return
			AnimalData.Temperament.AGGRESSIVE:
				_begin_chase()
				return
			AnimalData.Temperament.NEUTRAL:
				if data.curl_on_threat:
					_begin_curl()
					return
	elif _state == State.CURL and not _player_threatens():
		_set_state(State.IDLE)
		_state_left = _rng.randf_range(data.idle_duration_min, data.idle_duration_max)
	if _state == State.CHASE and not _player_in_lost_range():
		_set_state(State.IDLE)
		_state_left = _rng.randf_range(0.6, 1.4)
	if _state in [State.IDLE, State.WANDER, State.EAT] and _state_left <= 0.0:
		_pick_idle_or_wander()


func _tick_state(delta: float) -> void:
	_state_left -= delta
	match _state:
		State.IDLE, State.EAT, State.CURL:
			_dampen_x(delta, 520.0)
			if _uses_air_motion():
				_hover(delta, 10.0)
			if _state == State.IDLE and data.peck_idle and _state_left < 0.35:
				_play_anim(ANIM_EAT, false)
		State.WANDER:
			_tick_wander(delta)
		State.FLEE:
			_tick_flee(delta)
		State.CHASE:
			_tick_chase(delta)
		State.ATTACK:
			_tick_attack(delta)
		State.HURT:
			_dampen_x(delta, 480.0)
			if _hurt_left <= 0.0:
				if data.temperament == AnimalData.Temperament.AGGRESSIVE and _player_threatens():
					_begin_chase()
				elif data.temperament == AnimalData.Temperament.FLEE:
					_begin_flee()
				else:
					_set_state(State.IDLE)


func _tick_wander(delta: float) -> void:
	if _blocked_ahead() or _hazard_ahead() or _edge_too_steep():
		_wander_dir *= -1.0
		_face(_wander_dir)
		_set_state(State.IDLE)
		_state_left = _rng.randf_range(0.4, 1.1)
		return
	if _home.distance_to(global_position) > data.wander_radius:
		var home_dir := signf(_home.x - global_position.x)
		if home_dir != 0.0:
			_wander_dir = home_dir
			_face(_wander_dir)
	_move_horizontal(delta, data.walk_speed, false)
	if data.attracted_to_light and _light_target != Vector2.INF:
		_steer_towards(_light_target, delta, data.walk_speed)


func _tick_flee(delta: float) -> void:
	if _player_alive():
		var away := signf(global_position.x - _player.global_position.x)
		if away == 0.0:
			away = _wander_dir
		_face(away)
		_wander_dir = away
	if _blocked_ahead() or _hazard_ahead():
		_wander_dir *= -1.0
		_face(_wander_dir)
	if data.perch_then_fly or data.locomotion == AnimalData.Locomotion.FLYING:
		_flying = true
	_move_horizontal(delta, data.run_speed, true)
	if _despawn_after_flee and _state_left <= 0.0:
		remove_silent()
		return
	if not _despawn_after_flee and not _player_threatens() and _state_left <= 0.0:
		_set_state(State.IDLE)
		_state_left = _rng.randf_range(0.8, 1.6)


func _tick_chase(delta: float) -> void:
	if not _player_alive():
		_set_state(State.IDLE)
		return
	_face_towards_player()
	if data.can_attack and _player_in_attack_range() and _attack_cd <= 0.0:
		_begin_attack()
		return
	if _blocked_ahead() and is_on_floor() and data.jump_small_obstacles:
		velocity.y = -data.jump_force * 0.72
	elif _blocked_ahead() or _hazard_ahead() or _edge_too_steep():
		_dampen_x(delta, 700.0)
		return
	var spd := data.run_speed
	if _charge_left > 0.0:
		spd *= 1.45
	_move_horizontal(delta, spd, true)


func _tick_attack(delta: float) -> void:
	if data.charge_on_hit or _charge_left > 0.0:
		_face_towards_player()
		_move_horizontal(delta, data.run_speed * 1.5, true)
		_set_strike(true)
	else:
		_dampen_x(delta, 900.0)
		_face_towards_player()
		_update_hitbox_side()


func _tick_dead(delta: float) -> void:
	if not _uses_air_motion():
		_apply_gravity(delta)
		move_and_slide()
	_death_left -= delta
	if _death_left <= 0.0:
		queue_free()


func _pick_idle_or_wander() -> void:
	if _rng.randf() < 0.45:
		_set_state(State.IDLE)
		_state_left = _rng.randf_range(data.idle_duration_min, data.idle_duration_max)
		if data.peck_idle and _rng.randf() < 0.45:
			_set_state(State.EAT)
			_play_anim(ANIM_EAT, true)
		elif _rng.randf() < 0.35:
			_face(-_facing)
		return
	_begin_wander()


func _begin_wander() -> void:
	_wander_dir = -1.0 if _rng.randf() < 0.5 else 1.0
	_face(_wander_dir)
	_state_left = _rng.randf_range(data.wander_duration_min, data.wander_duration_max)
	_set_state(State.WANDER)


func _begin_flee() -> void:
	if _state == State.FLEE:
		return
	_play_sfx("Alert")
	_set_state(State.FLEE)
	_state_left = 2.2 if _despawn_after_flee else _rng.randf_range(1.4, 2.6)
	if _player_alive():
		var away := signf(global_position.x - _player.global_position.x)
		if away != 0.0:
			_face(away)
			_wander_dir = away


func _begin_chase() -> void:
	if _state == State.CHASE:
		return
	_play_sfx("Alert")
	_set_state(State.CHASE)
	_state_left = 4.0


func _begin_attack() -> void:
	_set_state(State.ATTACK)
	_attack_cd = data.attack_cooldown
	_state_left = 0.45
	if _hitbox != null:
		_hitbox.begin_attack(data.attack_damage, self)
	_play_sfx("Attack")
	_play_anim(ANIM_ATTACK, true)


func _begin_curl() -> void:
	_set_state(State.CURL)
	_state_left = 1.6
	velocity.x = 0.0
	_play_anim(ANIM_CURL, true)


func _die() -> void:
	_set_state(State.DEAD)
	_set_strike(false)
	_sleeping = false
	set_physics_process(true)
	if _hurtbox != null:
		_hurtbox.set_deferred("monitorable", false)
	set_collision_layer_value(3, false)
	if _body_shape != null:
		_body_shape.set_deferred("disabled", true)
	_play_sfx("Death")
	_play_anim(ANIM_DEATH, true)
	_death_left = 1.35
	died.emit()


func _move_horizontal(delta: float, speed: float, running: bool) -> void:
	if _uses_air_motion():
		_fly_or_swim(delta, speed)
		return
	if data.hop_locomotion:
		_hop_move(delta, speed)
		return
	if data.jump_small_obstacles and _blocked_ahead() and is_on_floor() and running:
		velocity.y = -data.jump_force * 0.65
	var desired := _facing * speed
	velocity.x = move_toward(velocity.x, desired, data.ground_acceleration * delta)


func _hop_move(delta: float, speed: float) -> void:
	if is_on_floor() and _hop_cd <= 0.0:
		velocity.y = -data.jump_force
		velocity.x = _facing * speed
		_hop_cd = data.hop_interval
		_play_anim(ANIM_JUMP, true)
	else:
		velocity.x = move_toward(velocity.x, _facing * speed, data.air_control * delta)


func _fly_or_swim(delta: float, speed: float) -> void:
	var target := Vector2(_facing * 48.0, sin(Time.get_ticks_msec() * 0.004 + _rng.randf()) * 18.0)
	if _state == State.FLEE and _player_alive():
		target = (global_position - _player.global_position).normalized() * 80.0
		target.y -= 24.0
	elif data.attracted_to_light and _light_target != Vector2.INF:
		target = _light_target - global_position
	elif _state == State.WANDER:
		target = Vector2(_wander_dir * 40.0, sin((_home.x + global_position.x) * 0.02) * 16.0)
	if data.locomotion == AnimalData.Locomotion.WATER or (_in_water and data.locomotion == AnimalData.Locomotion.AMPHIBIOUS):
		_stay_in_water(target)
	var desired := target.normalized() * speed if target.length() > 4.0 else Vector2.ZERO
	if data.locomotion == AnimalData.Locomotion.FLYING or _flying:
		desired.y = clampf(desired.y, -speed, speed * 0.7)
	velocity = velocity.move_toward(desired, data.ground_acceleration * delta)
	if _blocked_ahead() or _terrain_ahead():
		_wander_dir *= -1.0
		_face(_wander_dir)
		velocity.x *= -0.4


func _stay_in_water(target: Vector2) -> void:
	if _liquid == null:
		return
	var next := global_position + Vector2(signf(target.x) * 10.0, signf(target.y) * 8.0)
	var cell := _liquid.world_to_cell(next)
	if not _liquid.has_water(cell):
		_wander_dir *= -1.0
		_face(_wander_dir)
		velocity *= Vector2(-0.3, -0.2)


func _steer_towards(world_pos: Vector2, delta: float, speed: float) -> void:
	var dir := world_pos - global_position
	if dir.length() < 12.0:
		return
	_face(signf(dir.x))
	if _uses_air_motion():
		velocity = velocity.move_toward(dir.normalized() * speed, data.ground_acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, signf(dir.x) * speed, data.ground_acceleration * delta)


func _hover(delta: float, amp: float) -> void:
	velocity.y = move_toward(velocity.y, sin(Time.get_ticks_msec() * 0.005) * amp, 80.0 * delta)
	velocity.x = move_toward(velocity.x, 0.0, 120.0 * delta)


func _dampen_x(delta: float, amount: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, amount * delta)


func _uses_air_motion() -> bool:
	if data == null:
		return false
	if data.locomotion == AnimalData.Locomotion.FLYING and (_flying or not data.perch_then_fly):
		return true
	if data.locomotion == AnimalData.Locomotion.WATER:
		return true
	if data.locomotion == AnimalData.Locomotion.AMPHIBIOUS and _in_water:
		return true
	return false


func _apply_motion_mode() -> void:
	var air := _uses_air_motion()
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING if air else CharacterBody2D.MOTION_MODE_GROUNDED


func _sample_water() -> void:
	_in_water = false
	if _liquid == null:
		return
	var sample := _liquid.sample_submersion(global_position, -data.collider_size.y, -data.collider_size.y * 0.5)
	_in_water = bool(sample.get("in_water", false))


func _player_threatens() -> bool:
	if not _player_alive() or data == null:
		return false
	var admin := get_node_or_null("/root/AdminManager")
	if admin != null and bool(admin.call("should_ignore_player_for_ai")):
		return false
	var range_px := data.flee_range if data.temperament != AnimalData.Temperament.AGGRESSIVE else data.detection_range
	return _distance_to_player() <= range_px


func _player_in_lost_range() -> bool:
	if not _player_alive() or data == null:
		return false
	return _distance_to_player() <= data.detection_range * 1.4


func _player_in_attack_range() -> bool:
	if not _player_alive() or data == null:
		return false
	return _distance_to_player() <= data.attack_range


func _distance_to_player() -> float:
	if _player == null:
		return INF
	return global_position.distance_to(_player.global_position)


func _player_alive() -> bool:
	return _player != null and is_instance_valid(_player)


func _blocked_ahead() -> bool:
	return _wall_check != null and _wall_check.is_colliding()


func _terrain_ahead() -> bool:
	return _blocked_ahead()


func _edge_too_steep() -> bool:
	if _uses_air_motion() or data == null:
		return false
	if data.jump_small_obstacles:
		return false
	return _edge_check != null and not _edge_check.is_colliding() and is_on_floor()


func _hazard_ahead() -> bool:
	if _liquid == null:
		return false
	var probe := global_position + Vector2(_facing * 12.0, 2.0)
	var cell := _liquid.world_to_cell(probe)
	if _liquid.has_lava(cell):
		return true
	if data.locomotion == AnimalData.Locomotion.GROUND and _liquid.has_water(cell) and not data.near_water:
		return true
	return false


func _face_towards_player() -> void:
	if not _player_alive():
		return
	var dx := _player.global_position.x - global_position.x
	if absf(dx) > 2.0:
		_face(signf(dx))


func _face(dir: float) -> void:
	if dir == 0.0:
		return
	_facing = 1.0 if dir > 0.0 else -1.0


func _update_facing_visual() -> void:
	if _sprite != null:
		_sprite.flip_h = _facing < 0.0
	_update_hitbox_side()
	_update_sensors()


func _update_hitbox_side() -> void:
	if _hitbox == null:
		return
	_hitbox.position.x = (data.collider_size.x * 0.7) * _facing
	_hitbox.position.y = -data.collider_size.y * 0.45


func _update_sensors() -> void:
	if _wall_check != null:
		_wall_check.target_position = Vector2(12.0 * _facing, 0.0)
		_wall_check.position = Vector2(4.0 * _facing, -data.collider_size.y * 0.5)
	if _edge_check != null:
		_edge_check.position = Vector2(10.0 * _facing, -2.0)
		_edge_check.target_position = Vector2(0.0, 14.0)
	if _ground_check != null:
		_ground_check.target_position = Vector2(0.0, 10.0)


func _tick_lava(delta: float) -> void:
	if _state == State.DEAD or _liquid == null or _liquid.settings == null:
		return
	var sample := _liquid.sample_submersion(global_position, -data.collider_size.y, -data.collider_size.y * 0.5, LiquidTypes.Type.LAVA)
	if not bool(sample.get("in_lava", false)):
		return
	_lava_hurt_timer -= delta
	if _lava_hurt_timer > 0.0:
		return
	_lava_hurt_timer = _liquid.settings.enemy_lava_damage_interval
	var event := DamageEvent.new()
	event.incoming_amount = int(round(_liquid.settings.enemy_lava_damage))
	event.amount = event.incoming_amount
	event.damage_type = DamageTypes.Type.FIRE
	event.element = DamageTypes.Type.FIRE
	event.source_node = self
	event.target_node = self
	event.is_dot = true
	apply_damage_event(event)


func _apply_gravity(delta: float) -> void:
	var g := data.gravity
	var cap := data.max_fall_speed
	if _liquid != null and _liquid.settings != null:
		var lava := _liquid.sample_submersion(global_position, -data.collider_size.y, -data.collider_size.y * 0.5, LiquidTypes.Type.LAVA)
		if bool(lava.get("in_lava", false)):
			g *= _liquid.settings.enemy_lava_gravity_multiplier
			cap *= 0.4
		elif _in_water:
			g *= _liquid.settings.enemy_water_gravity_multiplier
			cap *= 0.5
	if not is_on_floor():
		velocity.y = minf(velocity.y + g * delta, cap)
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _update_animation() -> void:
	if _sprite == null or _state in [State.ATTACK, State.HURT, State.DEAD, State.CURL, State.EAT]:
		return
	_play_anim(_locomotion_anim(), false)


func _locomotion_anim() -> StringName:
	if _uses_air_motion():
		if data.locomotion == AnimalData.Locomotion.WATER or (_in_water and data.locomotion == AnimalData.Locomotion.AMPHIBIOUS):
			return ANIM_SWIM if absf(velocity.x) + absf(velocity.y) > 6.0 else ANIM_IDLE
		return ANIM_FLY if velocity.length() > 8.0 else ANIM_IDLE
	if not is_on_floor():
		return ANIM_JUMP
	if absf(velocity.x) > 8.0:
		if _state in [State.FLEE, State.CHASE] or absf(velocity.x) > data.walk_speed * 1.15:
			return ANIM_RUN
		return ANIM_WALK
	return ANIM_IDLE


func _play_anim(anim_name: StringName, restart: bool) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(anim_name):
		if anim_name == ANIM_RUN and _sprite.sprite_frames.has_animation(ANIM_WALK):
			anim_name = ANIM_WALK
		elif anim_name == ANIM_FLY and _sprite.sprite_frames.has_animation(ANIM_WALK):
			anim_name = ANIM_WALK
		elif anim_name == ANIM_SWIM and _sprite.sprite_frames.has_animation(ANIM_WALK):
			anim_name = ANIM_WALK
		elif anim_name == ANIM_JUMP and _sprite.sprite_frames.has_animation(ANIM_WALK):
			anim_name = ANIM_WALK
		elif anim_name == ANIM_EAT and _sprite.sprite_frames.has_animation(ANIM_IDLE):
			anim_name = ANIM_IDLE
		elif anim_name == ANIM_CURL and _sprite.sprite_frames.has_animation(ANIM_IDLE):
			anim_name = ANIM_IDLE
		elif not _sprite.sprite_frames.has_animation(anim_name):
			return
	if not restart and _sprite.animation == anim_name and _sprite.is_playing():
		return
	_sprite.play(anim_name)
	if data != null:
		_sprite.speed_scale = data.animation_speed / 6.0


func _on_anim_finished() -> void:
	if _sprite == null:
		return
	var anim := _sprite.animation
	if anim == ANIM_DEATH:
		queue_free()
		return
	if _state == State.DEAD:
		return
	if _state == State.ATTACK:
		_set_strike(false)
		if data.can_attack and _player_threatens() and _player_in_attack_range() and _attack_cd <= 0.0:
			_begin_attack()
		elif data.temperament == AnimalData.Temperament.AGGRESSIVE and _player_threatens():
			_begin_chase()
		else:
			_set_state(State.IDLE)
		return
	if _state == State.EAT:
		_set_state(State.IDLE)
		_state_left = _rng.randf_range(0.4, 1.0)


func _on_frame_changed() -> void:
	if _state != State.ATTACK or _sprite == null:
		if _state != State.ATTACK:
			_set_strike(false)
		return
	_set_strike(_sprite.frame in ATTACK_DAMAGE_FRAMES or data.charge_on_hit)


func _set_strike(active: bool) -> void:
	_strike_on = active
	if _hitbox != null:
		_hitbox.set_strike_active(active)


func _flash_hit() -> void:
	if _sprite == null:
		return
	if _flash_tween != null:
		_flash_tween.kill()
	_sprite.modulate = Color(1.6, 1.6, 1.6, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_sprite, "modulate", Color.WHITE, 0.12)


func _tick_glow(delta: float) -> void:
	if data == null or not data.glow or _sprite == null or _state == State.DEAD:
		return
	if not _on_screen:
		_sprite.modulate = Color(0.85, 0.9, 0.55, 1.0)
		return
	_glow_t += delta * 2.2
	var pulse := 0.55 + 0.45 * (0.5 + 0.5 * sin(_glow_t))
	_sprite.modulate = Color(0.75 + pulse * 0.55, 0.85 + pulse * 0.4, 0.35 + pulse * 0.2, 1.0)


func _tick_audio(delta: float) -> void:
	if _state == State.DEAD or _audio == null or not _on_screen:
		return
	_idle_sound_left -= delta
	if _state in [State.IDLE, State.WANDER] and _idle_sound_left <= 0.0:
		if _try_idle_sound():
			_play_sfx("Idle")
		_idle_sound_left = _rng.randf_range(4.8, 11.0)


func _try_idle_sound() -> bool:
	var spawner := get_tree().get_first_node_in_group("animal_spawner")
	if spawner != null and spawner.has_method("try_consume_idle_sound"):
		return bool(spawner.call("try_consume_idle_sound"))
	return true


func _play_sfx(sfx_name: String) -> void:
	if _audio == null:
		return
	var player := _audio.get_node_or_null(sfx_name) as AudioStreamPlayer2D
	if player == null or player.stream == null:
		return
	player.pitch_scale = _rng.randf_range(0.92, 1.08)
	player.play()


func _set_state(next: int) -> void:
	_state = next


func _state_name() -> String:
	match _state:
		State.IDLE:
			return "IDLE"
		State.WANDER:
			return "WANDER"
		State.FLEE:
			return "FLEE"
		State.CHASE:
			return "CHASE"
		State.ATTACK:
			return "ATTACK"
		State.HURT:
			return "HURT"
		State.DEAD:
			return "DEAD"
		State.CURL:
			return "CURL"
		State.EAT:
			return "EAT"
	return "?"


func _think_interval() -> float:
	var settings := _settings()
	if settings == null:
		return 0.2
	match _lod:
		Lod.MEDIUM:
			return settings.ai_medium_interval
		Lod.FAR:
			return 0.8
		_:
			return settings.ai_near_interval


func _settings() -> AnimalSettings:
	var spawner := get_tree().get_first_node_in_group("animal_spawner")
	if spawner == null:
		return null
	return spawner.get("settings") as AnimalSettings


func _refresh_light_target() -> void:
	_light_target = Vector2.INF
	var best := 420.0
	for node in get_tree().get_nodes_in_group("lantern"):
		if node is Node2D:
			var d := global_position.distance_to((node as Node2D).global_position)
			if d < best:
				best = d
				_light_target = (node as Node2D).global_position
	if _player_alive():
		var light := _player.get_node_or_null("ToolPivot/ToolArm/CombatLight") as PointLight2D
		if light != null and light.enabled:
			var d2 := global_position.distance_to(light.global_position)
			if d2 < best:
				_light_target = light.global_position


func _update_debug_label() -> void:
	var admin := get_node_or_null("/root/AdminManager")
	var show_debug := admin != null and bool(admin.get("show_animal_ai"))
	if not show_debug:
		if _debug_label != null:
			_debug_label.visible = false
		return
	if _debug_label == null:
		_debug_label = Label.new()
		_debug_label.z_index = 40
		_debug_label.add_theme_font_size_override("font_size", 8)
		_debug_label.position = Vector2(-28, data.health_bar_offset.y - 36.0)
		add_child(_debug_label)
	_debug_label.visible = true
	_debug_label.text = debug_ai_text()


func _on_fog_started(_day_n: int, _cycle: int) -> void:
	if data != null and data.flee_on_darkness and not data.darkness_form and not debug_spawned:
		force_flee_despawn()


func _on_fog_ended(_day_n: int, _cycle: int) -> void:
	pass


func _world_is_darkness() -> bool:
	_refresh_refs()
	if _fog == null:
		return false
	return _fog.state == FogEvent.State.FOG_ACTIVE or _fog.state == FogEvent.State.FOG_ENDING


func _on_screen_entered() -> void:
	_on_screen = true


func _on_screen_exited() -> void:
	_on_screen = false


func _refresh_refs() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	if _fog == null or not is_instance_valid(_fog):
		_fog = get_tree().get_first_node_in_group("fog_event") as FogEvent
		if _fog != null:
			if not _fog.fog_started.is_connected(_on_fog_started):
				_fog.fog_started.connect(_on_fog_started)
			if not _fog.fog_ended.is_connected(_on_fog_ended):
				_fog.fog_ended.connect(_on_fog_ended)
	if _day == null or not is_instance_valid(_day):
		_day = get_tree().get_first_node_in_group("day_cycle") as DayCycle
	if _liquid == null or not is_instance_valid(_liquid):
		_liquid = get_tree().get_first_node_in_group(LiquidSystem.GROUP) as LiquidSystem
