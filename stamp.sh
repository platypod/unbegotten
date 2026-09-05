#!/bin/sh
# Content-stamps the web build: renames bin/game.js to bin/game.<hash>.js and
# writes bin/index.html pointing at it.
#
# **Why the bundle needs a changing name.** Its URL used to be identical in
# every release, so a browser holding the previous build had no way to know it
# was stale — which is exactly what happened after v0.16.0 and cost a hard
# reload. v0.16.1 answered that with `Cache-Control: no-cache`, making the
# browser revalidate every load. This is the better answer: a new build is a
# new URL, so the old one can never be served by mistake, and the bundle
# itself becomes cacheable forever (see nginx.conf's `immutable`).
#
# The hash is of the file's own content, not a version, and that is what makes
# this cheap: nothing has to be passed in, so the Docker build needs no `.git`
# and CI needs no build argument. Eight hex characters is ample — a collision
# would need two builds of this one file to share a sha256 prefix.
#
# Run from the repo root, after `haxe build.hxml`. Used by both `make build`
# and the Dockerfile, which otherwise would each need their own copy of this.
set -e

if [ ! -f bin/game.js ]; then
    echo "stamp.sh: bin/game.js not found — run 'haxe build.hxml' first" >&2
    exit 1
fi

# Scoped to game.*.js on purpose: bin/ also holds walk.js and the .n tool
# builds, and a broader glob would delete them.
rm -f bin/game.*.js

HASH=$(sha256sum bin/game.js | cut -c1-8)
mv bin/game.js "bin/game.$HASH.js"
sed "s|game\.js|game.$HASH.js|" index.html > bin/index.html

echo "stamped bin/game.$HASH.js"
