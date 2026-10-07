# TLC results

## Checked revision

Model branch commit:

`595b70d030268938244345a089742a599fb426d2`

GitHub Actions run:

`37323965619`

TLC:

- TLA+ Tools v1.7.4
- TLC2 2.19, revision `5a47802`
- pinned official release asset checksum:
  `bee4a54f3ee3d4afc347c3240ec2d9e93b075104`

## Results

### Minimal + Direct

Configuration: `model/MinimalDirect.cfg`

Result: **PASS**

TLC completed the full reachable state graph with no invariant violation.

- 5 states generated
- 4 distinct states
- depth 4
- 0 states left on queue

### Always + Indexed

Configuration: `model/AlwaysIndexed.cfg`

Result: **PASS**

TLC completed the full reachable state graph with no invariant violation.

- 8 states generated
- 6 distinct states
- depth 4
- 0 states left on queue

### Minimal + Indexed

Configuration: `model/MinimalIndexed.cfg`

Result: **EXPECTED COUNTEREXAMPLE**

TLC reports:

`Invariant ReopenResolutionSafety is violated.`

The minimal trace is:

1. Initial state: pack/index/refs/staging are empty.
2. `StoreContent`: the Contents object is in the pack and volatile staging,
   but not in the persistent index under `Minimal`.
3. `PersistIndexedContentRef`: a persisted hash-only reference is created.
4. `Reopen`: staging is cleared. The Contents object still exists in the pack,
   but the hash-only reference cannot recover its offset because the persistent
   index has no entry for the hash.

TLC generated 6 states, found 6 distinct states, and reached the violation at
state-graph depth 4.

## What this establishes

For this abstract model, the following condition is necessary for the modeled
reopen safety property:

> If a Contents object is omitted from the persistent index, every persisted
> reference to it must remain resolvable without a hash-to-offset index lookup.

Equivalently, if a hash-only Contents reference can be persisted, either that
Contents hash must be indexed or some other durable hash-to-location mechanism
must exist.

## What this does not establish

This is not yet proof of an Irmin implementation bug.

The remaining discharge obligation is concrete:

> Demonstrate that real irmin-pack can persist a hash-only Contents reference
> under `Indexing_strategy.minimal` while the referenced Contents object has no
> durable index entry required to resolve that hash after reopen.

Only after establishing that implementation transition should this result be
taken upstream.
