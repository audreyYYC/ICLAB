# Sudoku Solver

A hardware constraint-propagation engine that receives a 9x9 Sudoku puzzle in raster order, iteratively fills forced values, and streams the completed grid back over 81 cycles.

## At a glance

| Item | Implementation |
| --- | --- |
| Grid storage | 81 registers, four bits per cell |
| Solving rules | Naked singles and hidden singles |
| Constraint scopes | Row, column, and 3x3 box |
| Controller | Input, solve, and output FSM phases |
| Source | [src/SUDOKU.v](src/SUDOKU.v) |

## Architecture

During input, each digit is written into its raster-indexed grid location. In the solve phase, the logic examines every empty cell and builds the set of legal digits by checking the corresponding row, column, and 3x3 box.

- A **naked single** is written when only one digit is legal for a cell.
- A **hidden single** is written when a legal digit cannot be placed anywhere else in the same row, column, or box.
- The next-state grid is committed each cycle, allowing newly resolved values to enable further deductions on later iterations.
- Completion is detected when no grid entry remains zero, after which the controller outputs all 81 cells in raster order.

This is a deterministic constraint-propagation architecture; it does not implement speculative search or backtracking.

## What this project demonstrates

- Mapping a constraint-solving algorithm into parallel comparison logic
- Indexing a flattened two-dimensional structure in synthesizable RTL
- Separating iterative datapath updates from input/output protocol control
- Handling a bounded-latency variable-iteration computation

## Repository scope

The repository contains my RTL implementation. Course-provided patterns, checker code, and the original handout are excluded.

