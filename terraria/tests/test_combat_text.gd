@tool
extends McpTestSuite


func suite_name() -> String:
	return "combat_text"


func _read(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func test_damage_types_are_data_not_colors() -> void:
	assert_eq(int(DamageTypes.Type.PHYSICAL), 0)
	assert_eq(int(DamageTypes.Type.DARKNESS), 1)
	assert_eq(int(DamageTypes.Type.FIRE), 2)
	assert_eq(int(DamageTypes.Type.FROST), 3)
	assert_eq(int(DamageTypes.Type.HEALING), 4)
	assert_eq(int(DamageTypes.from_legacy(&"fog")), int(DamageTypes.Type.DARKNESS))
	assert_eq(int(DamageTypes.from_legacy(&"fire")), int(DamageTypes.Type.FIRE))
	assert_eq(int(DamageTypes.from_legacy(&"frost")), int(DamageTypes.Type.FROST))
	assert_eq(int(DamageTypes.from_legacy(&"heal")), int(DamageTypes.Type.HEALING))
	assert_eq(int(DamageTypes.from_legacy("")), int(DamageTypes.Type.PHYSICAL))
	var src := _read("res://scripts/combat/combat_text_presenter.gd")
	assert_false(src.contains("if text_color"))
	assert_false(src.contains("damage_type = DARKNESS") and src.contains("PURPLE"))


func test_presenter_uses_event_fields() -> void:
	var cfg := CombatTextConfig.new()
	var physical := DamageEvent.new()
	physical.amount = 16
	physical.damage_type = DamageTypes.Type.PHYSICAL
	assert_eq(int(CombatTextPresenter.style_for(physical)), int(CombatTextPresenter.Style.PHYSICAL))
	assert_eq(CombatTextPresenter.display_text(physical), "16")
	assert_eq(CombatTextPresenter.color_for(physical, cfg), cfg.physical_color)

	var crit := DamageEvent.new()
	crit.amount = 32
	crit.critical = true
	assert_eq(int(CombatTextPresenter.style_for(crit)), int(CombatTextPresenter.Style.CRITICAL))
	assert_eq(CombatTextPresenter.display_text(crit), "32!")
	assert_eq(CombatTextPresenter.color_for(crit, cfg), cfg.critical_color)
	assert_eq(CombatTextPresenter.font_size_for(crit, cfg), cfg.critical_font_size)

	var player_hit := DamageEvent.new()
	player_hit.amount = 15
	player_hit.is_player_target = true
	assert_eq(int(CombatTextPresenter.style_for(player_hit)), int(CombatTextPresenter.Style.PLAYER_DAMAGE))
	assert_eq(CombatTextPresenter.display_text(player_hit), "-15")
	assert_eq(CombatTextPresenter.color_for(player_hit, cfg), cfg.player_damage_color)

	var dark := DamageEvent.new()
	dark.amount = 18
	dark.damage_type = DamageTypes.Type.DARKNESS
	dark.is_player_target = true
	assert_eq(int(CombatTextPresenter.style_for(dark)), int(CombatTextPresenter.Style.DARKNESS))
	assert_eq(CombatTextPresenter.color_for(dark, cfg), cfg.darkness_color)

	var fire := DamageEvent.new()
	fire.amount = 5
	fire.damage_type = DamageTypes.Type.FIRE
	assert_eq(int(CombatTextPresenter.style_for(fire)), int(CombatTextPresenter.Style.FIRE))
	assert_eq(CombatTextPresenter.color_for(fire, cfg), cfg.fire_color)

	var frost := DamageEvent.new()
	frost.amount = 4
	frost.damage_type = DamageTypes.Type.FROST
	assert_eq(int(CombatTextPresenter.style_for(frost)), int(CombatTextPresenter.Style.FROST))
	assert_eq(CombatTextPresenter.color_for(frost, cfg), cfg.frost_color)

	var heal := DamageEvent.healing(5, null)
	assert_eq(int(CombatTextPresenter.style_for(heal)), int(CombatTextPresenter.Style.HEAL))
	assert_eq(CombatTextPresenter.display_text(heal), "+5")
	assert_eq(CombatTextPresenter.color_for(heal, cfg), cfg.heal_color)

	var reduced := DamageEvent.new()
	reduced.amount = 3
	reduced.reduced = true
	reduced.is_player_target = true
	assert_eq(int(CombatTextPresenter.style_for(reduced)), int(CombatTextPresenter.Style.REDUCED))
	assert_eq(CombatTextPresenter.color_for(reduced, cfg), cfg.reduced_color)

	var blocked := DamageEvent.new()
	blocked.amount = 0
	blocked.blocked = true
	blocked.is_player_target = true
	assert_eq(CombatTextPresenter.display_text(blocked), "0")
	assert_eq(int(CombatTextPresenter.style_for(blocked)), int(CombatTextPresenter.Style.REDUCED))


func test_player_stats_reports_final_and_heal_clamp() -> void:
	var stats := PlayerStats.new()
	stats.max_health = 100.0
	stats.health = 100.0
	stats.armor_defense = 4
	var hit: Dictionary = stats.apply_incoming_damage(20.0, false)
	assert_eq(int(round(float(hit["applied"]))), 16)
	assert_true(bool(hit["reduced"]))
	assert_false(bool(hit["blocked"]))
	stats.health = 95.0
	var healed := stats.heal(25.0)
	assert_eq(int(round(healed)), 5)
	var blocked: Dictionary = stats.apply_incoming_damage(2.0, false)
	assert_eq(int(round(float(blocked["applied"]))), 0)
	assert_true(bool(blocked["blocked"]))


func test_critical_interface_does_not_change_uncrit_damage() -> void:
	assert_false(CombatResolver.roll_critical(0.0))
	assert_eq(CombatResolver.critical_amount(16, 2.0), 32)
	assert_eq(CombatResolver.resolve_damage(16, null, null), 16)


func test_dot_aggregator_combines_display_only() -> void:
	var agg := CombatTextAggregator.new()
	agg.window = 0.25
	var a := DamageEvent.new()
	a.amount = 2
	a.is_dot = true
	a.damage_type = DamageTypes.Type.FIRE
	var first: Array[DamageEvent] = agg.ingest(a, 0.0)
	assert_eq(first.size(), 0)
	var b := DamageEvent.new()
	b.amount = 3
	b.is_dot = true
	b.damage_type = DamageTypes.Type.FIRE
	var second: Array[DamageEvent] = agg.ingest(b, 0.1)
	assert_eq(second.size(), 0)
	var flushed: Array[DamageEvent] = agg.flush_due(0.4)
	assert_eq(flushed.size(), 1)
	assert_eq(flushed[0].amount, 5)


func test_config_and_hud_wiring() -> void:
	assert_true(ResourceLoader.exists("res://resources/combat/combat_text_config.tres"))
	var cfg := load("res://resources/combat/combat_text_config.tres") as CombatTextConfig
	assert_ne(cfg, null)
	assert_eq(cfg.max_combat_text, 30)
	assert_eq(cfg.normal_font_size, 11)
	assert_eq(cfg.critical_font_size, 15)
	var settings_src := _read("res://scripts/systems/last_lantern_settings.gd")
	assert_true(settings_src.contains("combat_text"))
	var hud := _read("res://scripts/ui/hud.gd")
	assert_true(hud.contains("CombatTextSystem"))
	assert_true(hud.contains("_ensure_combat_text_overlay"))
	var zombie := _read("res://scripts/enemies/zombie.gd")
	assert_true(zombie.contains("notify_hit"))
	assert_true(zombie.contains("CombatTextSystem.present"))
	assert_true(zombie.contains("get_combat_text_origin"))
	var resolver := _read("res://scripts/combat/combat_resolver.gd")
	assert_true(resolver.contains("apply_damage_event"))
	assert_true(resolver.contains("roll_critical"))
	var dummy := _read("res://scripts/combat/combat_dummy.gd")
	assert_true(dummy.contains("CombatTextSystem.present"))
	var player := _read("res://scripts/player/player.gd")
	assert_true(player.contains("apply_damage_event"))
	assert_true(player.contains("func heal"))
	var item := _read("res://scripts/combat/combat_text_item.gd")
	assert_true(item.contains("MOUSE_FILTER_IGNORE"))
	assert_false(item.contains("play_sfx"))
	var system := _read("res://scripts/combat/combat_text_system.gd")
	assert_true(system.contains("max_combat_text"))
	assert_true(system.contains("_acquire"))
