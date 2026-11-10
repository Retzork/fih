extends SceneTree
## Composite the masked MERYLTAIL rest cell onto the baked menu at candidate placements, so the
## fluke's attachment can be judged against the tail's measured tip instead of by eye.
##
##   & "<godot>" --headless --path . --script res://tools/godot/preview_tail.gd

const MaskAlphaScript := preload("res://scripts/data/mask_alpha.gd")

const CANDIDATES := [
	{"at": Vector2i(150, 270), "flip_h": false, "flip_v": false},
	{"at": Vector2i(150, 270), "flip_h": true, "flip_v": false},
	{"at": Vector2i(150, 300), "flip_h": false, "flip_v": true},
	{"at": Vector2i(120, 300), "flip_h": true, "flip_v": true},
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
		var frame := back.duplicate() as Image
		_blit(frame, cell, Vector2i(cand["at"]), bool(cand["flip_h"]), bool(cand["flip_v"]))
		var crop := frame.get_region(Rect2i(60, 250, 340, 230))
		crop.resize(680, 460, Image.INTERPOLATE_NEAREST)
		out.blit_rect(crop, Rect2i(0, 0, 680, 460), Vector2i(index * 680, 0))
	out.save_png("res://shot_tail_candidates.png")
	print("saved candidates")
	quit(0)


func _blit(dst: Image, src: Image, at: Vector2i, flip_h: bool, flip_v: bool) -> void:
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c.a <= 0.01:
				continue
			var sx := (src.get_width() - 1 - x) if flip_h else x
			var sy := (src.get_height() - 1 - y) if flip_v else y
			var px := at.x + sx
			var py := at.y + sy
			if px < 0 or py < 0 or px >= dst.get_width() or py >= dst.get_height():
				continue
			dst.set_pixel(px, py, c)
