------------------------------ MODULE IrminPack ------------------------------
EXTENDS Naturals, TLC

(*
A deliberately tiny model of one irmin-pack integrity boundary.

The model does NOT claim that Irmin currently executes every transition below.
In particular, PersistIndexedContentRef is a hypothesis transition to validate
against the implementation after TLC establishes what safety condition it needs.

We model one Contents object and one persisted parent reference to it.
*)

CONSTANTS Strategy, AllowIndexedContentRef

Strategies == {"Minimal", "Always"}

ASSUME Strategy \in Strategies
ASSUME AllowIndexedContentRef \in BOOLEAN

ContentHash == "content-hash"
ContentOffset == 1

Entry(h, o) ==
  [hash |-> h, offset |-> o]

DirectRef(h, o) ==
  [kind |-> "Direct", hash |-> h, offset |-> o]

IndexedRef(h) ==
  [kind |-> "Indexed", hash |-> h, offset |-> 0]

VARIABLES pack, index, refs, staging, phase

vars == <<pack, index, refs, staging, phase>>

Init ==
  /\ pack = {}
  /\ index = {}
  /\ refs = {}
  /\ staging = {}
  /\ phase = "Init"

StoreContent ==
  /\ phase = "Init"
  /\ pack' = pack \cup {Entry(ContentHash, ContentOffset)}
  /\ index' =
       IF Strategy = "Always"
       THEN index \cup {Entry(ContentHash, ContentOffset)}
       ELSE index
  /\ staging' = staging \cup {ContentHash}
  /\ refs' = refs
  /\ phase' = "ContentStored"

PersistDirectContentRef ==
  /\ phase = "ContentStored"
  /\ refs' = refs \cup {DirectRef(ContentHash, ContentOffset)}
  /\ UNCHANGED <<pack, index, staging>>
  /\ phase' = "Referenced"

PersistIndexedContentRef ==
  /\ phase = "ContentStored"
  /\ AllowIndexedContentRef
  /\ refs' = refs \cup {IndexedRef(ContentHash)}
  /\ UNCHANGED <<pack, index, staging>>
  /\ phase' = "Referenced"

Reopen ==
  /\ phase = "Referenced"
  /\ staging' = {}
  /\ UNCHANGED <<pack, index, refs>>
  /\ phase' = "Reopened"

Done ==
  /\ phase = "Reopened"
  /\ UNCHANGED vars

Next ==
  \/ StoreContent
  \/ PersistDirectContentRef
  \/ PersistIndexedContentRef
  \/ Reopen
  \/ Done

Spec ==
  Init /\ [][Next]_vars

TypeOK ==
  /\ pack \subseteq {Entry(ContentHash, ContentOffset)}
  /\ index \subseteq {Entry(ContentHash, ContentOffset)}
  /\ refs \subseteq
       {DirectRef(ContentHash, ContentOffset), IndexedRef(ContentHash)}
  /\ staging \subseteq {ContentHash}
  /\ phase \in {"Init", "ContentStored", "Referenced", "Reopened"}

DirectResolvable(r) ==
  Entry(r.hash, r.offset) \in pack

IndexedResolvable(r) ==
  \E e \in index : e.hash = r.hash

ResolvableAfterReopen(r) ==
  IF r.kind = "Direct"
  THEN DirectResolvable(r)
  ELSE IndexedResolvable(r)

(*
Safety target:
after volatile staging has been lost on reopen, every persisted reference
must still resolve from durable state alone.
*)
ReopenResolutionSafety ==
  phase # "Reopened"
  \/ \A r \in refs : ResolvableAfterReopen(r)

=============================================================================
