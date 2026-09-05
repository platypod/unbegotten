package biomes.weft;

import biomes.common.grid.GridModel;
import biomes.common.grid.GridModel.GridData;
import biomes.common.grid.GridModel.GridNode;

/**
	The Weft's one authored idea: **every wall answers to the wall at its
	antipode, and the two are always in opposite states.**

	**No manifold trick.** The sphere is the same sphere the Fold walks —
	nothing is glued, there is exactly one of the player, and every
	location is where you would expect it to be. What is added is a *rule
	laid over* the geometry, which is precisely what
	`docs/game/world.md` says the space is
	for: the correspondence is authored, has no geometric necessity behind
	it, and is therefore the first evidence in the game that *someone
	decided these two things would answer to each other*.

	That entry also carries a correction worth not undoing. This space was
	once "the projective plane, walkable" — a real quotient — and that was
	abandoned because a quotient has only *one* wall per identified edge,
	so there is nothing for it to be opposite *to*. Everything here keeps
	two distinct walls at two distinct places.

	**Where the rule cannot apply, and why that is geometry rather than
	laziness.** `GridModel`'s rows carry different column counts by
	latitude, and the two rows nearest each pole have an **odd** count
	(`COLS / 4` = 7). The antipodal map shifts a row by half its columns,
	which on an odd row lands on a cell *boundary* rather than a cell — so
	the map is not an involution there, and no fixed-point-free pairing of
	an odd number of cells exists at all. Those rows are simply unpaired.
	The design's own "Exists" note anticipates a pole edge case; this is
	it, in the exact place it predicted.
**/
class WeftModel {
	/**
		The node diametrically opposite this one — `theta → pi - theta`,
		`phi → phi + pi`, the transform the design names.

		Poles swap. A ring node is resolved through `GridModel.nodeAt`
		rather than by arithmetic on `(row, col)`, so it stays correct
		whatever `colsForRow` does — including the odd rows where the
		result will not be involutive, which `isPairable` is what catches.
		@param node the node to reflect.
		@return the node at its antipode.
	**/
	public static function antipodeOf(node:GridNode):GridNode {
		return switch node {
			case PoleNode(North): PoleNode(South);
			case PoleNode(South): PoleNode(North);
			case RingNode(_, _):
				var centre = GridModel.centerOf(node);
				GridModel.nodeAt(Math.PI - centre.theta, (centre.phi + Math.PI) % (2 * Math.PI));
		}
	}

	/**
		Whether a node's antipode is a genuine partner: distinct from it,
		and mapping back. Checked rather than assumed — see the class doc
		for the odd-column rows where it fails.
		@param node the node to test.
		@return true if the pairing is a fixed-point-free involution here.
	**/
	public static function isPairable(node:GridNode):Bool {
		var partner = antipodeOf(node);
		var back = antipodeOf(partner);
		return !sameNode(node, partner) && sameNode(node, back);
	}

	/**
		The wall paired with the one between `a` and `b`, or null if this
		wall has no partner — either because an endpoint sits on an
		unpairable row, or because the antipodal pair is not adjacent and
		so names no wall at all.
		@param a one end of the wall's own edge.
		@param b the other end.
		@return the partner edge's endpoints, or null.
	**/
	public static function partnerOf(a:GridNode, b:GridNode):Null<{a:GridNode, b:GridNode}> {
		if (!isPairable(a) || !isPairable(b)) {
			return null;
		}
		var pa = antipodeOf(a);
		var pb = antipodeOf(b);
		if (sameNode(pa, a) || sameNode(pb, b)) {
			return null;
		}
		if (GridModel.edgeKey(pa, pb) == GridModel.edgeKey(a, b)) {
			return null; // a wall cannot be its own opposite
		}
		for (neighbor in GridModel.neighborsOf(pa)) {
			if (sameNode(neighbor, pb)) {
				return {a: pa, b: pb};
			}
		}
		return null;
	}

	/**
		Half the grid whose theta is short of the equator — `centerOf`'s own
		coordinate, so it agrees with everything else that reads a node's
		position, and small enough that a row-boundary edge spanning rows 6
		and 7 (the only rows whose average theta lands exactly on π/2) needs
		its own tie-break rather than a false read from float error.
	**/
	static inline final EQUATOR_EPSILON:Float = 1e-6;

	/**
		Which hemisphere an edge belongs to, by the average theta of its two
		endpoints — `enforceOpposite`'s own generating/mirrored split. A
		pole counts as theta 0 or π, same as `GridModel.centerOf` already
		gives it.

		**Well-defined for every pairable edge but the true equator seam.**
		`antipodeOf` maps row `r` to row `13 - r`, so a same-row edge or a
		cross-row edge between rows on the same side of the equator always
		pairs with an edge entirely on the other side — except the one
		row-boundary that sits *on* the equator (rows 6 and 7, whose average
		theta is exactly π/2), which pairs with another edge on that same
		seam. `null` there rather than an arbitrary true/false, so the
		caller can fall back to a different, still-deterministic rule
		instead of silently mislabelling a hemisphere that doesn't apply.
		@param a one end of the edge.
		@param b the other end.
		@return true if north, false if south, null if the edge is the equator seam itself.
	**/
	static function isNorthern(a:GridNode, b:GridNode):Null<Bool> {
		var thetaA = GridModel.centerOf(a).theta;
		var thetaB = GridModel.centerOf(b).theta;
		var midpoint = (thetaA + thetaB) / 2;
		if (Math.abs(midpoint - Math.PI / 2) < EQUATOR_EPSILON) {
			return null;
		}
		return midpoint < Math.PI / 2;
	}

	/**
		Forces the invariant across the whole sphere: **a paired wall and
		its partner are never in the same state.**

		**The northern hemisphere generates; the southern hemisphere is its
		mirror.** Within each antipodal pair, the edge in the north (per
		`isNorthern`) is left exactly as the base carve made it; its
		southern partner is forced to the opposite. `antipodeOf` maps row
		`r` to row `13 - r`, so this split is total — a paired edge is
		always north-with-south, never north-with-north — except the single
		row boundary sitting exactly on the equator, which pairs with
		itself in that sense and falls back to comparing edge keys, same as
		this function used to do everywhere.

		**An earlier version of this split was by edge key alone**, scattered
		arbitrarily across the whole sphere rather than by hemisphere — technically
		satisfying the invariant, but with no relationship a player standing
		anywhere could actually see: the "authoritative" edge near them was
		as likely to be the one forced from its partner as the one setting
		it, so the far side read as unrelated noise rather than a legible
		negative. That was flagged directly ("no symmetry in the maze").
		The hemisphere split is what the design always described — *the far
		side of the world is the photographic negative of the near side* —
		made into the actual generating rule instead of an emergent
		description of a scattered one.

		Pleasantly, both sides still read as mazes. A spanning-tree carve
		opens roughly half a grid's edges, so its complement is also
		roughly half — the negative hemisphere is not the open plain one
		might expect.

		**Connectivity is not preserved, and that is left standing.** The
		carve guarantees every cell is reachable; complementing half the
		edges destroys that guarantee, so the negative side can hold loops
		and sealed pockets. It is survivable rather than a bug, because
		this space's whole verb is opening walls: a player enclosed
		anywhere paired can always toggle their way out. A Weft that wants
		an authored *puzzle* will need its own generator — carve,
		complement, then repair — rather than the Fold's.
		@param grid the layout to constrain, modified in place.
	**/
	public static function enforceOpposite(grid:GridData):Void {
		for (node in GridModel.allNodes()) {
			for (neighbor in GridModel.neighborsOf(node)) {
				var partner = partnerOf(node, neighbor);
				if (partner == null) {
					continue;
				}
				var northern = isNorthern(node, neighbor);
				var isSouth = northern != null ? !northern : edgeKeyIsHigher(node, neighbor, partner);
				if (isSouth) {
					continue; // the antipodal partner is the generating edge; this one is set from it, on that pass
				}
				setOpen(grid, partner.a, partner.b, !GridModel.isOpen(grid, node, neighbor));
			}
		}
	}

	/** The equator-seam tie-break `isNorthern` cannot make — same rule this function used everywhere before the hemisphere split. **/
	static function edgeKeyIsHigher(a:GridNode, b:GridNode, partner:{a:GridNode, b:GridNode}):Bool {
		return GridModel.edgeKey(a, b) >= GridModel.edgeKey(partner.a, partner.b);
	}

	/**
		Fraction of paired walls that are **hinged** — the only ones the
		player may open.

		**This is the fix for a space that had no difficulty.** Every
		pairable wall used to be toggleable, so every wall was a door on
		demand and the maze had walls but no structure: nothing constrained
		a route because any obstacle yielded to a keypress. The keystone
		gates were bolted on to supply the friction the base rule was not
		providing, which is a patch rather than a mechanic.

		With hinges scarce, the fixed walls make a real maze and the hinges
		become the scarce resource the space is actually about. It also
		gives the pairing rule teeth at last: a hinge you spend to get
		through here is a hinge that has *closed* at your antipode, on the
		route you have to walk back along.
	**/
	static inline final HINGE_SHARE:Float = 0.22;

	/**
		The key a wall and its antipodal partner are *both* filed under — the
		lower of the two edge keys — or null if the wall has no partner.

		Everything about hinges is decided on this key rather than on each
		edge's own, so a wall and its partner always agree about being
		hinged. They must: `toggle` moves both, and a hinge whose partner
		was fixed would let the player change a wall the rule forbids.
		@param a one end of the wall.
		@param b the other end.
		@return the pair's canonical key, or null for an unpaired wall.
	**/
	public static function canonicalKeyOf(a:GridNode, b:GridNode):Null<String> {
		var partner = partnerOf(a, b);
		if (partner == null) {
			return null; // unpaired walls were never the player's to move
		}
		var mine = GridModel.edgeKey(a, b);
		var theirs = GridModel.edgeKey(partner.a, partner.b);
		return mine < theirs ? mine : theirs;
	}

	/**
		Whether this wall is one the player may open, per a layout's own
		hinge set.
		@param hinges that layout's hinges, from `hingesFor`.
		@param a one end of the wall.
		@param b the other end.
		@return true if this wall is hinged.
	**/
	public static function isHinged(hinges:Map<String, Bool>, a:GridNode, b:GridNode):Bool {
		var key = canonicalKeyOf(a, b);
		return key != null && hinges.exists(key);
	}

	/**
		Which walls this layout's player may open: `HINGE_SHARE` of the
		paired walls picked by hash, **plus whatever it takes to make every
		waypoint reachable**.

		**The repair is not optional.** `enforceOpposite` has never
		guaranteed connectivity — complementing half a spanning tree's edges
		leaves sealed pockets, and its own doc shrugged that off because
		"a player enclosed anywhere paired can always toggle their way out."
		Making walls mostly fixed took that escape away, and measuring the
		result (30 layouts, `WeftModel`'s own numbers: 4.6 connected
		components, the largest holding 190 of 240 cells) found the beacon
		or the exit stranded in **2 layouts in 30** — an unwinnable level
		about once every fifteen visits.

		So: Dijkstra from the first waypoint over the whole grid, where an
		open or already-hinged wall costs nothing to cross and a fixed
		*pairable* one costs 1 (an unpaired wall can never be opened at all,
		so it stays impassable), then hinge every wall on the cheapest path
		to each remaining waypoint. Cheapest is what keeps the scarcity: the
		repair spends the fewest new hinges that make the level solvable,
		and spends none at all on the layouts that were already fine.

		This is the "carve, complement, then **repair**" that
		`enforceOpposite`'s own doc predicted a Weft with an authored puzzle
		would need.
		@param grid the layout to compute hinges for.
		@param waypoints the places that must be mutually reachable, the first being where the player starts.
		@param locked edge keys the player cannot open directly (a gate's lock, `WeftBiome.isLocked`) — the repair routes around these rather than through them, since a route that depends on one is a route the player cannot simply walk.
		@return the hinge set, keyed by `canonicalKeyOf`.
	**/
	public static function hingesFor(grid:GridData, waypoints:Array<GridNode>, ?locked:Map<String, Bool>):Map<String, Bool> {
		var closedToRepair = locked != null ? locked : new Map<String, Bool>();
		var hinges = new Map<String, Bool>();
		for (node in GridModel.allNodes()) {
			for (neighbor in GridModel.neighborsOf(node)) {
				var key = canonicalKeyOf(node, neighbor);
				if (key != null && hashOf(key) < HINGE_SHARE) {
					hinges.set(key, true);
				}
			}
		}
		if (waypoints.length == 0) {
			return hinges;
		}
		for (index in 1...waypoints.length) {
			repairRoute(grid, hinges, closedToRepair, waypoints[0], waypoints[index]);
		}
		return hinges;
	}

	/**
		Hinges the cheapest chain of fixed walls between two nodes, if any
		is needed — see `hingesFor`.

		Plain O(n²) Dijkstra rather than anything cleverer: the grid is 240
		cells, this runs once per layout, and the shape of the cost function
		(0 for a wall you can already cross, 1 for one you would have to
		hinge) is easier to read stated directly than folded into a
		0-1-BFS deque.
		@param grid the layout being repaired.
		@param hinges the hinge set, added to in place.
		@param locked walls the repair must route around — see `hingesFor`.
		@param from where the player starts.
		@param to the waypoint that must be reachable.
	**/
	static function repairRoute(grid:GridData, hinges:Map<String, Bool>, locked:Map<String, Bool>, from:GridNode, to:GridNode):Void {
		var nodes = GridModel.allNodes();
		var byKey = new Map<String, GridNode>();
		var dist = new Map<String, Float>();
		var previous = new Map<String, GridNode>();
		var settled = new Map<String, Bool>();
		for (node in nodes) {
			byKey.set(GridModel.nodeKey(node), node);
			dist.set(GridModel.nodeKey(node), Math.POSITIVE_INFINITY);
		}
		dist.set(GridModel.nodeKey(from), 0);

		while (true) {
			var nearestKey:Null<String> = null;
			var nearest = Math.POSITIVE_INFINITY;
			for (node in nodes) {
				var key = GridModel.nodeKey(node);
				if (settled.exists(key)) {
					continue;
				}
				var d = dist.get(key);
				if (d != null && d < nearest) {
					nearest = d;
					nearestKey = key;
				}
			}
			if (nearestKey == null) {
				return; // every reachable node settled, and `to` was not among them
			}
			settled.set(nearestKey, true);
			if (nearestKey == GridModel.nodeKey(to)) {
				break;
			}
			var here = byKey.get(nearestKey);
			if (here == null) {
				return;
			}
			for (neighbor in GridModel.neighborsOf(here)) {
				var step = costOf(grid, hinges, locked, here, neighbor);
				if (step == null) {
					continue; // a wall nothing can ever open
				}
				var neighborKey = GridModel.nodeKey(neighbor);
				var known = dist.get(neighborKey);
				if (known != null && nearest + step < known) {
					dist.set(neighborKey, nearest + step);
					previous.set(neighborKey, here);
				}
			}
		}

		var at = to;
		while (GridModel.nodeKey(at) != GridModel.nodeKey(from)) {
			var back = previous.get(GridModel.nodeKey(at));
			if (back == null) {
				return; // unreachable even through every hingeable wall — see `hingesFor`
			}
			var key = canonicalKeyOf(back, at);
			if (key != null) {
				hinges.set(key, true);
			}
			at = back;
		}
	}

	/**
		What crossing this wall costs the repair: nothing if it is already
		open or already hinged, 1 if hinging it would open the way, and null
		if no rule in this space can ever open it.
		@param grid the layout being repaired.
		@param hinges the hinge set so far.
		@param locked walls the repair must route around — see `hingesFor`.
		@param a one end of the wall.
		@param b the other end.
		@return the crossing cost, or null if impassable.
	**/
	static function costOf(grid:GridData, hinges:Map<String, Bool>, locked:Map<String, Bool>, a:GridNode, b:GridNode):Null<Float> {
		if (GridModel.isOpen(grid, a, b)) {
			return 0;
		}
		if (locked.exists(GridModel.edgeKey(a, b))) {
			return null; // a gate's lock: it opens, but not for a player standing next to it
		}
		var key = canonicalKeyOf(a, b);
		if (key == null) {
			return null;
		}
		return hinges.exists(key) ? 0 : 1;
	}

	/**
		The node the beacon stands on — in the northern hemisphere, and the
		first of the space's two objectives.

		**The exit is at its antipode**, which is what makes this space one
		puzzle rather than a maze with a rule attached. The route you carve
		north to reach the beacon is, edge for edge, the route that has
		*closed* in the south — so your way out is the wreckage of your way
		in, and you have to plan the first journey knowing it builds the
		second.
	**/
	public static function beaconNode():GridNode {
		return GridModel.nodeAt(BEACON_THETA, BEACON_PHI);
	}

	/** Where the way out stands: the beacon's own antipode, and therefore in the southern hemisphere. **/
	public static function exitNode():GridNode {
		return antipodeOf(beaconNode());
	}

	/** Polar angle of the beacon. Well north of the equator, so its antipode is well south and the two journeys are genuinely separate. **/
	static inline final BEACON_THETA:Float = 0.72;

	/** Azimuth of the beacon. **/
	static inline final BEACON_PHI:Float = 1.1;

	/** A stable value in `[0, 1)` from an edge key — the same shape of hash the other biomes use, over a string rather than coordinates. **/
	static function hashOf(key:String):Float {
		var h:Int = 0x811C9DC5;
		for (index in 0...key.length) {
			var c:Int = key.charCodeAt(index);
			h = ((h ^ c) * 16777619) & 0x7FFFFFFF;
		}
		h = (h ^ (h >> 15)) & 0x7FFFFFFF;
		return h / 2147483648.0;
	}

	/**
		Flips one wall, and its partner with it — so the invariant survives
		and, from the player's side, **closing a wall here opens the one at
		its antipode**.
		@param grid the layout to change, modified in place.
		@param a one end of the wall to flip.
		@param b the other end.
		@return true if anything changed; false if this wall has no partner and so is not the player's to move.
	**/
	public static function toggle(grid:GridData, a:GridNode, b:GridNode):Bool {
		var partner = partnerOf(a, b);
		if (partner == null) {
			return false;
		}
		var opened = !GridModel.isOpen(grid, a, b);
		setOpen(grid, a, b, opened);
		setOpen(grid, partner.a, partner.b, !opened);
		return true;
	}

	/** Whether a wall obeys the rule at all — what the player may act on, and what the ghost view is worth reading. **/
	public static function isPaired(a:GridNode, b:GridNode):Bool {
		return partnerOf(a, b) != null;
	}

	/**
		Opens or closes one wall.

		**`GridData.openEdges` is a presence set, not a map of booleans**,
		despite being typed `StringMap<Bool>`: `GridModel.isOpen` asks
		`exists`, never `get`, so the stored value is never read and
		closing an edge means *removing* its key. Writing `set(key, false)`
		leaves the edge reading as open — which is exactly what the first
		version of this did, and what `WeftModelTest` caught on its first
		run with "the wall itself did not flip".
	**/
	static function setOpen(grid:GridData, a:GridNode, b:GridNode, open:Bool):Void {
		var key = GridModel.edgeKey(a, b);
		if (open) {
			grid.openEdges.set(key, true);
		} else {
			grid.openEdges.remove(key);
		}
	}

	static function sameNode(a:GridNode, b:GridNode):Bool {
		return GridModel.nodeKey(a) == GridModel.nodeKey(b);
	}

	/** A `RingNode`'s own row/col — for `WeftBiome`'s own beacon placement, which needs `MazeExitWall.wallAt`'s row/col shape from a `GridNode` it only has because `partnerOf` handed it one. Throws on a pole: `findKeystoneCandidate` never returns one, and neither does `partnerOf` starting from one of its candidates (see that function's own doc — the reflection that produces a candidate's partner preserves "same row" exactly). **/
	public static function ringPositionOf(node:GridNode):{row:Int, col:Int} {
		return switch node {
			case RingNode(row, col): {row: row, col: col};
			case PoleNode(_): throw "unreachable: the Weft's own gate is always a west/east ring edge, never a pole";
		}
	}

	/** A ring row's own hemisphere, by row number — equivalent to `isNorthern`'s edge-midpoint reading for any west/east edge (both endpoints share a row), simpler here since `findKeystoneCandidate` never needs the equator-seam tie-break `isNorthern` exists for. **/
	static function isNorthernRow(row:Int):Bool {
		return row < (GridModel.ROWS - 1) / 2;
	}

	/**
		Finds a spot to seal into one of **the Weft's authored gates** —
		asked directly ("I'd like it if the user had to alternate between
		direct view and antipodal view to figure out tricks and find the
		way"), after the space shipped with the pairing rule but no puzzle
		built on top of it (see `docs/game/world.md`'s own "not built yet"
		note). See `sealKeystoneGates` for placing more than one.

		A single leaf cell (exactly one open neighbor — `GridModel`'s
		spanning-tree carve guarantees plenty of these) in the northern
		("generating") hemisphere, whose one open side is specifically west
		or east. North/south row-boundary edges can split into several
		pieces at a doubling boundary (`GridMesh`'s own
		`addRowBoundaryPieces`), which finding a vault's own wall (and its
		exit-painting wall, and its two beacon markers) has no reason to
		handle when west/east edges are always exactly one piece and every
		candidate row has plenty of them.

		**Deterministic, not random** — the first match found in
		`GridModel.allNodes`' own stable row-major order, same reasoning as
		`biomes.maze.MazeExitWall.find`'s own "first closed edge" scan: a
		saved/restored maze (`WeftBiome.restore`) picks the same vault every
		time, with nothing extra to serialize.
		@param grid the layout to search — already `enforceOpposite`'d.
		@return the first candidate found, or null if this particular maze happens to have none (both the vault and its one neighbor need to survive `isPairable`, so a sufficiently unlucky layout could come up empty — `WeftBiome` falls back to no gate at all rather than force one).
	**/
	public static function findKeystoneCandidate(grid:GridData):Null<KeystoneCandidate> {
		for (node in GridModel.allNodes()) {
			switch node {
				case PoleNode(_):
					// no plain "one open side" reading at a merged pole
				case RingNode(row, col):
					if (!isNorthernRow(row) || !isPairable(node)) {
						continue;
					}
					var cols = GridModel.colsForRow(row);
					var west = RingNode(row, (col - 1 + cols) % cols);
					var east = RingNode(row, (col + 1) % cols);
					var openNeighbors = [
						for (neighbor in GridModel.neighborsOf(node))
							if (GridModel.isOpen(grid, node, neighbor)) neighbor
					];
					if (openNeighbors.length != 1) {
						continue; // not a leaf
					}
					var only = openNeighbors[0];
					var isWest = sameNode(only, west);
					if (!isWest && !sameNode(only, east)) {
						continue; // the one open side is north/south, not this function's concern
					}
					if (!isPairable(only) || partnerOf(node, only) == null) {
						continue;
					}
					return {
						vault: node,
						approach: only,
						vaultRow: row,
						vaultCol: col,
						lockIsWest: isWest
					};
			}
		}
		return null;
	}

	/**
		Finds and seals up to `maxGates` keystone candidates in one pass —
		asked directly ("let's add a visual indication of which walls are
		gates", following "generalize to multiple gates"), after a single
		hand-picked gate proved the mechanic reads.

		Calls `findKeystoneCandidate` repeatedly against `grid`, sealing
		each one (`toggle`) the moment it's found, before searching again —
		not "find several, then seal them all" — which is what keeps two
		gates from ever reusing the same wall: a cell a gate just sealed can
		never re-qualify as a *later* gate's own leaf (its own open-neighbor
		count only ever drops from sealing, never rises), and the antipodal
		map is a bijection on pairable nodes, so two distinct northern
		vaults can never land on the same southern partner either. A cell
		whose degree *drops to exactly one* as a side effect of an earlier
		seal can legitimately become a new leaf itself — an emergent chain
		this function doesn't need to plan for, only allow, since each pass
		re-reads the grid's current state rather than the original one.
		@param grid the layout to search and seal, modified in place.
		@param maxGates the most gates to place — the search stops early if the maze runs out of valid candidates first.
		@return every gate actually placed, in the order found; possibly empty (`WeftBiome` falls back to no gate at all rather than force one).
	**/
	public static function sealKeystoneGates(grid:GridData, maxGates:Int):Array<KeystoneCandidate> {
		var gates:Array<KeystoneCandidate> = [];
		while (gates.length < maxGates) {
			var candidate = findKeystoneCandidate(grid);
			if (candidate == null) {
				break;
			}
			toggle(grid, candidate.vault, candidate.approach);
			gates.push(candidate);
		}
		return gates;
	}

	/**
		A candidate's own two edges, once accepted, in the shape
		`WeftMesh`'s gate highlights and `WeftBiome.isLocked` both need: the
		lock itself (`candidate.vault`-`candidate.approach`) paired with its
		actual antipodal partner. A thin wrapper around `partnerOf` — kept
		here rather than inlined at each call site so there is exactly one
		place that has to agree with `findKeystoneCandidate`'s own promise
		that a returned candidate always has a real partner.
		@param candidate a candidate already accepted (typically one of `sealKeystoneGates`'s own return values).
		@return the gate's two edges, or null only if `partnerOf` disagrees with the check that produced this candidate in the first place — unreachable in practice.
	**/
	public static function gateOf(candidate:KeystoneCandidate):Null<WeftGate> {
		var partner = partnerOf(candidate.vault, candidate.approach);
		if (partner == null) {
			return null;
		}
		return {lock: {a: candidate.vault, b: candidate.approach}, partner: partner};
	}

	/**
		Which row/col/west-or-east side each of a known west/east edge's two
		endpoints is, from that endpoint's *own* perspective — the shape
		`GridMesh.buildSingleWallPiecePrim`/`MazeExitWall.wallAt` need,
		derived once here rather than at every call site
		(`WeftBiome`'s beacon placement, `WeftMesh`'s gate-wall highlights).
		Only ever called on an edge already known to be west/east —
		`findKeystoneCandidate`'s own lock, or its partner, which the same
		function's doc argues is always west/east too (a same-row edge's
		antipodal reflection is itself always same-row).
		@param a one endpoint.
		@param b the other endpoint.
		@return each endpoint's own row/col/west-flag.
	**/
	public static function edgeSidesOf(a:GridNode, b:GridNode):{aSide:EdgeSide, bSide:EdgeSide} {
		var posA = ringPositionOf(a);
		var posB = ringPositionOf(b);
		var cols = GridModel.colsForRow(posA.row);
		var aWest = (posA.col - 1 + cols) % cols == posB.col;
		return {
			aSide: {row: posA.row, col: posA.col, west: aWest},
			bSide: {row: posB.row, col: posB.col, west: !aWest}
		};
	}
}

/**
	One candidate spot for `WeftModel.findKeystoneCandidate` to seal into
	one of the Weft's authored gates: a leaf cell (`vault`, exactly one
	open neighbor) whose single entrance (`approach`, via its west or east
	side — `lockIsWest` says which) is itself pairable, so gating it
	behind a distant antipodal partner is a real, solvable lock rather
	than an accident of the odd-row dead zone `WeftModel.isPairable`
	already excludes.
**/
typedef KeystoneCandidate = {
	vault:GridNode,
	approach:GridNode,
	vaultRow:Int,
	vaultCol:Int,
	lockIsWest:Bool
}

/** See `WeftModel.edgeSidesOf`'s own doc. **/
typedef EdgeSide = {row:Int, col:Int, west:Bool}

/** One sealed gate: the lock edge itself, and the antipodal partner that actually answers to it — see `WeftModel.gateOf`'s own doc. **/
typedef WeftGate = {lock:{a:GridNode, b:GridNode}, partner:{a:GridNode, b:GridNode}}
