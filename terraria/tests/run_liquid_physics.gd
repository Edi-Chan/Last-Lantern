extends SceneTree

## Headless physics checks for the repaired liquid system.
## Start: godot --headless --path terraria -s res://tests/run_liquid_physics.gd


func _init() -> void:
	var errors: PackedStringArray = []
	_test_fall(errors)
	_test_drain(errors)
	_test_equalize(errors)
	_test_no_duplicate(errors)
	_test_save(errors)
	_test_surface(errors)
	_test_quantize(errors)
	for message in errors:
		printerr(message)
	print("LIQUID_PHYSICS_FAILURES=%d" % errors.size())
	quit(0 if errors.is_empty() else 1)


func _test_fall(errors: PackedStringArray) -> void:
	var liquid := _make_liquid(8, 12)
	for y in range(0, 12):
		liquid.debug_set_solid(Vector2i(2, y), true)
		liquid.debug_set_solid(Vector2i(4, y), true)
	liquid.set_cell(Vector2i(3, 1), LiquidTypes.Type.WATER, LiquidTypes.FULL)
	_expect_eq(errors, "fall mass before", liquid.get_total_water_amount(), LiquidTypes.FULL)
	liquid.stabilize(80)
	print("FALL amounts bottom row: ", _row_amounts(liquid, 11, 8))
	print("FALL active=", liquid.get_active_cell_count(), " total=", liquid.get_total_water_amount())
	_print_active(liquid, "FALL")
	_expect_eq(errors, "fall mass after", liquid.get_total_water_amount(), LiquidTypes.FULL)
	_expect_eq(errors, "fall source empty", liquid.get_amount(Vector2i(3, 1)), 0)
	_expect_eq(errors, "fall landed", liquid.get_amount(Vector2i(3, 11)), LiquidTypes.FULL)
	_expect_eq(errors, "fall active", liquid.get_active_cell_count(), 0)
	liquid.free()


func _test_drain(errors: PackedStringArray) -> void:
	var liquid := _make_liquid(16, 16)
	_build_basin(liquid, 2, 12, 4, 9, 10)
	var start: int = liquid.get_total_water_amount()
	var t0 := Time.get_ticks_usec()
	liquid.debug_set_solid(Vector2i(7, 10), false)
	liquid.on_block_removed(Vector2i(7, 10))
	liquid.stabilize(800)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	print("LIQUID_DRAIN_STABILIZE_MS=%.2f active=%d total=%d" % [ms, liquid.get_active_cell_count(), liquid.get_total_water_amount()])
	print("DRAIN top row y4: ", _row_amounts(liquid, 4, 16))
	print("DRAIN y12: ", _row_amounts(liquid, 12, 16))
	print("DRAIN y15: ", _row_amounts(liquid, 15, 16))
	_print_active(liquid, "DRAIN")
	_expect_eq(errors, "drain mass", liquid.get_total_water_amount(), start)
	_expect_true(errors, "drain arrived below", liquid.get_amount(Vector2i(7, 15)) > 0)
	_expect_true(errors, "drain surface dropped", liquid.get_amount(Vector2i(4, 4)) < LiquidTypes.FULL or not liquid.has_water(Vector2i(4, 4)))
	_expect_eq(errors, "drain slept", liquid.get_active_cell_count(), 0)
	var idle_ms := 0.0
	for _i in 8:
		liquid.stabilize(1)
		idle_ms += float(liquid.get_debug_stats().get("simulation_ms", 0.0))
	print("LIQUID_IDLE_TICK_MS=%.3f active=%d" % [idle_ms / 8.0, liquid.get_active_cell_count()])
	liquid.free()


func _test_equalize(errors: PackedStringArray) -> void:
	var liquid := _make_liquid(12, 8)
	for x in range(2, 10):
		liquid.debug_set_solid(Vector2i(x, 6), true)
	liquid.debug_set_solid(Vector2i(1, 5), true)
	liquid.debug_set_solid(Vector2i(10, 5), true)
	liquid.set_cell(Vector2i(5, 5), LiquidTypes.Type.WATER, LiquidTypes.FULL)
	var start: int = liquid.get_total_water_amount()
	liquid.stabilize(250)
	print("EQ amounts: ", _row_amounts(liquid, 5, 12))
	_print_active(liquid, "EQ")
	_expect_eq(errors, "equalize mass", liquid.get_total_water_amount(), start)
	_expect_true(errors, "equalize left", liquid.get_amount(Vector2i(4, 5)) > 0)
	_expect_true(errors, "equalize right", liquid.get_amount(Vector2i(6, 5)) > 0)
	_expect_eq(errors, "equalize slept", liquid.get_active_cell_count(), 0)
	liquid.free()


func _test_no_duplicate(errors: PackedStringArray) -> void:
	var liquid := _make_liquid(6, 6)
	liquid.debug_set_solid(Vector2i(2, 4), true)
	liquid.debug_set_solid(Vector2i(3, 4), true)
	liquid.set_cell(Vector2i(2, 3), LiquidTypes.Type.WATER, 200)
	liquid.set_cell(Vector2i(3, 3), LiquidTypes.Type.WATER, 10)
	liquid.stabilize(40)
	_expect_eq(errors, "no duplicate", liquid.get_total_water_amount(), 210)
	liquid.free()


func _test_save(errors: PackedStringArray) -> void:
	var liquid := _make_liquid(12, 12)
	_build_basin(liquid, 2, 8, 3, 6, 7)
	liquid.capture_baseline()
	var original: int = liquid.get_total_water_amount()
	liquid.debug_set_solid(Vector2i(5, 7), false)
	liquid.on_block_removed(Vector2i(5, 7))
	liquid.stabilize(600)
	var drained: int = liquid.get_total_water_amount()
	_expect_eq(errors, "save mass", drained, original)
	var top_after: int = liquid.get_amount(Vector2i(3, 3))
	var below_after: int = liquid.get_amount(Vector2i(5, 11))
	_expect_true(errors, "save below filled", below_after > 0)
	var payload: Dictionary = liquid.to_save_dict()
	liquid.from_save_dict(payload)
	_expect_eq(errors, "load mass", liquid.get_total_water_amount(), drained)
	_expect_eq(errors, "load top", liquid.get_amount(Vector2i(3, 3)), top_after)
	_expect_eq(errors, "load below", liquid.get_amount(Vector2i(5, 11)), below_after)
	liquid.free()


func _test_surface(errors: PackedStringArray) -> void:
	var liquid := _make_liquid(8, 8)
	for x in range(2, 6):
		liquid.debug_set_solid(Vector2i(x, 6), true)
	liquid.debug_set_solid(Vector2i(1, 4), true)
	liquid.debug_set_solid(Vector2i(1, 5), true)
	liquid.debug_set_solid(Vector2i(6, 4), true)
	liquid.debug_set_solid(Vector2i(6, 5), true)
	for x in range(2, 6):
		liquid.set_cell(Vector2i(x, 5), LiquidTypes.Type.WATER, LiquidTypes.FULL, false)
		liquid.set_cell(Vector2i(x, 4), LiquidTypes.Type.WATER, LiquidTypes.FULL, false)
	_expect_true(errors, "top is surface", liquid.is_surface_cell(Vector2i(3, 4)))
	_expect_true(errors, "body is not surface", not liquid.is_surface_cell(Vector2i(3, 5)))
	_expect_true(errors, "body is not falling", not liquid.is_falling_cell(Vector2i(3, 5)))
	liquid.free()


func _test_quantize(errors: PackedStringArray) -> void:
	var liquid := _make_liquid(4, 4)
	_expect_eq(errors, "q0", liquid.quantized_fill_height(0), 0)
	_expect_eq(errors, "q255", liquid.quantized_fill_height(LiquidTypes.FULL), 16)
	_expect_eq(errors, "q128", liquid.quantized_fill_height(LiquidTypes.HALF), 8)
	_expect_eq(errors, "q1", liquid.quantized_fill_height(1), 1)
	liquid.free()


func _make_liquid(width: int, height: int) -> LiquidSystem:
	var liquid := LiquidSystem.new()
	liquid.settings = LiquidSettings.new()
	liquid.settings.sleep_after_stable_ticks = 2
	liquid.settings.max_updates_per_tick = 2000
	liquid.settings.max_updates_per_tick_max = 2000
	liquid.settings.adaptive_budget = false
	liquid.initialize(width, height)
	return liquid


func _build_basin(liquid: LiquidSystem, left: int, right: int, top: int, water_bottom: int, floor_y: int) -> void:
	for x in range(left, right + 1):
		liquid.debug_set_solid(Vector2i(x, floor_y), true)
	for y in range(top, floor_y + 1):
		liquid.debug_set_solid(Vector2i(left, y), true)
		liquid.debug_set_solid(Vector2i(right, y), true)
	for y in range(top, water_bottom + 1):
		for x in range(left + 1, right):
			liquid.set_cell(Vector2i(x, y), LiquidTypes.Type.WATER, LiquidTypes.FULL, false)
	liquid.finalize_generation()


func _row_amounts(liquid: LiquidSystem, y: int, width: int) -> Array:
	var row: Array = []
	for x in width:
		row.append(liquid.get_amount(Vector2i(x, y)))
	return row


func _print_active(liquid: LiquidSystem, label: String) -> void:
	var cells: Array = []
	for cell in liquid.get_water_cells():
		if liquid.is_cell_active(cell):
			cells.append("%s=%d" % [str(cell), liquid.get_amount(cell)])
	print("%s active cells (%d): %s" % [label, cells.size(), ", ".join(cells)])


func _expect_eq(errors: PackedStringArray, label: String, actual: Variant, expected: Variant) -> void:
	if actual != expected:
		errors.append("%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _expect_true(errors: PackedStringArray, label: String, condition: bool) -> void:
	if not condition:
		errors.append("%s: expected true" % label)
