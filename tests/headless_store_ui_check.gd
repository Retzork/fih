extends SceneTree
## Headless check for the store screen (P4.5): the recovered shelf rects, the price-line offsets and
## the row states the shop draws (sold out / unknown price / short purse).
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
	# D-0029: the base game keeps a `$100` shelf bright green at a wallet of 45, so a short purse is
	# reported as `affordable == false` and nothing else - the price line is not recoloured.
	_expect(not bool(poor["affordable"]), "a row above the purse is still reported unaffordable")
	_expect(not bool(poor["greyed"]) and ScreenScript.price_color(poor) == ScreenScript.PRICE_COLOR,
		"but a short purse does not grey the price line (wallet 45 against a $100 guppy)")
	_expect(ScreenScript.price_color(guppy_state) == ScreenScript.PRICE_COLOR,
		"an affordable row is the same green")
	_expect(ScreenScript.price_color(ScreenScript.row_state({}, 99999)) == ScreenScript.GREYED_COLOR,
		"only a sold-out shelf takes the grey (0xCCCCCC, no icon)")
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
	_expect(BarScript.BAR_IMAGE == "IMAGE_MENUBAR",
		"the bar is the game's own MENUBAR art, not a blank Control")
	_expect(BarScript.BAR_SIZE == Vector2(640, 75), "MENUBAR is the 640x75 top strip")
	# D-0033: the wallet is the tank's label widget `Tank+0x438` - (0x217, 0x28, 0x50) - printing the
	# bare `"%d"`; the `$` in the badge is the `MENUBAR` art's own glyph, not a second label.
	_expect(BarScript.MONEY_RECT.position == Vector2(535, 40) and BarScript.MONEY_RECT.size.x == 80,
		"the wallet number sits in the recovered (535, 40, 80) label box")
	_expect(BarScript.slot_rect(0) == Rect2(18, 3, 58, 60),
		"the first in-tank slot is at x 0x12, y 3, 58x60 (FUN_005409B0)")
	_expect(BarScript.PLATE_RECT == Rect2(7, 45, 45, 12),
		"the price sits on MENUBAR's measured purple plate")
	# D-0027: a per-row scan of the base game's stocked shelf gives an ellipse 44 wide spanning
	# slot-local y 3..40, i.e. the badge fills the dome window and stops 4 px above the plate.
	_expect(BarScript.ICON_RECT == Rect2(6, 3, 44, 38),
		"the badge fills the dome window (44x38 at slot-local 6, 3)")
	# D-0027: the recording's two glows are at badge-relative (10, 6.5) and (38.5, 30.5).
	_expect(BarScript.BADGE_GLOWS.size() == 2
		and BarScript.BADGE_GLOWS[0][0] == Vector2(0.23, 0.17)
		and BarScript.BADGE_GLOWS[1][0] == Vector2(0.88, 0.80),
		"the badge's glows are the upper-left and lower-right ones the recording has")
	_expect(BarScript.SWIM_INSET == Vector2i(10, 8),
		"the guppy leaves the base game's margin inside the badge")
	_expect(BarScript.PRICE_COLOR == Color8(0x6E, 0xFA, 0x6E),
		"the tank button's label is the recovered green (FUN_005373C0)")
	_expect(BarScript.ICON_ART[4] == "IMAGE_SCL_OSCAR",
		"the carnivore dome draws its shipped 40x40 icon, not a name")
	_expect(BarScript.slot_rect(1).position.x == 87, "slot 1 starts at 0x57")
	_expect(BarScript.slot_rect(6).position.x == 436, "slot 6 starts at 0x1B4")
	_expect(BarScript.slot_rect(7) == Rect2(),
		"slot 7 has no recovered x, so it draws nothing (Q-0054)")
	var sim: Node = SimScript.new()
	var level: Level = LevelScript.new()
	level.render = false
	level.setup(sim, 9191)
	level.start_level(1, 3)
	# D-0019: `FUN_005409B0` builds a widget for every row with `A >= 0` in one `while (+0x2E0 <
	# +0x2DC)` sweep (EV-0144), so the bar opens with the level's whole stock - nothing waits for a
	# growth milestone and the egg dome is on the bar from the first frame.
	_expect(StoreScript.item_name(int(BarScript.row_at(level, 0).get("slot", -1))) == "Guppy",
		"1-3 opens with the guppy shelf on the bar")
	_expect(int(BarScript.row_at(level, 1).get("slot", -1)) == 2, "and the first food shelf")
	_expect(int(BarScript.row_at(level, 2).get("slot", -1)) == 3, "and the second food shelf")
	_expect(int(BarScript.row_at(level, 3).get("slot", -1)) == 4, "and the carnivore shelf")
	_expect(int(BarScript.row_at(level, 5).get("slot", -1)) == 10, "and the blaster shelf")
	_expect(level.egg_price == 2000, "1-3's egg dome is priced from the first frame")
	_expect(BarScript.row_at(level, 7).is_empty(), "a bar slot past the stock is empty")
	_expect(BarScript.row_index(level, 3) == 3 and BarScript.shelf_of(level, 3) == 3,
		"a bar slot maps to its row and back")
	var bar: Control = BarScript.new()
	bar.setup(level)
	# In the tree so the `Content` autoload resolves and the domes really compose (D-0025's cache is
	# only meaningful with art to build).
	root.add_child(bar)
	bar.refresh()
	_expect(bar._icons[4].texture == null and bar._prices[4].text == "",
		"an unstocked dome stays empty - SOLD is the StoreScreen's branch, not an empty tank slot")
	_expect(bar._money_label.text == str(level.money),
		"the MENUBAR wallet plate shows the tank's money")
	_expect(bar.get_node_or_null("MoneySign") == null,
		"no `$` label is drawn over the art's own badge glyph")
	_expect(UiFont.BAR_PRICE_FONT == "FONT_TINY" and UiFont.BAR_MONEY_FONT == "FONT_CONTINUUMBOLD12",
		"the prices use the fitted 8-px font and the wallet the recovered ContinuumBold12")
	_expect(BarScript.PRICE_SHADOW_COLOR == Color8(0x00, 0x4A, 0x00),
		"the price label carries the recording's 1-px dark shadow")
	# D-0027: the recording keeps `$100` bright green at a purse of 45, so no price is recoloured by
	# whether the tank can pay it.
	level.money = 45
	bar.refresh()
	_expect(level.tank_store[0].get("price", 0) == 100 and level.money == 45,
		"the recording's case: wallet 45 against the $100 guppy shelf")
	_expect(bar._prices[0].text == "$100"
		and bar._prices[0].get_theme_color("font_color") == BarScript.PRICE_COLOR,
		"a $100 shelf stays bright green at a wallet of 45")
	level.money = 0
	bar.refresh()
	_expect(bar._prices[0].get_theme_color("font_color") == BarScript.PRICE_COLOR,
		"a price stays green when the purse cannot pay it")
	level.money = 100
	expect_purchase(bar, level, "the bar buys from its own slot")
	_expect(bar._money_label.text == "0", "the wallet plate follows the purchase")
	_expect(not bar.press(7), "an empty bar slot buys nothing")
	_expect(BarScript.MENU_RECT == Rect2(525, 4, 80, 26),
		"the tank MENU target is the recovered (0x20D, 4, 0x50) rect")
	var menu := bar.get_node_or_null("Menu") as Button
	_expect(menu != null and menu.position == BarScript.MENU_RECT.position
		and menu.size == BarScript.MENU_RECT.size,
		"the MENU hit target covers the baked label")
	var menu_hits := []
	var on_menu := func() -> void: menu_hits.append(true)
	level.menu_requested.connect(on_menu)
	bar.press_menu()
	_expect(menu_hits.size() == 1,
		"the bar's MENU reaches the level's MENU request (TankScreen id 99)")
	level.menu_requested.disconnect(on_menu)
	# D-0025: a dome's art is composed once. Rebuilding it on every refresh cost 17 ms with seven
	# stocked domes - a whole frame, on every coin - for art that only changes when the weapon levels.
	# A `--script` run pumps no frames, so `Content` has no loaded images and the cached art is null
	# here; what these pin is that `refresh()` files each stocked dome under its id instead of
	# composing a new one, and that the bare badge is a single shared texture.
	_expect(BarScript._icon_cache.has("2") and BarScript._icon_cache.has("3")
		and BarScript._icon_cache.has("4") and BarScript._icon_cache.has("10:%d" % int(level.weapon_level)),
		"a refresh caches every stocked dome under its item id (the weapon under its level)")
	var oscar: Texture2D = bar.icon_for(4)
	level.money += 5
	bar.refresh()
	_expect(bar._icons[3].texture == oscar and BarScript._icon_cache["4"] == oscar,
		"a purse change redraws the plates and wallet without composing a new dome")
	_expect(BarScript.badge_placeholder() == BarScript.badge_placeholder(),
		"the bare badge is composed once and shared (the egg dome's backdrop)")
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
