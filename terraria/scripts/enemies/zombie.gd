class_name Zombie
extends CharacterBody2D

## Gehoert an: Root von res://scenes/enemies/zombie.tscn
## Ein Gegnertyp, zwei Formen: Normal und Finsternis.

signal died
signal form_changed(darkness: bool)
signal health_changed(current: float, maximum: float)
signal damage_received(amount: int)

enum State {
	IDLE,
	WANDER,
	CHASE,
	ATTACK,
	HURT,
	TRANSFORM,
	DEAD,
}

const TILE := 16.0
const WORLD_MASK := 1
const PLATFORM_MASK_BIT := 6
const ANIM_IDLE := &"idle"
const ANIM_WALK := &"walk"
const ANIM_ATTACK := &"attack"
const ANIM_HURT := &"hurt"
const ANIM_DEATH := &"death"
const ANIM_TRANSFORM := &"transform"
const ATTACK_DAMAGE_FRAMES := [2, 3]

@export var data: EnemyData
@export var start_in_darkness: bool = false
## Debug-Spawns bleiben in ihrer Form, bis ein echtes Finsternis-Event kommt.
@export var lock_form: bool = false
@export var debug_spawned: bool = false
@export var lava_immune: bool = false
@export var fire_resistant: bool = false

var max_health: int = 50
var current_health: int = 50
var darkness_active: bool = false

var _state: int = State.IDLE
var _facing: float = 1.0
var _player: Player
var _fog: FogEvent
var _hurt_left: float = 0.0
var _attack_cd: float = 0.0
var _wander_dir: float = 1.0
var _wander_left: float = 0.0
var _idle_sound_left: float = 2.5
var _detected_once: bool = false
var _strike_on: bool = false
var _on_screen: bool = true
var _lava_hurt_timer: float = 0.0
var frozen: bool = false
var _flash_tween: Tween
var _sleeping: bool = false
var _full_sim: bool = true
var _fx_light_ok: bool = false
var _fx_particles_ok: bool = false
var _stride_parity: int = 0
var _liquid: LiquidSystem
var _admin: Node
var _ref_tick: int = 0
var _ignore_player_ai: bool = false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _hitbox: EnemyHitbox = $AttackHitbox
@onready var _detection: Area2D = $DetectionArea
@onready var _attack_range: Area2D = $AttackRange
@onready var _ground_check: RayCast2D = $GroundCheck
@onready var _wall_check: RayCast2D = $WallCheck
@onready var _edge_check: RayCast2D = $EdgeCheck
@onready var _screen: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var _body_smoke: GPUParticles2D = $DarknessEffects/BodySmoke
@onready var _trail_smoke: GPUParticles2D = $DarknessEffects/TrailSmoke
@onready var _ambient: GPUParticles2D = $DarknessEffects/AmbientParticles
@onready var _eye_light: PointLight2D = $DarknessEffects/EyeLight
@onready var _audio: Node = $Audio


func _ready() -> void:
	add_to_group("enemies")
	add_to_group("zombies")
	add_to_group("enemy_health")
	if data == null:
		data = load("res://resources/enemies/zombie_data.tres") as EnemyData
	set_collision_layer_value(1, false)
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	set_collision_mask_value(PLATFORM_MASK_BIT, true)
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 8.0
	floor_constant_speed = true
	_setup_areas()
	_setup_darkness_fx()
	_bind_signals()
	_setup_audio()
	call_deferred("_register_health_bar")
	call_deferred("_initialize_form")


func _initialize_form() -> void:
	_refresh_refs()
	var want_dark := start_in_darkness or (not lock_form and _world_is_darkness())
	_apply_form(want_dark, false, true)
	_set_state(State.IDLE)
	_play_anim(_anim_name(ANIM_IDLE), true)


func _setup_areas() -> void:
	if _detection != null:
		_detection.collision_layer = 0
		_detection.collision_mask = 0
		_detection.monitoring = false
		_detection.monitorable = false
		_detection.process_mode = Node.PROCESS_MODE_DISABLED
	if _attack_range != null:
		_attack_range.collision_layer = 0
		_attack_range.collision_mask = 0
		_attack_range.monitoring = false
		_attack_range.monitorable = false
		_attack_range.process_mode = Node.PROCESS_MODE_DISABLED
	if _hurtbox != null:
		_hurtbox.collision_layer = 4
		_hurtbox.collision_mask = 0
		_hurtbox.monitoring = false
		_hurtbox.monitorable = true
	if _hitbox != null:
		_hitbox.collision_layer = 0
		_hitbox.collision_mask = 2
	_update_sensors()
	if _screen != null:
		if not _screen.screen_entered.is_connected(_on_screen_entered):
			_screen.screen_entered.connect(_on_screen_entered)
		if not _screen.screen_exited.is_connected(_on_screen_exited):
			_screen.screen_exited.connect(_on_screen_exited)


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
			_apply_gravity(delta)
			move_and_slide()
		return
	if _sleeping:
		return
	_stride_parity += 1
	var skip_detail := not _full_sim and (_stride_parity & 1) == 1 and _state != State.ATTACK and _state != State.HURT
	if skip_detail:
		_apply_gravity(delta)
		move_and_slide()
		return
	if frozen:
		velocity.x = 0.0
		_apply_gravity(delta)
		move_and_slide()
		return
	_refresh_refs()
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_hurt_left = maxf(_hurt_left - delta, 0.0)
	_apply_gravity(delta)
	if _full_sim:
		_tick_lava(delta)
	match _state:
		State.IDLE:
			_tick_idle(delta)
		State.WANDER:
			_tick_wander(delta)
		State.CHASE:
			_tick_chase(delta)
		State.ATTACK:
			_tick_attack(delta)
		State.HURT:
			_tick_hurt(delta)
		State.TRANSFORM:
			velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	if _full_sim:
		_update_sensors()
	move_and_slide()
	_update_facing_visual()
	_update_animation()
	if _full_sim:
		_tick_audio(delta)
	_apply_fx_budget()


func is_dead() -> bool:
	return _state == State.DEAD


func is_darkness_form() -> bool:
	return darkness_active


func is_on_screen() -> bool:
	return _on_screen


func apply_crowd_budget(full_sim: bool, allow_light: bool, allow_particles: bool, sleep: bool) -> void:
	_full_sim = full_sim
	_fx_light_ok = allow_light
	_fx_particles_ok = allow_particles
	if _wall_check != null:
		_wall_check.enabled = full_sim
	if _edge_check != null:
		_edge_check.enabled = full_sim
	if _ground_check != null:
		_ground_check.enabled = full_sim
	if sleep and _state != State.DEAD and _state != State.ATTACK and _state != State.HURT and _state != State.TRANSFORM:
		_sleep_ai()
	else:
		_wake_ai()
	_apply_fx_budget()


func _sleep_ai() -> void:
	if _sleeping or _state == State.DEAD:
		return
	_sleeping = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	if _sprite != null:
		_sprite.speed_scale = 0.0
	_apply_fx_budget()


func _wake_ai() -> void:
	if not _sleeping:
		return
	_sleeping = false
	set_physics_process(true)
	if _sprite != null:
		_sprite.speed_scale = 1.0


func is_attacking_player() -> bool:
	return _state == State.ATTACK


func is_busy() -> bool:
	return _state == State.CHASE or _state == State.ATTACK or _state == State.HURT or _state == State.TRANSFORM


func get_display_name() -> String:
	if data != null and not String(data.display_name).is_empty():
		return data.display_name
	return "Zombie"


func get_health_current() -> float:
	return float(current_health)


func get_health_max() -> float:
	return float(max_health)


func get_health_bar_rank() -> int:
	if data == null:
		return EnemyData.Rank.NORMAL
	return data.rank


func get_health_bar_world_position() -> Vector2:
	var anchor := get_node_or_null("HealthBarAnchor") as Node2D
	if anchor != null:
		return anchor.global_position
	return global_position + Vector2(0, -56)


func get_combat_text_origin() -> Vector2:
	return get_health_bar_world_position() + Vector2(0, -14)


func _register_health_bar() -> void:
	var mgr := get_tree().get_first_node_in_group(EnemyHealthBarManager.GROUP)
	if mgr != null and mgr.has_method("register_enemy"):
		mgr.call("register_enemy", self)


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
	var mgr := get_tree().get_first_node_in_group(EnemyHealthBarManager.GROUP)
	if mgr != null and mgr.has_method("notify_hit"):
		mgr.call("notify_hit", self)
	CombatTextSystem.present(event)
	if current_health <= 0:
		_credit_player_kill(event.source_node)
		_die()
		return
	if _state == State.TRANSFORM:
		return
	_hurt_left = data.hurt_lock_time if data != null else 0.16
	_set_strike(false)
	_set_state(State.HURT)
	_play_anim(_anim_name(ANIM_HURT), true)


func apply_knockback(impulse: Vector2) -> void:
	if _state == State.DEAD:
		return
	velocity += impulse


func current_attack_damage() -> float:
	if data == null:
		return 10.0
	if darkness_active:
		return data.scaled_darkness_damage(_fog_cycle())
	return data.attack_damage


func current_speed() -> float:
	if data == null:
		return 42.0
	var speed := data.scaled_darkness_speed(_fog_cycle()) if darkness_active else data.move_speed
	var liquid := _liquid_system()
	if liquid != null and liquid.settings != null:
		var lava := liquid.sample_submersion(global_position, -28.0, -14.0, LiquidTypes.Type.LAVA)
		if bool(lava.get("in_lava", false)):
			speed *= liquid.settings.enemy_lava_speed_multiplier
		else:
			var sample := liquid.sample_submersion(global_position, -28.0, -14.0)
			if bool(sample.get("swimming", false)):
				speed *= liquid.settings.enemy_deep_speed_multiplier
			elif bool(sample.get("in_water", false)):
				speed *= liquid.settings.enemy_shallow_speed_multiplier
	return speed


func current_detection() -> float:
	if data == null:
		return 192.0
	return data.darkness_detection_range if darkness_active else data.detection_range


func current_attack_range() -> float:
	return data.attack_range if data != null else 30.0


func current_attack_cooldown() -> float:
	if data == null:
		return 1.0
	return data.darkness_attack_cooldown if darkness_active else data.attack_cooldown


func force_form(darkness: bool) -> void:
	lock_form = true
	start_in_darkness = darkness
	_apply_form(darkness, false, current_health <= 0 or current_health == max_health)


func _tick_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, _accel() * delta)
	if _can_see_player():
		_begin_chase()
		return
	_wander_left -= delta
	if _wander_left <= 0.0:
		_begin_wander()


func _tick_wander(delta: float) -> void:
	if _can_see_player():
		_begin_chase()
		return
	_wander_left -= delta
	if _wander_left <= 0.0 or _blocked_ahead():
		_wander_dir *= -1.0
		_face(_wander_dir)
		_set_state(State.IDLE)
		_wander_left = randf_range(0.8, 1.8)
		return
	var spd := data.wander_speed if data != null else 18.0
	if darkness_active:
		spd *= 1.25
	velocity.x = move_toward(velocity.x, _wander_dir * spd, _accel() * delta)
	_face(_wander_dir)


func _tick_chase(delta: float) -> void:
	if not _player_alive():
		_set_state(State.IDLE)
		return
	if not _player_in_lost_range():
		_detected_once = false
		_set_state(State.IDLE)
		_wander_left = randf_range(0.6, 1.4)
		return
	_face_towards_player()
	if _player_in_attack_range() and _attack_cd <= 0.0 and is_on_floor():
		_begin_attack()
		return
	if _blocked_ahead() and is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, _accel() * 1.4 * delta)
		return
	var desired := _facing * current_speed()
	velocity.x = move_toward(velocity.x, desired, _accel() * delta)


func _tick_attack(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * delta)
	_face_towards_player()
	_update_hitbox_side()


func _tick_hurt(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
	if _hurt_left > 0.0:
		return
	if _can_see_player():
		_begin_chase()
	else:
		_set_state(State.IDLE)


func _begin_chase() -> void:
	if not _detected_once:
		_detected_once = true
		_play_sfx("Detect")
	_set_state(State.CHASE)


func _begin_wander() -> void:
	_wander_dir = -1.0 if randf() < 0.5 else 1.0
	_face(_wander_dir)
	_wander_left = randf_range(1.4, 2.8)
	_set_state(State.WANDER)


func _begin_attack() -> void:
	_set_state(State.ATTACK)
	_attack_cd = current_attack_cooldown()
	if _hitbox != null:
		_hitbox.begin_attack(current_attack_damage(), self)
	_play_sfx("Attack")
	_play_anim(_anim_name(ANIM_ATTACK), true)


func _credit_player_kill(source: Node) -> void:
	var node := source
	while node != null:
		if node is Player and (node as Player).stats != null:
			(node as Player).stats.note_enemy_killed()
			return
		node = node.get_parent()


func _die() -> void:
	_set_state(State.DEAD)
	_set_strike(false)
	if _hurtbox != null:
		_hurtbox.set_deferred("monitorable", false)
	if _detection != null:
		_detection.monitoring = false
	if _attack_range != null:
		_attack_range.monitoring = false
	_set_fx_emitting(false)
	if _eye_light != null:
		_eye_light.enabled = false
	_play_sfx("Death")
	_play_anim(_anim_name(ANIM_DEATH), true)
	died.emit()


func remove_silent() -> void:
	queue_free()


func _apply_form(dark: bool, animate: bool, refill: bool) -> void:
	if data == null:
		return
	var ratio := 1.0
	if not refill and max_health > 0:
		ratio = float(current_health) / float(max_health)
	darkness_active = dark
	max_health = data.scaled_darkness_health(_fog_cycle()) if dark else data.max_health
	if refill:
		current_health = max_health
	else:
		current_health = clampi(int(round(ratio * float(max_health))), 1 if current_health > 0 else 0, max_health)
	health_changed.emit(float(current_health), float(max_health))
	_set_fx_emitting(dark)
	form_changed.emit(dark)
	if animate and _state != State.DEAD:
		_set_strike(false)
		_set_state(State.TRANSFORM)
		_play_anim(ANIM_TRANSFORM if not dark else ANIM_TRANSFORM, true)
		_sprite.modulate = Color(0.45, 0.4, 0.55, 1.0) if dark else Color.WHITE
	else:
		_sprite.modulate = Color(1, 1, 1, 1)
		_play_anim(_anim_name(ANIM_IDLE), false)


func _on_fog_started(_day: int, _cycle: int) -> void:
	if lock_form or darkness_active or _state == State.DEAD:
		lock_form = false
		if darkness_active or _state == State.DEAD:
			return
	_apply_form(true, true, false)


func _on_fog_ended(_day: int, _cycle: int) -> void:
	lock_form = false
	if not darkness_active or _state == State.DEAD:
		return
	_apply_form(false, false, false)
	if _state != State.DEAD:
		_play_anim(_anim_name(_locomotion_anim()), false)


func _on_anim_finished() -> void:
	if _sprite == null:
		return
	var anim := _sprite.animation
	if anim == ANIM_DEATH or anim == _anim_name(ANIM_DEATH):
		queue_free()
		return
	if _state == State.DEAD:
		return
	if anim == ANIM_TRANSFORM:
		_sprite.modulate = Color.WHITE
		if _can_see_player():
			_begin_chase()
		else:
			_set_state(State.IDLE)
		return
	if _state == State.ATTACK:
		_set_strike(false)
		if _can_see_player() and _player_in_attack_range() and _attack_cd <= 0.0:
			_begin_attack()
		elif _can_see_player():
			_begin_chase()
		else:
			_set_state(State.IDLE)
		return
	if _state == State.HURT and _hurt_left <= 0.0:
		if _can_see_player():
			_begin_chase()
		else:
			_set_state(State.IDLE)


func _on_frame_changed() -> void:
	if _state != State.ATTACK or _sprite == null:
		_set_strike(false)
		return
	var striking := _sprite.frame in ATTACK_DAMAGE_FRAMES
	_set_strike(striking)


func _set_strike(active: bool) -> void:
	_strike_on = active
	if _hitbox != null:
		_hitbox.set_strike_active(active)


func _can_see_player() -> bool:
	if not _player_alive():
		return false
	if _ignore_player_ai:
		return false
	return _distance_to_player() <= current_detection()


func _player_in_lost_range() -> bool:
	if not _player_alive() or data == null:
		return false
	return _distance_to_player() <= current_detection() * data.lose_target_multiplier


func _player_in_attack_range() -> bool:
	if not _player_alive():
		return false
	return _distance_to_player() <= current_attack_range()


func _distance_to_player() -> float:
	if _player == null:
		return INF
	return global_position.distance_to(_player.global_position)


func _player_alive() -> bool:
	return _player != null and is_instance_valid(_player)


func _blocked_ahead() -> bool:
	return _wall_check != null and _wall_check.is_colliding()


func _edge_ahead() -> bool:
	return _edge_check != null and not _edge_check.is_colliding() and is_on_floor()


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


func _update_hitbox_side() -> void:
	if _hitbox == null:
		return
	_hitbox.position.x = 16.0 * _facing
	_hitbox.position.y = -22.0
	if _trail_smoke != null:
		_trail_smoke.position.x = -8.0 * _facing
	if _eye_light != null:
		_eye_light.position.x = 4.0 * _facing


func _update_sensors() -> void:
	if _wall_check != null:
		_wall_check.target_position = Vector2(14.0 * _facing, 0.0)
		_wall_check.position = Vector2(6.0 * _facing, -20.0)
	if _edge_check != null:
		_edge_check.position = Vector2(12.0 * _facing, -2.0)
		_edge_check.target_position = Vector2(0.0, 14.0)
	if _ground_check != null:
		_ground_check.target_position = Vector2(0.0, 10.0)


func _tick_lava(delta: float) -> void:
	if lava_immune or fire_resistant or _state == State.DEAD:
		return
	var liquid := _liquid_system()
	if liquid == null or liquid.settings == null:
		return
	var sample := liquid.sample_submersion(global_position, -28.0, -14.0, LiquidTypes.Type.LAVA)
	if not bool(sample.get("in_lava", false)):
		return
	_lava_hurt_timer -= delta
	if _lava_hurt_timer > 0.0:
		return
	_lava_hurt_timer = liquid.settings.enemy_lava_damage_interval
	var event := DamageEvent.new()
	event.incoming_amount = int(round(liquid.settings.enemy_lava_damage))
	event.amount = event.incoming_amount
	event.damage_type = DamageTypes.Type.FIRE
	event.element = DamageTypes.Type.FIRE
	event.source_node = self
	event.target_node = self
	event.is_dot = true
	apply_damage_event(event)


func _apply_gravity(delta: float) -> void:
	var g := data.gravity if data != null else 1000.0
	var cap := data.max_fall_speed if data != null else 600.0
	var liquid := _liquid_system()
	if liquid != null:
		var lava := liquid.sample_submersion(global_position, -28.0, -14.0, LiquidTypes.Type.LAVA)
		if bool(lava.get("in_lava", false)):
			g *= liquid.settings.enemy_lava_gravity_multiplier
			cap *= 0.4
		else:
			var sample := liquid.sample_submersion(global_position, -28.0, -14.0)
			if bool(sample.get("swimming", false)):
				g *= liquid.settings.enemy_water_gravity_multiplier
				cap *= 0.5
			elif bool(sample.get("in_water", false)):
				g *= 0.85
	if not is_on_floor():
		velocity.y = minf(velocity.y + g * delta, cap)
	elif velocity.y > 0.0:
		velocity.y = 0.0


func _accel() -> float:
	if data == null:
		return 220.0
	return data.darkness_acceleration if darkness_active else data.ground_acceleration


func _update_animation() -> void:
	if _sprite == null or _state in [State.ATTACK, State.HURT, State.DEAD, State.TRANSFORM]:
		return
	var moving := absf(velocity.x) > 8.0 and is_on_floor()
	_play_anim(_anim_name(ANIM_WALK if moving else ANIM_IDLE), false)


func _locomotion_anim() -> StringName:
	return ANIM_WALK if absf(velocity.x) > 8.0 else ANIM_IDLE


func _anim_name(base: StringName) -> StringName:
	if darkness_active and base != ANIM_TRANSFORM:
		return StringName("dark_%s" % String(base))
	return base


func _play_anim(anim_name: StringName, restart: bool) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(anim_name):
		anim_name = StringName(String(anim_name).replace("dark_", ""))
		if not _sprite.sprite_frames.has_animation(anim_name):
			return
	if not restart and _sprite.animation == anim_name and _sprite.is_playing():
		return
	_sprite.play(anim_name)


func _flash_hit() -> void:
	if _sprite == null:
		return
	if _flash_tween != null:
		_flash_tween.kill()
	_sprite.modulate = Color(1.6, 1.6, 1.6, 1.0)
	_flash_tween = create_tween()
	var back := Color.WHITE
	_flash_tween.tween_property(_sprite, "modulate", back, 0.12)


func _setup_darkness_fx() -> void:
	var smoke_tex := load("res://assets/enemies/zombie/smoke_puff.png") as Texture2D
	var ember_tex := load("res://assets/enemies/zombie/dark_ember.png") as Texture2D
	_configure_particles(_body_smoke, smoke_tex, 14, 1.05, Vector3(0, -1, 0), 22.0, 7.0, 16.0, Vector3(0, -22, 0), Color(0.07, 0.05, 0.1, 0.72), 8.0)
	_configure_particles(_trail_smoke, smoke_tex, 10, 0.95, Vector3(-0.4, -0.7, 0), 18.0, 10.0, 20.0, Vector3(0, -14, 0), Color(0.05, 0.04, 0.08, 0.55), 6.0)
	_configure_particles(_ambient, ember_tex, 8, 1.4, Vector3(0, -1, 0), 40.0, 4.0, 10.0, Vector3(0, -8, 0), Color(0.45, 0.12, 0.28, 0.7), 10.0)
	if _trail_smoke != null:
		_trail_smoke.position = Vector2(-8, -18)
	if _body_smoke != null:
		_body_smoke.position = Vector2(0, -22)
	if _ambient != null:
		_ambient.position = Vector2(0, -28)
	if _eye_light != null:
		_eye_light.enabled = false
		_eye_light.color = Color(0.72, 0.12, 0.22, 1.0)
		_eye_light.energy = 0.28
		_eye_light.texture_scale = 0.22
		_eye_light.position = Vector2(4, -40)
	_set_fx_emitting(false)


func _configure_particles(
	node: GPUParticles2D,
	texture: Texture2D,
	amount: int,
	lifetime: float,
	direction: Vector3,
	spread: float,
	vmin: float,
	vmax: float,
	gravity: Vector3,
	color: Color,
	radius: float
) -> void:
	if node == null:
		return
	node.amount = amount
	node.lifetime = lifetime
	node.preprocess = 0.0
	node.explosiveness = 0.05
	node.randomness = 0.35
	node.local_coords = false
	node.texture = texture
	node.visibility_rect = Rect2(-80, -90, 160, 140)
	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = radius
	mat.particle_flag_disable_z = true
	mat.direction = direction
	mat.spread = spread
	mat.initial_velocity_min = vmin
	mat.initial_velocity_max = vmax
	mat.gravity = gravity
	mat.scale_min = 0.35
	mat.scale_max = 0.9
	mat.color = color
	node.process_material = mat
	node.emitting = false


func _set_fx_emitting(active: bool) -> void:
	if not active:
		_fx_light_ok = false
		_fx_particles_ok = false
	_apply_fx_budget()


func _apply_fx_budget() -> void:
	var vis := _on_screen and not _sleeping and _state != State.DEAD
	var particles := vis and darkness_active and _fx_particles_ok
	var light := vis and darkness_active and _fx_light_ok
	_set_particle_node(_body_smoke, particles)
	_set_particle_node(_trail_smoke, particles and absf(velocity.x) > 10.0)
	_set_particle_node(_ambient, particles)
	if _eye_light != null:
		_eye_light.enabled = light
		_eye_light.visible = light


func _set_particle_node(node: GPUParticles2D, on: bool) -> void:
	if node == null:
		return
	node.emitting = on
	node.visible = on
	node.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _on_screen_entered() -> void:
	_on_screen = true
	_apply_fx_budget()


func _on_screen_exited() -> void:
	_on_screen = false
	_apply_fx_budget()


func _tick_audio(delta: float) -> void:
	if _state == State.DEAD:
		return
	_idle_sound_left -= delta
	if _state in [State.IDLE, State.WANDER] and _idle_sound_left <= 0.0:
		_play_sfx("Idle")
		_idle_sound_left = randf_range(5.0, 9.0)
	var dark_player := _audio.get_node_or_null("Darkness") as AudioStreamPlayer2D if _audio != null else null
	if dark_player == null:
		return
	if darkness_active and _on_screen:
		if not dark_player.playing:
			dark_player.play()
	elif dark_player.playing:
		dark_player.stop()


func _setup_audio() -> void:
	if _audio == null:
		return
	var crowd := maxi(get_tree().get_nodes_in_group("zombies").size() - 1, 0)
	var dark := _audio.get_node_or_null("Darkness") as AudioStreamPlayer2D
	if dark != null:
		dark.bus = &"Ambient"
		dark.volume_db = -22.0 - minf(float(crowd) * 0.8, 6.0)
		dark.max_distance = 280.0
		if dark.stream is AudioStreamWAV:
			var wav := (dark.stream as AudioStreamWAV).duplicate() as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			dark.stream = wav
	for child in _audio.get_children():
		var player := child as AudioStreamPlayer2D
		if player == null:
			continue
		player.max_polyphony = 1
		if player.name == "Idle":
			player.volume_db = -12.0 - minf(float(crowd) * 1.4, 8.0)


func _play_sfx(sfx_name: String) -> void:
	if _audio == null:
		return
	var player := _audio.get_node_or_null(sfx_name) as AudioStreamPlayer2D
	if player == null or player.stream == null:
		return
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()


func _set_state(next: int) -> void:
	_state = next


func _world_is_darkness() -> bool:
	_refresh_refs()
	if _fog == null:
		return false
	return _fog.state == FogEvent.State.FOG_ACTIVE or _fog.state == FogEvent.State.FOG_ENDING


func _fog_cycle() -> int:
	if _fog == null:
		return 1
	return maxi(_fog.fog_cycle, 1)


func _liquid_system() -> LiquidSystem:
	if _liquid == null or not is_instance_valid(_liquid):
		_liquid = get_tree().get_first_node_in_group(LiquidSystem.GROUP) as LiquidSystem
	return _liquid


func _refresh_refs() -> void:
	_ref_tick -= 1
	if _ref_tick > 0 and _player != null and is_instance_valid(_player) and _fog != null and is_instance_valid(_fog):
		return
	_ref_tick = 20
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Player
	if _fog == null or not is_instance_valid(_fog):
		_fog = get_tree().get_first_node_in_group("fog_event") as FogEvent
		if _fog != null:
			if not _fog.fog_started.is_connected(_on_fog_started):
				_fog.fog_started.connect(_on_fog_started)
			if not _fog.fog_ended.is_connected(_on_fog_ended):
				_fog.fog_ended.connect(_on_fog_ended)
	if _admin == null:
		_admin = get_node_or_null("/root/AdminManager")
	_ignore_player_ai = _admin != null and bool(_admin.call("should_ignore_player_for_ai"))
	_liquid_system()
