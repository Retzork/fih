extends SceneTree
## Diagnostic: dump the PETBUTTON cell geometry/palette and the PETBUTTONRING outline so the
## button composition can be described from pixels rather than guessed.
##   Godot --headless --path . --script res://tools/godot/probe_petbutton.gd

const SHEET := "res://assets_raw/images/petbutton.png"
const RING := "res://assets_raw/images/petbuttonring.png"
const RING_MASK := "res://assets_raw/masks/petbuttonring_.png"


func _initialize() -> void:
	var sheet := Image.load_from_file(SHEET)
	print("SHEET ", sheet.get_size())
	var cell := sheet.get_width() / 4
	for i in 4:
		var region := sheet.get_region(Rect2i(i * cell, 0, cell, sheet.get_height()))
		_probe("cell%d" % i, region)
		region.resize(region.get_width() * 3, region.get_height() * 3, Image.INTERPOLATE_NEAREST)
		region.save_png("res://docs/captures/probe_petbutton_cell%d.png" % i)
	var ring := Image.load_from_file(RING)
	_probe("ring", ring)
	var mask := Image.load_from_file(RING_MASK)
	_probe("ring_mask", mask)
	print("RING pixels where mask is opaque and ring is brighter than 0.55: ", _ring_pixels(ring, mask))
	var big := ring.duplicate() as Image
	big.resize(big.get_width() * 4, big.get_height() * 4, Image.INTERPOLATE_NEAREST)
	big.save_png("res://docs/captures/probe_petbutton_ring.png")
	quit(0)


func _probe(label: String, image: Image) -> void:
	print(label, " size=", image.get_size(), " format=", image.get_format())
	var counts := {}
	for y in image.get_height():
		for x in image.get_width():
			var c := image.get_pixel(x, y)
			var key := "%d,%d,%d" % [int(c.r * 255.0), int(c.g * 255.0), int(c.b * 255.0)]
			counts[key] = int(counts.get(key, 0)) + 1
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return int(counts[a]) > int(counts[b]))
	for i in mini(6, keys.size()):
		print("  %-12s %6d px" % [keys[i], counts[keys[i]]])
	print("  corner=", image.get_pixel(0, 0), " centre=", image.get_pixel(
		image.get_width() / 2, image.get_height() / 2))


## True outline extents: opaque-mask pixels that are not the flat brown field.
func _ring_pixels(ring: Image, mask: Image) -> Array:
	var min_x := 999
	var max_x := -1
	var min_y := 999
	var max_y := -1
	var lit := 0
	for y in ring.get_height():
		for x in ring.get_width():
			if mask.get_pixel(x, y).r < 0.5:
				continue
			var c := ring.get_pixel(x, y)
			if c.get_luminance() > 0.55:
				lit += 1
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	print("RING lit bbox ", min_x, ",", min_y, " .. ", max_x, ",", max_y)
	return [lit]
