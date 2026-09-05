package biomes.weft;

import biomes.common.grid.GridModel;
import biomes.common.grid.GridModel.GridData;
import biomes.common.grid.GridModel.GridNode;
import biomes.maze.MazeGenerator;
import utest.Assert;
import utest.Test;

/**
	Covers the pairing itself — the one authored thing in this space — and
	the invariant it exists to hold.

	None of it is visible. A pairing that quietly failed to be an
	involution would still toggle walls and still look like a working
	mechanic; it would simply mean the wall you opened at your antipode is
	not the one that answers to the wall you closed, and the player's
	model of the space would be wrong with nothing to correct it. The odd-
	column rows are the concrete case, and `testTheUnpairableRowsAreExactly
	TheOddColumnOnes` pins which rows those are rather than leaving it as
	an argument in a doc comment.
**/
class WeftModelTest extends Test {
	function key(node:GridNode):String {
		return GridModel.nodeKey(node);
	}

	/** Same seeded generator as `freshMaze`, but before `enforceOpposite` — for tests that need to compare the enforced layout against its own raw origin. **/
	function rawMaze():GridData {
		var seed = 12345;
		return MazeGenerator.generate(() -> {
			seed = (seed * 1103515245 + 12345) & 0x7FFFFFFF;
			return seed / 2147483648.0;
		});
	}

	function freshMaze():GridData {
		var maze = rawMaze();
		WeftModel.enforceOpposite(maze);
		return maze;
	}

	/** A node's own hemisphere, by `GridModel.centerOf`'s theta — the same coordinate `WeftModel`'s own (package-private) `isNorthern` reads. **/
	function isNorthOf(node:GridNode):Bool {
		return GridModel.centerOf(node).theta < Math.PI / 2;
	}

	/** The poles answer to each other, which is the one pairing that needs no column arithmetic at all. **/
	function testThePolesArePaired():Void {
		Assert.equals(key(PoleNode(South)), key(WeftModel.antipodeOf(PoleNode(North))));
		Assert.equals(key(PoleNode(North)), key(WeftModel.antipodeOf(PoleNode(South))));
		Assert.isTrue(WeftModel.isPairable(PoleNode(North)));
		Assert.isTrue(WeftModel.isPairable(PoleNode(South)));
	}

	/** Where the pairing applies at all it is a genuine fixed-point-free involution: apply it twice and you are back, never where you started after one. **/
	function testPairingIsAnInvolutionWhereverItApplies():Void {
		var pairable = 0;
		for (node in GridModel.allNodes()) {
			if (!WeftModel.isPairable(node)) {
				continue;
			}
			pairable++;
			var partner = WeftModel.antipodeOf(node);
			Assert.notEquals(key(node), key(partner), 'node ${key(node)} is its own antipode');
			Assert.equals(key(node), key(WeftModel.antipodeOf(partner)), 'node ${key(node)} did not survive a round trip');
		}
		Assert.isTrue(pairable > 0, "nothing is pairable at all");
	}

	/**
		**Exactly the odd-column rows are unpairable**, and for the reason
		`WeftModel`'s doc gives: the antipodal map shifts a row by half its
		columns, which on an odd count lands on a cell boundary, and no
		fixed-point-free pairing of an odd number of cells exists anyway.
		Pinned here so that a future change to `GridModel.colsForRow` shows
		up as a failing test rather than as a silently larger dead zone.
	**/
	function testTheUnpairableRowsAreExactlyTheOddColumnOnes():Void {
		for (node in GridModel.allNodes()) {
			switch node {
				case PoleNode(_):
					Assert.isTrue(WeftModel.isPairable(node), "a pole should always pair");
				case RingNode(row, _):
					var oddRow = GridModel.colsForRow(row) % 2 != 0;
					Assert.equals(!oddRow, WeftModel.isPairable(node), 'row $row has ${GridModel.colsForRow(row)} columns; pairability disagrees');
			}
		}
	}

	/** A wall's partner is a real wall — the antipodal cells are genuinely adjacent, so the rule always names something that exists. **/
	function testEveryPartnerIsItselfARealWall():Void {
		var checked = 0;
		for (node in GridModel.allNodes()) {
			for (neighbor in GridModel.neighborsOf(node)) {
				var partner = WeftModel.partnerOf(node, neighbor);
				if (partner == null) {
					continue;
				}
				checked++;
				var adjacent = false;
				for (candidate in GridModel.neighborsOf(partner.a)) {
					if (key(candidate) == key(partner.b)) {
						adjacent = true;
					}
				}
				Assert.isTrue(adjacent, 'the partner of ${key(node)}-${key(neighbor)} is not an adjacent pair');
			}
		}
		Assert.isTrue(checked > 0, "no wall has a partner");
	}

	/** Pairing is symmetric: if this wall answers to that one, that one answers back. **/
	function testPartnershipIsMutual():Void {
		for (node in GridModel.allNodes()) {
			for (neighbor in GridModel.neighborsOf(node)) {
				var partner = WeftModel.partnerOf(node, neighbor);
				if (partner == null) {
					continue;
				}
				var back = WeftModel.partnerOf(partner.a, partner.b);
				Assert.notNull(back, 'the partner of ${key(node)}-${key(neighbor)} has no partner of its own');
				Assert.equals(GridModel.edgeKey(node, neighbor), GridModel.edgeKey(back.a, back.b), "partnership is not mutual");
			}
		}
	}

	/**
		**The invariant**: after `enforceOpposite`, no paired wall is ever
		in the same state as its partner. This is the rule the player will
		reason with, and it is the thing that would break silently.
	**/
	function testEnforceMakesEveryPairOpposite():Void {
		var maze = freshMaze();

		for (node in GridModel.allNodes()) {
			for (neighbor in GridModel.neighborsOf(node)) {
				var partner = WeftModel.partnerOf(node, neighbor);
				if (partner == null) {
					continue;
				}
				Assert.notEquals(GridModel.isOpen(maze, node, neighbor), GridModel.isOpen(maze, partner.a, partner.b),
					'${key(node)}-${key(neighbor)} matches its partner instead of opposing it');
			}
		}
	}

	/**
		**The fix for "no symmetry in the maze"**: the northern hemisphere is
		left exactly as generated, and the southern hemisphere is a legible
		mirror of it — not two independently-random halves reconciled by an
		arbitrary edge-key comparison, which is what `enforceOpposite` did
		before and produced no relationship a player standing anywhere could
		actually perceive.

		Checked directly against the *raw* pre-`enforceOpposite` layout: a
		northern paired edge's state must be untouched by enforcement, and a
		southern paired edge's state must be the exact opposite of its
		(also-untouched) northern partner's raw state. Equator-seam edges
		(average theta within `WeftModel.EQUATOR_EPSILON` of π/2, the one
		row boundary that pairs with itself in this sense) are skipped here
		for the same reason `enforceOpposite` itself falls back to a
		different rule there — see that function's own doc.
	**/
	function testTheNorthernHemisphereGeneratesAndTheSouthernMirrorsIt():Void {
		var raw = rawMaze();
		var enforced = MazeGenerator.deserialize(MazeGenerator.serialize(raw)); // an independent copy to enforce
		WeftModel.enforceOpposite(enforced);

		var checkedNorth = 0;
		var checkedSouth = 0;
		for (node in GridModel.allNodes()) {
			for (neighbor in GridModel.neighborsOf(node)) {
				var partner = WeftModel.partnerOf(node, neighbor);
				if (partner == null) {
					continue;
				}
				var midpoint = (GridModel.centerOf(node).theta + GridModel.centerOf(neighbor).theta) / 2;
				if (Math.abs(midpoint - Math.PI / 2) < 1e-6) {
					continue; // the equator seam — not this test's claim, see WeftModel.enforceOpposite
				}

				if (midpoint < Math.PI / 2) {
					checkedNorth++;
					Assert.equals(GridModel.isOpen(raw, node, neighbor), GridModel.isOpen(enforced, node, neighbor),
						'a northern edge ${key(node)}-${key(neighbor)} was changed by enforcement');
				} else {
					checkedSouth++;
					Assert.equals(!GridModel.isOpen(raw, partner.a, partner.b), GridModel.isOpen(enforced, node, neighbor),
						'a southern edge ${key(node)}-${key(neighbor)} is not the mirror of its northern partner\'s raw state');
				}
			}
		}
		Assert.isTrue(checkedNorth > 0 && checkedSouth > 0, "no northern/southern paired edges were found to check");
	}

	/** **Closing a wall opens its partner**, which is the verb the whole space is built on. **/
	function testTogglingAWallFlipsItsPartnerTheOtherWay():Void {
		var maze = freshMaze();

		var acted = 0;
		for (node in GridModel.allNodes()) {
			for (neighbor in GridModel.neighborsOf(node)) {
				var partner = WeftModel.partnerOf(node, neighbor);
				if (partner == null || acted >= 40) {
					continue;
				}
				acted++;

				var wasOpen = GridModel.isOpen(maze, node, neighbor);
				Assert.isTrue(WeftModel.toggle(maze, node, neighbor), "a paired wall refused to toggle");

				Assert.equals(!wasOpen, GridModel.isOpen(maze, node, neighbor), "the wall itself did not flip");
				Assert.equals(wasOpen, GridModel.isOpen(maze, partner.a, partner.b), "the partner did not take the opposite state");
			}
		}
		Assert.isTrue(acted > 0, "no paired wall was found to toggle");
	}

	/** Toggling twice returns the whole sphere to where it started, so the player can always undo. **/
	function testTogglingTwiceRestoresBothWalls():Void {
		var maze = freshMaze();

		for (node in GridModel.allNodes()) {
			for (neighbor in GridModel.neighborsOf(node)) {
				var partner = WeftModel.partnerOf(node, neighbor);
				if (partner == null) {
					continue;
				}
				var before = GridModel.isOpen(maze, node, neighbor);
				var partnerBefore = GridModel.isOpen(maze, partner.a, partner.b);

				WeftModel.toggle(maze, node, neighbor);
				WeftModel.toggle(maze, node, neighbor);

				Assert.equals(before, GridModel.isOpen(maze, node, neighbor), "the wall did not come back");
				Assert.equals(partnerBefore, GridModel.isOpen(maze, partner.a, partner.b), "the partner did not come back");
				return;
			}
		}
		Assert.fail("no paired wall was found");
	}

	/**
		**The gate exists and is genuinely solvable.** A found candidate's
		vault has exactly one open neighbor (west or east), that neighbor is
		itself pairable, and the pair has a real partner elsewhere on the
		sphere — everything `WeftBiome.reload` needs to seal the vault shut
		and know where its far mirror is.
	**/
	function testFindKeystoneCandidateFindsAGenuineLeafWithAPartner():Void {
		var maze = freshMaze();
		var candidate = WeftModel.findKeystoneCandidate(maze);
		Assert.notNull(candidate, "no keystone candidate found in a freshly generated maze");
		if (candidate == null) {
			return;
		}

		var openNeighbors = [
			for (neighbor in GridModel.neighborsOf(candidate.vault))
				if (GridModel.isOpen(maze, candidate.vault, neighbor)) neighbor
		];
		Assert.equals(1, openNeighbors.length, "the candidate vault is not a leaf");
		Assert.equals(key(candidate.approach), key(openNeighbors[0]), "the candidate's approach is not its one open neighbor");

		var cols = GridModel.colsForRow(candidate.vaultRow);
		var west = RingNode(candidate.vaultRow, (candidate.vaultCol - 1 + cols) % cols);
		var east = RingNode(candidate.vaultRow, (candidate.vaultCol + 1) % cols);
		var expectedApproach = candidate.lockIsWest ? west : east;
		Assert.equals(key(expectedApproach), key(candidate.approach), "lockIsWest disagrees with the approach node it names");

		Assert.notNull(WeftModel.partnerOf(candidate.vault, candidate.approach), "the candidate's own lock edge has no partner");
	}

	/** The candidate always sits in the northern ("generating") hemisphere — `enforceOpposite` never touches a northern edge, so sealing the vault by toggling it (which `WeftBiome.reload` does) has a predictable, single effect: the vault's own side closes, and the southern partner opens as its mirror, not the other way around. **/
	function testFindKeystoneCandidateIsAlwaysNorthern():Void {
		var candidate = WeftModel.findKeystoneCandidate(freshMaze());
		Assert.notNull(candidate);
		if (candidate == null) {
			return;
		}
		Assert.isTrue(isNorthOf(candidate.vault), 'candidate vault ${key(candidate.vault)} is not northern');
	}

	/** `ringPositionOf` recovers the exact row/col a `RingNode` was built from — the shape `MazeExitWall.wallAt` needs, from the `GridNode` values `partnerOf` hands back. **/
	function testRingPositionOfRecoversRowAndCol():Void {
		var pos = WeftModel.ringPositionOf(RingNode(4, 7));
		Assert.equals(4, pos.row);
		Assert.equals(7, pos.col);
	}

	/**
		**Several gates, never reusing a wall.** `sealKeystoneGates` seals
		each candidate it finds before searching for the next, which this
		test's own claim depends on: every gate's lock edge is distinct from
		every other gate's lock *and* partner edges, and likewise for
		partners — nothing doubles up as two different gates' own roles.
	**/
	function testSealKeystoneGatesNeverReusesAWall():Void {
		var maze = freshMaze();
		var gates = WeftModel.sealKeystoneGates(maze, 5);
		Assert.isTrue(gates.length > 1, "fewer than two gates were placed — not enough to test for reuse");

		var seenEdges = new Map<String, Bool>();
		for (candidate in gates) {
			var partner = WeftModel.partnerOf(candidate.vault, candidate.approach);
			Assert.notNull(partner, "a sealed gate's own lock has no partner");
			if (partner == null) {
				continue;
			}
			var lockKey = GridModel.edgeKey(candidate.vault, candidate.approach);
			var partnerKey = GridModel.edgeKey(partner.a, partner.b);
			Assert.isFalse(seenEdges.exists(lockKey), 'lock edge $lockKey was sealed by more than one gate');
			Assert.isFalse(seenEdges.exists(partnerKey), 'partner edge $partnerKey was sealed by more than one gate');
			seenEdges.set(lockKey, true);
			seenEdges.set(partnerKey, true);
		}
	}

	/** Every gate `sealKeystoneGates` places is actually sealed: the vault's own lock edge reads closed once the function returns (its partner having taken the opposite, open state, per the pairing invariant). **/
	function testSealKeystoneGatesActuallySealsEveryLock():Void {
		var maze = freshMaze();
		var gates = WeftModel.sealKeystoneGates(maze, 5);
		Assert.isTrue(gates.length > 0, "no gates were placed at all");

		for (candidate in gates) {
			Assert.isFalse(GridModel.isOpen(maze, candidate.vault, candidate.approach), 'gate at ${key(candidate.vault)} was not sealed shut');
		}
	}

	/** `gateOf` reports the same lock and a real partner for a candidate `sealKeystoneGates` already placed — the shape `WeftMesh`'s highlights and `WeftBiome.isLocked` both read. **/
	function testGateOfReportsTheLockAndItsRealPartner():Void {
		var maze = freshMaze();
		var gates = WeftModel.sealKeystoneGates(maze, 1);
		Assert.equals(1, gates.length);
		var candidate = gates[0];

		var gate = WeftModel.gateOf(candidate);
		Assert.notNull(gate);
		if (gate == null) {
			return;
		}
		Assert.equals(GridModel.edgeKey(candidate.vault, candidate.approach), GridModel.edgeKey(gate.lock.a, gate.lock.b));
		var partner = WeftModel.partnerOf(candidate.vault, candidate.approach);
		Assert.notNull(partner);
		if (partner == null) {
			return;
		}
		Assert.equals(GridModel.edgeKey(partner.a, partner.b), GridModel.edgeKey(gate.partner.a, gate.partner.b));
	}

	/** `edgeSidesOf` reports each endpoint's own row/col unchanged, and exactly one of the two sides as "west" (from that side's own perspective, `b` sits to its west) — never both, never neither, for a genuine west/east edge. **/
	function testEdgeSidesOfDisagreesOnWestExactlyOnce():Void {
		var sides = WeftModel.edgeSidesOf(RingNode(4, 10), RingNode(4, 11));
		Assert.equals(4, sides.aSide.row);
		Assert.equals(10, sides.aSide.col);
		Assert.equals(4, sides.bSide.row);
		Assert.equals(11, sides.bSide.col);
		Assert.notEquals(sides.aSide.west, sides.bSide.west);
	}

	/** An unpaired wall is scenery: the rule declines to move it rather than moving it alone and breaking the invariant. **/
	function testAnUnpairedWallDoesNotToggle():Void {
		var maze = freshMaze();

		for (node in GridModel.allNodes()) {
			for (neighbor in GridModel.neighborsOf(node)) {
				if (WeftModel.isPaired(node, neighbor)) {
					continue;
				}
				var before = GridModel.isOpen(maze, node, neighbor);
				Assert.isFalse(WeftModel.toggle(maze, node, neighbor), "an unpaired wall reported a change");
				Assert.equals(before, GridModel.isOpen(maze, node, neighbor), "an unpaired wall moved anyway");
				return;
			}
		}
		Assert.pass(); // a grid with no unpaired walls at all would be fine too
	}

	// --- Hinges and the two objectives (2026-09-06 redesign).

	function testAWallAndItsAntipodalPartnerAgreeAboutBeingHinged():Void {
		// They must: toggling either moves both, so a hinge whose partner
		// was fixed would let the player change a wall the rule says is not
		// theirs to move.
		var checked = 0;
		for (node in GridModel.allNodes()) {
			for (neighbor in GridModel.neighborsOf(node)) {
				var partner = WeftModel.partnerOf(node, neighbor);
				if (partner == null) {
					continue;
				}
				checked++;
				Assert.equals(WeftModel.isHinged(node, neighbor), WeftModel.isHinged(partner.a, partner.b),
					'a wall and its partner disagree about being hinged');
			}
		}
		Assert.isTrue(checked > 0, "no paired walls were checked at all");
	}

	function testHingesAreScarceButNotAbsent():Void {
		// The whole point of the redesign: when every wall was a door the
		// maze had no structure. Bounds rather than an exact figure, since
		// the share is a tuning value.
		var paired = 0;
		var hinged = 0;
		for (node in GridModel.allNodes()) {
			for (neighbor in GridModel.neighborsOf(node)) {
				if (WeftModel.partnerOf(node, neighbor) == null) {
					continue;
				}
				paired++;
				if (WeftModel.isHinged(node, neighbor)) {
					hinged++;
				}
			}
		}
		var share = hinged / paired;
		Assert.isTrue(share > 0.05, 'only $share of paired walls are hinged — the space would be unsolvable');
		Assert.isTrue(share < 0.45, 'as many as $share of paired walls are hinged — every wall is a door again');
	}

	function testAnUnpairedWallIsNeverHinged():Void {
		// The pole rows have no partner, so they were never the player's to
		// move; hinging one would break the opposite-state invariant.
		for (node in GridModel.allNodes()) {
			for (neighbor in GridModel.neighborsOf(node)) {
				if (WeftModel.partnerOf(node, neighbor) == null) {
					Assert.isFalse(WeftModel.isHinged(node, neighbor));
				}
			}
		}
	}

	function testTheExitIsTheBeaconsOwnAntipode():Void {
		// The space is one puzzle only because of this: the route carved to
		// reach the beacon is the route closed on the way out.
		var beacon = WeftModel.beaconNode();
		var exit = WeftModel.exitNode();

		Assert.equals(GridModel.nodeKey(WeftModel.antipodeOf(beacon)), GridModel.nodeKey(exit));
		Assert.isFalse(GridModel.nodeKey(beacon) == GridModel.nodeKey(exit), "the beacon and the exit are the same place");
	}

	function testTheBeaconAndExitSitInOppositeHemispheres():Void {
		var beacon = GridModel.centerOf(WeftModel.beaconNode());
		var exit = GridModel.centerOf(WeftModel.exitNode());
		var half = Math.PI / 2;

		Assert.isTrue((beacon.theta < half) != (exit.theta < half), 'beacon theta ${beacon.theta} and exit theta ${exit.theta} are on the same side');
	}
}
