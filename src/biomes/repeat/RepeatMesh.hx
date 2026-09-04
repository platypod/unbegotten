package biomes.repeat;

import game.BoxBatch;
import game.MeshBuilder;
import graphics.Colours;
import graphics.shaders.CityFacade;

/**
	The cell city: flat ground, blocky buildings, and a pale marker
	standing wherever a tile diverges from the reference.

	**The visual dialect is doing mechanical work, not decorating.**
	`docs/game/art-and-audio.md` assigns this space
	Manifold Garden's register — blocky, low-poly, almost no texture,
	silhouette carrying everything — and argues it from the mechanic
	rather than from taste: spot-the-difference needs hard edges and
	repeated units, because a city gives divergence somewhere obvious to
	hide in a way organic terrain never does. A missing block in a
	skyline is a shape you can *remember*; a missing rock on a hillside
	is not.

	Colour is value only. κ = 0 is bone, slate and ash, and hue belongs to
	curvature alone — so buildings, ground and marker are separated by
	lightness, exactly as in `biomes.ribbon.RibbonMesh`.
**/
class RepeatMesh {
	static inline final GROUND_COLOR:Int = Colours.SURFACE_DEEP;

	/**
		The sky, and what distance fades toward — the same value for both, or
		the horizon shows a seam where faded geometry meets a background it
		does not match. `RepeatBiome.backgroundColor` returns this, which is
		the whole of the "sky gradient": with the fade landing exactly on the
		clear colour, the far city dissolves into the sky instead of ending
		at a visible wall of geometry.
	**/
	public static inline final SKY_COLOR:Int = 0x0B1018;

	/**
		The three facet values. Faces are valued by which axis they face —
		see `graphics.shaders.CityFacade` for why a single flat fill made
		the whole city read as one silhouette.
	**/
	static inline final FACE_EAST_WEST:Int = 0x8A929C;

	/** See `FACE_EAST_WEST`. Darker, so a corner reads as a corner. **/
	static inline final FACE_NORTH_SOUTH:Int = 0x5E656E;

	/** See `FACE_EAST_WEST`. Roofs catch the most light in a world with no sun, being the faces that face the whole sky. **/
	static inline final FACE_TOP:Int = 0xA6AEB8;

	/** An unlit pane — below the wall value, so a dark tower still shows its grid rather than going featureless. **/
	static inline final WINDOW_DARK:Int = 0x3A424C;

	/** A lit pane. Value, not hue: the contrast budget spends saturation on signals. **/
	static inline final WINDOW_LIT:Int = 0xD8DDE4;

	/** The rare saturated pane — see `CityFacade`'s own note on why roughly one window in forty. **/
	static inline final WINDOW_NEON:Int = Colours.SIGNAL_LIVE;

	/** Street-level light strips, the one other emissive thing down here. **/
	static inline final STREET_GLOW:Int = 0x4A5A6B;

	/** Where distance fading begins and ends, in world units. Tuned to the built radius so the far edge of the region dissolves rather than ending in a visible wall of geometry. **/
	static inline final FOG_START:Float = 120;

	/** See `FOG_START`. **/
	static inline final FOG_END:Float = 620;

	/** Half-width of a street light strip. **/
	static inline final STRIP_HALF_WIDTH:Float = 0.7;

	/** How high a street strip stands off the ground — just enough not to z-fight with it. **/
	static inline final STRIP_HEIGHT:Float = 0.35;

	/** The marker standing in a diverged plot — the brightest thing in the biome, and the only one. **/
	static inline final FRAGMENT_COLOR:Int = 0xEFEAE0;

	static inline final FRAGMENT_HEIGHT:Float = 16;
	static inline final FRAGMENT_HALF_WIDTH:Float = 2.2;

	/**
		Builds every tile within `radius` tiles of the one the player is
		standing in.
		@param parent the scene object to build under.
		@param centre the tile at the centre of the built region.
		@param radius how many tiles out to build, each way.
		@param collected which tiles have had their fragment taken, keyed by `RepeatBiome.tileKey`.
	**/
	public static function build(parent:h3d.scene.Object, centre:{i:Int, j:Int}, radius:Int, collected:Map<String, Bool>):Void {
		addGround(parent, centre, radius);

		var buildings = new BoxBatch(parent, FACE_EAST_WEST,
			() -> new CityFacade(FACE_EAST_WEST, FACE_NORTH_SOUTH, FACE_TOP, WINDOW_DARK, WINDOW_LIT, WINDOW_NEON, SKY_COLOR, FOG_START, FOG_END,
				RepeatModel.TILE_SIZE));
		var strips = new BoxBatch(parent, STREET_GLOW);
		var fragments = new BoxBatch(parent, FRAGMENT_COLOR);

		for (di in -radius...radius + 1) {
			for (dj in -radius...radius + 1) {
				addTile(buildings, strips, fragments, centre.i + di, centre.j + dj, collected);
			}
		}

		buildings.flush();
		strips.flush();
		fragments.flush();
	}

	/** One flat quad under the whole built region — the streets, and everything a building is not standing on. **/
	static function addGround(parent:h3d.scene.Object, centre:{i:Int, j:Int}, radius:Int):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();

		var origin = RepeatModel.tileOrigin(centre.i - radius, centre.j - radius);
		var span = (radius * 2 + 1) * RepeatModel.TILE_SIZE;

		MeshBuilder.addQuad(points, idx, new h3d.Vector(origin.x, 0, origin.z), new h3d.Vector(origin.x + span, 0, origin.z),
			new h3d.Vector(origin.x + span, 0, origin.z + span), new h3d.Vector(origin.x, 0, origin.z + span));

		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), parent);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(GROUND_COLOR));
		mesh.material.mainPass.culling = None;
	}

	/** One tile's buildings and street strips, plus its fragment marker if it diverges and has not been collected. **/
	static function addTile(buildings:BoxBatch, strips:BoxBatch, fragments:BoxBatch, i:Int, j:Int, collected:Map<String, Bool>):Void {
		var half = RepeatModel.buildingHalfExtent();

		for (plotX in 0...RepeatModel.PLOTS_PER_TILE) {
			for (plotZ in 0...RepeatModel.PLOTS_PER_TILE) {
				if (!RepeatModel.hasBuilding(i, j, plotX, plotZ)) {
					continue;
				}
				var centre = RepeatModel.plotCentre(i, j, plotX, plotZ);
				addBuilding(buildings, centre.x, centre.z, half, RepeatModel.buildingHeight(plotX, plotZ), RepeatModel.tierCount(plotX, plotZ));
			}
		}
		addStreetStrips(strips, i, j);

		var divergence = RepeatModel.divergenceOf(i, j);
		if (divergence == null || collected.exists(RepeatBiome.tileKey(i, j))) {
			return;
		}
		var at = RepeatModel.plotCentre(i, j, divergence.plotX, divergence.plotZ);
		fragments.add(at.x, at.z, FRAGMENT_HALF_WIDTH, FRAGMENT_HALF_WIDTH, 0, FRAGMENT_HEIGHT);
	}

	/**
		One building as a stack of tiers, each inset from the one below —
		see `RepeatModel.tierCount` for why a stepped skyline is worth the
		extra boxes.
	**/
	static function addBuilding(buildings:BoxBatch, x:Float, z:Float, half:Float, height:Float, tiers:Int):Void {
		var base = 0.0;
		var extent = half;
		for (tier in 0...tiers) {
			// Later tiers are shorter as well as narrower, so a tower
			// tapers rather than looking like stacked identical blocks.
			var slice = height * (tier == tiers - 1 ? 1.0 : 0.55) / (tiers - tier);
			buildings.add(x, z, extent, extent, base, slice);
			base += slice;
			extent *= RepeatModel.TIER_INSET;
		}
	}

	/**
		Light strips down the middle of a tile's streets — the one other
		emissive thing at ground level, and what stops the ground plane and
		the building bases merging into a single dark mass.

		Drawn on the plot grid rather than only where there is no building,
		so the grid reads as continuous the way a lit road does; a strip
		under a building is simply hidden by it.
	**/
	static function addStreetStrips(strips:BoxBatch, i:Int, j:Int):Void {
		var origin = RepeatModel.tileOrigin(i, j);
		var span = RepeatModel.TILE_SIZE;
		for (line in 0...RepeatModel.PLOTS_PER_TILE) {
			var offset = line * RepeatModel.PLOT_SIZE;
			strips.add(origin.x + offset, origin.z + span / 2, STRIP_HALF_WIDTH, span / 2, STRIP_HEIGHT, STRIP_HEIGHT);
			strips.add(origin.x + span / 2, origin.z + offset, span / 2, STRIP_HALF_WIDTH, STRIP_HEIGHT, STRIP_HEIGHT);
		}
	}
}
