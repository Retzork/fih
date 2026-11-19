class_name StoreScreen
extends Control
## StoreScreen - the in-tank shop (P4.5, SPECS.md §6; P2.12 §6/EV-0133/EV-0135).
##
## The screen is the 640x480 `STORESCREEN` art (the Fish Emporium room with its empty shelves) plus
## eight flat slots at the rects `FUN_0052B2D0` hands its item widgets. Each slot draws the row's name
## and a price line built from the widget's own offsets - `+0x150` = 13 across, `+0x154` = 108 down,
## with the shell icon at `(x + 0x19, y + 3)` - and the Shell count sits on the art's bottom plate.
##
## Not recovered, so deliberately not drawn (Q-0052): the stock roller (`FUN_0052FEA0` /
## `FUN_0052F0D0`), the widget's kind byte `+0x14C` -> per-kind art binding, the tooltip table's
## binding to item ids, the refresh timer `+0x1CC` and the paging arrows. The rows themselves come
## from the level's `tank_store`, the save-shaped stock the economy code already owns.

const SCREEN_SIZE := Vector2(640.0, 480.0)
const BACKGROUND_ID := "IMAGE_STORESCREEN"
const SHELL_ICON_ID := "IMAGE_STORESHELL"

## The eight item rects in creation order (`FUN_0052B2D0`'s stack `CRect` array, EV-0133). The slot
## index is the store slot: the stock refresh walks `item[i]` against the per-slot unlock byte
## `profile+0xA8+i` (P2.12 §6d), so widget `i` belongs to store slot `i` - the field the rows carry as
## `shelf` (D-0048).
const SLOT_RECTS := [
	Rect2(1.0, 5.0, 109.0, 140.0),
	Rect2(1.0, 143.0, 109.0, 140.0),
	Rect2(1.0, 282.0, 109.0, 140.0),
	Rect2(193.0, 38.0, 98.0, 140.0),
	Rect2(303.0, 38.0, 98.0, 140.0),
	Rect2(414.0, 38.0, 98.0, 140.0),
	Rect2(525.0, 38.0, 98.0, 140.0),
	Rect2(489.0, 339.0, 121.0, 100.0),
]

## An unavailable row's price string is the four-character literal `SOLD` (`0x5A7CA4`,
## `FUN_005372F0`), so the shelf reads SOLD rather than nothing.
const SOLD_TEXT := "SOLD"
## Price line (`+0x150`/`+0x154`) and icon offset (`x + 0x19`, `y + 3`).
const PRICE_OFFSET := Vector2(13.0, 108.0)
const PRICE_ICON_OFFSET := Vector2(25.0, 3.0)
## Price colour `FUN_00433360(0x6E, 0xFA, 0x6E)`; the greyed-out line is `0xCCCCCC` with no icon.
## Grey belongs to a shelf with nothing to sell (SOLD) or a figure the table never recovered -
## never to a purse that is short: the base keeps a price green at any balance (D-0029).
const PRICE_COLOR := Color(110.0 / 255.0, 250.0 / 255.0, 110.0 / 255.0)
const GREYED_COLOR := Color(0.8, 0.8, 0.8)
## Name line: the port's own addition (the original's name text lives on the tooltip), placed above
## the recovered price line inside the widget.
const NAME_OFFSET := Vector2(0.0, 84.0)
## The item icon above the name line. The store's own per-item art is not recovered (Q-0052), so the
## shelf draws the item's shipped icon (the bar's binding) in a square that fits every slot.
const ICON_SIZE := 46.0
const ICON_TOP := 24.0
## The Shell plate in the art's bottom centre. The counter widget's ctor rect (250,155,150,255) is a
## label layout box, not the plate, so the number is drawn on the plate the art actually shows.
const SHELL_RECT := Rect2(250.0, 424.0, 145.0, 32.0)
## The purchase blurb (`+0xBA0`, "Thanks for shopping at the Fish Emporium!") drawn at the tooltip's
## own position (0x186,0xDC) with the tooltip width (200).
const THANKS_TEXT := "Thanks for shopping at\nthe Fish Emporium!"
const THANKS_RECT := Rect2(390.0, 220.0, 200.0, 60.0)
## How long the blurb stays up. The original decrements `+0xBA0` without a recovered period.
const THANKS_SECONDS := 2.0

## The level this shop sells from; `setup()` is called before the screen enters the tree.
var level: Level = null

var _icons: Array[TextureRect] = []
var _names: Array[Label] = []
var _prices: Array[Label] = []
var _shell: Label = null
var _thanks: Label = null
var _thanks_left := 0.0


## Resolve an autoload only when the screen is inside the scene tree. `close()` is callable on a
## standalone screen in the headless checks, where `/root/...` is not available.
func _autoload(node_name: String) -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/" + node_name)


func setup(source: Level) -> void:
	level = source


func _ready() -> void:
	build()


## Build the slot labels and start drawing from the level. Split out of `_ready` so a check can
## stand a screen up without a tree (a `SceneTree`'s root has no frame yet during `_init`). Idempotent.
func build() -> void:
	if not _names.is_empty():
		refresh()
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_add_background()
	for index in SLOT_RECTS.size():
		_add_slot(index)
	_add_shell()
	_add_thanks()
	refresh()


func _process(delta: float) -> void:
	if _thanks_left > 0.0:
		_thanks_left -= delta
		if _thanks_left <= 0.0 and _thanks != null:
			_thanks.visible = false
	refresh()


## Escape leaves the shop; the original's own close control is not reconstructed (Q-0052).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


## Close the dialog and let the tank run again.
func close() -> void:
	var game := _autoload("Game")
	if game != null:
		game.gameplay_paused = false
	var screens := _autoload("Screens")
	if screens != null:
		screens.close_dialog()
	queue_free()


## The row's position in `tank_store`, which is what `Level.buy_item` takes; -1 when the slot is empty.
## Matched by the row's `shelf`, like the bar: the store slot is the base's per-item index
## (`profile+0xA8+i`, P2.12 §6d), and a loaded or restocked table need not sit in shelf order (D-0048).
func row_index_at(shelf: int) -> int:
	if level == null:
		return -1
	for i in level.tank_store.size():
		if int(level.tank_store[i].get("shelf", -1)) == shelf:
			return i
	return -1


## The row drawn on a store slot, or `{}` when that slot is unstocked.
func row_at(shelf: int) -> Dictionary:
	var index := row_index_at(shelf)
	return level.tank_store[index] if index >= 0 else {}


## The drawing state of one row: what the name and price lines say and whether they are greyed.
## `sold_out` rows are the ones `Store.is_available()` refuses - the port's stand-in for kind 0
## ("Sorry, this is sold out. Check back tomorrow!", P2.12 §6c) until the kind byte is bound.
## `affordable` is reported but no longer greys anything: a price the purse cannot pay is drawn
## exactly like one it can (D-0029), so `greyed` is only the sold-out / unknown-price pair.
static func row_state(row: Dictionary, money: int) -> Dictionary:
	var id := int(row.get("slot", -1))
	if id < 0:
		return {
			"id": -1,
			"name": "Sold out",
			"price": 0,
			"sold_out": true,
			"affordable": false,
			"greyed": true,
		}
	var sold_out := not Store.is_available(id)
	var price := int(row.get("price", 0))
	var price_known := Store.price_known(row)
	var affordable := money >= price
	return {
		"id": id,
		"name": Store.item_name(id),
		"price": price,
		"price_known": price_known,
		"sold_out": sold_out,
		"affordable": affordable,
		"greyed": sold_out or not price_known,
	}


## The colour of a row's price line: the recovered green for everything on sale, grey only for a
## sold-out shelf or an unrecovered figure.
static func price_color(state: Dictionary) -> Color:
	return GREYED_COLOR if bool(state["greyed"]) else PRICE_COLOR


## What the price line says: the literal `SOLD` on an unavailable row, `?` when the table never
## recovered the figure, otherwise the bare `"%d"` number the original formats (`FUN_00536350`).
static func price_text(state: Dictionary) -> String:
	if bool(state["sold_out"]):
		return SOLD_TEXT
	if not bool(state["price_known"]):
		return "?"
	return str(int(state["price"]))


## The absolute price-line origin of a slot: the widget rect plus `+0x150`/`+0x154`.
static func price_origin(rect: Rect2) -> Vector2:
	return rect.position + PRICE_OFFSET


## Redraw every line from the level's current stock, shells and upgrades.
func refresh() -> void:
	if level == null:
		return
	if _shell != null:
		_shell.text = str(level.money)
	for index in SLOT_RECTS.size():
		var row := row_at(index)
		var state := row_state(row, level.money)
		# A shelf this tank never stocks draws nothing at all: `FUN_005409B0` builds no widget for an
		# item with `A = -1`, so SOLD belongs only to a stocked row `Store.is_available()` refuses.
		var unstocked := row.is_empty()
		if index < _icons.size() and _icons[index] != null:
			var icon := _icons[index]
			var cell: Texture2D = null
			if not unstocked and not bool(state["sold_out"]):
				cell = StoreBar.item_cell(int(state["id"]),
					int(level.weapon_level), _autoload("Content"))
			icon.texture = cell
			icon.visible = cell != null
		if index < _names.size() and _names[index] != null:
			_names[index].text = "" if unstocked or bool(state["sold_out"]) else String(state["name"])
			_names[index].add_theme_color_override(
				"font_color", GREYED_COLOR if bool(state["greyed"]) else Color.WHITE)
		if index < _prices.size() and _prices[index] != null:
			var price := _prices[index]
			price.text = price_text(state)
			price.visible = not unstocked
			price.add_theme_color_override("font_color", price_color(state))


func _on_slot_pressed(shelf: int) -> void:
	var audio := _autoload("Audio")
	if audio != null:
		audio.play_click()
	if level == null:
		return
	# The button is bound to its store slot, not to an array position, so the purchase has to resolve
	# the slot's row the same way the drawing does (D-0048).
	var index := row_index_at(shelf)
	if index >= 0 and level.buy_item(index):
		_show_thanks()
	refresh()


func _show_thanks() -> void:
	_thanks_left = THANKS_SECONDS
	if _thanks != null:
		_thanks.visible = true


func _add_background() -> void:
	var content := _autoload("Content")
	if content == null or not content.has_image(BACKGROUND_ID):
		return
	var texture: Texture2D = content.texture(BACKGROUND_ID)
	if texture == null:
		return
	var back := TextureRect.new()
	back.name = "Background"
	back.texture = texture
	back.position = Vector2.ZERO
	back.size = SCREEN_SIZE
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)


func _add_slot(index: int) -> void:
	var rect: Rect2 = SLOT_RECTS[index]
	var button := Button.new()
	button.name = "Slot%d" % index
	button.position = rect.position
	button.size = rect.size
	# The art already draws the shelf, so the button contributes only its text lines.
	for style in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	button.pressed.connect(_on_slot_pressed.bind(index))
	add_child(button)
	# The item art the shelf sells, from the same binding the tank's shop bar draws (D-0054): the
	# shipped store art has the ledges but no item pictures, so a stocked shelf would read as an empty
	# room with a floating label.
	var icon := TextureRect.new()
	icon.name = "Icon%d" % index
	icon.size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.position = rect.position + Vector2((rect.size.x - ICON_SIZE) * 0.5, ICON_TOP)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	add_child(icon)
	_icons.append(icon)
	var name_label := Label.new()
	name_label.name = "Name%d" % index
	name_label.position = rect.position + NAME_OFFSET
	name_label.size = Vector2(rect.size.x, 22.0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The name line is a port addition (the original carries it on the tooltip), so it uses the
	# outline cut of the recovered store font to stay readable over the shelf art.
	UiFont.apply(name_label, UiFont.STORE_OUTLINE_FONT)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)
	_names.append(name_label)
	var price_label := Label.new()
	price_label.name = "Price%d" % index
	price_label.position = price_origin(rect) + Vector2(PRICE_ICON_OFFSET.x + 25.0, 0.0)
	price_label.size = Vector2(rect.size.x - 40.0, 20.0)
	UiFont.apply(price_label, UiFont.STORE_FONT)
	price_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(price_label)
	_prices.append(price_label)


func _add_shell() -> void:
	var content := _autoload("Content")
	if content != null and content.has_image(SHELL_ICON_ID):
		var texture: Texture2D = content.texture(SHELL_ICON_ID)
		if texture != null:
			var icon := TextureRect.new()
			icon.name = "ShellIcon"
			icon.texture = texture
			icon.position = SHELL_RECT.position - Vector2(texture.get_width() + 8.0, 2.0)
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(icon)
	_shell = Label.new()
	_shell.name = "Shells"
	_shell.position = SHELL_RECT.position
	_shell.size = SHELL_RECT.size
	_shell.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shell.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_shell.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	# `FUN_0050E190` maps the StoreScreen's counter font `DAT_005e8CE4` to ContinuumBold12.
	UiFont.apply(_shell, UiFont.STORE_FONT)
	_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shell)


func _add_thanks() -> void:
	_thanks = Label.new()
	_thanks.name = "Thanks"
	_thanks.text = THANKS_TEXT
	_thanks.position = THANKS_RECT.position
	_thanks.size = THANKS_RECT.size
	_thanks.visible = false
	_thanks.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	UiFont.apply(_thanks, UiFont.LABEL_FONT)
	_thanks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_thanks)
