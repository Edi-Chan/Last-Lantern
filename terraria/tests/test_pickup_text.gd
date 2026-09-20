@tool
extends McpTestSuite


func suite_name() -> String:
	return "pickup_text"


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func test_presenter_formats_name_and_amount() -> void:
	var item := ItemData.new()
	item.display_name = "Holz"
	assert_eq(PickupTextPresenter.display_text(item, 3), "Holz ×3")
	assert_eq(PickupTextPresenter.display_text(item, 1), "Holz ×1")
	assert_eq(PickupTextPresenter.item_name(null, 9), "Item 9")
	assert_eq(PickupTextPresenter.display_text(null, 2, 9), "Item 9 ×2")


func test_presenter_uses_rarity_color_and_icon() -> void:
	var item := ItemData.new()
	item.rarity = ItemData.Rarity.RARE
	assert_eq(PickupTextPresenter.color_for(item), item.get_rarity_color())
	assert_eq(PickupTextPresenter.icon_for(null), null)


func test_inventory_and_hud_wiring() -> void:
	var inv := _read("res://scripts/inventory/inventory.gd")
	assert_true(inv.contains("_notify_items_received"))
	assert_true(inv.contains("PickupTextSystem.present"))
	var hud := _read("res://scripts/ui/hud.gd")
	assert_true(hud.contains("PickupTextSystem"))
	assert_true(hud.contains("_ensure_pickup_text_overlay"))
	var drop := _read("res://scripts/items/item_drop.gd")
	assert_true(drop.contains("inventory.add_item"))
	var item_src := _read("res://scripts/ui/pickup_text_item.gd")
	assert_true(item_src.contains("MOUSE_FILTER_IGNORE"))
	assert_true(item_src.contains("lifetime: float = 1.6"))
	assert_false(item_src.contains("play_sfx"))
	var system := _read("res://scripts/ui/pickup_text_system.gd")
	assert_true(system.contains("MAX_LINES"))
	assert_true(system.contains("_acquire"))
	assert_true(system.contains("add_amount"))
