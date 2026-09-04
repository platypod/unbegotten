package entities.landmark;

import entities.landmark.GlyphAlphabet.Glyph;
import utest.Assert;
import utest.Test;

/**
	Covers the one property that makes the landmark alphabet an alphabet:
	no glyph is a rotation or reflection of any other.

	This is not a style check. Parallel transport rotates a glyph as the
	player carries a route around a curved surface — the Defect exists to
	teach exactly that — so two glyphs related by a rotation are the *same
	landmark* to a player who arrived from a different direction. The
	alphabet would silently have fewer letters than it claims, and a route
	remembered as a sequence of glyphs would stop being unambiguous, which
	is the whole navigation mechanism for the Sprawl.

	Run against the real `res/data/landmark-glyphs.json` rather than a
	fixture, so adding a thirteenth glyph that happens to be a rotated
	`boat` fails here instead of in someone's play session.
**/
class GlyphAlphabetTest extends Test {
	/**
		The shipped alphabet — the real `res/data/landmark-glyphs.json`,
		embedded at compile time by `test.hxml`'s own `-resource` rather than
		read at runtime: the test target is `-js`, which has no
		`sys.io.File`, and `hxd.Res` needs a real Heaps app. Embedding is
		what keeps this a check on what actually ships instead of on a
		fixture that could drift away from it.
	**/
	function alphabet():Array<Glyph> {
		return GlyphAlphabet.parse(haxe.Resource.getString("landmark-glyphs"));
	}

	function testTheAlphabetHasTwelveGlyphs():Void {
		Assert.equals(12, alphabet().length);
	}

	function testEveryGlyphHasAName():Void {
		for (glyph in alphabet()) {
			Assert.isTrue(glyph.name.length > 0);
		}
	}

	function testNoGlyphIsARotationOrReflectionOfAnother():Void {
		var glyphs = alphabet();
		for (i in 0...glyphs.length) {
			for (j in (i + 1)...glyphs.length) {
				var a = glyphs[i];
				var b = glyphs[j];
				var bShapes = [for (shape in b.orientations()) shape => true];
				for (shape in a.orientations()) {
					Assert.isFalse(bShapes.exists(shape), '${a.name} and ${b.name} are the same shape once rotated or mirrored');
				}
			}
		}
	}

	function testRotatingAGlyphFourTimesReturnsItsOwnShape():Void {
		for (glyph in alphabet()) {
			var turned = glyph.rotated().rotated().rotated().rotated();
			Assert.equals(glyph.shapeKey(), turned.shapeKey(), glyph.name);
		}
	}

	function testNormalisingMovesAGlyphToTheOrigin():Void {
		var glyph = new Glyph("shifted", [{x: 5, y: 7}, {x: 6, y: 7}]);

		Assert.equals("0,0 1,0", glyph.shapeKey());
	}

	function testASymmetricGlyphHasFewerOrientationsThanAnAsymmetricOne():Void {
		// Not a curiosity: a glyph with rotational symmetry reads the same
		// however the player arrives at it, which is the *desirable* end of
		// this spectrum for a landmark.
		var block = new Glyph("block", [{x: 0, y: 0}, {x: 1, y: 0}, {x: 0, y: 1}, {x: 1, y: 1}]);
		var eater = new Glyph("eater", [
			{x: 0, y: 0},
			{x: 1, y: 0},
			{x: 0, y: 1},
			{x: 2, y: 1},
			{x: 2, y: 2},
			{x: 2, y: 3},
			{x: 3, y: 3}
		]);

		Assert.equals(1, block.orientations().length);
		Assert.isTrue(eater.orientations().length > block.orientations().length);
	}
}
