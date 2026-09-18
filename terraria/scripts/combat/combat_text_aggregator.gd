class_name CombatTextAggregator
extends RefCounted

## Fasst nur die ANZEIGE wiederholter DOT-Ticks zusammen, nicht den Schaden.

var window: float = 0.28
var _pending: Dictionary = {}


func ingest(event: DamageEvent, now: float) -> Array[DamageEvent]:
	var ready: Array[DamageEvent] = flush_due(now)
	if event == null:
		return ready
	if not event.is_dot:
		ready.append(event)
		return ready
	var key := _key(event)
	if _pending.has(key):
		var bucket: Dictionary = _pending[key]
		var stored: DamageEvent = bucket.get("event")
		if stored != null:
			stored.amount = int(stored.amount) + event.amount
			stored.incoming_amount = int(stored.incoming_amount) + event.incoming_amount
			stored.world_position = event.world_position
		bucket["until"] = now + window
		_pending[key] = bucket
		return ready
	_pending[key] = {
		"event": event,
		"until": now + window,
	}
	return ready


func flush_due(now: float) -> Array[DamageEvent]:
	var out: Array[DamageEvent] = []
	var drop: Array = []
	for key in _pending.keys():
		var bucket: Dictionary = _pending[key]
		if now >= float(bucket.get("until", 0.0)):
			var stored: DamageEvent = bucket.get("event")
			if stored != null:
				out.append(stored)
			drop.append(key)
	for key in drop:
		_pending.erase(key)
	return out


func flush_all() -> Array[DamageEvent]:
	var out: Array[DamageEvent] = []
	for key in _pending.keys():
		var stored: DamageEvent = _pending[key].get("event")
		if stored != null:
			out.append(stored)
	_pending.clear()
	return out


func _key(event: DamageEvent) -> String:
	return "%d:%d:%d" % [event.target_id(), event.damage_type, int(event.critical)]
