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
## The tank bar's own pair (D-0033). The wallet is recovered: `FUN_00542CFD` gives the tank's label
## widget (`Tank+0x438`, box 0x217/0x28/0x50) `DAT_005e8ce4` = plain ContinuumBold12, and `FUN_0053A360`
## prints the bare `"%d"` into it (EV-0058). The price label's font is not recovered, so it is fitted to
## the recording: `$100` inks 25 px wide there against the 45-px plate, which is Tiny's 27-px advance -
## ContinuumBold12's 35 (what the widget ctor's `+0x2e` global would suggest) overruns the plate.
const BAR_PRICE_FONT := "FONT_TINY"
const BAR_MONEY_FONT := "FONT_CONTINUUMBOLD12"
const SMALL_FONT := "FONT_TINYBOLD"
const TINY_FONT := "FONT_TINY"
const HUD_FONT := "FONT_LIDDIE15"
const LABEL_FONT := "FONT_LIDDIE12"
## The tank screen's bottom row (D-0028/D-0034), measured off the 1-1 recording: the hunger hint's 36
## glyphs span 277 px there and `CONTINUUMBOLD14` draws them 279, so it keeps its native size. The tank
## name inks 60 px there and `CONTINUUMBOLD12` draws "Tank  1-1" 72, so the name alone is tracked in by
## 1 px per glyph (advance 64, ink ~61) - the base draws it 1:1 and nothing else in the set lands
## closer: `CONTINUUMBOLD12OUTLINE`/`JUNGLEFEVER10OUTLINE` are 65 wide but outlined, `BLAMBOTPRO8` 64
## and `TINYBOLD` 60 both stand ~8 px tall where the recording's name is 11.
const BOTTOM_HINT_FONT := "FONT_CONTINUUMBOLD14"
const BOTTOM_NAME_FONT := "FONT_CONTINUUMBOLD12"
const BOTTOM_NAME_TRACKING := -1.0


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


## Apply `id` and its native size, then tighten its tracking by `spacing` pixels per glyph
## (`BOTTOM_NAME_TRACKING`). The shared `FontFile` stays untouched: the tightened font is a
## `FontVariation` over it, which is what `applied_id()` cannot name - use `applied_base_id()`.
static func apply_tracked(target: Control, id: String, spacing: float) -> bool:
	if not apply(target, id):
		return false
	var variation := FontVariation.new()
	variation.base_font = target.get_theme_font("font")
	variation.spacing_glyph = spacing
	target.add_theme_font_override("font", variation)
	return true


## The font id applied to `target`, seeing through a `FontVariation` (the tracked name label).
static func applied_base_id(target: Control) -> String:
	if target == null:
		return ""
	var font := target.get_theme_font("font")
	if font is FontVariation and font.base_font != null:
		font = font.base_font
	if font == null or font.resource_path == "":
		return ""
	return "FONT_" + font.resource_path.get_file().get_basename()


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
