class_name EggWidget
extends Control
## The tank's egg-piece widget (P2.6 §3/§5). `buy_egg()` is the purchase API; this is the clickable
## object that makes it reachable on tanks 1-4. Tank 5 sells the egg as a free store row instead, so
## the widget hides there.
##
## The original widget's rect was not recovered (Q-0053), so its placement here is presentation-only:
## the recovered `EggPieces` art sits at the tank's bottom-right with the current piece count and
## price. The click path itself is the recovered one: spend `egg_price`, add a piece, and complete the
## level on the fourth.

const RECT := Rect2(500.0, 416.0, 128.0, 52.0)
const EGG_ART := "IMAGE_EGGPIECES"
const PIECES_TO_COMPLETE := 4
const GREY := Color8(0xCC, 0xCC, 0xCC)
const PRICE_COLOR := Color8(0xF2, 0xE8, 0xC8)

var level = null

var _button: Button = null
var _name: Label = null
var _price: Label = null
var _art: TextureRect = null
var _last_signature := ""


func _autoload(node_name: String) -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/" + node_name)


func setup(source) -> void:
	level = source
	position = RECT.position
	size = RECT.size
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 200

	var panel := Panel.new()
	panel.name = "Panel"
	panel.position = Vector2.ZERO
	panel.size = RECT.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	style.border_color = Color8(0xF2, 0xE8, 0xC8, 0xAA)
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	_button = Button.new()
	_button.name = "Buy"
	_button.position = Vector2.ZERO
	_button.size = RECT.size
	_button.flat = true
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(_on_pressed)
	add_child(_button)

	_name = Label.new()
	_name.name = "Pieces"
	_name.position = Vector2(54.0, 4.0)
	_name.size = Vector2(70.0, 20.0)
	_name.add_theme_font_size_override("font_size", 12)
	_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_name.add_theme_constant_override("outline_size", 3)
	_button.add_child(_name)

	_price = Label.new()
	_price.name = "Price"
	_price.position = Vector2(54.0, 26.0)
	_price.size = Vector2(70.0, 20.0)
	_price.add_theme_font_size_override("font_size", 13)
	_price.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_price.add_theme_constant_override("outline_size", 3)
	_button.add_child(_price)

	refresh()


func _ready() -> void:
	var content := _autoload("Content")
	if content == null:
		return
	var frames: SpriteFrames = content.sprite_frames(EGG_ART)
	if frames == null or frames.get_frame_count("default") == 0:
		return
	var texture := frames.get_frame_texture("default", 0)
	if texture == null:
		return
	_art = TextureRect.new()
	_art.name = "Egg"
	_art.texture = texture
	_art.position = Vector2(4.0, 7.0)
	_art.size = Vector2(float(texture.get_width()), float(texture.get_height()))
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	move_child(_art, 0)


## Redraw only when the purse, the piece count, the price or completion changed.
func refresh_if_changed() -> void:
	if level == null:
		return
	var signature := "%d:%d:%d:%s" % [
		int(level.money), int(level.egg_pieces), int(level.egg_price), str(level.completed)
	]
	if signature == _last_signature:
		return
	refresh()


func refresh() -> void:
	if level == null or _button == null:
		return
	# Tank 5 sells the egg as a free store row (P2.6 §3); the widget is for the other four tanks.
	visible = int(level.tank_index) != 5
	if not visible:
		return
	_last_signature = "%d:%d:%d:%s" % [
		int(level.money), int(level.egg_pieces), int(level.egg_price), str(level.completed)
	]
	var price := int(level.egg_price)
	var known := price != Progression.PRICE_UNKNOWN
	var affordable := known and (price <= 0 or int(level.money) >= price)
	_button.disabled = bool(level.completed) or not known or not affordable
	_name.text = "EGG %d/%d" % [mini(int(level.egg_pieces), PIECES_TO_COMPLETE), PIECES_TO_COMPLETE]
	if not known:
		_price.text = "?"
	elif price <= 0:
		_price.text = "FREE"
	else:
		_price.text = str(price)
	var colour := PRICE_COLOR if affordable and not level.completed else GREY
	_name.add_theme_color_override("font_color", colour if not level.completed else GREY)
	_price.add_theme_color_override("font_color", colour)


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
