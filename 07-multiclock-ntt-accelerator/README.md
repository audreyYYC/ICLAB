# Multiclock NTT Accelerator

A 128-point Number Theoretic Transform subsystem spanning three asynchronous clock domains. The project combines finite-field arithmetic with explicit clock-domain-crossing structures and formal CDC verification.

## At a glance

| Clock domain | Responsibility | Transfer mechanism |
| --- | --- | --- |
| clk1 | Capture 128 four-bit coefficients over 16 cycles | Request/acknowledge handshake |
| clk2 | Execute the seven-stage radix-2 NTT | Local compute array |
| clk3 | Drain and serialize 128 transformed coefficients | Asynchronous FIFO |

| Arithmetic | Value |
| --- | ---: |
| Transform size | 128 points |
| Modulus Q | 12289 |
| Montgomery radix R | 2^16 |
| Main RTL | [src/DESIGN_module.v](src/DESIGN_module.v) |
| CDC RTL | [src/Handshake_syn.v](src/Handshake_syn.v), [src/FIFO_syn.v](src/FIFO_syn.v) |

## Compute architecture

The clk2 domain stores 128 coefficients and iterates through radix-2 butterfly stages. Each butterfly computes a twiddle-factor product with Montgomery reduction, followed by modular sum and difference:

\[
v=x[j+h_t]\cdot s\pmod Q,\qquad
x[j]=(u+v)\pmod Q,\qquad
x[j+h_t]=(u-v)\pmod Q
\]

Loop-index counters generate the butterfly addresses, stage stride, and twiddle index. Predefined twiddle constants are held in RTL, while intermediate widths accommodate the multiply-and-reduce path.

## Clock-domain crossing

- The input handshake keeps the source request asserted until the destination captures a stable 128-coefficient payload and returns acknowledgement.
- The output asynchronous FIFO uses independently clocked read/write pointers, Gray-code synchronization, and full/empty detection.
- FIFO storage is represented by a generic dual_port_sram_64x16 placeholder; the licensed course memory model is excluded.
- CDC structures were checked with JasperGold using the course formal flow.

## Repository scope

The student compute and synchronizer modules are included. The instructor top-level wrapper, synchronizer primitives, formal script, and proprietary SRAM collateral are not published, so this directory documents a subsystem rather than a standalone build.

