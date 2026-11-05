extends SceneTree

const MaskAlphaScript := preload("res://scripts/data/mask_alpha.gd")
## headless_menu_check - P4.14's GameSelector dispatch: EV-0131's ids, the mode writers and the two
## profile gates. Mode numbers are Game.Mode: 0 adventure, 1 time trial, 4 challenge, 5 virtual tank.

var _checks := 0
var _failures := 0


func _init() -> void:
	_test_mermaid_tail()
	_test_ids()
	_test_gates()
	_test_labels()
	if _checks == 0:
		print("headless_menu_check: no assertions ran")
		quit(1)
		return
	if _failures > 0:
		print("headless_menu_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)
		return
	print("headless_menu_check: PASS (%d assertions)" % _checks)
	quit(0)


func _expect(condition: bool, what: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("  FAIL %s" % what)


func _test_mermaid_tail() -> void:
	_expect(GameSelector.TAIL_CELL == Vector2(238, 165), "a MERYLTAIL cell is 238x165")
	_expect(GameSelector.TAIL_REST_FRAME == 2, "the rest pose is cell 2 (Q-0055)")
	_expect(GameSelector.TAIL_OFFSET == Vector2(114, 274), "the tail sits at its port-measured offset")
	_expect(GameSelector.TAIL_SHEET_PATH.ends_with("tailflop.png"), "the sheet is the extracted tail")
	_expect(GameSelector.TAIL_MASK_PATH.ends_with("tailflop_.png"), "and its alpha is the mask companion")
	# The tail's one-shot flop: framemap order, a 3-tick hold then 2 ticks a frame, back to rest.
	_expect(GameSelector.TAIL_PLAY_ORDER == [7, 6, 5, 4, 3, 2, 1, 0], "the strip plays its framemap order")
	_expect(GameSelector.TAIL_FRAME_TICKS == 2 and GameSelector.TAIL_BEGIN_TICKS == 3,
		"framedelay 2 / begindelay 3 from the manifest")
	var tail := GameSelector.new()
	_expect(tail.tail_cell(0) == GameSelector.TAIL_REST_FRAME, "the tail rests before the begin hold ends")
	_expect(tail.tail_cell(3) == 7, "the flop starts on cell 7")
	_expect(tail.tail_cell(5) == 6, "then cell 6 two ticks later")
	_expect(tail.tail_cell(3 + 2 * 8) == GameSelector.TAIL_REST_FRAME, "after the flop it returns to the rest pose")
	_expect(tail.tail_position(4) == 0 and tail.tail_position(200) == -1, "the flop plays exactly once")
	tail.free()
	var base := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	base.set_pixel(0, 0, Color(0.4, 0.6, 0.2, 1.0))
	base.set_pixel(1, 0, Color(0.4, 0.6, 0.2, 1.0))
	var mask := Image.create(2, 1, false, Image.FORMAT_RGBA8)
	mask.set_pixel(0, 0, Color(1, 1, 1, 1))
	mask.set_pixel(1, 0, Color(0, 0, 0, 1))
	var keyed := MaskAlphaScript.apply(base, mask)
	_expect(keyed != null and keyed.get_pixel(0, 0).a == 1.0, "a white mask pixel is opaque")
	_expect(keyed != null and keyed.get_pixel(1, 0).a == 0.0, "a black mask pixel is clear")
	_expect(keyed != null and keyed.get_pixel(0, 0).g == base.get_pixel(0, 0).g, "the base keeps its colour")
	_expect(MaskAlphaScript.apply(base, Image.create(3, 1, false, Image.FORMAT_RGBA8)) == null,
		"a mask of another size is refused rather than stretched")


func _test_ids() -> void:
	var menu := GameSelector.new()
	var open := {"tanks_unlocked": 4, "adventure_done": true}
	_expect(int(menu.choose(1, open)["mode"]) == 0, "id 1 opens adventure")
	_expect(int(menu.choose(2, open)["mode"]) == 5, "id 2 opens the virtual tank")
	_expect(int(menu.choose(8, open)["mode"]) == 1, "id 8 opens time trial")
	_expect(int(menu.choose(9, open)["mode"]) == 4, "id 9 opens challenge")
	_expect(String(menu.choose(3, open)["action"]) == "options", "id 3 is the options dialog")
	_expect(String(menu.choose(4, open)["action"]) == "quit", "id 4 quits")
	_expect(String(menu.choose(6, open)["action"]) == "hall", "id 6 is the hall of fame")
	_expect(String(menu.choose(7, open)["action"]) == "help", "id 7 is help")
	_expect(String(menu.choose(42, open)["action"]) == "ignored", "an unknown id is ignored")
	menu.free()


func _test_gates() -> void:
	var menu := GameSelector.new()
	var fresh := {"tanks_unlocked": 1, "adventure_done": false}
	_expect(String(menu.choose(8, fresh)["action"]) == "not_yet", "time trial needs tank 2")
	_expect(String(menu.choose(9, fresh)["action"]) == "not_yet", "challenge needs a finished adventure")
	_expect(String(menu.choose(1, fresh)["action"]) == "mode", "adventure is never gated")
	_expect(String(menu.choose(2, fresh)["action"]) == "mode", "the virtual tank is never gated")
	var tank2 := {"tanks_unlocked": 2, "adventure_done": false}
	_expect(String(menu.choose(8, tank2)["action"]) == "mode", "tank 2 unlocks time trial")
	_expect(String(menu.choose(8, {"tanks_unlocked": 2})["action"]) == "mode", "a missing flag key does not gate")
	_expect(String(menu.choose(9, {"tanks_unlocked": 9})["action"]) == "not_yet", "challenge still needs the flag")
	var done := {"tanks_unlocked": 2, "adventure_done": true}
	_expect(String(menu.choose(9, done)["action"]) == "mode", "the flag unlocks challenge")
	_expect(String(menu.choose(8, done)["action"]) == "mode", "time trial stays open afterwards")
	menu.free()


func _test_labels() -> void:
	_expect(GameSelector.label_for(1) == "Adventure", "id 1 is labelled Adventure")
	_expect(GameSelector.label_for(9) == "Challenge", "id 9 is labelled Challenge")
	_expect(GameSelector.label_for(42) == "", "an unknown id has no label")
