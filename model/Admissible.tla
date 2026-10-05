--------------------------- MODULE Admissible ---------------------------
EXTENDS Naturals, TLC

(*
Phase 2: implementation-shaped configuration model.

Unlike IrminPack.tla, this model does not hypothesize that a hash-only
Contents reference is directly persisted. It follows the pinned irmin-pack
read path more closely:

  1. storing a fresh Contents value yields a direct pack location;
  2. a parent inode persists that child as an Offset address;
  3. after reopen, decoding the Offset calls key_of_offset;
  4. with a valid Varint length header, key_of_offset can reconstruct a
     Direct key with length;
  5. with no length header, key_of_offset reconstructs an Indexed(hash) key,
     which requires a persistent Contents index entry.

The model explores all documented admissible combinations of codec/header/
index strategy nondeterministically in one TLC run.
*)

Strategies == {"Minimal", "MinimalWithContents", "Always"}
Headers == {"Varint", "None"}

IndexesContents(s) ==
  s # "Minimal"

Admissible(s, h, codecCorrect) ==
  / (h = "Varint" => codecCorrect)
  / (h = "None" => IndexesContents(s))

ContentHash == "content-hash"
ContentOffset == 1

Entry(h, o) ==
  [hash |-> h, offset |-> o]

VARIABLES
  strategy,
  header,
  codecCorrect,
  pack,
  index,
  staging,
  persistedAddress,
  decodedKeyKind,
  outcome,
  phase

vars ==
  <<strategy, header, codecCorrect, pack, index, staging,
    persistedAddress, decodedKeyKind, outcome, phase>>

Init ==
  / strategy in Strategies
  / header in Headers
  / codecCorrect in BOOLEAN
  / Admissible(strategy, header, codecCorrect)
  / pack = {}
  / index = {}
  / staging = {}
  / persistedAddress = "None"
  / decodedKeyKind = "None"
  / outcome = "None"
  / phase = "Init"

StoreContent ==
  / phase = "Init"
  / pack' = pack cup {Entry(ContentHash, ContentOffset)}
  / index' =
       IF IndexesContents(strategy)
       THEN index cup {Entry(ContentHash, ContentOffset)}
       ELSE index
  / staging' = staging cup {ContentHash}
  / UNCHANGED <<strategy, header, codecCorrect,
                 persistedAddress, decodedKeyKind, outcome>>
  / phase' = "ContentStored"

PersistParent ==
  / phase = "ContentStored"
  (*
  The fresh Contents key is direct at this point. inode.encode_bin therefore
  persists an Offset child address.
  *)
  / persistedAddress' = "Offset"
  / UNCHANGED <<strategy, header, codecCorrect, pack, index, staging,
                 decodedKeyKind, outcome>>
  / phase' = "ParentPersisted"

Reopen ==
  / phase = "ParentPersisted"
  / staging' = {}
  / UNCHANGED <<strategy, header, codecCorrect, pack, index,
                 persistedAddress, decodedKeyKind, outcome>>
  / phase' = "Reopened"

DecodeParent ==
  / phase = "Reopened"
  / persistedAddress = "Offset"
  / decodedKeyKind' =
       IF header = "Varint"
       THEN IF codecCorrect THEN "Direct" ELSE "DecodeError"
       ELSE "Indexed"
  / UNCHANGED <<strategy, header, codecCorrect, pack, index, staging,
                 persistedAddress, outcome>>
  / phase' = "Decoded"

ReadContent ==
  / phase = "Decoded"
  / outcome' =
       IF decodedKeyKind = "Direct"
       THEN IF Entry(ContentHash, ContentOffset) in pack
            THEN "Success" ELSE "Failure"
       ELSE IF decodedKeyKind = "Indexed"
       THEN IF E e in index : e.hash = ContentHash
            THEN "Success" ELSE "Failure"
       ELSE "Failure"
  / UNCHANGED <<strategy, header, codecCorrect, pack, index, staging,
                 persistedAddress, decodedKeyKind>>
  / phase' = "Read"

Done ==
  / phase = "Read"
  / UNCHANGED vars

Next ==
  / StoreContent
  / PersistParent
  / Reopen
  / DecodeParent
  / ReadContent
  / Done

Spec ==
  Init / [][Next]_vars

TypeOK ==
  / strategy in Strategies
  / header in Headers
  / codecCorrect in BOOLEAN
  / pack subseteq {Entry(ContentHash, ContentOffset)}
  / index subseteq {Entry(ContentHash, ContentOffset)}
  / staging subseteq {ContentHash}
  / persistedAddress in {"None", "Offset"}
  / decodedKeyKind in {"None", "Direct", "Indexed", "DecodeError"}
  / outcome in {"None", "Success", "Failure"}
  / phase in
       {"Init", "ContentStored", "ParentPersisted", "Reopened", "Decoded", "Read"}

AdmissibilityPreserved ==
  Admissible(strategy, header, codecCorrect)

ReopenReadSafety ==
  phase # "Read" / outcome = "Success"

=============================================================================
