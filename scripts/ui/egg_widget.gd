class_name EggWidget
extends Control
## The tank's egg-piece widget (P2.6 §3/§5). `buy_egg()` is the purchase API; this is the clickable
## object that makes it reachable on tanks 1-4.
##
## Placement (2026-11-10, owner review): the **seventh `MENUBAR` dome** (store slot 6), which no store
## row occupies on tanks 1-4 - the bar leaves that dome empty. Tank 5 sells the egg as that dome's
## free row, so the bar keeps the row and the click; the widget still draws the dome there, which is
## why `StoreBar` blanks that row's text (`StoreBar.refresh`).
##
## The widget's own rect was never recovered (Q-0053), so the dome placement is a presentation choice
## that follows the bar it sits in; the piece count and the price are the recovered figures.
##
## The art is the progress readout: `EGGPIECES` ships three cells, from the bare shell to the whole
## egg, so the piece count picks the cell. There is no recovered text label, so the exact count lives
## in the tooltip rather than as another line drawn over the tank.

const EGG_ART := "IMAGE_EGGPIECES"
const PIECES_TO_COMPLETE := 4
## The eighth dome, at `SLOT_X[6]` in `StoreBar` (the recovered `FUN_005409B0` x table).
const SLOT := 6
## Inside the 58x60 slot: the 46x39 cell (`EGGPIECES` is 138x39, three cells) is fitted into the
## 40x34 dome window, so it can never spill over the gold rim, and the price sits on the same
## measured purple plate as every other dome (`StoreBar.PLATE_RECT`, 45x12 at (7, 45)).
const ART_RECT := Rect2(9.0, 4.0, 40.0, 34.0)
## The label box is centred on the 12-px plate (centre y 51) so the native glyphs are not clipped.
const PRICE_RECT := Rect2(7.0, 42.0, 45.0, 18.0)
const GREY := Color8(0xCC, 0xCC, 0xCC)
## `FUN_005373C0` seeds the tank store buttons with the green label colour 0x6EFA6E.
const PRICE_COLOR := Color8(0x6E, 0xFA, 0x6E)

var level = null

var _button: Button = null
var _price: Label = null
var _art: TextureRect = null
var _frames: SpriteFrames = null
var _last_signature := ""


func _autoload(node_name: String) -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/" + node_name)


func setup(source) -> void:
	level = source
	var slot := StoreBar.slot_rect(SLOT)
	position = slot.position
	size = slot.size
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200

	_button = Button.new()
	_button.name = "Buy"
	_button.position = Vector2.ZERO
	_button.size = size
	_button.flat = true
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(_on_pressed)
	add_child(_button)

	_price = Label.new()
	_price.name = "Price"
	_price.position = PRICE_RECT.position
	_price.size = PRICE_RECT.size
	_price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiFont.apply(_price, UiFont.SMALL_FONT)
	_button.add_child(_price)

	refresh()


func _ready() -> void:
	var content := _autoload("Content")
	if content == null:
		return
	_frames = content.sprite_frames(EGG_ART)
	if _frames == null or _frames.get_frame_count("default") == 0:
		return
	var texture := _frames.get_frame_texture("default", 0)
	if texture == null:
		return
	_art = TextureRect.new()
	_art.name = "Egg"
	_art.texture = texture
	_art.position = ART_RECT.position
	_art.size = ART_RECT.size
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	move_child(_art, 0)
	refresh()


## Redraw only when the purse, the piece count, the price, completion or the tank changed.
func refresh_if_changed() -> void:
	if level == null:
		return
	var signature := _signature()
	if signature == _last_signature:
		return
	_last_signature = signature
	refresh()


func refresh() -> void:
	if level == null or _button == null:
		return
	_last_signature = _signature()
	# The dome is on the bar on every tank, but only once the egg is revealed (EV-0185: 1-1 after a
	# large guppy, 1-2 after food Lv 2, 1-3+ after a predator; always from the start on tank 5).
	visible = bool(level.egg_unlocked)
	var pieces := mini(int(level.egg_pieces), PIECES_TO_COMPLETE)
	var price := int(level.egg_price)
	var known := price != Progression.PRICE_UNKNOWN
	var affordable := known and (price <= 0 or int(level.money) >= price)
	_button.disabled = bool(level.completed) or not known or not affordable
	tooltip_text = "Egg %d/%d" % [pieces, PIECES_TO_COMPLETE]
	if not known:
		_price.text = "?"
	elif price <= 0:
		_price.text = "FREE"
	else:
		_price.text = str(price)
	var colour := PRICE_COLOR if affordable and not level.completed else GREY
	_price.add_theme_color_override("font_color", colour)
	_show_frame(pieces)


## The cell for this piece count: the sheet runs from the bare shell (0) to the whole egg (2).
func _show_frame(pieces: int) -> void:
	if _art == null or _frames == null:
		return
	var last := _frames.get_frame_count("default") - 1
	var texture := _frames.get_frame_texture("default", clampi(pieces - 1, 0, last))
	if texture != null:
		_art.texture = texture


func _signature() -> String:
	return "%d:%d:%d:%d:%s:%s" % [
		int(level.tank_index), int(level.money), int(level.egg_pieces),
		int(level.egg_price), str(level.completed), str(level.egg_unlocked)
	]


## Click the widget: buy one piece. Returns whether the purchase went through.
func press() -> bool:
	if level == null or _button == null:
		return false
	# The purse can change between ticks (a collected coin, a store purchase), so re-evaluate the
	# button state before deciding the click is refused.
	refresh()
	if _button.disabled:
		return false
	if not level.buy_egg():
		refresh()
		return false
	level.play_sound("SOUND_BUY")
	refresh()
	return true


func _on_pressed() -> void:
	press()
