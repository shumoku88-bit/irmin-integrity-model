# Evidence log

## Scope

Target issues:

- mirage/irmin#2369
- mirage/irmin#2389

The first model focuses only on the indexing/reference-integrity portion of
#2369. The `contents_length_header` behavior mentioned in #2369 and #2389 is
kept separate until there is evidence that it belongs to the same failure path.

## Pinned Irmin revision

`7a09a06fff67bc4981faca36a332c51fc16e819e`

## Source observations

### Indexing strategy contract

`src/irmin-pack/indexing_strategy.mli` states that:

- `minimal` indexes as few objects as possible while maintaining store
  integrity;
- indexing more than `minimal` should affect performance, not correctness.

`src/irmin-pack/indexing_strategy.ml` shows:

- `minimal`: `Contents -> false`
- `minimal_with_contents`: `Contents -> true`

### Hash fallback during inode encoding

`src/irmin-pack/inode.ml` defines compressed addresses as either
`Offset` or `Hash`.

During encoding, `address_of_key` chooses:

- `Offset off` when `offset_of_key key = Some off`;
- `Hash (Key.to_hash key)` when `offset_of_key key = None`.

The source describes the latter as unusual but not forbidden.

### Indexed key without an index entry

`src/irmin-pack/unix/pack_store.ml` implements `offset_of_key` so that an
already-direct key yields its offset, while an indexed key performs
`Index.find`. A missing index entry yields `None`.

During decode, hash addresses are reconstructed with `Pack_key.v_indexed`.

### Existing static-safety hint

`src/irmin-pack/inode.ml`'s `Val_ref` comment explicitly mentions a possible
future type-level guarantee ensuring portable nodes containing hash references
are not saved without first saving their children.

## Issue evidence

In mirage/irmin#2369 a maintainer reported that the submitted configuration
works when avoiding the `minimal` strategy, including with
`minimal_with_contents`, and said the behavior might be a bug.

The same discussion separately mentions problems with
`contents_length_header = Some \`Varint`, with `None` as a workaround.
mirage/irmin#2389 tracks that non-String contents / length-header concern.

## Current status

We have a plausible formal boundary but not yet a demonstrated root cause.

Do not collapse the indexing issue and the length-header issue into one claim
without further evidence.
