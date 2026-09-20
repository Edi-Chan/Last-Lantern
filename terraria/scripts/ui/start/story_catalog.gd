class_name StoryCatalog
extends RefCounted

## Placeholder-Intro anhand vorhandener Systeme: Tag/Nacht, 7-Tage-Finsternis, Laterne.


static func slides() -> Array[StorySlide]:
	var list: Array[StorySlide] = []
	list.append(_slide(
		"Die Nacht kommt schnell.",
		"In dieser Welt zaehlt jeder Tag. Wenn die Sonne sinkt, wird das Land stiller und gefaehrlicher."
	))
	list.append(_slide(
		"Alle sieben Tage bricht die Finsternis herein.",
		"Dann reicht das Mondlicht nicht mehr. Die Nebelwand frisst alles ausserhalb eines sicheren Kreises."
	))
	list.append(_slide(
		"Die letzte Laterne haelt den Kreis.",
		"In ihrem Licht kannst du ausharren. Ausserhalb musst du sammeln, bauen und die Nacht ueberstehen."
	))
	list.append(_slide(
		"Du startest mit leeren Haenden.",
		"Kein Werkzeug, keine Waffe. Die Welt hat Holz, Stein und Erz - wenn du sie holst, bevor Tag 7 kommt."
	))
	return list


static func _slide(title: String, body: String) -> StorySlide:
	var slide := StorySlide.new()
	slide.title = title
	slide.body = body
	return slide
