# Final Project — MVDM Accelerator

A motion-vector difference/magnitude accelerator for image blocks. The hardware performs interpolation and block-based calculations over SRAM-resident reference data; Python code provides the algorithmic reference and pattern generation used to validate the RTL.

- RTL: `src/MVDM.v`
- Reference/verification: `verification/algorithms.py`, `verification/config.py`, `verification/gen_pat.py`
- Skills: image interpolation, memory-aware architecture, fixed-point arithmetic, RTL/reference-model co-verification, synthesis and APR

Foundry memory models, synthesis/APR files, generated netlists, timing annotation, and course testbench material are excluded. The Python utilities were developed with AI assistance and reviewed and adapted by the author.

