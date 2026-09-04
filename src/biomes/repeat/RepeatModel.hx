package biomes.repeat;

/**
	The Repeat's layout: a city block generated deterministically, tiled
	across the plane, and the small divergences that make one tile worth
	comparing against the next.

	**This is deliberately not a quotient**, even though
	`geometry.DeckGroup` exists and would make it one.
	`docs/game/world.md` is explicit about
	the distinction and it is the whole design: a true torus has exactly
	*one* tile, rendered repeatedly, so there is nothing to compare and no
	mechanic. What this space needs is **many separate tiles that happen
	to be identical** — same seed, same rule, same future — so that a
	difference means something has actually intervened.

	So the group is used for the parts that are honestly about the
	lattice: where the tiles sit, and which of them to draw.
	`tileIndexAt` and the divergence live here, keyed on the tile's own
	integer coordinates, because those are what distinguish one tile from
	another — which under a real quotient they could not do.

	**Sameness is generated, not copied.** Every plot's building is a pure
	function of its position *within* a tile, with the tile's own
	coordinates deliberately absent from the hash. Two tiles are identical
	because nothing in their construction could make them differ, which is
	exactly the determinism argument the design rests the mechanic on.
**/
class RepeatModel {
	/** Plots along each edge of a tile. **/
	public static inline final PLOTS_PER_TILE:Int = 6;

	/** World units across one plot, street included. **/
	public static inline final PLOT_SIZE:Float = 40;

	/**
		How much of a plot the building fills; the remainder is street.

		Tuned down from `0.7` after looking at it. At that value the
		streets were twelve units wide between buildings up to a hundred
		and ten tall — a slot canyon, in which the player can see two walls
		and nothing else. That is fatal here specifically: the mechanic is
		spot-the-difference against a remembered **skyline**, and a city
		you cannot see across has no skyline to remember.
	**/
	public static inline final BUILDING_FOOTPRINT:Float = 0.55;

	/** One tile's own period — the distance the design's verb ("walk exactly one measured period") is measured in. About sixteen seconds at `game.GameLoop.WALK_SPEED`. **/
	public static inline final TILE_SIZE:Float = PLOTS_PER_TILE * PLOT_SIZE;

	/** Fraction of plots left as open ground rather than built on, so the city has squares and through-routes instead of a uniform grid of blocks. **/
	static inline final EMPTY_PLOT_RATE:Float = 0.36;

	/**
		Height range, low-rise on purpose — see `BUILDING_FOOTPRINT` for
		what the tall version cost. Manifold Garden's register, which this
		space borrows, is big legible geometry seen whole, not Manhattan
		seen from the pavement.
	**/
	static inline final MIN_BUILDING_HEIGHT:Float = 10;

	static inline final MAX_BUILDING_HEIGHT:Float = 52;

	/**
		Fraction of tiles carrying a divergence.

		High for a prototype. The design wants finding one to be an act of
		memory and comparison, which argues for rarity; but a rate low
		enough to be interesting is also low enough that a first playtest
		might walk four tiles and conclude the mechanic is not implemented.
		Tuned down once the mechanic is confirmed to read at all.
	**/
	static inline final DIVERGENCE_RATE:Float = 0.34;

	/**
		Which tile a world position falls in. Tiles are indexed by the
		lattice, so `(0, 0)` is the one containing the origin.
		@param x world x.
		@param z world z.
		@return the tile's own integer coordinates.
	**/
	public static function tileIndexAt(x:Float, z:Float):{i:Int, j:Int} {
		return {i: Math.floor(x / TILE_SIZE), j: Math.floor(z / TILE_SIZE)};
	}

	/** The world position of a tile's own south-west corner. **/
	public static function tileOrigin(i:Int, j:Int):{x:Float, z:Float} {
		return {x: i * TILE_SIZE, z: j * TILE_SIZE};
	}

	/**
		Whether a plot carries a building **in the reference layout** —
		that is, ignoring any divergence. A pure function of the plot's
		position within a tile, with no tile coordinate involved, which is
		what makes every tile identical by construction.
		@param plotX plot column within the tile, `0` to `PLOTS_PER_TILE - 1`.
		@param plotZ plot row within the tile.
		@return true if the reference layout builds here.
	**/
	public static function referenceHasBuilding(plotX:Int, plotZ:Int):Bool {
		return noise(plotX, plotZ, 1) >= EMPTY_PLOT_RATE;
	}

	/**
		How many stacked tiers a plot's building is built from — a plain box
		(`1`) or a stepped one (`2`/`3`), each tier inset from the one below.

		Silhouette variety, and it also buys the space's own mechanic
		something: a *missing setback* is a subtler difference than a
		missing block, which gives spot-the-difference a range of
		difficulties it did not have when every building was one box.

		Deterministic from the plot alone, with the tile's coordinates
		deliberately absent, for exactly the reason `referenceHasBuilding`
		is — every tile has to be identical by construction or the
		comparison mechanic has nothing to stand on.
		@param plotX plot column within the tile.
		@param plotZ plot row within the tile.
		@return how many tiers to stack.
	**/
	public static function tierCount(plotX:Int, plotZ:Int):Int {
		var roll = noise(plotX, plotZ, 5);
		if (buildingHeight(plotX, plotZ) < MIN_BUILDING_HEIGHT + (MAX_BUILDING_HEIGHT - MIN_BUILDING_HEIGHT) * 0.35) {
			return 1; // a low block has no room to step and reads as a plinth if it tries
		}
		return roll < 0.45 ? 1 : (roll < 0.85 ? 2 : 3);
	}

	/**
		Fraction of anomalies that are the Tetris building.

		The **easy** one, and deliberately so: a player who finds one obvious
		anomaly now knows there is a search to lead, which is what makes the
		other two findable at all. It teaches that anomalies exist; they
		teach what looking closely is worth.
	**/
	static inline final PLAYING_SHARE:Float = 0.18;

	/** Fraction of anomalies that glitch rather than lean. **/
	static inline final GLITCH_SHARE:Float = 0.28;

	/** Least a deformed building leans. See `anomalyLean`. **/
	public static inline final ANOMALY_MIN_LEAN:Float = 0.035;

	/** Most a deformed building leans — about five degrees, which is visibly wrong beside a true one and unremarkable alone. **/
	public static inline final ANOMALY_MAX_LEAN:Float = 0.09;

	/** How much each tier narrows relative to the one below it. **/
	public static inline final TIER_INSET:Float = 0.74;

	/** How tall the building on a plot stands. Same determinism as `referenceHasBuilding`. **/
	public static function buildingHeight(plotX:Int, plotZ:Int):Float {
		return MIN_BUILDING_HEIGHT + noise(plotX, plotZ, 2) * (MAX_BUILDING_HEIGHT - MIN_BUILDING_HEIGHT);
	}

	/**
		**The mark the predecessor left**, as plots of a tile's own grid.

		`world.md`'s mechanism for this space turns on one word: the
		divergences, *overlaid*, "compose into something specific — a mark,
		not the player's own, deliberate rather than incidental." So the mark
		is not a separate object placed somewhere to be found. It is latent
		in **which** plot each tile diverges at: overlay every tile's
		divergence onto one grid and the shape appears. Before this, that
		plot was hashed, so the overlay was noise and the design's payload
		could not exist however long the player looked.

		The shape is the **loaf**, a Conway still life, at the rotation and
		offset where all seven of its cells land on plots the reference
		layout actually builds on — a divergence that removed an
		already-empty plot would be no divergence at all. That constraint is
		most of why it is this glyph: `eater`, tried first, has no placement
		on this 6×6 grid where every cell is built.

		A still life is exactly the right thing for the mark to be. Random
		cells are noise; a still life is a configuration that *holds*, which
		is unmistakably a choice — and Thread 2 makes it more than a
		flourish, since a still life is one of the ones who stopped. The
		player has also been navigating by these shapes elsewhere
		(`entities.landmark.GlyphAlphabet`), so it reads as language rather
		than as a pattern.

		Duplicated here rather than loaded from the alphabet's own data file,
		because this class is engine-agnostic and pure — the whole reason it
		is testable without `hxd.Res` — and story content pinned to this
		biome's plot grid is not the same object as a wayfinding vocabulary.
		`RepeatMarkTest` asserts the two cannot drift apart.
	**/
	public static final MARK_PLOTS:Array<{plotX:Int, plotZ:Int}> = [
		{plotX: 1, plotZ: 2},
		{plotX: 0, plotZ: 3},
		{plotX: 2, plotZ: 3},
		{plotX: 0, plotZ: 4},
		{plotX: 3, plotZ: 4},
		{plotX: 1, plotZ: 5},
		{plotX: 2, plotZ: 5}
	];

	/**
		Which plot of a tile diverges from the reference, or null if this
		tile is one of the untouched ones.

		**The divergence leaves the building standing but wrong** — tilted
		off true, its top storey turned a few degrees out of line. It used
		to remove the building outright, and the change was asked for
		directly: a whole missing block from a repeated skyline is
		unmissable ("way too noticeable"), so the space was solved by
		glancing rather than by comparing, which is the one thing it exists
		to make you do.

		**This does cost something and the trade is deliberate.** The
		original rule was argued in `world.md` as "recognising the
		difference and reaching the new ground are the same act" — a gap is
		somewhere you can *walk* that you could not walk in the last tile,
		so noticing and reaching were one motion with no puzzle bolted on
		top. A wrong building is a difference you can only look at, so those
		two come apart and reaching it is now a separate (if small) act of
		walking over. Worth it: a difference subtle enough to require the
		comparison is the point of the space, and a mechanic that is never
		exercised because the answer is obvious from fifty metres away is
		worth less than a slightly less elegant one that is.
		@param i the tile's own x coordinate.
		@param j the tile's own z coordinate.
		@return the diverging plot, or null.
	**/
	public static function divergenceOf(i:Int, j:Int):Null<{plotX:Int, plotZ:Int}> {
		if (noise(i, j, 3) >= DIVERGENCE_RATE) {
			return null;
		}
		// One of the mark's own plots, not an arbitrary built one — this
		// is what makes the overlay across tiles compose into a shape
		// instead of into noise. See MARK_PLOTS.
		return MARK_PLOTS[Math.floor(noise(i, j, 4) * MARK_PLOTS.length)];
	}

	/**
		Whether a plot of a *particular* tile actually carries a building —
		the reference layout, minus this tile's own divergence. The one
		function collision and mesh building should both ask, so the thing
		the player can see and the thing they can walk through cannot
		disagree.
		@param i the tile's own x coordinate.
		@param j the tile's own z coordinate.
		@param plotX plot column within the tile.
		@param plotZ plot row within the tile.
		@return true if there is a building standing there.
	**/
	public static function hasBuilding(i:Int, j:Int, plotX:Int, plotZ:Int):Bool {
		// Every tile now builds the full reference layout: the divergence
		// deforms a building rather than deleting it, so nothing is missing
		// and collision is the same everywhere. See `divergenceOf`.
		return referenceHasBuilding(plotX, plotZ);
	}

	/**
		Whether this plot carries this tile's own deformed building.
		@param i the tile's own x coordinate.
		@param j the tile's own z coordinate.
		@param plotX plot column within the tile.
		@param plotZ plot row within the tile.
		@return true if the building standing here is the wrong one.
	**/
	public static function isAnomalous(i:Int, j:Int, plotX:Int, plotZ:Int):Bool {
		var divergence = divergenceOf(i, j);
		return divergence != null && divergence.plotX == plotX && divergence.plotZ == plotZ;
	}

	/**
		How far out of true a tile's anomalous building leans, in radians.

		Small on purpose, and the hardest number here to get right: large
		enough that a player *comparing* two tiles sees it, small enough
		that a player merely walking past does not. Deterministic per tile
		so the same tile is always wrong in the same way.
		@param i the tile's own x coordinate.
		@param j the tile's own z coordinate.
		@return the lean angle, in radians.
	**/
	public static function anomalyLean(i:Int, j:Int):Float {
		return ANOMALY_MIN_LEAN + noise(i, j, 6) * (ANOMALY_MAX_LEAN - ANOMALY_MIN_LEAN);
	}

	/** Which way the lean points, in radians around the vertical. **/
	public static function anomalyBearing(i:Int, j:Int):Float {
		return noise(i, j, 7) * Math.PI * 2;
	}

	/**
		Which kind of wrong this tile's anomaly is.

		Three kinds, appealing to different senses, which is the point of
		having more than one: a `Leaning` building is spotted by *comparing shapes*
		against the tile you just left, and a `Glitching` one only by
		*watching* — its facade runs a Life that cannot settle (see
		`FacadeLife.GLITCH_FACADE`), so a player who never stands still will
		walk straight past it. It stands perfectly upright on purpose;
		giving it a lean too would let the harder tell be solved by the
		easier one. `Playing` is the tutorial case — unmissable once seen,
		and its whole job is to establish that there is something to look
		for.
		@param i the tile's own x coordinate.
		@param j the tile's own z coordinate.
		@return the anomaly's kind.
	**/
	public static function anomalyKind(i:Int, j:Int):AnomalyKind {
		var roll = noise(i, j, 8);
		if (roll < PLAYING_SHARE) {
			return Playing;
		}
		return roll < PLAYING_SHARE + GLITCH_SHARE ? Glitching : Leaning;
	}

	/** The world position of a plot's own centre, in the given tile. **/
	public static function plotCentre(i:Int, j:Int, plotX:Int, plotZ:Int):{x:Float, z:Float} {
		var origin = tileOrigin(i, j);
		return {x: origin.x + (plotX + 0.5) * PLOT_SIZE, z: origin.z + (plotZ + 0.5) * PLOT_SIZE};
	}

	/** Half a building's own footprint, so collision and geometry agree on where its walls are. **/
	public static function buildingHalfExtent():Float {
		return PLOT_SIZE * BUILDING_FOOTPRINT / 2;
	}

	/**
		A deterministic value in `[0, 1)` from two integers and a salt.

		Hash-based rather than a seeded PRNG walked in order, because
		every caller here needs to ask about an *arbitrary* plot or tile
		without having generated its neighbours first — collision asks
		about wherever the player happens to be standing, and the mesh
		asks about whatever is currently in view. A sequential generator
		would force the whole plane to be materialised in a fixed order.
		@param a first coordinate.
		@param b second coordinate.
		@param salt distinguishes independent questions about the same coordinates.
		@return a stable pseudo-random value in `[0, 1)`.
	**/
	static function noise(a:Int, b:Int, salt:Int):Float {
		var h = a * 374761393 + b * 668265263 + salt * 1274126177;
		h = (h ^ (h >> 13)) * 1274126177;
		h = h ^ (h >> 16);
		return (h & 0x7FFFFFFF) / 2147483648.0;
	}
}

/** How a tile's anomalous building is wrong — see `RepeatModel.anomalyKind`. **/
enum AnomalyKind {
	/** Out of true: found by comparing its shape against a tile you remember. **/
	Leaning;

	/** Running a Life that cannot settle: found only by watching it. **/
	Glitching;

	/** Not running Life at all — see `FacadeLife.TETRIS_FACADE`. The one you are meant to find first. **/
	Playing;
}
