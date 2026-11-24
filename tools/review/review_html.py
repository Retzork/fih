"""HTML rendering for the review pages.

Both pages share one layout: a sticky sidebar of entity groups, a search box, and one section per
entity. The sprite page shows every manifest sheet as a card with a description and a click-to-zoom
lightbox; the animation page shows every clip playing on its own canvas, grouped under its entity.
"""

import html
import json
from pathlib import Path

KIND_HEADINGS = [
    ("fish", "Fish"),
    ("pet", "Pets"),
    ("alien", "Aliens"),
    ("item", "Food, coins & eggs"),
    ("effect", "Effects & weapon"),
    ("world", "Tanks & world"),
    ("ui", "Interface"),
    ("other", "Other"),
]

CSS = r"""
  :root { color-scheme: dark; --ink:#e9e9e4; --dim:#98a1ac; --line:#2e3540; --card:#1c2027; --bg:#14161a; }
  * { box-sizing: border-box; }
  html { scroll-behavior: smooth; }
  body { margin: 0; background: var(--bg); color: var(--ink);
         font: 13px/1.45 -apple-system, Segoe UI, Roboto, Helvetica, Arial, sans-serif; }
  a { color: #8fb0ff; text-decoration: none; }
  header { position: sticky; top: 0; z-index: 20; background: #1b1f26; border-bottom: 1px solid var(--line);
           padding: 9px 18px; display: flex; flex-wrap: wrap; gap: 8px 18px; align-items: center; }
  header h1 { font-size: 15px; margin: 0; font-weight: 650; }
  header .nav { font-size: 12px; }
  .spacer { flex: 1; }
  .controls { display: flex; flex-wrap: wrap; gap: 7px 14px; align-items: center; }
  .controls label { color: #aeb6c0; font-size: 12px; }
  button, select, input[type=search] { background: #252b34; color: var(--ink); border: 1px solid #39414d;
           border-radius: 6px; padding: 4px 9px; font: inherit; font-size: 12px; }
  button:hover { background: #2f3742; cursor: pointer; }
  .layout { display: grid; grid-template-columns: 232px minmax(0, 1fr); }
  nav { position: sticky; top: 46px; align-self: start; height: calc(100vh - 46px); overflow-y: auto;
        padding: 12px 10px 40px 14px; border-right: 1px solid var(--line); font-size: 12px; }
  nav h3 { font-size: 10.5px; letter-spacing: .09em; text-transform: uppercase; color: #7f8894;
           margin: 14px 0 4px; }
  nav a { display: flex; justify-content: space-between; gap: 6px; padding: 3px 6px; border-radius: 4px;
          color: #c9d0d8; }
  nav a:hover { background: #262d37; color: #fff; }
  nav a span { color: #7f8894; }
  main { padding: 14px 18px 80px; min-width: 0; }
  section.group { margin: 0 0 30px; scroll-margin-top: 56px; }
  .ghead { display: flex; align-items: baseline; gap: 10px; flex-wrap: wrap;
           padding: 7px 10px; background: #222833; border-left: 4px solid #5b7cfa; border-radius: 4px; }
  .ghead h2 { font-size: 14px; margin: 0; }
  .ghead .count { color: #8f98a4; font-size: 11.5px; }
  .blurb { color: #aeb6c0; font-size: 12px; margin: 7px 2px 12px; max-width: 1100px; }
  .sub { font-size: 11.5px; margin: 14px 0 2px; color: #cfd6df; letter-spacing: .05em;
         text-transform: uppercase; }
  .subblurb { color: #98a1ac; font-size: 11.5px; margin: 0 2px 8px; }
  .grid.icons { margin-top: 14px; }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 10px; }
  .card { background: var(--card); border: 1px solid var(--line); border-radius: 7px; padding: 8px;
          display: flex; flex-direction: column; gap: 6px; min-width: 0; }
  .card:hover { border-color: #46505f; }
  .thumb { border: 0; padding: 0; margin: 0; background: none; cursor: zoom-in; display: flex;
           justify-content: center; align-items: center; min-height: 46px; border-radius: 5px; overflow: hidden; }
  .thumb.checker { background-image:
      linear-gradient(45deg, #24272d 25%, transparent 25%, transparent 75%, #24272d 75%),
      linear-gradient(45deg, #24272d 25%, #1a1d22 25%, #1a1d22 75%, #24272d 75%);
      background-size: 14px 14px; background-position: 0 0, 7px 7px; }
  .thumb.white { background: #f4f4f0; }
  .thumb.dark { background: #0e1013; }
  .thumb img { display: block; max-width: 100%; image-rendering: pixelated; }
  .name { font-weight: 600; font-size: 12.5px; overflow-wrap: anywhere; }
  .desc { color: #b7c0ca; font-size: 11.5px; }
  .meta { color: #808a96; font-size: 10.5px; font-variant-numeric: tabular-nums; }
  .live { color: #7fd18b; font-size: 11px; font-variant-numeric: tabular-nums; }
  .hidden { display: none !important; }
  #lightbox { position: fixed; inset: 0; z-index: 50; background: rgba(6,8,11,.92); display: none;
              flex-direction: column; padding: 16px 18px; }
  #lightbox.open { display: flex; }
  #lightbox .bar { display: flex; gap: 14px; align-items: center; flex-wrap: wrap; padding-bottom: 10px; }
  #lightbox .title { font-weight: 650; }
  #lightbox .desc { max-width: 720px; }
  #lightbox .stage { flex: 1; overflow: auto; display: flex; justify-content: center; align-items: flex-start; }
  #lightbox .stage.checker { background-image:
      linear-gradient(45deg, #24272d 25%, transparent 25%, transparent 75%, #24272d 75%),
      linear-gradient(45deg, #24272d 25%, #1a1d22 25%, #1a1d22 75%, #24272d 75%);
      background-size: 24px 24px; background-position: 0 0, 12px 12px; }
  #lightbox img { image-rendering: pixelated; }
  .hint { color: #7f8894; font-size: 11px; }
"""

SPRITE_JS = r"""
let zoomMode = 'fit', scaleFactor = 1, bg = 'checker';
let current = null, order = [];

function applyZoom() {
  document.querySelectorAll('.thumb').forEach(el => {
    const img = el.querySelector('img');
    if (!img) return;
    img.style.width = zoomMode === 'fit' ? '100%' : (img.naturalWidth * parseInt(zoomMode, 10)) + 'px';
    img.style.maxWidth = zoomMode === 'fit' ? '100%' : 'none';
  });
  if (current) setStageSize();
}

function setStageSize() {
  if (!current) return;
  const img = document.getElementById('lb-img');
  const stage = document.getElementById('lb-stage');
  const s = zoomMode === 'fit'
    ? Math.max(1, Math.min(4, (stage.clientWidth - 48) / img.naturalWidth))
    : parseInt(zoomMode, 10);
  img.style.width = Math.round(img.naturalWidth * s) + 'px';
  img.style.maxWidth = 'none';
}

window.addEventListener('resize', () => { if (current) setStageSize(); });

function openLightbox(card) {
  const group = card.closest('section.group');
  order = [...group.querySelectorAll('.card')];
  showLightbox(card);
}

function showLightbox(card) {
  current = card;
  document.getElementById('lb-img').src = card.dataset.src;
  document.getElementById('lb-title').textContent = card.dataset.name;
  document.getElementById('lb-desc').textContent = card.dataset.desc;
  document.getElementById('lb-meta').textContent = card.dataset.meta;
  document.getElementById('lb-count').textContent = (order.indexOf(card) + 1) + ' / ' + order.length;
  document.getElementById('lightbox').classList.add('open');
  const img = document.getElementById('lb-img');
  if (img.complete) setStageSize(); else img.onload = setStageSize;
}

function step(delta) {
  if (!current || !order.length) return;
  const i = (order.indexOf(current) + delta + order.length) % order.length;
  showLightbox(order[i]);
}

function closeLightbox() { document.getElementById('lightbox').classList.remove('open'); current = null; }

document.querySelectorAll('.thumb').forEach(el => {
  el.addEventListener('click', () => openLightbox(el.closest('.card')));
});
document.getElementById('lb-prev').onclick = () => step(-1);
document.getElementById('lb-next').onclick = () => step(1);
document.getElementById('lb-close').onclick = closeLightbox;
document.getElementById('lightbox').addEventListener('click', e => { if (e.target.id === 'lightbox') closeLightbox(); });
document.getElementById('lb-stage').className = 'stage checker';
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') closeLightbox();
  if (e.key === 'ArrowLeft') step(-1);
  if (e.key === 'ArrowRight') step(1);
});
document.getElementById('zoom').onchange = e => { zoomMode = e.target.value; applyZoom(); };
document.getElementById('bg').onchange = e => {
  bg = e.target.value;
  document.querySelectorAll('.thumb').forEach(el => el.className = 'thumb ' + bg);
  document.getElementById('lb-stage').className = 'stage ' + (bg === 'white' ? 'white' : bg === 'dark' ? 'dark' : 'checker');
};
document.getElementById('filter').oninput = e => {
  const q = e.target.value.trim().toLowerCase();
  document.querySelectorAll('.card').forEach(el => {
    el.classList.toggle('hidden', q !== '' && !el.dataset.name.toLowerCase().includes(q));
  });
  document.querySelectorAll('section.group').forEach(sec => {
    sec.classList.toggle('hidden', ![...sec.querySelectorAll('.card')].some(c => !c.classList.contains('hidden')));
  });
  document.querySelectorAll('nav a').forEach(a => {
    const sec = document.querySelector(a.getAttribute('href'));
    a.classList.toggle('hidden', !!sec && sec.classList.contains('hidden'));
  });
};
applyZoom();
"""

ANIM_JS = r"""
const TICK_MS = 1000 / 36;
let speed = 1, playing = true, zoomMode = 'auto', loopOnce = true;
let worldTick = 0, last = performance.now();

for (const c of CLIPS) {
  c.canvas = document.getElementById('cv' + c.i);
  c.ctx = c.canvas.getContext('2d');
  c.card = c.canvas.closest('.card');
  c.frameEl = c.canvas.parentElement;
  c.liveEl = document.getElementById('lv' + c.i);
  c.start = 0;
  c.img = new Image();
  c.img.src = c.sheet;
  c.base = Math.max(1, Math.min(4, Math.floor(120 / Math.max(c.cell[0], c.cell[1]))));
}

function layout() {
  for (const c of CLIPS) {
    const s = zoomMode === 'auto' ? c.base : parseInt(zoomMode, 10);
    const w = c.cell[0] * s, h = c.cell[1] * s;
    c.canvas.width = w; c.canvas.height = h;
    c.canvas.style.width = w + 'px'; c.canvas.style.height = h + 'px';
  }
}

function frameFor(c, local) {
  const n = c.count;
  if (n <= 1) return 0;
  let t = local - c.begin;
  if (t < 0) return 0;
  if (c.anim === 'pingpong' && !c.per) {
    const period = 2 * (n - 1);
    const step = Math.floor(t / c.tick) % period;
    return step < n ? step : period - step;
  }
  if (c.anim === 'once' && !loopOnce) {
    if (t >= c.span) return n - 1;
  } else {
    t = t % c.span;
  }
  for (let k = n - 1; k >= 0; k--) if (t >= c.starts[k]) return k;
  return 0;
}

function draw() {
  const now = performance.now();
  const dt = now - last; last = now;
  if (playing) worldTick += dt / TICK_MS * speed;
  for (const c of CLIPS) {
    const local = worldTick - c.start;
    const idx = frameFor(c, local);
    const f = c.frames[idx];
    if (c.img.complete && c.img.naturalWidth) {
      const s = c.canvas.width / c.cell[0];
      c.ctx.clearRect(0, 0, c.canvas.width, c.canvas.height);
      c.ctx.imageSmoothingEnabled = false;
      c.ctx.drawImage(c.img, f[0], f[1], f[2], f[3], 0, 0, f[2] * s, f[3] * s);
    }
    if (c.liveEl) {
      const held = c.anim === 'once' && !loopOnce && local - c.begin >= c.span;
      const cycle = held ? c.span : Math.max(0, local - c.begin) % c.span;
      c.liveEl.textContent = 'frame ' + (idx + 1) + '/' + c.count +
        '  ' + (cycle / 36).toFixed(2) + 's' + (held ? '  held' : '');
    }
  }
  requestAnimationFrame(draw);
}

document.getElementById('toggle').onclick = e => {
  playing = !playing;
  e.target.textContent = playing ? 'Pause' : 'Play';
};
document.getElementById('restart').onclick = () => { for (const c of CLIPS) c.start = worldTick; };
document.getElementById('speed').onchange = e => { speed = parseFloat(e.target.value); };
document.getElementById('zoom').onchange = e => { zoomMode = e.target.value; layout(); };
document.getElementById('bg').onchange = e => {
  document.querySelectorAll('.frame').forEach(el => el.className = 'frame ' + e.target.value);
};
document.getElementById('looponce').onchange = e => { loopOnce = e.target.checked; };
document.getElementById('filter').oninput = e => {
  const q = e.target.value.trim().toLowerCase();
  document.querySelectorAll('.card').forEach(el => {
    el.classList.toggle('hidden', q !== '' && !el.dataset.name.toLowerCase().includes(q));
  });
  document.querySelectorAll('.subblock').forEach(blk => {
    blk.classList.toggle('hidden', ![...blk.querySelectorAll('.card')].some(c => !c.classList.contains('hidden')));
  });
  document.querySelectorAll('section.group').forEach(sec => {
    sec.classList.toggle('hidden', ![...sec.querySelectorAll('.card')].some(c => !c.classList.contains('hidden')));
  });
  document.querySelectorAll('nav a').forEach(a => {
    const sec = document.querySelector(a.getAttribute('href'));
    a.classList.toggle('hidden', !!sec && sec.classList.contains('hidden'));
  });
};
for (const c of CLIPS) {
  if (c.anim === 'once') c.card.classList.add('once');
  c.card.onclick = () => { c.start = worldTick; };
}
layout();
requestAnimationFrame(draw);
"""

SHELL = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>{title}</title>
<style>{css}</style>
</head>
<body>
<header>
  <h1>{heading}</h1>
  <div class="nav"><a href="{other_href}">{other_label}</a></div>
  <div class="spacer"></div>
  {controls}
</header>
<div class="layout">
  <nav>{nav}</nav>
  <main>{main}</main>
</div>
{extra}
<script>{js}</script>
</body>
</html>
"""


def _esc(text: str) -> str:
    return html.escape(str(text), quote=True)


def _nav(groups, page_prefix: str) -> str:
    parts = []
    for kind, heading in KIND_HEADINGS:
        items = [g for g in groups if g["kind"] == kind]
        if not items:
            continue
        parts.append('<h3>%s</h3>' % heading)
        for g in items:
            parts.append('<a href="#g-%s"><span class="t">%s</span><span>%d</span></a>'
                         % (_esc(g["id"]), _esc(g["title"]), g["count"]))
    return "\n".join(parts)


def _sprites_controls() -> str:
    return """<div class="controls">
      <label>Zoom <select id="zoom">
        <option value="fit" selected>fit</option><option value="1">1x</option>
        <option value="2">2x</option><option value="3">3x</option>
      </select></label>
      <label>Background <select id="bg">
        <option value="checker" selected>checker</option><option value="dark">dark</option><option value="white">white</option>
      </select></label>
      <input id="filter" type="search" placeholder="filter by name...">
      <span class="hint">click art to zoom</span>
    </div>"""


def sprites_page(groups, out_path: Path) -> Path:
    sections = []
    for g in groups:
        cards = []
        for item in g["items"]:
            cards.append(
                '<div class="card" data-name="{name}" data-src="{src}" data-desc="{desc}" data-meta="{meta}">'
                '<button class="thumb checker" type="button"><img src="{src}" alt="{name}"></button>'
                '<div class="name">{name}</div><div class="desc">{desc}</div><div class="meta">{meta}</div>'
                '</div>'.format(name=_esc(item["name"]), src=_esc(item["src"]), desc=_esc(item["desc"]),
                                meta=_esc(item["meta"])))
        sections.append(
            '<section class="group" id="g-%s"><div class="ghead"><h2>%s</h2><span class="count">%d item%s</span></div>'
            '<p class="blurb">%s</p><div class="grid">%s</div></section>'
            % (_esc(g["id"]), _esc(g["title"]), g["count"], "" if g["count"] == 1 else "s",
               _esc(g["blurb"]), "\n".join(cards)))

    nav = _nav(groups, "")
    lightbox = """<div id="lightbox">
  <div class="bar">
    <span class="title" id="lb-title"></span>
    <span class="hint" id="lb-count"></span>
    <span class="desc" id="lb-desc"></span>
    <span class="spacer"></span>
    <span class="hint" id="lb-meta"></span>
    <button id="lb-prev" type="button">Prev</button>
    <button id="lb-next" type="button">Next</button>
    <button id="lb-close" type="button">Close</button>
  </div>
  <div class="stage checker" id="lb-stage"><img id="lb-img" alt=""></div>
</div>"""

    page = SHELL.format(
        title="Sprite review - grouped by entity",
        heading="Sprite review - grouped by entity",
        other_href="animations.html",
        other_label="Animations page ->",
        controls=_sprites_controls(),
        nav=nav,
        main="\n".join(sections),
        extra=lightbox,
        css=CSS,
        js=SPRITE_JS,
    )
    out_path.write_text(page, encoding="utf-8")
    return out_path


def _anim_controls() -> str:
    return """<div class="controls">
      <button id="toggle" type="button">Pause</button>
      <button id="restart" type="button">Restart all</button>
      <label>Speed <select id="speed">
        <option value="0.25">0.25x</option><option value="0.5">0.5x</option>
        <option value="1" selected>1x</option><option value="2">2x</option><option value="4">4x</option>
      </select></label>
      <label>Zoom <select id="zoom">
        <option value="auto" selected>auto</option><option value="1">1x</option>
        <option value="2">2x</option><option value="3">3x</option><option value="4">4x</option>
      </select></label>
      <label>Background <select id="bg">
        <option value="checker" selected>checker</option><option value="dark">dark</option><option value="white">white</option>
      </select></label>
      <label><input id="looponce" type="checkbox" checked> loop <code>once</code></label>
      <input id="filter" type="search" placeholder="filter by name...">
    </div>"""


def _anim_card(clip) -> str:
    return (
        '<div class="card" data-name="{name}">'
        '<div class="frame checker"><canvas id="cv{i}"></canvas></div>'
        '<div class="name">{name}</div><div class="desc">{desc}</div>'
        '<div class="meta">{anim} · {count} frames · {cycle:.2f}s</div>'
        '<div class="live" id="lv{i}"></div>'
        '</div>'.format(name=_esc(clip["name"]), desc=_esc(clip["desc"]), anim=_esc(clip["anim"]),
                        count=clip["count"], cycle=clip["cycle"], i=clip["i"]))


def animations_page(groups, out_path: Path) -> Path:
    sections = []
    for g in groups:
        blocks = []
        if g["clips"]:
            blocks.append('<div class="grid">%s</div>' % "\n".join(_anim_card(c) for c in g["clips"]))
        for sub in g.get("subs", []):
            blocks.append(
                '<div class="subblock"><h3 class="sub">%s</h3><p class="subblurb">%s</p>'
                '<div class="grid">%s</div></div>'
                % (_esc(sub["title"]), _esc(sub["blurb"]),
                   "\n".join(_anim_card(c) for c in sub["clips"])))
        if g.get("icons"):
            blocks.append('<div class="grid icons">%s</div>'
                          % "\n".join(_anim_card(c) for c in g["icons"]))
        sections.append(
            '<section class="group" id="g-%s"><div class="ghead"><h2>%s</h2><span class="count">%d clip%s</span></div>'
            '<p class="blurb">%s</p>%s</section>'
            % (_esc(g["id"]), _esc(g["title"]), g["count"], "" if g["count"] == 1 else "s",
               _esc(g["blurb"]), "\n".join(blocks)))

    clips = [clip for g in groups for clip in g["clips"]]
    clips += [clip for g in groups for sub in g.get("subs", []) for clip in sub["clips"]]
    clips += [clip for g in groups for clip in g.get("icons", [])]
    data = json.dumps(clips, separators=(",", ":"))
    js = "const CLIPS = %s;\n%s" % (data, ANIM_JS)

    page = SHELL.format(
        title="Animation review - grouped by entity",
        heading="Animation review - grouped by entity",
        other_href="sprites.html",
        other_label="Sprite page ->",
        controls=_anim_controls(),
        nav=_nav(groups, ""),
        main="\n".join(sections),
        extra="",
        css=CSS,
        js=js,
    )
    out_path.write_text(page, encoding="utf-8")
    return out_path
