extends Node
## Content - the one resource registry, and the original's three load phases (P4.2).
##
## SPECS.md §2 / P2.15 §8: the game never reads `properties\resources.xml` at runtime. A build step
## (`tools/godot/gen_content.gd`) emits `resources/content.json`, and this autoload resolves every id
## in it exactly once into a typed handle - `IMAGE_*` -> `ImageRes`, `SOUND_*` -> `AudioStream`,
## `FONT_*` -> `FontFile` - exactly as the original's group handlers do.
##
## The groups are *load phases*, and the ordering is observable, not cosmetic:
##
##   Init          (14)  loader screen, cursors, blank, two fonts, click sound - before first frame
##   Register      (16)  dialog skin + 13 UI fonts - before any dialog or menu
##   LoadingThread (296) 232 images + 64 sounds - behind the loading bar
##
## `bootstrap()` runs from `_ready()`, so Init is genuinely available before the first frame. Register
## is pulled on demand with `ensure_phase(Phase.REGISTER)`. LoadingThread is pumped a little each
## frame (`pump()`) so a loading screen (P4.5) can draw its bar between slices.
##
## Lookups by string are for setup code only. A live system captures its handles once and holds them
## (SPECS.md §2.1) - a per-tick string lookup is a bug.

## Load phases in the original's order (P2.15 §2). The values index `PHASES`.
enum Phase { INIT, REGISTER, LOADING, COUNT }

## Manifest group name per phase. These strings are the shipped manifest's, kept verbatim.
const PHASES := ["Init", "Register", "LoadingThread"]
const MANIFEST_PATH := "res://resources/content.json"
## The shipped manifest's id count (P2.15/EV-0151..EV-0154). `gen_content.gd` refuses to emit a
## different partition, so this guards against a stale or truncated manifest.
const EXPECTED_TOTAL := 326

signal phase_started(phase: int, total: int)
signal phase_finished(phase: int)
## Emitted every `pump()` call while a phase is in progress, for the loading bar.
signal progress_changed(phase: int, done: int, total: int)

## Missing-asset diagnostics from the last load (also reported via push_error).
var failures: Array[String] = []

var _manifest: Dictionary = {}
var _images: Dictionary = {}   ## String -> ImageRes
var _sounds: Dictionary = {}   ## String -> AudioStream (aliases included)
var _sound_volume: Dictionary = {}
var _fonts: Dictionary = {}    ## String -> FontFile
var _font_size: Dictionary = {}

var _queue: Array = []
var _phase := -1
var _done := 0
var _total := 0
var _completed: Array[bool] = []
var _loaded_total := 0


func _ready() -> void:
	bootstrap()


## Read the manifest and complete the Init phase. Safe to call twice; returns false only when the
## manifest itself is unusable (that is a build error, not a runtime state).
func bootstrap() -> bool:
	_ensure_state()
	if not _manifest.is_empty():
		return true
	if not FileAccess.file_exists(MANIFEST_PATH):
		push_error("Content: missing %s - run tools/godot/gen_content.gd" % MANIFEST_PATH)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Content: invalid JSON in " + MANIFEST_PATH)
		return false
	_manifest = parsed

	var total := 0
	var counts: Dictionary = _manifest.get("counts", {})
	for group: String in counts:
		total += int(counts[group])
	if total != EXPECTED_TOTAL:
		push_error("Content: manifest has %d ids, expected %d - regenerate it" % [total, EXPECTED_TOTAL])

	start_phase(Phase.INIT)
	return ensure_phase(Phase.INIT)


# --- phases ----------------------------------------------------------------

## Queue a phase. Returns false when another phase is still loading (the phases are ordered, so a
## caller that skips ahead has a bug).
func start_phase(phase: int) -> bool:
	if phase < 0 or phase >= Phase.COUNT:
		return false
	if is_phase_complete(phase):
		return true
	if not _queue.is_empty():
		# Already loading that phase (`bootstrap()` queues Init, then `ensure_phase()` drains it).
		if phase == _phase:
			return true
		push_error("Content: cannot start %s while %s is loading" % [PHASES[phase], PHASES[_phase]])
		return false
	_ensure_state()
	_phase = phase
	_queue = _build_queue(PHASES[phase])
	_total = _queue.size()
	_done = 0
	phase_started.emit(phase, _total)
	return true


## Load whatever is pending, spending at most `budget_ms` in this call. Always makes at least one
## step, so a zero budget cannot stall the phase. Returns the number of resources loaded.
func pump(budget_ms: float = 8.0) -> int:
	var started := Time.get_ticks_usec()
	var steps := 0
	while not _queue.is_empty():
		_load_entry(_queue.pop_front())
		steps += 1
		_done += 1
		_loaded_total += 1
		if float(Time.get_ticks_usec() - started) / 1000.0 >= budget_ms:
			break
	if _queue.is_empty() and _phase >= 0 and not is_phase_complete(_phase):
		_completed[_phase] = true
		# One line per phase: the boot log is the cheapest proof that all three ran, in order.
		print("Content: %s loaded (%d resources)" % [PHASES[_phase], _total])
		phase_finished.emit(_phase)
	if _phase >= 0:
		progress_changed.emit(_phase, _done, _total)
	return steps


## Complete a phase synchronously - the "must exist before X" rule (`Register` before a dialog).
func ensure_phase(phase: int) -> bool:
	if is_phase_complete(phase):
		return true
	if not start_phase(phase):
		return false
	while not _queue.is_empty():
		pump(1000.0)
	return is_phase_complete(phase)


func is_phase_complete(phase: int) -> bool:
	_ensure_state()
	return phase >= 0 and phase < _completed.size() and _completed[phase]


## The phase table must exist even when this script is constructed outside the tree (the headless
## checks do exactly that), so it cannot live in `_ready()` alone.
func _ensure_state() -> void:
	if _completed.size() != Phase.COUNT:
		_completed.resize(Phase.COUNT)


## Phase currently loading, or -1 when idle.
func current_phase() -> int:
	return _phase if not _queue.is_empty() else -1


func pending() -> int:
	return _queue.size()


## 0..1 for the loading bar; 1.0 once the phase is complete, 0.0 before it starts.
func progress() -> float:
	if _phase < 0:
		return 0.0
	if is_phase_complete(_phase):
		return 1.0
	return float(_done) / float(maxi(_total, 1))


func phase_progress(phase: int) -> float:
	if is_phase_complete(phase):
		return 1.0
	if phase != _phase:
		return 0.0
	return float(_done) / float(maxi(_total, 1))


func loaded_count() -> int:
	return _loaded_total


# --- typed lookups ---------------------------------------------------------

func has_image(id: String) -> bool:
	return _images.has(id)


func has_sound(id: String) -> bool:
	return _sounds.has(id)


func has_font(id: String) -> bool:
	return _fonts.has(id)


## The resolved image, or null after reporting a missing id. Use `has_image()` when the absence is
## legitimate; the original throws ("image resource not found"), so the default here is a loud error.
func image(id: String) -> ImageRes:
	var res: ImageRes = _images.get(id)
	if res == null:
		_missing("image", id)
	return res


func texture(id: String) -> Texture2D:
	var res := image(id)
	return res.texture if res != null else null


func sprite_frames(id: String) -> SpriteFrames:
	var res := image(id)
	return res.sprite_frames if res != null else null


## Stream for an id, aliases included (`SOUND_START` -> `SOUND_AWOOGA`, resolved from the manifest's
## `alias` attribute rather than by guessing at filenames).
func sound(id: String) -> AudioStream:
	var stream: AudioStream = _sounds.get(id)
	if stream == null:
		_missing("sound", id)
	return stream


## The manifest's per-entry volume, used as the sound pool's default (SPECS.md §2.5).
func sound_volume(id: String) -> float:
	return float(_sound_volume.get(id, 1.0))


func font(id: String) -> FontFile:
	var res: FontFile = _fonts.get(id)
	if res == null:
		_missing("font", id)
	return res


## Native point size from the manifest (`size=` in the .fnt), for `font_size` overrides.
func font_size(id: String) -> int:
	return int(_font_size.get(id, 0))


func image_ids() -> Array:
	return _images.keys()


func sound_ids() -> Array:
	return _sounds.keys()


func font_ids() -> Array:
	return _fonts.keys()


# --- loading ---------------------------------------------------------------

func _build_queue(group: String) -> Array:
	var jobs: Array = []
	for kind: String in ["images", "sounds", "fonts"]:
		for raw: Variant in _manifest.get(kind, []):
			var entry: Dictionary = raw
			if String(entry["group"]) == group:
				jobs.append({"kind": kind, "entry": entry})
	return jobs


func _load_entry(job: Dictionary) -> void:
	var entry: Dictionary = job["entry"]
	match String(job["kind"]):
		"images":
			_load_image(entry)
		"sounds":
			_load_sound(entry)
		"fonts":
			_load_font(entry)


func _load_image(entry: Dictionary) -> void:
	var res := ImageRes.new()
	res.id = String(entry["id"])
	res.name = String(entry.get("name", ""))
	res.path = String(entry.get("path", ""))
	res.cols = int(entry.get("cols", 1))
	res.rows = int(entry.get("rows", 1))
	res.cell_w = int(entry.get("cellW", 0))
	res.cell_h = int(entry.get("cellH", 0))
	res.frame_count = int(entry.get("frameCount", 1))
	res.anim = String(entry.get("anim", ""))
	res.frame_delay = int(entry.get("frameDelay", 0))
	res.begin_delay = int(entry.get("beginDelay", 0))
	res.end_delay = int(entry.get("endDelay", 0))
	for value: Variant in entry.get("perFrameDelay", []):
		res.per_frame_delay.append(int(value))

	var sf_path := String(entry.get("spriteFrames", ""))
	if sf_path != "":
		res.sprite_frames = load(sf_path) as SpriteFrames
		if res.sprite_frames == null:
			_fail(sf_path, res.id)
			return
		res.texture = res.sprite_frames.get_frame_texture("default", 0)
	else:
		res.texture = load(res.path) as Texture2D
		if res.texture == null:
			_fail(res.path, res.id)
			return
	_images[res.id] = res


func _load_sound(entry: Dictionary) -> void:
	var id := String(entry["id"])
	var path := String(entry.get("path", ""))
	var stream := load(path) as AudioStream
	if stream == null:
		_fail(path, id)
		return
	_sounds[id] = stream
	_sound_volume[id] = float(entry.get("volume", 1.0))
	var alias := String(entry.get("alias", ""))
	if alias != "":
		_sounds[alias] = stream
		_sound_volume[alias] = _sound_volume[id]


func _load_font(entry: Dictionary) -> void:
	var id := String(entry["id"])
	var path := String(entry.get("path", ""))
	var res := load(path) as FontFile
	if res == null:
		_fail(path, id)
		return
	_fonts[id] = res
	_font_size[id] = int(entry.get("size", 0))


func _fail(path: String, id: String) -> void:
	var message := "%s (id %s)" % [path, id]
	failures.append(message)
	push_error("Content: could not load %s" % message)


## The original's lookup error is fatal ("X resource not found: %s", EV-0153); here it is a reported
## error plus null, so one missing optional sheet cannot take the game down mid-frame.
func _missing(kind: String, id: String) -> void:
	failures.append("%s %s" % [kind, id])
	push_error("Content: %s resource not found: %s" % [kind, id])
