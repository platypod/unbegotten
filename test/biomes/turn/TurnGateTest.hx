package biomes.turn;

import utest.Assert;
import utest.Test;

/**
	Covers the chirality gate — the Turn's own mechanism, and the first
	thing in this space that reads the player's handedness rather than
	displaying it.

	All of it is invisible in a screenshot and none of it is felt until
	the player has walked a whole lap, which is exactly the kind of rule
	that can be quietly wrong for a long time. The property that matters
	is not "the gate opens" but **that a lap is what opens it**: a gate
	that flipped on anything else — a timer, a trigger, an obstacle count
	— would look identical from inside the game and would teach the
	player something false about the space.
**/
class TurnGateTest extends Test {
	function testTheGateIsClosedOnTheLiftThePlayerArrivesOn():Void {
		// Meeting it open first would teach nothing: an open gate is
		// indistinguishable from no gate at all.
		Assert.isTrue(TurnModel.gateClosedOn(0));
	}

	function testOneLapOpensTheGateAndTwoClosesItAgain():Void {
		Assert.isFalse(TurnModel.gateClosedOn(1));
		Assert.isTrue(TurnModel.gateClosedOn(2));
		Assert.isFalse(TurnModel.gateClosedOn(3));
	}

	function testWalkingBackwardsAroundOpensItToo():Void {
		// Haxe's `%` yields -1 for a negative odd operand, so a player who
		// laps the other way must not fall through a naive parity test.
		Assert.isFalse(TurnModel.gateClosedOn(-1));
		Assert.isTrue(TurnModel.gateClosedOn(-2));
		Assert.isFalse(TurnModel.gateClosedOn(-3));
	}

	function testAClosedGateAlwaysLeavesAWayPast():Void {
		// The load-bearing property, and the reason this is a shortcut and
		// not a lock: this space's setup is explicitly unproven in
		// world.md, and its exit is otherwise the only way out of the
		// biome. Scanned rather than probed at a guessed offset — the
		// first version of this test picked a z inside the rail clearance,
		// where nothing is standable for reasons that have nothing to do
		// with the gate, and failed for the wrong reason.
		var passableLeft = false;
		var passableRight = false;
		var probe = -TurnModel.HALF_WIDTH;
		while (probe <= TurnModel.HALF_WIDTH) {
			if (TurnCollision.isOpen(TurnModel.GATE_ALONG, probe, true)) {
				if (probe < 0) {
					passableLeft = true;
				} else {
					passableRight = true;
				}
			}
			probe += 1;
		}

		Assert.isTrue(passableLeft, "no way past the closed gate on one side");
		Assert.isTrue(passableRight, "no way past the closed gate on the other side");
	}

	function testTheClosedGateActuallyBlocksTheMiddle():Void {
		Assert.isFalse(TurnCollision.isOpen(TurnModel.GATE_ALONG, 0, true));
	}

	function testTheOpenGateBlocksNothing():Void {
		Assert.isTrue(TurnCollision.isOpen(TurnModel.GATE_ALONG, 0, false));
	}

	function testTheGateSitsOnTheBandAndClearOfTheRails():Void {
		Assert.isTrue(Math.abs(TurnModel.GATE_ALONG) < TurnModel.PERIOD / 2, "inside the fundamental domain");
		Assert.isTrue(TurnModel.GATE_HALF_WIDTH < TurnModel.HALF_WIDTH, "leaves a lane at each rail");
	}
}
