# Cryptographic Packet Arbiter (MPCA)

**Advanced network packet processor with SPECK32/64 encryption and intelligent channel arbitration**

## System Overview
High-performance packet arbiter implementing lightweight cryptographic security with priority-based scheduling and dynamic load balancing for multi-channel communication systems.

## Key Technical Features
- SPECK32/64 Block Cipher: 4-round ARX (Addition, Rotation, XOR) encryption with hardware key scheduling
- Priority Scheduling: Multi-factor QoS-aware packet prioritization with signed/unsigned mode support
- Dynamic Load Balancing: Global channel rebalancing with constraint satisfaction algorithms
- Round-Robin Fallback: Pivot-based search optimization for channel allocation efficiency

## Verified Performance Results

### Timing & Area (UMC 0.18μm)
- Cycle Time: 31.4ns
- Total Cell Area: 247,321 μm²
- Technology: UMC 0.18μm standard cell library

### Verification Status
- RTL Simulation: Functional verification passed
- Synthesis: Latch-free implementation with timing closure
- Gate-Level Simulation: Post-synthesis verification confirmed
- Pattern Coverage: All test cases including hidden patterns

## Implementation Specifications
- Input Processing: 8 encrypted packets (128 bits) with 64-bit SPECK key
- Channel Management: 3 configurable channels with capacity control (0-7 packets each)
- Output Format: 16-bit allocation vector (2 bits per packet: 00/01/10 = channels 0/1/2, 11 = unallocated)
- Design Style: Combinational logic for single-cycle packet processing

## Algorithm Features\
- Packet Decryption: Hardware-accelerated SPECK32/64 with dynamic subkey generation
- Priority Calculation: `(qos-2)*4 + (pkt_len-8)*(-2) + (1-congestion)*3 + (src_hint-4)`
- Mask Policy: Threshold-based quality filtering with channel load consideration
- Load Balancing: Automatic rebalancing when channel load exceeds 50% of combined others

*Production-ready cryptographic packet processing for network infrastructure and SoC integration*
