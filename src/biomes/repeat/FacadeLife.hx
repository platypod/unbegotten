package biomes.repeat;

/**
	Conway's Life, running on the Repeat's building facades.

	**The city is not decorated with a metaphor; it is the thing itself.**
	The material language already says everything here is cells and that
	alive is emissive, so a lit window already *looks* like a live cell —
	it just was not one. `graphics.shaders.CityFacade` lit panes from a
	fixed hash, decided once and frozen, and the resemblance was entirely
	in the eye. This makes it real, which also turns Thread 2's "the
	terrain is made of the ones who stopped" from a line into something the
	player can watch happen: towers settle into still lifes as their facades
	run down, next to towers still churning.

	**Why an unbounded city costs 37 grids.** The naive objection is that
	simulating Life on every building of an infinite city is impossible.
	But this space's tile identity means there are only ever
	`PLOTS_PER_TILE²` distinct facades — every tile *is* the same tile — so
	36 small grids covers the whole plane, plus one more for the glitch (see
	`GLITCH_FACADE`). Every visible building showing the same generation of
	the same simulation is not a compromise either; it is precisely the
	claim the space makes: same seed, same rule, same future, identical
	unless something has intervened.

	**Seeded from the plot alone**, never from a tile's coordinates — the
	same discipline `RepeatModel.referenceHasBuilding` follows, and for the
	same reason. A seed that knew which tile it was in would make every tile
	visibly unique and destroy the comparison mechanic outright.

	Engine-agnostic and pure: a grid of booleans stepped by a rule, with no
	texture, scene graph or `hxd` anywhere. `RepeatBiome` owns the clock and
	`RepeatMesh` owns the upload.
**/
class FacadeLife {
	/** Cells across one facade — a plot's width at `CityFacade`'s own window pitch. **/
	public static inline final COLS:Int = 12;

	/** Cells up one facade — the tallest building's own height at that pitch, with headroom. **/
	public static inline final ROWS:Int = 17;

	/** World units per window cell. The lattice is defined here, not in the shader, since the simulation is what it has to line up with. **/
	public static inline final WINDOW_SIZE:Float = 3.4;

	/** How many ordinary facades there are: one per plot of a tile, which is every distinct building in the world. **/
	public static inline final FACADE_COUNT:Int = RepeatModel.PLOTS_PER_TILE * RepeatModel.PLOTS_PER_TILE;

	/**
		The index of the extra, deliberately broken facade.

		A building running this one cannot settle: every `GLITCH_PERIOD`
		generations its whole grid is stamped dead or alive, so whatever
		pattern was developing is wiped and starts over. It is the second
		kind of anomaly, and a different *sense* from the leaning one — that
		one is spotted by comparing shapes, this one only by watching. A
		player who never stands still never finds it.
	**/
	public static inline final GLITCH_FACADE:Int = FACADE_COUNT;

	/** Total grids, ordinary plus the glitch. **/
	public static inline final TOTAL_FACADES:Int = FACADE_COUNT + 1;

	/** Generations between the glitch facade's own wipes. **/
	public static inline final GLITCH_PERIOD:Int = 7;

	/** Fraction of cells alive in a fresh seed — dense enough to develop, sparse enough not to die of overcrowding on generation one. **/
	static inline final SEED_DENSITY:Float = 0.38;

	/** Cells, indexed `facade * COLS * ROWS + row * COLS + col`. **/
	var cells:Array<Bool>;

	/** How many generations have been stepped — drives the glitch's own period. **/
	public var generation(default, null):Int = 0;

	public function new() {
		cells = [for (_ in 0...TOTAL_FACADES * COLS * ROWS) false];
		seed();
	}

	/** Whether a cell is currently alive. Out-of-range coordinates read as dead, which is also the boundary rule. **/
	public function isAlive(facade:Int, col:Int, row:Int):Bool {
		if (facade < 0 || facade >= TOTAL_FACADES || col < 0 || col >= COLS || row < 0 || row >= ROWS) {
			return false;
		}
		return cells[facade * COLS * ROWS + row * COLS + col];
	}

	/**
		Which facade a plot runs.
		@param plotX plot column within the tile.
		@param plotZ plot row within the tile.
		@return that plot's own facade index.
	**/
	public static function facadeOf(plotX:Int, plotZ:Int):Int {
		return plotZ * RepeatModel.PLOTS_PER_TILE + plotX;
	}

	/**
		Advances every facade one generation under B3/S23, then applies the
		glitch facade's own wipe if this generation is one of its.

		Edges are dead rather than wrapped: a facade is a finite wall, and
		wrapping it would make patterns re-enter from the far side, which
		reads as a bug rather than as a rule.
	**/
	public function step():Void {
		var next = [for (_ in 0...cells.length) false];
		for (facade in 0...TOTAL_FACADES) {
			for (row in 0...ROWS) {
				for (col in 0...COLS) {
					var live = countNeighbours(facade, col, row);
					var alive = isAlive(facade, col, row);
					next[facade * COLS * ROWS + row * COLS + col] = alive ? (live == 2 || live == 3) : live == 3;
				}
			}
		}
		cells = next;
		generation++;

		if (generation % GLITCH_PERIOD == 0) {
			// Alternating rather than always-dead: a facade that only ever
			// blanks reads as a rendering fault, while one that also floods
			// reads as something wrong with the rule itself.
			var flood = Std.int(generation / GLITCH_PERIOD) % 2 == 0;
			for (index in 0...COLS * ROWS) {
				cells[GLITCH_FACADE * COLS * ROWS + index] = flood;
			}
		}
	}

	function countNeighbours(facade:Int, col:Int, row:Int):Int {
		var live = 0;
		for (dr in -1...2) {
			for (dc in -1...2) {
				if (dr == 0 && dc == 0) {
					continue;
				}
				if (isAlive(facade, col + dc, row + dr)) {
					live++;
				}
			}
		}
		return live;
	}

	function seed():Void {
		for (facade in 0...TOTAL_FACADES) {
			for (row in 0...ROWS) {
				for (col in 0...COLS) {
					cells[facade * COLS * ROWS + row * COLS + col] = noise(facade * COLS + col, row) < SEED_DENSITY;
				}
			}
		}
	}

	/**
		A deterministic value in `[0, 1)`. The same hash
		`RepeatModel` uses, for the same reason: the seed has to be a pure
		function of position so that a fresh `FacadeLife` is always the same
		city.
	**/
	static function noise(a:Int, b:Int):Float {
		var h = a * 374761393 + b * 668265263 + 928371;
		h = (h ^ (h >> 13)) * 1274126177;
		h = h ^ (h >> 16);
		return (h & 0x7FFFFFFF) / 2147483648.0;
	}
}
