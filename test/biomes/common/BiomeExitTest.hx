package biomes.common;

import biomes.debug.DebugHubBiome;
import biomes.defect.DefectBiome;
import biomes.knot.KnotBiome;
import biomes.ribbon.RibbonBiome;
import biomes.sprawl.SprawlBiome;
import biomes.turn.TurnBiome;
import utest.Assert;
import utest.Test;

/**
	Pins where the numbered prototype spaces send you, and which of their
	exits are allowed to fire when you walk near one.

	**This exists because the same bug was reported twice.** An exit
	painting with nothing drawn at it is not an exit, it is a trapdoor: the
	player is removed from the level having had no way to see where it was
	or to avoid it. It was fixed once for the Fold and the Weft
	(2026-09-05) and the remaining biomes were cleared by the wrong test —
	*does this biome have a visible landmark* — which the Ribbon, the
	Defect and the Knot all pass while their exits stand somewhere else
	entirely. The Turn's was then walked into.

	Neither half of this can be checked generically: "is something drawn
	here" is not a question the model layer can answer, and a test that
	tried would be asserting against a mesh builder rather than against the
	rule. So these are concrete facts about concrete biomes, written down
	so the next person to add an exit has to come and change them
	deliberately.
**/
class BiomeExitTest extends Test {
	/**
		The exits that stand on nothing, and must therefore stay inert until
		something marks them.

		Not a blanket rule against triggering — see
		`testTheSprawlsDrawnExitStillTriggers`.
	**/
	function testUnmarkedExitsDoNotTriggerOnApproach():Void {
		for (biome in unmarked()) {
			for (exit in biome.exitPaintings()) {
				Assert.isFalse(exit.triggersOnApproach, '${biome.id()} has an exit that fires on approach with nothing drawn at it');
			}
		}
	}

	/** The Sprawl's amber home tile is the brightest thing in that biome, so it is an exit rather than a trapdoor and keeps its trigger. **/
	function testTheSprawlsDrawnExitStillTriggers():Void {
		var exits = new SprawlBiome().exitPaintings();

		Assert.equals(1, exits.length);
		Assert.isTrue(exits[0].triggersOnApproach, "the Sprawl's home tile stopped being a working exit");
	}

	/**
		Every one of these spaces sends you to the dev room rather than the
		real hub.

		They are prototypes reached from the debug ring, so landing back in
		`biomes.hub.HubBiome` — a designed place with an hourglass and a
		story job — is both a longer walk back and a category error.
	**/
	function testTheyAllLeadToTheDebugRoom():Void {
		var checked = 0;
		for (biome in unmarked().concat([cast new SprawlBiome()])) {
			for (exit in biome.exitPaintings()) {
				checked++;
				Assert.equals(DebugHubBiome.ID, exit.destinationBiomeId, '${biome.id()} does not lead to the debug room');
			}
		}
		Assert.isTrue(checked >= 5, 'only $checked exits were checked across five biomes');
	}

	/** Every one of them still *has* an exit, inert or not — the debug leave key reads `exitPaintings()[0]`, so an empty list would strand a developer. **/
	function testEveryBiomeStillOffersAWayOut():Void {
		for (biome in unmarked().concat([cast new SprawlBiome()])) {
			Assert.isTrue(biome.exitPaintings().length > 0, '${biome.id()} has no exit at all, so the debug leave key cannot work');
		}
	}

	/** The four whose exits nothing is drawn at — see the class doc. **/
	function unmarked():Array<Biome> {
		return [
			cast new TurnBiome(),
			cast new DefectBiome(),
			cast new RibbonBiome(),
			cast new KnotBiome()
		];
	}
}
