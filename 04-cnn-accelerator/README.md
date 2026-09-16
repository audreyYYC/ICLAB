# CNN Accelerator

A single-precision floating-point accelerator supporting two related workloads: a compact CNN inference pipeline and a capacity-constrained kernel-selection problem. The implementation schedules shared arithmetic hardware under an FSM rather than instantiating every operation spatially.

## At a glance

| Item | Implementation |
| --- | --- |
| Numeric format | IEEE-754 single precision |
| Input image | 6x6, one or two channels depending on task |
| Convolution | 3x3 kernels with replication or reflection padding |
| Nonlinear stages | Tanh or swish, then leaky ReLU in the inference path |
| Output stages | Fully connected layers and softmax, or best feasible kernel subset |
| Source | [src/CNN.v](src/CNN.v) |

## Workload 0: inference datapath

**Input capture -> padded convolution -> 3x3 max pooling -> tanh/swish -> FC(8 to 5) -> leaky ReLU -> FC(5 to 3) -> softmax**

Image samples, kernels, weights, and biases are buffered in register arrays. Nine floating-point multipliers form the convolution product set; shared add, compare, divide, and exponential operators are selected by the controller for pooling, activation, fully connected, and normalization phases.

## Workload 1: kernel selection

Four candidate kernels are convolved with the image. The design accumulates each convolution result, receives a capacity and four kernel costs, then evaluates feasible subsets to select the maximum-valued combination without exceeding capacity. Selecting no kernel is also legal.

## Design decisions

- The FSM explicitly separates input, convolution, activation, fully connected, softmax, and selection phases.
- Arithmetic resources are reused across stages to control area.
- Border handling is selected at runtime: replication for modes 00/01 and reflection for modes 10/11.
- Floating-point DesignWare operators provide multiplication, addition, comparison, division, and exponential functions; those licensed implementations are external dependencies and are not included.

## What this project demonstrates

Floating-point accelerator design, multi-phase datapath scheduling, resource sharing, CNN arithmetic, and integration of commercial arithmetic IP.

