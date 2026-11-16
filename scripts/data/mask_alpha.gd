class_name MaskAlpha
extends RefCounted
## P3.3's alpha model: 243 of the 246 base GIFs have **no** transparent pixels; a grayscale companion
## file under `assets_raw/masks/` supplies the alpha (white = opaque, black = clear). The port keeps
## base and mask as separate layers, so any sprite drawn straight from a masked sheet is a solid
## rectangle - `tailflop.png` (the menu mermaid's tail) is the first one this mattered for, since its
## background is an opaque green field instead of the usual black.
##
## `apply()` returns a new RGBA image: the base's colours with the mask's luminance as alpha. It never
## mutates its inputs and returns null when the two images do not line up.


## Compose a texture with its `masks/_<file>` companion (P3.3). The base sheets are opaque, so a
## caller that draws one directly gets a solid rectangle; anything that wants the game's cut-out
## look must pass the texture through here. Returns the input unchanged when it has no mask or the
## mask does not line up.
static func compose(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var image := texture.get_image()
	if image == null:
		return texture
	var mask := mask_for(texture.resource_path)
	if mask == null:
		return texture
	var composed := apply(image, mask)
	if composed == null:
		return texture
	return ImageTexture.create_from_image(composed)


## The alpha companion for an `assets_raw` sheet: `masks/_<file>` for most, `<stem>_` for a few.
static func mask_for(image_path: String) -> Image:
	if image_path == "":
		return null
	var file := image_path.get_file()
	var stem := file.trim_suffix(".png")
	for path in ["res://assets_raw/masks/_%s" % file, "res://assets_raw/masks/%s_.png" % stem]:
		if not ResourceLoader.exists(path):
			continue
		var texture := load(path) as Texture2D
		if texture != null:
			return texture.get_image()
	return null


static func apply(base: Image, mask: Image) -> Image:
	if base == null or mask == null:
		return null
	if base.get_width() != mask.get_width() or base.get_height() != mask.get_height():
		return null
	var out := base.duplicate() as Image
	out.convert(Image.FORMAT_RGBA8)
	var grey := mask.duplicate() as Image
	grey.convert(Image.FORMAT_RGBA8)
	for y in out.get_height():
		for x in out.get_width():
			var colour := out.get_pixel(x, y)
			var coverage := grey.get_pixel(x, y)
			colour.a = (coverage.r + coverage.g + coverage.b) / 3.0
			out.set_pixel(x, y, colour)
	return out
