# SystemVerilog RPG Controller

A DRAM-backed transaction processor that maintains persistent player records and applies five state-changing game operations with rule checks, saturation handling, and prioritized warnings.

## At a glance

| Item | Implementation |
| --- | --- |
| Language features | SystemVerilog interfaces, packages, structs/enums, always_ff, and always_comb |
| Operations | Login, level up, battle, use skill, and inactivity check |
| Persistent state | Date, experience, MP, HP, attack, and defense fields per player |
| Memory protocol | Independent address, data, and response handshakes |
| RTL | [src/RPG.sv](src/RPG.sv) |
| Verification data | [verification/generate_dram.py](verification/generate_dram.py) |

## Transaction flow

**Capture operation fields -> read player record -> compute/check -> optionally write updated record -> return status**

Seven non-overlapping valid signals deliver action-specific inputs. The controller waits until all fields required for the chosen action have arrived, calculates the selected player's record address, and performs a memory read. A compute phase applies the operation rules and chooses a warning according to the required priority.

Only successful operations and saturation-qualified updates proceed to the write channels. Other warning conditions leave DRAM unchanged and return directly to the one-cycle output response. Separating read, compute, write-address, write-data, and write-response states keeps each ready/valid handshake independent.

## Datapath behavior

- Login logic handles consecutive-date rewards and month/year boundaries.
- Level-up modes use different attribute-update formulas, including ordering-based calculations and saturating arithmetic.
- Battle compares attack/defense/HP values and updates both experience and player attributes.
- Skill use accumulates MP cost and rejects insufficient resources.
- Inactivity checking computes elapsed calendar time from stored and current dates.

## Repository scope

RPG.sv depends on the course type/interface package for declarations and top-level connectivity. That instructor-provided package, the official testbench, and pseudo-DRAM are not included. The Python DRAM generator was developed with AI assistance and manually reviewed and adapted.

