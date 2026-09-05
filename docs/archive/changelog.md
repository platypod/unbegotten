# Changelog

Bugs that have been fixed, oldest first. When a bug in `docs/open/bug-tracker.md`
gets fixed, move its entry here and add the date and fixing commit.

Fixes that predate this file live only in git history
(`git log --grep='^fix'`) and in `docs/archive/project-log.md`'s narrative entries —
not backfilled here.

---

<!-- Add new entries below this line, oldest first. Format:

## YYYY-MM-DD — Short title

One-line description of the bug and the fix. Commit: `<hash>`.

-->

## 2026-08-10 — Camera could enter a wall's solitary end

Walking toward the dead end of a wall (no neighbouring segment) at the wrong
angle could still let the camera clip into it a little. Fixed as a side
effect of `GeodesicCollision`'s new distance-based wall clearance check
(`WALL_CLEARANCE`), which keeps the player away from a closed segment's own
thickness by point-to-segment distance — including near either endpoint, not
just along its middle. Commit: `1a713e9`.

## 2026-09-03 — Canvas stopped tracking the window after load

The game froze at whatever size the window was during loading: resizing,
rotating a phone, or opening devtools left the picture cropped or letterboxed
for the rest of the session. Heaps' `GlDriver.resize()` writes an inline pixel
size onto the canvas when `canvas.style.width == ""`, which is how it defers to
a page that sized the canvas itself — and sizing it from the stylesheet leaves
that property empty. Inline beats the stylesheet, so `#webgl { width: 100% }`
died on the first frame, the canvas' bounding rect never changed again, and the
`ResizeObserver` Heaps installs on it never fired. Fixed by sizing the canvas
inline in `index.html`/`walk.html` so the browser's layout owns it and Heaps
only reads it; no Haxe change was needed. Commit: `118c071`.

## 2026-09-05 — Browsers served a stale bundle after every release

A deployed release kept showing the previous build until a hard reload. The
image shipped no nginx config, so it used `nginx:alpine`'s stock default:
`Last-Modified` and `ETag`, but no `Cache-Control` at all. With no
`Cache-Control`, a browser falls back to *heuristic caching* — it invents a
freshness lifetime, conventionally about 10% of the age since
`Last-Modified`, and reuses the file without asking. Nothing was
misconfigured; the server never said anything about caching, so the browser
guessed. Fixed twice over: `no-cache` on `index.html` and `game.js` so
they are revalidated rather than guessed at (`v0.16.1`), then a content
hash in the bundle's own filename so a new build is a new URL and the stale
one simply 404s (`v0.16.2`, commit `cd862b5`).
