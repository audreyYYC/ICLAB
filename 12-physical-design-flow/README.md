# Physical Design Flow

A chip-level implementation case study covering the transition from synthesized netlist to routed layout and post-layout verification in Cadence Innovus.

## Flow at a glance

| Stage | Work performed |
| --- | --- |
| Design setup | Imported the netlist and timing constraints; configured analysis views |
| Floorplanning | Defined die/core geometry and placed macros and I/O pads |
| Power planning | Built core rings and power stripes and checked connectivity |
| Placement | Placed and optimized standard cells while reviewing density and congestion |
| Clock tree synthesis | Built the clock network and evaluated skew, latency, setup, and hold |
| Routing | Completed signal routing and post-route optimization |
| Signoff checks | Reviewed timing, DRC, connectivity/LVS, power, IR drop, and post-layout simulation |

## Selected results

| Metric | Result |
| --- | ---: |
| Placement density | 52.088% |
| Post-route setup WNS | +0.106 ns |
| Post-route hold WNS | +0.273 ns |
| Capacitance violations | 0 |
| Transition violations | 0 |
| Fanout violations | 0 |
| DRC violations | 0 |
| Connectivity errors/warnings | 0 |
| Post-layout simulation | Passed |

## Main engineering takeaway

Physical implementation is a coupled optimization problem. Macro and I/O placement affect routing demand; the power grid consumes routing resources; clock insertion changes setup and hold behavior; and post-route parasitics can invalidate decisions that looked safe before detailed routing. This project required iterating across those views rather than treating floorplan, timing, power, and verification as independent checkboxes.

A concise stage-by-stage discussion is available in [results/summary.md](results/summary.md).

## Repository scope

Only a sanitized technical summary is public. Raw reports, screenshots, scripts, I/O constraints, netlists, timing files, tool databases, library identifiers, and foundry/PDK collateral are intentionally excluded.

