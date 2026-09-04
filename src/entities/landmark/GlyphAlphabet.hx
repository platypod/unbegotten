package entities.landmark;

/**
	The landmark alphabet: ~12 cell-scale glyphs the player navigates by,
	parsed from `res/data/landmark-glyphs.json`.

	**Why an alphabet at all.** `docs/game/art-and-audio.md`'s own landmark
	section: in hyperbolic space you cannot see far and everything nearby is
	locally identical, so the standard answer (a tall tower visible across
	the level) has nothing to be visible across. Landmarks have to be
	legible *at arm's length* and individually distinguishable, and the
	player navigates by remembering a **sequence** of them rather than a
	map — route memory, not position memory.

	**Why still lifes specifically**, rather than invented shapes: the
	material language says everything in this world is cells, and Thread 2
	says the terrain is made of the ones who stopped. A still life is
	literally a pattern that stopped. So the alphabet is not decoration
	standing in for content — walking a route by these glyphs is walking
	past twelve of the dead, which is the reading Thread 2 wants long before
	anything says it out loud.

	**The invariant that makes the set usable** is that no glyph is a
	rotation or reflection of another. Parallel transport rotates a glyph as
	the player carries a route around a curved surface (see the Defect,
	whose whole lesson is that this happens), so two glyphs related by a
	rotation would be the *same landmark* to a player who arrived from a
	different direction — the alphabet would silently have fewer letters
	than it claims. `GlyphAlphabetTest` checks it over the real data file
	rather than trusting the shapes to have been chosen carefully.

	Engine-agnostic — a plain JSON string in, parsed glyphs out, same shape
	and reasoning as `entities.CreatureSpawnTable` — so it stays testable
	without `hxd.Res` or a scene graph. `GlyphMesh` is what turns one into
	geometry.
**/
class GlyphAlphabet {
	/**
		Parses the alphabet from JSON:
		`{"glyphs": [{"name": "...", "cells": [[x, y], ...]}, ...]}`.
		@param json a JSON string in the alphabet format.
		@return the parsed glyphs, in file order.
	**/
	public static function parse(json:String):Array<Glyph> {
		var parsed:{glyphs:Array<{name:String, cells:Array<Array<Int>>}>} = haxe.Json.parse(json);
		return [
			for (entry in parsed.glyphs)
				new Glyph(entry.name, [for (cell in entry.cells) {x: cell[0], y: cell[1]}])
		];
	}
}

/**
	One landmark glyph: a name and the cells it occupies on a small grid.
	Immutable — an alphabet is a fixed vocabulary, and a glyph that could be
	edited after parsing is a glyph that could stop being distinct from its
	neighbours without anything noticing.
**/
class Glyph {
	/** This glyph's own name — the still life it is (`"block"`, `"loaf"`, ...). **/
	public final name:String;

	/** The cells this glyph occupies, in file order. **/
	public final cells:Array<GlyphCell>;

	public function new(name:String, cells:Array<GlyphCell>) {
		this.name = name;
		this.cells = cells;
	}

	/**
		This glyph's cells translated so the lowest occupied x and y are both
		zero — the comparable form, since where a glyph happens to sit on its
		authoring grid says nothing about its shape.
		@return the origin-normalised cells, sorted so two equal shapes
				produce equal arrays regardless of the order they were
				written in.
	**/
	public function normalised():Array<GlyphCell> {
		var minX = cells[0].x;
		var minY = cells[0].y;
		for (cell in cells) {
			if (cell.x < minX) {
				minX = cell.x;
			}
			if (cell.y < minY) {
				minY = cell.y;
			}
		}
		var moved = [for (cell in cells) {x: cell.x - minX, y: cell.y - minY}];
		moved.sort((a, b) -> a.y != b.y ? a.y - b.y : a.x - b.x);
		return moved;
	}

	/**
		This glyph rotated a quarter turn. Used to enumerate the orientations
		a player could meet it in — see the class doc's own invariant.
		@return a new glyph with the same name, rotated 90 degrees.
	**/
	public function rotated():Glyph {
		return new Glyph(name, [for (cell in cells) {x: cell.y, y: -cell.x}]);
	}

	/**
		This glyph mirrored across the y axis. Included in the distinctness
		check because a surface the player can reach both sides of (the Turn,
		the Möbius strip) hands them the mirrored glyph without their having
		done anything.
		@return a new glyph with the same name, reflected.
	**/
	public function reflected():Glyph {
		return new Glyph(name, [for (cell in cells) {x: -cell.x, y: cell.y}]);
	}

	/**
		Every distinct shape this glyph can present: its four rotations and
		the four rotations of its mirror image, origin-normalised and
		de-duplicated. A glyph with rotational symmetry yields fewer than
		eight, which is a *good* property here — such a glyph reads the same
		however the player arrives at it.
		@return each distinct orientation, as a comparable key.
	**/
	public function orientations():Array<String> {
		var seen = new Map<String, Bool>();
		var out = [];
		for (start in [this, reflected()]) {
			var current = start;
			for (_ in 0...4) {
				var key = current.shapeKey();
				if (!seen.exists(key)) {
					seen.set(key, true);
					out.push(key);
				}
				current = current.rotated();
			}
		}
		return out;
	}

	/**
		A string that is equal for two glyphs exactly when they occupy the
		same normalised cells — the comparison primitive `orientations` and
		the distinctness test both work in, since Haxe has no structural
		equality for arrays of anonymous objects.
		@return this glyph's own shape as a comparable key.
	**/
	public function shapeKey():String {
		return [for (cell in normalised()) '${cell.x},${cell.y}'].join(" ");
	}
}

/** One occupied cell of a glyph, on its own small authoring grid. **/
typedef GlyphCell = {
	var x:Int;
	var y:Int;
}
