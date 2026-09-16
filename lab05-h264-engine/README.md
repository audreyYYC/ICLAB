# Lab 05 — H.264 Processing Engine

A memory-oriented H.264 processing engine built around block access, filtering, and carefully sequenced read/write operations. The portfolio includes the student controller/datapath, while the foundry memory model is excluded.

- Source: `src/HLPTE.v`
- Skills: memory scheduling, image/video datapaths, synthesis-aware RTL

`HLPTE.v` expects a course memory interface named `MEM`; its proprietary implementation is not included.

