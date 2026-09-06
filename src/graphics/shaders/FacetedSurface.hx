package graphics.shaders;

/**
	Facet shading and distance fade for any solid geometry — the two halves
	of the Repeat's own visual pass that were never specific to the Repeat.

	`h3d.shader.FixedColor` gives a mesh one value for every face at every
	distance and orientation, and an image like that carries no information
	but silhouette. Same-value silhouettes that overlap merge into a single
	shape, which is what "too flat... barely-grey-cubes" was describing when
	it was said of the Repeat — and every space from the Turn onward was
	still drawn exactly that way. This is the fix, extracted so it is one
	shader rather than five.

	Two things, no extra polygons:

	- **Facet shading.** Faces are valued by which axis they face, so
		adjacent solids differ at their shared edge and a box reads as a
		solid rather than a cutout. The oldest trick in low-poly rendering.
	- **Distance fade.** Anything repeated recedes into the background
		instead of stacking up as one flat mass, which is what gives a
		repeated space depth.

	**The normal is taken from screen-space derivatives, not from vertex
	data, and that is the whole reason this is reusable.** Every biome here
	builds `h3d.prim.Polygon` out of bare positions, and several rebuild
	their entire mesh every frame (`biomes.sprawl.SprawlBiome`,
	`biomes.knot.KnotBiome`). Asking for real normals would mean
	`unindex()` plus `addNormals()` per frame — tripling the vertex count of
	a per-frame rebuild — and averaged vertex normals would smooth away the
	very facets this exists to show. The cross product of the fragment's own
	position derivatives is the true *flat* face normal, costs nothing, and
	works on geometry that was never authored with this shader in mind.

	**Not a lighting model.** There is no light, no direction, no falloff —
	three constants indexed by axis. That is deliberate:
	`docs/game/art-and-audio.md` spends value rather than illumination, and
	a real light would put a highlight somewhere the design never asked for
	one.

	`CityFacade` stays separate rather than being rebuilt on this: it does
	the same two things plus procedural windows keyed on tile-local
	coordinates, and folding a mechanic-critical tiling rule into a shader
	that five other biomes share would be exactly the wrong coupling.
**/
class FacetedSurface extends hxsl.Shader {
	static var SRC = {
		@global var camera:{
			var position:Vec3;
		};
		@param var faceEastWest:Vec3;
		@param var faceNorthSouth:Vec3;
		@param var faceTop:Vec3;
		@param var fogColor:Vec3;
		@param var fogStart:Float;
		@param var fogEnd:Float;
		var transformedPosition:Vec3;
		var output:{
			var color:Vec4;
		};
		function fragment():Void {
			// The flat face normal, from how this fragment's world position
			// changes across neighbouring pixels — see the class doc on why
			// this is not read from vertex data.
			var n = normalize(cross(dFdx(transformedPosition), dFdy(transformedPosition)));
			var facingX = step(0.5, abs(n.x));
			var facingUp = step(0.5, abs(n.y));

			var side = mix(faceNorthSouth, faceEastWest, facingX);
			var surface = mix(side, faceTop, facingUp);

			var distance = length(camera.position - transformedPosition);
			var fade = clamp((distance - fogStart) / (fogEnd - fogStart), 0.0, 1.0);

			output.color = vec4(mix(surface, fogColor, fade), 1.0);
		}
	}

	/**
		@param faceEastWest value for faces normal to the x axis.
		@param faceNorthSouth value for faces normal to the z axis — differing from `faceEastWest` is what gives a solid its volume.
		@param faceTop value for faces normal to the y axis: floors and roofs.
		@param fogColor what distance fades toward; pass the biome's own `backgroundColor`, or the picture separates from its own backdrop.
		@param fogStart world distance at which fading begins.
		@param fogEnd world distance at which geometry has faded out entirely.
	**/
	public function new(faceEastWest:Int, faceNorthSouth:Int, faceTop:Int, fogColor:Int, fogStart:Float, fogEnd:Float) {
		super();
		this.faceEastWest.setColor(faceEastWest);
		this.faceNorthSouth.setColor(faceNorthSouth);
		this.faceTop.setColor(faceTop);
		this.fogColor.setColor(fogColor);
		this.fogStart = fogStart;
		this.fogEnd = fogEnd;
	}

	/**
		The same shading from one base value, with the two side faces
		derived from it — the common case, since most surfaces here want
		"this colour, with volume" rather than three separately chosen
		values.

		The top face keeps the base value and the sides step *down* from it,
		which is the convention throughout: `graphics.Colours`' ramp is
		value-only, floors are what the player mostly sees, and darkening
		the sides keeps a solid reading as one object lit from nowhere in
		particular rather than as a paler shape stuck on a darker one.
		@param base the surface's own value, used as-is for floors and roofs.
		@param fogColor what distance fades toward.
		@param fogStart world distance at which fading begins.
		@param fogEnd world distance at which geometry has faded out entirely.
		@return a shader shading `base` with volume.
	**/
	public static function from(base:Int, fogColor:Int, fogStart:Float, fogEnd:Float):FacetedSurface {
		return new FacetedSurface(shade(base, EAST_WEST_SHADE), shade(base, NORTH_SOUTH_SHADE), base, fogColor, fogStart, fogEnd);
	}

	/** How much darker an x-facing face is than the surface's own value. **/
	static inline final EAST_WEST_SHADE:Float = 0.74;

	/** How much darker a z-facing face is — different from `EAST_WEST_SHADE` or the two side faces match and the facets vanish. **/
	static inline final NORTH_SOUTH_SHADE:Float = 0.88;

	/**
		Scales a colour's channels toward black, leaving alpha alone.
		@param color the `0xAARRGGBB` value to darken.
		@param factor what to multiply each channel by, in [0, 1].
		@return the darkened colour.
	**/
	static function shade(color:Int, factor:Float):Int {
		var r = Std.int(((color >> 16) & 0xFF) * factor);
		var g = Std.int(((color >> 8) & 0xFF) * factor);
		var b = Std.int((color & 0xFF) * factor);
		return (color & 0xFF000000) | (r << 16) | (g << 8) | b;
	}
}
