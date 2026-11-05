class_name StoreBar
extends Control
## The in-tank store bar: the row of item buttons along the top of the aquarium that sells fish and
## upgrades in Adventure mode. Each button is a `Sexy::StoreButtonWidget` in the original, created by
## `FUN_005409B0` (EV-0150) and cached on the tank at `Tank+0x404 + slot*4`; the tank owns the widgets
## and the StoreScreen's shelf widgets are clients of the same rows (Q-0018).
##
## Recovered here: `FUN_005409B0` builds the widget at `Rect(x[slot], 3, 60, 58)`, where the x table is
## `0x12, 0x57, 0x90, 0xD9, 0x122, 0x16B, 0x1B4` for slots 0-6. The eighth entry is not a constant in
## the decompile (the array's last element is pushed from the stack), so slot 7's x is unrecovered and
## Q-0054 records it - the port leaves that slot blank rather than guessing.
##
## Not recovered, so not drawn: the widget art per item kind (`+0x14C`, Q-0052). The buttons are flat
## with the item's name and its recovered price line, exactly like the StoreScreen's shelves.

## `FUN_005409B0`'s x table for slots 0-6; slot 7 is unrecovered (Q-0054).
const SLOT_X := [0x12, 0x57, 0x90, 0xD9, 0x122, 0x16B, 0x1B4]
## The widget rect's other three numbers from the same call: `y = 3`, 60 wide, 58 tall.
const SLOT_Y := 3.0
const SLOT_SIZE := Vector2(60.0, 58.0)
const SLOT_COUNT := 8

const GREYED_COLOR := Color8(0xCC, 0xCC, 0xCC)
const PRICE_COLOR := Color8(0xF2, 0xE8, 0xC8)
const SOLD_TEXT := "SOLD"

## The level whose `tank_store` the bar sells from.
var level: Level = null
var _buttons: Array[Button] = []
var _labels: Array[Label] = []
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
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
		var name_label := Label.new()
		name_label.position = Vector2(2.0, 6.0)
		name_label.size = Vector2(rect.size.x - 4.0, 20.0)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 9)
		button.add_child(name_label)
		_labels.append(name_label)
		var price_label := Label.new()
		price_label.position = Vector2(2.0, 24.0)
		price_label.size = Vector2(rect.size.x - 4.0, 20.0)
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.add_theme_font_size_override("font_size", 11)
		price_label.add_theme_color_override("font_color", PRICE_COLOR)
		button.add_child(price_label)
		_prices.append(price_label)
	refresh()


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
	for shelf in _buttons.size():
		var row := row_at(level, shelf)
		var button := _buttons[shelf]
		var name_label := _labels[shelf]
		var price_label := _prices[shelf]
		if row.is_empty():
			button.disabled = true
			name_label.text = ""
			price_label.text = SOLD_TEXT
			price_label.add_theme_color_override("font_color", GREYED_COLOR)
			continue
		var id := int(row.get("slot", -1))
		name_label.text = Store.item_name(id)
		var known := Store.price_known(row)
		var affordable := known and (int(row.get("price", 0)) <= level.money)
		button.disabled = not known or level.completed
		price_label.text = str(int(row.get("price", 0))) if known else "?"
		var colour := PRICE_COLOR if affordable else GREYED_COLOR
		price_label.add_theme_color_override("font_color", colour)
		name_label.add_theme_color_override("font_color",
			Color.WHITE if affordable else GREYED_COLOR)


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
