class_name Zombie
extends CharacterBody2D

## Gehoert an: Root von res://scenes/enemies/zombie.tscn
## Ein Gegnertyp, zwei Formen: Normal und Finsternis.

signal died
signal form_changed(darkness: bool)

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
var _flash_tween: Tween

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D
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
		_detection.collision_mask = 2
		_detection.monitoring = true
		_detection.monitorable = false
	if _attack_range != null:
		_attack_range.collision_layer = 0
		_attack_range.collision_mask = 2
		_attack_range.monitoring = true
		_attack_range.monitorable = false
	if _hurtbox != null:
		_hurtbox.collision_layer = 4
		_hurtbox.collision_mask = 0
		_hurtbox.monitoring = false
		_hurtbox.monitorable = true
	if _hitbox != null:
		_hitbox.collision_layer = 0
		_hitbox.collision_mask = 2
	_sync_range_shapes()
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
	_refresh_refs()
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	_hurt_left = maxf(_hurt_left - delta, 0.0)
	_apply_gravity(delta)
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
	_update_sensors()
	move_and_slide()
	_update_facing_visual()
	_update_animation()
	_tick_audio(delta)
	_sync_fx_budget()


func is_dead() -> bool:
	return _state == State.DEAD


func is_darkness_form() -> bool:
	return darkness_active


func take_damage(amount: int, _source = null) -> void:
	if _state == State.DEAD:
		return
	var dmg := maxi(int(round(float(amount))), 0)
	if dmg <= 0:
		return
	current_health = maxi(current_health - dmg, 0)
	_flash_hit()
	_play_sfx("Hurt")
	if current_health <= 0:
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
	if darkness_active:
		return data.scaled_darkness_speed(_fog_cycle())
	return data.move_speed


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
	_sync_range_shapes()
	_set_fx_emitting(dark)
	if _eye_light != null:
		_eye_light.enabled = dark
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
	_update_sensors()


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


func _sync_range_shapes() -> void:
	_set_circle(_detection, current_detection())
	_set_circle(_attack_range, current_attack_range())


func _set_circle(area: Area2D, radius: float) -> void:
	if area == null:
		return
	var node := area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if node == null:
		return
	var circle := CircleShape2D.new()
	circle.radius = radius
	node.shape = circle


func _apply_gravity(delta: float) -> void:
	var g := data.gravity if data != null else 1000.0
	var cap := data.max_fall_speed if data != null else 600.0
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


func _play_anim(name: StringName, restart: bool) -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if not _sprite.sprite_frames.has_animation(name):
		name = StringName(String(name).replace("dark_", ""))
		if not _sprite.sprite_frames.has_animation(name):
			return
	if not restart and _sprite.animation == name and _sprite.is_playing():
		return
	_sprite.play(name)


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
	node.preprocess = 0.2
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
	var on := active and _on_screen
	if _body_smoke != null:
		_body_smoke.emitting = on
	if _trail_smoke != null:
		_trail_smoke.emitting = on
	if _ambient != null:
		_ambient.emitting = on
	if _eye_light != null:
		_eye_light.enabled = on


func _sync_fx_budget() -> void:
	if not darkness_active:
		return
	var many := get_tree().get_nodes_in_group("zombies").size() > 8
	var vis := _on_screen
	if _body_smoke != null:
		_body_smoke.emitting = vis
		_body_smoke.amount = 8 if many else 14
		_body_smoke.speed_scale = 0.7 if not vis else 1.0
	if _trail_smoke != null:
		_trail_smoke.emitting = vis and absf(velocity.x) > 10.0
		_trail_smoke.amount = 6 if many else 10
	if _ambient != null:
		_ambient.emitting = vis
		_ambient.amount = 4 if many else 8
	if _eye_light != null:
		_eye_light.enabled = vis


func _on_screen_entered() -> void:
	_on_screen = true


func _on_screen_exited() -> void:
	_on_screen = false
	if _body_smoke != null:
		_body_smoke.emitting = false
	if _trail_smoke != null:
		_trail_smoke.emitting = false
	if _ambient != null:
		_ambient.emitting = false
	if _eye_light != null:
		_eye_light.enabled = false


func _tick_audio(delta: float) -> void:
	if _state == State.DEAD:
		return
	_idle_sound_left -= delta
	if _state in [State.IDLE, State.WANDER] and _idle_sound_left <= 0.0:
		_play_sfx("Idle")
		_idle_sound_left = randf_range(3.5, 7.0)
	var dark_player := _audio.get_node_or_null("Darkness") as AudioStreamPlayer2D if _audio != null else null
	if dark_player == null:
		return
	if darkness_active and _on_screen:
		if not dark_player.playing:
			dark_player.play()
	elif dark_player.playing:
		dark_player.stop()


func _play_sfx(name: String) -> void:
	if _audio == null:
		return
	var player := _audio.get_node_or_null(name) as AudioStreamPlayer2D
	if player == null or player.stream == null:
		return
	player.pitch_scale = randf_range(0.92, 1.08)
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
