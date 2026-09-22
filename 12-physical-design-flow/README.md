# Backend APR and Power Analysis: Static-Timing Graph Analyzer

A backend physical-design case study implementing a TA-provided static-timing graph analyzer netlist in 180-nm CMOS. The design accepts graph edges with source, destination, and delay fields, then reports the worst-case accumulated delay and corresponding critical path.

The RTL and synthesized netlist were provided by the course; my work focused on chip-level physical implementation, timing closure, physical verification, power analysis, and rail integrity rather than front-end RTL design. This exercise is separate from the MVDM final project and the GTE RTL project.

## Implementation flow

| Stage | Work performed |
| --- | --- |
| Design setup | Imported the provided synthesized netlist, constraints, I/O assignment, and setup/hold analysis views |
| Floorplanning | Defined die/core geometry and placed I/O, power, and corner pads |
| Power planning | Designed core rings, power stripes, standard-cell rails, and global power connectivity |
| Placement | Placed and optimized standard cells while reviewing density and routing congestion |
| Clock-tree synthesis | Built the clock network and analyzed setup, hold, skew, and insertion delay |
| Routing | Performed timing-driven routing, parasitic extraction, and post-route optimization |
| Verification | Ran post-route STA, electrical-rule checks, DRC, connectivity checks, and post-layout simulation |
| Power integrity | Performed power and rail analysis and checked maximum IR drop against the 1 mV requirement |

## Final implementation results

| Metric | Result |
| --- | ---: |
| Technology | 180-nm CMOS |
| Post-route clock constraint | 11 ns |
| Placement density | 52.088% |
| Setup WNS | +0.106 ns |
| Hold WNS | +0.273 ns |
| Setup/hold violating paths | 0 |
| Capacitance/transition/fanout violations | 0 |
| DRC violations | 0 |
| Connectivity errors/warnings | 0 |
| Post-layout simulation | Passed, 50,000 cycles |
| Maximum IR drop | 0.70095 mV |
| IR-drop requirement | <1 mV |

The positive setup and hold slack values are from the routed design with extracted parasitics. The connectivity result refers to the Innovus `verifyConnectivity` check; it is not presented as a separate extracted-layout-versus-schematic run.

## Main engineering takeaway

Backend implementation is a coupled optimization problem. I/O and power-pad placement affect the delivery network; rings and stripes consume routing resources; placement density changes congestion; clock-tree decisions shift setup and hold margins; and routed parasitics require re-evaluation after CTS. The final rail analysis also showed how pad distribution and the power grid determine worst-case voltage drop across the core.

A concise stage-by-stage discussion is available in [results/summary.md](results/summary.md).

## Repository scope

Only a sanitized technical summary is public. The TA-provided netlist, assignment/testbench files, raw reports, screenshots, scripts, I/O constraints, SDF, timing files, tool databases, library identifiers, and foundry/PDK collateral are intentionally excluded.
