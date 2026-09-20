@tool
class_name AmbientLayerData
extends Resource

## Wind, Voegel, Insekten, Hoehle. Mehrere Beds koennen gleichzeitig laufen.

enum Kind { BED, ONESHOT }

@export var id: StringName = &""
@export var display_name: String = ""
@export var stream: AudioStream
@export var stream_path: String = ""
@export var stream_paths: Array[String] = []
@export var volume_db: float = -10.0
@export var kind: Kind = Kind.BED
@export var fade_seconds: float = 1.8
@export var oneshot_min: float = 4.0
@export var oneshot_max: float = 10.0
@export var priority: int = 0
@export var enabled: bool = true

@export_group("Filter")
@export var scenes: Array[StringName] = [&"world"]
@export var biomes: Array[StringName] = []
@export var day_phases: Array[StringName] = []
@export var depth_layers: Array[StringName] = []
@export var fog_states: Array[StringName] = [&"clear"]
@export var interiors: Array[StringName] = [&"WORLD"]


func matches(ctx: MusicContext) -> bool:
	if not enabled or ctx == null:
		return false
	return (
		_allows(scenes, ctx.scene)
		and _allows(biomes, ctx.biome)
		and _allows(day_phases, ctx.day_phase)
		and _allows(depth_layers, ctx.depth_layer)
		and _allows(fog_states, ctx.fog_state)
		and _allows(interiors, ctx.interior)
	)


func resolved_stream() -> AudioStream:
	var path := pick_path()
	if path.is_empty() and stream != null:
		path = stream.resource_path
	if path.is_empty():
		return stream
	return WavLoader.playable(path, kind == Kind.BED)


func pick_path() -> String:
	if not stream_paths.is_empty():
		return stream_paths[randi() % stream_paths.size()]
	return stream_path


func _allows(allowed: Array[StringName], value: StringName) -> bool:
	return allowed.is_empty() or allowed.has(value)
