package biomes.sprawl;

import biomes.common.Biome;
import biomes.common.Gravity;
import biomes.common.space.hyperbolic.HyperbolicSpace;
import biomes.common.space.hyperbolic.HyperbolicView;
import biomes.debug.DebugHubBiome;
import entities.painting.PaintingModel;
import entities.player.Camera.CameraOverride;
import entities.player.PlayerModel;
import game.MeshBuilder;
import geometry.CurvedSpace.ModelPoint;
import geometry.HyperbolicProjection;
import geometry.HyperbolicTiling;
import graphics.Colours;
import graphics.shaders.FacetedSurface;
import geometry.Isometry;

/**
	**The Sprawl** — the hyperbolic plane, and the first biome in the game
	whose floor is not a surface sitting in ordinary space. See
	[the design](../../../docs/game/world.md)'s
	own entry (`### 7. The Sprawl`), which calls it the turn of the game.

	This is a **prototype**, in the sense
	`docs/rules/philosophy.md` uses: the geometry is real and the
	rest is not. What's here is a `{7,3}` floor you can walk, columns for
	parallax, and one bright home tile that takes you back to the hub.
	What is deliberately absent is everything the design asks of the place
	— the ring-counting mechanism, the predecessor fragments, the audio cue
	at ring boundaries, the cellular automaton. Adding any of it before the
	space itself is confirmed to feel right would make a bad answer
	ambiguous, which is the same discipline
	`tools.hyperbolic.HyperbolicWalkApp` was built under.

	**How this renders, and why it is not like any other biome.** Hilbert's
	theorem forbids an isometric embedding of H² in ℝ³, so there is no mesh
	that *is* this floor and no camera position that *is* the player.
	Instead the camera is pinned at the origin looking down `+x`, and the
	whole world is transformed around it every frame by the player's own
	view isometry (`HyperbolicView.viewOf`), then projected
	(`geometry.HyperbolicProjection`, Beltrami-Klein, which keeps geodesics
	straight so an ordinary rasteriser still works). That is what
	`cameraOverride` is doing here — and why `Biome.capturesInput` had to
	become a separate question from it, since this biome wants its own
	camera on every frame *while walking normally*, which no previous user
	of `cameraOverride` did.

	**Two scales, and confusing them is the easy mistake.** Hyperbolic
	geometry has an intrinsic length unit (the curvature radius), and the
	tiling is expressed in it: a `{7,3}` cell is `≈1.09` across, full stop,
	because that is what the tiling *is*. The game's own movement is in
	world units. `CURVATURE_RADIUS` is the exchange rate, it is threaded
	through `Space` as the `radius` parameter that was already there, and
	every distance in this class is in **world units** unless its own name
	says otherwise.

	**Rendering scale is a third thing, and independent of both.**
	`HyperbolicProjection.HORIZON` decides how large the near field draws;
	it has nothing to do with how fast you walk. This is why the camera
	here sits at `EYE_HEIGHT` rather than `entities.player.Camera.EYE_HEIGHT`.
**/
class SprawlBiome implements Biome {
	public static inline final ID:String = "sprawl";

	/**
		World units per intrinsic hyperbolic unit — the biome's own
		curvature radius, and the only thing that decides how big this place
		feels to walk.

		Set from the harness that was actually played and validated:
		`HyperbolicWalkApp` crossed roughly one cell per second at `1.1`
		intrinsic units/s, and `game.GameLoop.WALK_SPEED` is `15` world
		units/s, so one intrinsic unit is `15 / 1.1 ≈ 13.6` world units.
		Deriving it that way rather than picking a round number is the
		point: it preserves the *one* thing about this space that has been
		confirmed comfortable by a human, which is its walking speed
		relative to its cell size.
	**/
	public static inline final CURVATURE_RADIUS:Float = 13.6;

	/** Rings of `{7,3}` generated — six is 1625 faces, and the distant ones cost nothing once `DRAW_DISTANCE` culls them. **/
	static inline final RINGS:Int = 6;

	/** Cull beyond this **intrinsic** distance. Past ~4 everything is inside the last 2% of the Klein disk and contributes vertices but no pixels. **/
	static inline final DRAW_DISTANCE:Float = 4.0;

	/** Camera height above the floor, in *rendered* units — see the class doc's third-scale note for why this is not `entities.player.Camera.EYE_HEIGHT`. **/
	static inline final EYE_HEIGHT:Float = 1.7;

	static inline final COLUMN_HEIGHT:Float = 4.0;

	/** Column half-width, intrinsic — so a column is the same real size everywhere rather than shrinking with the projection. **/
	static inline final COLUMN_RADIUS:Float = 0.10;

	/** Floor tiles drawn just inside their true boundary, so the tiling's own grid reads as gaps rather than needing outlines. **/
	static inline final TILE_INSET:Float = 0.92;

	/** Every Nth face gets a column: dense enough for continuous parallax, sparse enough to see past. **/
	static inline final COLUMN_EVERY:Int = 3;

	/** How far from the home tile the player starts, intrinsic — two cells, so home is a landmark to walk back to rather than somewhere you are already standing. **/
	static inline final SPAWN_DISTANCE:Float = 2.2;

	/** Same first-pass value as the maze's — see `biomes.hub.HubBiome.GRAVITY`'s own doc for why each biome states its own. **/
	static inline final GRAVITY:Float = 60;

	/**
		The floor is banded by ring parity, not painted one colour — this is
		the **ring-counting instrument**, not decoration.

		`world.md`'s own navigation algorithm for this space needs two
		components, and radius is the one the geometry can answer directly: a
		traveller moving outward crosses ring boundaries at a learnable,
		predictable rate, so the boundaries have to be *visible* before any of
		that is learnable at all. Alternating two base-ramp values across
		`HyperbolicTiling.rings` turns the tiling into concentric bands the
		player can count outward, which is the cheapest possible version of
		the mechanism — no new geometry, no new data, just the ring number the
		BFS already assigned every face.

		Two values from the ramp rather than two hues, so this costs nothing
		from `graphics.Colours`'s contrast budget: banding is everywhere, and
		anything everywhere has to read by value.
	**/
	static inline final FLOOR_EVEN_COLOR:Int = Colours.SURFACE_BASE;

	/** See `FLOOR_EVEN_COLOR`. **/
	static inline final FLOOR_ODD_COLOR:Int = Colours.SURFACE_MID;

	static inline final COLUMN_COLOR:Int = Colours.SURFACE_RAISED;

	/**
		Columns standing on a `MILESTONE_RING` boundary — a clear step up the
		ramp from `COLUMN_COLOR`.

		**This is the navigation instrument, not decoration.**
		`docs/game/world.md` gives this space ring-counting as the way to
		establish radius, and pairs it with an audio cue at ring boundaries
		that is not built. Milestones were already drawn taller
		(`MILESTONE_HEIGHT_SCALE`), but height is the one channel this
		projection is worst at: everything past a short distance compresses
		toward the disc edge, so a 1.9x column two rings out is barely
		taller on screen than an ordinary one nearby. Value survives that
		compression where height does not.

		Value rather than hue, even though this is doing a signal's job:
		`SIGNAL_MARK` is already spent on the home tile here, and two amber
		things in a space whose whole problem is that you cannot tell where
		you are would be worse than none.
	**/
	static inline final MILESTONE_COLOR:Int = Colours.SURFACE_EDGE;

	/**
		Where the near field starts fading out, in *rendered* units — the
		third scale in this class's own note, not world units and not
		intrinsic ones.

		**Here the fog is the legibility law rather than atmosphere.**
		`world.md` gives this space the Fold's law inverted — *see near, not
		far* — with everything past a short distance compressing into an
		illegible band. Beltrami-Klein already does most of that
		geometrically: hyperbolic distance 1 lands at rendered radius 7.6
		and distance 2 at 9.6, so the far field is crushed against the disc
		edge by the projection itself. Fading that outer shell into the
		backdrop is what turns a crowded, unreadable rim into an honest
		horizon.
	**/
	static inline final FOG_START:Float = 5.0;

	/** Just inside the projection's own disc edge (`HyperbolicProjection.HORIZON`), so nothing is ever drawn crisply at the rim. **/
	static inline final FOG_END:Float = 9.8;

	/** The way out — one of the very few things allowed a signal colour here. **/
	static inline final HOME_COLOR:Int = Colours.SIGNAL_MARK;

	/** Every Nth ring gets taller columns, so counting can be chunked instead of one-at-a-time — coarse milestones over the fine parity banding. **/
	static inline final MILESTONE_RING:Int = 4;

	/** How much taller a milestone ring's columns stand. **/
	static inline final MILESTONE_HEIGHT_SCALE:Float = 1.9;

	final tiling:HyperbolicTiling;
	final space:HyperbolicSpace;

	/** Every face's corners in world hyperbolic coordinates — static geometry, so computed once rather than per frame. Only the *view* changes as the player walks. **/
	final faceCorners:Array<Array<ModelPoint>>;

	/** Base corners of each column, or null for a face without one. Same reasoning as `faceCorners`. **/
	final columnBases:Array<Null<Array<ModelPoint>>>;

	var world:Null<h3d.scene.Object>;

	public function new() {
		tiling = new HyperbolicTiling(7, 3, RINGS);
		space = new HyperbolicSpace(CURVATURE_RADIUS);

		var circumradius = HyperbolicTiling.circumradiusOf(7, 3) * TILE_INSET;
		// Corners sit half a step around from the edge midpoints the generators point at, hence the extra pi/7.
		var cornerOffsets = [
			for (k in 0...7)
				Isometry.compose(Isometry.rotation(k * 2 * Math.PI / 7 + Math.PI / 7), Isometry.translation(Hyperbolic, circumradius))
		];
		var columnOffsets = [
			for (k in 0...4)
				Isometry.compose(Isometry.rotation(k * Math.PI / 2), Isometry.translation(Hyperbolic, COLUMN_RADIUS))
		];

		faceCorners = [];
		columnBases = [];
		for (id in 0...tiling.centers.length) {
			var frame = tiling.frames[id];
			faceCorners.push([
				for (offset in cornerOffsets)
					Isometry.positionOf(Isometry.compose(frame, offset))
			]);
			columnBases.push(hasColumn(id) ? [
				for (offset in columnOffsets)
					Isometry.positionOf(Isometry.compose(frame, offset))
			] : null);
		}
	}

	/** The home tile stays clear — it is the way out, and a spire standing on it would be something to walk around rather than onto. **/
	static function hasColumn(id:Int):Bool {
		return id != 0 && id % COLUMN_EVERY == 1;
	}

	public function id():String {
		return ID;
	}

	public function gravity():Float {
		return GRAVITY;
	}

	/** Cold and dark, against the Fold's own warmth — `docs/game/art-and-audio.md` ties colour temperature to curvature, and this is the first negatively-curved place in the game. **/
	public function backgroundColor():Int {
		return BACKGROUND_COLOR;
	}

	/** What the near field fades into — geometry has to disappear into the same value the backdrop is painted, or the picture separates from its own background. **/
	static inline final BACKGROUND_COLOR:Int = 0x0A1018;

	/**
		Creates the container the per-frame rebuild fills. Nothing is drawn
		here: what a hyperbolic world looks like depends entirely on where
		the player is standing, so there is no view-independent mesh to
		build once (see `rebuild`).
		@param parent the scene object to build under.
	**/
	public function build(parent:h3d.scene.Object):Void {
		world = new h3d.scene.Object(parent);
	}

	/**
		Spawns two cells back from home, facing it. Standing *on* home would
		trigger the exit painting immediately and bounce the player straight
		back to the hub.
		@param returning unused — this biome has no "where you left off" to resume yet.
		@param fromBiomeId unused.
		@return the spawned player, walking in `HyperbolicSpace`.
	**/
	public function spawnPlayer(returning:Bool, fromBiomeId:Null<String>):PlayerModel {
		var home = homePosition();
		var facing = new h3d.Vector(1, 0, 0);
		// walk backwards away from home, so `forward` still points at it
		var backedOff = space.moveAlong(home, facing, facing, -SPAWN_DISTANCE * CURVATURE_RADIUS, CURVATURE_RADIUS);
		return new PlayerModel(backedOff.pos, backedOff.forward, 0, space);
	}

	/** The model origin, scaled the way every position in this biome is — the centre of face `0`, and the way back to the hub. **/
	function homePosition():h3d.Vector {
		return new h3d.Vector(0, 0, CURVATURE_RADIUS);
	}

	/**
		One exit: the home tile.

		**The one exit in biomes 4 and up that still triggers on approach**,
		and it earns that by being drawn — the amber tile at the origin
		(`HOME_COLOR`) is the brightest thing in the biome. The others were
		disarmed because nothing marked them, which made them trapdoors
		rather than exits; see `biomes.turn.TurnBiome.exitPaintings`.

		`PaintingModel.triggeredBy` measures a plain Euclidean distance
		between two `h3d.Vector`s, which is meaningless between two
		arbitrary points of this biome — hyperboloid coordinates are not
		ambient positions. It is **exactly right against this particular
		painting**, though, and that is not luck: every point at hyperbolic
		distance `d` from the model origin has the same Euclidean norm, by
		the rotational symmetry of the hyperboloid about its own axis, so
		Euclidean distance *to the origin* is a strictly increasing function
		of hyperbolic distance to it. A Euclidean threshold there is a
		hyperbolic threshold, and `SprawlBiomeTest` pins that rather than
		leaving it as an argument.

		The threshold itself is converted from one the design can state —
		half the tile's inradius — by the same function, since `4` world
		units of ambient distance would be an arbitrary number here.
		@return the single exit painting, at the home tile.
	**/
	public function exitPaintings():Array<PaintingModel> {
		return [new PaintingModel(homePosition(), DebugHubBiome.ID, homeTriggerRadius())];
	}

	/** The Euclidean radius, in hyperboloid coordinates, of the ball of hyperbolic radius "half a tile's inradius" about the origin — see `exitPaintings`. **/
	function homeTriggerRadius():Float {
		return euclideanRadiusOf(HyperbolicTiling.inradiusOf(7, 3) * 0.5);
	}

	/**
		Euclidean norm, in scaled hyperboloid coordinates, of a point at
		intrinsic distance `intrinsic` from the model origin. Increasing in
		`intrinsic`, which is the whole reason `exitPaintings` can use the
		stock Euclidean trigger at all.
		@param intrinsic hyperbolic distance from the origin, in intrinsic units.
		@return the corresponding Euclidean distance in this biome's own coordinates.
	**/
	public static function euclideanRadiusOf(intrinsic:Float):Float {
		var cosh = (Math.exp(intrinsic) + Math.exp(-intrinsic)) / 2;
		return CURVATURE_RADIUS * Math.sqrt(2 * cosh * (cosh - 1));
	}

	/**
		Walks, unless a column is in the way.

		**Hyperbolic collision, and the reason it could not be inherited.**
		Every other biome's collision measures ordinary ℝ³ distance, which
		between two hyperboloid coordinates is not a distance at all — it
		grows like `cosh` of the real one. This asks `space.distance`
		instead, which is the genuine geodesic metric.

		Blocks rather than slides, unlike `biomes.common.grid.GridCollision`.
		Sliding along an obstacle in hyperbolic space means transporting the
		slide direction correctly, and against sparse round columns the
		difference is barely felt — so it is left until the biome has walls
		worth sliding along, rather than guessed at now.

		Checks every column each step rather than only nearby ones: 1625
		faces yield about 540 columns, and 540 distance evaluations per
		fixed step is nothing. A tiling large enough for that to matter
		needs a spatial index anyway, which is a different piece of work.
		@param player the player to move.
		@param direction unit tangent at `player.pos` to move along.
		@param distance arc length in world units; negative moves the opposite way.
	**/
	public function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		var attempted = space.moveAlong(player.pos, player.forward, direction, distance, CURVATURE_RADIUS);
		if (blocked(attempted.pos)) {
			return;
		}
		player.moveAlong(direction, distance, CURVATURE_RADIUS);
	}

	/** Whether `pos` is inside any column — see `tryMove` for why this measures `space.distance` and not `h3d.Vector` distance. **/
	function blocked(pos:h3d.Vector):Bool {
		var clearance = COLUMN_RADIUS * CURVATURE_RADIUS;
		for (id in 0...tiling.centers.length) {
			if (columnBases[id] == null) {
				continue;
			}
			if (space.distance(pos, worldPositionOf(tiling.centers[id])) < clearance) {
				return true;
			}
		}
		return false;
	}

	/** A tiling point (unit hyperboloid) as a position in this biome's own scaled coordinates. **/
	function worldPositionOf(p:ModelPoint):h3d.Vector {
		return new h3d.Vector(p.x * CURVATURE_RADIUS, p.y * CURVATURE_RADIUS, p.z * CURVATURE_RADIUS);
	}

	/** Height is the Euclidean factor of H²×ℝ, so jumping and falling behave completely normally here — see `HyperbolicSpace.upAt`. **/
	public function applyGravity(player:PlayerModel, dt:Float):Void {
		Gravity.fallToSurface(player, GRAVITY, dt);
	}

	/**
		Rebuilds the visible world around the player.

		This runs one fixed step behind the player's own movement, since
		`GameLoop.fixedUpdate` ticks biomes before it moves anyone. That is
		invisible rather than merely tolerable: the camera does not move in
		this biome *at all*, so the rebuild is the only thing that expresses
		motion, and a uniform one-step delay of everything is not a
		mismatch between two things — it is the whole picture, arriving 16ms
		late. Doing it in `cameraOverride` instead would be correctly timed
		and would make a query mutate the scene graph.
		@param player the player to rebuild around.
		@param dt unused — the rebuild depends on position, not elapsed time.
	**/
	public function tick(player:PlayerModel, dt:Float):Void {
		rebuild(player);
	}

	/**
		Draws every face and column within `DRAW_DISTANCE`, from scratch.

		Wasteful on purpose, and the same trade
		`tools.hyperbolic.HyperbolicWalkApp` documents: the alternative is
		an HxSL vertex shader doing the projection with static geometry,
		which is faster and cannot be verified in this environment at all.
		Keeping the arithmetic in tested Haxe means a wrong-looking world is
		a plumbing bug rather than an unverifiable shader. Port once the
		biome is confirmed to look right.
		@param player the player to build the view around.
	**/
	function rebuild(player:PlayerModel):Void {
		var container = world;
		if (container == null) {
			return; // not built yet — nothing to draw into
		}
		container.removeChildren();

		var view = HyperbolicView.viewOf(player.pos, player.forward, CURVATURE_RADIUS);

		var floorEvenPoints:Array<h3d.Vector> = [];
		var floorEvenIdx = new hxd.IndexBuffer();
		var floorOddPoints:Array<h3d.Vector> = [];
		var floorOddIdx = new hxd.IndexBuffer();
		var columnPoints:Array<h3d.Vector> = [];
		var columnIdx = new hxd.IndexBuffer();
		var milestonePoints:Array<h3d.Vector> = [];
		var milestoneIdx = new hxd.IndexBuffer();
		var homePoints:Array<h3d.Vector> = [];
		var homeIdx = new hxd.IndexBuffer();

		for (id in 0...tiling.centers.length) {
			var center = Isometry.apply(view, tiling.centers[id]);
			if (HyperbolicProjection.distanceFromCamera(center) > DRAW_DISTANCE) {
				continue;
			}

			var isHome = id == 0;
			var evenRing = tiling.rings[id] % 2 == 0;
			var points = isHome ? homePoints : (evenRing ? floorEvenPoints : floorOddPoints);
			var idx = isHome ? homeIdx : (evenRing ? floorEvenIdx : floorOddIdx);

			var corners = [
				for (p in faceCorners[id])
					HyperbolicProjection.toWorld(Isometry.apply(view, p), 0)
			];
			var hub = HyperbolicProjection.toWorld(center, 0);
			for (k in 0...corners.length) {
				MeshBuilder.addTriangle(points, idx, hub, corners[k], corners[(k + 1) % corners.length]);
			}

			var base = columnBases[id];
			if (base != null) {
				var milestone = tiling.rings[id] > 0 && tiling.rings[id] % MILESTONE_RING == 0;
				addColumn(milestone ? milestonePoints : columnPoints, milestone ? milestoneIdx : columnIdx, view, base,
					milestone ? COLUMN_HEIGHT * MILESTONE_HEIGHT_SCALE : COLUMN_HEIGHT);
			}
		}

		addMesh(container, floorEvenPoints, floorEvenIdx, FLOOR_EVEN_COLOR);
		addMesh(container, floorOddPoints, floorOddIdx, FLOOR_ODD_COLOR);
		addMesh(container, columnPoints, columnIdx, COLUMN_COLOR);
		addMesh(container, milestonePoints, milestoneIdx, MILESTONE_COLOR);
		addMesh(container, homePoints, homeIdx, HOME_COLOR);
	}

	/** One column: four side quads plus a cap, from precomputed hyperbolic base corners. **/
	function addColumn(points:Array<h3d.Vector>, idx:hxd.IndexBuffer, view:Isometry, base:Array<ModelPoint>, height:Float):Void {
		var low = [for (p in base) HyperbolicProjection.toWorld(Isometry.apply(view, p), 0)];
		var high = [
			for (p in base)
				HyperbolicProjection.toWorld(Isometry.apply(view, p), height)
		];

		for (k in 0...4) {
			var next = (k + 1) % 4;
			MeshBuilder.addQuad(points, idx, low[k], low[next], high[next], high[k]);
		}
		MeshBuilder.addQuad(points, idx, high[0], high[1], high[2], high[3]);
	}

	function addMesh(parent:h3d.scene.Object, points:Array<h3d.Vector>, idx:hxd.IndexBuffer, color:Int):Void {
		if (points.length == 0) {
			return; // Polygon rejects an empty vertex list, and a fully-culled bucket legitimately produces one
		}
		var mesh = new h3d.scene.Mesh(new h3d.prim.Polygon(points, idx), parent);
		mesh.material.mainPass.addShader(FacetedSurface.from(color, BACKGROUND_COLOR, FOG_START, FOG_END));
		mesh.material.mainPass.culling = None;
	}

	/** Nothing to interact with yet — see `biomes.common.Biome.interact`'s own doc. **/
	public function interact(player:PlayerModel):Void {}

	/**
		The camera, every frame, for as long as the player is here — the
		opposite of every other user of this hook, which returns null except
		during some special mode.

		It never moves. In hyperbolic rendering the world is transformed
		around a camera pinned at the origin (see `rebuild`), so *turning is
		a property of the world here*, not of the camera. Only pitch is an
		actual camera rotation, because height is the Euclidean factor of
		H²×ℝ and behaves normally — which is the same reason jumping works
		without any special handling.
		@param player the player, read for pitch and jump height only.
		@return the pinned camera placement.
	**/
	public function cameraOverride(player:PlayerModel):Null<CameraOverride> {
		var eye = new h3d.Vector(0, EYE_HEIGHT + player.airborneHeight, 0);
		return {
			pos: eye,
			target: new h3d.Vector(eye.x + Math.cos(player.pitch), eye.y + Math.sin(player.pitch), eye.z),
			up: new h3d.Vector(0, 1, 0),
		};
	}

	/** Walking, turning and looking all stay with the player here — see `biomes.common.Biome.capturesInput`'s own doc for why that is a separate question from `cameraOverride`. **/
	public function capturesInput():Bool {
		return false;
	}

	/** Nothing to click on here — see `biomes.common.Biome.onEditClick`'s own doc. **/
	public function onEditClick(ray:h3d.col.Ray):Void {}

	/** No game-speed control here — see `biomes.common.Biome.timeScale`'s own doc. **/
	public function timeScale():Float {
		return 1;
	}

	/** Nothing worth saving yet: the tiling is regenerated identically from `RINGS` — see `biomes.common.Biome.serialize`'s own doc. **/
	public function serialize():String {
		return "{}";
	}

	/** Nothing to restore — see `serialize`. **/
	public function restore(json:String):Void {}
}
