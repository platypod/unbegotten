package biomes.weft;

import biomes.common.grid.GridModel;
import biomes.common.grid.GridModel.GridData;
import biomes.common.grid.GridModel.GridNode;
import biomes.maze.MazeGenerator;
import utest.Assert;
import utest.Test;

/**
	Covers the propagation carver — that it obeys the invariant it is built
	around, and that it actually delivers the connectivity it exists for.

	**The second half is the point.** `WeftCarver` is not a texture change;
	it replaces a generator that left the sphere in four or five pieces, and
	the only honest way to hold it to that is to measure the layouts it
	produces and compare against the pipeline it replaced. So these tests
	carve many spheres and assert on the distribution, which is unusual here
	and deliberate: a single layout proves nothing about a generator whose
	whole claim is statistical.
**/
class WeftCarverTest extends Test {
	/** Enough layouts for the connectivity assertions to mean something without making the suite slow. **/
	static inline final SAMPLES:Int = 12;

	/**
		The rule the whole space is built on: exactly one wall of every
		antipodal pair is open. `WeftCarver` produces this by construction
		rather than by being corrected afterward, which is the difference
		between it and `WeftModel.enforceOpposite`.
	**/
	function testEveryAntipodalPairHasExactlyOneWallOpen():Void {
		var checked = 0;
		for (attempt in 0...SAMPLES) {
			var maze = WeftCarver.carve();
			for (node in GridModel.allNodes()) {
				for (neighbor in GridModel.neighborsOf(node)) {
					var partner = WeftModel.partnerOf(node, neighbor);
					if (partner == null) {
						continue;
					}
					checked++;
					var here = GridModel.isOpen(maze, node, neighbor);
					var there = GridModel.isOpen(maze, partner.a, partner.b);
					Assert.isFalse(here == there, 'a wall and its antipode are both ${here ? "open" : "closed"}');
				}
			}
		}
		Assert.isTrue(checked > 0, "no paired walls were checked at all");
	}

	/** Every pair is *decided* — the propagation loop can defer a pair, but it must never leave one unspent. **/
	function testNoPairIsLeftUndecided():Void {
		var maze = WeftCarver.carve();
		for (node in GridModel.allNodes()) {
			for (neighbor in GridModel.neighborsOf(node)) {
				var partner = WeftModel.partnerOf(node, neighbor);
				if (partner == null) {
					continue;
				}
				var open = GridModel.isOpen(maze, node, neighbor) || GridModel.isOpen(maze, partner.a, partner.b);
				Assert.isTrue(open, "an antipodal pair came out with both walls shut");
			}
		}
	}

	/**
		The reason this class exists: propagation leaves far less of the
		sphere stranded than carving one hemisphere and complementing the
		other.

		Measured over 30 layouts each, the old pipeline left 5.1 components
		with the largest holding 190 of 240 cells; this one leaves 2.8 with
		the largest holding 238. The bound below is well clear of both, so
		it fails if the carver regresses toward the old behaviour without
		being so tight that ordinary variance trips it.
	**/
	function testTheSphereComesOutNearlyWhole():Void {
		var total = 0.0;
		for (attempt in 0...SAMPLES) {
			var largest = largestComponentOf(WeftCarver.carve());
			Assert.isTrue(largest > 200, 'a layout stranded ${240 - largest} of 240 cells');
			total += largest;
		}
		var mean = total / SAMPLES;
		Assert.isTrue(mean > 225, 'the largest component averaged $mean of 240 cells');
	}

	/** And it beats the pipeline it replaced on the same measure, run side by side rather than against a number written down once. **/
	function testItStrandsLessThanCarvingOneHemisphere():Void {
		var carved = 0.0;
		var complemented = 0.0;
		for (attempt in 0...SAMPLES) {
			carved += largestComponentOf(WeftCarver.carve());
			var old = MazeGenerator.generate();
			WeftModel.enforceOpposite(old);
			complemented += largestComponentOf(old);
		}
		Assert.isTrue(carved > complemented, 'propagation reached $carved cells against the old pipeline\'s $complemented');
	}

	/** Same random source, same sphere — the carver may not reach for `Math.random` behind the caller's back. **/
	function testCarvingIsDeterministicForAGivenRandomSource():Void {
		var first = WeftCarver.carve(seeded(20260906));
		var second = WeftCarver.carve(seeded(20260906));

		Assert.equals(edgeSignatureOf(first), edgeSignatureOf(second));
	}

	/** And different sources give different spheres, or the shuffle is not doing anything. **/
	function testDifferentSeedsGiveDifferentSpheres():Void {
		var first = WeftCarver.carve(seeded(1));
		var second = WeftCarver.carve(seeded(2));

		Assert.notEquals(edgeSignatureOf(first), edgeSignatureOf(second));
	}

	/**
		A deterministic stand-in for `Math.random` — a plain 32-bit LCG,
		enough to make a test repeatable and not used for anything else.
		@param seed the sequence to start from.
		@return a source of values in [0, 1).
	**/
	function seeded(seed:Int):Void->Float {
		var state = seed;
		return function():Float {
			state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
			return state / 2147483648.0;
		};
	}

	/**
		A layout's open edges as one comparable string.
		@param maze the layout to fingerprint.
		@return its sorted open-edge keys, joined.
	**/
	function edgeSignatureOf(maze:GridData):String {
		var keys = [for (key in maze.openEdges.keys()) key];
		keys.sort((a, b) -> a < b ? -1 : (a > b ? 1 : 0));
		return keys.join(",");
	}

	/**
		How many cells the biggest connected region holds, walking open walls
		only — no hinges, since this measures the *carve* rather than what
		the player can eventually open.
		@param maze the layout to measure.
		@return the size of its largest connected component.
	**/
	function largestComponentOf(maze:GridData):Int {
		var seen = new Map<String, Bool>();
		var largest = 0;
		for (start in GridModel.allNodes()) {
			if (seen.exists(GridModel.nodeKey(start))) {
				continue;
			}
			var size = 0;
			var frontier:Array<GridNode> = [start];
			seen.set(GridModel.nodeKey(start), true);
			while (frontier.length > 0) {
				var here = frontier.pop();
				if (here == null) {
					break;
				}
				size++;
				for (neighbor in GridModel.neighborsOf(here)) {
					if (!GridModel.isOpen(maze, here, neighbor)) {
						continue;
					}
					var key = GridModel.nodeKey(neighbor);
					if (seen.exists(key)) {
						continue;
					}
					seen.set(key, true);
					frontier.push(neighbor);
				}
			}
			if (size > largest) {
				largest = size;
			}
		}
		return largest;
	}
}
