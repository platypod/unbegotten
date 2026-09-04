package biomes.repeat;

import biomes.repeat.RepeatModel.AnomalyKind;
import utest.Assert;
import utest.Test;

/**
	Covers the difficulty tiering — that the city really does teach you to
	see before it asks you to.

	The failure this guards against is silent and ruinous: if a hard kind
	leaked into the tiles around spawn, a first-time player would be asked
	to spot a nine-generation phase shift before they had any reason to
	believe anomalies existed, conclude there was nothing to find, and stop
	looking. Nothing in a screenshot would show it.
**/
class AnomalyTierTest extends Test {
	function testTilesNearSpawnOnlyEverCarryTheEasyKinds():Void {
		var easy = [Playing, Misshapen];
		for (i in -2...3) {
			for (j in -2...3) {
				if (RepeatModel.divergenceOf(i, j) == null) {
					continue;
				}
				var kind = RepeatModel.anomalyKind(i, j);
				Assert.contains(kind, easy, 'tile ($i, $j) is next to spawn and carries $kind');
			}
		}
	}

	function testTheHardestKindsNeverAppearBeforeTheOuterTier():Void {
		for (i in -6...7) {
			for (j in -6...7) {
				if (RepeatModel.divergenceOf(i, j) == null) {
					continue;
				}
				var kind = RepeatModel.anomalyKind(i, j);
				Assert.isFalse(kind == Phased || kind == Stopped, 'tile ($i, $j) is inside the middle tier and carries $kind');
			}
		}
	}

	function testTheOuterCityActuallyUsesTheHardKinds():Void {
		// The mirror of the test above: tiering that only ever excluded
		// would mean the hard anomalies were written and never reachable.
		var seen = new Map<String, Bool>();
		for (i in -25...26) {
			for (j in -25...26) {
				if (RepeatModel.divergenceOf(i, j) == null) {
					continue;
				}
				seen.set(Std.string(RepeatModel.anomalyKind(i, j)), true);
			}
		}
		Assert.isTrue(seen.exists("Phased"), "no tile anywhere is Phased");
		Assert.isTrue(seen.exists("Stopped"), "no tile anywhere is Stopped");
	}

	function testEveryTierPoolIsNonEmptyAndDrawnFrom():Void {
		for (tier in 0...3) {
			Assert.isTrue(RepeatModel.anomalyPool(tier).length > 0, 'tier $tier has no kinds at all');
		}
	}

	function testTheTierRisesWithDistanceAndNeverFalls():Void {
		var previous = RepeatModel.anomalyTierAt(0, 0);
		for (ring in 0...20) {
			var tier = RepeatModel.anomalyTierAt(ring, 0);
			Assert.isTrue(tier >= previous, 'tier fell from $previous to $tier at ring $ring');
			previous = tier;
			Assert.equals(tier, RepeatModel.anomalyTierAt(0, ring), 'tiering is not symmetric at ring $ring');
			Assert.equals(tier, RepeatModel.anomalyTierAt(-ring, 0), 'tiering differs in the negative direction at ring $ring');
		}
	}
}
