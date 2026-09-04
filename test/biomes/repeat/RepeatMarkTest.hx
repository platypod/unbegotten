package biomes.repeat;

import entities.landmark.GlyphAlphabet;
import entities.landmark.GlyphAlphabet.Glyph;
import utest.Assert;
import utest.Test;

/**
	Covers the mark the divergences compose — the Repeat's own payload.

	Three things can silently destroy it, none visible in a screenshot and
	none caught by the collision or layout tests:

	1. A mark plot the reference layout does not build on. That tile's
	   divergence would remove nothing, so the piece could never be found
	   and the mark could never complete. The player would collect
	   forever.
	2. A divergence drawn from outside the mark, which puts noise into the
	   overlay and makes the shape unreadable however carefully it is
	   looked for.
	3. `MARK_PLOTS` drifting away from the still life it is supposed to
	   be. It is duplicated from the landmark alphabet by hand (see its
	   own doc for why), so nothing but this test stops the two diverging.
**/
class RepeatMarkTest extends Test {
	function loaf():Glyph {
		var alphabet = GlyphAlphabet.parse(haxe.Resource.getString("landmark-glyphs"));
		for (glyph in alphabet) {
			if (glyph.name == "loaf") {
				return glyph;
			}
		}
		throw "the alphabet no longer has a loaf";
	}

	function testEveryMarkPlotIsOneTheReferenceLayoutBuildsOn():Void {
		// Otherwise that piece of the mark can never be found, and the
		// player collects forever without the shape completing.
		for (plot in RepeatModel.MARK_PLOTS) {
			Assert.isTrue(RepeatModel.referenceHasBuilding(plot.plotX, plot.plotZ), 'mark plot (${plot.plotX}, ${plot.plotZ}) has no building to remove');
		}
	}

	function testTheMarkPlotsAreAllDistinct():Void {
		var seen = new Map<String, Bool>();
		for (plot in RepeatModel.MARK_PLOTS) {
			var key = '${plot.plotX},${plot.plotZ}';
			Assert.isFalse(seen.exists(key), 'mark plot $key appears twice');
			seen.set(key, true);
		}
	}

	function testEveryDivergenceLandsOnAMarkPlot():Void {
		// The overlay is the mechanism; a divergence off the mark is noise
		// in it.
		var marks = new Map<String, Bool>();
		for (plot in RepeatModel.MARK_PLOTS) {
			marks.set('${plot.plotX},${plot.plotZ}', true);
		}
		for (i in -12...12) {
			for (j in -12...12) {
				var divergence = RepeatModel.divergenceOf(i, j);
				if (divergence == null) {
					continue;
				}
				Assert.isTrue(marks.exists('${divergence.plotX},${divergence.plotZ}'), 'tile ($i, $j) diverges off the mark');
			}
		}
	}

	function testEveryMarkPlotIsActuallyReachableAcrossTheTiles():Void {
		// The mark has to be completable: if the hash never selects some
		// plot, that piece does not exist in the world at all.
		var found = new Map<String, Bool>();
		for (i in -20...20) {
			for (j in -20...20) {
				var divergence = RepeatModel.divergenceOf(i, j);
				if (divergence != null) {
					found.set('${divergence.plotX},${divergence.plotZ}', true);
				}
			}
		}
		for (plot in RepeatModel.MARK_PLOTS) {
			Assert.isTrue(found.exists('${plot.plotX},${plot.plotZ}'), 'no tile in range ever diverges at (${plot.plotX}, ${plot.plotZ})');
		}
	}

	function testTheMarkIsStillTheLoafFromTheAlphabet():Void {
		// The duplication guard. Compares by shape, not by coordinates, so
		// the mark may be placed and rotated freely on the plot grid — it
		// just may not stop being a loaf.
		var asGlyph = new Glyph("mark", [for (plot in RepeatModel.MARK_PLOTS) {x: plot.plotX, y: plot.plotZ}]);
		var shapes = [for (shape in loaf().orientations()) shape => true];

		Assert.isTrue(shapes.exists(asGlyph.shapeKey()), "MARK_PLOTS is no longer a loaf in any orientation");
	}
}
