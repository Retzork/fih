class_name Level
extends Node2D
## P4.4 - the tank screen, playable. It owns the `Tank`, the starting guppies, the click handling
## (pick up a coin, otherwise drop a pellet), the sprite layer and a placeholder HUD.
##
## Scope is the *feeding loop* (P2.2/P2.3): food drops, fish eat, hunger kills, coins drop and are
## picked up, dead fish leave a live successor (P2.4 §4: successors spawn, they are not revived
## corpses). What is deliberately not here yet:
## - gore/splat particles and the pet-corpse art (ids >= 0x65) on the death path;
## - the food budget / prices / store (P4.5): dropping a pellet is free until the economy lands;
## - the tank backdrop, decorations, music and click sounds (P4.5/P4.13);
## - the stage -> coin-kind table (Q-0036): a drop uses kind 1 (the 15-shell coin) as a placeholder.
##
## Rendering is optional (`render = false`), which is how the headless check runs it: no `Content`
## access, no sprites, same simulation.

const TankScript := preload("res://scripts/tank/tank.gd")
const FishScript := preload("res://scripts/entities/fish.gd")
const FoodScript := preload("res://scripts/entities/food.gd")
const AlienScript := preload("res://scripts/entities/alien.gd")
const PetScript := preload("res://scripts/entities/pet.gd")
const EggWidgetScript := preload("res://scripts/ui/egg_widget.gd")
const DebugPanelScript := preload("res://scripts/ui/debug_panel.gd")
const WaveClockScript := preload("res://scripts/tank/wave_clock.gd")
const LarvaScript := preload("res://scripts/entities/larva.gd")

## `Tank::AddMoney` clamps the wallet at 9,999,999 (P2.5 §5).
const MONEY_MAX := 9999999
## Two guppies, as a tank start; the real starting population is level data (P2.6, P4.6).
const STARTING_FISH := 2
const SPAWN_MIN := Vector2(80.0, 160.0)
const SPAWN_MAX := Vector2(480.0, 300.0)
## The drawn tank rect (`AQUARIUM1..6` are 640x480).
const TANK_SIZE := Vector2(640.0, 480.0)
## The bottom HUD the recording shows and the port lacked (D-0028, EV-0197). The game area starts
## 24 px into the window, so the window-measured glyph rows (y 483..498) are game rows 459..474.
## "Tank  1-1" bottom-left: glyphs x 14..73, 11 px tall, in pale gold (#98834F averaged over the
## bright stroke pixels, #A49364 at the brightest). It is the tank screen's only level readout
## (D-0031).
const TANK_LABEL_RECT := Rect2(13.0, 453.0, 220.0, 22.0)
const TANK_LABEL_COLOR := Color8(0xA8, 0x94, 0x60)
## The hunger hint centred in the same row: glyphs x 186..462 (centre 324), 18 px tall with the dark
## outline the base draws round the lime fill (#ADF762) - the outline samples #004A00. The label box
## is a layout box; the painted row sits inside it at `HINT_INK_RECT`.
const HINT_RECT := Rect2(0.0, 448.0, 640.0, 22.0)
## The painted rows of that box, measured off the windowed captures: 457..474, the recording's row
## (the 454 box put the ink 6 px low at 463..479.5, PLAN R29). It is kept separate because the layout
## box is taller than the glyphs and overlaps the F12 stats line's band (D-0036) where the ink does not.
const HINT_INK_RECT := Rect2(0.0, 457.0, 640.0, 17.0)
const HINT_COLOR := Color8(0xAE, 0xF7, 0x62)
const HINT_OUTLINE_COLOR := Color8(0x00, 0x4A, 0x00)
const HINT_OUTLINE_SIZE := 2
## The base's three wordings, one per warning line of `Fish.HUNGER_HINTS` (-1/-200/-400; P2.3 §5):
## the shallow one while the tank is short, the capitalised one at -200 and the dying one at -400
## (`0x598D14`, `0x598D48`, `0x598D70` in the shipped string table).
const HINT_TEXT := "Fish are hungry! Click to drop food!"
const HINT_TEXT_SEVERE := "Fish are REALLY hungry! Click to feed!"
const HINT_TEXT_DYING := "Fish are about to die of hunger! Click on aquarium!"
## Guppy swim frames are three separate images (`SIMSWIM1..3`, 40x40).
const FISH_IMAGES := ["IMAGE_SIMSWIM1", "IMAGE_SIMSWIM2", "IMAGE_SIMSWIM3"]
## The guppy body sheet: 10 frames per row, one row per growth stage (`SMALLSWIM`, 50 frames). The
## `SIMSWIM1..3` sheets turned out to be **eye layers only** (black cells with an eye), so drawing
## them alone rendered floating eyes. The body is drawn from here instead; layering the eyes back on
## top needs the assembly rule that is still open (Q-0042).
const BODY_IMAGE := "IMAGE_SMALLSWIM"
## The starving twin of the same sheet: 10 frames per row, same five stage rows (Q-0042).
const HUNGRY_BODY_IMAGE := "IMAGE_HUNGRYSWIM"
## The corpse sheet: `SMALLDIE` is the same 10x5 stage rows as `SMALLSWIM`, death cells 6..9.
const DEATH_IMAGE := "IMAGE_SMALLDIE"
const GUPPY_COLS := 10
const GUPPY_ROWS := 5
const FOOD_IMAGE := "IMAGE_FOOD"
## The alien/boss HP bar (P2.9 §5): the `HEALTHBARTUBE` glass over the `HEALTHBAR` fill, both
## 127x15, inside the alien's own box at x 10 and y = box height - 3. The fill is clipped to
## `tube_w * hp / hp0`.
const HEALTH_BAR_FILL_IMAGE := "IMAGE_HEALTHBAR"
const HEALTH_BAR_TUBE_IMAGE := "IMAGE_HEALTHBARTUBE"
const HEALTH_BAR_X := 10.0
const HEALTH_BAR_BOTTOM_INSET := 3.0

const PrestoPickerScript := preload("res://scripts/ui/presto_picker.gd")
const TankSaveScript := preload("res://scripts/persistence/tank_save.gd")
const SaveFilesScript := preload("res://scripts/persistence/save_files.gd")
const TankScalarsScript := preload("res://scripts/persistence/tank_scalars.gd")
const TankSnapshotScript := preload("res://scripts/persistence/tank_snapshot.gd")

var tank: Tank = null
## Starting wallet (SPECS §4.3): 200 in every mode; Sandbox sets 999999 in `_apply_mode_flags`.
const STARTING_MONEY := 200
## Manual pellet price (SPECS §3.2, P2.3 §2): `Tank+0x4AC` base 5, spent per drop.
const PELLET_PRICE := 5
var money := 0
var money_earned := 0
## The food quantity level (1..9, a saved tank counter - P2.3 §2, P2.5): at most this many
## *non-special* pellets may be in the tank at once. The store raises it (P4.5).
const FOOD_QUANTITY_MIN := 1
const FOOD_QUANTITY_MAX := 9
var food_quantity := FOOD_QUANTITY_MIN

## Food quality (0..2) and the backdrop index (`+0x3E8`); both are saved (P2.13 §6.3).
var food_quality := 0
var backdrop := 1
## The backdrop tint (`5e89e8`, drawn over the backdrop); `adv1` uses the backdrop-1 value.
var backdrop_tint := Color8(0x42, 0x30, 0x29, 0xFF)
## The store table, row for row with `TankSave.store` (slot `-1` = empty). The store UI is P4.5.
var tank_store: Array[Dictionary] = []
## The open shop dialog, null while the store is closed (P4.5).
var store_screen: Control = null
## The open "PRESTO CHANGE-O" picker (`FUN_0054C6F0`, EV-0100), null while it is closed.
var presto_picker: Control = null
## The live "Recharging..." notice: `{"pet": Pet, "ticks": int}`, or empty (EV-0182).
var _presto_notice: Dictionary = {}
var _presto_notice_label: Label = null
## The in-tank store bar along the top of the aquarium (P4.5/P4.6), null until `_ready` builds it
## with rendering on.
var store_bar: StoreBar = null
## The port-only cheat panel (D-0014), hidden until F1; null in `render = false` runs. Untyped so
## the preloaded script does not have to resolve a global class name at parse time.
var debug_panel = null
## The 24 per-pet presence flags as last saved. Pet bodies are only partly implemented, so a load
## records the flags without spawning the pets back (P4.7).
var pet_flags: Array[int] = []
## `Tank+0x440`: the next manual drop is a star potion pellet (P2.3 §2).
var star_potion_armed := false
## Where F5/F9 write and read (the Adventure slot of the active profile).
var save_path := "userdata/adv1.dat"
## The level within the tank (1..5); the save header stores it.
var level_index := 1
## The tank within the adventure (1..5), `Tank+0x3C8`: one field, read and written through the live
## tank, so the name label, the egg price and the store's restock tables can never disagree with the
## tank the simulation runs (D-0038). Writes before `setup()` build the tank are dropped, and the
## value is 0 until `load_game()`/`start_level()` sets it, like the recovered field.
var tank_index: int:
	get:
		return tank.tank_index if tank != null else 0
	set(value):
		if tank != null:
			tank.tank_index = value
## `Tank+0x43C`: egg pieces bought. The level completes at 4 (tank 5 starts at 3), P2.6 §5.
var egg_pieces := Progression.EGG_PIECES_AT_START
## The egg-piece price of this tank/level, or `Progression.PRICE_UNKNOWN` (P2.6 §3).
var egg_price := Progression.PRICE_UNKNOWN
## Set once the level has completed, so a second egg purchase cannot complete it again.
var completed := false
## The Adventure profile the completion writes to; `Main` hands over `Game.profile`. A level run
## without one keeps a private profile, so the headless checks stay standalone.
var profile: Profile = null

## A completed level: `tank`, `level`, the awarded pet index (999 for the tank-4 L5 card, -1 when
## Challenge mode records the run instead). The Hatch/Pets screens are not ported (Q-0053), so
## `Main` uses this to start the next level.
signal level_completed(tank_no: int, level_no: int, pet_index: int)
## The tank MENU button (TankScreen id 99 -> `FUN_0054AED0` + `FUN_00552100`): `Main` saves the
## tank, frees this level and rebuilds the main menu.
signal menu_requested
## Port-only NEXT LEVEL (D-0018): the profile has already been walked on, so `Main` only has to
## swap the level. The between-level cards are skipped.
signal skip_level_requested

## The game mode the selector writes (P2.12 EV-0131): 0 adventure, 1 time trial, 3 sandbox,
## 4 challenge, 5 virtual tank. Mode branches live in `start_level` and `_on_sim_tick`
## (P2.11 §10) and nowhere else.
const MODE_TIME_TRIAL := 1
const MODE_SANDBOX := 3
const MODE_CHALLENGE := 4
const MODE_VIRTUAL := 5
var game_mode := 0

## Time Trial clock (P2.11 §4 / EV-0127): budget in ticks at the 36 Hz port rate. 300 s on
## tank 1, 600 s on tanks 2-4. `elapsed` counts `_on_sim_tick` calls (one per Sim tick).
## Expiry collects all coins and completes the level through the normal path.
##
## The base counts seconds: `Tank+0x3B0` is the live elapsed time, rewritten every tick as
## `(now - +0x3B8) / 1000` (P2.11 §4), and `+0x3BC` is the budget in seconds (300 on tank 1, 600 on
## tanks 2-4). The port counts ticks, so this is the one place the two meet.
const TICKS_PER_SECOND := 36
var time_trial_budget_ticks := 0
var time_trial_elapsed := 0
## Challenge reward per tank, flat (P2.11 §5): tanks 1-4. Completion grants shells.
const CHALLENGE_REWARDS := {1: 2000, 2: 5000, 3: 10000, 4: 20000}
## Sandbox starts with 999999 money (P2.11 §6).
const SANDBOX_MONEY := 999999
## Virtual Tank (P2.11 §7 / EV-0128): 76 % ordinary / 24 % prize, weights sum to 100.
const VT_ORDINARY_CHANCE := 76
## `(prize_type, weight)` in roll order; the strict `<` walk makes the fallback unreachable,
## exactly as the binary does. `kind` is the P2.4 type id; `species` is the Fish entity's
## stand-in (Penta/Grubber/Breeder have no Fish class yet, so the guppy proxy is flagged).
const VT_PRIZE := [
	[8, 26], [9, 25], [7, 25], [10, 10], [6, 5], [0x24, 3], [0x23, 3], [0x22, 3],
]
## Type id -> Fish species for the prize fish the port can spawn today.
const VT_PRIZE_SPECIES := {
	7: 3, 6: 2, 0x24: 6, 0x23: 5, 0x22: 4, 8: 0, 9: 0, 10: 0,
}

## The weapon level (2..12) **is** `Tank+0x3E4`, the field P2.5 calls the weapon upgrade and P2.9
## calls pet capacity (the boss forces it to 10); keeping one field is why `shot_damage()` and the
## boss agree. Its UI is P4.10.
var weapon_level: int:
	get:
		return tank.pet_capacity if tank != null else 2
	set(value):
		if tank != null:
			tank.pet_capacity = clampi(value, 2, Store.WEAPON_MAX)
## The stored alien selection the wave clock reads; 0 disarms it.
var alien_selection := 0
## The stored alien selection the wave clock reads; 0 disarms it.
var wave: WaveClock = null
## The clickable egg-piece widget (P4.6); tank 5 sells the egg as a store row instead.
var egg_widget = null
## The base's bottom row: the tank name and the hunger hint (D-0028), the only level readout (D-0031).
var tank_label: Label = null
var hint_label: Label = null
## The tick `hint_label` was last computed for, and the wording it shows: fullness only moves when the
## tank advances, so a paused or unchanged tick does no work at all (D-0032).
var _hint_tick := -1
var _hint_shown := ""
## How many waves have spawned this level (the original's `Tank+0x45C`, `+0x45C++` on every spawned
## wave, P2.8 §5). It is a scalar-block field, so a load restores it and a level start clears it
## (`start_level`), exactly as the base does at session init (P2.6 §1.5, P2.11 §7).
var waves_spawned := 0
## Composite recipes spawn two member kinds at one point; the clock emits the recipe twice.
const COMPOSITE_MEMBERS := {
	0x09: [0x01, 0x03],
	0x0A: [0x07, 0x03],
	0x0B: [0x05, 0x06],
	0x0C: [0x03, 0x08],
}
var _composite_pending: Array[int] = []
var _composite_selection := -1
## Click box for an alien (P2.10 has no recovered per-kind hit box; Q-0046).
const ALIEN_CLICK_BOX := 80.0
## Render sprites and the HUD. False for headless checks (no Content access, no sprites).
var render := true

## Every sound the level asked for, in order: the headless checks read this instead of listening.
var sounds_played: Array[String] = []
## Lightweight particles (P4.4): smoke puffs and hit bursts live here as tick-counted facts,
## not as entities - the original spawns them through `FUN_00543640`/`FUN_005436F0` and the
## port keeps the same lifetime (smoke drifts, bursts fade in 5 ticks). Each entry is
## `{"pos": Vector2, "life": int, "kind": String}` with `life` counting down per Sim tick.
var particles: Array[Dictionary] = []
## Laser sparks (P2.10 §1): one entry per resolved click at `click - (40,40)`, for the
## renderer. The frame binding is parameterised (Q-0023): `laser_cell_for()` rows by tier.
var laser_sparks: Array[Dictionary] = []
## Held-fire state (SPECS §3.5): set while the left button is down; the period decides the cadence.
var holding_fire := false
var fire_cooldown := 0
## Where held fire aims (the last left-button press position).
var fire_target := Vector2.ZERO
var _sim: Node = null
## The `Content` autoload, looked up at run time: a `--script` run cannot resolve the autoload name at
## parse time, so the reference stays dynamic (the level is also usable with rendering disabled).
var _content: Node = null


## Resolve an autoload only when this level is inside the scene tree. The headless checks
## instantiate `Level` directly, where an absolute `/root/...` lookup is an engine error; a missing
## autoload is a normal state for those checks and must stay silent.
func _autoload(node_name: String) -> Node:
	if not is_inside_tree():
		return null
	return get_node_or_null("/root/" + node_name)


## Wire the tank. `sim_node` is the driver (the `Sim` autoload in the game, a fresh instance in the
## checks); `seed_value` fixes the level's single RNG stream.
func setup(sim_node: Node, seed_value: int = 4242) -> void:
	tank = TankScript.new()
	tank.name = "Tank"
	add_child(tank)
	# `setup()` builds the port's default 1-1 level (the `level_index` default); the one tank index lives
	# on the tank, so it is seeded there until `start_level`/`load_game` names another (D-0038).
	tank.tank_index = 1
	_sim = sim_node
	tank.setup(sim_node, seed_value)
	# `Tank.is_paused()` reads this shared gate (`Game.gameplay_paused`, the original's Tank+0x94).
	# Without the wiring the flag was written by the store/Options/presto paths but never read, so
	# entities kept ticking behind every modal. Tests may set their own source after `setup()`.
	tank.pause_source = _autoload("Game")
	tank.entity_spawned.connect(_on_entity_spawned)
	_ensure_wave()
	# The egg widget is built even when rendering is off, so the headless checks can drive the same
	# click path the game uses (P4.6, G14).
	egg_widget = EggWidgetScript.new()
	egg_widget.name = "EggWidget"
	add_child(egg_widget)
	egg_widget.setup(self)
	_mount_egg_widget()
	for i in STARTING_FISH:
		spawn_guppy(_random_spawn_point())
	# A fresh level starts with the mode's wallet even before `start_level` (R1).
	_apply_mode_flags()
	if _sim != null and _sim.has_signal("ticked"):
		_sim.ticked.connect(_on_sim_tick)
	# `_ready()` may have run before the tank existed, so the backdrop is added here as well.
	if render:
		_add_backdrop()


func _ready() -> void:
	_content = _autoload("Content")
	if not render:
		return
	var layer := CanvasLayer.new()
	layer.name = "Hud"
	add_child(layer)
	# The in-tank store bar (`FUN_005409B0`, Q-0018): the row of buy buttons above the tank.
	store_bar = StoreBar.new()
	store_bar.name = "StoreBar"
	layer.add_child(store_bar)
	store_bar.setup(self)
	# Port-only cheat panel (D-0014). It starts hidden and never pauses the simulation, so a
	# long-running playtest can keep growing/feeding while the panel is open.
	debug_panel = DebugPanelScript.new()
	debug_panel.name = "DebugPanel"
	layer.add_child(debug_panel)
	debug_panel.setup()
	debug_panel.visible = false
	debug_panel.action_requested.connect(_on_debug_action)
	_mount_egg_widget()
	_add_backdrop()
	_add_bottom_hud()


## The egg widget lives in the bar's empty seventh dome, so it has to draw with the bar: a
## CanvasLayer draws over every Node2D in the level, and `z_index` cannot lift a node across layers.
## `setup()` can run before or after `_ready()` (Main adds the level to the tree first), so both call
## this; `reparent()` keeps the widget's position, and it enters after the bar so it draws on top.
func _mount_egg_widget() -> void:
	if not render or egg_widget == null or not is_inside_tree():
		return
	var layer := get_node_or_null("Hud")
	if layer == null or egg_widget.get_parent() == layer:
		return
	egg_widget.reparent(layer)
	egg_widget.refresh()


## The base's own bottom row (D-0028): the tank name at the bottom left and the hunger hint centred
## under the sand line. Both draw on the `Hud` layer, ignore the mouse and were absent from the port.
func _add_bottom_hud() -> void:
	var layer := get_node_or_null("Hud")
	if layer == null:
		return
	tank_label = Label.new()
	tank_label.name = "TankLabel"
	tank_label.position = TANK_LABEL_RECT.position
	tank_label.size = TANK_LABEL_RECT.size
	tank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tank_label.add_theme_color_override("font_color", TANK_LABEL_COLOR)
	# The name is the one bottom-row string whose native advance overruns the recording (D-0034).
	UiFont.apply_tracked(tank_label, UiFont.BOTTOM_NAME_FONT, UiFont.BOTTOM_NAME_TRACKING)
	tank_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(tank_label)
	_refresh_tank_label()
	hint_label = Label.new()
	hint_label.name = "HungerHint"
	hint_label.position = HINT_RECT.position
	hint_label.size = HINT_RECT.size
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_color", HINT_COLOR)
	hint_label.add_theme_color_override("font_outline_color", HINT_OUTLINE_COLOR)
	hint_label.add_theme_constant_override("outline_size", HINT_OUTLINE_SIZE)
	UiFont.apply(hint_label, UiFont.BOTTOM_HINT_FONT)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.visible = false
	layer.add_child(hint_label)


## The base's own naming of the pair, with the wide gap the recording has between the name and the
## numbers. Static so the suite pins the string without building a HUD.
static func tank_name(tank_no: int, level_no: int) -> String:
	return "Tank  %d-%d" % [tank_no, level_no]


func _refresh_tank_label() -> void:
	if tank_label == null:
		return
	tank_label.text = tank_name(tank_index, level_index)


## The hint follows the tank's hungriest live fish: nothing while they are fed, the shallow wording
## from the first warning line and the capitalised one from the last. Split out from the label so the
## headless suite can drive it without a rendered HUD.
func hint_text() -> String:
	if tank == null:
		return ""
	var worst := 0
	for entity in tank.entities_in(Sim.Phase.FISH):
		var fish := entity as Fish
		if fish != null and not fish.dead:
			worst = mini(worst, int(fish.fullness))
	if worst <= Fish.HUNGER_HINTS[2]:
		return HINT_TEXT_DYING
	if worst <= Fish.HUNGER_HINTS[1]:
		return HINT_TEXT_SEVERE
	if worst <= Fish.HUNGER_HINTS[0]:
		return HINT_TEXT
	return ""


## The one place the hint can change: the tank's tick clock. A paused tank fires no ticks, and a
## frame without a tick costs one integer compare - the label is only written when its wording
## actually changes, so a settled hint does not dirty its own layout every frame.
func _refresh_hint() -> void:
	if hint_label == null or tank == null or int(tank.age_ticks) == _hint_tick:
		return
	_hint_tick = int(tank.age_ticks)
	var text := hint_text()
	if text == _hint_shown:
		return
	_hint_shown = text
	hint_label.visible = text != ""
	hint_label.text = text

## The tank backdrop (`+0x3E8`, 1..6 -> `TANKBACKDROP1..6`), drawn behind every entity. Idempotent:
## `setup()` and `_ready()` both call it, and a load names another index, so it re-points the sprite
## the session started with instead of leaving the old art up (D-0037).
func _add_backdrop() -> void:
	if _content == null or tank == null:
		return
	var texture := _backdrop_texture()
	if texture == null:
		return
	var sprite := get_node_or_null("Backdrop") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Backdrop"
		sprite.centered = false
		sprite.z_index = -100
		add_child(sprite)
	_fit_backdrop(sprite, texture)


## The 640x480 tank art is `AQUARIUM1..6`; the `TANKBACKDROP` thumbnails (190x121) are the menu
## previews, so they are only a fallback and are scaled to the tank rect when used.
func _backdrop_texture() -> Texture2D:
	if _content == null:
		return null
	var id := "IMAGE_AQUARIUM%d" % backdrop
	if not _content.has_image(id):
		id = "IMAGE_TANKBACKDROP%d" % backdrop
	if not _content.has_image(id):
		return null
	var res: ImageRes = _content.image(id)
	return res.texture if res != null else null


func _fit_backdrop(sprite: Sprite2D, texture: Texture2D) -> void:
	sprite.texture = texture
	sprite.scale = Vector2(TANK_SIZE.x / texture.get_width(), TANK_SIZE.y / texture.get_height())


# --- entities ----------------------------------------------------------------

## Spawn a guppy and wire its events. `stage` -1 keeps the species default (stage 0).
func spawn_guppy(pos: Vector2, stage: int = -1, facing: int = 0) -> Fish:
	var fish: Fish = tank.spawn_fish(FishScript.Species.GUPPY, pos, stage, facing)
	_wire(fish)
	return fish


## Every fish the level owns answers the same events. The death path goes through a corpse, not
## straight to a successor (P2.4 §4). Hunger/growth cues are wired to sounds (Q-0030: the
## event->sound mapping is a port choice; see `CUE_SOUNDS`).
func _wire(fish: Fish) -> void:
	fish.died.connect(_on_fish_died)
	fish.breed_requested.connect(_on_breed)
	fish.coin_due.connect(_on_coin_due)
	fish.hunger_warning.connect(_on_fish_hunger)
	fish.grew.connect(_on_fish_grew)


func _on_fish_died(fish: Fish) -> void:
	# Death leaves a corpse and nothing else: it sinks and is removed silently (P2.4 §4, EV-0053).
	var corpse: DeadFish = tank.spawn_dead_fish(
		fish.species, fish.stage, fish.position, fish.facing,
		fish.vx, fish.vy, maxf(fish.speed_divisor, 0.01)
	)
	# The revive branch (`phase < 1`) has no recovered trigger, so this stays a wire, not a behaviour.
	corpse.successor_requested.connect(_on_successor)


## Drop one pellet at `pos` (the feeding click; P2.3 §2).
## `Tank::DropFood` manual-drop cap (P2.3 §2): refuse when
## `food_quantity + specials <= total`, i.e. at most `food_quantity` non-special pellets exist at
## once. Specials (`kind != 0 || variant != 0`) are exempt from the cap.
## A manual drop spends the pellet price (5, SPECS §3.2); Virtual Tank drops are free
## (its economy runs on shells, not money).
func drop_food(pos: Vector2) -> Food:
	if non_special_food() >= food_quantity:
		return null
	if not bool(tank.virtual_tank):
		if money < PELLET_PRICE:
			return null
		money -= PELLET_PRICE
	# A bought star potion turns the next manual drop into a quality-3 pellet (P2.3 §2).
	var quality := 3 if star_potion_armed else 0
	star_potion_armed = false
	var pellet: Food = FoodScript.create(pos, 0, false, 0, quality, tank.rng)
	play_sound("SOUND_DROPFOOD")
	return tank.spawn_at(pellet, Sim.Phase.FOOD, pos) as Food


## Non-special pellets in the tank: the count the manual-drop cap measures (P2.3 §2).
func non_special_food() -> int:
	var count := 0
	for entity in tank.entities_in(Sim.Phase.FOOD):
		var pellet := entity as Food
		if pellet != null and int(pellet.kind) == 0 and int(pellet.variant) == 0:
			count += 1
	return count


## Rebuild the wave clock after `shutdown()` freed it, and keep both spawn signals connected.
func _ensure_wave() -> void:
	if wave != null and is_instance_valid(wave) and not wave.dead:
		return
	wave = tank.spawn_wave_clock()
	wave.alien_spawn_requested.connect(_on_wave_spawn)
	wave.wave_spawned.connect(_on_wave_spawned)
	wave.milestone.connect(_on_wave_milestone)


## Arm the wave clock with a stored selection (0 disarms it). `countdown` is the clock's remaining
## ticks: the normal start is 3000, and tank 1 level 2 starts at 1750 (P2.6 §8).
func arm_wave(kind: int, countdown: int = WaveClock.WAVE_TICKS) -> void:
	alien_selection = kind
	_ensure_wave()
	wave.selection = kind
	wave.timer = clampi(WaveClock.WAVE_TICKS - countdown, 0, WaveClock.WAVE_TICKS)


## Restore the saved selection without disturbing the countdown `TankScalars.apply` just set.
func _sync_wave_selection() -> void:
	_ensure_wave()
	wave.selection = alien_selection


## The wave clock asked for a spawn. Composite recipes (9..0xC) spawn their two member kinds at the
## one rolled point; the clock emits the recipe twice, so the pending queue hands out one member per
## request (P2.8 §4).
func _on_wave_spawn(selection: int, at: Vector2) -> void:
	if COMPOSITE_MEMBERS.has(selection):
		if _composite_selection != selection or _composite_pending.is_empty():
			_composite_selection = selection
			_composite_pending.clear()
			for member in COMPOSITE_MEMBERS[selection]:
				_composite_pending.append(int(member))
		wire_alien(tank.spawn_alien(int(_composite_pending.pop_front()), at))
		return
	_composite_selection = -1
	_composite_pending.clear()
	if AlienScript.DEFS.has(selection):
		wire_alien(tank.spawn_alien(selection, at))


## After every spawned wave the level re-rolls its stored type for the next one (P2.8 §5.1).
func _on_wave_spawned(selection: int) -> void:
	waves_spawned += 1
	var next := next_wave_selection(selection)
	alien_selection = next
	if wave != null and is_instance_valid(wave):
		wave.selection = next


## Every alien the level owns: its shots go through the tank's projectile spawner, and its death
## refreshes the flag the pet gates read.
func wire_alien(alien: Alien) -> void:
	alien.attack_requested.connect(_on_alien_attack)
	alien.died.connect(_on_alien_died)
	alien.cue.connect(_on_alien_cue)
	tank.aliens_present = true


func _on_alien_attack(shot_kind: int, at: Vector2, target: Node2D) -> void:
	var shot: Projectile = tank.spawn_projectile(shot_kind, at, target)
	shot.smoke_requested.connect(_on_projectile_smoke)
	shot.burst_requested.connect(_on_projectile_burst)
	shot.hit_target.connect(_on_projectile_hit_target)


## The wave milestones (P2.8 §5): message -> warp hole -> sound -> warning -> event.
## Warning and sound play; message/warp/event are presentation the milestones name.
func _on_wave_milestone(step: String) -> void:
	match step:
		"warning":
			play_sound("SOUND_ROAR")
		"sound":
			play_sound("SOUND_SONAR")
		"message":
			play_sound("SOUND_TAPGLASS")
		_:
			pass


## Pet cue names (P2.7) through the registry: the numeric `FUN_00538230` ids name these
## sounds but no recovered table binds them (Q-0030), so the mapping is by semantic name.
const CUE_SOUNDS := {
	"niko_open": "SOUND_NIKOOPEN",
	"niko_close": "SOUND_NIKOCLOSE",
	"pearl": "SOUND_PEARL",
	"drop": "SOUND_POINTS",
	"snot": "SOUND_SNEEZE",
	"revive": "SOUND_HEAL",
	"missile": "SOUND_MISSLE",
	"ball": "SOUND_RICOCHET",
	"birth": "SOUND_BABY",
	"food": "SOUND_BUBBLES",
	"sing": "SOUND_SING",
	"zap": "SOUND_ZAP",
	"punch": "SOUND_PUNCH",
	"toss": "SOUND_POINTS2",
	"feed": "SOUND_SLURP",
}


func _on_pet_cue(cue_name: String, _at: Vector2) -> void:
	var id := String(CUE_SOUNDS.get(cue_name, ""))
	if id != "":
		play_sound(id)


func _on_alien_cue(cue_name: String) -> void:
	var id := String(CUE_SOUNDS.get(cue_name, ""))
	if id != "":
		play_sound(id)


func _on_fish_hunger(_level_no: int) -> void:
	play_sound("SOUND_SLURP")


func _on_fish_grew(_fish, _stage: int) -> void:
	play_sound("SOUND_GROW")


func _on_projectile_smoke(at: Vector2) -> void:
	spawn_particle(at, "smoke", 28)


func _on_projectile_burst(at: Vector2) -> void:
	spawn_particle(at, "burst", 5)
	play_sound("SOUND_HIT")


func _on_projectile_hit_target(_victim) -> void:
	pass


func _on_larva_burst(at: Vector2) -> void:
	spawn_particle(at, "burst", 5)
	play_sound("SOUND_HIT")


func _on_larva_payout(_larva) -> void:
	# The shells payout (`FUN_0053C1E0` routing, P2.6 §9) lands as shells in every mode.
	_profile().add_shells(15)


## A tick-counted particle (P4.4): no entity, no phase, just a lifetime the renderer draws.
func spawn_particle(at: Vector2, kind: String, life: int) -> void:
	particles.append({"pos": at, "life": life, "kind": kind})


## Age every particle and every laser spark by one Sim tick.
func _tick_particles() -> void:
	for i in range(particles.size() - 1, -1, -1):
		particles[i]["life"] = int(particles[i]["life"]) - 1
		if int(particles[i]["life"]) <= 0:
			particles.remove_at(i)
	for i in range(laser_sparks.size() - 1, -1, -1):
		laser_sparks[i]["life"] = int(laser_sparks[i]["life"]) - 1
		if int(laser_sparks[i]["life"]) <= 0:
			laser_sparks.remove_at(i)


## The laser spark of `FUN_00543640(x - 0x28, y - 0x28)` (P2.10 §1): drawn on every resolved
## click. `life` 5 ticks matches the fire cooldown the hit bookkeeping stamps.
func spawn_laser(at: Vector2) -> void:
	laser_sparks.append({"pos": at - Vector2(40.0, 40.0), "life": 5, "cell": laser_cell_for(weapon_level)})


## Q-0023 parameterisation: `IMAGE_LASERS` is 6 rows x 10 cols (60 cells). The row is the
## asset-level reading for the upgrade tier; the column is the beam animation. The draw code
## that binds tier to row was never found, so this stays the one place to change.
static func laser_cell_for(tier: int) -> int:
	var row := clampi(tier - 2, 0, 5)
	return row * 10


func _on_alien_died(_alien, _from_shot: bool) -> void:
	tank.aliens_present = tank.alien_count() > 0


## Shoot the alien under `point`, if any (one click = one shot, P2.10 §1).
func try_shoot(point: Vector2) -> bool:
	for entity: SimEntity in tank.entities_in(Sim.Phase.ALIENS):
		var alien := entity as Alien
		if alien == null:
			continue
		if Rect2(alien.position, Vector2(ALIEN_CLICK_BOX, ALIEN_CLICK_BOX)).has_point(point):
			alien.hit(tank.shot_damage(), true)
			return true
	return false


## Click a projectile: missiles are destroyed, balls deflected (P2.10 §5.4).
func try_hit_projectile(point: Vector2) -> bool:
	for entity: SimEntity in tank.entities_in(Sim.Phase.PROJECTILES):
		var shot := entity as Projectile
		if shot != null and shot.hit_test(point):
			return true
	return false


## Click a larva (`Tank+0xDC`, `Larva::HitTest`): kind 0 is destroyed, kind 1 deflects, kind 2
## cannot be clicked (P2.10 §1/§5.4). The click chain tests larvae before missiles, as the
## handler does; Rapid Fire tests them in reverse (P2.11 §8).
func try_hit_larva(point: Vector2) -> bool:
	for entity: SimEntity in tank.entities_in(Sim.Phase.PROJECTILES):
		var larva := entity as Larva
		if larva != null and larva.hit_test(point):
			return true
	return false


## The level schedule's boss table (P2.6/P2.9 §10): tank 5 level 1 is Cyrax, every other level has
## no boss. `"tank:level"` -> boss name, and the name -> alien kind the tank spawns.
const BOSS_BY_LEVEL := {"5:1": "cyrax"}
## Cyrax's alien kind; `Boss.KIND` mirrors it (a preloaded script constant is not a constant
## expression inside a dictionary, so the literal is repeated here).
const BOSS_KINDS := {"cyrax": 0x15}


## `FUN_00541200`'s normal start type per level (P2.6 §8). Zero is tank 1 level 1, which deliberately
## runs no wave; kinds 9..0xC are recipes, not entries in this table.
const WAVE_SELECTIONS := {
	"1:1": 0, "1:2": 1, "1:3": 2, "1:4": 3, "1:5": 3,
	"2:1": 2, "2:2": 3, "2:3": 4, "2:4": 5,
	"3:1": 3, "3:3": 7, "3:4": 6,
	"4:1": 3, "4:2": 8, "4:3": 4, "4:4": 8, "4:5": 8,
	"5:1": 0x15,
}
## Levels whose start type is one of a pair; the seeded level RNG picks the first wave's member.
const WAVE_PAIRS := {"2:5": [4, 5], "3:2": [4, 5], "3:5": [6, 7]}
## `FUN_00541200` also shortens tank 1 level 2's arrival to 1750 ticks (P2.6 §8).
const WAVE_COUNTDOWNS := {"1:2": 1750}


## The spawn selection a level starts with, or 0 when the level has no wave.
static func wave_selection_for(tank_no: int, level_no: int, rng: RandomNumberGenerator = null) -> int:
	var key := "%d:%d" % [tank_no, level_no]
	var pair: Array = WAVE_PAIRS.get(key, [])
	if not pair.is_empty():
		var index := 0
		if rng != null:
			index = rng.randi_range(0, pair.size() - 1)
		return int(pair[index])
	return int(WAVE_SELECTIONS.get(key, 0))


static func wave_countdown_for(tank_no: int, level_no: int) -> int:
	return int(WAVE_COUNTDOWNS.get("%d:%d" % [tank_no, level_no], WaveClock.WAVE_TICKS))


## The type re-roll the wave block applies after each spawn (P2.8 §5.1).
func next_wave_selection(current: int) -> int:
	match "%d:%d" % [tank_index, level_index]:
		"1:5":
			return 3 if tank.randi_below(2) == 0 else 0x09
		"2:5":
			var next := current
			if next == 0x09:
				next = 4 + (1 - tank.randi_below(2))
			var roll := tank.randi_below(100)
			if roll < 10:
				next = 4 if next == 5 else 5
			elif roll < 15:
				next = 0x09
			return next
		"3:2":
			if tank.randi_below(100) < 10:
				return 4 if current == 5 else 5
			return current
		"3:5":
			return 6 + (1 - tank.randi_below(2))
		"4:3":
			return 4 if tank.randi_below(2) == 0 else 0x0A
		"4:4":
			return 8 if tank.randi_below(2) == 0 else 0x0B
		"4:5":
			var roll5 := tank.randi_below(5)
			var selection := 0x0A if roll5 < 2 else (0x0B if roll5 < 4 else 0x08)
			if game_mode == MODE_CHALLENGE and waves_spawned > 4 and selection == 0x08:
				selection = 0x0C
			return selection
	return current


## The boss kind a level starts with, or 0 (P2.6: tank 5 level 1 is `boss = "cyrax"`).
static func boss_kind_for(tank_no: int, level_no: int) -> int:
	var name: String = BOSS_BY_LEVEL.get("%d:%d" % [tank_no, level_no], "")
	return int(BOSS_KINDS.get(name, 0))


## Enter a level (P2.6 §1.1/§10.2): resolve the tank/level (a start on the level-6 sentinel is the
## post-bonus step, Q-0053), set the egg counter and price, build the tank's store table and start
## the scheduled boss.
func start_level(tank_no: int, level_no: int = 1, profile_counter: int = 1) -> Boss:
	var start := Progression.resolve_start(tank_no, level_no, _profile().bonus_adventure)
	tank_index = int(start["tank"])
	level_index = int(start["level"])
	if level_no == Progression.LEVEL_SENTINEL:
		var owner := _profile()
		owner.tank = tank_index
		owner.level = level_index
		owner.bonus_adventure = bool(start["bonus_adventure"])
		owner.sessions_started += 1
	completed = false
	egg_pieces = Progression.egg_pieces_at_start(tank_index)
	egg_price = Progression.egg_price(tank_index, level_index, game_mode)
	stock_default_store()
	_refresh_tank_label()
	# The bar builds a widget for every row with `A >= 0` on its first frame (EV-0144), so the
	# `Tank+0x2E0 < Tank+0x2DC` latch Blip clears (EV-0094) starts clear; only a check or an old
	# save can set it.
	tank.age_ticks = 0
	# `Tank+0x45C = 0` at session init (P2.6 §1.5's clear list, P2.11 §7's VT init).
	waves_spawned = 0
	tank.wadsworth_count = 0
	tank.wadsworth_mouth = Vector2.ZERO
	reset_prices()
	_apply_mode_flags()
	refresh_save_path()
	if game_mode != MODE_TIME_TRIAL:
		spawn_owned_pets()
	if game_mode == MODE_VIRTUAL:
		_start_virtual_tank()
	else:
		# The level schedule owns the wave start: tank 1 level 1 stays at 0, tank 1 level 2
		# starts with 1750 ticks left, and every other level uses its recovered type (P2.6 §8).
		arm_wave(
			wave_selection_for(tank_index, level_index, tank.rng),
			wave_countdown_for(tank_index, level_index)
		)
	if egg_widget != null:
		egg_widget.refresh()
	# `SetMusic` per stage (P2.14 §4.1/EV-0148); Virtual Tank is silenced inside `Audio`.
	var audio := _autoload("Audio")
	if audio != null:
		audio.set_stage_music(tank_index)
	if boss_kind_for(tank_index, level_index) == BOSS_KINDS["cyrax"]:
		# `profile_counter <= 0` means "use the profile": `Main` starts levels without an
		# explicit counter, and Cyrax's hp must read `profile+0x54` (P2.9 §8/§10).
		var counter := profile_counter if profile_counter > 0 else _profile().cyrax_attempts
		return start_boss(counter)
	return null


## Mode -> tank flags (G7): mode is an input to level start (SPECS §5), so every mode-only
## rule branches here. `virtual_tank` mirrors the original's mode 5: it changes growth
## thresholds, nutrition caps and coin pacing. Sandbox money, Challenge rewards and the
## Time Trial budget are level-local and are set here too.
func _apply_mode_flags() -> void:
	tank.virtual_tank = game_mode == MODE_VIRTUAL
	# SPECS §4.3: every mode starts at 200, Sandbox at 999999. A load restores the saved
	# wallet afterwards, so this only seeds a fresh level.
	money = SANDBOX_MONEY if game_mode == MODE_SANDBOX else STARTING_MONEY
	if game_mode == MODE_TIME_TRIAL:
		time_trial_budget_ticks = time_trial_budget_seconds(tank_index) * TICKS_PER_SECOND
	else:
		time_trial_budget_ticks = 0
	time_trial_elapsed = 0


## The Time Trial budget in seconds for a tank (P2.11 §4 / P2.6 §8): 300 s on tank 1, 600 s on the
## rest. Static so a load can re-derive it before the mode flags run.
static func time_trial_budget_seconds(tank_no: int) -> int:
	return 300 if tank_no == 1 else 600


## `FUN_0053C3F0` (EV-0128): a Virtual Tank starts without the starter fish `setup()` placed
## and without an alien clock (P2.11 §7). It populates through the weighted fish spawner
## instead; the save is `sim%d.dat` through `Game.save_stem` (EV-0142).
func _start_virtual_tank() -> void:
	for entity in tank.entities_in(Sim.Phase.FISH):
		tank.despawn(entity)
	alien_selection = 0
	if wave != null and is_instance_valid(wave):
		wave.selection = 0
	for i in 6:
		spawn_virtual_fish(-1)


## `FUN_0051B260` (EV-0128): 76 % ordinary, otherwise the weighted prize table. The retried
## roll re-checks the exclusion and gives up after 100 tries with the "anything" call.
## Ordinary fish upgrade through `FUN_00519890(obj, 1)` 76 % of the time (stage +1).
func spawn_virtual_fish(excluded_type: int) -> Fish:
	if tank == null:
		return null
	for attempt in 100:
		var prize := tank.randi_below(100) >= VT_ORDINARY_CHANCE
		var type_id := -1
		if prize:
			var roll := tank.randi_below(100)
			var cumulative := 0
			for pair: Array in VT_PRIZE:
				cumulative += int(pair[1])
				if roll < cumulative:
					type_id = int(pair[0])
					break
			if type_id == excluded_type:
				continue
		var stage := tank.randi_below(3)
		var species := FishScript.Species.GUPPY
		if prize:
			species = int(VT_PRIZE_SPECIES.get(type_id, FishScript.Species.GUPPY))
			if type_id in [8, 9, 10]:
				# Penta/Grubber/Breeder have no Fish class yet; the guppy at a high stage
				# is the port's stand-in until the creature entities land (see Fish header).
				stage = 4 if type_id == 8 else (3 if type_id == 9 else 2)
			elif species == FishScript.Species.GEKKO:
				stage = -1
			elif species == FishScript.Species.ULTRA:
				stage = -1
		elif tank.randi_below(100) < VT_ORDINARY_CHANCE:
			stage += 1
		var at := _random_spawn_point()
		var fish: Fish = tank.spawn_fish(species, at, stage, 0)
		_wire(fish)
		return fish
	# Exhausted: the fallback call passes excluded_type = -1 (EV-0128).
	var fallback: Fish = tank.spawn_fish(FishScript.Species.GUPPY, _random_spawn_point(), 0, 0)
	_wire(fallback)
	return fallback


## The level-end sweep (`FUN_0053C2D0`, EV-0047): every live coin is collected. Used by the
## Time Trial clock expiry and by egg completion in Time Trial/Challenge/Virtual Tank.
func collect_all_coins() -> int:
	var taken := 0
	for coin in tank.coins():
		if not coin.dead:
			coin.collect()
			taken += 1
	return taken


## Pets join the tank with the session (P2.7 §2.2, branch A): every owned flag `FUN_00501410(i)` spawns
## its pet through `FUN_00544A90(index, -1, ...)`, which rolls x 105..369 and y 20..539. When the
## profile carries a non-empty pending selection (`profile+0x5A`, branch B), that selection is the
## spawned set instead. Returns how many pets entered.
func spawn_owned_pets() -> int:
	if tank == null:
		return 0
	var owner := _profile()
	var spawned := 0
	var selected: Array[int] = []
	for index: int in PetScript.DEFS:
		if index >= 0 and index < owner.selected_pets.size() and owner.selected_pets[index] != 0 \
				and owner.owns_pet(index):
			selected.append(index)
	var indices: Array[int] = []
	indices.append_array(selected)
	if indices.is_empty():
		for index: int in PetScript.DEFS:
			if owner.owns_pet(index):
				indices.append(index)
	for index: int in indices:
		var at := Vector2(
			tank.rng.randf_range(PET_SPAWN_MIN.x, PET_SPAWN_MAX.x),
			tank.rng.randf_range(PET_SPAWN_MIN.y, PET_SPAWN_MAX.y)
		)
		var pet: Pet = tank.spawn_pet(index, at)
		pet.cue.connect(_on_pet_cue)
		pet.birth_requested.connect(_on_pet_birth)
		pet.food_requested.connect(_on_pet_food)
		pet.attack_requested.connect(_on_pet_attack)
		pet.unlock_requested.connect(_on_pet_unlock)
		pet.transform_requested.connect(_on_pet_transform)
		spawned += 1
	return spawned


## Prego's birth: the guppy spawns live at the reported point (`FUN_00546EF0`).
func _on_pet_birth(at: Vector2) -> void:
	_wire(tank.spawn_fish(FishScript.Species.GUPPY, at, 0, 0))


## Zorf's level-2 food drop; the pellet is special, so the manual cap does not block it.
func _on_pet_food(quality_kind: int, at: Vector2) -> void:
	tank.spawn_food(at, 0, quality_kind)


## Pet melee/ball damage (Itchy/Rufus/Gash/Stanley/Walter): float damage vs aliens.
func _on_pet_attack(target: Node2D, damage: float) -> void:
	if target != null and is_instance_valid(target) and target.has_method("hit"):
		if target is Boss:
			(target as Boss).hit(int(damage), true)
		else:
			target.hit(int(damage), true)


## Blip's instant unlock (EV-0094): `FUN_005409B0(i, 1)` makes every store item available, which is
## the whole table - the level-gated (`A = -1`) shelves included.
func _on_pet_unlock() -> void:
	if not tank.store_locked:
		return
	tank.store_locked = false
	_unlock_store_rows()


## Presto's swap (EV-0100): the target is a real pet of its own index at the same point, spawned
## transformed so it inherits the 360-tick recharge. The old object already ran `cleanup()`.
func _on_pet_transform(pet_index: int, at: Vector2, facing: int) -> void:
	var pet: Pet = tank.spawn_pet(pet_index, at, true)
	pet.facing = facing
	pet.cue.connect(_on_pet_cue)
	pet.birth_requested.connect(_on_pet_birth)
	pet.food_requested.connect(_on_pet_food)
	pet.attack_requested.connect(_on_pet_attack)
	pet.unlock_requested.connect(_on_pet_unlock)
	pet.transform_requested.connect(_on_pet_transform)


## `FUN_00544A90`'s randomized spawn point when the caller passes x = -1.
const PET_SPAWN_MIN := Vector2(105.0, 20.0)
const PET_SPAWN_MAX := Vector2(369.0, 539.0)


## The profile the completion writes to (P2.6 §1.2). Lazily created so a level can run alone.
func _profile() -> Profile:
	if profile == null:
		profile = Profile.new()
	return profile


## Buy one egg piece (P2.6 §3/§5). Refuses when the level is complete, when the figure was never
## recovered, or when the purse is short; the 4th piece completes the level.
func buy_egg() -> bool:
	if completed or egg_price == Progression.PRICE_UNKNOWN:
		return false
	if egg_price > 0 and money < egg_price:
		return false
	money -= egg_price
	egg_pieces += 1
	if egg_pieces >= Progression.EGG_PIECES_TO_COMPLETE:
		complete_level()
	return true


## `FUN_00545960` (P2.6 §1.2/§10.4). The elapsed-time record, the coin sweep, the challenge record
## and the Hatch/Bonus screens are not ported (Q-0053); what is: the award, the grant, the
## 5000-shell final-boss bonus and the advance of the profile.
func complete_level() -> void:
	if completed:
		return
	completed = true
	var audio := _autoload("Audio")
	if audio != null:
		audio.set_level_complete_music()
	var owner := _profile()
	var tank_no := tank_index
	var level_no := level_index
	if game_mode == MODE_CHALLENGE:
		if tank_no >= 1 and tank_no <= Profile.CHALLENGE_SLOTS:
			owner.challenge_unlocks[tank_no - 1] = 1
		owner.add_shells(int(CHALLENGE_REWARDS.get(tank_no, 0)))
		level_completed.emit(tank_no, level_no, -1)
		return
	if game_mode == MODE_TIME_TRIAL:
		# Time Trial ends by the clock, not the egg (P2.11 §4): the reward is money*5/100
		# as shells. The expiry path collects first (see `_tick_time_trial`).
		owner.add_shells(int(money * 5 / 100))
		level_completed.emit(tank_no, level_no, -1)
		return
	var award := Progression.offered_pet(tank_no, level_no)
	if award != Progression.PET_CARD:
		owner.grant_pet(award)
		if award == Progression.FINAL_BOSS_PET:
			owner.add_shells(Progression.FINAL_BOSS_SHELLS)
	var step := Progression.advance(tank_no, level_no, owner.bonus_adventure)
	owner.tank = int(step["tank"])
	owner.level = int(step["level"])
	owner.bonus_adventure = bool(step["bonus_adventure"])
	owner.tank5_wins += int(step["tank5_wins"])
	level_completed.emit(tank_no, level_no, award)


## Start the boss fight: spawns Cyrax, freezes the waves and forces pet capacity 10 (P2.9 §10).
func start_boss(counter: int, at: Vector2 = Vector2(320.0, 200.0)) -> Boss:
	var boss: Boss = tank.spawn_boss(counter, at)
	boss.minion_requested.connect(_on_boss_minion)
	boss.pulse_requested.connect(_on_boss_pulse)
	boss.died.connect(_on_alien_died)
	boss.died.connect(_on_boss_died)
	return boss


## `FUN_00545580(x, y)` (EV-0117): a 1-hp Minisylvester (kind 0x14) at the boss position
## +40,+40. The boss signal already carries that point.
func _on_boss_minion(at: Vector2) -> void:
	wire_alien(tank.spawn_alien(0x14, at))


## `FUN_005475B0(type, 1)` (EV-0117): the 300-tick pulse spawns `type = rand%6 + 4` through the
## generic wave spawner, at `x 20..469, y 105..299`. Applies exactly like a wave spawn, so a
## composite 9 arrives as its two members at the one rolled point.
func _on_boss_pulse(at: Vector2) -> void:
	var selection := 4 + tank.randi_below(6)
	var point := Vector2(
		WaveClockScript.SPAWN_X_BASE + tank.randi_below(WaveClockScript.SPAWN_X_SPAN),
		WaveClockScript.SPAWN_Y_BASE + tank.randi_below(WaveClockScript.SPAWN_Y_SPAN)
	)
	_on_wave_spawn(selection, point)
	if COMPOSITE_MEMBERS.has(selection):
		_on_wave_spawn(selection, point)


## P2.9 §10: a fight that ends with more than 1000 damage dealt and no minions left counts
## toward `profile+0x54`, so the next Cyrax spawns 125 hp weaker (down to 2500). The binary
## runs this in the tank update while the boss is still alive (Q-0022); the port's kill path
## is where the fight ends, and the death wipe (`FUN_004F9950`) has already cleared the field
## by the time this handler runs.
func _on_boss_died(boss: Boss, _from_shot: bool) -> void:
	if boss == null:
		return
	# `died` fires before the boss despawns, so it still counts itself: the
	# "no minions left" check has to exclude the dying boss.
	var others := 0
	for entity in tank.entities_in(Sim.Phase.ALIENS):
		if entity != boss and not entity.dead:
			others += 1
	if boss.max_hp - boss.hp > 1000 and others == 0:
		_profile().cyrax_attempts += 1


## Pick up the coin under `point`, if any. Returns true when a coin was taken (P2.5 §5).
func try_collect(point: Vector2) -> bool:
	for coin: Coin in tank.coins():
		if coin.can_collect(point):
			coin.collect()
			return true
	return false


## `Tank::AddMoney` (P2.5 §5): wallet clamped at 9,999,999 and the level's earned total tracked.
func add_money(amount: int) -> void:
	if amount <= 0:
		return
	money = mini(money + amount, MONEY_MAX)
	money_earned += amount


func _random_spawn_point() -> Vector2:
	return Vector2(
		tank.rng.randf_range(SPAWN_MIN.x, SPAWN_MAX.x),
		tank.rng.randf_range(SPAWN_MIN.y, SPAWN_MAX.y)
	)


## The corpse's revive branch (Q-0043). It only fires when something sets the corpse's phase below
## 1, which no recovered code does; the spawn is live (`FUN_00542EE0(obj, 1)`), never a ghost.
func _on_successor(species: int, stage: int, at: Vector2, facing: int) -> void:
	_wire(tank.spawn_fish(species, at, stage, facing))


func _on_breed(_species: int, at: Vector2, facing: int) -> void:
	_wire(tank.spawn_fish(FishScript.Species.GUPPY, at, 0, facing))


## Q-0036 port tuning: the binary's stage -> kind assignment is still open (the slot-81 call sites
## elide the kind argument), so the port tiers by stage through the recovered value table (EV-0047):
## 1->15, 2->35, 3->40, 4->200, 5/6->500, 7->2000. Revisit when a slot-81 kind is bound; the mapping
## is kept here, keyed by `(species, stage)`, so one edit re-tunes the whole economy.
static func coin_kind_for(species: int, stage: int) -> int:
	if species == FishScript.Species.ULTRA:
		return 0x06
	if species == FishScript.Species.GEKKO:
		return 0x07
	match stage:
		1:
			return 0x01
		2:
			return 0x02
		3:
			return 0x03
		4:
			return 0x04
		5:
			return 0x06
		6:
			return 0x06
	return 0x01


func _on_coin_due(fish: Fish) -> void:
	tank.spawn_coin(coin_kind_for(fish.species, fish.stage),
		fish.position + Vector2(20.0, 20.0))


func _on_coin_collected(_coin, amount: int) -> void:
	# Virtual Tank converts coins to shells instead of money (P2.11 §7 / EV-0128).
	if tank != null and bool(tank.virtual_tank):
		_profile().add_shells(amount)
		return
	add_money(amount)


## Virtual Tank banked hand-off (`Coin.banked` at (550,30)): shells, not money.
func _on_coin_banked(coin) -> void:
	if coin != null and not coin.dead:
		_profile().add_shells(int(coin.amount()))


## Hold-to-fire (SPECS §3.5): level 12 unlocks it at `11 - level/2` ticks, floored at 100 ms
## (10 ticks), which is what the 5-tick value at level 12 would otherwise beat.
func hold_fire_period() -> int:
	if weapon_level < Store.WEAPON_MAX:
		return 0
	return maxi(11 - weapon_level / 2, 10)


## Held fire: level 12 fires every `hold_fire_period()` ticks at the last press position. The
## re-test order is Rapid Fire's missiles -> larvae -> aliens (P2.11 §8).
func aim(point: Vector2) -> void:
	fire_target = point


func fire_at(point: Vector2) -> bool:
	if try_hit_projectile(point):
		spawn_laser(point)
		return true
	if try_hit_larva(point):
		spawn_laser(point)
		return true
	if try_shoot(point):
		spawn_laser(point)
		return true
	return false


func _on_sim_tick(_tick: int) -> void:
	# The shared pause gate must stop the level's own clock too, not just the entities: time-trial
	# budget, particles, store refresh and held fire all live here. The original's tank update is
	# gated as one unit (Tank+0x94), so a paused tank freezes every counter.
	if tank == null or tank.is_paused():
		return
	tank.age_ticks += 1
	_tick_presto_notice()
	if game_mode == MODE_CHALLENGE:
		inflate_prices(1)
	if game_mode == MODE_TIME_TRIAL and not completed:
		_tick_time_trial()
	_tick_particles()
	if store_bar != null:
		store_bar.refresh_if_changed()
	if egg_widget != null:
		egg_widget.refresh_if_changed()
	if fire_cooldown > 0:
		fire_cooldown -= 1
	var period := hold_fire_period()
	if not holding_fire or period <= 0 or fire_cooldown > 0:
		return
	if fire_at(fire_target):
		fire_cooldown = period


## One Time Trial tick (P2.11 §4 / EV-0127). Expiry collects all coins
## (`FUN_0053C2D0`) and completes the level, which pays `money*5/100` shells.
func _tick_time_trial() -> void:
	if time_trial_budget_ticks <= 0:
		return
	time_trial_elapsed += 1
	if time_trial_elapsed > time_trial_budget_ticks:
		collect_all_coins()
		complete_level()


## Seconds left on the Time Trial clock (integer, like `Tank+0x3BC - +0x3B0`), or 0 outside Time
## Trial.
func time_trial_seconds_left() -> int:
	if game_mode != MODE_TIME_TRIAL or time_trial_budget_ticks <= 0:
		return 0
	return maxi(0, int((time_trial_budget_ticks - time_trial_elapsed) / TICKS_PER_SECOND))


# --- audio -------------------------------------------------------------------

## Play a registry sound through the `Audio` pool (P4.13): the voice, its slot volume and the
## `"Out of free sound ids"` drop all live there, so overlapping clicks no longer cut each other off.
## Every request is logged, which is what the headless checks read; without the autoload (a
## `--script` run) the request is only logged.
func play_sound(id: String) -> void:
	sounds_played.append(id)
	var audio := _autoload("Audio")
	if audio != null:
		audio.play(id)


# --- store -------------------------------------------------------------------

## Open the shop as a modal dialog over the tank. The original opens it from the tank screen's store
## button, which is not reconstructed yet (Q-0052), so the level binds the port-only `S` key. The tank
## pauses while the dialog is up, the same `Tank+0x94` gate the rest of the game reads.
func open_store() -> void:
	if store_screen != null and is_instance_valid(store_screen):
		return
	var screens := _autoload("Screens")
	if screens == null:
		return
	var store := StoreScreen.new()
	store.name = "StoreScreen"
	store.setup(self)
	if not screens.open_dialog(store):
		store.queue_free()
		return
	var game := _autoload("Game")
	if game != null:
		game.gameplay_paused = true
	store_screen = store



## `FUN_004F89A0`'s failure text (EV-0100): with `+0x238` still running it draws "Recharging..." at
## `(x + width/2 - 20, y - 10)` instead of transforming. The pet box is the 80x80 pet sheet, so the
## anchor is 20 px right of its centre and 10 above its top.
const PRESTO_RECHARGE_TEXT := "Recharging..."
const PRESTO_NOTICE_OFFSET := Vector2(20.0, -10.0)
## How long the notice stays up. The original draws it for the failed attempt itself; the port holds
## it 90 ticks (2.5 s at the recovered 36 Hz) so a key press is readable (port choice, EV-0182).
const PRESTO_NOTICE_TICKS := 0x5A


## The level's live Presto, or null. `FUN_0054C6F0` opens the picker from Presto's own object, so a
## tank without one has nothing to open.
func presto_pet() -> Pet:
	if tank == null:
		return null
	for entity in tank.entities_in(Sim.Phase.PETS):
		var pet := entity as Pet
		if pet != null and pet.index == PetScript.PRESTO:
			return pet
	return null


## The gate `FUN_0054C6F0` runs before it builds the dialog: a live Presto whose `+0x238` recharge
## has run out (`FUN_004F2650`), and no dialog already occupying the single slot.
func can_open_presto_picker() -> bool:
	if store_screen != null and is_instance_valid(store_screen):
		return false
	if presto_picker != null and is_instance_valid(presto_picker):
		return false
	var pet := presto_pet()
	return pet != null and pet.can_transform()


## Open the "PRESTO CHANGE-O" picker (`FUN_0054C6F0`: a `Sexy::PetDialog` on screen id 0x1F). The
## original opens it from the pet's own input handler, which EV-0106 records as untraced; the port
## binds the `P` key next to its existing `S` shop key (Q-0061) so the swap is reachable in play.
func open_presto_picker() -> bool:
	var presto := presto_pet()
	# `FUN_004F89A0`'s failure half: a live pet whose timer has not run out draws "Recharging..." and
	# returns. That is an attempt banner, not a permanent readout, so it is raised here.
	if presto != null and not presto.can_transform():
		show_presto_recharging(presto)
		return false
	if not can_open_presto_picker():
		return false
	var screens := _autoload("Screens")
	if screens == null:
		return false
	var picker := PrestoPickerScript.new()
	picker.name = "PrestoPicker"
	picker.setup(self, presto_pet())
	if not screens.open_dialog(picker):
		picker.queue_free()
		return false
	var game := _autoload("Game")
	if game != null:
		game.gameplay_paused = true
	presto_picker = picker
	return true


func close_presto_picker() -> void:
	if presto_picker != null and is_instance_valid(presto_picker):
		presto_picker.close()
	presto_picker = null


## Raise the "Recharging..." notice over `pet` for `PRESTO_NOTICE_TICKS` ticks.
func show_presto_recharging(pet: Pet) -> void:
	if pet == null or not is_instance_valid(pet):
		return
	_presto_notice = {"pet": pet, "ticks": PRESTO_NOTICE_TICKS}
	_sync_presto_notice()


func clear_presto_notice() -> void:
	_presto_notice.clear()
	if _presto_notice_label != null and is_instance_valid(_presto_notice_label):
		_presto_notice_label.queue_free()
	_presto_notice_label = null


func presto_notice_visible() -> bool:
	return not _presto_notice.is_empty()


func presto_notice_text() -> String:
	return PRESTO_RECHARGE_TEXT if presto_notice_visible() else ""


## Where the notice sits (`FUN_004F89A0`'s `x + width/2 - 20`, `y - 10`), computed from the pet so
## the headless checks can assert it with rendering off.
func presto_notice_position() -> Vector2:
	if _presto_notice.is_empty():
		return Vector2.ZERO
	var pet: Pet = _presto_notice["pet"]
	if pet == null or not is_instance_valid(pet) or pet.dead:
		return Vector2.ZERO
	return pet.position + PRESTO_NOTICE_OFFSET


## Age the notice and keep it on the pet. A dead or freed pet clears it at once, so no text can
## outlive the body it explains.
func _tick_presto_notice() -> void:
	if _presto_notice.is_empty():
		return
	var pet: Pet = _presto_notice["pet"]
	_presto_notice["ticks"] = int(_presto_notice["ticks"]) - 1
	if int(_presto_notice["ticks"]) <= 0 or pet == null or not is_instance_valid(pet) or pet.dead:
		clear_presto_notice()
		return
	_sync_presto_notice()


## The notice is world text over a Node2D, so it lives on the level's Hud CanvasLayer - the same
## layer the store bar and egg widget draw on - created on first use and freed by `clear`.
func _sync_presto_notice() -> void:
	var label := _presto_notice_label_node()
	if label == null:
		return
	label.text = PRESTO_RECHARGE_TEXT
	label.position = presto_notice_position()


func _presto_notice_label_node() -> Label:
	if not render or not is_inside_tree():
		return null
	if _presto_notice_label != null and is_instance_valid(_presto_notice_label):
		return _presto_notice_label
	var layer := get_node_or_null("Hud")
	if layer == null:
		return null
	var label := Label.new()
	label.name = "PrestoRecharging"
	label.text = PRESTO_RECHARGE_TEXT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))
	UiFont.apply(label, UiFont.SMALL_FONT)
	layer.add_child(label)
	_presto_notice_label = label
	return label


## `Tank::BuyItem` (P2.5 §3): resolve the row, check the price and the upgrade cap, spend, then apply.
## A row whose item has no ported effect (Q-0049) refuses without spending, so no money can vanish
## into an unimplemented purchase.
func buy_item(index: int) -> bool:
	if index < 0 or index >= tank_store.size():
		return false
	var row: Dictionary = tank_store[index]
	var id := int(row.get("slot", -1))
	# The egg piece is the level-completion purchase, not a store item (P2.6 §3/§5).
	if id == Progression.EGG_ITEM:
		return buy_egg()
	if id < 0 or not Store.is_available(id):
		return false
	# A 0 price is the table's "not recovered" marker, so the row refuses rather than selling for free.
	if not Store.price_known(row):
		return false
	var price := int(row.get("price", 0))
	if money < price:
		return false
	var kind := String(Store.item(id)["kind"])
	match kind:
		Store.KIND_FOOD_QUALITY:
			if food_quality >= Store.FOOD_QUALITY_MAX:
				return false
		Store.KIND_FOOD_QUANTITY:
			if food_quantity >= FOOD_QUANTITY_MAX:
				return false
		Store.KIND_WEAPON:
			if weapon_level >= Store.WEAPON_MAX:
				return false
		Store.KIND_STAR_POTION:
			if star_potion_armed:
				return false

	money -= price
	# The store's purchase click sits next to the money subtraction (P2.14 xref 0x520836).
	play_sound("SOUND_BUY")
	match kind:
		Store.KIND_FISH:
			# Shop-bought fish enter through the same wiring as starter and bred fish (G4):
			# without it a bought guppy never emits died/coin_due/breed_requested.
			_wire(tank.spawn_fish(int(Store.item(id)["species"]), _random_spawn_point()))
		Store.KIND_FOOD_QUALITY:
			food_quality += 1
		Store.KIND_FOOD_QUANTITY:
			food_quantity += 1
		Store.KIND_WEAPON:
			weapon_level += 1
		Store.KIND_STAR_POTION:
			star_potion_armed = true
	return true


## Levels end with the table back at its base prices (the wiki's "prices reset").
func reset_prices() -> void:
	for row in tank_store:
		row["price"] = int(row["base"])


## Challenge-mode inflation: every row's price rises by its own per-tick increment (P2.5 §3).
func inflate_prices(ticks: int) -> void:
	for row in tank_store:
		Store.inflate(row, ticks)


## The eight shelves the store screen draws (EV-0133).
const STORE_SHELF_COUNT := 8


## Stock the shop from P2.6 §3's per-tank table: which items a tank sells, at which store slot and
## for which price, with level 1/2 hiding the gated ones. This is the level's opening stock;
## `roll_stock()` overlays the one roller slot on top of it (Q-000?/EV-0141).
##
## There is no in-level reveal: `FUN_005409B0` builds a widget for every row with `A >= 0` in one
## `while (+0x2E0 < +0x2DC)` sweep (EV-0144), so the bar opens with the level's whole stock and the
## egg dome shows its price from the first frame. The earlier milestone table (EV-0185, a guide
## reading) left 1-1..1-5 with one or two domes and was withdrawn after the owner's 2026-11-16
## playtest (D-0019).
func stock_default_store() -> void:
	tank_store.clear()
	for row in Progression.store_rows(tank_index, level_index, game_mode):
		tank_store.append(row)


## Restock with the level-gated (`A = -1`) rows included, keeping the prices already rolled. This is
## Blip's `FUN_005409B0(i, 1)` unlock (EV-0094) and the F8 / REVEAL STORE debug action (D-0019).
## Returns whether any row was added.
func _unlock_store_rows() -> bool:
	var prices := {}
	for row in tank_store:
		prices[int(row.get("slot", -1))] = int(row.get("price", 0))
	var added := false
	tank_store.clear()
	for row in Progression.store_rows(tank_index, level_index, game_mode, true):
		if prices.has(int(row["slot"])):
			row["price"] = int(prices[int(row["slot"])])
		else:
			added = true
		tank_store.append(row)
	if store_bar != null:
		store_bar.refresh_if_changed()
	if egg_widget != null:
		egg_widget.refresh()
	return added
	if egg_widget != null:
		egg_widget.refresh()


## The stock roller (EV-0141, Q-0026): one slot is always a random **unowned** backdrop at
## 15000 shells, falling back to a random unowned pet once all six backdrops are owned.
## Buying the slot marks it owned (`_on_store_roller_bought`). The 100-249-tick refresh
## timer (`FUN_0052FEA0`) is the StoreScreen's job; this is the single roll.
func roll_stock() -> Dictionary:
	var owner := _profile()
	var unowned: Array[int] = []
	for i in Profile.BACKDROP_SLOTS:
		if i < owner.backdrops_owned.size() and owner.backdrops_owned[i] == 0:
			unowned.append(i)
	var row := {
		"slot": -1, "price": Profile.BACKDROP_PRICE, "base": Profile.BACKDROP_PRICE,
		"increment": 0, "present": 0, "kind_roll": 3,
	}
	if not unowned.is_empty():
		row["backdrop"] = unowned[tank.randi_below(unowned.size())]
	else:
		var unowned_pets: Array[int] = []
		for index: int in PetScript.DEFS:
			if not owner.owns_pet(index):
				unowned_pets.append(index)
		if unowned_pets.is_empty():
			row["kind_roll"] = 0
			return row
		row["kind_roll"] = 1
		row["pet"] = unowned_pets[tank.randi_below(unowned_pets.size())]
		row["price"] = 5000
		row["base"] = 5000
	tank_store.append(row)
	return row


func store_rows(ids: Array) -> void:
	tank_store.clear()
	for id: int in ids:
		tank_store.append(Store.row_for(id))


# --- persistence -------------------------------------------------------------

## The per-mode save path (EV-0142): `userdata/<stem><slot>.dat` with the stem from the
## mode and the slot from `profile+0x44`. `save_path` stays the headless default; the game
## refreshes it at level start so each mode keeps its own file (G10).
func current_save_path() -> String:
	return SaveFilesScript.path_for(game_mode, _profile().save_slot)


func refresh_save_path() -> void:
	save_path = current_save_path()


## Save the tank: fish records, the store table, the pet flags and the scalar block.
func save_game(path: String = "") -> Error:
	if path == "":
		path = save_path
	var save: TankSave = TankSnapshotScript.capture(tank, tank_index, level_index)
	while save.store.size() < TankSaveScript.STORE_ROWS:
		save.store.append({"slot": -1, "price": 0, "base": 0, "increment": 0, "present": 0})
	for i in mini(tank_store.size(), TankSaveScript.STORE_ROWS):
		save.store[i] = tank_store[i].duplicate()
	save.pet_flags = _capture_pet_flags()
	save.scalars = TankScalarsScript.capture(self)
	save.timestamp = int(Time.get_unix_time_from_system())
	return SaveFilesScript.write_tank_save(path, save)


## Load a save: scalars, store, pet flags and the fish. Live fish are replaced, not merged.
func load_game(path: String = "") -> bool:
	if path == "":
		path = save_path
	var save: TankSave = SaveFilesScript.read_tank_save(path)
	if save == null:
		return false
	# The header's tank and level come before the scalars: the scalar restore floors the egg pieces at
	# the *restored tank's* start (1, or 3 on tank 5), so it has to read the saved index, not the one
	# the session started with (D-0044). The tank index also feeds the name label, the egg price and
	# the store's restock tables, so a save from another tank would otherwise keep pricing the one
	# that started the session (D-0037). There is one copy, the live tank's `+0x3C8`, so this write
	# covers every reader (D-0038).
	tank_index = save.tank
	level_index = save.level
	TankScalarsScript.apply(save.scalars, self)
	tank_store = save.store.duplicate(true)
	# Saves written before D-0019 carry per-row `hidden` flags from the withdrawn reveal table; the bar
	# reads only the row's shelf now, so the key is dropped on load.
	for row: Dictionary in tank_store:
		row.erase("hidden")
	pet_flags = save.pet_flags.duplicate()
	# The saved rows are the fixed 17-byte records (slot, price, base, increment, present); the port's
	# own row keys are not in the file, so they are re-derived here (D-0040/D-0042). Without `shelf`
	# the bar finds no row for any shelf and draws seven empty domes.
	_restore_store_rows()
	_refresh_tank_label()
	for entity in tank.entities_in(Sim.Phase.FISH):
		tank.despawn(entity)
	TankSnapshotScript.restore(tank, save)
	# The scalar block restored the type and countdown; point the live clock at the restored type
	# without resetting the countdown (G10).
	_sync_wave_selection()
	# Everything below belonged to the tank that was just replaced, and the `Level` outlives the tank, so
	# each one has to be re-derived or dropped here (D-0037).
	#
	# The hint: only the tick cache has to go. It belongs to the tank that drew it, and a restored
	# `age_ticks` equal to it would hold the pre-load wording until the clock moved on. `_hint_shown`
	# still describes the label exactly as before the load, so leaving it alone is what keeps that cache
	# honest - the next `_refresh_hint()` compares against it and writes only if the restored tank reads
	# differently.
	_hint_tick = -1
	# The egg dome prices off the tank and level; the save may name different ones.
	egg_price = Progression.egg_price(tank_index, level_index, game_mode)
	# Time Trial's budget belongs to the tank the save names (300 s on tank 1, 600 s on the rest), so a
	# save from another tank cannot keep the previous run's; the elapsed clock itself came back from
	# the block's `+0x3B0` seconds in `TankScalars.apply` (D-0045).
	if game_mode == MODE_TIME_TRIAL:
		time_trial_budget_ticks = time_trial_budget_seconds(tank_index) * TICKS_PER_SECOND
	# The base keeps no per-level "completed" flag: `+0x43C >= 4` **is** completion (P2.5 §6 step 7,
	# P2.9 §10), and the header's `+0x2A5` is the whole-tank latch that starts the bonus round. So this
	# is derived, not saved - otherwise a finished save stays buyable and a live one stays blocked.
	completed = egg_pieces >= Progression.EGG_PIECES_TO_COMPLETE
	# A composite recipe hands out one member per wave request, so a load can catch it half-delivered;
	# the queued member belongs to the old tank's roll and must not spawn into the restored one.
	_composite_selection = -1
	_composite_pending.clear()
	# The "Recharging..." notice points at a pet body, and pet bodies are not part of a tank save.
	clear_presto_notice()
	# The save may name another backdrop, and the level keeps the sprite it was built with.
	_add_backdrop()
	return true


## Put the port-only row keys back on rows that came from a save. The 17-byte record carries only
## slot, price, base, increment and present, so:
## - `shelf` (which dome draws the row) is matched by slot id against the stock table for the tank and
##   level the header names; the hidden shelves are included, so a row Blip unlocked keeps its dome;
## - `free` is the tank-5 egg's recovered 0 price, the same test `Progression.store_rows` makes.
## A row the table no longer sells (the store roller's `slot -1`) keeps the bare record and draws no
## dome, exactly as before it was saved.
func _restore_store_rows() -> void:
	var shelves := {}
	for row in Progression.store_rows(tank_index, level_index, game_mode, true):
		shelves[int(row["slot"])] = int(row["shelf"])
	for row in tank_store:
		var slot := int(row.get("slot", -1))
		# `shelves` holds only real item ids, so the roller's -1 simply misses.
		if shelves.has(slot):
			row["shelf"] = int(shelves[slot])
		row["free"] = slot == Progression.EGG_ITEM and int(row.get("price", 0)) == 0


func _capture_pet_flags() -> Array[int]:
	var flags: Array[int] = []
	flags.resize(TankSaveScript.PET_FLAGS)
	flags.fill(0)
	for entity in tank.entities_in(Sim.Phase.PETS):
		var pet := entity as Pet
		if pet != null and pet.index >= 0 and pet.index < TankSaveScript.PET_FLAGS:
			flags[pet.index] = 1
	return flags


# --- debug (port-only) -------------------------------------------------------

## How much the debug money cheat adds per press.
const DEBUG_MONEY_STEP := 1000


## The tank MENU button's request. The original's `FUN_0051B6C0(99)` removes the tank screen and
## calls `FUN_00552100()` to rebuild the main menu; `Main` owns that transition and the save.
func request_menu() -> void:
	menu_requested.emit()


## Dispatch one debug action. Returns true when it changed something. These actions are
## **port-only** (D-0014): the shipped game has no cheat console recovered, so nothing here is
## claimed as original behavior. The panel and the F2..F10 keys both come through this one entry.
func debug_action(action: StringName) -> bool:
	match action:
		&"money":
			return debug_add_money()
		&"grow":
			return debug_grow_all()
		&"feed":
			return debug_feed_all()
		&"egg":
			return debug_egg_piece()
		&"weapon":
			return debug_max_weapon()
		&"reveal":
			return debug_reveal_store()
		&"guppy":
			return debug_spawn_guppy()
		&"next_level":
			return debug_next_level()
	return false


## Port-only NEXT LEVEL (D-0018): walk the profile one level on, rolling into the next tank after
## level 5, and ask the owner to restart. The Hatch/Pets/Bonus cards are skipped on purpose, so a
## playtest can reach a specific tank without replaying the flow.
func debug_next_level() -> bool:
	if tank == null:
		return false
	var owner := _profile()
	var next_level := int(owner.level) + 1
	if next_level > Progression.LEVELS:
		owner.tank = mini(int(owner.tank) + 1, Progression.TANKS)
		owner.level = 1
	else:
		owner.level = next_level
	skip_level_requested.emit()
	return true


## Add shells through the normal clamped `AddMoney` path.
func debug_add_money(amount: int = DEBUG_MONEY_STEP) -> bool:
	if amount <= 0 or money >= MONEY_MAX:
		return false
	add_money(amount)
	if store_bar != null:
		store_bar.refresh()
	return true


## Advance every growable fish one step (stage < 2 -> +1, then the stage-4 overshoot form). The
## normal `grew` signal still fires, so the store milestones reveal exactly as they do in play.
func debug_grow_all() -> bool:
	if tank == null:
		return false
	var changed := false
	for entity in tank.entities_in(Sim.Phase.FISH):
		var fish := entity as Fish
		if fish != null and fish.debug_grow():
			changed = true
	return changed


## Fill every fish to its species' eat cap.
func debug_feed_all() -> bool:
	if tank == null:
		return false
	var changed := false
	for entity in tank.entities_in(Sim.Phase.FISH):
		var fish := entity as Fish
		if fish != null and fish.debug_feed():
			changed = true
	return changed


## Buy the next egg piece for free. The fourth piece completes the level through the normal path,
## which is also the quickest way to exercise the Hatch/Pets/Bonus flow.
func debug_egg_piece() -> bool:
	if completed or egg_pieces >= Progression.EGG_PIECES_TO_COMPLETE:
		return false
	egg_pieces += 1
	if egg_pieces >= Progression.EGG_PIECES_TO_COMPLETE:
		complete_level()
		return true
	if egg_widget != null:
		egg_widget.refresh()
	if store_bar != null:
		store_bar.refresh()
	return true


## Jump the weapon/capacity field to its recovered maximum (level 12, EV-0151/EV-0174).
func debug_max_weapon() -> bool:
	if tank == null or weapon_level >= Store.WEAPON_MAX:
		return false
	weapon_level = Store.WEAPON_MAX
	if store_bar != null:
		store_bar.refresh()
	return true


## Blip's instant unlock on demand: `FUN_005409B0(i, 1)` for every item, which adds the level-gated
## rows to a bar that is otherwise already open (D-0019). Reports whether anything changed.
func debug_reveal_store() -> bool:
	if tank == null:
		return false
	var had_latch := tank.store_locked
	tank.store_locked = false
	return _unlock_store_rows() or had_latch


## Add one guppy in the normal spawn band, wired like every other spawned fish.
func debug_spawn_guppy() -> bool:
	if tank == null:
		return false
	spawn_guppy(_random_spawn_point())
	return true


## Show/hide the panel. Returns its new visibility; false when rendering is off (no panel).
func toggle_debug_panel() -> bool:
	if debug_panel == null:
		return false
	debug_panel.visible = not debug_panel.visible
	return debug_panel.visible


func _on_debug_action(action: StringName) -> void:
	debug_action(action)


# --- input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	# A modal dialog owns input while it is up (Options, store, Presto): the tank must not drop
	# food behind it or run its F1..F10/S/P hotkeys. Mouse clicks usually stop in the full-rect
	# dialog already; this also covers keyboard events.
	var screens := _autoload("Screens")
	if screens != null and screens.dialog() != null:
		return
	if event is InputEventMouseMotion and holding_fire:
		aim(get_global_mouse_position())
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		holding_fire = event.pressed
		if event.pressed:
			fire_target = get_global_mouse_position()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				toggle_debug_panel()
			KEY_F2:
				debug_action(&"money")
			KEY_F3:
				debug_action(&"grow")
			KEY_F4:
				debug_action(&"feed")
			KEY_F5:
				save_game()
			KEY_F6:
				debug_action(&"egg")
			KEY_F7:
				debug_action(&"weapon")
			KEY_F8:
				debug_action(&"reveal")
			KEY_F9:
				load_game()
			KEY_F10:
				debug_action(&"guppy")
			KEY_S:
				open_store()
			KEY_P:
				open_presto_picker()
		return
	if event is not InputEventMouseButton:
		return
	var click := event as InputEventMouseButton
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var at := get_global_mouse_position()
	fire_target = at
	# Click order (P2.10 §1): larvae (`Tank+0xDC`), missiles (`Tank+0xF4`), aliens, coins, feed.
	# Every resolved click draws a laser spark (`FUN_00543640`); the feed path does not.
	if try_hit_larva(at):
		spawn_laser(at)
		return
	if try_hit_projectile(at):
		spawn_laser(at)
		return
	if try_shoot(at):
		spawn_laser(at)
		return
	if try_collect(at):
		spawn_laser(at)
		return
	drop_food(at)


# --- rendering ---------------------------------------------------------------

func _process(_delta: float) -> void:
	if not render or tank == null:
		return
	# Held fire follows the live cursor (the event path only sees motion, which stops at the edges).
	# A paused tank keeps drawing but must not re-aim: the modal owns the pointer.
	if holding_fire and not tank.is_paused():
		aim(get_global_mouse_position())
	_sync_visuals()
	_sync_fx()
	_refresh_hint()


## The FX layer: one small tinted square per particle/laser spark. Squares keep the
## original's "spawn a particle, age it, remove it" shape without a particle system;
## the sheet-level gore/splat art (P4.4) is still a Q-0036-adjacent gap, not faked here.
var _fx_layer: Node2D = null
var _fx_dot: Texture2D = null


func _sync_fx() -> void:
	if _fx_layer == null:
		_fx_layer = Node2D.new()
		_fx_layer.name = "FxLayer"
		_fx_layer.z_index = 50
		add_child(_fx_layer)
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_fx_dot = ImageTexture.create_from_image(img)
	var wanted: Array[Dictionary] = []
	for p in particles:
		wanted.append({"pos": p["pos"], "kind": String(p["kind"]), "life": int(p["life"])})
	for s in laser_sparks:
		wanted.append({"pos": s["pos"], "kind": "laser", "life": int(s["life"])})
	# `queue_free()` only queues the node: it stays a child until the frame ends, so a loop that
	# waits for `get_child_count()` to shrink never terminates. That spin froze the main thread - the
	# app then could not close on its own and had to be killed - so the surplus dots are detached
	# first and freed afterwards, and `dots` is the working list both loops and the update walk use.
	var dots: Array[Node] = _fx_layer.get_children()
	while dots.size() > wanted.size():
		var extra: Node = dots.pop_back()
		_fx_layer.remove_child(extra)
		extra.queue_free()
	while dots.size() < wanted.size():
		var dot := Sprite2D.new()
		dot.texture = _fx_dot
		dot.centered = true
		_fx_layer.add_child(dot)
		dots.append(dot)
	for i in wanted.size():
		var dot := dots[i] as Sprite2D
		dot.position = wanted[i]["pos"]
		match String(wanted[i]["kind"]):
			"smoke":
				dot.modulate = Color(0.8, 0.8, 0.8, 0.6)
				dot.scale = Vector2.ONE * (0.6 + float(int(wanted[i]["life"])) / 30.0)
			"burst":
				dot.modulate = Color(1.0, 0.85, 0.3)
				dot.scale = Vector2.ONE * 0.8
			_:
				dot.modulate = Color(0.5, 0.95, 1.0)
				dot.scale = Vector2(4.0, 2.0)


func _on_entity_spawned(entity: SimEntity) -> void:
	# The pickup path is simulation, not drawing: connect it even when rendering is off.
	if entity is Coin:
		(entity as Coin).collected.connect(_on_coin_collected)
		(entity as Coin).banked.connect(_on_coin_banked)
	if entity is Larva:
		(entity as Larva).shells_payout.connect(_on_larva_payout)
		(entity as Larva).burst_requested.connect(_on_larva_burst)
	if not render:
		return
	var visual := _make_visual(entity)
	if visual == null:
		return
	# `_make_visual` adds the sprite to the entity itself.
	entity.set_meta("visual", visual)


## One sprite per entity, built from the content registry. Returns null while the loading phase has
## not reached the image yet.
##
## The frame is chosen per tick, not by an `AnimatedSprite2D` clock: `AnimState` reproduces the
## resource's own playback metadata, and each sprite's playback starts at the tick its entity spawned,
## so two fish no longer paddle in step. Sheets that declare no `anim` (the fish body, `FOOD`,
## `MONEY`) are entity-driven, which is why the fish column comes from `AnimState.column_at`.
func _make_visual(entity: SimEntity) -> Sprite2D:
	var body_row := -1
	var source_id := ""
	if entity is Fish:
		var fish := entity as Fish
		# The sheet is the recovered state sheet (swim/eat + hungry) and the row is the species'
		# own (guppy stages, carnivore row 4) - EV-0164.
		source_id = fish.draw_image()
		body_row = fish.sprite_row()
	elif entity is Food:
		source_id = FOOD_IMAGE
	elif entity is Coin:
		# The coin picks its own sheet: `MONEY` in a normal tank, `SHELLS`/`MONEYBAG`/`PEARL`
		# per kind (EV-0162).
		source_id = (entity as Coin).sprite_image()
	elif entity is Pet:
		source_id = (entity as Pet).image_id()
	elif entity is DeadFish:
		# P2.4 §4: the corpse draws `SMALLDIE`, the death twin of the state sheet, at the species'
		# row and `sprite_frame()`'s cell (EV-0164 binds the row; Q-0043 keeps the cell rule).
		var corpse := entity as DeadFish
		source_id = DEATH_IMAGE
		body_row = Fish.row_for(corpse.species, corpse.corpse_id)
	elif entity is Alien:
		# P2.8 §3: the kind -> image binding includes Cyrax (BOSS) and the 80x80 minis/Bilaterus.
		source_id = (entity as Alien).image_id()
	elif entity is Projectile:
		# P2.10 §5: the three projectile kinds bind the missile, energy-ball and balls sheets.
		source_id = (entity as Projectile).image_id()
	elif entity is Larva:
		# P2.10 §5.5: the larva shares the family sheets (Q-0023 keeps the binding open).
		source_id = (entity as Larva).image_id()
	else:
		return null
	if _content == null or not _content.has_image(source_id):
		return null
	var res: ImageRes = _content.image(source_id)
	if res == null:
		return null

	var sprite := Sprite2D.new()
	sprite.name = "Visual"
	# Fish, corpses and pets draw from the top-left corner of their bounds box; aliens and shots
	# fill their box, and the entity position is its centre (P2.8 §2.1), so those are centred.
	# Coins are drawn from their box's top-left like fish (`Coin.position` is the 80x80 box origin and
	# the pickup square sits at `+36,+36`), so a centred coin sprite drew 36 px away from its own hit
	# box and a click on the visible coin missed it.
	sprite.centered = not (entity is Fish or entity is DeadFish or entity is Pet or entity is Coin)
	var anim := AnimState.new()
	anim.setup(res, _sim_tick())
	sprite.set_meta("anim", anim)
	sprite.set_meta("body_row", body_row)
	sprite.set_meta("source", source_id)
	_draw_entity_frame(entity, sprite, anim)
	entity.add_child(sprite)
	if entity is Alien:
		_make_health_bar(entity as Alien)
	return sprite


func _sim_tick() -> int:
	return _sim.tick_count if _sim != null else 0





## Pick this tick's texture. The sheet is keyed once and cached per `(id, cell)`, so the per-frame
## path is a dictionary lookup rather than a colour-key pass.
func _draw_entity_frame(entity: SimEntity, sprite: Sprite2D, anim: AnimState) -> void:
	if entity is Fish:
		var fish := entity as Fish
		# The state sheet changes with the eat timer and the hunger flag (EV-0164), so the sprite
		# takes the new sheet in place instead of being rebuilt.
		var source := fish.draw_image()
		if source != String(sprite.get_meta("source", "")):
			sprite.set_meta("source", source)
		var row := fish.sprite_row()
		var col := AnimState.column_at(anim.started, _sim_tick(), GUPPY_COLS)
		sprite.texture = _keyed_cell(source, row * GUPPY_COLS + col)
		return
	if entity is DeadFish:
		# The corpse's frame is its own countdown rule, not a clock: it walks the death cells as the
		# stage counter falls (P2.4 §4), inside the species' own row (EV-0164).
		var corpse := entity as DeadFish
		var death_row := int(sprite.get_meta("body_row", 0))
		sprite.texture = _keyed_cell(String(sprite.get_meta("source", DEATH_IMAGE)),
			death_row * GUPPY_COLS + corpse.sprite_frame())
		return
	if entity is Pet:
		# The sheet's own metadata plays the swim loop (`loop`/`pingpong`, `framedelay`); the pet does
		# not pick a column itself (Q-0044 keeps the per-pet animation cells open).
		sprite.texture = _keyed_cell(String(sprite.get_meta("source", "")), anim.frame_at(_sim_tick()))
		return
	if entity is Alien:
		# Alien sheets declare their own loop. Bilaterus is the exception: its sheet has no `anim`
		# metadata, so use its first cell rather than cycling unrelated body/head cells (P2.8 §3).
		var alien := entity as Alien
		var source := String(sprite.get_meta("source", ""))
		if anim.res != null and anim.res.anim == "":
			sprite.texture = _keyed_cell(source, 0)
		else:
			sprite.texture = _keyed_cell(source, anim.frame_at(_sim_tick()))
		_update_health_bar(alien)
		return
	if entity is Projectile:
		# The projectile sheets have no recovered playback metadata; the first cell is their base
		# art. The missing homing body still owns the direction/animation choice (Q-0041).
		sprite.texture = _keyed_cell(String(sprite.get_meta("source", "")), 0)
		return
	if entity is Larva:
		sprite.texture = _keyed_cell(String(sprite.get_meta("source", "")), 0)
		return
	if entity is Food:
		# The simulation counter picks the frame; `anim_cycle` 3/4 means the first 3/4 rows.
		var food := entity as Food
		sprite.texture = _keyed_cell(String(sprite.get_meta("source", "")), _food_frame(food))
		return
	if entity is Coin:
		# The recovered draw (`FUN_004DD7A0`) blits one cell of the coin's own sheet: the column is the
		# coin's animation frame, the row is the kind's row in that sheet (EV-0162). Single-cell art
		# (`PEARL`, `MONEYBAG`) has no row.
		var coin := entity as Coin
		var id := String(sprite.get_meta("source", coin.sprite_image()))
		var row := coin.sprite_row()
		_draw_sparks(entity, coin, anim)
		if row < 0:
			sprite.texture = _keyed_cell(id, 0)
			return
		var columns := _sheet_columns(id)
		var column := AnimState.column_at(anim.started, _sim_tick(), columns)
		sprite.texture = _keyed_cell(id, row * columns + column)


## The 0x11 drop is the one coin with a second sprite: `IMAGE_SPARKS` at (10,-10) over the
## single-cell `MISCITEMS`, stepped by the coin's own column (EV-0162). Created on demand, so a kind
## that stops drawing it cannot leave the overlay behind.
func _draw_sparks(entity: SimEntity, coin: Coin, anim: AnimState) -> void:
	var sparks := entity.get_node_or_null("Sparks") as Sprite2D
	if not coin.draws_sparks():
		if sparks != null:
			sparks.queue_free()
		return
	if sparks == null:
		sparks = Sprite2D.new()
		sparks.name = "Sparks"
		sparks.position = Coin.SPARKS_OFFSET
		sparks.set_meta("source", Coin.IMAGE_SPARKS)
		entity.add_child(sparks)
	sparks.texture = _keyed_cell(Coin.IMAGE_SPARKS,
		AnimState.column_at(anim.started, _sim_tick(), _sheet_columns(Coin.IMAGE_SPARKS)))


## The bar is a pair of sprites inside the alien's box: the red fill (width-clipped to hp) under
## the full-length glass tube. It is created once per alien and only re-cut per frame.
func _make_health_bar(alien: Alien) -> Node2D:
	var existing := alien.get_node_or_null("HealthBar") as Node2D
	if existing != null:
		return existing
	var bar := Node2D.new()
	bar.name = "HealthBar"
	var box := alien.box_size()
	var half := box * 0.5
	# P2.9 §5: x = 10, y = box height - 3, both inside the box's own top-left corner.
	bar.position = Vector2(-half + HEALTH_BAR_X, -half + box - HEALTH_BAR_BOTTOM_INSET)
	var fill := Sprite2D.new()
	fill.name = "Fill"
	fill.centered = false
	fill.texture = _keyed_cell(HEALTH_BAR_FILL_IMAGE, 0)
	var tube := Sprite2D.new()
	tube.name = "Tube"
	tube.centered = false
	tube.texture = _keyed_cell(HEALTH_BAR_TUBE_IMAGE, 0)
	bar.add_child(fill)
	bar.add_child(tube)
	alien.add_child(bar)
	_update_health_bar(alien)
	return bar


## The recovered draw gate (P2.9 §5): Cyrax always has a bar; ordinary aliens only when
## `Tank+0x178` is set and the tank is not tank 5.
func _alien_health_visible(alien: Alien) -> bool:
	if alien.kind == int(BOSS_KINDS["cyrax"]):
		return true
	return tank.show_alien_health and int(tank.tank_index) != 5


## Cut the fill to `tube_w * hp / hp0` (clamped), and show/hide the whole bar from the draw gate.
func _update_health_bar(alien: Alien) -> void:
	var bar := alien.get_node_or_null("HealthBar") as Node2D
	if bar == null:
		return
	var max_hp := alien.initial_hp()
	bar.visible = max_hp > 0 and _alien_health_visible(alien)
	if not bar.visible:
		return
	var fill := bar.get_node_or_null("Fill") as Sprite2D
	if fill == null or fill.texture == null:
		return
	var ratio := clampf(float(alien.hp) / float(max_hp), 0.0, 1.0)
	fill.region_enabled = true
	fill.region_rect = Rect2(0.0, 0.0, roundf(fill.texture.get_width() * ratio),
		fill.texture.get_height())


## One keyed cell of a sheet, built once and kept for the session.
var _cell_cache: Dictionary = {}


## A sheet's column count, so a coin cell is `row * columns + column` - `MONEY` is 10 wide and
## `SHELLS` 20, and the recovered blit sources `(column * cellW, row * cellH)` (EV-0162).
func _sheet_columns(id: String) -> int:
	if _content == null or not _content.has_image(id):
		return 1
	var res: ImageRes = _content.image(id)
	if res == null:
		return 1
	return maxi(res.cols, 1)


func _keyed_cell(id: String, cell: int) -> Texture2D:
	if _content == null or not _content.has_image(id):
		return null
	var res: ImageRes = _content.image(id)
	if res == null:
		return null
	var index := clampi(cell, 0, maxi(res.frame_count - 1, 0))
	var key := "%s#%d" % [id, index]
	if _cell_cache.has(key):
		return _cell_cache[key]
	var texture := SpriteKey.keyed(res.frame(index))
	_cell_cache[key] = texture
	return texture


## The pellet has no free-running animation: `anim_frame` is the simulation's own counter, advanced
## one per tick and wrapped at `anim_cycle * 10 - 1`; `Food.column()` turns it into the tumbler
## column of the `FOOD` sheet, each column held `anim_cycle` ticks (D-0024).
## `FOOD` is 10x5 and its rows are food kinds, so the drawn frame is `row * 10 + column`.
##
## Which row a quality/variant draws is **not** recovered (Q-0051): the port follows the sheet's own
## order - row 0 brown (quality 0), 1 green, 2 red, 3 the star-potion flask, 4 the breeding droplet.
## That mapping is an inference from the art and the quality values (3 = star potion, variant 2 =
## breeding pellet), not a traced constant.
const FOOD_SHEET_COLUMNS := 10
const FOOD_ROW_STAR := 3
const FOOD_ROW_BREEDING := 4


func _food_row(food: Food) -> int:
	if int(food.variant) == Food.VARIANT_BREEDING:
		return FOOD_ROW_BREEDING
	return clampi(int(food.quality), 0, FOOD_ROW_STAR)


func _food_frame(food: Food) -> int:
	return _food_row(food) * FOOD_SHEET_COLUMNS + food.column()


func _sync_visuals() -> void:
	var tick := _sim_tick()
	for entity: SimEntity in tank.entities:
		if not is_instance_valid(entity):
			continue
		# Entities drawn without a sprite (a projectile, a shot) simply have no visual.
		if not entity.has_meta("visual"):
			continue
		var visual: Sprite2D = entity.get_meta("visual")
		if visual == null or not is_instance_valid(visual) or not visual.has_meta("anim"):
			continue
		var anim: AnimState = visual.get_meta("anim")
		if anim == null:
			continue
		if entity is DeadFish:
			# The corpse keeps the fish's box and facing; it is drawn but does not swim.
			var corpse := entity as DeadFish
			visual.position = Vector2(20.0, 20.0) + Vector2(20.0, 0.0) * (1.0 if corpse.facing < 0 else 0.0)
			visual.flip_h = corpse.facing < 0
		elif entity is Fish:
			var fish := entity as Fish
			# Fish box offsets: the drawn 40x40 art sits in the middle of the 80x80 bounds box.
			visual.position = Vector2(20.0, 20.0) + Vector2(20.0, 0.0) * (1.0 if fish.flip else 0.0)
			visual.flip_h = fish.flip
		else:
			visual.position = Vector2.ZERO
		_draw_entity_frame(entity, visual, anim)
