# H.264 Lite Prediction and Transform Engine

An SRAM-based video-processing accelerator that performs simplified H.264 intra prediction, residual generation, integer transform, quantization, inverse processing, and pixel reconstruction on 32x32 grayscale frames.

## At a glance

| Item | Implementation |
| --- | --- |
| Stored workload | Sixteen 32x32, 8-bit luma frames |
| Prediction granularity | Intra 4x4 or Intra 16x16 |
| Candidate modes | DC, horizontal, and vertical, subject to neighbor availability |
| Mode decision | Minimum sum of absolute differences (SAD), with deterministic tie priority |
| Transform path | 4x4 integer transform, quantization, rescaling, inverse transform |
| Source | [src/HLPTE.v](src/HLPTE.v) |

## Processing flow

**SRAM read -> intra prediction -> SAD mode decision -> residual -> integer transform -> quantization -> inverse path -> reconstruction -> SRAM write**

For each block, the engine derives candidate predictions from already reconstructed top and/or left neighbors. It computes SAD against the original block, chooses the lowest-cost legal mode, and forms signed residuals. A separable 4x4 integer transform converts residuals into transform coefficients; quantization uses the supplied QP-dependent multiplier and shift rules.

The reconstruction path rescales and inverse-transforms the quantized coefficients, adds the predicted pixels, clips results to the 8-bit range, and writes them back for use by later blocks. This dependency makes address generation and operation order part of the algorithm, not merely storage plumbing.

## Architecture and control

- A 32-bit SRAM word packs four adjacent 8-bit pixels.
- Frame, macroblock, 4x4-block, row, and column counters generate addresses and sequencing.
- Separate controller phases cover data loading, parameter capture, Intra 4x4/16x16 prediction, residual computation, transform, quantization, output, and reconstruction.
- Wide signed intermediates retain transform and quantization precision before clipping.

## Repository scope

The student controller and datapath RTL are included. The licensed memory model is not; HLPTE.v therefore references a documented external placeholder module named MEM.

