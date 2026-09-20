class_name Player
extends CharacterBody2D

## Gehoert an: Player-Root (CharacterBody2D) in res://scenes/player/player.tscn
## Bewegung, Sprint, Crouch, Blickrichtung und Hand-Ausrichtung.
## Mining bleibt in player_interaction.gd, die Charakterwerte in player_stats.gd.

signal fog_hurt(amount: float)

@export var move_speed: float = 130.0
@export var ground_acceleration: float = 900.0
@export var air_acceleration: float = 500.0
@export var ground_friction: float = 1100.0
@export var gravity: float = 1000.0
@export var jump_velocity: float = -330.0
@export var jump_cut_multiplier: float = 0.5
@export var max_fall_speed: float = 600.0

@export_group("Sprint")
@export var sprint_multiplier: float = 1.5
## Verbrauch pro Sekunde, nicht pro Frame.
@export var stamina_sprint_cost: float = 20.0
@export var stamina_regeneration: float = 15.0
@export var stamina_regen_delay: float = 0.6
## Nach voelliger Erschoepfung erst ab diesem Wert wieder sprintbar.
@export var sprint_min_stamina: float = 15.0

@export_group("Crouch")
@export var crouch_speed_multiplier: float = 0.45

var world_input_enabled: bool = true
var facing_sign: float = 1.0
var is_sprinting: bool = false
var is_crouching: bool = false
var character_name: String = ""

var _inventory_action_held: bool = false
var _was_on_floor: bool = true
var _peak_fall_speed: float = 0.0
var _land_lock: float = 0.0
var _stamina_regen_left: float = 0.0
## Gesetzt, sobald die Ausdauer auf 0 faellt. Blockiert den Sprint, bis
## sprint_min_stamina wieder erreicht ist.
var _sprint_exhausted: bool = false
var _drop_through_left: float = 0.0
var _step_gate: float = 0.0
## Wird nur beim Aufstehversuch gebraucht, deshalb einmalig angelegt statt
## pro Frame neu erzeugt.
var _headroom_shape := RectangleShape2D.new()
var _headroom_query := PhysicsShapeQueryParameters2D.new()

@onready var _visuals: Node2D = $Visuals
@onready var _animated_sprite: AnimatedSprite2D = $Visuals/BaseSprite
@onready var _leg_armor: AnimatedSprite2D = $Visuals/LegArmorSprite
@onready var _chest_armor: AnimatedSprite2D = $Visuals/ChestArmorSprite
@onready var _helmet: AnimatedSprite2D = $Visuals/HelmetSprite
@onready var _collision: CollisionShape2D = $CollisionShape2D
## ToolPivot spiegelt nur (scale.x). Die Rotation sitzt eine Ebene tiefer, sonst
## dreht der Swing beim Blick nach links nach oben statt nach unten.
@onready var _tool_pivot: Node2D = $ToolPivot
@onready var _anim: AnimationPlayer = $AnimationPlayer
@onready var _audio: PlayerAudio = $Audio
@onready var stats: PlayerStats = $Stats
@onready var _water: WaterInteraction = $WaterInteraction

## Gameplay-Collider. Beim Ducken schrumpft er nur nach oben, die Unterkante
## bleibt auf der Fusslinie (y = 0) und der Player sinkt nicht in den Boden.
const STAND_SIZE := Vector2(20.0, 42.0)
const STAND_CENTER := Vector2(0.0, -21.0)
const CROUCH_SIZE := Vector2(20.0, 28.0)
const CROUCH_CENTER := Vector2(0.0, -14.0)
## Physics-Layer 1 = World. Nur dagegen wird der Kopfraum geprueft.
const WORLD_LAYER_MASK := 1
## Rechte Side-View-Hand, gemessen vom Fuss-Ursprung des 40x56-Sprites.
const TOOL_PIVOT_X := 10.0
const TOOL_PIVOT_Y := -24.0
## Geduckt sitzt die Hand rund 8 px tiefer.
const CROUCH_TOOL_PIVOT_Y := -16.0
const JUMP_TOOL_PIVOT_Y := -28.0
const FALL_TOOL_PIVOT_Y := -25.0
## Solange die Maus naeher als das am Player steht, bleibt die Blickrichtung
## stehen. Ohne das flippt der Sprite bei jeder kleinen Mausbewegung.
const MOUSE_FACING_DEADZONE := 10.0
const CROUCH_FOOTSTEP_VOLUME := -6.0
const SPRINT_FOOTSTEP_VOLUME := 1.5
const MOVING_SPEED_EPSILON := 8.0
const LANDING_MIN_SPEED := 140.0

func _ready() -> void:
	add_to_group("player")
	# Gespiegelt wird ueber flip_h, der Body und seine Kinder bleiben unskaliert.
	_visuals.scale = Vector2.ONE
	# Eigene Kopie, damit die Groessenumschaltung nicht in die Szenenressource
	# schreibt und andere Instanzen mitzieht.
	_collision.shape = _collision.shape.duplicate()
	_apply_collider(false)
	set_collision_mask_value(1, true)
	set_collision_mask_value(6, true)
	# 45°-Treppen sind bei Default 45° kein Floor (Winkel muss kleiner als max sein).
	floor_max_angle = deg_to_rad(50.0)
	floor_constant_speed = true
	_headroom_query.collision_mask = WORLD_LAYER_MASK
	_headroom_query.collide_with_bodies = true
	_headroom_query.collide_with_areas = false
	_headroom_query.exclude = [get_rid()]
	_animated_sprite.play("idle")
	if _animated_sprite != null and not _animated_sprite.frame_changed.is_connected(_on_sprite_frame_changed):
		_animated_sprite.frame_changed.connect(_on_sprite_frame_changed)
	var inventory := get_node_or_null("Inventory") as Inventory
	if inventory != null:
		inventory.equipment_changed.connect(_refresh_armor_visuals)
	call_deferred("_refresh_armor_visuals")


func _physics_process(delta: float) -> void:
	_handle_inventory_toggle()
	_update_crouch()
	_update_sprint(delta)
	_update_drop_through(delta)
	_handle_gravity(delta)
	if world_input_enabled:
		_handle_jump()
		_handle_movement(delta)
	else:
		_dampen_horizontal(delta)
	move_and_slide()
	_update_facing()
	_aim_tool()
	_update_animation()
	_sync_armor_layers()
	_update_landing(delta)


func play_sfx(sound: StringName, volume_offset_db: float = 0.0, sfx_material: StringName = &"") -> void:
	if _audio != null:
		_audio.play(sound, volume_offset_db, sfx_material)


func play_weapon_swing(kind: int) -> void:
	if _audio != null:
		_audio.play_weapon_swing(kind)


func play_hit(kind: int = 0, darkness_bonus: bool = false) -> void:
	if _audio != null:
		_audio.play_hit(kind, darkness_bonus)


func get_combat_text_origin() -> Vector2:
	return global_position + Vector2(0, -58)


## Einstiegspunkt fuer Tool-Hitboxen, Finsternis und spaetere Gegner.
func take_damage(amount: float, _source: Node = null, damage_type: Variant = null) -> void:
	var event: DamageEvent
	if damage_type is DamageEvent:
		event = damage_type
	else:
		event = DamageEvent.new()
		event.incoming_amount = int(round(amount))
		event.amount = event.incoming_amount
		event.source_node = _source
		event.target_node = self
		event.damage_type = DamageTypes.from_legacy(damage_type)
		event.element = event.damage_type
		if StringName(str(damage_type)) == &"fog":
			event.ignore_armor = true
			event.is_dot = true
			event.damage_type = DamageTypes.Type.DARKNESS
			event.element = DamageTypes.Type.DARKNESS
	apply_damage_event(event)


func apply_damage_event(event: DamageEvent) -> void:
	if stats == null or event == null:
		return
	var admin := get_node_or_null("/root/AdminManager")
	if admin != null and bool(admin.call("should_block_damage")):
		return
	event.target_node = self
	event.is_player_target = true
	if event.world_position == Vector2.ZERO:
		event.world_position = get_combat_text_origin()
	var result := stats.apply_incoming_damage(float(event.incoming_amount if event.incoming_amount > 0 else event.amount), event.ignore_armor, event.damage_type)
	event.incoming_amount = int(round(float(result["incoming"])))
	event.amount = int(round(float(result["applied"])))
	event.reduced = bool(result["reduced"])
	event.blocked = bool(result["blocked"])
	print("Player hp=%.0f/%.0f (-%d) type=%d" % [stats.health, stats.max_health, event.amount, event.damage_type])
	CombatTextSystem.present(event)
	if event.is_dot and event.damage_type == DamageTypes.Type.DARKNESS:
		fog_hurt.emit(float(event.incoming_amount))


func heal(amount: float) -> float:
	if stats == null:
		return 0.0
	var applied := stats.heal(amount)
	if applied > 0.0:
		CombatTextSystem.present(DamageEvent.healing(int(round(applied)), self))
	return applied


func _handle_inventory_toggle() -> void:
	if UIManager.is_blocking_gameplay():
		_inventory_action_held = Input.is_action_pressed("inventory")
		return
	var pressed := Input.is_action_pressed("inventory")
	if pressed and not _inventory_action_held:
		var screen := get_tree().get_first_node_in_group("inventory_ui")
		if screen != null and screen.has_method("toggle"):
			screen.call("toggle")
	_inventory_action_held = pressed


## Ducken geht immer, Aufstehen nur mit freiem Kopfraum.
func _update_crouch() -> void:
	var wants_crouch := world_input_enabled and Input.is_action_pressed("crouch")
	if wants_crouch == is_crouching:
		return
	if wants_crouch:
		_apply_collider(true)
	elif _has_standing_headroom():
		_apply_collider(false)


func _apply_collider(crouching: bool) -> void:
	is_crouching = crouching
	var shape := _collision.shape as RectangleShape2D
	if shape != null:
		shape.size = CROUCH_SIZE if crouching else STAND_SIZE
	_collision.position = CROUCH_CENTER if crouching else STAND_CENTER


## Prueft, ob der Stand-Collider an der aktuellen Position frei ist. Die Box ist
## an allen Seiten 1 px kleiner, sonst melden der beruehrte Boden und
## anliegende Waende einen Treffer und der Player koennte nie aufstehen.
func _has_standing_headroom() -> bool:
	var space := get_world_2d().direct_space_state
	if space == null:
		return true
	_headroom_shape.size = STAND_SIZE - Vector2(2.0, 2.0)
	_headroom_query.shape = _headroom_shape
	_headroom_query.transform = Transform2D(0.0, global_position + STAND_CENTER)
	return space.intersect_shape(_headroom_query, 1).is_empty()


func _update_sprint(delta: float) -> void:
	if stats == null:
		return
	var water_mult := _water_movement_multipliers()
	var has_move_input := world_input_enabled \
		and Input.get_axis("move_left", "move_right") != 0.0
	is_sprinting = has_move_input \
		and world_input_enabled \
		and Input.is_action_pressed("sprint") \
		and not is_crouching \
		and not _sprint_exhausted \
		and stats.stamina > 0.0 \
		and bool(water_mult.get("sprint_allowed", true))

	if is_sprinting:
		stats.drain_stamina(stamina_sprint_cost * delta)
		_stamina_regen_left = stamina_regen_delay
		if stats.stamina <= 0.0:
			is_sprinting = false
			_sprint_exhausted = true
		return

	if _sprint_exhausted and stats.stamina >= sprint_min_stamina:
		_sprint_exhausted = false
	if _stamina_regen_left > 0.0:
		_stamina_regen_left = maxf(_stamina_regen_left - delta, 0.0)
	else:
		stats.restore_stamina(stats.stamina_regen_rate() * delta)


func _current_move_speed() -> float:
	var speed := move_speed * stats.movement_multiplier() if stats != null else move_speed
	if is_crouching:
		speed *= crouch_speed_multiplier
	elif is_sprinting:
		speed *= stats.sprint_multiplier() if stats != null else sprint_multiplier
	speed *= float(_water_movement_multipliers().get("speed", 1.0))
	var admin := get_node_or_null("/root/AdminManager")
	if admin != null:
		speed *= float(admin.call("get_speed_multiplier"))
	return speed


func _handle_gravity(delta: float) -> void:
	if _is_admin_noclip():
		return
	if _try_ladder(delta):
		return
	if _water != null:
		_water.apply_swim_forces(delta)
	if not is_on_floor():
		var g_delta := gravity * delta
		if _water != null and _water.in_water:
			g_delta = _water.apply_water_gravity_multiplier(gravity, delta)
		var fall_cap := max_fall_speed
		if _water != null and _water.swimming:
			fall_cap *= float(_water_movement_multipliers().get("max_fall", 1.0))
		velocity.y = minf(velocity.y + g_delta, fall_cap)


func _handle_jump() -> void:
	if _is_admin_noclip():
		var vertical := 0.0
		if Input.is_action_pressed("jump"):
			vertical -= 1.0
		if Input.is_action_pressed("crouch") or (InputMap.has_action("move_down") and Input.is_action_pressed("move_down")):
			vertical += 1.0
		velocity.y = vertical * _current_move_speed()
		return
	if _drop_through_left > 0.0:
		return
	var wants_drop := Input.is_action_pressed("crouch")
	if InputMap.has_action("move_down") and Input.is_action_pressed("move_down"):
		wants_drop = true
	if is_on_floor() and wants_drop and Input.is_action_just_pressed("jump"):
		_drop_through_left = 0.28
		set_collision_mask_value(6, false)
		velocity.y = 60.0
		return
	if _water != null and _water.swimming:
		return
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		var jump := jump_velocity
		if stats != null:
			jump *= stats.jump_multiplier()
		velocity.y = jump
		play_sfx(&"Jump")
	elif Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier


func _handle_movement(delta: float) -> void:
	var input_direction := Input.get_axis("move_left", "move_right")
	var acceleration := ground_acceleration if is_on_floor() else air_acceleration
	if input_direction != 0.0:
		var target := input_direction * _current_move_speed()
		velocity.x = move_toward(velocity.x, target, acceleration * delta)
	else:
		_dampen_horizontal(delta)


func _dampen_horizontal(delta: float) -> void:
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, ground_friction * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, air_acceleration * delta)


## Bewegung bestimmt die Blickrichtung. Steht der Player still, bleibt die
## letzte Richtung erhalten - ausser er benutzt oder zielt gerade mit dem Tool,
## dann uebernimmt die Maus. Eine Richtung fuer Sprite, Hand und Werkzeug.
func _update_facing() -> void:
	if world_input_enabled:
		var input_direction := Input.get_axis("move_left", "move_right")
		if input_direction != 0.0:
			facing_sign = signf(input_direction)
		elif _is_aiming():
			facing_sign = _mouse_facing()
	_animated_sprite.flip_h = facing_sign < 0.0
	_sync_armor_facing()
	_tool_pivot.scale.x = facing_sign
	_tool_pivot.position = Vector2(TOOL_PIVOT_X * facing_sign, _tool_hand_y())


func _is_aiming() -> bool:
	if Input.is_action_pressed("use_item") or Input.is_action_pressed("interact_secondary"):
		return true
	var interaction := get_node_or_null("Interaction")
	if interaction != null and interaction.has_method("is_drawing_bow") and bool(interaction.call("is_drawing_bow")):
		return true
	if InputMap.has_action("block_autolock") and Input.is_action_pressed("block_autolock"):
		return true
	if is_auto_tool_held():
		return true
	return _is_swinging()


func is_auto_tool_held() -> bool:
	if Input.is_key_pressed(KEY_ALT) or Input.is_physical_key_pressed(KEY_ALT):
		return true
	return InputMap.has_action("auto_tool") and Input.is_action_pressed("auto_tool")


func _is_swinging() -> bool:
	if _anim == null or not _anim.is_playing():
		return false
	var current := _anim.current_animation
	return current == &"tool_swing" or current == &"sword_swing" or current == &"spear_thrust" or current == &"bow_shot" or current == &"lantern_burst"


## Weltposition unter dem Systemcursor, im selben Canvas wie der Spieler.
func get_world_mouse_position() -> Vector2:
	return get_global_mouse_position()


func _water_movement_multipliers() -> Dictionary:
	if _water == null:
		return {"speed": 1.0, "gravity": 1.0, "max_fall": 1.0, "sprint_allowed": true}
	return _water.get_movement_multipliers()


func _is_admin_noclip() -> bool:
	var admin := get_node_or_null("/root/AdminManager")
	return admin != null and bool(admin.get("no_clip"))


func _mouse_facing() -> float:
	var offset_x := get_world_mouse_position().x - global_position.x
	if absf(offset_x) < MOUSE_FACING_DEADZONE:
		return facing_sign
	return 1.0 if offset_x > 0.0 else -1.0


func _tool_hand_y() -> float:
	if is_crouching:
		return CROUCH_TOOL_PIVOT_Y
	if not is_on_floor():
		return JUMP_TOOL_PIVOT_Y if velocity.y < 0.0 else FALL_TOOL_PIVOT_Y
	return TOOL_PIVOT_Y


func _aim_tool() -> void:
	## Rest-Pose und Walk-Swing setzt HeldItem. Use-Animation hat Vorrang.
	pass


## Reihenfolge: airborne > crouch > Tool-Swing > sprint > walk > idle.
func _update_animation() -> void:
	var moving := absf(velocity.x) > MOVING_SPEED_EPSILON
	if not is_on_floor():
		_animated_sprite.play("jump" if velocity.y < 0.0 else "fall")
	elif is_crouching:
		_animated_sprite.play("crouch_walk" if moving else "crouch_idle")
	elif _is_swinging():
		_animated_sprite.play("use_tool")
	elif is_sprinting and moving:
		_animated_sprite.play("run")
	elif moving:
		_animated_sprite.play("walk")
	else:
		_animated_sprite.play("idle")


func _update_landing(delta: float) -> void:
	_land_lock = maxf(_land_lock - delta, 0.0)
	_step_gate = maxf(_step_gate - delta, 0.0)
	var grounded := is_on_floor()
	if not grounded:
		_peak_fall_speed = maxf(_peak_fall_speed, velocity.y)
	elif not _was_on_floor:
		if _peak_fall_speed >= LANDING_MIN_SPEED:
			var amp := clampf((_peak_fall_speed - LANDING_MIN_SPEED) / 360.0, 0.0, 1.0)
			play_sfx(&"Land", lerpf(-8.0, 0.0, amp), _ground_material())
		_land_lock = 0.08
		_peak_fall_speed = 0.0
	_was_on_floor = grounded


func _on_sprite_frame_changed() -> void:
	if _land_lock > 0.0 or not is_on_floor() or _animated_sprite == null:
		return
	var anim := _animated_sprite.animation
	if anim != &"walk" and anim != &"run" and anim != &"crouch_walk":
		return
	if absf(velocity.x) < MOVING_SPEED_EPSILON:
		return
	if _step_gate > 0.0:
		return
	var vol := CROUCH_FOOTSTEP_VOLUME if is_crouching else (SPRINT_FOOTSTEP_VOLUME if is_sprinting else 0.0)
	play_sfx(&"Footstep", vol, _ground_material())
	if is_crouching:
		_step_gate = 0.14
	elif is_sprinting:
		_step_gate = 0.08
	else:
		_step_gate = 0.11


func _ground_material() -> StringName:
	var interaction := get_node_or_null("Interaction")
	if interaction == null or not interaction.has_method("get_block_data"):
		return &"dirt"
	var tilemap := get_tree().get_first_node_in_group("terrain") as TileMapLayer
	if tilemap == null:
		return &"dirt"
	var cell: Vector2i = tilemap.local_to_map(tilemap.to_local(global_position + Vector2(0.0, 4.0)))
	var block: Variant = interaction.call("get_block_data", cell)
	if block == null:
		block = interaction.call("get_block_data", cell + Vector2i(0, 1))
	if block == null or not block.has_method("get_audio_material"):
		return &"dirt"
	return StringName(block.call("get_audio_material"))


func _update_drop_through(delta: float) -> void:
	if _drop_through_left <= 0.0:
		return
	_drop_through_left = maxf(0.0, _drop_through_left - delta)
	if _drop_through_left <= 0.0:
		set_collision_mask_value(6, true)


func _try_ladder(_delta: float) -> bool:
	var parts := get_tree().get_first_node_in_group(&"building_part_system") as BuildingPartSystem
	if parts == null or not parts.is_climbable_at_world(global_position + Vector2(0, -16)):
		return false
	var climb := 0.0
	if Input.is_action_pressed("jump"):
		climb -= 1.0
	if Input.is_action_pressed("crouch"):
		climb += 1.0
	if InputMap.has_action("move_down") and Input.is_action_pressed("move_down"):
		climb += 1.0
	velocity.y = climb * move_speed
	return true


func _armor_sprites() -> Array[AnimatedSprite2D]:
	var layers: Array[AnimatedSprite2D] = []
	for sprite in [_leg_armor, _chest_armor, _helmet]:
		if sprite != null:
			layers.append(sprite)
	return layers


func _sync_armor_facing() -> void:
	var flip := facing_sign < 0.0
	for sprite in _armor_sprites():
		sprite.flip_h = flip


func _sync_armor_layers() -> void:
	if _animated_sprite == null:
		return
	var anim := _animated_sprite.animation
	var frame := _animated_sprite.frame
	var flip := _animated_sprite.flip_h
	for sprite in _armor_sprites():
		if not sprite.visible or sprite.sprite_frames == null:
			continue
		if not sprite.sprite_frames.has_animation(anim):
			continue
		if sprite.animation != anim:
			sprite.animation = anim
		sprite.frame = frame
		sprite.flip_h = flip


func _refresh_armor_visuals() -> void:
	var inventory := get_node_or_null("Inventory") as Inventory
	if inventory == null:
		return
	_apply_armor_item(_leg_armor, inventory.get_equipment_item("legs"))
	_apply_armor_item(_chest_armor, inventory.get_equipment_item("chest"))
	_apply_armor_item(_helmet, inventory.get_equipment_item("head"))
	_sync_armor_layers()
	if stats != null:
		stats.rebuild_from_inventory(inventory)


func _apply_armor_item(sprite: AnimatedSprite2D, item: ItemData) -> void:
	if sprite == null:
		return
	if item == null or item.armor_sprite_frames == null:
		sprite.visible = false
		return
	sprite.sprite_frames = item.armor_sprite_frames
	sprite.speed_scale = 0.0
	sprite.visible = true


func apply_appearance(data: LookRecord) -> void:
	if data == null:
		return
	data.normalize()
	character_name = data.character_name


func apply_knockback(impulse: Vector2) -> void:
	var scale := 1.0
	if stats != null:
		scale = 1.0 - stats.knockback_resistance()
	velocity += impulse * scale


func compose_preview_texture() -> Texture2D:
	if _animated_sprite == null or _animated_sprite.sprite_frames == null:
		return null
	if not _animated_sprite.sprite_frames.has_animation(&"idle"):
		return null
	var base := _animated_sprite.sprite_frames.get_frame_texture(&"idle", 0)
	if base == null:
		return null
	var image := base.get_image()
	if image == null:
		return base
	image = image.duplicate()
	for sprite in _armor_sprites():
		if sprite == null or not sprite.visible or sprite.sprite_frames == null:
			continue
		if not sprite.sprite_frames.has_animation(&"idle"):
			continue
		var overlay_tex := sprite.sprite_frames.get_frame_texture(&"idle", 0)
		if overlay_tex == null:
			continue
		var overlay := overlay_tex.get_image()
		if overlay == null:
			continue
		image.blend_rect(overlay, Rect2i(Vector2i.ZERO, overlay.get_size()), Vector2i.ZERO)
	return ImageTexture.create_from_image(image)
