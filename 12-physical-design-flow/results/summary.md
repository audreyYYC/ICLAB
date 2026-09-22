# Backend APR Flow Summary

## Design scope

This Lab 12 exercise used a TA-provided synthesized netlist for a static-timing graph analyzer. The student work began at physical-design import and did not include ownership of the RTL or synthesis implementation.

The backend target was 180-nm CMOS with an 11 ns clock constraint.

## Implementation sequence

1. **Import and analysis setup** - Load the provided netlist and constraints, then establish setup and hold analysis views.
2. **Floorplan and I/O planning** - Define die/core dimensions and place I/O, power, and corner pads.
3. **Power delivery** - Create core rings, internal stripes, standard-cell rails, and global power connections.
4. **Placement optimization** - Place standard cells, inspect density and congestion, and repair timing and electrical-rule issues.
5. **Clock-tree synthesis** - Distribute the clock, balance skew and insertion delay, and re-evaluate setup and hold timing.
6. **Detailed routing** - Route signal nets, extract post-route parasitics, and perform post-route optimization.
7. **Verification** - Run post-route STA, physical DRC, Innovus connectivity checks, and post-layout simulation.
8. **Power integrity** - Run power and rail analysis and compare maximum IR drop with the 1 mV course requirement.

## Final checks

| Check | Outcome |
| --- | ---: |
| Placement density | 52.088% |
| Setup WNS | +0.106 ns |
| Hold WNS | +0.273 ns |
| Setup/hold violating paths | 0 |
| Electrical design-rule violations | 0 |
| Physical DRC violations | 0 |
| Connectivity errors/warnings | 0 |
| Post-layout functional simulation | Passed, 50,000 cycles |
| Maximum IR drop | 0.70095 mV |
| IR-drop requirement | <1 mV |

## Design interpretation

The final positive setup and hold slack indicates that the implemented clock and data paths met both timing directions after routed parasitics were included. Zero capacitance, transition, and fanout violations indicates that electrical repair completed cleanly. DRC and connectivity checks confirm a physically consistent routed database under the academic flow.

The most important lesson was the interaction among implementation decisions: pad and macro placement influenced routing demand, power structures consumed routing tracks, clock-tree choices shifted setup and hold margins, routing parasitics required post-CTS re-optimization, and power-pad distribution affected the maximum rail drop.
