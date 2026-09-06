package biomes.defect;

import game.BoxBatch;
import game.MeshBuilder;
import graphics.Colours;
import graphics.shaders.FacetedSurface;

/**
	The plain, the apex, and the markers that make a rotation readable.

	**Everything here exists to be a reference frame.** The space's own
	lesson is that you come back turned, and "turned" is only meaningful
	against something. So: one **meridian** — a straight line of posts
	running out from the apex, the single unambiguous bearing in the
	world — plus concentric rings to gauge distance by, plus a tall spire
	on the apex so the thing being circled is never in doubt.

	Value only, as everywhere flat: κ is zero at every point the player
	can stand, and hue belongs to curvature.

	**Faceted and fogged (2026-09-06), and the fog is doing real work
	here.** `DefectBiome`'s own note admits the one thing this space cannot
	deliver: a cone cannot be flattened, so the markers are drawn in a
	window centred on the player and the unavoidable gap sits directly
	behind the apex. A flat fill drawn to a hard rim put that rim, and the
	disc's own edge, in plain sight. Fading geometry into the backdrop
	instead means the plain ends in darkness rather than at a visible
	boundary — the compromise stops being *visible* even though it is still
	there, which is the closest this gets to the legibility law's "nothing
	is visibly bent" without writing the seamless cone renderer that entry
	calls for. The posts gaining their sides is the ordinary half of the
	same change.
**/
class DefectMesh {
	/** Moved onto `graphics.Colours`' ramp with the visual pass; the ad-hoc grey predated the palette. **/
	static inline final GROUND_COLOR:Int = Colours.SURFACE_MID;

	static inline final RING_COLOR:Int = 0x5C646E;

	/**
		Where the plain starts fading out, in world units.

		Comfortably past the outermost ring, so every marker a player is
		actually reading a rotation against is drawn at full value; it is
		the empty ground beyond them, and the rim, that this is for.
	**/
	static inline final FOG_START:Float = 240;

	/** Where geometry has faded out entirely — past `DefectModel.PLAIN_RADIUS`, so the disc's own edge is deep in the fade rather than sitting exactly at it, which would read as a deliberate ring. **/
	static inline final FOG_END:Float = 700;

	/** The meridian, and the brightest thing here — it is the reference the whole space is read against. **/
	static inline final MERIDIAN_COLOR:Int = 0xE8E4DA;

	/** The apex spire. Mid-value: unmissable as a landmark without competing with the meridian. **/
	static inline final APEX_COLOR:Int = 0x8C949E;

	static inline final APEX_HEIGHT:Float = 90;
	static inline final APEX_HALF_WIDTH:Float = 5;

	static inline final POST_HALF_WIDTH:Float = 2.2;
	static inline final POST_HEIGHT:Float = 9;

	/** Meridian posts, from just outside the apex exclusion to the edge of the plain. **/
	static inline final MERIDIAN_POSTS:Int = 22;

	/** Concentric rings of posts, to judge how far round the apex you have come. **/
	static inline final RING_COUNT:Int = 4;

	/** Posts per full turn of a ring — spaced by *cone* angle, so a ring closes on itself exactly once. **/
	static inline final POSTS_PER_RING:Int = 24;

	/**
		Builds the plain around the player's current bearing.
		@param parent the scene object to build under.
		@param playerAngle where the player stands, as a world angle about the apex — the window of markers is centred on it (see `DefectModel.drawAngleFor`).
	**/
	public static function build(parent:h3d.scene.Object, playerAngle:Float):Void {
		addGround(parent);

		var apex = new BoxBatch(parent, APEX_COLOR, faceted(APEX_COLOR));
		apex.add(0, 0, APEX_HALF_WIDTH, APEX_HALF_WIDTH, 0, APEX_HEIGHT);
		apex.flush();

		addMeridian(parent, playerAngle);
		addRings(parent, playerAngle);
	}

	/**
		The floor, as one full disc.

		Drawn over the whole `2π` rather than over the cone's own angle, and
		deliberately featureless. A wedge of blank ground repeated or
		omitted is indistinguishable either way, whereas a hole in the
		floor would be the single most conspicuous thing in the biome —
		see `DefectBiome`'s note on the rendering compromise.
	**/
	static function addGround(parent:h3d.scene.Object):Void {
		var points:Array<h3d.Vector> = [];
		var idx = new hxd.IndexBuffer();
		var segments = 64;
		var centre = new h3d.Vector(0, 0, 0);

		for (i in 0...segments) {
			var a = 2 * Math.PI * i / segments;
			var b = 2 * Math.PI * (i + 1) / segments;
			MeshBuilder.addTriangle(points, idx, centre, at(DefectModel.PLAIN_RADIUS, a, 0), at(DefectModel.PLAIN_RADIUS, b, 0));
		}

		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), parent);
		mesh.material.mainPass.addShader(FacetedSurface.from(GROUND_COLOR, DefectBiome.BACKGROUND_COLOR, FOG_START, FOG_END));
		mesh.material.mainPass.culling = None;
	}

	/**
		This plain's own shading, for one `game.BoxBatch` — a factory, since
		`BoxBatch.flush` can emit several meshes and a shader carries
		per-mesh state.
		@param base the batch's own value.
		@return a factory building its shader.
	**/
	static function faceted(base:Int):Void->hxsl.Shader {
		return () -> FacetedSurface.from(base, DefectBiome.BACKGROUND_COLOR, FOG_START, FOG_END);
	}

	/** The one straight line out from the apex — cone angle `0`, the world's only unambiguous bearing. **/
	static function addMeridian(parent:h3d.scene.Object, playerAngle:Float):Void {
		var batch = new BoxBatch(parent, MERIDIAN_COLOR, faceted(MERIDIAN_COLOR));
		var drawAngle = DefectModel.drawAngleFor(0, playerAngle);
		var span = DefectModel.PLAIN_RADIUS - DefectModel.APEX_EXCLUSION;

		for (i in 0...MERIDIAN_POSTS) {
			var radius = DefectModel.APEX_EXCLUSION + span * (i + 0.5) / MERIDIAN_POSTS;
			var post = at(radius, drawAngle, 0);
			batch.add(post.x, post.z, POST_HALF_WIDTH, POST_HALF_WIDTH, 0, POST_HEIGHT);
		}
		batch.flush();
	}

	/**
		Concentric rings.

		Posts are spaced by **cone** angle, not world angle, so a ring
		closes on itself exactly once around the apex — which is what makes
		counting them a way to measure how far round you have come, and
		what makes the missing wedge behind the apex a gap in a count
		rather than a visible discontinuity.
	**/
	static function addRings(parent:h3d.scene.Object, playerAngle:Float):Void {
		var batch = new BoxBatch(parent, RING_COLOR, faceted(RING_COLOR));
		var span = DefectModel.PLAIN_RADIUS - DefectModel.APEX_EXCLUSION;

		for (ring in 0...RING_COUNT) {
			var radius = DefectModel.APEX_EXCLUSION + span * (ring + 1) / (RING_COUNT + 1);
			for (index in 0...POSTS_PER_RING) {
				var coneAngle = DefectModel.CONE_ANGLE * index / POSTS_PER_RING;
				var post = at(radius, DefectModel.drawAngleFor(coneAngle, playerAngle), 0);
				batch.add(post.x, post.z, POST_HALF_WIDTH, POST_HALF_WIDTH, 0, POST_HEIGHT);
			}
		}
		batch.flush();
	}

	static function at(radius:Float, angle:Float, height:Float):h3d.Vector {
		return new h3d.Vector(radius * Math.cos(angle), height, radius * Math.sin(angle));
	}
}
