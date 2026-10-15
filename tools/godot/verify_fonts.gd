extends SceneTree

func _init() -> void:
	var manifest_path := "res://assets_raw/fonts.json"
	if not FileAccess.file_exists(manifest_path):
		push_error("missing " + manifest_path)
		quit(1)
		return
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	if manifest == null:
		push_error("cannot parse fonts.json")
		quit(1)
		return
	var fails := 0
	var expected_total := 0
	for entry in manifest["fonts"]:
		var id: String = entry["id"]
		var path := "res://assets_raw/fonts/%s.fnt" % id
		var res = load(path)
		if res == null or not (res is FontFile):
			print("FAIL %s: not loadable as FontFile" % id)
			fails += 1
			continue
		var font: FontFile = res
		var missing := ""
		for code in entry["charCodes"]:
			if not font.has_char(int(code)):
				missing += String.chr(int(code))
		if not font.has_char(32):
			missing += " "
		var w := font.get_string_size("Insaniquarium 123", HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		var expected: int = int(entry["chars"]) + 1
		if missing != "" or w <= 0.0:
			print("FAIL %s: missing=[%s] width=%.1f" % [id, missing, w])
			fails += 1
		else:
			print("OK %s: %d expected chars all present, width=%.1f" % [id, expected, w])
			expected_total += expected
	print("fonts verified: %d/%d (glyphs checked=%d, fails=%d)" % [manifest["fonts"].size() - fails, manifest["fonts"].size(), expected_total, fails])
	quit(1 if fails > 0 else 0)
