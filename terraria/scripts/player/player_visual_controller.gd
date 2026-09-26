class_name PlayerVisualController
extends Node2D


## Master fuer Pose, Frame, Facing und Equipment-Layer.
## Layer besitzen keine eigene State Machine. Sie kopieren den Master.

signal pose_changed(anim: StringName, frame: int, flip_h: bool)

const LAYER_DEFS := [
	{"name": &"HairBack", "frames": "res://resources/player/hair_back_frames.tres", "z": 0, "kind": &"hair_back"},
	{"name": &"BaseSprite", "frames": "res://resources/player/body_frames.tres", "z": 1, "kind": &"body"},
	{"name": &"ClothingLegs", "frames": "res://resources/player/pants_frames.tres", "z": 2, "kind": &"pants"},
	{"name": &"ClothingShoes", "frames": "res://resources/player/shoes_frames.tres", "z": 3, "kind": &"shoes"},
	{"name": &"ClothingChest", "frames": "res://resources/player/shirt_frames.tres", "z": 4, "kind": &"shirt"},
	{"name": &"LegArmorSprite", "frames": "", "z": 5, "kind": &"armor_legs"},
	{"name": &"ChestArmorSprite", "frames": "", "z": 6, "kind": &"armor_chest"},
	{"name": &"HairFront", "frames": "res://resources/player/hair_front_frames.tres", "z": 7, "kind": &"hair_front"},
	{"name": &"HelmetSprite", "frames": "", "z": 8, "kind": &"armor_head"},
	{"name": &"VisualEffects", "frames": "", "z": 9, "kind": &"fx"},
]

const DEFAULT_SKIN := Color(224.0 / 255.0, 176.0 / 255.0, 138.0 / 255.0)
const DEFAULT_HAIR := Color(122.0 / 255.0, 72.0 / 255.0, 38.0 / 255.0)
const DEFAULT_SHIRT := Color(52.0 / 255.0, 108.0 / 255.0, 176.0 / 255.0)
const DEFAULT_PANTS := Color(118.0 / 255.0, 74.0 / 255.0, 44.0 / 255.0)
const DEFAULT_SHOES := Color(62.0 / 255.0, 42.0 / 255.0, 32.0 / 255.0)

var current_animation: StringName = &"idle"
var current_frame: int = 0
var facing_left: bool = false
var appearance: LookRecord

var _layers: Dictionary = {}
var _last_key: String = ""
var _preview_cache: Texture2D
var _preview_dirty: bool = true
var _missing_warned: Dictionary = {}
var _hair_policy: int = PlayerAnimationContract.HairPolicy.SHOW_HAIR
var _body: AnimatedSprite2D
var _locomotion_accum: float = 0.0


func _ready() -> void:
	scale = Vector2.ONE
	_ensure_layers()
	play(&"idle", true)


func body_sprite() -> AnimatedSprite2D:
	return _body


func _ensure_layers() -> void:
	for spec in LAYER_DEFS:
		var node_name: StringName = spec["name"]
		var sprite := get_node_or_null(NodePath(String(node_name))) as AnimatedSprite2D
		if sprite == null:
			sprite = AnimatedSprite2D.new()
			sprite.name = String(node_name)
			add_child(sprite)
		sprite.centered = true
		sprite.position = PlayerAnimationContract.SPRITE_OFFSET
		sprite.offset = Vector2.ZERO
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.z_index = int(spec["z"])
		sprite.speed_scale = 0.0
		var frames_path := str(spec["frames"])
		if not frames_path.is_empty() and ResourceLoader.exists(frames_path):
			sprite.sprite_frames = load(frames_path) as SpriteFrames
		var kind: StringName = spec["kind"]
		_layers[kind] = sprite
		if kind == &"armor_legs" or kind == &"armor_chest" or kind == &"armor_head" or kind == &"fx":
			sprite.visible = kind != &"fx" and sprite.sprite_frames != null
		else:
			sprite.visible = sprite.sprite_frames != null
	_body = _layers.get(&"body") as AnimatedSprite2D
	if _body == null:
		_body = get_node_or_null("BaseSprite") as AnimatedSprite2D


func play(anim: StringName, force: bool = false) -> void:
	if not force and current_animation == anim:
		return
	var resolved := _resolve_anim(_body, anim)
	current_animation = resolved
	current_frame = 0
	_locomotion_accum = 0.0
	_preview_dirty = true
	_sync(true)


func set_frame(frame: int) -> void:
	var count := PlayerAnimationContract.frame_count(current_animation)
	var next := clampi(frame, 0, maxi(count - 1, 0))
	if next == current_frame:
		return
	current_frame = next
	_sync(false)


func set_facing(left: bool) -> void:
	if facing_left == left:
		return
	facing_left = left
	_sync(false)


func advance_locomotion(delta: float) -> void:
	var spec := PlayerAnimationContract.spec_for(current_animation)
	if spec.is_empty():
		return
	var fps := float(spec.get("fps", 8.0))
	if fps <= 0.0:
		return
	var count := int(spec.get("frames", 1))
	if count <= 1:
		return
	var next := current_frame
	_locomotion_accum += delta * fps
	var looping := bool(spec.get("loop", true))
	while _locomotion_accum >= 1.0:
		_locomotion_accum -= 1.0
		if looping:
			next = (next + 1) % count
		else:
			next = mini(next + 1, count - 1)
	if next != current_frame:
		current_frame = next
		_sync(false)


func sync_action_from_player(anim_player: AnimationPlayer) -> void:
	if anim_player == null or not anim_player.is_playing():
		return
	var spec := PlayerAnimationContract.spec_for(current_animation)
	var count := int(spec.get("frames", 1))
	if count <= 1:
		set_frame(0)
		return
	var length := maxf(anim_player.current_animation_length, 0.001)
	var t := clampf(anim_player.current_animation_position / length, 0.0, 0.999)
	set_frame(int(t * float(count)))


func sync_bow_draw(charge: float) -> void:
	play(&"bow_draw")
	var count := PlayerAnimationContract.frame_count(&"bow_draw")
	set_frame(int(clampf(charge, 0.0, 0.999) * float(maxi(count, 1))))


func apply_appearance(data: LookRecord) -> void:
	appearance = data
	_preview_dirty = true
	_apply_tints()
	_sync(true)


func apply_equipment(inventory: Inventory) -> void:
	if inventory == null:
		return
	_apply_armor_item(&"armor_legs", inventory.get_equipment_item("legs"))
	_apply_armor_item(&"armor_chest", inventory.get_equipment_item("chest"))
	_apply_armor_item(&"armor_head", inventory.get_equipment_item("head"))
	_hair_policy = _resolve_hair_policy(inventory.get_equipment_item("head"))
	_apply_hair_visibility()
	_preview_dirty = true
	_sync(true)


func compose_preview_texture() -> Texture2D:
	if not _preview_dirty and _preview_cache != null:
		return _preview_cache
	var image: Image = null
	for spec in LAYER_DEFS:
		var kind: StringName = spec["kind"]
		var sprite := _layers.get(kind) as AnimatedSprite2D
		if sprite == null or not sprite.visible or sprite.sprite_frames == null:
			continue
		var anim := _resolve_anim(sprite, &"idle")
		var tex := sprite.sprite_frames.get_frame_texture(anim, 0)
		if tex == null:
			continue
		var overlay := tex.get_image()
		if overlay == null:
			continue
		overlay = overlay.duplicate()
		if sprite.modulate != Color.WHITE:
			_modulate_image(overlay, sprite.modulate)
		if image == null:
			image = overlay
		else:
			image.blend_rect(overlay, Rect2i(Vector2i.ZERO, overlay.get_size()), Vector2i.ZERO)
	if image == null:
		return null
	_preview_cache = ImageTexture.create_from_image(image)
	_preview_dirty = false
	return _preview_cache


func invalidate_preview() -> void:
	_preview_dirty = true


func _sync(force: bool) -> void:
	var key := "%s:%d:%s" % [String(current_animation), current_frame, str(facing_left)]
	if not force and key == _last_key:
		return
	_last_key = key
	var flip := facing_left
	for spec in LAYER_DEFS:
		var kind: StringName = spec["kind"]
		var sprite := _layers.get(kind) as AnimatedSprite2D
		if sprite == null or sprite.sprite_frames == null:
			continue
		if kind == &"fx":
			continue
		if not sprite.visible:
			continue
		var anim := _resolve_anim(sprite, current_animation)
		if sprite.animation != anim:
			sprite.animation = anim
		var count := sprite.sprite_frames.get_frame_count(anim) if sprite.sprite_frames.has_animation(anim) else 1
		sprite.frame = clampi(current_frame, 0, maxi(count - 1, 0))
		sprite.flip_h = flip
		sprite.speed_scale = 0.0
	if _body != null:
		_body.flip_h = flip
	pose_changed.emit(current_animation, current_frame, flip)


func _resolve_anim(sprite: AnimatedSprite2D, anim: StringName) -> StringName:
	if sprite == null or sprite.sprite_frames == null:
		return PlayerAnimationContract.FALLBACK_ANIM
	if sprite.sprite_frames.has_animation(anim):
		return anim
	var key := "%s:%s" % [sprite.name, String(anim)]
	if not _missing_warned.has(key):
		_missing_warned[key] = true
		push_warning("%s missing animation: %s" % [sprite.name, String(anim)])
	if sprite.sprite_frames.has_animation(PlayerAnimationContract.FALLBACK_ANIM):
		return PlayerAnimationContract.FALLBACK_ANIM
	var names := sprite.sprite_frames.get_animation_names()
	if names.is_empty():
		return anim
	return names[0]


func _apply_armor_item(kind: StringName, item: ItemData) -> void:
	var sprite := _layers.get(kind) as AnimatedSprite2D
	if sprite == null:
		return
	if item == null:
		sprite.visible = false
		sprite.sprite_frames = null
		sprite.modulate = Color.WHITE
		return
	var frames := item.resolve_armor_frames() if item.has_method("resolve_armor_frames") else item.armor_sprite_frames
	if frames == null:
		sprite.visible = false
		sprite.modulate = Color.WHITE
		return
	sprite.sprite_frames = frames
	sprite.speed_scale = 0.0
	sprite.visible = true
	sprite.modulate = item.resolve_armor_modulate() if item.has_method("resolve_armor_modulate") else Color.WHITE
	_validate_armor_frames(sprite, item)


func _validate_armor_frames(sprite: AnimatedSprite2D, item: ItemData) -> void:
	if sprite.sprite_frames == null:
		return
	for spec in PlayerAnimationContract.ANIMS:
		var anim: StringName = spec["name"]
		if sprite.sprite_frames.has_animation(anim):
			var got := sprite.sprite_frames.get_frame_count(anim)
			var want := int(spec["frames"])
			if got != want:
				var key := "%s:%s:count" % [sprite.name, String(anim)]
				if not _missing_warned.has(key):
					_missing_warned[key] = true
					push_warning("%s (%s) animation %s has %d frames, contract expects %d" % [
						String(item.display_name) if item != null else String(sprite.name),
						String(sprite.name),
						String(anim),
						got,
						want,
					])
			continue
		var key_miss := "%s:%s" % [sprite.name, String(anim)]
		if _missing_warned.has(key_miss):
			continue
		_missing_warned[key_miss] = true
		push_warning("%s missing animation: %s" % [String(item.display_name) if item != null else String(sprite.name), String(anim)])


func _resolve_hair_policy(head_item: ItemData) -> int:
	if head_item == null:
		return PlayerAnimationContract.HairPolicy.SHOW_HAIR
	if head_item.has_method("resolve_hair_policy"):
		return int(head_item.call("resolve_hair_policy"))
	if head_item.armor_sprite_frames != null or (head_item.equipment_visual != null):
		return PlayerAnimationContract.HairPolicy.HIDE_HAIR
	return PlayerAnimationContract.HairPolicy.SHOW_HAIR


func _apply_hair_visibility() -> void:
	var back := _layers.get(&"hair_back") as AnimatedSprite2D
	var front := _layers.get(&"hair_front") as AnimatedSprite2D
	match _hair_policy:
		PlayerAnimationContract.HairPolicy.HIDE_HAIR:
			if back != null:
				back.visible = false
			if front != null:
				front.visible = false
		PlayerAnimationContract.HairPolicy.SHOW_PARTIAL_HAIR:
			if back != null:
				back.visible = back.sprite_frames != null
			if front != null:
				front.visible = false
		_:
			if back != null:
				back.visible = back.sprite_frames != null
			if front != null:
				front.visible = front.sprite_frames != null


func _apply_tints() -> void:
	var look := appearance
	_tint(_layers.get(&"body") as AnimatedSprite2D, DEFAULT_SKIN, look.skin_color if look != null else DEFAULT_SKIN)
	_tint(_layers.get(&"hair_back") as AnimatedSprite2D, DEFAULT_HAIR, look.hair_color if look != null else DEFAULT_HAIR)
	_tint(_layers.get(&"hair_front") as AnimatedSprite2D, DEFAULT_HAIR, look.hair_color if look != null else DEFAULT_HAIR)
	_tint(_layers.get(&"shirt") as AnimatedSprite2D, DEFAULT_SHIRT, look.shirt_color if look != null else DEFAULT_SHIRT)
	_tint(_layers.get(&"pants") as AnimatedSprite2D, DEFAULT_PANTS, look.pants_color if look != null else DEFAULT_PANTS)
	_tint(_layers.get(&"shoes") as AnimatedSprite2D, DEFAULT_SHOES, look.shoes_color if look != null else DEFAULT_SHOES)


func _tint(sprite: AnimatedSprite2D, drawn: Color, target: Color) -> void:
	if sprite == null:
		return
	if target.a <= 0.0 or target.is_equal_approx(drawn):
		sprite.modulate = Color.WHITE
		return
	var ratio := Color(
		clampf(target.r / maxf(drawn.r, 0.04), 0.35, 1.85),
		clampf(target.g / maxf(drawn.g, 0.04), 0.35, 1.85),
		clampf(target.b / maxf(drawn.b, 0.04), 0.35, 1.85),
		1.0
	)
	sprite.modulate = ratio


func _modulate_image(image: Image, color: Color) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var px := image.get_pixel(x, y)
			if px.a <= 0.0:
				continue
			image.set_pixel(x, y, Color(px.r * color.r, px.g * color.g, px.b * color.b, px.a * color.a))
