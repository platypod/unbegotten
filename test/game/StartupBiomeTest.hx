package game;

import utest.Assert;
import utest.Test;

/**
	Covers `GameLoop.biomeIdFromFragment`, the parser behind the
	`#biome=<id>` startup override.

	Worth its own tests despite being six lines: the input is a URL typed
	by a human, so every degenerate form of it is reachable, and the
	failure mode of getting it wrong is the game opening somewhere other
	than where the person asked — which looks exactly like the override not
	existing.
**/
class StartupBiomeTest extends Test {
	function testReadsABiomeIdOutOfAFragment():Void {
		Assert.equals("knot", GameLoop.biomeIdFromFragment("#biome=knot"));
	}

	/** With or without the leading `#`, since `location.hash` carries it and a hand-written string may not. **/
	function testTheLeadingHashIsOptional():Void {
		Assert.equals("knot", GameLoop.biomeIdFromFragment("biome=knot"));
	}

	function testFindsTheBiomeAmongOtherParameters():Void {
		Assert.equals("sprawl", GameLoop.biomeIdFromFragment("#debug=1&biome=sprawl&zoom=2"));
	}

	/** No fragment at all is the ordinary case — every normal page load takes this path. **/
	function testAnEmptyFragmentNamesNothing():Void {
		Assert.isNull(GameLoop.biomeIdFromFragment(""));
		Assert.isNull(GameLoop.biomeIdFromFragment("#"));
	}

	function testAFragmentWithoutABiomeNamesNothing():Void {
		Assert.isNull(GameLoop.biomeIdFromFragment("#debug=1"));
	}

	/** `#biome=` with nothing after it is a typo, not a request for a biome called "". **/
	function testAnEmptyValueNamesNothing():Void {
		Assert.isNull(GameLoop.biomeIdFromFragment("#biome="));
		Assert.isNull(GameLoop.biomeIdFromFragment("#biome=   "));
	}

	/** Trimmed, since a hand-typed or copy-pasted URL picks up whitespace easily. **/
	function testSurroundingWhitespaceIsIgnored():Void {
		Assert.equals("turn", GameLoop.biomeIdFromFragment("#biome= turn "));
	}
}
