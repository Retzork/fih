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

## `Tank::AddMoney` clamps the wallet at 9,999,999 (P2.5 §5).
const MONEY_MAX := 9999999
## Two guppies, as a tank start; the real starting population is level data (P2.6, P4.6).
const STARTING_FISH := 2
const SPAWN_MIN := Vector2(80.0, 160.0)
const SPAWN_MAX := Vector2(480.0, 300.0)
## The drawn tank rect (`AQUARIUM1..6` are 640x480).
const TANK_SIZE := Vector2(640.0, 480.0)
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
const COIN_IMAGE := "IMAGE_MONEY"
## The coin sheet's animation columns (`MONEY` is 10x6).
const COIN_COLUMNS := 10
## The alien/boss HP bar (P2.9 §5): the `HEALTHBARTUBE` glass over the `HEALTHBAR` fill, both
## 127x15, inside the alien's own box at x 10 and y = box height - 3. The fill is clipped to
## `tube_w * hp / hp0`.
const HEALTH_BAR_FILL_IMAGE := "IMAGE_HEALTHBAR"
const HEALTH_BAR_TUBE_IMAGE := "IMAGE_HEALTHBARTUBE"
const HEALTH_BAR_X := 10.0
const HEALTH_BAR_BOTTOM_INSET := 3.0

const TankSaveScript := preload("res://scripts/persistence/tank_save.gd")
const SaveFilesScript := preload("res://scripts/persistence/save_files.gd")
const TankScalarsScript := preload("res://scripts/persistence/tank_scalars.gd")
const TankSnapshotScript := preload("res://scripts/persistence/tank_snapshot.gd")

var tank: Tank = null
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
## The in-tank store bar along the top of the aquarium (P4.5/P4.6), null until `_ready` builds it
## with rendering on.
var store_bar: StoreBar = null
## The 24 per-pet presence flags as last saved. Pet bodies are only partly implemented, so a load
## records the flags without spawning the pets back (P4.7).
var pet_flags: Array[int] = []
## `Tank+0x440`: the next manual drop is a star potion pellet (P2.3 §2).
var star_potion_armed := false
## Where F5/F9 write and read (the Adventure slot of the active profile).
var save_path := "userdata/adv1.dat"
## The level within the tank (1..5); the save header stores it.
var level_index := 1
## The tank within the adventure (1..5), `Tank+0x3C8`.
var tank_index := 1
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

## The game mode the selector writes (P2.12 EV-0131): 0 adventure, 1 time trial, 4 challenge,
## 5 virtual tank. Only mode 4 inflates store prices.
const MODE_CHALLENGE := 4
var game_mode := 0

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
## How many waves have spawned this session (the original's `Tank+0x45C`).
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
## Held-fire state (SPECS §3.5): set while the left button is down; the period decides the cadence.
var holding_fire := false
var fire_cooldown := 0
## Where held fire aims (the last left-button press position).
var fire_target := Vector2.ZERO
var _sim: Node = null
var _hud: Label = null
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
	_sim = sim_node
	tank.setup(sim_node, seed_value)
	tank.entity_spawned.connect(_on_entity_spawned)
	_ensure_wave()
	# The egg widget is built even when rendering is off, so the headless checks can drive the same
	# click path the game uses (P4.6, G14).
	egg_widget = EggWidgetScript.new()
	egg_widget.name = "EggWidget"
	add_child(egg_widget)
	egg_widget.setup(self)
	for i in STARTING_FISH:
		spawn_guppy(_random_spawn_point())
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
	_hud = Label.new()
	# The debug/HUD line clears the in-tank store bar, whose slots start at y 3 and are 58 tall.
	_hud.position = Vector2(8.0, 66.0)
	layer.add_child(_hud)
	# The in-tank store bar (`FUN_005409B0`, Q-0018): the row of buy buttons above the tank.
	store_bar = StoreBar.new()
	store_bar.name = "StoreBar"
	layer.add_child(store_bar)
	store_bar.setup(self)
	if egg_widget != null:
		egg_widget.refresh()
	_update_hud()
	_add_backdrop()


## The tank backdrop (`+0x3E8`, 1..6 -> `TANKBACKDROP1..6`), drawn behind every entity.
func _add_backdrop() -> void:
	if _content == null or tank == null or has_node("Backdrop"):
		return
	# The 640x480 tank art is `AQUARIUM1..6`; the `TANKBACKDROP` thumbnails (190x121) are the menu
	# previews, so they are only a fallback and are scaled to the tank rect when used.
	var id := "IMAGE_AQUARIUM%d" % backdrop
	if not _content.has_image(id):
		id = "IMAGE_TANKBACKDROP%d" % backdrop
	if not _content.has_image(id):
		return
	var res: ImageRes = _content.image(id)
	if res == null or res.texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = "Backdrop"
	sprite.centered = false
	sprite.texture = res.texture
	sprite.scale = Vector2(TANK_SIZE.x / res.texture.get_width(), TANK_SIZE.y / res.texture.get_height())
	sprite.z_index = -100
	add_child(sprite)


# --- entities ----------------------------------------------------------------

## Spawn a guppy and wire its events. `stage` -1 keeps the species default (stage 0).
func spawn_guppy(pos: Vector2, stage: int = -1, facing: int = 0) -> Fish:
	var fish: Fish = tank.spawn_fish(FishScript.Species.GUPPY, pos, stage, facing)
	_wire(fish)
	return fish


## Every fish the level owns answers the same three events. The death path goes through a corpse, not
## straight to a successor (P2.4 §4).
func _wire(fish: Fish) -> void:
	fish.died.connect(_on_fish_died)
	fish.breed_requested.connect(_on_breed)
	fish.coin_due.connect(_on_coin_due)


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
func drop_food(pos: Vector2) -> Food:
	if non_special_food() >= food_quantity:
		return null
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
	tank.aliens_present = true


func _on_alien_attack(shot_kind: int, at: Vector2, target: Node2D) -> void:
	tank.spawn_projectile(shot_kind, at, target)


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
	reset_prices()
	tank.tank_index = tank_index
	spawn_owned_pets()
	# The level schedule owns the wave start: tank 1 level 1 stays at 0, tank 1 level 2 starts with
	# 1750 ticks left, and every other level uses its recovered type (P2.6 §8).
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
		return start_boss(profile_counter)
	return null


## Pets join the tank with the session (P2.7 §2.2, branch A): every owned flag `FUN_00501410(i)` spawns
## its pet through `FUN_00544A90(index, -1, ...)`, which rolls x 105..369 and y 20..539. Branch B
## (the profile's selected-pet bytes) needs `profile+0x18`/mode, which is still open (Q-0013 area), so
## the owned flags are the port's source. Returns how many pets entered.
func spawn_owned_pets() -> int:
	if tank == null:
		return 0
	var owner := _profile()
	var spawned := 0
	for index: int in PetScript.DEFS:
		if not owner.owns_pet(index):
			continue
		var at := Vector2(
			tank.rng.randf_range(PET_SPAWN_MIN.x, PET_SPAWN_MAX.x),
			tank.rng.randf_range(PET_SPAWN_MIN.y, PET_SPAWN_MAX.y)
		)
		tank.spawn_pet(index, at)
		spawned += 1
	return spawned


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
	if game_mode == Progression.MODE_CHALLENGE:
		if tank_no >= 1 and tank_no <= Profile.CHALLENGE_SLOTS:
			owner.challenge_unlocks[tank_no - 1] = 1
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
	return boss


## Q-0047: the minion kind is not named by the note; a Sylvester stands in for it.
func _on_boss_minion(at: Vector2) -> void:
	wire_alien(tank.spawn_alien(0x01, at))


func _on_boss_pulse(at: Vector2) -> void:
	wire_alien(tank.spawn_alien(0x01, at))


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
	_update_hud()


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


func _on_coin_due(fish: Fish) -> void:
	# Q-0036: the stage -> kind table is still open. Kind 1 (15 shells) is the placeholder.
	tank.spawn_coin(1, fish.position + Vector2(20.0, 20.0))


func _on_coin_collected(_coin, amount: int) -> void:
	add_money(amount)


## Hold-to-fire (SPECS §3.5): level 12 unlocks it at `11 - level/2` ticks, floored at 100 ms
## (10 ticks), which is what the 5-tick value at level 12 would otherwise beat.
func hold_fire_period() -> int:
	if weapon_level < Store.WEAPON_MAX:
		return 0
	return maxi(11 - weapon_level / 2, 10)


## Held fire: level 12 fires every `hold_fire_period()` ticks at the last press position. The re-test
## order is the spec's missiles -> aliens (there is no larvae entity in the port yet).
## Retarget held fire (the live cursor while the button is held).
func aim(point: Vector2) -> void:
	fire_target = point


func fire_at(point: Vector2) -> bool:
	if try_hit_projectile(point):
		return true
	return try_shoot(point)


func _on_sim_tick(_tick: int) -> void:
	if game_mode == MODE_CHALLENGE:
		inflate_prices(1)
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
			tank.spawn_fish(int(Store.item(id)["species"]), _random_spawn_point())
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
## for which price, with level 1/2 hiding the gated ones. The roller that re-rolls the shelves every
## 100-249 ticks (`FUN_0052F0D0`) is still open (Q-0052), so this is the level's opening stock.
func stock_default_store() -> void:
	tank_store.clear()
	for row in Progression.store_rows(tank_index, level_index, game_mode):
		tank_store.append(row)


func store_rows(ids: Array) -> void:
	tank_store.clear()
	for id: int in ids:
		tank_store.append(Store.row_for(id))


# --- persistence -------------------------------------------------------------

## Save the tank: fish records, the store table, the pet flags and the scalar block.
func save_game(path: String = save_path) -> Error:
	var save: TankSave = TankSnapshotScript.capture(tank, int(tank.tank_index), level_index)
	while save.store.size() < TankSaveScript.STORE_ROWS:
		save.store.append({"slot": -1, "price": 0, "base": 0, "increment": 0, "present": 0})
	for i in mini(tank_store.size(), TankSaveScript.STORE_ROWS):
		save.store[i] = tank_store[i].duplicate()
	save.pet_flags = _capture_pet_flags()
	save.scalars = TankScalarsScript.capture(self)
	save.timestamp = int(Time.get_unix_time_from_system())
	return SaveFilesScript.write_tank_save(path, save)


## Load a save: scalars, store, pet flags and the fish. Live fish are replaced, not merged.
func load_game(path: String = save_path) -> bool:
	var save: TankSave = SaveFilesScript.read_tank_save(path)
	if save == null:
		return false
	TankScalarsScript.apply(save.scalars, self)
	tank_store = save.store.duplicate(true)
	pet_flags = save.pet_flags.duplicate()
	tank.tank_index = save.tank
	level_index = save.level
	for entity in tank.entities_in(Sim.Phase.FISH):
		tank.despawn(entity)
	TankSnapshotScript.restore(tank, save)
	# The scalar block restored the type and countdown; point the live clock at the restored type
	# without resetting the countdown (G10).
	_sync_wave_selection()
	return true


func _capture_pet_flags() -> Array[int]:
	var flags: Array[int] = []
	flags.resize(TankSaveScript.PET_FLAGS)
	flags.fill(0)
	for entity in tank.entities_in(Sim.Phase.PETS):
		var pet := entity as Pet
		if pet != null and pet.index >= 0 and pet.index < TankSaveScript.PET_FLAGS:
			flags[pet.index] = 1
	return flags


# --- input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and holding_fire:
		aim(get_global_mouse_position())
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		holding_fire = event.pressed
		if event.pressed:
			fire_target = get_global_mouse_position()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F5:
				save_game()
			KEY_F9:
				load_game()
			KEY_S:
				open_store()
		return
	if event is not InputEventMouseButton:
		return
	var click := event as InputEventMouseButton
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var at := get_global_mouse_position()
	fire_target = at
	# Click order (P2.10 §6.1): projectiles, then aliens, then coins, then feeding.
	if try_hit_projectile(at):
		return
	if try_shoot(at):
		return
	if try_collect(at):
		return
	drop_food(at)


# --- rendering ---------------------------------------------------------------

func _process(_delta: float) -> void:
	if not render or tank == null:
		return
	# Held fire follows the live cursor (the event path only sees motion, which stops at the edges).
	if holding_fire:
		aim(get_global_mouse_position())
	_sync_visuals()
	_update_hud()


func _on_entity_spawned(entity: SimEntity) -> void:
	# The pickup path is simulation, not drawing: connect it even when rendering is off.
	if entity is Coin:
		(entity as Coin).collected.connect(_on_coin_collected)
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
		source_id = _fish_body_image(fish)
		if fish.species == Fish.Species.GUPPY:
			body_row = clampi(fish.stage, 0, GUPPY_ROWS - 1)
	elif entity is Food:
		source_id = FOOD_IMAGE
	elif entity is Coin:
		source_id = COIN_IMAGE
	elif entity is Pet:
		source_id = (entity as Pet).image_id()
	elif entity is DeadFish:
		# P2.4 §4: the corpse draws `SMALLDIE` at the dying stage's row, framed by `sprite_frame()`.
		# Only the guppy lines are drawn for now (P4.4 scope, Q-0042).
		var corpse := entity as DeadFish
		if corpse.species != Fish.Species.GUPPY:
			return null
		source_id = DEATH_IMAGE
		body_row = clampi(corpse.corpse_id, 0, GUPPY_ROWS - 1)
	elif entity is Alien:
		# P2.8 §3: the kind -> image binding includes Cyrax (BOSS) and the 80x80 minis/Bilaterus.
		source_id = (entity as Alien).image_id()
	elif entity is Projectile:
		# P2.10 §5: the three projectile kinds bind the missile, energy-ball and balls sheets.
		source_id = (entity as Projectile).image_id()
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
	sprite.centered = not (entity is Fish or entity is DeadFish or entity is Pet)
	var anim := AnimState.new()
	anim.setup(res, _sim_tick())
	sprite.set_meta("anim", anim)
	sprite.set_meta("body_row", body_row)
	sprite.set_meta("source", source_id)
	sprite.set_meta("hungry", entity is Fish and (entity as Fish).uses_hungry_art())
	_draw_entity_frame(entity, sprite, anim)
	entity.add_child(sprite)
	if entity is Alien:
		_make_health_bar(entity as Alien)
	return sprite


func _sim_tick() -> int:
	return _sim.tick_count if _sim != null else 0


## The body sheet a fish draws from: the starving twin appears on the hunger transition (P2.3 §6).
func _fish_body_image(fish: Fish) -> String:
	if fish.uses_hungry_art():
		return HUNGRY_BODY_IMAGE
	return BODY_IMAGE


## Pick this tick's texture. The sheet is keyed once and cached per `(id, cell)`, so the per-frame
## path is a dictionary lookup rather than a colour-key pass.
func _draw_entity_frame(entity: SimEntity, sprite: Sprite2D, anim: AnimState) -> void:
	if entity is Fish:
		var fish := entity as Fish
		var row := int(sprite.get_meta("body_row", 0))
		var col := AnimState.column_at(anim.started, _sim_tick(), GUPPY_COLS)
		sprite.texture = _keyed_cell(String(sprite.get_meta("source", "")), row * GUPPY_COLS + col)
		return
	if entity is DeadFish:
		# The corpse's frame is its own countdown rule, not a clock: it walks the death cells as the
		# stage counter falls (P2.4 §4).
		var corpse := entity as DeadFish
		var death_row := int(sprite.get_meta("body_row", 0))
		sprite.texture = _keyed_cell(String(sprite.get_meta("source", BODY_IMAGE)),
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
	if entity is Food:
		# The simulation counter picks the frame; `anim_cycle` 3/4 means the first 3/4 rows.
		var food := entity as Food
		sprite.texture = _keyed_cell(String(sprite.get_meta("source", "")), _food_frame(food))
		return
	# Coins cycle the sheet's first row: which row belongs to which kind is not recovered (Q-0057).
	sprite.texture = _keyed_cell(String(sprite.get_meta("source", "")),
		AnimState.column_at(anim.started, _sim_tick(), COIN_COLUMNS))


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
## one per tick and wrapped at `anim_cycle * 10 - 1`; it picks the tumbler column of the `FOOD` sheet.
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
	return _food_row(food) * FOOD_SHEET_COLUMNS + int(food.anim_frame) % FOOD_SHEET_COLUMNS


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
			# Hungry art is a different sheet, so the sprite is rebuilt on the transition (P2.3 §6).
			var hungry := fish.uses_hungry_art()
			if hungry != bool(visual.get_meta("hungry")):
				var fresh := _make_visual(fish)
				if fresh != null:
					visual.queue_free()
					entity.set_meta("visual", fresh)
					continue
		else:
			visual.position = Vector2.ZERO
		_draw_entity_frame(entity, visual, anim)


func _update_hud() -> void:
	# `_ready()` can run before `setup()` when the level is added to the tree first, so the tank may
	# still be null here; the first tick after setup fills the label.
	if _hud == null or tank == null:
		return
	_hud.text = "Shells %d   Fish %d   Food %d" % [
		money, tank.entities_in(Sim.Phase.FISH).size(), tank.food_count()
	]
