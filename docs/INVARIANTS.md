# First invariant

## Pinned implementation evidence

Initial implementation reading is pinned to:

`mirage/irmin@7a09a06fff67bc4981faca36a332c51fc16e819e`

No claim in this repository should silently move to later Irmin code without
recording the new revision.

## Safety property

The first property is deliberately small:

> Every persisted reference reachable after reopen resolves using durable state.

In the TLA+ model this is `ReopenResolutionSafety`.

A direct reference is durable when its offset still names the target pack entry.
A hash-only reference is durable when the hash is present in the persistent
index. Volatile staging is intentionally cleared by `Reopen`.

## Why this boundary matches Irmin

At the pinned revision:

1. `Indexing_strategy.minimal` does not index `Contents`, while
   `minimal_with_contents` does.
2. The public documentation says `minimal` indexes as few objects as possible
   while maintaining store integrity, and that indexing more than `minimal`
   should affect performance rather than correctness.
3. Inode compression has two persistent child-address forms:
   `Offset` and `Hash`.
4. When encoding an inode, `address_of_key` uses an offset when
   `offset_of_key` succeeds, but persists a hash when it does not.
5. In the pack store, an indexed key whose hash is absent from the index makes
   `offset_of_key` return `None`.
6. When decoding a persisted hash address, `key_of_hash` constructs an indexed
   key.
7. `Val_ref` already contains a note about a possible future static guarantee
   preventing portable nodes with hash references from being saved before
   their children are safely persisted.

These facts make the following boundary worth checking formally:

> If a Contents object is omitted from the index, then every durable reference
> to that object must remain offset-addressable. If a hash-only reference can be
> persisted instead, reopen safety requires that hash to be indexed.

The model tests that statement without yet asserting that a particular real
Irmin execution reaches the bad transition.

## Three model configurations

### `MinimalDirect.cfg`

Contents is not indexed and only a direct reference may be persisted.

Expected result: `ReopenResolutionSafety` holds.

### `MinimalIndexed.cfg`

Contents is not indexed and a hash-only reference may be persisted.

Expected result: TLC should produce a short counterexample after `Reopen`.

This is only a model counterexample until the corresponding implementation
transition is demonstrated.

### `AlwaysIndexed.cfg`

Contents is indexed and a hash-only reference may be persisted.

Expected result: `ReopenResolutionSafety` holds.

## Promotion rule

Nothing goes upstream merely because TLC finds the expected counterexample.

The next question must be answered from pinned implementation evidence or a
minimal executable reproducer:

> Can a real persisted inode contain a hash-only Contents reference under the
> minimal indexing strategy while the referenced Contents object itself is not
> present in the index?

Only if that transition is established does the abstract counterexample become
evidence about Irmin rather than about our model.


## Configuration admissibility

The implementation matrix adds a second, independent obligation to the original
reopen-resolution invariant.

Define:

```text
Admissible(codec, header, strategy) :=
  (header = Varint -> CodecHasCorrectVarintPrefix(codec))
  /\
  (header = None -> StrategyIndexesContents(strategy))
```

The first conjunct protects offset/length reconstruction. The second protects
hash/location reconstruction.

The original TLA+ model discharges the second conjunct's failure mode. A later
model extension may represent the first conjunct explicitly, but the two failure
modes must remain separate.
