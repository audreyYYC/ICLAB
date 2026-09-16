# Lab 11 — Geometric Transformation Engine

An image-processing accelerator for geometric operations over SRAM-backed image data, accompanied by a NumPy reference model and pattern generator. The project was also taken through synthesis and an APR exercise.

- RTL: `src/GTE.v`
- Reference/verification: `verification/algorithms.py`, `verification/config.py`, `verification/gen_pat.py`
- Skills: image transforms, SRAM banking, RTL/reference-model co-verification, synthesis-to-APR handoff

Foundry memory files and physical-design collateral are excluded. Foundry SRAM identifiers in the RTL were replaced by `sram_4096x8`, `sram_2048x16`, and `sram_1024x32` placeholders. The Python utilities were developed with AI assistance and reviewed and adapted by the author.

