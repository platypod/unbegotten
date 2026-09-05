package biomes.debug;

import utest.Assert;
import utest.Test;

/**
	Covers the debug room's own label table — the numbering, and the French
	names now sharing it.

	The French set is duplicated from `docs/game/one-page.fr.svg` by hand
	(the poster is a document, this is runtime data), so nothing but a test
	stops the two drifting. A drifted name is not a crash: the sign simply
	says something the design document does not, in the one room whose whole
	job is telling you where you are.
**/
class DebugHubOrderTest extends Test {
	/** The nine numbered spaces, and what each sign should read. **/
	static final EXPECTED:Array<{
		id:String,
		number:Int,
		english:String,
		french:String
	}> = [
		{
			id: "hub",
			number: 0,
			english: "Still Life",
			french: "La Nature Morte"
		},
		{
			id: "conway",
			number: 1,
			english: "Fold",
			french: "Le Repli"
		},
		{
			id: "weft",
			number: 2,
			english: "Weft",
			french: "La Trame"
		},
		{
			id: "repeat",
			number: 3,
			english: "Repeat",
			french: "Le Motif"
		},
		{
			id: "turn",
			number: 4,
			english: "Turn",
			french: "La Volte"
		},
		{
			id: "defect",
			number: 5,
			english: "Defect",
			french: "Le Défaut"
		},
		{
			id: "ribbon",
			number: 6,
			english: "Ribbon",
			french: "Le Ruban"
		},
		{
			id: "sprawl",
			number: 7,
			english: "Sprawl",
			french: "La Prolifération"
		},
		{
			id: "knot",
			number: 8,
			english: "Knot",
			french: "Le Nœud"
		}
	];

	function testEveryNumberedSpaceReadsItsNumberNameAndFrenchName():Void {
		for (entry in EXPECTED) {
			Assert.equals('${entry.number}. ${entry.english}\n${entry.french}', DebugHubOrder.labelFor(entry.id));
		}
	}

	function testTheNumbersRunZeroToEightWithoutAGap():Void {
		var seen = [for (entry in EXPECTED) entry.number];
		seen.sort((a, b) -> a - b);
		for (index in 0...seen.length) {
			Assert.equals(index, seen[index], 'the curvature numbering skips or repeats at $index');
		}
	}

	function testAnUnnumberedBiomeKeepsItsBareId():Void {
		// maze, tower, mobius, wind, exterior and twosided predate the
		// direction and have no place on the curvature scale — showing them
		// a number would claim otherwise.
		for (id in ["maze", "tower", "mobius", "wind", "exterior", "twosided"]) {
			Assert.equals(id, DebugHubOrder.labelFor(id), '$id was given a design number it does not have');
		}
	}

	function testASpaceGetsTwoLinesAndAPlainIdGetsOne():Void {
		for (entry in EXPECTED) {
			Assert.equals(2, DebugHubOrder.labelFor(entry.id).split("\n").length);
		}
		Assert.equals(1, DebugHubOrder.labelFor("wind").split("\n").length);
	}

	function testNoTwoSpacesShareAFrenchName():Void {
		var seen = new Map<String, Bool>();
		for (entry in EXPECTED) {
			Assert.isFalse(seen.exists(entry.french), '${entry.french} is used twice');
			seen.set(entry.french, true);
		}
	}
}
