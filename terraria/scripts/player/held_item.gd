class_name HeldItem
extends Node2D

## Weapon Controller auf Player/ToolPivot.
## Maus liefert Aim. ActionType bestimmt Bewegung. ItemData bestimmt Sprite.

@onready var _sprite: Sprite2D = $ToolArm/HeldItemSprite
@onready var _tool_arm: Node2D = $ToolArm
@onready var _inventory: Inventory = $"../Inventory"
@onready var _anim: AnimationPlayer = $"../AnimationPlayer"
@onready var _hitbox: Area2D = $ToolArm/ToolHitbox

var _base_offset := Vector2.ZERO
var _base_pivot := Vector2.ZERO
var _base_rotation_deg: float = 0.0
var _attacking := false
var _attack_action: int = 0
var _attack_dir := Vector2.RIGHT
var _debug_aim := Vector2.RIGHT
var _debug_attack := Vector2.RIGHT

func _ready() -> void:
	process_priority = 25
	scale = Vector2.ONE
	rotation = 0.0
	if _inventory != null:
		_inventory.inventory_changed.connect(refresh)
		_inventory.selected_slot_changed.connect(_on_selected_changed)
	call_deferred("refresh")


func _on_selected_changed(_index: int) -> void:
	refresh()


func _process(_delta: float) -> void:
	scale = Vector2.ONE
	rotation = 0.0
	_sync_visual()
	queue_redraw()


func refresh() -> void:
	if _sprite == null:
		return
	var item := _selected_item()
	var tex: Texture2D = item.get_held_texture() if item != null else null
	if item == null or tex == null:
		_sprite.visible = false
		_sprite.texture = null
		_sprite.rotation_degrees = 0.0
		_sprite.flip_h = false
		_sprite.flip_v = false
		_sprite.offset = Vector2.ZERO
		if _tool_arm != null and not _attacking:
			_tool_arm.position = Vector2.ZERO
			_tool_arm.rotation = 0.0
		return
	_sprite.visible = true
	_sprite.texture = tex
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = true
	_sprite.z_index = 2
	var held_scale := item.get_held_scale()
	_sprite.scale = Vector2(held_scale, held_scale)
	_base_rotation_deg = item.held_rotation_degrees
	_base_offset = item.get_held_offset()
	_base_pivot = item.get_held_pivot_offset()
	_sprite.position = _base_offset
	_sprite.offset = _base_pivot
	_sync_visual()


func begin_attack(action: int, direction: Vector2) -> void:
	_attacking = true
	_attack_action = action
	_attack_dir = direction if direction.length_squared() > 0.0001 else Vector2.RIGHT


func clear_aim() -> void:
	_attacking = false
	_attack_action = 0
	_attack_dir = Vector2.RIGHT


func lock_aim_to_mouse() -> void:
	var player := _player()
	var dir := player.visual_aim_direction() if player != null else Vector2.RIGHT
	var item := _selected_item()
	var action := int(item.resolve_action_type()) if item != null else int(ItemData.ActionType.NONE)
	begin_attack(action, dir)


func _sync_visual() -> void:
	if _sprite == null or _tool_arm == null:
		return
	if not _sprite.visible:
		return
	var player := _player()
	var item := _selected_item()
	var action := int(item.resolve_action_type()) if item != null else int(ItemData.ActionType.NONE)
	var live := player.aim_direction if player != null else Vector2.RIGHT
	var locked := _attack_dir if _attacking else live
	if player != null and player.is_attacking:
		locked = player.attack_direction
		action = player.attack_action if player.attack_action != 0 else action
	var progress := _attack_progress()
	var facing := player.facing_sign if player != null else 1.0
	var dir := live
	var arm_rot := 0.0
	var arm_pos := Vector2.ZERO
	var flip_from_aim := true
	if _attacking and PlayerAim.uses_thrust(action):
		dir = locked
		arm_rot = dir.angle()
		arm_pos = dir * PlayerAim.thrust_distance(progress, PlayerAim.thrust_max(action), PlayerAim.thrust_windup(action))
	elif _attacking and PlayerAim.uses_swing(action):
		dir = locked
		flip_from_aim = false
		arm_rot = PlayerAim.swing_angle(progress, dir.angle(), PlayerAim.swing_arc(action), facing)
	elif PlayerAim.uses_live_aim(action) or _is_bow_drawing():
		dir = live
		arm_rot = dir.angle()
		if _is_bow_drawing():
			var interaction := get_node_or_null("../Interaction")
			var charge := float(interaction.call("get_bow_charge")) if interaction != null and interaction.has_method("get_bow_charge") else 0.0
			arm_pos = dir * (-7.0 * charge)
	else:
		flip_from_aim = false
		dir = Vector2(facing, 0.0)
		arm_rot = PlayerAim.rest_angle(facing)
		var pose := _walk_bob()
		arm_pos = Vector2(roundf(pose.x), roundf(pose.y))
	_tool_arm.rotation = arm_rot
	_tool_arm.position = Vector2(roundf(arm_pos.x), roundf(arm_pos.y))
	_sprite.position = _base_offset
	_sprite.offset = _base_pivot
	_sprite.rotation_degrees = _base_rotation_deg
	_sprite.flip_h = item.held_flip_h if item != null else false
	var flip_v := PlayerAim.needs_vertical_flip(dir) if flip_from_aim else facing < 0.0
	if item != null and item.held_flip_v:
		flip_v = not flip_v
	_sprite.flip_v = flip_v
	_debug_aim = live
	_debug_attack = locked


func _attack_progress() -> float:
	if _anim == null or not _anim.is_playing():
		return 1.0
	var length := _anim.current_animation_length
	if length <= 0.0:
		return 1.0
	return clampf(_anim.current_animation_position / length, 0.0, 1.0)


func _walk_bob() -> Vector3:
	var player := _player()
	if player == null:
		return Vector3.ZERO
	var visual := player.get_node_or_null("Visuals/BaseSprite") as AnimatedSprite2D
	if visual == null:
		return Vector3.ZERO
	return PlayerAnimationContract.hand_pose(visual.animation, visual.frame)


func _is_bow_drawing() -> bool:
	var interaction := get_node_or_null("../Interaction")
	return interaction != null and interaction.has_method("is_drawing_bow") and bool(interaction.call("is_drawing_bow"))


func _selected_item() -> ItemData:
	return _inventory.get_selected_item() if _inventory != null else null


func _player() -> Player:
	return get_parent() as Player


func _draw() -> void:
	var admin := get_node_or_null("/root/AdminManager")
	if admin == null or not bool(admin.get("show_weapon_debug")):
		return
	draw_line(Vector2.ZERO, _debug_aim.normalized() * 28.0, Color(0.2, 0.95, 0.35, 0.9), 1.5)
	if _attacking:
		draw_line(Vector2.ZERO, _debug_attack.normalized() * 28.0, Color(0.95, 0.2, 0.2, 0.9), 1.5)
	draw_circle(Vector2.ZERO, 2.0, Color(1, 0.9, 0.2, 1))
	if _hitbox != null:
		draw_circle(_tool_arm.position + Vector2(20, 0).rotated(_tool_arm.rotation), 2.0, Color(1, 0.4, 0.1, 1))
