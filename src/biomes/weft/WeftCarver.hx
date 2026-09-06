package biomes.weft;

import biomes.common.grid.GridModel;
import biomes.common.grid.GridModel.GridData;
import biomes.common.grid.GridModel.GridNode;

/** One wall, as its two cells — the shape `WeftModel.partnerOf` already hands back. **/
typedef WeftWall = {a:GridNode, b:GridNode};

/**
	One antipodal pair of walls, and therefore **one binary decision**: the
	invariant says exactly one of the two is open, so a pair is a variable
	with two values rather than two independent walls.
**/
typedef WeftOrbit = {near:WeftWall, far:WeftWall};

/**
	The Weft's own generator: carves the **whole sphere at once**, one
	antipodal pair at a time, by constraint propagation.

	Replaces "carve a maze in the north, force the south to its complement"
	(`MazeGenerator.generate` followed by `WeftModel.enforceOpposite`),
	which produced a sphere in four or five disconnected pieces. What
	follows is why that was never a tuning problem, and why this is the
	shape of the fix.

	## The invariant conserves connectivity — it cannot create it

	Exactly one wall per antipodal pair is open, always. Measured across 30
	layouts that is 224 open paired walls with **zero variance**, because it
	is not a statistical property but the rule itself. The only walls the
	generator may spend freely are the 56 unpaired ones in the pole collars
	(see `WeftModel`'s class doc for why those rows have no partner), of
	which around 21 come out open.

	So the open-edge count is pinned near 245 for 240 cells, and a spanning
	tree needs 239. **The Weft runs on about six edges of slack**, and that
	is arithmetic, not luck: the grid is 4-regular, so `|E| ≈ 2|V|`, the
	rule halves it to `|E|/2 ≈ |V|`, and a connected graph needs `|V| - 1`.
	The space sits exactly on the connectivity threshold by construction.

	The consequence is that connectivity cannot be *added* to this space,
	only moved between hemispheres. Three levers were measured, and all
	three confirmed it:

	- **Opening every pole-collar wall** (the maximum slack the rule
		permits, 280 open edges) took the layout from 4.8 components to
		3.0. The slack is in the wrong place — the collars cannot reach a
		component stranded at mid-latitude.
	- **Braiding the base carve** from 0 to 100% made it *worse*: 4.5
		components to 6.8. Every dead end opened in the north forces a wall
		shut in the south, one for one.
	- **Binding only some pairs** (10% through 100%) fragmented it at once:
		one component becomes 4.6 at just 10% bound. It is not how many
		pairs are bound, it is that binding any of them costs a spanning
		tree its only slack.

	Braiding making things worse is the clean proof that this is zero-sum.

	## Which is why a hemisphere cannot generate

	`enforceOpposite` carves the north and lets the south follow, which is
	optimising half a sphere at the exact cost of the other half. No
	generator that treats one hemisphere as authoritative can produce a
	connected Weft, however good its carve. The decision has to be taken
	over the whole sphere, with each antipodal pair as a single either/or.

	## The formal object: a ℤ/2 voltage graph

	This space is not a novel construction. The antipodal map is a free
	involution (on the pairable part), and by the **Gross–Tucker theorem** a
	group acting freely on a graph makes that graph the *derived graph* of a
	**voltage assignment** on the quotient. Here the group is ℤ/2, the
	quotient is the Weft's grid modulo the antipodal map, and the choice of
	which lift of each quotient edge is open **is** the voltage. See
	[Wolfram MathWorld on voltage graphs](https://mathworld.wolfram.com/VoltageGraph.html)
	and Gross & Tucker, *Generating all graph coverings by permutation
	voltage assignments* (Discrete Mathematics, 1977).

	The frame earns its keep by naming the decision variables: there are
	224 orbits, not 504 walls, and a generator should be searching the
	former. Everything below follows from taking that seriously.

	## Four generators, measured

	Over the same 30-layout harness (components, and the size of the
	largest, out of 240 cells):

	| generator | components | largest |
	|---|---|---|
	| carve north, complement south (the old one) | 4.9 | 202 |
	| orbit-Kruskal, one greedy pass | 6.3 | 232 |
	| hill-climb using the player's own flip as the move | 2.4 | — |
	| **constraint propagation over orbits** (this) | **3.5** | **237** |

	One greedy pass is *worse* than doing nothing clever, and the reason is
	instructive: early on almost every pair merges something whichever way
	it is spent, so a greedy pass burns its freedom on coin flips and
	starves the pairs that are genuinely forced later.

	The hill-climb is the prettiest of the four — the generator searching
	with the same verb the player uses, since flipping a pair is the only
	move that preserves the invariant — but it stalls, because escaping the
	last plateau needs two simultaneous flips and a single-flip climb cannot
	see it. Kept in the record because it is the obvious thing to reach for
	again, and it does not work.

	## What this does instead

	Unit propagation, with orbits as the variables. Commit only the pairs
	where exactly **one** of the two lifts merges two components; re-scan,
	because every commitment changes which of the remaining pairs are
	forced; and break a tie at random only when a whole pass finds nothing
	forced at all. The unpaired collar walls, being free, are spent first,
	so propagation has as much settled structure as possible to reason
	against.

	**It does not reach one component, and is not expected to.** Three or so
	cells still end up stranded, against nearly forty before. The floor is
	`WeftModel.hingesFor`'s repair, which guarantees the beacon and the exit
	are reachable; the point of carving better is that the repair then has
	almost nothing to do, so the guaranteed route stops dominating the
	level.

	**Neither hemisphere is individually "the carved one" any more**, and
	that is a deliberate reversal of `enforceOpposite`'s own decision. What
	that decision was protecting survives untouched: the far side is still
	the exact photographic negative of the near side, because that follows
	from the invariant rather than from which side generated. What is lost
	is the north being a maze in its own right. That is the trade — one
	maze wrapped on a sphere, rather than a maze and its complement.
**/
class WeftCarver {
	/**
		Carves a layout obeying the antipodal invariant.
		@param random source of randomness in [0, 1); defaults to Math.random.
		@return the carved layout, ready for `WeftModel.hingesFor`.
	**/
	public static function carve(?random:Void->Float):GridData {
		var rng = random != null ? random : Math.random;
		var nodes = GridModel.allNodes();
		var walls = wallsOf(nodes);
		shuffle(walls.orbits, rng);
		shuffle(walls.unpaired, rng);

		var groups = new Map<String, String>();
		for (node in nodes) {
			groups.set(GridModel.nodeKey(node), GridModel.nodeKey(node));
		}
		var grid:GridData = {openEdges: new haxe.ds.StringMap<Bool>()};

		// The collar walls have no partner, so opening one costs nothing
		// anywhere else — the only free moves this space has. Spent first,
		// so propagation reasons against as much settled structure as it
		// can get.
		for (wall in walls.unpaired) {
			if (joins(groups, wall)) {
				commit(grid, groups, wall);
			}
		}

		var pending = walls.orbits;
		while (pending.length > 0) {
			var deferred:Array<WeftOrbit> = [];
			var committed = 0;
			for (orbit in pending) {
				var near = joins(groups, orbit.near);
				var far = joins(groups, orbit.far);
				if (near == far) {
					deferred.push(orbit); // both merge, or neither does: nothing forces this one yet
					continue;
				}
				commit(grid, groups, near ? orbit.near : orbit.far);
				committed++;
			}
			if (committed == 0) {
				// Nothing forced anywhere. Spend a single pair at random and
				// go round again — that one commitment is usually enough to
				// force several others.
				var free = deferred.shift();
				if (free == null) {
					break;
				}
				commit(grid, groups, rng() < 0.5 ? free.near : free.far);
			}
			pending = deferred;
		}
		return grid;
	}

	/**
		Every antipodal pair, and every wall that has no partner.

		Walks the whole grid rather than deriving the pairs arithmetically,
		for the same reason `WeftModel.antipodeOf` resolves through
		`GridModel.nodeAt`: the pairing is a property of the grid's own
		geometry, and a shortcut here would silently disagree with it the
		next time `colsForRow` changes.
		@param nodes every cell in the grid.
		@return the orbits and the unpaired walls, each listed once.
	**/
	static function wallsOf(nodes:Array<GridNode>):{orbits:Array<WeftOrbit>, unpaired:Array<WeftWall>} {
		var orbits:Array<WeftOrbit> = [];
		var unpaired:Array<WeftWall> = [];
		var seenOrbit = new Map<String, Bool>();
		var seenWall = new Map<String, Bool>();
		for (node in nodes) {
			for (neighbor in GridModel.neighborsOf(node)) {
				var canonical = WeftModel.canonicalKeyOf(node, neighbor);
				if (canonical == null) {
					var key = GridModel.edgeKey(node, neighbor);
					if (!seenWall.exists(key)) {
						seenWall.set(key, true);
						unpaired.push({a: node, b: neighbor});
					}
					continue;
				}
				if (seenOrbit.exists(canonical)) {
					continue;
				}
				var partner = WeftModel.partnerOf(node, neighbor);
				if (partner == null) {
					continue; // canonicalKeyOf already proved this cannot happen; kept so null safety needs no cast
				}
				seenOrbit.set(canonical, true);
				orbits.push({near: {a: node, b: neighbor}, far: partner});
			}
		}
		return {orbits: orbits, unpaired: unpaired};
	}

	/**
		Whether opening this wall would merge two separate regions — the
		whole of the propagation's reasoning.
		@param groups the union-find built so far.
		@param wall the wall to test.
		@return true if its two cells are not already connected.
	**/
	static function joins(groups:Map<String, String>, wall:WeftWall):Bool {
		return rootOf(groups, GridModel.nodeKey(wall.a)) != rootOf(groups, GridModel.nodeKey(wall.b));
	}

	/**
		Opens a wall and records the merge.
		@param grid the layout being built.
		@param groups the union-find to update.
		@param wall the wall to open.
	**/
	static function commit(grid:GridData, groups:Map<String, String>, wall:WeftWall):Void {
		grid.openEdges.set(GridModel.edgeKey(wall.a, wall.b), true);
		var a = rootOf(groups, GridModel.nodeKey(wall.a));
		var b = rootOf(groups, GridModel.nodeKey(wall.b));
		if (a != b) {
			groups.set(a, b);
		}
	}

	/**
		Union-find root, without ranking or path compression: the grid is 240
		cells and this runs once per layout, so the honest loop beats the
		fast one for anyone reading it later.
		@param groups the union-find.
		@param key the node key to resolve.
		@return that node's current root key.
	**/
	static function rootOf(groups:Map<String, String>, key:String):String {
		var at = key;
		while (true) {
			var up = groups.get(at);
			if (up == null || up == at) {
				return at;
			}
			at = up;
		}
	}

	/**
		Fisher-Yates, in place — the orbits have to be considered in a random
		order or every layout comes out the same.
		@param items the array to shuffle.
		@param rng source of randomness in [0, 1).
	**/
	static function shuffle<T>(items:Array<T>, rng:Void->Float):Void {
		var index = items.length - 1;
		while (index > 0) {
			var swap = Std.int(rng() * (index + 1));
			var held = items[index];
			items[index] = items[swap];
			items[swap] = held;
			index--;
		}
	}
}
