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
## Inside the 58x60 slot: the cell (`EGGPIECES` is 138x39, three cells of 46x39) is drawn over the
## same violet badge every other item sits on (owner review 2026-11-16). The base game's egg dome is a
## wide violet disc with a big cream cup (1-1 recording, D-0023). Its cup is larger than this cell's:
## the cell is `EGGPIECES`' progress art, not the store icon the original puts there (that icon atlas
## is unrecovered, Q-0054), so the cell is fitted to the badge's height rather than scaled past it -
## at 1.25 the pointed egg's top gets clipped flat, which looked worse than the smaller cup. The fit
## is derived from the window, so the two can never drift apart. The price sits on the same measured
## purple plate as every other dome (`StoreBar.PLATE_RECT`, 45x12 at (7, 45)).
const ART_WINDOW := StoreBar.ICON_RECT
## `EGGPIECES` cell size (138x39 / 3).
const CELL_SIZE := Vector2(46.0, 39.0)
## The label box is the bar's own price box: same plate, same centre y 51, so the two domes cannot
## drift apart.
const PRICE_RECT := StoreBar.PRICE_LABEL_RECT
## `FUN_005373C0` seeds the tank store buttons with the green label colour 0x6EFA6E, and the
## recording keeps that green at any balance (the `$150` egg is bright at money 45 as well - D-0027).
const PRICE_COLOR := Color8(0x6E, 0xFA, 0x6E)

var level = null

var _button: Button = null
var _price: Label = null
var _art: TextureRect = null
var _frames: SpriteFrames = null
var _last_signature := ""
## Composed cells by index, so the mask pass runs once per piece count.
var _cells := {}


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

	# The badge first: it is what fills the dome once the cup art is on top.
	var badge := TextureRect.new()
	badge.name = "Badge"
	badge.texture = StoreBar.badge_placeholder()
	badge.position = ART_WINDOW.position
	badge.size = ART_WINDOW.size
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(badge)
	var texture := _masked(0)
	if texture == null:
		return
	# The cell is composed through its alpha companion (`masks/_EggPieces.png`, see `_masked`), which
	# is what keeps the purple window the art draws inside the dome instead of landing as a square
	# patch on the bar (owner review 2026-11-16). The fit below keeps the cell inside the badge, so
	# no clip control is needed.
	_art = TextureRect.new()
	_art.name = "Egg"
	_art.texture = texture
	var fit := minf(ART_WINDOW.size.x / CELL_SIZE.x, ART_WINDOW.size.y / CELL_SIZE.y)
	_art.size = CELL_SIZE * fit
	_art.position = ART_WINDOW.position + (ART_WINDOW.size - _art.size) * 0.5
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
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
	var pieces := mini(int(level.egg_pieces), PIECES_TO_COMPLETE)
	var price := int(level.egg_price)
	var known := price != Progression.PRICE_UNKNOWN
	var affordable := known and (price <= 0 or int(level.money) >= price)
	_button.disabled = bool(level.completed) or not known or not affordable
	tooltip_text = "Egg %d/%d" % [pieces, PIECES_TO_COMPLETE]
	if not known:
		_price.text = "$?"
	elif price <= 0:
		_price.text = "FREE"
	else:
		# The base game prints the same `$` prefix on the egg dome (`$150` on the 1-1 recording).
		_price.text = "$%d" % price
	_price.add_theme_color_override("font_color", PRICE_COLOR)
	_show_frame(pieces)


## The cell for this piece count: the sheet runs from the bare shell (0) to the whole egg (2).
func _show_frame(pieces: int) -> void:
	if _art == null or _frames == null:
		return
	var last := _frames.get_frame_count("default") - 1
	var texture := _masked(clampi(pieces - 1, 0, last))
	if texture != null:
		_art.texture = texture


## One cell composed with the sheet's alpha companion (`masks/_EggPieces.png`). The shipped cell is
## opaque, so its purple dome window used to land as a square patch across the bar's gold rim (owner
## review 2026-11-16); through the mask the window is the dome shape the art itself draws.
func _masked(index: int) -> Texture2D:
	if _cells.has(index):
		return _cells[index]
	if _frames == null:
		return null
	var texture := _frames.get_frame_texture("default", index)
	if texture == null:
		return null
	var content := _autoload("Content")
	var res: ImageRes = content.image(EGG_ART) if content != null else null
	var mask := HatchScreen.mask_for(res.path) if res != null else null
	var composed := HatchScreen.masked_cell(texture, mask) if mask != null else null
	var base := (composed if composed != null else texture).get_image()
	if base == null:
		return null
	var cell := ImageTexture.create_from_image(_without_baked_dome(base))
	_cells[index] = cell
	return cell


## `EGGPIECES` bakes the dome's own violet window behind the cup (sampled #532B8B, shaded #7D43A2 and
## a lighter lilac), so drawn over the bar's badge it showed a second, pointed egg shape inside the
## dome - the owner's "the egg looks off". Keying that violet out leaves the cup, the basket and the
## whole egg alone on the shared badge, which is what the base game's egg dome shows (D-0026). The
## cup, the basket and the egg are cream and brown; the test is "purple by a clear margin", which
## also keeps the art's own violet outline that separates it from the badge.
static func _without_baked_dome(image: Image) -> Image:
	var out := image.duplicate() as Image
	out.convert(Image.FORMAT_RGBA8)
	for y in out.get_height():
		for x in out.get_width():
			var colour := out.get_pixel(x, y)
			if colour.a > 0.04 and colour.b > 0.35 \
				and colour.b > colour.r + 0.05 and colour.r > colour.g + 0.03:
				out.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	return out





func _signature() -> String:
	return "%d:%d:%d:%d:%s" % [
		int(level.tank_index), int(level.money), int(level.egg_pieces),
		int(level.egg_price), str(level.completed)
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
