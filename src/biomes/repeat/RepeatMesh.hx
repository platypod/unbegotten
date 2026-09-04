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
	static inline final FOG_START:Float = 55;

	/** See `FOG_START`. **/
	static inline final FOG_END:Float = 340;

	/**
		The progress constellation: one star per mark plot already found,
		hung in the sky in the mark's *own* arrangement.

		Diegetic, and deliberately the same shape as the payload rather than
		a separate motif. The player watches a constellation assemble
		overhead, one star at a time, in the layout the ground-level reveal
		will eventually take — so progress and the thing being progressed
		toward are one object, and the sky is quietly telling you what you
		are building long before it finishes. A counter would say "3 of 7";
		this says "three of *these*, and here is where the others go".

		Stars only appear where a plot has actually been found, so the gaps
		are information too: they are the pieces still out there.
	**/
	static inline final STAR_COLOR:Int = 0xC8D4E2;

	/** How high the constellation hangs. Well above the tallest tower, so nothing occludes it and it reads as sky rather than as architecture. **/
	static inline final STAR_HEIGHT:Float = 210;

	/** World units between neighbouring stars — the mark's own plot spacing, scaled up so the shape is legible from the ground. **/
	static inline final STAR_SPACING:Float = 26;

	/** Half-extent of one star. **/
	static inline final STAR_HALF_WIDTH:Float = 3.2;

	/** Half-width of a street light strip. **/
	static inline final STRIP_HALF_WIDTH:Float = 0.7;

	/** How high a street strip stands off the ground — just enough not to z-fight with it. **/
	static inline final STRIP_HEIGHT:Float = 0.35;

	/**
		Builds every tile within `radius` tiles of the one the player is
		standing in.
		@param parent the scene object to build under.
		@param centre the tile at the centre of the built region.
		@param radius how many tiles out to build, each way.
		@param collected which tiles have had their anomaly put right, keyed by `RepeatBiome.tileKey`.
		@param found which of the mark's own plots have been found, keyed `"plotX,plotZ"` — drives the progress constellation.
	**/
	public static function build(parent:h3d.scene.Object, centre:{i:Int, j:Int}, radius:Int, collected:Map<String, Bool>, found:Map<String, Bool>):Void {
		addGround(parent, centre, radius);

		var buildings = new BoxBatch(parent, FACE_EAST_WEST,
			() -> new CityFacade(FACE_EAST_WEST, FACE_NORTH_SOUTH, FACE_TOP, WINDOW_DARK, WINDOW_LIT, WINDOW_NEON, SKY_COLOR, FOG_START, FOG_END,
				RepeatModel.TILE_SIZE));
		var strips = new BoxBatch(parent, STREET_GLOW);

		for (di in -radius...radius + 1) {
			for (dj in -radius...radius + 1) {
				addTile(parent, buildings, strips, centre.i + di, centre.j + dj, collected);
			}
		}

		buildings.flush();
		strips.flush();
		addConstellation(parent, centre, found);
	}

	/**
		The found-so-far stars, centred over the region being built so they
		stay overhead as the player walks. See `STAR_COLOR`.
		@param found which mark plots have been found, keyed `"plotX,plotZ"`.
	**/
	static function addConstellation(parent:h3d.scene.Object, centre:{i:Int, j:Int}, found:Map<String, Bool>):Void {
		var stars = new BoxBatch(parent, STAR_COLOR);
		var origin = RepeatModel.tileOrigin(centre.i, centre.j);
		var middle = RepeatModel.TILE_SIZE / 2;
		for (plot in RepeatModel.MARK_PLOTS) {
			if (!found.exists('${plot.plotX},${plot.plotZ}')) {
				continue;
			}
			// Centred on the mark's own bounding box rather than on plot
			// (0,0), so the constellation sits overhead rather than off to
			// one side of wherever the player happens to be.
			var x = origin.x + middle + (plot.plotX - 1.5) * STAR_SPACING;
			var z = origin.z + middle + (plot.plotZ - 3.5) * STAR_SPACING;
			stars.add(x, z, STAR_HALF_WIDTH, STAR_HALF_WIDTH, STAR_HEIGHT, STAR_HALF_WIDTH * 2);
		}
		stars.flush();
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

	/** One tile's buildings and street strips — including its deformed one, if it has one and it has not been put right. **/
	static function addTile(parent:h3d.scene.Object, buildings:BoxBatch, strips:BoxBatch, i:Int, j:Int, collected:Map<String, Bool>):Void {
		var half = RepeatModel.buildingHalfExtent();

		for (plotX in 0...RepeatModel.PLOTS_PER_TILE) {
			for (plotZ in 0...RepeatModel.PLOTS_PER_TILE) {
				if (!RepeatModel.hasBuilding(i, j, plotX, plotZ)) {
					continue;
				}
				var centre = RepeatModel.plotCentre(i, j, plotX, plotZ);
				var height = RepeatModel.buildingHeight(plotX, plotZ);
				var tiers = RepeatModel.tierCount(plotX, plotZ);
				if (RepeatModel.isAnomalous(i, j, plotX, plotZ) && !collected.exists(RepeatBiome.tileKey(i, j))) {
					addDeformedBuilding(parent, centre.x, centre.z, half, height, tiers, RepeatModel.anomalyLean(i, j), RepeatModel.anomalyBearing(i, j));
					continue;
				}
				addBuilding(buildings, centre.x, centre.z, half, height, tiers);
			}
		}
		addStreetStrips(strips, i, j);
	}

	/**
		The anomalous building: the same building, leaning.

		Its own object with a rotation on it rather than a box in the shared
		batch, because `game.BoxBatch` emits axis-aligned geometry by design
		— "a building or a cell is a discrete thing sitting on the terrain,
		not a shear of it" — and this is the one building in the world that
		is deliberately not upright.

		The lean is applied about the base, not the centre, so the building
		still meets the ground where it should and only its top is out of
		line. That is what makes it a *comparison* rather than an alarm: the
		footprint is right, the silhouette is not, and you cannot tell
		without something to hold it against.
	**/
	static function addDeformedBuilding(parent:h3d.scene.Object, x:Float, z:Float, half:Float, height:Float, tiers:Int, lean:Float, bearing:Float):Void {
		var pivot = new h3d.scene.Object(parent);
		pivot.x = x;
		pivot.z = z;
		pivot.rotate(Math.cos(bearing) * lean, 0, Math.sin(bearing) * lean);

		var batch = new BoxBatch(pivot, FACE_EAST_WEST,
			() -> new CityFacade(FACE_EAST_WEST, FACE_NORTH_SOUTH, FACE_TOP, WINDOW_DARK, WINDOW_LIT, WINDOW_NEON, SKY_COLOR, FOG_START, FOG_END,
				RepeatModel.TILE_SIZE));
		addBuilding(batch, 0, 0, half, height, tiers);
		batch.flush();
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
		Light strips along a tile's own edges — the one other emissive thing
		at ground level, and what stops the ground plane and the building
		bases merging into a single dark mass.

		**On tile boundaries, not on every plot**, which is both a visual
		and a mechanical decision. A strip per plot was a grid fine enough to
		read as graph paper ("too granular"), and it also said nothing: it
		marked a division the player has no use for. A strip per *tile* draws
		the period itself, so the ground answers the question this space's
		own verb asks — "walk exactly one measured period" — without a UI or
		a counter. You can see where one repeat ends and the next begins,
		which is the comparison the whole biome is about.
	**/
	static function addStreetStrips(strips:BoxBatch, i:Int, j:Int):Void {
		var origin = RepeatModel.tileOrigin(i, j);
		var span = RepeatModel.TILE_SIZE;
		strips.add(origin.x, origin.z + span / 2, STRIP_HALF_WIDTH, span / 2, STRIP_HEIGHT, STRIP_HEIGHT);
		strips.add(origin.x + span / 2, origin.z, span / 2, STRIP_HALF_WIDTH, STRIP_HEIGHT, STRIP_HEIGHT);
	}
}
