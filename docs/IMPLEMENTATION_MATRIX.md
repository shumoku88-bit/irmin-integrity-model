# Implementation configuration matrix

## Pinned implementation

All implementation runs in this document use:

`mirage/irmin@7a09a06fff67bc4981faca36a332c51fc16e819e`

GitHub Actions run:

`37327321825`

The custom contents type is structurally equivalent to the record from
mirage/irmin#2369:

```ocaml
type t = {
  name : string;
  deck : string list;
  reveal : [ `Everyone | `SpectatorsOnly ];
}
[@@deriving irmin]
```

Each case writes a value, reads it in the same repository instance, closes the
repository, reopens it, and reads the same value again.

## Encoding observation

For the sample custom value:

- encoded length: 22 bytes
- first encoded byte: 5
- therefore the encoding does **not** satisfy the declared
  `contents_length_header = Some `Varint` contract.

The first byte is not a length prefix for the complete encoded contents value.

## Matrix

| Contents codec | length-header declaration | indexing strategy | Result after reopen |
| --- | --- | --- | --- |
| `Irmin.Contents.String` | `Some `Varint` | `minimal` | PASS |
| custom derived record | `Some `Varint` | `minimal` | FAIL: `Invalid_argument("index out of bounds")` |
| custom derived record | `Some `Varint` | `minimal_with_contents` | FAIL: `Invalid_argument("index out of bounds")` |
| custom derived record | `Some `Varint` | `always` | FAIL: `Invalid_argument("index out of bounds")` |
| custom derived record | `None` | `minimal` | FAIL: dangling hash |
| custom derived record | `None` | `always` | PASS |

The dangling-hash case was:

```
Irmin.Tree.find_all: encountered dangling hash
48dd0be1bf07bffe229ee80dfddd11bc155102fed1a2fa661a971f0eee150382d591264a6036b95998720bc2c0ac280e9ee9a62a0255c8a64d14cfd5c338949f
```

## Interpretation

The matrix separates two independent integrity obligations.

### 1. Codec/header agreement

If `contents_length_header = Some `Varint`, the contents codec must actually
encode a leading Varint that describes the complete contents payload length.

Violating this obligation fails independently of whether Contents is indexed:
all three indexing strategies above fail with an out-of-bounds decode.

### 2. Hash/location recoverability

If `contents_length_header = None`, the reader cannot reconstruct a direct
Contents key from an offset alone because the entry length is unknown.

In that mode, a persisted hash reference requires a durable hash-to-location
mapping. The real implementation therefore reproduces the same boundary as the
TLA+ model:

- omit Contents from the index => dangling hash after reopen;
- index Contents => reopen succeeds.

## Formal configuration predicate

The observed boundary can be summarized as an admissibility condition:

```text
Admissible(codec, header, strategy) :=
  (header = Varint -> CodecHasCorrectVarintPrefix(codec))
  /\
  (header = None -> StrategyIndexesContents(strategy))
```

The current evidence supports both conjuncts independently.

This predicate is a statement about configuration safety. It does not yet
establish that Irmin has an implementation correctness bug, because the pinned
Irmin documentation already describes both underlying preconditions.

## Upstream relevance

The remaining potentially actionable question is narrower:

> Can Irmin reject or make unrepresentable inadmissible combinations early,
> instead of allowing them to persist data successfully and fail later during
> reopen/read?

That is a configuration-safety / diagnostics question, not the same claim as
"irmin-pack cannot handle non-String contents."
