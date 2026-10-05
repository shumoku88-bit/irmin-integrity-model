# GC Moment B: startup lower-layer metadata freshness

## Hypothesis

The lower-layer design documents a recoverable crash point, "Moment B":

1. the new upper control file has been published;
2. the appendable volume still has its old `volume.control`;
3. a generation-specific temporary volume control contains the new metadata.

On restart, the temporary control is renamed over `volume.control`.

At the pinned revision, startup construction appears to perform these operations
in this order:

1. `Lower.v` loads all volume controls into `Volume.t` values;
2. `File_manager.cleanup` calls `Lower.cleanup`;
3. `Volume.cleanup` renames the matching generation control into
   `volume.control`.

`Volume.t` stores the parsed control payload by value. Its `contains`
routing predicate and `open_` mapping size use that cached payload.

The normal in-process GC path differs: `Lower.swap` performs
`Volume.swap` and then calls `reload`.

The startup cleanup path does not currently show that reload step.

## Formal question

After Moment B recovery, can disk metadata be repaired while the just-started
process keeps the old in-memory volume range?

`model/GcMomentB.tla` checks a minimal range-extension case:

- old volume end offset: 10
- recovered volume end offset: 20
- probe offset: 15

Two configurations are checked:

- `GcMomentBCurrent.cfg`: models startup cleanup without reloading lower
  metadata. Expected to violate `RoutingSafety`.
- `GcMomentBReloaded.cfg`: models a reload after the rename. Expected to
  preserve `RoutingSafety`.

## Promotion rule

A TLC counterexample is not enough for an upstream claim.

We still need a pinned executable reproducer that creates the Moment B disk
layout, opens irmin-pack through the real startup path, and demonstrates whether
a newly archived lower-layer offset is unreadable until a second reopen/reload.
