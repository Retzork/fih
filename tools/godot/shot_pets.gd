extends SceneTree
## Windowed confirmation of the shipped pet chooser (R60): boots the real main path, finishes 1-5,
## walks the Hatch card through to the Pets screen and captures the grid empty, with three pets
## selected and scrolled to the last rows.
##   Godot --path . --audio-driver Dummy --script res://tools/godot/shot_pets.gd

const OUT_EMPTY := "shot_pets_empty.png"
const OUT_SELECTED := "shot_pets_selected.png"
const OUT_ZOOM := "shot_pets_zoom.png"
const OUT_SCROLLED := "shot_pets_scrolled.png"

var _fails := 0


func _initialize() -> void:
	_run()


func _shot(out: String) -> void:
	var image := root.get_texture().get_image()
	image.save_png("res://docs/captures/" + out)
	print("SHOT: ", out, " ", image.get_size())


## A nearest-neighbour enlargement of a 640x480-space rect, so a nine-pixel ring is readable.
func _shot_zoom(out: String, logical: Rect2, factor: int) -> void:
	var image := root.get_texture().get_image()
	var window_scale := float(image.get_width()) / 640.0
	var region := Rect2i(
		Vector2i(logical.position * window_scale), Vector2i(logical.size * window_scale))
	var crop := image.get_region(region)
	crop.resize(crop.get_width() * factor, crop.get_height() * factor, Image.INTERPOLATE_NEAREST)
	crop.save_png("res://docs/captures/" + out)
	print("SHOT: ", out, " ", crop.get_size())


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok   ", what)
	else:
		_fails += 1
		printerr("  FAIL ", what)


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _run() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var game := root.get_node_or_null("Game")
	var content := root.get_node_or_null("Content")
	if game == null or content == null:
		push_error("autoloads missing")
		quit(1)
		return
	for index in [0, 1, 6, 7, 8]:
		game.profile.grant_pet(index)
	var selector: Node = null
	for i in 2400:
		await process_frame
		selector = root.find_child("GameSelector", true, false)
		if selector != null and content.is_phase_complete(content.Phase.LOADING):
			break
	if selector == null:
		push_error("GameSelector never mounted")
		quit(1)
		return
	game.profile.tank = 1
	game.profile.level = 5
	selector.press(1, {})
	await _frames(12)
	var level: Level = root.find_child("Level", true, false)
	if level == null:
		push_error("Level never mounted")
		quit(1)
		return
	level.money = 20000
	for i in 3:
		level.buy_egg()
	await _frames(6)
	var hatch: HatchScreen = root.find_child("HatchScreen", true, false)
	_check(hatch != null, "the Hatch card follows the completion")
	if hatch != null:
		hatch.press_ok()
	await _frames(8)
	var pets: PetsScreen = root.find_child("PetsScreen", true, false)
	_check(pets != null, "the pet chooser is the screen after Hatch")
	if pets == null:
		quit(1)
		return
	var grid := pets.get_node_or_null("Viewport/Grid")
	_check(grid != null, "the grid lives in the scrolling viewport")
	_check(grid != null and grid.get_child_count() == 24, "24 pet buttons exist")
	_check(pets.get_node_or_null("Viewport/Grid/Pet0") != null, "pet 0 has a button")
	_check(pets.get_node_or_null("Viewport/Grid/Pet2") != null
		and not pets.get_node("Viewport/Grid/Pet2").visible, "an unowned pet's button is hidden")
	_check(pets.get_node_or_null("Continue") != null and pets.get_node_or_null("Menu") != null,
		"the two recovered buttons are mounted")
	_shot(OUT_EMPTY)

	_check(pets.toggle(0), "one pet selects")
	await _frames(2)
	var ring: Control = pets.get_node_or_null("Viewport/Grid/Pet0/Ring")
	_check(ring != null and ring.visible, "the selected pet draws its ring")
	var dome: TextureRect = pets.get_node_or_null("Viewport/Grid/Pet0/Button")
	var neighbour: TextureRect = pets.get_node_or_null("Viewport/Grid/Pet1/Button")
	_check(dome != null and neighbour != null and dome.texture != neighbour.texture,
		"the selected pet draws the bright PETBUTTON face, its neighbour the plain one")
	_check(dome != null and neighbour != null and dome.modulate != neighbour.modulate,
		"the unselected dome is dimmed as well")
	_shot(OUT_SELECTED)
	# Pet 0 is selected and pet 1 is not, so one 190x96 crop carries both states at 3x.
	_shot_zoom(OUT_ZOOM, Rect2(20.0, 88.0, 190.0, 96.0), 3)

	pets.scroll_by(PetsScreen.ROW_PITCH * 2.0)
	await _frames(2)
	_check(pets.scroll_y() > 0.0, "the grid scrolls to the last rows")
	_shot(OUT_SCROLLED)
	print("PETS: scroll=", pets.scroll_y(), " cap=", pets.selection_cap(),
		" selected=", pets.selected(), " continue=", pets.request_confirm())
	quit(0 if _fails == 0 else 1)
