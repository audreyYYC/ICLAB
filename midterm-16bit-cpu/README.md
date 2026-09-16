# Custom 16-Bit CPU

A multicycle RISC-style processor with 16 architectural registers, a compact custom ISA, local SRAM buffering, and separate instruction/data traffic over AXI-style memory channels.

## At a glance

| Item | Implementation |
| --- | --- |
| Datapath width | 16 bits |
| Register file | Sixteen signed 16-bit architectural registers |
| Instruction formats | R, I, and J |
| ISA | ADD, SUB, signed SLT, low-16-bit multiply, load, store, branch-equal, jump |
| External memory | Two read ports and one write port with independent AXI-style handshakes |
| RTL | [src/CPU.v](src/CPU.v) |
| Verification data | [verification/gen_DRAM.py](verification/gen_DRAM.py) |

## Microarchitecture

The core is controlled by a multicycle FSM rather than a fixed five-stage pipeline. Its states separate instruction lookup, miss-address and refill traffic, decode, execution, data access, store address/data/response handshakes, and architectural completion.

A local SRAM is partitioned for instruction and data buffering. Each side tracks a valid bit and base address; a hit is detected when the requested byte address lies within the current 128-byte window. On a miss, the controller issues a burst read, fills the local SRAM, and resumes the interrupted instruction.

## Datapath and control

- The decoder extracts three-bit opcodes, two register operands, a destination, a signed five-bit immediate, or a 13-bit jump target.
- ADD, SUB, and signed comparison share the ALU path.
- Multiplication is decomposed into four-bit partial products and recombined to produce the low 16 bits.
- Loads wait for a data-buffer hit/refill before register writeback.
- Stores use distinct address, data, and response channel states.
- Branch and jump logic updates the byte-addressed program counter; ordinary instructions advance it by two bytes.
- IO_stall deasserts for one cycle when an instruction has architecturally completed.

## Verification

The Python utility generates instruction and data memory images for simulation. It was developed with AI assistance, then reviewed, adapted, and used by the author. The course pseudo-DRAM and official checker are excluded.

