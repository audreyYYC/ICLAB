# APR Flow Summary

The design was implemented from a synthesized gate-level netlist through a standard digital APR sequence:

1. Import the netlist and constraints and configure analysis views.
2. Establish die/core geometry and place macros and IOs.
3. Build the power grid and verify connectivity.
4. Place and optimize standard cells while monitoring timing and congestion.
5. Synthesize the clock tree and evaluate skew, latency, and hold/setup impact.
6. Route signals, repair violations, and review post-route timing and physical checks.

The main learning outcome was understanding how RTL and synthesis choices affect physical feasibility. Congestion, macro placement, clock distribution, and timing closure are coupled rather than independent steps.

No numerical signoff results or process-specific information are published here because the original reports depend on restricted course/foundry collateral.

