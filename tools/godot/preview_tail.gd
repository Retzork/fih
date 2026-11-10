extends SceneTree
## Composite the masked MERYLTAIL rest cell onto the baked menu at scaled placements, so the fin can
## be judged against the tail's measured stump instead of by eye.
##
##   & "<godot>" --headless --path . --script res://tools/godot/preview_tail.gd

const MaskAlphaScript := preload("res://scripts/data/mask_alpha.gd")

## at = top-left of the scaled cell, scale = fin size relative to the 238x165 cell.
const CANDIDATES := [
	{"at": Vector2i(88, 355), "scale": 0.6, "flip_h": false},
	{"at": Vector2i(110, 360), "scale": 0.6, "flip_h": false},
	{"at": Vector2i(98, 363), "scale": 0.5, "flip_h": false},
	{"at": Vector2i(80, 350), "scale": 0.7, "flip_h": false},
]


func _init() -> void:
	var back := Image.new()
	var base := Image.new()
	var mask := Image.new()
	if back.load("res://assets_raw/images/selectorback.png") != OK:
		quit(1)
		return
	back.convert(Image.FORMAT_RGBA8)
	if base.load("res://assets_raw/images/tailflop.png") != OK or mask.load("res://assets_raw/masks/tailflop_.png") != OK:
		quit(1)
		return
	var sheet := MaskAlphaScript.apply(base, mask)
	var cell := sheet.get_region(Rect2i(0, 0, 238, 165))
	var out := Image.create(4 * 340 * 2, 230 * 2, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.1, 0.1, 0.1))
	for index in CANDIDATES.size():
		var cand: Dictionary = CANDIDATES[index]
		var scaled := cell.duplicate() as Image
		var scale := float(cand["scale"])
		scaled.resize(int(238 * scale), int(165 * scale), Image.INTERPOLATE_BILINEAR)
		var frame := back.duplicate() as Image
		_blit(frame, scaled, Vector2i(cand["at"]), bool(cand["flip_h"]))
		var crop := frame.get_region(Rect2i(60, 250, 340, 230))
		crop.resize(680, 460, Image.INTERPOLATE_NEAREST)
		out.blit_rect(crop, Rect2i(0, 0, 680, 460), Vector2i(index * 680, 0))
	out.save_png("res://shot_tail_candidates.png")
	print("saved candidates")
	quit(0)


func _blit(dst: Image, src: Image, at: Vector2i, flip_h: bool) -> void:
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c.a <= 0.01:
				continue
			var sx := (src.get_width() - 1 - x) if flip_h else x
			var px := at.x + sx
			var py := at.y + y
			if px < 0 or py < 0 or px >= dst.get_width() or py >= dst.get_height():
				continue
			dst.set_pixel(px, py, c)
