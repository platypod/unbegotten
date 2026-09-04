package graphics.shaders;

/**
	The Repeat's city surface: facet shading, lit windows, and distance
	fade, in one pass.

	Raised directly against a screenshot of the old look — "too flat...
	barely-grey-cubes" — and the cause was exactly one line: every building
	was a single `h3d.shader.FixedColor` fill, so all six faces of every box
	at every distance and orientation were the identical value. An image
	like that carries no information but silhouette, and same-value
	silhouettes that overlap merge into one shape, which is why a street of
	towers read as a single grey blob with a notch in it.

	Three fixes, none of which adds a polygon:

	- **Facet shading.** Faces are valued by which axis they face — the
		oldest trick in low-poly rendering, and the reason Manifold Garden's
		cubes read as solids rather than as cutouts. This alone does most of
		the work, because adjacent buildings now differ at their shared edge.
	- **Windows.** A procedural grid off the facade's own position, so the
		city gains surface information for free. Thematically this is not
		decoration: a window is a *cell*, and lit-means-alive is already the
		material language, so a tower of lit and dark panes is a column of
		cells — which is what this world says everything is made of.
	- **Distance fade.** Twenty same-valued buildings behind one another
		still merge however well each one is shaded. Fading toward the sky
		is what gives a repeated city depth.

	**The window pattern is derived from tile-local coordinates, and that is
	load-bearing rather than tidy.** `biomes.repeat.RepeatModel`'s whole
	mechanic needs every tile to be pixel-identical — a difference has to
	mean something intervened — so a pattern keyed on world position would
	make every tile visibly unique and destroy the space outright. Taking
	the horizontal position modulo `tileSize` makes the pattern periodic by
	construction, so identity is enforced by the arithmetic rather than by
	anyone remembering the rule. The vertical axis needs no such treatment,
	being the same everywhere already.

	**Neon is deliberately rare.** `graphics.Colours` spends saturation on
	signals — the exit, the mark, the actionable thing — so a city where
	every window glows would demote `SIGNAL_LIVE` to background noise and
	stop the Repeat's own fragments popping. `neonRate` defaults to roughly
	one window in forty, which also simply looks better: a city where
	everything glows is a Christmas tree and has no depth.
**/
class CityFacade extends hxsl.Shader {
	/** Fraction of windows that are lit *and* saturated. See the class doc on why this is small. **/
	public static inline final DEFAULT_NEON_RATE:Float = 0.025;

	static var SRC = {
		@input var input:{
			var normal:Vec3;
		};
		@global var camera:{
			var position:Vec3;
		};
		@param var faceEastWest:Vec3;
		@param var faceNorthSouth:Vec3;
		@param var faceTop:Vec3;
		@param var windowDark:Vec3;
		@param var windowLit:Vec3;
		@param var windowNeon:Vec3;
		@param var fogColor:Vec3;
		@param var fogStart:Float;
		@param var fogEnd:Float;
		@param var tileSize:Float;
		@param var windowSize:Float;
		@param var neonRate:Float;
		@param var lifeMap:Sampler2D;
		@param var plotSize:Float;
		@param var facadeCols:Float;
		@param var facadeRows:Float;
		@param var totalFacades:Float;
		@param var plotsPerTile:Float;
		/**
			Which facade this instance reads, or `-1` to read the one its
			own plot implies.

			The escape hatch for the anomaly, and the reason it is a
			parameter rather than something derived: everything else in this
			shader is deliberately blind to which tile it is in, which is
			what guarantees tiles look identical. A building that ran a
			*different* simulation because of its tile would need that
			knowledge and would break the guarantee for every other
			building too. The deformed building is already drawn as its own
			object with its own shader instance, so it can simply be told.
		**/
		@param var facadeOverride:Float;
		/**
			`1` to light panes from a fixed hash instead of the simulation —
			what an *identified* building looks like.

			The building stops running: whatever rule it was on, once the
			player has named it, its windows freeze into static noise. It is
			the one visible record of what you have already found, it is
			diegetic (no counter, no marker), and it is the same hash the
			whole city used before any of it was alive — so a found building
			is quite literally one that has stopped.
		**/
		@param var frozen:Float;
		var transformedPosition:Vec3;
		var output:{
			var color:Vec4;
		};
		/** A stable pseudo-random value in `[0, 1)` from a grid cell. **/
		function hash(cell:Vec2, salt:Float):Float {
			return fract(sin(dot(cell, vec2(12.9898, 78.233)) + salt) * 43758.5453);
		}
		function fragment():Void {
			var n = normalize(input.normal);
			var facingX = step(0.5, abs(n.x));
			var facingUp = step(0.5, abs(n.y));

			var side = mix(faceNorthSouth, faceEastWest, facingX);
			var surface = mix(side, faceTop, facingUp);

			// Tile-local horizontal position — see the class doc. `floor`
			// rather than a modulo operator, which HXSL does not have for
			// floats, and which would need the same correction for negative
			// coordinates anyway (tiles exist at negative indices).
			var localX = transformedPosition.x - tileSize * floor(transformedPosition.x / tileSize);
			var localZ = transformedPosition.z - tileSize * floor(transformedPosition.z / tileSize);
			// Whichever axis runs *along* this facade. A face whose normal
			// is x runs along z, not along x — getting this backwards makes
			// `along` constant across the whole face, so every pane in a row
			// shares one hash and the windows come out as horizontal bands
			// spanning the building rather than as a grid.
			var along = mix(localX, localZ, facingX);

			// Which plot this facade belongs to, and therefore which of the
			// 36 simulations it shows. Both indices come from the tile-local
			// position, so they are the same in every tile by construction.
			var plotX = floor(localX / plotSize);
			var plotZ = floor(localZ / plotSize);
			var facade = plotZ * plotsPerTile + plotX;
			facade = mix(facade, facadeOverride, step(0.0, facadeOverride));

			// Cell within this plot's own facade grid.
			var alongInPlot = along - plotSize * floor(along / plotSize);
			var cell = vec2(floor(alongInPlot / windowSize), floor(transformedPosition.y / windowSize));
			var within = vec2(fract(along / windowSize), fract(transformedPosition.y / windowSize));

			// A gutter around each pane, so windows read as separate units
			// rather than as a continuous stripe.
			var pane = step(0.16, within.x) * step(within.x, 0.84) * step(0.22, within.y) * step(within.y, 0.78);
			// No windows on roofs, and none in the ground storey, which is
			// where a street-level city has doors and shopfronts instead.
			var glazed = pane * (1.0 - facingUp) * step(windowSize, transformedPosition.y);

			// Lit means *alive*, read straight out of the simulation — see
			// `biomes.repeat.FacadeLife`. The grids are stacked vertically
			// into one strip, so a facade is a band of `facadeRows` rows.
			var u = (cell.x + 0.5) / facadeCols;
			var v = (facade * facadeRows + cell.y + 0.5) / (facadeRows * totalFacades);
			var simulated = step(0.5, lifeMap.get(vec2(u, v)).r);
			var frozenLit = step(0.62, hash(cell, 11.0));
			var lit = mix(simulated, frozenLit, frozen);
			var neon = step(1.0 - neonRate, hash(cell, 37.0)) * lit;

			// Unlit panes sit *below* the wall value, so a dark tower still
			// shows its grid rather than going featureless.
			var glass = mix(windowDark, windowLit, lit);
			glass = mix(glass, windowNeon, neon);
			var lithue = mix(surface, glass, glazed);

			var distance = length(camera.position - transformedPosition);
			var fade = clamp((distance - fogStart) / (fogEnd - fogStart), 0.0, 1.0);

			output.color = vec4(mix(lithue, fogColor, fade), 1.0);
		}
	}

	/**
		@param faceEastWest value for faces normal to the x axis.
		@param faceNorthSouth value for faces normal to the z axis — differing from `faceEastWest` is what gives a box its volume.
		@param faceTop value for roofs.
		@param windowDark an unlit pane.
		@param windowLit a lit pane.
		@param windowNeon a lit *and* saturated pane; see the class doc on why these are rare.
		@param fogColor what distance fades toward — the sky, or the picture separates from its own background.
		@param fogStart world distance at which fading begins.
		@param fogEnd world distance at which geometry is fully faded out.
		@param tileSize the Repeat's own tile period, which makes the window pattern identical in every tile.
		@param lifeMap the packed facade simulations — see `biomes.repeat.FacadeLife`.
		@param facadeOverride which facade to read regardless of position, or `-1` to use the one this building's own plot implies. Only the anomaly passes anything else.
		@param frozen `1` for a building the player has already identified, which stops simulating and shows static noise.
	**/
	public function new(faceEastWest:Int, faceNorthSouth:Int, faceTop:Int, windowDark:Int, windowLit:Int, windowNeon:Int, fogColor:Int, fogStart:Float,
			fogEnd:Float, tileSize:Float, lifeMap:h3d.mat.Texture, facadeOverride:Float = -1, frozen:Float = 0) {
		super();
		this.faceEastWest.setColor(faceEastWest);
		this.faceNorthSouth.setColor(faceNorthSouth);
		this.faceTop.setColor(faceTop);
		this.windowDark.setColor(windowDark);
		this.windowLit.setColor(windowLit);
		this.windowNeon.setColor(windowNeon);
		this.fogColor.setColor(fogColor);
		this.fogStart = fogStart;
		this.fogEnd = fogEnd;
		this.tileSize = tileSize;
		this.lifeMap = lifeMap;
		this.facadeOverride = facadeOverride;
		this.frozen = frozen;
		this.windowSize = biomes.repeat.FacadeLife.WINDOW_SIZE;
		this.plotSize = biomes.repeat.RepeatModel.PLOT_SIZE;
		this.facadeCols = biomes.repeat.FacadeLife.COLS;
		this.facadeRows = biomes.repeat.FacadeLife.ROWS;
		this.totalFacades = biomes.repeat.FacadeLife.TOTAL_FACADES;
		this.plotsPerTile = biomes.repeat.RepeatModel.PLOTS_PER_TILE;
		this.neonRate = DEFAULT_NEON_RATE;
	}
}
