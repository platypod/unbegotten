package biomes.weft;

import biomes.common.Biome;
import biomes.common.Gravity;
import biomes.common.grid.GridCollision;
import biomes.common.grid.GridGeometry;
import biomes.common.grid.GridModel;
import biomes.common.grid.GridModel.GridData;
import biomes.common.grid.GridModel.GridNode;
import biomes.common.space.sphere.SphereMath;
import biomes.hub.HubBiome;
import biomes.maze.MazeExitWall;
import biomes.maze.MazeExitWall.FoundWall;
import biomes.maze.MazeGenerator;
import biomes.weft.WeftModel.WeftGate;
import entities.painting.PaintingModel;
import entities.player.Camera.CameraOverride;
import entities.player.PlayerModel;

/**
	**The Weft** — an ordinary sphere, wired to itself. See
	[the design](../../../docs/game/world.md)'s
	own entry (`### 2. The Weft`).

	Every wall answers to the wall at its antipode and the two are always
	in opposite states, so **closing the door in front of you opens one on
	the far side of the world** — see `WeftModel`, which holds the rule and
	the geometry that limits where it can apply, including *how* the
	invariant is generated: the northern hemisphere is carved freely and
	the southern hemisphere is forced to its exact opposite, which is what
	makes the far side read as a legible negative rather than an unrelated
	tangle — see `WeftModel.enforceOpposite`'s own doc.

	**Not the Fold's sphere**, despite an earlier version of this comment
	claiming it was: this reuses `biomes.common.grid` and `biomes.maze`,
	the lat/long grid and generic spanning-tree maze that predate
	[the direction](../../../docs/game/world.md) entirely (see that
	document's own note on which biomes are pre-direction) — not
	`biomes.conway`, the icosahedral automaton sphere the numbered Fold
	actually is. Both are κ>0 spheres, which is the sense in which "the
	same sphere" was true; the geometry, generator and (until `WeftMesh`)
	the render were the maze prototype's, not the Fold's.

	**The echo.** The design gives this space a legibility law: look toward
	your own antipode and see a reflection of what is there, so you can
	read the far side of a pairing without walking to it. Here that is a
	pale marker standing at `-pos`, moving as the player moves, passing
	through walls it has no business colliding with — settled as "phase
	through," which is what makes it an image rather than a second body.
	It is the instrument the whole space is read with: act on a wall,
	watch the echo's surroundings change.

	**What this reuses, and what that says.** The grid, the collision and
	the exit painting are the maze prototype's, untouched — this space
	needed no new topology, only a rule laid over an existing one. The
	render is not reused: `WeftMesh` replaces the prototype's grass and
	stone with this space's own flat, hue-correct dialect, once that
	mismatch with [art-and-audio.md](../../../docs/game/art-and-audio.md)
	was flagged directly ("no... coherence with our new Artistic
	Direction"). What is new, in total: `WeftModel` (the pairing rule and
	the hemisphere generation it now performs), `WeftMesh` (the dialect),
	and the echo.

	**The gates (2026-08-18, generalized from a single one the same day).**
	`WeftModel.sealKeystoneGates` seals up to `GATE_COUNT` walls shut; each
	one, unlike every ordinary wall here, refuses to answer `interact`
	directly (this class's own `isLocked`). A gate still obeys the pairing
	rule underneath, so it still opens the instant its antipodal partner
	closes — the player just cannot make that happen standing next to it.
	The exit painting moves into the first gate's now-reachable vault, so
	leaving the Weft at all requires solving *that one* once; any further
	gates are optional side-vaults, not additional exit requirements.
	Asked directly: "I'd like it if the user had to alternate between
	direct view and antipodal view to figure out tricks and find the
	way."

	**Made "too obvious" on purpose, for now** (asked directly, to be
	revisited toward something subtler once the mechanic itself is
	proven out): each gate's lock and partner walls render in flat
	stop/go red and green (`WeftMesh`'s own `Colours.WEFT_GATE_LOCK`/
	`WEFT_GATE_KEY`, standing apart from the uniform Fold-cyan everywhere
	else), and two beacons of the same two colors
	(`buildKeystoneMarkers`) mark both ends even while a wall isn't
	currently rendered there (an open partner has no wall panel to color,
	same as any open edge) — visible from across the sphere the same way
	any other distant geometry is, the Fold's own "raise your head"
	legibility, not a new instrument.
**/
class WeftBiome implements Biome {
	public static inline final ID:String = "weft";

	/** Same first-pass value as the maze's — see `biomes.hub.HubBiome.GRAVITY`'s own doc for why each biome states its own. **/
	static inline final GRAVITY:Float = 60;

	/** How far above the far surface the echo floats, so it reads against the floor rather than z-fighting with it. **/
	static inline final ECHO_HEIGHT:Float = 4;

	static inline final ECHO_SIZE:Float = 3.2;

	/** Pale, and the brightest thing in the biome — value, not hue, since hue belongs to curvature. **/
	static inline final ECHO_COLOR:Int = 0xF0ECE2;

	/** Half-extent of one `buildKeystoneMarkers` beacon — a touch larger than the echo (`ECHO_SIZE`), since a beacon has to read from across the sphere rather than up close. **/
	static inline final KEYSTONE_MARKER_SIZE:Float = 3.6;

	/** How far above the floor a beacon floats — same reasoning as `ECHO_HEIGHT`. **/
	static inline final KEYSTONE_MARKER_HEIGHT:Float = 5;

	/** How many gates `WeftModel.sealKeystoneGates` tries to place — untuned, a reasonable first guess ("several tricky moments," not one) rather than a measured value; the maze may legitimately end up with fewer, see that function's own doc. **/
	static inline final GATE_COUNT:Int = 3;

	static inline final SPAWN_THETA:Float = 1.35;
	static inline final SPAWN_PHI:Float = 2.1;
	static inline final SPAWN_FACING:Float = 0.0;

	/** See `biomes.maze.MazeBiome.RETURN_SPAWN_OFFSET` — same reason, same value. **/
	static inline final RETURN_SPAWN_OFFSET:Float = 6;

	var maze:GridData;
	var exitWall:FoundWall;

	/** This maze's own sealed gates — see the class doc. Possibly empty, on the rare layout with no valid candidate at all, in which case there is no puzzle this playthrough and `exitWall` falls back to `MazeExitWall.find`'s ordinary scan. **/
	var gates:Array<WeftGate>;

	/** The whole rebuildable world — replaced wholesale whenever a wall is toggled, since a flip changes geometry on two sides of the sphere at once. **/
	var world:Null<h3d.scene.Object>;

	var echo:Null<h3d.scene.Object>;

	public function new(?random:Void->Float) {
		reload(MazeGenerator.generate(random));
	}

	/**
		Adopts a layout, forces the opposite-rule invariant onto it, seals
		up to `GATE_COUNT` vaults behind gates (if this layout has valid
		candidates for any), and re-derives the exit.
	**/
	function reload(layout:GridData):Void {
		WeftModel.enforceOpposite(layout);
		maze = layout;

		var candidates = WeftModel.sealKeystoneGates(maze, GATE_COUNT);
		if (candidates.length == 0) {
			gates = [];
			exitWall = MazeExitWall.find(maze);
			return;
		}

		var built:Array<WeftGate> = [];
		for (candidate in candidates) {
			var gate = WeftModel.gateOf(candidate);
			if (gate != null) {
				built.push(gate);
			}
		}
		gates = built;

		var exit = candidates[0];
		exitWall = MazeExitWall.wallAt(exit.vaultRow, exit.vaultCol,
			!exit.lockIsWest); // the first vault's other west/east side — guaranteed closed, since the vault was a leaf with only the lock side open. Only this one gate gates the exit; any further gates are optional side-vaults.
	}

	public function id():String {
		return ID;
	}

	public function gravity():Float {
		return GRAVITY;
	}

	/** The Fold's own background (`biomes.conway.ConwayBiome.BACKGROUND_COLOR`) — matched here alongside `WeftMesh`'s own floor/wall dialect swap (2026-08-17), so the ambient tone agrees with the now-cold geometry instead of the old warm amber dialect it was tuned for. **/
	public function backgroundColor():Int {
		return biomes.conway.ConwayBiome.BACKGROUND_COLOR;
	}

	public function build(parent:h3d.scene.Object):Void {
		world = new h3d.scene.Object(parent);
		echo = buildEcho(parent);
		rebuild();
	}

	/** A small pale block standing at the player's antipode — see the class doc on why it is an image and not a body. **/
	function buildEcho(parent:h3d.scene.Object):h3d.scene.Object {
		var container = new h3d.scene.Object(parent);
		var batch = new game.BoxBatch(container, ECHO_COLOR);
		batch.add(0, 0, ECHO_SIZE, ECHO_SIZE, 0, ECHO_SIZE * 2);
		batch.flush();
		return container;
	}

	function rebuild():Void {
		var container = world;
		if (container == null) {
			return; // not built yet
		}
		container.removeChildren();
		WeftMesh.build(maze, container, gates);
		buildKeystoneMarkers(container);
	}

	/**
		Two beacons per gate marking its own two ends — the sealed vault's
		lock (red, `Colours.WEFT_GATE_LOCK`) and the far wall that actually
		answers to it (green, `Colours.WEFT_GATE_KEY`) — same colors
		`WeftMesh`'s own gate walls use, so a beacon and its wall read as
		one thing once a player is close enough to see both. Unlike `echo`,
		none of these move, so they're built once per `rebuild` alongside
		the walls rather than tracked per-frame. Two batches, not one: a
		`game.BoxBatch` is one color for its whole batch, and lock/key are
		deliberately different colors.
		@param container the scene node to attach the beacons under.
	**/
	function buildKeystoneMarkers(container:h3d.scene.Object):Void {
		var lockBatch = new game.BoxBatch(container, graphics.Colours.WEFT_GATE_LOCK);
		var keyBatch = new game.BoxBatch(container, graphics.Colours.WEFT_GATE_KEY);
		for (gate in gates) {
			addKeystoneMarker(lockBatch, gate.lock.a, gate.lock.b);
			addKeystoneMarker(keyBatch, gate.partner.a, gate.partner.b);
		}
		lockBatch.flush();
		keyBatch.flush();
	}

	/** One beacon, floating at a wall's own midpoint — `a`/`b` need not be in west/east order, only their shared wall's location matters. **/
	function addKeystoneMarker(batch:game.BoxBatch, a:GridNode, b:GridNode):Void {
		var sides = WeftModel.edgeSidesOf(a, b);
		var wall = MazeExitWall.wallAt(sides.aSide.row, sides.aSide.col, sides.aSide.west);
		var mid = wall.a.add(wall.b).scaled(0.5);
		var outward = mid.normalized();
		var stand = mid.sub(outward.scaled(KEYSTONE_MARKER_HEIGHT));
		batch.add(stand.x, stand.z, KEYSTONE_MARKER_SIZE, KEYSTONE_MARKER_SIZE, stand.y, KEYSTONE_MARKER_SIZE * 2);
	}

	public function spawnPlayer(returning:Bool, fromBiomeId:Null<String>):PlayerModel {
		return returning ? playerInFrontOfExitWall() : PlayerModel.spawnAt(SPAWN_THETA, SPAWN_PHI, SPAWN_FACING, GridGeometry.RADIUS);
	}

	public function exitPaintings():Array<PaintingModel> {
		return [new PaintingModel(PaintingModel.midpointOf(exitWall.a, exitWall.b), HubBiome.ID)];
	}

	public function tryMove(player:PlayerModel, direction:h3d.Vector, distance:Float):Void {
		GridCollision.tryMove(player, direction, distance, GridGeometry.RADIUS, maze);
	}

	public function applyGravity(player:PlayerModel, dt:Float):Void {
		Gravity.fallToSurface(player, GRAVITY, dt);
	}

	/**
		Keeps the echo standing at the player's antipode.

		`-pos` is the antipode of a point on a sphere centred at the
		origin, which is the whole computation — no transform needed,
		because nothing here is glued and the antipode is an ordinary
		place.
		@param player the player to mirror.
		@param dt unused — the echo has no dynamics of its own.
	**/
	public function tick(player:PlayerModel, dt:Float):Void {
		var marker = echo;
		if (marker == null) {
			return;
		}
		var opposite = player.pos.scaled(-1);
		var outward = opposite.normalized();
		var stand = opposite.sub(outward.scaled(ECHO_HEIGHT));
		marker.setPosition(stand.x, stand.y, stand.z);
	}

	/**
		Flips the wall the player is facing, and its partner with it.

		Picks the neighbouring cell whose own direction best matches where
		the player is looking, rather than the nearest wall by distance:
		standing in a corner, "nearest" is ambiguous and "the one I am
		looking at" is not. A wall with no partner (see `WeftModel`) does
		not move — the rule is the only thing that gives the player any
		purchase here, and a wall outside it is simply scenery. Neither does
		`lock` — see `isLocked`'s own doc.
		@param player the player acting.
	**/
	public function interact(player:PlayerModel):Void {
		var here = GridModel.nodeAt(SphereMath.thetaOf(player.pos), SphereMath.phiOf(player.pos));
		var facing = mostFacedNeighbor(player, here);
		if (facing == null || isLocked(here, facing)) {
			return;
		}
		if (WeftModel.toggle(maze, here, facing)) {
			rebuild();
		}
	}

	/**
		Whether `a`-`b` is any gate's own lock — a wall the player cannot
		open by standing next to it, only by finding and toggling its
		antipodal partner instead (`WeftModel.toggle` still flips it then,
		same as any other paired wall — this only blocks *this specific
		edge* from `interact`, not the pairing rule itself). A gate's
		*partner* edge is deliberately not checked here: it's an ordinary,
		freely-toggleable wall, just a colored one.
	**/
	function isLocked(a:GridNode, b:GridNode):Bool {
		var key = GridModel.edgeKey(a, b);
		for (gate in gates) {
			if (GridModel.edgeKey(gate.lock.a, gate.lock.b) == key) {
				return true;
			}
		}
		return false;
	}

	/** Which neighbour of `here` the player is looking most directly toward. **/
	function mostFacedNeighbor(player:PlayerModel, here:GridNode):Null<GridNode> {
		var best:Null<GridNode> = null;
		var bestAlignment = 0.0;

		for (neighbor in GridModel.neighborsOf(here)) {
			var centre = GridModel.centerOf(neighbor);
			var towards = SphereMath.sphericalToCartesian(GridGeometry.RADIUS, centre.theta, centre.phi).sub(player.pos);
			var alignment = towards.normalized().dot(player.forward);
			if (alignment > bestAlignment) {
				bestAlignment = alignment;
				best = neighbor;
			}
		}
		return best;
	}

	/** No camera override here — see `biomes.common.Biome.cameraOverride`'s own doc. **/
	public function cameraOverride(player:PlayerModel):Null<CameraOverride> {
		return null;
	}

	/** Never captures input — see `biomes.common.Biome.capturesInput`'s own doc. **/
	public function capturesInput():Bool {
		return false;
	}

	/** Nothing to click on here — see `biomes.common.Biome.onEditClick`'s own doc. **/
	public function onEditClick(ray:h3d.col.Ray):Void {}

	/** No game-speed control here — see `biomes.common.Biome.timeScale`'s own doc. **/
	public function timeScale():Float {
		return 1;
	}

	public function serialize():String {
		return MazeGenerator.serialize(maze);
	}

	/** Restores a layout *and* re-imposes the opposite rule on it — an imported maze has no reason to already satisfy it. **/
	public function restore(json:String):Void {
		reload(MazeGenerator.deserialize(json));
		rebuild();
	}

	/** See `biomes.maze.MazeBiome.playerInFrontOfExitWall` — same construction, same reasoning about re-tangenting `forward`. **/
	function playerInFrontOfExitWall():PlayerModel {
		var mid = PaintingModel.midpointOf(exitWall.a, exitWall.b);
		var intoRoom = exitWall.cellCenter.sub(mid).normalized();
		var pos = mid.add(intoRoom.scaled(RETURN_SPAWN_OFFSET)).normalized().scaled(GridGeometry.RADIUS);

		var posDir = pos.normalized();
		var forward = intoRoom.sub(posDir.scaled(intoRoom.dot(posDir))).normalized();
		return new PlayerModel(pos, forward);
	}
}
