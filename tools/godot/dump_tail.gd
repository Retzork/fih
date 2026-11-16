extends SceneTree
## Temporary inspection aid: dump the masked mermaid tail cells and the baked tail crop.

const MaskAlphaScript := preload("res://scripts/data/mask_alpha.gd")


func _init() -> void:
	var out_dir := "res://.tmp_tail"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var base := Image.new()
	if base.load("res://assets_raw/images/tailflop.png") != OK:
		printerr("no base")
		quit(1)
		return
	var mask := Image.new()
	if mask.load("res://assets_raw/masks/tailflop_.png") != OK:
		printerr("no mask")
		quit(1)
		return
	var sheet := MaskAlphaScript.apply(base, mask)
	sheet.save_png(out_dir + "/tail_masked.png")
	for cell in 8:
		var region := sheet.get_region(Rect2i(cell * 238, 0, 238, 165))
		region.save_png(out_dir + "/tail_cell_%d.png" % cell)
		region.resize(476, 330, Image.INTERPOLATE_NEAREST)
		region.save_png(out_dir + "/tail_cell_%d_2x.png" % cell)
	var back := Image.new()
	if back.load("res://assets_raw/images/selectorback.png") == OK:
		var crop := back.get_region(Rect2i(60, 200, 300, 280))
		crop.save_png(out_dir + "/baked_mermaid.png")
		crop.resize(900, 840, Image.INTERPOLATE_NEAREST)
		crop.save_png(out_dir + "/baked_mermaid_3x.png")
	print("dumped to ", out_dir)
	quit(0)
