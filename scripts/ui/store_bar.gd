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
## The tank-screen MENU button (`FUN_00506820(99, ...)`, id 99): its recovered rect starts at
## (0x20D, 4) and is 0x50 wide; the fourth argument is the button's own height field, not a literal,
## so the port uses the same 26-px height `HatchScreen` gives the baked MENU plate. The label and
## frame are part of the `MENUBAR` art, so the control itself is a flat hit target.
const MENU_RECT := Rect2(525.0, 4.0, 80.0, 26.0)
## The green wallet plate inside `MENUBAR` (green pixels span x 530..621, y 39..58). The base game
## puts a dark-green `$` in the plate's left badge and right-aligns the number in the green field.
## Both boxes share y 34..64, so the glyphs share one centre line by construction.
const MONEY_RECT := Rect2(546.0, 34.0, 74.0, 30.0)
const MONEY_SIGN_RECT := Rect2(531.0, 34.0, 14.0, 30.0)
const MONEY_SIGN_COLOR := Color8(0x36, 0x72, 0x0A)
## The purple price plate under each dome, measured from the art: (7, 45, 45, 12) slot-local.
const PLATE_RECT := Rect2(7.0, 45.0, 45.0, 12.0)
## The label's layout box: a `Label` clips its glyphs to its own rect, and the 8-px font's line is
## taller than the 12-px plate, so the box is deliberately tall (centre y 51) and the glyphs are
## drawn at their native size - a shorter box cut the bottoms off the price digits.
const PRICE_LABEL_RECT := Rect2(7.0, 30.0, 45.0, 42.0)
## The dome's glass, measured off the base-game recording (D-0027): a per-row scan of the stocked
## shelf's violet gives an ellipse 44 wide spanning slot-local y 3..40 - 14 px wide on its top row,
## 44 wide from y 15..28, 20 px on its bottom row - so the badge fills the whole dome window and
## stops 4 px above the price plate at y 45. The earlier 44x33 at (6, 9) was too small and sat too
## low, leaving the dome's gold moulding showing above the violet.
const ICON_RECT := Rect2(6.0, 3.0, 44.0, 38.0)

## `FUN_005409B0`'s x table for slots 0-6; slot 7 is unrecovered (Q-0054).
const SLOT_X := [0x12, 0x57, 0x90, 0xD9, 0x122, 0x16B, 0x1B4]
## The widget rect's other three numbers from the same call: `y = 3`, 58 wide, 60 tall.
const SLOT_Y := 3.0
const SLOT_SIZE := Vector2(58.0, 60.0)
const SLOT_COUNT := 8

## `FUN_005373C0` writes `FUN_00433360(0x6E,0xFA,0x6E)` into the button's label colour, and the
## recording keeps that green whatever the purse holds - at money 45 the `$100` shelf and the `$150`
## egg are as bright as at money 400 (D-0027). The bar used to grey a price it could not pay; the
## base game never does, so there is no second colour here.
const PRICE_COLOR := Color8(0x6E, 0xFA, 0x6E)
## The wallet number is the same green as every price (sampled #84EF89 in the recording).
const MONEY_COLOR := PRICE_COLOR

## The fish icon is animated (D-0022, owner report: the base game swims the guppy in its dome): the
## bar plays the same stage-0 row of `SMALLSWIM` the tank draws - `SWIM_COLUMNS` cells, one per
## `AnimState.SHEET_FRAME_TICKS`, from the same column clock - instead of holding one cell still.
const SWIM_COLUMNS := 10

## The item badge (D-0023): the base game draws every stocked shelf as the item over a violet disc
## that fills the dome - `$100` with a blue-violet badge behind the guppy, the egg cup over the same
## violet in the seventh dome (measured from the owner's 1-1 recording: the badge is 44x33 logical,
## i.e. the dome glass). Colours sampled from that recording: base #522488, brighter blue at the
## right side #5132B3, lavender highlight #A489C7, dark floor #44052B. Port fit - the shipped icon
## atlas that carries the badge is unrecovered (Q-0054), so the bar builds it from these samples.
const BADGE_BASE := Color8(0x52, 0x24, 0x88)
const BADGE_EDGE := Color8(0x51, 0x32, 0xB3)
const BADGE_HIGHLIGHT := Color8(0xA4, 0x89, 0xC7)

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

## The tank MENU was pressed (TankScreen id 99 -> `FUN_0054AED0` + `FUN_00552100`); the bar has
## already forwarded the request to `Level.request_menu()`.
signal menu_pressed

## Dome art by item id, composed once per run (D-0025). `refresh()` runs whenever the purse changes -
## so on every coin - and building a dome is a mask composite plus a 44x33 per-pixel badge; seven
## stocked domes cost 17 ms a refresh, a whole frame, which the owner felt as a stutter on pickups.
## Keyed by the item id, with the weapon's upgrade level appended because that picks its cell.
static var _icon_cache := {}
## The bare badge, composed once and shared by every dome that has no item on it - the egg widget's
## backdrop, which used to build its own copy per widget.
static var _badge_placeholder: Texture2D = null

## The level whose `tank_store` the bar sells from.
var level: Level = null
var _background: TextureRect = null
var _money_label: Label = null
var _money_sign: Label = null
var _menu_button: Button = null
var _buttons: Array[Button] = []
var _icons: Array[TextureRect] = []
var _prices: Array[Label] = []
var _last_money := -1
var _last_stock := ""
## The composed swim cells of the fish icon and the slot/time they are being played on.
var _swim_frames: Array[Texture2D] = []
var _swim_loaded := false
var _swim_shelf := -1
var _swim_column := -1


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
		# Every row the level sells owns a widget from the first frame (EV-0144), so an empty dome is
		# simply a shelf this tank never stocks.
		if int(row.get("shelf", -1)) == shelf:
			return row
	return {}


## The row's index in `tank_store`, which is what `Level.buy_item` takes; -1 when the slot is empty.
static func row_index(target: Level, shelf: int) -> int:
	if target == null:
		return -1
	for i in target.tank_store.size():
		if int(target.tank_store[i].get("shelf", -1)) == shelf:
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
	var game := _autoload("Game")
	if game != null and not game.show_money_changed.is_connected(_on_show_money_changed):
		game.show_money_changed.connect(_on_show_money_changed)
	_add_menu_button()
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


## The tank MENU hit target over the baked `MENUBAR` label. `FUN_00506820(99, ...)` creates it as
## a text button, but the shipped bar already draws the word and frame, so a flat button is enough.
func _add_menu_button() -> void:
	_menu_button = Button.new()
	_menu_button.name = "Menu"
	_menu_button.position = MENU_RECT.position
	_menu_button.size = MENU_RECT.size
	_menu_button.flat = true
	_menu_button.focus_mode = Control.FOCUS_NONE
	_menu_button.pressed.connect(_on_menu_pressed)
	add_child(_menu_button)


## The wallet on the art's green plate (`Tank::AddMoney`'s value): the dark-green `$` in the plate's
## left badge and the number right-aligned in the green field, as the base game draws it.
func _add_money_readout() -> void:
	_money_sign = Label.new()
	_money_sign.name = "MoneySign"
	_money_sign.text = "$"
	_money_sign.position = MONEY_SIGN_RECT.position
	_money_sign.size = MONEY_SIGN_RECT.size
	_money_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_money_sign.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_money_sign.add_theme_color_override("font_color", MONEY_SIGN_COLOR)
	UiFont.apply(_money_sign, UiFont.SMALL_FONT)
	add_child(_money_sign)
	_money_label = Label.new()
	_money_label.name = "Money"
	_money_label.position = MONEY_RECT.position
	_money_label.size = MONEY_RECT.size
	_money_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	var cell: Texture2D = null
	if mask != null:
		cell = HatchScreen.masked_cell(texture, mask)
	if cell == null:
		cell = SpriteKey.keyed(texture)
	if cell == null or cell.get_image() == null:
		return null
	return badge_cell(cell.get_image())


## The dome art for `id`, composed once and reused (D-0025).
func icon_for(id: int) -> Texture2D:
	var key := str(id)
	if id == 10:
		key = "10:%d" % (int(level.weapon_level) if level != null else 0)
	if _icon_cache.has(key):
		return _icon_cache[key]
	var texture := _icon_texture(id)
	if texture == null:
		# A stocked shelf the port has no icon for (the star potion, id 5) still has to read as a
		# shelf: the base game never draws a stocked dome as an empty gold one (Q-0054).
		texture = badge_placeholder()
	_icon_cache[key] = texture
	return texture


## The empty badge, composed once: the egg dome and any item without art sit on this one texture.
static func badge_placeholder() -> Texture2D:
	if _badge_placeholder == null:
		_badge_placeholder = badge_cell(null)
	return _badge_placeholder


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
		var game := _autoload("Game")
		var show_money := true if game == null else bool(game.show_money)
		_money_label.visible = show_money
		_money_label.text = str(level.money)
		if _money_sign != null:
			_money_sign.visible = show_money
	_swim_shelf = -1
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
		if id == 0:
			# The guppy dome plays its own swim row (D-0022) rather than one held cell.
			_ensure_swim_frames()
			_swim_shelf = shelf
			_swim_column = _swim_column_at()
			icon.texture = _swim_frames[_swim_column] if not _swim_frames.is_empty() else null
		else:
			icon.texture = icon_for(id)
		var known := Store.price_known(row)
		button.disabled = not known or level.completed
		button.mouse_default_cursor_shape = (
			Control.CURSOR_ARROW if button.disabled else Control.CURSOR_POINTING_HAND)
		# The base game's price label carries the currency sign (`$100` on the 1-1 recording, D-0023).
		price_label.text = ("$%d" % int(row.get("price", 0))) if known else "$?"
		price_label.add_theme_color_override("font_color", PRICE_COLOR)
	set_process(_swim_shelf >= 0)


## Advance the fish icon's swim cell. The column is a pure function of the sim tick, the same clock
## the tank's own guppy uses (`AnimState.column_at`), so the dome keeps the game's cadence instead of
## a per-frame flicker.
func _process(_delta: float) -> void:
	if _swim_shelf < 0 or _swim_frames.is_empty():
		return
	var column := mini(_swim_column_at(), _swim_frames.size() - 1)
	if column == _swim_column:
		return
	_swim_column = column
	var icon := _icons[_swim_shelf]
	if icon != null:
		icon.texture = _swim_frames[column]


## Compose the swim row once, on the first frame that has to draw the fish dome (its ten cells are as
## expensive as the other domes, and `refresh()` must not redo them on a coin - D-0025).
func _ensure_swim_frames() -> void:
	if _swim_loaded:
		return
	_swim_loaded = true
	_swim_frames = _compose_swim_frames()


func _sim_tick() -> int:
	var sim := _autoload("Sim")
	return int(sim.tick_count) if sim != null else 0


func _swim_column_at() -> int:
	return AnimState.column_at(0, _sim_tick(), SWIM_COLUMNS)


## The fish icon's swim cells: every column of the stage-0 row, composed through the sheet's mask.
## All ten are cropped with **one** box - the union of their opaque pixels - so the fish fills the
## dome and does not breathe in scale from cell to cell (the earlier fixed 44x44 crop left the dome's
## own shading showing around a small fish, which the owner read as a shut lid, D-0022).
func _compose_swim_frames() -> Array[Texture2D]:
	var content := _autoload("Content")
	var art := String(ICON_ART.get(0, ""))
	var out: Array[Texture2D] = []
	if content == null or art == "" or not content.has_image(art):
		return out
	var frames: SpriteFrames = content.sprite_frames(art)
	if frames == null:
		return out
	var res: ImageRes = content.image(art)
	var mask := HatchScreen.mask_for(res.path) if res != null else null
	var cells: Array[Image] = []
	var box := Rect2i()
	for column in mini(frames.get_frame_count("default"), SWIM_COLUMNS):
		var texture := frames.get_frame_texture("default", column)
		if texture == null:
			continue
		var composed := HatchScreen.masked_cell(texture, mask) if mask != null else null
		var image := (composed if composed != null else SpriteKey.keyed(texture)).get_image()
		if image == null:
			continue
		cells.append(image)
		var cell_box := _opaque_box(image)
		box = cell_box if box.size == Vector2i.ZERO else box.merge(cell_box)
	if box.size.x < 8 or box.size.y < 8:
		return out
	for image in cells:
		out.append(badge_cell(image.get_region(box)))
	return out


## The icon cell: the item over the violet badge that fills the dome (D-0023). `ICON_RECT` is that
## badge's own 44x33, so the texture draws 1:1. The item is fitted inside the badge and centred.
static func badge_cell(body: Image) -> Texture2D:
	var width := int(ICON_RECT.size.x)
	var height := int(ICON_RECT.size.y)
	var canvas := Image.create(width, height, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0.0, 0.0, 0.0, 0.0))
	var centre := Vector2(width, height) * 0.5
	for y in height:
		for x in width:
			var dx := (x + 0.5 - centre.x) / centre.x
			var dy := (y + 0.5 - centre.y) / centre.y
			var inside := 1.0 - (dx * dx + dy * dy)
			if inside <= 0.0:
				continue
			var coverage := clampf(inside * float(height) * 0.5, 0.0, 1.0)
			var across := clampf(float(x) / float(width - 1), 0.0, 1.0)
			var shade := clampf(1.15 - float(y) / float(height - 1) * 0.75, 0.42, 1.15)
			var tint := BADGE_BASE.lerp(BADGE_EDGE, across * across)
			canvas.set_pixel(x, y, Color(tint.r * shade, tint.g * shade, tint.b * shade, coverage))
	_badge_highlight(canvas, Vector2(width * 0.29, height * 0.30), height * 0.14, 0.85)
	_badge_highlight(canvas, Vector2(width * 0.24, height * 0.24), height * 0.05, 0.95)
	if body != null:
		# The base game's fish all but fills the badge (its tail crosses the dome ring), so the fit
		# leaves only a two-pixel margin on the long side.
		var scale := minf(float(width - 3) / maxi(body.get_width(), 1),
			float(height - 2) / maxi(body.get_height(), 1))
		var fitted := body.duplicate() as Image
		fitted.resize(maxi(int(body.get_width() * scale), 1), maxi(int(body.get_height() * scale), 1),
			Image.INTERPOLATE_BILINEAR)
		canvas.blend_rect(fitted, Rect2i(Vector2i.ZERO, fitted.get_size()),
			Vector2i((width - fitted.get_width()) / 2, (height - fitted.get_height()) / 2))
	return ImageTexture.create_from_image(canvas)


## A soft lavender blob on the badge, alpha-blended so it reads as the shipped highlight.
static func _badge_highlight(canvas: Image, at: Vector2, radius: float, strength: float) -> void:
	var reach := int(ceil(radius))
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var x := int(at.x) + dx
			var y := int(at.y) + dy
			if x < 0 or y < 0 or x >= canvas.get_width() or y >= canvas.get_height():
				continue
			var distance := Vector2(dx, dy).length()
			if distance > radius:
				continue
			var alpha := (1.0 - distance / maxf(radius, 0.001)) * strength
			var under := canvas.get_pixel(x, y)
			canvas.set_pixel(x, y, under.blend(Color(BADGE_HIGHLIGHT.r, BADGE_HIGHLIGHT.g,
				BADGE_HIGHLIGHT.b, alpha * under.a)))


## The box of an image's drawn pixels (alpha above the mask's antialiasing floor).
static func _opaque_box(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.06:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


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


## Press the tank MENU button (TankScreen id 99). The original's handler
## (`FUN_0051B6C0(99)`) tears the tank screen down with `FUN_0054AED0()` and rebuilds the main menu
## with `FUN_00552100()`; the transition itself belongs to `Level`/`Main`, so the bar only forwards
## the request. `menu_pressed` stays available for checks and future HUD listeners.
func press_menu() -> void:
	var audio := _autoload("Audio")
	if audio != null:
		audio.play_click()
	if level != null:
		level.request_menu()
	menu_pressed.emit()


func _on_menu_pressed() -> void:
	press_menu()


## The Options "Show Money" checkbox: hide or show the wallet plate without rebuilding the bar.
func _on_show_money_changed(show: bool) -> void:
	if _money_label != null:
		_money_label.visible = show
	if _money_sign != null:
		_money_sign.visible = show
