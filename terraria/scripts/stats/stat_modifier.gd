@tool
class_name StatModifier
extends Resource

## Wiederverwendbarer Bonus/Malus. Items, Tränke und Upgrades nutzen dieselbe Form.

enum Type {
	FLAT,
	PERCENT,
}

enum SourceKind {
	OTHER,
	EQUIPMENT,
	WEAPON,
	ACCESSORY,
	CONSUMABLE,
	BUFF,
	DEBUFF,
	UPGRADE,
}

@export var stat: int = 0
@export var value: float = 0.0
@export var modifier_type: Type = Type.FLAT
@export var source: StringName = &""
@export var source_kind: SourceKind = SourceKind.OTHER
## -1 = dauerhaft. Sonst Sekunden.
@export var duration: float = -1.0

var remaining: float = -1.0


func _init(
		p_stat: int = 0,
		p_value: float = 0.0,
		p_type: Type = Type.FLAT,
		p_source: StringName = &"",
		p_kind: SourceKind = SourceKind.OTHER,
		p_duration: float = -1.0
	) -> void:
	stat = p_stat
	value = p_value
	modifier_type = p_type
	source = p_source
	source_kind = p_kind
	duration = p_duration
	remaining = p_duration


func is_timed() -> bool:
	return duration >= 0.0


func is_expired() -> bool:
	return is_timed() and remaining <= 0.0


func tick(delta: float) -> void:
	if not is_timed():
		return
	remaining = maxf(remaining - delta, 0.0)


func duplicate_runtime() -> StatModifier:
	var copy := StatModifier.new(stat, value, modifier_type, source, source_kind, duration)
	copy.remaining = remaining if remaining >= 0.0 else duration
	return copy


func to_dict() -> Dictionary:
	return {
		"stat": stat,
		"value": value,
		"type": int(modifier_type),
		"source": String(source),
		"kind": int(source_kind),
		"duration": duration,
		"remaining": remaining,
	}


static func from_dict(data: Dictionary) -> StatModifier:
	var mod := StatModifier.new(
		int(data.get("stat", 0)),
		float(data.get("value", 0.0)),
		int(data.get("type", 0)) as Type,
		StringName(str(data.get("source", ""))),
		int(data.get("kind", 0)) as SourceKind,
		float(data.get("duration", -1.0))
	)
	mod.remaining = float(data.get("remaining", mod.duration))
	return mod
