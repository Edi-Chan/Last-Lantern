@tool
class_name MusicTrackData
extends Resource

## Ein Stueck Hintergrundmusik. Leere Filter = Wildcard. Hoehere Priority gewinnt.

@export var id: StringName = &""
@export var display_name: String = ""
@export var stream: AudioStream
@export var stream_path: String = ""
@export var stems: Array[MusicStemData] = []
@export var volume_db: float = -3.0
@export var crossfade_seconds: float = 2.8
@export var priority: int = 0
@export var enabled: bool = true

@export_group("Filter")
@export var scenes: Array[StringName] = []
@export var biomes: Array[StringName] = []
@export var day_phases: Array[StringName] = []
@export var depth_layers: Array[StringName] = []
@export var fog_states: Array[StringName] = []
@export var interiors: Array[StringName] = []
@export var cues: Array[StringName] = []


func resolved_stream() -> AudioStream:
	if not stream_path.is_empty():
		var loaded := WavLoader.playable(stream_path, true)
		if loaded != null:
			return loaded
	if stream != null:
		if not stream.resource_path.is_empty():
			return WavLoader.playable(stream.resource_path, true)
		return stream
	return null


func matches(ctx: MusicContext) -> bool:
	if not enabled or ctx == null:
		return false
	if ctx.cue != &"":
		if cues.is_empty() or not cues.has(ctx.cue):
			return false
	elif not cues.is_empty():
		return false
	return (
		_allows(scenes, ctx.scene)
		and _allows(biomes, ctx.biome)
		and _allows(day_phases, ctx.day_phase)
		and _allows(depth_layers, ctx.depth_layer)
		and _allows(fog_states, ctx.fog_state)
		and _allows(interiors, ctx.interior)
	)


func _allows(allowed: Array[StringName], value: StringName) -> bool:
	return allowed.is_empty() or allowed.has(value)
