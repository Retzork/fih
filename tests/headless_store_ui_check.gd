extends SceneTree
## Headless check for the store screen (P4.5): the recovered shelf rects, the price-line offsets and
## the row states the shop draws (sold out / greyed / affordable).
##
##   & "<godot>" --headless --path . --script res://tests/headless_store_ui_check.gd

const SimScript := preload("res://scripts/autoload/sim.gd")
const LevelScript := preload("res://scripts/tank/level.gd")
const ScreenScript := preload("res://scripts/ui/store_screen.gd")
const StoreScript := preload("res://scripts/economy/store.gd")
const BarScript := preload("res://scripts/ui/store_bar.gd")

var _failures := 0
var _checks := 0


func _init() -> void:
	_test_rects()
	_test_states()
	_test_rows()
	_test_bar()
	if _failures == 0:
		print("headless_store_ui_check: PASS (%d assertions)" % _checks)
		quit(0)
	else:
		printerr("headless_store_ui_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)


func _expect(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)


func _test_rects() -> void:
	_expect(ScreenScript.SLOT_RECTS.size() == 8, "eight shelves")
	_expect(ScreenScript.SLOT_RECTS[0] == Rect2(1, 5, 109, 140), "shelf 0 is the first left-column one")
	_expect(ScreenScript.SLOT_RECTS[3] == Rect2(193, 38, 98, 140), "shelf 3 opens the top row")
	_expect(ScreenScript.SLOT_RECTS[7] == Rect2(489, 339, 121, 100), "shelf 7 is the bottom-right one")
	_expect(ScreenScript.PRICE_OFFSET == Vector2(13, 108), "the price line sits at +0x150 / +0x154")
	_expect(ScreenScript.price_origin(Rect2(1, 5, 109, 140)) == Vector2(14, 113),
		"a price origin is the widget origin plus those offsets")


func _test_states() -> void:
	var empty := ScreenScript.row_state({}, 0)
	_expect(bool(empty["sold_out"]) and String(empty["name"]) == "Sold out", "an empty row reads sold out")
	var guppy := StoreScript.row_for(0)
	var guppy_state := ScreenScript.row_state(guppy, 100)
	var poor := ScreenScript.row_state(guppy, 50)
	_expect(not bool(poor["affordable"]) and bool(poor["greyed"]), "a row above the purse is greyed out")
	_expect(String(poor["name"]) == "Guppy" and int(poor["price"]) == 100, "the guppy row has its label and price")
	var exact := ScreenScript.row_state(guppy, 100)
	_expect(bool(exact["affordable"]) and not bool(exact["greyed"]), "exactly enough shells buys the row")
	var breeder := ScreenScript.row_state(StoreScript.row_for(1), 99999)
	_expect(bool(breeder["sold_out"]), "a row with no ported effect is sold out (Q-0049)")
	var carnivore := ScreenScript.row_state(StoreScript.row_for(4), 99999)
	_expect(not bool(carnivore["price_known"]) and bool(carnivore["greyed"]),
		"an unrecovered price greys the row instead of reading as free")
	_expect(not StoreScript.price_known(StoreScript.row_for(4)) and StoreScript.price_known(StoreScript.row_for(0)),
		"price_known separates the missing figures from the wiki ones")
	_expect(ScreenScript.price_text(breeder) == "SOLD", "a sold-out row's price line reads SOLD")
	_expect(ScreenScript.price_text(carnivore) == "?", "a missing figure reads as a question mark")
	_expect(ScreenScript.price_text(guppy_state) == "100", "a known price is the bare number")


func _test_bar() -> void:
	_expect(BarScript.slot_rect(0) == Rect2(18, 3, 60, 58),
		"the first in-tank slot is at x 0x12, y 3, 60x58 (FUN_005409B0)")
	_expect(BarScript.slot_rect(1).position.x == 87, "slot 1 starts at 0x57")
	_expect(BarScript.slot_rect(6).position.x == 436, "slot 6 starts at 0x1B4")
	_expect(BarScript.slot_rect(7) == Rect2(),
		"slot 7 has no recovered x, so it draws nothing (Q-0054)")
	var sim: Node = SimScript.new()
	var level: Level = LevelScript.new()
	level.render = false
	level.setup(sim, 9191)
	level.start_level(1, 3)
	_expect(StoreScript.item_name(int(BarScript.row_at(level, 0).get("slot", -1))) == "Guppy",
		"bar slot 0 sells the guppy on 1-3")
	_expect(int(BarScript.row_at(level, 3).get("slot", -1)) == 4, "bar slot 3 sells the carnivore")
	_expect(BarScript.row_at(level, 7).is_empty(), "a bar slot past the stock is empty")
	_expect(BarScript.row_index(level, 3) == 3 and BarScript.shelf_of(level, 3) == 3,
		"a bar slot maps to its row and back")
	var bar: Control = BarScript.new()
	bar.setup(level)
	level.money = 100
	expect_purchase(bar, level, "the bar buys from its own slot")
	_expect(not bar.press(7), "an empty bar slot buys nothing")
	bar.free()
	level.tank.shutdown()
	level.free()
	sim.free()


func expect_purchase(bar: Control, level: Level, what: String) -> void:
	var fish_before: int = level.tank.entities_in(SimScript.Phase.FISH).size()
	_expect(bar.press(0), what)
	_expect(level.money == 0, "the bar spends the row's price")
	_expect(level.tank.entities_in(SimScript.Phase.FISH).size() == fish_before + 1, "the purchase adds the fish")


func _test_rows() -> void:
	var sim: Node = SimScript.new()
	var level: Level = LevelScript.new()
	level.render = false
	level.setup(sim, 9090)
	level.store_rows([0, 2, 3, 10])
	_expect(level.tank_store.size() == 4, "the level carries four store rows")
	var screen: Control = ScreenScript.new()
	screen.setup(level)
	_expect(int(screen.row_at(0).get("slot", -1)) == 0, "slot 0 sells the guppy")
	_expect(int(screen.row_at(3).get("slot", -1)) == 10, "slot 3 sells the weapon upgrade")
	_expect(screen.row_at(7).is_empty(), "a shelf past the stock has no row")
	level.money = 100
	_expect(level.buy_item(0), "clicking the guppy shelf buys a fish")
	_expect(level.money == 0, "the price comes out of the shells")
	screen.free()
	level.tank.shutdown()
	level.free()
	sim.free()
