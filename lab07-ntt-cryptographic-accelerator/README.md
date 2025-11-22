# Number Theoretic Transform Cryptographic Accelerator
**Multi-clock domain NTT processor with CDC-verified handshake and FIFO synchronizers for post-quantum cryptography**

## System Overview
Hardware implementation of 128-point Number Theoretic Transform (NTT) for polynomial ring arithmetic in cryptographic applications. Features three asynchronous clock domains with formal CDC verification, custom synchronizers (Handshake and FIFO), and Montgomery multiplication for modular arithmetic over finite field Q=12289.

## Verified Performance Results

### Timing & Area (UMC 0.18μm)
- **Clock Domains**: 3 asynchronous clocks (clk1: input, clk2: compute, clk3: output)  
- **Cycle Time (clk3)**: 20.7ns (validated at 3.1ns, 4.1ns, 11.1ns, 20.7ns)
- **Total Cell Area**: 515,867 μm²
- **Processing Latency**: 430 cycles (clk3 domain, well under 5,000-cycle constraint)
- **Technology**: UMC 0.18μm standard cell library

### Verification Status
- **RTL Simulation**: Multi-clock functional verification passed
- **Synthesis**: Latch-free implementation with timing closure
- **Gate-Level Simulation**: Post-synthesis verification with no timing violations
- **CDC Verification**: Jasper Gold formal verification - all properties proven
  - 3 clock domains detected
  - 152 CDC pairs identified
  - 2 synchronizer schemes verified (Handshake + FIFO)
  - 11/11 protocol properties proven
- **Prime Time**: Static timing analysis passed across all clock domains

## Key Technical Features

### NTT Cryptographic Core (CLK_2_MODULE)
- **Algorithm**: Radix-2 Cooley-Tukey NTT with degree n=128
- **Arithmetic**: Montgomery multiplication over finite field (Q=12289, Q0I=12287)
- **Butterfly Units**: Pipelined structure with modular add/subtract operations
- **Twiddle Factors**: Pre-computed GMb constants for efficient rotation
- **SRAM Integration**: Dual-port 64×16 memory for coefficient buffering

### Clock Domain Crossing Architecture
- **3 Asynchronous Domains**:
  - **clk1**: Input buffering and serialization (32-bit → 4-bit coefficients)
  - **clk2**: NTT computation core with Montgomery multipliers
  - **clk3**: Output deserialization (variable 3.1-20.7ns operation)
- **CDC Synchronizers**:
  - **Handshake (clk1→clk2)**: 4-phase protocol with ready/valid/ack signals
  - **FIFO (clk2→clk3)**: 64-word async FIFO with Gray-code pointers
- **Formal Verification**: Jasper Gold CDC verification with protocol proofs

### Handshake Synchronizer
- **Protocol**: 4-phase handshake with data stability guarantees
- **Width**: Parametric (32-bit data path)
- **Properties Proven**:
  - Source request hold time
  - Destination acknowledgment stability
  - Data stability at destination
  - New request/ack detection

### FIFO Synchronizer  
- **Configuration**: 64 words × 16 bits
- **Pointer Synchronization**: Gray-code encoding for safe CDC
- **Full/Empty Flags**: Dual-clock safe generation
- **Properties Proven**:
  - No write-on-full violations
  - No read-on-empty violations
  - Gray-code pointer correctness

## Implementation Specifications

- **Input**: 128 polynomial coefficients (16-bit each, 16 cycles × 8 coefficients)
- **Output**: 128 NTT-transformed coefficients (16-bit each, 128 cycles non-continuous)
- **Modular Arithmetic**: Montgomery multiplication with R=2^16
- **NTT Stages**: 7 stages (log₂(128)) with butterfly operations
- **Latency**: 430 clk3 cycles from in_valid falling to out_valid completion
- **Area Efficiency**: 516k μm² (74% under 2M limit)

## Design Methodology

### Multi-Clock Domain Strategy
1. **Input Domain (clk1)**: Deserialize 32-bit input into polynomial coefficients
2. **Handshake CDC**: Transfer coefficients from clk1 to clk2 with protocol verification
3. **Compute Domain (clk2)**: Execute NTT algorithm with Montgomery arithmetic
4. **FIFO CDC**: Buffer results from clk2 to clk3 with Gray-code synchronization
5. **Output Domain (clk3)**: Serialize NTT results at variable clock rates

### NTT Algorithm Implementation
- **Radix-2 Structure**: Iterative butterfly units across 7 stages
- **Montgomery Reduction**: Efficient modular multiplication without division
- **Memory Optimization**: Dual-port SRAM enables parallel coefficient access
- **Pipeline Efficiency**: Overlapped computation and memory access

### CDC Verification Flow
```
Jasper Gold Formal Verification:
├── Clock Domain Detection (3 domains)
├── CDC Pair Analysis (152 crossings)
├── Synchronizer Scheme Recognition
│   ├── Handshake: data stability proven
│   └── FIFO: Gray-code pointer correctness proven
└── Protocol Property Verification (11/11 proven)
```

## Performance Characteristics

- **Multi-Rate Operation**: Validated at 4 different clk3 frequencies
- **Low Latency**: 430 cycles (9.1% of maximum allowed latency)
- **Area Efficient**: 26% of area budget with full CDC verification
- **Formally Verified**: All CDC properties mathematically proven (no simulation gaps)

## Application Domains

- **Post-Quantum Cryptography**: Lattice-based schemes (CRYSTALS-Kyber, Dilithium)
- **Homomorphic Encryption**: Privacy-preserving computation acceleration
- **Digital Signatures**: Fast polynomial multiplication for signature schemes
- **Secure Communication**: Real-time cryptographic protocol engines

## Design Files

- `src/DESIGN_module.v` - Three clock domain modules (input, compute, output)
- `src/Handshake_syn.v` - 4-phase handshake synchronizer with protocol verification
- `src/FIFO_syn.v` - Async FIFO with Gray-code pointers and formal guarantees
- `src/NTT_TOP.v` - Top-level multi-clock integration (TA-provided wrapper)
- `jg.tcl` - Jasper Gold CDC verification script with property definitions

## CDC Verification Highlights

**Formal Proof Results:**
- ✓ Handshake data stability (source & destination)
- ✓ Request/acknowledgment hold times
- ✓ FIFO full/empty flag correctness
- ✓ Gray-code pointer encoding
- ✓ No metastability-induced data corruption
- ✓ All 11 protocol properties proven in <31 seconds

*Production-ready NTT accelerator with formally verified clock domain crossing for post-quantum cryptography applications*
