class_name PlayerAim
extends RefCounted

## Zentrale Maus-Aim-Mathematik. Keine Nodes, keine Ressourcen pro Frame.

const FACING_DEADZONE := 10.0
const MIN_AIM_LENGTH_SQ := 1.0
## Leicht gegen den Uhrzeigersinn (oben), damit Schwert/Tools nicht zu flach liegen.
const SWING_RAISE := 0.28


static func world_direction(origin: Vector2, mouse: Vector2, fallback: Vector2) -> Vector2:
	var delta := mouse - origin
	if delta.length_squared() < MIN_AIM_LENGTH_SQ:
		if fallback.length_squared() < MIN_AIM_LENGTH_SQ:
			return Vector2.RIGHT
		return fallback.normalized()
	return delta.normalized()


static func facing_sign_from_delta_x(delta_x: float, current: float, deadzone: float = FACING_DEADZONE) -> float:
	if absf(delta_x) < deadzone:
		return current if current != 0.0 else 1.0
	return 1.0 if delta_x > 0.0 else -1.0


static func needs_vertical_flip(direction: Vector2) -> bool:
	return direction.x < 0.0


static func uses_live_aim(action: int) -> bool:
	match action:
		ItemData.ActionType.THRUST, ItemData.ActionType.STAB, ItemData.ActionType.BOW:
			return true
		_:
			return false


static func uses_thrust(action: int) -> bool:
	return action == int(ItemData.ActionType.THRUST) or action == int(ItemData.ActionType.STAB)


static func uses_swing(action: int) -> bool:
	match action:
		ItemData.ActionType.SWING, ItemData.ActionType.OVERHEAD, ItemData.ActionType.CHOP, ItemData.ActionType.MINE, ItemData.ActionType.NONE, ItemData.ActionType.LANTERN:
			return true
		_:
			return false


static func swing_arc(action: int) -> float:
	match action:
		ItemData.ActionType.OVERHEAD:
			return 2.9
		ItemData.ActionType.CHOP:
			return 2.7
		ItemData.ActionType.MINE:
			return 2.55
		ItemData.ActionType.LANTERN:
			return 1.4
		ItemData.ActionType.NONE:
			return 2.1
		_:
			return 2.35


static func thrust_max(action: int) -> float:
	return 11.0 if action == int(ItemData.ActionType.STAB) else 18.0


static func thrust_windup(action: int) -> float:
	return 4.0 if action == int(ItemData.ActionType.STAB) else 8.0


static func swing_angle(progress: float, attack_angle: float, arc: float, facing_sign: float = 1.0) -> float:
	## Nicht lerp_angle: links waere der kuerzeste Weg ueber rechts und die Waffe kreist.
	var t := _ease_swing(clampf(progress, 0.0, 1.0))
	var facing := 1.0 if facing_sign >= 0.0 else -1.0
	var center := attack_angle - facing * SWING_RAISE
	var start := center - facing * arc * 0.5
	var end := center + facing * arc * 0.5
	return start + (end - start) * t


static func thrust_distance(progress: float, max_dist: float, windup: float) -> float:
	var p := clampf(progress, 0.0, 1.0)
	if p < 0.33:
		return lerpf(0.0, -windup, p / 0.33)
	if p < 0.55:
		return lerpf(-windup, max_dist, (p - 0.33) / 0.22)
	if p < 0.67:
		return max_dist
	return lerpf(max_dist, 0.0, (p - 0.67) / 0.33)


static func rest_angle(facing_sign: float) -> float:
	var facing := 1.0 if facing_sign >= 0.0 else -1.0
	var base := 0.0 if facing >= 0.0 else PI
	return base - facing * SWING_RAISE


static func _ease_swing(t: float) -> float:
	if t < 0.22:
		return 0.12 * (t / 0.22)
	if t < 0.55:
		var u := (t - 0.22) / 0.33
		return lerpf(0.12, 1.0, u * u)
	return 1.0
