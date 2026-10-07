# Phase 2 TLC result: documented-admissible configurations

## Checked model

- `model/Admissible.tla`
- `model/Admissible.cfg`
- branch commit: `63be113fd66155b526f0693f1be81bbc7578d2f4`
- GitHub Actions run: `37330486811`
- job: `111831994018`
- TLA+ Tools v1.7.4 / TLC2 2.19

## Result

**No counterexample was found in the bounded implementation-shaped model.**

TLC explored every reachable state from all documented-admissible initial
configurations represented by the model:

- 7 distinct initial states
- 49 states generated
- 42 distinct states
- state-graph depth 6
- 0 states left on the queue

TLC reported:

`Model checking completed. No error has been found.`

## Meaning

This closes the simple reopen/read hypothesis for the modeled state space.

After restricting initial states to configurations satisfying the two
documented obligations recovered in Phase 1:

1. `Some `Varint` implies a codec with the required leading length header;
2. `None` implies an indexing strategy that indexes Contents;

the implementation-shaped sequence

`StoreContent -> PersistParent -> Reopen -> DecodeParent -> ReadContent`

preserves `ReopenReadSafety` in the complete bounded state graph.

This is not a proof of all irmin-pack behavior. It says that simply widening the
Phase 1 configuration matrix while respecting the documented preconditions did
not reveal a new defect.

## Research consequence

Do not take the Phase 1 finding upstream as a correctness bug.

The next search dimension should involve state transitions not represented by
this model, especially crash-sensitive multi-file transitions such as GC swap.
