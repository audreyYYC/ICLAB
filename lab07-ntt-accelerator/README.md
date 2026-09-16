# Lab 07 — Multi-Clock NTT Accelerator

A multi-clock Number Theoretic Transform subsystem integrating computation, handshaking, and an asynchronous FIFO. The design exercises safe clock-domain crossing and coordination between independently clocked pipeline stages.

- Sources: `src/DESIGN_module.v`, `src/Handshake_syn.v`, `src/FIFO_syn.v`
- Skills: CDC, asynchronous FIFO design, multi-clock verification, NTT datapaths

The instructor-owned top-level wrapper and foundry SRAM model are excluded. In `FIFO_syn.v`, the foundry macro identifier was replaced by the generic placeholder `dual_port_sram_64x16`.

