class_name DamageEvent
extends RefCounted

## Ergebnis eines Treffers oder einer Heilung. Combat Text liest nur dieses Objekt.

var amount: int = 0
var incoming_amount: int = 0
var damage_type: int = DamageTypes.Type.PHYSICAL
var element: int = DamageTypes.Type.PHYSICAL
var critical: bool = false
var source_node: Node = null
var target_node: Node = null
var weapon: Resource = null
var world_position: Vector2 = Vector2.ZERO
var blocked: bool = false
var reduced: bool = false
var ignore_armor: bool = false
var is_dot: bool = false
var is_player_target: bool = false
var killed: bool = false


static func outgoing_hit(p_amount: int, source: Node, target: Node, p_weapon: Resource = null) -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = maxi(p_amount, 0)
	event.incoming_amount = event.amount
	event.damage_type = DamageTypes.Type.PHYSICAL
	event.element = DamageTypes.Type.PHYSICAL
	event.source_node = source
	event.target_node = target
	event.weapon = p_weapon
	event.is_player_target = target is Player
	event.world_position = CombatTextSystem.anchor_of(target)
	return event


static func healing(p_amount: int, target: Node, source: Node = null) -> DamageEvent:
	var event := DamageEvent.new()
	event.amount = maxi(p_amount, 0)
	event.incoming_amount = event.amount
	event.damage_type = DamageTypes.Type.HEALING
	event.element = DamageTypes.Type.HEALING
	event.source_node = source
	event.target_node = target
	event.is_player_target = target is Player
	event.world_position = CombatTextSystem.anchor_of(target)
	return event


func target_id() -> int:
	if target_node != null and is_instance_valid(target_node):
		return target_node.get_instance_id()
	return 0


func is_heal() -> bool:
	return damage_type == DamageTypes.Type.HEALING
