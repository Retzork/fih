extends SceneTree
## headless_audio_check - P4.13's audio layer (P2.14): the two buses, the effect pool with its
## 256-slot cap and the `"Out of free sound ids"` drop, per-resource volumes, the aliases, and the
## music side (preloaded looping tracks, the recovered `SetMusic` pairs, Virtual Tank silence).
##
## The autoloads do run under `--script`, so the check drives the shipped `Audio` singleton against
## the real registry: it finishes the LoadingThread phase first (that is where 64 of the 65 sounds
## live) and then plays the extracted files without listening to them.

var _checks := 0
var _failures := 0
## The autoloads, looked up at run time: `--script` cannot resolve their names at parse time.
var _content: Node = null
var _audio: Node = null
var _game: Node = null


func _init() -> void:
	await process_frame
	for id in ["Content", "Audio", "Game"]:
		if root.get_node_or_null(id) == null:
			print("headless_audio_check: %s autoload missing" % id)
			quit(1)
			return
	_content = root.get_node("Content")
	_audio = root.get_node("Audio")
	_game = root.get_node("Game")
	# The 64 LoadingThread sounds must be in before anything can play them.
	await process_frame
	_content.ensure_phase(_content.Phase.REGISTER)
	_content.start_phase(_content.Phase.LOADING)
	var guard := 0
	while not _content.is_phase_complete(_content.Phase.LOADING) and guard < 400:
		_content.pump(50.0)
		guard += 1
	_test_buses()
	_test_play()
	_test_volumes()
	_test_pool_limit()
	_test_music()
	if _checks == 0:
		print("headless_audio_check: no assertions ran")
		quit(1)
		return
	if _failures > 0:
		print("headless_audio_check: %d FAILURE(S) of %d" % [_failures, _checks])
		quit(1)
		return
	print("headless_audio_check: PASS (%d assertions)" % _checks)
	quit(0)


func _expect(condition: bool, what: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("  FAIL %s" % what)


func _test_buses() -> void:
	_expect(AudioServer.get_bus_index("Music") > 0, "the effects and music mixers are separate buses")
	_expect(AudioServer.get_bus_index("Sfx") > 0, "the Sfx bus exists")
	_expect(AudioServer.get_bus_index("Music") != AudioServer.get_bus_index("Sfx"), "music and Sfx are not one bus")
	_expect(_audio.PAIR_STAGE.size() == 4, "one music pair per stage")


func _test_play() -> void:
	_expect(_content.has_sound("SOUND_BUY"), "the LoadingThread sounds are in the registry")
	_expect(_audio.play("SOUND_BUY"), "a known sound plays")
	_expect(_audio.played.has("SOUND_BUY"), "and the play is recorded")
	_expect(_audio.play("SOUND_BUY"), "the same sound overlaps itself")
	_expect(_audio.played.size() == 2, "both overlapping plays are recorded")
	_expect(_audio.play("SOUND_START"), "an alias plays its target sound (SOUND_START -> SOUND_AWOOGA)")
	_expect(_audio.play_click(), "the UI click helper plays the Init sound")
	_expect(_audio.played.has("SOUND_BUTTONCLICK"), "and it is the button click")
	var missing_before: int = int(_audio.missing)
	_expect(not _audio.play("SOUND_NOPE"), "an unknown id is refused")
	_expect(_audio.missing == missing_before + 1, "and counted as missing")
	# Per-resource volume: the manifest's half-volume sound is attenuated on the voice.
	_audio.play("SOUND_NIKOOPEN")
	var quiet := 0.0
	for child in _audio.get_children():
		if child is AudioStreamPlayer and child.volume_db < quiet:
			quiet = child.volume_db
	_expect(absf(quiet - linear_to_db(0.5)) < 0.01, "a voice takes the resource's own volume")
	_expect(_audio.voice_count() >= 1, "voices are allocated for playback")


func _test_volumes() -> void:
	_audio.set_music_volume(0.5)
	_expect(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")) - linear_to_db(0.5)) < 0.01,
		"music volume reaches the Music bus")
	_audio.set_sfx_volume(0.25)
	_expect(absf(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Sfx")) - linear_to_db(0.25)) < 0.01,
		"effect volume reaches the Sfx bus")
	_audio.set_music_volume(2.0)
	_expect(_audio.music_volume == 1.0, "the volume is a 0..1 double")
	_audio.set_sfx_volume(-1.0)
	_expect(_audio.sfx_volume == 0.0, "and clamps at 0")
	_audio.set_music_volume(1.0)
	_audio.set_sfx_volume(1.0)


func _test_pool_limit() -> void:
	_expect(_audio.SFX_SLOT_LIMIT == 256, "the effect pool is the original's 256 slots")
	var used := int(_audio._slots.size())
	_audio.slot_limit = used
	var dropped_before: int = int(_audio.dropped)
	_expect(not _audio.play("SOUND_DROPFOOD"), "a full pool refuses the play")
	_expect(_audio.dropped == dropped_before + 1, "and mirrors the original's \"Out of free sound ids\" drop")
	_audio.slot_limit = _audio.SFX_SLOT_LIMIT
	_expect(_audio.play("SOUND_DROPFOOD"), "the id plays once a slot is free")


func _test_music() -> void:
	_expect(_audio.TRACKS.size() == 3, "the three shipped tracks are the music set")
	for id in _audio.TRACKS:
		_expect(load(String(_audio.TRACKS[id])) != null, "track %d loads" % id)
	_audio.set_music_pair(_audio.PAIR_STARTUP)
	_expect(_audio.current_pair == Vector2i(2, 45), "the startup pair is (2, 45)")
	_expect(_audio.track_id == _audio.TRACK_MAIN, "the startup state plays the main theme")
	_expect(_audio.music_playing(), "music actually starts")
	var stream := _audio._music.stream as AudioStreamOggVorbis
	_expect(stream != null and stream.loop, "the track loops")
	_audio.set_music_pair(_audio.PAIR_STAGE[0])
	_expect(_audio.current_pair == Vector2i(0, 22), "stage 1's pair is (0, 22)")
	_audio.set_stage_music(3)
	_expect(_audio.current_pair == _audio.PAIR_STAGE[2], "stage 3 selects its own pair")
	_audio.set_stage_music(9)
	_expect(_audio.current_pair == _audio.PAIR_STAGE[3], "a tank past the table clamps to the last pair")
	_audio.set_level_complete_music()
	_expect(_audio.current_pair == Vector2i(0, 13), "a finished level asks for (0, 13)")
	_audio.stop_music()
	_expect(not _audio.music_playing(), "stop_music silences the track")
	_expect(_audio.track_id == 0, "and clears the current track")
	# Virtual Tank: the original's whole music selector sits inside a `mode != 5` gate.
	_game.set_mode(Game.Mode.VIRTUAL_TANK)
	_audio.set_music_pair(_audio.PAIR_STAGE[0])
	_expect(not _audio.music_playing(), "Virtual Tank plays no music")
	_expect(_audio.track_id == 0, "and names no track")
	_game.set_mode(Game.Mode.ADVENTURE)
