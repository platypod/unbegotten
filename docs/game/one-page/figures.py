"""Computed figures for the Unbegotten one-page design.

Everything here produces plain SVG fragments with presentation attributes
only -- no <style>, no defs, no external references -- so the emitted page
stays a single self-contained file that GitHub renders and git diffs.
"""
import math, cmath

# ---------------------------------------------------------------- palette
VOID    = "#05070A"; DEEP  = "#0A0E16"; BASE = "#111A22"
MID     = "#1B2530"; RAISED= "#2A3846"; EDGE = "#3D4E5E"
LIVE    = "#38E8FF"; ACT   = "#3BC47A"; DENY = "#E5484D"; MARK = "#FFB627"
T_HI    = "#E8EFF5"; T_MID = "#C9D3DD"; T_LO = "#8494A2"; T_DIM = "#5A6874"; T_FNT = "#3D4E5E"


def f(v):
    """Trim floats so the SVG diffs like code rather than like noise."""
    return ("%.2f" % v).rstrip("0").rstrip(".")


# ------------------------------------------------------- hyperbolic {7,3}
def poincare_73(levels=4):
    """The ternary heptagrid in the Poincare disk.

    Neighbours are reached by a half-turn about the hyperbolic midpoint of
    the shared edge -- an orientation-preserving symmetry of any {p,q}.
    Reflecting in the full geodesic through an edge is *not* a symmetry
    when q is odd, which is the trap here: the extended edge of a {7,3}
    heptagon runs through the interior of another heptagon.
    """
    p, q = 7, 3
    # circumradius: cosh R = cot(pi/p) cot(pi/q) -- and cosh R = cosh a cosh b
    # over the (pi/p, pi/q, pi/2) triangle, which is the check that it is
    # the circumradius and not the inradius.
    coshR = (1.0 / math.tan(math.pi / p)) * (1.0 / math.tan(math.pi / q))
    R = math.acosh(coshR)
    r = math.tanh(R / 2.0)                      # euclidean radius in the disk
    centre = [cmath.rect(r, 2 * math.pi * k / p - math.pi / 2) for k in range(p)]

    def to_origin(m, z):
        return (z - m) / (1 - m.conjugate() * z)

    def from_origin(m, w):
        return (w + m) / (1 + m.conjugate() * w)

    def midpoint(a, b):
        bp = to_origin(a, b)
        if abs(bp) < 1e-15:
            return a
        half = math.tanh(math.atanh(min(abs(bp), 1 - 1e-12)) / 2.0)
        return from_origin(a, cmath.rect(half, cmath.phase(bp)))

    def half_turn(m, z):
        return from_origin(m, -to_origin(m, z))

    polys, seen = [], set()

    def key(poly):
        c = sum(poly) / len(poly)
        return (round(c.real, 5), round(c.imag, 5))

    frontier = [centre]
    seen.add(key(centre)); polys.append(centre)
    for _ in range(levels):
        nxt = []
        for poly in frontier:
            for i in range(p):
                m = midpoint(poly[i], poly[(i + 1) % p])
                new = [half_turn(m, z) for z in poly]
                k = key(new)
                if k in seen or abs(sum(new) / p) > 0.982:
                    continue
                seen.add(k); polys.append(new); nxt.append(new)
        frontier = nxt
    return polys


def fig_sprawl(x, y, w, h):
    """Poincare disk {7,3}, with the legible near-zone marked."""
    cx, cy = x + w / 2, y + h / 2
    rad = min(w, h) / 2 - 6
    out = ['<circle cx="%s" cy="%s" r="%s" fill="%s" stroke="%s" stroke-width="1"/>'
           % (f(cx), f(cy), f(rad), DEEP, RAISED)]
    for poly in poincare_73(6):
        pts = " ".join("%s,%s" % (f(cx + z.real * rad), f(cy + z.imag * rad)) for z in poly)
        d = abs(sum(poly) / len(poly))
        col = EDGE if d < 0.30 else (RAISED if d < 0.66 else MID)
        sw = 1.3 if d < 0.30 else (0.9 if d < 0.66 else 0.5)
        out.append('<polygon points="%s" fill="none" stroke="%s" stroke-width="%s"/>'
                   % (pts, col, f(sw)))
    # the only thing you can actually read: a couple of cells around you
    out.append('<circle cx="%s" cy="%s" r="%s" fill="none" stroke="%s" stroke-width="1.4"/>'
               % (f(cx), f(cy), f(rad * 0.30), LIVE))
    out.append('<circle cx="%s" cy="%s" r="3" fill="%s"/>' % (f(cx), f(cy), LIVE))
    return "\n".join(out)


# ------------------------------------------------------------- rule 110
def rule110(width, gens, seed_right=True):
    row = [0] * width
    row[width - 1 if seed_right else width // 2] = 1
    rows = [row[:]]
    for _ in range(gens - 1):
        nxt = [0] * width
        for i in range(width):
            l = row[(i - 1) % width]; c = row[i]; r = row[(i + 1) % width]
            nxt[i] = 0 if (l, c, r) in ((1, 1, 1), (1, 0, 0), (0, 0, 0)) else 1
        row = nxt
        rows.append(row[:])
    return rows


def fig_ribbon(x, y, w, h):
    """Rule 110's spacetime diagram as a hillside descending into the past.

    Generation zero is at the top (furthest north, oldest); the strip is
    drawn in perspective so the near rows are wide and the far ones narrow,
    which is the space's own legibility law.
    """
    gens, width = 30, 46
    rows = rule110(width, gens)
    out = []
    for g, row in enumerate(rows):
        t = g / (gens - 1.0)                       # 0 = far/past, 1 = near
        rowy = y + 6 + (h - 22) * t
        halfw = (w / 2 - 4) * (0.22 + 0.78 * t)
        cw = (halfw * 2) / width
        ch = max(1.2, (h - 22) / gens * (0.45 + 0.55 * t))
        for i, v in enumerate(row):
            if not v:
                continue
            col = LIVE if t > 0.72 else (EDGE if t > 0.4 else RAISED)
            out.append('<rect x="%s" y="%s" width="%s" height="%s" fill="%s"/>'
                       % (f(x + w / 2 - halfw + i * cw), f(rowy), f(cw * 0.86), f(ch), col))
    # the monolith standing on generation zero
    mx = x + w / 2
    out.append('<rect x="%s" y="%s" width="7" height="20" fill="%s"/>' % (f(mx - 3.5), f(y - 8), MARK))
    return "\n".join(out)


# ---------------------------------------------------------------- the fold
def fig_fold(x, y, w, h):
    """A geodesic sphere walked from inside: see far, not near."""
    cx, cy = x + w / 2, y + h / 2
    rad = min(w, h) / 2 - 6
    out = ['<circle cx="%s" cy="%s" r="%s" fill="%s" stroke="%s" stroke-width="1.4"/>'
           % (f(cx), f(cy), f(rad), DEEP, EDGE)]
    # hex-ish interior scaffold: latitude ellipses + meridian arcs
    for k in (-0.66, -0.33, 0.0, 0.33, 0.66):
        ry = rad * 0.30 * (1 - abs(k) * 0.55)
        out.append('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="none" stroke="%s" stroke-width="0.9"/>'
                   % (f(cx), f(cy + rad * k), f(rad * math.sqrt(max(0.02, 1 - k * k))), f(ry), MID))
    for a in range(0, 180, 30):
        rx = rad * abs(math.cos(math.radians(a)))
        out.append('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="none" stroke="%s" stroke-width="0.7"/>'
                   % (f(cx), f(cy), f(max(1.0, rx)), f(rad), MID))
    # the twelve forced pentagons -- icosahedral, so five up, five down, two poles
    pent = [(0, -1.0)]
    for i in range(5):
        a = 2 * math.pi * i / 5
        pent.append((math.cos(a) * 0.90, -0.42))
        pent.append((math.cos(a + math.pi / 5) * 0.90, 0.42))
    pent.append((0, 1.0))
    for px, py in pent:
        out.append('<circle cx="%s" cy="%s" r="3.4" fill="%s"/>'
                   % (f(cx + px * rad * 0.86), f(cy + py * rad * 0.86), MARK))
    # the player, and what the player can see
    py = cy + rad * 0.80
    for tgt in (-0.72, -0.35, 0.15, 0.6):
        out.append('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="0.8"/>'
                   % (f(cx), f(py), f(cx + tgt * rad), f(cy - rad * 0.62), LIVE))
    out.append('<circle cx="%s" cy="%s" r="3.2" fill="%s"/>' % (f(cx), f(py), LIVE))
    # the blind zone: what you cannot see is your own cell
    out.append('<circle cx="%s" cy="%s" r="%s" fill="none" stroke="%s" stroke-width="1.2" stroke-dasharray="3 3"/>'
               % (f(cx), f(py), f(rad * 0.22), DENY))
    return "\n".join(out)


# ---------------------------------------------------------------- the weft
def fig_weft(x, y, w, h):
    """A sphere with an antipodal rule laid over it: close here, opens there."""
    cx, cy = x + w / 2, y + h / 2
    rad = min(w, h) / 2 - 8
    out = ['<circle cx="%s" cy="%s" r="%s" fill="%s" stroke="%s" stroke-width="1.4"/>'
           % (f(cx), f(cy), f(rad), DEEP, EDGE)]
    for k in (-0.55, 0.0, 0.55):
        out.append('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="none" stroke="%s" stroke-width="0.9"/>'
                   % (f(cx), f(cy + rad * k), f(rad * math.sqrt(max(0.02, 1 - k * k))), f(rad * 0.26), MID))
    for a in (0, 45, 90, 135):
        out.append('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="none" stroke="%s" stroke-width="0.9"/>'
                   % (f(cx), f(cy), f(max(1.2, rad * abs(math.cos(math.radians(a))))), f(rad), MID))
    ang = math.radians(215)
    ux, uy = math.cos(ang), math.sin(ang)
    px, py = cx + ux * rad * 0.74, cy + uy * rad * 0.74
    qx, qy = cx - ux * rad * 0.74, cy - uy * rad * 0.74
    out.append('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="1" stroke-dasharray="5 5"/>'
               % (f(px), f(py), f(qx), f(qy), T_DIM))

    def wall(bx, by, col, closed):
        tx, ty = -uy, ux                       # tangent, perpendicular to the radius
        x1, y1, x2, y2 = bx - tx * 17, by - ty * 17, bx + tx * 17, by + ty * 17
        if closed:
            return ('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="4.5"/>'
                    % (f(x1), f(y1), f(x2), f(y2), col))
        return ('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="2.4" stroke-dasharray="4 5"/>'
                % (f(x1), f(y1), f(x2), f(y2), col))

    out.append(wall(cx + ux * rad * 0.34, cy + uy * rad * 0.34, DENY, True))
    out.append(wall(cx - ux * rad * 0.34, cy - uy * rad * 0.34, ACT, False))
    out.append('<circle cx="%s" cy="%s" r="5" fill="%s"/>' % (f(px), f(py), LIVE))
    out.append('<circle cx="%s" cy="%s" r="5" fill="none" stroke="%s" stroke-width="1.5" stroke-dasharray="2 2"/>'
               % (f(qx), f(qy), LIVE))
    return "\n".join(out)

# -------------------------------------------------------------- the repeat
def _skyline(x, y, w, h, seed, odd=False):
    out, n = [], 6
    bw = w / n
    for i in range(n):
        r = ((seed * 7919 + i * 104729) % 97) / 97.0
        bh = h * (0.32 + 0.62 * r)
        col = MARK if (odd and i == 3) else MID
        out.append('<rect x="%s" y="%s" width="%s" height="%s" fill="%s"/>'
                   % (f(x + i * bw + 1), f(y + h - bh), f(bw - 2), f(bh), col))
        # windows: the facades really are cells
        rows = max(1, int(bh / 6))
        for rr in range(rows):
            for cc in range(2):
                if ((seed * 31 + i * 17 + rr * 5 + cc) % 3) == 0:
                    out.append('<rect x="%s" y="%s" width="1.6" height="1.6" fill="%s"/>'
                               % (f(x + i * bw + 3 + cc * 4), f(y + h - bh + 3 + rr * 6),
                                  MARK if (odd and i == 3) else LIVE))
    return out


def fig_repeat(x, y, w, h):
    """Many separate, identical tiles -- and one that has stopped being one."""
    out, cols, rows = [], 3, 2
    tw, th = (w - 8) / cols, (h - 8) / rows
    for r in range(rows):
        for c in range(cols):
            tx, ty = x + 4 + c * tw, y + 4 + r * th
            odd = (r == 0 and c == 2)
            out.append('<rect x="%s" y="%s" width="%s" height="%s" fill="%s" stroke="%s" stroke-width="%s"/>'
                       % (f(tx), f(ty), f(tw - 4), f(th - 4), DEEP,
                          MARK if odd else RAISED, "1.4" if odd else "0.7"))
            out += _skyline(tx + 4, ty + 4, tw - 12, th - 12, 5, odd)
    return "\n".join(out)


# ---------------------------------------------------------------- the turn
def fig_turn(x, y, w, h):
    """A Mobius band, and the single boundary curve that reads out your lift.

    The boundary is one curve of twice the band's own period: trace it with
    s = +1 for a lap and with s = -1 for the next and you have drawn the rail
    readout the biome already ships -- pale for one lift, dashed for the other.
    """
    cx, cy = x + w / 2, y + h / 2
    R, bw = min(w, h) * 0.33, min(w, h) * 0.235

    def pt(t, s):
        half = t / 2.0
        rr = R + s * bw * math.cos(half)
        y3 = rr * math.sin(t)
        z = s * bw * math.sin(half)
        return (cx + rr * math.cos(t), cy + y3 * 0.42 - z * 0.92, y3)

    N, quads = 96, []
    for i in range(N):
        t0, t1 = 2 * math.pi * i / N, 2 * math.pi * (i + 1) / N
        a, b, c, d = pt(t0, -1), pt(t0, 1), pt(t1, 1), pt(t1, -1)
        quads.append((min(a[2], b[2], c[2], d[2]), a, b, c, d))
    quads.sort(key=lambda q: q[0])                     # painter's, back to front
    out = []
    for depth, a, b, c, d in quads:
        out.append('<polygon points="%s,%s %s,%s %s,%s %s,%s" fill="%s" stroke="%s" stroke-width="0.5"/>'
                   % (f(a[0]), f(a[1]), f(b[0]), f(b[1]), f(c[0]), f(c[1]),
                      f(d[0]), f(d[1]), EDGE if depth > 0 else RAISED, DEEP))
    for s, col, dash in ((1, LIVE, None), (-1, T_LO, "6 4")):
        pts = [pt(2 * math.pi * i / 160, s) for i in range(161)]
        path = "M " + " L ".join("%s %s" % (f(p[0]), f(p[1])) for p in pts)
        out.append('<path d="%s" fill="none" stroke="%s" stroke-width="1.8"%s/>'
                   % (path, col, ' stroke-dasharray="%s"' % dash if dash else ''))
    return "\n".join(out)

# -------------------------------------------------------------- the defect
def fig_defect(x, y, w, h):
    """A cone point developed flat: the wedge really is missing, and a loop
    around the apex returns you turned by exactly the angle that is gone."""
    cx, cy = x + w / 2, y + h / 2 + 6
    rad = min(w, h) / 2 - 12
    deficit = 100.0
    a0, a1 = -90 + deficit / 2, 270 - deficit / 2
    p0 = (cx + rad * math.cos(math.radians(a0)), cy + rad * math.sin(math.radians(a0)))
    p1 = (cx + rad * math.cos(math.radians(a1)), cy + rad * math.sin(math.radians(a1)))
    # the sector that is gone, ghosted, so that "gone" is a thing you can see
    out = ['<path d="M %s %s L %s %s A %s %s 0 0 1 %s %s Z" fill="none" stroke="%s" '
           'stroke-width="1" stroke-dasharray="3 4"/>'
           % (f(cx), f(cy), f(p1[0]), f(p1[1]), f(rad), f(rad), f(p0[0]), f(p0[1]), T_FNT)]
    out.append('<path d="M %s %s L %s %s A %s %s 0 1 1 %s %s Z" fill="%s" stroke="%s" stroke-width="1.2"/>'
               % (f(cx), f(cy), f(p0[0]), f(p0[1]), f(rad), f(rad), f(p1[0]), f(p1[1]), BASE, EDGE))
    for e in (p0, p1):                                  # the two glued cut edges
        out.append('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="2"/>'
                   % (f(cx), f(cy), f(e[0]), f(e[1]), MARK))
    for k in (0.42, 0.72):
        pts = [(cx + rad * k * math.cos(math.radians(a0 + (a1 - a0) * i / 48)),
                cy + rad * k * math.sin(math.radians(a0 + (a1 - a0) * i / 48))) for i in range(49)]
        out.append('<path d="M %s" fill="none" stroke="%s" stroke-width="0.8"/>'
                   % (" L ".join("%s %s" % (f(p[0]), f(p[1])) for p in pts), MID))

    def arrow(ax, ay, deg, col, L=24):
        ex, ey = ax + L * math.cos(math.radians(deg)), ay + L * math.sin(math.radians(deg))
        hx, hy = ex - 7 * math.cos(math.radians(deg - 24)), ey - 7 * math.sin(math.radians(deg - 24))
        gx, gy = ex - 7 * math.cos(math.radians(deg + 24)), ey - 7 * math.sin(math.radians(deg + 24))
        return ('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="2"/>'
                '<polygon points="%s,%s %s,%s %s,%s" fill="%s"/>'
                % (f(ax), f(ay), f(ex), f(ey), col, f(ex), f(ey), f(hx), f(hy), f(gx), f(gy), col))

    # you set out along one cut edge and return along the other, never turning
    sa, ea = math.radians(a0 + 8), math.radians(a1 - 8)
    out.append(arrow(cx + rad * 0.72 * math.cos(sa), cy + rad * 0.72 * math.sin(sa), a0 - 90, T_LO))
    out.append(arrow(cx + rad * 0.72 * math.cos(ea), cy + rad * 0.72 * math.sin(ea), a0 - 90 + deficit, LIVE))
    out.append('<circle cx="%s" cy="%s" r="4.5" fill="%s"/>' % (f(cx), f(cy), MARK))
    out.append('<text x="%s" y="%s" font-family="ui-monospace, SFMono-Regular, Menlo, Consolas, monospace" '
               'font-size="10" fill="%s" text-anchor="middle">%s&#176; gone</text>'
               % (f(cx), f(cy - rad * 0.70), MARK, f(deficit)))
    return "\n".join(out)

# ---------------------------------------------------------------- the knot
def fig_knot(x, y, w, h):
    """The octagon with opposite sides identified: a b a' b' c d c' d'."""
    cx, cy = x + w / 2, y + h / 2
    rad = min(w, h) / 2 - 16
    pts = [(cx + rad * math.cos(math.pi / 8 + math.pi * k / 4),
            cy + rad * math.sin(math.pi / 8 + math.pi * k / 4)) for k in range(8)]
    out = ['<polygon points="%s" fill="%s" stroke="%s" stroke-width="1"/>'
           % (" ".join("%s,%s" % (f(p[0]), f(p[1])) for p in pts), DEEP, RAISED)]
    # each side is identified with the one opposite it -- same colour, matched arrows
    cols = [LIVE, ACT, LIVE, ACT, LIVE, ACT, LIVE, ACT]
    labels = ["a", "b", "a", "b", "c", "d", "c", "d"]
    for k in range(8):
        p, q = pts[k], pts[(k + 1) % 8]
        out.append('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="2.2"/>'
                   % (f(p[0]), f(p[1]), f(q[0]), f(q[1]), cols[k]))
        mx, my = (p[0] + q[0]) / 2, (p[1] + q[1]) / 2
        dx, dy = q[0] - p[0], q[1] - p[1]
        L = math.hypot(dx, dy); dx, dy = dx / L, dy / L
        s = 1 if k < 4 else -1
        out.append('<polygon points="%s,%s %s,%s %s,%s" fill="%s"/>'
                   % (f(mx + dx * 5 * s), f(my + dy * 5 * s),
                      f(mx - dx * 3 * s + dy * 3.4), f(my - dy * 3 * s - dx * 3.4),
                      f(mx - dx * 3 * s - dy * 3.4), f(my - dy * 3 * s + dx * 3.4), cols[k]))
        ox, oy = mx + (mx - cx) * 0.20, my + (my - cy) * 0.20
        out.append('<text x="%s" y="%s" font-family="ui-monospace, SFMono-Regular, Menlo, Consolas, monospace" '
                   'font-size="10" fill="%s" text-anchor="middle">%s</text>'
                   % (f(ox), f(oy + 3.5), cols[k], labels[k]))
    # one room, many images: the landmark is asymmetric on purpose
    for a in (30, 150, 270):
        lx, ly = cx + rad * 0.44 * math.cos(math.radians(a)), cy + rad * 0.44 * math.sin(math.radians(a))
        out.append('<polygon points="%s,%s %s,%s %s,%s" fill="%s"/>'
                   % (f(lx), f(ly - 7), f(lx + 6), f(ly + 5), f(lx - 3), f(ly + 5), MARK))
    return "\n".join(out)


# -------------------------------------------------------------- the garden
def fig_garden(x, y, w, h, label="NOT BUILT"):
    """Not built. The honest figure for a space that does not exist is an empty frame."""
    out = ['<rect x="%s" y="%s" width="%s" height="%s" fill="%s" stroke="%s" stroke-width="1.4" stroke-dasharray="6 6"/>'
           % (f(x + 4), f(y + 4), f(w - 8), f(h - 8), VOID, DENY)]
    cx, cy = x + w / 2, y + h / 2 + 10
    out.append('<text x="%s" y="%s" font-family="ui-monospace, SFMono-Regular, Menlo, Consolas, monospace" '
               'font-size="13" fill="%s" text-anchor="middle" letter-spacing="2">%s</text>'
               % (f(cx), f(cy + 26), DENY, label))
    # the three positions the space exists to pose
    for i, (dx, lab, col) in enumerate(((-1, "1", MARK), (0, "3", MARK), (1, "2", MARK))):
        ax = cx + dx * 52
        out.append('<line x1="%s" y1="%s" x2="%s" y2="%s" stroke="%s" stroke-width="1.4"/>'
                   % (f(cx), f(cy), f(ax), f(cy - 42), col))
        out.append('<circle cx="%s" cy="%s" r="7" fill="%s" stroke="%s" stroke-width="1"/>'
                   % (f(ax), f(cy - 46), VOID, col))
        out.append('<text x="%s" y="%s" font-family="ui-monospace, SFMono-Regular, Menlo, Consolas, monospace" '
                   'font-size="9" fill="%s" text-anchor="middle">%s</text>' % (f(ax), f(cy - 43), col, lab))
    out.append('<circle cx="%s" cy="%s" r="3.4" fill="%s"/>' % (f(cx), f(cy), MARK))
    return "\n".join(out)


# ----------------------------------------------------------- the still life
def fig_stilllife(x, y, w, h):
    """The hub gains curvature as you do. Flat at the start; by the end, not."""
    out, n = [], 3
    cw = w / n
    for s in range(n):
        bend = (0.0, 0.55, 1.15)[s]
        col = (MID, RAISED, EDGE)[s]
        ox, oy = x + s * cw + cw / 2, y + h / 2
        gw, gh = cw - 24, h * 0.54

        def P(u, v):
            # a saddle: one axis sags by exactly what the other lifts
            return (ox + u * gw / 2,
                    oy + v * gh / 2 + bend * (u * u - v * v) * gh * 0.40)

        for i in range(6):
            pts = [P(j / 10.0 * 2 - 1, i / 5.0 * 2 - 1) for j in range(11)]
            out.append('<path d="M %s" fill="none" stroke="%s" stroke-width="0.9"/>'
                       % (" L ".join("%s %s" % (f(p[0]), f(p[1])) for p in pts), col))
        for j in range(7):
            pts = [P(j / 6.0 * 2 - 1, i / 10.0 * 2 - 1) for i in range(11)]
            out.append('<path d="M %s" fill="none" stroke="%s" stroke-width="0.9"/>'
                       % (" L ".join("%s %s" % (f(p[0]), f(p[1])) for p in pts), col))
        if s:
            bx = x + s * cw
            out.append('<polygon points="%s,%s %s,%s %s,%s" fill="%s"/>'
                       % (f(bx - 6), f(oy), f(bx - 14), f(oy - 5), f(bx - 14), f(oy + 5), T_FNT))
    return "\n".join(out)

# ------------------------------------------------------------- the theorem
def fig_theorem(x, y, w, h, lab_a="erasure &#8660; orphan", lab_b="orphan, no erasure"):
    """Two panels: the equivalence, and the equivalence breaking."""
    out = []
    pw = (w - 18) / 2
    for panel in (0, 1):
        px = x + panel * (pw + 18)
        out.append('<rect x="%s" y="%s" width="%s" height="%s" fill="%s" stroke="%s" stroke-width="1"/>'
                   % (f(px), f(y), f(pw), f(h), DEEP, MID if panel == 0 else RAISED))
        mid = px + pw / 2
        col = T_LO if panel == 0 else LIVE
        # two configurations collapsing onto one future -- only on the left
        for k, dy in ((0, 18), (1, 44)):
            out.append('<rect x="%s" y="%s" width="15" height="11" fill="none" stroke="%s" stroke-width="1"/>'
                       % (f(px + 16), f(y + dy), T_DIM if panel == 0 else T_FNT))
        if panel == 0:
            out.append('<path d="M %s %s L %s %s M %s %s L %s %s" fill="none" stroke="%s" stroke-width="1"/>'
                       % (f(px + 33), f(y + 24), f(px + 56), f(y + 36),
                          f(px + 33), f(y + 50), f(px + 56), f(y + 38), T_LO))
            out.append('<rect x="%s" y="%s" width="15" height="11" fill="%s"/>' % (f(px + 58), f(y + 32), T_LO))
        else:
            out.append('<path d="M %s %s L %s %s" fill="none" stroke="%s" stroke-width="1.4" stroke-dasharray="3 3"/>'
                       % (f(px + 33), f(y + 24), f(px + 56), f(y + 36), DENY))
            out.append('<path d="M %s %s L %s %s M %s %s L %s %s" stroke="%s" stroke-width="1.6"/>'
                       % (f(px + 60), f(y + 46), f(px + 70), f(y + 56),
                          f(px + 70), f(y + 46), f(px + 60), f(y + 56), DENY))
        # the orphan: a configuration with no arrow coming into it
        out.append('<rect x="%s" y="%s" width="17" height="13" fill="none" stroke="%s" stroke-width="1.4"/>'
                   % (f(mid + 14), f(y + 30), col))
        out.append('<text x="%s" y="%s" font-family="ui-monospace, SFMono-Regular, Menlo, Consolas, monospace" '
                   'font-size="9" fill="%s" text-anchor="middle">%s</text>'
                   % (f(px + pw / 2), f(y + h - 8), col,
                      lab_a if panel == 0 else lab_b))
    return "\n".join(out)
