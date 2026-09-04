package biomes.weft;

import biomes.common.grid.GridMesh;
import biomes.common.grid.GridModel;
import biomes.common.grid.GridModel.GridData;
import biomes.common.grid.GridModel.GridNode;
import biomes.weft.WeftModel.EdgeSide;
import biomes.weft.WeftModel.WeftGate;
import graphics.Colours;
import graphics.shaders.ConwayWallGlow;

/**
	The Weft's own floor and walls — built from `GridMesh`'s verified
	geometry (`buildFloorPrim`, `buildWallPrim`: the same corner and
	row-boundary-seam construction the maze prototype uses, unmodified),
	with the Fold's own material on top instead of `GridMesh.build`'s
	grass and stone.

	**Why this exists at all**, rather than the Weft continuing to call
	`GridMesh.build` directly. Grass and stone are the maze prototype's own
	materials — `biomes.maze`, unnumbered, predating
	[the direction](../../../docs/game/world.md) entirely — and the Weft
	inherited them by reusing that prototype's grid rather than by any
	deliberate choice. Flagged directly ("no... coherence with our new
	Artistic Direction"): grass is organic, against
	[art-and-audio.md](../../../docs/game/art-and-audio.md)'s "everything
	is cells"; its hue is whatever a grass texture's hue happens to be, not
	a function of curvature, against that document's other universal
	constant.

	**Now reuses the Fold's own dialect outright (2026-08-17, asked
	directly: "make the walls and ground look the very same")**, rather
	than the flat amber/ember/brass dialect this class shipped with
	originally — see `docs/game/art-and-audio.md`'s per-biome dialect
	table, updated alongside this change. The floor reuses
	`Colours.CONWAY_TILE_DEAD` (`tools.geodesic.GeodesicMesh`'s own dead-
	cell blue-black, unlit `FixedColor`, unchanged in kind from before).
	The walls reuse `graphics.shaders.ConwayWallGlow` itself —
	`Colours.CONWAY_WALL_PANEL`/`CONWAY_WALL_GLOW`, the Fold's own dark
	panel-plus-cyan-seam treatment — via `GridMesh.buildWallPrim`'s
	`glowUv` mode, which emits that shader's own UV/normal convention
	instead of the texture-tile one `GridMesh.build`'s other callers still
	use. Every wall here sits at a constant zero activity (the shader's own
	rest brightness): the Weft has no Conway-style "about to flip" reading
	to drive the glow's pulse with, only an instant player-triggered
	toggle, so there is nothing truthful to animate it with.

	**Gate walls are colored apart from the rest (2026-08-18), on
	purpose "too obvious."** `GridMesh.buildWallPrim`'s `skipEdge` leaves
	every gate edge out of the uniform Fold-glow mesh above, and
	`addGateWall` rebuilds each one on its own (`GridMesh.
	buildSingleWallPiecePrim`) in a flat, unlit `Colours.WEFT_GATE_LOCK`
	(red) or `WEFT_GATE_KEY` (green) instead — a stock stop/go pairing,
	deliberately not argued from curvature the way the rest of this
	class's palette is, since the whole point right now is that a gate
	reads as *obviously* different from ordinary wall, not blended in. A
	gate wall's geometry only exists at all while its edge is actually
	closed, same as any other wall (`GridModel.isOpen`) — a solved lock
	simply has no wall there any more, same payoff as opening anything
	else here.

	Unlit and flat-shaded, same reasoning as every other flat-color mesh in
	the project (`biomes.defect.DefectMesh`, `biomes.conway.ConwayMesh`, …):
	nothing here has real lighting to shade by, so a lit material would
	read as a smooth gradient across faces the sphere's own faceting is
	supposed to keep discrete.
**/
class WeftMesh {
	/**
		@param maze the current layout.
		@param parent the scene object to attach the floor and walls under.
		@param gates every gate currently sealed into this maze (`WeftModel.sealKeystoneGates`'s own output, converted via `WeftModel.gateOf`) — possibly empty.
	**/
	public static function build(maze:GridData, parent:h3d.scene.Object, gates:Array<WeftGate>):Void {
		var floorMesh = new h3d.scene.Mesh(GridMesh.buildFloorPrim(), parent);
		floorMesh.material.mainPass.addShader(new h3d.shader.FixedColor(Colours.CONWAY_TILE_DEAD));
		floorMesh.material.mainPass.culling = None;

		var wallMesh = new h3d.scene.Mesh(GridMesh.buildWallPrim(maze, false, true, (a, b) -> isGateEdge(gates, a, b)), parent);
		wallMesh.material.mainPass.addShader(new ConwayWallGlow(Colours.CONWAY_WALL_PANEL, Colours.CONWAY_WALL_GLOW));
		wallMesh.material.mainPass.culling = None;

		for (gate in gates) {
			addGateWall(parent, maze, gate.lock.a, gate.lock.b, Colours.WEFT_GATE_LOCK);
			addGateWall(parent, maze, gate.partner.a, gate.partner.b, Colours.WEFT_GATE_KEY);
		}
	}

	/** Whether `a`-`b` is any gate's own lock or partner edge — what the uniform wall mesh above leaves out, so `addGateWall`'s own separately-colored piece is the only thing ever drawn there. **/
	static function isGateEdge(gates:Array<WeftGate>, a:GridNode, b:GridNode):Bool {
		var key = GridModel.edgeKey(a, b);
		for (gate in gates) {
			if (GridModel.edgeKey(gate.lock.a, gate.lock.b) == key || GridModel.edgeKey(gate.partner.a, gate.partner.b) == key) {
				return true;
			}
		}
		return false;
	}

	/** One gate edge's own wall, in `color` — both sides (`WeftModel.edgeSidesOf`), same "one piece per cell per side" convention every other wall in this grid uses. Nothing built at all while the edge is open: a gate wall works the same as any other, it just never shares the uniform mesh's material. **/
	static function addGateWall(parent:h3d.scene.Object, maze:GridData, a:GridNode, b:GridNode, color:Int):Void {
		if (GridModel.isOpen(maze, a, b)) {
			return;
		}
		var sides = WeftModel.edgeSidesOf(a, b);
		addGateWallSide(parent, sides.aSide, color);
		addGateWallSide(parent, sides.bSide, color);
	}

	static function addGateWallSide(parent:h3d.scene.Object, side:EdgeSide, color:Int):Void {
		var mesh = new h3d.scene.Mesh(GridMesh.buildSingleWallPiecePrim(side.row, side.col, side.west), parent);
		mesh.material.mainPass.addShader(new h3d.shader.FixedColor(color));
		mesh.material.mainPass.culling = None;
	}
}
