extends SceneTree
## Headless check for the Content loader (P4.2).
##
##   & "<godot>" --headless --path . --script res://tests/headless_content_check.gd
##
## Exits 0 only when the registry matches SPECS.md §2 and the generated manifest: the three load
## phases partition the 326 ids, each phase makes exactly its own ids available, ids resolve to the
## right typed handle, animation metadata survives the trip from the manifest, and aliases resolve.
## Autoloads do not exist under `--script`, so the registry is constructed directly.

const ContentScript := preload("res://scripts/autoload/content.gd")

var _failures := 0
var _checks := 0


func _init() -> void:
	var content: Node = ContentScript.new()

	# --- the three groups are load phases, in the original's order -------------
	_expect(ContentScript.PHASES.size() == ContentScript.Phase.COUNT, "one phase per manifest group")
	_expect(ContentScript.PHASES[ContentScript.Phase.INIT] == "Init", "phase 0 is Init")
	_expect(ContentScript.PHASES[ContentScript.Phase.REGISTER] == "Register", "phase 1 is Register")
	_expect(ContentScript.PHASES[ContentScript.Phase.LOADING] == "LoadingThread", "phase 2 is LoadingThread")

	# --- Init must be complete before anything else ---------------------------
	_expect(content.bootstrap(), "bootstrap() loads the manifest and the Init phase")
	_expect(content.is_phase_complete(ContentScript.Phase.INIT), "Init completes before the first frame")
	_expect(not content.is_phase_complete(ContentScript.Phase.REGISTER), "Register is not loaded yet")
	_expect(not content.is_phase_complete(ContentScript.Phase.LOADING), "LoadingThread is not loaded yet")
	_expect(content.loaded_count() == 14, "Init resolved its 14 ids (got %d)" % content.loaded_count())
	_expect(content.phase_progress(ContentScript.Phase.INIT) == 1.0, "Init reports 100% progress")

	# The loader screen and cursors are Init-phase resources: the original cannot draw its own
	# loading screen otherwise (P2.15 §8.2).
	_expect(content.texture("IMAGE_CURSOR_POINTER") != null, "Init cursor texture resolves")
	_expect(content.image("IMAGE_LOADERBAR").cell_w == 250, "Init loader bar keeps its 250 px cell")
	_expect(content.font("FONT_JUNGLEFEVER10OUTLINE") != null, "Init font resolves")
	_expect(content.sound("SOUND_BUTTONCLICK") != null, "Init click sound resolves")

	# --- an id is only available once its own phase has run -------------------
	_expect(not content.has_image("IMAGE_AMP"), "a LoadingThread image is absent after Init")
	_expect(not content.has_sound("SOUND_START"), "a LoadingThread alias is absent after Init")

	# --- Register: the dialog skin and UI fonts, pulled on demand -------------
	_expect(content.ensure_phase(ContentScript.Phase.REGISTER), "ensure_phase(Register) completes it")
	_expect(content.has_image("IMAGE_DIALOG"), "dialog skin is available")
	_expect(content.font("FONT_LIDDIE12") != null, "a UI font is available")
	_expect(content.font_size("FONT_LIDDIE12") == 12, "font size comes from the manifest")
	_expect(content.loaded_count() == 30, "Init + Register = 30 ids (got %d)" % content.loaded_count())
	_expect(not content.has_image("IMAGE_AMP"), "Register did not load LoadingThread ids")

	# --- LoadingThread: pumped in slices, the way the loading bar will ---------
	_expect(content.start_phase(ContentScript.Phase.LOADING), "start_phase(LoadingThread) queues the rest")
	_expect(content.pending() == 296, "LoadingThread queues 296 ids (got %d)" % content.pending())
	var before: float = content.progress()
	content.pump(0.0)
	_expect(content.progress() > before, "a zero budget still makes progress")
	_expect(content.progress() < 1.0, "a zero budget does not finish the phase")

	var guard := 0
	while content.pending() > 0 and guard < 10000:
		content.pump(1.0)
		guard += 1
	_expect(content.pending() == 0 and guard < 10000, "pumping drains the phase")
	_expect(content.is_phase_complete(ContentScript.Phase.LOADING), "LoadingThread completes")
	_expect(content.progress() == 1.0, "progress reaches 1.0")
	_expect(content.loaded_count() == 326, "all 326 ids resolved (got %d)" % content.loaded_count())

	# --- handles are typed and carry the manifest's animation metadata --------
	var amp: ImageRes = content.image("IMAGE_AMP")
	_expect(amp != null and amp.sprite_frames != null, "animated image carries SpriteFrames")
	_expect(amp.play_count() == 20 and amp.frame_count == 20, "AMP plays its 20 cells")
	_expect(amp.cols == 10 and amp.rows == 2 and amp.cell_w == 160 and amp.cell_h == 60, "AMP grid is 10x2 of 160x60")
	_expect(amp.is_animated() and amp.anim == "loop", "AMP loops")
	_expect(amp.frame_delay == 2, "AMP frame delay is 2 ticks from the manifest")
	_expect(amp.delay(7) == 2, "an image without perframedelay uses framedelay")
	_expect(amp.frame(19) != null, "the last frame resolves")
	_expect(amp.frame(20) == amp.frame(0), "frame() wraps for looping callers")

	# framemap is the playback order; a trailing `-1` placeholder is dropped, and the per-frame delay
	# table is applied to the kept positions (P2.15 §8.4-§8.5).
	var blink: ImageRes = content.image("IMAGE_MERYLBLINK")
	_expect(blink.play_count() == 5 and blink.frame_count == 3, "MERYLBLINK maps 3 cells into 5 playback frames")
	_expect(blink.delay(0) == 3 and blink.delay(4) == 1, "per-frame delays follow the mapped sequence")
	_expect(blink.holds_last_frame() and blink.is_animated(), "MERYLBLINK plays once")

	var cursor: ImageRes = content.image("IMAGE_CURSOR_POINTER")
	_expect(cursor.sprite_frames == null and not cursor.is_animated(), "a single-cell image has no SpriteFrames")
	_expect(cursor.frame(0) == cursor.texture, "a single-cell image is its own frame")

	# --- sounds: aliases and per-entry volume ---------------------------------
	_expect(content.sound("SOUND_START") == content.sound("SOUND_AWOOGA"), "SOUND_START aliases SOUND_AWOOGA")
	_expect(content.sound_volume("SOUND_NIKOOPEN") == 0.5, "sound volume comes from the manifest")
	_expect(content.sound_volume("SOUND_AWOOGA") == 1.0, "an unannotated sound defaults to 1.0")
	_expect(content.sound_ids().size() == 67, "65 sound ids + 2 aliases (got %d)" % content.sound_ids().size())

	# --- registry totals ------------------------------------------------------
	_expect(content.image_ids().size() == 246, "246 image ids (got %d)" % content.image_ids().size())
	_expect(content.font_ids().size() == 15, "15 font ids (got %d)" % content.font_ids().size())

	# --- a missing id is reported and returns null, not a crash ---------------
	_expect(content.image("IMAGE_NO_SUCH_THING") == null, "unknown image id returns null")
	_expect(content.failures.size() == 1, "the missing lookup was recorded (got %d)" % content.failures.size())

	content.free()
	if _failures == 0:
		print("headless_content_check: PASS (%d assertions)" % _checks)
		quit(0)
	else:
		printerr("headless_content_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)


func _expect(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("  ok   ", what)
	else:
		_failures += 1
		printerr("  FAIL ", what)
