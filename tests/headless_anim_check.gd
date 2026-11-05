extends SceneTree
## headless_anim_check - the tick-driven sprite playback added for P4.3's presentation: `AnimState`
## reproduces the resource's own metadata (`anim`, `framedelay`, `perframedelay`, `begindelay`,
## `enddelay`), and `SpriteKey` must key each sheet **cell** separately.
##
## Driven against real registry entries so the assertions are the shipped numbers: `MERYLTAIL` (once,
## framemap 7..0, 2 ticks per frame after a 3-tick hold), `WAVESIDE` (pingpong, 4 ticks, 6-tick hold)
## and `SYLV` (loop, 2 ticks).

var _checks := 0
var _failures := 0
var _content: Node = null


func _init() -> void:
	await process_frame
	if root.get_node_or_null("Content") == null:
		print("headless_anim_check: Content autoload missing")
		quit(1)
		return
	_content = root.get_node("Content")
	_content.ensure_phase(_content.Phase.REGISTER)
	_content.start_phase(_content.Phase.LOADING)
	var guard := 0
	while not _content.is_phase_complete(_content.Phase.LOADING) and guard < 400:
		_content.pump(50.0)
		guard += 1
	_test_once()
	_test_loop()
	_test_pingpong()
	_test_keyed_cells()
	if _checks == 0:
		print("headless_anim_check: no assertions ran")
		quit(1)
		return
	if _failures > 0:
		print("headless_anim_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)
		return
	print("headless_anim_check: PASS (%d assertions)" % _checks)
	quit(0)


func _expect(condition: bool, what: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("  FAIL %s" % what)


func _anim(id: String, started: int = 0) -> AnimState:
	var res: ImageRes = _content.image(id)
	var state := AnimState.new()
	state.setup(res, started)
	return state


func _test_once() -> void:
	var res: ImageRes = _content.image("IMAGE_MERYLTAIL")
	_expect(res.anim == "once", "MERYLTAIL plays once")
	_expect(res.play_count() == 8, "the strip has eight playback positions")
	var state := _anim("IMAGE_MERYLTAIL")
	_expect(state.frame_at(0) == 0, "the begin hold keeps position 0")
	_expect(state.frame_at(2) == 0, "for its three ticks")
	_expect(state.frame_at(3) == 0, "and starts position 0 on tick 3")
	_expect(state.frame_at(5) == 1, "the next position starts after two more ticks")
	_expect(state.frame_at(3 + 2 * 7) == 7, "the last position is reached")
	_expect(state.frame_at(400) == 7, "and a one-shot holds it, it does not wrap")
	_expect(state.texture_at(0) != null, "the texture comes from the resource")


func _test_loop() -> void:
	var state := _anim("IMAGE_SYLV")
	_expect(state.frame_at(0) == 0, "a loop starts at position 0")
	_expect(state.frame_at(2) == 1, "and advances every two ticks")
	var count := state.res.play_count()
	_expect(state.frame_at(2 * count) == 0, "then wraps to the start")


func _test_pingpong() -> void:
	var res: ImageRes = _content.image("IMAGE_WAVESIDE")
	_expect(res.anim == "pingpong", "WAVESIDE pingpongs")
	var state := _anim("IMAGE_WAVESIDE")
	_expect(state.frame_at(6 + 4 * (res.play_count() - 1)) == res.play_count() - 1, "it reaches the last frame")
	_expect(state.frame_at(6 + 4 * res.play_count()) == res.play_count() - 2, "and folds back one step")


func _test_keyed_cells() -> void:
	# The regression this pins: an AtlasTexture answers `get_rid()` with its atlas's RID, so keying on
	# the RID alone returned the first keyed frame for every cell - frozen sprites.
	var res: ImageRes = _content.image("IMAGE_SMALLSWIM")
	var first := SpriteKey.keyed(res.frame(0))
	var second := SpriteKey.keyed(res.frame(1))
	_expect(first != null and second != null, "two cells of the swim sheet key")
	_expect(first != second, "and are distinct textures, not one shared frame")
	_expect(SpriteKey.keyed(res.frame(0)) == first, "the same cell is cached")
