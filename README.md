# unbegotten

3D maze wrapped onto the interior surface of a sphere: raise your head and you
can see clear across to the far side, but not what's in your immediate
vicinity.

## Stack

Haxe + [Heaps](https://heaps.io/), compiling to WebGL for the browser (desktop
and mobile) with HashLink for fast local dev/debugging.

Coding standards, architecture decisions, and the git/commit workflow are in
[`CLAUDE.md`](CLAUDE.md) (short version) and
[`docs/rules/guidelines.md`](docs/rules/guidelines.md) (full detail + rationale).
[`docs/archive/project-log.md`](docs/archive/project-log.md) has the chronological history of
how the project got here, and is where new decisions get logged as the
project continues.

## Dev

```sh
haxelib install heaps utest formatter checkstyle  # once per machine
git config core.hooksPath .githooks                # once per clone

make help    # list targets
make check   # compile
make test    # run utest suite
make build   # production web build -> bin/ (self-contained static web root)
```

**HashLink caveat:** Homebrew's `hashlink` formula ships no `hl` (JIT VM) on
Apple Silicon — only HashLink/C native compilation is supported on ARM
([hashlink#557](https://github.com/HaxeFoundation/hashlink/issues/557)). The
"fast HL dev loop" `docs/rules/guidelines.md` §6.1 describes isn't wired up yet as a
result; `make check`/`make test`/`make build` all currently target JS (run via
`node` for tests), which needs no extra toolchain. See
`docs/archive/project-log.md` for the full note.

## Deployment

The game is a static web build (Heaps → JS/WebGL), deployed as a service in
platypod's `stack` `games` module (alongside `pokeclicker`, `rommapp`),
behind Authelia SSO like the rest of the homelab.

### Release build (implemented)

Pushing a git tag triggers [`.github/workflows/build.yml`](.github/workflows/build.yml),
which builds a multi-arch image (`linux/amd64` + `linux/arm64`, via Docker
Buildx) and pushes it to `ghcr.io/platypod/unbegotten:<tag>` (+ `:latest`).
[`Dockerfile`](Dockerfile) is a two-stage build — `haxe:4.3.7-alpine` compiles
`bin/` (matching `make build`'s output exactly), then `nginx:alpine` serves
it with no language runtime in the shipped image. Same pattern as
`mediarvester`/`prompt-meter`; no cluster credentials are involved in this
step.

**First tag only — make the GHCR package public.** GitHub creates new GHCR
packages as **private**. After the first tag push, set it public once:
`github.com/orgs/platypod/packages` → `unbegotten` → *Package settings* →
*Danger Zone* → *Change visibility* → **Public**. Persists across all future
versions. There's no REST API for changing package visibility (a GitHub
limitation), so it's a one-time manual step — same as every other platypod
image.

Traefik doesn't change here — it's a reverse proxy/router, not a web or file
server, so it can't host the static files itself (that's a deliberate scope
choice in Traefik's design, unlike e.g. Caddy which can do both). It routes
to our pod exactly like it already routes to every other service in the
`games` module (`Deployment` + `Service` + `IngressRoute`, same pattern as
`pokeclicker`/`rommapp`); the nginx/Caddy container is just what runs *inside*
that pod to actually serve the files.

### Prod deploy (resolved: GitOps via Flux)

**Settled: platypod adopted the GitOps route.** This was open for a while, with
manual deploy, in-cluster GitOps, and a scoped webhook receiver all on the
table; the driving constraint was that *no cluster credential should ever be
stored in GitHub*, even a scoped, short-lived one. The `stack` repo went to
Flux CD in the end — prod cut over 2026-08-24, the `dev`/`main` branch split
landed 2026-09-02 — which satisfies that constraint by construction:
controllers *inside* the cluster pull, GitHub never pushes, and no cluster
credential exists on GitHub's side at all.

End to end, from a tag in this repo to a running pod:

1. Push a git tag → GitHub Actions builds and pushes
   `ghcr.io/platypod/unbegotten:<tag>` (the step above; still no cluster
   credentials involved).
2. Flux's `image-reflector-controller`, running in each cluster, scans GHCR and
   resolves the newest matching tag. `stack` declares two policies for this
   image: `unbegotten` (final releases) and `unbegotten-local` (range ending
   `-0`, so `-dev.N` prereleases match too).
3. `image-automation-controller` commits the new pin to `stack`'s **`dev`**
   branch — `apps/base/values/games.yaml` for the final-release policy,
   `apps/local-overlay/games-image.yaml` for the local prerelease one. It only
   ever writes to `dev`, including prod's own instance of it.
4. The local cluster tracks `dev` and picks the change up within a poll
   interval. Prod tracks `main`, and reaches it only when `dev` is merged into
   `main` — **that merge is the entire prod promotion.** No tag gate, no
   manual deploy step.

There is no `make deploy` any more, in `stack` or anywhere else.

**Enabling the service on a cluster is separate from shipping an image**, and
is a one-time thing. Each service carries an `enable` flag in the private
`platypod-sops` repo (`clusters/<env>/secrets.enc.yaml`, SOPS/age-encrypted);
that Secret is the last `valuesFrom` entry on every `HelmRelease`, so it
overrides the chart's own default. Flip it and push to the branch that cluster
tracks. Unbegotten was enabled on local this way on 2026-09-03.

The authoritative write-ups live in `stack`: `docs/branching.md` for which
branch deploys where, `docs/operations.md` for the day-to-day, and
`docs/flux-migration.md` for the migration record and its gotchas.

## Design, backlog & bug tracking

- [**`docs/game/`**](docs/game/README.md) — **what this game is.** The
  premise and pillars, the nine spaces, the systems, the opening hour, the
  mathematics it exploits, and the art direction.
- [`docs/rules/`](docs/rules/philosophy.md) — what must be respected: the
  design pillars, the engineering guidelines, the spatial architecture.
- [`docs/building/`](docs/building/development.md) — setup, roadmap and
  engineering notes.
- [`docs/open/`](docs/open/ideas-backlog.md) — the ideas backlog and known
  bugs. Nothing there is decided.
- [`docs/archive/`](docs/archive/project-log.md) — history: project log,
  decision records, changelog.

Start at [`docs/README.md`](docs/README.md), which sorts all of it by how
much it binds you.