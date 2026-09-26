class_name PlayerAnimationContract
extends RefCounted


## Verbindliches Frame-Layout fuer alle Character-Layer.
## Ruestung und Kleidung folgen denselben Namen, Frame-Zahlen und Pivots.
## Master ist der Player-Koerper. Layer besitzen keine eigene State Machine.

const FRAME_WIDTH := 40
const FRAME_HEIGHT := 56
const FOOT_ORIGIN_Y := 55
const PIVOT := Vector2(20, 56)
const SPRITE_OFFSET := Vector2(0, -28)
const MAX_COLUMNS := 6

enum ActionType {
	NONE,
	SWING,
	OVERHEAD,
	THRUST,
	CHOP,
	MINE,
	STAB,
	BOW,
	PLACE,
	INTERACT,
	LANTERN,
}

enum HairPolicy {
	SHOW_HAIR,
	HIDE_HAIR,
	SHOW_PARTIAL_HAIR,
}

const ANIMS: Array[Dictionary] = [
	{"name": &"idle", "frames": 4, "fps": 6.0, "loop": true},
	{"name": &"idle_alt", "frames": 3, "fps": 5.0, "loop": true},
	{"name": &"walk", "frames": 6, "fps": 10.0, "loop": true},
	{"name": &"run", "frames": 6, "fps": 14.0, "loop": true},
	{"name": &"crouch_idle", "frames": 2, "fps": 5.0, "loop": true},
	{"name": &"crouch_walk", "frames": 4, "fps": 8.0, "loop": true},
	{"name": &"jump_start", "frames": 2, "fps": 14.0, "loop": false},
	{"name": &"jump", "frames": 2, "fps": 8.0, "loop": true},
	{"name": &"fall", "frames": 2, "fps": 8.0, "loop": true},
	{"name": &"land", "frames": 2, "fps": 12.0, "loop": false},
	{"name": &"swim_idle", "frames": 4, "fps": 6.0, "loop": true},
	{"name": &"swim", "frames": 6, "fps": 10.0, "loop": true},
	{"name": &"ladder_idle", "frames": 1, "fps": 5.0, "loop": true},
	{"name": &"ladder_climb", "frames": 4, "fps": 8.0, "loop": true},
	{"name": &"hurt", "frames": 2, "fps": 12.0, "loop": false},
	{"name": &"death", "frames": 4, "fps": 8.0, "loop": false},
	{"name": &"sleep", "frames": 2, "fps": 3.0, "loop": true},
	{"name": &"use_swing", "frames": 6, "fps": 16.0, "loop": false},
	{"name": &"use_overhead", "frames": 5, "fps": 14.0, "loop": false},
	{"name": &"use_thrust", "frames": 5, "fps": 14.0, "loop": false},
	{"name": &"use_chop", "frames": 5, "fps": 14.0, "loop": false},
	{"name": &"use_mine", "frames": 5, "fps": 14.0, "loop": false},
	{"name": &"use_stab", "frames": 4, "fps": 18.0, "loop": false},
	{"name": &"bow_draw", "frames": 3, "fps": 10.0, "loop": false},
	{"name": &"bow_release", "frames": 3, "fps": 14.0, "loop": false},
	{"name": &"block_place", "frames": 3, "fps": 12.0, "loop": false},
	{"name": &"interact", "frames": 3, "fps": 10.0, "loop": false},
	{"name": &"use_tool", "frames": 1, "fps": 5.0, "loop": true},
]

const LAYER_ORDER: Array[StringName] = [
	&"HairBack",
	&"BaseSprite",
	&"ClothingLegs",
	&"ClothingShoes",
	&"ClothingChest",
	&"LegArmorSprite",
	&"ChestArmorSprite",
	&"HairFront",
	&"HelmetSprite",
	&"VisualEffects",
]

const FALLBACK_ANIM := &"idle"


const ACTION_SPECS := {
	ActionType.SWING: {
		"anim": &"use_swing",
		"clip": &"use_swing",
		"fallback_clip": &"sword_swing",
		"length": 0.36,
		"hit_start": 0.10,
		"hit_end": 0.24,
		"item_front_after": 0.10,
	},
	ActionType.OVERHEAD: {
		"anim": &"use_overhead",
		"clip": &"use_overhead",
		"fallback_clip": &"sword_swing",
		"length": 0.36,
		"hit_start": 0.12,
		"hit_end": 0.24,
		"item_front_after": 0.12,
	},
	ActionType.THRUST: {
		"anim": &"use_thrust",
		"clip": &"use_thrust",
		"fallback_clip": &"spear_thrust",
		"length": 0.42,
		"hit_start": 0.16,
		"hit_end": 0.28,
		"item_front_after": 0.14,
	},
	ActionType.CHOP: {
		"anim": &"use_chop",
		"clip": &"use_chop",
		"fallback_clip": &"tool_swing",
		"length": 0.38,
		"hit_start": 0.12,
		"hit_end": 0.26,
		"item_front_after": 0.12,
	},
	ActionType.MINE: {
		"anim": &"use_mine",
		"clip": &"use_mine",
		"fallback_clip": &"tool_swing",
		"length": 0.38,
		"hit_start": 0.12,
		"hit_end": 0.26,
		"item_front_after": 0.12,
	},
	ActionType.STAB: {
		"anim": &"use_stab",
		"clip": &"use_stab",
		"fallback_clip": &"spear_thrust",
		"length": 0.22,
		"hit_start": 0.06,
		"hit_end": 0.14,
		"item_front_after": 0.04,
	},
	ActionType.BOW: {
		"anim": &"bow_release",
		"clip": &"bow_release",
		"fallback_clip": &"bow_shot",
		"length": 0.28,
		"hit_start": 1.0,
		"hit_end": 1.0,
		"item_front_after": 0.0,
	},
	ActionType.PLACE: {
		"anim": &"block_place",
		"clip": &"block_place",
		"fallback_clip": &"block_place",
		"length": 0.18,
		"hit_start": 1.0,
		"hit_end": 1.0,
		"item_front_after": 0.0,
	},
	ActionType.INTERACT: {
		"anim": &"interact",
		"clip": &"interact",
		"fallback_clip": &"block_place",
		"length": 0.24,
		"hit_start": 1.0,
		"hit_end": 1.0,
		"item_front_after": 0.0,
	},
	ActionType.LANTERN: {
		"anim": &"use_swing",
		"clip": &"lantern_burst",
		"fallback_clip": &"tool_swing",
		"length": 0.50,
		"hit_start": 0.18,
		"hit_end": 0.32,
		"item_front_after": 0.12,
	},
	ActionType.NONE: {
		"anim": &"use_mine",
		"clip": &"use_mine",
		"fallback_clip": &"tool_swing",
		"length": 0.30,
		"hit_start": 0.08,
		"hit_end": 0.18,
		"item_front_after": 0.08,
	},
}

const COMBAT_CLIPS: Array[StringName] = [
	&"use_swing",
	&"use_overhead",
	&"use_thrust",
	&"use_chop",
	&"use_mine",
	&"use_stab",
	&"bow_release",
	&"bow_shot",
	&"lantern_burst",
	&"sword_swing",
	&"spear_thrust",
	&"tool_swing",
]

const LOCOMOTION_ANIMS: Array[StringName] = [
	&"idle", &"idle_alt", &"walk", &"run",
	&"crouch_idle", &"crouch_walk",
	&"jump_start", &"jump", &"fall", &"land",
	&"swim_idle", &"swim",
	&"ladder_idle", &"ladder_climb",
]


static func anim_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for spec in ANIMS:
		names.append(spec["name"])
	return names


static func spec_for(anim: StringName) -> Dictionary:
	for spec in ANIMS:
		if spec["name"] == anim:
			return spec
	return {}


static func frame_count(anim: StringName) -> int:
	var spec := spec_for(anim)
	return int(spec.get("frames", 1))


static func row_index(anim: StringName) -> int:
	for i in ANIMS.size():
		if ANIMS[i]["name"] == anim:
			return i
	return -1


static func sheet_size() -> Vector2i:
	return Vector2i(MAX_COLUMNS * FRAME_WIDTH, ANIMS.size() * FRAME_HEIGHT)


static func cell_rect(anim: StringName, frame: int) -> Rect2:
	var row := row_index(anim)
	var col := clampi(frame, 0, MAX_COLUMNS - 1)
	return Rect2(col * FRAME_WIDTH, maxi(row, 0) * FRAME_HEIGHT, FRAME_WIDTH, FRAME_HEIGHT)


static func action_spec(action: int) -> Dictionary:
	if ACTION_SPECS.has(action):
		return ACTION_SPECS[action]
	return ACTION_SPECS[ActionType.NONE]


static func is_combat_clip(name: StringName) -> bool:
	return COMBAT_CLIPS.has(name)


static func is_locomotion(name: StringName) -> bool:
	return LOCOMOTION_ANIMS.has(name)


static func resolve_action_type(item: ItemData) -> int:
	if item == null:
		return ActionType.NONE
	if item.has_method("resolve_action_type"):
		return int(item.call("resolve_action_type"))
	return ActionType.NONE


static func body_anim_for_action(action: int) -> StringName:
	return StringName(str(action_spec(action).get("anim", &"use_swing")))


static func body_anim_for_clip(clip: StringName) -> StringName:
	match clip:
		&"use_swing", &"sword_swing":
			return &"use_swing"
		&"use_overhead":
			return &"use_overhead"
		&"use_thrust", &"spear_thrust":
			return &"use_thrust"
		&"use_chop":
			return &"use_chop"
		&"use_mine", &"tool_swing":
			return &"use_mine"
		&"use_stab":
			return &"use_stab"
		&"bow_release", &"bow_shot":
			return &"bow_release"
		&"lantern_burst":
			return &"use_swing"
		&"block_place":
			return &"block_place"
		&"interact":
			return &"interact"
		_:
			return &"use_mine"


static func hand_pose(anim: StringName, frame: int) -> Vector3:
	match anim:
		&"walk":
			var walk_poses: Array[Vector3] = [
				Vector3(-1, 1, -5), Vector3(0, 0, -2), Vector3(2, -1, 4),
				Vector3(1, 1, 5), Vector3(0, 0, 2), Vector3(-1, -1, -4),
			]
			return walk_poses[clampi(frame, 0, walk_poses.size() - 1)]
		&"run":
			var run_poses: Array[Vector3] = [
				Vector3(-2, 1, -8), Vector3(0, 0, -3), Vector3(3, -1, 7),
				Vector3(2, 1, 8), Vector3(0, 0, 3), Vector3(-2, -1, -7),
			]
			return run_poses[clampi(frame, 0, run_poses.size() - 1)]
		&"crouch_walk":
			var crouch_poses: Array[Vector3] = [
				Vector3(-1, 1, -3), Vector3(0, 0, 0), Vector3(1, 0, 3), Vector3(0, 1, 0),
			]
			return crouch_poses[clampi(frame, 0, crouch_poses.size() - 1)]
		&"jump_start", &"jump":
			return Vector3(1, -2, -8)
		&"fall":
			return Vector3(0, 1, 5)
		&"land":
			return Vector3(0, 2, 2)
		&"swim", &"swim_idle":
			return Vector3(2, 0, -10)
		&"ladder_climb", &"ladder_idle":
			return Vector3(-2, -4, -20)
		&"hurt":
			return Vector3(-2, 1, 8)
		&"death", &"sleep":
			return Vector3(0, 4, 12)
		&"bow_draw":
			return Vector3(-2 - frame, 0, 0)
		&"use_swing", &"use_overhead", &"use_chop", &"use_mine", &"use_thrust", &"use_stab", &"use_tool", &"bow_release", &"block_place", &"interact":
			return Vector3.ZERO
		_:
			return Vector3.ZERO
