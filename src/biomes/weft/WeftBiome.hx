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
import biomes.maze.MazeGenerator;
import biomes.weft.WeftModel.WeftGate;
import entities.painting.PaintingModel;
import graphics.Colours;
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

	**What this reuses, and what that says.** The grid and the collision
	are the maze prototype's, untouched — this space needed no new
	topology, only a rule laid over an existing one. (The exit painting
	was the prototype's too, until it moved onto the antipode of the
	beacon; see `reload`.) The
	render is not reused: `WeftMesh` replaces the prototype's grass and
	stone with this space's own flat, hue-correct dialect, once that
	mismatch with [art-and-audio.md](../../../docs/game/art-and-audio.md)
	was flagged directly ("no... coherence with our new Artistic
	Direction"). What is new, in total: `WeftModel` (the pairing rule and
	the hemisphere generation it now performs), `WeftMesh` (the dialect),
	and the echo.

	**The way out (2026-09-06).** Two objectives, one in each hemisphere:
	a beacon north, and the exit at its exact antipode
	(`WeftModel.beaconNode`/`exitNode`), dead until the beacon has been
	reached. That is the point of the whole space stated as a route —
	**the way you carve north is the way you close south**, so the exit
	you have to walk to is one you have spent the first half of the visit
	demolishing. Before this the exit was wherever a scan happened to put
	it and the pairing rule was a curiosity you could ignore.

	It only works because walls are now mostly *fixed*: see
	`WeftModel.HINGE_SHARE`, raised against the verdict that this space
	"presents no challenge at all since the player can remove pretty much
	all of the walls". A maze in which every wall is a door on demand has
	no structure to plan around, and no route worth closing.

	**The gates (2026-08-18, generalized from a single one the same day).**
	`WeftModel.sealKeystoneGates` seals up to `GATE_COUNT` walls shut; each
	one, unlike every ordinary wall here, refuses to answer `interact`
	directly (this class's own `isLocked`). A gate still obeys the pairing
	rule underneath, so it still opens the instant its antipodal partner
	closes — the player just cannot make that happen standing next to it.
	Asked directly: "I'd like it if the user had to alternate between
	direct view and antipodal view to figure out tricks and find the
	way." The gates no longer gate the exit — see `reload` — so they are
	all side-vaults now, and the friction they were carrying comes from
	`WeftModel.HINGE_SHARE` instead.

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

	/** How close the player must get to the beacon to arm the way out. **/
	static inline final BEACON_REACH:Float = 7.0;

	/** The beacon's own marker, and the exit's: tall enough to read across the sphere's interior, which is this space's whole instrument. **/
	static inline final OBJECTIVE_MARKER_SIZE:Float = 4.2;

	/** See `OBJECTIVE_MARKER_SIZE`. **/
	static inline final OBJECTIVE_MARKER_HEIGHT:Float = 9;

	static inline final SPAWN_THETA:Float = 1.35;
	static inline final SPAWN_PHI:Float = 2.1;
	static inline final SPAWN_FACING:Float = 0.0;

	var maze:GridData;

	/**
		Which of this layout's walls will open for the player — see
		`WeftModel.hingesFor`, which also guarantees the beacon and the exit
		are among the places its hinges can reach.

		Derived, not saved: `reload` recomputes it from the layout, so a
		maze restored from a file gets exactly the hinges it would have had
		when generated.
	**/
	var hinges:Map<String, Bool>;

	/**
		Whether the player has reached the beacon, which is what opens the
		way out.

		Per visit, not persisted: the space's point is the *journey* — the
		route carved north is the route closed south — and arriving already
		armed would skip the half that matters.
	**/
	var beaconReached:Bool = false;

	/** This maze's own sealed gates — see the class doc. Possibly empty, on the rare layout with no valid candidate at all, in which case there are simply no vaults this playthrough; the exit is unaffected either way, see `reload`. **/
	var gates:Array<WeftGate>;

	/** The whole rebuildable world — replaced wholesale whenever a wall is toggled, since a flip changes geometry on two sides of the sphere at once. **/
	var world:Null<h3d.scene.Object>;

	var echo:Null<h3d.scene.Object>;

	public function new(?random:Void->Float) {
		reload(WeftCarver.carve(random));
	}

	/**
		Adopts a layout, forces the opposite-rule invariant onto it, and
		seals up to `GATE_COUNT` vaults behind gates (if this layout has
		valid candidates for any).

		**`enforceOpposite` is still called, and is now a guard rather than
		a generator.** `WeftCarver` produces the invariant by construction,
		so on a freshly carved layout this is a no-op; it earns its place on
		the other path into here, `restore`, which will happily be handed a
		maze file saved from any other biome (see `GameLoop.onMazeFileChosen`)
		and has no reason to trust it.

		**The exit is no longer derived from the layout**; it stands at
		`WeftModel.exitNode`, a fixed cell, and the layout has no say in
		where it is. It used to be placed behind the first keystone gate,
		which made the way out an accident of whichever vault the scan
		happened to find first — and on a layout with no valid candidate at
		all it fell back to `MazeExitWall.find`'s "first closed edge" scan,
		i.e. somewhere arbitrary. Pinning it to the beacon's own antipode is
		what turns this space into one puzzle: the exit is not *found*, it
		is the place your first journey has been quietly closing behind you.
		The gates stay, as ordinary locked walls.
	**/
	function reload(layout:GridData):Void {
		WeftModel.enforceOpposite(layout);
		maze = layout;

		var built:Array<WeftGate> = [];
		for (candidate in WeftModel.sealKeystoneGates(maze, GATE_COUNT)) {
			var gate = WeftModel.gateOf(candidate);
			if (gate != null) {
				built.push(gate);
			}
		}
		gates = built;

		// Last, and after the gates: the gates close walls, so hinges have
		// to be computed against the layout the player will actually meet.
		var locks = new Map<String, Bool>();
		for (gate in gates) {
			locks.set(GridModel.edgeKey(gate.lock.a, gate.lock.b), true);
		}
		hinges = WeftModel.hingesFor(maze, [
			GridModel.nodeAt(SPAWN_THETA, SPAWN_PHI),
			WeftModel.beaconNode(),
			WeftModel.exitNode()
		], locks);
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
		beaconReached = false; // per visit — see the field's own doc
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
		buildObjectiveMarkers(container);
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

	/**
		The beacon and the way out, one in each hemisphere.

		Colour carries their state, which is the only thing the player needs
		to read from across the sphere: the beacon is a thing to reach
		(`Colours.SIGNAL_MARK`, going inert once it has been), the exit is
		refused until then (`Colours.SIGNAL_DENY`) and actionable after
		(`Colours.SIGNAL_ACT`). Marking them at all matters here more than
		elsewhere — this space's own legibility law is that you can see the
		far side, so an objective you cannot see across the interior is an
		objective the space has hidden from its own instrument.

		One batch per marker rather than one for both, for the same reason
		`buildKeystoneMarkers` uses two: a `game.BoxBatch` carries a single
		color, and here the two colors are the whole message.
		@param container the scene node to attach the markers under.
	**/
	function buildObjectiveMarkers(container:h3d.scene.Object):Void {
		addObjectiveMarker(container, WeftModel.beaconNode(), beaconReached ? Colours.SURFACE_EDGE : Colours.SIGNAL_MARK);
		addObjectiveMarker(container, WeftModel.exitNode(), beaconReached ? Colours.SIGNAL_ACT : Colours.SIGNAL_DENY);
	}

	/**
		One objective marker, standing on a cell's own floor.

		Offset *inward* (`sub`, not `add`) like `addKeystoneMarker`: the
		player walks the inside of the sphere, so up from the floor points
		toward the centre, and adding would bury the marker behind the wall
		it stands on.
		@param container the scene node to attach the marker under.
		@param node the cell the marker stands in.
		@param colour the marker's own fill — its state, see `buildObjectiveMarkers`.
	**/
	function addObjectiveMarker(container:h3d.scene.Object, node:GridNode, colour:Int):Void {
		var batch = new game.BoxBatch(container, colour);
		var stand = objectiveCentre(node).sub(objectiveCentre(node).normalized().scaled(OBJECTIVE_MARKER_HEIGHT));
		batch.add(stand.x, stand.z, OBJECTIVE_MARKER_SIZE, OBJECTIVE_MARKER_SIZE, stand.y, OBJECTIVE_MARKER_HEIGHT);
		batch.flush();
	}

	/**
		Where a cell sits in the world — its own centre, on the sphere.
		@param node the cell to place.
		@return that cell's centre as a world position.
	**/
	static function objectiveCentre(node:GridNode):h3d.Vector {
		var centre = GridModel.centerOf(node);
		return SphereMath.sphericalToCartesian(GridGeometry.RADIUS, centre.theta, centre.phi);
	}

	public function spawnPlayer(returning:Bool, fromBiomeId:Null<String>):PlayerModel {
		return returning ? playerAtExit() : PlayerModel.spawnAt(SPAWN_THETA, SPAWN_PHI, SPAWN_FACING, GridGeometry.RADIUS);
	}

	/**
		The one way out, standing at `WeftModel.exitNode`.

		**Always returned, but only live once the beacon has been reached.**
		Two different things are being said: the painting exists at all times
		so the debug leave key (`game.Keybinds.LEAVE_BIOME`) has somewhere to
		send a developer, and `triggersOnApproach` carries the actual rule —
		before the beacon, walking onto the exit does nothing, which is what
		the red marker there has been saying. Returning `[]` instead would
		have conflated the two and taken the escape hatch away with it.
	**/
	public function exitPaintings():Array<PaintingModel> {
		return [
			new PaintingModel(objectiveCentre(WeftModel.exitNode()), HubBiome.ID, null, beaconReached)
		];
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
		checkBeacon(player);
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
		Arms the way out once the player stands at the beacon.

		Rebuilds on the transition, since both markers change colour at that
		moment — the beacon goes inert and the exit goes from refused to
		actionable. Once only: `beaconReached` short-circuits every later
		tick, so this is a distance test and nothing more for the rest of
		the visit.
		@param player the player to test against the beacon.
	**/
	function checkBeacon(player:PlayerModel):Void {
		if (beaconReached) {
			return;
		}
		if (player.pos.sub(objectiveCentre(WeftModel.beaconNode())).length() <= BEACON_REACH) {
			beaconReached = true;
			rebuild();
		}
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
		// Most walls are simply walls now. When every one was a door the
		// maze had no structure at all — see `WeftModel.HINGE_SHARE`.
		if (!WeftModel.isHinged(hinges, here, facing)) {
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

	/**
		Where a returning player lands: the exit cell itself, since that is
		where they left from.

		Simpler than `biomes.maze.MazeBiome.playerInFrontOfExitWall`, which
		has to step *off* a wall and re-tangent its forward vector — the
		Weft's exit is a cell rather than a wall, so `PlayerModel.spawnAt`
		already does the whole job.
	**/
	function playerAtExit():PlayerModel {
		var centre = GridModel.centerOf(WeftModel.exitNode());
		return PlayerModel.spawnAt(centre.theta, centre.phi, SPAWN_FACING, GridGeometry.RADIUS);
	}
}
