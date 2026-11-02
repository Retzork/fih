class_name ImageRes
extends RefCounted
## One manifest image, resolved into its Godot handles once at load time (P4.2).
##
## A manifest image is a grid (`cols` x `rows` cells, row-major) plus playback metadata. P4 keeps
## the animation *timing* in data rather than baked into the resource (SPECS.md §2.3): `frame_delay`
## counts 10 ms logic ticks, `per_frame_delay` overrides per position in the mapped sequence, and
## `begin_delay` holds the first frame before starting.
##
## Single-cell images have only `texture`. Multi-cell ones carry a `SpriteFrames` built by P3.5
## (`tools/godot/gen_spriteframes.gd`) whose "default" animation is already in `framemap` order, so
## `frame(i)` indexes the playback sequence, not the raw grid.

var id: String            ## canonical id, e.g. "IMAGE_OSCAR"
var name: String          ## manifest's bare id, e.g. "OSCAR"
var path: String          ## source texture, for diagnostics
var texture: Texture2D    ## sheet texture (single-cell) or the first frame
var sprite_frames: SpriteFrames  ## null for single-cell images
var cols: int = 1
var rows: int = 1
var cell_w: int = 0
var cell_h: int = 0
var frame_count: int = 1  ## grid cells (cols * rows)
var anim: String = ""     ## "", "loop", "once" or "pingpong"
var frame_delay: int = 0  ## ticks (10 ms) per frame, the manifest default
var per_frame_delay: Array = []
var begin_delay: int = 0
var end_delay: int = 0


func is_animated() -> bool:
	return sprite_frames != null and play_count() > 1


## Frames in the playback sequence (`framemap` applied, dropped placeholders excluded).
func play_count() -> int:
	if sprite_frames == null:
		return 1
	return sprite_frames.get_frame_count("default")


## Frame `index` of the playback sequence, wrapping so callers need not guard a looping counter.
func frame(index: int) -> Texture2D:
	if sprite_frames == null:
		return texture
	var count := play_count()
	if count == 0:
		return texture
	return sprite_frames.get_frame_texture("default", posmod(index, count))


## Ticks to hold frame `index`: `perframedelay` when the manifest gives it for that position,
## else the image-wide `framedelay` (P2.15 §8.5).
func delay(index: int) -> int:
	if index >= 0 and index < per_frame_delay.size():
		return int(per_frame_delay[index])
	return frame_delay


## Plays once and holds the last frame rather than looping (SPECS.md §2.3).
func holds_last_frame() -> bool:
	return anim == "once"


func uses_pingpong() -> bool:
	return anim == "pingpong"
