package biomes.repeat;

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
}
