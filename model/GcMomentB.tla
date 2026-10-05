-------------------------- MODULE GcMomentB --------------------------
EXTENDS Naturals, TLC

(*
A focused model of lower-layer startup recovery after a crash at the
documented GC "Moment B":

  - upper control already names the new generation;
  - volume.control still contains the old range;
  - volume.<generation>.control contains the new range.

At startup, Lower.v loads volume.control into an in-memory Volume.t. Cleanup
then renames the generation control over volume.control. The question is
whether the already-loaded in-memory routing metadata is refreshed.
*)

CONSTANT ReloadAfterCleanup

ASSUME ReloadAfterCleanup \in BOOLEAN

OldEnd == 10
NewEnd == 20
ProbeOffset == 15

VARIABLES diskEnd, tmpEnd, memoryEnd, phase, outcome

vars == <<diskEnd, tmpEnd, memoryEnd, phase, outcome>>

Init ==
  /\ diskEnd = OldEnd
  /\ tmpEnd = NewEnd
  /\ memoryEnd = 0
  /\ phase = "CrashMomentB"
  /\ outcome = "None"

LoadLower ==
  /\ phase = "CrashMomentB"
  /\ memoryEnd' = diskEnd
  /\ UNCHANGED <<diskEnd, tmpEnd, outcome>>
  /\ phase' = "LowerLoaded"

CleanupSwap ==
  /\ phase = "LowerLoaded"
  /\ diskEnd' = tmpEnd
  /\ tmpEnd' = 0
  /\ memoryEnd' =
       IF ReloadAfterCleanup
       THEN diskEnd'
       ELSE memoryEnd
  /\ UNCHANGED outcome
  /\ phase' = "Recovered"

ReadNewlyArchivedOffset ==
  /\ phase = "Recovered"
  /\ outcome' =
       IF ProbeOffset < memoryEnd
       THEN "Success"
       ELSE "VolumeNotFound"
  /\ UNCHANGED <<diskEnd, tmpEnd, memoryEnd>>
  /\ phase' = "Read"

Done ==
  /\ phase = "Read"
  /\ UNCHANGED vars

Next ==
  \/ LoadLower
  \/ CleanupSwap
  \/ ReadNewlyArchivedOffset
  \/ Done

Spec ==
  Init /\ [][Next]_vars

TypeOK ==
  /\ diskEnd \in {OldEnd, NewEnd}
  /\ tmpEnd \in {0, NewEnd}
  /\ memoryEnd \in {0, OldEnd, NewEnd}
  /\ phase \in {"CrashMomentB", "LowerLoaded", "Recovered", "Read"}
  /\ outcome \in {"None", "Success", "VolumeNotFound"}

DiskRecovery ==
  phase \in {"CrashMomentB", "LowerLoaded"} \/ diskEnd = NewEnd

RoutingSafety ==
  phase # "Read" \/ outcome = "Success"

=============================================================================
