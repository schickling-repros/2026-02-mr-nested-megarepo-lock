# mr sync — nested megarepo.lock not updated

`mr sync` updates `devenv.lock`/`flake.lock` in member repos to match the parent `megarepo.lock`, but does NOT update nested `megarepo.lock` files. This causes `mr sync --frozen` to fail in CI when a nested megarepo references a shared dependency at a stale commit.

## Reproduction

Requires `mr` (megarepo CLI) in PATH.

```bash
git clone https://github.com/schickling-repros/2026-02-mr-nested-megarepo-lock
cd 2026-02-mr-nested-megarepo-lock
./repro.sh
```

The script creates a temporary parent megarepo with two public members:
- `effect-ts/effect` — shared dependency
- `livestorejs/livestore` — a real megarepo that also references `effect-ts/effect` in its own `megarepo.lock`

After `mr sync --pull`, the parent gets the latest effect commit. The script then compares:
- `repos/livestore/devenv.lock` — **updated** (effect rev matches parent)
- `repos/livestore/megarepo.lock` — **NOT updated** (effect commit is stale)

## Expected

`mr sync` should update `megarepo.lock` entries in nested megarepos when the parent tracks a newer commit for the same member.

## Actual

Only `devenv.lock`/`flake.lock` files are synced. Nested `megarepo.lock` files are ignored.

## Versions

- megarepo (mr): from effect-utils @ 32cc9b0
- OS: macOS (Darwin 25.2.0)

## Related Issue

https://github.com/overengineeringstudio/effect-utils/issues/266
