class_name StoreBar
extends Control
## The in-tank store bar: the row of item buttons along the top of the aquarium that sells fish and
## upgrades in Adventure mode. The original builds each button with `FUN_005409B0`, which resolves the
## tank's store slot (`Tank+0x2E4 + i*4`), calls `FUN_005373C0(manager, i, listener)` to make a
## `Sexy::MenuButtonWidget`, and resizes it to `Rect(x[i], 3, 58, 60)`; the widgets are cached on the
## tank at `Tank+0x404 + slot*4` (EV-0150/EV-0183). The eighth x is not a constant in the decompile
## (the array's last element is pushed from the stack), so slot 7 stays unrecovered (Q-0054).
##
## `FUN_005373C0` is what this bar now follows: a menu button with an **image** and a **label**, not a
## text-only stand-in. It seeds the label colour green (`FUN_00433360(0x6E,0xFA,0x6E)`, EV-0183) and
## a 60 px label width at `+0x190`; the price string is the label. The image is the item's own art -
## the shipped 40x40 `SCL_*` creature icons, `FOOD` and `LASERUPGRADES` sheets - drawn in the dome
## above the plate.
##
## The bar is the game's own `MENUBAR` art (640x75). Its purple plates measure x 25..69 + 69*i,
## y 48..59, i.e. (7, 45, 45, 12) inside a slot whose x is the recovered table; the green wallet
## plate spans 530..621 x 39..58. Those measured rects place the icon and the price, so nothing is
## guessed from a font metric.
const BAR_IMAGE := "IMAGE_MENUBAR"
const BAR_SIZE := Vector2(640.0, 75.0)
## The green wallet plate inside `MENUBAR` (green pixels span x 530..621, y 39..58).
const MONEY_RECT := Rect2(530.0, 34.0, 100.0, 30.0)
## The purple price plate under each dome, measured from the art: (7, 45, 45, 12) slot-local.
const PLATE_RECT := Rect2(7.0, 45.0, 45.0, 12.0)
## The label's layout box: a `Label` clips its glyphs to its own rect, and the 8-px font's line is
## taller than the 12-px plate, so the box is deliberately tall (centre y 51) and the glyphs are
## drawn at their native size - a shorter box cut the bottoms off the price digits.
const PRICE_LABEL_RECT := Rect2(7.0, 30.0, 45.0, 42.0)
## The dome's glass: the shipped item icons are full 40x40 cells, so they are fitted to 34x34 inside
## the ring (a 1:1 draw put the fins across the gold rim).
const ICON_RECT := Rect2(12.0, 5.0, 34.0, 34.0)

## `FUN_005409B0`'s x table for slots 0-6; slot 7 is unrecovered (Q-0054).
const SLOT_X := [0x12, 0x57, 0x90, 0xD9, 0x122, 0x16B, 0x1B4]
## The widget rect's other three numbers from the same call: `y = 3`, 58 wide, 60 tall.
const SLOT_Y := 3.0
const SLOT_SIZE := Vector2(58.0, 60.0)
const SLOT_COUNT := 8

## `FUN_005373C0` writes `FUN_00433360(0x6E,0xFA,0x6E)` into the button's label colour.
const PRICE_COLOR := Color8(0x6E, 0xFA, 0x6E)
const GREYED_COLOR := Color8(0xCC, 0xCC, 0xCC)
const MONEY_COLOR := Color8(0xFF, 0xFF, 0xE8)

## The item art each store item draws in its dome. The creature icons are the shipped 40x40
## `SCL_*` sheets (one icon per sellable species); food and the weapon use their own sheets (the
## `LASERUPGRADES` cell is the weapon level). Item 0 has no `SCL_` icon, so it uses the guppy body
## sheet the tank draws (`SMALLSWIM`; `SIMSWIM1..3` are eye-only layers, Q-0042). Item 5 (star
## potion) ships no matching icon; the dome keeps the price only.
const ICON_ART := {
	0: "IMAGE_SMALLSWIM",
	1: "IMAGE_SCL_BREEDER",
	2: "IMAGE_FOOD",
	3: "IMAGE_FOOD",
	4: "IMAGE_SCL_OSCAR",
	6: "IMAGE_SCL_STARCATCHER",
	7: "IMAGE_SCL_GRUBBER",
	8: "IMAGE_SCL_GEKKO",
	9: "IMAGE_SCL_ULTRA",
	10: "IMAGE_LASERUPGRADES",
}

## The level whose `tank_store` the bar sells from.
var level: Level = null
var _background: TextureRect = null
var _money_label: Label = null
var _buttons: Array[Button] = []
var _icons: Array[TextureRect] = []
var _prices: Array[Label] = []
var _last_money := -1
var _last_stock := ""


## Resolve an autoload only when the bar is inside the scene tree. The headless checks call
## `press()` on a standalone bar, where an absolute `/root/...` lookup is an engine error.
func _autoload(node_name: String) -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/" + node_name)


## The rect of a bar slot. A slot past the recovered x table has an empty rect.
static func slot_rect(shelf: int) -> Rect2:
	if shelf < 0 or shelf >= SLOT_X.size():
		return Rect2()
	return Rect2(float(SLOT_X[shelf]), SLOT_Y, SLOT_SIZE.x, SLOT_SIZE.y)


## The store row the level puts on this bar slot (the row's `shelf`), or `{}`.
static func row_at(target: Level, shelf: int) -> Dictionary:
	if target == null:
		return {}
	for row: Dictionary in target.tank_store:
		# A shelf the level has not revealed yet has no widget, exactly like an unstocked one
		# (EV-0185): the dome stays empty until its milestone happens.
		if int(row.get("shelf", -1)) == shelf and not bool(row.get("hidden", false)):
			return row
	return {}


## The row's index in `tank_store`, which is what `Level.buy_item` takes; -1 when the slot is empty.
static func row_index(target: Level, shelf: int) -> int:
	if target == null:
		return -1
	for i in target.tank_store.size():
		if int(target.tank_store[i].get("shelf", -1)) == shelf and not bool(target.tank_store[i].get("hidden", false)):
			return i
	return -1


## The bar slot a `tank_store` row sits on, or -1.
static func shelf_of(target: Level, index: int) -> int:
	if target == null or index < 0 or index >= target.tank_store.size():
		return -1
	return int(target.tank_store[index].get("shelf", index))


func setup(target: Level) -> void:
	level = target
	position = Vector2.ZERO
	size = BAR_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add_background()
	_add_money_readout()
	for shelf in SLOT_X.size():
		var rect := slot_rect(shelf)
		var button := Button.new()
		button.name = "Slot%d" % shelf
		button.position = rect.position
		button.size = rect.size
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_slot_pressed.bind(shelf))
		add_child(button)
		_buttons.append(button)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.position = ICON_RECT.position
		icon.size = ICON_RECT.size
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		_icons.append(icon)
		var price_label := Label.new()
		price_label.name = "Price"
		price_label.position = PRICE_LABEL_RECT.position
		price_label.size = PRICE_LABEL_RECT.size
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		price_label.add_theme_color_override("font_color", PRICE_COLOR)
		UiFont.apply(price_label, UiFont.SMALL_FONT)
		button.add_child(price_label)
		_prices.append(price_label)
	refresh()


## The 640x75 `MENUBAR` art: the seven domes, the MENU button and the wallet plate. Without Content
## (a `--script` check runs the bar outside the tree) the bar keeps the same controls on a blank field.
func _add_background() -> void:
	var content := _autoload("Content")
	if content == null or not content.has_image(BAR_IMAGE):
		return
	var res: ImageRes = content.image(BAR_IMAGE)
	if res == null or res.texture == null:
		return
	_background = TextureRect.new()
	_background.name = "Background"
	_background.texture = res.texture
	_background.position = Vector2.ZERO
	_background.size = BAR_SIZE
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)


## The wallet number on the art's green plate (`Tank::AddMoney`'s value).
func _add_money_readout() -> void:
	_money_label = Label.new()
	_money_label.name = "Money"
	_money_label.position = MONEY_RECT.position
	_money_label.size = MONEY_RECT.size
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_money_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_money_label.add_theme_color_override("font_color", MONEY_COLOR)
	UiFont.apply(_money_label, UiFont.SMALL_FONT)
	add_child(_money_label)


## The item art a store id draws in its dome, as the first cell of its shipped sheet (the weapon's
## cell is its upgrade level). Null when the item ships no matching icon.
func _icon_texture(id: int) -> Texture2D:
	var art := String(ICON_ART.get(id, ""))
	if art == "":
		return null
	var content := _autoload("Content")
	if content == null or not content.has_image(art):
		return null
	var frames: SpriteFrames = content.sprite_frames(art)
	if frames == null or frames.get_frame_count("default") == 0:
		return null
	var frame := 0
	if id == 10 and level != null:
		frame = clampi(int(level.weapon_level), 0, frames.get_frame_count("default") - 1)
	var texture := frames.get_frame_texture("default", frame)
	if texture == null:
		return null

	# These sheets have no transparency of their own (P3.3): their alpha lives in the `masks/_<name>`
	# companion, exactly as the pets' sheets do. Compose the cell through `MaskAlpha`, and fall back
	# to colour-keying when a sheet ships no mask.
	var res: ImageRes = content.image(art)
	var mask := HatchScreen.mask_for(res.path) if res != null else null
	if mask != null:
		var composed := HatchScreen.masked_cell(texture, mask)
		if composed != null:
			return _body_crop(composed, art)
	return _body_crop(SpriteKey.keyed(texture), art)


## The guppy body sheet is 80x80 per cell with the fish inside a ~44-px centre; cropping that centre
## keeps it the same visual size as the 40x40 `SCL_` icons (port fit: the original's own icon image id
## is unrecovered, Q-0054). Cropping happens **after** the mask composite, which needs the full cell.
func _body_crop(texture: Texture2D, art: String) -> Texture2D:
	if texture == null or art != "IMAGE_SMALLSWIM":
		return texture
	var image := texture.get_image()
	if image == null or image.get_width() < 44 or image.get_height() < 44:
		return texture
	return ImageTexture.create_from_image(image.get_region(Rect2i(18, 18, 44, 44)))


## Redraw the eight slots when the purse or the stock changed since the last call.
func refresh_if_changed() -> void:
	if level == null:
		return
	var stock := str(level.tank_store.size()) + ":" + str(level.tank_store.hash())
	if level.money == _last_money and stock == _last_stock:
		return
	refresh()


func refresh() -> void:
	if level == null:
		return
	_last_money = level.money
	_last_stock = str(level.tank_store.size()) + ":" + str(level.tank_store.hash())
	if _money_label != null:
		_money_label.text = str(level.money)
	for shelf in _buttons.size():
		var row := row_at(level, shelf)
		var button := _buttons[shelf]
		var icon := _icons[shelf]
		var price_label := _prices[shelf]
		if row.is_empty():
			# `FUN_005409B0` builds no widget for an item that is not for sale, so the dome stays
			# empty. `SOLD` belongs to the StoreScreen's sold-out branch, not to an empty tank slot.
			button.disabled = true
			button.mouse_default_cursor_shape = Control.CURSOR_ARROW
			icon.texture = null
			price_label.text = ""
			continue
		var id := int(row.get("slot", -1))
		if id == Progression.EGG_ITEM:
			# The egg's own widget draws this dome (art, piece cell and price) on every tank; the bar
			# keeps the row and the click path, so nothing is drawn twice.
			icon.texture = null
			price_label.text = ""
			# The widget's own button covers this rect, so the bar's stays inert underneath.
			button.disabled = true
			button.mouse_default_cursor_shape = Control.CURSOR_ARROW
			continue
		icon.texture = _icon_texture(id)
		var known := Store.price_known(row)
		var affordable := known and (int(row.get("price", 0)) <= level.money)
		button.disabled = not known or level.completed
		button.mouse_default_cursor_shape = (
			Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND)
		price_label.text = str(int(row.get("price", 0))) if known else "?"
		var colour := PRICE_COLOR if affordable else GREYED_COLOR
		price_label.add_theme_color_override("font_color", colour)


## Click a bar slot: it buys the row that sits there. Returns whether the purchase went through.
func press(shelf: int) -> bool:
	var audio := _autoload("Audio")
	if audio != null:
		audio.play_click()
	var index := row_index(level, shelf)
	if index < 0:
		return false
	var bought := level.buy_item(index)
	refresh()
	return bought


func _on_slot_pressed(shelf: int) -> void:
	press(shelf)
