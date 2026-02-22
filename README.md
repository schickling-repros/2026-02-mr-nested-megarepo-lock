# mr sync — nested megarepo.lock not updated

`mr sync` updates `devenv.lock` and `flake.lock` in member repos to match the parent `megarepo.lock`, but does NOT update nested `megarepo.lock` files. This causes `mr sync --frozen` to fail in CI when a nested megarepo references a shared dependency at a stale commit.

## Reproduction

Requires `mr` (megarepo CLI) in PATH.

```bash
git clone https://github.com/schickling-repros/2026-02-mr-nested-megarepo-lock
cd 2026-02-mr-nested-megarepo-lock
./repro.sh
```

## Expected

`mr sync` should update `repos/nested-megarepo/megarepo.lock` to match the parent's effect commit.

## Actual

The nested `megarepo.lock` retains its old effect commit. Only `devenv.lock`/`flake.lock` files are synced.

```
=== Result ===
  BUG CONFIRMED: nested megarepo.lock was NOT updated by mr sync
  Parent:  ab3b64c20a03
  Nested:  12b1f1eadf64
```

## Versions

- megarepo (mr): from effect-utils @ 32cc9b0
- OS: macOS (Darwin 25.2.0)

## Related Issue

https://github.com/overengineeringstudio/effect-utils/issues/266
