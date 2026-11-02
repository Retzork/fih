# gen_content.gd - P4.2 build step: emit the runtime content manifest.
# Run (from project root):
#   & "<godot>" --headless --path . --script res://tools/godot/gen_content.gd
# Input:  res://assets_raw/extraction.json (P3.3 images), audio.json (P3.6 sounds),
#         fonts.json (P3.7 fonts)
# Output: res://resources/content.json - committed, one entry per manifest id, in the original's
#         three load groups. The game never parses resources.xml at runtime (SPECS.md §2, P2.15 §8).
#
# The output is byte-stable for unchanged inputs: the only timestamp is the extraction's own, so a
# regeneration diff means the assets changed. Fails (exit 1) on any missing asset file or on a
# group partition that does not match the contract (Init 14 / Register 16 / LoadingThread 296).

extends SceneTree

const EXTRACTION := "res://assets_raw/extraction.json"
const AUDIO := "res://assets_raw/audio.json"
const FONTS := "res://assets_raw/fonts.json"
const OUT := "res://resources/content.json"
const SPRITES_DIR := "res://resources/sprites"
const ASSETS_DIR := "res://assets_raw/"

## The shipped manifest's group partition (P2.15/EV-0151..EV-0154). A change here is a contract
## change, not a regeneration detail, so it fails the build instead of drifting silently.
const EXPECTED_GROUPS := {"Init": 14, "Register": 16, "LoadingThread": 296}
const EXPECTED_TOTAL := 326

var _failures := 0


func _init() -> void:
	var extraction: Variant = _read_json(EXTRACTION)
	var audio: Variant = _read_json(AUDIO)
	var fonts: Variant = _read_json(FONTS)
	if extraction == null or audio == null or fonts == null:
		quit(1)
		return

	var images: Array = []
	for raw: Variant in extraction["images"]:
		images.append(_image_entry(raw))

	var sounds: Array = []
	for raw: Variant in audio["sounds"]:
		sounds.append(_sound_entry(raw))

	var font_list: Array = []
	for raw: Variant in fonts["fonts"]:
		font_list.append(_font_entry(raw))

	var counts := {}
	for entry: Dictionary in images + sounds + font_list:
		var group := String(entry["group"])
		counts[group] = int(counts.get(group, 0)) + 1

	var manifest := {
		"generated": String(extraction.get("generated", "")),
		"source": "docs/analysis/resources.json -> assets_raw/{extraction,audio,fonts}.json",
		"ids": {
			"image": "IMAGE_", "sound": "SOUND_", "font": "FONT_",
		},
		"groups": ["Init", "Register", "LoadingThread"],
		"counts": counts,
		"images": images,
		"sounds": sounds,
		"fonts": font_list,
	}

	_check_partition(counts)
	_check_files(images + sounds + font_list)

	if _failures > 0:
		printerr("gen_content: %d failure(s), %s not written" % [_failures, OUT])
		quit(1)
		return

	var text := JSON.stringify(manifest, "  ", false) + "\n"
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	if f == null:
		printerr("gen_content: cannot write " + OUT)
		quit(1)
		return
	f.store_string(text)
	f.close()

	print("gen_content: %d images, %d sounds, %d fonts -> %s" % [
		images.size(), sounds.size(), font_list.size(), OUT])
	print("gen_content: groups %s" % [counts])
	quit(0)


# --- entries ---------------------------------------------------------------

func _image_entry(raw: Variant) -> Dictionary:
	var img: Dictionary = raw
	var attrs: Dictionary = img.get("attrs", {})
	var bare := String(img["id"])
	var cols := int(img.get("cols", 1))
	var rows := int(img.get("rows", 1))
	var count := maxi(cols * rows, 1)
	var order := _frame_order(attrs, count)
	var sf_path := "%s/%s.tres" % [SPRITES_DIR, bare]

	var entry := {
		"id": "IMAGE_" + bare,
		"name": bare,
		"group": String(img["group"]),
		"path": ASSETS_DIR + String(img["png"]).replace("\\", "/"),
		"spriteFrames": sf_path if FileAccess.file_exists(sf_path) else "",
		"cols": cols,
		"rows": rows,
		"cellW": int(img.get("cellW", 0)),
		"cellH": int(img.get("cellH", 0)),
		"frameCount": count,
		"playCount": order.size(),
		"anim": String(attrs.get("anim", "")),
		"frameDelay": int(attrs.get("framedelay", "0")),
		"beginDelay": int(attrs.get("begindelay", "0")),
		"endDelay": int(attrs.get("enddelay", "0")),
	}
	if attrs.has("framemap"):
		entry["frameMap"] = order
	if attrs.has("perframedelay"):
		entry["perFrameDelay"] = _per_frame_delays(attrs, order)
	return entry


func _sound_entry(raw: Variant) -> Dictionary:
	var snd: Dictionary = raw
	var attrs: Dictionary = snd.get("attrs", {})
	var bare := String(snd["id"])
	var entry := {
		"id": "SOUND_" + bare,
		"name": bare,
		"group": String(snd["group"]),
		"path": ASSETS_DIR + String(snd["output"]).replace("\\", "/"),
		"volume": float(String(attrs.get("volume", "1.0"))),
	}
	# `alias` declares a second id for the same stream (PIPELINE.md §4: resolve through the
	# manifest, never by filename).
	if attrs.has("alias"):
		entry["alias"] = "SOUND_" + String(attrs["alias"])
	return entry


func _font_entry(raw: Variant) -> Dictionary:
	var font: Dictionary = raw
	var bare := String(font["id"])
	var metrics: Dictionary = font.get("metrics", {})
	return {
		"id": "FONT_" + bare,
		"name": bare,
		"group": String(font["group"]),
		"path": ASSETS_DIR + "fonts/" + bare + ".fnt",
		"size": int(metrics.get("pointSize", 0)),
		"lineHeight": int(metrics.get("lineHeight", 0)),
	}


# --- manifest semantics -----------------------------------------------------

## Playback order: `framemap` when present (row-major cell indices), else every cell. Negative
## entries are the manifest's "unresolved" placeholder and are dropped (EV-0027).
func _frame_order(attrs: Dictionary, count: int) -> Array:
	var order: Array = []
	if attrs.has("framemap"):
		for part: String in String(attrs["framemap"]).split(","):
			var n := int(part)
			if n >= 0 and n < count:
				order.append(n)
	else:
		for i in count:
			order.append(i)
	return order


## `perframedelay` is indexed by position in the *mapped* sequence and falls back to `framedelay`
## when short (P2.15 §8.5). Because dropped `-1` entries shift positions, a negative entry that is
## followed by a kept one would misalign the table - refuse that instead of shipping wrong timing.
func _per_frame_delays(attrs: Dictionary, order: Array) -> Array:
	var raw: Array = []
	for part: String in String(attrs["perframedelay"]).split(","):
		raw.append(int(part))
	if raw.size() > order.size():
		var mapped := String(attrs.get("framemap", ""))
		if mapped.contains("-1"):
			push_warning("perframedelay longer than the mapped sequence (%d > %d)" % [raw.size(), order.size()])
	return raw.slice(0, order.size())


# --- verification ----------------------------------------------------------

func _check_partition(counts: Dictionary) -> void:
	var total := 0
	for group: String in EXPECTED_GROUPS:
		total += int(counts.get(group, 0))
		if int(counts.get(group, 0)) != int(EXPECTED_GROUPS[group]):
			printerr("gen_content: group %s has %d ids, expected %d" % [
				group, int(counts.get(group, 0)), int(EXPECTED_GROUPS[group])])
			_failures += 1
	if total != EXPECTED_TOTAL:
		printerr("gen_content: %d ids total, expected %d" % [total, EXPECTED_TOTAL])
		_failures += 1


func _check_files(entries: Array) -> void:
	var missing := 0
	for entry: Dictionary in entries:
		if not FileAccess.file_exists(String(entry["path"])):
			if missing < 10:
				printerr("gen_content: missing asset " + String(entry["path"]))
			missing += 1
		var sf := String(entry.get("spriteFrames", ""))
		if sf != "" and not FileAccess.file_exists(sf):
			printerr("gen_content: missing SpriteFrames " + sf)
			missing += 1
	if missing > 0:
		printerr("gen_content: %d missing file(s) - regenerate assets_raw (PIPELINE.md)" % missing)
		_failures += 1


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		printerr("gen_content: missing input " + path)
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		printerr("gen_content: invalid JSON in " + path)
		return null
	return parsed
