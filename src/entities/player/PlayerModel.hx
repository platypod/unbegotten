package entities.player;

import biomes.common.space.common.Space;
import biomes.common.space.sphere.SphereMath;
import biomes.common.space.sphere.SphereSpace;
import entities.Entity;

/**
	The player's position and facing direction on the maze sphere's interior
	surface, plus a pitch for looking up toward the center. Both `pos` and
	`forward` are plain 3D vectors — not spherical coordinates (theta, phi)
	— updated by direct rotation as the player moves or turns, never
	reconstructed from a (theta, phi) parameterization.

	That's a deliberate fix, not a style choice: (theta, phi) is singular at
	the poles — circles of latitude shrink to zero circumference there, so a
	tiny physical step near a pole corresponds to a huge change in phi, even
	though the actual 3D position barely moved. `facing` used to be a scalar
	angle measured against a tangent basis derived fresh from phi every
	frame (`thetaTangentAt(theta, phi)`), so that phi instability showed up
	as the *view* spinning wildly near a pole — reported directly as
	"pivoting at mach-speed like a spinner" while walking through one.
	Storing `pos`/`forward` as vectors and rotating them directly has no
	such singularity anywhere on the sphere, poles included.

	An `Entity` (CLAUDE.md "Architecture") — the first one, now that
	cross-biome creatures and NPCs are the second use case the foundation
	was deferred pending (see docs/rules/guidelines.md §1.3). Doesn't override
	`onFixedUpdate`: its own movement stays driven by `GameLoop`'s explicit
	input handling, not automatic per-tick behavior, so being an `Entity`
	today only means it can be parented in a `Process` tree — nothing about
	how it moves has changed.

	Rotation math (local "up", moving `pos`/`forward` along a tangent) is
	delegated through `space:Space` rather than hardcoded here — every method
	below still reads as sphere math today because `SphereSpace` is the only
	implementation, but a future biome with a different topology would spawn
	its `PlayerModel` with its own `Space` instead of this class needing to
	know about it.

	Camera placement (`applyToCamera`, `EYE_HEIGHT`) lives on `Camera`, not
	here — this class is the player's own state and movement, not how a
	camera gets derived from it.

	Doesn't re-orthogonalize `pos`/`forward` against accumulated floating-
	point drift over many small rotations — each rotation preserves their
	relationship exactly in theory, and this hasn't shown up as a problem in
	practice. Revisit (e.g. a periodic Gram-Schmidt pass) if it ever does.
**/
class PlayerModel extends Entity {
	/**
		Clamped just short of pi/2: at exactly pi/2 the view direction would
		be exactly parallel to the camera's up vector, which is a degenerate
		lookAt (no well-defined "right"). Visually indistinguishable from a
		true 90 degrees.
	**/
	public static inline final MAX_PITCH:Float = 1.55; // ~88.8 degrees

	/**
		Movement-feel tuning. These four are the whole of "tier 1" — no new
		verb, just making the jump the game already has honest about what
		the player meant. **Starting values, not tuned**: they were chosen
		from platformer convention, and per CLAUDE.md's own note Claude
		cannot drive the game to feel them, so they want a pass by hand.
	**/
	public static inline final COYOTE_TIME:Float = 0.12;

	/** See `COYOTE_TIME`. **/
	public static inline final JUMP_BUFFER_TIME:Float = 0.15;

	/** Fraction of upward speed kept when the jump key is released mid-rise. See `COYOTE_TIME`. **/
	public static inline final JUMP_CUT_FACTOR:Float = 0.45;

	/** Seconds from standing still to full walk speed. See `COYOTE_TIME`. **/
	public static inline final ACCELERATION_TIME:Float = 0.14;

	/** Seconds from full walk speed back to standing still. See `COYOTE_TIME`. **/
	public static inline final DECELERATION_TIME:Float = 0.10;

	/** Position on the sphere's interior surface. **/
	public var pos:h3d.Vector;

	/** Unit tangent vector at `pos`: the horizontal look/walk direction. **/
	public var forward:h3d.Vector;

	/** View tilt from horizontal (0) toward the sphere's center (+MAX_PITCH) or the floor (-MAX_PITCH). **/
	public var pitch:Float;

	/**
		Which biome's topology `pos`/`forward` live in — defaults to
		`SphereSpace`. A biome with a different topology spawns its own
		`PlayerModel` with its own `Space` instead.

		Settable (through `switchSpace`) rather than final, which it used to
		be: `biomes.twosided.TwoSidedBiome` walks the *same* shell from both
		sides, so crossing between them changes nothing about where the player
		is — only which way "up" is from there. Re-spawning a whole
		`PlayerModel` to express that would throw away the position and facing
		that the crossing is supposed to preserve.
	**/
	public var space(default, null):Space;

	/**
		A continuous choice of local "up" at `pos`, used for camera roll,
		turning, and strafing. `space.upAt(pos)` alone is enough on orientable
		surfaces (sphere, plane), but not on the Möbius strip: there, the same
		physical point has two equally valid opposite normals, and
		`MobiusSpace.upAt` necessarily picks one branch discontinuously at the
		seam. Keeping the branch closest to the previous tick's own choice
		preserves a stable local frame while the player walks through that
		wrap.
	**/
	public var surfaceUp:h3d.Vector;

	/**
		Current vertical speed — positive moves away from the ground,
		negative toward it. Shared physics state that any biome's own
		`biomes.common.Biome.applyGravity` integrates every fixed step;
		*where* that motion actually shows up (`airborneHeight` here, or a
		biome tracking real world height in `pos` directly, like the tower)
		is that biome's own concern, not this class's.
	**/
	public var verticalVelocity:Float = 0;

	/**
		Whether the player is currently standing on solid ground, per
		whichever biome's own `biomes.common.Biome.applyGravity` last
		decided. `jump` only takes effect while this is true, so holding the
		key doesn't stack impulses in mid-air.
	**/
	public var grounded(default, set):Bool = true;

	/**
		Seconds of grace left in which a jump still works after walking off
		an edge — "coyote time". Opened by `set_grounded` when the ground
		goes away *without* a jump having caused it, so stepping off a ledge
		stays forgiving while jumping off one does not (that would be a
		silent double jump).
	**/
	var coyoteRemaining:Float = 0;

	/**
		Seconds left for a jump pressed slightly too early to still fire on
		landing. Without this, a press during the last few frames of a fall
		is simply eaten, which reads as the game ignoring input rather than
		as the player being early — the single most common "unresponsive
		controls" complaint in any 3D platformer.
	**/
	var jumpBufferRemaining:Float = 0;

	/** Impulse the buffered jump should fire at, captured at press time. **/
	var bufferedImpulse:Float = 0;

	/**
		Whether releasing the jump key can still cut this jump short. True
		from launch until either the key is released or the rise ends, so
		hold height is continuous rather than one fixed arc — a tap clears a
		low wall, a hold clears a high one, off the same button.
	**/
	var jumpCutAvailable:Bool = false;

	/**
		Eased 0..1 scale on walk speed, ramped by `updateThrottle`. A scalar
		rather than a velocity vector on purpose: a real horizontal momentum
		vector would have to be parallel-transported every time `pos` moves
		on a curved surface (the same problem `moveAlong` solves for
		`forward`), and every biome here is curved. Scaling the existing
		direction-driven movement buys the weight of acceleration without
		introducing a second transported quantity that could drift out of
		the tangent plane.
	**/
	public var throttle(default, null):Float = 0;

	/**
		How far above the surface `pos` sits, along `space.upAt(pos)` — a
		cosmetic offset for a biome whose floor is present everywhere (see
		`biomes.common.Gravity.fallToSurface`), so a jump never has to touch
		`pos` itself and none of the horizontal collision math built against
		a fixed `pos` (e.g. `biomes.common.grid.GridCollision`'s theta/phi
		lookups) needs to change while airborne. A biome with real
		multi-level falling (the tower) tracks height in `pos` directly
		instead and leaves this at 0, unused.
	**/
	public var airborneHeight:Float = 0;

	public function new(pos:h3d.Vector, forward:h3d.Vector, pitch:Float = 0, ?space:Space) {
		super();
		this.pos = pos;
		this.forward = forward;
		this.pitch = clampPitch(pitch);
		this.space = space != null ? space : SphereSpace.INSTANCE;
		this.surfaceUp = this.space.upAt(pos);
	}

	/**
		Builds a PlayerModel standing at a spherical (theta, phi) position,
		facing `facing` radians around from thetaTangentAt (0 = toward
		increasing theta). Only ever used once, at spawn — see the class
		doc for why PlayerModel's own state afterward is plain 3D vectors,
		never theta/phi again.
		@param theta polar angle from +Y, in radians.
		@param phi azimuth around Y, in radians.
		@param facing initial look direction, in radians from thetaTangentAt.
		@param radius sphere radius — must match the biome's physical sphere (see GridGeometry.RADIUS).
		@return a PlayerModel at that position and facing.
	**/
	public static function spawnAt(theta:Float, phi:Float, facing:Float, radius:Float):PlayerModel {
		var spawnPos = SphereMath.sphericalToCartesian(radius, theta, phi);
		var up = SphereMath.upVectorAt(spawnPos, new h3d.Vector(0, 0, 0));
		var spawnForward = SphereMath.rotateAroundAxis(SphereMath.thetaTangentAt(theta, phi), up, facing);
		return new PlayerModel(spawnPos, spawnForward);
	}

	/**
		Adopts a different topology at the same position — for a biome that
		moves the player between two sides of one surface
		(`biomes.twosided.TwoSidedBiome`). `pos` and `forward` are untouched:
		a tangent to the shell is a tangent to it from either side, so the
		player keeps standing exactly where they stood, facing the same way.

		`surfaceUp` is recomputed *without* the sign-continuity check
		`applyMoveResult` applies. That check exists to stop the local frame
		flipping as the player walks (see `surfaceUp`'s own doc), which is
		exactly the opposite of what's wanted here: crossing to the other side
		of a surface is precisely the moment "up" is *supposed* to reverse.
		@param space the topology to adopt.
	**/
	public function switchSpace(space:Space):Void {
		this.space = space;
		this.surfaceUp = space.upAt(pos);
	}

	/**
		Unit tangent to the right of `forward`, ignoring pitch — the same
		computation `Camera.applyTo` already needs for its own pitch-rotation
		axis, exposed here too for strafing (see `GridCollision`), which
		moves sideways without turning to face that direction.
		@return unit tangent at `pos`, perpendicular to `forward`, pointing right.
	**/
	public function rightVector():h3d.Vector {
		return space.rightOf(pos, forward, surfaceUp);
	}

	/**
		Walks forward (or backward, for a negative distance) along
		`forward` — pitch doesn't affect movement. Rotates `pos` and
		`forward` together, by the same angle around the same axis, within
		the great circle they define: exact for any distance (not a
		small-step approximation), and always stays exactly on the sphere
		and tangent to it by construction — including straight through a
		pole, since this never touches theta/phi.
		@param distance arc length to walk; negative walks backward.
		@param radius sphere radius — must match the biome's physical sphere (see GridGeometry.RADIUS).
	**/
	public function moveForward(distance:Float, radius:Float):Void {
		applyMoveResult(space.moveAlong(pos, forward, forward, distance, radius));
	}

	/**
		Translates `pos` by `distance` along `direction` — a unit tangent at
		`pos`, not necessarily `forward`. For sliding along a wall (see
		`GridCollision`), where the player's body gets redirected without
		them actively choosing to turn.

		`forward` is parallel-transported by the same rotation as `pos`
		(exactly like `moveForward` does for its own direction), *not* left
		untouched: `forward` staying a valid unit tangent at `pos` is a hard
		invariant every other method here relies on (`SphereSpace.moveAlong`'s
		own `axis = posDir.cross(direction)`, `Camera.applyTo`'s `right =
		forward.cross(up)`, ...). An earlier version skipped this to keep the
		view from "snapping" during a slide — reasonable-sounding, but it let
		`forward` drift out of the tangent plane over repeated slides, since
		nothing ever re-aligned it to the position's own tangent plane as
		that plane rotated out from under it; a few ticks of sliding was
		enough to visibly break movement (reported directly as gliding that
		"stops working after a really short time"). Transporting it this way
		keeps the angle between `forward` and the slide direction fixed,
		which is the correct minimal adjustment on a curved surface — not a
		re-orientation toward the wall, just what staying tangent costs.
		@param direction unit tangent at `pos` to move along.
		@param distance arc length to move; negative moves the opposite way.
		@param radius sphere radius — must match the biome's physical sphere (see GridGeometry.RADIUS).
	**/
	public function moveAlong(direction:h3d.Vector, distance:Float, radius:Float):Void {
		applyMoveResult(space.moveAlong(pos, forward, direction, distance, radius));
	}

	/**
		Rotates `forward` by `deltaAngle` radians in place; positive turns
		right.

		Delegated through `space` rather than done here, for the same reason
		`moveForward` already is — see `biomes.common.space.common.Space.turn`.
		This used to be `rotateAroundAxis(forward, surfaceUp, deltaAngle)`
		inline, which is exactly what every ambient-ℝ³ space still does
		(`biomes.common.space.common.AmbientFrame`), so the four spaces that
		existed when this moved are unchanged by the move.
		@param deltaAngle angle to turn by, in radians; positive turns right.
	**/
	public function turn(deltaAngle:Float):Void {
		forward = space.turn(pos, forward, surfaceUp, deltaAngle);
	}

	/**
		Tilts `pitch` by `deltaAngle` radians, clamped to +-MAX_PITCH
		(positive looks up, toward the sphere's center).
		@param deltaAngle angle to tilt by, in radians.
	**/
	public function lookUp(deltaAngle:Float):Void {
		pitch = clampPitch(pitch + deltaAngle);
	}

	/**
		Launches the player upward at `impulse` — a no-op unless `grounded`.
		Leaving the ground from here on (gravity's pull, landing) is each
		biome's own `biomes.common.Biome.applyGravity`, not this method's
		concern.
		@param impulse initial upward speed.
	**/
	public function jump(impulse:Float):Void {
		if (!grounded && coyoteRemaining <= 0) {
			return;
		}
		launch(impulse);
	}

	/**
		Handles a jump key *press*: jumps now if that is possible (on the
		ground, or inside the coyote window), and otherwise remembers the
		press for `JUMP_BUFFER_TIME` so it fires the moment the player
		lands.
		@param impulse initial upward speed to launch at.
	**/
	public function requestJump(impulse:Float):Void {
		if (grounded || coyoteRemaining > 0) {
			launch(impulse);
			return;
		}
		jumpBufferRemaining = JUMP_BUFFER_TIME;
		bufferedImpulse = impulse;
	}

	/**
		Handles a jump key *release*: cuts an in-progress rise short, which
		is what makes hold height continuous. Only ever reduces upward
		speed, so releasing while already falling does nothing.
	**/
	public function releaseJump():Void {
		if (!jumpCutAvailable) {
			return;
		}
		jumpCutAvailable = false;
		if (verticalVelocity > 0) {
			verticalVelocity *= JUMP_CUT_FACTOR;
		}
	}

	/**
		Advances the jump timers by one fixed step and fires a buffered jump
		if the player has landed since it was pressed.

		**Must be called after the biome's own `applyGravity`**, not before:
		that is what sets `grounded` for this tick, and a buffered jump is
		precisely a jump that wants to fire on the tick the landing happens
		rather than the one after it.
		@param dt fixed timestep duration, in seconds.
	**/
	public function updateJump(dt:Float):Void {
		if (coyoteRemaining > 0) {
			coyoteRemaining -= dt;
		}
		if (verticalVelocity <= 0) {
			jumpCutAvailable = false;
		}
		if (jumpBufferRemaining > 0) {
			jumpBufferRemaining -= dt;
			if (grounded) {
				jumpBufferRemaining = 0;
				launch(bufferedImpulse);
			}
		}
	}

	/**
		Eases `throttle` toward 1 while a movement key is held and back to 0
		once it is not, so starting and stopping have weight instead of
		snapping between still and full speed.
		@param dt fixed timestep duration, in seconds.
		@param moving whether any movement input is currently held.
	**/
	public function updateThrottle(dt:Float, moving:Bool):Void {
		var rate = moving ? 1 / ACCELERATION_TIME : -1 / DECELERATION_TIME;
		throttle = hxd.Math.clamp(throttle + rate * dt, 0, 1);
	}

	function launch(impulse:Float):Void {
		verticalVelocity = impulse;
		jumpCutAvailable = true;
		// Order matters, and not obviously: assigning `grounded = false`
		// runs `set_grounded`, which opens a coyote window on any
		// ground-to-air transition. Zeroing it has to come *after* that
		// assignment or the jump grants its own window and becomes an
		// unlimited mid-air jump. Pinned by
		// `PlayerModelTest.testJumpIsANoOpWhileAirborne`.
		grounded = false;
		coyoteRemaining = 0;
	}

	function set_grounded(value:Bool):Bool {
		// Only a landing-to-airborne transition the player did not cause by
		// jumping opens the window; `launch` zeroes it immediately after
		// setting this false, so a jump never grants a second one.
		if (grounded && !value) {
			coyoteRemaining = COYOTE_TIME;
		}
		return grounded = value;
	}

	function applyMoveResult(result:{pos:h3d.Vector, forward:h3d.Vector}):Void {
		var previousUp = surfaceUp;
		pos = result.pos;
		forward = result.forward;

		var newUp = space.upAt(pos);
		if (newUp.dot(previousUp) < 0) {
			newUp = newUp.scaled(-1);
		}
		surfaceUp = newUp;
	}

	static function clampPitch(p:Float):Float {
		return hxd.Math.clamp(p, -MAX_PITCH, MAX_PITCH);
	}
}
