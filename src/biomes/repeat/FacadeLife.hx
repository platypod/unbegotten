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

	/**
		The Easter-egg facade: a building playing Tetris instead of running
		Life.

		**It is an anomaly, and deliberately the easy one.** The worry was
		that a joke in the same slot as two real tells would cheapen them;
		the answer, asked directly, is the opposite — it is *supposed* to be
		found early and easily, because a player who finds one obvious
		anomaly now knows there is a search to lead. It bootstraps the other
		two rather than competing with them.

		It also is not only a joke. In a space whose whole mechanic is
		spotting what has been intervened with, a facade running a
		**different rule** is the most extreme divergence available — and
		Thread 4 has the rule being locally editable. Somebody did this.

		**It loses.** See `stepTetris`.
	**/
	public static inline final TETRIS_FACADE:Int = FACADE_COUNT + 1;

	/**
		The facade that has **stopped**: seeded with still lifes and never
		stepped, so it stands perfectly motionless while every counterpart
		churns.

		Thread 2 stated in architecture — "the terrain is made of the ones
		who stopped" — and here is one, mid-city, that did. Distinct from
		`GLITCH_FACADE` in the way that matters: that one flails, this one is
		*still*, and stillness in a city that moves is its own kind of loud.
	**/
	public static inline final STOPPED_FACADE:Int = FACADE_COUNT + 2;

	/**
		Where the **phase band** starts: 36 more facades, seeded identically
		to the ordinary ones and stepped `PHASE_LAG` generations later, so
		facade `PHASE_BASE + p` is always exactly what facade `p` was a
		while ago.

		This is the most on-thesis anomaly in the set. The space's own claim
		is *same seed, same rule, same future — unless something
		intervened*, and a building out of phase is that sentence broken in
		the smallest way it can be broken. Nothing about it is wrong in
		isolation; it is only wrong *relative to a tile you remember*, which
		is the entire mechanic rather than a decoration on top of it.

		Running a second lagged copy rather than keeping a history buffer:
		the simulation is deterministic, so a copy that starts late *is* the
		past, exactly, for free.
	**/
	public static inline final PHASE_BASE:Int = FACADE_COUNT + 3;

	/** How many generations the phase band lags. Long enough that the difference is a real memory test, short enough to still be the same pattern. **/
	public static inline final PHASE_LAG:Int = 9;

	/** Total grids: one per plot, the glitch, the Tetris, the stopped one, and the lagged copy of every plot. **/
	public static inline final TOTAL_FACADES:Int = FACADE_COUNT * 2 + 3;

	/**
		The seven tetrominoes, as `[col, row]` offsets from the spawn corner
		with row growing downward. Written out rather than generated: they
		are the piece set, not data, and a reader should be able to see the
		S and the Z are different.
	**/
	static final TETROMINOES:Array<Array<Array<Int>>> = [
		[[0, 0], [1, 0], [2, 0], [3, 0]], // I
		[[0, 0], [1, 0], [0, 1], [1, 1]], // O
		[[0, 0], [1, 0], [2, 0], [1, 1]], // T
		[[0, 0], [1, 0], [2, 0], [2, 1]], // J
		[[0, 0], [1, 0], [2, 0], [0, 1]], // L
		[[1, 0], [2, 0], [0, 1], [1, 1]], // S
		[[0, 0], [1, 0], [1, 1], [2, 1]] // Z
	];

	/** Generations between the glitch facade's own wipes. **/
	public static inline final GLITCH_PERIOD:Int = 7;

	/** Fraction of cells alive in a fresh seed — dense enough to develop, sparse enough not to die of overcrowding on generation one. **/
	static inline final SEED_DENSITY:Float = 0.38;

	/** Cells, indexed `facade * COLS * ROWS + row * COLS + col`. Row `0` is the bottom of a facade, since a window's row comes from its height above the ground. **/
	var cells:Array<Bool>;

	/** The falling piece's own cells, as `[col, row]` pairs, or empty between pieces. **/
	var piece:Array<Array<Int>> = [];

	/** How many pieces have been dropped — also the hash salt that picks the next one, so the sequence is deterministic. **/
	var piecesDropped:Int = 0;

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
		Which rule a facade runs. Explicit rather than a pair of index
		comparisons scattered through `step`, since this is exactly the
		"behaviour mode" CLAUDE.md wants stated as a machine — and a fourth
		rule should be one branch here rather than another special case
		bolted on.
		@param facade the facade index.
		@return the rule it runs.
	**/
	public static function ruleOf(facade:Int):FacadeRule {
		if (facade == GLITCH_FACADE) {
			return Glitched;
		}
		if (facade == TETRIS_FACADE) {
			return Tetris;
		}
		if (facade == STOPPED_FACADE) {
			return Stopped;
		}
		return facade >= PHASE_BASE ? Phased : Conway;
	}

	/**
		The lagged twin of a plot's own facade — what it looked like
		`PHASE_LAG` generations ago.
		@param plotX plot column within the tile.
		@param plotZ plot row within the tile.
		@return that plot's phase-band facade index.
	**/
	public static function phasedFacadeOf(plotX:Int, plotZ:Int):Int {
		return PHASE_BASE + facadeOf(plotX, plotZ);
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
		var next = cells.copy();
		for (facade in 0...TOTAL_FACADES) {
			var rule = ruleOf(facade);
			// `Stopped` never steps — that is the whole of it. `Phased` runs
			// the same rule as `Conway`, just starting `PHASE_LAG`
			// generations later, so it is stepped here too but only once the
			// lag has elapsed.
			if (rule == Stopped || rule == Glitched || rule == Tetris) {
				continue;
			}
			if (rule == Phased && generation < PHASE_LAG) {
				continue;
			}
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

		stepTetris();
	}

	/**
		Advances the Tetris facade one frame: the piece falls a row, locks
		when it cannot, full rows clear, and a topped-out board is wiped and
		started over.

		**It plays badly on purpose.** Each piece is dropped at a hashed
		column with no rotation and no attempt to fit — so the stack goes
		ragged, holes get buried, and it tops out and starts again, forever.
		That is the whole point of it: a perfect-play Tetris reads as a flex,
		and a losing one reads as a *tomb*, which is what this city is.
		Mechanically it is an oscillator that never learns, which is exactly
		what Thread 2 says the ghosts are.
	**/
	function stepTetris():Void {
		// Lift the piece off the board first, so everything below reasons
		// about *settled* cells only. Without this the piece stayed painted
		// at every row it had passed through: it left a trail up the
		// facade, and — worse than the look of it — that trail counted as
		// board, so the next piece landed on the smear instead of falling.
		erasePiece();

		if (piece.length == 0) {
			spawnPiece();
			return;
		}

		if (canFall()) {
			for (cell in piece) {
				cell[1]--;
			}
			paintPiece();
			return;
		}

		paintPiece(); // settles where it stopped; it is board from here on
		clearFullRows();
		piece = [];
		spawnPiece();
	}

	/** Clears the falling piece's cells, leaving only settled board behind. **/
	function erasePiece():Void {
		for (cell in piece) {
			if (cell[0] >= 0 && cell[0] < COLS && cell[1] >= 0 && cell[1] < ROWS) {
				cells[TETRIS_FACADE * COLS * ROWS + cell[1] * COLS + cell[0]] = false;
			}
		}
	}

	/** Whether every cell of the falling piece has empty space below it. **/
	function canFall():Bool {
		for (cell in piece) {
			var below = cell[1] - 1;
			if (below < 0) {
				return false;
			}
			if (isLocked(cell[0], below)) {
				return false;
			}
		}
		return true;
	}

	/**
		Whether a cell holds settled board.

		No longer has to exclude the falling piece's own cells: `stepTetris`
		lifts the piece off the board before anything asks. That exclusion
		was a workaround for the piece being painted in place, and it hid
		the trail bug rather than preventing it.
	**/
	function isLocked(col:Int, row:Int):Bool {
		if (col < 0 || col >= COLS || row < 0 || row >= ROWS) {
			return true;
		}
		return cells[TETRIS_FACADE * COLS * ROWS + row * COLS + col];
	}

	function spawnPiece():Void {
		var shapes = TETROMINOES;
		var shape = shapes[Std.int(noise(piecesDropped, 91) * shapes.length) % shapes.length];
		var column = Std.int(noise(piecesDropped, 17) * COLS);
		piecesDropped++;

		var spawned = [for (offset in shape) [column + offset[0], ROWS - 1 - offset[1]]];
		for (cell in spawned) {
			if (cell[0] < 0 || cell[0] >= COLS) {
				// Off the side: the bad player does not check, so the piece is
				// simply lost. Another way this board never improves.
				piece = [];
				return;
			}
		}
		// Topped out: the new piece has nowhere to be. Wipe and start over,
		// which is the losing this facade exists to do.
		for (cell in spawned) {
			if (isLocked(cell[0], cell[1])) {
				for (index in 0...COLS * ROWS) {
					cells[TETRIS_FACADE * COLS * ROWS + index] = false;
				}
				piece = [];
				return;
			}
		}
		piece = spawned;
		paintPiece();
	}

	/** Draws the falling piece into the grid so the shader can see it. **/
	function paintPiece():Void {
		for (cell in piece) {
			if (cell[0] >= 0 && cell[0] < COLS && cell[1] >= 0 && cell[1] < ROWS) {
				cells[TETRIS_FACADE * COLS * ROWS + cell[1] * COLS + cell[0]] = true;
			}
		}
	}

	/** Removes every full row and drops what was above it. **/
	function clearFullRows():Void {
		var kept = [];
		for (row in 0...ROWS) {
			var full = true;
			for (col in 0...COLS) {
				if (!cells[TETRIS_FACADE * COLS * ROWS + row * COLS + col]) {
					full = false;
					break;
				}
			}
			if (!full) {
				kept.push([for (col in 0...COLS) cells[TETRIS_FACADE * COLS * ROWS + row * COLS + col]]);
			}
		}
		for (row in 0...ROWS) {
			for (col in 0...COLS) {
				cells[TETRIS_FACADE * COLS * ROWS + row * COLS + col] = row < kept.length ? kept[row][col] : false;
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
			// The phase band is seeded from its *twin*, not from itself:
			// being the same city a moment later is the entire point, and a
			// band with its own seed would just be 36 more unrelated
			// buildings.
			var seedFrom = facade >= PHASE_BASE ? facade - PHASE_BASE : facade;
			for (row in 0...ROWS) {
				for (col in 0...COLS) {
					cells[facade * COLS * ROWS + row * COLS + col] = noise(seedFrom * COLS + col, row) < SEED_DENSITY;
				}
			}
		}
		seedStopped();
	}

	/**
		Fills `STOPPED_FACADE` with blocks — the canonical still life, so it
		is genuinely settled rather than merely frozen: were it ever stepped,
		it would not change. A facade that only *looks* stopped because
		nothing advances it would be a lie of the same kind the static
		window hash was.
	**/
	function seedStopped():Void {
		for (index in 0...COLS * ROWS) {
			cells[STOPPED_FACADE * COLS * ROWS + index] = false;
		}
		var row = 1;
		while (row + 1 < ROWS - 1) {
			var col = 1;
			while (col + 1 < COLS - 1) {
				cells[STOPPED_FACADE * COLS * ROWS + row * COLS + col] = true;
				cells[STOPPED_FACADE * COLS * ROWS + row * COLS + col + 1] = true;
				cells[STOPPED_FACADE * COLS * ROWS + (row + 1) * COLS + col] = true;
				cells[STOPPED_FACADE * COLS * ROWS + (row + 1) * COLS + col + 1] = true;
				col += 4;
			}
			row += 4;
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

/** Which rule a facade runs — see `FacadeLife.ruleOf`. **/
enum FacadeRule {
	/** Conway's B3/S23, which is what the world claims everything here runs. **/
	Conway;

	/** Life, but wiped on a period so it can never settle. **/
	Glitched;

	/** Not Life at all: somebody changed the rule here. **/
	Tetris;

	/** Settled into still lifes and never stepped again — one of the ones who stopped. **/
	Stopped;

	/** The same rule and the same seed, running `FacadeLife.PHASE_LAG` generations late. **/
	Phased;
}
