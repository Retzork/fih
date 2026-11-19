class_name SpriteKey
extends RefCounted
## Colour-keying for the extracted art.
##
## The original blits its sprite sheets with a colour key, and the extraction kept that background
## opaque (Guppy's `SIMSWIM` sheet is 98% `#000000`). Drawing it as-is paints boxes, so every frame is
## keyed once here: background pixels **connected to the frame border** become transparent. Only the
## border-connected region is cleared, so a dark outline inside the art survives.
##
## Black is the usual key, but not the only one: `MONEY` row 3 (the 200-value diamond) sits on a navy
## `#00007B` background in the shipped sheet, which a black-only key left drawn as a solid blue box.
## So the key is the cell's own border colour when at least three of its four corners agree on one
## non-black value; black stays keyed regardless.

## Channel value at or below this counts as the key colour (the sheets are exact black, the margin
## covers resampling).
const KEY_EPSILON := 0.012
## How far a background pixel may sit from a corner colour and still count as the key. The sheets'
## backgrounds are not perfectly flat (`MONEY` row 3 runs 0.48..0.52 blue across one 72 px cell), so
## this is looser than the black test above; real art sits much further away than 0.08 per channel.
const KEY_TOLERANCE := 0.08

static var _cache := {}


## A keyed copy of `texture`, cached per source cell.
static func keyed(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var cache_key := _cache_key(texture)
	if _cache.has(cache_key):
		return _cache[cache_key]
	var image := texture.get_image()
	if image == null:
		return texture
	image = image.duplicate()
	image.convert(Image.FORMAT_RGBA8)
	_clear_border(image, _border_keys(image))
	var keyed_texture := ImageTexture.create_from_image(image)
	_cache[cache_key] = keyed_texture
	return keyed_texture


## A sheet cell's cache identity. An `AtlasTexture` answers `get_rid()` with its **atlas's** RID, so
## keying on the RID alone collapsed every cell of a sheet onto the first keyed frame - the sprites
## were drawn frozen on cell 0. The region is part of the identity for atlas cells.
static func _cache_key(texture: Texture2D) -> String:
	if texture is AtlasTexture:
		var atlas := (texture as AtlasTexture).atlas
		var region := (texture as AtlasTexture).region
		if atlas != null:
			return "%s|%d,%d,%d,%d" % [atlas.get_rid(), region.position.x, region.position.y, region.size.x, region.size.y]
	return str(texture.get_rid())


static func _is_black(colour: Color) -> bool:
	return colour.r <= KEY_EPSILON and colour.g <= KEY_EPSILON and colour.b <= KEY_EPSILON


static func _near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) <= KEY_TOLERANCE and absf(a.g - b.g) <= KEY_TOLERANCE \
		and absf(a.b - b.b) <= KEY_TOLERANCE


## The colours a cell's border flood fill may clear: black, plus the corner colour when three of the
## four corners carry it (a sheet whose background is not black, like `MONEY` row 3's navy).
static func _border_keys(image: Image) -> Array[Color]:
	var keys: Array[Color] = [Color.BLACK]
	var corners: Array[Color] = [
		image.get_pixel(0, 0),
		image.get_pixel(image.get_width() - 1, 0),
		image.get_pixel(0, image.get_height() - 1),
		image.get_pixel(image.get_width() - 1, image.get_height() - 1),
	]
	for corner: Color in corners:
		if _is_black(corner):
			continue
		var agreeing := 0
		for other: Color in corners:
			if _near(corner, other):
				agreeing += 1
		if agreeing >= 3:
			keys.append(corner)
			break
	return keys


static func _is_key(colour: Color, keys: Array[Color]) -> bool:
	for key: Color in keys:
		if _near(colour, key):
			return true
	return false


static func _clear_border(image: Image, keys: Array[Color]) -> void:
	var width := image.get_width()
	var height := image.get_height()
	if width == 0 or height == 0:
		return
	var seen := PackedByteArray()
	seen.resize(width * height)
	var queue: Array[Vector2i] = []
	for x in width:
		queue.append(Vector2i(x, 0))
		queue.append(Vector2i(x, height - 1))
	for y in height:
		queue.append(Vector2i(0, y))
		queue.append(Vector2i(width - 1, y))
	while not queue.is_empty():
		var point: Vector2i = queue.pop_back()
		if point.x < 0 or point.y < 0 or point.x >= width or point.y >= height:
			continue
		var index := point.y * width + point.x
		if seen[index] == 1:
			continue
		seen[index] = 1
		if not _is_key(image.get_pixel(point.x, point.y), keys):
			continue
		image.set_pixel(point.x, point.y, Color(0.0, 0.0, 0.0, 0.0))
		queue.append(Vector2i(point.x + 1, point.y))
		queue.append(Vector2i(point.x - 1, point.y))
		queue.append(Vector2i(point.x, point.y + 1))
		queue.append(Vector2i(point.x, point.y - 1))
