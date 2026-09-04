package graphics;

/**
	The project palette.

	**The working direction is monotone cyberpunk** (asked directly,
	2026-09-04): "futuristic, with monotone, buildings in a cyberpunk
	ambiance for now. Empty, deserted, without identity so that the very few
	things we want to pop out do pop out more."

	That last clause is the whole system, and it is a **contrast budget**
	rather than a colour scheme:

	- **The base ramp is value-only.** `VOID` through `SURFACE_EDGE` below
	  are one desaturated blue-grey walked from near-black to a dim
	  highlight. Nothing in the base tier is allowed to be saturated, so
	  ordinary terrain, walls and buildings can never compete for the eye.
	  Silhouette and value do all the work — which is also what makes a
	  deserted city read as deserted rather than as unfinished.
	- **The signal tier is the only saturated thing on screen**, and it is
	  deliberately small: four entries, each with one meaning. Spending
	  saturation on anything that is not load-bearing is what breaks this,
	  so a new colour wants a reason, not a taste.

	**This supersedes `docs/game/art-and-audio.md`'s hue-encodes-curvature
	rule for now, and that is an open question rather than a settled
	reversal** — see that file's own status note. The curvature gradient was
	a proposal that has never been validated in the engine; the Tron
	register the Fold already had is what is actually being tried. Neither is
	committed to.

	Entries below the palette are per-object placeholders, several of them
	predating any direction at all (the grass and trees especially, which are
	organic and hue-arbitrary against everything above). They are kept
	working, not endorsed.
**/
class Colours {
	// ------------------------------------------------------------------
	// Base ramp — value-only, never saturated. ~95% of every frame.
	// ------------------------------------------------------------------

	/** Backdrop behind everything; the clear colour a biome falls back to. Near-black with just enough blue to not read as a dead pixel. **/
	public static inline final VOID:Int = 0xFF05070A;

	/** Deepest built surface — recessed panel faces, the inside of things. **/
	public static inline final SURFACE_DEEP:Int = 0xFF0A0E16;

	/** The default floor/ground value across biomes. **/
	public static inline final SURFACE_BASE:Int = 0xFF111A22;

	/** Ordinary wall and building mass — the value most of a city block is. **/
	public static inline final SURFACE_MID:Int = 0xFF1B2530;

	/** Raised or nearer massing, so blocks separate from each other by value alone. **/
	public static inline final SURFACE_RAISED:Int = 0xFF2A3846;

	/** Top edges, rims, and the lit lip of a ledge — the brightest a non-signal surface is allowed to be. **/
	public static inline final SURFACE_EDGE:Int = 0xFF3D4E5E;

	// ------------------------------------------------------------------
	// Signal tier — saturated, rare, one meaning each. Spend sparingly.
	// ------------------------------------------------------------------

	/** Powered / alive / running. The ambient cyberpunk tell, and the only signal allowed to appear at scale (a live cell field is still mostly dark). **/
	public static inline final SIGNAL_LIVE:Int = 0xFF38E8FF;

	/** The actionable thing — what the player can do something with right now. **/
	public static inline final SIGNAL_ACT:Int = 0xFF3BC47A;

	/** Refused / locked / dying. Anything that answers "no". **/
	public static inline final SIGNAL_DENY:Int = 0xFFE5484D;

	/** Notable and followable — a thing worth crossing a space for. The rarest of the four; if several are visible at once it has stopped meaning anything. **/
	public static inline final SIGNAL_MARK:Int = 0xFFFFB627;

	/** `GrassMesh`'s blade gradient — darker at the root, lighter/yellower at the tip. **/
	public static inline final GRASS_BASE:Int = 0xFF2E5C2E;

	public static inline final GRASS_TIP:Int = 0xFF7AA648;

	/** `entities.painting.PaintingModel.buildFrame`'s own moulding — a plain wood-brown placeholder, no real art for it yet either. **/
	public static inline final PAINTING_FRAME:Int = 0xFF7A5C3E;

	/** `entities.painting.PaintingModel.buildFrame`'s own thin edge bands — flat unlit shading has no real lighting to read the frame's relief from, so a traced black keyline along its inner/outer border stands in for one. **/
	public static inline final PAINTING_FRAME_OUTLINE:Int = 0xFF000000;

	/** `entities.hourglass.Hourglass`'s own top/bottom caps — a dark wood placeholder, darker than `PAINTING_FRAME` so it reads as a sturdy base rather than a picture frame. **/
	public static inline final HOURGLASS_WOOD:Int = 0xFF3B2417;

	/** `entities.hourglass.Hourglass`'s own reinforcing spiral — a brushed-pewter placeholder. **/
	public static inline final HOURGLASS_METAL:Int = 0xFFAEB4BD;

	/** `entities.hourglass.Hourglass.buildGlass`'s own bulbs — a faint icy tint, alpha-blended (see `Hourglass.GLASS_ALPHA`) rather than opaque, so the sand/spiral read through it. **/
	public static inline final HOURGLASS_GLASS:Int = 0xFFDDF0FA;

	/** `entities.hourglass.Hourglass.buildGlassHighlights`'s own rim/neck bands — brighter than `HOURGLASS_GLASS`, standing in for a specular glint (see that method's own doc for why brightness rather than real reflection). **/
	public static inline final HOURGLASS_GLASS_HIGHLIGHT:Int = 0xFFF4FBFF;

	/**
		`entities.hourglass.Hourglass`'s own sand (and, sharing the same
		fill, its two signs) — a clear light blue, not an ordinary warm sand
		color. `0xFF7FD4EC`, not the original near-white `0xFFE6F2FB`:
		reported directly as wanting it "light blue by default," the glow
		overlays (`HOURGLASS_SAND_GLOW`, still plain white) doing the actual
		emitting-light work untouched.
	**/
	public static inline final HOURGLASS_SAND:Int = 0xFF7FD4EC;

	/** `entities.hourglass.Hourglass`'s own additive glow overlay (`addGlowOverlay`), for the sand and the `+`/`-` signs both — plain white, same "no colour, emit white light" choice `graphics.shaders.TileRingGlow` already made for the tower floor's own glow. **/
	public static inline final HOURGLASS_SAND_GLOW:Int = 0xFFFFFFFF;

	/** `entities.hourglass.Hourglass`'s own sand once `HourglassModel.unlocked` — the hidden mechanic's own visible payoff, "changing the colour of the sand to... say, golden," per the ask. **/
	public static inline final HOURGLASS_SAND_GOLD:Int = 0xFFE8B84B;

	/** The gold sand's own additive glow overlay — a warmer tint than the plain `HOURGLASS_SAND_GLOW`, so the glow itself reads as gold too rather than washing the gold fill back toward white. **/
	public static inline final HOURGLASS_SAND_GOLD_GLOW:Int = 0xFFFFE9A8;

	/** `biomes.tower.TowerMesh`'s own floor glow once `entities.hourglass.HourglassModel.unlocked` — the hourglass secret's own payoff bleeding into the tower, same gold as `HOURGLASS_SAND_GOLD_GLOW` rather than a second, unrelated gold. **/
	public static inline final TOWER_SECRET_GLOW:Int = HOURGLASS_SAND_GOLD_GLOW;

	/** `biomes.mobius.MobiusMesh`'s own alternating across-width color bands — a placeholder pair chosen purely so the ribbon's own twist(s) read clearly as you walk it (no real art for this biome yet either). **/
	public static inline final MOBIUS_BAND_A:Int = 0xFFB0473C;

	/** See `MOBIUS_BAND_A`. **/
	public static inline final MOBIUS_BAND_B:Int = 0xFF3C6EB0;

	/** `biomes.conway.ConwayMesh` floor tiles — dim "dead" cells. **/
	public static inline final CONWAY_TILE_DEAD:Int = SURFACE_BASE;

	/**
		`tools.geodesic.GeodesicMesh`'s own pentagon floor tiles — the 12
		icosahedral pinch-points, a brighter lift off `CONWAY_TILE_DEAD`
		(same hue family, not a new one) so they read as distinct without
		competing with `CONWAY_TILE_LIVE`. This constant is the single
		switch for that: set it equal to `CONWAY_TILE_DEAD` to have
		pentagons blend back into the hexagons instead, no code change
		needed beyond this value — see `GeodesicMesh.build`'s own doc for
		why the split is architected as two separate meshes rather than
		per-vertex color.

		**Toned down (2026-08-11)** — asked directly for pentagons to "pop
		out less, but still noticeable." Was `0xFF35566E`, roughly `3×`
		`CONWAY_TILE_DEAD`'s own per-channel brightness; this value is
		roughly `1.9×` instead, closer to the halfway point between dead
		and the original lift. Untuned past "still noticeable" — a
		reasonable middle guess, not a measured one; the doc above still
		holds exactly, only the value moved.
	**/
	public static inline final CONWAY_TILE_PENTAGON:Int = 0xFF1F3240;

	/**
		`biomes.conway.ConwayMesh` raised live-cell blocks and the hub
		waypoint — the single hue every lifecycle stage shares
		(`ConwayMesh.scaledColor` dims it per stage rather than switching
		hue; "too much colours... let's keep unicolor-cells, but make them
		brighter when they birth, dimmer when they age, dimmer again when
		they die").
	**/
	public static inline final CONWAY_TILE_LIVE:Int = SIGNAL_ACT;

	/**
		`tools.geodesic.GeodesicMesh`'s own dying-cell blocks — red instead
		of a dimmer `CONWAY_TILE_LIVE` green (2026-08-11, asked directly:
		dying cells should read red, not green). A deliberate one-off
		exception to `CONWAY_TILE_LIVE`'s own "unicolor cells, dim don't
		recolor" rule (see that constant's own doc, quoting the original
		call for `biomes.conway.ConwayMesh`) — that call was scoped to the
		older square-grid biome; this only recolors `GeodesicMesh`'s own
		`Dying` bucket, not a reversal of the earlier one.
	**/
	public static inline final CONWAY_TILE_DYING:Int = SIGNAL_DENY;

	/**
		`tools.geodesic.GeodesicMesh`'s own tracked-glider live blocks — a
		warm amber standing apart from `CONWAY_TILE_LIVE`'s green so a
		spawned glider (`GeodesicGliderTracker`) reads as a distinct,
		followable thing against the ambient soup, not just a brighter
		blob of the same color.
	**/
	public static inline final CONWAY_TILE_GLIDER:Int = SIGNAL_MARK;

	/**
		`tools.geodesic.GeodesicGliderTracker`'s own per-site palette
		(2026-08-07) — every generator site (the traveling spaceship or one
		of the smaller shuttle patterns) gets its own hue instead of
		everything sharing `CONWAY_TILE_GLIDER`, so which pentagon a moving
		structure came from — and whether two of them are the same
		structure meeting, not one growing — reads at a glance. Explicitly
		"for now": a debug/exploratory palette for watching interactions,
		not a settled art choice. `CONWAY_TILE_GLIDER` itself is `[0]`, kept
		as the palette's own first entry rather than a separate constant,
		so nothing else has to change if this gets folded back to one
		shared color later.
	**/
	public static final CONWAY_TILE_SITE_PALETTE:Array<Int> = [
		CONWAY_TILE_GLIDER,
		0xFFEF476F,
		0xFF9B5DE5,
		0xFF3A86FF,
		0xFFFB5607,
		0xFFFFD60A,
		0xFF06D6A0,
		0xFFE0E0E0,
		0xFFC77DFF
	];

	/** `biomes.conway.ConwayMesh` closed-edge walls' dark base panel — `graphics.shaders.ConwayWallGlow` paints the actual Tron lines on top. **/
	public static inline final CONWAY_WALL_PANEL:Int = SURFACE_DEEP;

	/** `biomes.conway.ConwayMesh` closed-edge walls' emissive rim/seam color, see `graphics.shaders.ConwayWallGlow`. Also the color of an *opened* reactive wall's own faded "ghost" — same panel, just at `ConwayMesh.GHOST_WALL_OPACITY`. **/
	public static inline final CONWAY_WALL_GLOW:Int = SIGNAL_LIVE;

	/** `biomes.twosided.MarkModel`'s own posts — a hot pink that exists in no other biome, so a mark can never be mistaken for scenery while the mechanic is being tested. **/
	public static inline final MARK_POST:Int = 0xFFFF3FA0;

	/** `biomes.twosided.TwoSidedBiome`'s own pole-crossing discs — placeholder signage for a placeholder mechanism, see that class's own doc. **/
	public static inline final CROSSING_MARKER:Int = 0xFFF5C84A;

	/** `biomes.debug.DebugHubBiome`'s own floor — a flat mid-grey, deliberately drab: the dev room shouldn't look like content (see that class's own doc). **/
	public static inline final DEBUG_FLOOR:Int = 0xFF3A3A3E;

	/** `biomes.debug.DebugHubBiome`'s own portal signs — see `graphics.LabelTexture`. **/
	public static inline final DEBUG_SIGN:Int = 0xFF1E2430;

	/** See `DEBUG_SIGN` — the label text drawn on it, bright enough to read across the dev room. **/
	public static inline final DEBUG_SIGN_TEXT:Int = 0xFFE8EEF5;

	/** `biomes.common.tree.TreeMesh`'s own trunks, at the root (`graphics.shaders.HeightGradient`'s own base color) — a plain bark-brown placeholder, no real art yet either. **/
	public static inline final TREE_TRUNK_BASE:Int = 0xFF3E2E20;

	/** `biomes.common.tree.TreeMesh`'s own trunks, at the top (`graphics.shaders.HeightGradient`'s own tip color) — lighter than `TREE_TRUNK_BASE`, so the trunk reads with some depth instead of one flat fill. **/
	public static inline final TREE_TRUNK_TIP:Int = 0xFF6B4E36;

	/** `biomes.common.tree.TreeMesh`'s own foliage, at the trunk-top collar (`graphics.shaders.HeightGradient`'s own base color) — a deep conifer green, distinct from `GRASS_BASE`/`GRASS_TIP` so a forest's canopy reads apart from the ground cover beneath it. **/
	public static inline final TREE_FOLIAGE_BASE:Int = 0xFF16351F;

	/** `biomes.common.tree.TreeMesh`'s own foliage, at the very tip (`graphics.shaders.HeightGradient`'s own tip color) — lighter/yellower than `TREE_FOLIAGE_BASE`, catching more light at the canopy's own top. **/
	public static inline final TREE_FOLIAGE_TIP:Int = 0xFF3D7A45;

	/**
		`biomes.weft.WeftMesh`'s own locked gate walls (2026-08-18) — the one
		wall of each `WeftModel` gate the player cannot open directly. Reuses
		`CONWAY_TILE_DYING`'s own red rather than a new hue, the same "needs
		attention" reading that color already carries in the Fold. Flat, not
		argued from curvature/hue-discipline the way the rest of this file
		is — asked directly to make gates "too obvious" as a first pass, to
		be revisited toward something subtler once the mechanic itself is
		proven out.
	**/
	public static inline final WEFT_GATE_LOCK:Int = CONWAY_TILE_DYING;

	/**
		`biomes.weft.WeftMesh`'s own gate keys (2026-08-18) — the antipodal
		wall that actually answers to a `WEFT_GATE_LOCK`, when it happens to
		be closed (it starts open — see `WeftModel.sealKeystoneGates`). Reuses
		`CONWAY_TILE_LIVE`'s own green; same "too obvious, on purpose, for
		now" caveat as `WEFT_GATE_LOCK`.
	**/
	public static inline final WEFT_GATE_KEY:Int = CONWAY_TILE_LIVE;
}
