#!/usr/bin/env python
"""Build the art review artifacts: docs/review/sprites.pdf and docs/review/animations/*.gif.

Run after tools/godot/export_review_assets.gd has written docs/review/assets/:

    .venv-review/Scripts/python tools/review/build_review.py

The sprites PDF is a contact sheet: one card per manifest sheet, grouped with section dividers, the
art drawn at the size the game gives it (mask companion applied, or the tank's border colour key),
with the cell grid overlaid. The guppy body sheets are the one split: their four stage rows stay on
the guppy card and the fifth (carnivore) row is Oscar's card.

The animations are one GIF per manifest animation. Playback is AnimState's own clock: frame order is
the SpriteFrames order from resources/sprites/<NAME>.tres (framemap applied), per-frame delay comes
from `perFrameDelay` or `frameDelay`, the first frame is held `beginDelay`, `once` holds its last
frame, `pingpong` folds 0..n-1..1 on the uniform frame delay, and everything runs on the 36 Hz sim
tick (Q-0034) converted to GIF centiseconds.
"""

from __future__ import annotations

import json
import math
import re
import zipfile
from pathlib import Path

from fpdf import FPDF
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
CONTENT = ROOT / "resources" / "content.json"
ASSETS = ROOT / "docs" / "review" / "assets"
OUT = ROOT / "docs" / "review"
GIF_DIR = OUT / "animations"
TICK_MS = 1000.0 / 36.0
CHECKER = (34, 34, 34)
CHECKER_ALT = (44, 44, 44)
INK = (18, 18, 18)
PAPER = (250, 250, 248)

FISH = {
    "SYLV", "BALROG", "GUS", "MINISYLV", "SMALLSWIM", "SMALLTURN", "SMALLEAT", "SMALLDIE",
    "HUNGRYSWIM", "HUNGRYEAT", "HUNGRYTURN", "HUNGRYBREEDER", "SIMEAT1", "SIMEAT2", "SIMEAT3",
    "SIMSWIM1", "SIMSWIM2", "SIMSWIM3", "SIMTURN1", "SIMTURN2", "SIMTURN3", "SIMCARNIVORE",
    "GRUBBER", "STARCATCHER", "GEKKO", "BREEDER", "ULTRA",
}
PETS = {
    "STINKY", "NIKO", "ITCHY", "PREGO", "ZORF", "CLYDE", "VERT", "RUFUS", "MERYL", "WADSWORTH",
    "SEYMOUR", "SHRAPNEL", "GUMBO", "BLIP", "RHUBARB", "NIMBUS", "AMP", "GASH", "ANGIE", "PRESTO",
    "BRINKLEY", "NOSTRADAMUS", "STANLEY", "WALTER", "MERYLLIPS", "MERYLBLINK", "MERYLTAIL",
}
ALIENS = {
    "DESTRUCTOR", "ULYSSES", "PSYCHOSQUID", "BILATERUS", "BOSS", "AA_BEAM", "AA_GLOW", "AA_TOP1",
    "AA_TOP2", "AA_BOTTOM", "CHOMP",
}
PICKUPS = {"FOOD", "MONEY", "PEARL", "PEANUT", "SHELLS", "MONEYBAG", "MONEYFLASH"}
EFFECTS = {
    "EXPLOSION", "EXPLOSIONSMALL", "EXPLOSIONTINY", "SMOKETINY", "SMOKESMALL", "SMOKEMISSILE",
    "SPARKS", "SPARKLE", "BUBBLES", "WARPHOLE", "WARPGLOW", "HALO", "EGGSHARDS", "EGGCRACK1",
    "EGGCRACK2", "ENERGYBALL", "MISSILE", "BALLS", "LASERS", "GUMBOLIGHT", "AMPCHARGE", "NIKOTOWER",
    "SHADOW", "BOLT", "WAVESIDE", "WAVE",
}
UI = {
    "CURSOR_POINTER", "CURSOR_HAND", "CURSOR_DRAGGING", "CURSOR_TEXT", "MENUBAR", "MONEYFLASH_X",
    "LOADERBAR", "LOADERBAROVER", "LOADERBARLOADING", "LOADERPLAY", "DIALOG", "DIALOGBUTTON",
    "EDITBOX", "MAINBUTTON", "LEFTBUTTON", "RIGHTBUTTON", "CENTERBUTTON", "FISHBOX",
    "FISHBOXBUTTON", "PETBUTTON", "PETBUTTONRING", "PETBUTTONREFLECT", "PETBUTTONHOLE",
    "STORELEFTBUTTON", "STORETOPBUTTON", "STORERIGHTBUTTON", "STORELEFTHILIGHT", "STORETOPHILIGHT",
    "STORERIGHTHILIGHT", "BATTLETANKBUTTON", "BATTLETANKBUTTOND", "MIDDLEBUTTON", "MIDDLEBUTTOND",
    "OPTIONSBUTTON", "OPTIONSBUTTOND", "MENUBTND", "MENUBTND2", "MENUBTNU", "MENUBTNO", "PETBTNU",
    "PETBTNO", "UNCHECKED", "CHECKED", "SLIDERTRACK", "SLIDERTHUMB", "WAIT_BAR", "TROPHYBAR",
    "SPEECHBUBBLE", "SELECTORSPEECHBUBBLE", "HELPARROW", "HEALTHBAR", "HEALTHBARTUBE",
    "HELPSHELL", "STORESHELL", "BONUSBUTTONOVERLAY", "FATBUTTON", "PEGGPLACEHOLDER",
    "BONUSAWARD", "BONUSAWARD2", "MISCITEMS", "EGGPIECES", "PETLIMITEGG", "HATCHANIMATION",
    "ZZZ", "PETBUTTON_X", "MENUBUTTONREFLECTION", "HATCHREFLECTION", "STOREBACKDROPS",
}
SCREENS = {
    "TITLEPAGE", "TITLEPAGEMASK", "SELECTORSCREEN", "STORESCREEN", "HATCHSCREEN", "SCREENBACK",
    "SCREENTITLE", "SCREENTITLEHOLE", "TANKCHOOSER", "WELCOMETO", "WELCOMEBACK", "BONUS1",
    "BONUS2", "BONUS3", "BUBBULATOR_STORE", "AA_STORE", "BUBBULATOR", "HELPALIEN", "HELPPETCHOOSE",
    "HELPSCREENSAVER", "PIZZA", "ICECREAM", "CHICKEN", "TROPHYBUTTONS", "FISHBOX_X",
}
BACKDROPS = {
    "TANKBACKDROP1", "TANKBACKDROP2", "TANKBACKDROP3", "TANKBACKDROP4", "TANKBACKDROP5",
    "TANKBACKDROP6", "AQUARIUM1", "AQUARIUM2", "AQUARIUM3", "AQUARIUM4", "AQUARIUM5", "AQUARIUM6",
    "TANKMASK1", "TANKMASK2", "TANKMASK3", "TANKMASK4", "TANKMASK5", "TANKMASK6",
    "TANKLIGHTING",
}
SECTIONS = [
    ("Fish", FISH),
    ("Pets", PETS),
    ("Aliens & boss", ALIENS),
    ("Food, money & pickups", PICKUPS),
    ("Effects & projectiles", EFFECTS),
    ("UI chrome, bars & buttons", UI),
    ("Screens, titles & cards", SCREENS),
    ("Tank backdrops & lighting", BACKDROPS),
]


def section_for(name: str) -> str:
    for title, names in SECTIONS:
        if name in names:
            return title
    return "Miscellaneous"


def load_data():
    data = json.loads(CONTENT.read_text(encoding="utf-8"))
    return data["images"]


# --------------------------------------------------------------------------- sprites PDF
def build_pdf(cards) -> Path:
    pdf = FPDF(orientation="P", unit="mm", format="A4")
    pdf.set_auto_page_break(False)
    pdf.alias_nb_pages()
    pdf.set_title("Insaniquarium remake - sprite review")
    pdf.set_author("fih review sheet")
    margin = 10.0
    page_w, page_h = 210.0, 297.0
    card_w = page_w - 2 * margin
    top = 18.0
    bottom = 276.0
    flow_gap = 5.0

    pdf.add_page()
    pdf.set_fill_color(*PAPER)
    pdf.rect(0, 0, page_w, page_h, style="F")
    pdf.set_text_color(*INK)
    pdf.set_font("Helvetica", "B", 22)
    pdf.set_xy(margin, 24)
    pdf.cell(0, 12, "Sprite review - every image in the game")
    pdf.set_font("Helvetica", "", 11)
    pdf.set_xy(margin, 38)
    pdf.multi_cell(
        page_w - 2 * margin, 5.5,
        "One card per manifest sheet, except the guppy body sheets: their four guppy stage rows are "
        "one card and the carnivore fifth row is Oscar's card. Art is composed exactly as the game "
        "draws it: a sheet with an alpha companion under assets_raw/masks/ uses that companion "
        "(P3.3); every other sheet goes through the tank's border colour key (SpriteKey). Thin grey "
        "lines are the cell grid.",
    )
    pdf.set_xy(margin, 62)
    pdf.multi_cell(
        page_w - 2 * margin, 5.5,
        "Read the caption as: NAME, then the manifest id, grid (columns x rows), cell size, frame "
        "count and playback metadata. Animated images are also reviewed as GIFs in animations/.",
    )
    counts = {}
    for entry in cards:
        counts[entry["section"]] = counts.get(entry["section"], 0) + 1
    pdf.set_xy(margin, 86)
    pdf.set_font("Helvetica", "B", 11)
    pdf.cell(0, 6, "Contents")
    pdf.set_font("Helvetica", "", 9.5)
    y = 94
    for title, names in SECTIONS + [("Miscellaneous", set())]:
        n = counts.get(title, 0)
        if not n:
            continue
        pdf.set_xy(margin + 4, y)
        pdf.cell(70, 5, title)
        pdf.set_xy(margin + 76, y)
        pdf.cell(20, 5, str(n))
        y += 5
    pdf.set_xy(margin, y + 8)
    pdf.set_font("Helvetica", "", 8.5)
    pdf.set_text_color(90, 90, 90)
    pdf.multi_cell(
        page_w - 2 * margin, 4.6,
        f"{len(cards)} cards. Generated from resources/content.json + assets_raw; regenerate with "
        "tools/review/build_review.py after re-running tools/godot/export_review_assets.gd.",
    )

    # Group while keeping a stable, readable order inside each section.
    order = [title for title, _ in SECTIONS] + ["Miscellaneous"]
    grouped = {title: [] for title in order}
    for entry in cards:
        grouped[entry["section"]].append(entry)
    for title in order:
        grouped[title].sort(key=lambda e: e["name"])

    def footer():
        pdf.set_y(-12)
        pdf.set_font("Helvetica", "", 8)
        pdf.set_text_color(120, 120, 120)
        pdf.cell(0, 5, "fih - sprite review", align="L")
        pdf.set_xy(-30, -12)
        pdf.cell(20, 5, f"{pdf.page_no()} / {{nb}}", align="R")

    def new_page():
        pdf.add_page()
        pdf.set_fill_color(*PAPER)
        pdf.rect(0, 0, page_w, page_h, style="F")
        footer()

    for title in order:
        entries = grouped[title]
        if not entries:
            continue
        if pdf.get_y() > bottom - 50:
            new_page()
        # Section divider: a full-width bar, then a rule.
        y = pdf.get_y() + (6 if pdf.get_y() > 20 else 0)
        pdf.set_fill_color(28, 34, 44)
        pdf.rect(margin, y, page_w - 2 * margin, 8.5, style="F")
        pdf.set_text_color(255, 255, 255)
        pdf.set_font("Helvetica", "B", 10.5)
        pdf.set_xy(margin + 3, y + 0.8)
        pdf.cell(0, 7, f"{title.upper()}   -   {len(entries)} images")
        pdf.set_text_color(*INK)
        pdf.set_draw_color(160, 160, 160)
        pdf.set_line_width(0.2)
        pdf.line(margin, y + 9.5, page_w - margin, y + 9.5)
        y += 13.0
        for entry in entries:
            dw, dh = card_image_size(entry)
            card_h = dh + 19.0
            if y + card_h > bottom:
                new_page()
                y = top
            draw_card(pdf, entry, margin, y, card_w, card_h, dw, dh)
            y += card_h + flow_gap
        pdf.set_y(y)

    out = OUT / "sprites.pdf"
    pdf.output(str(out))
    return out


## Art size on the card in mm: fill the 186 mm column, cap the height at 112 mm, and never
## upscale a sprite more than 4x its native pixels (1 px = 4 pt), which keeps tiny icons sane.
MM_PER_PX = 0.3527778


def card_image_size(entry) -> tuple[float, float]:
    try:
        with Image.open(entry["png"]) as im:
            iw, ih = im.size
    except Exception:
        iw, ih = 1, 1
    max_w, max_h = 186.0, 100.0
    scale = min(max_w / (iw * MM_PER_PX), max_h / (ih * MM_PER_PX), 4.0)
    return iw * MM_PER_PX * scale, ih * MM_PER_PX * scale


def draw_card(pdf: FPDF, entry, x: float, y: float, w: float, h: float, dw: float, dh: float) -> None:
    name = entry["name"]
    path = entry["png"]
    if not path.exists():
        return
    pdf.set_fill_color(255, 255, 255)
    pdf.set_draw_color(205, 205, 200)
    pdf.set_line_width(0.25)
    pdf.rect(x, y, w, h, style="DF")
    ix = x + (w - dw) / 2
    iy = y + 2.0
    pdf.image(str(path), x=ix, y=iy, w=dw, h=dh)
    # Cell grid over the drawn sheet.
    cols, rows = int(entry["cols"]), int(entry["rows"])
    if cols > 1 or rows > 1:
        pdf.set_draw_color(120, 120, 120)
        pdf.set_line_width(0.12)
        for c in range(1, cols):
            gx = ix + dw * c / cols
            pdf.line(gx, iy, gx, iy + dh)
        for r in range(1, rows):
            gy = iy + dh * r / rows
            pdf.line(ix, gy, ix + dw, gy)
    # Caption.
    pdf.set_draw_color(205, 205, 200)
    pdf.set_line_width(0.2)
    pdf.line(x, y + dh + 3.5, x + w, y + dh + 3.5)
    pdf.set_text_color(*INK)
    pdf.set_font("Helvetica", "B", 9.0)
    pdf.set_xy(x + 3, y + dh + 4.6)
    pdf.cell(w - 6, 4.2, name)
    meta = "%s  %dx%d cells  %dx%dpx  %d play frames" % (
        entry["id"], cols, rows, int(entry["cellW"]), int(entry["cellH"]), int(entry["playCount"]),
    )
    pdf.set_font("Helvetica", "", 7.2)
    pdf.set_text_color(70, 70, 70)
    pdf.set_xy(x + 3, y + dh + 9.2)
    pdf.cell(w - 6, 3.8, meta)
    if entry.get("anim"):
        extra = "anim %s, %s ticks%s" % (
            entry["anim"], entry.get("frameDelay", 0),
            ", first held %d" % entry["beginDelay"] if entry.get("beginDelay") else "",
        )
        if entry.get("perFrameDelay"):
            extra += ", per-frame " + "/".join(str(v) for v in entry["perFrameDelay"])
        pdf.set_xy(x + 3, y + dh + 13.0)
        pdf.cell(w - 6, 3.8, extra)
    elif int(entry.get("playCount", 1)) > 1:
        pdf.set_xy(x + 3, y + dh + 13.0)
        pdf.cell(w - 6, 3.8, "sheet: cell column driven by the entity (no playback metadata)")


## The guppy body sheets carry a fifth row of carnivore art (p1-recon: "small, hungry (carnivore)").
## `Fish.row_for` folds every guppy stage onto rows 0-3 and only Oscar draws row 4
## (`Fish.SPECIES_DRAW` fixes his row), so the sprite pages split the sheet: the guppy card shows the
## four stage rows and the fifth row becomes Oscar's card.
GUPPY_BODY_STATES = {
    "SMALLSWIM": "swim",
    "HUNGRYSWIM": "starving swim",
    "SMALLEAT": "eat",
    "HUNGRYEAT": "starving eat",
    "SMALLTURN": "turn",
    "HUNGRYTURN": "starving turn",
    "SMALLDIE": "corpse",
}
CROP_DIR = OUT / "crops"


def crop_rows(name: str, first: int, count: int, cell_h: int, tag: str) -> Path | None:
    """Crop `count` rows of a sheet from row `first` into docs/review/crops/."""
    src = ASSETS / f"{name}.png"
    if not src.exists():
        return None
    CROP_DIR.mkdir(parents=True, exist_ok=True)
    out = CROP_DIR / f"{name}_{tag}.png"
    with Image.open(src) as im:
        top = first * cell_h
        im.crop((0, top, im.width, top + count * cell_h)).save(out)
    return out


## Sheets that ship as masks on a black background: SIMCARNIVORE's three white layers are white-on-
## black cells, so drawn as-is they read as black boxes (owner 2026-11-23: carnivore layer masking
## is improper). A row whose cell corner is opaque black is a mask row: its luminance becomes the
## alpha, so the silhouette shows on the page's own background. The coloured body row is already
## transparent and is left untouched.
_KEYED_CACHE = {}


def keyed_asset(entry) -> str:
    name = entry["name"]
    rows = int(entry.get("rows", 1))
    if rows < 2:
        return "assets/%s.png" % name
    if name in _KEYED_CACHE:
        return _KEYED_CACHE[name]
    src = ASSETS / f"{name}.png"
    ch = int(entry["cellH"])
    with Image.open(src) as raw:
        im = raw.convert("RGBA")
        px = im.load()
        mask_rows = [r for r in range(rows)
                     if px[0, r * ch][3] == 255 and max(px[0, r * ch][:3]) <= 8]
        if not mask_rows:
            _KEYED_CACHE[name] = "assets/%s.png" % name
            return _KEYED_CACHE[name]
        for r in mask_rows:
            for y in range(r * ch, min((r + 1) * ch, im.height)):
                for x in range(im.width):
                    pr, pg, pb, _ = px[x, y]
                    lum = max(pr, pg, pb)
                    # Neutral grey, not white: the same sheet is drawn on the dark page and on the
                    # PDF's light paper, and a white silhouette vanishes on one of them.
                    px[x, y] = (120, 120, 120, lum) if lum > 8 else (0, 0, 0, 0)
        im.save(ASSETS / f"{name}_keyed.png")
    _KEYED_CACHE[name] = "assets/%s_keyed.png" % name
    return _KEYED_CACHE[name]


def sprite_cards(images):
    """Sprite-page cards: one per manifest sheet, with the guppy body sheets split into two."""
    cards = []
    for entry in images:
        name = entry["name"]
        cols, rows = int(entry.get("cols", 1)), int(entry.get("rows", 1))
        cw, ch = int(entry["cellW"]), int(entry["cellH"])
        card = dict(entry)
        card["cols"], card["rows"] = cols, rows
        card["png"] = ASSETS / Path(keyed_asset(entry)).name
        card["section"] = section_for(name)
        card["owner"] = ""
        card["desc"] = review_meta.describe(name, review_meta.group_for(name))
        card["meta"] = _entry_meta(entry)
        state = GUPPY_BODY_STATES.get(name)
        if state and rows > GUPPY_STAGE_ROWS:
            stage = crop_rows(name, 0, GUPPY_STAGE_ROWS, ch, "guppy")
            carnivore = crop_rows(name, GUPPY_STAGE_ROWS, 1, ch, "oscar")
            if stage is not None and carnivore is not None:
                card["png"] = stage
                card["rows"] = GUPPY_STAGE_ROWS
                card["playCount"] = cols * GUPPY_STAGE_ROWS
                card["meta"] = "%dx%dpx · %dx%d cells · four guppy stage rows" % (
                    cols * cw, GUPPY_STAGE_ROWS * ch, cols, GUPPY_STAGE_ROWS)
                cards.append({
                    "name": "OSCAR · %s" % state,
                    "id": "IMAGE_%s row 5" % name,
                    "cols": cols, "rows": 1, "cellW": cw, "cellH": ch,
                    "playCount": cols, "anim": "",
                    "png": carnivore, "section": "Fish", "owner": "oscar",
                    "rank": list(GUPPY_BODY_STATES).index(name),
                    "meta": "%dx%dpx · %dx1 cells · row 5 of %s" % (
                        cols * cw, ch, cols, name),
                    "desc": "The carnivore row of %s - Oscar's %s art at every stage, because "
                            "Fish.SPECIES_DRAW fixes his row to 4." % (name, state),
                })
        cards.append(card)
    return cards


# --------------------------------------------------------------------------- animations PDF
# --------------------------------------------------------------------------- review pages
import math

import review_meta
import review_html


def _entry_meta(entry) -> str:
    return "%sx%s cells · %sx%spx · %s frames" % (
        entry.get("cols", 1), entry.get("rows", 1), entry.get("cellW"), entry.get("cellH"),
        entry.get("frameCount", 1))


## The selector screen's mermaid is painted without her tail: GameSelector draws MERYLTAIL over the
## stump at (152,405), scaled 0.65 and turned 145 degrees about the cell's notch (Q-0055). Reproduce
## that here so the review shows the whole Meryl exactly as the menu composes her.
def build_meryl_menu() -> Path | None:
    screen_path = ASSETS / "SELECTORSCREEN.png"
    tail_path = ASSETS / "MERYLTAIL.png"
    if not screen_path.exists() or not tail_path.exists():
        return None
    cell_w, cell_h = 238, 165
    scale = 0.65
    tail = Image.open(tail_path).convert("RGBA")
    cell = tail.crop((0, 0, cell_w, cell_h)).resize(
        (int(cell_w * scale), int(cell_h * scale)), Image.BILINEAR)
    pad = 1200
    big = Image.new("RGBA", (pad * 2, pad * 2), (0, 0, 0, 0))
    big.paste(cell, (pad, pad), cell)
    rotated = big.rotate(-145.0, resample=Image.BILINEAR, center=(pad, pad))
    theta = math.radians(145.0)
    notch = (107.0 * scale, 84.0 * scale)
    rx = notch[0] * math.cos(theta) - notch[1] * math.sin(theta)
    ry = notch[0] * math.sin(theta) + notch[1] * math.cos(theta)
    px = 152.0 - 4.0 - rx
    py = 405.0 - ry
    screen = Image.open(screen_path).convert("RGBA")
    layer = rotated.crop((int(pad - px), int(pad - py),
                          int(pad - px) + screen.width, int(pad - py) + screen.height))
    screen.alpha_composite(layer)
    out = OUT / "meryl_menu.png"
    screen.save(out)
    return out


def build_sprites_html(images) -> Path:
    cards = sprite_cards(images)
    by_name = {c["name"]: c for c in cards if not c["owner"]}
    owned = {}
    for card in cards:
        if card["owner"]:
            owned.setdefault(card["owner"], []).append(card)

    def item(card):
        return {"name": card["name"], "src": card["png"].relative_to(OUT).as_posix(),
                "desc": card["desc"], "meta": card["meta"]}

    menu = build_meryl_menu()
    groups = []
    for group in review_meta.GROUPS:
        items = [item(c) for c in sorted(owned.get(group["id"], []), key=lambda c: c["rank"])]
        for name in group["items"]:
            card = by_name.get(name)
            if card is None:
                if name == "MERYL_MENU" and menu is not None:
                    items.append({"name": name, "src": menu.name,
                                  "desc": review_meta.describe(name, group["id"]),
                                  "meta": "640x480px composite"})
                continue
            items.append(item(card))
        if items:
            groups.append(dict(group, items=items, count=len(items)))
    out = OUT / "sprites.html"
    return review_html.sprites_page(groups, out)


## What each row is, read from the sheets themselves (owner 2026-11-23: name the function, not the
## row number; then: the species sheets are states, not growth, and Oscar's rows are his layers).
## Every sheet was re-read row by row on 2026-11-23. A row that shows the body rotating through
## 180 degrees is a turn; a wide red mouth held open is an eat; a body fading white with X eyes is a
## death; a colour change is the starving twin. Pets and aliens are poses, so the names describe the
## pose the row actually holds.
ROW_NOTES = {
    "SYLV": {0: "swim", 1: "attack"},
    "MINISYLV": {0: "swim", 1: "attack"},
    "BALROG": {0: "walk", 1: "roar"},
    "GUS": {0: "idle", 1: "arms out", 2: "grin"},
    ## The robot holds a red-tipped claw overhead; row 1 is the body rotating to face the viewer with
    ## the claw lowered - there is no cannon in the art (owner 2026-11-23: alien labels are wrong).
    "DESTRUCTOR": {0: "idle, claw raised", 1: "turn"},
    "ULYSSES": {0: "walk", 1: "turn, arms down", 2: "turn, arms up"},
    "PSYCHOSQUID": {0: "red swim", 1: "red turn", 2: "blue swim", 3: "blue turn",
                    4: "red to blue"},
    "BILATERUS": {0: "swim, jaw open", 1: "swim, jaw wide", 2: "swim, jaw working",
                  3: "swim, fins out", 4: "mouth open", 5: "mouth wide",
                  6: "top-down, fins out", 7: "top-down, fins turned"},
    "BOSS": {0: "idle", 1: "tentacles out"},
    "HALO": {0: "glow, wide", 1: "glow, narrow"},
    "STINKY": {0: "crawl", 1: "turn", 2: "hide"},
    "NIKO": {0: "closed", 1: "opening, pearl", 2: "closing"},
    "ITCHY": {0: "swim", 1: "turn", 2: "eat", 3: "eat, turn"},
    "PREGO": {0: "swim", 1: "swim, belly full", 2: "turn", 3: "swim, belly full, head up"},
    "ZORF": {0: "swim", 1: "turn", 2: "spit"},
    "VERT": {0: "swim", 1: "turn"},
    "RUFUS": {0: "idle", 1: "snap"},
    "MERYL": {0: "swim", 1: "sing", 2: "turn", 3: "hair flip"},
    "WADSWORTH": {0: "swim", 1: "turn", 2: "mouth open (shelter)"},
    "SEYMOUR": {0: "swim", 1: "turn"},
    "SHRAPNEL": {0: "swim", 1: "turn"},
    "GUMBO": {0: "swim", 1: "turn"},
    "BLIP": {0: "swim", 1: "turn"},
    "RHUBARB": {0: "idle", 1: "claw raise"},
    "NIMBUS": {0: "swim", 1: "turn"},
    "AMP": {0: "swim", 1: "turn"},
    "GASH": {0: "swim", 1: "turn", 2: "bite"},
    "ANGIE": {0: "swim", 1: "turn"},
    "PRESTO": {0: "fish", 1: "turn", 2: "transform cloud"},
    "BRINKLEY": {0: "idle", 1: "eat, trunk up"},
    "NOSTRADAMUS": {0: "idle", 1: "turn"},
    "STANLEY": {0: "green walk", 1: "green turn", 2: "brown walk", 3: "brown turn",
                4: "brown eat", 5: "green to brown"},
    "WALTER": {0: "swim", 1: "turn", 2: "punch"},
    ## Fish species sheets: states per growth, or one row per state at one size. None of them is a
    ## plain growth ladder (owner 2026-11-23: Breeder has three growths, Grubber has no growth).
    "BREEDER": {0: "swim (growth 1)", 1: "turn (growth 1)", 2: "eat (growth 1)",
                3: "swim (growth 2)", 4: "turn (growth 2)", 5: "eat (growth 2)",
                6: "swim (growth 3)", 7: "turn (growth 3)", 8: "eat (growth 3)"},
    "HUNGRYBREEDER": {0: "starving swim (growth 1)", 1: "starving turn (growth 1)",
                      2: "starving death (growth 1)", 3: "starving swim (growth 2)",
                      4: "starving turn (growth 2)", 5: "starving death (growth 2)",
                      6: "starving swim (growth 3)", 7: "starving turn (growth 3)",
                      8: "starving death (growth 3)", 9: "starving eat (growth 1)",
                      10: "starving eat (growth 2)", 11: "starving eat (growth 3)"},
    "GRUBBER": {0: "swim", 1: "eat", 2: "starving swim", 3: "starving death",
                4: "starving eat"},
    "STARCATCHER": {0: "swim", 1: "starving swim", 2: "starving death"},
    "ULTRA": {0: "swim", 1: "eat", 2: "turn", 3: "death"},
    "GEKKO": {0: "swim", 1: "turn", 2: "eat", 3: "starving swim", 4: "starving turn",
              5: "starving death", 6: "starving eat"},
    "BALLS": {0: "white ball", 1: "beach ball", 2: "soccer ball", 3: "basketball"},
    ## Amp's own sheet: the swim and the turn. FOOD, MONEY, SHELLS, LASERS, AMPCHARGE and GUMBOLIGHT
    ## carry no playback metadata, so they are sprite cards rather than clips; their rows are named
    ## in `review_meta`'s descriptions instead.
    "AMP": {0: "swim", 1: "turn"},
    ## Oscar is one size, so his sheet is the four tinted layers of each pose, not a growth ladder
    ## (`Fish.SPECIES_DRAW` fixes his row; the draw stacks body mask, fin mask, teeth and body).
    "SIMCARNIVORE": {0: "swim · body mask", 1: "swim · fin mask", 2: "swim · teeth mask",
                     3: "swim · body", 4: "turn · body mask", 5: "turn · fin mask",
                     6: "turn · teeth mask", 7: "turn · body", 8: "eat · body mask",
                     9: "eat · fin mask", 10: "eat · teeth mask", 11: "eat · body"},
}

## One line per sheet that explains how its rows are organised, used in the clip descriptions.
ROW_CONTEXT = {
    "BREEDER": "Nine rows: three growth stages, each with swim, turn and eat.",
    "HUNGRYBREEDER": "Twelve rows: three starving growth stages, each with swim, turn and death, "
                     "then the eat pose at each of the three sizes.",
    "GRUBBER": "Five rows: brown swim and eat, then the starving green swim, death and eat.",
    "STARCATCHER": "Three rows: purple swim, green starving swim and green starving death.",
    "ULTRA": "Four rows at one size: swim, eat, turn and death.",
    "GEKKO": "Seven rows: green swim, turn and eat, then the starving yellow swim, turn, death "
             "and eat.",
    "BALLS": "Four ball designs, one per row: white, beach, soccer and basketball.",
    "AMP": "Two rows: the swim loop and the turn.",
    "SIMCARNIVORE": "Oscar's layered draw: three white masks (body, fin, teeth) on a keyed black "
                    "background and the black body, for the swim, turn and eat poses; the tank tints "
                    "the masks and stacks them (EV-0168).",
}

## Clips whose sheet playback mode is wrong for the row. Walter's punch is an action, not a loop:
## pingpong plays the glove out and back, so the clip runs forward once and holds the last frame.
ROW_MODE = {("WALTER", 2): "once"}

## The guppy groups are sizes, not row numbers. `Fish.row_for` draws row 1 for fish stage 0, row 2
## for stage 1, row 3 for stages 2-3 and row 4 for stage 4; the body sheets' fifth row is carnivore
## art and is not a guppy stage (EV-0239).
GUPPY_STAGE_GROUPS = [
    {"id": "guppy-small", "title": "Guppy · small",
     "blurb": "The smallest guppy, drawn for fish stage 0: swim, starving swim, eat, starving eat, "
              "turn, starving turn and corpse, plus the three eye layers."},
    {"id": "guppy-medium", "title": "Guppy · medium",
     "blurb": "One growth step up (fish stage 1): the same states at medium size."},
    {"id": "guppy-large", "title": "Guppy · large",
     "blurb": "The large body, drawn for fish stages 2 and 3."},
    {"id": "guppy-crowned", "title": "Guppy · crowned",
     "blurb": "The crowned stage-4 guppy. The body sheets' fifth row is carnivore art, so it is not "
              "a guppy size: it is the row Oscar draws and is on his card."},
]
GUPPY_STAGE_IDS = [g["id"] for g in GUPPY_STAGE_GROUPS]
GUPPY_ROW_STAGE = {0: "fish stage 0", 1: "fish stage 1", 2: "fish stages 2 and 3",
                   3: "fish stage 4"}
## Clip names inside a stage group say what the animation does; the section already says the size.
GUPPY_STATE_NAMES = {
    "SMALLSWIM": "Swim",
    "HUNGRYSWIM": "Starving swim",
    "SMALLEAT": "Eat",
    "HUNGRYEAT": "Starving eat",
    "SMALLTURN": "Turn",
    "HUNGRYTURN": "Starving turn",
    "SMALLDIE": "Corpse",
    "SIMSWIM1": "Eye layer · swim 1",
    "SIMSWIM2": "Eye layer · swim 2",
    "SIMSWIM3": "Eye layer · swim 3",
    "SIMTURN1": "Eye layer · turn 1",
    "SIMTURN2": "Eye layer · turn 2",
    "SIMTURN3": "Eye layer · turn 3",
    "SIMEAT1": "Eye layer · eat 1",
    "SIMEAT2": "Eye layer · eat 2",
    "SIMEAT3": "Eye layer · eat 3",
}
## The size is part of the clip name too, so a gif filename stays unique and the card still says
## what the animation does.
GUPPY_SIZE_WORD = {"guppy-small": "small", "guppy-medium": "medium",
                   "guppy-large": "large", "guppy-crowned": "crowned"}
GUPPY_STATE_ORDER = list(GUPPY_STATE_NAMES)
GUPPY_STATE_RANK = {name: rank for rank, name in enumerate(GUPPY_STATE_ORDER)}
## Body sheets use four stage rows; the eye layers only carry the first three.
GUPPY_STAGE_ROWS = 4
GUPPY_EYE_ROWS = 3
## The body sheets' fifth row is carnivore art (EV-0239). Oscar draws it at every stage
## (`Fish.SPECIES_DRAW` fixes his row to 4), so those rows are clips in his group, named
## "Swim (carnivore)" the way the sizes are.
GUPPY_CARNIVORE_ROW = 4
GUPPY_CARNIVORE_ID = "oscar"
GUPPY_CARNIVORE_WORD = "carnivore"


def _guppy_stage_key(name, row, group_id) -> str:
    if group_id != "guppy":
        return ""
    if not name.startswith(("SMALL", "HUNGRY")):
        return GUPPY_STAGE_IDS[row] if row < GUPPY_EYE_ROWS else ""
    if row < GUPPY_STAGE_ROWS:
        return GUPPY_STAGE_IDS[row]
    return GUPPY_CARNIVORE_ID if row == GUPPY_CARNIVORE_ROW else ""


def _clip(index, name, desc, frames, delays, anim, begin, end, cell, sheet, sheet_rel=None):
    starts, acc = [], 0
    for d in delays:
        starts.append(acc)
        acc += d
    span = acc + max(end, 0)
    count = len(frames)
    tick = max(delays[0] if delays else 1, 1)
    uniform = anim == "pingpong"
    cycle = (max(begin, 0) + (2 * (count - 1) * tick if uniform else span)) * TICK_MS / 1000
    return {
        "i": index,
        "name": name,
        "desc": desc,
        "anim": anim,
        "count": count,
        "cycle": cycle,
        "frames": [list(f) for f in frames],
        "delays": delays,
        "starts": starts,
        "span": span,
        "begin": max(begin, 0),
        "end": max(end, 0),
        "tick": tick,
        "per": False,
        "cell": cell,
        "sheet": sheet_rel or "assets/%s.png" % sheet,
    }


def animation_groups(images):
    """The same clip list the HTML renders: one clip per row, row names functional."""
    by_id = {g["id"]: g for g in review_meta.GROUPS}
    buckets = {}
    for entry in images:
        gid = review_meta.group_for(entry["name"])
        group = by_id.get(gid)
        if group is None:
            continue
        animated = bool(entry.get("anim")) and int(entry.get("playCount", 1)) > 1
        fish_rows = (not entry.get("anim")) and group["kind"] in ("fish", "alien") \
            and int(entry.get("cols", 1)) > 1 and int(entry.get("playCount", 1)) > 1
        if not (animated or fish_rows):
            continue
        cols = int(entry.get("cols", 1))
        rows = int(entry.get("rows", 1))
        if cols > 1 and rows > 1:
            for row in range(rows):
                target = _guppy_stage_key(entry["name"], row, gid)
                if target == "" and gid == "guppy":
                    continue  # rows past the stage count
                buckets.setdefault(target or gid, []).append((entry, row, animated))
        else:
            buckets.setdefault(gid, []).append((entry, None, animated))

    groups, index = [], 0

    def make_clip(entry, row, animated, group_id):
        nonlocal index
        sheet = entry["name"]
        cols = int(entry.get("cols", 1))
        rows = int(entry.get("rows", 1))
        cw = int(entry["cellW"])
        ch = int(entry["cellH"])
        cell = [cw, ch]
        rel = keyed_asset(entry)
        if row is None:
            frames = animation_frames(entry)
            delays = tick_delays(entry, len(frames))
            clip = _clip(index, sheet,
                         review_meta.CLIP_DESC.get(sheet) or review_meta.describe(sheet, group_id),
                         frames, delays, entry["anim"], int(entry.get("beginDelay", 0)),
                         int(entry.get("endDelay", 0)), cell, sheet, rel)
        else:
            frames = [[c * cw, row * ch, cw, ch] for c in range(cols)]
            delay = max(int(entry.get("frameDelay", 0)), 1) if animated else 5
            mode = ROW_MODE.get((sheet, row)) or (entry["anim"] if animated else "loop")
            begin = max(int(entry.get("beginDelay", 0)), 0) if animated else 0
            end = max(int(entry.get("endDelay", 0)), 0) if animated else 0
            note = ROW_NOTES.get(sheet, {}).get(row)
            size_word = GUPPY_SIZE_WORD.get(group_id)
            if size_word is None and group_id == GUPPY_CARNIVORE_ID and sheet in GUPPY_STATE_NAMES:
                size_word = GUPPY_CARNIVORE_WORD
            if size_word:
                label = "%s (%s)" % (GUPPY_STATE_NAMES.get(sheet, sheet), size_word)
                if size_word == GUPPY_CARNIVORE_WORD:
                    desc = "%s - row %d of %s, the carnivore art Oscar draws at every stage." % (
                        GUPPY_STATE_NAMES[sheet], row + 1, sheet)
                else:
                    desc = "%s Drawn for %s." % (review_meta.describe(sheet, "guppy"),
                                                 GUPPY_ROW_STAGE.get(row, "this stage"))
            elif note:
                label = "%s · %s" % (sheet, note)
                context = ROW_CONTEXT.get(sheet)
                if context:
                    desc = "%s - row %d of %d. %s" % (note[0].upper() + note[1:], row + 1,
                                                      rows, context)
                else:
                    desc = "%s - row %d of %d, its own animation; the tank never plays two rows " \
                           "as one loop." % (note[0].upper() + note[1:], row + 1, rows)
            else:
                # No sheet should reach this: every multi-row sheet has a ROW_NOTES entry. If one
                # does, say only where the row sits - never invent growth stages (EV-0244).
                label = "%s · row %d" % (sheet, row + 1)
                desc = "Row %d of %d; the sheet's rows have no recovered names, so this clip is " \
                       "its position on the sheet." % (row + 1, rows)
            clip = _clip(index, label, desc, frames, [delay] * cols, mode, begin, end, cell, sheet, rel)
        index += 1
        return clip

    def emit(group_id, title, blurb, items, kind="fish"):
        if group_id in GUPPY_STAGE_IDS:
            ordered = sorted(items, key=lambda it: (GUPPY_STATE_RANK.get(it[0]["name"], 99),
                                                    it[0]["name"]))
        elif group_id == GUPPY_CARNIVORE_ID:
            # Oscar: his state-sheet rows first, then the carnivore sheet, then the store icon.
            ordered = sorted(items, key=lambda it: (
                0 if it[0]["name"] in GUPPY_STATE_NAMES else
                2 if it[0]["name"].startswith("SCL_") else 1,
                GUPPY_STATE_RANK.get(it[0]["name"], 0), it[0]["name"], it[1] or 0))
        else:
            ordered = sorted(items, key=lambda it: (it[0]["name"].startswith("SCL_"),
                                                    it[0]["name"], it[1] or 0))
        # Rows that belong to one family (a growth, a colour, a pose's layers) become sub-sections of
        # the entity's group, so Breeder reads as three growths instead of nine loose rows.
        rest, sub_order, sub_items = [], [], {}
        for item in ordered:
            entry, row, animated = item
            key = None
            for sub_title, sub_blurb, sub_rows in review_meta.subgroups_for(entry["name"]):
                if row in sub_rows:
                    key = (entry["name"], sub_title)
                    if key not in sub_items:
                        sub_items[key] = {"title": sub_title, "blurb": sub_blurb, "items": []}
                        sub_order.append(key)
                    sub_items[key]["items"].append(item)
                    break
            if key is None:
                rest.append(item)
        # Loose clips first, then the row families, then the store/chooser icon: Oscar's real state-
        # sheet art stays ahead of his layer sheet, and no group opens with its SCL portrait.
        loose = [it for it in rest if not it[0]["name"].startswith("SCL_")]
        icons = [it for it in rest if it[0]["name"].startswith("SCL_")]
        clips = [make_clip(entry, row, animated, group_id) for entry, row, animated in loose]
        icon_clips = [make_clip(entry, row, animated, group_id) for entry, row, animated in icons]
        subs = [{"title": sub_items[k]["title"], "blurb": sub_items[k]["blurb"],
                 "clips": [make_clip(e, r, a, group_id) for e, r, a in sub_items[k]["items"]]}
                for k in sub_order]
        total = len(clips) + len(icon_clips) + sum(len(s["clips"]) for s in subs)
        if total:
            groups.append({"id": group_id, "title": title, "blurb": blurb, "kind": kind,
                           "clips": clips, "subs": subs, "icons": icon_clips, "count": total})

    stage_defs = {g["id"]: g for g in GUPPY_STAGE_GROUPS}
    for group in review_meta.GROUPS:
        if group["id"] == "guppy":
            for stage_id in GUPPY_STAGE_IDS:
                stage = stage_defs[stage_id]
                emit(stage_id, stage["title"], stage["blurb"], buckets.get(stage_id, []))
            continue
        emit(group["id"], group["title"], group["blurb"], buckets.get(group["id"], []),
             group["kind"])
    return groups


def group_clips(group):
    """Every clip of a group in page order: loose clips, row families, then the icon."""
    return (list(group["clips"]) + [c for sub in group.get("subs", []) for c in sub["clips"]]
            + list(group.get("icons", [])))


def build_animations_html(images) -> Path:
    out = OUT / "animations.html"
    return review_html.animations_page(animation_groups(images), out)


def slugify(text: str) -> str:
    name = text.replace(" · ", " - ").replace("·", "-").replace("/", "-")
    name = re.sub(r"[^A-Za-z0-9 ._-]", "", name).strip()
    return name or "clip"


def build_animation_pdf(images) -> Path:
    groups = animation_groups(images)
    clips_total = sum(g["count"] for g in groups)

    pdf = FPDF(orientation="P", unit="mm", format="A4")
    pdf.set_auto_page_break(False)
    pdf.alias_nb_pages()
    pdf.set_title("Insaniquarium remake - animation review")
    margin = 10.0
    page_w, page_h = 210.0, 297.0
    bottom = 278.0

    def footer():
        pdf.set_y(-12)
        pdf.set_font("Helvetica", "", 8)
        pdf.set_text_color(120, 120, 120)
        pdf.cell(0, 5, "fih - animation review (frame strips; live GIFs in animations/)", align="L")
        pdf.set_xy(-30, -12)
        pdf.cell(20, 5, f"{pdf.page_no()} / {{nb}}", align="R")

    def new_page():
        pdf.add_page()
        pdf.set_fill_color(*PAPER)
        pdf.rect(0, 0, page_w, page_h, style="F")
        footer()

    pdf.add_page()
    pdf.set_fill_color(*PAPER)
    pdf.rect(0, 0, page_w, page_h, style="F")
    pdf.set_text_color(*INK)
    pdf.set_font("Helvetica", "B", 21)
    pdf.set_xy(margin, 22)
    pdf.cell(0, 11, "Animation review - every clip in one file")
    pdf.set_font("Helvetica", "", 10.5)
    pdf.set_xy(margin, 34)
    pdf.multi_cell(
        page_w - 2 * margin, 5.2,
        "A PDF cannot play a GIF, so each card is a filmstrip: every frame of the clip in playback "
        "order, left to right and top to bottom, exactly the SpriteFrames order the game uses. The "
        "small label under a frame is its play position and hold in 36 Hz ticks. Live playback for "
        "the same clips is in animations/ (and animations.zip).",
    )
    pdf.set_xy(margin, 64)
    pdf.multi_cell(
        page_w - 2 * margin, 5.2,
        "Clips are the same rows the animation page shows: pets and aliens one row per pose (walk, "
        "roar, punch, ...), guppy states grouped by size, and species rows grouped into their "
        "growths, colour pairs and pose layers. Holds "
        "follow AnimState: per-frame delay when the sheet has one, else the sheet delay; the first "
        "frame is held beginDelay; once clips stop on their last frame; pingpong folds 0..N-1..1 at "
        "a uniform delay. The caption gives type, frame count, ticks per frame and total cycle time.",
    )
    pdf.set_xy(margin, 92)
    pdf.set_font("Helvetica", "B", 11)
    pdf.cell(0, 6, "Contents")
    y = 100
    pdf.set_font("Helvetica", "", 8.5)
    for group in groups:
        if y > bottom - 10:
            new_page()
            y = 16
        pdf.set_xy(margin + 4, y)
        pdf.cell(130, 4.4, group["title"])
        pdf.set_xy(margin + 140, y)
        pdf.cell(20, 4.4, str(group["count"]), align="R")
        y += 4.6
    pdf.set_xy(margin, y + 6)
    pdf.set_font("Helvetica", "", 8.5)
    pdf.set_text_color(90, 90, 90)
    pdf.multi_cell(
        page_w - 2 * margin, 4.6,
        f"{clips_total} clips in {len(groups)} groups. Frames are cropped from docs/review/assets, "
        "the same mask-composited sheets the game draws. Rebuild: tools/review/build_review.py.",
    )
    pdf.set_text_color(*INK)

    for group in groups:
        if pdf.get_y() > bottom - 30:
            new_page()
        y = pdf.get_y() + 3
        pdf.set_fill_color(28, 34, 44)
        pdf.rect(margin, y, page_w - 2 * margin, 8.5, style="F")
        pdf.set_text_color(255, 255, 255)
        pdf.set_font("Helvetica", "B", 10.5)
        pdf.set_xy(margin + 3, y + 0.8)
        pdf.cell(0, 7, f"{group['title'].upper()}   -   {group['count']} clips")
        pdf.set_text_color(*INK)
        y += 12
        rows = [("clip", clip) for clip in group["clips"]]
        for sub in group.get("subs", []):
            rows.append(("sub", sub))
            rows.extend(("clip", clip) for clip in sub["clips"])
        rows.extend(("clip", clip) for clip in group.get("icons", []))
        for kind_row, payload in rows:
            if kind_row == "sub":
                if y + 12 > bottom:
                    new_page()
                    y = 16
                pdf.set_font("Helvetica", "B", 8.8)
                pdf.set_text_color(60, 70, 90)
                pdf.set_xy(margin + 2, y)
                pdf.cell(0, 4.6, payload["title"].upper())
                y += 4.8
                pdf.set_font("Helvetica", "", 7.6)
                pdf.set_text_color(110, 110, 110)
                pdf.set_xy(margin + 2, y)
                pdf.cell(0, 4.0, payload["blurb"])
                y += 5.2
                pdf.set_text_color(*INK)
                continue
            clip = payload
            strip = clip_strip(clip)
            if strip is None:
                continue
            with Image.open(strip) as strip_image:
                iw, ih = strip_image.size
            draw_w = page_w - 2 * margin
            draw_h = draw_w * ih / iw
            if draw_h > 110:
                scale = 110 / draw_h
                draw_w *= scale
                draw_h = 110
            if y + draw_h + 12 > bottom:
                new_page()
                y = 16
            pdf.set_font("Helvetica", "B", 8.4)
            pdf.set_text_color(*INK)
            pdf.set_xy(margin, y)
            pdf.cell(0, 4.4, clip_caption(clip))
            y += 5.0
            pdf.image(str(strip), x=margin, y=y, w=draw_w, h=draw_h)
            y += draw_h + 3.5
            pdf.set_draw_color(200, 200, 196)
            pdf.set_line_width(0.2)
            pdf.line(margin, y, page_w - margin, y)
            y += 4.0
        pdf.set_y(y + 1)

    out = OUT / "animations.pdf"
    pdf.output(str(out))
    return out


def clip_caption(clip) -> str:
    count = clip["count"]
    if clip["anim"] == "pingpong":
        extra = "pingpong, %d frames, %d ticks/frame, cycle %.2fs" % (
            count, clip["tick"], clip["cycle"])
    else:
        extra = "%s, %d frames, %.2fs cycle" % (clip["anim"], count, clip["cycle"])
    if clip["begin"]:
        extra += ", first held %dt" % clip["begin"]
    if clip["end"]:
        extra += ", last +%dt" % clip["end"]
    return "%s   -   %s" % (clip["name"], extra)


STRIP_DIR = OUT / "frames"


def clip_strip(clip) -> Path:
    frames = clip["frames"]
    if not frames:
        return None
    sheet_path = ASSETS / clip["sheet"].split("/")[-1]
    if not sheet_path.exists():
        return None
    STRIP_DIR.mkdir(parents=True, exist_ok=True)
    out = STRIP_DIR / ("%s.png" % slugify(clip["name"]))
    with Image.open(sheet_path) as sheet:
        sheet = sheet.convert("RGBA")
        count = len(frames)
        cols = min(count, 10)
        cw = max(f[2] for f in frames)
        ch = max(f[3] for f in frames)
        scale = min(1.0, 132.0 / max(cw, ch)) if max(cw, ch) > 132 else 3.0
        if max(cw, ch) <= 44:
            scale = 3.0
        dw, dh = max(1, int(cw * scale)), max(1, int(ch * scale))
        label_h = 24
        gap = 7
        rows = math.ceil(count / cols)
        width = cols * dw + (cols + 1) * gap
        height = rows * (dh + label_h) + (rows + 1) * gap
        strip = Image.new("RGB", (width, height), (246, 246, 243))
        draw = ImageDraw.Draw(strip)
        font = label_font(15)
        delays = clip["delays"]
        uniform = clip["anim"] == "pingpong"
        for i, (x, y, w, h) in enumerate(frames):
            col, row = i % cols, i // cols
            cx = gap + col * (dw + gap)
            cy = gap + row * (dh + label_h + gap)
            for yy in range(cy, cy + dh, 10):
                for xx in range(cx, cx + dw, 10):
                    if ((xx - cx) // 10 + (yy - cy) // 10) % 2:
                        draw.rectangle([xx, yy, min(xx + 9, cx + dw - 1), min(yy + 9, cy + dh - 1)],
                                       fill=(232, 232, 228))
            cell = sheet.crop((x, y, x + w, y + h))
            if scale != 1.0:
                cell = cell.resize((max(1, int(w * scale)), max(1, int(h * scale))), Image.NEAREST)
            strip.paste(cell, (cx, cy), cell)
            draw.rectangle([cx, cy, cx + dw - 1, cy + dh - 1], outline=(150, 150, 148))
            hold = clip["tick"] if uniform else delays[i]
            draw.text((cx + 1, cy + dh + 3), "%d - %dt" % (i + 1, hold), fill=(40, 40, 40), font=font)
        strip.save(out)
    return out


# --------------------------------------------------------------------------- animations
def parse_tres(path: Path):
    """Frames of the 'default' animation, in order: [(x, y, w, h), ...]."""
    if not path.exists():
        return []
    text = path.read_text(encoding="utf-8")
    regions = {}
    pattern = re.compile(
        r'\[sub_resource type="AtlasTexture" id="([^"]+)"\](.*?)(?=\n\[|\Z)', re.S
    )
    for m in pattern.finditer(text):
        sub_id, body = m.group(1), m.group(2)
        region = re.search(r"region = Rect2\(([^)]+)\)", body)
        if region:
            parts = [float(v) for v in region.group(1).split(",")]
            regions[sub_id] = tuple(int(round(v)) for v in parts[:4])
    frames = []
    for ref in re.finditer(r'"texture": SubResource\("([^"]+)"\)', text):
        frame = regions.get(ref.group(1))
        if frame:
            frames.append(frame)
    return frames


## Frames of an animation in playback order: the SpriteFrames sequence when the .tres lines up,
## else the physical grid.
def animation_frames(entry):
    tres_path = None
    if entry.get("spriteFrames"):
        tres_path = ROOT / str(entry["spriteFrames"]).removeprefix("res://")
    frames = parse_tres(tres_path) if tres_path else []
    if len(frames) != int(entry["playCount"]):
        cw, ch = int(entry["cellW"]), int(entry["cellH"])
        frames = [((i % int(entry["cols"])) * cw, (i // int(entry["cols"])) * ch, cw, ch)
                  for i in range(int(entry["playCount"]))]
    return frames


def tick_delays(entry, count: int):
    """AnimState's per-position hold, in ticks."""
    timed = bool(entry.get("anim"))
    per = entry.get("perFrameDelay") or []
    if not timed:
        return [5] * count
    return [max(int(per[i]) if i < len(per) else int(entry.get("frameDelay", 0)), 1) for i in range(count)]


def schedule(entry, count: int):
    """[(frame, ticks), ...] for one cycle, matching AnimState.frame_at."""
    if count <= 1:
        return [(0, 18)]
    begin = max(int(entry.get("beginDelay", 0)), 0)
    if entry.get("anim") == "pingpong" and not entry.get("perFrameDelay"):
        step = max(int(entry.get("frameDelay", 0)), 1)
        period = 2 * (count - 1)
        seq = []
        for i in range(period):
            seq.append((i if i < count else period - i, step))
        if begin:
            seq.insert(0, (0, begin))
        return seq
    delays = tick_delays(entry, count)
    ends = max(int(entry.get("endDelay", 0)), 0)
    delays[-1] += ends
    seq = [(0, begin)] if begin else []
    seq += [(i, delays[i]) for i in range(count)]
    return seq


def cs(ticks: int) -> int:
    return max(1, int(round(ticks * TICK_MS / 10.0)))


def label_font(size: int):
    try:
        return ImageFont.load_default(size=size)
    except TypeError:
        return ImageFont.load_default()


def checker_canvas(size, pad=10):
    w, h = size
    img = Image.new("RGB", (w + pad * 2, h + pad * 2), CHECKER)
    d = ImageDraw.Draw(img)
    step = 8
    for yy in range(0, h + pad * 2, step):
        for xx in range(0, w + pad * 2, step):
            if (xx // step + yy // step) % 2:
                d.rectangle([xx, yy, xx + step - 1, yy + step - 1], fill=CHECKER_ALT)
    return img, d


## One cycle of a clip's playback, matching AnimState.frame_at: pingpong folds at a uniform delay,
## `once` holds the last frame, `loop` repeats, and begin/end holds pad the ends.
def clip_schedule(clip):
    count = clip["count"]
    if count <= 1:
        return [(0, 18)]
    begin = clip["begin"]
    if clip["anim"] == "pingpong":
        step = clip["tick"]
        period = 2 * (count - 1)
        seq = [(i if i < count else period - i, step) for i in range(period)]
        if begin:
            seq.insert(0, (0, begin))
        return seq
    delays = list(clip["delays"])
    delays[-1] += clip["end"]
    seq = [(0, begin)] if begin else []
    seq += [(i, delays[i]) for i in range(count)]
    return seq


def build_clip_gif(clip, sheet: Image.Image, out_dir: Path) -> tuple[Path, int]:
    frames = clip["frames"]
    count = len(frames)
    seq = clip_schedule(clip)
    first = frames[0]
    scale = 1
    if max(first[2], first[3]) <= 200:
        scale = max(1, min(4, int(220 / max(first[2], first[3]))))
    tw, th = first[2] * scale, first[3] * scale
    banner = 22
    canvas, draw = checker_canvas((tw, th))
    full_h = canvas.height + banner
    base = Image.new("RGB", (canvas.width, full_h), (17, 17, 17))
    base.paste(canvas, (0, 0))
    draw = ImageDraw.Draw(base)
    font = label_font(11)
    draw.text((8, canvas.height + 5), f"{clip['name']}  |  {clip['anim']}  {count}f",
              fill=(235, 235, 235), font=font)
    imgs = []
    durations = []
    for index, ticks in seq:
        cell = sheet.crop((frames[index][0], frames[index][1],
                           frames[index][0] + frames[index][2], frames[index][1] + frames[index][3]))
        if scale != 1:
            cell = cell.resize((tw, th), Image.NEAREST)
        frame = base.copy()
        if cell.mode != "RGBA":
            cell = cell.convert("RGBA")
        frame.paste(cell, (10, 10), cell)
        imgs.append(frame)
        durations.append(cs(ticks))
    if not imgs:
        return None, 0
    out = out_dir / ("%s.gif" % slugify(clip["name"]))
    kwargs = dict(save_all=True, append_images=imgs[1:], duration=[d * 10 for d in durations],
                  disposal=2, optimize=False)
    if clip["anim"] != "once":
        kwargs["loop"] = 0
    imgs[0].save(out, **kwargs)
    return out, len(imgs)


def main() -> None:
    images = load_data()
    OUT.mkdir(parents=True, exist_ok=True)
    # Stale filmstrips and crops from an older clip/sheet set would sit beside the new ones.
    for folder in (STRIP_DIR, CROP_DIR):
        if folder.exists():
            for old in folder.glob("*.png"):
                old.unlink()
    cards = sprite_cards(images)
    pdf_path = build_pdf(cards)
    print("pdf", pdf_path, round(pdf_path.stat().st_size / 1e6, 1), "MB")
    anim_pdf = build_animation_pdf(images)
    print("animation pdf", anim_pdf, round(anim_pdf.stat().st_size / 1e6, 1), "MB")
    anim_html = build_animations_html(images)
    print("animation html", anim_html, round(anim_html.stat().st_size / 1024, 1), "KB")
    sprite_html = build_sprites_html(images)
    print("sprite html", sprite_html, round(sprite_html.stat().st_size / 1024, 1), "KB")

    GIF_DIR.mkdir(parents=True, exist_ok=True)
    for old in GIF_DIR.glob("*.gif"):
        old.unlink()
    made = 0
    missing = []
    for group in animation_groups(images):
        for clip in group_clips(group):
            sheet_path = ASSETS / clip["sheet"].split("/")[-1]
            if not sheet_path.exists():
                missing.append(clip["name"])
                continue
            with Image.open(sheet_path) as sheet:
                gif, n = build_clip_gif(clip, sheet.convert("RGBA"), GIF_DIR)
            if gif:
                made += 1
    total = sum(p.stat().st_size for p in GIF_DIR.glob("*.gif"))
    print("gifs", made, "files", round(total / 1e6, 1), "MB", "missing", missing)
    zpath = OUT / "animations.zip"
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        for gif in sorted(GIF_DIR.glob("*.gif")):
            z.write(gif, gif.name)
    print("zip", zpath, round(zpath.stat().st_size / 1e6, 1), "MB")


if __name__ == "__main__":
    main()
