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
