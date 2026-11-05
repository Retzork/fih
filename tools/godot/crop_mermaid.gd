extends SceneTree
## Crop and enlarge the menu mermaid so her tail area can be inspected at pixel level.
##
##   & "<godot>" --headless --path . --script res://tools/godot/crop_mermaid.gd


func _init() -> void:
	var back := Image.new()
	if back.load("res://assets_raw/images/selectorback.png") != OK:
		printerr("no selectorback")
		quit(1)
		return
	back.convert(Image.FORMAT_RGBA8)
	var crop := back.get_region(Rect2i(90, 260, 250, 220))
	crop.resize(750, 660, Image.INTERPOLATE_NEAREST)
	crop.save_png("res://assets_raw/images/_mermaid_crop.png")
	print("saved crop")
	quit(0)
