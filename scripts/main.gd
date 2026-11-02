extends Node2D
## Main - the boot scene. It owns almost nothing on purpose: it attaches the screen layer to the
## Screens autoload and drives the debug overlay (P2.1/EV-0035: `FPS: %d` per 1000 ms window).
##
## Everything else is a screen (docs/ARCHITECTURE.md §3). Main also drives the P4.2 content load:
## Init is already done by the Content autoload, Register is pulled before the first menu, and the
## LoadingThread phase is pumped here a slice at a time until P4.5's loading screen takes the bar.

@onready var _screens_layer: CanvasLayer = $Screens
@onready var _info: Label = $Debug/Info

var _frames := 0
var _elapsed := 0.0


func _ready() -> void:
	Screens.attach(_screens_layer)
	# Boot order (SPECS.md §2.2): Init is already resolved by the Content autoload's _ready(), which
	# runs before any scene. Register must be present before the first menu or dialog, and the bulk
	# of the assets loads behind the loading bar - P4.5 draws that bar, the debug overlay shows
	# progress until then.
	Content.ensure_phase(Content.Phase.REGISTER)
	Content.start_phase(Content.Phase.LOADING)


func _process(delta: float) -> void:
	# ~4 ms of loading per frame: finishes in a second or two and keeps the window responsive.
	if not Content.is_phase_complete(Content.Phase.LOADING):
		Content.pump(4.0)
	_elapsed += delta
	_frames += 1
	if _elapsed < 1.0:
		return
	_info.text = "FPS: %d  tick %d  (%.0f Hz, %d this frame)  content %d/%d" % [
		roundi(_frames / _elapsed),
		Sim.tick_count,
		Sim.TICKS_PER_SECOND,
		Sim.last_ticks_per_frame,
		Content.loaded_count(),
		Content.EXPECTED_TOTAL,
	]
	_frames = 0
	_elapsed = 0.0
