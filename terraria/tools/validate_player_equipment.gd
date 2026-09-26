@tool
extends EditorScript

## Im Godot-Editor: Datei oeffnen, File -> Run.
## Oder Tests: PlayerEquipmentValidator.run()

func _run() -> void:
	var report := PlayerEquipmentValidator.run()
	print("VALIDATE PLAYER EQUIPMENT ASSETS")
	print("ok=", report["ok"])
	for err in report["errors"]:
		push_error(str(err))
		print("ERROR: ", err)
	for warn in report["warnings"]:
		push_warning(str(warn))
		print("WARN: ", warn)
	if bool(report["ok"]):
		print("All required player/armor sheets match the animation contract.")
