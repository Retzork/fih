#!/usr/bin/env python
"""Build docs/review/scenes.html from a real scene-gallery run.

The captures and the manifest come from the game itself:

    & "<godot>" --path . --audio-driver Dummy --script res://tools/godot/scene_gallery.gd
    python tools/review/build_scenes.py

Every card's facts (tank, money, fish, dialog, paused state) are read from the live run, so the page
cannot drift from the build it documents. Missing captures are shown as failures instead of being
dropped.
"""

from __future__ import annotations

import base64
import html
import json
from pathlib import Path

from review_html import CSS

ROOT = Path(__file__).resolve().parents[2]
SCENES = ROOT / "docs" / "review" / "scenes"
MANIFEST = SCENES / "manifest.json"
OUT = ROOT / "docs" / "review" / "scenes.html"

GROUPS = [
    ("Menus", "The shipped menus and their dialogs."),
    ("Tank", "Live tanks at different points in the adventure."),
    ("Shop", "The in-tank shop screen."),
    ("Progression", "The between-level cards and the loss card."),
    ("Dialogs", "The tank's own modal screens."),
    ("Modes", "Time Trial, Challenge and the tank-final bonus round."),
]

EXTRA_CSS = r"""
  main.scenes { padding: 14px 18px 80px; }
  .scene { padding: 0; overflow: hidden; gap: 0; }
  .scene .frame { background: #0d0f13; display: flex; justify-content: center; align-items: center;
                  border-bottom: 1px solid var(--line); }
  .scene .frame img { display: block; width: 100%; image-rendering: pixelated; cursor: zoom-in; }
  .scene .body { padding: 9px 11px 11px; display: flex; flex-direction: column; gap: 7px; }
  .scene h3 { margin: 0; font-size: 13.5px; }
  .chip { display: inline-block; font-size: 10.5px; letter-spacing: .04em; text-transform: uppercase;
          color: #9fb4ff; background: #212a3d; border: 1px solid #31406a; border-radius: 999px;
          padding: 1px 8px; margin-left: 6px; vertical-align: 1px; }
  .facts { display: grid; grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
           gap: 3px 10px; margin: 0; font-size: 11px; }
  .facts div { display: flex; gap: 5px; min-width: 0; }
  .facts dt { color: #7f8894; }
  .facts dd { margin: 0; color: #cfd6df; font-variant-numeric: tabular-nums; overflow-wrap: anywhere; }
  .route { font: 11px/1.4 ui-monospace, Consolas, monospace; color: #93a2b6; background: #171b21;
           border: 1px solid var(--line); border-radius: 5px; padding: 4px 6px; overflow-wrap: anywhere; }
  .bad { border-color: #7d3b3b; }
  .bad .status { color: #ff9c9c; font-size: 11px; }
  .grid.scene-grid { grid-template-columns: repeat(auto-fill, minmax(430px, 1fr)); }
  @media (max-width: 760px) { .grid.scene-grid { grid-template-columns: 1fr; } }
"""

JS = r"""
const search = document.getElementById('q');
const cards = Array.from(document.querySelectorAll('.scene'));
function applyFilter() {
  const q = (search.value || '').toLowerCase().trim();
  const group = document.querySelector('nav a.active')?.dataset.group || '';
  cards.forEach(card => {
    const hit = !q || card.dataset.search.includes(q);
    const inGroup = !group || card.dataset.group === group;
    card.classList.toggle('hidden', !(hit && inGroup));
  });
  document.querySelectorAll('section.group').forEach(sec => {
    const any = sec.querySelectorAll('.scene:not(.hidden)').length > 0;
    sec.classList.toggle('hidden', !any);
  });
}
search.addEventListener('input', applyFilter);
document.querySelectorAll('nav a').forEach(a => a.addEventListener('click', e => {
  document.querySelectorAll('nav a').forEach(x => x.classList.remove('active'));
  a.classList.add('active');
  applyFilter();
}));
const lb = document.getElementById('lightbox');
document.querySelectorAll('.frame img').forEach(img => img.addEventListener('click', () => {
  document.getElementById('lb-img').src = img.src;
  document.getElementById('lb-title').textContent = img.dataset.title || '';
  lb.classList.add('open');
}));
document.getElementById('lb-close').addEventListener('click', () => lb.classList.remove('open'));
lb.addEventListener('click', e => { if (e.target === lb) lb.classList.remove('open'); });
document.addEventListener('keydown', e => { if (e.key === 'Escape') lb.classList.remove('open'); });
"""


_DATA_URIS: dict[Path, str] = {}


def data_uri(path: Path) -> str:
    """Embed the capture so the page is one self-contained file (the preview serves only the HTML)."""
    if path not in _DATA_URIS:
        _DATA_URIS[path] = "data:image/png;base64," + base64.b64encode(
            path.read_bytes()).decode("ascii")
    return _DATA_URIS[path]


def esc(value) -> str:
    return html.escape(str(value), quote=True)


def load() -> dict:
    if not MANIFEST.exists():
        raise SystemExit(
            "missing %s - run tools/godot/scene_gallery.gd first" % MANIFEST)
    return json.loads(MANIFEST.read_text(encoding="utf-8"))


def facts_html(facts: dict) -> str:
    rows = []
    for key in sorted(facts):
        rows.append(
            "<div><dt>%s</dt><dd>%s</dd></div>" % (esc(key), esc(facts[key])))
    return "".join(rows)


def card(shot: dict, index: int) -> str:
    slug = str(shot.get("slug", "shot-%d" % index))
    title = str(shot.get("title", slug))
    group = str(shot.get("group", "Other"))
    image = SCENES / (slug + ".png")
    ok = shot.get("status", "ok") == "ok" and image.exists()
    notes = shot.get("notes") or []
    if not image.exists():
        notes = list(notes) + ["capture file is missing"]
    search_text = " ".join([
        slug, title, group, str(shot.get("description", "")),
        str(shot.get("route", "")), json.dumps(shot.get("facts", {})),
    ]).lower()
    frame = (
        '<button class="thumb frame" type="button">'
        '<img src="%s" alt="%s" data-title="%s" loading="lazy"></button>'
        % (esc(data_uri(image)), esc(title), esc(title))
    ) if image.exists() else '<div class="frame" style="padding:30px">no capture</div>'
    status = "" if ok else '<div class="status">%s</div>' % esc("; ".join(notes))
    return (
        '<article class="card scene%s" data-group="%s" data-search="%s">'
        '%s<div class="body"><h3>%s<span class="chip">%s</span></h3>'
        '<div class="desc">%s</div>%s<dl class="facts">%s</dl>'
        '<div class="route">%s</div>%s</div></article>'
        % (" bad" if not ok else "", esc(group), esc(search_text), frame,
           esc(title), esc(group), esc(shot.get("description", "")),
           "", facts_html(shot.get("facts", {})), esc(shot.get("route", "")), status)
    )


def build() -> None:
    data = load()
    shots = data.get("shots", [])
    grouped: dict[str, list[dict]] = {}
    for shot in shots:
        grouped.setdefault(str(shot.get("group", "Other")), []).append(shot)
    order = [name for name, _ in GROUPS] + [
        name for name in grouped if name not in dict(GROUPS)]

    sidebar = []
    sections = []
    for name in order:
        group_shots = grouped.get(name)
        if not group_shots:
            continue
        blurb = dict(GROUPS).get(name, "")
        cards = "".join(card(shot, i) for i, shot in enumerate(group_shots))
        sections.append(
            '<section class="group" id="g-%s"><div class="ghead"><h2>%s</h2>'
            '<span class="count">%d shot%s</span></div>'
            '<p class="blurb">%s</p><div class="grid scene-grid">%s</div></section>'
            % (esc(name.lower()), esc(name), len(group_shots),
               "" if len(group_shots) == 1 else "s", esc(blurb), cards))
        sidebar.append('<a href="#g-%s" data-group="%s">%s <span>%d</span></a>'
                       % (esc(name.lower()), esc(name), esc(name), len(group_shots)))

    sidebar.insert(0, '<h3>Shots</h3><a href="#top" data-group="">All scenes '
                      '<span>%d</span></a>' % len(shots))
    bad = sum(1 for shot in shots if shot.get("status", "ok") != "ok")
    generated = esc(data.get("generated_at", "unknown"))
    window = data.get("window", [0, 0])
    content = data.get("content", {})
    summary = (
        "%d captures from one live run &middot; %d failure%s &middot; window %sx%s &middot; "
        "content %s/%s &middot; generated %s &middot; Godot %s"
        % (len(shots), bad, "" if bad == 1 else "s", window[0], window[1],
           content.get("loaded", "?"), content.get("total", "?"), generated,
           esc(data.get("godot", "?")))
    )

    page = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Scene gallery - Insaniquarium remake</title>
<style>{CSS}{EXTRA_CSS}</style></head>
<body>
<header><h1>Scene gallery</h1>
  <span class="nav"><a href="sprites.html">Sprites</a> &middot; <a href="animations.html">Animations</a></span>
  <div class="spacer"></div>
  <div class="controls"><input id="q" type="search" placeholder="Filter scenes, facts, routes&hellip;" size="34"></div>
</header>
<div class="layout">
<nav>{''.join(sidebar)}</nav>
<main class="scenes">
  <p class="blurb">{summary}</p>
  <p class="hint">Captured by <code>tools/godot/scene_gallery.gd</code> driving the port's own entry
  points, then rendered by <code>tools/review/build_scenes.py</code>. Re-run the two commands to sync
  this page with the current build; the facts under each shot are read from the live run, not typed.
  Click a shot to enlarge it.</p>
  {''.join(sections)}
</main></div>
<div id="lightbox"><div class="bar"><span class="title" id="lb-title"></span>
  <span class="desc">Click outside or press Escape to close.</span>
  <div class="spacer"></div><button id="lb-close" type="button">Close</button></div>
  <div class="stage"><img id="lb-img" alt=""></div></div>
<script>{JS}</script>
</body></html>
"""
    OUT.write_text(page, encoding="utf-8")
    print("scenes: %d cards -> %s (%d failures)" % (len(shots), OUT, bad))


if __name__ == "__main__":
    build()
