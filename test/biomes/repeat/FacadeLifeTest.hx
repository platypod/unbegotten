package biomes.repeat;

import biomes.repeat.FacadeLife.FacadeRule;
import utest.Assert;
import utest.Test;

/**
	Covers the facade simulation — that it is really Conway's rule, that it
	is seeded identically for every tile, and that the glitch facade cannot
	settle.

	The rule itself is worth pinning rather than trusting: a Life that is
	subtly not Life still *looks* like something evolving, so nothing in a
	screenshot would catch it, and the whole reason the city runs one is
	that the world claims everything in it is cells under a rule. A city
	running an approximation would be the claim quietly being false.
**/
class FacadeLifeTest extends Test {
	function testABlockIsAStillLife():Void {
		// The 2x2 block is the canonical still life; if B3/S23 is right it
		// survives forever, and if the neighbour count is off by one it
		// will not.
		var life = new FacadeLife();
		var grid = blank(life);
		set(grid, 3, 3);
		set(grid, 4, 3);
		set(grid, 3, 4);
		set(grid, 4, 4);
		write(life, grid);

		life.step();

		Assert.isTrue(life.isAlive(0, 3, 3));
		Assert.isTrue(life.isAlive(0, 4, 3));
		Assert.isTrue(life.isAlive(0, 3, 4));
		Assert.isTrue(life.isAlive(0, 4, 4));
		Assert.equals(4, aliveIn(life, 0));
	}

	function testABlinkerOscillates():Void {
		var life = new FacadeLife();
		var grid = blank(life);
		set(grid, 3, 4);
		set(grid, 4, 4);
		set(grid, 5, 4);
		write(life, grid);

		life.step();

		// horizontal becomes vertical
		Assert.isTrue(life.isAlive(0, 4, 3));
		Assert.isTrue(life.isAlive(0, 4, 4));
		Assert.isTrue(life.isAlive(0, 4, 5));
		Assert.equals(3, aliveIn(life, 0));

		life.step();

		Assert.isTrue(life.isAlive(0, 3, 4));
		Assert.isTrue(life.isAlive(0, 5, 4));
	}

	function testALoneCellDies():Void {
		var life = new FacadeLife();
		var grid = blank(life);
		set(grid, 5, 5);
		write(life, grid);

		life.step();

		Assert.equals(0, aliveIn(life, 0));
	}

	function testEdgesAreDeadRatherThanWrapped():Void {
		// A wrapped edge would let a pattern re-enter from the far side of
		// a wall, which reads as a bug rather than as a rule.
		var life = new FacadeLife();
		var grid = blank(life);
		set(grid, 0, 0);
		set(grid, 1, 0);
		set(grid, 0, 1);
		write(life, grid);

		life.step();

		Assert.isTrue(life.isAlive(0, 1, 1), "the corner triple should birth its fourth cell");
		Assert.isFalse(life.isAlive(0, FacadeLife.COLS - 1, 0), "something wrapped around the edge");
	}

	function testEveryFacadeIsSeededFromItsPlotAloneSoTwoRunsAgree():Void {
		// Tile identity ultimately rests on this: a second `FacadeLife` has
		// to be the same city, or nothing downstream can be deterministic.
		var a = new FacadeLife();
		var b = new FacadeLife();
		for (_ in 0...5) {
			a.step();
			b.step();
		}
		for (facade in 0...FacadeLife.TOTAL_FACADES) {
			for (row in 0...FacadeLife.ROWS) {
				for (col in 0...FacadeLife.COLS) {
					Assert.equals(a.isAlive(facade, col, row), b.isAlive(facade, col, row));
				}
			}
		}
	}

	function testTheFacadesAreNotAllTheSameSimulation():Void {
		// Otherwise every building in the city would be identical and the
		// "some towers settle, some churn" contrast could never happen.
		var life = new FacadeLife();
		var differing = 0;
		for (facade in 1...FacadeLife.FACADE_COUNT) {
			if (aliveIn(life, facade) != aliveIn(life, 0)) {
				differing++;
			}
		}
		Assert.isTrue(differing > FacadeLife.FACADE_COUNT / 2, 'only $differing facades differ from the first');
	}

	function testTheGlitchFacadeIsWipedOnItsOwnPeriod():Void {
		var life = new FacadeLife();
		for (_ in 0...FacadeLife.GLITCH_PERIOD) {
			life.step();
		}
		var cells = FacadeLife.COLS * FacadeLife.ROWS;
		var alive = aliveIn(life, FacadeLife.GLITCH_FACADE);

		Assert.isTrue(alive == 0 || alive == cells, 'the glitch facade should be wholly dead or wholly alive, but $alive of $cells are alive');
	}

	function testTheGlitchFacadeAlternatesRatherThanOnlyBlanking():Void {
		// A facade that only ever blanks reads as a rendering fault; one
		// that also floods reads as something wrong with the rule.
		var life = new FacadeLife();
		var states = [];
		for (_ in 0...4) {
			for (_ in 0...FacadeLife.GLITCH_PERIOD) {
				life.step();
			}
			states.push(aliveIn(life, FacadeLife.GLITCH_FACADE) > 0);
		}

		Assert.contains(true, states);
		Assert.contains(false, states);
	}

	function testOrdinaryFacadesAreNeverWiped():Void {
		var life = new FacadeLife();
		for (_ in 0...FacadeLife.GLITCH_PERIOD * 2) {
			life.step();
		}
		var cells = FacadeLife.COLS * FacadeLife.ROWS;
		var wiped = 0;
		for (facade in 0...FacadeLife.FACADE_COUNT) {
			var alive = aliveIn(life, facade);
			if (alive == 0 || alive == cells) {
				wiped++;
			}
		}
		Assert.equals(0, wiped, '$wiped ordinary facades were wiped along with the glitch one');
	}

	// --- helpers: seed facade 0 directly, so a rule test is not at the
	// mercy of whatever the deterministic seed happened to produce.

	function blank(life:FacadeLife):Array<Bool> {
		return [for (_ in 0...FacadeLife.COLS * FacadeLife.ROWS) false];
	}

	function set(grid:Array<Bool>, col:Int, row:Int):Void {
		grid[row * FacadeLife.COLS + col] = true;
	}

	function write(life:FacadeLife, grid:Array<Bool>):Void {
		@:privateAccess for (index in 0...grid.length) {
			life.cells[index] = grid[index];
		}
	}

	function aliveIn(life:FacadeLife, facade:Int):Int {
		var alive = 0;
		for (row in 0...FacadeLife.ROWS) {
			for (col in 0...FacadeLife.COLS) {
				if (life.isAlive(facade, col, row)) {
					alive++;
				}
			}
		}
		return alive;
	}

	// --- The Tetris facade: an Easter egg that has to actually lose.

	function testTheTetrisFacadeIsNotRunningLife():Void {
		Assert.equals(Tetris, FacadeLife.ruleOf(FacadeLife.TETRIS_FACADE));
		Assert.equals(Glitched, FacadeLife.ruleOf(FacadeLife.GLITCH_FACADE));
		Assert.equals(Conway, FacadeLife.ruleOf(0));
	}

	function testTheTetrisFacadeEventuallyStacksSomething():Void {
		// If pieces never locked, the board would be empty forever and the
		// egg would just be a dark building.
		var life = new FacadeLife();
		for (_ in 0...60) {
			life.step();
		}
		Assert.isTrue(aliveIn(life, FacadeLife.TETRIS_FACADE) > 0, "nothing ever landed on the Tetris board");
	}

	function testTheTetrisFacadeNeverOverflowsItsOwnGrid():Void {
		// The piece walks a raw index; a spawn off the side or a lock past
		// the top would corrupt a neighbouring facade's cells rather than
		// erroring, which is the kind of bug that shows up as another
		// building behaving strangely.
		var life = new FacadeLife();
		var before = [for (facade in 0...FacadeLife.FACADE_COUNT) aliveIn(life, facade)];
		for (_ in 0...200) {
			life.step();
		}
		var conwayMoved = 0;
		for (facade in 0...FacadeLife.FACADE_COUNT) {
			if (aliveIn(life, facade) != before[facade]) {
				conwayMoved++;
			}
		}
		// They should have evolved on their own, but none should have been
		// stamped wholly on or off the way only the glitch is.
		var cells = FacadeLife.COLS * FacadeLife.ROWS;
		for (facade in 0...FacadeLife.FACADE_COUNT) {
			var alive = aliveIn(life, facade);
			Assert.isTrue(alive < cells, 'facade $facade was flooded, which only the glitch may be');
		}
		Assert.isTrue(conwayMoved > 0, "no ordinary facade evolved at all");
	}

	function testTheTetrisFacadeLoses():Void {
		// The whole point of the egg: it plays badly, tops out, and starts
		// over. A board that only ever grew would mean it never resets; one
		// that never shrank would mean rows never clear either.
		var life = new FacadeLife();
		var counts = [];
		for (_ in 0...400) {
			life.step();
			counts.push(aliveIn(life, FacadeLife.TETRIS_FACADE));
		}
		var drops = 0;
		for (index in 1...counts.length) {
			if (counts[index] < counts[index - 1]) {
				drops++;
			}
		}
		Assert.isTrue(drops > 0, "the Tetris board never lost anything — it neither clears rows nor tops out");
	}

	// --- The two anomaly facades added with the difficulty tiers.

	function testTheStoppedFacadeIsGenuinelySettledNotMerelyFrozen():Void {
		// A facade that only *looks* stopped because nothing advances it
		// would be a lie of the same kind the static window hash was. These
		// are blocks: step them and they would not move.
		var life = new FacadeLife();
		var before = aliveIn(life, FacadeLife.STOPPED_FACADE);
		Assert.isTrue(before > 0, "the stopped facade is empty, so it reads as a dark building rather than a settled one");

		// Every live cell should be part of a 2x2 block — the still life.
		for (row in 0...FacadeLife.ROWS) {
			for (col in 0...FacadeLife.COLS) {
				if (!life.isAlive(FacadeLife.STOPPED_FACADE, col, row)) {
					continue;
				}
				var neighbours = 0;
				for (dr in -1...2) {
					for (dc in -1...2) {
						if ((dr != 0 || dc != 0) && life.isAlive(FacadeLife.STOPPED_FACADE, col + dc, row + dr)) {
							neighbours++;
						}
					}
				}
				Assert.equals(3, neighbours, 'a cell at ($col, $row) has $neighbours neighbours, so it is not part of a block and would change if stepped');
			}
		}
	}

	function testTheStoppedFacadeNeverMoves():Void {
		var life = new FacadeLife();
		var before = snapshot(life, FacadeLife.STOPPED_FACADE);
		for (_ in 0...40) {
			life.step();
		}
		Assert.same(before, snapshot(life, FacadeLife.STOPPED_FACADE));
	}

	function testThePhaseBandIsItsTwinRunningLate():Void {
		// The load-bearing property of the whole `Phased` anomaly: it has to
		// be the *same* city a moment ago, not another one. Checked by
		// running past the lag and comparing the band against a second
		// simulation stopped `PHASE_LAG` generations earlier.
		var ahead = new FacadeLife();
		var behind = new FacadeLife();
		var total = FacadeLife.PHASE_LAG + 6;
		for (_ in 0...total) {
			ahead.step();
		}
		for (_ in 0...(total - FacadeLife.PHASE_LAG)) {
			behind.step();
		}

		for (plot in 0...FacadeLife.FACADE_COUNT) {
			var phased = FacadeLife.PHASE_BASE + plot;
			Assert.same(snapshot(behind, plot), snapshot(ahead, phased), 'phase band facade $plot is not its twin running late');
		}
	}

	function testThePhaseBandDiffersFromTheLiveOne():Void {
		// If they matched, the anomaly would be invisible.
		var life = new FacadeLife();
		for (_ in 0...(FacadeLife.PHASE_LAG + 6)) {
			life.step();
		}
		var differing = 0;
		for (plot in 0...FacadeLife.FACADE_COUNT) {
			if (snapshot(life, plot).join("") != snapshot(life, FacadeLife.PHASE_BASE + plot).join("")) {
				differing++;
			}
		}
		Assert.isTrue(differing > FacadeLife.FACADE_COUNT / 2, 'only $differing facades differ from their lagged twin');
	}

	function snapshot(life:FacadeLife, facade:Int):Array<Bool> {
		return [
			for (row in 0...FacadeLife.ROWS)
				for (col in 0...FacadeLife.COLS)
					life.isAlive(facade, col, row)
		];
	}
}
