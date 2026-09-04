package entities.player;

import biomes.common.space.mobius.MobiusMath;
import biomes.common.space.mobius.MobiusSpace;
import utest.Test;
import utest.Assert;
import biomes.common.space.sphere.SphereMath;

/** Covers PlayerModel's pure movement/pitch math — see CameraTest for its composition into a camera. **/
class PlayerModelTest extends Test {
	function testTurnRotatesForwardByDeltaAngle():Void {
		var player = PlayerModel.spawnAt(1, 0, 0, 1);
		var oldForward = player.forward;

		player.turn(0.5);

		Assert.floatEquals(Math.cos(0.5), oldForward.dot(player.forward), 1e-9);
		Assert.floatEquals(1, player.forward.length(), 1e-9);
		Assert.floatEquals(0, player.pos.normalized().dot(player.forward), 1e-9);
	}

	function testRightVectorIsUnitAndPerpendicularToForwardAndUp():Void {
		var radius = 50.0;
		var player = PlayerModel.spawnAt(1.1, 2.2, 0.7, radius);

		var right = player.rightVector();

		Assert.floatEquals(1, right.length(), 1e-9);
		Assert.floatEquals(0, right.dot(player.forward), 1e-9);
		Assert.floatEquals(0, player.pos.normalized().dot(right), 1e-9);
	}

	function testMoveForwardAlongAMeridianMatchesArcLength():Void {
		// facing 0 at any point looks toward increasing theta (see
		// PlayerModel.spawnAt's doc comment), so from the equator this walks a
		// meridian — an exact great circle — where arc length is just
		// radius*angle.
		var radius = 1.0;
		var player = PlayerModel.spawnAt(Math.PI / 2, 0, 0, radius);

		player.moveForward(0.3, radius);

		var theta = Math.acos(player.pos.y / radius);
		var phi = Math.atan2(player.pos.z, player.pos.x);
		Assert.floatEquals(Math.PI / 2 + 0.3, theta, 1e-9);
		Assert.floatEquals(0, phi, 1e-9);
	}

	function testMoveBackwardDecreasesTheta():Void {
		var radius = 1.0;
		var player = PlayerModel.spawnAt(Math.PI / 2, 0, 0, radius);

		player.moveForward(-0.3, radius);

		var theta = Math.acos(player.pos.y / radius);
		Assert.floatEquals(Math.PI / 2 - 0.3, theta, 1e-9);
	}

	function testMoveForwardStaysOnTheSphereAndTangent():Void {
		var radius = 50.0;
		var player = PlayerModel.spawnAt(1.1, 2.2, 0.7, radius);

		player.moveForward(4, radius);

		Assert.floatEquals(radius, player.pos.length(), 1e-9);
		Assert.floatEquals(1, player.forward.length(), 1e-9);
		Assert.floatEquals(0, player.pos.normalized().dot(player.forward), 1e-9);
	}

	function testMoveAlongMatchesArcLength():Void {
		var radius = 50.0;
		var player = PlayerModel.spawnAt(1.1, 2.2, 0.7, radius);
		var oldPosDir = player.pos.normalized();
		var direction = SphereMath.upVectorAt(player.pos, new h3d.Vector(0, 0, 0)).cross(player.forward).normalized();

		player.moveAlong(direction, 4, radius);

		Assert.floatEquals(radius, player.pos.length(), 1e-9);
		var angle = Math.acos(hxd.Math.clamp(oldPosDir.dot(player.pos.normalized()), -1, 1));
		Assert.floatEquals(4 / radius, angle, 1e-9);
	}

	function testMoveAlongKeepsForwardTangent():Void {
		// forward isn't left untouched — it's parallel-transported by the
		// same rotation as pos, same as moveForward does for its own
		// direction. That's what keeps it a valid tangent after the move
		// (skipping this let forward drift out of the tangent plane over
		// repeated slides, breaking movement after a few ticks — see
		// PlayerModel.moveAlong's doc comment).
		var radius = 50.0;
		var player = PlayerModel.spawnAt(1.1, 2.2, 0.7, radius);
		var direction = SphereMath.upVectorAt(player.pos, new h3d.Vector(0, 0, 0)).cross(player.forward).normalized();

		player.moveAlong(direction, 4, radius);

		Assert.floatEquals(1, player.forward.length(), 1e-9);
		Assert.floatEquals(0, player.pos.normalized().dot(player.forward), 1e-9);
	}

	function testMoveAlongStaysTangentAfterManyConsecutiveSlides():Void {
		// The exact reported bug: repeated sliding (many fixed-timestep
		// ticks in a row, same shape as Collision calling moveAlong every
		// frame while a player holds into a wall at an angle) used to drift
		// forward out of the tangent plane, since nothing ever re-aligned it
		// as the tangent plane itself rotated out from under a frozen
		// forward. 50 consecutive slides is well past where that drift
		// became visible in practice.
		var radius = 50.0;
		var player = PlayerModel.spawnAt(1.1, 2.2, 0.7, radius);

		for (_ in 0...50) {
			var direction = SphereMath.upVectorAt(player.pos, new h3d.Vector(0, 0, 0)).cross(player.forward).normalized();
			player.moveAlong(direction, 2, radius);
		}

		Assert.floatEquals(1, player.forward.length(), 1e-6);
		Assert.floatEquals(0, player.pos.normalized().dot(player.forward), 1e-6);
	}

	function testMoveForwardIgnoresPitch():Void {
		// WASD-style movement stays on the ground regardless of where the
		// camera is looking — same as any FPS.
		var radius = 1.0;
		var level = PlayerModel.spawnAt(Math.PI / 2, 0, 0, radius);
		var lookingUp = PlayerModel.spawnAt(Math.PI / 2, 0, 0, radius);
		lookingUp.lookUp(1.0);

		level.moveForward(0.3, radius);
		lookingUp.moveForward(0.3, radius);

		Assert.floatEquals(level.pos.x, lookingUp.pos.x, 1e-9);
		Assert.floatEquals(level.pos.y, lookingUp.pos.y, 1e-9);
		Assert.floatEquals(level.pos.z, lookingUp.pos.z, 1e-9);
	}

	function testMoveForwardNearPoleDoesNotSpin():Void {
		// The reported bug: (theta, phi) is singular at the poles — a tiny
		// physical step near one used to correspond to a huge change in
		// phi, and since the old "facing" was measured against a tangent
		// basis derived fresh from phi every frame, that instability showed
		// up as the view spinning wildly ("mach-speed... like a spinner")
		// while walking through a pole. This representation never touches
		// theta/phi, so forward should rotate by exactly the arc angle
		// traveled, pole or not — no more, no less.
		var radius = 50.0;
		var player = PlayerModel.spawnAt(0.05, 0.7, Math.PI, radius); // facing toward the north pole
		var oldForward = player.forward;

		var distance = 3.0; // crosses right through theta=0
		player.moveForward(distance, radius);

		var angle = distance / radius;
		Assert.floatEquals(Math.cos(angle), oldForward.dot(player.forward), 1e-9);
		Assert.floatEquals(1, player.forward.length(), 1e-9);
		Assert.floatEquals(radius, player.pos.length(), 1e-9);
		Assert.floatEquals(0, player.pos.normalized().dot(player.forward), 1e-9);
	}

	function testLookUpClampsToMaxPitch():Void {
		var player = PlayerModel.spawnAt(1, 0, 0, 1);

		player.lookUp(100);

		Assert.floatEquals(PlayerModel.MAX_PITCH, player.pitch);
	}

	function testLookDownClampsToMinusMaxPitch():Void {
		var player = PlayerModel.spawnAt(1, 0, 0, 1);

		player.lookUp(-100);

		Assert.floatEquals(-PlayerModel.MAX_PITCH, player.pitch);
	}

	function testJumpSetsVerticalVelocityAndClearsGroundedWhileGrounded():Void {
		var player = PlayerModel.spawnAt(1, 0, 0, 1);

		player.jump(18);

		Assert.floatEquals(18, player.verticalVelocity);
		Assert.isFalse(player.grounded);
	}

	function testJumpIsANoOpWhileAirborne():Void {
		// Holding the jump key shouldn't stack impulses mid-air.
		var player = PlayerModel.spawnAt(1, 0, 0, 1);
		player.jump(18);

		player.jump(30);

		Assert.floatEquals(18, player.verticalVelocity);
	}

	function testMoveForwardAcrossMobiusSeamKeepsSurfaceUpContinuous():Void {
		var twists = 3;
		var beforeU = 2 * Math.PI - 0.02;
		var startV = 30.0;
		var pos = MobiusMath.pointAt(beforeU, startV, twists, 50);
		var frame = MobiusMath.localFrameAt(beforeU, startV, twists, 50);
		var player = new PlayerModel(pos, frame.tu, 0, new MobiusSpace(twists, 50));
		var oldUp = player.surfaceUp;

		player.moveForward(2, 50);

		Assert.isTrue(oldUp.dot(player.surfaceUp) > 0.99);
		Assert.isTrue(player.surfaceUp.dot(player.space.upAt(player.pos)) < -0.99);
	}

	// ------------------------------------------------------------------
	// Jump feel (coyote time, buffering, variable height, throttle).
	// None of this is visible in a screenshot and all of it is timing, so
	// it is pinned here rather than left to be felt — the numbers can be
	// retuned freely, but the *rules* below are what "responsive" means.
	// ------------------------------------------------------------------

	function freshPlayer():PlayerModel {
		return PlayerModel.spawnAt(1, 0, 0, 50);
	}

	function testWalkingOffAnEdgeStillAllowsAJumpInsideTheCoyoteWindow():Void {
		var player = freshPlayer();
		player.grounded = false; // stepped off, did not jump

		player.updateJump(PlayerModel.COYOTE_TIME * 0.5);
		player.requestJump(18);

		Assert.isTrue(player.verticalVelocity > 0, "a jump just after leaving the ground should still fire");
	}

	function testTheCoyoteWindowCloses():Void {
		var player = freshPlayer();
		player.grounded = false;

		player.updateJump(PlayerModel.COYOTE_TIME * 2);
		player.requestJump(18);

		Assert.floatEquals(0, player.verticalVelocity, 1e-9);
	}

	function testJumpingDoesNotItselfOpenACoyoteWindow():Void {
		// Otherwise the window would grant a silent second jump in mid-air,
		// which is a different mechanic entirely and not one we chose.
		var player = freshPlayer();

		player.requestJump(18);
		var afterFirst = player.verticalVelocity;
		player.updateJump(PlayerModel.COYOTE_TIME * 0.5);
		// A *different* impulse, deliberately: reusing 18 here made this
		// test pass against a launch() that did grant itself a window,
		// since the second jump wrote back the same number.
		player.requestJump(30);

		Assert.floatEquals(afterFirst, player.verticalVelocity, 1e-9);
	}

	function testAJumpPressedJustBeforeLandingFiresOnLanding():Void {
		var player = freshPlayer();
		player.grounded = false;
		player.updateJump(PlayerModel.COYOTE_TIME * 2); // well past coyote

		player.requestJump(18); // too early — buffered, not fired
		Assert.floatEquals(0, player.verticalVelocity, 1e-9);

		player.grounded = true; // the biome's applyGravity lands them
		player.updateJump(1 / 60.0);

		Assert.isTrue(player.verticalVelocity > 0, "a buffered jump should fire on landing");
	}

	function testABufferedJumpExpires():Void {
		var player = freshPlayer();
		player.grounded = false;
		player.updateJump(PlayerModel.COYOTE_TIME * 2);

		player.requestJump(18);
		player.updateJump(PlayerModel.JUMP_BUFFER_TIME * 2);
		player.grounded = true;
		player.updateJump(1 / 60.0);

		Assert.floatEquals(0, player.verticalVelocity, 1e-9);
	}

	function testReleasingTheKeyMidRiseCutsTheJumpShort():Void {
		var player = freshPlayer();
		player.requestJump(18);
		var full = player.verticalVelocity;

		player.releaseJump();

		Assert.floatEquals(full * PlayerModel.JUMP_CUT_FACTOR, player.verticalVelocity, 1e-9);
	}

	function testReleasingTheKeyWhileFallingDoesNotSpeedTheFall():Void {
		var player = freshPlayer();
		player.requestJump(18);
		player.verticalVelocity = -5; // already descending

		player.releaseJump();

		Assert.floatEquals(-5, player.verticalVelocity, 1e-9);
	}

	function testThrottleRampsUpAndBackDownWithinItsOwnTimes():Void {
		var player = freshPlayer();
		Assert.floatEquals(0, player.throttle, 1e-9);

		player.updateThrottle(PlayerModel.ACCELERATION_TIME, true);
		Assert.floatEquals(1, player.throttle, 1e-9);

		player.updateThrottle(PlayerModel.DECELERATION_TIME, false);
		Assert.floatEquals(0, player.throttle, 1e-9);
	}

	function testThrottleNeverLeavesTheZeroToOneRange():Void {
		var player = freshPlayer();

		player.updateThrottle(10, true);
		Assert.floatEquals(1, player.throttle, 1e-9);

		player.updateThrottle(10, false);
		Assert.floatEquals(0, player.throttle, 1e-9);
	}
}
