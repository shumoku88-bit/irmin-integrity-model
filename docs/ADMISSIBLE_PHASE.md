# Phase 2: admissible configuration state space

This phase asks a stricter question than the calibration model:

> If the documented `contents_length_header` and indexing preconditions are
> satisfied, does the pinned implementation-shaped reopen/read model still
> admit a safety counterexample?

## Difference from the first model

`model/IrminPack.tla` directly allowed a persisted hash-only reference as a
hypothesis. That was useful for deriving the recoverability condition, but it
was not an exact description of the observed irmin-pack path.

`model/Admissible.tla` follows the pinned implementation more closely:

1. a fresh Contents value is stored at a pack offset;
2. the parent inode persists an `Offset` child address;
3. reopen clears volatile staging;
4. inode decode invokes the conceptual `key_of_offset` path;
5. with a correct Varint header, a direct key can be reconstructed;
6. with no length header, decode yields an indexed hash key;
7. indexed recovery succeeds only when Contents was durably indexed.

## Explored configurations

TLC chooses nondeterministically among:

- strategy: `Minimal`, `MinimalWithContents`, `Always`;
- header: `Varint`, `None`;
- codec/header agreement: true or false.

`Init` admits only documented-safe combinations:

```
(header = Varint -> codecCorrect)
and
(header = None -> strategy indexes Contents)
```

The safety property is:

> after reopen, decode, and read, the Contents value resolves successfully.

## Interpretation rule

A clean TLC run is **not** proof that all of irmin-pack is safe. It only closes
this bounded abstraction.

A counterexample, however, would be interesting because every explored initial
configuration already satisfies the two documented preconditions recovered in
Phase 1.
