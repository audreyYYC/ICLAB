# Motion Vector Difference Matching Accelerator

A memory-based video-processing accelerator that performs half-pixel interpolation and SATD-based mirror motion-vector matching on two 128x128 reference images.

## At a glance

| Item | Implementation |
| --- | --- |
| Image storage | Two 128x128, 8-bit reference frames in SRAM |
| Sampling | Integer or half-pixel positions in x and y |
| Interpolation | H.264-style six-tap FIR with edge replication |
| Search | Nine points in a 3x3 mirror-motion pattern |
| Similarity metric | Four 4x4 Hadamard SATDs per 8x8 comparison |
| RTL | [src/MVDM.v](src/MVDM.v) |
| Reference model | [verification/algorithms.py](verification/algorithms.py) |
| Pattern generation | [verification/gen_pat.py](verification/gen_pat.py) |

## Processing flow

**Load L0/L1 -> capture two motion-vector pairs -> build interpolated windows -> evaluate nine search points -> select minimum SATD -> serialize results**

Each motion vector contains integer x/y coordinates and one fractional bit per axis. The four interpolation modes are direct sampling, horizontal FIR, vertical FIR, and two-dimensional separable FIR. The six-tap coefficient set is [1, -5, 20, 20, -5, 1]. Out-of-range coordinates are clamped to the nearest image edge.

Horizontal or vertical half-pixel results are rounded, shifted by five, and clipped to 0-255. The two-dimensional path retains the unclipped horizontal intermediate, applies the vertical filter, then rounds and shifts by ten before final clipping.

## SATD pipeline

For each of the nine search points, the engine subtracts the two interpolated 8x8 blocks and divides the residual into four 4x4 sub-blocks. A five-stage datapath performs:

| Stage | Operation |
| --- | --- |
| 1 | Sixteen signed pixel differences |
| 2 | Row-wise 4x4 Hadamard transform |
| 3 | Column-wise Hadamard transform |
| 4 | Absolute-value partial sums |
| 5 | Sub-block SATD accumulation |

The four sub-block costs form the 8x8 SATD. A running minimum records both the cost and search-point index, with the comparison performed in the specified 0-to-8 order.

## Memory and control

Independent L0 and L1 SRAM interfaces allow the two reference windows to be gathered in parallel. A 15x10 signed working buffer provides the neighborhood needed for interpolation and the mirrored search offsets. Controller states separate image loading, motion-vector capture, interpolation, SATD evaluation, and serialized output.

## Verification

The Python reference model reproduces boundary clipping, FIR interpolation, search order, Hadamard arithmetic, and packed output generation. Python-generated golden results cover randomized reference frames, motion vectors, interpolation modes, boundary conditions, and SATD comparisons.

The Python utilities were developed with AI assistance, then reviewed, adapted, and used by the author.

## Physical implementation

The accelerator was taken through synthesis and an academic RTL-to-post-layout flow in 180-nm CMOS.

| Metric | Final result |
| --- | ---: |
| Standard cells | 22,748 |
| SRAM macros | 2 |
| Post-route utilization | 72.155% |
| Final post-route clock constraint | 12 ns |
| Setup WNS | +0.151 ns |
| Hold WNS | +0.110 ns |
| Setup/hold violating paths | 0 |
| DRC violations | 0 |
| Connectivity violations | 0 |

These values come from the final saved Innovus database. The post-route flow used a 12 ns clock constraint; an earlier 4.6 ns synthesis constraint is not presented as the final routed timing target.

## Repository scope

Memory models, assignment/testbench files, synthesis/APR scripts, generated netlists, SDF, tool databases, and technology data are intentionally excluded.
