# H.264 Lite Prediction and Transform Engine (HLPTE)
**Video encoding accelerator with SRAM-based macroblock processing and multi-mode intra prediction**

## System Overview
Hardware implementation of H.264/AVC video compression pre-entropy encoder. Designed for real-time video encoding with spatial prediction, integer transform, and quantization for efficient video compression at reduced bitrates.

## Verified Performance Results

### Timing & Area (UMC 0.18μm)
- **Cycle Time**: 11.8ns
- **Total Cell Area**: 1,993,640 μm²
- **Processing Latency**: ~1,000 cycles per macroblock set
- **Technology**: UMC 0.18μm standard cell library

### Verification Status
- **RTL Simulation**: Functional verification passed
- **Synthesis**: Latch-free implementation with timing closure
- **Gate-Level Simulation**: Post-synthesis verification confirmed
- **SRAM Integration**: Custom memory compiler integration verified

## Key Technical Features

### H.264 Video Encoding Pipeline
- **Macroblock Partitioning**: 128×128 pixel frame processing (16×16 macroblocks)
- **Dual Intra Prediction Modes**: 
  - Intra 16×16: Directional prediction (Vertical, Horizontal, DC)
  - Intra 4×4: 9-mode prediction including diagonal directions
- **Integer Transform**: 4×4 Hadamard transform for DCT-like frequency representation
- **Adaptive Quantization**: QP-based compression control (QP range: 0-29)

### SRAM Memory Architecture
- **Custom Memory Design**: Self-generated SRAM modules for frame storage
- **Frame Buffer**: 16,384-cycle continuous data input (128×128 pixels)
- **Reconstruction Buffer**: Stores decoded reference pixels for prediction
- **Flexible Configuration**: Designer-specified word/bit width optimization

### Advanced Video Compression Features
- **Spatial Prediction**: Exploits intra-frame pixel correlation
- **Residual Encoding**: Original minus predicted pixel differences
- **Transform Coding**: Integer transform for frequency domain representation
- **Rate-Distortion Optimization**: QP-controlled quality vs. compression tradeoff

## Implementation Specifications

- **Input Processing**: 128×128 grayscale frame (8-bit unsigned pixels)
- **Prediction Modes**: 16 macroblock sets with configurable intra modes
- **Output Format**: 32-bit signed quantized coefficients (1,024 per set)
- **Processing Efficiency**: ~1,000 cycles per macroblock set (well within 10,000-cycle constraint)
- **Area Constraint**: <3,500,000 μm² total cell area

## Performance Characteristics

- **Multi-Mode Processing**: Dynamic switching between Intra 16×16 and 4×4
- **Pipeline Efficiency**: Overlapped prediction, transform, and quantization stages
- **Memory Bandwidth**: Optimized SRAM access patterns for reconstruction data
- **Compression Quality**: QP-adjustable rate-distortion performance
- **Throughput**: 16 macroblock sets per frame with efficient state machine control

## Application Domains

- **Video Streaming**: Real-time encoding for adaptive bitrate streaming
- **Video Conferencing**: Low-latency compression for telepresence systems
- **Mobile Video**: Power-efficient encoding for smartphone cameras
- **Broadcast Television**: High-quality video compression for transmission

## Note on SRAM Files
This design integrates Faraday SRAM compiler IP (4096 words × 32 bits, single-port synchronous SRAM). The SRAM files (MEM.v, MEM_WC.db) are proprietary and not included in this public repository per Faraday Technology Corp. licensing terms.

*Production-ready H.264 video encoding engine for embedded video compression and streaming applications*
