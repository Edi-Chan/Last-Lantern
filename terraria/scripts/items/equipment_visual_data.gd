class_name EquipmentVisualData
extends Resource


## Nur Grafik. Keine Animations-State-Machine.
## Frames muessen den PlayerAnimationContract erfuellen.

enum HairPolicy {
	SHOW_HAIR,
	HIDE_HAIR,
	SHOW_PARTIAL_HAIR,
}

@export var sprite_frames: SpriteFrames
@export var modulate: Color = Color.WHITE
@export var hair_policy: HairPolicy = HairPolicy.SHOW_HAIR
