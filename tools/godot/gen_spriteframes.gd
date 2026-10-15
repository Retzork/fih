# gen_spriteframes.gd - P3.5 Godot import step: SpriteFrames per multi-cell image.
# Run (from project root):
#   & "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --import
#   & "C:\Users\Fauzi\Desktop\Godot_v4.7.1-stable_win64.exe" --headless --path . --script res://tools/godot/gen_spriteframes.gd
# Input:  res://assets_raw/extraction.json (P3.3 manifest)
# Output: res://resources/sprites/<ID>.tres (SpriteFrames, animation "default")
# Frames are AtlasTexture regions into the sheet PNG; framemap order is applied when the
# manifest declares one (negative entries skipped, meaning unresolved - see EV-0027).
# Delays/speeds are NOT baked (tick semantics unknown until P2.1); raw attrs stay in
# extraction.json. Exits non-zero if any resource fails to generate or verify.

extends SceneTree

const EXTRACTION_PATH := "res://assets_raw/extraction.json"
const OUT_DIR := "res://resources/sprites"


func _init() -> void:
	var f := FileAccess.open(EXTRACTION_PATH, FileAccess.READ)
	if f == null:
		push_error("cannot open " + EXTRACTION_PATH)
		quit(1)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("invalid JSON in " + EXTRACTION_PATH)
		quit(1)
		return
	var data: Dictionary = parsed

	var out_abs := ProjectSettings.globalize_path(OUT_DIR)
	DirAccess.make_dir_recursive_absolute(out_abs)

	var generated := 0
	var failures := 0
	var total_frames := 0
	var expected := {}

	for raw in data["images"]:
		var img: Dictionary = raw
		var frames_meta: Array = img["frames"]
		if frames_meta.is_empty():
			continue
		var id := String(img["id"])
		var cols := int(img["cols"])
		var rows := int(img["rows"])
		var cell_w := int(img["cellW"])
		var cell_h := int(img["cellH"])
		var count := cols * rows
		var png_path := "res://assets_raw/" + String(img["png"]).replace("\\", "/")
		var tex := load(png_path) as Texture2D
		if tex == null:
			push_error("missing texture: " + png_path + " (id " + id + ")")
			failures += 1
			continue

		var order: Array = []
		var attrs: Dictionary = img["attrs"]
		if attrs.has("framemap"):
			for part in String(attrs["framemap"]).split(","):
				var n := int(part)
				if n >= 0 and n < count:
					order.append(n)
		if order.is_empty():
			for i in count:
				order.append(i)

		var sf := SpriteFrames.new()
		while sf.get_frame_count("default") > 0:
			sf.remove_frame("default", 0)
		for idx: int in order:
			var col := idx % cols
			var row := idx / cols
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(col * cell_w, row * cell_h, cell_w, cell_h)
			at.filter_clip = true
			sf.add_frame("default", at)

		var out_path := OUT_DIR + "/" + id + ".tres"
		var err := ResourceSaver.save(sf, out_path)
		if err != OK:
			push_error("save failed (%d): %s" % [err, out_path])
			failures += 1
			continue
		expected[out_path] = order.size()
		generated += 1
		total_frames += order.size()

	var verified := 0
	for path: String in expected:
		var res := load(path) as SpriteFrames
		if res == null:
			push_error("verify failed to load: " + path)
			failures += 1
			continue
		if res.get_frame_count("default") != int(expected[path]):
			push_error("verify frame count mismatch: " + path)
			failures += 1
			continue
		verified += 1

	print("spriteframes generated=%d verified=%d failures=%d total_frames=%d" % [generated, verified, failures, total_frames])
	quit(1 if failures > 0 else 0)
