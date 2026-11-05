class_name SpriteKey
extends RefCounted
## Colour-keying for the extracted art.
##
## The original blits its sprite sheets with a black colour key, and the extraction kept that black
## background opaque (Guppy's `SIMSWIM` sheet is 98% `#000000`). Drawing it as-is paints black boxes,
## so every frame is keyed once here: black pixels **connected to the frame border** become
## transparent. Only the border-connected region is cleared, so a dark outline inside the art survives.

## Channel value at or below this counts as the key colour (the sheets are exact black, the margin
## covers resampling).
const KEY_EPSILON := 0.012

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
	_clear_border_black(image)
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


static func _is_key(colour: Color) -> bool:
	return colour.r <= KEY_EPSILON and colour.g <= KEY_EPSILON and colour.b <= KEY_EPSILON


static func _clear_border_black(image: Image) -> void:
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
		if not _is_key(image.get_pixel(point.x, point.y)):
			continue
		image.set_pixel(point.x, point.y, Color(0.0, 0.0, 0.0, 0.0))
		queue.append(Vector2i(point.x + 1, point.y))
		queue.append(Vector2i(point.x - 1, point.y))
		queue.append(Vector2i(point.x, point.y + 1))
		queue.append(Vector2i(point.x, point.y - 1))
