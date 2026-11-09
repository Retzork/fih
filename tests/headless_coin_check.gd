extends SceneTree
## Headless check for the Coin entity (P4.3).
##
##   & "<godot>" --headless --path . --script res://tests/headless_coin_check.gd
##
## Covers the two value tables (`Value()`/`FUN_004D53A0` and the Virtual Tank multipliers), the fall and
## landing line, the staged bob, the three expiry modes plus Niko's Pearl, the collection square, the
## Virtual Tank homing/bank hand-off, the animation timer, and the recovered draw binding (image + sheet
## row per kind). Rendering itself, audio and the AddMoney side are out of scope (P4.4/P4.7/P4.13).

const SimScript := preload("res://scripts/autoload/sim.gd")
const TankScript := preload("res://scripts/tank/tank.gd")
const CoinScript := preload("res://scripts/entities/coin.gd")

var _failures := 0
var _checks := 0
var sim: Node
var tank: Tank


func _init() -> void:
	sim = SimScript.new()
	tank = TankScript.new()
	tank.setup(sim, 2026)

	_test_value_table()
	_test_virtual_values()
	_test_spawn_and_phase()
	_test_fall_and_landing()
	_test_bob()
	_test_expiry()
	_test_collection()
	_test_virtual_flight()
	_test_animation_timer()
	_test_sprite_binding()

	tank.shutdown()
	sim.free()
	tank.free()

	if _failures == 0:
		print("headless_coin_check: PASS (%d assertions)" % _checks)
		quit(0)
	else:
		printerr("headless_coin_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)


# --- value tables ------------------------------------------------------------

func _test_value_table() -> void:
	var expected := {
		0x01: 15, 0x08: 15, 0x12: 15,
		0x02: 35, 0x09: 35,
		0x03: 40, 0x0A: 40,
		0x04: 200, 0x0B: 200, 0x05: 200, 0x0C: 200,
		0x06: 500, 0x0D: 500,
		0x07: 2000, 0x0E: 2000,
		0x11: 150, 0x0F: 250, 0x10: 0,
	}
	for kind: int in expected:
		var coin := CoinScript.new()
		coin.kind = kind
		_expect(coin.value() == int(expected[kind]), "kind 0x%X is worth %d (got %d)" % [kind, expected[kind], coin.value()])
		coin.free()

	# The pairs {n, n+7} are two sprite variants of one denomination.
	for kind: int in [0x01, 0x02, 0x03, 0x04, 0x06, 0x07]:
		var a := CoinScript.new()
		var b := CoinScript.new()
		a.kind = kind
		b.kind = kind + 7
		_expect(a.value() == b.value(), "kinds 0x%X/0x%X share a value" % [kind, kind + 7])
		a.free()
		b.free()

	var unknown := CoinScript.new()
	unknown.kind = 0x7F
	_expect(unknown.value() == 0, "an unknown kind is worth 0")
	unknown.free()


func _test_virtual_values() -> void:
	var kind_multipliers := {
		0x01: 1, 0x02: 2, 0x03: 3, 0x04: 5, 0x06: 10, 0x07: 20, 0x11: 5, 0x0F: 10,
	}
	for kind: int in kind_multipliers:
		var coin: Coin = CoinScript.create(kind, Vector2(300.0, 300.0))
		_expect(
			int(CoinScript.VIRTUAL_MULTIPLIER.get(kind, -1)) == int(kind_multipliers[kind]),
			"kind 0x%X has Virtual Tank multiplier x%d" % [kind, kind_multipliers[kind]]
		)
		# The `+0x1C0` base is unrecovered (Q-0040), so the default equals the normal value.
		_expect(coin.virtual_base == coin.value(), "virtual base defaults to the normal value for 0x%X" % kind)
		coin.free()

	var diamond: Coin = CoinScript.create(0x04, Vector2(300.0, 300.0))
	_expect(diamond.amount() == 200, "a diamond is worth 200 outside Virtual Tank")
	_attach(diamond)
	tank.virtual_tank = true
	_expect(diamond.virtual_mode(), "the coin reports Virtual Tank mode from the tank")
	_expect(diamond.amount() == 1000, "a diamond is 200 x 5 in Virtual Tank (got %d)" % diamond.amount())
	tank.virtual_tank = false
	tank.shutdown()


# --- spawn, fall, bob --------------------------------------------------------

func _test_spawn_and_phase() -> void:
	tank.shutdown()
	var coin: Coin = tank.spawn_coin(0x02, Vector2(300.0, 200.0))
	_expect(coin.phase == SimScript.Phase.COLLISION, "coins tick in the COLLISION phase")
	_expect(tank.layer_for(SimScript.Phase.COLLISION).get_child_count() == 1, "the coin is parented to the collision layer")
	_expect(tank.coin_count() == 1, "the tank counts one coin")
	_expect(coin.value() == 35, "the spawned kind keeps its value")


func _test_fall_and_landing() -> void:
	tank.shutdown()
	var coin: Coin = tank.spawn_coin(0x01, Vector2(300.0, 200.0))
	_step(1)
	_expect(is_equal_approx(coin.position.y, 201.5), "a coin falls 1.5/tick (got %.2f)" % coin.position.y)
	_expect(not coin.landed, "a falling coin is not landed")

	_step(200)
	_expect(coin.landed, "the coin lands")
	_expect(is_equal_approx(coin.position.y, CoinScript.LAND_Y) or coin.position.y < CoinScript.LAND_Y,
		"the landing line is y 370 (got %.2f)" % coin.position.y)
	_expect(coin.position.x == 300.0, "a coin does not drift horizontally")


func _test_bob() -> void:
	tank.shutdown()
	tank.coin_hint_active = true  # 150-tick expiry, so the climb is not cut short
	var coin: Coin = tank.spawn_coin(0x01, Vector2(300.0, 368.0))
	_step(2)
	_expect(coin.landed and is_equal_approx(coin.position.y, CoinScript.LAND_Y), "the coin reaches the landing line")
	var at_landing := coin.position.y
	_step(1)
	_expect(coin.position.y < at_landing, "the staged bob rises from the landing line (%.2f -> %.2f)" % [at_landing, coin.position.y])
	_expect(coin.rising, "a landed coin starts out rising")

	# The band table bottoms out at 120 and tops at 150, so the coin oscillates inside it.
	var lowest := coin.position.y
	var highest := coin.position.y
	for i in 400:
		_step(1)
		lowest = minf(lowest, coin.position.y)
		highest = maxf(highest, coin.position.y)
	_expect(lowest >= 110.0 and highest <= 372.0, "the bob stays in the 120..150 band (%.1f..%.1f)" % [lowest, highest])
	_expect(lowest <= CoinScript.BOB_BANDS[4][0], "the bob reaches the table's bottom (%.2f)" % lowest)
	_expect(highest >= CoinScript.BOB_BANDS[0][0] - 1.0, "the bob reaches the table's top (%.2f)" % highest)
	tank.coin_hint_active = false


func _test_expiry() -> void:
	# Default: 20 ticks after landing, then a 5-tick fade.
	tank.shutdown()
	var coin: Coin = _landed_coin(0x01)
	_expect(coin.expiry_ticks == CoinScript.EXPIRY_DEFAULT,
		"the default expiry is 20 ticks (got %d)" % coin.expiry_ticks)
	_step(CoinScript.EXPIRY_DEFAULT - 1)
	_expect(not coin.dead and coin.expiry_ticks == 1,
		"the coin is alive with 1 tick left (left %d)" % coin.expiry_ticks)
	_step(1)
	_expect(coin.fade == CoinScript.FADE_TICKS, "the fade starts at 20 ticks (fade %d)" % coin.fade)
	_step(CoinScript.FADE_TICKS - 1)
	_expect(not coin.dead, "the coin survives the fade")
	_step(1)
	_expect(coin.dead, "the coin is gone after the fade")

	# Niko's Pearl holds for 217 ticks.
	tank.shutdown()
	var pearl: Coin = _landed_coin(CoinScript.KIND_NIKO_PEARL)
	_expect(pearl.expiry_ticks == CoinScript.NIKO_PEARL_EXPIRY,
		"Niko's Pearl expires after 217 ticks (got %d)" % pearl.expiry_ticks)
	_expect(pearl.value() == 250, "Niko's Pearl is worth 250")

	# Hinted tank, demo mode and the `Tank+0x16C` flag change the base expiry.
	tank.shutdown()
	tank.coin_hint_active = true
	var hinted: Coin = _landed_coin(0x01)
	_expect(hinted.expiry_ticks == CoinScript.EXPIRY_HINTED,
		"a hinted tank holds coins 150 ticks (got %d)" % hinted.expiry_ticks)

	tank.demo_mode = true
	var demo: Coin = _landed_coin(0x01)
	_expect(demo.expiry_ticks == CoinScript.EXPIRY_DEMO,
		"demo mode expires after 108 ticks (got %d)" % demo.expiry_ticks)

	tank.demo_mode = false
	tank.tank_flag_16c = true
	var flagged: Coin = _landed_coin(0x01)
	_expect(flagged.expiry_ticks == CoinScript.EXPIRY_TANK_FLAG,
		"the tank flag expires after 200 ticks (got %d)" % flagged.expiry_ticks)
	tank.tank_flag_16c = false
	tank.coin_hint_active = false


func _test_collection() -> void:
	tank.shutdown()
	var coin: Coin = tank.spawn_coin(0x04, Vector2(300.0, 300.0))
	var centre := coin.position + CoinScript.COLLECT_CENTER
	_expect(coin.can_collect(centre), "a collector on the coin's centre picks it up")
	_expect(coin.can_collect(centre + Vector2(29.0, 29.0)), "the pickup square is 60x60")
	_expect(not coin.can_collect(centre + Vector2(31.0, 0.0)), "31 px away is outside the square")

	var amounts: Array[int] = []
	coin.collected.connect(func(_c, amount: int) -> void: amounts.append(amount))
	coin.collect()
	_expect(amounts == [200], "collecting reports the amount instead of crediting it, got %s" % [amounts])
	_expect(coin.dead, "a collected coin is removed")
	_expect(tank.coin_count() == 0, "the tank no longer counts the coin")
	coin.collect()
	_expect(amounts.size() == 1, "collecting twice does nothing")


func _test_virtual_flight() -> void:
	tank.shutdown()
	tank.virtual_tank = true
	var coin: Coin = tank.spawn_coin(0x02, Vector2(100.0, 300.0))
	_expect(coin.amount() == 70, "a Virtual Tank gold coin is 35 x 2 (got %d)" % coin.amount())
	var start_x := coin.position.x
	var banked: Array[Coin] = []
	coin.banked.connect(func(c) -> void: banked.append(c))
	_step(1)
	_expect(coin.position.x > start_x, "a Virtual Tank coin homes toward (550, 30) (%.1f -> %.1f)" % [start_x, coin.position.x])
	_step(60)
	_expect(banked.size() == 1, "reaching the corner emits one bank")
	_expect(coin.dead, "the banked coin is removed")
	tank.virtual_tank = false


func _test_animation_timer() -> void:
	tank.shutdown()
	# A 150-tick expiry keeps the coin alive through the 79-tick timer wrap.
	tank.coin_hint_active = true
	var coin: Coin = tank.spawn_coin(0x01, Vector2(300.0, 300.0))
	_step(10)
	_expect(coin.anim_frame == 1, "ten ticks advance one animation frame (got %d)" % coin.anim_frame)
	for i in 69:
		_step(1)
	_expect(coin.frame_timer == 0, "the frame timer wraps at 79 (got %d)" % coin.frame_timer)
	tank.coin_hint_active = false


# --- draw binding ------------------------------------------------------------

## EV-0162: `FUN_004DD7A0` picks image + sheet row per kind, and the Virtual Tank draws the `SHELLS`
## sheet (rows 0..3) with the 2000-value kinds as the single-cell `MONEYBAG`.
func _test_sprite_binding() -> void:
	var money_rows := {0x01: 0, 0x08: 0, 0x02: 1, 0x09: 1, 0x03: 2, 0x0A: 2,
		0x04: 3, 0x0B: 3, 0x05: 3, 0x0C: 3, 0x07: 4, 0x0E: 4}
	for kind: int in money_rows:
		var coin: Coin = CoinScript.create(kind, Vector2.ZERO)
		coin.tank = tank
		_expect(coin.sprite_image() == "IMAGE_MONEY", "kind 0x%X draws the money sheet" % kind)
		_expect(coin.sprite_row() == int(money_rows[kind]),
			"kind 0x%X draws money row %d (got %d)" % [kind, int(money_rows[kind]), coin.sprite_row()])
		coin.free()
	for kind: int in [0x06, 0x0D, 0x0F]:
		var pearl: Coin = CoinScript.create(kind, Vector2.ZERO)
		pearl.tank = tank
		_expect(pearl.sprite_image() == "IMAGE_PEARL", "kind 0x%X draws the pearl" % kind)
		_expect(pearl.sprite_row() == -1, "kind 0x%X has no sheet row" % kind)
		pearl.free()
	tank.virtual_tank = true
	var shell_rows := {0x01: 0, 0x08: 0, 0x02: 1, 0x09: 1, 0x04: 2, 0x0B: 2,
		0x05: 2, 0x0C: 2, 0x06: 3, 0x0D: 3}
	for kind: int in shell_rows:
		var coin: Coin = CoinScript.create(kind, Vector2.ZERO)
		coin.tank = tank
		_expect(coin.sprite_image() == "IMAGE_SHELLS", "Virtual kind 0x%X draws the shell sheet" % kind)
		_expect(coin.sprite_row() == int(shell_rows[kind]),
			"Virtual kind 0x%X draws shell row %d (got %d)" % [kind, int(shell_rows[kind]), coin.sprite_row()])
		coin.free()
	for kind: int in [0x07, 0x0E]:
		var bag: Coin = CoinScript.create(kind, Vector2.ZERO)
		bag.tank = tank
		_expect(bag.sprite_image() == "IMAGE_MONEYBAG", "Virtual kind 0x%X draws the money bag" % kind)
		_expect(bag.sprite_row() == -1, "Virtual kind 0x%X has no sheet row" % kind)
		bag.free()
	var star: Coin = CoinScript.create(0x03, Vector2.ZERO)
	star.tank = tank
	_expect(star.sprite_image() == "IMAGE_MONEY", "Virtual kind 0x03 keeps the money sheet")
	_expect(star.sprite_row() == 2, "Virtual kind 0x03 keeps money row 2 (got %d)" % star.sprite_row())
	star.free()
	tank.virtual_tank = false

	# 0x11 (Shrapnel) draws the single-cell MISCITEMS with the SPARKS overlay at (10,-10).
	var shrapnel: Coin = CoinScript.create(0x11, Vector2.ZERO)
	shrapnel.tank = tank
	_expect(shrapnel.sprite_image() == "IMAGE_MISCITEMS", "kind 0x11 draws the misc-items image")
	_expect(shrapnel.sprite_row() == -1, "kind 0x11 has no sheet row")
	_expect(shrapnel.draws_sparks(), "kind 0x11 overlays the sparks sheet")
	_expect(CoinScript.SPARKS_OFFSET == Vector2(10.0, -10.0),
		"the sparks overlay uses the recovered (10,-10)")
	shrapnel.free()
	# 0x12 (Nostradamus' snot) draws the recovered single-cell PEANUT image. Its shipped resource is
	# the dedicated blank 107x34 image (P3.3), so the binding is invisible by design, not by fallback.
	var snot: Coin = CoinScript.create(0x12, Vector2.ZERO)
	snot.tank = tank
	_expect(snot.sprite_image() == "IMAGE_PEANUT", "kind 0x12 draws the peanut image")
	_expect(snot.sprite_row() == -1, "kind 0x12 has no sheet row")
	_expect(not snot.draws_sparks(), "kind 0x12 draws no sparks overlay")
	snot.free()
	# The recovered switch's virtual branch does not cover 0x11/0x12, so that mode keeps MONEY cell 0.
	tank.virtual_tank = true
	var virtual_shrapnel: Coin = CoinScript.create(0x11, Vector2.ZERO)
	virtual_shrapnel.tank = tank
	_expect(virtual_shrapnel.sprite_image() == "IMAGE_MONEY", "Virtual kind 0x11 keeps the money fallback")
	_expect(not virtual_shrapnel.draws_sparks(), "Virtual kind 0x11 draws no sparks")
	virtual_shrapnel.free()
	var virtual_snot: Coin = CoinScript.create(0x12, Vector2.ZERO)
	virtual_snot.tank = tank
	_expect(virtual_snot.sprite_image() == "IMAGE_MONEY", "Virtual kind 0x12 keeps the money fallback")
	_expect(virtual_snot.sprite_row() == -1, "Virtual kind 0x12 draws money cell 0")
	virtual_snot.free()
	tank.virtual_tank = false


# --- helpers -----------------------------------------------------------------

## Attach a hand-built coin to the tank's RNG/host wiring without going through spawn.
func _attach(coin: Coin) -> void:
	coin.tank = tank
	coin.phase = SimScript.Phase.COLLISION
	tank.add_child(coin)


## A coin spawned just above the landing line and ticked onto it.
func _landed_coin(kind: int, y: float = 368.0) -> Coin:
	var coin: Coin = tank.spawn_coin(kind, Vector2(300.0, y))
	_step(2)
	_expect(coin.landed, "coin 0x%X landed for the expiry test" % kind)
	return coin


## Exactly `count` logic ticks with no carried backlog.
func _step(count: int) -> void:
	sim.flush_backlog()
	for i in count:
		sim.advance(SimScript.TICK_MS)


func _expect(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)
