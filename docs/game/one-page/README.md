# How the one-page figures are computed

**The SVG is still the artefact.** [`../one-page.en.svg`](../one-page.en.svg)
is plain, self-contained, buildless text that GitHub renders and git diffs,
exactly as [the wrapper](../one-page.en.md#conventions) requires — nothing
here is needed to *use* it. This folder is how it was produced, and it exists
because half the figures cannot be hand-edited afterwards: a `{7,3}`
heptagrid and a Rule 110 spacetime diagram are computations, not drawings,
and a future editor nudging polygon coordinates by hand would silently make
them wrong.

If that trade is not worth it, delete this folder. The SVGs stand alone.

```
python3 docs/game/one-page/build.py docs/game
```

Writes `one-page.en.svg` and `one-page.fr.svg`. No dependencies beyond the
standard library.

| File | What it holds |
|---|---|
| `content.py` | Every string, in both languages, with the line breaks written by hand — a break point is a design decision and should diff like one. The two dicts must keep identical key sets; `build.py` reads both through the same code path, so a missing key is a crash rather than a silently English page. |
| `figures.py` | The palette (mirroring `graphics.Colours`) and the ten figures. Each returns an SVG fragment using presentation attributes only. |
| `build.py` | Layout. All geometry is constants at the top and a single `render(L)`. |

## The two figures that are real mathematics

**The heptagrid** (`poincare_73`) is built by taking a half-turn about the
hyperbolic midpoint of each shared edge, which is an orientation-preserving
symmetry of any `{p, q}`. The obvious alternative — reflecting in the full
geodesic through an edge — is *not* a symmetry when `q` is odd, because the
extended edge of a `{7,3}` heptagon runs through the interior of another
heptagon; it produces a plausible-looking picture with nine polygons meeting
at a vertex instead of three. The circumradius is `cosh R = cot(π/p)·cot(π/q)`,
which is the *circum*radius and not the inradius; the two differ by enough to
make overlapping polygons that still look like a tiling at a glance. Both
mistakes were made and caught here, and the check that catches them is cheap:

```python
# every interior vertex of {7,3} is shared by exactly three heptagons
import collections, figures
c = collections.Counter()
for poly in figures.poincare_73(3):
    for z in poly:
        c[(round(z.real, 4), round(z.imag, 4))] += 1
print(collections.Counter(c.values()))   # interior vertices -> 3
```

It also reproduces the ring populations `1, 7, 21, 56, …` that
[`hyperbolic-simulation-findings.md`](../../building/notes/hyperbolic-simulation-findings.md)
measured in the engine — the ratio converging on φ², independently.

**The Ribbon** (`rule110`) is elementary rule 110 on a wrapped row, drawn in
perspective so the past recedes, which is the tilt
[`world.md`](../world.md)'s own Ribbon entry settled on after a flat
heightfield foreshortened to nothing at eye height.
