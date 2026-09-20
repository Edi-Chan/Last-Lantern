extends Node

## Autoload. Haelt New-Game-/Continue-Daten ueber Szenenwechsel hinweg.

const MAIN_MENU_PATH := "res://scenes/ui/main_menu.tscn"
const CHARACTER_CREATOR_PATH := "res://scenes/ui/character_creator.tscn"
const GAME_INTRO_PATH := "res://scenes/ui/game_intro.tscn"
const WORLD_LOADING_PATH := "res://scenes/ui/world_loading_screen.tscn"
const GAME_WORLD_PATH := "res://scenes/main/main.tscn"

enum Mode { IDLE, NEW_GAME, CONTINUE, IN_WORLD }

var mode: Mode = Mode.IDLE
var skip_start_loadout: bool = false
var session: SessionRecord
var _pending_seed: int = 0
var _changing: bool = false


func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_menu_flow() -> bool:
	return mode != Mode.IN_WORLD


func resolve_world_seed() -> int:
	return _pending_seed


func remember_generated_seed(used_seed: int) -> void:
	if used_seed == 0:
		return
	_pending_seed = used_seed
	if session != null:
		session.world_seed = used_seed


func peek_save() -> Dictionary:
	return SaveManager.read_payload()


func has_continue_save() -> bool:
	return SaveManager.has_valid_save()


func open_main_menu() -> void:
	if mode != Mode.IN_WORLD:
		_clear_session()
	_go(MAIN_MENU_PATH)


func begin_new_game() -> void:
	mode = Mode.NEW_GAME
	skip_start_loadout = true
	session = null
	_pending_seed = 0
	_go(CHARACTER_CREATOR_PATH)


func submit_character(appearance: LookRecord) -> void:
	if appearance == null or not appearance.is_valid():
		return
	session = SessionFactory.create_session(appearance)
	_pending_seed = session.world_seed
	skip_start_loadout = true
	mode = Mode.NEW_GAME
	_go(GAME_INTRO_PATH)


func finish_intro() -> void:
	if mode != Mode.NEW_GAME:
		mode = Mode.NEW_GAME
	_go(WORLD_LOADING_PATH)


func continue_last_save() -> void:
	var payload := SaveManager.read_payload()
	if payload.is_empty():
		return
	mode = Mode.CONTINUE
	skip_start_loadout = true
	session = SessionFactory.session_from_dict(payload)
	_pending_seed = int(payload.get("world_seed", 12345))
	if _pending_seed == 0:
		_pending_seed = 12345
	if session.appearance == null or session.appearance.character_name.is_empty():
		var player_data: Dictionary = payload.get("player", {})
		session.appearance = SessionFactory.look_from_dict({
			"character_name": str(player_data.get("character_name", "")),
		})
	_go(WORLD_LOADING_PATH)


func enter_world() -> void:
	_go(GAME_WORLD_PATH)


func on_world_ready(main: Node) -> void:
	if main == null:
		return
	if mode != Mode.NEW_GAME and mode != Mode.CONTINUE:
		return
	var player := main.get_node_or_null("Player") as Player
	if player != null and session != null and session.appearance != null:
		player.call("apply_appearance", session.appearance)
	var saver := main.get_tree().get_first_node_in_group(SaveManager.GROUP)
	if mode == Mode.CONTINUE:
		if saver != null and saver.has_method("load_game"):
			saver.call("load_game")
	elif mode == Mode.NEW_GAME:
		if player != null:
			var inventory := player.get_node_or_null("Inventory") as Inventory
			if inventory != null:
				inventory.give_new_game_start_items()
		if saver != null and saver.has_method("save_game"):
			saver.call("save_game")
	mode = Mode.IN_WORLD
	skip_start_loadout = false


func return_to_main_menu(autosave: bool = true) -> void:
	if autosave and mode == Mode.IN_WORLD:
		var saver := get_tree().get_first_node_in_group(SaveManager.GROUP)
		if saver != null and saver.has_method("save_game"):
			saver.call("save_game")
	_clear_session()
	if SettingsManager != null:
		SettingsManager.set_menu_pause(false)
	get_tree().paused = false
	_go(MAIN_MENU_PATH)


func _clear_session() -> void:
	mode = Mode.IDLE
	skip_start_loadout = false
	session = null
	_pending_seed = 0


func _go(path: String) -> void:
	if _changing or path.is_empty():
		return
	if not ResourceLoader.exists(path):
		push_warning("GameFlow: Szene fehlt: %s" % path)
		return
	_changing = true
	get_tree().paused = false
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_warning("GameFlow: Szenenwechsel fehlgeschlagen (%s): %s" % [err, path])
	_changing = false
