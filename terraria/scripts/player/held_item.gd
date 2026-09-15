class_name HeldItem
extends Node2D

## Gehoert an: Player/ToolPivot. Zeigt das aktuell ausgewaehlte Hotbar-Item
## direkt in der Hand. Item-Basis kommt aus ItemData, Bewegung aus der
## Player-Animation, Use kommt vom AnimationPlayer.

@onready var _sprite: Sprite2D = $ToolArm/HeldItemSprite
@onready var _tool_arm: Node2D = $ToolArm
@onready var _inventory: Inventory = $"../Inventory"
@onready var _anim: AnimationPlayer = $"../AnimationPlayer"
@onready var _base_sprite: AnimatedSprite2D = $"../Visuals/BaseSprite"

var _base_offset := Vector2(2, 1)
var _base_pivot := Vector2.ZERO
var _base_rotation_deg: float = 0.0

func _ready() -> void:
	if _inventory != null:
		_inventory.inventory_changed.connect(refresh)
		_inventory.selected_slot_changed.connect(_on_selected_changed)
	call_deferred("refresh")


func _on_selected_changed(_index: int) -> void:
	refresh()


func _process(_delta: float) -> void:
	if _sprite == null or not _sprite.visible:
		return
	if _is_use_animation_playing():
		return
	_apply_pose()


func refresh() -> void:
	if _sprite == null:
		return
	var item := _inventory.get_selected_item() if _inventory != null else null
	var tex: Texture2D = item.get_held_texture() if item != null else null
	if item == null or tex == null:
		_sprite.visible = false
		_sprite.texture = null
		_sprite.rotation_degrees = 0.0
		_sprite.flip_h = false
		_sprite.flip_v = false
		_sprite.offset = Vector2.ZERO
		if _tool_arm != null and not _is_use_animation_playing():
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
	_sprite.rotation_degrees = _base_rotation_deg
	_sprite.flip_h = item.held_flip_h
	_sprite.flip_v = item.held_flip_v
	_base_offset = item.get_held_offset()
	_base_pivot = item.get_held_pivot_offset()
	_sprite.position = _base_offset
	_sprite.offset = _base_pivot
	if not _is_use_animation_playing():
		_apply_pose()


func _is_use_animation_playing() -> bool:
	if _anim == null or not _anim.is_playing():
		return false
	var current := _anim.current_animation
	return current == &"tool_swing" or current == &"block_place"


func _apply_pose() -> void:
	var pose := _pose_for_current_state()
	_tool_arm.position = Vector2(roundf(pose.x), roundf(pose.y))
	_tool_arm.rotation = deg_to_rad(pose.z)
	_sprite.position = _base_offset
	_sprite.offset = _base_pivot
	_sprite.rotation_degrees = _base_rotation_deg


func _pose_for_current_state() -> Vector3:
	if _base_sprite == null:
		return Vector3.ZERO
	var anim := _base_sprite.animation
	var frame := _base_sprite.frame
	match anim:
		&"walk":
			if frame == 0:
				return Vector3(-1, 1, -4)
			return Vector3(2, -1, 4)
		&"run":
			if frame == 0:
				return Vector3(-1, 1, -6)
			return Vector3(2, -1, 6)
		&"crouch_walk":
			if frame == 0:
				return Vector3(-1, 1, -3)
			return Vector3(1, 0, 3)
		&"jump":
			return Vector3(1, -1, -6)
		&"fall":
			return Vector3(0, 1, 4)
		&"use_tool":
			return Vector3.ZERO
		_:
			return Vector3.ZERO
