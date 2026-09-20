@tool
class_name MusicCatalog
extends Resource

## Zentrale Trackliste. Neue Stuecke als MusicTrackData anlegen und hier eintragen.

@export var tracks: Array[MusicTrackData] = []
@export var fallback_id: StringName = &"menu"


func get_by_id(track_id: StringName) -> MusicTrackData:
	for track in tracks:
		if track != null and track.id == track_id:
			return track
	return null


func resolve(ctx: MusicContext) -> MusicTrackData:
	var best: MusicTrackData = null
	for track in tracks:
		if track == null or not track.matches(ctx):
			continue
		if best == null or track.priority > best.priority:
			best = track
	if best != null:
		return best
	return get_by_id(fallback_id)
