class_name MapExploration
extends RefCounted

## Bitmaske der entdeckten Weltkarten-Zellen. 1 Bit pro Tile, weltbezogen.

const CHUNK_SHIFT := 4
const CHUNK_SIZE := 1 << CHUNK_SHIFT

var width: int = 0
var height: int = 0
var mask: PackedByteArray = PackedByteArray()
var discovered_count: int = 0


func setup(world_width: int, world_height: int, keep_if_same: bool = false) -> void:
	if keep_if_same and world_width == width and world_height == height and not mask.is_empty():
		return
	width = maxi(world_width, 0)
	height = maxi(world_height, 0)
	mask = PackedByteArray()
	var bytes := byte_size_for(width, height)
	mask.resize(bytes)
	discovered_count = 0


func clear() -> void:
	if mask.is_empty():
		return
	mask.fill(0)
	discovered_count = 0


func reveal_all() -> void:
	if mask.is_empty():
		return
	mask.fill(255)
	discovered_count = width * height


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func is_discovered(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	var index := cell.y * width + cell.x
	return (mask[index >> 3] & (1 << (index & 7))) != 0


func set_discovered(cell: Vector2i) -> bool:
	if not in_bounds(cell):
		return false
	var index := cell.y * width + cell.x
	var byte_i := index >> 3
	var bit := 1 << (index & 7)
	if (mask[byte_i] & bit) != 0:
		return false
	mask[byte_i] |= bit
	discovered_count += 1
	return true


func chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x >> CHUNK_SHIFT, cell.y >> CHUNK_SHIFT)


func discover_with_los(origin: Vector2i, radius: int, is_blocking: Callable) -> Array[Vector2i]:
	var newly: Array[Vector2i] = []
	if radius < 0 or not in_bounds(origin):
		if in_bounds(origin) and set_discovered(origin):
			newly.append(origin)
		return newly
	if set_discovered(origin):
		newly.append(origin)
	var r2 := radius * radius
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx == 0 and dy == 0:
				continue
			if dx * dx + dy * dy > r2:
				continue
			var target := Vector2i(origin.x + dx, origin.y + dy)
			if not in_bounds(target):
				continue
			if not _has_line_of_sight(origin, target, is_blocking):
				continue
			if set_discovered(target):
				newly.append(target)
	return newly


func to_save_dict() -> Dictionary:
	return {
		"version": 1,
		"width": width,
		"height": height,
		"count": discovered_count,
		"mask": Marshalls.raw_to_base64(mask),
	}


func from_save_dict(data: Dictionary) -> bool:
	if data.is_empty():
		return false
	var saved_w := int(data.get("width", 0))
	var saved_h := int(data.get("height", 0))
	if saved_w != width or saved_h != height or width <= 0 or height <= 0:
		return false
	if bool(data.get("full", false)):
		reveal_all()
		return true
	var raw := Marshalls.base64_to_raw(str(data.get("mask", "")))
	var expected := byte_size_for(width, height)
	if raw.size() != expected:
		return false
	mask = raw
	discovered_count = _count_bits()
	return true


func byte_size() -> int:
	return mask.size()


static func byte_size_for(world_width: int, world_height: int) -> int:
	var bits := maxi(world_width, 0) * maxi(world_height, 0)
	return (bits + 7) >> 3


func _has_line_of_sight(from_cell: Vector2i, to_cell: Vector2i, is_blocking: Callable) -> bool:
	var x := from_cell.x
	var y := from_cell.y
	var x1 := to_cell.x
	var y1 := to_cell.y
	var dx := absi(x1 - x)
	var dy := -absi(y1 - y)
	var sx := 1 if x < x1 else -1
	var sy := 1 if y < y1 else -1
	var err := dx + dy
	while true:
		if x == x1 and y == y1:
			return true
		var e2 := err * 2
		var step_x := false
		var step_y := false
		if e2 >= dy:
			err += dy
			x += sx
			step_x = true
		if e2 <= dx:
			err += dx
			y += sy
			step_y = true
		if x == x1 and y == y1:
			return true
		var stepped := Vector2i(x, y)
		if not in_bounds(stepped):
			return false
		if is_blocking.is_valid() and bool(is_blocking.call(stepped)):
			return stepped == to_cell
		if step_x and step_y:
			var side_a := Vector2i(x - sx, y)
			var side_b := Vector2i(x, y - sy)
			var block_a := in_bounds(side_a) and is_blocking.is_valid() and bool(is_blocking.call(side_a))
			var block_b := in_bounds(side_b) and is_blocking.is_valid() and bool(is_blocking.call(side_b))
			if block_a and block_b:
				return false
	return false


func _count_bits() -> int:
	var total := 0
	var limit := width * height
	for i in mask.size():
		var byte_v := mask[i]
		if byte_v == 0:
			continue
		var base := i << 3
		for bit in 8:
			if base + bit >= limit:
				break
			if (byte_v & (1 << bit)) != 0:
				total += 1
	return total
