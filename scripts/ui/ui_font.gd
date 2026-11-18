class_name UiFont
extends RefCounted
## Applies the game's own BMFonts to UI controls.
##
## The manifest carries the complete 15-font set (P2.15 §2/§6); the original never loads a font
## outside it. A `FontFile` has one native pixel size, so a size override other than the manifest's
## `size` would scale the glyphs - these fonts are drawn 1:1, exactly like the game.
##
## `FONT_JUNGLEFEVER10OUTLINE` / `FONT_JUNGLEFEVER17OUTLINE` are the two `Init` fonts, and the
## `GameSelector` ctor preloads font ids 0x61/0x62 (P2.12 §4) - the two outline fonts, in an order
## the decompile does not pin down. Q-0059 records that split as the port's inference.
##
## Resolution is dynamic and goes through the scene root, not the control's own ancestry: callers
## apply fonts while they build a control, before `add_child` puts it in the tree. The `--script`
## suites have no autoloads at all, so a missing `Content` keeps the engine default font.

const SELECTOR_BIG_FONT := "FONT_JUNGLEFEVER17OUTLINE"
const SELECTOR_SMALL_FONT := "FONT_JUNGLEFEVER10OUTLINE"
## `FUN_0050E190` maps `DAT_005e8CE4` to this font; the StoreScreen writes that pointer into its
## Shell counter (P2.12 §6).
const STORE_FONT := "FONT_CONTINUUMBOLD12"
const STORE_OUTLINE_FONT := "FONT_CONTINUUMBOLD12OUTLINE"
const SMALL_FONT := "FONT_TINYBOLD"
const TINY_FONT := "FONT_TINY"
const HUD_FONT := "FONT_LIDDIE15"
const LABEL_FONT := "FONT_LIDDIE12"
## The tank screen's bottom row (D-0028), measured off the 1-1 recording: the hunger hint's 36 glyphs
## span 277 px there and `CONTINUUMBOLD14` draws them 279, the tank name spans 60 and
## `CONTINUUMBOLD12` draws it 72. The base draws both 1:1, so these keep their native size.
const BOTTOM_HINT_FONT := "FONT_CONTINUUMBOLD14"
const BOTTOM_NAME_FONT := "FONT_CONTINUUMBOLD12"


## Apply `id` and its native size to `target`. Returns false (leaving the theme default) when
## Content is absent or has not loaded that font.
static func apply(target: Control, id: String) -> bool:
	if target == null:
		return false
	var content := _content()
	if content == null or not content.has_font(id):
		return false
	var font: FontFile = content.font(id)
	if font == null:
		return false
	target.add_theme_font_override("font", font)
	var size := int(content.font_size(id))
	if size > 0:
		target.add_theme_font_size_override("font_size", size)
	return true


## The `Content` autoload under the scene root, or null outside a scene (the `--script` suites).
static func _content() -> Node:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null or loop.root == null:
		return null
	return loop.root.get_node_or_null("Content")


## The font id applied to a control, or "" when it still uses the theme default. For the suites.
static func applied_id(target: Control) -> String:
	if target == null:
		return ""
	var font := target.get_theme_font("font")
	if font == null or font.resource_path == "":
		return ""
	return "FONT_" + font.resource_path.get_file().get_basename()
