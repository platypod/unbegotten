package entities.landmark;

import entities.landmark.GlyphAlphabet.Glyph;
import graphics.Colours;
import h3d.scene.Mesh;
import h3d.scene.Object;

/**
	Turns a `Glyph` into standing geometry — one extruded block per occupied
	cell, so the shape reads as a silhouette from any direction.

	**Deliberately not a signal colour.** `graphics.Colours`'s own contrast
	budget reserves saturation for the very few things that should pop, and
	wayfinding furniture is not one of them: there is a glyph at every
	junction worth naming, so colouring them would spend the whole budget on
	the most common object in the world and leave nothing for an actual
	goal. They earn their legibility from silhouette instead, which is
	exactly what `docs/game/art-and-audio.md` asks of them
	("distinguishable by silhouette alone") — value and shape, no hue.

	Built flat on the local xz plane and extruded up y. A caller places and
	orients the returned object; this class has no opinion about which
	surface it is standing on, so the same glyph works on a sphere's
	interior, a cone, or a hyperbolic floor without knowing about any of
	them.
**/
class GlyphMesh {
	/** World size of one glyph cell. Small on purpose — these are read at arm's length, not across a level. **/
	public static inline final CELL_SIZE:Float = 2.2;

	/** How far a glyph block stands off its floor. Tall enough to break the horizon line at eye height, short enough not to become architecture. **/
	public static inline final HEIGHT:Float = 3.4;

	/** Gap between neighbouring blocks, as a fraction of `CELL_SIZE` — keeps a glyph's cells individually countable rather than fusing into one slab. **/
	public static inline final CELL_GAP:Float = 0.14;

	/**
		Builds `glyph` as a parented object of one block per cell, centred on
		its own footprint so a caller can place it by its middle rather than
		by a corner.
		@param glyph the glyph to build.
		@param parent scene object to attach the blocks to.
		@param colour block fill; defaults to the base ramp's raised value.
		@return the object the blocks were added to.
	**/
	public static function build(glyph:Glyph, parent:Object, colour:Int = Colours.SURFACE_RAISED):Object {
		var root = new Object(parent);
		var cells = glyph.normalised();

		var maxX = 0;
		var maxY = 0;
		for (cell in cells) {
			if (cell.x > maxX) {
				maxX = cell.x;
			}
			if (cell.y > maxY) {
				maxY = cell.y;
			}
		}
		// Centre on the footprint, not on cell (0,0): a glyph placed at a
		// junction should straddle it rather than hang off one side.
		var offsetX = maxX * CELL_SIZE * 0.5;
		var offsetY = maxY * CELL_SIZE * 0.5;

		var side = CELL_SIZE * (1 - CELL_GAP);
		for (cell in cells) {
			var block = new Mesh(new h3d.prim.Cube(side, HEIGHT, side), root);
			block.x = cell.x * CELL_SIZE - offsetX;
			block.z = cell.y * CELL_SIZE - offsetY;
			block.material.color.setColor(colour);
			block.material.shadows = false;
		}
		return root;
	}
}
