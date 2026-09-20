@tool
class_name WavLoader
extends RefCounted

## Laedt Audio zum Abspielen. Zuerst Godot-Import, sonst PCM aus der Datei.


static func playable(path: String, loop: bool) -> AudioStream:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		var loaded := ResourceLoader.load(path)
		if loaded is AudioStreamWAV:
			var wav := (loaded as AudioStreamWAV).duplicate() as AudioStreamWAV
			if loop:
				_force_loop(wav)
			else:
				wav.loop_mode = AudioStreamWAV.LOOP_DISABLED
			return wav
		if loaded is AudioStreamOggVorbis:
			var ogg := (loaded as AudioStreamOggVorbis).duplicate() as AudioStreamOggVorbis
			ogg.loop = loop
			return ogg
		if loaded is AudioStream:
			return loaded
	return load_loop(path) if loop else load_stream(path)


static func load_loop(path: String) -> AudioStreamWAV:
	var stream := load_stream(path)
	if stream != null:
		_force_loop(stream)
	return stream


static func load_stream(path: String) -> AudioStreamWAV:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF":
		return null
	var offset := 12
	var channels := 1
	var rate := 22050
	var bits := 16
	var data := PackedByteArray()
	while offset + 8 <= bytes.size():
		var chunk := bytes.slice(offset, offset + 4).get_string_from_ascii()
		var size := bytes.decode_u32(offset + 4)
		var body := offset + 8
		if chunk == "fmt " and size >= 16:
			channels = bytes.decode_u16(body + 2)
			rate = bytes.decode_u32(body + 4)
			bits = bytes.decode_u16(body + 14)
		elif chunk == "data":
			data = bytes.slice(body, mini(body + size, bytes.size()))
			break
		offset = body + size + (size & 1)
	if data.is_empty() or bits != 16:
		return null
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.stereo = channels > 1
	stream.data = data
	return stream


static func _force_loop(wav: AudioStreamWAV) -> void:
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	var frame_bytes := 2
	if wav.stereo:
		frame_bytes = 4
	wav.loop_end = maxi(wav.data.size() / frame_bytes, 1)
