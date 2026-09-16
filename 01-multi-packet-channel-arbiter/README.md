# Multi-Packet Channel Arbiter

A combinational RTL engine that decrypts eight packet descriptors, ranks valid requests, assigns them to three capacity-limited channels, checks a policy mask, and performs a final load-balancing move.

## At a glance

| Item | Implementation |
| --- | --- |
| Input workload | Eight encrypted 16-bit packet descriptors |
| Cryptography | Four-round SPECK32/64-style inverse ARX datapath |
| Scheduling | Priority sort followed by preferred-channel and round-robin fallback allocation |
| Output | Two-bit channel decision for each original packet |
| Source | [src/MPCA.v](src/MPCA.v) |

## Architecture

The datapath is organized as five combinational stages:

1. **Key expansion and decryption** - derives four 16-bit round keys and reverses the rotate, XOR, and modular-add operations for four 32-bit blocks.
2. **Priority calculation** - scores each packet from QoS, packet length, congestion, source hint, and its signed/unsigned interpretation mode.
3. **Sorting network** - a fixed compare-swap network orders all eight packets while preserving their original indices.
4. **Channel allocation** - tries the preferred channel first, then rotates through available fallbacks while tracking capacity and current load.
5. **Policy and rebalance** - evaluates the mask rule, moves at most one eligible packet away from the most heavily loaded channel, and restores decisions to original packet order.

## What this project demonstrates

- Translating a multi-step scheduling algorithm into synthesizable combinational RTL
- Managing signed and unsigned arithmetic inside the same scoring datapath
- Using a deterministic sorting network instead of a software-style variable loop
- Preserving packet identity while transforming, sorting, allocating, and reordering data

## Repository scope

The repository contains my RTL implementation. The assignment handout, official patterns, and course testbench are intentionally excluded.

