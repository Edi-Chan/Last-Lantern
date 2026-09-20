class_name PickupTextPresenter
extends RefCounted

## Reiner Text fuer kurze Item-Hinweise. Kein Fenster, keine Persistenz.


static func item_name(item: ItemData, item_id: int = -1) -> String:
	if item != null and not item.display_name.is_empty():
		return item.display_name
	if item_id >= 0:
		return "Item %d" % item_id
	return "Item"


static func display_text(item: ItemData, amount: int, item_id: int = -1) -> String:
	var shown := maxi(amount, 1)
	return "%s ×%d" % [item_name(item, item_id), shown]


static func color_for(item: ItemData) -> Color:
	if item != null:
		return item.get_rarity_color()
	return Color(0.92, 0.88, 0.74, 1.0)


static func icon_for(item: ItemData) -> Texture2D:
	if item == null:
		return null
	return item.icon
