extends SceneTree

## headless_menu_check - P4.14's GameSelector dispatch: EV-0131's ids, the mode writers and the two
## profile gates. Mode numbers are Game.Mode: 0 adventure, 1 time trial, 4 challenge, 5 virtual tank.

var _checks := 0
var _failures := 0


func _init() -> void:
	_test_ids()
	_test_gates()
	_test_labels()
	_test_mermaid_tail()
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


## The mermaid tail's playback is the recovered `MERYLTAIL` strip: 8 cells of 238x165, `anim="once"`,
## `framemap="7,6,5,4,3,2,1,0"`, `framedelay="2"`, `begindelay="3"`, resting on the cell the flop
## ends on (Q-0055 keeps the screen placement a port fit, so it is not asserted here).
func _test_mermaid_tail() -> void:
	var menu := GameSelector.new()
	_expect(GameSelector.TAIL_CELL == Vector2(238.0, 165.0), "the strip cells are 238x165")
	_expect(GameSelector.TAIL_REST_FRAME == 0, "the idle pose is the flop's last cell")
	_expect(menu.tail_cell(2) == GameSelector.TAIL_REST_FRAME, "the open holds the rest pose")
	_expect(menu.tail_cell(3) == 7, "the first flop cell plays after the 3-tick begin delay")
	_expect(menu.tail_cell(5) == 6, "the next cell is two ticks later")
	_expect(menu.tail_cell(17) == 0, "the flop ends on cell 0")
	_expect(menu.tail_cell(19) == GameSelector.TAIL_REST_FRAME, "the one-shot returns to the rest pose")
	menu.free()
