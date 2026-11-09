extends Node
## P4.13 - the audio layer (P2.14). The original runs **two independent mixers** and this mirrors that
## split exactly: an effects pool (DirectSound, `Sexy::DSoundManager`) and music (BASS,
## `Sexy::BassMusicInterface`) on their own buses with their own volume.
##
## Effects (P2.14 §7, EV-0149): the manager owns a fixed pool of **256** slot records with a parallel
## volume array, and a play call names only a sound id - no per-call volume or pan - so a voice takes
## the resource's own volume. A new sound id takes the next free slot; when all 256 are used the
## original reports `"Out of free sound ids"` and the play does not happen, which this does too
## (`dropped`). Identical sounds overlap freely: a voice is allocated per play, not per id.
##
## Music (P2.14 §4, EV-0147/EV-0148): the three shipped tracks are preloaded at startup as
## `SexyApp::Init` does, always loop, and one `SetMusic(a, b)` call covers menus and levels. Which
## loaded file a pair names is **not recovered** (Q-0031b), so `_track_for_pair` is a port choice -
## see the comment there. Virtual Tank plays no music at all (the original's whole selector sits
## inside a `mode != 5` gate), and `Game.silences_music()` says so.
##
## Volumes are 0..1 doubles in memory and integer percent on disk (P2.14 §6); the options dialog's two
## sliders convert, and applying either is instant because it goes straight to the bus.

## The original's 256 effect-slot records (`_eh_vector_constructor_iterator_(this+0x404, 0x1C, 0x100)`,
## EV-0149). The checks shrink it to exercise the exhaustion path.
const SFX_SLOT_LIMIT := 256
const MUSIC_BUS := "Music"
const SFX_BUS := "Sfx"

## The three `music\*.mo3` tracks, ids 1/3/4 (`SexyApp::Init`, EV-0147), as the P3.7 OGG transcodes.
const TRACKS := {
	1: "res://assets_raw/music/Alien.ogg",
	3: "res://assets_raw/music/Lullaby.ogg",
	4: "res://assets_raw/music/Insaniq2.ogg",
}
## Every recovered pair plays this track; the reasoning is in `_track_for_pair`.
const TRACK_MAIN := 4

## `SetMusic` pair per stage 1..4, `level complete`, and the startup/menu state (EV-0148).
const PAIR_STAGE := [
	Vector2i(0, 22),
	Vector2i(0, 0),
	Vector2i(2, 32),
	Vector2i(2, 45),
]
const PAIR_LEVEL_COMPLETE := Vector2i(0, 13)
const PAIR_STARTUP := Vector2i(2, 45)

var slot_limit := SFX_SLOT_LIMIT
## 0..1 doubles, the in-memory half of the volume model (P2.14 §6).
##
## TEMPORARY PORT CHOICE (2026-11-09, owner request): both mixes start muted (0 %) because the
## owner asked for silence during review - the shipped defaults are not in evidence (Q-0056), so
## this is a playtest choice, not a recovered value. The Options sliders start at 0 and are the
## only place that raises them; nothing else writes these fields.
var sfx_volume := 0.0
var music_volume := 0.0
## Every accepted effect, in order - the checks read this instead of listening.
var played: Array[String] = []
## Sound ids that ran out of pool slots (`"Out of free sound ids"`), and ids the registry does not
## know at all.
var dropped := 0
var missing := 0
var current_pair := Vector2i(-1, -1)
var track_id := 0

## id -> slot index (the original's 256-entry volume array, as a growing list).
var _slots: Dictionary = {}
var _slot_volume: Array[float] = []
var _voices: Array[AudioStreamPlayer] = []
var _tracks: Dictionary = {}
var _music: AudioStreamPlayer = null


func _ready() -> void:
	_ensure_bus(MUSIC_BUS)
	_ensure_bus(SFX_BUS)
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = MUSIC_BUS
	add_child(_music)
	set_music_volume(music_volume)
	set_sfx_volume(sfx_volume)


# --- effects -----------------------------------------------------------------

## Play one registry sound: `id` only, the resource's own volume, a fresh voice. True when a voice
## started; false when the id is unknown or the pool is exhausted.
func play(id: String) -> bool:
	var content := get_node_or_null("/root/Content")
	if content == null or not content.has_sound(id):
		missing += 1
		return false
	var slot := _slot_of(id)
	if slot < 0:
		dropped += 1
		push_warning("Out of free sound ids")
		return false
	var voice := _free_voice()
	voice.stream = content.sound(id)
	voice.volume_db = linear_to_db(clampf(_slot_volume[slot], 0.0, 1.0))
	voice.play()
	played.append(id)
	return true


## The UI click (`SOUND_BUTTONCLICK`, the Init-phase sound every screen's click handler reads).
func play_click() -> bool:
	return play("SOUND_BUTTONCLICK")


## Voices alive so far (one is allocated per overlapping play).
func voice_count() -> int:
	return _voices.size()


## The slot a sound id occupies, or -1 when the pool is full. The volume comes from the resource.
func _slot_of(id: String) -> int:
	if _slots.has(id):
		return int(_slots[id])
	if _slots.size() >= slot_limit:
		return -1
	var content := get_node_or_null("/root/Content")
	var volume := 1.0
	if content != null:
		volume = float(content.sound_volume(id))
	_slots[id] = _slots.size()
	_slot_volume.append(volume)
	return int(_slots[id])


func _free_voice() -> AudioStreamPlayer:
	for voice in _voices:
		if not voice.playing:
			return voice
	var voice := AudioStreamPlayer.new()
	voice.name = "Sfx%d" % _voices.size()
	voice.bus = SFX_BUS
	add_child(voice)
	_voices.append(voice)
	return voice


# --- music -------------------------------------------------------------------

## The `SetMusic(a, b)` request. Virtual Tank gets silence instead of a track.
func set_music_pair(pair: Vector2i) -> void:
	current_pair = pair
	var game := get_node_or_null("/root/Game")
	if game != null and game.has_method("silences_music") and game.silences_music():
		stop_music()
		return
	var id := _track_for_pair(pair)
	if id < 0:
		stop_music()
		return
	if id == track_id and _music != null and _music.playing:
		return
	start_music(id)


## Stage music from the tank index (1..5): stages 1..4 have recovered pairs, tank 5 re-uses the last.
func set_stage_music(tank_no: int) -> void:
	var index := clampi(tank_no, 1, PAIR_STAGE.size()) - 1
	set_music_pair(PAIR_STAGE[index])


func set_level_complete_music() -> void:
	set_music_pair(PAIR_LEVEL_COMPLETE)


func start_music(id: int) -> void:
	if _music == null:
		return
	var stream := _track(id)
	if stream == null:
		return
	_music.stream = stream
	_music.volume_db = linear_to_db(clampf(music_volume, 0.0, 1.0))
	_music.play()
	track_id = id
	print("audio: music track %d" % id)


func stop_music() -> void:
	if _music != null:
		_music.stop()
	track_id = 0


func music_playing() -> bool:
	return _music != null and _music.playing


func _track(id: int) -> AudioStream:
	if _tracks.has(id):
		return _tracks[id]
	if not TRACKS.has(id):
		return null
	var stream := load(String(TRACKS[id])) as AudioStream
	if stream == null:
		return null
	# Every track loops: the play slot restarts the module with the loop bit (P2.14 §3.3).
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_tracks[id] = stream
	return stream


## Which loaded file a pair names is **not** recovered: §4.2's remap sends every pair to track 4,
## and the startup call site - the state the main theme plays in - is `(2, 45)` (`SexyApp::Init`).
## The port therefore plays `Insaniq2` for every recovered pair, and the battle loop (`Alien`) stays
## unused until its trigger is recovered (Q-0031b/Q-0030).
func _track_for_pair(_pair: Vector2i) -> int:
	return TRACK_MAIN


# --- volume ------------------------------------------------------------------

## `MusicVolume`: a 0..1 double, applied to the Music bus immediately (P2.14 §6).
func set_music_volume(volume: float) -> void:
	music_volume = clampf(volume, 0.0, 1.0)
	_set_bus_volume(MUSIC_BUS, music_volume)


## `SfxVolume`, same model on the Sfx bus.
func set_sfx_volume(volume: float) -> void:
	sfx_volume = clampf(volume, 0.0, 1.0)
	_set_bus_volume(SFX_BUS, sfx_volume)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


func _set_bus_volume(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
