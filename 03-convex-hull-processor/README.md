# Convex Hull Processor

A streaming geometry accelerator that incrementally updates a convex polygon whenever a new 2-D point arrives. Points removed from the hull - including an incoming point that lies inside the current polygon - are returned through a variable-length output stream.

## At a glance

| Item | Implementation |
| --- | --- |
| Coordinate format | Unsigned 10-bit x/y inputs with signed intermediate differences |
| Geometric primitive | 2-D cross product for orientation testing |
| Hull representation | Coordinate arrays plus next-vertex links |
| Control | Input, traversal/compute, and output phases |
| Source | [src/CONVEX.v](src/CONVEX.v) |

## Architecture

The core orientation test is:

\[
\text{cross}=(x_1-x_0)(y_2-y_0)-(x_2-x_0)(y_1-y_0)
\]

Its sign identifies which side of a directed hull edge contains the new point. The controller walks the linked hull, detects the transition edges that bound the visible region, and then either inserts the new point or discards it. Vertices displaced by the update are collected in an output buffer and emitted on consecutive valid cycles.

The linked representation avoids shifting an entire vertex array after every insertion. Separate buffers retain hull coordinates and discarded points, while signed 11-bit coordinate differences and a signed 21-bit cross-product path preserve orientation information.

## What this project demonstrates

- Signed arithmetic and width planning for computational geometry
- Incremental data-structure updates in RTL
- Variable-latency traversal and variable-length output control
- Careful handling of interior, exterior, collinear, and multi-discard cases

## Repository scope

Only my design RTL is published. The course testbench and assignment materials are excluded.

