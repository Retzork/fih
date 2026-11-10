extends SceneTree
## Measure the baked menu mermaid's green tail and the MERYLTAIL fluke cells so the overlay can be
## placed by geometry instead of by eye.
##
##   & "<godot>" --headless --path . --script res://tools/godot/measure_mermaid.gd

const MaskAlphaScript := preload("res://scripts/data/mask_alpha.gd")


func _init() -> void:
	var back := Image.new()
	if back.load("res://assets_raw/images/selectorback.png") != OK:
		printerr("no selectorback")
		quit(1)
		return
	back.convert(Image.FORMAT_RGBA8)
	var minx := 9999
	var miny := 9999
	var maxx := -1
	var maxy := -1
	for y in range(230, 470):
		for x in range(60, 400):
			var c := back.get_pixel(x, y)
			if c.g > c.r + 0.15 and c.g > c.b + 0.15 and c.g > 0.35:
				minx = min(minx, x)
				miny = min(miny, y)
				maxx = max(maxx, x)
				maxy = max(maxy, y)
	print("BAKED green bbox ", minx, ",", miny, " .. ", maxx, ",", maxy)
	# Per-row extremes, 10 px steps, to see the tail's shape and its blunt end.
	for y in range(300, 460, 10):
		var rmin := 9999
		var rmax := -1
		for x in range(60, 400):
			var c := back.get_pixel(x, y)
			if c.g > c.r + 0.15 and c.g > c.b + 0.15 and c.g > 0.35:
				rmin = min(rmin, x)
				rmax = max(rmax, x)
		if rmax >= 0:
			print("ROW y=%d x %d..%d" % [y, rmin, rmax])

	var base := Image.new()
	var mask := Image.new()
	if base.load("res://assets_raw/images/tailflop.png") != OK or mask.load("res://assets_raw/masks/tailflop_.png") != OK:
		printerr("no tailflop")
		quit(1)
		return
	var sheet := MaskAlphaScript.apply(base, mask)
	for cell in 3:
		var cminx := 9999
		var cminy := 9999
		var cmaxx := -1
		var cmaxy := -1
		for y in 165:
			for x in range(cell * 238, cell * 238 + 238):
				if sheet.get_pixel(x, y).a > 0.2:
					cminx = min(cminx, x - cell * 238)
					cminy = min(cminy, y)
					cmaxx = max(cmaxx, x - cell * 238)
					cmaxy = max(cmaxy, y)
		print("CELL ", cell, " bbox ", cminx, ",", cminy, " .. ", cmaxx, ",", cmaxy)
		for y in range(cminy, cmaxy + 1, 10):
			var rmin := 9999
			var rmax := -1
			for x in range(cell * 238, cell * 238 + 238):
				if sheet.get_pixel(x, y).a > 0.2:
					rmin = min(rmin, x - cell * 238)
					rmax = max(rmax, x - cell * 238)
			print("  c%d row y=%d x %d..%d" % [cell, y, rmin, rmax])
	quit(0)
