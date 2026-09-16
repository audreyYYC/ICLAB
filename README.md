# Digital IC Design Portfolio

Selected coursework from Integrated Circuit Design Laboratory (積體電路設計實驗) at National Yang Ming Chiao Tung University (NYCU), Fall 2025. This intensive, project-based course covered RTL architecture, functional verification, synthesis, static timing analysis, clock-domain crossing, formal verification, gate-level simulation, and complete automatic place-and-route.


## Portfolio at a glance

| Design | What I built | Engineering focus |
| --- | --- | --- |
| [Multi-Packet Channel Arbiter](01-multi-packet-channel-arbiter/) | SPECK decryption, priority sorting, capacity-aware allocation, and load rebalance | Combinational datapaths, sorting networks, arbitration |
| [Sudoku Solver](02-sudoku-solver/) | Constraint-propagation engine for 9x9 puzzles | Candidate checking, iterative state updates, FSM control |
| [Convex Hull Processor](03-convex-hull-processor/) | Streaming incremental convex-hull update engine | Signed cross products, linked traversal, variable-length output |
| [CNN Accelerator](04-cnn-accelerator/) | Two floating-point CNN-oriented workloads | Arithmetic scheduling, resource reuse, DesignWare integration |
| [H.264 Processing Engine](05-h264-processing-engine/) | Intra prediction, transform, quantization, and reconstruction | SRAM scheduling, image/video arithmetic, complex control |
| [Poker Win-Rate Calculator](06-poker-win-rate-calculator/) | Parameterized hand evaluator and exhaustive turn/river analysis | Reusable IP, ranking/tie logic, Python golden model |
| [Multiclock NTT Accelerator](07-multiclock-ntt-accelerator/) | 128-point NTT across three asynchronous clock domains | Modular arithmetic, handshake CDC, asynchronous FIFO |
| [SystemVerilog RPG Controller](09-systemverilog-rpg/) | DRAM-backed transactional state machine | SystemVerilog types/interfaces, protocol control, data integrity |
| [16-Bit CPU](midterm-16bit-cpu/) | Custom RISC-style core with separate instruction/data traffic | ISA design, cache refill control, AXI-style handshakes |
| [Geometric Transform Engine](11-geometric-transform-engine/) | 15 image transforms over a heterogeneous SRAM organization | Address generation, memory packing, RTL/Python co-verification |
| [Physical Design Flow](12-physical-design-flow/) | Full synthesis-to-post-layout implementation case study | Floorplanning, power planning, CTS, routing, timing closure |
| [MVDM Accelerator](final-mvdm-accelerator/) | Half-pixel interpolation and SATD-based motion matching | FIR filtering, Hadamard pipeline, SRAM-aware image processing |

## Design flow covered

`Specification -> RTL architecture -> functional simulation -> synthesis -> static timing analysis -> gate-level simulation -> APR -> post-layout verification`

Across the projects, I worked with Verilog/SystemVerilog, Python reference models and pattern generators, Design Compiler, PrimeTime, JasperGold CDC checks, and Cadence Innovus. The individual READMEs focus on architecture, arithmetic, control, memory organization, and verification so each design can be understood without the original course handout.

## Repository scope

This is a curated engineering portfolio, not a course distribution. It intentionally excludes assignment PDFs, instructor testbenches, answer checkers, generated netlists, timing back-annotation, tool databases, standard-cell libraries, memory-compiler output, PDK data, server paths, and raw APR collateral. Proprietary SRAM module names in student RTL were replaced by descriptive placeholders.

The Python verification utilities were developed with AI assistance, then reviewed, adapted, and used by the author. See [NOTICE.md](NOTICE.md) before reusing material. No open-source license is granted.
