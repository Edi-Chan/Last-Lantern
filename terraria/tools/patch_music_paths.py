from pathlib import Path

root = Path(__file__).resolve().parents[1] / "resources" / "audio" / "music"
for path in root.glob("*.tres"):
    if path.name == "music_catalog.tres":
        continue
    text = path.read_text(encoding="utf-8")
    wav = f"res://audio/music/{path.stem}.wav"
    if "stream_path" not in text:
        text = text.replace(
            'stream = ExtResource("2_stream")\n',
            f'stream = ExtResource("2_stream")\nstream_path = "{wav}"\n',
        )
    text = text.replace("volume_db = -7.0", "volume_db = -3.0")
    path.write_text(text, encoding="utf-8")
    print("patched", path.name)
