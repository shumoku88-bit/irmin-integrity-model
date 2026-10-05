# irmin-integrity-model

A small formal-methods experiment about integrity properties in `irmin-pack`.

## Question

Under what conditions is it safe for an indexing strategy to omit `Contents`
objects from the index while preserving store integrity across flush/reopen?

This repository starts from the public contract of
`Irmin_pack.Indexing_strategy.minimal`: indexing less should not change
correctness, and `minimal` should preserve store integrity.

The first target is the family of reports in:

- mirage/irmin#2369 — dangling hash with non-string contents
- mirage/irmin#2389 — handling of non-`String` contents / length headers

## Method

1. Model only references, pack entries, index entries, flush, reopen, and resolve.
2. State one safety invariant: every reachable persisted reference remains
   resolvable after reopen.
3. Compare `Minimal` and `Always` as observable behaviours, ignoring
   performance-only differences such as offsets and index size.
4. Ask TLC for a counterexample.
5. Only if the model yields a new condition or counterexample, map that result
   back to the real Irmin implementation.
6. Do not file an upstream issue or PR merely from code inspection.

## Non-goals

- Reimplementing Irmin.
- Claiming that mirage/irmin#2369 and #2389 have the same root cause.
- Treating an abstract-model counterexample as an implementation bug without
  validating the corresponding implementation transition.
- Growing this into a general storage framework before the first invariant has
  taught us something.

## Status

Initial research scaffold. No upstream claim has been established yet.
