# Geometric Transform Engine

An SRAM-based image accelerator that stores 128 grayscale images and executes 15 geometric or memory-order transforms between a selected source and destination image.

## At a glance

| Item | Implementation |
| --- | --- |
| Dataset | 128 images, each 16x16 pixels at 8 bits per pixel |
| Commands | Mirrors, transposes, rotations, shifts, zig-zag scans, and Morton orders |
| Memory system | Eight SRAM banks with 8-, 16-, and 32-bit words |
| Internal workspace | 256-byte image buffer plus address-generation logic |
| RTL | [src/GTE.v](src/GTE.v) |
| Reference model | [verification/algorithms.py](verification/algorithms.py) |
| Pattern generation | [verification/gen_pat.py](verification/gen_pat.py) |

## Supported operations

| Category | Operations |
| --- | --- |
| Reflection | X-axis mirror, Y-axis mirror, main-diagonal transpose, secondary-diagonal transpose |
| Rotation | 90°, 180°, and 270° clockwise |
| Shift | Right, left, up, and down |
| Reordering | 4x4/8x8 zig-zag and 4x4/8x8 Morton order |

## Architecture

The input loader writes 32,768 pixels in raster order across eight banks. Four banks store one byte per word, two pack two adjacent pixels per word, and two pack four pixels per word. Bank selection comes from the seven-bit image index, while row/column bits determine the word address and byte lane.

For each 18-bit command, the controller:

1. Decodes the operation plus source and destination image indices.
2. Reads all 256 source pixels, unpacking 8-, 16-, or 32-bit SRAM words as needed.
3. Maps each destination coordinate to a source coordinate or traversal index.
4. Re-packs the transformed pixels for the destination bank's word width.
5. Writes the completed image and releases busy for result checking and the next command.

The coordinate mapping is selected combinationally from opcode/function fields, while READ, EXE, and WRITE controller phases manage single-port memory timing.

## Verification and implementation

The Python reference model mirrors all 15 coordinate transformations and the generator builds randomized command sequences and expected images. These utilities were developed with AI assistance, then reviewed, adapted, and used by the author. The RTL was also taken through synthesis and the course APR flow.

## Repository scope

Licensed SRAM implementations and physical-design collateral are excluded. The RTL uses descriptive placeholders: sram_4096x8, sram_2048x16, and sram_1024x32.

