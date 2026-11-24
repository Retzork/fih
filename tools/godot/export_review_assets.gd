# export_review_assets.gd - review aid: writes every manifest image to docs/review/assets as the
# game would draw it. Masked sheets take their masks/_<file> alpha companion (MaskAlpha); the rest go
# through the same border colour key the tank uses (SpriteKey). Run headless from the project root:
#   & "<godot>" --headless --path . --script res://tools/godot/export_review_assets.gd
extends SceneTree

const MaskAlphaScript := preload("res://scripts/data/mask_alpha.gd")
const SpriteKeyScript := preload("res://scripts/tank/sprite_key.gd")
const CONTENT := "res://resources/content.json"
const OUT := "res://docs/review/assets"


func _init() -> void:
	var f := FileAccess.open(CONTENT, FileAccess.READ)
	if f == null:
		push_error("cannot open " + CONTENT)
		quit(1)
		return
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	var out_abs := ProjectSettings.globalize_path(OUT)
	DirAccess.make_dir_recursive_absolute(out_abs)
	var made := 0
	var masked := 0
	var failed := 0
	for entry: Dictionary in data["images"]:
		var path := String(entry["path"])
		var tex := load(path) as Texture2D
		if tex == null:
			push_error("missing texture: " + path)
			failed += 1
			continue
		var image := tex.get_image()
		if image == null:
			failed += 1
			continue
		image = image.duplicate() as Image
		image.convert(Image.FORMAT_RGBA8)
		var sheet_mask := MaskAlphaScript.mask_for(path)
		if sheet_mask != null:
			var composed := MaskAlphaScript.apply(image, sheet_mask)
			if composed != null:
				image = composed
				masked += 1
		else:
			var keyed := SpriteKeyScript.keyed(tex)
			if keyed != null and keyed.get_image() != null:
				image = keyed.get_image().duplicate() as Image
		var name := String(entry["name"])
		if image.save_png(out_abs.path_join(name + ".png")) == OK:
			made += 1
		else:
			failed += 1
	print("review assets: made=%d masked=%d failed=%d" % [made, masked, failed])
	quit(0 if failed == 0 else 1)
