class_name AnimState
extends RefCounted
## One sprite's playback, driven by the fixed logic tick instead of a wall-clock timer.
##
## P2.15 §8.5 recovers the playback model from `resources.xml`: an image has a grid, an `anim` mode
## (`loop`, `once`, `pingpong` or none), a `framedelay` in 10 ms ticks, an optional parallel
## `perframedelay`, and `begindelay`/`enddelay` holds. `ImageRes` already carries all of it, and
## `frame(i)` is the framemap-ordered playback position, so this class is only the clock.
##
## Why not `AnimatedSprite2D`: its playback runs on seconds, ignores per-frame delays and the begin
## hold, has no pingpong, and every sprite started together therefore animates in lockstep. Here the
## frame is a pure function of `(tick - started)`, so each entity's animation begins when *it* spawns
## and can be asserted headlessly.
##
## Sheets whose `anim` is empty are **not** resource animations: the fish body, `FOOD`, `MONEY` and
## `SMALLSWIM` all declare no playback metadata, and the original advances their frame column from the
## entity (fish `+0x1C0`, advanced by one of the unlocated slots - Q-0057). This class still offers a
## uniform column clock for them so the callers share one implementation, at `SHEET_FRAME_TICKS`.

## Port default for the column of a sheet that declares no playback metadata (Q-0057).
const SHEET_FRAME_TICKS := 5

var res: ImageRes = null
## The tick playback began: the frame is `frame_at(tick)` from here on.
var started := 0

var _starts: Array[int] = [] ## tick, relative to the cycle start, at which each position begins
var _count := 1
var _frame_ticks := 1
var _begin := 0
var _span := 0
var _loop := true
var _pingpong := false


func setup(image_res: ImageRes, start_tick: int) -> void:
	res = image_res
	started = start_tick
	_count = res.play_count() if res != null else 1
	if res == null:
		return
	var timed := res.anim != ""
	_frame_ticks = maxi(res.frame_delay, 1) if timed else SHEET_FRAME_TICKS
	_begin = maxi(res.begin_delay, 0)
	_loop = not res.holds_last_frame()
	# Pingpong needs evenly spaced frames to fold back cleanly; a per-frame delay list disables it.
	_pingpong = res.uses_pingpong() and res.per_frame_delay.is_empty()
	_starts.clear()
	var acc := 0
	for i in _count:
		_starts.append(acc)
		acc += maxi(res.delay(i), 1) if timed else SHEET_FRAME_TICKS
	_span = acc + maxi(res.end_delay, 0)


## Playback position at `tick` (already framemap-ordered for `ImageRes.frame`).
func frame_at(tick: int) -> int:
	if res == null or _count <= 1:
		return 0
	var local := tick - started - _begin
	if local < 0:
		return 0
	if _span <= 0:
		return 0
	if _pingpong:
		var period := 2 * (_count - 1)
		if period <= 0:
			return 0
		var step := int(local / _frame_ticks) % period
		return step if step < _count else period - step
	if _loop:
		local = local % _span
	elif local >= _span:
		return _count - 1
	for i in range(_count - 1, -1, -1):
		if local >= _starts[i]:
			return i
	return 0


## The texture to draw at `tick`.
func texture_at(tick: int) -> Texture2D:
	if res == null:
		return null
	return res.frame(frame_at(tick))


func is_animated() -> bool:
	return _count > 1


## The uniform column clock for a sheet with no playback metadata, e.g. the fish body: `columns`
## columns cycling every `SHEET_FRAME_TICKS`.
static func column_at(start_tick: int, tick: int, columns: int) -> int:
	if columns <= 1:
		return 0
	var elapsed := maxi(tick - start_tick, 0)
	return int(elapsed / SHEET_FRAME_TICKS) % columns
