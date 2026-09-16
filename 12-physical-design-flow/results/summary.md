# APR Flow Summary

## Implementation sequence

1. **Import and analysis setup** - load the synthesized netlist and constraints, then establish setup/hold analysis views.
2. **Floorplan** - choose die/core dimensions, establish placement rows, and position macros and I/O cells.
3. **Power delivery** - create core rings and internal stripes, connect the power network, and verify connectivity.
4. **Placement optimization** - place standard cells, inspect congestion, and repair timing and design-rule issues.
5. **Clock tree synthesis** - distribute the clock, balance skew and insertion delay, and re-evaluate setup/hold timing.
6. **Detailed routing** - route signal nets, extract post-route parasitics, and perform post-route optimization.
7. **Verification** - run timing, physical-rule, connectivity, power, IR-drop, and post-layout simulation checks.

## Final checks

| Check | Outcome |
| --- | ---: |
| Setup WNS | +0.106 ns |
| Hold WNS | +0.273 ns |
| Electrical design-rule violations | 0 |
| Physical DRC violations | 0 |
| Connectivity errors/warnings | 0 |
| Post-layout functional simulation | Passed |

## Design interpretation

The final positive setup and hold slack indicates that the implemented clock and data paths met both timing directions after routed parasitics were included. Zero capacitance, transition, and fanout violations indicates that electrical repair completed cleanly. DRC and connectivity results confirm a physically consistent routed database under the restricted academic flow.

The most important lesson was the interaction among decisions: macro placement influenced congestion and wire length, power structures consumed routing tracks, clock-tree choices shifted both setup and hold margins, and routing parasitics required re-optimization after CTS.

