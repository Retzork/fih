extends SceneTree

## headless_menu_check - P4.14's GameSelector dispatch: EV-0131's ids, the mode writers and the two
## profile gates. Mode numbers are Game.Mode: 0 adventure, 1 time trial, 4 challenge, 5 virtual tank.

var _checks := 0
var _failures := 0


func _init() -> void:
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
