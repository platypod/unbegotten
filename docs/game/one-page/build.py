# -*- coding: utf-8 -*-
"""Emit the Unbegotten one-page design, v2, as plain SVG.

Presentation attributes only: no <style>, no script, no webfont, no external
reference -- so GitHub renders it in the file view, outline-sync can carry it,
and it prints as vector at any size.
"""
import sys, html
sys.path.insert(0, __file__.rsplit("/", 1)[0])
import figures as F
from figures import (VOID, DEEP, BASE, MID, RAISED, EDGE, LIVE, ACT, DENY, MARK,
                     T_HI, T_MID, T_LO, T_DIM, T_FNT, f)
import content

MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
SERIF = "Georgia, 'Times New Roman', Times, serif"

W, H, M = 2688, 2196, 56
CONTENT = W - 2 * M                                    # 2576
NCARD = 8
GUT = 18
CLIFF_GAP = 62            # a real gutter where the theorem fails, not a 18px seam
CW = (CONTENT - (NCARD - 1) * GUT - CLIFF_GAP) / NCARD

out = []


def esc(s):
    return html.escape(str(s), quote=False)


def txt(x, y, s, size=11, fill=T_LO, font=MONO, weight=None, anchor=None,
        style=None, ls=None):
    if s == "" or s is None:
        return
    a = ['x="%s"' % f(x), 'y="%s"' % f(y), 'font-family="%s"' % font,
         'font-size="%s"' % f(size), 'fill="%s"' % fill]
    if weight:
        a.append('font-weight="%s"' % weight)
    if anchor:
        a.append('text-anchor="%s"' % anchor)
    if style:
        a.append('font-style="%s"' % style)
    if ls is not None:
        a.append('letter-spacing="%s"' % f(ls))
    out.append("<text %s>%s</text>" % (" ".join(a), esc(s)))


def rect(x, y, w, h, fill="none", stroke=None, sw=1, dash=None):
    a = ['x="%s"' % f(x), 'y="%s"' % f(y), 'width="%s"' % f(w),
         'height="%s"' % f(h), 'fill="%s"' % fill]
    if stroke:
        a += ['stroke="%s"' % stroke, 'stroke-width="%s"' % f(sw)]
    if dash:
        a.append('stroke-dasharray="%s"' % dash)
    out.append("<rect %s/>" % " ".join(a))


def line(x1, y1, x2, y2, stroke=MID, sw=1, dash=None):
    a = ['x1="%s"' % f(x1), 'y1="%s"' % f(y1), 'x2="%s"' % f(x2),
         'y2="%s"' % f(y2), 'stroke="%s"' % stroke, 'stroke-width="%s"' % f(sw)]
    if dash:
        a.append('stroke-dasharray="%s"' % dash)
    out.append("<line %s/>" % " ".join(a))


def band_head(x, y, s, w=None, colour=T_DIM):
    """A section rule with its label sitting on it."""
    txt(x, y, s, 12, colour, MONO, weight="bold", ls=2.2)
    if w:
        line(x, y + 9, x + w, y + 9, MID, 1)


def status_colour(st):
    return {"built": LIVE, "partial": T_LO, "none": DENY}[st]


def status_chip(x, y, label, st, L):
    col = status_colour(st)
    word = {"built": L["st_built"], "partial": L["st_partial"], "none": L["st_none"]}[st]
    rect(x, y - 7, 8, 8, col if st != "partial" else "none",
         None if st != "partial" else col, 1.2)
    txt(x + 13, y, "%s %s" % (label, word), 9.5, col if st != "partial" else T_LO)


# =====================================================================
def render(L):
    del out[:]
    out.append('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %d %d" '
               'width="%d" height="%d" role="img" aria-label="%s">'
               % (W, H, W, H, esc(L["map_head"])))
    out.append("<title>Unbegotten — %s</title>" % esc(L["stamp_kind"]))
    rect(0, 0, W, H, VOID)

    # ---------------------------------------------------------- header
    txt(M, 112, "UNBEGOTTEN", 62, T_HI, MONO, weight="bold", ls=-1.5)
    if L["gloss"]:
        txt(M + 432, 112, L["gloss"], 26, T_DIM, SERIF, style="italic")
    txt(M, 144, L["tagline"], 20, T_MID, SERIF, style="italic")
    txt(M, 166, L["subtagline"], 12.5, T_LO, MONO)
    for i, s in enumerate([L["stamp_kind"], L["rev"], L["tech"], L["build"]]):
        txt(W - M, 78 + i * 21, s, 12 if i == 1 else 11,
            T_LO if i == 1 else T_DIM, MONO,
            weight="bold" if i == 1 else None, anchor="end", ls=1.4 if i == 0 else None)
    line(M, 194, W - M, 194, RAISED, 1)

    # ---------------------------------------------------- band A: thesis
    ax, aw = M, 1040
    bx, bw = M + 1080, 690
    cx, cw = M + 1810, 766

    y = 234
    for i, s in enumerate(L["thesis_head"]):
        txt(ax, y, s, 26, T_HI, SERIF,
            style="italic" if i == len(L["thesis_head"]) - 1 else None)
        y += 34
    y += 10
    for s in L["thesis_body"]:
        txt(ax, y, s, 13, T_LO, MONO)
        y += 20
    y += 12
    rect(ax, y - 14, aw, 68, DEEP, MID, 1)
    for i, s in enumerate(L["thesis_caveat"]):
        txt(ax + 12, y + 4 + i * 17, s, 10.5, T_DIM, MONO)

    # ------------------------------------------------- band A: theorem
    band_head(bx, 224, L["theorem_head"], bw, T_LO)
    out.append(F.fig_theorem(bx, 240, bw, 68, L["fig_erasure"], L["fig_orphan"]))
    y = 326
    for s, tone in L["theorem"]:
        if s:
            txt(bx, y, s, 11, LIVE if tone == 3 else [T_LO, T_MID, T_DIM][tone],
                MONO, weight="bold" if tone in (1, 3) else None)
            y += 14
        else:
            y += 6
    y += 8
    rect(bx, y - 13, bw, 62, DEEP, LIVE, 1)
    for i, s in enumerate(L["theorem_punch"]):
        txt(bx + 12, y + 3 + i * 16, s, 11, T_HI, MONO, weight="bold")
    txt(bx + 12, y + 41, L["theorem_tail"], 10, T_LO, MONO)

    # ----------------------------------------------- band A: constants
    band_head(cx, 224, L["constants_head"], cw, T_LO)
    y = 254
    for head, body in L["constants"]:
        txt(cx, y, "·", 12, T_FNT)
        txt(cx + 16, y, head, 12.5, T_MID, MONO, weight="bold")
        for j, s in enumerate(body):
            txt(cx + 16, y + 17 + j * 16, s, 11, T_LO, MONO)
        y += 34 + 16 * len(body)

    # -------------------------------------------------- band B: the map
    band_head(M, 500, L["map_head"], CONTENT, T_HI)

    CLIFF = M + (CW + GUT) * 5 - GUT / 2 + CLIFF_GAP / 2
    GAP = CLIFF_GAP / 2 + 6
    CARD_TOP, CARD_BOT = 664, 1124
    AXIS = 636

    # the two regimes, bracketed above the axis
    for x0, x1, col, lab in ((M, CLIFF - GAP, T_MID, L["amenable_label"]),
                             (CLIFF + GAP, W - M, LIVE, L["nonamenable_label"])):
        line(x0, 548, x1, 548, EDGE if col is T_MID else LIVE, 1.4)
        line(x0, 542, x0, 554, EDGE if col is T_MID else LIVE, 1.4)
        line(x1, 542, x1, 554, EDGE if col is T_MID else LIVE, 1.4)
        txt((x0 + x1) / 2, 536, lab, 12.5, col, MONO, weight="bold",
            anchor="middle", ls=1.2)

    for i, (k, a, b) in enumerate(L["kappa"]):
        x0 = (M, M + (CW + GUT) * 2, CLIFF + GAP + 10)[i]
        txt(x0, 598, k, 20, T_HI if i == 2 else T_MID, MONO, weight="bold")
        txt(x0 + 76, 594, a, 11.5, T_LO, MONO)
        txt(x0 + 76, 609, b, 11.5, T_DIM, MONO)

    line(M, AXIS, CLIFF - GAP, AXIS, EDGE, 2.4)
    line(CLIFF + GAP, AXIS, W - M, AXIS, LIVE, 2.4)

    # the cliff: the whole point of the map, so it gets the whole height
    rect(CLIFF - GAP, 560, GAP * 2, CARD_BOT - 560, VOID)
    line(CLIFF, 560, CLIFF, CARD_BOT, LIVE, 2.4)
    lab = " · ".join([" ".join(L["cliff"]), L["cliff_sub"]])
    ly = (CARD_TOP + CARD_BOT) / 2
    out.append('<text x="%s" y="%s" transform="rotate(-90 %s %s)" font-family="%s" '
               'font-size="17" fill="%s" font-weight="bold" text-anchor="middle" '
               'letter-spacing="2.4">%s</text>'
               % (f(CLIFF), f(ly), f(CLIFF), f(ly), MONO, LIVE, esc(lab)))
    line(CLIFF - 92, AXIS, CLIFF + 92, AXIS, LIVE, 2.4)
    out.append('<polygon points="%s,%s %s,%s %s,%s" fill="%s"/>'
               % (f(CLIFF + 106), f(AXIS), f(CLIFF + 90), f(AXIS - 7),
                  f(CLIFF + 90), f(AXIS + 7), LIVE))

    figmap = dict(fold=F.fig_fold, weft=F.fig_weft, repeat=F.fig_repeat,
                  turn=F.fig_turn, defect=F.fig_defect, sprawl=F.fig_sprawl,
                  knot=F.fig_knot, garden=F.fig_garden)

    for i, sp in enumerate(L["spaces"]):
        x = M + i * (CW + GUT) + (CLIFF_GAP if i >= 5 else 0)
        accent = DENY if sp["sp"] == "none" else (LIVE if sp["fig"] == "sprawl" else EDGE)
        line(x + CW / 2, AXIS, x + CW / 2, CARD_TOP, RAISED, 1)
        rect(x, CARD_TOP, CW, CARD_BOT - CARD_TOP,
             (BASE, "#0D141C", DEEP)[sp["k"]], MID, 1)
        rect(x, CARD_TOP, CW, 3, accent)
        txt(x + 12, CARD_TOP + 28, sp["title"], 16, T_HI, MONO, weight="bold")
        txt(x + CW - 12, CARD_TOP + 27, sp["verb"], 10, T_DIM, MONO, anchor="end", ls=1.4)
        txt(x + 12, CARD_TOP + 47, sp["geom"], 10, T_LO, MONO)
        fn = figmap[sp["fig"]]
        out.append(fn(x + 6, CARD_TOP + 56, CW - 12, 172, L["fig_notbuilt"])
                   if sp["fig"] == "garden" else fn(x + 6, CARD_TOP + 56, CW - 12, 172))

        yy = CARD_TOP + 254
        for s in sp["teaches"]:
            txt(x + 12, yy, s, 12.5, T_MID, SERIF)
            yy += 18
        yy += 10
        line(x + 12, yy - 11, x + 12, yy + 15 * len(sp["law"]) - 11, RAISED, 2)
        for s in sp["law"]:
            txt(x + 22, yy, s, 9.8, T_LO, MONO)
            yy += 15
        yy += 11
        for s in sp["mech"]:
            txt(x + 12, yy, s, 9.5, T_DIM, MONO)
            yy += 14

        status_chip(x + 12, CARD_BOT - 13, L["lbl_space"], sp["sp"], L)
        status_chip(x + CW / 2 + 8, CARD_BOT - 13, L["lbl_mech"], sp["me"], L)

    # ------------------------------------------------ off the line
    band_head(M, 1166, L["offline_head"], CONTENT, T_DIM)
    ow = (CONTENT - 40) / 2
    for i, sp in enumerate(L["offline"]):
        x, top = M + i * (ow + 40), 1186
        rect(x, top, ow, 150, (BASE, "#0D141C")[i], MID, 1)
        rect(x, top, ow, 2, EDGE)
        out.append((F.fig_stilllife if sp["fig"] == "stilllife" else F.fig_ribbon)(
            x + 8, top + 10, 200, 128))
        tx = x + 224
        txt(tx, top + 26, sp["title"], 16, T_HI, MONO, weight="bold")
        txt(tx + 200, top + 25, sp["geom"], 10.5, T_LO, MONO)
        txt(x + ow - 12, top + 25, sp["verb"], 10, T_DIM, MONO, anchor="end", ls=1.4)
        for j, (s, tone) in enumerate(sp["lines"]):
            txt(tx, top + 50 + j * 17, s, 10.5, T_MID if tone else T_LO, MONO,
                weight="bold" if tone and j == 2 else None)
        status_chip(tx, top + 142, L["lbl_space"], sp["sp"], L)
        status_chip(tx + 140, top + 142, L["lbl_mech"], sp["me"], L)

    # ============================================== the pressure band
    PY_ = 1362
    p1w, p2w, p3w = 1080, 760, 700
    p2x, p3x = M + p1w + 18, M + p1w + p2w + 36
    hbox = 116
    rect(M, PY_, p1w, hbox, DEEP, DENY, 1)
    rect(M, PY_, 3, hbox, DENY)
    txt(M + 14, PY_ + 22, L["antagonist_head"], 13, DENY, MONO, weight="bold", ls=1.6)
    for i, s in enumerate(L["antagonist"]):
        txt(M + 14, PY_ + 44 + i * 15, s, 10.5, T_MID, MONO)
    rect(p2x, PY_, p2w, hbox, DEEP, MID, 1)
    txt(p2x + 14, PY_ + 22, L["scales_head"], 12, T_MID, MONO, weight="bold", ls=1.6)
    for i, s in enumerate(L["scales"]):
        txt(p2x + 14, PY_ + 46 + i * 16, s, 10.5, T_LO, MONO)
    rect(p3x, PY_, p3w, hbox, DEEP, MID, 1)
    txt(p3x + 14, PY_ + 22, L["failure_head"], 12, T_MID, MONO, weight="bold", ls=1.6)
    for i, s in enumerate(L["failure"]):
        txt(p3x + 14, PY_ + 46 + i * 15, s, 10.5, T_LO, MONO)

    # ============================================== lower three columns
    TOP = 1526
    c1x, c1w = M, 1080
    c2x, c2w = M + 1120, 700
    c3x, c3w = M + 1860, 716

    band_head(c1x, TOP, L["do_head"], c1w, T_HI)
    txt(c1x, TOP + 28, L["do_sub"], 11, T_LO, MONO)
    y = TOP + 54
    for v, what, st, note in L["verbs"]:
        col = ACT if st in ("NEW", "NOUVEAU") else (
            LIVE if st in ("BUILT", "FAIT") else T_DIM)
        txt(c1x, y, v, 12, ACT, MONO, weight="bold")
        txt(c1x + 100, y, what, 11, T_MID, MONO)
        txt(c1x + 566, y, st, 9.5, col, MONO, weight="bold", ls=1.2)
        txt(c1x + 566, y + 12, note, 9.5, T_DIM, MONO)
        y += 29

    band_head(c2x, TOP, L["gate_head"], c2w, T_HI)
    txt(c2x, TOP + 28, L["gate_sub"], 11, T_LO, MONO)
    y = TOP + 54
    txt(c2x, y, L["read_head"], 11, ACT, MONO, weight="bold", ls=1.3)
    for i, s in enumerate(L["read_body"]):
        txt(c2x, y + 20 + i * 15, s, 10.5, T_MID, MONO)
    y += 20 + 15 * len(L["read_body"]) + 18
    txt(c2x, y, L["web_head"], 10.5, T_DIM, MONO, weight="bold", ls=1.3)
    y += 22
    for chain in L["web"]:
        line(c2x, y - 10, c2x, y + 14 * len(chain) - 12, RAISED, 2)
        for i, s in enumerate(chain):
            txt(c2x + 10, y + i * 14, s, 10, T_LO, MONO)
        y += 14 * len(chain) + 12

    band_head(c3x, TOP, L["threads_head"], c3w, T_HI)
    y = TOP + 30
    for n, title, bodyl in L["threads"]:
        txt(c3x, y, n, 11, MARK, MONO, weight="bold")
        txt(c3x + 16, y, title, 11.5, T_MID, MONO, weight="bold")
        for i, s in enumerate(bodyl):
            txt(c3x + 16, y + 15 + i * 13, s, 10, T_LO, MONO)
        y += 20 + 13 * len(bodyl)
    y += 10
    txt(c3x, y, L["perc_head"], 11, ACT, MONO, weight="bold", ls=1.3)
    txt(c3x, y + 17, L["perc_sub"], 10, T_DIM, MONO)
    y += 38
    for name, what in L["perceptions"]:
        txt(c3x, y, name, 10.5, T_MID, MONO, weight="bold")
        txt(c3x + 140, y, what, 10, T_LO, MONO)
        y += 15
    txt(c3x, y + 16, L["perc_punch"], 15, T_HI, SERIF, style="italic")

    # ================================================= the endgame, full width
    EY = 1900
    band_head(M, EY, L["end_head"], CONTENT, MARK)
    txt(M, EY + 26, L["end_sub"], 10.5, T_LO, MONO)
    ew = (CONTENT - 2 * 36) / 3
    for i, (name, where, act, gift, cost) in enumerate(L["endings"]):
        x, top = M + i * (ew + 36), EY + 40
        rect(x, top, ew, 106, DEEP, MID, 1)
        rect(x, top, ew, 2, MARK)
        txt(x + 14, top + 22, name, 13.5, MARK, MONO, weight="bold", ls=1.2)
        txt(x + ew - 12, top + 21, where, 9.5, T_DIM, MONO, anchor="end")
        for j, s in enumerate(act):
            txt(x + 14, top + 44 + j * 14, s, 10, T_MID, MONO)
        for j, s in enumerate(gift):
            txt(x + 14, top + 44 + 14 * len(act) + 6 + j * 14, s, 10, ACT, MONO)
        for j, s in enumerate(cost):
            txt(x + 400, top + 44 + j * 13, s, 9.5, T_DIM, MONO)

    # ------------------------------------------------------- honest scope
    SY = 2064
    rect(M, SY, CONTENT, 86, DEEP, RAISED, 1, dash="4 4")
    txt(M + 16, SY + 26, L["scope_head"], 12, T_MID, MONO, weight="bold", ls=1.8)
    for i, (tone, s) in enumerate(L["scope"]):
        txt(M + 190, SY + 19 + i * 12, s, 10, DENY if tone else T_LO, MONO,
            weight="bold" if tone else None)

    # ------------------------------------------------------------ footer
    line(M, 2166, W - M, 2166, MID, 1)
    txt(M, 2180, L["method"], 9.5, T_DIM, MONO)
    txt(W - M, 2180, L["sources"], 9.5, T_DIM, MONO, anchor="end")

    out.append("</svg>")
    return "\n".join(out)


if __name__ == "__main__":
    for L, name in ((content.EN, "one-page.en.svg"), (content.FR, "one-page.fr.svg")):
        svg = render(L)
        open(sys.argv[1] + "/" + name, "w", encoding="utf-8").write(svg + "\n")
        print(name, len(svg), "bytes")
